# GUIDA COMPLETA: Oracle Unified Auditing ÔÇö Migrazione, Policy Multitenant & Ottimizzazione Storage

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PI+Ö ADATTO):**
> - **Unified Auditing & Compliance (questa guida)**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) (attivazione policy di audit, storage e purge automatico).
> - **Setup Database Vault**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms CDB/PDB, protezione SYSDBA).
> - **Data Masking & Redaction**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento dinamico con DBMS_REDACT e statico con Data Pump).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md) (TDE, Auditing base, Password Profiles).

---

## 1. Traditional Auditing vs Unified Auditing: L'Evoluzione di Oracle

Nelle versioni di Oracle precedenti alla 12c, l'auditing era frammentato in vari motori e tabelle di sistema all'interno dello schema `SYS`:
*   Audit Standard/Tradizionale: Tabella `SYS.AUD$` (gestita tramite parametro `AUDIT_TRAIL`).
*   Fine-Grained Auditing (FGA): Tabella `SYS.FGA_LOG$` (gestita via `DBMS_FGA`).
*   Audit Amministrativo (SYSDBA): File di testo salvati a livello OS in formato `.aud` o nel registro eventi di Windows/Syslog.

Questo approccio creava colli di bottiglia e gravi rischi prestazionali. Le scritture sui log dell'audit tradizionale erano **sincrone**: ogni istruzione monitorata doveva attendere l'inserimento fisico del record di audit su disco nella tabella `SYS.AUD$` prima di poter committare la transazione applicativa.

**Unified Auditing** rivoluziona questo sistema introducendo un'architettura ad altissime prestazioni:

```
                  [ ISTANTE DI QUERY / TRANSAZIONE APPLICATIVA ]
                                        Ôöé
                                        Ôû+
                   La sessione scatena una policy di audit
                                        Ôöé
                                        Ôû+
             ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
             Ôöé       UNIFIED AUDIT BUFFER (Memoria SGA)            Ôöé
             Ôöé Scrittura asincrona veloce per non bloccare il clientÔöé
             ÔööÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÿ
                                        Ôöé
                                        Ôû+ (Flushing asincrono)
             ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
             Ôöé            TABELLA AUDSYS.AUD$UNIFIED               Ôöé
             Ôöé       Vista di sistema: UNIFIED_AUDIT_TRAIL         Ôöé
             ÔööÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÿ
```

### Principali Differenze Strutturali:

| Caratteristica | Traditional Auditing | Unified Auditing |
|---|---|---|
| **Prestazioni** | Scrittura sincrona su disco. Rallenta pesantemente le transazioni OLTP massive. | Scrittura asincrona in memoria (SGA buffer). Impatto prestazionale quasi impercettibile. |
| **Archiviazione** | Frammentata in `SYS.AUD$`, `SYS.FGA_LOG$` e file di sistema OS. | Centralizzata ed unificata nello schema di sistema `AUDSYS` (tablespace `SYSAUX`). |
| **Multitenancy** | Configurazione locale per ogni database. | Supporto per policy comuni (CDB) e locali (PDB). |
| **Separazione Doveri** | Il DBA con ruoli di sistema pu+▓ cancellare i log direttamente. | Gestito dal ruolo delegato `AUDIT_ADMIN`. Nessun utente (incluso `SYS`) pu+▓ modificare i log di audit. |

---

## 2. mixed Mode vs Pure Unified Auditing Mode

Di default, quando installi o effettui un upgrade ad Oracle 19c/21c/23ai, il database si avvia in **Mixed Mode**. Questo consente di utilizzare Unified Auditing mantenendo attiva la retrocompatibilit+á con i vecchi parametri tradizionali. 
Tuttavia, per conformarsi alle normative **PCI-DSS** o **GDPR** e sbloccare i massimi benefici prestazionali dell'auditing asincrono, +¿ obbligatorio disabilitare l'audit tradizionale e passare alla modalit+á **Pure Unified Auditing Mode**.

