# 35 - Capacity Forecast Enterprise

<!-- READY_SCRIPTS_START -->
## Script e runbook collegati

- [12 Capacity Planning e Limiti](./RUNBOOK_12_CAPACITY_PLANNING_LIMITI.md)
- [05_asm_storage.sql](../03_scripts_pronti/05_asm_storage.sql)
- [03_fra_archivelog.sql](../03_scripts_pronti/03_fra_archivelog.sql)
- [monitoring_scripts/general/data-growth-db.sql](../04_libreria_script_completa/monitoring_scripts/general/data-growth-db.sql)
- [monitoring_scripts/general/data-growth-tbs.sql](../04_libreria_script_completa/monitoring_scripts/general/data-growth-tbs.sql)
- [monitoring_scripts/general/data-growth-db-predict-regr.sql](../04_libreria_script_completa/monitoring_scripts/general/data-growth-db-predict-regr.sql)
<!-- READY_SCRIPTS_END -->

## Obiettivo

Trasformare controlli spazio puntuali in previsione: quando finira lo spazio, quale componente cresce, quale change aprire prima che diventi incidente.

## Ambiti da prevedere

- Datafile/tablespace.
- TEMP.
- UNDO.
- FRA e archivelog.
- ASM diskgroup.
- Audit/log/diag filesystem.
- Backup retention.
- Crescita AWR/SYSAUX.
- Numero sessioni/processi.

## Snapshot corrente

Tablespace:

```sql
select tablespace_name,
       used_space * block_size / 1024 / 1024 used_mb,
       tablespace_size * block_size / 1024 / 1024 max_mb,
       used_percent
from dba_tablespace_usage_metrics
order by used_percent desc;
```

Datafile:

```sql
select tablespace_name, file_name,
       bytes/1024/1024 mb,
       maxbytes/1024/1024 max_mb,
       autoextensible
from dba_data_files
order by tablespace_name, file_name;
```

ASM:

```sql
select name, type, total_mb, free_mb, required_mirror_free_mb,
       usable_file_mb
from v$asm_diskgroup
order by name;
```

FRA:

```sql
select name,
       space_limit/1024/1024 limit_mb,
       space_used/1024/1024 used_mb,
       space_reclaimable/1024/1024 reclaimable_mb,
       number_of_files
from v$recovery_file_dest;
```

## Crescita storica AWR

Database:

```sql
set lines 220 pages 200
col begin_time format a20

select to_char(s.begin_interval_time, 'YYYY-MM-DD') day,
       round(max(tablespace_size * ts.block_size)/1024/1024/1024, 2) size_gb
from dba_hist_tbspc_space_usage u
join dba_hist_snapshot s
  on s.snap_id = u.snap_id
 and s.dbid = u.dbid
 and s.instance_number = u.instance_number
join v$tablespace ts
  on ts.ts# = u.tablespace_id
group by to_char(s.begin_interval_time, 'YYYY-MM-DD')
order by day;
```

Per tablespace:

```sql
select to_char(s.begin_interval_time, 'YYYY-MM-DD') day,
       ts.name tablespace_name,
       round(max(u.tablespace_usedsize * ts.block_size)/1024/1024/1024, 2) used_gb
from dba_hist_tbspc_space_usage u
join dba_hist_snapshot s
  on s.snap_id = u.snap_id
 and s.dbid = u.dbid
 and s.instance_number = u.instance_number
join v$tablespace ts
  on ts.ts# = u.tablespace_id
group by to_char(s.begin_interval_time, 'YYYY-MM-DD'), ts.name
order by day, tablespace_name;
```

## Forecast semplice con regressione

Esempio per tablespace:

```sql
with hist as (
  select trunc(s.begin_interval_time) day,
         ts.name tablespace_name,
         max(u.tablespace_usedsize * ts.block_size)/1024/1024/1024 used_gb
  from dba_hist_tbspc_space_usage u
  join dba_hist_snapshot s
    on s.snap_id = u.snap_id
   and s.dbid = u.dbid
   and s.instance_number = u.instance_number
  join v$tablespace ts
    on ts.ts# = u.tablespace_id
  where s.begin_interval_time > sysdate - 60
  group by trunc(s.begin_interval_time), ts.name
),
regr as (
  select tablespace_name,
         regr_slope(used_gb, day - date '1970-01-01') gb_per_day,
         regr_intercept(used_gb, day - date '1970-01-01') intercept_gb,
         max(used_gb) current_used_gb
  from hist
  group by tablespace_name
),
cap as (
  select tablespace_name,
         sum(case when autoextensible='YES' then maxbytes else bytes end)/1024/1024/1024 max_gb
  from dba_data_files
  group by tablespace_name
)
select r.tablespace_name,
       round(r.current_used_gb,2) current_used_gb,
       round(c.max_gb,2) max_gb,
       round(r.gb_per_day,3) gb_per_day,
       case
         when r.gb_per_day <= 0 then null
         else round((c.max_gb - r.current_used_gb) / r.gb_per_day)
       end days_to_full
from regr r
join cap c on c.tablespace_name = r.tablespace_name
order by days_to_full nulls last;
```

## FRA forecast

Misura produzione archive giornaliera:

```sql
select trunc(first_time) day,
       round(sum(blocks * block_size)/1024/1024/1024, 2) arch_gb
from v$archived_log
where first_time > sysdate - 30
group by trunc(first_time)
order by day;
```

Stima giorni coperti:

```sql
select round(space_limit/1024/1024/1024,2) fra_limit_gb,
       round(space_used/1024/1024/1024,2) fra_used_gb,
       round(space_reclaimable/1024/1024/1024,2) reclaimable_gb
from v$recovery_file_dest;
```

Se Data Guard o GoldenGate sono fermi, la retention archive reale cambia: aprire runbook DG/GG prima di aumentare FRA.

## SYSAUX e AWR

```sql
select occupant_name, space_usage_kbytes/1024 mb
from v$sysaux_occupants
order by space_usage_kbytes desc;

select retention, snap_interval
from dba_hist_wr_control;
```

Azioni possibili:

- ridurre retention AWR solo con approvazione performance/compliance;
- purgare componenti specifici con procedure Oracle;
- aumentare SYSAUX se crescita legittima.

## Sessioni e processi

```sql
select resource_name, current_utilization, max_utilization, limit_value
from v$resource_limit
where resource_name in ('processes','sessions','transactions')
order by resource_name;
```

Se `max_utilization` e vicino a `limit_value`, valutare:

- connection pool applicativo;
- processi batch;
- `processes` e `sessions` in SPFILE con restart;
- memory footprint per processo.

## Output mensile consigliato

```text
DB:
Periodo analizzato:
Top 5 tablespace per crescita:
Tablespace con days_to_full < 60:
ASM diskgroup con usable_file_mb critico:
FRA media GB/giorno:
TEMP picco:
UNDO picco:
SYSAUX crescita:
Processes max utilization:
Change proposti:
Rischio se non si interviene:
```

## Soglie pratiche

| Area | Warning | Critical |
|---|---:|---:|
| Tablespace autoextend | 80% max | 90% max |
| Tablespace no autoextend | 75% | 85% |
| ASM usable_file_mb | < 30 giorni | < 14 giorni |
| FRA | > 75% | > 85% |
| TEMP | trend picco > 70% | ORA-01652 o > 90% |
| Processes | > 75% max | > 90% max |

Le soglie vanno adattate a SLA, tempi procurement storage e change window.
