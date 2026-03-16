Redo logs generation

***** Shows current redo logs generation info (RAC-non RAC environment)
set line 3000
col machine for a15
col username for a10
col redo_MB for 999G990 heading "Redo |Size MB"
column sid_serial for a13;

select b.inst_id,
       lpad((b.SID || ',' || lpad(b.serial#,5)),11) sid_serial,
       b.username,
       machine,
       b.osuser,
       b.status,
       a.redo_mb
from (select n.inst_id, sid,
             round(value/1024/1024) redo_mb
        from gv$statname n, gv$sesstat s
        where n.inst_id=s.inst_id
              and n.name = 'redo size'
              and s.statistic# = n.statistic#
        order by value desc
     ) a,
     gv$session b
where b.inst_id=a.inst_id
  and a.sid = b.sid
and   rownum <= 30
;

******When and how many redo logs generation occurred?

set pagesize 999
set line 150
col day for a6
col "  00" for 999
col "  01" for 999
col "  02" for 999
col "  03" for 999
col "  04" for 999
col "  05" for 999
col "  06" for 999
col "  07" for 999
col "  08" for 999
col "  09" for 999
col "  10" for 999
col "  11" for 999
col "  12" for 999
col "  13" for 999
col "  14" for 999
col "  15" for 999
col "  16" for 999
col "  17" for 999
col "  18" for 999
col "  19" for 999
col "  20" for 999
col "  21" for 9999
col "  22" for 999
col "  23" for 999
col " Tot" for 9999

--COMPUTE  SUM LABEL Totale  AVG LABEL Media  OF " Tot" ON REPORT
COMPUTE  AVG LABEL Media  OF " Tot" ON REPORT
BREAK ON REPORT

select substr(to_char(first_time, 'MM-DD HH24'),1,6) day,
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'00',1,0)),'9999') "  00",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'01',1,0)),'9999') "  01",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'02',1,0)),'9999') "  02",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'03',1,0)),'9999') "  03",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'04',1,0)),'9999') "  04",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'05',1,0)),'9999') "  05",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'06',1,0)),'9999') "  06",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'07',1,0)),'9999') "  07",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'08',1,0)),'9999') "  08",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'09',1,0)),'9999') "  09",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'10',1,0)),'9999') "  10",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'11',1,0)),'9999') "  11",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'12',1,0)),'9999') "  12",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'13',1,0)),'9999') "  13",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'14',1,0)),'9999') "  14",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'15',1,0)),'9999') "  15",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'16',1,0)),'9999') "  16",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'17',1,0)),'9999') "  17",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'18',1,0)),'9999') "  18",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'19',1,0)),'9999') "  19",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'20',1,0)),'9999') "  20",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'21',1,0)),'9999') "  21",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'22',1,0)),'9999') "  22",
       to_number(sum(decode(substr(to_char(first_time, 'DD-MON-RR HH24'),11,2),'23',1,0)),'9999') "  23",
       to_number(to_char(count(*),'9909')) " Tot"
  from v$log_history
  where first_time>trunc(sysdate-90)
  group by substr(to_char(first_time, 'MM-DD HH24'),1,6)
  order by day
/


--****

set lines 300
set pages 300
col day for a20
col "00" for a5
col "01" for a5
col "02" for a5
col "03" for a5
col "04" for a5
col "05" for a5
col "06" for a5
col "07" for a5
col "08" for a5
col "09" for a5
col "10" for a5
col "11" for a5
col "12" for a5
col "13" for a5
col "14" for a5
col "15" for a5
col "16" for a5
col "17" for a5
col "18" for a5
col "19" for a5
col "20" for a5
col "21" for a5
col "22" for a5
col "23" for a5

