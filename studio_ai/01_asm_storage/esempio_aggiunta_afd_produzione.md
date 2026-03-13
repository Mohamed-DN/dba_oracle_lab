# Esempio aggiunta AFD in produzione (template)

Template sintetico per aggiunta disco AFD:

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

- label visibile su tutti i nodi
- diskgroup in stato `MOUNTED`
- rebalance completato

Per flusso completo usa:

- [procedura_aggiunta_dischi_asm.md](./procedura_aggiunta_dischi_asm.md)
