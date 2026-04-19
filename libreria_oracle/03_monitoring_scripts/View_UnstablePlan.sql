UNSTABLE PLAN STATEMENT
-----------------------

The first one can be used to show statements that have experienced significant variances in execution time
(it can be modified to look for variances in the amount of logical i/o, but I’ll leave it as an exercise for the reader).
I called the script unstable_plans.sql.
It uses an analytic function to calculate a standard deviation on the average elapsed time by plan.
So the statements that have multiple plans with wild variations in the response time between plans will be returned by the script.
The script prompts for a couple of values. The first is minimum number of standard deviations.
The second is the minimum elapsed time (I usually don’t care if a statement executes sometimes in .005 seconds and sometimes in .02 seconds,
even though this is a large swing statistically).
Both these inputs are defaulted by the way

unstable_plan.sql

set lines 155
col execs for 999,999,999
col min_etime for 999,999.99
col max_etime for 999,999.99
col avg_etime for 999,999.999
col avg_lio for 999,999,999.9
col norm_stddev for 999,999.9999
col begin_interval_time for a30
col node for 99999
break on plan_hash_value on startup_time skip 1

select *
from ( select sql_id,
       sum(execs),
       min(avg_etime) min_etime,
       max(avg_etime) max_etime,
       stddev_etime/min(avg_etime) norm_stddev
from ( select sql_id,
              plan_hash_value,
              execs,
              avg_etime,
              stddev(avg_etime) over (partition by sql_id) stddev_etime
       from ( select sql_id,
              	     plan_hash_value,
                     sum(nvl(executions_delta,0)) execs,
                     (sum(elapsed_time_delta)/decode(sum(nvl(executions_delta,0)),0,1,sum(executions_delta))/1000000) avg_etime
              from   DBA_HIST_SQLSTAT S,
                     DBA_HIST_SNAPSHOT SS
              where  ss.snap_id = S.snap_id
              and    ss.instance_number = S.instance_number
              and    executions_delta > 0
              and    elapsed_time_delta > 0
              and    s.snap_id > nvl('&earliest_snap_id',1016)
              group by sql_id, plan_hash_value))
       group by sql_id, stddev_etime)
where norm_stddev > nvl(to_number('&min_stddev'),2)
and   max_etime > nvl(to_number('&min_etime'),.1)
order by norm_stddev
/

min_stddev: the minimum "normalized" standard deviation between plans    (the default is 2)
min_etime:  only include statements that have an avg. etime > this value (the default is .1 second)


SQL_ID        SUM(EXECS)   MIN_ETIME   MAX_ETIME   NORM_STDDEV
------------- ---------- ----------- ----------- -------------
0qa98gcnnza7h         62       25.58      314.34        7.9833

Questo sql_id ha avuto degli scossoni nel tempo di risposta

Eseguo lo script : find_sql.sql

select sql_id, child_number, plan_hash_value plan_hash, executions execs,
       (elapsed_time/1000000)/decode(nvl(executions,0),0,1,executions) avg_etime,
       buffer_gets/decode(nvl(executions,0),0,1,executions) avg_lio
from   v$sql s
where    sql_text not like '%from v$sql where sql_text like nvl(%'and sql_id like nvl('&sql_id',sql_id)
order by 1, 2, 3

select sql_id, child_number, plan_hash_value plan_hash, executions execs,
       (elapsed_time/1000000)/decode(nvl(executions,0),0,1,executions) avg_etime,
       buffer_gets/decode(nvl(executions,0),0,1,executions) avg_lio,
       substr(sql_text,10)
from   v$sql s
where  upper(sql_text) like upper(nvl('&sql_text',sql_text))
and    sql_text not like '%from v$sql where sql_text like nvl(%'and sql_id like nvl('&sql_id',sql_id)
order by 1, 2, 3

Enter value for sql_text:
Enter value for address:
Enter value for sql_id: 0qa98gcnnza7h

