# Example of adding AFD in production (template)

Synthetic template for adding AFD disk:

```bash
asmcmd afd_state
asmcmd afd_label DATA_019 /dev/sdX1
asmcmd afd_lsdsk
```

```sql
ALTER DISKGROUP DATA ADD DISK 'AFD:DATA_019' REBALANCE POWER 8;
SELECT name, state, total_mb, free_mb FROM v$asm_diskgroup;
```

Controlli:

- label visible on all nodes
- diskgroup in state `MOUNTED`
- rebalance completato

For full flow use:

- [asm_disk_add_procedure.md](./asm_disk_add_procedure.md)
