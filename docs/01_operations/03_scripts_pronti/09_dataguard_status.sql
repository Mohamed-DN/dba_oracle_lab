-- ============================================================================
-- SCRIPT 09: DATA GUARD STATUS
-- Scenario: Morning check, pre-switchover, troubleshooting lag
-- ============================================================================

-- Runbook collegati:
--   - ../02_runbooks_incidenti/03_CHECK_DATAGUARD.md
--   - ../02_runbooks_incidenti/14_CHAOS_NETWORK_PARTITION_DATAGUARD.md
--   - ../02_runbooks_incidenti/22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md
-- Uso rapido:
--   sqlplus / as sysdba @09_dataguard_status.sql
-- Nota: verificare sempre ambiente, ruolo database e privilegi prima di eseguire azioni correttive.
SET LINESIZE 220
SET PAGESIZE 200
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

PROMPT ====================================================================
PROMPT  1. RUOLO DATABASE (Primary o Standby?)
PROMPT ====================================================================

COL db_unique_name FOR A20
COL database_role FOR A20
COL open_mode FOR A20
COL protection_mode FOR A25
COL switchover_status FOR A20

SELECT db_unique_name, database_role, open_mode,
       protection_mode, switchover_status
FROM v$database;


PROMPT ====================================================================
PROMPT  2. DATA GUARD STATS — Transport e Apply Lag
PROMPT ====================================================================

COL name FOR A30
COL value FOR A30
COL time_computed FOR A22

SELECT name, value, TO_CHAR(time_computed, 'DD-MON HH24:MI:SS') AS time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag', 'apply finish time');

-- ⚠️ Se transport lag > 0 → problema di rete o listener standby
-- ⚠️ Se apply lag > qualche minuto → MRP lento o standby sotto carico


PROMPT ====================================================================
PROMPT  3. ARCHIVE DEST — Stato destinazioni
PROMPT ====================================================================

COL dest_name FOR A22
COL status FOR A10
COL target FOR A10
COL destination FOR A40
COL error FOR A40

SELECT dest_name, status, target, destination, error
FROM v$archive_dest
WHERE target IS NOT NULL
  AND status != 'INACTIVE'
ORDER BY dest_id;


PROMPT ====================================================================
PROMPT  4. GAP CHECK — Archivelog mancanti
PROMPT ====================================================================

COL low_sequence FOR 999999
COL high_sequence FOR 999999

SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;

-- Se esce qualcosa → c'è un GAP! Lo standby è indietro.
-- FIX: copia gli archivelog mancanti dal primary e registrali:
-- ALTER DATABASE REGISTER PHYSICAL LOGFILE '/path/to/archN.arc';


PROMPT ====================================================================
PROMPT  5. MRP (Managed Recovery Process) — Sta applicando?
PROMPT ====================================================================

COL process FOR A10
COL status FOR A15
COL thread# FOR 9
COL sequence# FOR 999999
COL block# FOR 9999999

SELECT process, status, thread#, sequence#, block#
FROM v$managed_standby
WHERE process IN ('MRP0', 'RFS', 'ARCH', 'LNS')
ORDER BY process;

-- MRP0 con status APPLYING → lo standby sta applicando → OK
-- Se MRP0 non c'è o è IDLE → lo standby NON sta applicando!


PROMPT ====================================================================
PROMPT  6. SEQUENCE CHECK — Primary vs Standby
PROMPT ====================================================================

-- Sul PRIMARY:
SELECT thread#, MAX(sequence#) AS max_sequence
FROM v$archived_log
WHERE archived = 'YES'
GROUP BY thread#;

-- Sul STANDBY (confronta con sopra):
-- SELECT thread#, MAX(sequence#) AS max_applied
-- FROM v$archived_log WHERE applied = 'YES' GROUP BY thread#;


PROMPT ====================================================================
PROMPT  7. REDO SHIPPING — Transport OK?
PROMPT ====================================================================

COL type FOR A15
COL status FOR A15
COL database_mode FOR A15
COL recovery_mode FOR A15

SELECT type, status, database_mode, recovery_mode
FROM v$archive_dest_status
WHERE type != 'LOCAL'
  AND status != 'INACTIVE';


PROMPT ====================================================================
PROMPT  8. SWITCHOVER READINESS
PROMPT ====================================================================

SELECT switchover_status FROM v$database;

-- TO STANDBY           → Primary pronto per switchover
-- TO PRIMARY            → Standby pronto per diventare primary
-- NOT ALLOWED           → C'è un problema (controlla GAP e MRP)
-- SESSIONS ACTIVE       → Ci sono sessioni connesse (puoi forzare con DISCONNECT SESSION)

PROMPT ====================================================================
PROMPT  Fine Script 09 — Data Guard Status
PROMPT ====================================================================
