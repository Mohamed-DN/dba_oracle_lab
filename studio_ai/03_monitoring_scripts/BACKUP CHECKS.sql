-- NB: Queries are only applicable for target databases from 10g onwards
-- How to Clean up The information in EM Backup Report (Doc ID 430601.1)

alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';
set lines 222 pages 4444
col DAY for a15
col status for a15
col TIME_TAKEN for a13
col INPUT_BYTES for a13
col "INPUT B/S" for a13
col OUTPUT_BYTES for a13
col "OUTPUT B/S" for a13

-- CHECK BACKUP INCREMENTALI DI UN DB SPECIFICO

SELECT b.session_key, input_type, status, to_char(start_time,'DAY') as DAY, start_time, end_time, time_taken_display TIME_TAKEN,
b.input_bytes_display INPUT_BYTES, b.input_bytes_per_sec_display "INPUT B/S",
b.output_bytes_display OUTPUT_BYTES, b.output_bytes_per_sec_display "OUTPUT B/S"
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 15)
AND b.input_type='DB INCR'
AND b.db_name='&db_name'
ORDER BY db_name, start_time;

-- CHECK BACKUP DA NUOVE VISTE

SELECT b.session_key, input_type, status, to_char(start_time,'DAY') as DAY, start_time, end_time, time_taken_display TIME_TAKEN,
b.input_bytes_display INPUT_BYTES, b.input_bytes_per_sec_display "INPUT B/S",
b.output_bytes_display OUTPUT_BYTES, b.output_bytes_per_sec_display "OUTPUT B/S"
FROM dba_op.rmanway4_backup_job_details b
WHERE b.input_type='DB INCR' AND b.db_name='&db_name'
AND b.start_time > to_date('01/01/2023 00:00:00','dd/mm/yyyy hh24:mi:ss')
AND b.end_time < to_date('31/01/2023 00:00:00','dd/mm/yyyy hh24:mi:ss')
ORDER BY db_name, start_time;

-- OLDEST BACKUP INFO

SELECT b.db_name, min(start_time) FROM rman.rc_rman_backup_job_details b WHERE b.input_type='DB INCR' GROUP BY b.db_name ORDER BY 1;
SELECT b.db_name, min(start_time) FROM rman19.rc_rman_backup_job_details b WHERE b.input_type='DB INCR' GROUP BY b.db_name ORDER BY 1;
SELECT b.db_name, min(start_time) FROM rmanway4.rc_rman_backup_job_details b WHERE b.input_type='DB INCR' GROUP BY b.db_name ORDER BY 1;

-- DB_NAME

select name from rman.rc_database order by 1;
select name from rman19.rc_database order by 1;
select name from rmanway4.rc_database order by 1;

-- CHECK PRIMARY SITES and STANDBY

select DB_UNIQUE_NAME,DATABASE_ROLE,SITE_KEY,DB_KEY from rman19.rc_site order by 1;

-- BACKUP SIZE

select name, db_unique_name, trunc(sum(bytes)/1024/1024/1024) as SIZE_GB
from rman19.rc_backup_piece bp, rman19.rc_database rd , rman19.rc_site st
where 1=1
--and rd.dbid = 2522464018
and rd.dbid = bp.db_id
and bp.site_key =  st.site_key
--and rd.dbid = st.db_key
and status = 'A'
group by name,db_unique_name
order by 1;

-- CHECK BACKUP IN ESECUZIONE

SELECT b.db_name, input_type, status, to_char(start_time,'DAY') as DAY, start_time, end_time, time_taken_display TIME_TAKEN,
b.input_bytes_display INPUT_BYTES, b.input_bytes_per_sec_display "INPUT B/S",
b.output_bytes_display OUTPUT_BYTES, b.output_bytes_per_sec_display "OUTPUT B/S"
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key and status='RUNNING'
ORDER BY start_time;

-- ACTIVE BACKUP SESSIONS

set lines 222 pages 4444
col inst_id for 9
col sid for 99999
col serial# for 999999
col username for a22
col program for a35
col machine for a35
col event for a50
select inst_id, sid, serial#, username, program, machine, sql_id, last_call_et, event, seconds_in_wait "SECS"
from gv$session where program like 'rman%' order by username,sql_id,inst_id,sid;

-- CHECK BACKUP LEGGENDO DA CONTROLFILE

SELECT b.session_key, input_type, status, to_char(start_time,'DAY') as DAY, start_time, end_time, time_taken_display TIME_TAKEN,
b.input_bytes_display INPUT_BYTES, b.input_bytes_per_sec_display "INPUT B/S",
b.output_bytes_display OUTPUT_BYTES, b.output_bytes_per_sec_display "OUTPUT B/S"
FROM v$rman_backup_job_details b
WHERE b.input_type='DB INCR'
ORDER BY start_time;

-- CHECK ALL FAILURES

SELECT db_name, input_type, status, start_time, end_time
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 15)
AND b.status != 'COMPLETED'
ORDER BY start_time;

-- CHECK ALL BACKUPS OF A SPECIFIC DB

SELECT b.session_key, input_type, status, to_char(start_time,'DAY') as DAY, start_time, end_time, time_taken_display TIME_TAKEN,
b.input_bytes_display INPUT_BYTES, b.input_bytes_per_sec_display "INPUT B/S",
b.output_bytes_display OUTPUT_BYTES, b.output_bytes_per_sec_display "OUTPUT B/S"
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 15)
AND b.db_name='&db_name'
ORDER BY start_time;

