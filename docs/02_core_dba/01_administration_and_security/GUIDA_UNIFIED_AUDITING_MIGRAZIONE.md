# GUIDA MONUMENTALE: Migrazione e Gestione di Oracle Unified Auditing (19c/21c/23ai)

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI:**
> - **Unified Auditing (questa guida)**: Focus su compliance, audit storage, e integrazione SIEM.
> - **Setup Database Vault**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms CDB/PDB).
> - **Data Masking & Redaction**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento in transito ed at-rest).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md).

---

## 1. Architettura Tradizionale vs Unified Auditing

Negli ambienti Oracle antecedenti alla 12c, il sistema di auditing era frammentato (Traditional Auditing). Le informazioni venivano scritte in diverse locazioni:
- `AUD$` e `FGA_LOG$` (nel tablespace SYSTEM).
- Directory del sistema operativo per l'audit di SYSDBA (es. `$ORACLE_BASE/admin/$ORACLE_SID/adump`).
- Tabelle e viste di Database Vault e Label Security separate.

Questo generava enormi problemi di performance (lock sui dizionari) e di frammentazione delle logiche di parsing per gli strumenti SIEM (Splunk, QRadar, ArcSight).

**Oracle Unified Auditing** centralizza e consolida tutti gli eventi di sicurezza:
1. Standard e Fine-Grained Auditing (FGA).
2. Azioni di amministrazione (`SYSDBA`, `SYSOPER`, `SYSBACKUP`).
3. RMAN (Recovery Manager) operations.
4. Database Vault, Label Security e Data Pump.

I record vengono ora memorizzati in modo asincrono, ad altissime prestazioni, nello schema dedicato `AUDSYS` (risiedente di default nel tablespace `SYSAUX`), e interrogabili tramite un'unica vista unificata: `UNIFIED_AUDIT_TRAIL`.

### 1.1 Mixed Mode vs Pure Unified Auditing
Di default, in Oracle 19c, l'ambiente è installato in **Mixed Mode**. Questo significa che sia il Traditional Auditing (basato sul parametro `audit_trail=DB`) sia l'Unified Auditing sono attivi in parallelo.
Per ottenere i veri benefici prestazionali ed architetturali, l'infrastruttura Enterprise deve essere migrata al **Pure Unified Auditing**, ricompilando i binari Oracle.

---

## 2. Abilitazione del Pure Unified Auditing (Migrazione dal Mixed Mode)

L'abilitazione del Pure Unified Auditing è irreversibile e richiede un downtime per la ricompilazione dei binari. Disabiliterà tutti i vecchi parametri tradizionali come `AUDIT_TRAIL`, `AUDIT_FILE_DEST` e `AUDIT_SYS_OPERATIONS`.

### Step 1: Verifica dello Stato Attuale
```sql
sqlplus / as sysdba

-- Restituisce FALSE se sei in Mixed Mode. Restituisce TRUE se sei già in Pure Mode.
SELECT value FROM v$option WHERE parameter = 'Unified Auditing';
```

### Step 2: Riavvio Non-Rolling del Cluster (RAC) e Ricompilazione
In un ambiente RAC, l'operazione deve essere coordinata ed eseguita a database spento.

```bash
# Entra con l'utente oracle sul nodo amministrativo del database OS
srvctl stop database -d RACDB

# Esegui la ricompilazione del kernel per abilitare Unified Auditing (uniaud_on)
cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk uniaud_on ioracle

# (Opzionale: per annullare l'operazione usa uniaud_off)
# make -f ins_rdbms.mk uniaud_off ioracle

# Riavvia il database a livello cluster
srvctl start database -d RACDB
```

### Step 3: Verifica post-ricompilazione
```sql
SELECT value FROM v$option WHERE parameter = 'Unified Auditing';
-- Risultato atteso: TRUE
```
Tutti i record di audit tradizionali presenti in `AUD$` possono ora essere archiviati, poiché non verranno più popolati.

---

## 3. Gestione e Spostamento dello Spazio `AUDSYS`

L'Unified Audit inserisce record nella tabella a partizionamento per intervallo (Interval-Partitioned Table) sotto lo schema `AUDSYS`. Di default, questo risiede nel tablespace `SYSAUX`. Nelle banche ed ambienti enterprise, una policy di audit aggressiva può saturare rapidamente il `SYSAUX`, impattando l'AWR.