### 2.1 Verifica dello stato attuale
Controlliamo se la modalit+á Pure +¿ attiva o se siamo ancora in modalit+á mista:

```sql
sqlplus / as sysdba

-- 1. Controlla se l'opzione Unified Auditing +¿ abilitata
SELECT parameter, value FROM v$option WHERE parameter = 'Unified Auditing';
-- Output atteso: Unified Auditing | TRUE

-- 2. Verifica se i parametri tradizionali sono attivi (se diversi da NONE, siamo in Mixed Mode)
SHOW PARAMETER audit_trail;
-- Se il parametro +¿ diverso da NONE (es. DB, OS), l'audit tradizionale +¿ ancora attivo.
```

---

## 3. Workflow di Abilitazione Pure Mode (Rolling RAC & Single Node)

Per attivare la modalit+á **Pure**, occorre disabilitare i parametri tradizionali nel database e **ricompilare il binario eseguibile Oracle** a livello di sistema operativo per linkare la libreria `uniaud_on`.

### 3.1 Procedura Completa su Node Singolo (Single Instance)

```bash
# Esegui come utente oracle a livello OS

# 1. Imposta i parametri del database a NONE per spegnere l'audit tradizionale
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET audit_trail=NONE SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
EXIT;
EOF

# 2. Spegni il listener
lsnrctl stop

# 3. Spostati nella directory delle librerie e ricompila il binario abilitando uniaud
cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk uniaud_on ioracle

# 4. Riavvia listener e database
lsnrctl start
sqlplus / as sysdba <<EOF
STARTUP;
SELECT select_path, status FROM dba_audit_mgmt_config_params WHERE parameter_name = 'AUDIT SYSTEM TO OS';
EOF
```

### 3.2 Procedura in ambiente RAC (Rolling Upgrade Node-by-Node)
In ambienti di produzione clusterizzati (RAC), +¿ possibile abilitare la modalit+á Pure **senza causare il downtime completo del database**, agendo un nodo alla volta in modalit+á rolling.

```bash
# ==========================================
# SUL NODO 1:
# ==========================================
# 1. Imposta a NONE i parametri tradizionali nel cluster (valido per tutte le istanze)
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET audit_trail=NONE SCOPE=SPFILE SID='*';
EOF

# 2. Arresta l'istanza 1 tramite Grid Infrastructure
srvctl stop instance -d RACDB -i RACDB1

# 3. Ricompila il motore Oracle sul nodo 1
cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk uniaud_on ioracle

# 4. Riavvia l'istanza 1
srvctl start instance -d RACDB -i RACDB1

# ==========================================
# SUL NODO 2:
# ==========================================
# 5. Arresta l'istanza 2
srvctl stop instance -d RACDB -i RACDB2

# 6. Ricompila il motore Oracle sul nodo 2
cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk uniaud_on ioracle

# 7. Riavvia l'istanza 2
srvctl start instance -d RACDB -i RACDB2
```

---

## 4. Policy di Audit Multitenant (Common vs Local)

In un database Multitenant, Unified Auditing consente di definire le policy con due ambiti differenti:
1.  **Common Audit Policy**: Definita nel `CDB$ROOT` (spesso dagli utenti `C##`), monitora le azioni comuni in tutti i Pluggable Database (PDB) attuali e futuri.
2.  **Local Audit Policy**: Definita all'interno di un singolo PDB, traccia le azioni ed i dati locali specifici di quel contenitore.

### 4.1 Creazione di una Policy Comune (CDB$ROOT)
Vogliamo monitorare ogni tentativo fallito di login (`LOGON`) su tutto il parco PDB.

```sql
sqlplus / as sysdba
-- Connesso a CDB$ROOT

-- Creazione della policy comune
CREATE AUDIT POLICY pol_common_failed_logon
  ACTIONS LOGON
  CONTAINER = ALL; -- Rendila visibile e attiva in tutti i PDB

-- Abilitazione globale solo per i fallimenti
AUDIT POLICY pol_common_failed_logon WHENEVER NOT SUCCESSFUL;
```

