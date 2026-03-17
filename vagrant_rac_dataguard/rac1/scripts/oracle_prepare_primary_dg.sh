. /vagrant_config/install_primary.env

echo "******************************************************************************"
echo "Switching database to ARCHIVELOG and FORCE LOGGING."
echo "******************************************************************************"

srvctl stop database -d ${ORACLE_UNQNAME}

sqlplus / as sysdba <<EOF
startup mount;
alter database archivelog;
alter database force logging;
alter system set log_archive_dest_1='location=USE_DB_RECOVERY_FILE_DEST valid_for=(ALL_LOGFILES,ALL_ROLES) db_unique_name=${ORACLE_UNQNAME}' scope=both;
alter database open;
EOF

echo "******************************************************************************"
echo "Creating Standby Redo Logs on Primary."
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 SIZE 200M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 SIZE 200M;
exit;
EOF

srvctl status database -d ${ORACLE_UNQNAME}
