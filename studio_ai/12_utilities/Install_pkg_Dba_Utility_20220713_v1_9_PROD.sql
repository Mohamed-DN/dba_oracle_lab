--
-- The PURGE_AM_TABLES JOB is NOT created automatically by the script
-- versione 1.01 : corretta schedulazione job "JOB_COLLECT_DB_GROWTH_JOB"

-- 28052022 Modified Script for automatic drop and creation of job temp and undo usage

-- 28052022 Execution on all PDBs of a CDB:
--               $ORACLE_HOME/perl/bin/perl $ORACLE_HOME/rdbms/admin/catcon.pl -d /tmp -l /tmp -C 'CDB$ROOT PDB$SEED NEXI_PDB_TEMPLATE' -b pkgdba /tmp/Install_pkg_Dba_Utility_20220531.sql

-- 31052022 Changed the timing of the jobs chosen randomly to avoid them starting at the same time on the PDBs


WHENEVER SQLERROR EXIT 1;

set serveroutput on 

grant alter system to dba_op ;
grant alter tablespace to dba_op ;
grant select on dba_tablespaces to dba_op ;
grant alter database to dba_op ;
grant PURGE DBA_RECYCLEBIN to DBA_OP; 
grant select on dba_users to DBA_OP;
grant select on dba_recyclebin to DBA_OP;
grant drop any table to DBA_OP;
grant select on dba_free_space to dba_op ;
 grant select on dba_data_files to dba_op ;
 grant unlimited tablespace to dba_op ;



DECLARE 

 USR_EXISTS NUMBER;

BEGIN 

SELECT 
  COUNT(*)
INTO USR_EXISTS
FROM DBA_USERS
WHERE USERNAME = 'DBA_CHANGE';


IF USR_EXISTS > 0 THEN

	execute immediate ('grant alter tablespace to dba_change') ;
	execute immediate ('grant select on dba_tablespaces to dba_change') ;
	execute immediate ('grant alter database to dba_change') ;
	execute immediate ('grant alter system to dba_change') ;

ELSE
    DBMS_OUTPUT.PUT_LINE('DBA_CHANGE does not exists. Continue');
END IF ;

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Granting needed priviledges to DBA_CHANGE. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/



-- ====================================================================================
-- Create Tablespace Tables

DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

    SELECT 
	 COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.MAINT_TABLESPACE_LOG' ;
	
	IF TAB_EXISTS > 0 THEN
	  execute immediate('DROP TABLE DBA_OP.MAINT_TABLESPACE_LOG');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table MAINT_TABLESPACE_LOG does not exist. This seems to be the first installation. Continue');
	END IF ;
	
    execute immediate('CREATE TABLE DBA_OP.MAINT_TABLESPACE_LOG( DATETIME DATE, SEVERITY VARCHAR2(10 BYTE), TABLESPACE_NAME  VARCHAR2(100 BYTE), MESSAGE VARCHAR2(4000 BYTE)) NOCOMPRESS TABLESPACE DBA_OP_DATA PARTITION BY RANGE (DATETIME) INTERVAL( NUMTODSINTERVAL(7,''DAY'')) ( PARTITION P20190909 VALUES LESS THAN (TO_DATE('' 2019-09-10 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA, PARTITION VALUES LESS THAN (TO_DATE('' 2022-03-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA )');

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Creating MAINT_TABLESPACE_LOG. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/




DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

    SELECT 
	 COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.MAINT_TABLESPACE_RESIZE' ;
	
	IF TAB_EXISTS > 0 THEN
	  execute immediate('DROP TABLE DBA_OP.MAINT_TABLESPACE_RESIZE');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table MAINT_TABLESPACE_RESIZE does not exist. This seems to be the first installation. Continue');
	END IF ;

	  execute immediate('CREATE TABLE DBA_OP.MAINT_TABLESPACE_RESIZE(DATETIME DATE, TABLESPACE_NAME VARCHAR2(100 BYTE), USED_MB NUMBER, ADDED_MB NUMBER, MAXSIZE_MB NUMBER, STATUS VARCHAR2(20 BYTE), RESIZE_MESSAGE VARCHAR2(2000 BYTE) ) TABLESPACE DBA_OP_DATA PARTITION BY RANGE (DATETIME) INTERVAL( NUMTODSINTERVAL(7,''DAY''))( PARTITION P20190909 VALUES LESS THAN (TO_DATE('' 2019-09-10 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA, PARTITION VALUES LESS THAN (TO_DATE('' 2022-03-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA)');
	  execute immediate('CREATE INDEX DBA_OP.IDX_TBLSPACE_RESZ ON DBA_OP.MAINT_TABLESPACE_RESIZE(TABLESPACE_NAME) TABLESPACE DBA_OP_DATA LOCAL ( PARTITION P20190909 LOGGING NOCOMPRESS TABLESPACE DBA_OP_DATA,PARTITION LOGGING NOCOMPRESS TABLESPACE DBA_OP_DATA)');

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Creating MAINT_TABLESPACE_RESIZE. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/

-- ====================================================================================


-- ====================================================================================
-- Database segment growth tables

DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

    SELECT 
	 COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.DB_TABLESPACES_GROWTH' ;
	
	IF TAB_EXISTS = 0 THEN
	  execute immediate('CREATE TABLE DBA_OP.DB_TABLESPACES_GROWTH( INS_DATE DATE, TABLESPACE_NAME VARCHAR2(30 BYTE) NOT NULL, MB_ALLOCATI NUMBER, MB_OCCUPATI NUMBER) TABLESPACE DBA_OP_DATA  PARTITION BY RANGE (INS_DATE) INTERVAL( NUMTODSINTERVAL(7,''DAY''))( PARTITION P20190909 VALUES LESS THAN (TO_DATE('' 2019-09-10 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA, PARTITION VALUES LESS THAN (TO_DATE('' 2022-03-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA)');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table DB_TABLESPACES_GROWTH already exist. Continue');
	END IF ;

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Creating DB_TABLESPACES_GROWTH. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/



DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

    SELECT 
	 COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.DB_SEGMENTS_GROWTH' ;
	
	IF TAB_EXISTS = 0 THEN
	  execute immediate('CREATE TABLE DBA_OP.DB_SEGMENTS_GROWTH( INS_DATE DATE, OWNER VARCHAR2(128 BYTE), SEGMENT_NAME VARCHAR2(128 BYTE), PARTITION_NAME VARCHAR2(128 BYTE), COMPRESSION VARCHAR2(8 BYTE), SIZE_MB NUMBER, NROWS NUMBER, SEGMENT_TYPE VARCHAR2(128 BYTE), SUBPARTITION_NAME  VARCHAR2(128 BYTE)) TABLESPACE DBA_OP_DATA PARTITION BY RANGE (INS_DATE) INTERVAL( NUMTODSINTERVAL(7,''DAY''))( PARTITION P20190909 VALUES LESS THAN (TO_DATE('' 2019-09-10 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA, PARTITION VALUES LESS THAN (TO_DATE('' 2022-03-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA)');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table DB_SEGMENTS_GROWTH already exist. Continue');
	END IF ;

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Creating DB_SEGMENTS_GROWTH. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/

-- ====================================================================================


-- ====================================================================================
-- Creating Table for Purge AM Tables
DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

    SELECT 
	 COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.PURGE_TABLE_AM_OBJ_LOG' ;
	
	IF TAB_EXISTS > 0 THEN
	  execute immediate('DROP TABLE DBA_OP.PURGE_TABLE_AM_OBJ_LOG');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table PURGE_TABLE_AM_OBJ_LOG does not exist. This seems to be the first installation. Continue');
	END IF ;

     execute immediate('CREATE TABLE DBA_OP.PURGE_TABLE_AM_OBJ_LOG( DATE_LOG DATE, OWNER VARCHAR2(30 BYTE), TABLE_NAME  VARCHAR2(30 BYTE), STATUS VARCHAR2(10 BYTE)) TABLESPACE DBA_OP_DATA PARTITION BY RANGE (DATE_LOG) INTERVAL( NUMTODSINTERVAL(7,''DAY''))( PARTITION P20190909 VALUES LESS THAN (TO_DATE('' 2019-09-10 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA, PARTITION VALUES LESS THAN (TO_DATE('' 2022-03-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA)');

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Creating PURGE_TABLE_AM_OBJ_LOG. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/



DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

        SELECT 
	  COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.PURGE_TABLE_AM_USERS' ;
	
	IF TAB_EXISTS = 0 THEN

	  execute immediate('CREATE TABLE DBA_OP.PURGE_TABLE_AM_USERS( USERNAME  VARCHAR2(30 BYTE)) TABLESPACE DBA_OP_DATA');
	  
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table PURGE_TABLE_AM_USERS already exist. Continue');
	END IF ;

           COMMIT ;

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Creating PURGE_TABLE_AM_USERS. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/





DECLARE

 TAB_EXISTS NUMBER;

BEGIN

        SELECT
          COUNT(*)
        INTO TAB_EXISTS
        FROM DBA_TABLES
        WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.PURGE_TABLE_AM_USERS' ;

        IF TAB_EXISTS = 1 THEN

          insert into dba_op.PURGE_TABLE_AM_USERS values ('ICTEAM_OBJ'      );
          insert into dba_op.PURGE_TABLE_AM_USERS values ('SOPRA_OBJ'       );
          insert into dba_op.PURGE_TABLE_AM_USERS values ('REPLY_OBJ'       );
          insert into dba_op.PURGE_TABLE_AM_USERS values ('NEXI_DIGITAL_OBJ');
          insert into dba_op.PURGE_TABLE_AM_USERS values ('NEXI_OBJ');
          insert into dba_op.PURGE_TABLE_AM_USERS values ('NEXI_DST_OBJ');

        ELSE
          DBMS_OUTPUT.PUT_LINE('Table PURGE_TABLE_AM_USERS already exists , it will not be populated again. Continue');
        END IF ;

           COMMIT ;

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error populating PURGE_TABLE_AM_USERS. Exiting'|| SUBSTR(SQLERRM, 1, 64));
         RAISE;
END;
/




-- ====================================================================================


-- ====================================================================================
-- Creating View for job of temp and Undo usage

CREATE OR REPLACE FORCE VIEW DBA_OP.VW_TEMP_USE
(
   DATA,
   SID,
   INST,
   USED_TMP_BLKS,
   MB,
   SEGTYPE,
   TABLESPACE,
   USERNAME,
   PROGRAM,
   MACHINE,
   MODULE,
   SERVICE_NAME,
   CURRENT_SQL,
   LAST_SQL
)
AS
     SELECT SYSDATE                                           data,
            s.sid,
            t.inst_id                                         inst,
            t.blocks                                          used_tmp_blks,
            ROUND (t.blocks * ts.block_size / (1024 * 1024), 0) MB,
            t.segtype,
            ts.TABLESPACE_NAME                                tablespace,
            s.username,
            s.program,
            s.machine,
            s.MODULE,
            s.service_name,
            a.sql_text                                        current_sql,
            a1.sql_text                                       last_sql
       FROM gv$tempseg_usage t,
            gv$session     s,
            gv$sqlarea     a,
            gv$sqlarea     a1,
            dba_tablespaces ts
      WHERE     s.inst_id = t.inst_id
            AND s.saddr = t.session_addr
            AND s.inst_id = a.inst_id(+)
            AND s.sql_address = a.address(+)
            AND t.inst_id = a1.inst_id(+)
            AND t.sqladdr = a1.address(+)
            AND t.TABLESPACE = ts.TABLESPACE_NAME
   ORDER BY t.blocks DESC;


