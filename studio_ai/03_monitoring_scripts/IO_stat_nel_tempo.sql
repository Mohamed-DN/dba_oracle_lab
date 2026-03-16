--via SQL (per day):
set lin 300 pages 300
col sample_time for a20

SELECT range.sample_time,
      end_snap.PHYRDS - beg_snap.PHYRDS 									phys_reads,
      round(((end_snap.READTIM - beg_snap.READTIM) * 10),2) 							read_time_ms,
      round(((end_snap.READTIM - beg_snap.READTIM) * 10) /
                decode((end_snap.PHYRDS - beg_snap.PHYRDS),0,1,(end_snap.PHYRDS - beg_snap.PHYRDS)),5) 		avg_read_time_ms,
      end_snap.PHYWRTS - beg_snap.PHYWRTS phys_writes,
      round(((end_snap.WRITETIM - beg_snap.WRITETIM) * 10),2) write_time_ms,
      round(((end_snap.WRITETIM - beg_snap.WRITETIM) * 10) /
                decode((end_snap.PHYWRTS - beg_snap.PHYWRTS),0,1,(end_snap.PHYWRTS - beg_snap.PHYWRTS)),5) 	avg_write_time_ms
  FROM (  SELECT snap_id,
                 SUM (F.PHYRDS) PHYRDS,
                 SUM (F.READTIM) READTIM,
                 SUM (F.PHYWRTS) PHYWRTS,
                 SUM (F.WRITETIM) WRITETIM
            FROM DBA_HIST_FILESTATXS f
           --WHERE INSTANCE_NUMBER=2
        GROUP BY snap_id
        ORDER BY 1) end_snap,
       (  SELECT snap_id,
                 SUM (F.PHYRDS) PHYRDS,
                 SUM (F.READTIM) READTIM,
                 SUM (F.PHYWRTS) PHYWRTS,
                 SUM (F.WRITETIM) WRITETIM
            FROM DBA_HIST_FILESTATXS f
           --WHERE INSTANCE_NUMBER=2
        GROUP BY snap_id
        ORDER BY 1) beg_snap,
       (  SELECT TRUNC (BEGIN_INTERVAL_TIME) sample_time,
                 MIN (snap_id) min_snap_id,
                 MAX (snap_id) max_snap_id
            FROM DBA_HIST_SNAPSHOT
           WHERE BEGIN_INTERVAL_TIME > TO_DATE ('20170101 23:59:59', 'YYYYMMDD HH24:MI:SS')
             --AND INSTANCE_NUMBER=2
        GROUP BY TRUNC (BEGIN_INTERVAL_TIME)
        ORDER BY 1) range
 WHERE end_snap.snap_id = range.max_snap_id
       AND beg_snap.snap_id = range.min_snap_id;

SAMPLE_TIME          PHYS_READS READ_TIME_MS AVG_READ_TIME_MS PHYS_WRITES WRITE_TIME_MS AVG_WRITE_TIME_MS
-------------------- ---------- ------------ ---------------- ----------- ------------- -----------------
22-FEB-12              11566276    140639020          12.1594     2160189     226985210         105.07655
23-FEB-12              12812414    249971730         19.51012      823906     138546210         168.15779


--via SQL (per every snap_id):
set lin 300 pages 300
col sample_time for a30

