# Guida Oracle Scheduler e Manutenzione Automatica

> Oracle Scheduler (`DBMS_SCHEDULER`) è il motore di automazione integrato nel database. Ogni DBA deve saperlo configurare, monitorare e risolverne i problemi. Questa guida copre teoria, configurazione, monitoring e troubleshooting.

---

## 1. Concetti Fondamentali

```
╔═══════════════════════════════════════════════════════════════════╗
║                  ARCHITETTURA SCHEDULER                           ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║   JOB = Cosa fare + Quando farlo + Con quale identità             ║
║   ┌──────────────────────────────────────────────────────┐       ║
║   │  PROGRAM      = "cosa fare" (PL/SQL, script, exec)  │       ║
║   │  SCHEDULE     = "quando farlo" (cron-like, event)    │       ║
║   │  CREDENTIAL   = "con quale utente OS" (per external) │       ║
║   │  JOB CLASS    = "con quale priorità/resource group"  │       ║
║   └──────────────────────────────────────────────────────┘       ║
║                                                                   ║
║   WINDOW = Finestra temporale con Resource Plan associato         ║
║   ┌──────────────────────────────────────────────────────┐       ║
║   │  MAINTENANCE_WINDOW_GROUP: lunedì-venerdì 22:00-02:00│       ║
║   │  WEEKEND_WINDOW: sabato-domenica 00:00-24:00         │       ║
║   │  → Oracle auto-tasks girano SOLO nelle finestre      │       ║
║   └──────────────────────────────────────────────────────┘       ║
║                                                                   ║
║   CHAIN = Sequenza condizionale di step (workflow)                ║
║   ┌──────────────────────────────────────────────────────┐       ║
║   │  Step 1 (export) → Step 2 (compress) → Step 3 (scp) │       ║
║   │  Se Step 1 fallisce → Step 4 (notify)                │       ║
║   └──────────────────────────────────────────────────────┘       ║
╚═══════════════════════════════════════════════════════════════════╝
```

### Differenza: DBMS_JOB vs DBMS_SCHEDULER

| Caratteristica | DBMS_JOB (legacy) | DBMS_SCHEDULER (19c) |
|---|---|---|
| Tipi di job | Solo PL/SQL | PL/SQL, OS script, catene, eventi |
| Scheduling | Intervallo semplice | Calendario complesso, cron-like |
| Logging | Minimo | Completo (run details, log history) |
| RAC awareness | No | Sì (instance_id, service) |
| Resource Management | No | Sì (Job Class + Resource Plan) |
| Monitoring EM | Limitato | Completo |

> **Best Practice Oracle**: Non usare mai `DBMS_JOB` in nuovi sviluppi. È deprecato. Usa sempre `DBMS_SCHEDULER`.

---

## 2. Creare Job: I 3 Metodi

### 2.1 Job Semplice (inline — tutto in una chiamata)

```sql
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'HR.DAILY_STATS_GATHER',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(''HR''); END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0',
        -- ↑ ogni giorno alle 02:00
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Raccolta statistiche schema HR'
    );
END;
/
```

### 2.2 Job con Program + Schedule Separati (riusabili)

```sql
-- 1. Crea il PROGRAM (cosa fare)
BEGIN
    DBMS_SCHEDULER.CREATE_PROGRAM(
        program_name   => 'PROG_GATHER_STATS',
        program_type   => 'PLSQL_BLOCK',
        program_action => 'BEGIN DBMS_STATS.GATHER_SCHEMA_STATS(''HR''); END;',
        enabled        => TRUE,
        comments       => 'Raccolta statistiche — riusabile'
    );
END;
/

-- 2. Crea lo SCHEDULE (quando farlo)
BEGIN
    DBMS_SCHEDULER.CREATE_SCHEDULE(
        schedule_name   => 'SCHED_NIGHTLY_2AM',
        repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0',
        comments        => 'Ogni notte alle 02:00'
    );
END;
/

-- 3. Crea il JOB combinando i due
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name      => 'HR.STATS_VIA_PROGRAM',
        program_name  => 'PROG_GATHER_STATS',
        schedule_name => 'SCHED_NIGHTLY_2AM',
        enabled       => TRUE,
        auto_drop     => FALSE
    );
END;
/
```