### 4.2 Creazione di Policy Locali con filtri basati su Contesti (PDB Applicativo)
Ci spostiamo nel PDB `PDB_PROD` per tracciare le modifiche DDL sensibili dei dipendenti del dipartimento IT, escludendo l'utente di deployment automatizzato `ANSIBLE_USER`.

```sql
sqlplus / as sysdba
ALTER SESSION SET CONTAINER = PDB_PROD;

-- Creazione della policy locale con clausola condizionale WHEN
CREATE AUDIT POLICY pol_local_security_it
  ACTIONS CREATE TABLE, ALTER TABLE, DROP TABLE, CREATE USER, GRANT
  WHEN 'SYS_CONTEXT(''USERENV'', ''SESSION_USER'') != ''ANSIBLE_USER'''
  EVALUATE PER STATEMENT;

-- Abilita la policy localmente
AUDIT POLICY pol_local_security_it;
```

---

## 5. Lettura e Diagnostica Avanzata

I record generati confluiscono in tempo reale nella vista di sistema `UNIFIED_AUDIT_TRAIL`. Per scopi forensi, ecco le query essenziali da usare in produzione.

### Query 1: Tracciare tentativi di attacco per brute-force (accessi falliti consecutivi)
```sql
SELECT event_timestamp,
       dbusername,
       userhost,
       client_program_name,
       os_username,
       authentication_type
FROM   unified_audit_trail
WHERE  action_name = 'LOGON'
AND    return_code > 0 -- Indica un fallimento (es. ORA-01017: invalid username/password)
AND    event_timestamp > SYSDATE - 1/24 -- nell'ultima ora
ORDER BY event_timestamp DESC;
```

### Query 2: Tracciare DDL e modifiche strutturali critiche eseguite da SYSDBA
```sql
SELECT event_timestamp,
       dbusername,
       action_name,
       object_schema,
       object_name,
       sql_text
FROM   unified_audit_trail
WHERE  unified_audit_policies LIKE '%STRUCTURAL%'
OR     dbusername = 'SYS'
ORDER BY event_timestamp DESC;
```

---

## 6. Ottimizzazione dello Storage: Purge Automatico e Spostamento in Tablespace Dedicato

Per impostazione predefinita, le righe di audit vengono salvate all'interno del tablespace `SYSAUX`. In ambienti di produzione ad alto traffico, questo pu+▓ saturare rapidamente il tablespace di sistema, provocando rallentamenti gravissimi sul dizionario e disservizi globali.
**Standard Enterprise**: Spostare l'archiviazione di Unified Auditing su un tablespace dedicato ed impostare un meccanismo automatico di pulizia (*Purge*).

```
                      [ PROCESSO DI FLUSH DI AUDIT ]
                                    Ôöé
                  Verifica la locazione di destinazione:
                                    Ôöé
         ÔöîÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔö+ÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÇÔöÉ
         Ôû+                                                     Ôû+
    (Default)                                             (Consigliato)
 Spazio su SYSAUX                                    Tablespace Isolato AUD_DATA
   - Rischio di stallo DB                              - Nessun rischio per SYSAUX
   - Frammentazione dizionario                         - Facile manutenzione I/O
```

### Step 1: Creazione del Tablespace dedicato (consigliato BIGFILE su ASM)
```sql
CREATE BIGFILE TABLESPACE AUD_DATA
  DATAFILE '+DATA' SIZE 5G AUTOEXTEND ON NEXT 1G MAXSIZE 100G
  LOGGING
  EXTENT MANAGEMENT LOCAL;
```

### Step 2: Spostamento fisico del repository di Unified Audit
Il package `DBMS_AUDIT_MGMT` provvede allo spostamento a caldo della tabella `AUDSYS.AUD$UNIFIED`.
```sql
BEGIN
  DBMS_AUDIT_MGMT.SET_AUDIT_TRAIL_LOCATION(
    audit_trail_type            => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    audit_trail_location_value  => 'AUD_DATA'
  );
END;
/

-- Verifica il successo dell'operazione
SELECT parameter_name, parameter_value 
FROM   dba_audit_mgmt_config_params 
WHERE  parameter_name = 'AUDIT LEVEL';
```

