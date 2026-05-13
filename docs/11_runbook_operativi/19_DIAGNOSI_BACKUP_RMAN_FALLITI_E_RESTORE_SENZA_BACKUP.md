# 19 Diagnosi Backup RMAN Falliti + Restore Senza Backup

## Obiettivo

Fornire una procedura pratica per:
1) capire **perché** i backup RMAN (full, incremental, archivelog) falliscono  
2) gestire il ripristino **quando non esistono backup RMAN disponibili**

## Prerequisiti

- Accesso `SYSDBA` o `SYSBACKUP`
- RMAN disponibile sul server target
- Alert log e directory di backup accessibili
- FRA (se usata) visibile e con spazio

## Procedura operativa

### A) Diagnosi fallimenti backup RMAN

#### 1) Raccogli evidenze primarie

```rman
LIST BACKUP SUMMARY;
LIST FAILURE ALL;
```

```sql
SELECT start_time, end_time, status, input_type, output_device_type
FROM v$rman_backup_job_details
ORDER BY start_time DESC FETCH FIRST 20 ROWS ONLY;

SELECT recid, stamp, status, operation, object_type
FROM v$rman_status
ORDER BY stamp DESC FETCH FIRST 50 ROWS ONLY;
```

Controlla anche `alert.log` e i log RMAN (`rman | tee rman.log`).

#### 2) Errori tipici (FULL)

- **Spazio insufficiente** (FRA o filesystem)
  ```sql
  SELECT name, space_limit, space_used, space_reclaimable
  FROM v$recovery_file_dest;
  ```
  Azione: libera FRA o cambia destinazione backup.

- **Permessi/ownership** sul path di backup  
  Azione: verifica ACL e proprietà directory.

- **Problemi canali** (SBT/DISK)
  Azione: verifica `CONFIGURE CHANNEL`, MML library, variabili `ENV`.

#### 3) Errori tipici (INCREMENTAL)

- **Block Change Tracking non attivo**
  ```sql
  SELECT status, filename FROM v$block_change_tracking;
  ```
  Azione: abilita BCT o accetta backup più lenti.

- **Catalogo incoerente**
  ```rman
  CROSSCHECK BACKUP;
  LIST EXPIRED BACKUP;
  ```
  Azione: `DELETE EXPIRED` + `CATALOG START WITH`.

#### 4) Errori tipici (ARCHIVELOG)

- **Sequenze mancanti**
  ```rman
  LIST ARCHIVELOG ALL;
  LIST BACKUP OF ARCHIVELOG ALL;
  ```
  Azione: verifica retention, cancella solo dopo backup confermato.

- **Log switch non avvenuto**
  ```sql
  ALTER SYSTEM ARCHIVE LOG CURRENT;
  ALTER SYSTEM SWITCH LOGFILE;
  ```

#### 5) Check di coerenza finale

```rman
REPORT NEED BACKUP;
REPORT OBSOLETE;
```

Se il job resta **FAILED**, cattura:
1) output RMAN completo  
2) alert log  
3) query da `v$rman_status`

---

### B) Restore quando NON esistono backup RMAN

> Se **non esiste alcun backup RMAN**, il ripristino tradizionale non è possibile.  
> Si procede con **alternative di resilienza**.

#### 1) Verifica rapida: davvero non c’è backup?

```rman
LIST BACKUP SUMMARY;
CROSSCHECK BACKUP;
CATALOG START WITH '<path_backup>';
```

Se resta vuoto, passa alle opzioni sotto.

#### 2) Opzione 1 — Flashback Database (se abilitato)

```sql
SELECT flashback_on FROM v$database;
```

```sql
FLASHBACK DATABASE TO RESTORE POINT <rp_name>;
-- oppure
FLASHBACK DATABASE TO TIME "TO_DATE('2024-01-15 10:00:00','YYYY-MM-DD HH24:MI:SS')";
```

Poi:

```sql
ALTER DATABASE OPEN RESETLOGS;
```

#### 3) Opzione 2 — Standby / Data Guard

- Esegui **failover** verso standby se disponibile.
- In alternativa, **DUPLICATE FROM ACTIVE DATABASE** (serve DB primario attivo).

```rman
DUPLICATE TARGET DATABASE TO newdb FROM ACTIVE DATABASE;
```

#### 4) Opzione 3 — Snapshot storage / SAN / VM

Ripristina il volume da snapshot e avvia recovery da redo disponibili (se presenti).

#### 5) Opzione 4 — Ricostruzione logica

Se non c’è alternativa:
- ripristina schema/app da **export/data pump**
- ricrea i dati critici da applicazioni o sorgenti esterne

---

## Validazione finale

- Il database è **OPEN** e accessibile
- Le applicazioni riescono a connettersi
- Non ci sono errori RMAN/ORA ricorrenti in alert log

## Troubleshooting rapido

- **Backup falliti senza log RMAN**: avvia RMAN con `tee` per catturare output
- **Catalog mismatch**: `RESYNC CATALOG` + `CROSSCHECK`
- **FRA piena**: libera spazio con `DELETE OBSOLETE` dopo verifica retention