### 2.3 Job Esterno (esegue script OS)

```sql
-- 1. Crea credenziale (chi esegue lo script OS)
BEGIN
    DBMS_SCHEDULER.CREATE_CREDENTIAL(
        credential_name => 'OS_ORACLE_CRED',
        username        => 'oracle',
        password        => '<password>'
    );
END;
/

-- 2. Crea il job esterno
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'SYS.RMAN_BACKUP_JOB',
        job_type        => 'EXECUTABLE',
        job_action      => '/home/oracle/scripts/rman_backup.sh',
        credential_name => 'OS_ORACLE_CRED',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=23; BYMINUTE=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Backup RMAN notturno via script OS'
    );
END;
/
```

---

## 3. Sintassi Calendario (repeat_interval)

```sql
-- Ogni giorno alle 02:00
'FREQ=DAILY; BYHOUR=2; BYMINUTE=0'

-- Ogni lunedì e giovedì alle 03:30
'FREQ=WEEKLY; BYDAY=MON,THU; BYHOUR=3; BYMINUTE=30'

-- Il primo giorno di ogni mese alle 01:00
'FREQ=MONTHLY; BYMONTHDAY=1; BYHOUR=1'

-- L'ultimo venerdì di ogni mese
'FREQ=MONTHLY; BYDAY=-1FRI; BYHOUR=22'

-- Ogni 30 minuti (per monitoring)
'FREQ=MINUTELY; INTERVAL=30'

-- Ogni 4 ore durante il weekend
'FREQ=HOURLY; INTERVAL=4; BYDAY=SAT,SUN'

-- Verifica quando cadrà la prossima esecuzione:
SELECT DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING(
    'FREQ=DAILY; BYHOUR=2; BYMINUTE=0',
    SYSTIMESTAMP, NULL
) AS next_run FROM dual;
```

---

## 4. Chains — Workflow Multi-Step

```sql
-- Scenario: Export → Compress → Transfer → Notify

-- 1. Crea la chain
BEGIN
    DBMS_SCHEDULER.CREATE_CHAIN(
        chain_name => 'CHAIN_EXPORT_SHIP',
        comments   => 'Export, comprime, trasferisce e notifica'
    );
END;
/

-- 2. Definisci gli step
BEGIN
    -- Step 1: Export
    DBMS_SCHEDULER.DEFINE_CHAIN_STEP(
        chain_name => 'CHAIN_EXPORT_SHIP',
        step_name  => 'STEP_EXPORT',
        program_name => 'PROG_DATAPUMP_EXPORT'
    );
    -- Step 2: Compress
    DBMS_SCHEDULER.DEFINE_CHAIN_STEP(
        chain_name => 'CHAIN_EXPORT_SHIP',
        step_name  => 'STEP_COMPRESS',
        program_name => 'PROG_GZIP_DUMP'
    );
    -- Step 3: Transfer
    DBMS_SCHEDULER.DEFINE_CHAIN_STEP(
        chain_name => 'CHAIN_EXPORT_SHIP',
        step_name  => 'STEP_SCP',
        program_name => 'PROG_SCP_TO_TARGET'
    );
    -- Step 4: Notify (solo su errore)
    DBMS_SCHEDULER.DEFINE_CHAIN_STEP(
        chain_name => 'CHAIN_EXPORT_SHIP',
        step_name  => 'STEP_NOTIFY_FAIL',
        program_name => 'PROG_SEND_ALERT'
    );
END;
/

-- 3. Definisci le regole (condizioni)
BEGIN
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name => 'CHAIN_EXPORT_SHIP',
        condition  => 'TRUE',            -- inizia subito
        action     => 'START STEP_EXPORT'
    );
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name => 'CHAIN_EXPORT_SHIP',
        condition  => 'STEP_EXPORT SUCCEEDED',
        action     => 'START STEP_COMPRESS'
    );
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name => 'CHAIN_EXPORT_SHIP',
        condition  => 'STEP_COMPRESS SUCCEEDED',
        action     => 'START STEP_SCP'
    );
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name => 'CHAIN_EXPORT_SHIP',
        condition  => 'STEP_EXPORT FAILED OR STEP_COMPRESS FAILED',
        action     => 'START STEP_NOTIFY_FAIL'
    );
    DBMS_SCHEDULER.DEFINE_CHAIN_RULE(
        chain_name => 'CHAIN_EXPORT_SHIP',
        condition  => 'STEP_SCP SUCCEEDED OR STEP_NOTIFY_FAIL COMPLETED',
        action     => 'END'
    );
END;
/

EXEC DBMS_SCHEDULER.ENABLE('CHAIN_EXPORT_SHIP');
```

