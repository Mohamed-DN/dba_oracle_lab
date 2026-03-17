. /vagrant_config/install_standby.env

echo "******************************************************************************"
echo "Configure TNSNAMES for RMAN Duplicate."
echo "******************************************************************************"
# Primary Unique Name is hardcoded since env uses RACDB_STBY
PRIMARY_UNIQUE_NAME="RACDB"
PRIMARY_PUBLIC_IP="192.168.56.101"

cat >> ${GRID_HOME}/network/admin/tnsnames.ora <<EOF
${PRIMARY_UNIQUE_NAME} =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${PRIMARY_UNIQUE_NAME}.localdomain)
    )
  )
EOF

cat >> ${ORACLE_HOME}/network/admin/tnsnames.ora <<EOF
${PRIMARY_UNIQUE_NAME} =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ${PRIMARY_UNIQUE_NAME}.localdomain)
    )
  )
EOF

echo "******************************************************************************"
echo "Create Standby Parameter File and start NOMOUNT."
echo "******************************************************************************"

cat > /tmp/init${NODE1_ORACLE_SID}.ora <<EOF
DB_NAME=${PRIMARY_UNIQUE_NAME}
DB_UNIQUE_NAME=${ORACLE_UNQNAME}
EOF

# Create standard directories
mkdir -p ${ORACLE_BASE}/admin/${ORACLE_UNQNAME}/adump

sqlplus / as sysdba <<EOF
startup nomount pfile='/tmp/init${NODE1_ORACLE_SID}.ora';
exit;
EOF

echo "******************************************************************************"
echo "Executing RMAN Duplicate For Standby from Active Database."
echo "******************************************************************************"

rman target sys/${SYS_PASSWORD}@${PRIMARY_UNIQUE_NAME} auxiliary sys/${SYS_PASSWORD} <<EOF
run {
  allocate channel prmy1 type disk;
  allocate channel prmy2 type disk;
  allocate auxiliary channel stby1 type disk;
  allocate auxiliary channel stby2 type disk;
  duplicate target database for standby from active database
  spfile
    parameter_value_convert '${PRIMARY_UNIQUE_NAME}','${ORACLE_UNQNAME}'
    set db_name='${PRIMARY_UNIQUE_NAME}'
    set db_unique_name='${ORACLE_UNQNAME}'
    set cluster_database='true'
    set control_files='+DATA'
    set db_create_file_dest='+DATA'
    set db_recovery_file_dest='+RECO'
    set log_archive_dest_1='location=USE_DB_RECOVERY_FILE_DEST valid_for=(ALL_LOGFILES,ALL_ROLES) db_unique_name=${ORACLE_UNQNAME}'
  nofilenamecheck;
}
exit;
EOF

echo "******************************************************************************"
echo "Registering Standby Database in Clusterware."
echo "******************************************************************************"

srvctl add database -db ${ORACLE_UNQNAME} -oraclehome ${ORACLE_HOME} -dbtype RAC -role PHYSICAL_STANDBY -startoption mount -stopoption immediate
srvctl add instance -db ${ORACLE_UNQNAME} -instance ${NODE1_ORACLE_SID} -node ${NODE1_HOSTNAME}
srvctl add instance -db ${ORACLE_UNQNAME} -instance ${NODE2_ORACLE_SID} -node ${NODE2_HOSTNAME}

echo "******************************************************************************"
echo "Starting MRP (Managed Recovery Process)."
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
exit;
EOF

srvctl status database -d ${ORACLE_UNQNAME}