SQL_ID         CHILD  PLAN_HASH        EXECS         ETIME     AVG_ETIME USERNAME      SQL_TEXT
------------- ------ ---------- ------------ ------------- ------------- ------------- -----------------------------------------
0qa98gcnnza7h      0 3723858078            5        356.53         71.31 SYS           select avg(pk_col) from kso.skew where col1 > 0
0qa98gcnnza7h      1  568322376            1          7.92          7.92 SYS           select avg(pk_col) from kso.skew where col1 > 0
0qa98gcnnza7h      2  568322376           10         52.14          5.21 SYS           select avg(pk_col) from kso.skew where col1 > 0
0qa98gcnnza7h      3  568322376           30      1,064.19         35.47 KSO           select avg(pk_col) from kso.skew where col1 > 0
0qa98gcnnza7h      4 3723858078           10      4,558.62        455.86 KSO           select avg(pk_col) from kso.skew where col1 > 0


Eseguo lo script awr_plan_change.sql dandogli il sql_id

Enter value for sql_id: 0qa98gcnnza7h

set lines 4000
set page 30000
col execs for 999,999,999
col avg_etime for 999,999.999
col avg_lio for 999,999,999.9
col begin_interval_time for a30
col node for 99999
break on plan_hash_value on startup_time skip 1

select ss.snap_id,
       ss.instance_number node,
       begin_interval_time,
       sql_id,
       plan_hash_value,
       nvl(executions_delta,0) 									execs,
       nvl(executions_total,0)									execs_total,
       (elapsed_time_delta/decode(nvl(executions_delta,0),0,1,executions_delta))/1000000 	avg_etime
       --(buffer_gets_delta/decode(nvl(buffer_gets_delta,0),0,1,executions_delta)) 		avg_lio
from   DBA_HIST_SQLSTAT S,
       DBA_HIST_SNAPSHOT SS
where  sql_id = nvl('&sql_id','aw8222d0yfjdy') --04qd7p7kc1p0x
and    ss.snap_id = S.snap_id
and    ss.instance_number = S.instance_number
--and    ss.instance_number=1
and    executions_delta > -1
AND ss.BEGIN_INTERVAL_TIME >
                TO_DATE ('01-01-2016 00:00:00', 'dd-mm-yyyy hh24:mi:ss')
         AND ss.END_INTERVAL_TIME <
                TO_DATE ('30-12-2017 00:00:00', 'dd-mm-yyyy hh24:mi:ss')
order by 1, 2, 3
/


  SNAP_ID   NODE BEGIN_INTERVAL_TIME            SQL_ID        PLAN_HASH_VALUE        EXECS    AVG_ETIME        AVG_LIO
---------- ------ ------------------------------ ------------- --------------- ------------ ------------ --------------
      3206      1 02-OCT-08 08.00.38.743 AM      0qa98gcnnza7h       568322376            4       10.359      121,722.8
      3235      1 03-OCT-08 01.00.44.932 PM      0qa98gcnnza7h                            1       10.865      162,375.0
      3235      1 03-OCT-08 01.00.44.932 PM      0qa98gcnnza7h      3723858078            1      127.664   28,913,271.0
      3236      1 03-OCT-08 01.28.09.000 PM      0qa98gcnnza7h       568322376            1        7.924      162,585.0
      3236      1 03-OCT-08 01.28.09.000 PM      0qa98gcnnza7h      3723858078            1       86.682   27,751,123.0
      3305      1 06-OCT-08 10.00.11.988 AM      0qa98gcnnza7h                            4       64.138   22,616,931.5
      3305      1 06-OCT-08 10.00.11.988 AM      0qa98gcnnza7h       568322376            2        5.710       81,149.0
      3306      1 06-OCT-08 11.00.16.490 AM      0qa98gcnnza7h                            6        5.512      108,198.5
      3307      1 06-OCT-08 12.00.20.716 PM      0qa98gcnnza7h                            2        3.824       81,149.0
      3328      1 07-OCT-08 08.39.20.525 AM      0qa98gcnnza7h                           30       35.473      156,904.7
      3335      1 07-OCT-08 03.00.20.950 PM      0qa98gcnnza7h      3723858078           10