**È obbligatorio spostare l'Unified Audit Trail su un tablespace dedicato.**

### Step 1: Creazione Tablespace Dedicato
```sql
sqlplus / as sysdba

CREATE SMALLFILE TABLESPACE TBS_UNIFIED_AUDIT 
  DATAFILE '+DATA' SIZE 5G AUTOEXTEND ON NEXT 1G MAXSIZE 30G
  LOGGING ONLINE PERMANENT BLOCKSIZE 8192 
  EXTENT MANAGEMENT LOCAL AUTOALLOCATE SEGMENT SPACE MANAGEMENT AUTO;
```

### Step 2: Relocazione dello storage di `AUDSYS` tramite `DBMS_AUDIT_MGMT`
```sql
BEGIN
  DBMS_AUDIT_MGMT.SET_AUDIT_TRAIL_LOCATION(
    audit_trail_type            => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    audit_trail_location_value  => 'TBS_UNIFIED_AUDIT'
  );
END;
/
```
L'operazione è online e sposterà le nuove partizioni e i metadati. Per spostare i record già scritti, occorre gestire la partition table in manuale o eseguire un purge.

---

## 4. Policy Customizzate: Creazione, Attivazione ed Esempi

Unified Auditing lavora tramite il concetto di "Policies". Tu definisci *cosa* tracciare in una policy, e poi *abiliti* quella policy per uno specifico utente (o per tutti `BY ALL`).

> [!TIP]
> **Le Default Policies in Oracle 19c:**
> Oracle abilita di default due policy: `ORA_SECURECONFIG` e `ORA_LOGON_FAILURES`. Assicurati che siano attive con `SELECT * FROM AUDIT_UNIFIED_ENABLED_POLICIES;`.

### Esempio 1: Tracciare specifici Comandi DDL di Sicurezza
Vogliamo un alert log ogni volta che qualcuno modifica ruoli o utenti.

```sql
-- 1. Crea la Policy
CREATE AUDIT POLICY audit_security_admin_pol
  PRIVILEGES CREATE USER, ALTER USER, DROP USER, GRANT ANY ROLE, DROP ANY ROLE;

-- 2. Abilita la Policy per tutti
AUDIT POLICY audit_security_admin_pol;
```

### Esempio 2: Tracciare DML su Dati Sensibili con Condizioni (Fine-Grained)
Vogliamo sapere chi legge o modifica la tabella `HR.SALARIES`, ma **SOLO** se l'utente che effettua la query NON proviene dalla subnet applicativa fidata `192.168.10.%`.

```sql
-- 1. Crea la policy con la clausola WHEN (valutata context-aware)
CREATE AUDIT POLICY audit_salary_access_pol
  ACTIONS SELECT ON HR.SALARIES, UPDATE ON HR.SALARIES
  WHEN 'SYS_CONTEXT(''USERENV'', ''IP_ADDRESS'') NOT LIKE ''192.168.10.%'''
  EVALUATE PER STATEMENT;

-- 2. Abilita la policy per tutti eccetto l'utente batch
AUDIT POLICY audit_salary_access_pol EXCEPT batch_user;
```

### Esempio 3: Tracciare i fallimenti DBA e Data Pump
```sql
CREATE AUDIT POLICY audit_dba_fail_pol
  ROLES DBA, SYSDBA, DATAPUMP_EXP_FULL_DATABASE
  WHENEVER NOT SUCCESSFUL;

AUDIT POLICY audit_dba_fail_pol;
```

---

## 5. Manutenzione del Repository (Purge & Archiving)

Senza una corretta procedura di pulizia periodica (Purge), il tablespace `TBS_UNIFIED_AUDIT` si riempirà rapidamente, generando rallentamenti o il blocco delle operazioni di logon degli utenti (`ORA-00604` / `ORA-20000`).
La pulizia deve essere programmata (Job Scheduler) in base alle policy di retention aziendali (es. 90 giorni in DB, il resto esportato).

### Workflow per Creare un Purge Automatico a 90 giorni:

