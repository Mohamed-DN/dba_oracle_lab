-- Source: https://www.scriptdba.com/tuning-sga-oracle-database/
-- Title: Tuning SGA Oracle database

alter system set  memory_max_target=4G scope=spfile;

alter system set memory_target=3G scope=spfile;

alter system set  memory_max_target=4G scope=spfile;

alter system set memory_target=3G scope=spfile;

alter system reset sga_max_size scope=spfile;

alter system reset sga_target scope=spfile;

alter system reset sga_max_size scope=spfile;

alter system reset sga_target scope=spfile;

create pfile='/tmp/pfile.ora' from spfile;

create pfile='/tmp/pfile.ora' from spfile;

sqlplus / as sysdba

sqlplus / as sysdba

startup pfile='/tmp/pfile.ora'

startup pfile='/tmp/pfile.ora'

create spfile from pfile='/tmp/pfile.ora'

create spfile from pfile='/tmp/pfile.ora'