Vedo che per le 62 esecuzioni tale sql_id ha 2 piani di esecuzione

Controllo i 2 piani di esecuzione

select * from table(dbms_xplan.display_cursor('&sql_id','&child_no','typical'));

Oppure

select * from table(dbms_xplan.display_cursor('&sql_id','&child_no',''));

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('&sql_id', format => 'ADVANCED'));


Controllo piano con HASH_VALUE

select * from table(dbms_xplan.display_awr('&sql_id','&plan_hash',''));


Per E-Rows and A-Rows

SELECT * FROM TABLE (DBMS_XPLAN.display_cursor ('&sql_id', NULL, 'ALLSTATS LAST'));


***************

SET LINE 250 PAGES 2000
ALTER SESSION SET nls_date_format='dd-mon-yy hh24:mi:ss';

COL SQL_PLAN_HASH_VALUE FOR 99999999999
COL END_TIME FOR a30
COL RUN_TIME FOR a30

  SELECT sql_id,
         sql_plan_hash_value,
         sql_exec_start starting_time,
         MAX (sample_time) end_time,
         MAX (sample_time - sql_exec_start) run_time,
         SUM (delta_read_io_bytes) read_io_bytes
    FROM (SELECT sql_id,
                 sql_plan_hash_value,
                 sample_time,
                 sql_exec_start,
                 delta_read_io_bytes,
                 sql_exec_id
            --FROM dba_hist_active_sess_history
            FROM v$active_session_history
           WHERE     sql_id IN ('aw8222d0yfjdy')
                 AND sample_time >=
                        TO_DATE ('2017/01/01 00:00:00',
                                 'YYYY/MM/DD HH24:MI:SS')
                 AND sample_time <=
                        TO_DATE ('2017/12/31 23:00:00',
                                 'YYYY/MM/DD HH24:MI:SS')
                 AND sql_exec_start IS NOT NULL)
GROUP BY sql_id,
         sql_exec_id,
         sql_exec_start,
         sql_plan_hash_value
ORDER BY starting_time
/

***************



*********
# per vedere in tempo reale l''elapsed time
*********
SET LINE 250 PAGES 2000
ALTER SESSION SET nls_date_format='dd-mon-yy hh24:mi:ss';
COL SQL_PLAN_HASH_VALUE FOR 99999999999
COL END_TIME FOR a30
COL RUN_TIME FOR a30



  SELECT sql_id,
         sql_plan_hash_value,
         sql_exec_start starting_time,
         MAX (sample_time) end_time,
         MAX (sample_time - sql_exec_start) run_time,
         SUM (delta_read_io_bytes) read_io_bytes
    FROM (SELECT sql_id,
                 sql_plan_hash_value,
                 sample_time,
                 sql_exec_start,
                 delta_read_io_bytes,
                 sql_exec_id
                                  FROM dba_hist_active_sess_history
            --FROM v$active_session_history
           WHERE     sql_id = 'a4yya9th1td59'
                 AND sample_time >=
                        TO_DATE ('2017/09/18 12:00:00',
                                 'YYYY/MM/DD HH24:MI:SS')
                 AND sample_time <=
                        TO_DATE ('2017/12/31 18:00:00',
                                 'YYYY/MM/DD HH24:MI:SS'))
                 --AND sql_exec_start IS NOT NULL)
GROUP BY sql_id,
         sql_exec_id,
         sql_exec_start,
         sql_plan_hash_value
ORDER BY starting_time
/

*********

Per trovare il sql_id

set long 90000
set pages 40000
set lines 300
col sql_text for a100

	select SQL_TEXT
	from   v$sqltext
	where  sql_id = 'bvrvy849a5mt6'
	order by piece;


