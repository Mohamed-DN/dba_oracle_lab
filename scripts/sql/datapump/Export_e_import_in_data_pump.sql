-- Source: https://www.scriptdba.com/export-e-import-in-data-pump/
-- Title: Export e import in data pump

select * from dba_directories;

select * from dba_directories;

create or replace directory DIR_PROVA as '/path/dump/dir/';

create or replace directory DIR_PROVA as '/path/dump/dir/';

select owner,sum(bytes/1024/1024) MB from dba_segments where owner='&owner' group by owner;

select owner,sum(bytes/1024/1024) MB from dba_segments where owner='&owner' group by owner;

expdp scott@test directory=DIR_PROVA dumpfile=exp_tipoexport.dmp logfile=exp_tipoexport.logfile

expdp scott@test directory=DIR_PROVA dumpfile=exp_tipoexport.dmp logfile=exp_tipoexport.logfile

select sum(bytes/1024/1024) MB from dba_segments;

select sum(bytes/1024/1024) MB from dba_segments;

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_full.dmp logfile=exp_full.log full=y

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_full.dmp logfile=exp_full.log full=y

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_full_%U.dmp logfile=exp_full.log full=y parallel=4 compression=ALL

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_full_%U.dmp logfile=exp_full.log full=y parallel=4 compression=ALL

select sum(bytes/1024/1024) MB from dba_segments where owner='PIPPO';

select sum(bytes/1024/1024) MB from dba_segments where owner='PIPPO';

select sum(bytes/1024/1024) MB from dba_segments where owner in ('PIPPO','PLUTO');

select sum(bytes/1024/1024) MB from dba_segments where owner in ('PIPPO','PLUTO');

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMA.dmp logfile=exp_full.log schemas=PIPPO

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMA.dmp logfile=exp_full.log schemas=PIPPO

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS_%U.dmp logfile=exp_full.log schema=PIPPO,PLUTO parallel=4

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS_%U.dmp logfile=exp_full.log schema=PIPPO,PLUTO parallel=4

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS.dmp logfile=exp_full.log schema=PIPPO content=METADATA_ONLY

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS.dmp logfile=exp_full.log schema=PIPPO content=METADATA_ONLY

select table_name, bytes/1024/1024 MB from dba_segments where segment_name in ('TAB_PIPPO_1','TAB_PIPPO_2');

select table_name, bytes/1024/1024 MB from dba_segments where segment_name in ('TAB_PIPPO_1','TAB_PIPPO_2');

set lines 300
spool disable_constraints.sql
select 'alter table '||owner||'.'||table_name||' enable novalidate constraint '||constraint_name||';' from dba_constraints where table_name ='&TABLE';
spool off

set lines 300
spool disable_constraints.sql
select 'alter table '||owner||'.'||table_name||' enable novalidate constraint '||constraint_name||';' from dba_constraints where table_name ='&TABLE';
spool off

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS.dmp logfile=exp_full.log tables=PIPPO.TAB_PIPPO_1,PIPPO.TAB_PIPPO_2

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS.dmp logfile=exp_full.log tables=PIPPO.TAB_PIPPO_1,PIPPO.TAB_PIPPO_2

scp filedump nomeutente@indirizzoip:/path/di/destinazione

scp filedump nomeutente@indirizzoip:/path/di/destinazione

sftp nomeutente@indirizzoip

cd /path/di/destinazione

put nomedump

sftp nomeutente@indirizzoip

cd /path/di/destinazione

put nomedump

\\ipserver\c$

\\ipserver\c$

impdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_full.dmp logfile=imp_full.log full=y

impdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_full.dmp logfile=imp_full.log full=y

impdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_full_%U.dmp logfile=imp_full.log full=y parallel=4

impdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_full_%U.dmp logfile=imp_full.log full=y parallel=4

drop user PIPPO cascade;

drop user PIPPO cascade;

impdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS.dmp logfile=impd_full.log schema=PIPPO

impdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS.dmp logfile=impd_full.log schema=PIPPO

set lines 300
spool disable_constraints.sql
select 'alter table '||owner||'.'||table_name||' disable novalidate constraint '||constraint_name||';' from dba_constraints where table_name ='&TABLE';
spool off

set lines 300
spool disable_constraints.sql
select 'alter table '||owner||'.'||table_name||' disable novalidate constraint '||constraint_name||';' from dba_constraints where table_name ='&TABLE';
spool off

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS.dmp logfile=exp_full.log tables=PIPPO.TAB_PIPPO_1,PIPPO.TAB_PIPPO_2 TABLE_EXISTS_ACTION=TRUNCATE

expdp "' / as sysdba'" directory=DIR_PROVA dumpfile=exp_SCHEMAS.dmp logfile=exp_full.log tables=PIPPO.TAB_PIPPO_1,PIPPO.TAB_PIPPO_2 TABLE_EXISTS_ACTION=TRUNCATE

