-- ============================================================================
-- SCRIPT 12: Log Purge (FRA + Unified Audit)
-- Scenario: spazio log in crescita, audit trail troppo grande
-- ============================================================================

PROMPT ====================================================================
PROMPT  1. STATO FRA
PROMPT ====================================================================

COL fra_limit_gb FOR 999.99
COL fra_used_gb FOR 999.99
COL reclaimable_gb FOR 999.99

SELECT ROUND(space_limit/1024/1024/1024,2) AS fra_limit_gb,
       ROUND(space_used/1024/1024/1024,2) AS fra_used_gb,
       ROUND(space_reclaimable/1024/1024/1024,2) AS reclaimable_gb
FROM v$recovery_file_dest;

PROMPT ====================================================================
PROMPT  2. PREPARA CLEANUP UNIFIED AUDIT (ULTIMI 30 GIORNI)
PROMPT ====================================================================

BEGIN
  DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(
    audit_trail_type  => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    last_archive_time => SYSTIMESTAMP - INTERVAL '30' DAY
  );
END;
/

BEGIN
  DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
    audit_trail_type        => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    use_last_arch_timestamp => TRUE
  );
END;
/

PROMPT ====================================================================
PROMPT  3. VERIFICA EVENTI AUDIT RECENTI
PROMPT ====================================================================

COL dbusername FOR A20
COL action_name FOR A25
COL event_timestamp FOR A30

SELECT event_timestamp, dbusername, action_name, return_code
FROM unified_audit_trail
ORDER BY event_timestamp DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT ====================================================================
PROMPT  NOTE RMAN/ADRCI
PROMPT ====================================================================

PROMPT Eseguire da shell/rman:
PROMPT   RMAN> CROSSCHECK ARCHIVELOG ALL;
PROMPT   RMAN> DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
PROMPT   RMAN> DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;
PROMPT   ADRCI> purge -age 604800 -type trace

PROMPT ====================================================================
PROMPT  Fine Script 12 — Log Purge
PROMPT ====================================================================
