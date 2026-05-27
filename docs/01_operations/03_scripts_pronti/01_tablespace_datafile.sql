-- ============================================================================
-- SCRIPT 01: TABLESPACE E DATAFILE — Diagnosi e Risoluzione Completa
-- Scenario: Tablespace pieno, resize, maxsize, bigfile vs smallfile
-- Errori coperti: ORA-01654, ORA-01653, ORA-01658, ORA-01652
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/06_TABLESPACE_PIENO.md
--   - ../02_runbooks_incidenti/12_CAPACITY_PLANNING_LIMITI.md
--   - ../02_runbooks_incidenti/08_ORA_ERRORS.md
-- Uso rapido:
--   sqlplus / as sysdba @01_tablespace_datafile.sql
-- Nota: verificare sempre ambiente, ruolo database e privilegi prima di eseguire azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. PANORAMICA TABLESPACE (uso % con MAXSIZE reale)
PROMPT ====================================================================

-- Questa query mostra l'uso REALE considerando il MAXSIZE, non solo lo spazio allocato.
-- È la query più importante: un tablespace può sembrare al 50% ma se il maxsize
-- è vicino al bytes allocato, sei in pericolo.

COL tablespace_name FOR A25
COL contents FOR A10
COL status FOR A9
COL used_gb FOR 999,999.99
COL alloc_gb FOR 999,999.99
COL max_gb FOR 999,999.99
COL pct_of_max FOR 999.9
COL autoext FOR A7

SELECT
    t.tablespace_name,
    t.contents,
    t.bigfile,
    t.status,
    ROUND(alloc.alloc_bytes/1024/1024/1024, 2) AS alloc_gb,
    ROUND((alloc.alloc_bytes - NVL(f.free_bytes, 0))/1024/1024/1024, 2) AS used_gb,
    ROUND(alloc.max_bytes/1024/1024/1024, 2) AS max_gb,
    ROUND((alloc.alloc_bytes - NVL(f.free_bytes, 0)) * 100 /
          NULLIF(alloc.max_bytes, 0), 1) AS pct_of_max,
    alloc.autoext
FROM dba_tablespaces t
JOIN (
    SELECT tablespace_name, SUM(bytes) AS alloc_bytes,
           SUM(CASE WHEN maxbytes = 0 THEN bytes ELSE maxbytes END) AS max_bytes,
           CASE WHEN SUM(CASE WHEN autoextensible = 'YES' THEN 1 ELSE 0 END) > 0 THEN 'YES' ELSE 'NO' END AS autoext
    FROM (
        SELECT tablespace_name, bytes, maxbytes, autoextensible FROM dba_data_files
        UNION ALL
        SELECT tablespace_name, bytes, maxbytes, autoextensible FROM dba_temp_files
    )
    GROUP BY tablespace_name
) alloc ON t.tablespace_name = alloc.tablespace_name
LEFT JOIN (
    SELECT tablespace_name, SUM(free_bytes) AS free_bytes
    FROM (
        SELECT tablespace_name, bytes AS free_bytes FROM dba_free_space
        UNION ALL
        SELECT tablespace_name, free_space AS free_bytes FROM dba_temp_free_space
    )
    GROUP BY tablespace_name
) f ON alloc.tablespace_name = f.tablespace_name
ORDER BY pct_of_max DESC NULLS LAST;


PROMPT ====================================================================
PROMPT  2. DETTAGLIO DATAFILE (ogni file con autoextend, maxsize)
PROMPT ====================================================================

COL file_name FOR A70
COL tbs FOR A25
COL size_gb FOR 999,999.99
COL max_gb FOR 999,999.99
COL autoext FOR A7
COL pct_used FOR 999.9

SELECT
    d.tablespace_name AS tbs,
    d.file_name,
    ROUND(d.bytes/1024/1024/1024, 2) AS size_gb,
    ROUND(CASE WHEN d.maxbytes = 0 THEN d.bytes ELSE d.maxbytes END /1024/1024/1024, 2) AS max_gb,
    d.autoextensible AS autoext,
    d.file_id
FROM dba_data_files d
ORDER BY d.tablespace_name, d.file_id;


PROMPT ====================================================================
PROMPT  3. BIGFILE vs SMALLFILE — Limiti fisici (IMPORTANTE!)
PROMPT ====================================================================

-- LIMITI FISICI Oracle:
-- SMALLFILE tablespace: max 1023 datafile, ogni datafile max 32GB (block 8K) = ~32TB teorico
-- BIGFILE tablespace: 1 solo datafile, max 32TB (block 8K) o 128TB (block 32K)
--
-- ⚠️ ATTENZIONE al MAXBYTES default:
-- Se crei un datafile con AUTOEXTEND ON senza specificare MAXSIZE:
--   SMALLFILE: maxbytes = 34359738368 (32GB)
--   BIGFILE:   maxbytes = 35184372064256 (32TB)
--
-- Il "gap" è la differenza fra maxbytes e bytes attuali = quanto puoi ancora crescere.

