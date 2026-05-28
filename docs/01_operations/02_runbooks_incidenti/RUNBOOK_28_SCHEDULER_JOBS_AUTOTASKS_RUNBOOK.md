# 28 - Scheduler Jobs e AutoTasks

## Casi piu frequenti

- Job applicativo fallito.
- Job bloccato in `RUNNING`.
- Auto stats non girano o causano regressione.
- Maintenance window chiusa o disabilitata.
- Job esterno fallisce per credenziali OS.
- Troppi job saturano CPU/I/O in finestra batch.

## Triage rapido

```sql
SELECT owner, job_name, enabled, state, job_type, job_action,
       last_start_date, next_run_date, failure_count
FROM dba_scheduler_jobs
ORDER BY owner, job_name;

SELECT owner, job_name, status, error#, actual_start_date,
       run_duration, additional_info
FROM dba_scheduler_job_run_details
WHERE actual_start_date > SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY actual_start_date DESC;

SELECT owner, job_name, session_id, running_instance,
       elapsed_time, cpu_used
FROM dba_scheduler_running_jobs
ORDER BY elapsed_time DESC;
```

## Scenario A - Job fallito

Dettaglio errore:

```sql
SELECT log_id, owner, job_name, status, error#, additional_info
FROM dba_scheduler_job_run_details
WHERE owner = '<OWNER>'
  AND job_name = '<JOB_NAME>'
ORDER BY log_id DESC
FETCH FIRST 10 ROWS ONLY;
```

Rilancio controllato:

```sql
BEGIN
  DBMS_SCHEDULER.RUN_JOB(
    job_name => '<OWNER>.<JOB_NAME>',
    use_current_session => FALSE
  );
END;
/
```

## Scenario B - Job bloccato

```sql
SELECT r.owner, r.job_name, r.session_id, r.running_instance,
       s.sid, s.serial#, s.sql_id, s.event, s.blocking_session
FROM dba_scheduler_running_jobs r
JOIN gv$session s
  ON s.inst_id = r.running_instance
 AND s.sid = r.session_id;
```

Stop graceful:

```sql
BEGIN
  DBMS_SCHEDULER.STOP_JOB(
    job_name => '<OWNER>.<JOB_NAME>',
    force => FALSE
  );
END;
/
```

Stop forzato solo se approvato:

```sql
BEGIN
  DBMS_SCHEDULER.STOP_JOB(
    job_name => '<OWNER>.<JOB_NAME>',
    force => TRUE
  );
END;
/
```

## Scenario C - Disabilitare temporaneamente un job

```sql
BEGIN
  DBMS_SCHEDULER.DISABLE('<OWNER>.<JOB_NAME>');
END;
/
```

Riabilitare:

```sql
BEGIN
  DBMS_SCHEDULER.ENABLE('<OWNER>.<JOB_NAME>');
END;
/
```

## Scenario D - Maintenance windows e AutoTask

```sql
SELECT window_name, enabled, active, repeat_interval, duration
FROM dba_scheduler_windows
ORDER BY window_name;

SELECT client_name, status
FROM dba_autotask_client
ORDER BY client_name;

SELECT client_name, window_name, jobs_created, jobs_started, jobs_completed
FROM dba_autotask_client_history
ORDER BY window_start_time DESC;
```

Disabilitare auto stats temporaneamente solo con change:

```sql
BEGIN
  DBMS_AUTO_TASK_ADMIN.DISABLE(
    client_name => 'auto optimizer stats collection',
    operation   => NULL,
    window_name => NULL
  );
END;
/
```

Riabilitare:

```sql
BEGIN
  DBMS_AUTO_TASK_ADMIN.ENABLE(
    client_name => 'auto optimizer stats collection',
    operation   => NULL,
    window_name => NULL
  );
END;
/
```

## Scenario E - Job esterno OS

Controlla credential:

```sql
SELECT credential_name, username, enabled
FROM dba_scheduler_credentials
ORDER BY credential_name;
```

Log:

```sql
SELECT owner, job_name, status, error#, additional_info
FROM dba_scheduler_job_run_details
WHERE job_name = '<JOB_NAME>'
ORDER BY actual_start_date DESC;
```

Verifica OS:

```bash
ls -l <script_path>
id oracle
```

## Cosa non fare

- Non killare la sessione del job senza capire transazione e impatto.
- Non disabilitare AutoTask globalmente senza change.
- Non rilanciare job batch se il run precedente e ancora attivo.
- Non cambiare finestre scheduler senza owner applicativo.

## Collegamenti

- [Guida Scheduler Jobs](../../02_core_dba/01_administration_and_security/GUIDA_SCHEDULER_JOBS.md)
- [Gestione statistiche optimizer](./RUNBOOK_18_GESTIONE_STATISTICHE_OPTIMIZER.md)
- [Lock e sessioni bloccate](./RUNBOOK_04_LOCK_SESSIONI_BLOCCATE.md)

## Evidence ticket

```text
Job:
Owner:
Ultimo status:
Errore:
Sessione/SQL_ID:
Azione eseguita:
Esito rilancio/stop:
Owner applicativo avvisato:
```
