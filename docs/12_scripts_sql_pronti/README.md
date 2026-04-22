# Script Operativi per Scenario

> Raccolta di script SQL **pronti al copia-incolla** organizzati per **scenario operativo**.
> Ogni file include diagnosi, azione, verifica e note d'uso.

> [!WARNING]
> Questi script sono ottimi per uso rapido e didattico.
> Per analisi senior/approfondita usa la libreria completa: [../13_libreria_completa_script](../13_libreria_completa_script).

---

## Percorso consigliato

1. Parti dal runbook: [../11_runbook_operativi/README.md](../11_runbook_operativi/README.md)
2. Esegui script rapido per scenario
3. Se incidente complesso, scala a:
   - [Top 100 Script DBA](../05_performance/TOP_100_SCRIPT_DBA.md)
   - [Libreria completa script](../13_libreria_completa_script/README.md)
   - [Guida ADRCI diagnostica](../05_performance/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)

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

---

## Cheat Sheet correlate

- [Cheat Sheet RMAN](../11_runbook_operativi/CHEAT_SHEET_RMAN.md)
- [Cheat Sheet DGMGRL](../11_runbook_operativi/CHEAT_SHEET_DGMGRL.md)
- [Cheat Sheet GoldenGate](../11_runbook_operativi/CHEAT_SHEET_GOLDENGATE.md)
