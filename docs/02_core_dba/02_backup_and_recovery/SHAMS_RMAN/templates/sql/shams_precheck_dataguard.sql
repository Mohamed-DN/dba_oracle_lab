SET LINES 240 PAGES 500 TRIMSPOOL ON
COL name FORMAT A18
COL db_unique_name FORMAT A18
COL open_mode FORMAT A22
COL database_role FORMAT A20
COL value FORMAT A90
COL destination FORMAT A70
COL error FORMAT A90

PROMPT == DATABASE IDENTITY ==
SELECT name, dbid, db_unique_name, database_role, open_mode,
       log_mode, force_logging, flashback_on, protection_mode
FROM v$database;

PROMPT == INSTANCE ==
SELECT instance_name, host_name, version, status, database_status
FROM v$instance;

PROMPT == CORE PARAMETERS ==
SELECT name, value
FROM v$parameter
WHERE name IN (
  'db_name',
  'db_unique_name',
  'control_files',
  'db_create_file_dest',
  'db_create_online_log_dest_1',
  'db_create_online_log_dest_2',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'log_archive_config',
  'log_archive_dest_1',
  'log_archive_dest_2',
  'fal_server',
  'standby_file_management',
  'dg_broker_start',
  'wallet_root',
  'tde_configuration'
)
ORDER BY name;

PROMPT == ONLINE REDO ==
SELECT group#, thread#, bytes / 1024 / 1024 AS mb, members, status
FROM v$log
ORDER BY thread#, group#;

PROMPT == STANDBY REDO ==
SELECT group#, thread#, bytes / 1024 / 1024 AS mb, status
FROM v$standby_log
ORDER BY thread#, group#;

PROMPT == ARCHIVE DESTINATIONS ==
SELECT dest_id, status, target, destination, db_unique_name, error
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

PROMPT == TDE WALLET ==
SELECT wrl_type, wrl_parameter, status, wallet_type
FROM v$encryption_wallet;