---

## 5. Manutenzione Automatica Oracle (Auto-Tasks)

Oracle ha 3 task di manutenzione automatica che girano nelle **Maintenance Windows**:

| Auto-Task | Cosa fa | Impatto |
|---|---|---|
| `AUTO_STATS_GATHER` | Raccoglie statistiche stale | **Il più importante** — statistiche fresche = piani SQL buoni |
| `AUTO_SPACE_ADVISOR` | Analizza spazio e segment advisor | Medio — suggerimenti di compressione/shrink |
| `SQL_TUNE_ADVISOR` | Analizza top SQL e suggerisce profili | Medio — può proporre SQL Profiles automatici |

### 5.1 Verificare lo Stato

```sql
-- Auto-tasks attivi
SELECT client_name, status, consumer_group, window_group
FROM dba_autotask_client;

-- Cronologia esecuzioni
SELECT client_name, window_name, 
       jobs_created, jobs_started, jobs_completed
FROM dba_autotask_client_history
WHERE window_name LIKE '%TODAY%'
ORDER BY window_name DESC;

-- Finestre di manutenzione
SELECT window_name, enabled, active,
       TO_CHAR(next_start_date, 'DY HH24:MI') AS prossima,
       EXTRACT(HOUR FROM duration) || 'h' AS durata
FROM dba_scheduler_windows
WHERE window_name LIKE '%WINDOW%'
ORDER BY next_start_date;
```

### 5.2 Modificare le Finestre di Manutenzione

```sql
-- Estendi la finestra del lunedì a 6 ore
BEGIN
    DBMS_SCHEDULER.SET_ATTRIBUTE(
        name      => 'SYS.MONDAY_WINDOW',
        attribute => 'DURATION',
        value     => NUMTODSINTERVAL(6, 'HOUR')
    );
END;
/

-- Cambia l'inizio della finestra (dal default 22:00 → 01:00)
BEGIN
    DBMS_SCHEDULER.SET_ATTRIBUTE(
        name      => 'SYS.MONDAY_WINDOW',
        attribute => 'REPEAT_INTERVAL',
        value     => 'FREQ=WEEKLY; BYDAY=MON; BYHOUR=1; BYMINUTE=0'
    );
END;
/

-- Disabilita un auto-task (es. SQL Tuning Advisor se non lo vuoi)
BEGIN
    DBMS_AUTO_TASK_ADMIN.DISABLE(
        client_name => 'sql tuning advisor',
        operation   => NULL,
        window_name => NULL
    );
END;
/
```

---

## 6. Monitoring — Query Essenziali

### 6.1 Job in Esecuzione Adesso

```sql
SELECT job_name, session_id, running_instance, 
       elapsed_time, cpu_used
FROM dba_scheduler_running_jobs;
```

### 6.2 Ultimi Job Falliti

```sql
SELECT job_name, status, actual_start_date, 
       run_duration, error#, additional_info
FROM dba_scheduler_job_run_details
WHERE status = 'FAILED'
ORDER BY actual_start_date DESC
FETCH FIRST 20 ROWS ONLY;
```

### 6.3 Tutti i Job con Ultimo Esito

```sql
SELECT j.job_name, j.enabled, j.state, 
       j.last_start_date, j.last_run_duration,
       j.next_run_date, j.failure_count
FROM dba_scheduler_jobs j
WHERE j.owner NOT IN ('SYS','ORACLE_OCM','EXFSYS')
ORDER BY j.last_start_date DESC NULLS LAST;
```

### 6.4 Job Bloccati (in esecuzione da troppo)

```sql
SELECT job_name, elapsed_time, running_instance
FROM dba_scheduler_running_jobs
WHERE elapsed_time > NUMTODSINTERVAL(2, 'HOUR');
-- ↑ Job che girano da più di 2 ore
```

