#!/bin/bash
# install_grid.sh

# This script is intended to be run as root or grid (switches inside)
# Usage: ./install_grid.sh

# 1. Unzip binaries (Run as grid)
if [ ! -d "/u01/app/19.0.0/grid/bin" ]; then
  echo "Unzipping Grid Binaries..."
  su - grid -c "unzip -q /vagrant/software/LINUX.X64_193000_grid_home.zip -d /u01/app/19.0.0/grid"
fi

# 2. Install cvuqdisk (Run as root)
rpm -ivh /u01/app/19.0.0/grid/cv/rpm/cvuqdisk-1.0.10-1.rpm

# 3. Create Response File
cat > /home/grid/grid_install.rsp <<EOF
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0
INVENTORY_LOCATION=/u01/app/oraInventory
oracle.install.option=CRS_CONFIG
ORACLE_BASE=/u01/app/grid
ORACLE_HOME=/u01/app/19.0.0/grid
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.gpnp.scanName=rac-scan
oracle.install.crs.config.gpnp.scanPort=1521
oracle.install.crs.config.clusterName=rac-cluster
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.clusterNodes=rac1:rac1-vip,rac2:rac2-vip
oracle.install.crs.config.networkInterfaceList=eth1:192.168.56.0:1,eth2:192.168.10.0:2
oracle.install.crs.config.storageOption=FLEX_ASM_STORAGE
oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ignoreConfiguration=false
oracle.install.crs.config.clusterType=STANDARD
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.storage.diskGroup.name=DATA
oracle.install.crs.config.storage.diskGroup.redundancy=EXTERNAL
oracle.install.crs.config.storage.diskGroup.diskList=/dev/oracleasm/disks/DATA1,/dev/oracleasm/disks/DATA2
EOF

chown grid:oinstall /home/grid/grid_install.rsp

echo "Response file created at /home/grid/grid_install.rsp"
echo "Now run the following command as GRID user to install:"
echo "/u01/app/19.0.0/grid/gridSetup.sh -silent -responseFile /home/grid/grid_install.rsp -ignorePrereq"
