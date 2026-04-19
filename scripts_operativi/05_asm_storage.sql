-- ============================================================================
-- SCRIPT 05: ASM STORAGE — Diskgroup, AU_SIZE, Limiti Fisici
-- Scenario: Capacity planning, add disk, check limiti reali
-- ============================================================================

PROMPT ====================================================================
PROMPT  1. PANORAMICA ASM DISKGROUP
PROMPT ====================================================================

COL name FOR A15
COL type FOR A10
COL state FOR A10
COL total_gb FOR 999,999.99
COL free_gb FOR 999,999.99
COL usable_gb FOR 999,999.99
COL pct_used FOR 999.9

SELECT
    name, type, state,
    ROUND(total_mb/1024, 2) AS total_gb,
    ROUND(free_mb/1024, 2) AS free_gb,
    -- Usable = spazio realmente utilizzabile (tiene conto del mirroring)
    ROUND(CASE
        WHEN type = 'EXTERN' THEN free_mb
        WHEN type = 'NORMAL' THEN free_mb / 2
        WHEN type = 'HIGH'   THEN free_mb / 3
    END / 1024, 2) AS usable_gb,
    ROUND((1 - free_mb / NULLIF(total_mb, 0)) * 100, 1) AS pct_used
FROM v$asm_diskgroup
ORDER BY pct_used DESC;


PROMPT ====================================================================
PROMPT  2. DISCHI ASM — Dettaglio per diskgroup
PROMPT ====================================================================

COL disk_name FOR A20
COL dg_name FOR A15
COL path FOR A40
COL total_gb FOR 999.99
COL free_gb FOR 999.99
COL status FOR A10

SELECT
    dg.name AS dg_name,
    d.name AS disk_name,
    d.path,
    ROUND(d.total_mb/1024, 2) AS total_gb,
    ROUND(d.free_mb/1024, 2) AS free_gb,
    d.mode_status AS status
FROM v$asm_disk d
JOIN v$asm_diskgroup dg ON d.group_number = dg.group_number
ORDER BY dg.name, d.name;


PROMPT ====================================================================
PROMPT  3. AU_SIZE E LIMITI FISICI (CRITICO per Capacity Planning!)
PROMPT ====================================================================

-- AU_SIZE (Allocation Unit) determina il limite massimo di un file ASM:
--   AU_SIZE 1MB  → max file = 16TB
--   AU_SIZE 4MB  → max file = 64TB
--   AU_SIZE 16MB → max file = 256TB
--
-- ⚠️ La trap: se hai AU_SIZE=1MB e un bigfile tablespace vicino ai 16TB,
-- non puoi più crescere anche se il diskgroup ha spazio!

COL name FOR A15
COL au_size_mb FOR 999
COL max_file_size_tb FOR 999.9

SELECT
    dg.name,
    dg.allocation_unit_size / 1024 / 1024 AS au_size_mb,
    -- Formula Oracle: max file = AU_SIZE * 4194304 (per extent variabile)
    ROUND(dg.allocation_unit_size * 4194304.0 / 1024/1024/1024/1024, 1) AS max_file_size_tb,
    dg.type
FROM v$asm_diskgroup dg
ORDER BY dg.name;


PROMPT ====================================================================
PROMPT  4. FILE ASM — Dimensione file nel diskgroup
PROMPT ====================================================================

-- Esegui da istanza ASM: sqlplus / as sysasm

COL full_path FOR A60
COL size_gb FOR 999,999.99
COL type FOR A15

SELECT
    CONCAT('+' || gname, SYS_CONNECT_BY_PATH(aname, '/')) AS full_path,
    ROUND(bytes/1024/1024/1024, 2) AS size_gb,
    ftype AS type
FROM (
    SELECT g.name gname, a.parent_index pindex, a.name aname,
           a.reference_index rindex, a.system_generated, a.alias_directory,
           f.bytes, f.type ftype
    FROM v$asm_alias a
    LEFT JOIN v$asm_file f ON a.group_number = f.group_number AND a.file_number = f.file_number
    JOIN v$asm_diskgroup g ON a.group_number = g.group_number
)
WHERE ftype IS NOT NULL
START WITH (MOD(pindex, POWER(2, 24))) = 0
CONNECT BY PRIOR rindex = pindex
ORDER BY size_gb DESC NULLS LAST
FETCH FIRST 20 ROWS ONLY;


PROMPT ====================================================================
PROMPT  5. SOLUZIONI — Aggiungere spazio ASM
PROMPT ====================================================================

-- ---- ADD DISK a diskgroup esistente ----
-- ALTER DISKGROUP DATA ADD DISK '/dev/oracleasm/disk4' NAME data_disk4;
--
-- ---- REBALANCE manuale (se serve accelerare) ----
-- ALTER DISKGROUP DATA REBALANCE POWER 8;  -- da 0 (off) a 11 (max)
--
-- ---- CHECK rebalance in corso ----
-- SELECT * FROM v$asm_operation WHERE group_number = (SELECT group_number FROM v$asm_diskgroup WHERE name = 'DATA');

PROMPT ====================================================================
PROMPT  Fine Script 05 — ASM Storage
PROMPT ====================================================================
