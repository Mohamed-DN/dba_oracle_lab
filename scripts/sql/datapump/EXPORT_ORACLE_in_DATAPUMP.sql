-- Source: https://www.scriptdba.com/export-oracle-in-datapump/
-- Title: EXPORT ORACLE in DATAPUMP

select owner, sum(bytes/1024/1024) mb from dba_segments where owner='SH' group by owner;

select owner, sum(bytes/1024/1024) mb from dba_segments where owner='SH' group by owner;

mkdir /dbTEST/export

mkdir /dbTEST/export

create or replace directory EXPDIR AS '/dbTEST/export';

create or replace directory EXPDIR AS '/dbTEST/export';

expdp "'/ as sysdba'" directory=EXPDIR dumpfile=exp_SH.dmp logfile=exp_SH.log SCHEMAS=SH

expdp "'/ as sysdba'" directory=EXPDIR dumpfile=exp_SH.dmp logfile=exp_SH.log SCHEMAS=SH

expdp "'/ as sysdba'" directory=EXPDIR dumpfile=exp_tab_OE.dmp logfile=exp_tab_OE.log TABLES=OE.ORDERS,OE.INVENTORIES,OE.CUSTOMERS,OE.PROMOTIONS

expdp "'/ as sysdba'" directory=EXPDIR dumpfile=exp_tab_OE.dmp logfile=exp_tab_OE.log TABLES=OE.ORDERS,OE.INVENTORIES,OE.CUSTOMERS,OE.PROMOTIONS

expdp "'/ as sysdba'" directory=POLPY dumpfile=exp_tab_OE.dmp logfile=full

expdp "'/ as sysdba'" directory=POLPY dumpfile=exp_tab_OE.dmp logfile=full