### Step 3: Configurazione del Job di Purge Automatico
Configuriamo una soglia di conservazione di 30 giorni. I dati pi++ vecchi verranno eliminati automaticamente ogni notte.

```sql
-- 1. Inizializza il cleanup per Unified Audit
BEGIN
  DBMS_AUDIT_MGMT.INIT_CLEANUP(
    audit_trail_type         => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    default_cleanup_interval => 24 -- ore
  );
END;
/

-- 2. Definisci un job per l'aggiornamento automatico della data di conservazione (mantiene 30 giorni)
BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'JOB_SET_AUDIT_ARCHIVE_TS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                          DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(
                            audit_trail_type  => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
                            last_archive_time => SYSDATE - 30
                          );
                        END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=5', -- Esegui ogni notte alle 00:05
    enabled         => TRUE,
    comments        => 'Aggiorna la data di archiviazione dell''audit a 30 giorni'
  );
END;
/

-- 3. Crea il Job di Purge reale integrato di Oracle
BEGIN
  DBMS_AUDIT_MGMT.CREATE_PURGE_JOB(
    audit_trail_type           => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    purge_interval             => 24, -- esegui ogni 24 ore
    use_last_arch_timestamp    => TRUE, -- cancella solo quello antecedente a last_archive_timestamp
    container                  => DBMS_AUDIT_MGMT.CONTAINER_ALL
  );
END;
/
```

---

## 7. Tuning Avanzato delle Performance di Unified Auditing

In ambienti OLTP ad altissime transazioni (es. core banking), il comportamento predefinito di Unified Auditing pu+▓ essere calibrato per ottimizzare ulteriormente il throughput.

### 7.1 Immediate Write vs Queued Write
Di default, Oracle utilizza la scrittura asincrona tramite un buffer in memoria SGA (**Queued Write Mode**). Se preferisci la sicurezza assoluta della persistenza immediata (es. per policy a livello governativo), puoi forzare la scrittura immediata (**Immediate Write Mode**), tenendo presente che questo potrebbe influire minimamente sulla latenza delle query.

```sql
-- Impostare la scrittura immediata (Immediate Mode)
BEGIN
  DBMS_AUDIT_MGMT.SET_AUDIT_TRAIL_PROPERTY(
    audit_trail_type  => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    audit_trail_property => DBMS_AUDIT_MGMT.AUDIT_TRAIL_WRITE_MODE,
    audit_trail_property_value => DBMS_AUDIT_MGMT.AUDIT_TRAIL_WRITE_IMMEDIATE
  );
END;
/

-- Ripristinare la scrittura asincrona in memoria (Queued Mode - Default raccomandato)
BEGIN
  DBMS_AUDIT_MGMT.SET_AUDIT_TRAIL_PROPERTY(
    audit_trail_type  => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    audit_trail_property => DBMS_AUDIT_MGMT.AUDIT_TRAIL_WRITE_MODE,
    audit_trail_property_value => DBMS_AUDIT_MGMT.AUDIT_TRAIL_WRITE_QUEUED
  );
END;
/
```


================================================================================

# [SEZIONE AGGIUNTIVA] APPROFONDIMENTO MONUMENTALE


## [ARCHITETTURA VISIVA] Unified Auditing & SIEM
```text

[ Utenti / DBA ] ---> (Oracle Unified Auditing Kernel)
                                 |
           +---------------------+---------------------+
           | Asincrono                                 | Asincrono
           v                                           v
[ AUDSYS.UNIFIED_AUDIT_TRAIL ]                 [ OS Syslog Daemon ]
           |                                           |
           v DBMS_AUDIT_MGMT (Purge)                   v Forwarder
[ Archiviazione Storica ]                      [ SIEM (Splunk/QRadar) ]
```

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
