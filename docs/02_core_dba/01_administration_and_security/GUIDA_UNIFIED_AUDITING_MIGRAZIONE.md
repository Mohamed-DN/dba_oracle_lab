# GUIDA: Oracle Unified Auditing — Migrazione, Policy Avanzate & Gestione Storage

> [!NOTE]
> **DOCUMENTI DI SICUREZZA CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Unified Auditing & Compliance (questa guida)**: [GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md](./GUIDA_UNIFIED_AUDITING_MIGRAZIONE.md) (attivazione policy di audit e gestione storage).
> - **Setup Database Vault**: [GUIDA_DATABASE_VAULT_ENTERPRISE.md](./GUIDA_DATABASE_VAULT_ENTERPRISE.md) (Separation of duties, Realms, protezione SYSDBA).
> - **Data Masking & Redaction**: [GUIDA_DATA_MASKING_REDACTION.md](./GUIDA_DATA_MASKING_REDACTION.md) (mascheramento dinamico e statico di dati sensibili).
> - **Security Hardening Generale**: [GUIDA_SECURITY_HARDENING.md](./GUIDA_SECURITY_HARDENING.md) (TDE, Auditing base, Password Profiles).

---

## 1. Traditional Auditing vs Unified Auditing

Fino a Oracle 12c, l'audit era frammentato: esistevano i log dell'audit tradizionale (`AUD$`), dell'audit fine-grained (`FGA_LOG$`), e dell'audit di rete, ognuno salvato in tabelle e formati diversi.

A partire da Oracle 12c e consolidato in **19c/21c/23ai**, Oracle introduce **Unified Auditing**. Tutti i record di audit vengono scritti in un unico formato centralizzato ad altissime prestazioni in memoria (tramite code asincrone) e poi scaricati nella tabella di sistema `AUD$UNIFIED` (esposta tramite la vista `UNIFIED_AUDIT_TRAIL`) nel tablespace `SYSAUX`.

### Confronto Strutturale:

| Caratteristica | Traditional Auditing | Unified Auditing |
|---|---|---|
| **Prestazioni** | Scrittura sincrona a disco (rallenta le transazioni in caso di audit massivo). | Scrittura asincrona in memoria (impatto prestazionale quasi nullo). |
| **Archiviazione** | Dispersa in `SYS.AUD$`, `SYS.FGA_LOG$`, file OS. | Unificata in `AUDSYS.AUD$UNIFIED` (`SYSAUX`). |
| **Flessibilità** | Configurazione rigida tramite parametri statici (`AUDIT_TRAIL`). | Policy dinamiche condizionali (`CREATE AUDIT POLICY ... WHEN`). |
| **Separazione Doveri** | Il DBA può cancellare i log direttamente. | Possibilità di delegare la gestione dell'audit al solo audit manager (`AUDIT_ADMIN`). |

---

## 2. Verifica Stato & Modalità (Mixed Mode vs Pure Mode)

Di default, in Oracle 19c, Unified Auditing è attivo in **Mixed Mode** (modalità mista), il che significa che coesiste con il vecchio Traditional Auditing. Per ottenere le massime prestazioni e aderenza agli standard PCI-DSS, è raccomandato passare alla **Pure Unified Auditing Mode**.

### 2.1 Verifica dello stato attuale
Esegui la query per capire in quale modalità si trova il database:

```sql
sqlplus / as sysdba

SELECT value FROM v$option WHERE parameter = 'Unified Auditing';
-- Output atteso in Mixed Mode: TRUE
-- Output atteso in Pure Mode: TRUE (ma con parametri tradizionali disabilitati)
```

Per determinare se sei in Pure Mode, controlla se l'eseguibile oracle ha la libreria unificata linkata:

```sql
SELECT select_path, status FROM dba_audit_mgmt_config_params WHERE parameter_name = 'AUDIT SYSTEM TO OS';
```

---

## 3. Workflow di Abilitazione Pure Mode (Rolling RAC & Single)

Per attivare la modalità **Pure Unified Auditing** è necessario compilare il binario Oracle linkando la libreria corretta a livello di sistema operativo.

### 3.1 Procedura su Single Instance
```bash
# 1. Spegni il database e il listener
sqlplus / as sysdba <<< "SHUTDOWN IMMEDIATE"
lsnrctl stop

# 2. Compila il motore Oracle abilitando uniaud (esegui come utente oracle)
cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk uniaud_on ioracle

# 3. Riavvia listener e database
lsnrctl start
sqlplus / as sysdba <<< "STARTUP"
```

### 3.2 Procedura in ambiente RAC (Rolling Node-by-Node)
In RAC puoi evitare il downtime totale procedendo un nodo alla volta:

```bash
# Sul Nodo 1:
srvctl stop instance -d RACDB -i RACDB1
# Compila come sopra:
cd $ORACLE_HOME/rdbms/lib
make -f ins_rdbms.mk uniaud_on ioracle
# Riavvia l'istanza:
srvctl start instance -d RACDB -i RACDB1

# Ripeti l'operazione identica sul Nodo 2!
```

---

## 4. Creazione & Gestione di Policy di Audit Personalizzate

Unified Auditing lavora tramite **Audit Policies**. Puoi creare policy per monitorare ruoli, privilegi di sistema, DDL, DML o azioni specifiche, filtrando opzionalmente per contesti utente (es. IP address, programmi client).

### 4.1 Policy 1: Monitorare Accessi Falliti (Sicurezza Base)
```sql
-- Creazione della policy
CREATE AUDIT POLICY pol_failed_logins
  ACTIONS LOGON;

-- Abilitazione della policy (solo per i tentativi falliti)
AUDIT POLICY pol_failed_logins WHENEVER NOT SUCCESSFUL;
```

