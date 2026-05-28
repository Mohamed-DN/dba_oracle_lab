-- ============================================================================
-- SCRIPT 05: ASM STORAGE - Diskgroup, AU_SIZE, limiti fisici
-- Scenario: capacity planning, add disk, controllo LUN/path/ASM
-- ============================================================================

-- Runbook/guide collegati:
--   - ../02_runbooks_incidenti/12_CAPACITY_PLANNING_LIMITI.md
--   - ../02_runbooks_incidenti/24_GAP_ANALYSIS_COPERTURA_DBA.md
--   - ../../02_core_dba/01_administration_and_security/GUIDA_STORAGE_LUN_LVM_UDEV_ASM_ASMLIB_AFD.md
-- Uso rapido:
--   sqlplus / as sysasm @05_asm_storage.sql
-- Nota: le viste ASM vanno interrogate da istanza ASM con privilegi SYSASM.
SET LINESIZE 240
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. PANORAMICA ASM DISKGROUP
PROMPT ====================================================================

COL name FOR A15
COL type FOR A10
COL state FOR A12
COL total_gb FOR 999,999.99
COL free_gb FOR 999,999.99
COL usable_gb FOR 999,999.99
COL pct_used FOR 999.9

SELECT
    name,
    type,
    state,
    ROUND(total_mb/1024, 2) AS total_gb,
    ROUND(free_mb/1024, 2) AS free_gb,
    ROUND(CASE
        WHEN type = 'EXTERN' THEN free_mb
        WHEN type = 'NORMAL' THEN free_mb / 2
        WHEN type = 'HIGH' THEN free_mb / 3
        ELSE usable_file_mb
    END / 1024, 2) AS usable_gb,
    ROUND((1 - free_mb / NULLIF(total_mb, 0)) * 100, 1) AS pct_used
FROM v$asm_diskgroup
ORDER BY pct_used DESC;


PROMPT ====================================================================
PROMPT  2. DISCHI ASM - Dettaglio per diskgroup e path
PROMPT ====================================================================

COL disk_name FOR A25
COL dg_name FOR A15
COL path FOR A70
COL total_gb FOR 999,999.99
COL free_gb FOR 999,999.99
COL header_status FOR A15
COL mode_status FOR A12

SELECT
    dg.name AS dg_name,
    d.name AS disk_name,
    d.path,
    ROUND(d.total_mb/1024, 2) AS total_gb,
    ROUND(d.free_mb/1024, 2) AS free_gb,
    d.header_status,
    d.mode_status
FROM v$asm_disk d
JOIN v$asm_diskgroup dg ON d.group_number = dg.group_number
ORDER BY dg.name, d.name;


PROMPT ====================================================================
PROMPT  3. AU_SIZE E LIMITI FISICI
PROMPT ====================================================================

-- AU_SIZE determina il limite massimo teorico di un file ASM.
-- Esempi pratici:
--   AU_SIZE 1MB  -> max file circa 16TB
--   AU_SIZE 4MB  -> max file circa 64TB
--   AU_SIZE 16MB -> max file circa 256TB
-- Se un bigfile tablespace si avvicina al limite, non basta avere spazio libero.

COL au_size_mb FOR 999
COL max_file_size_tb FOR 999,999.9

SELECT
    dg.name,
    dg.allocation_unit_size / 1024 / 1024 AS au_size_mb,
    ROUND(dg.allocation_unit_size * 4194304.0 / 1024/1024/1024/1024, 1) AS max_file_size_tb,
    dg.type
FROM v$asm_diskgroup dg
ORDER BY dg.name;


PROMPT ====================================================================
PROMPT  4. CLIENT ASM - Database/istanze collegate ai diskgroup
PROMPT ====================================================================

COL instance_name FOR A20
COL db_name FOR A15
COL status FOR A12

SELECT group_number, instance_name, db_name, status
FROM v$asm_client
ORDER BY group_number, instance_name;


PROMPT ====================================================================
PROMPT  5. FILE ASM - Top file per dimensione
PROMPT ====================================================================

COL full_path FOR A90
COL size_gb FOR 999,999.99
COL type FOR A18

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
PROMPT  6. OPERAZIONI ASM IN CORSO
PROMPT ====================================================================

COL operation FOR A12
COL state FOR A12
COL est_minutes FOR 999999

SELECT group_number, operation, state, power, actual, sofar, est_work,
       ROUND(est_minutes, 0) AS est_minutes
FROM v$asm_operation
ORDER BY group_number, operation;


PROMPT ====================================================================
PROMPT  7. COMANDI OPERATIVI ASM - esempi
PROMPT ====================================================================

-- Add disk a diskgroup esistente:
-- ALTER DISKGROUP DATA ADD DISK '/dev/oracleasm/disks/DATA04' NAME DATA04;
--
-- Drop disk:
-- ALTER DISKGROUP DATA DROP DISK DATA04;
--
-- Rebalance manuale:
-- ALTER DISKGROUP DATA REBALANCE POWER 8;
--
-- Compatibilita' diskgroup:
-- SELECT name, compatibility, database_compatibility FROM v$asm_diskgroup;
--
-- Verifica path candidati prima di ADD DISK:
-- SELECT path, header_status, mode_status, state, total_mb FROM v$asm_disk ORDER BY path;

PROMPT ====================================================================
PROMPT  Fine Script 05 - ASM Storage
PROMPT ====================================================================