set long 90000
set pages 40000
set lines 300
col sql_text for a100

	select SQL_TEXT
	from   dba_hist_sqltext
	where  sql_id = 'ayhfas9dfz6qq';

*********

--How to get execution statistics and history for a SQL (Doc ID 1371778.1)

--How To Interpret DBA_HIST_SQLSTAT (Doc ID 471053.1)

-- From Memory:

SET LINE 3000
SET PAGES 3000
COL sql_id              FOR a30
COL child_number        FOR a30
COL plan_hash_value     FOR a30
COL first_load_time     FOR a20
COL last_load_time      FOR a20
COL outline_category    FOR a10
COL sql_profile         FOR a10
COL executions          for 9999999999
COL rows_avg            for 9999999999
COL fetches_avg         for 9999999999
COL disk_reads_avg      for 9999999999
COL buffer_gets_avg     for 9999999999
COL cpu_time_avg        for 9999999999
COL elapsed_time_avg    for 9999999999
COL apwait_time_avg     for 9999999999
COL cwait_time_avg      for 9999999999
COL clwait_time_avg     for 9999999999
COL iowait_time_avg     for 9999999999
COL plsexec_time_avg    for 9999999999
COL javexec_time_avg    for 9999999999


  SELECT                                                            --inst_id,
        sql_id,
         child_number,
         plan_hash_value,
         first_load_time,
         last_load_time,
         outline_category,
         sql_profile,
         executions,
         TRUNC (DECODE (executions, 0, 0, rows_processed / executions))
            rows_avg,
         TRUNC (DECODE (executions, 0, 0, fetches / executions)) fetches_avg,
         TRUNC (DECODE (executions, 0, 0, disk_reads / executions))
            disk_reads_avg,
         TRUNC (DECODE (executions, 0, 0, buffer_gets / executions))
            buffer_gets_avg,
         TRUNC (DECODE (executions, 0, 0, cpu_time / 1000000 / executions))
            cpu_time_avg,
         TRUNC (DECODE (executions, 0, 0, elapsed_time / 1000000 / executions))
            elapsed_time_avg,
         TRUNC (
            DECODE (executions,
                    0, 0,
                    application_wait_time / 1000000 / executions))
            apwait_time_avg,
         TRUNC (
            DECODE (executions,
                    0, 0,
                    concurrency_wait_time / 1000000 / executions))
            cwait_time_avg,
         TRUNC (
            DECODE (executions, 0, 0, cluster_wait_time / 1000000 / executions))
            clwait_time_avg,
         TRUNC (
            DECODE (executions, 0, 0, user_io_wait_time / 1000000 / executions))
            iowait_time_avg,
         TRUNC (
            DECODE (executions, 0, 0, plsql_exec_time / 1000000 / executions))
            plsexec_time_avg,
         TRUNC (
            DECODE (executions, 0, 0, java_exec_time / 1000000 / executions))
            javexec_time_avg
    FROM gv$sql
   WHERE sql_id = decode('&sql_id',null,'aw8222d0yfjdy')
ORDER BY child_number;