SELECT min.snap_id,
       to_char(min.BEGIN_INTERVAL_TIME,'DD/MM/YYYY HH24:MI:SS') sample_time,
       MAX.phyrds - MIN.phyrds phys_reads,
       round(((max.READTIME - min.READTIME) * 10),2) read_time_ms,
       round(((max.READTIME - min.READTIME) * 10) / decode((MAX.phyrds - MIN.phyrds),0,1,(MAX.phyrds - MIN.phyrds)),5) avg_read_time_ms,
       MAX.phywrts - MIN.phywrts phys_writes,
       round(((max.WRITETIME - min.WRITETIME) * 10),2) write_time_ms,
       round(((max.WRITETIME - min.WRITETIME) * 10) / decode((MAX.phywrts - MIN.phywrts),0,1,(MAX.phywrts - MIN.phywrts)),5) avg_write_time_ms
  FROM (  SELECT fs.snap_id,
                 s.BEGIN_INTERVAL_TIME,
                 SUM (FS.PHYRDS) phyrds,
                 SUM (FS.READTIM) readtime,
                 SUM (FS.PHYWRTS) phywrts,
                 SUM (FS.WRITETIM) writetime
            FROM DBA_HIST_FILESTATXS fs,
                 DBA_HIST_SNAPSHOT s
           WHERE fs.snap_id = s.snap_id
--             AND s.INSTANCE_NUMBER=1                   <<<--- instance number
             AND s.instance_number=fs.instance_number
             and s.BEGIN_INTERVAL_TIME > sysdate-30
        GROUP BY fs.snap_id, s.BEGIN_INTERVAL_TIME
        ORDER BY 1) MAX,
       (  SELECT fs.snap_id,
                 s.BEGIN_INTERVAL_TIME,
                 SUM (FS.PHYRDS) phyrds,
                 SUM (FS.READTIM) readtime,
                 SUM (FS.PHYWRTS) phywrts,
                 SUM (FS.WRITETIM) writetime
            FROM DBA_HIST_FILESTATXS fs,
                 DBA_HIST_SNAPSHOT s
           WHERE fs.snap_id = s.snap_id
--             AND s.INSTANCE_NUMBER=1                    <<<--- instance number
             AND s.instance_number=fs.instance_number
             and s.BEGIN_INTERVAL_TIME > sysdate-30
        GROUP BY fs.snap_id, s.BEGIN_INTERVAL_TIME
        ORDER BY 1) MIN
 WHERE MAX.snap_id - 1 = MIN.snap_id
 ORDER by 1;

  SNAP_ID SAMPLE_TIME                    PHYS_READS READ_TIME_MS AVG_READ_TIME_MS PHYS_WRITES WRITE_TIME_MS AVG_WRITE_TIME_MS
---------- ------------------------------ ---------- ------------ ---------------- ----------- ------------- -----------------
      8855 21/02/2012 13:00:04                820816     10354860         12.61532       96151       4748740          49.38836
      8856 21/02/2012 14:00:07               1029482     12527120         12.16837      117538       7919590          67.37898
      8857 21/02/2012 15:00:02                373763      2420190           6.4752      116412       1588410          13.64473
      8858 21/02/2012 16:00:09                465051      4554410          9.79336      108863      32258640         296.32327
      8859 21/02/2012 17:00:18                202579      2845650         14.04711       93343       7168660          76.79912
      8860 21/02/2012 18:00:30                326519      1681470          5.14969      181317      16308170          89.94286
      8861 21/02/2012 19:00:02                138425       592500           4.2803      115398       7872570          68.22103
      8862 21/02/2012 20:00:05                 27422       140800          5.13456       86722        500530           5.77166
      8863 21/02/2012 21:00:11                 50689       936470         18.47482       86339       5197280           60.1962
      8864 21/02/2012 22:00:26                 33746       589110         17.45718       86494       5273720          60.97209
      8865 21/02/2012 23:00:34                 57838      5077110         87.78156       86550      18463380         213.32617
      8866 22/02/2012 00:00:43                 20024      1944850         97.12595       80711      23328560         289.03817

---> If you want a narrower time interval put:

AND s.BEGIN_INTERVAL_TIME > to_date('23-feb-2012 17:50:00', 'dd-mon-yyyy hh24:mi:ss')
AND s.BEGIN_INTERVAL_TIME < to_date('23-feb-2012 20:00:00', 'dd-mon-yyyy hh24:mi:ss')


COL phyrds FOR 999,999,999,999,999
COL phywrts FOR 999,999,999,999,999

