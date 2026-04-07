# Guida Data Pump (expdp/impdp) — Oracle 19c

> Data Pump è lo strumento standard Oracle per export e import logici di dati. È superiore al vecchio exp/imp in tutto: velocità, parallelismo, filtraggio, rete.

---

## 1. Teoria: Data Pump vs Vecchio exp/imp

| Aspetto | exp/imp (vecchio) | expdp/impdp (Data Pump) |
|---------|-------------------|------------------------|
| Velocità | Lento (single thread) | Parallelo (PARALLEL=N) |
| Formato file | Proprietario .dmp | Proprietario .dmp (diverso!) |
| Filtro | Limitato | WHERE, EXCLUDE, INCLUDE, QUERY |
| Rete | No | Sì (NETWORK_LINK) |
| Compressione | No | Sì (COMPRESSION=ALL) |
| Stima dimensione | No | Sì (ESTIMATE_ONLY) |
| Consistenza | Al momento del commit | SCN-consistent (FLASHBACK_SCN) |

> **Regola**: NON usare mai `exp`/`imp`. Usa SEMPRE `expdp`/`impdp`. Il vecchio formato è deprecato.

---

## 2. Configurazione DIRECTORY

Data Pump richiede un oggetto DIRECTORY Oracle che punta a una cartella sul filesystem del server.

```sql
sqlplus / as sysdba

-- Verifica se esiste già DATA_PUMP_DIR
SELECT directory_name, directory_path FROM dba_directories;
-- Default: DATA_PUMP_DIR → $ORACLE_BASE/admin/$ORACLE_SID/dpdump/

-- Crea una directory custom (opzionale)
CREATE OR REPLACE DIRECTORY DPUMP_DIR AS '/u01/backup/datapump';
GRANT READ, WRITE ON DIRECTORY DPUMP_DIR TO ggadmin;
-- ^^^ L'utente che esegue expdp/impdp deve avere READ,WRITE sulla directory.

-- Sul filesystem Linux:
mkdir -p /u01/backup/datapump
chown oracle:oinstall /u01/backup/datapump
```

---

## 3. Export (expdp) — Scenari Comuni

### 3.1 Export di uno Schema Completo

```bash
expdp system/<password> \
  SCHEMAS=HR \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=hr_export_%U.dmp \
  LOGFILE=hr_export.log \
  PARALLEL=4 \
  COMPRESSION=ALL \
  FILESIZE=2G
# ^^^ SCHEMAS=HR: esporta TUTTO lo schema HR (tabelle, indici, viste, ecc.)
#     %U: genera file multipli (hr_export_01.dmp, hr_export_02.dmp, ...)
#     PARALLEL=4: usa 4 worker paralleli (servono tanti file quanti worker)
#     COMPRESSION=ALL: comprimi dati + metadati (riduce 50-80% lo spazio)
#     FILESIZE=2G: ogni file max 2 GB
```

### 3.2 Export di Tabelle Specifiche

```bash
expdp system/<password> \
  TABLES=HR.EMPLOYEES,HR.DEPARTMENTS \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=hr_tables.dmp \
  LOGFILE=hr_tables.log
```

### 3.3 Export con Filtro WHERE

```bash
expdp system/<password> \
  TABLES=HR.EMPLOYEES \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=hr_emp_filtered.dmp \
  QUERY=HR.EMPLOYEES:'"WHERE department_id = 50"'
# ^^^ Esporta SOLO i dipendenti del dipartimento 50
```

### 3.4 Export Full Database

```bash
expdp system/<password> \
  FULL=Y \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=full_db_%U.dmp \
  LOGFILE=full_db.log \
  PARALLEL=8 \
  COMPRESSION=ALL \
  FILESIZE=4G
# ^^^ FULL=Y: esporta TUTTO il database (tutti gli schemi, tutti gli oggetti)
#     ⚠️ Può generare file enormi in produzione!
```

### 3.5 Export Consistente (per GoldenGate Initial Load)

```bash
# Prendi l'SCN corrente
sqlplus -s / as sysdba <<< "SELECT CURRENT_SCN FROM v\$database;"

expdp ggadmin/<password> \
  SCHEMAS=HR,APP \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=gg_init_%U.dmp \
  FLASHBACK_SCN=3847291 \
  PARALLEL=4
# ^^^ FLASHBACK_SCN: l'export è consistente a QUEL SCN esatto.
#     Tutti i dati riflettono lo stato del database a quell'istante.
#     Fondamentale per GoldenGate, altrimenti potresti avere buchi.
```

