#!/bin/bash
. /vagrant_config/install_primary.env

echo "******************************************************************************"
echo "Starting Data Guard Broker setup..."
echo "******************************************************************************"

sqlplus / as sysdba <<EOF
ALTER SYSTEM SET dg_broker_start=true scope=both;
exit;
EOF

ssh oracle@${NODE1_HOSTNAME} "sqlplus / as sysdba <<EOF
ALTER SYSTEM SET dg_broker_start=true scope=both;
exit;
EOF"
ssh oracle@${NODE2_HOSTNAME} "sqlplus / as sysdba <<EOF
ALTER SYSTEM SET dg_broker_start=true scope=both;
exit;
EOF"

# Enable broker on Standby instances too
ssh oracle@racstby1 "sqlplus / as sysdba <<EOF
ALTER SYSTEM SET dg_broker_start=true scope=both;
exit;
EOF"
ssh oracle@racstby2 "sqlplus / as sysdba <<EOF
ALTER SYSTEM SET dg_broker_start=true scope=both;
exit;
EOF"

echo "******************************************************************************"
echo "Waiting 30 seconds for Broker processes (DMON) to start globally..."
echo "******************************************************************************"
sleep 30

cat > /tmp/broker_setup.dgmgrl <<EOF
CREATE CONFIGURATION 'rac_dg_config' AS PRIMARY DATABASE IS 'RACDB' CONNECT IDENTIFIER IS 'RACDB';
ADD DATABASE 'RACDB_STBY' AS CONNECT IDENTIFIER IS 'RACDB_STBY' MAINTAINED AS PHYSICAL;
ENABLE CONFIGURATION;
EDIT DATABASE 'RACDB' SET PROPERTY 'LogXptMode'='ASYNC';
EDIT DATABASE 'RACDB_STBY' SET PROPERTY 'LogXptMode'='ASYNC';
SHOW CONFIGURATION;
EOF

dgmgrl sys/${SYS_PASSWORD} @/tmp/broker_setup.dgmgrl

echo "******************************************************************************"
echo "Broker configuration enabled! Use 'dgmgrl /' and 'show configuration' to monitor."
echo "******************************************************************************"
