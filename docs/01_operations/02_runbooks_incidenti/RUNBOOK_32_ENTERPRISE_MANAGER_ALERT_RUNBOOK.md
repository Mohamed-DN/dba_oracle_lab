# 32 - Enterprise Manager Alert Handling Runbook

<!-- READY_SCRIPTS_START -->
## Guide collegate

- [Enterprise Manager](../../02_core_dba/06_monitoring_systems/GUIDA_FASE6_ENTERPRISE_MANAGER.md)
- [Monitoring Open Source](../../02_core_dba/06_monitoring_systems/GUIDA_MONITORING_OPENSOURCE.md)
- [Checkmk Oracle Enterprise](../../02_core_dba/06_monitoring_systems/GUIDA_SETUP_CHECKMK_ORACLE_ENTERPRISE.md)
- [Morning Health Check](./RUNBOOK_01_MORNING_HEALTH_CHECK.md)
<!-- READY_SCRIPTS_END -->

## Obiettivo

Usare l'alert OEM/EM come ingresso operativo, non come diagnosi finale. Ogni alert deve essere trasformato in evidenza tecnica, runbook specifico, fix e validazione.

## Classificazione alert

| Alert | Prima destinazione |
|---|---|
| Tablespace, TEMP, FRA | [06 Tablespace Pieno](./RUNBOOK_06_TABLESPACE_PIENO.md), [16 Resize TEMP](./RUNBOOK_16_RESIZE_TEMP.md), [17 Purge Log](./RUNBOOK_17_PURGE_LOG_ORACLE.md) |
| Database down, instance down | [01 Morning Health Check](./RUNBOOK_01_MORNING_HEALTH_CHECK.md), [10 Start/Stop RAC](./RUNBOOK_10_START_STOP_RAC.md) |
| Data Guard lag/gap | [03 Check Data Guard](./RUNBOOK_03_CHECK_DATAGUARD.md), [22 RMAN + DG Recovery](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) |
| Host CPU/memory/filesystem | [07 CPU Alta](./RUNBOOK_07_CPU_ALTA.md), [25 ASM Storage](./RUNBOOK_25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md) |
| Listener/service down | [26 Listener/SCAN/Services](./RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md) |
| Backup failed | [02 Verifica Backup](./RUNBOOK_02_VERIFICA_BACKUP.md), [19 Diagnosi RMAN](./RUNBOOK_19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) |
| Job failed | [28 Scheduler Jobs](./RUNBOOK_28_SCHEDULER_JOBS_AUTOTASKS_RUNBOOK.md) |
| Wallet closed | [27 TDE Wallet](./RUNBOOK_27_TDE_WALLET_KEYSTORE_RUNBOOK.md) |

## Precheck OEM

Da console:

1. Apri target e alert.
2. Verifica severity, first raised, last checked, metric, threshold.
3. Controlla se e alert singolo o correlato a cluster/host/storage.
4. Verifica blackout attivi o change pianificata.
5. Esporta screenshot o dettaglio alert nel ticket.

Da host agent:

```bash
emctl status agent
emctl pingOMS
emctl upload agent
emctl status agent scheduler
```

Se agent non comunica, non assumere che il database sia down: verifica localmente con SQL/srvctl.

## Convertire alert in evidenza SQL

Database:

```sql
set lines 220 pages 200
select name, open_mode, database_role from v$database;
select instance_name, status, host_name, startup_time from gv$instance;
select systimestamp from dual;
```

Storage:

```sql
select tablespace_name, used_percent
from dba_tablespace_usage_metrics
order by used_percent desc;

select name, space_limit/1024/1024 mb_limit, space_used/1024/1024 mb_used
from v$recovery_file_dest;
```

Performance:

```sql
select inst_id, event, count(*)
from gv$session
where status='ACTIVE'
group by inst_id, event
order by count(*) desc;
```

Data Guard:

```sql
select name, value, unit, time_computed
from v$dataguard_stats;
```

## Alert falsi positivi o metriche stantie

Controlli:

```bash
emctl status agent
emctl upload agent
emctl clearstate agent
```

`clearstate` va usato con cautela: puo rigenerare upload massivo e non risolve problemi reali del target.

Verificare ora host:

```bash
date
timedatectl status
```

Se l'alert e stantio:

1. allega evidence SQL/OS che mostra stato sano;
2. forza upload agent;
3. annota in ticket come monitoring issue;
4. non chiudere se l'alert ritorna senza root cause.

## Blackout per change

Prima di patching/restart:

```bash
emctl status agent
```

Da console OEM:

- crea blackout con nome change/ticket;
- includi target DB, listener, ASM, host, cluster;
- durata coerente con change window;
- fine blackout manuale solo dopo validazione.

Nel ticket:

```text
Blackout name:
Target inclusi:
Start/End:
Change:
Owner:
```

## Escalation

Escala subito se:

- alert su primary e standby insieme;
- backup fallito e finestra successiva non disponibile;
- Data Guard apply/transport lag fuori RTO;
- ASM/FRA sopra soglia critica;
- wallet chiuso e database/app non possono leggere dati cifrati;
- agent down nasconde target di produzione.

## Chiusura alert

Non chiudere su "alert cleared" senza validazione tecnica.

Checklist:

- alert cleared in OEM;
- query SQL/OS coerenti;
- runbook specifico completato;
- evidenza before/after nel ticket;
- causa e prevenzione documentate;
- se soglia errata, aprire tuning soglia separato.

## Template ticket

```text
Alert OEM:
Target:
Severity:
First raised:
Metric/threshold:
Runbook usato:
Evidenze prima:
Fix:
Evidenze dopo:
OEM cleared:
Prevenzione:
```