### 3.6 Solo Stima (senza esportare)

```bash
expdp system/<password> \
  SCHEMAS=HR \
  ESTIMATE_ONLY=Y
# ^^^ Mostra quanto spazio occuperebbe l'export SENZA farlo.
#     Utile per pianificazione spazio disco.
```

---

## 4. Import (impdp) — Scenari Comuni

### 4.1 Import Standard

```bash
impdp system/<password> \
  SCHEMAS=HR \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=hr_export_%U.dmp \
  LOGFILE=hr_import.log \
  PARALLEL=4
```

### 4.2 Import con REMAP_SCHEMA (Cambia il Nome dello Schema)

```bash
impdp system/<password> \
  REMAP_SCHEMA=HR:HR_TEST \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=hr_export_%U.dmp \
  LOGFILE=hr_remap.log
# ^^^ Importa lo schema HR come HR_TEST.
#     Tutte le tabelle, indici, ecc. finiscono nello schema HR_TEST.
#     Perfetto per creare copie di test senza toccare i dati originali.
```

### 4.3 Import con REMAP_TABLESPACE

```bash
impdp system/<password> \
  SCHEMAS=HR \
  REMAP_TABLESPACE=USERS:TEST_TS \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=hr_export_%U.dmp
# ^^^ Sposta tutti gli oggetti dal tablespace USERS al tablespace TEST_TS.
```

### 4.4 Import con TABLE_EXISTS_ACTION

```bash
impdp system/<password> \
  SCHEMAS=HR \
  TABLE_EXISTS_ACTION=REPLACE \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=hr_export_%U.dmp
# ^^^ TABLE_EXISTS_ACTION controlla cosa fare se la tabella esiste già:
#     SKIP: salta la tabella (default)
#     APPEND: aggiunge le righe (NO: duplicati!)
#     TRUNCATE: svuota la tabella e poi inserisce
#     REPLACE: droppa e ricrea la tabella (la più sicura per refresh)
```

### 4.5 Network Import (senza File Dump!)

```bash
impdp system/<password>@TARGET_DB \
  NETWORK_LINK=SOURCE_DBLINK \
  SCHEMAS=HR \
  PARALLEL=4
# ^^^ NETWORK_LINK: usa un Database Link per importare DIRETTAMENTE
#     dal database source al target, SENZA creare file dump.
#     Il DATA fluisce via rete: source → target.
#     ⚠️ Richiede: CREATE DATABASE LINK prima.
```

```sql
-- Crea il DB Link sul target
CREATE DATABASE LINK SOURCE_DBLINK
  CONNECT TO system IDENTIFIED BY <password>
  USING 'RACDB';
```

---

## 5. Monitoraggio Job Data Pump

```sql
-- Stato dei job Data Pump attivi
SELECT owner_name, job_name, operation, job_mode, state,
       degree, attached_sessions
FROM dba_datapump_jobs
WHERE state = 'EXECUTING';

-- Progresso in percentuale
SELECT opname, target_desc, sofar, totalwork,
       ROUND(sofar/totalwork*100,1) AS pct_done
FROM v$session_longops
WHERE opname LIKE 'DATAPUMP%'
  AND sofar < totalwork;
```

---

## 6. Troubleshooting

| Errore | Causa | Soluzione |
|--------|-------|-----------|
| ORA-39002: invalid operation | Directory non valida | Verifica `dba_directories`, permessi filesystem |
| ORA-39070: unable to open the logfile | No WRITE su directory | `GRANT WRITE ON DIRECTORY` |
| ORA-31626: job does not exist | Job terminato o invalido | Cancella: `DBMS_DATAPUMP.STOP_JOB` |
| ORA-39126: worker unexpected fatal error | Spazio disco pieno | Libera spazio o usa `FILESIZE` |
| Import lento | PARALLEL basso | Aumenta `PARALLEL` e usa `%U` nel dumpfile |

---

## 7. Fonti Oracle Ufficiali

- Data Pump Overview: https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump-overview.html
- expdp Reference: https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump-export-utility.html
- impdp Reference: https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump-import-utility.html