-- From AWR:

	set line 3000
	set pages 3000
	col instance_number for a2
	col BEGIN_INTERVAL_TIME for a30
	col end_interval_time for a30
	col plan_has_value for a10
	col executions_total for 99999999
	col executions_delta for 99999999
	col sql_profile for a10
	col rows_avg for 999999999
	col fetches_avg for 9999999999
	col disk_reads_avg for 9999999999
	col buffer_gets_avg for 9999999999999
	col cpu_time_avg for 9999999999
	col elapsed_time_avg for 9999999999
	col iowait_time_avg for 9999999999

	  SELECT --SS.instance_number,
			 SN.BEGIN_INTERVAL_TIME,
			 --sn.end_interval_time,
			 SS.plan_hash_value,
			 --SS.sql_profile,
			 SS.executions_total,
			 --ss.executions_delta,
			 TRUNC (
				DECODE (SS.executions_total,
						0, 0,
						SS.rows_processed_total / SS.executions_total))
				rows_avg,
			 TRUNC (
				DECODE (SS.executions_total,
						0, 0,
						SS.fetches_total / SS.executions_total))
				fetches_avg,
			 TRUNC (
				DECODE (SS.executions_total,
						0, 0,
						SS.disk_reads_total / SS.executions_total))
				disk_reads_avg,
			 TRUNC (
				DECODE (SS.executions_total,
						0, 0,
						SS.buffer_gets_total / SS.executions_total))
				buffer_gets_avg,
			 TRUNC (
				DECODE (SS.executions_total,
						0, 0,
						SS.cpu_time_total / 1000000 / SS.executions_total))
				cpu_time_avg,
			 TRUNC (
				DECODE (SS.executions_total,
						0, 0,
						SS.elapsed_time_total / 1000000 / SS.executions_total))
				elapsed_time_avg,
			 TRUNC (
				DECODE (SS.executions_total,
						0, 0,
						SS.iowait_total / 1000000 / SS.executions_total))
				iowait_time_avg
	--         TRUNC (
	--            DECODE (SS.executions_total,
	--                    0, 0,
	--                    SS.clwait_total / 1000000 / SS.executions_total))
	--            clwait_time_avg,
	--         TRUNC (
	--            DECODE (SS.executions_total,
	--                    0, 0,
	--                    SS.apwait_total / 1000000 / SS.executions_total))
	--            apwait_time_avg,
	--         TRUNC (
	--            DECODE (SS.executions_total,
	--                    0, 0,
	--                    SS.ccwait_total / 1000000 / SS.executions_total))
	--            ccwait_time_avg,
	--         TRUNC (
	--            DECODE (SS.executions_total,
	--                    0, 0,
	--                    SS.plsexec_time_total / 1000000 / SS.executions_total))
	--            plsexec_time_avg
	--         TRUNC (
	--            DECODE (SS.executions_total,
	--                    0, 0,
	--                    SS.javexec_time_total / 1000000 / SS.executions_total))
	--            javexec_time_avg
		FROM dba_hist_sqlstat SS, dba_hist_snapshot SN
	   WHERE     SS.sql_id = NVL('&sql_id', 'aw8222d0yfjdy')
			 AND SS.snap_id = SN.snap_id
			 AND SS.instance_number = SN.instance_number
	ORDER BY SS.snap_id DESC, SS.instance_number;


*********
Altra query utile

set lines 300
set pages 2000
col snap_time for a22
col "ela/execs" for 999999.999999
col exec for 99999999


SELECT DISTINCT
   sn.snap_id,
   to_char(begin_interval_time, 'dd/mm/yy hh24:mi')||'->'||to_char(end_interval_time, 'hh24:mi') snap_time,
--   sql_id,
--   sq.instance_number "inst",
   plan_hash_value "phv",
   executions_delta "execs",
   round(elapsed_time_delta / 1000000 / decode(px_servers_execs_delta,0,1,px_servers_execs_delta),4) "ela(s)",
   round(elapsed_time_delta / 1000000 / decode(executions_delta,0,1,executions_delta) /
                    decode(px_servers_execs_delta,0,1,px_servers_execs_delta),2) "ela/execs",
   round((cpu_time_delta / 1000000),4) "cpu_time(s)",
   round(cpu_time_delta / 1000000 / decode(executions_delta,0,1,executions_delta) /
                    decode(px_servers_execs_delta,0,1,px_servers_execs_delta),2) "cpu/execs",
   round(cpu_time_delta*100/decode(elapsed_time_delta,0,1,elapsed_time_delta),4) "%cpu",
