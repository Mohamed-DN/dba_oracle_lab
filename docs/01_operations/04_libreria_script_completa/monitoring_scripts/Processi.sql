-- OSPID FROM SID

select s.username, s.program, s.status, s.sid, s.serial#, p.spid OSPID from v$session s,v$process p where s.paddr=p.addr and s.sid=&sid order by 1,2;

select 'kill -9 ' || p.spid from v$session s,v$process p where s.paddr=p.addr and s.status='KILLED' order by logon_time;

-- SID FROM OSPID

select s.username, s.program, s.status, s.sid, s.serial#, p.spid OSPID from v$session s,v$process p where s.paddr=p.addr and p.spid=&spid order by 1,2;

-- PGA USAGE

col username for a30
select s.inst_id, spid, s.username,
       round(pga_used_mem/1024/1024) "MB USATI",
       round(pga_alloc_mem/1024/1024) "MB ALLOCATI",
       round(pga_freeable_mem/1024/1024) "MB LIBERABILI",
       round(pga_max_mem/1024/1024) "MB MAX"
from gv$session s,gv$process p
where s.inst_id=p.inst_id and s.paddr=p.addr and s.username is not null
and pga_alloc_mem>100000 order by pga_alloc_mem;

select s.inst_id, round(sum(pga_used_mem/1024/1024)) "TOTAL MB USATI", round(sum(pga_alloc_mem/1024/1024)) "TOTAL MB ALLOC"
from gv$session s,gv$process p where s.inst_id=p.inst_id and s.paddr=p.addr group by s.inst_id order by 1;

select s.inst_id, s.username, round(sum(pga_used_mem/1024/1024)) "TOTAL MB USATI", sum(pga_alloc_mem/1024/1024) "TOTAL MB ALLOC"
from gv$session s,gv$process p where s.inst_id=p.inst_id and s.paddr=p.addr group by s.inst_id, s.username order by 1,2;

-- CDB PGA USAGE

select pdb.pdb_name, s.inst_id, spid, s.username,
       round(pga_used_mem/1024/1024) "MB USATI",
       round(pga_alloc_mem/1024/1024) "MB ALLOCATI",
       round(pga_freeable_mem/1024/1024) "MB LIBERABILI",
       round(pga_max_mem/1024/1024) "MB MAX"
from gv$session s, gv$process p, dba_pdbs pdb
where s.inst_id=p.inst_id and s.paddr=p.addr and s.con_id=pdb.con_id and s.username is not null
and pga_alloc_mem>100000 order by pga_alloc_mem;

col pdb_name for a30
select pdb.pdb_name, s.inst_id, round(sum(pga_used_mem/1024/1024)) "TOTAL MB USATI", round(sum(pga_alloc_mem/1024/1024)) "TOTAL MB ALLOC", 
       round(sum(pga_freeable_mem/1024/1024)) "TOTAL MB LIBERABILI", round(sum(pga_max_mem/1024/1024)) "TOTAL MB MAX"
from gv$session s, gv$process p, dba_pdbs pdb
where s.con_id=p.con_id and s.inst_id=p.inst_id and s.paddr=p.addr and s.con_id=pdb.con_id
group by pdb.pdb_name, s.con_id, s.inst_id order by 1;

-- Killable processes

http://oracle-help.com/oracle-database/killable-processes-oracle-database/

-- Primary Note: Overview of Oracle Background Processes (Doc ID 1503146.1)

-- Statistiche storiche processes

col data for a20
select distinct to_char(b.begin_interval_time,'DD/MM/YYYY HH24:MI') data, a.* --b.begin_interval_time
from DBA_HIST_RESOURCE_LIMIT a, DBA_HIST_SNAPSHOT b
where a.resource_name='processes'
and b.snap_id=a.snap_id
and a.instance_number=1
order by a.snap_id;

col data for a20
select to_char(b.begin_interval_time,'YYYY/MM/DD') data, round(avg(current_utilization))
from DBA_HIST_RESOURCE_LIMIT a, DBA_HIST_SNAPSHOT b
where a.resource_name='processes'
and b.snap_id=a.snap_id
and a.instance_number=1
group by to_char(b.begin_interval_time,'YYYY/MM/DD')
order by to_char(b.begin_interval_time,'YYYY/MM/DD');

-- How To Find Where The Memory Is Growing For A Process (Doc ID 822527.1)

COLUMN alme     HEADING "Allocated MB" FORMAT 99999D9
COLUMN usme     HEADING "Used MB"      FORMAT 99999D9
COLUMN frme     HEADING "Freeable MB"  FORMAT 99999D9
COLUMN mame     HEADING "Max MB"       FORMAT 99999D9
COLUMN username                        FORMAT a15
COLUMN program                         FORMAT a22
COLUMN sid                             FORMAT a5
COLUMN spid                            FORMAT a8
SET LINESIZE 300
SELECT s.username, SUBSTR(s.sid,1,5) sid, p.spid, logon_time,
       SUBSTR(s.program,1,22) program , s.process pid_remote,
       s.status,
       ROUND(pga_used_mem/1024/1024) usme,
       ROUND(pga_alloc_mem/1024/1024) alme,
       ROUND(pga_freeable_mem/1024/1024) frme,
       ROUND(pga_max_mem/1024/1024) mame
FROM  v$session s,v$process p
WHERE p.addr=s.paddr
ORDER BY pga_max_mem,logon_time;

COLUMN category      HEADING "Category"
COLUMN allocated     HEADING "Allocated bytes"
COLUMN used          HEADING "Used bytes"
COLUMN max_allocated HEADING "Max allocated bytes"
SELECT pid, category, allocated, used, max_allocated
FROM   v$process_memory
WHERE  pid = (SELECT pid
              FROM   v$process
              WHERE  addr= (select paddr
                            FROM   v$session
                            WHERE  sid = &SID));

alter session set events'immediate trace name PGA_DETAIL_GET level 387';
							
SELECT category, name, heap_name, bytes, allocation_count,
       heap_descriptor, parent_heap_descriptor
FROM   v$process_memory_detail
WHERE  pid      = 387
AND    category = 'Other';

-- BACKGROUND PROCESSES

-- SCM

12.2 RAC DB Background process SCM0 consuming excessive CPU (Doc ID 2373451.1)
https://dbtut.com/index.php/2019/05/22/scm0-process-consumes-high-cpu-in-12-2-rac-databases/
DLM Statistics Collection and Management slave (SCM0) background process