-- Source: https://www.scriptdba.com/query-per-vedere-gli-spazi-dei-diskgroup-asm/
-- Title: Query per vedere gli spazi dei DiskGroup ASM

col name for a25
set lines 200
select name, total_mb, free_mb,
100 - ROUND(100 * free_mb / decode(nvl(total_mb,0),0,1,total_mb)) as perc_used
from V$asm_diskgroup;

col name for a25
set lines 200
select name, total_mb, free_mb,
100 - ROUND(100 * free_mb / decode(nvl(total_mb,0),0,1,total_mb)) as perc_used
from V$asm_diskgroup;