CREATE OR REPLACE FORCE VIEW DBA_OP.VW_UNDO_USE
(
   DATA,
   SID,
   INST,
   USED_UBLK,
   MB,
   USERNAME,
   PROGRAM,
   MACHINE,
   MODULE,
   SERVICE_NAME,
   SQL_TEXT
)
AS
     SELECT SYSDATE                          data,
            s.sid,
            t.inst_id                        inst,
            t.used_ublk,
            ROUND (t.used_ublk * 16 / 1024, 0) MB,
            s.username,
            s.program,
            s.machine,
            s.MODULE,
            s.service_name,
            a.sql_text
       FROM gv$session s, gv$transaction t, gv$sqlarea a
      WHERE     s.inst_id = t.inst_id(+)
            AND s.inst_id = a.inst_id(+)
            AND s.saddr = t.ses_addr
            AND s.sql_address = a.address(+)
            AND s.username IS NOT NULL
            AND t.used_ublk > 1000
ORDER BY t.used_ublk DESC;




DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

    SELECT 
	 COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.TEMP_USE_HISTORY' ;
	
	IF TAB_EXISTS > 0 THEN
	  execute immediate('DROP TABLE DBA_OP.TEMP_USE_HISTORY');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table TEMP_USE_HISTORY does not exist. This seems to be the first installation. Continue');
	END IF ;

     execute immediate('CREATE TABLE DBA_OP.TEMP_USE_HISTORY( DATA DATE, SID NUMBER, INST NUMBER, USED_TMP_BLKS  NUMBER, MB NUMBER, SEGTYPE VARCHAR2(9 BYTE), TABLESPACE VARCHAR2(30 BYTE) NOT NULL, USERNAME VARCHAR2(30 BYTE), PROGRAM VARCHAR2(48 BYTE), MACHINE VARCHAR2(64 BYTE), MODULE VARCHAR2(64 BYTE), SERVICE_NAME VARCHAR2(64 BYTE), CURRENT_SQL VARCHAR2(1000 CHAR), LAST_SQL VARCHAR2(1000 CHAR) ) TABLESPACE DBA_OP_DATA  PARTITION BY RANGE (DATA) INTERVAL( NUMTODSINTERVAL(7,''DAY''))( PARTITION P20190909 VALUES LESS THAN (TO_DATE('' 2019-09-10 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA, PARTITION VALUES LESS THAN (TO_DATE('' 2022-03-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA)');

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Creating TEMP_USE_HISTORY. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/



DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

    SELECT 
	 COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.UNDO_USE_HISTORY' ;
	
	IF TAB_EXISTS > 0 THEN
	  execute immediate('DROP TABLE DBA_OP.UNDO_USE_HISTORY');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table UNDO_USE_HISTORY does not exist. This seems to be the first installation. Continue');
	END IF ;

     execute immediate('CREATE TABLE DBA_OP.UNDO_USE_HISTORY( DATA DATE, SID NUMBER, INST NUMBER, USED_UBLK NUMBER, MB NUMBER, USERNAME VARCHAR2(30 BYTE), PROGRAM VARCHAR2(48 BYTE), MACHINE VARCHAR2(64 BYTE), MODULE VARCHAR2(64 BYTE), SERVICE_NAME VARCHAR2(64 BYTE), SQL_TEXT VARCHAR2(1000 BYTE)) TABLESPACE DBA_OP_DATA PARTITION BY RANGE (DATA) INTERVAL( NUMTODSINTERVAL(7,''DAY''))( PARTITION P20190909 VALUES LESS THAN (TO_DATE('' 2019-09-10 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA, PARTITION VALUES LESS THAN (TO_DATE('' 2022-03-01 00:00:00'', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')) TABLESPACE DBA_OP_DATA)');

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error Creating UNDO_USE_HISTORY. Exiting'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/


-- ====================================================================================






-- ====================================================================================
--  Insertion of the rejuvenation configurations on PM 




DECLARE

 v_maxseq NUMBER ;
 table_does_not_exist exception;  
 PRAGMA EXCEPTION_INIT(table_does_not_exist, -00942);

BEGIN

-- Cancello le predisposizioni gia presenti 

execute immediate('DELETE FROM DBA_OP.MAINT_PARTITIONS WHERE TABLE_NAME IN (''DBA_OP.MAINT_TABLESPACE_LOG'',''DBA_OP.MAINT_TABLESPACE_RESIZE'',''DBA_OP.DB_TABLESPACES_GROWTH'',''DBA_OP.DB_SEGMENTS_GROWTH'',''DBA_OP.PURGE_TABLE_AM_OBJ_LOG'',''DBA_OP.TEMP_USE_HISTORY'',''DBA_OP.UNDO_USE_HISTORY'')');

execute immediate('SELECT MAX(TABLE_ID)+1 FROM DBA_OP.MAINT_PARTITIONS') INTO v_maxseq ;

execute immediate ('Insert into DBA_OP.MAINT_PARTITIONS(TABLE_ID, TABLE_NAME, ENABLED, PARTITION_RETENTION_UNIT, PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE, ACTION_EXPORT_DATA, ACTION_COMPRESS_PART, PARTITION_COMPRESS_TYPE, ACTION_ADD_PART, PARTITION_ADD_COUNT, PARTITION_NAME_PREFIX, ACTION_DROP_PART, ACTION_EXCHANGE_PART, ACTION_ARCHIVE_WITH_QUERY,LAST_RUN_DATE, LAST_RUN_RESULT, NEXT_RUN_DATE, SCHEDULE) Values ( :1 , ''DBA_OP.MAINT_TABLESPACE_LOG'',    ''Y'', ''YYYYMMWK'',  24, 1, ''N'', ''N'', '''', ''N'', 1, ''P'', ''Y'', ''N'', ''N'', NULL, ''OK'', NULL, ''FREQ=WEEKLY;BYHOUR=1;BYMINUTE=0;BYSECOND=0'')') using v_maxseq;
																																																																																																																									    
execute immediate ('Insert into DBA_OP.MAINT_PARTITIONS(TABLE_ID, TABLE_NAME, ENABLED, PARTITION_RETENTION_UNIT, PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE, ACTION_EXPORT_DATA, ACTION_COMPRESS_PART, PARTITION_COMPRESS_TYPE, ACTION_ADD_PART, PARTITION_ADD_COUNT, PARTITION_NAME_PREFIX, ACTION_DROP_PART, ACTION_EXCHANGE_PART, ACTION_ARCHIVE_WITH_QUERY,LAST_RUN_DATE, LAST_RUN_RESULT, NEXT_RUN_DATE, SCHEDULE) Values ( :1 , ''DBA_OP.MAINT_TABLESPACE_RESIZE'', ''Y'', ''YYYYMMWK'', 120, 1, ''N'', ''N'', '''', ''N'', 1, ''P'', ''Y'', ''N'', ''N'', NULL, ''OK'', NULL, ''FREQ=WEEKLY;BYHOUR=1;BYMINUTE=0;BYSECOND=0'')') using v_maxseq + 1;
																																																																																																																									    
execute immediate ('Insert into DBA_OP.MAINT_PARTITIONS(TABLE_ID, TABLE_NAME, ENABLED, PARTITION_RETENTION_UNIT, PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE, ACTION_EXPORT_DATA, ACTION_COMPRESS_PART, PARTITION_COMPRESS_TYPE, ACTION_ADD_PART, PARTITION_ADD_COUNT, PARTITION_NAME_PREFIX, ACTION_DROP_PART, ACTION_EXCHANGE_PART, ACTION_ARCHIVE_WITH_QUERY,LAST_RUN_DATE, LAST_RUN_RESULT, NEXT_RUN_DATE, SCHEDULE) Values ( :1 , ''DBA_OP.DB_TABLESPACES_GROWTH'',   ''Y'', ''YYYYMMWK'', 120, 1, ''N'', ''N'', '''', ''N'', 1, ''P'', ''Y'', ''N'', ''N'', NULL, ''OK'', NULL, ''FREQ=WEEKLY;BYHOUR=1;BYMINUTE=0;BYSECOND=0'')') using v_maxseq + 2;
																																																																																																																									    
execute immediate ('Insert into DBA_OP.MAINT_PARTITIONS(TABLE_ID, TABLE_NAME, ENABLED, PARTITION_RETENTION_UNIT, PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE, ACTION_EXPORT_DATA, ACTION_COMPRESS_PART, PARTITION_COMPRESS_TYPE, ACTION_ADD_PART, PARTITION_ADD_COUNT, PARTITION_NAME_PREFIX, ACTION_DROP_PART, ACTION_EXCHANGE_PART, ACTION_ARCHIVE_WITH_QUERY,LAST_RUN_DATE, LAST_RUN_RESULT, NEXT_RUN_DATE, SCHEDULE) Values ( :1 , ''DBA_OP.DB_SEGMENTS_GROWTH'',      ''Y'', ''YYYYMMWK'', 120, 1, ''N'', ''N'', '''', ''N'', 1, ''P'', ''Y'', ''N'', ''N'', NULL, ''OK'', NULL, ''FREQ=WEEKLY;BYHOUR=1;BYMINUTE=0;BYSECOND=0'')') using v_maxseq + 3;
																																																																																																																									    
execute immediate ('Insert into DBA_OP.MAINT_PARTITIONS(TABLE_ID, TABLE_NAME, ENABLED, PARTITION_RETENTION_UNIT, PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE, ACTION_EXPORT_DATA, ACTION_COMPRESS_PART, PARTITION_COMPRESS_TYPE, ACTION_ADD_PART, PARTITION_ADD_COUNT, PARTITION_NAME_PREFIX, ACTION_DROP_PART, ACTION_EXCHANGE_PART, ACTION_ARCHIVE_WITH_QUERY,LAST_RUN_DATE, LAST_RUN_RESULT, NEXT_RUN_DATE, SCHEDULE) Values ( :1 , ''DBA_OP.PURGE_TABLE_AM_OBJ_LOG'',  ''Y'', ''YYYYMMWK'',  15, 1, ''N'', ''N'', '''', ''N'', 1, ''P'', ''Y'', ''N'', ''N'', NULL, ''OK'', NULL, ''FREQ=WEEKLY;BYHOUR=1;BYMINUTE=0;BYSECOND=0'')') using v_maxseq + 4;
																																																																																																																									    
execute immediate ('Insert into DBA_OP.MAINT_PARTITIONS(TABLE_ID, TABLE_NAME, ENABLED, PARTITION_RETENTION_UNIT, PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE, ACTION_EXPORT_DATA, ACTION_COMPRESS_PART, PARTITION_COMPRESS_TYPE, ACTION_ADD_PART, PARTITION_ADD_COUNT, PARTITION_NAME_PREFIX, ACTION_DROP_PART, ACTION_EXCHANGE_PART, ACTION_ARCHIVE_WITH_QUERY,LAST_RUN_DATE, LAST_RUN_RESULT, NEXT_RUN_DATE, SCHEDULE) Values ( :1 , ''DBA_OP.TEMP_USE_HISTORY'',        ''Y'', ''YYYYMMWK'',   5, 1, ''N'', ''N'', '''', ''N'', 1, ''P'', ''Y'', ''N'', ''N'', NULL, ''OK'', NULL, ''FREQ=WEEKLY;BYHOUR=1;BYMINUTE=0;BYSECOND=0'')') using v_maxseq + 5;
																																																																																																																									    