--   buffer_gets_delta "buff_gets",
   round(buffer_gets_delta / decode(executions_delta,0,1,executions_delta) / decode(px_servers_execs_delta,0,1,px_servers_execs_delta),4) "gets/execs",
--   disk_reads_delta "disk_reads",
   round(disk_reads_delta / decode(executions_delta,0,1,executions_delta) / decode(px_servers_execs_delta,0,1,px_servers_execs_delta),4) "rds/execs",
--   fetches_delta "fetches",
--   round(fetches_delta / decode(executions_delta,0,1,executions_delta) / decode(px_servers_execs_delta,0,1,px_servers_execs_delta),4) "fetches/exec",
--   rows_processed_delta "rows",
   round(rows_processed_delta / decode(executions_delta,0,1,executions_delta) / decode(px_servers_execs_delta,0,1,px_servers_execs_delta),4) "rows/exec"
--   direct_writes_delta "direct_wrts",
--   round(direct_writes_delta / decode(executions_delta,0,1,executions_delta) /
--                            decode(px_servers_execs_delta,0,1,px_servers_execs_delta),4) "d-wrts/execs",
--   iowait_delta "io_wtime",
--   round(iowait_delta*100/decode(elapsed_time_delta,0,1,elapsed_time_delta),4) "%iowait",
--   apwait_delta "ap_wtime",
--   round(apwait_delta*100/decode(elapsed_time_delta,0,1,elapsed_time_delta),4) "%apwait",
--   ccwait_delta "cc_wtime",
--  round(ccwait_delta*100/decode(elapsed_time_delta,0,1,elapsed_time_delta),4) "%ccwait",
--   clwait_delta "cl_wtime",
--   round(clwait_delta*100/decode(elapsed_time_delta,0,1,elapsed_time_delta),4) "%clwait",
--   module,
--   version_count
FROM
   dba_hist_snapshot sn,
   dba_hist_sqlstat sq
WHERE
   sn.snap_id=sq.snap_id
   AND sn.instance_number=sq.instance_number
   AND sq.sql_id = NVL('&sql_id', 'aw8222d0yfjdy')
   AND sn.begin_interval_time > sysdate -30
 --  AND sq.instance_number = 1
ORDER BY
   1;


*************
SET LINES 3000
SET PAGES 3000

COL rows/e FOR 999999999
COL "sql_id" FOR A13
COL fetch/e FOR 99999
COL execs FOR 99999
COL inst FOR 99
COL snap FOR 99999
COL time FOR A15
COL "ela/e (s)" FOR 9999999

  SELECT TO_CHAR (end_interval_time, 'dd-mon-yy hh24:mi') "time",
         sql_id "sql_id",
         plan_hash_value "phv",
         --module,
         ROUND (
              elapsed_time_delta
            / DECODE (executions_delta, 0, 1, executions_delta)
            / 1000000,
            2)
            "ela/e (s)",
         ROUND (
              cpu_time_delta
            / DECODE (executions_delta, 0, 1, executions_delta)
            / 1000000,
            2)
            "cpu/e (s)",
         ROUND (
              st.iowait_delta
            / DECODE (executions_delta, 0, 1, executions_delta)
            / 1000000,
            2)
            "io/e (s)",
         ROUND (
              st.apwait_delta
            / DECODE (executions_delta, 0, 1, executions_delta)
            / 1000000,
            2)
            "ap/e (s)",
         ROUND (
              st.clwait_delta
            / DECODE (executions_delta, 0, 1, executions_delta)
            / 1000000,
            2)
            "cl/e (s)",
         ROUND (
              st.ccwait_delta
            / DECODE (executions_delta, 0, 1, executions_delta)
            / 1000000,
            2)
            "cc/e (s)",
         ROUND (
              st.buffer_gets_delta
            / DECODE (executions_delta, 0, 1, executions_delta),
            2)
            "get/e",
         ROUND (
              st.disk_reads_delta
            / DECODE (executions_delta, 0, 1, executions_delta),
            2)
            "disk/e",
         ROUND (
              st.fetches_delta
            / DECODE (executions_delta, 0, 1, executions_delta),
            2)
            "fetch/e",
         ROUND (
              st.rows_processed_delta
            / DECODE (executions_delta, 0, 1, executions_delta),
            2)
            "rows/e",
         st.executions_delta "execs"
    ---- , st.sql_profile,
    ----- module
    FROM dba_hist_sqlstat st, dba_hist_snapshot sn
   WHERE     st.snap_id = sn.snap_id
         AND sql_id = NVL('&sql_id', 'aw8222d0yfjdy')
         --AND plan_hash_value = 3535714343 AND
             AND st.instance_number = sn.instance_number
