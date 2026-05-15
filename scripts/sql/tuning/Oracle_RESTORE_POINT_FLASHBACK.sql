-- Source: https://www.scriptdba.com/oracle-restore-point-flashback/
-- Title: Oracle RESTORE POINT FLASHBACK

CREATE RESTORE POINT "NOME_RESTORE_POINT" GUARANTEE FLASHBACK DATABASE;

CREATE RESTORE POINT "NOME_RESTORE_POINT" GUARANTEE FLASHBACK DATABASE;

col name for a40

col time for a50

set linesize 200

select NAME,SCN,TIME from v$restore_point;

col name for a40

col time for a50

set linesize 200

select NAME,SCN,TIME from v$restore_point;

DROP RESTORE POINT "NOME_RESTORE_POINT";

DROP RESTORE POINT "NOME_RESTORE_POINT";

shutdown immediate

shutdown immediate

startup mount

startup mount

FLASHBACK DATABASE TO RESTORE POINT "NOME_RESTORE_POINT";

FLASHBACK DATABASE TO RESTORE POINT "NOME_RESTORE_POINT";

ALTER DATABASE OPEN RESETELOGS;

ALTER DATABASE OPEN RESETELOGS;