### 4.2 Policy 2: Monitorare Cambiamenti Strutturali (DDL & Grant)
```sql
CREATE AUDIT POLICY pol_structural_changes
  ACTIONS CREATE TABLE, ALTER TABLE, DROP TABLE,
          CREATE USER, ALTER USER, DROP USER,
          CREATE ROLE, ALTER ROLE, DROP ROLE,
          GRANT, REVOKE;

-- Abilitazione della policy (sia successi che fallimenti)
AUDIT POLICY pol_structural_changes;
```

### 4.3 Policy 3: Audit Condizionale su Tabelle Sensibili (GDPR / PCI-DSS)
Vogliamo monitorare chi esegue query sulla tabella `PAYROLL` dello schema `HR`, ma *solo se l'utente che si connette non è l'application server autorizzato*.

```sql
CREATE AUDIT POLICY pol_sensitive_payroll
  ACTIONS SELECT ON HR.PAYROLL
  WHEN 'SYS_CONTEXT(''USERENV'', ''CLIENT_PROGRAM_NAME'') != ''wildfly.exe'''
  EVALUATE PER STATEMENT;

AUDIT POLICY pol_sensitive_payroll;
```

### 4.4 Verificare le Policy Attive nel Database
```sql
-- Elenco delle policy attive nel database e a chi sono applicate
SELECT policy_name, enabled_option, entity_name, success, failure
FROM   audit_unified_enabled_policies;
```

---

## 5. Lettura & Diagnostica del Log di Audit

Tutti i log confluiscono nella vista di sistema `UNIFIED_AUDIT_TRAIL`.

```sql
-- Query di analisi per ultimi incidenti o accessi sospetti
SELECT event_timestamp,
       dbusername,
       userhost,
       action_name,
       object_schema,
       object_name,
       sql_text
FROM   unified_audit_trail
WHERE  event_timestamp > SYSDATE - 1/24 -- ultime 2 ore
ORDER BY event_timestamp DESC;
```

---

## 6. Gestione Storage & Purge Automatico (SYSAUX Management)

Un grosso rischio prestazionale e operativo in produzione è il riempimento del tablespace `SYSAUX` causato da milioni di righe di audit non gestite. È **obbligatorio** impostare una strategia di pulizia automatica.

### 6.1 Spostare la tabella di Audit su un Tablespace Dedicato
Per evitare che l'audit saturi il tablespace `SYSAUX` (bloccando altre funzioni come AWR), sposta i dati di audit in un tablespace isolato (es. `AUD_DATA`):

```sql
-- 1. Crea un tablespace dedicato (consigliato BIGFILE)
CREATE BIGFILE TABLESPACE AUD_DATA
  DATAFILE '+DATA' SIZE 2G AUTOEXTEND ON NEXT 500M MAXSIZE 100G;

-- 2. Sposta lo storage di Unified Audit
BEGIN
  dbms_audit_mgmt.set_audit_trail_location(
    audit_trail_type            => dbms_audit_mgmt.audit_trail_unified,
    audit_trail_location_value  => 'AUD_DATA'
  );
END;
/

-- Verifica il successo dello spostamento
SELECT parameter_name, parameter_value 
FROM   dba_audit_mgmt_config_params 
WHERE  parameter_name = 'AUDIT LEVEL';
```

### 6.2 Configurazione del Purge Automatico (DBMS_AUDIT_MGMT)
Configura un job interno che elimini i dati di audit più vecchi di 30 giorni:

```sql
-- 1. Inizializza il meccanismo di cleanup di Unified Audit
BEGIN
  dbms_audit_mgmt.init_cleanup(
    audit_trail_type         => dbms_audit_mgmt.audit_trail_unified,
    default_cleanup_interval => 24 -- esegui ogni 24 ore
  );
END;
/

-- 2. Definisci una "Last Archive Timestamp" (soglia temporale per l'eliminazione)
-- Esempio: imposta la soglia a 30 giorni fa
BEGIN
  dbms_audit_mgmt.set_last_archive_timestamp(
    audit_trail_type  => dbms_audit_mgmt.audit_trail_unified,
    last_archive_time => SYSDATE - 30
  );
END;
/

-- 3. Crea il Job di pulizia automatica (DBMS_SCHEDULER integrato)
BEGIN
  dbms_audit_mgmt.create_purge_job(
    audit_trail_type           => dbms_audit_mgmt.audit_trail_unified,
    purge_interval             => 24, -- ore
    use_last_arch_timestamp    => TRUE,
    container                  => dbms_audit_mgmt.container_all
  );
END;
/
```

### 6.3 Aggiornamento Dinamico della Soglia di Archiviazione
Il job di purge automatico elimina i record antecedenti alla data registrata come *Last Archive Timestamp*. Per fare in modo che questa data avanzi automaticamente ogni notte (mantenendo una finestra scorrevole di 30 giorni), crea un piccolo scheduler job:

```sql
BEGIN
  dbms_scheduler.create_job (
    job_name        => 'JOB_UPDATE_AUDIT_ARCHIVE_TS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                          dbms_audit_mgmt.set_last_archive_timestamp(
                            audit_trail_type  => dbms_audit_mgmt.audit_trail_unified,
                            last_archive_time => SYSDATE - 30
                          );
                        END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=10', -- esegui ogni notte alle 00:10
    enabled         => TRUE,
    comments        => 'Aggiorna la soglia scorrevole di 30 giorni per il purge di Unified Audit'
  );
END;
/
```