--via SQL(per day)
SELECT /*+ parallel(s 2) */ -- fs.snap_id,
                 to_char(s.BEGIN_INTERVAL_TIME,'dd/mm/yyyy') day,
                 -- fs.filename,
                 SUM (FS.PHYRDS) phyrds,
                 --round((SUM (FS.READTIM)) / 100,2) tot_readtime_secs,
                 round((SUM (FS.READTIM)) /  (SUM (FS.PHYRDS))* 10,2) avg_read_ms,
                 SUM (FS.PHYWRTS) phywrts,
                 --round((SUM (FS.WRITETIM)) / 100,2) tot_writetime_secs,
                 round((SUM (FS.WRITETIM)) /  (SUM (FS.PHYWRTS))* 10,2) avg_write_ms
            FROM DBA_HIST_FILESTATXS fs,
                 DBA_HIST_SNAPSHOT s
           WHERE fs.snap_id = s.snap_id
             and s.BEGIN_INTERVAL_TIME > sysdate-10
             --and s.INSTANCE_NUMBER=2
             and s.instance_number=fs.instance_number
        GROUP BY  to_char(s.BEGIN_INTERVAL_TIME,'dd/mm/yyyy')
                  -- , filename
                  -- , snap_id
        ORDER BY 1;

DAY                      PHYRDS AVG_READ_MS              PHYWRTS AVG_WRITE_MS
---------- -------------------- ----------- -------------------- ------------
20/02/2012        2,561,058,755        8.83          397,381,422         85.6
21/02/2012        5,767,494,877        8.92          906,100,493        85.95
22/02/2012        6,043,942,713        9.09          960,630,951        87.38
23/02/2012        2,628,389,094        9.53          417,702,749        88.84

Quest'ultima farla anche senza l'instance_number

Per Oracle 9
------------
set lin 300 pages 300
col sample_time for a30

SELECT min.snap_id,
       to_char(min.snap_time,'DD/MM/YYYY HH24:MI:SS') sample_time,
       MAX.phyrds - MIN.phyrds phys_reads,
       round(((max.READTIME - min.READTIME) * 10),2) read_time_ms,
       round(((max.READTIME - min.READTIME) * 10) / decode((MAX.phyrds - MIN.phyrds),0,1,(MAX.phyrds - MIN.phyrds)),5) avg_read_time_ms,
       MAX.phywrts - MIN.phywrts phys_writes,
       round(((max.WRITETIME - min.WRITETIME) * 10),2) write_time_ms,
       round(((max.WRITETIME - min.WRITETIME) * 10) / decode((MAX.phywrts - MIN.phywrts),0,1,(MAX.phywrts - MIN.phywrts)),5) avg_write_time_ms
  FROM (  SELECT fs.snap_id,
                 s.snap_time,
                 SUM (FS.PHYRDS) phyrds,
                 SUM (FS.READTIM) readtime,
                 SUM (FS.PHYWRTS) phywrts,
                 SUM (FS.WRITETIM) writetime
            FROM perfstat.stats$filestatxs fs, perfstat.stats$snapshot s
           WHERE fs.snap_id = s.snap_id
        GROUP BY fs.snap_id, s.snap_time
        ORDER BY 1) MAX,
       (  SELECT fs.snap_id,
                 s.snap_time,
                 SUM (FS.PHYRDS) phyrds,
                 SUM (FS.READTIM) readtime,
                 SUM (FS.PHYWRTS) phywrts,
                 SUM (FS.WRITETIM) writetime
            FROM perfstat.stats$filestatxs fs, perfstat.stats$snapshot s
           WHERE fs.snap_id = s.snap_id
        GROUP BY fs.snap_id, s.snap_time
        ORDER BY 1) MIN
WHERE MAX.snap_id - 1 = MIN.snap_id
ORDER by 1 desc;

---> If you want a narrower time interval put:

AND s.SNAP_TIME > to_date('23-feb-2012 17:50:00', 'dd-mon-yyyy hh24:mi:ss')
AND s.SNAP_TIME < to_date('23-feb-2012 20:00:00', 'dd-mon-yyyy hh24:mi:ss')

