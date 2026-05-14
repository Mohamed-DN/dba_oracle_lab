-- # Mostra i dischi ASM
select g.name DG, d.name DISK, d.total_mb, d.free_mb, d.header_status, d.path, d.GROUP_NUMBER, d.failgroup, d.DISK_NUMBER
from v$asm_diskgroup g,
     v$asm_disk d
where g.group_number(+)=d.group_number
order by d.GROUP_NUMBER, d.DISK_NUMBER;