```sql
sqlplus / as sysdba

-- 1. Inizializza il sub-system di Audit Management per Unified
BEGIN
  DBMS_AUDIT_MGMT.INIT_CLEANUP(
    audit_trail_type          => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    default_cleanup_interval  => 24 -- Frequenza di pulizia oraria (default fallback)
  );
END;
/

-- 2. Definisci l'Ages di Pulizia (es. mantieni 90 giorni)
-- Questo imposta il timestamp Last-Archive
BEGIN
  DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(
    audit_trail_type     => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    last_archive_time    => SYSDATE - 90
  );
END;
/

-- 3. Crea il Job di Purge Schedulato all'interno di Oracle
BEGIN
  DBMS_AUDIT_MGMT.CREATE_PURGE_JOB(
    audit_trail_type            => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    audit_trail_purge_interval  => 24, -- Esegui il job ogni 24 ore
    audit_trail_purge_name      => 'JOB_PURGE_UNIFIED_AUDIT',
    use_last_arch_timestamp     => TRUE -- Pulisci solo i record più vecchi di SYSDATE-90 (impostato sopra)
  );
END;
/

-- Per visualizzare o modificare il Last Archive Time programmaticamente, usa un DBMS_SCHEDULER 
-- custom che chiami SET_LAST_ARCHIVE_TIMESTAMP prima del purge job giornaliero.
```

---

## 6. Integrazione Avanzata con i Sistemi SIEM (SYSLOG)

In architetture moderne "Zero-Trust", gli audit log non dovrebbero rimanere sul database. I DBA potrebbero manometterli (qualora la SoD del Database Vault non fosse adeguata). La best-practice è inviare l'Unified Audit al demone OS `syslog` in tempo reale, affinché strumenti di classe SIEM (Splunk, IBM QRadar, Datadog) li aggreghino senza query impattanti.

### Step 1: Modifica dei Parametri di Rete in `sqlnet.ora`
Modifica il file `$ORACLE_HOME/network/admin/sqlnet.ora` ed aggiungi:

```ini
UNIFIED_AUDIT_SYSTEMLOG = { "FACILITY":"syslog.local0", "LEVEL":"syslog.info" }
```

### Step 2: Disabilita il write on database e spingi su Syslog
Di default, Oracle scriverebbe *sia* su DB che su Syslog, aumentando l'I/O. Per forzare *esclusivamente* l'output Syslog, occorre alterare il parametro a livello PDB o CDB.

```sql
-- Scrive in UNIFIED_AUDIT_TRAIL (valore di default 'TABLE') e opzionalmente syslog
-- Modifica questo comportamento a livello di istanza
ALTER SYSTEM SET UNIFIED_AUDIT_SYSTEMLOG = 'syslog.local0.info' SCOPE=SPFILE;
```
> [!WARNING]
> La scrittura asincrona su syslog in ambienti ad altissima transazionalità (100k+ TPS) potrebbe sovraccaricare il buffer del sistema operativo `/dev/log`. È necessario tunizzare l'Rsyslog linux o usare agent esterni (Splunk Universal Forwarder) che leggono direttamente la tabella `UNIFIED_AUDIT_TRAIL` su read-replica (Active Data Guard) per non pesare sul primario.

---

## 7. Troubleshooting e Viste Diagnostiche Fondamentali

In caso di incidenti o problemi di performance, utilizza le seguenti query:

**1. Individuare la dimensione fisica reale dei record non partizionati:**
```sql
SELECT segment_name, bytes/1024/1024/1024 as GB 
FROM dba_segments 
WHERE owner = 'AUDSYS' ORDER BY GB DESC;
```

**2. Ispezionare un allarme di Data Breach:**
```sql
SELECT event_timestamp, 
       dbusername, 
       client_program_name, 
       os_username, 
       userhost, 
       action_name, 
       object_schema, 
       object_name, 
       sql_text
FROM unified_audit_trail
WHERE event_timestamp >= SYSDATE - 1
AND action_name IN ('SELECT', 'UPDATE', 'DELETE')
AND dbusername NOT IN ('APP_SERVER')
ORDER BY event_timestamp DESC;
```

**3. Verificare i Job di Purge bloccati o interrotti:**
```sql
SELECT job_name, job_status, audit_trail_type, job_frequency 
FROM dba_audit_mgmt_cleanup_jobs;
```
Se il purge job si blocca regolarmente, aumentare lo spazio del Tablespace dedicato o diminuire l'intervallo di retention (es. da 90 a 30 giorni) e rieseguire `DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL` manualmente in fasce notturne in piccoli lotti per sbloccare l'High Water Mark (HWM).