--         AND sn.begin_interval_time BETWEEN TO_DATE ('22-NOV-16 00:00:00',
--                                                     'DD-MON-YY HH24:MI:SS')
--                                        AND TO_DATE ('30-DEC-16 01:00:00',
--                                                     'DD-MON-YY HH24:MI:SS')
--         AND ROUND (
--                  elapsed_time_delta
--                / DECODE (executions_delta, 0, 1, executions_delta)
--                / 1000000,
--                2) > 0
--         AND executions_delta != 0
ORDER BY st.snap_id ASC
/


*************
Altra query Utile

ALTER SESSION SET nls_date_format='dd-mm-yyyy hh24:mi:ss';
SET LINES 2000
SET PAGES 3000
COL SQL_ID FOR a20
COL EXE_DELTA FOR 999
COL ROWS_PROCESSED_TOTAL FOR 999,999,999
COL END_INTERVAL_TIME FOR a20

  SELECT ss.sql_id,
         ss.PLAN_HASH_VALUE,
         to_char(sn.END_INTERVAL_TIME,'dd/mm/yyyy hh24:mi:ss') END_INTERVAL_TIME,
         ss.executions_delta EXEC_DELTA,
         TRUNC ( (ELAPSED_TIME_DELTA / (executions_delta * 1000)), 2)
            "ElapsAverageMs",
         TRUNC ( (CPU_TIME_DELTA / (executions_delta * 1000)), 2)
            "CPUAverageMs",
         TRUNC ( (IOWAIT_DELTA / (executions_delta * 1000)), 2) "IOAvgMs",
         TRUNC ( (BUFFER_GETS_DELTA / executions_delta), 2)
            "AvgBufferGets",
         TRUNC ( (DISK_READS_DELTA / executions_delta), 2) "AvgDiskReads",
         ss.ROWS_PROCESSED_TOTAL,
         ss.SORTS_DELTA,
         ss.FETCHES_DELTA
    FROM DBA_HIST_SQLSTAT ss, DBA_HIST_SNAPSHOT sn
   WHERE     ss.sql_id IN ('3gdmxctcjzntp')
--         AND sn.BEGIN_INTERVAL_TIME >
  --              TO_DATE ('01-01-2017 00:00:00', 'dd-mm-yyyy hh24:mi:ss')
    --     AND sn.END_INTERVAL_TIME <
      --          TO_DATE ('31-12-2017 00:00:00', 'dd-mm-yyyy hh24:mi:ss')
         AND ss.snap_id = sn.snap_id
         --AND executions_delta > 1
ORDER BY ss.snap_id, ss.sql_id;

*************
Altra query Utile

PROMPT enter start and end times in format DD-MON-YYYY [HH24:MI]

