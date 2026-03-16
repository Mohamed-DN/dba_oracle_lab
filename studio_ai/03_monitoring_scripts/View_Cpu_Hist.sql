To see the CPU consumption of the operating system for the week
-----------------------------------------------------------------
SET LINES 3000
SET PAGES 3000
col begin_interval_time heading "START" FOR A20
col end_interval_time heading "END"     FOR A20
col value heading "TOT CPU DISP"
col used_cpu_sec heading "CPU/SEC"
col interval_sec heading "DURATA INTERVALLO"
col cpu_avail_tot heading "TOT SEC CPU DISP"
col used_cpu_perc heading "% CPU USED"

select ol.snap_id,
       to_char(nw.begin_interval_time,'DD/MM/YYYY HH24:MI:SS')                                                                         begin_interval_time,
       to_char(nw.end_interval_time,'DD/MM/YYYY HH24:MI:SS')                                                                           end_interval_time,
--       pa.value,
       round((nw.value - ol.value) / 100)                                                                                                   used_cpu_sec,
(cast(nw.end_interval_time as date) - cast(ol.end_interval_time as date)) * 24 *60 * 60 interval_sec,
      (cast(nw.end_interval_time as date) - cast(ol.end_interval_time as date)) * 24 *60 * 60 * pa.value                                    cpu_avail_tot,
--round((round((nw.value - ol.value) / 100)) / ((cast(nw.end_interval_time as date) - cast(ol.end_interval_time as date)) * 24 *60 * 60),2) used_cpu_perc
      round((((nw.value - ol.value) / 100)) / (((EXTRACT(DAY FROM nw.END_INTERVAL_TIME - ol.END_INTERVAL_TIME) * 1440
                        + EXTRACT(HOUR FROM nw.END_INTERVAL_TIME - ol.END_INTERVAL_TIME) * 60
                        + EXTRACT(MINUTE FROM nw.END_INTERVAL_TIME - ol.END_INTERVAL_TIME)
                        + EXTRACT(SECOND FROM nw.END_INTERVAL_TIME - ol.END_INTERVAL_TIME) / 60)*60)*pa.value)*100,2) used_cpu_perc
from  (select sn.snap_id,
              begin_interval_time,
              end_interval_time,
              stat_name,
              value
       from   dba_hist_osstat os,
              dba_hist_snapshot sn
       where  stat_id = 2 and
              sn.snap_id = os.snap_id and
              os.instance_number = 1 and
              sn.instance_number = 1 and trunc(sn.begin_interval_time) > trunc(sysdate - 90) ) ol,
      (select sn.snap_id,
              begin_interval_time,
              end_interval_time,
              stat_name,
              value
       from   dba_hist_osstat os,
              dba_hist_snapshot sn
       where  stat_id = 2 and
              sn.snap_id = os.snap_id and
              os.instance_number = 1 and
              sn.instance_number = 1 and trunc(sn.begin_interval_time) > trunc(sysdate - 90) ) nw,
       (select value, snap_id from dba_hist_osstat where stat_id = 0 and instance_number = 1) pa
where nw.snap_id -1 = ol.snap_id and
      ol.snap_id = pa.snap_id
order by 1
/

Per il database
---------------

CPU used by this session + recursive cpu usage + parse time cpu

alter session set nls_date_format = 'DD-MON-YYYY HH24:MI';

SET LINES 300
COL BEGIN_INTERVAL_TIME FOR A26

select BEGIN_INTERVAL_TIME,
       s.instance_number i,
        tb.STAT_NAME,
     (te.value-tb.value)  "Total Mb"
from DBA_HIST_SYSSTAT tb,
     DBA_HIST_SYSSTAT te,
     dba_hist_snapshot s
where tb.snap_id+1= te.snap_id
  and s.snap_id=tb.snap_id
  and tb.STAT_NAME in ('CPU used by this session','recursive cpu usage','parse time cpu')
  and tb.stat_name=te.stat_name
  and s.instance_number=tb.instance_number
  and te.instance_number=tb.instance_number
 and tb.instance_number=1
  and BEGIN_INTERVAL_TIME> sysdate - 10
order by 1;