select * from RMAN.rc_rman_output where SESSION_KEY='&session_key' order by RECID;

-- CHECK BACKUP ARCHIVELOG DI UN DB SPECIFICO

SELECT b.session_key, input_type, status, to_char(start_time,'DAY') as DAY, start_time, end_time, time_taken_display TIME_TAKEN,
b.input_bytes_display INPUT_BYTES, b.input_bytes_per_sec_display "INPUT B/S",
b.output_bytes_display OUTPUT_BYTES, b.output_bytes_per_sec_display "OUTPUT B/S"
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 15)
AND b.input_type='ARCHIVELOG'
AND b.db_name='&db_name'
ORDER BY start_time;


-- CHECK ULTIMO BACKUP ARCHIVELOG VALIDO PER CIASCUN DB

SELECT db_name, max(start_time)
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 1)
AND b.input_type='ARCHIVELOG'
AND b.status='COMPLETED'
GROUP BY db_name
ORDER BY 1;

-- CHECK FALLIMENTI CONSECUTIVI DI BACKUP INCREMENTALI 

SELECT db_name
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 3)
AND b.input_type like 'DB%'
AND b.status != 'COMPLETED'
AND b.db_name!='PROD'
GROUP BY db_name
HAVING count(1)>1
ORDER BY 1;




### Archivelog giorni feriali per un singolo DB: media elapsed e media quantità di dati

SELECT to_char(start_time,'HH24'), round(avg(elapsed_seconds)/60) as minuti,round(avg(B.INPUT_BYTES)/1024/1024/1024,4) as GB
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 31)
AND b.input_type='ARCHIVELOG'
AND b.db_name='&db_name'
and to_char(start_time,'DAY') not like 'DOMENICA%'
and to_char(start_time,'DAY') not like 'SABATO%'
GROUP BY to_char(start_time,'HH24')
order by 1;

### Archivelog giorni festivi per un singolo DB: media elapsed e media quantità di dati

SELECT to_char(start_time,'HH24'), round(avg(elapsed_seconds)/60) as minuti,round(avg(B.INPUT_BYTES)/1024/1024/1024,4) as GB
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 31)
AND b.input_type='ARCHIVELOG'
AND b.db_name='&db_name'
and (to_char(start_time,'DAY') like 'DOMENICA%' or to_char(start_time,'DAY') like 'SABATO%')
GROUP BY to_char(start_time,'HH24')
order by 1;

### Backup incrementali giorni feriali per un singolo DB: media elapsed e media quantità di dati

SELECT to_char(start_time,'DAY'),round(avg(elapsed_seconds)/60) as minuti,round(avg(B.OUTPUT_BYTES)/1024/1024/1024,2) as GB
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 31)
AND b.input_type!='ARCHIVELOG'
AND b.db_name='&db_name' 
and to_char(start_time,'DAY') not like 'DOMENICA%'
and to_char(start_time,'DAY') not like 'SABATO%'
GROUP BY to_char(start_time,'DAY');

### Backup incrementali giorni festivi per un singolo DB: media elapsed e media quantità di dati

SELECT to_char(start_time,'DAY'),round(avg(elapsed_seconds)/60) as minuti,round(avg(B.OUTPUT_BYTES)/1024/1024/1024,2) as GB
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 31)
AND b.input_type!='ARCHIVELOG'
AND b.db_name='&db_name' 
and (to_char(start_time,'DAY') like 'DOMENICA%' or to_char(start_time,'DAY') like 'SABATO%') 
GROUP BY to_char(start_time,'DAY');

## Medie tempi / spazi dei backup incrementali di un singolo DB

SELECT to_char(start_time,'YYYY/MM/DD DAY') as Giorno,
round(elapsed_seconds/60) as minuti,round(B.INPUT_BYTES/1024/1024/1024,2) as INPUT_GB, 
round(b.output_bytes/1024/1024/1024,2) as OUTPUT_GB, round(b.compression_ratio,2) as compression_ratio
FROM rman.rc_rman_backup_job_details b, rman.rc_database d
WHERE b.db_key = d.db_key
AND b.start_time > (SYSDATE - 28)
AND b.input_type!='ARCHIVELOG'
AND b.db_name='&db_name'
order by 1;

select db_name, to_char(start_time,'HH24') as start_time, to_char(start_time,'DAY') as start_day,round(avg(elapsed_seconds)/60) as minuti,round(avg(OUTPUT_BYTES)/1024/1024/1024,4) as GB
FROM rman.rc_rman_backup_job_details
where (to_char(start_time,'DAY') like '%LUNEDÌ%'
or to_char(start_time,'DAY') like '%MARTEDÌ%')
AND input_type!='ARCHIVELOG'
GROUP BY db_name, to_char(start_time,'HH24'), to_char(start_time,'DAY')
order by 3,2;

## Per verificare il corretto backup di un archivelog

select * 
from RMAN.rc_backup_archivelog_details
where db_name = 'MTPROD'
and sequence# = 1087024;

select * 
from rman.RC_RMAN_BACKUP_JOB_DETAILS
where session_key = 13210196;

select * 
from RMAN.rc_backup_piece_details
where db_key = 190587
and session_recid = 30551
and session_stamp = 723013343;

### Verifica pulizia e crescita catalogo RMAN

select db_id, min(START_TIME) from RC_BACKUP_SET group by db_id;