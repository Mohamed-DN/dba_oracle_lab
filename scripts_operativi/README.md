# Script Operativi per Scenario

> Raccolta di script SQL **pronti al copia-incolla** organizzati per **scenario operativo**.
> Ogni file contiene: diagnosi, azione correttiva, verifica, e note per la produzione.

---

## Come Usarli

```bash
# Da terminale con sqlplus:
sqlplus / as sysdba @scripts_operativi/01_tablespace_datafile.sql

# Oppure copia-incolla i blocchi che ti servono direttamente in sqlplus.
```

---

## Indice per Scenario

| # | File | Scenario | Quando lo usi |
|---|---|---|---|
| 01 | [Tablespace e Datafile](./01_tablespace_datafile.sql) | Tablespace pieno, maxsize, bigfile, resize, add datafile | Alert "ORA-01654", "ORA-01653" |
| 02 | [UNDO e TEMP](./02_undo_temp.sql) | Undo pieno, ORA-30036, temp piena, sort disk | "ORA-01555", query lentissime, temp 100% |
| 03 | [FRA e Archivelog](./03_fra_archivelog.sql) | FRA piena, archivelog che crescono, pulizia | Alert "DB Suspended", Data Pump che riempie la FRA |
| 04 | [Data Pump (expdp/impdp)](./04_datapump_operativo.sql) | Monitor export/import, impatto su FRA/TEMP/UNDO | Richiesta Dev, refresh test, migrazione |
| 05 | [ASM Storage](./05_asm_storage.sql) | Spazio ASM, diskgroup, AU_SIZE, limiti fisici | Capacity planning, add disk |
| 06 | [Sessioni e Lock](./06_sessioni_lock.sql) | Chi blocca chi, kill session, deadlock | "L'app è bloccata!" |
| 07 | [Performance Quick](./07_performance_quick.sql) | Top SQL, wait events, buffer cache hit | "Il database è lento!" |
| 08 | [RMAN e Backup Status](./08_rman_backup_status.sql) | Ultimo backup, validate, crosscheck | Morning check, pre-upgrade |
| 09 | [Data Guard Status](./09_dataguard_status.sql) | Lag, transport, apply, GAP | Morning check, before switchover |
| 10 | [Oggetti e Schema](./10_oggetti_schema.sql) | Invalidi, segment size, tabelle grandi, indici | Pulizia, tuning, capacity |
