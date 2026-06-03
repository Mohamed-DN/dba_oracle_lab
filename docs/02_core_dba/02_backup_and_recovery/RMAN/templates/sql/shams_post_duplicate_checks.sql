SET LINES 240 PAGES 500 TRIMSPOOL ON
COL name FORMAT A18
COL db_unique_name FORMAT A18
COL open_mode FORMAT A22
COL database_role FORMAT A20
COL value FORMAT A90
COL process FORMAT A10
COL status FORMAT A22
COL error FORMAT A90

PROMPT == STANDBY ROLE ==
SELECT name, db_unique_name, database_role, open_mode, switchover_status
FROM v$database;

PROMPT == SPFILE ==
SHOW PARAMETER spfile

PROMPT == APPLY PROCESSES ==
SELECT process, status, thread#, sequence#, block#
FROM v$managed_standby
ORDER BY process, thread#;

PROMPT == DATAGUARD STATS ==
SELECT name, value, unit
FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');

PROMPT == ARCHIVE GAP ==
SELECT * FROM v$archive_gap;

PROMPT == RECEIVED VS APPLIED ==
WITH received AS (
  SELECT thread#, MAX(sequence#) last_received
  FROM v$archived_log
  GROUP BY thread#
),
applied AS (
  SELECT thread#, MAX(sequence#) last_applied
  FROM v$archived_log
  WHERE applied = 'YES'
  GROUP BY thread#
)
SELECT r.thread#, r.last_received, a.last_applied,
       r.last_received - NVL(a.last_applied, 0) AS sequence_gap
FROM received r
LEFT JOIN applied a ON a.thread# = r.thread#
ORDER BY r.thread#;

PROMPT == ARCHIVE DEST ERRORS ==
SELECT dest_id, status, db_unique_name, error
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;