select to_char(first_time,'YYYY-MON-DD') day,
to_char(sum(decode(to_char(first_time,'HH24'),'00',1,0)),'99') "00",
to_char(sum(decode(to_char(first_time,'HH24'),'01',1,0)),'99') "01",
to_char(sum(decode(to_char(first_time,'HH24'),'02',1,0)),'99') "02",
to_char(sum(decode(to_char(first_time,'HH24'),'03',1,0)),'99') "03",
to_char(sum(decode(to_char(first_time,'HH24'),'04',1,0)),'99') "04",
to_char(sum(decode(to_char(first_time,'HH24'),'05',1,0)),'99') "05",
to_char(sum(decode(to_char(first_time,'HH24'),'06',1,0)),'99') "06",
to_char(sum(decode(to_char(first_time,'HH24'),'07',1,0)),'99') "07",
to_char(sum(decode(to_char(first_time,'HH24'),'08',1,0)),'99') "08",
to_char(sum(decode(to_char(first_time,'HH24'),'09',1,0)),'99') "09",
to_char(sum(decode(to_char(first_time,'HH24'),'10',1,0)),'99') "10",
to_char(sum(decode(to_char(first_time,'HH24'),'11',1,0)),'99') "11",
to_char(sum(decode(to_char(first_time,'HH24'),'12',1,0)),'99') "12",
to_char(sum(decode(to_char(first_time,'HH24'),'13',1,0)),'99') "13",
to_char(sum(decode(to_char(first_time,'HH24'),'14',1,0)),'99') "14",
to_char(sum(decode(to_char(first_time,'HH24'),'15',1,0)),'99') "15",
to_char(sum(decode(to_char(first_time,'HH24'),'16',1,0)),'99') "16",
to_char(sum(decode(to_char(first_time,'HH24'),'17',1,0)),'99') "17",
to_char(sum(decode(to_char(first_time,'HH24'),'18',1,0)),'99') "18",
to_char(sum(decode(to_char(first_time,'HH24'),'19',1,0)),'99') "19",
to_char(sum(decode(to_char(first_time,'HH24'),'20',1,0)),'99') "20",
to_char(sum(decode(to_char(first_time,'HH24'),'21',1,0)),'99') "21",
to_char(sum(decode(to_char(first_time,'HH24'),'22',1,0)),'99') "22",
to_char(sum(decode(to_char(first_time,'HH24'),'23',1,0)),'99') "23"
from v$log_history 
group by to_char(first_time,'YYYY-MON-DD')
order by 1 desc ;

--****

**************************************************************************************
How much is that in Mb?
Total redo logs size (and according that, archived log size) cannot be computed from previous query because not all redo log switches occur when redo log was full.
For that you might want to use this very easy query:

select sum(value)/1048576 redo_MB from sys.gv_$sysstat where name = 'redo size';

   REDO_MB
----------
1074623.75

SQL>

If you want to calculate on instance grouping, then use this:

select inst_id, sum(value)/1048576 redo_MB from sys.gv_$sysstat where name = 'redo size'
group by inst_id;

   INST_ID    REDO_MB
---------- ----------
         1 370325.298
         2   4712.567
         4 405129.283
         3 294457.100

SQL>

Both queries works on single instances as well.
Which segments are generating redo logs?
After we found out our point of interest, in mine case where were most of the redo logs generation,
it is very useful to find out which segments (not tables only) are causing redo log generation.
For that we need to use "dba_hist" based tables, part of "Oracle AWR (Automated Workload Repository)",
which usage I have described in topic Automated AWR reports in Oracle 10g/11g. For this example
I''ll focus on data based on time period: 11-01-28 13:00-11-01-28 14:00. Query for such a task should be:


SELECT to_char(begin_interval_time,'YY-MM-DD HH24') snap_time,
        dhso.object_name,
        sum(db_block_changes_delta) BLOCK_CHANGED
  FROM dba_hist_seg_stat dhss,
       dba_hist_seg_stat_obj dhso,
       dba_hist_snapshot dhs
  WHERE dhs.snap_id = dhss.snap_id
    AND dhs.instance_number = dhss.instance_number
    AND dhss.obj# = dhso.obj#
    AND dhss.dataobj# = dhso.dataobj#
    AND begin_interval_time BETWEEN to_date('16-03-27 01:00','YY-MM-DD HH24:MI')
                                AND to_date('16-04-07 15:00','YY-MM-DD HH24:MI')
  GROUP BY to_char(begin_interval_time,'YY-MM-DD HH24'),
           dhso.object_name
  HAVING sum(db_block_changes_delta) > 0
ORDER BY sum(db_block_changes_delta) desc ;