execute immediate ('Insert into DBA_OP.MAINT_PARTITIONS(TABLE_ID, TABLE_NAME, ENABLED, PARTITION_RETENTION_UNIT, PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE, ACTION_EXPORT_DATA, ACTION_COMPRESS_PART, PARTITION_COMPRESS_TYPE, ACTION_ADD_PART, PARTITION_ADD_COUNT, PARTITION_NAME_PREFIX, ACTION_DROP_PART, ACTION_EXCHANGE_PART, ACTION_ARCHIVE_WITH_QUERY,LAST_RUN_DATE, LAST_RUN_RESULT, NEXT_RUN_DATE, SCHEDULE) Values ( :1 , ''DBA_OP.UNDO_USE_HISTORY'',        ''Y'', ''YYYYMMWK'',   5, 1, ''N'', ''N'', '''', ''N'', 1, ''P'', ''Y'', ''N'', ''N'', NULL, ''OK'', NULL, ''FREQ=WEEKLY;BYHOUR=1;BYMINUTE=0;BYSECOND=0'')') using v_maxseq + 6;


EXCEPTION
WHEN table_does_not_exist
 THEN DBMS_OUTPUT.PUT_LINE('Partition Manager seems do not be installed. We will not archive records in application tables. Continue');  
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Error during insert into PM tables.'|| SUBSTR(SQLERRM, 1, 64));
	 RAISE;
END;
/


CREATE OR REPLACE PACKAGE DBA_OP.PKG_DBA_UTILITY AS

/*
   Contributors: Fabio Olivo

   20220223      versione v1.0       Start Version

   20220304      versione v1.1       Added other utility

   20220322      versione v1.2       Create Procedure CalculateMaxAllowedDfSize

   20220527      versione v1.3       Introduced parametered thresholds
                                     Modified some error level returned by application

   20220713      versione v1.4       Eliminata differenza di calcolo tra PDB e DB Standalone
                                     Bug Fix CheckForAutoextendDF which only worked on non-autoextensible dfs

   20220718 version v1.5 Introduced Error handling in ExtendTablespaceAuto loop
                                     Modificata query di generazione lista tablepace da estendere
                                     Modified MAINTENANCE_TABLESPACE_RESIZE table
                                     Modified LogResize Procedure to introduce WAR or ERROR conditions in the resize log
                                     Logging in tablespace resize even if just an autoextend of the datafile has been performed
                                     Resize UNDO tablespace management eliminated

   20220721 version v1.6 Changed algorithm for adding space CalculateSpaceToAdd

   20220801 version v1.7 Improvement on purge_dba_recycle_bin to allow running multiple jobs with different configurations for different schemas

   20220828 version v1.8 Fix ExtendTablespace on Warning message "Added maximum number of 10" that is logged for no real reason
   
   20220928      versione v1.9       CanTablespaceBeExtended fixed ricerca ultimo evento di modifica spazi
                                     ExtendTablespaceAuto modificata per non eseguire nessuna estenzione nel caso in cui non ci sia spazio su ASM

*/

  -- Static Package version number
  VERSIONE CONSTANT VARCHAR2(100) := '1.8';

-- Tablespace Automatic management

  TABLESPACE_NOT_FOUND          EXCEPTION ;
  PRAGMA EXCEPTION_INIT(TABLESPACE_NOT_FOUND, -20001);

  FUNCTION  GetWarnSizeMN(vTablespaceMaxSize IN NUMBER) RETURN NUMBER;
  FUNCTION  GetErrSizeMN(vTablespaceMaxSize IN NUMBER) RETURN NUMBER;
  FUNCTION  CalculateMaxAllowedDfSize RETURN NUMBER;
  FUNCTION  CheckFreeAsmSpace(vTablespaceToAddMB NUMBER ) RETURN BOOLEAN;
  FUNCTION  CanTablespaceBeExtended(vTablespaceName VARCHAR2 ) RETURN INTEGER ;

  PROCEDURE LogFacility( pSeverity INTEGER, pMessage  VARCHAR2, pTablespaceName VARCHAR2) ;
  PROCEDURE LogResize(  pTablespaceName VARCHAR2,pUserMb NUMBER,pAddedMb NUMBER,pMaxsizeMb NUMBER, pStatus VARCHAR2 DEFAULT 'OK', pMessages VARCHAR2 DEFAULT '' ) ;
  PROCEDURE DisplayTblSpaceOverLimit  ;
  PROCEDURE ExtendTablespace ( vTablespaceName VARCHAR2 ) ;
  PROCEDURE ExtendTablespaceAuto ;
  PROCEDURE CalculateSpaceToAdd(vTablespaceName IN VARCHAR2, vSpaceAddMb OUT NUMBER ) ;
  PROCEDURE CheckForAutoextendDF(vTablespaceName  IN VARCHAR2 , vMBToAdd IN OUT NUMBER ) ;

  V_NORM_SIZE        NUMBER := 0.97; -- 1000MB da esprimere in GB
  V_LEVEL_ERR        NUMBER := 0.9 ;
  V_LEVEL_WRN        NUMBER := 0.8 ;
  V_MNUM             NUMBER := 0.8 ;

  V_GROW_DATEDIFF_HH NUMBER := 24 ;

  -- Recyclebin Purging procedure
  PROCEDURE PURGE_DBA_RECYCLEBIN( p_purge_before_days in NUMBER default 30, p_dryrun in varchar2 := 'Y' , p_schema in varchar2 default NULL);

  -- Tablespace Size Collection
  PROCEDURE PRC_DB_GROWTH_DATA ;

  -- Procedure to Purge Tables from am schemas
  PROCEDURE PURGE_TABLE_AM_OBJ( p_dryrun VARCHAR2 DEFAULT 'Y') ;

  -- Collecting TEMP + UNDO Info
  PROCEDURE PRC_TEMP_USE_HISTORY ;
  PROCEDURE PRC_UNDO_USE_HISTORY ;

-- General

  LOG_SEV_DEBUG         CONSTANT INTEGER := -1 ;
  LOG_SEV_INFO          CONSTANT INTEGER := 0  ;
  LOG_SEV_WARNING       CONSTANT INTEGER := 1  ;
  LOG_SEV_ERROR         CONSTANT INTEGER := 2  ;


END PKG_DBA_UTILITY;
/



CREATE OR REPLACE PACKAGE BODY DBA_OP.PKG_DBA_UTILITY AS

  /*
       This function return the size that tablespace must reach to be in warning state ( > 80% )
       Input Tbalespace maxsize as GB
  */

  FUNCTION GetWarnSizeMN(vTablespaceMaxSize IN NUMBER) RETURN NUMBER
  IS

    V_ISPDB NUMBER := 0;

  BEGIN

 --    execute immediate('SELECT COUNT(*) FROM V$PDBS') INTO V_ISPDB ;

     -- If this is not a PDB, the check return 95% for error size MB
   --  IF V_ISPDB = 0 THEN
        RETURN ROUND(vTablespaceMaxSize - vTablespaceMaxSize * ((1 - V_LEVEL_WRN) * (POWER((vTablespaceMaxSize/V_NORM_SIZE),V_MNUM)*V_NORM_SIZE/vTablespaceMaxSize )),3);

    --ELSE
    --    RETURN ROUND(vTablespaceMaxSize*V_LEVEL_WRN,3) ;
    -- END IF ;

  -- if errors ( should not ) return the def warn level
  EXCEPTION
  WHEN OTHERS THEN
     RETURN ROUND(vTablespaceMaxSize*V_LEVEL_WRN,3) ;
  END ;

  /*
       This function return the size that tablespace must reach to be in Error state ( > 90% )
       Input Tbalespace maxsize as GB
  */

  FUNCTION GetErrSizeMN(vTablespaceMaxSize IN NUMBER) RETURN NUMBER
  IS

    V_ISPDB NUMBER := 0;

  BEGIN

  --   execute immediate('SELECT COUNT(*) FROM V$PDBS') INTO V_ISPDB ;

     -- If this is not a PDB, the check return 95% for error size MB
    -- IF V_ISPDB = 0 THEN
        RETURN ROUND(vTablespaceMaxSize - vTablespaceMaxSize * ((1 - V_LEVEL_ERR) * (POWER((vTablespaceMaxSize/V_NORM_SIZE),V_MNUM)*V_NORM_SIZE/vTablespaceMaxSize )),3) ;
    -- ELSE
    --    RETURN ROUND(vTablespaceMaxSize*V_LEVEL_ERR,3) ;
    -- END IF ;

  -- if errors ( should not ) return the def error level
  EXCEPTION
  WHEN OTHERS THEN
     RETURN ROUND(vTablespaceMaxSize*V_LEVEL_ERR,3) ;
  END ;


  /*
       This function return the space in MB to add to tablespace in order to stop warning/error alerts
       Input TablespaceName
  */
  PROCEDURE CalculateSpaceToAdd(vTablespaceName IN VARCHAR2, vSpaceAddMb OUT NUMBER)
  AS

     vTablespaceExists  NUMBER := 0;
     vWarnSizeMb        NUMBER := 0;
     vErrSizeMb         NUMBER := 0;
     vUsedSizeMb        NUMBER := 0;
     vMaxSizeMb         NUMBER := 0;

  BEGIN

    -- Checking if tablespace exists
    SELECT
      COUNT(*)
    INTO vTablespaceExists
    FROM DBA_TABLESPACES
    WHERE TABLESPACE_NAME = vTablespaceName;

    IF vTablespaceExists = 0 THEN
       --dbms_output.put_line( 'ERROR: Tablespace ' ||vTablespaceName || ' does not exists.' );
       LogFacility(LOG_SEV_ERROR,'Tablespace ' ||vTablespaceName || ' does not exists.',vTablespaceName);
        RAISE TABLESPACE_NOT_FOUND;
    END IF ;

        SELECT
          CASE
             WHEN TBSP_MAXSIZE_MB < V_NORM_SIZE*1024 AND ( USED_PERCENT >= 80  and USED_PERCENT < 90 )
               THEN (TBSP_MAXSIZE_MB - WARN_SIZE_MB )/2
             WHEN TBSP_MAXSIZE_MB < V_NORM_SIZE*1024 AND ( USED_PERCENT >= 90 )
               THEN TBSP_MAXSIZE_MB - WARN_SIZE_MB
             WHEN  TBSP_MAXSIZE_MB >= V_NORM_SIZE*1024 AND ( USED_MB >= WARN_SIZE_MB  and USED_MB < ERR_SIZE_MB )
               THEN (TBSP_MAXSIZE_MB - WARN_SIZE_MB )/2
             WHEN TBSP_MAXSIZE_MB >= V_NORM_SIZE*1024 AND (USED_MB >= ERR_SIZE_MB)
               -- per uscire dall'error e poi dal warning, uso il free per andare oltre la soglia di warning
               THEN 1.5*(TBSP_MAXSIZE_MB - WARN_SIZE_MB)
          END as SPACEMB_ADD,
          WARN_SIZE_MB,
          ERR_SIZE_MB,
          USED_MB,
          TBSP_MAXSIZE_MB
         INTO vSpaceAddMb,
              vWarnSizeMb,
              vErrSizeMb,
              vUsedSizeMb,
              vMaxSizeMb
         FROM (
              SELECT tbs.tablespace_name tbs_name,
                     bigfile,
                     ROUND(a.b_max/1024/1024, 0)  TBSP_MAXSIZE_MB,
                     ROUND(( a.b_allocati - NVL(f.b_free, 0) ) / 1024 / 1024, 0)     USED_MB,
                     ROUND((( a.b_allocati - NVL(f.b_free, 0) )/1024/1024)*100/(a.b_max/1024/1024),2)     USED_PERCENT,
                     (DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN(a.b_max/1024/1024/1024))*1024 WARN_SIZE_MB,
                     (DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN(a.b_max/1024/1024/1024))*1024 ERR_SIZE_MB
              FROM   dba_tablespaces tbs
                   , (SELECT tablespace_name
                             , SUM(bytes)                                     b_allocati
                             , SUM(DECODE (maxbytes, '0', bytes, maxbytes))   b_max
                      FROM   dba_data_files
                      GROUP  BY tablespace_name) a
                   , (SELECT tablespace_name
                             , SUM(bytes)  b_free
                             , MAX(blocks) max_blk
                      FROM   dba_free_space
                      GROUP  BY tablespace_name) f
                   , (SELECT tablespace_name
                             , COUNT(*) df#
                      FROM   dba_data_files
                      GROUP  BY tablespace_name) df
              WHERE  tbs.tablespace_name   = a.tablespace_name
                   AND tbs.tablespace_name = f.tablespace_name(+)
                   AND tbs.tablespace_name = df.tablespace_name
                   AND df.tablespace_name  = vTablespaceName
        );


        IF vSpaceAddMb IS NULL OR vSpaceAddMb <= 0
          THEN
            LogFacility(LOG_SEV_INFO,'Tablespace ' || vTablespaceName ||' does not need to be extended.' ,vTablespaceName);
            LogFacility(LOG_SEV_INFO,'UsedMb: ' || vUsedSizeMb || ' WarnSizeMb: ' || vWarnSizeMb || ' ErrSizeMb: ' || vErrSizeMb || ' MaxSizeMb: ' || vMaxSizeMb ,vTablespaceName);
            vSpaceAddMb := 0;
            return ;
        END IF ;

          -- Return the warrning space
          vSpaceAddMb := CEIL(vSpaceAddMb + vSpaceAddMb*0.10) ;

          LogFacility(LOG_SEV_INFO,'Tablespace ' ||vTablespaceName || ' need to be extended of ' || vSpaceAddMb || 'M',vTablespaceName);

  END ;


  FUNCTION  CalculateMaxAllowedDfSize
    RETURN NUMBER
   IS

   vTblspMaxDfSize NUMBER ;

    BEGIN

        select
          ROUND(value*4194303/1024/1024)
        into vTblspMaxDfSize
        from v$parameter
        where name = 'db_block_size';

          RETURN vTblspMaxDfSize ;

    END ;


  FUNCTION CanTablespaceBeExtended(vTablespaceName VARCHAR2 )
    RETURN INTEGER
   IS

    vCanTbsBeExtended INTEGER ;

   BEGIN

        -- Return 1 only if the difference between sysdate e last time where tablespace has been grown is less that 24h
        SELECT
          CASE
            WHEN TRUNC(ABS(( NVL(MAX(DATETIME),TRUNC(SYSDATE-7)) - SYSDATE )*24)) >= 24
             THEN 1
            WHEN TRUNC(ABS(( NVL(MAX(DATETIME),TRUNC(SYSDATE-7)) - SYSDATE )*24)) < 24
             THEN 0
          END as EXTENDABLE
        INTO  vCanTbsBeExtended
        FROM DBA_OP.MAINT_TABLESPACE_RESIZE
        WHERE TABLESPACE_NAME = vTablespaceName 
        AND status = 'OK' and added_mb > 0 ;

          RETURN vCanTbsBeExtended  ;

   END ;


  FUNCTION checkFreeAsmSpace(vTablespaceToAddMB NUMBER )
    RETURN BOOLEAN
   IS

       vFreeMb NUMBER ;

   BEGIN
        select
           nvl(free_mb,0)
        into vFreeMb
        from v$asm_diskgroup
        where name = ( select
                           substr(value,2,length(value))
                       from v$parameter
                       where name = 'db_create_file_dest' ) ;

        IF vFreeMb IS NULL THEN
           return FALSE  ;
        END IF ;

        return
           CASE
            WHEN vFreeMb > vTablespaceToAddMB
             THEN TRUE
            WHEN vFreeMb <= vTablespaceToAddMB
             THEN FALSE
           END ;

    END ;


  PROCEDURE CheckForAutoextendDF(vTablespaceName  IN VARCHAR2 , vMBToAdd IN OUT NUMBER )
  AS

    vStmtCmd          VARCHAR2(4000);

    CURSOR cTblsDfAutoextend(vTablespaceName VARCHAR2) IS
        select
            file_id,file_name,ROUND(CalculateMaxAllowedDfSize - BYTES/1024/1024,3) as GainedMb
        from dba_data_files
        where tablespace_name = vTablespaceName
        order by file_id;


    BEGIN


        FOR rTblsDfAutoextend IN cTblsDfAutoextend(vTablespaceName)
        LOOP

              BEGIN

                  vStmtCmd := 'ALTER DATABASE DATAFILE ''' || rTblsDfAutoextend.file_name || ''' AUTOEXTEND ON NEXT 128M MAXSIZE UNLIMITED' ;

                  LogFacility(LOG_SEV_INFO, 'Executing: ' || vStmtCmd, vTablespaceName);

                  execute immediate(vStmtCmd);

                  LogFacility(LOG_SEV_INFO, 'Modified in autoextend maxsize unlimited the following datafile : ' || rTblsDfAutoextend.file_name, vTablespaceName);

                  -- Subtract the gained free space after setup of autoextend from free space needed
                  -- If it is negative or better 0 , then no need to proceed to modify other datafiles
                  vMBToAdd := vMBToAdd - rTblsDfAutoextend.GainedMb ;

                  -- Se
                  IF vMBToAdd <= 0
                   THEN
                      vMBToAdd := 0 ;
                       RETURN ;
                  END IF ;

              EXCEPTION
                  WHEN OTHERS THEN
                    LogFacility(LOG_SEV_ERROR, 'Failed Autoextend datafile of tablespace ' || vTablespaceName || ' : ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']', vTablespaceName );
                     RAISE ;
              END ;

        END LOOP;

    END ;


  /*
       This procedure add space to tablespace passed as argument
       Input TablespaceName
  */
  PROCEDURE ExtendTablespace ( vTablespaceName VARCHAR2 )
  AS

     vMBToAdd          NUMBER ;
     vOmfEnabled       VARCHAR2(5) ;
     vTablespaceExists NUMBER ;
     vStmtCmd          VARCHAR2(4000);
     vDfToAdd          NUMBER ;
     vAddedDf          NUMBER := 1;


     CURSOR cTblspaceParam(vTablespaceName VARCHAR2) IS (
          SELECT tbs.tablespace_name tbs_name,
                 db_unique_name,
                 bigfile,
                 b_autoext TBSP_AUTOEXT,
                 ROUND(a.b_max / 1024 / 1024, 0)  TBSP_MAXSIZE_MB,
                 ROUND(( a.b_allocati - NVL(f.b_free, 0))/1024/1024, 0)     USED_MB,
                 ROUND((( a.b_allocati - NVL(f.b_free, 0))/1024/1024)*100/(a.b_max/1024/1024),2)     USED_PERCENT,
                 (DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN(a.b_max/1024/1024/1024))*1024 WARN_SIZE_MB,
                 ROUND((DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN((a.b_max/1024/1024/1024))*100/(a.b_max/1024/1024/1024)),2) WARN_PERC,
                 (DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN(a.b_max/1024/1024/1024))*1024 ERR_SIZE_MB,
                 ROUND((DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN((a.b_max/1024/1024/1024))*100/(a.b_max/1024/1024/1024)),2) ERR_PERC
          FROM   dba_tablespaces tbs, v$database
               , (SELECT tablespace_name
                         , SUM(bytes)                                     b_allocati
                         , SUM(DECODE (maxbytes, '0', bytes, maxbytes))   b_max
                         , SUM(decode(AUTOEXTENSIBLE,'YES',1,0)) b_autoext
                  FROM   dba_data_files
                  GROUP  BY tablespace_name) a
               , (SELECT tablespace_name
                         , SUM(bytes)  b_free
                         , MAX(blocks) max_blk
                  FROM   dba_free_space
                  GROUP  BY tablespace_name) f
               , (SELECT tablespace_name
                         , COUNT(*) df#
                  FROM   dba_data_files
                  GROUP  BY tablespace_name) df
          WHERE  tbs.tablespace_name = a.tablespace_name
               AND tbs.tablespace_name = f.tablespace_name(+)
               AND tbs.tablespace_name = df.tablespace_name
               AND df.tablespace_name = UPPER(vTablespaceName)
               AND tbs.tablespace_name not like 'UNDO%'
        ) ;

  BEGIN

    -- Checking if tablespace exists
    SELECT
      COUNT(*)
    INTO vTablespaceExists
    FROM DBA_TABLESPACES
    WHERE TABLESPACE_NAME = UPPER(vTablespaceName);

    IF vTablespaceExists = 0 THEN
       LogFacility(LOG_SEV_ERROR,'Tablespace ' ||vTablespaceName || ' does not exists.',vTablespaceName);
         RETURN ;
    END IF ;

      CalculateSpaceToAdd(UPPER(vTablespaceName),vMBToAdd) ;

    IF vMBToAdd <=0  THEN
        --dbms_output.put_line('WARN : Tablespace' ||vTablespaceName || ' does not need to be extended' );
        LogFacility(LOG_SEV_INFO,'Tablespace ' ||vTablespaceName || ' does not need to be extended',vTablespaceName);
          RETURN ;
    END IF ;

    -- We need to be sure that OMF is enabled and db_create:_file_dest is populated accordingly
    select
      decode(substr(value,1,1),'+','ASM','/','FS','KO')
    into vOmfEnabled
    from v$parameter
    where name = 'db_create_file_dest' ;

    IF vOmfEnabled = 'KO' THEN
       --dbms_output.put_line('WARN : OMF is not enabled. Tablespace ' || vTablespaceName || ' will not be extended' );
       LogFacility(LOG_SEV_WARNING, 'OMF is not enabled. Tablespace ' || vTablespaceName || ' will not be extended',vTablespaceName);
        RETURN ;
    END IF ;

    -- At this point, db_create_file dest is correctly populated and we can continue
    -- This will loop just one time

    FOR rTblspaceParam IN cTblspaceParam(vTablespaceName)
    LOOP

      BEGIN

             -- =================================================================
             -- BigFile
             IF rTblspaceParam.BIGFILE = 'YES' THEN

                -- If Bigfile is in autoextend, then execute the extend command
                IF rTblspaceParam.TBSP_AUTOEXT > 0 THEN

                   IF NOT checkFreeAsmSpace(vMBToAdd)
                     THEN
                       -- dbms_output.put_line('INFO : Free ASM Space cannot accomodate ' || vMBToAdd || 'M added to tablespace' || vTableSpaceName );
                       -- dbms_output.put_line('INFO : I will increase maxsize of tablespace leave you time to add space to ASM Diskgroup') ;
                       LogFacility(LOG_SEV_ERROR, 'Free ASM Space cannot accomodate ' || vMBToAdd || 'M added to tablespace' || vTableSpaceName,vTablespaceName);
                  --     LogFacility(LOG_SEV_WARNING, 'I will increase maxsize of tablespace leave you time to add space to ASM Diskgroup',vTablespaceName);
                       LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'ERROR', 'Free ASM Space cannot accomodate ' || vMBToAdd || 'M added to tablespace' || vTableSpaceName);
                        RETURN ;
                        
                   END IF ;

                      vStmtCmd := 'ALTER TABLESPACE ' || UPPER(vTablespaceName) || ' AUTOEXTEND ON NEXT 128M MAXSIZE ' || TO_NUMBER(vMBToAdd + rTblspaceParam.TBSP_MAXSIZE_MB) || 'M';

                ELSE

                    -- In this case, I need to resize the tablespace datafile
                    -- Checking that free Space can accomodate the new file size
                    -- I will check space only if there is ASM as storage manager
                    IF vOmfEnabled = 'ASM' THEN

                        IF checkFreeAsmSpace(vMBToAdd) THEN
                            -- vStmtCmd := 'ALTER TABLESPACE ' || UPPER(vTablespaceName)  || ' RESIZE ' || TO_NUMBER(vMBToAdd + rTblspaceParam.TBSP_MAXSIZE_MB) || 'M';
                            vStmtCmd := 'ALTER TABLESPACE ' || UPPER(vTablespaceName) || ' AUTOEXTEND ON NEXT 128M MAXSIZE ' || TO_NUMBER(vMBToAdd + rTblspaceParam.TBSP_MAXSIZE_MB) || 'M';
                        ELSE
                             --dbms_output.put_line('WARN: Free ASM Space cannot accomodate tablespace ' || vTablespaceName || ' resize of ' || vMBToAdd || 'M') ;
                             LogFacility(LOG_SEV_ERROR, 'Free ASM Space cannot accomodate tablespace ' || vTablespaceName || ' resize of ' || vMBToAdd || 'M',vTablespaceName);
                             LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'ERROR', 'Free ASM Space cannot accomodate tablespace ' || vTablespaceName || ' resize of ' || vMBToAdd || 'M');
                              RETURN;

                        END IF ;

                    ELSE
                      --dbms_output.put_line('WARN : db_create_file_dest seems to reference a filesystem. Cannot check free space') ;
                      --dbms_output.put_line('WARN : Tablespace ' || vTablespaceName || ' will not be extended') ;
                      LogFacility(LOG_SEV_WARNING, 'db_create_file_dest seems to reference a filesystem. Cannot check free space',vTablespaceName);
                      LogFacility(LOG_SEV_WARNING, 'Tablespace ' || vTablespaceName || ' will not be extended',vTablespaceName);
                      LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'WARNING', 'db_create_file_dest seems to reference a filesystem. Cannot check free space');

                        RETURN ;

                    END IF ;

                END IF ;

                --dbms_output.put_line('INFO : Extending tablespace : ' || vTablespacename || ' using: ');
                --dbms_output.put_line('INFO : ' || vStmtCmd);

                LogFacility(LOG_SEV_INFO, 'Extending tablespace : ' || vTablespacename || ' using: ',vTablespaceName);
                LogFacility(LOG_SEV_INFO, 'INFO : ' || vStmtCmd,vTablespaceName);

                execute immediate(vStmtCmd) ;

                LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'OK','');

                --dbms_output.put_line('INFO : Tablespace : ' || vTablespacename || ' size increased of ' || vMBToAdd || 'M') ;
                LogFacility(LOG_SEV_INFO, 'Tablespace : ' || vTablespacename || ' size increased of ' || vMBToAdd || 'M',vTablespaceName);

             ELSE
                 -- =================================================================
                 -- Here the tablespace is NOT a bigfile
                 -- The behaviour will be the same if DF is in autoextend or not
                 --

                    IF vOmfEnabled = 'ASM' THEN

                      -- I have to check the total space since the check, so I can only do it now
                      IF NOT checkFreeAsmSpace(vMBToAdd)
                        THEN
                         -- dbms_output.put_line('INFO : Free ASM Space cannot accomodate ' || vMBToAdd || 'M added to tablespace' || vTableSpaceName );
                         -- dbms_output.put_line('INFO : I will increase maxsize of tablespace leave you time to add space to ASM Diskgroup') ;
                         LogFacility(LOG_SEV_INFO, 'Free ASM Space cannot accomodate ' || vMBToAdd || 'M added to tablespace' || vTableSpaceName,vTablespaceName);
                         LogFacility(LOG_SEV_INFO, 'I will increase maxsize of tablespace leave you time to add space to ASM Diskgroup',vTablespaceName);
                         LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'WARNING','Free ASM Space cannot accomodate ' || vMBToAdd || 'M added to tablespace' || vTableSpaceName || '. I will increase maxsize of tablespace leave you time to add space to ASM Diskgroup');
                          RETURN ;

                     END IF ;


                        -- Checking if there are DF in NoAutoextend.
                        -- if yes put them in autoextend and see if that is enough to add needed space
                        CheckForAutoextendDF(vTablespaceName, vMBToAdd) ;

                        IF vMBToAdd <= 0
                        THEN

                           LogFacility(LOG_SEV_INFO,'No need to proceed. Modifying autoextend was enough to add necessary space.Exiting..',vTablespaceName);
                           LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'OK','');
                            RETURN ;

                        END IF ;


                        -- Calculating number of DF to add
                        select
                          ceil(vMBToAdd/CalculateMaxAllowedDfSize),
                          ceil(vMBToAdd/CalculateMaxAllowedDfSize)*CalculateMaxAllowedDfSize
                        into vDfToAdd ,
                             vMBToAdd
                        from dual;

                        vAddedDf := 0 ;

                        -- The Space to add need to be calculated as #dfadded*CalculateMaxAllowedDfSize
                           FOR i in 1..vDfToAdd
                            LOOP

                                BEGIN

                                    --dbms_output.put_line('INFO : Executing: ALTER TABLESPACE ' || vTablespaceName  || ' ADD DATAFILE SIZE 100M AUTOEXTEND ON NEXT 128M MAXSIZE UNLIMITED' ) ;
                                    vStmtCmd := 'ALTER TABLESPACE ' || UPPER(vTablespaceName)  || ' ADD DATAFILE SIZE 100M AUTOEXTEND ON NEXT 128M MAXSIZE UNLIMITED';
                                    LogFacility(LOG_SEV_INFO, 'Executing: ' || vStmtCmd,vTablespaceName);

                                    execute immediate(vStmtCmd) ;

                                    --dbms_output.put_line('INFO : Datafile # ' || i || ' Added ') ;
                                    LogFacility(LOG_SEV_INFO, 'Datafile # ' || i || ' Added to tablespace ' || vTablespaceName,vTablespaceName);

                                    vAddedDf := vAddedDf + 1 ;
                                    
                                    IF ( i >= 10 ) THEN
                                      EXIT;
                                    END IF ;

                                EXCEPTION
                                  WHEN OTHERS THEN
                                    LogFacility(LOG_SEV_ERROR, 'Extend Tablespace ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']', vTablespaceName );
                                    --dbms_output.put_line('ERROR: Extend Tablespace ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']' );
                                     RAISE ;
                                END ;

                            END LOOP;

                            IF vAddedDf <= vDfToAdd THEN
                               LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'OK','');
                            ELSIF vAddedDf = 10 THEN
                               LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'WARNING', 'Added maximum number of 10 datafiles to tablespace ' || vTablespaceName || '. We should add up to '|| vDfToAdd ||' to reach space to add');
                            ELSE
                               LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'WARNING', 'All required ' || vDfToAdd ||' datafiles were notadded. Added only ' || vAddedDf || '');
                            END IF ;

                    ELSE
                      --dbms_output.put_line('WARN : db_create_file_dest seems to reference a filesystem. Cannot check free space') ;
                      --dbms_output.put_line('WARN : Tablespace ' || vTablespaceName || ' will not be extended') ;
                      LogFacility(LOG_SEV_WARNING, 'db_create_file_dest seems to reference a filesystem. Cannot check free space',vTablespaceName);
                      LogFacility(LOG_SEV_WARNING, 'Tablespace ' || vTablespaceName || ' will not be extended',vTablespaceName);
                      LogResize(vTablespaceName,rTblspaceParam.USED_MB,vMBToAdd,rTblspaceParam.TBSP_MAXSIZE_MB,'ERROR', 'db_create_file_dest seems to reference a filesystem. Cannot check free space');

                        RETURN ;

                END IF ;


             END IF ;

      EXCEPTION
              WHEN OTHERS THEN
                --LogFacility(LOG_SEV_ERROR, SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']', pTableName );
                --dbms_output.put_line('ERROR: During executions of : ' || vStmtCmd );
                --dbms_output.put_line('ERROR: Extend Tablespace ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']' );
                LogFacility(LOG_SEV_ERROR, 'During executions of : ' || vStmtCmd, vTablespaceName );
                LogFacility(LOG_SEV_ERROR, 'Extend Tablespace ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']', vTablespaceName );
      END ;

    END LOOP;


  END ;

  PROCEDURE DisplayTblSpaceOverLimit
  AS

  vRecCount NUMBER := 0 ;

  CURSOR cTblspaceOver IS (
      select '#' || ROWNUM || TBLS_OUTPUT as TBLS_OUTPUT
      FROM (
        SELECT
           case
             WHEN TBSP_MAXSIZE_MB < V_NORM_SIZE*1024 AND ( USED_PERCENT >= 80  and USED_PERCENT < 90 )
               THEN '   #WARN - '|| RPAD(db_unique_name,10,' ' ) || RPAD('#Tablespace #'||TBS_NAME || '#' ,40,' ' ) || RPAD('USED='||trunc(USED_MB) || ' MB',15,' ') || RPAD(' USED% : '|| USED_PERCENT ||'%',25,' ') || RPAD('( Warn=' || WARN_PERC || '%',15,' ') || RPAD('Crit=' || ERR_PERC  || '% )',14,' ') ||' MAXSIZE:' || LPAD(TBSP_MAXSIZE_MB,10,' ' ) ||'MB'
             WHEN TBSP_MAXSIZE_MB < V_NORM_SIZE*1024 AND ( USED_PERCENT >= 90 )
               THEN '   #CRIT - '||RPAD(db_unique_name,10,' ' ) || RPAD('#Tablespace #'||TBS_NAME  || '#',40,' ' ) || RPAD('USED='||trunc(USED_MB) || ' MB',15,' ') || RPAD(' USED% : '|| USED_PERCENT ||'%',25,' ') || RPAD('( Warn=' || WARN_PERC || '%',15,' ') || RPAD('Crit=' || ERR_PERC  || '% )',14,' ') || ' MAXSIZE:' || LPAD(TBSP_MAXSIZE_MB,10,' ' ) ||'MB'
             WHEN  TBSP_MAXSIZE_MB >= V_NORM_SIZE*1024 AND ( USED_MB >= WARN_SIZE_MB  and USED_MB < ERR_SIZE_MB )
               THEN '   #WARN - '|| RPAD(db_unique_name,10,' ' ) || RPAD('#Tablespace #'||TBS_NAME  || '#',40,' ' ) || RPAD('USED='||trunc(USED_MB) || ' MB',15,' ') || RPAD(' USED% : '|| USED_PERCENT ||'%',25,' ') || RPAD('( Warn=' || WARN_PERC || '%',15,' ') || RPAD('Crit=' || ERR_PERC  || '% )',14,' ') ||' MAXSIZE:' || LPAD(TBSP_MAXSIZE_MB,10,' ' ) ||'MB'
             WHEN TBSP_MAXSIZE_MB >= V_NORM_SIZE*1024 AND (USED_MB >= ERR_SIZE_MB)
               THEN '   #CRIT - '||RPAD(db_unique_name,10,' ' ) || RPAD('#Tablespace #'||TBS_NAME  || '#',40,' ' ) || RPAD('USED='||trunc(USED_MB) || ' MB',15,' ') || RPAD(' USED% : '|| USED_PERCENT ||'%',25,' ') || RPAD('( Warn=' || WARN_PERC || '%',15,' ') || RPAD('Crit=' || ERR_PERC  || '% )',14,' ') || ' MAXSIZE:' || LPAD(TBSP_MAXSIZE_MB,10,' ' ) ||'MB'
            END TBLS_OUTPUT
        from (
          SELECT tbs.tablespace_name tbs_name,db_unique_name,
                 bigfile,
                 ROUND(a.b_max / 1024 / 1024, 0)  TBSP_MAXSIZE_MB,
                 ROUND(( a.b_allocati - NVL(f.b_free, 0) )/1024/1024, 0)     USED_MB,
                 ROUND((( a.b_allocati - NVL(f.b_free, 0) )/1024/1024)*100/(a.b_max/1024/1024),2)     USED_PERCENT,
                 (DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN(a.b_max/1024/1024/1024))*1024 WARN_SIZE_MB,
                 ROUND((DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN((a.b_max/1024/1024/1024))*100/(a.b_max/1024/1024/1024)),2) WARN_PERC,
                 (DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN(a.b_max/1024/1024/1024))*1024 ERR_SIZE_MB,
                 ROUND((DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN((a.b_max/1024/1024/1024))*100/(a.b_max/1024/1024/1024)),2) ERR_PERC
          FROM   dba_tablespaces tbs, v$database
               , (SELECT tablespace_name
                         , SUM(bytes)                                     b_allocati
                         , SUM(DECODE (maxbytes, '0', bytes, maxbytes))   b_max
                  FROM   dba_data_files
                  GROUP  BY tablespace_name) a
               , (SELECT tablespace_name
                         , SUM(bytes)  b_free
                         , MAX(blocks) max_blk
                  FROM   dba_free_space
                  GROUP  BY tablespace_name) f
               , (SELECT tablespace_name
                         , COUNT(*) df#
                  FROM   dba_data_files
                  GROUP  BY tablespace_name) df
          WHERE  tbs.tablespace_name = a.tablespace_name
               AND tbs.tablespace_name = f.tablespace_name(+)
               AND tbs.tablespace_name = df.tablespace_name
               AND tbs.tablespace_name not like 'UNDO%'
        )
        WHERE USED_MB > WARN_SIZE_MB
        )
        WHERE TBLS_OUTPUT IS NOT NULL
        )
        ORDER BY 1 ;

    BEGIN


       FOR rTblspaceOver in cTblspaceOver
        LOOP

          dbms_output.put_line(rTblspaceOver.TBLS_OUTPUT);
          vRecCount := vRecCount + 1 ;

        END LOOP ;

       IF vRecCount = 0 THEN
          dbms_output.put_line('No Tablespace over Limit');
       END IF ;

  END ;



  PROCEDURE ExtendTablespaceAuto
  AS

  CURSOR cTblspaceOver IS (
        select
           tbs_name tablespace_name,
           USED_MB,
           WARN_SIZE_MB,
           TBSP_MAXSIZE_MB
        from (
          SELECT tbs.tablespace_name tbs_name,db_unique_name,
                 bigfile,
                 ROUND(a.b_max / 1024 / 1024, 0)  TBSP_MAXSIZE_MB,
                 ROUND(( a.b_allocati - NVL(f.b_free, 0) )/1024/1024, 0)     USED_MB,
                 ROUND((( a.b_allocati - NVL(f.b_free, 0) )/1024/1024)*100/(a.b_max/1024/1024),2)     USED_PERCENT,
                 (DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN(a.b_max/1024/1024/1024))*1024 WARN_SIZE_MB,
                 ROUND((DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN((a.b_max/1024/1024/1024))*100/(a.b_max/1024/1024/1024)),2) WARN_PERC,
                 (DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN(a.b_max/1024/1024/1024))*1024 ERR_SIZE_MB,
                 ROUND((DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN((a.b_max/1024/1024/1024))*100/(a.b_max/1024/1024/1024)),2) ERR_PERC
          FROM   dba_tablespaces tbs, v$database
               , (SELECT tablespace_name
                         , SUM(bytes)                                     b_allocati
                         , SUM(DECODE (maxbytes, '0', bytes, maxbytes))   b_max
                  FROM   dba_data_files
                  GROUP  BY tablespace_name) a
               , (SELECT tablespace_name
                         , SUM(bytes)  b_free
                         , MAX(blocks) max_blk
                  FROM   dba_free_space
                  GROUP  BY tablespace_name) f
               , (SELECT tablespace_name
                         , COUNT(*) df#
                  FROM   dba_data_files
                  GROUP  BY tablespace_name) df
          WHERE  tbs.tablespace_name = a.tablespace_name
               AND tbs.tablespace_name = f.tablespace_name(+)
               AND tbs.tablespace_name = df.tablespace_name
               AND tbs.tablespace_name not like 'UNDO%'
        )
        WHERE USED_MB > WARN_SIZE_MB
        ) ;

    BEGIN

     LogFacility(LOG_SEV_INFO, 'Automatic Tablespace Extend job started...' , NULL);

       FOR rTblspaceOver in cTblspaceOver
        LOOP

          BEGIN

              -- I will extend tablespace only if last tablespace add has been performed one day earlier
                IF CanTablespaceBeExtended(rTblspaceOver.tablespace_name) = 1 THEN
                  ExtendTablespace(rTblspaceOver.tablespace_name);
                ELSE
                   LogFacility(LOG_SEV_WARNING, 'This tablespace ' || rTblspaceOver.tablespace_name || ' need to be extended again, but it has been already extended less than 24h ago ' , rTblspaceOver.tablespace_name );
                   LogResize(rTblspaceOver.tablespace_name,rTblspaceOver.USED_MB,0,rTblspaceOver.TBSP_MAXSIZE_MB,'ERROR', 'This tablespace ' || rTblspaceOver.tablespace_name || ' need to be extended again, but it has been already extended less than 24h ago ');
                END IF ;

          EXCEPTION
            WHEN OTHERS THEN
               LogResize(rTblspaceOver.tablespace_name,rTblspaceOver.USED_MB,0,rTblspaceOver.TBSP_MAXSIZE_MB,'ERROR', 'Extend Tablespace ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']');
          END ;

        END LOOP ;

      LogFacility(LOG_SEV_INFO, 'Automatic Tablespace Extend job finished' , NULL);

  END ;


PROCEDURE LogFacility( pSeverity         INTEGER,
                       pMessage          VARCHAR2,
                       pTablespaceName   VARCHAR2)

AS
   vSeverityText VARCHAR2(10) ;

    BEGIN

         SELECT
            RPAD(decode(pSeverity, -1, 'DEBUG',0,'INFO',1 ,'WARN',2 ,'ERROR','INFO'),5,' ')
         INTO vSeverityText
         FROM DUAL;

        dbms_output.put_line ( vSeverityText || ': ' || pMessage ) ;

        INSERT INTO DBA_OP.MAINT_TABLESPACE_LOG
            (datetime,
             severity,
             tablespace_name,
             message)
        SELECT
             sysdate,
             decode(pSeverity, -1, 'DEBUG',0,'INFO',1 ,'WARN',2 ,'ERROR','INFO'),
             UPPER(pTablespaceName),
             SUBSTR(pMessage,1,3999)
         FROM DUAL;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
           dbms_output.put_line ( pSeverity || '  ' || pTableSpaceName || ' : ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']' );
           --LogFacility(LOG_SEV_ERROR, 'During executions ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']', pTablespaceName );
            ROLLBACK;
    END;


PROCEDURE LogResize(  pTablespaceName   VARCHAR2 ,
                      pUserMb           NUMBER  ,
                      pAddedMb          NUMBER  ,
                      pMaxsizeMb        NUMBER ,
                      pStatus           VARCHAR2 DEFAULT 'OK',
                      pMessages         VARCHAR2 DEFAULT '')
     AS


    BEGIN

        INSERT INTO DBA_OP.MAINT_TABLESPACE_RESIZE
            (datetime,
             tablespace_name,
             used_mb,
             added_mb,
             maxsize_mb,
             status,
             resize_message)
        SELECT
             sysdate,
             upper(pTablespaceName),
             pUserMb,
             pAddedMb,
             pMaxsizeMb,
             pStatus,
             pMessages
         FROM DUAL;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
           LogFacility(LOG_SEV_ERROR, 'During executions ' || SQLERRM || ' [Code: ' || TO_CHAR(SQLCODE) || ']', pTablespaceName );
            ROLLBACK;
    END;


PROCEDURE PURGE_DBA_RECYCLEBIN(
  p_purge_before_days   in NUMBER default 30,
  p_dryrun              in varchar2 := 'Y',
  p_schema              in varchar2 default NULL
)
---Requirements:
-- grant PURGE DBA_RECYCLEBIN to DBA_OP;
-- grant select on dba_users lo DBA_OP;
-- grant select on dba_recyclebin to DBA_OP;
--HOW TO USE IT
--If youd like to test to see what it would do, without actually purging anything,
--just do pass the p_dryrun parameter the value Y and set serveroutput on size 1000000. This will list the commands that it would run, but it doesnt actually run them.
--
--Purging all recyclebin objects before a given date
--This will display all recyclebin objects that were dropped before 10 days ago according to SYSDATE: the dryrun flag has been passed as Y
--   execute purge_dba_recyclebin(10,NULL,'Y');
-- now do it really:
---execute purge_dba_recyclebin(10,'N');

is
  cursor c_purge_before_date is
    select
      owner,
      object_name
    from  dba_recyclebin
    where to_date(droptime,'YYYY-MM-DD:HH24:MI:SS') < (SYSDATE - p_purge_before_days)
    and   can_purge = 'YES'
    and type='TABLE'
    and owner in (
         select
           username
         from dba_users
         where created > (select created + interval '30' minute from v$database) and username not in (select
                  value
                from dba_scheduler_job_args
                where job_name like 'PURGE%RECYCLE%'
                and argument_position = 3
                and owner = 'DBA_OP'
                ) and p_schema is null
        union all
        select
         p_schema
        from dual
    );


  v_sql varchar2(1024);

  e_38302 exception;
  pragma exception_init(e_38302,-38302);


begin

     for r in c_purge_before_date loop

            v_sql := 'purge table '||r.owner||'."'||r.object_name||'"';
            if (p_dryrun = 'N') then

              begin
                execute immediate v_sql;
              exception
                 when e_38302 then
                   dbms_output.put_line('Warning; object '||r.owner||'.'||r.object_name||' does not exist. Ignoring.');
                 when others then
                   dbms_output.put_line('Error dropping '||r.owner||'.'||r.object_name);
                   dbms_output.put_line(dbms_utility.format_error_backtrace);
              end;
            else
              dbms_output.put_line(v_sql);
            end if;

     end loop;

END PURGE_DBA_RECYCLEBIN;


PROCEDURE PRC_DB_GROWTH_DATA IS

BEGIN

-- Insert tables Growth size
INSERT INTO DBA_OP.DB_SEGMENTS_GROWTH
select
   sysdate as INS_DATE,
   owner,
   segment_name,
   partition_name,
   decode(compression,'NO','DISABLED',compression) COMPRESSION,
   sum(size_mb) SIZE_MB,
   sum(NROWS) NROWS,
   SEGMENT_TYPE,
   subpartition_name
from (
SELECT
         OWNER,
         SEGMENT_NAME,
         partition_name,
         SUM(SIZE_MB) SIZE_MB,
         SUM(nvl(NUM_ROWS,0)) as NROWS,
         TABLESPACE_NAME,
         compression,
         SEGMENT_TYPE,
         subpartition_name
     FROM (
            SELECT   s.owner,
                          s.segment_name,
                         -- s.segment_type,
                          s.tablespace_name,
                          t.partition_name,
                          ROUND(s.BYTES / 1048576) SIZE_MB,
                          num_rows,
                          t.compression,
                          'TABLE PARTITION' as SEGMENT_TYPE,
                          NULL   as subpartition_name
                           FROM dba_segments s,
                                    dba_tab_partitions t
                           WHERE s.segment_type != 'TEMPORARY' and
                                      S.OWNER = T.TABLE_OWNER AND
                                     s.segment_name = t.table_name and
                                     s.partition_name = t.partition_name and
                                     s.segment_type in( 'TABLE PARTITION' )
                     UNION ALL
            SELECT   s.owner,
                          s.segment_name,
                         -- s.segment_type,
                          s.tablespace_name,
                          t.partition_name,
                          ROUND(s.BYTES / 1048576) SIZE_MB,
                          num_rows,
                          t.compression,
                          'TABLE SUBPARTITION',
                          t.subpartition_name
                           FROM dba_segments s,
                                    dba_tab_subpartitions t
                           WHERE s.segment_type != 'TEMPORARY' and
                                      S.OWNER = T.TABLE_OWNER AND
                                     s.segment_name = t.table_name and
                                     s.partition_name = t.subpartition_name and
                                     s.segment_type in( 'TABLE SUBPARTITION' )
                     UNION ALL
            SELECT   s.owner,
                          s.segment_name,
                          --s.segment_type,
                          s.tablespace_name,
                                                                                                s.partition_name,
                          ROUND(s.BYTES / 1048576) SIZE_MB,
                          num_rows,
                                                                                                t.compression,
                          'TABLE',
                          NULL
                           FROM dba_segments s,
                                    dba_tables t
                           WHERE s.segment_type != 'TEMPORARY' and
                                 s.partition_name is null and
                                      S.OWNER = T.OWNER AND
                                     s.segment_name = t.table_name  and
                                     s.segment_type in( 'TABLE')
                     UNION ALL
            SELECT   s.owner,
                          l.TABLE_NAME,
                          --'TABLE' segment_type,
                          s.tablespace_name,
                                                                                                s.partition_name,
                         ROUND(s.BYTES / 1048576) SIZE_MB,
                          NULL as num_rows,
                                                                                                l.compression,
                          'LOB',
                          NULL
                           FROM dba_segments s,
                                dba_lobs l
                           WHERE s.segment_type != 'TEMPORARY' and
                                      S.OWNER = l.OWNER AND
                                     s.segment_name = L.SEGMENT_NAME
)
GROUP BY OWNER,
         SEGMENT_NAME,
         partition_name,
         TABLESPACE_NAME,
         compression,
         SEGMENT_TYPE,
         subpartition_name
ORDER BY SIZE_MB DESC
)
WHERE owner in ( select username from dba_users where created > (select created + interval '30' minute from v$database) )
group by owner,
         segment_name,
         partition_name,
         decode(compression,'NO','DISABLED',compression),
         SEGMENT_TYPE,
         subpartition_name;


-- Index Growth Informations
INSERT INTO DBA_OP.DB_SEGMENTS_GROWTH
select
   sysdate as INS_DATE,
   owner,
   segment_name,
   partition_name,
   decode(compression,'NO','DISABLED',compression) COMPRESSION,
   sum(size_mb) SIZE_MB,
   sum(NROWS) NROWS,
   SEGMENT_TYPE,
   subpartition_name
from (
SELECT
         OWNER,
         SEGMENT_NAME,
         partition_name,
         SUM(SIZE_MB) SIZE_MB,
         SUM(nvl(NUM_ROWS,0)) as NROWS,
         --SEGMENT_TYPE,
         TABLESPACE_NAME,
         compression,
         SEGMENT_TYPE,
         subpartition_name
     FROM (
 SELECT   s.owner,
                          s.segment_name,
                         -- s.segment_type,
                          s.tablespace_name,
                          t.partition_name,
                          ROUND(s.BYTES / 1048576) SIZE_MB,
                          num_rows,
                          t.compression,
                          'INDEX PARTITION' as SEGMENT_TYPE,
                          NULL   as subpartition_name
                           FROM dba_segments s,
                                    dba_ind_partitions t
                           WHERE s.segment_type != 'TEMPORARY' and
                                      S.OWNER = T.INDEX_OWNER AND
                                     s.segment_name = t.index_name and
                                     s.partition_name = t.partition_name and
                                     s.segment_type in( 'INDEX PARTITION' )
                     UNION ALL
 SELECT   s.owner,
                          s.segment_name,
                         -- s.segment_type,
                          s.tablespace_name,
                          t.partition_name,
                          ROUND(s.BYTES / 1048576) SIZE_MB,
                          num_rows,
                          t.compression,
                          'INDEX SUBPARTITION' as SEGMENT_TYPE,
                          subpartition_name
                           FROM dba_segments s,
                                    dba_ind_subpartitions t
                           WHERE s.segment_type != 'TEMPORARY' and
                                      S.OWNER = T.INDEX_OWNER AND
                                     s.segment_name = t.index_name and
                                     s.partition_name = t.subpartition_name and
                                     s.segment_type in( 'INDEX SUBPARTITION' )
                     UNION ALL
            SELECT   s.owner,
                          s.segment_name,
                          --s.segment_type,
                          s.tablespace_name,
                          s.partition_name,
                          ROUND(s.BYTES / 1048576) SIZE_MB,
                          num_rows,
                          t.compression,
                          'INDEX',
                          NULL
                           FROM dba_segments s,
                                    dba_indexes t
                           WHERE s.segment_type != 'TEMPORARY' and
                                 s.partition_name is null and
                                      S.OWNER = T.OWNER AND
                                     s.segment_name = t.table_name  and
                                     s.segment_type in( 'INDEX')
   )
GROUP BY OWNER,
         SEGMENT_NAME,
         partition_name,
         TABLESPACE_NAME,
         compression,
         SEGMENT_TYPE,
         subpartition_name
ORDER BY SIZE_MB DESC
)
WHERE owner in ( select username from dba_users where created > (select created + interval '30' minute from v$database) )
group by owner,
         segment_name,
         partition_name,
         decode(compression,'NO','DISABLED',compression),
         SEGMENT_TYPE,
         subpartition_name;


INSERT INTO DBA_OP.DB_TABLESPACES_GROWTH
  SELECT
         SYSDATE as INS_DATE,
         tbs.tablespace_name
       , ROUND(a.b_allocati / 1024 / 1024, 0)                                                  mb_allocati
       , ROUND(( a.b_allocati - NVL(f.b_free, 0) ) / 1024 / 1024, 0)     mb_occupati
  FROM   dba_tablespaces tbs
       , (SELECT tablespace_name
                 , SUM(bytes)                                     b_allocati
                 , SUM(DECODE (maxbytes, '0', bytes, maxbytes))   b_max
                -- , WM_CONCAT(DISTINCT autoextensible)             autoextensible
          FROM   dba_data_files
          GROUP  BY tablespace_name) a
       , (SELECT tablespace_name
                 , SUM(bytes)  b_free
                 , MAX(blocks) max_blk
          FROM   dba_free_space
          GROUP  BY tablespace_name) f
       , (SELECT tablespace_name
                 , COUNT(*) df#
          FROM   dba_data_files
          GROUP  BY tablespace_name) df
  WHERE  tbs.tablespace_name = a.tablespace_name
       AND tbs.tablespace_name = f.tablespace_name(+)
       AND tbs.tablespace_name = df.tablespace_name ;

END;


PROCEDURE PURGE_TABLE_AM_OBJ( p_dryrun VARCHAR2 DEFAULT 'Y' )
-- COMMENT the AUTHID string IF THE JOB IS CREATED not in a VAULT environment with owner SYS
is
-- PURGE PROCEDURE USER TABLES PROFILES 0
--
-- Procedure for deleting AM_OBJ tables intended for deletion for a maximum period
-- di giacienza stabilito nelle seguanti modalita :
-- The tables will have the following suffixes which determine their maximum time spent on the DB:
-- "DAY_" - One day of stay
-- "WEEK_" - One week stay
-- "MONTH_"  - Un mese di permanenza
-- "MONTH3_" - Tre mesi ( 90 day )
-- ATTENTION !!!! The tables created with these suffixes will be maintained for the established period
-- ALL others that do not maintain this standard will be CANCELED IMMEDIATELY!!!!
--
-- !!!!!!!!!!!!!!
-- NOTA ATTENZIONE !!!!!
-- The schemes that are subjected to this procedure must be explained DIRECTLY in this procedure
-- which will consequently be SELF-CONSISTENT for the management of the schemes themselves !!!!!!!!

--
-- !!!!!!!!!!
-- UTENZE INTERESSATE DA TALE SVECCHIAMENTO :
--  - ICTEIM_OBJ
--  - REPLAY_OBJ          -- inserita il 13-4-2018
--  - SOPRA_OBJ           -- inserita il 13-4-2018
--  - NEXI_DIGITAL_OBJ    -- inserita il 20-4-2018
--  - NEXI_OBJ            -- inserita il 13-9-2019
--  - NEXI_DST_OBJ        -- inserita il 05-5-2021
--
--  !!!!!! Tali utenze sono inserite nella clausola descritta in basso
--
------------------------------------------------------------------------------------ BEGIN
ecode    NUMBER(38);

begin
for drop_am_table in
 ( select 'drop table "'||owner||'"."'||object_name||'" cascade constraint purge'  command,
           owner,object_name,created ,trunc (sysdate) - trunc(created) day
from (
-- Dated tables > One Day
select owner,object_name,created from dba_objects
 where object_type ='TABLE'
   and object_name like 'DAY/_%' escape '/'
   and trunc (sysdate) - trunc(created) > 0
union
-- Dated tables > One Week
select owner,object_name,created from dba_objects
 where object_type ='TABLE'
   and object_name like 'WEEK/_%' escape '/'
   and trunc (sysdate) - trunc(created) > 7
union
-- Tabelle datate > Un Mese
select owner,object_name,created from dba_objects
 where object_type ='TABLE'
   and object_name like 'MONTH/_%' escape '/'
   and trunc (sysdate) - trunc(created) > 30
union
-- Tables dated > 90 days
select owner,object_name,created from dba_objects
 where object_type ='TABLE'
   and object_name like 'MONTH3/_%' escape '/'
   and trunc (sysdate) - trunc(created)> 90
-- Unauthorized tables without suffix
--- Abilitato il 6/7/2018
union
select owner,object_name,created from dba_objects
 where object_type ='TABLE'
   and object_name not like 'MONTH3/_%' escape '/'
   and object_name not like 'MONTH/_%' escape '/'
   and object_name not like 'WEEK/_%' escape '/'
   and object_name not like 'DAY/_%' escape '/'
------------------------------------------- !!! UTENZE DA SVECCHIARE
----in ('<UTENTE_OBJ','........') ----------------------------------
--------------------------------------------------------------------
---!!!!! ATTENZIONE NON COMMENTARE QUESTA CLAUSOLA !!!! ------------
 ) where owner in ('ICTEAM_OBJ','SOPRA_OBJ','REPLY_OBJ','NEXI_DIGITAL_OBJ','NEXI_OBJ','NEXI_DST_OBJ')
     and owner in ( select username from dba_op.purge_table_am_users )
   )
  loop
   begin

        dbms_output.put_line ( drop_am_table.command );

        if p_dryrun = 'N' then
            execute immediate  drop_am_table.command;
            insert into DBA_OP.PURGE_TABLE_AM_OBJ_LOG values (sysdate,drop_am_table.owner,drop_am_table.object_name,'DROP');
        end if ;

    exception when others then
     ecode := SQLCODE;
     insert into DBA_OP.PURGE_TABLE_AM_OBJ_LOG values (sysdate,drop_am_table.owner,drop_am_table.object_name,to_char(ecode));
   end;
  end loop;

commit;

END;


PROCEDURE PRC_TEMP_USE_HISTORY
IS
BEGIN
     INSERT INTO DBA_OP.TEMP_USE_HISTORY
     SELECT *
     FROM DBA_OP.VW_TEMP_USE
     WHERE ROWNUM < 10;

     COMMIT;

 END;


PROCEDURE PRC_UNDO_USE_HISTORY
IS
BEGIN
     INSERT INTO DBA_OP.UNDO_USE_HISTORY
     SELECT *
     FROM DBA_OP.VW_UNDO_USE
     WHERE ROWNUM < 10;

     COMMIT;

 END;


END PKG_DBA_UTILITY;
/





-- Creating Views to monitor abnormal tablespace growth
CREATE OR REPLACE VIEW DBA_OP.VW_TBLSPC_OVER_GROWTH AS
with tbs_growth as (
select *
from (
select 
  ins_date,
  tablespace_name,
  mb_occupati,
  mb_occupati - lag(mb_occupati) over ( partition by tablespace_name order by ins_date) as MB_GROWTH--,
  --round(avg(mb_occupati) over ( partition by tablespace_name order by ins_date)) avg_growth
from DBA_OP.DB_TABLESPACES_GROWTH
)
WHERE MB_GROWTH > 0
order by 2,1
),
last_growth as (
select 
  tablespace_name,
  ins_date ,
  mb_growth
from tbs_growth
where ins_date > SYSDATE - 6
)
select 
  lg.ins_date,
  tg.*,
  lg.mb_growth
from (
select
  tablespace_name,
  PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY mb_growth ) as mb_growth_90
from tbs_growth 
group by tablespace_name
) tg, last_growth lg
where tg.tablespace_name = lg.tablespace_name
and lg.mb_growth > 1.2*tg.mb_growth_90
and mb_growth > 300
order by 1 ;


-- Create VIew to monitor tablespace with checkmk Magic Factor
CREATE OR REPLACE VIEW DBA_OP.VW_TBLSPC_MONITOR AS
SELECT * FROM (
          SELECT tbs.tablespace_name tbs_name,db_unique_name,
                 bigfile,
                 ROUND(a.b_max / 1024 / 1024, 0)  TBSP_MAXSIZE_MB,
                 ROUND(( a.b_allocati - NVL(f.b_free, 0) )/1024/1024, 0)     USED_MB,
                 ROUND((( a.b_allocati - NVL(f.b_free, 0) )/1024/1024)*100/(a.b_max/1024/1024),2)     USED_PERCENT,
                 (DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN(a.b_max/1024/1024/1024))*1024 WARN_SIZE_MB,
                 ROUND((DBA_OP.PKG_DBA_UTILITY.GETWARNSIZEMN((a.b_max/1024/1024/1024))*100/(a.b_max/1024/1024/1024)),2) WARN_PERC,
                 (DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN(a.b_max/1024/1024/1024))*1024 ERR_SIZE_MB,
                 ROUND((DBA_OP.PKG_DBA_UTILITY.GETERRSIZEMN((a.b_max/1024/1024/1024))*100/(a.b_max/1024/1024/1024)),2) ERR_PERC
          FROM   dba_tablespaces tbs, v$database
               , (SELECT tablespace_name
                         , SUM(bytes)                                     b_allocati
                         , SUM(DECODE (maxbytes, '0', bytes, maxbytes))   b_max
                  FROM   dba_data_files
                  GROUP  BY tablespace_name) a
               , (SELECT tablespace_name
                         , SUM(bytes)  b_free
                         , MAX(blocks) max_blk
                  FROM   dba_free_space
                  GROUP  BY tablespace_name) f
               , (SELECT tablespace_name
                         , COUNT(*) df#
                  FROM   dba_data_files
                  GROUP  BY tablespace_name) df
          WHERE  tbs.tablespace_name = a.tablespace_name
               AND tbs.tablespace_name = f.tablespace_name(+)
               AND tbs.tablespace_name = df.tablespace_name
        )
        WHERE USED_MB > WARN_SIZE_MB ;
        


-- JOB Automatic management of Tablespaces
BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB
    (job_name  => 'DBA_OP.MAINT_TABLESPACE_JOB');

EXCEPTION
   WHEN OTHERS THEN
    NULL ;
END;
/

/* COMMENTATO PER PROD 

DECLARE 
   RAND_SEC NUMBER ;  
BEGIN

SELECT
  trunc(dbms_random.value(1,59))
INTO RAND_SEC  
FROM dual;
 
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DBA_OP.MAINT_TABLESPACE_JOB'
      ,start_date      => SYSTIMESTAMP
      ,repeat_interval => 'FREQ=HOURLY; BYMINUTE='|| RAND_SEC ||';BYSECOND=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'PLSQL_BLOCK'
      ,job_action      => '
BEGIN
    
	DBA_OP.PKG_DBA_UTILITY.EXTENDTABLESPACEAUTO;

    -- Transaction Control
    COMMIT;
END;
'
      ,comments        => NULL
    );

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DBA_OP.MAINT_TABLESPACE_JOB');
END;
/
*/


--- To schedule procedure , purge recyclebin objects older than 30 days.
---
---

BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB
    (job_name  => 'DBA_OP.PURGE_DBA_RECYCLEBIN');
EXCEPTION
   WHEN OTHERS THEN
    NULL ;
END;
/


BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB
    (job_name  => 'DBA_OP.PURGE_DBA_RECYCLEBIN_JOB');
EXCEPTION
   WHEN OTHERS THEN
    NULL ;
END;
/


BEGIN
  DBMS_SCHEDULER.CREATE_JOB(JOB_NAME   => 'DBA_OP.PURGE_DBA_RECYCLEBIN_JOB',
                            JOB_TYPE   => 'STORED_PROCEDURE',
                            JOB_ACTION => 'DBA_OP.PKG_DBA_UTILITY.PURGE_DBA_RECYCLEBIN',
                                               NUMBER_OF_ARGUMENTS =>2,
                                               repeat_interval => 'FREQ=DAILY;',
                            START_DATE => SYSDATE,
                            COMMENTS   => 'Cancellazione DBA_RECYCLEBIN');
END;
/


begin
SYS.DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(
JOB_NAME          => 'DBA_OP.PURGE_DBA_RECYCLEBIN_JOB',
argument_position => 1,
argument_value => 10);
end;
/

begin
SYS.DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(
JOB_NAME          => 'DBA_OP.PURGE_DBA_RECYCLEBIN_JOB',
argument_position => 2,
argument_value => 'N');
end;
/

begin
SYS.DBMS_SCHEDULER.enable(
name => 'DBA_OP.PURGE_DBA_RECYCLEBIN_JOB');
end;
/

COMMIT ;



-- Collect Growth job

BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB
    (job_name  => 'DBA_OP.COLLECT_DB_GROWTH_JOB');
EXCEPTION
   WHEN OTHERS THEN
    NULL ;
END;
/

DECLARE 
   RAND_SEC NUMBER ;  
BEGIN

SELECT
  trunc(dbms_random.value(1,59))
INTO RAND_SEC  
FROM dual;

  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DBA_OP.COLLECT_DB_GROWTH_JOB'
      ,start_date      => TO_TIMESTAMP_TZ('2021/11/24 10:06:22.798897 Europe/Vienna','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=DAILY; BYDAY=MON; BYHOUR=7; BYMINUTE='|| RAND_SEC || ';BYSECOND=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'PLSQL_BLOCK'
      ,job_action      => 'BEGIN
 DBA_OP.PKG_DBA_UTILITY.PRC_DB_GROWTH_DATA;
END;'
      ,comments        => NULL
    );


  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DBA_OP.COLLECT_DB_GROWTH_JOB');
END;
/


-- Temp Usage Job

BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB
    (job_name  => 'DBA_OP.PURGE_TEMP_USE_HISTORY');
EXCEPTION
   WHEN OTHERS THEN
    NULL ;
END;
/

BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB
    (job_name  => 'DBA_OP.PRC_TEMP_USE_HISTORY');
EXCEPTION
   WHEN OTHERS THEN
    NULL ;
END;
/



BEGIN


  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DBA_OP.PRC_TEMP_USE_HISTORY'
      ,start_date      => TO_TIMESTAMP_TZ('2021/11/24 10:06:22.798897 Europe/Vienna','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=MINUTELY;INTERVAL=5;'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'PLSQL_BLOCK'
      ,job_action      => 'BEGIN
 DBA_OP.PKG_DBA_UTILITY.PRC_TEMP_USE_HISTORY;
END;'
      ,comments        => NULL
    );


  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DBA_OP.PRC_TEMP_USE_HISTORY');
END;
/


-- Undo Usage Job

BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB
    (job_name  => 'DBA_OP.PURGE_UNDO_USE_HISTORY');
EXCEPTION
   WHEN OTHERS THEN
    NULL ;
END;
/

BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB
    (job_name  => 'DBA_OP.PRC_UNDO_USE_HISTORY');
EXCEPTION
   WHEN OTHERS THEN
    NULL ;
END;
/


BEGIN


  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DBA_OP.PRC_UNDO_USE_HISTORY'
      ,start_date      => TO_TIMESTAMP_TZ('2021/11/24 10:06:22.798897 Europe/Vienna','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=MINUTELY;INTERVAL=5;'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'PLSQL_BLOCK'
      ,job_action      => 'BEGIN
 DBA_OP.PKG_DBA_UTILITY.PRC_UNDO_USE_HISTORY;
END;'
      ,comments        => NULL
    );


  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DBA_OP.PRC_UNDO_USE_HISTORY');
END;
/

exit


