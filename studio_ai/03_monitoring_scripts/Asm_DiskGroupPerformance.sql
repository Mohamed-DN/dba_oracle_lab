ASM disk-level throughput and service time 
-------------------------------------------

col disk_path format a32 heading "Disk Path"
col total_mb format 999,999 heading "MB"
col avg_read_ms format 999.99 heading "Avg Read|(ms)"
col io_1k format  999,999 heading "IO|/1000"
col io_secs format  999,999,999 heading "IO|seconds"
col pct_io format 999.99 heading "Pct|IO"
col pct_time format 999.99 heading "Pct|Time"
set pagesize 10000
set lines 275
set verify off 
set echo on 

SELECT d.PATH disk_path, d.total_mb,
       ROUND(ds.read_secs * 1000 / ds.reads, 2) avg_read_ms, 
       ds.reads/1000 +  ds.writes/1000 io_1k, 
       ds.read_secs +ds.write_secs io_secs,
       ROUND((d.reads + d.writes) * 100 / 
            SUM(d.reads + d.writes) OVER (),2) pct_io,
       ROUND((ds.read_secs +ds.write_secs)*100/
            SUM(ds.read_secs +ds.write_secs) OVER (),2) pct_time
  FROM v$asm_diskgroup_stat dg
  JOIN v$asm_disk_stat d ON (d.group_number = dg.group_number)
  JOIN (SELECT group_number, disk_number disk_number, SUM(reads) reads,
               SUM(writes) writes, ROUND(SUM(read_time), 2) read_secs,
               ROUND(SUM(write_time), 2) write_secs
          FROM gv$asm_disk_stat 
         WHERE mount_status = 'CACHED'
         GROUP BY group_number, disk_number) ds
        ON (ds.group_number = d.group_number
            AND ds.disk_number = d.disk_number)
 WHERE dg.name = 'PRV_DG' 
   AND d.mount_status = 'CACHED'
 ORDER BY d.PATH;

                                          Avg Read       IO           IO     Pct     Pct
Disk Path                              MB     (ms)    /1000      seconds      IO    Time
-------------------------------- -------- -------- -------- ------------ ------- -------
/dev/oracleasm/disks/PRVDG01      102,892    15.13  122,039    1,165,050    5.18    5.58
/dev/oracleasm/disks/PRVDG02      102,892    15.21  114,171    1,147,423    5.19    5.49
/dev/oracleasm/disks/PRVDG03      102,892    11.16  153,187    1,189,931    6.97    5.70
/dev/oracleasm/disks/PRVDG04      102,892    15.13  114,392    1,150,008    5.20    5.51
/dev/oracleasm/disks/PRVDG05      102,892    15.64  112,130    1,137,319    5.10    5.44

ASM diskgroup IO throughput and service time - Totale
------------------------------------------------------
col name format a12 heading "Diskgroup|Name"
col type format a6 heading "Redundacy|Type"
col total_gb format 9,999 heading "Size|GB"
col active_disks format 99 heading "Active|Disks"
col reads1k format 9,999,999 heading "Reads|/1000"
col writes1k format 9,999,999 heading "Writes|/1000"
col read_time format 999,999,999 heading "Read Time|Secs"
col write_time format 999,999,999 heading "Write Time|Secs"
col avg_read_ms format 999.99 heading "Avg Read|ms"
set pagesize 1000
set lines 380
set echo on

SELECT name, ROUND(total_mb / 1024) total_gb, active_disks,
       reads / 1000 reads1k, writes / 1000 writes1k,
       ROUND(read_time) read_time, ROUND(write_time) write_time,
       ROUND(read_time * 1000 / reads, 2) avg_read_ms
FROM     v$asm_diskgroup_stat dg
     JOIN
         (SELECT group_number, COUNT(DISTINCT disk_number) active_disks,
                 SUM(reads) reads, SUM(writes) writes,
                 SUM(read_time) read_time, SUM(write_time) write_time
          FROM gv$asm_disk_stat
          WHERE mount_status = 'CACHED'
          GROUP BY group_number) ds
     ON (ds.group_number = dg.group_number)
ORDER BY dg.group_number;


Diskgroup      Size Active      Reads     Writes    Read Time   Write Time Avg Read
Name             GB  Disks      /1000      /1000         Secs         Secs       ms
------------ ------ ------ ---------- ---------- ------------ ------------ --------
APRT_DG         143      1     81,933     27,220    1,128,792      446,215    13.78
APRT_FRA        108      1      3,077     19,805       50,669      277,125    16.47
CEEDOPR_DG      286      6     82,386     25,976    1,009,305      481,875    12.25
CEEDOPR_FRA      95      2      3,757     16,989       50,792      326,174    13.52
CRS               6      3      4,925     34,782       46,937    1,086,606     9.53
MDS_FRA         251      1     32,253    131,520    1,631,252    1,919,824    50.58
MDS_DG        1,005      4    498,065    596,788   16,527,806   23,815,870    33.18
DATA            502      2     67,846     20,949      907,605      383,013    13.38