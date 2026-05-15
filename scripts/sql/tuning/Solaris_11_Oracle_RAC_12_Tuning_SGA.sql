-- Source: https://www.scriptdba.com/solaris-11-oracle-rac-12-tuning-sga/
-- Title: Solaris 11 Oracle RAC 12 Tuning SGA

ps -ef |grep smon

ps -ef |grep smon

pmap –xs 
| grep ism

pmap –xs 
| grep ism

create pfile='/tmp/pfile.ora' from spfile;

create pfile='/tmp/pfile.ora' from spfile;

alter system reset memory_max_target scope=spfile SID='*';

alter system reset memory_max_target scope=spfile SID='*';

alter system reset memory_target scope=spfile SID='*';

alter system reset memory_target scope=spfile SID='*';

alter system set SGA_MAX_SIZE=25G scope=spfile SID='*';

alter system set SGA_MAX_SIZE=25G scope=spfile SID='*';

alter system set SGA_TARGET=20G scope=spfile SID='*';

alter system set SGA_TARGET=20G scope=spfile SID='*';

alter system set PGA_AGGREGATE_TARGET=6G scope=spfile SID='*';

alter system set PGA_AGGREGATE_TARGET=6G scope=spfile SID='*';

alter system set pga_aggregate_limit=10g scope=spfile SID='*';

alter system set pga_aggregate_limit=10g scope=spfile SID='*';

srvctl stop database -d TEST -o immediate

srvctl stop database -d TEST -o immediate

srvctl start database -d TEST

srvctl start database -d TEST