Reduced result from previously shown query would be:
SNAP_TIME   OBJECT_NAME                    BLOCK_CHANGED
----------- ------------------------------ -------------
11-01-28 13 USR_RACUNI_MV                        1410112
11-01-28 13 TROK_TAB_RESEAU_I                     734592
11-01-28 13 TROK_VOIE_I                           638496
11-01-28 13 TROK_DATUM_ULAZA_I                    434688
11-01-28 13 TROK_PAIEMENT_I                       428544
11-01-28 13 D_DPX_VP_RAD                          351760
11-01-28 13 TROK_SVE_OK_I                         161472
11-01-28 13 I_DATPBZ_S002                         135296
11-01-28 13 IDS2_DATUM_I                          129904
11-01-28 13 IDS2_PZNBR                            129632
11-01-28 13 IDS2_IDS1_FK_I                        128848
11-01-28 13 IDS2_DATTRAN_I                        127440
11-01-28 13 IDS2_DATSOC_I                         127152
11-01-28 13 IDS2_VRSTA_PROD_I                     122816
...
Let us focus on first segment "USR_RACUNI_MV", segment with highest number of changed blocks (what mean directly highest redo log generation). Just for information, this is MATERIALIZED VIEW.
What SQL was causing redo log generation
Now when we know when, how much and what, time is to find out how redo logs are generated. In next query "USR_RACUNI_MV" and mentioned period are hard codded, because we are focused on them. Just to point that SQL that start with "SELECT" are not point of our interest because they do not make any changes.

SELECT to_char(begin_interval_time,'YYYY_MM_DD HH24') WHEN,
       dbms_lob.substr(sql_text,4000,1) SQL,
       dhss.instance_number INST_ID,
       dhss.sql_id,
       executions_delta exec_delta,
rows_processed_delta rows_proc_delta
  FROM dba_hist_sqlstat dhss,
       dba_hist_snapshot dhs,
       dba_hist_sqltext dhst
  WHERE upper(dhst.sql_text) LIKE '%USR_RACUNI_MV%'
    AND ltrim(upper(dhst.sql_text)) NOT LIKE 'SELECT%'
    AND dhss.snap_id=dhs.snap_id
    AND dhss.instance_number=dhs.instance_number
    AND dhss.sql_id=dhst.sql_id
    AND begin_interval_time BETWEEN to_date('11-01-28 13:00','YY-MM-DD HH24:MI')
                                AND to_date('11-01-28 14:00','YY-MM-DD HH24:MI')
;
Result is like:
WHEN          SQL                                               inst_id       sql_id  exec_delta rows_proc_delta
------------- ------------------------------------------------- ------- ------------- ---------- ---------------
2011_01_28 13 DECLARE                                                 1 duwxbg5d1dw0q          0                0
                job BINARY_INTEGER := :job;
                next_date DATE := :mydate;
                broken BOOLEAN := FALSE;
              BEGIN
                dbms_refresh.refresh('"TAB"."USR_RACUNI_MV"');
                :mydate := next_date;
                IF broken THEN :b := 1;
                ELSE :b := 0;
                END IF;
              END;
2011_01_28 13 delete from "TAB"."USR_RACUNI_MV"                       1 5n375fxu0uv89          0                0
For both of examples it was impossible to find out number of rows changed according operation that was performed. Let us see output of another example (NC_TRANSACTION_OK_T table) where we can meet with DDL that generate redo logs!
WHEN          SQL                                               inst_id       sql_id  exec_delta rows_proc_delta
------------- ------------------------------------------------- ------- ------------- ---------- ---------------
2011_01_28 13 alter table TAB.NC_TRANSACTION_OK_T                     4 g5gvacc8ngnb8          0               0
              shrink space cascade
