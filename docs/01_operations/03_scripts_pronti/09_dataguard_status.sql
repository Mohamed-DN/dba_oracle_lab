-- ============================================================================
-- SCRIPT 09: DATA GUARD STATUS
-- Scenario: morning check, pre-switchover, troubleshooting lag
-- Uso: sqlplus / as sysdba @09_dataguard_status.sql
-- ============================================================================

-- Runbook:
--   - ../02_runbooks_incidenti/RUNBOOK_03_CHECK_DATAGUARD.md
--   - ../02_runbooks_incidenti/RUNBOOK_14_CHAOS_NETWORK_PARTITION_DATAGUARD.md
--   - ../02_runbooks_incidenti/RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md
--
-- Leggere sempre DATABASE_ROLE prima di interpretare l'output.
-- V$ARCHIVE_GAP e' significativo sullo STANDBY.
-- Le query sono read-only: non eseguono correzioni.

SET LINESIZE 240
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. RUOLO E STATO DATABASE
PROMPT ====================================================================

COL db_unique_name FOR A24
COL database_role FOR A20
COL open_mode FOR A22
COL protection_mode FOR A25
COL switchover_status FOR A22

SELECT db_unique_name, database_role, open_mode,
       protection_mode, switchover_status
FROM v$database;

PROMPT ====================================================================
PROMPT  2. LAG - INTERPRETARE SULLO STANDBY
PROMPT ====================================================================

COL name FOR A30
COL value FOR A30
COL unit FOR A20
COL time_computed FOR A22

SELECT name, value, unit,
       TO_CHAR(time_computed, 'DD-MON HH24:MI:SS') AS time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag', 'apply finish time');

PROMPT ====================================================================
PROMPT  3. DESTINAZIONI REDO - INTERPRETARE SUL PRIMARY
PROMPT ====================================================================

COL dest_name FOR A24
COL status FOR A12
COL target FOR A12
COL destination FOR A42
COL error FOR A50

SELECT inst_id, dest_id, dest_name, status, target, destination, error
FROM gv$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY inst_id, dest_id;

PROMPT ====================================================================
PROMPT  4. GAP - ESEGUIRE E INTERPRETARE SULLO STANDBY
PROMPT ====================================================================

COL low_sequence FOR 999999999
COL high_sequence FOR 999999999

SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;

PROMPT Nessuna riga sullo standby = nessun gap noto.
PROMPT Se ci sono righe, preservare le sequence e seguire il runbook DG-062.

PROMPT ====================================================================
PROMPT  5. PROCESSI REDO APPLY - INTERPRETARE SULLO STANDBY
PROMPT ====================================================================

COL process FOR A10
COL status FOR A20
COL thread# FOR 999
COL sequence# FOR 999999999
COL block# FOR 999999999

SELECT inst_id, process, status, thread#, sequence#, block#
FROM gv$managed_standby
WHERE process IN ('MRP0', 'RFS', 'ARCH', 'LNS')
ORDER BY inst_id, process;

PROMPT MRP0 APPLYING_LOG o WAIT_FOR_LOG = apply operativo.

PROMPT ====================================================================
PROMPT  6. SEQUENCE GENERATE O APPLICATE - DIPENDE DAL RUOLO
PROMPT ====================================================================

SELECT thread#,
       MAX(sequence#) AS max_sequence,
       MAX(CASE WHEN applied = 'YES' THEN sequence# END) AS max_applied
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

PROMPT Sul primary osservare MAX_SEQUENCE. Sullo standby confrontare MAX_APPLIED.

PROMPT ====================================================================
PROMPT  7. DEST STATUS - INTERPRETARE SUL PRIMARY
PROMPT ====================================================================

COL type FOR A15
COL database_mode FOR A18
COL recovery_mode FOR A22
COL gap_status FOR A18

SELECT inst_id, dest_id, type, status, database_mode, recovery_mode, gap_status
FROM gv$archive_dest_status
WHERE status <> 'INACTIVE'
ORDER BY inst_id, dest_id;

PROMPT ====================================================================
PROMPT  8. SWITCHOVER READINESS
PROMPT ====================================================================

SELECT switchover_status FROM v$database;

PROMPT TO STANDBY = primary pronto.
PROMPT TO PRIMARY = standby pronto.
PROMPT NOT ALLOWED = verificare lag, gap, MRP e Broker.

PROMPT ====================================================================
PROMPT  Fine Script 09 - Data Guard Status
PROMPT ====================================================================
