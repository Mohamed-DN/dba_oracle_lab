# 06 — Tablespace Pieno

> ⏱️ Tempo: 5-15 minuti | 📅 Frequenza: Su alert | 👤 Chi: DBA on-call
> **Scenario tipico**: Alert "Tablespace USERS al 95%!" oppure ORA-01653/ORA-01654

---

## Step 1: Verifica la Situazione

```sql
sqlplus / as sysdba

-- Tutti i tablespace con percentuale uso
SELECT tablespace_name,
       ROUND(used_space * 8192 / 1024 / 1024) AS used_mb,
       ROUND(tablespace_size * 8192 / 1024 / 1024) AS total_mb,
       ROUND(used_percent, 1) AS pct_used
FROM dba_tablespace_usage_metrics
ORDER BY used_percent DESC;
```

```sql
-- Dettaglio datafile del tablespace pieno
SELECT file_name, file_id,
       ROUND(bytes/1024/1024) AS size_mb,
       ROUND(maxbytes/1024/1024) AS max_mb,
       autoextensible
FROM dba_data_files
WHERE tablespace_name = '&TABLESPACE_NAME'
ORDER BY file_name;
```

## Step 2: Chi Sta Consumando Spazio?

```sql
-- Top 20 segmenti per dimensione nel tablespace
SELECT owner, segment_name, segment_type,
       ROUND(bytes/1024/1024) AS mb
FROM dba_segments
WHERE tablespace_name = '&TABLESPACE_NAME'
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;
```

```sql
-- Crescita recente (se disponibile da AWR)
SELECT TO_CHAR(snap_time, 'DD-MON') AS day,
       tablespace_name,
       ROUND(tablespace_size/1024/1024) AS total_mb,
       ROUND(tablespace_usedsize/1024/1024) AS used_mb
FROM dba_hist_tbspc_space_usage h
JOIN v$tablespace t ON h.tablespace_id = t.ts#
WHERE t.name = '&TABLESPACE_NAME'
ORDER BY snap_time DESC
FETCH FIRST 14 ROWS ONLY;
```

## Step 3: Risolvere — Ordine di Priorità

### 3A. Abilita Autoextend (se non attivo)

```sql
-- Abilita autoextend su datafile esistente
ALTER DATABASE DATAFILE '&file_name'
    AUTOEXTEND ON NEXT 100M MAXSIZE 32G;
```

### 3B. Aggiungi Datafile (soluzione più comune)

```sql
-- Per ASM (lab RAC)
ALTER TABLESPACE &TABLESPACE_NAME
    ADD DATAFILE '+DATA' SIZE 1G AUTOEXTEND ON NEXT 100M MAXSIZE 32G;

-- Per filesystem
ALTER TABLESPACE &TABLESPACE_NAME
    ADD DATAFILE '/u01/app/oracle/oradata/RACDB/&ts_new.dbf'
    SIZE 1G AUTOEXTEND ON NEXT 100M MAXSIZE 32G;
```

### 3C. Recupera Spazio (se c'è spazio reclaimabile)

```sql
-- Svuota cestino Oracle
PURGE DBA_RECYCLEBIN;

-- Shrink segmenti frammentati (solo ASSM tablespace)
ALTER TABLE &owner.&table_name ENABLE ROW MOVEMENT;
ALTER TABLE &owner.&table_name SHRINK SPACE CASCADE;
ALTER TABLE &owner.&table_name DISABLE ROW MOVEMENT;

-- Resize datafile (se c'è spazio libero alla fine del file)
-- Prima trova lo spazio recuperabile:
SELECT file_id, file_name,
       ROUND(bytes/1024/1024) AS current_mb,
       CEIL((NVL(hwm,1) * 8192) / 1024 / 1024) AS min_mb
FROM dba_data_files df,
     (SELECT file_id, MAX(block_id + blocks - 1) AS hwm
      FROM dba_extents
      GROUP BY file_id) e
WHERE df.file_id = e.file_id(+)
  AND df.tablespace_name = '&TABLESPACE_NAME';

-- Poi riduci:
ALTER DATABASE DATAFILE '&file_name' RESIZE &new_size_mb M;
```

## Step 4: TEMP Tablespace Pieno

```sql
-- Se il problema è il TEMP:
SELECT tablespace_name,
       ROUND(tablespace_size/1024/1024) AS total_mb,
       ROUND(allocated_space/1024/1024) AS used_mb,
       ROUND(free_space/1024/1024) AS free_mb
FROM dba_temp_free_space;

-- Chi sta usando TEMP?
SELECT s.sid, s.serial#, s.username, s.program,
       t.blocks * 8192 / 1024 / 1024 AS temp_mb,
       s.sql_id
FROM v$sort_usage t
JOIN v$session s ON t.session_addr = s.saddr
ORDER BY t.blocks DESC;

-- Aggiungi tempfile
ALTER TABLESPACE TEMP ADD TEMPFILE '+DATA' SIZE 2G AUTOEXTEND ON NEXT 500M;
```

## Step 5: UNDO Tablespace Pieno

```sql
-- Se il problema è UNDO:
SELECT tablespace_name, status, SUM(bytes)/1024/1024 AS mb
FROM dba_undo_extents
GROUP BY tablespace_name, status;
-- STATUS: ACTIVE = in uso, UNEXPIRED = potrebbe servire, EXPIRED = reclaimabile

-- Azioni:
-- 1. Se EXPIRED è grande → Oracle reclamerà automaticamente
-- 2. Aumenta undo_retention se ORA-01555
ALTER SYSTEM SET undo_retention = 3600;  -- 1 ora
-- 3. Aggiungi datafile se necessario
ALTER TABLESPACE UNDOTBS1 ADD DATAFILE '+DATA' SIZE 2G AUTOEXTEND ON;
```

---

## ⚠️ Errori ORA Correlati

| Errore | Causa | Fix |
|---|---|---|
| `ORA-01653` | Tabella non può estendersi | Aggiungi datafile |
| `ORA-01654` | Indice non può estendersi | Aggiungi datafile |
| `ORA-01652` | TEMP pieno | Aggiungi tempfile o kill query |
| `ORA-30036` | UNDO pieno | Aggiungi undo datafile |
| `ORA-19815` | FRA piena | DELETE OBSOLETE in RMAN |

---

## ✅ Check di Conferma

| Controllo | Atteso |
|---|---|
| pct_used | < 85% dopo il fix |
| Autoextend | ON su tutti i datafile |
| Applicazione | Nessun errore ORA-016xx |
