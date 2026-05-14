# Script Operativi per Scenario

> Raccolta di script SQL **pronti al copia-incolla** organizzati per **scenario operativo**.
> Ogni file include diagnosi, azione, verifica e note d'uso.

> [!WARNING]
> Questi script sono ottimi per uso rapido e didattico.
> Per analisi senior/approfondita usa la libreria completa: [../../01_operations/04_libreria_script_completa](../../01_operations/04_libreria_script_completa).

---

## Percorso consigliato

1. Parti dal runbook: [../../01_operations/02_runbooks_incidenti/README.md](../../01_operations/02_runbooks_incidenti/README.md)
2. Esegui script rapido per scenario
3. Se incidente complesso, scala a:
   - [Top 100 Script DBA](../../02_core_dba/03_performance_and_diagnostics/TOP_100_SCRIPT_DBA.md)
   - [Libreria completa script](../../01_operations/04_libreria_script_completa/README.md)
   - [Guida ADRCI diagnostica](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)

---

## Indice per Scenario

| # | File | Scenario | Quando lo usi |
|---|---|---|---|
| 01 | [Tablespace e Datafile](./01_tablespace_datafile.sql) | Tablespace pieno, maxsize, bigfile, resize, add datafile | Alert ORA-01654, ORA-01653 |
| 02 | [UNDO e TEMP](./02_undo_temp.sql) | Undo pieno, ORA-30036, temp piena, sort disk | "ORA-01555", query lentissime, temp 100% |
| 03 | [FRA e Archivelog](./03_fra_archivelog.sql) | FRA piena, archivelog che crescono, pulizia | Alert "DB Suspended", Data Pump che riempie la FRA |
| 04 | [Data Pump (expdp/impdp)](./04_datapump_operativo.sql) | Monitor export/import, impatto su FRA/TEMP/UNDO | Richiesta Dev, refresh test, migrazione |
| 05 | [ASM Storage](./05_asm_storage.sql) | Spazio ASM, diskgroup, AU_SIZE, limiti fisici | Capacity planning, add disk |
| 06 | [Sessioni e Lock](./06_sessioni_lock.sql) | Chi blocca chi, sessioni bloccanti, deadlock | Applicazione bloccata |
| 07 | [Performance Quick](./07_performance_quick.sql) | Top SQL, wait events, buffer cache hit | Database lento |
| 08 | [RMAN e Backup Status](./08_rman_backup_status.sql) | Ultimo backup, validate, crosscheck | Morning check, pre-upgrade |
| 09 | [Data Guard Status](./09_dataguard_status.sql) | Lag, transport, apply, GAP | Morning check, pre-switchover |
| 10 | [Oggetti e Schema](./10_oggetti_schema.sql) | Invalidi, segment size, tabelle grandi, indici | Pulizia, tuning, capacity |
| 11 | [TEMP Resize & Capacity](./11_temp_resize.sql) | Diagnosi TEMP, tempfile, autoextend/resize | ORA-01652, temp al 100% |
| 12 | [Log Purge (FRA + Unified Audit)](./12_log_purge_audit.sql) | Stato FRA, cleanup audit, note RMAN/ADRCI | Spazio log in crescita |
| 13 | [Monitor DDL (Package + Trigger)](./13_monitor_ddl_package.sql) | Audit DDL centralizzato con retention | Tracking cambi schema |
| 14 | [Optimizer Stats Operations](./14_optimizer_stats.sql) | Individua stale stats e gather sicuro | Regressioni piani SQL |

<details>
  <summary>📂 Elenco completo file SQL disponibili (click per espandere)</summary>

- [01_tablespace_datafile.sql](./01_tablespace_datafile.sql)
- [02_undo_temp.sql](./02_undo_temp.sql)
- [03_fra_archivelog.sql](./03_fra_archivelog.sql)
- [04_datapump_operativo.sql](./04_datapump_operativo.sql)
- [05_asm_storage.sql](./05_asm_storage.sql)
- [06_sessioni_lock.sql](./06_sessioni_lock.sql)
- [07_performance_quick.sql](./07_performance_quick.sql)
- [08_rman_backup_status.sql](./08_rman_backup_status.sql)
- [09_dataguard_status.sql](./09_dataguard_status.sql)
- [10_oggetti_schema.sql](./10_oggetti_schema.sql)
- [11_temp_resize.sql](./11_temp_resize.sql)
- [12_log_purge_audit.sql](./12_log_purge_audit.sql)
- [13_monitor_ddl_package.sql](./13_monitor_ddl_package.sql)
- [14_optimizer_stats.sql](./14_optimizer_stats.sql)

</details>

---

## Cheat Sheet correlate

- [Cheat Sheet RMAN](../../01_operations/02_runbooks_incidenti/CHEAT_SHEET_RMAN.md)
- [Cheat Sheet DGMGRL](../../01_operations/02_runbooks_incidenti/CHEAT_SHEET_DGMGRL.md)
- [Cheat Sheet GoldenGate](../../01_operations/02_runbooks_incidenti/CHEAT_SHEET_GOLDENGATE.md)
