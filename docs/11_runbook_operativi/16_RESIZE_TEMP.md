# 16 — Resize TEMP (Tempfile) in Sicurezza

> ⏱️ Tempo: 10-20 minuti | 📅 Frequenza: Su alert | 👤 Chi: DBA on-call
> **Scenario tipico**: `ORA-01652`, sort su disco, TEMP al 95-100%.

---

## Step 1: Diagnosi rapida (chi usa TEMP)

```sql
sqlplus / as sysdba

SELECT tablespace_name,
       ROUND(tablespace_size * 8192 / 1024 / 1024 / 1024, 2) AS total_gb,
       ROUND(allocated_space * 8192 / 1024 / 1024 / 1024, 2) AS used_gb,
       ROUND(free_space * 8192 / 1024 / 1024 / 1024, 2) AS free_gb,
       ROUND(allocated_space * 100 / NULLIF(tablespace_size, 0), 1) AS pct_used
FROM dba_temp_free_space;
```

```sql
SELECT s.sid, s.serial#, s.username, s.program, s.sql_id,
       ROUND(t.blocks * 8192 / 1024 / 1024, 2) AS temp_mb
FROM v$sort_usage t
JOIN v$session s ON s.saddr = t.session_addr
ORDER BY t.blocks DESC;
```

---

## Step 2: Verifica configurazione tempfile

```sql
SELECT file_id, file_name,
       ROUND(bytes/1024/1024) AS size_mb,
       ROUND(maxbytes/1024/1024) AS max_mb,
       autoextensible
FROM dba_temp_files
ORDER BY file_id;
```

---

## Step 3: Azioni consigliate (ordine)

### 3A) Abilita autoextend (se disabilitato)

```sql
ALTER DATABASE TEMPFILE '&tempfile_name'
  AUTOEXTEND ON NEXT 512M MAXSIZE 32G;
```

### 3B) Aggiungi un nuovo tempfile (fix più sicuro)

```sql
-- RAC/ASM
ALTER TABLESPACE TEMP
  ADD TEMPFILE '+DATA' SIZE 4G AUTOEXTEND ON NEXT 512M MAXSIZE 32G;

-- Filesystem
-- ALTER TABLESPACE TEMP
--   ADD TEMPFILE '/u02/oradata/RACDB/temp02.dbf' SIZE 4G AUTOEXTEND ON NEXT 512M MAXSIZE 32G;
```

### 3C) Resize di un tempfile esistente

```sql
ALTER DATABASE TEMPFILE '&tempfile_name' RESIZE 8G;
```

> Nota: resize in aumento è immediato. Riduzione richiede che lo spazio in coda sia libero.

---

## Step 4: Riduzione TEMP (quando serve davvero)

```sql
-- Strategia raccomandata: crea TEMP2, switch, drop TEMP vecchio
CREATE TEMPORARY TABLESPACE TEMP2 TEMPFILE '+DATA' SIZE 4G AUTOEXTEND ON NEXT 512M MAXSIZE 32G;
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP2;

-- verifica che nessuna sessione usi TEMP vecchio, poi:
DROP TABLESPACE TEMP INCLUDING CONTENTS AND DATAFILES;

CREATE TEMPORARY TABLESPACE TEMP TEMPFILE '+DATA' SIZE 4G AUTOEXTEND ON NEXT 512M MAXSIZE 32G;
ALTER DATABASE DEFAULT TEMPORARY TABLESPACE TEMP;
DROP TABLESPACE TEMP2 INCLUDING CONTENTS AND DATAFILES;
```

---

## Step 5: Validazione finale

```sql
SELECT tablespace_name,
       ROUND(allocated_space * 100 / NULLIF(tablespace_size, 0), 1) AS pct_used
FROM dba_temp_free_space;
```

```sql
SELECT file_name, autoextensible,
       ROUND(bytes/1024/1024) AS size_mb,
       ROUND(maxbytes/1024/1024) AS max_mb
FROM dba_temp_files;
```

**Atteso**:
- `pct_used` TEMP sotto soglia operativa (tipicamente < 85%)
- autoextend coerente con policy
- nessun nuovo `ORA-01652`

---

## Rollback / piano di rientro

- Se aggiungi tempfile: puoi rimuoverlo a caldo dopo normalizzazione carico.
- Se hai usato TEMP2: torna alla configurazione originale e rimuovi TEMP2.
- Documenta sempre SQL_ID e sessioni principali che saturavano TEMP.