COLUMN sample_end FORMAT a21

  SELECT TO_CHAR (MIN (s.end_interval_time), 'DD-MON-YYYY DY HH24:MI')
            sample_end,
         q.sql_id,
         q.plan_hash_value,
         SUM (q.EXECUTIONS_DELTA) executions,
         ROUND (SUM (DISK_READS_delta) / GREATEST (SUM (executions_delta), 1),
                1)
            pio_per_exec,
         ROUND (SUM (BUFFER_GETS_delta) / GREATEST (SUM (executions_delta), 1),
                1)
            lio_per_exec,
         ROUND (
            (  SUM (ELAPSED_TIME_delta)
             / GREATEST (SUM (executions_delta), 1)
             / 1000),
            1)
            msec_exec
    FROM dba_hist_sqlstat q, dba_hist_snapshot s
   WHERE     q.SQL_ID = TRIM ('&sqlid.')
         AND s.snap_id = q.snap_id
         AND s.dbid = q.dbid
         AND s.instance_number = q.instance_number
         --AND s.end_interval_time >=
           --     TO_DATE (TRIM ('&start_time.'), 'dd-mon-yyyy hh24:mi')
         --AND s.begin_interval_time <=
           --     TO_DATE (TRIM ('&end_time.'), 'dd-mon-yyyy hh24:mi')
         --AND SUBSTR (TO_CHAR (s.end_interval_time, 'DD-MON-YYYY DY HH24:MI'),
           --          13,
             --        2) LIKE
               -- '%&hr24_filter.%'
GROUP BY s.snap_id, q.sql_id, q.plan_hash_value
ORDER BY s.snap_id, q.sql_id, q.plan_hash_value
/



**********************************************************************************

Query Utili per BIND VARIABLE

SET LINESIZE 200
SET PAGESIZE 200
COL cdate FORMAT a30
COL name for a20
COL VALUE_STRING FORMAT a20
ALTER SESSION SET NLS_DATE_FORMAT='YYYY:MM:DD HH24:MI:SS';

  SELECT snap_id,
         NAME,
         POSITION,
         DATATYPE_STRING,
         VALUE_STRING,
         LAST_CAPTURED cdate
    FROM DBA_HIST_SQLBIND
   WHERE SNAP_ID=NVL('&snapid',81211)
     and SQL_ID = NVL('&sqlid','7h3bydmqa8bmn')
ORDER BY name,position,cdate,snap_id
/


SELECT *
  FROM v$sql_shared_cursor
 WHERE sql_id = 'fcrakprtksy1p';

SELECT parsing_user_id,
       parsing_schema_id,
       sql_text,
       address,
       child_address
  FROM v$sql
 WHERE address = '00000017CDBCBF00';

SELECT address,
       child_address,
       CHILD_NUMBER,
       HASH_VALUE,
       PLAN_HASH_VALUE,
       PARSING_USER_ID,
       PARSING_SCHEMA_ID
  FROM v$sql
 WHERE address = '00000017CDBCBF00';


SELECT *
  FROM v$sql
 WHERE sql_id LIKE ' fcrakprtksy1p';



SELECT *
  FROM v$sql
 WHERE sql_id LIKE '2g825dtag74x2';


SELECT DISTINCT (plan_hash_value)
  FROM V$SQL_PLAN
 WHERE sql_id = 'fcrakprtksy1p';



SELECT fetches, executions, PARSE_CALLS
  FROM v$sqlarea
 WHERE sql_id = 'fcrakprtksy1p';


  SELECT ADDRESS, COUNT (*)
    FROM v$sql_shared_cursor
   WHERE bind_mismatch = 'Y'
GROUP BY ADDRESS
ORDER BY 2 DESC;

SELECT *
  FROM v$sqlarea
 WHERE address = '000000039DE93C08';

SELECT *
  FROM v$sql_shared_cursor
 WHERE address = '000000039DE93C08';


  SELECT position,
         datatype,
         max_length,
         COUNT (*)
    FROM v$sql_bind_metadata
   WHERE address IN (SELECT address
                       FROM v$sql_shared_cursor
                      WHERE address = '000000047CDD9A28')
GROUP BY position, datatype, max_length
  HAVING COUNT (*) != (SELECT COUNT (*)
                         FROM v$sql_shared_cursor
                        WHERE address = '000000047CDD9A28')
ORDER BY 1;