COL tablespace_name FOR A25
COL bigfile FOR A7
COL num_files FOR 999
COL actual_gb FOR 999,999.99
COL maxbytes_gb FOR 999,999.99
COL remaining_gb FOR 999,999.99

SELECT
    t.tablespace_name,
    t.bigfile,
    COUNT(d.file_id) AS num_files,
    ROUND(SUM(d.bytes)/1024/1024/1024, 2) AS actual_gb,
    ROUND(SUM(d.maxbytes)/1024/1024/1024, 2) AS maxbytes_gb,
    ROUND(SUM(d.maxbytes - d.bytes)/1024/1024/1024, 2) AS remaining_gb
FROM dba_tablespaces t
JOIN dba_data_files d ON t.tablespace_name = d.tablespace_name
GROUP BY t.tablespace_name, t.bigfile
ORDER BY remaining_gb ASC;


PROMPT ====================================================================
PROMPT  4. TABLESPACE CRITICI (> 85% del MAXSIZE)
PROMPT ====================================================================

SELECT tablespace_name, ROUND(used_percent, 1) AS pct_used
FROM dba_tablespace_usage_metrics
WHERE used_percent > 85
ORDER BY used_percent DESC;


PROMPT ====================================================================
PROMPT  5. SOLUZIONI — Comandi per risolvere tablespace pieno
PROMPT ====================================================================

-- ---- 5A. RIDIMENSIONA DATAFILE ESISTENTE ----
-- ALTER DATABASE DATAFILE '/path/to/file.dbf' RESIZE 20G;

-- ---- 5B. ABILITA AUTOEXTEND ----
-- ALTER DATABASE DATAFILE '/path/to/file.dbf' AUTOEXTEND ON MAXSIZE 30G;

-- ---- 5C. AGGIUNGI DATAFILE (SMALLFILE) ----
-- ALTER TABLESPACE USERS ADD DATAFILE '+DATA' SIZE 10G AUTOEXTEND ON MAXSIZE 30G;

-- ---- 5D. RIDIMENSIONA BIGFILE ----
-- ALTER DATABASE DATAFILE '+DATA/RACDB/datafile/users.dbf' RESIZE 500G;

-- ---- 5E. CONVERTI SMALLFILE → BIGFILE (solo tablespace vuoto!) ----
-- Per tablespace con dati, devi creare un nuovo bigfile TBS e spostare gli oggetti.
-- CREATE BIGFILE TABLESPACE USERS_BIG DATAFILE '+DATA' SIZE 100G AUTOEXTEND ON MAXSIZE 10T;
-- ALTER TABLE schema.tabella MOVE TABLESPACE USERS_BIG;


PROMPT ====================================================================
PROMPT  6. GENERA COMANDI AUTOEXTEND MAXSIZE (per bigfile con default 32TB)
PROMPT ====================================================================

-- Questo script genera i comandi ALTER per impostare un maxsize ragionevole
-- sui bigfile tablespace che hanno il maxsize default di 32TB.

COL comando FOR A120
SELECT
    'ALTER TABLESPACE ' || a.tablespace_name ||
    ' AUTOEXTEND ON MAXSIZE ' ||
    NVL(TRUNC(SUM(a.bytes) * 170 / 100), 10737418240) || ';' AS comando,
    b.bigfile,
    SUM(a.bytes) AS actual_space,
    a.maxbytes
FROM dba_data_files a
JOIN dba_tablespaces b ON a.tablespace_name = b.tablespace_name
WHERE a.maxbytes = 35184372064256   -- default bigfile 32TB
  AND b.bigfile = 'YES'
GROUP BY a.tablespace_name, b.bigfile, a.maxbytes;


PROMPT ====================================================================
PROMPT  7. CONTENUTO TABLESPACE — Chi sta occupando spazio
PROMPT ====================================================================

COL owner FOR A20
COL segment_name FOR A35
COL segment_type FOR A20
COL size_mb FOR 999,999.99

-- Sostituisci &TBS_NAME con il nome del tablespace problematico
SELECT owner, segment_name, segment_type,
       ROUND(bytes/1024/1024, 2) AS size_mb
FROM dba_segments
WHERE tablespace_name = UPPER('&TBS_NAME')
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT ====================================================================
PROMPT  Fine Script 01 — Tablespace & Datafile
PROMPT ====================================================================