If you are focused on pure number of changes, then you might to perform query where inst_id and sql_id are irrelevant (excluded from query). Here is a little modified previous example, for "Z_PLACENO" segment (pure oracle table):
SELECT when, sql, SUM(sx) executions, sum (sd) rows_processed
FROM (
      SELECT to_char(begin_interval_time,'YYYY_MM_DD HH24') when,
             dbms_lob.substr(sql_text,4000,1) sql,
             dhss.instance_number inst_id,
             dhss.sql_id,
             sum(executions_delta) exec_delta,
sum(rows_processed_delta) rows_proc_delta
        FROM dba_hist_sqlstat dhss,
             dba_hist_snapshot dhs,
             dba_hist_sqltext dhst
        WHERE upper(dhst.sql_text) LIKE '%Z_PLACENO%'
          AND ltrim(upper(dhst.sql_text)) NOT LIKE 'SELECT%'
          AND dhss.snap_id=dhs.snap_id
          AND dhss.instance_Number=dhs.instance_number
          AND dhss.sql_id = dhst.sql_id
          AND begin_interval_time BETWEEN to_date('11-01-25 14:00','YY-MM-DD HH24:MI')
                                      AND to_date('11-01-25 15:00','YY-MM-DD HH24:MI')
        GROUP BY to_char(begin_interval_time,'YYYY_MM_DD HH24'),
             dbms_lob.substr(sql_text,4000,1),
             dhss.instance_number,
             dhss.sql_id
)
group by when, sql;
Result is like:
WHEN          SQL                                                                    exec_delta rows_proc_delta
------------- ---------------------------------------------------------------------- ---------- ---------------
2011_01_25 14 DELETE FROM Z_PLACENO                                                           4         7250031
2011_01_25 14 INSERT INTO Z_PLACENO(OBP_ID,MT_SIFRA,A_TOT)                                    4         7250830
              SELECT P.OBP_ID,P.MT_SIFRA,SUM(P.OSNOVICA)
                FROM (SELECT OPI.OBP_ID,
                              OPO.MT_SIFRA,
                              SUM(OPO.IZNKN) OSNOVICA
                        WHERE OPI.OBP_ID = OPO.OPI_OBP_ID
                          AND OPI.RBR = OPO.OPI_RBR
                          AND NVL(OPI.S_PRETPOREZA,'O') IN ( 'O','N','A','Z','S')
                        GROUP BY OPI.OBP_ID,OPO.MT_SIFRA
                      )
Here you can see directly number executions and number of involved rows.
Query based on segment directly
Sometimes you do not want to focus on period, so your investigation may start with segment as starting point. For such a tasks I use next query. This is small variation of previous example where "USR_RACUNI_MV" segment is hard codded.

SELECT to_char(begin_interval_time,'YY-MM-DD HH24') snap_time,
       sum(db_block_changes_delta)
  FROM dba_hist_seg_stat dhss,
       dba_hist_seg_stat_obj dhso,
       dba_hist_snapshot dhs
  WHERE dhs.snap_id = dhss.snap_id
    AND dhs.instance_number = dhss.instance_number
    AND dhss.obj# = dhso.obj#
    AND dhss.dataobj# = dhso.dataobj#
    AND dhso.object_name = 'USR_RACUNI_MV'
  GROUP BY to_char(begin_interval_time,'YY-MM-DD HH24')
  ORDER BY to_char(begin_interval_time,'YY-MM-DD HH24');
Reduced result is:
   SNAP_TIME   SUM(DB_BLOCK_CHANGES_DELTA)
   ----------- ---------------------------
   ...
   11-01-28 11                     1224240
   11-01-28 12                      702880
 11-01-28 13                     1410112
   11-01-28 14                      806416
   11-01-28 15                     2008912
   11-01-28 16                     1103648
   ...
As you can see in accented row, the numbers are the same as at the begging of topic.

*********************************************************************************************

col c1 format a10 heading "Month"
col c2 format a25 heading "Archive Date"
col c3 format 999 heading "Switches"

compute AVG of C on A
compute AVG of C on REPORT

break on A skip 1 on REPORT skip 1

select
   to_char(trunc(first_time), 'Month') c1,
   to_char(trunc(first_time), 'Day : DD-Mon-YYYY') c2,
   count(*) c3
from
   v$log_history
where
   trunc(first_time) > last_day(sysdate-100) +1
group by
   trunc(first_time)
order by c1;


-- Daily Count and Size of Redo Log Space (Single Instance)
--
SELECT A.*,
Round(A.Count#*B.AVG#/1024/1024) Daily_Avg_Mb
FROM
(
   SELECT
   To_Char(First_Time,'YYYY-MM-DD') DAY,
   Count(1) Count#,
   Min(RECID) Min#,
   Max(RECID) Max#
FROM
   v$log_history
GROUP BY
   To_Char(First_Time,'YYYY-MM-DD')
ORDER
BY 1 DESC
) A,
(
SELECT
Avg(BYTES) AVG#,
Count(1) Count#,
Max(BYTES) Max_Bytes,
Min(BYTES) Min_Bytes
FROM
v$log
) B
;
