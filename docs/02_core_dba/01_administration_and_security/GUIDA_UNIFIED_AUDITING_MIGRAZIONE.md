# GUIDA COMPLETA: Oracle Unified Auditing — Migrazione, Policy Multitenant & Ottimizzazione Storage

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
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
                                        │
                                        ▼
                   La sessione scatena una policy di audit
                                        │
                                        ▼
             ┌─────────────────────────────────────────────────────┐
             │       UNIFIED AUDIT BUFFER (Memoria SGA)            │
             │ Scrittura asincrona veloce per non bloccare il client│
             └─────────────────────────────────────────────────────┘
                                        │
                                        ▼ (Flushing asincrono)
             ┌─────────────────────────────────────────────────────┐
             │            TABELLA AUDSYS.AUD$UNIFIED               │
             │       Vista di sistema: UNIFIED_AUDIT_TRAIL         │
             └─────────────────────────────────────────────────────┘
```

### Principali Differenze Strutturali:

| Caratteristica | Traditional Auditing | Unified Auditing |
|---|---|---|
| **Prestazioni** | Scrittura sincrona su disco. Rallenta pesantemente le transazioni OLTP massive. | Scrittura asincrona in memoria (SGA buffer). Impatto prestazionale quasi impercettibile. |
| **Archiviazione** | Frammentata in `SYS.AUD$`, `SYS.FGA_LOG$` e file di sistema OS. | Centralizzata ed unificata nello schema di sistema `AUDSYS` (tablespace `SYSAUX`). |
| **Multitenancy** | Configurazione locale per ogni database. | Supporto per policy comuni (CDB) e locali (PDB). |
| **Separazione Doveri** | Il DBA con ruoli di sistema può cancellare i log direttamente. | Gestito dal ruolo delegato `AUDIT_ADMIN`. Nessun utente (incluso `SYS`) può modificare i log di audit. |

---

## 2. mixed Mode vs Pure Unified Auditing Mode

Di default, quando installi o effettui un upgrade ad Oracle 19c/21c/23ai, il database si avvia in **Mixed Mode**. Questo consente di utilizzare Unified Auditing mantenendo attiva la retrocompatibilità con i vecchi parametri tradizionali. 
Tuttavia, per conformarsi alle normative **PCI-DSS** o **GDPR** e sbloccare i massimi benefici prestazionali dell'auditing asincrono, è obbligatorio disabilitare l'audit tradizionale e passare alla modalità **Pure Unified Auditing Mode**.

### 2.1 Verifica dello stato attuale
Controlliamo se la modalità Pure è attiva o se siamo ancora in modalità mista:

```sql
sqlplus / as sysdba

-- 1. Controlla se l'opzione Unified Auditing è abilitata
SELECT parameter, value FROM v$option WHERE parameter = 'Unified Auditing';
-- Output atteso: Unified Auditing | TRUE

-- 2. Verifica se i parametri tradizionali sono attivi (se diversi da NONE, siamo in Mixed Mode)
SHOW PARAMETER audit_trail;
-- Se il parametro è diverso da NONE (es. DB, OS), l'audit tradizionale è ancora attivo.
```

---

## 3. Workflow di Abilitazione Pure Mode (Rolling RAC & Single Node)

Per attivare la modalità **Pure**, occorre disabilitare i parametri tradizionali nel database e **ricompilare il binario eseguibile Oracle** a livello di sistema operativo per linkare la libreria `uniaud_on`.

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
In ambienti di produzione clusterizzati (RAC), è possibile abilitare la modalità Pure **senza causare il downtime completo del database**, agendo un nodo alla volta in modalità rolling.

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

Per impostazione predefinita, le righe di audit vengono salvate all'interno del tablespace `SYSAUX`. In ambienti di produzione ad alto traffico, questo può saturare rapidamente il tablespace di sistema, provocando rallentamenti gravissimi sul dizionario e disservizi globali.
**Standard Enterprise**: Spostare l'archiviazione di Unified Auditing su un tablespace dedicato ed impostare un meccanismo automatico di pulizia (*Purge*).

```
                      [ PROCESSO DI FLUSH DI AUDIT ]
                                    │
                  Verifica la locazione di destinazione:
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         ▼                                                     ▼
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
Configuriamo una soglia di conservazione di 30 giorni. I dati più vecchi verranno eliminati automaticamente ogni notte.

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

In ambienti OLTP ad altissime transazioni (es. core banking), il comportamento predefinito di Unified Auditing può essere calibrato per ottimizzare ulteriormente il throughput.

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