### 6.5 Log History (pulizia)

```sql
-- Quanti record di log ci sono?
SELECT COUNT(*) FROM dba_scheduler_job_log;

-- Pulisci log più vecchi di 30 giorni
BEGIN
    DBMS_SCHEDULER.PURGE_LOG(
        log_history => 30
    );
END;
/
```

---

## 7. Gestione Operativa

### Start/Stop/Drop

```sql
-- Esegui un job immediatamente (fuori schedule)
EXEC DBMS_SCHEDULER.RUN_JOB('HR.DAILY_STATS_GATHER', use_current_session => FALSE);

-- Ferma un job in esecuzione
EXEC DBMS_SCHEDULER.STOP_JOB('HR.DAILY_STATS_GATHER', force => TRUE);

-- Disabilita (NON lo cancella, solo lo mette in pausa)
EXEC DBMS_SCHEDULER.DISABLE('HR.DAILY_STATS_GATHER');

-- Riabilita
EXEC DBMS_SCHEDULER.ENABLE('HR.DAILY_STATS_GATHER');

-- Drop definitivo
EXEC DBMS_SCHEDULER.DROP_JOB('HR.DAILY_STATS_GATHER', force => TRUE);
```

### Scheduler in RAC

```sql
-- Forza il job su un'istanza specifica
BEGIN
    DBMS_SCHEDULER.SET_ATTRIBUTE(
        name      => 'HR.DAILY_STATS_GATHER',
        attribute => 'INSTANCE_ID',
        value     => 1    -- solo su istanza 1
    );
END;
/

-- Oppure usa un service (best practice RAC)
BEGIN
    DBMS_SCHEDULER.SET_ATTRIBUTE(
        name      => 'HR.DAILY_STATS_GATHER',
        attribute => 'DATABASE_ROLE',
        value     => 'PRIMARY'  -- gira solo se il DB è primary
    );
END;
/
```

---

## 8. Troubleshooting

### Job Fallisce con Errore

```sql
-- 1. Trova il job e il suo errore
SELECT job_name, status, error#, additional_info
FROM dba_scheduler_job_run_details
WHERE job_name = 'HR.DAILY_STATS_GATHER'
ORDER BY actual_start_date DESC
FETCH FIRST 5 ROWS ONLY;

-- 2. Controlla se il job è abilitato
SELECT job_name, enabled, state, failure_count
FROM dba_scheduler_jobs
WHERE job_name = 'HR.DAILY_STATS_GATHER';

-- 3. Se failure_count è alto, resetta
EXEC DBMS_SCHEDULER.DISABLE('HR.DAILY_STATS_GATHER');
EXEC DBMS_SCHEDULER.ENABLE('HR.DAILY_STATS_GATHER');
```

### Job Non Parte (state = SCHEDULED ma non gira)

Cause comuni:
- `enabled = FALSE` → `EXEC DBMS_SCHEDULER.ENABLE(...)`
- Schedule errato → verifica `repeat_interval` e `next_run_date`
- Job Class con Resource Plan limitante → `SELECT * FROM dba_scheduler_job_classes`
- Finestra di manutenzione chiusa → `SELECT * FROM dba_scheduler_windows WHERE active = 'TRUE'`
- In RAC: il job è assegnato a un'istanza che non è attiva

### Auto-Task Non Gira

```sql
-- Verifica se la finestra è aperta
SELECT window_name, active FROM dba_scheduler_windows;

-- Verifica se l'auto-task è disabilitato
SELECT client_name, status FROM dba_autotask_client;

-- Forza esecuzione manuale delle statistiche
EXEC DBMS_STATS.GATHER_DATABASE_STATS(OPTIONS => 'GATHER STALE');
```

---

## 9. Fonti Oracle Ufficiali

- **Scheduler Admin Guide**: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/administering-oracle-scheduler.html
- **DBMS_SCHEDULER Reference**: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_SCHEDULER.html
- **Auto-Tasks**: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-automated-database-maintenance-tasks.html
- **Calendar Syntax**: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/scheduling-jobs-with-oracle-scheduler.html#GUID-9D3C2BD5-6B6F-4B24-8E6E-9B2E4B50D7D3
