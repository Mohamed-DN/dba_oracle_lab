-- Source: https://www.scriptdba.com/installazione-oracle-19-su-oracle-linux-8-in-virtualbox-6/
-- Title: Installazione Oracle 19 su Oracle Linux 8 in VirtualBox 6

Disk /dev/sdc: 20 GiB, 21474836480 bytes, 41943040 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdb: 20 GiB, 21474836480 bytes, 41943040 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdd: 20 GiB, 21474836480 bytes, 41943040 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes

Disk /dev/sdc: 20 GiB, 21474836480 bytes, 41943040 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdb: 20 GiB, 21474836480 bytes, 41943040 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes


Disk /dev/sdd: 20 GiB, 21474836480 bytes, 41943040 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes

fdisk /dev/sdb
n
<Invio>
<Invio>
<Invio>
w

fdisk /dev/sdb
n
<Invio>
<Invio>
<Invio>
w

mkfs.ext4 /dev/sdb1

mkfs.ext4 /dev/sdb1

mount /dev/sdb1 /u01

mount /dev/sdb1 /u01

mkdir /datiDBTEST
mkdir /fraDBTEST

mkdir /datiDBTEST
mkdir /fraDBTEST

vi /etc/fstab

vi /etc/fstab

#FS Oracle
/dev/sdb1 /u01        ext4    defaults        0 0
/dev/sdc1 /datiDBTEST        ext4    defaults        0 0
/dev/sdd1 /fraDBTEST        ext4    defaults        0 0

#FS Oracle
/dev/sdb1 /u01        ext4    defaults        0 0
/dev/sdc1 /datiDBTEST        ext4    defaults        0 0
/dev/sdd1 /fraDBTEST        ext4    defaults        0 0

groupadd dba

groupadd dba

useradd -g dba oracle

useradd -g dba oracle

passwd oracle

passwd oracle

mkdir -p /u01/app/oracle
mkdir -p /u01/app/oraInventory
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1

mkdir -p /u01/app/oracle
mkdir -p /u01/app/oraInventory
mkdir -p /u01/app/oracle/product/19.0.0/dbhome_1

chown -R oracle:dba /u01
chown -R oracle:dba /datiDBTEST
chown -R oracle:dba /fraDBTEST

chown -R oracle:dba /u01
chown -R oracle:dba /datiDBTEST
chown -R oracle:dba /fraDBTEST

chmod -R 775 /u01
chmod -R 775 /datiDBTEST
chmod -R 775 /fraDBTEST

chmod -R 775 /u01
chmod -R 775 /datiDBTEST
chmod -R 775 /fraDBTEST

yum install -y binutils 
yum install -y targetcli
yum install -y sysstat             
yum install -y nfs-utils
yum install -y make
yum install -y libstdc++-devel
yum install -y rdma-core-devel
yum install -y libXtst
yum install -y libXi
yum install -y libXrender-devel
yum install -y libaio-devel
yum install -y ksh
yum install -y glibc-devel
yum install -y fontconfig-devel
yum install -y elfutils-libelf-devel 
yum install -y libnsl

yum install -y binutils 
yum install -y targetcli
yum install -y sysstat             
yum install -y nfs-utils
yum install -y make
yum install -y libstdc++-devel
yum install -y rdma-core-devel
yum install -y libXtst
yum install -y libXi
yum install -y libXrender-devel
yum install -y libaio-devel
yum install -y ksh
yum install -y glibc-devel
yum install -y fontconfig-devel
yum install -y elfutils-libelf-devel 
yum install -y libnsl

yum install -y zip unzip

yum install -y zip unzip

yum install xorg-x11-server-Xorg xorg-x11-xauth.x86_64 -y
yum install xdpyinfo -y

yum install xorg-x11-server-Xorg xorg-x11-xauth.x86_64 -y
yum install xdpyinfo -y

vi /etc/sysctl.conf

vi /etc/sysctl.conf

fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 2251799813685247
kernel.shmmax = 2987162112
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048586

fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 2251799813685247
kernel.shmmax = 2987162112
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048586

vi /etc/security/limits.conf

vi /etc/security/limits.conf

oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536

oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536

vi /home/oracle/.bash_profile

vi /home/oracle/.bash_profile

ORACLE_BASE=/u01/app/oracle
export ORACLE_BASE
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
export ORACLE_HOME
ORACLE_SID=DBTEST 
export ORACLE_SID
PATH=$ORACLE_HOME/bin:$PATH
export PATH
export CV_ASSUME_DISTID=RHEL7.6

ORACLE_BASE=/u01/app/oracle
export ORACLE_BASE
ORACLE_HOME=$ORACLE_BASE/product/19.0.0/dbhome_1
export ORACLE_HOME
ORACLE_SID=DBTEST 
export ORACLE_SID
PATH=$ORACLE_HOME/bin:$PATH
export PATH
export CV_ASSUME_DISTID=RHEL7.6

cd /u01/app/oracle/product/19.0.0/dbhome_1

cd /u01/app/oracle/product/19.0.0/dbhome_1

unzip LINUX.X64_193000_db_home.zip

unzip LINUX.X64_193000_db_home.zip

./runInstaller

./runInstaller

[oracle@oraclelx ~]$ ps -ef |grep pmon
oracle   10965     1  0 05:44 ?        00:00:00 ora_pmon_DBTEST
oracle   19049 18860  0 06:05 pts/0    00:00:00 grep --color=auto pmon
[oracle@oraclelx ~]$ ps -ef |grep tns
root        46     2  0 04:08 ?        00:00:00 [netns]
oracle    5584     1  0 05:33 ?        00:00:00 /u01/app/oracle/product/19.0.0/dbhome_1/bin/tnslsnr LISTENER_DBTEST -inherit
oracle   19081 18860  0 06:05 pts/0    00:00:00 grep --color=auto tns
[oracle@oraclelx ~]$ sqlplus /@DBTEST

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Nov 9 06:05:32 2019
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.

Last Successful login time: Sat Nov 09 2019 06:04:58 +01:00

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL>

[oracle@oraclelx ~]$ ps -ef |grep pmon
oracle   10965     1  0 05:44 ?        00:00:00 ora_pmon_DBTEST
oracle   19049 18860  0 06:05 pts/0    00:00:00 grep --color=auto pmon
[oracle@oraclelx ~]$ ps -ef |grep tns
root        46     2  0 04:08 ?        00:00:00 [netns]
oracle    5584     1  0 05:33 ?        00:00:00 /u01/app/oracle/product/19.0.0/dbhome_1/bin/tnslsnr LISTENER_DBTEST -inherit
oracle   19081 18860  0 06:05 pts/0    00:00:00 grep --color=auto tns
[oracle@oraclelx ~]$ sqlplus /@DBTEST

SQL*Plus: Release 19.0.0.0.0 - Production on Sat Nov 9 06:05:32 2019
Version 19.3.0.0.0

Copyright (c) 1982, 2019, Oracle.  All rights reserved.

Last Successful login time: Sat Nov 09 2019 06:04:58 +01:00

Connected to:
Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.3.0.0.0

SQL>

