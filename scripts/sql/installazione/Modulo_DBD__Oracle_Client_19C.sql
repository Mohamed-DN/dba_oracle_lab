-- Source: https://www.scriptdba.com/modulo-dbdoracle-client-19c/
-- Title: Modulo DBD::Oracle Client 19C

wget https://download.oracle.com/otn_software/linux/instantclient/199000/oracle-instantclient19.9-basic-19.9.0.0.0-1.x86_64.rpm

wget https://download.oracle.com/otn_software/linux/instantclient/199000/oracle-instantclient19.9-basic-19.9.0.0.0-1.x86_64.rpm

wget https://download.oracle.com/otn_software/linux/instantclient/199000/oracle-instantclient19.9-sqlplus-19.9.0.0.0-1.x86_64.rpm

wget https://download.oracle.com/otn_software/linux/instantclient/199000/oracle-instantclient19.9-sqlplus-19.9.0.0.0-1.x86_64.rpm

wget https://download.oracle.com/otn_software/linux/instantclient/199000/oracle-instantclient19.9-devel-19.9.0.0.0-1.x86_64.rpm

wget https://download.oracle.com/otn_software/linux/instantclient/199000/oracle-instantclient19.9-devel-19.9.0.0.0-1.x86_64.rpm

yum install oracle-instantclient19.9-basic-19.9.0.0.0-1.x86_64.rpm
yum install oracle-instantclient19.9-sqlplus-19.9.0.0.0-1.x86_64.rpm
yum install oracle-instantclient19.9-devel-19.9.0.0.0-1.x86_64.rpm

yum install oracle-instantclient19.9-basic-19.9.0.0.0-1.x86_64.rpm
yum install oracle-instantclient19.9-sqlplus-19.9.0.0.0-1.x86_64.rpm
yum install oracle-instantclient19.9-devel-19.9.0.0.0-1.x86_64.rpm

vi /home/perl/.bash_profile

vi /home/perl/.bash_profile

export ORACLE_BASE=/usr/lib/oracle/
export ORACLE_HOME=/usr/lib/oracle/19.9/client64/
export PATH=$ORACLE_HOME/bin:$PATH
export TNS_ADMIN=/usr/lib/oracle/19.9/client64/lib/network/admin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/home/perl/perl5/lib
export ORACLE_USERID="system/Ciao10@TEST"
export ORACLE_DSN='dbi:Oracle:TEST'

export ORACLE_BASE=/usr/lib/oracle/
export ORACLE_HOME=/usr/lib/oracle/19.9/client64/
export PATH=$ORACLE_HOME/bin:$PATH
export TNS_ADMIN=/usr/lib/oracle/19.9/client64/lib/network/admin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/home/perl/perl5/lib
export ORACLE_USERID="system/Ciao10@TEST"
export ORACLE_DSN='dbi:Oracle:TEST'

vi /usr/lib/oracle/19.9/client64/lib/network/admin/tnsnames.ora

vi /usr/lib/oracle/19.9/client64/lib/network/admin/tnsnames.ora

TEST =
(DESCRIPTION =
(ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.3.10)(PORT = 1521))
(CONNECT_DATA =
(SERVER = DEDICATED)
(SERVICE_NAME = TEST)
)
)

TEST =
(DESCRIPTION =
(ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.3.10)(PORT = 1521))
(CONNECT_DATA =
(SERVER = DEDICATED)
(SERVICE_NAME = TEST)
)
)

sqlplus system/Ciao10@TEST

sqlplus system/Ciao10@TEST

yum install perl perl-DBI perl-YAML -y

yum install perl perl-DBI perl-YAML -y

wget https://www.cpan.org/modules/by-module/DBD/MJEVANS/DBD-Oracle-1.80.tar.gz

wget https://www.cpan.org/modules/by-module/DBD/MJEVANS/DBD-Oracle-1.80.tar.gz

tar xzvf DBD-Oracle-1.80.tar.gz

tar xzvf DBD-Oracle-1.80.tar.gz

cd DBD-Oracle-1.80
perl Makefile.PL
make
make test

cd DBD-Oracle-1.80
perl Makefile.PL
make
make test

