--- Script for Creating Table Renewal Packages

set define off
set serveroutput on

WHENEVER SQLERROR EXIT SQL.SQLCODE;

GRANT LOCK ANY TABLE TO DBA_OP;
GRANT CREATE ANY SEQUENCE TO DBA_OP ;  
GRANT EXECUTE ON UTL_FILE TO DBA_OP ;
GRANT EXECUTE ON DBMS_RANDOM to DBA_OP ;
GRANT EXP_FULL_DATABASE TO DBA_OP;
GRANT IMP_FULL_DATABASE TO DBA_OP;


DECLARE 
  V_DBVER NUMBER;
BEGIN  

  select
    replace(version,'.','')
into V_DBVER
  from PRODUCT_COMPONENT_VERSION
  where PRODUCT like 'Oracle Database%' ;

  -- When db is highe or equal to 12.1, role exists
  IF V_DBVER >= 121020 THEN 
  
    execute immediate('GRANT PDB_DBA TO DBA_OP WITH ADMIN OPTION');
     
  END IF;
  
END;
/


GRANT RESOURCE TO DBA_OP WITH ADMIN OPTION;
GRANT SELECT_CATALOG_ROLE TO DBA_OP;
GRANT ALTER ANY INDEX TO DBA_OP;
GRANT ALTER ANY TABLE TO DBA_OP;
GRANT ALTER SESSION TO DBA_OP WITH ADMIN OPTION;
GRANT ALTER USER TO DBA_OP WITH ADMIN OPTION;
GRANT CREATE ANY INDEX TO DBA_OP;
GRANT CREATE ANY TABLE TO DBA_OP;
GRANT CREATE SESSION TO DBA_OP WITH ADMIN OPTION;
GRANT CREATE SYNONYM TO DBA_OP WITH ADMIN OPTION;
GRANT DROP ANY TABLE TO DBA_OP;
GRANT EXECUTE ANY PROCEDURE TO DBA_OP;
GRANT LOCK ANY TABLE TO DBA_OP;
GRANT SELECT ANY DICTIONARY TO DBA_OP;
GRANT SELECT ANY TABLE TO DBA_OP;
GRANT UNLIMITED TABLESPACE TO DBA_OP WITH ADMIN OPTION;
GRANT SELECT ANY TABLE TO DBA_OP ;
GRANT INSERT ANY TABLE TO DBA_OP ;
GRANT UPDATE  ANY TABLE TO DBA_OP ;
GRANT DELETE ANY TABLE TO DBA_OP ;
GRANT DROP ANY INDEX TO DBA_OP;
GRANT EXECUTE ON SYS.UTL_FILE TO DBA_OP;
GRANT EXECUTE ON SYS.UTL_SMTP TO DBA_OP;
GRANT EXECUTE ON SYS.UTL_TCP TO DBA_OP;
GRANT ALTER ANY SEQUENCE TO DBA_OP ;
GRANT CREATE TYPE TO DBA_OP ;
  


   DECLARE 
     V_ACL_EXISTS NUMBER ;	  
begin

   select 
  count(*)
into V_ACL_EXISTS
FROM   dba_network_acls
where acl = '/sys/acls/smtp_acl_pm.xml' ;

IF V_ACL_EXISTS = 0 THEN

	dbms_network_acl_admin.create_acl (
	acl => 'smtp_acl_pm.xml',
	description => 'SMTP Access',
	principal => 'DBA_OP', -- the user name trying to access the network resource
	is_grant => TRUE,
privilege => 'connect',
	start_date => null,
	end_date => null
	);
END IF;

end;
/

BEGIN

	dbms_network_acl_admin.assign_acl (

	acl => 'smtp_acl_pm.xml',
	host => '10.10.122.21',
	lower_port => 25,
	upper_port => 25
	);

END;
/

BEGIN

	dbms_network_acl_admin.assign_acl (

	acl => 'smtp_acl_pm.xml',
	host => '10.11.7.224',
	lower_port => 25,
	upper_port => 25
	);

END;
/

BEGIN

	dbms_network_acl_admin.assign_acl (

	acl => 'smtp_acl_pm.xml',
	host => '192.168.36.62',
	lower_port => 25,
	upper_port => 25
	);

END;
/


begin

	DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl => 'smtp_acl_pm.xml',
principal => 'DBA_OP',
	is_grant => true,
	privilege => 'resolve');

end;
/

begin

	DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl => 'smtp_acl_pm.xml',
principal => 'DBA_OP',
	is_grant => true,
privilege => 'connect');

end;
/


CREATE OR REPLACE TYPE DBA_OP.PM_PARTITION_LIST_TYPE IS TABLE OF DBA_OP.PM_PART_REC_TYPE
/

CREATE OR REPLACE TYPE DBA_OP.PM_CONSTRAINT_LIST_TYPE IS TABLE OF VARCHAR2(4000)
/


	
CREATE OR REPLACE TYPE DBA_OP.PM_PART_REC_TYPE FORCE AS OBJECT (
  PARTITION_NAME       VARCHAR2(30),
  PARTITION_HIGH_VALUE NUMBER,
  TABLESPACE_NAME      VARCHAR2(30)
)
/


BEGIN
   execute immediate('DROP SEQUENCE DBA_OP.MAIN_PARTITIONS_SEQ') ;
EXCEPTION
WHEN OTHERS
   THEN
     DBMS_OUTPUT.PUT_LINE('Sequence DBA_OP.MAIN_PARTITIONS_SEQ does not exist , but this is not a problem. It belongs to a older PM version. Will not be created again');
END;
/


  
BEGIN
   execute immediate('DROP SEQUENCE DBA_OP.PARTITIONS_LOG_SEQ') ;
EXCEPTION
WHEN OTHERS
   THEN
     DBMS_OUTPUT.PUT_LINE('Sequence DBA_OP.MAIN_PARTITIONS_LOG_SEQ does not exist , but this is not a problem. It will be created later');
END;
/


CREATE SEQUENCE DBA_OP.PARTITIONS_LOG_SEQ
  START WITH 1
  MAXVALUE 9999999999999999999999999999
  MINVALUE 0
  NOCYCLE
  NOCACHE
  NOORDER;


  
---- Creation of Configuration Table

DECLARE 

 TAB_EXISTS NUMBER;

BEGIN

    SELECT 
	 COUNT(*) 
	INTO TAB_EXISTS
	FROM DBA_TABLES 
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.MAINT_PARTITIONS' ;
	
	IF TAB_EXISTS > 0 THEN
	  execute immediate('CREATE GLOBAL TEMPORARY TABLE DBA_OP.TEMP_MAINT_PARTITIONS ON COMMIT PRESERVE ROWS AS SELECT * FROM DBA_OP.MAINT_PARTITIONS');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table MAINT_PARTITIONS does not exist. This seems to be the first installation of PM. Continue');
	END IF ;

EXCEPTION
WHEN OTHERS
 THEN

	 IF SQLCODE = -955 THEN
		 DBMS_OUTPUT.PUT_LINE('TEMP_MAINT_PARTITIONS already exists. Please check the content of DBA_OP.TEMP_MAINT_PARTITIONS. If is not usefull, drop table and run script againt.'|| SUBSTR(SQLERRM, 1, 64));
	 END IF ;

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
	WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.MAINT_PARTITIONS_EMAIL' ;
	
	IF TAB_EXISTS > 0 THEN
	  execute immediate ('CREATE GLOBAL TEMPORARY TABLE DBA_OP.TEMP_MAINT_PARTITIONS_EMAIL ON COMMIT PRESERVE ROWS AS SELECT * FROM DBA_OP.MAINT_PARTITIONS_EMAIL');
	ELSE
	  DBMS_OUTPUT.PUT_LINE('Table TEMP_MAINT_PARTITIONS_EMAIL does not exist. This seems to be the first installation of PM. Continue');
	END IF ;

EXCEPTION
WHEN OTHERS
 THEN
   IF SQLCODE = -955 THEN
		 DBMS_OUTPUT.PUT_LINE('TEMP_MAINT_PARTITIONS_EMAIL already exists. Please check the content of TEMP_MAINT_PARTITIONS_EMAIL. If is not usefull, drop table and run script againt.'|| SUBSTR(SQLERRM, 1, 64));
   END IF ;

      RAISE;  
END;
/

  
BEGIN

   execute immediate('DROP TABLE DBA_OP.MAINT_PARTITIONS_EMAIL') ;

EXCEPTION
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Table DBA_OP.MAINT_PARTITIONS_EMAIL does not exist , but this is not a problem. It will be created later' );
END;
/

  
CREATE TABLE DBA_OP.MAINT_PARTITIONS_EMAIL
(
  ENABLED       CHAR(1 BYTE),
  SMTP_HOST     VARCHAR2(200 BYTE),
  SMTP_PORT     NUMBER                          DEFAULT 25,
  EMAIL_FROM    VARCHAR2(200 BYTE),
  CONTENT_INFO  VARCHAR2(200 BYTE)
)
TABLESPACE DBA_OP_DATA;


BEGIN
 
   -- I drop the table
   execute immediate('DROP TABLE DBA_OP.TEMP_MAINT_PARTITIONS_GRANT CASCADE CONSTRAINTS');
 
EXCEPTION
	WHEN OTHERS
	 THEN
      DBMS_OUTPUT.PUT_LINE('Table DBA_OP.TEMP_MAINT_PARTITIONS_GRANT does not exist , but this is not a problem. It will be created soon' );
END;
/


BEGIN
   -- Before dropping the tables, I get the grants given to other users 
   execute immediate ('CREATE GLOBAL TEMPORARY TABLE DBA_OP.TEMP_MAINT_PARTITIONS_GRANT ON COMMIT PRESERVE ROWS AS	select ''GRANT '' || PRIVILEGE || '' ON '' || OWNER || ''.'' || TABLE_NAME || '' TO '' || GRANTEE as GRANT_CMD from dba_tab_privs where owner = ''DBA_OP'' and table_name = ''MAINT_PARTITIONS''');

EXCEPTION
	WHEN OTHERS
	 THEN
   IF SQLCODE = -955 THEN
     DBMS_OUTPUT.PUT_LINE('TEMP_MAINT_PARTITIONS_GRANT already exists. using previous saved configuration'|| SUBSTR(SQLERRM, 1, 64));
   ELSE
     DBMS_OUTPUT.PUT_LINE('Table DBA_OP.TEMP_MAINT_PARTITIONS_GRANT does not exist , but this is not a problem. It will be created later' );
   END IF ;

END;
/

BEGIN
 
   -- I drop the table
   execute immediate('DROP TABLE DBA_OP.MAINT_PARTITIONS CASCADE CONSTRAINTS');
 
EXCEPTION
	WHEN OTHERS
	 THEN
     DBMS_OUTPUT.PUT_LINE('Table DBA_OP.MAINT_PARTITIONS does not exist , but this is not a problem. It will be created later' );
END;
/




CREATE TABLE DBA_OP.MAINT_PARTITIONS
(
  TABLE_ID                        NUMBER        NOT NULL,
  TABLE_NAME                      VARCHAR2(60 BYTE),
  ENABLED                         CHAR(1 BYTE)  DEFAULT 'Y',
  PARTITION_RETENTION_UNIT        VARCHAR2(100 BYTE),
  PARTITION_RETENTION_UNIT_COUNT  NUMBER,
  PARALLEL_DEGREE                 NUMBER        DEFAULT 1,
  ACTION_EXPORT_DATA              CHAR(1 BYTE)  DEFAULT 'N',
  EXPDP_DIRECTORY                 VARCHAR2(100 BYTE),
  ACTION_COMPRESS_PART            CHAR(1 BYTE)  DEFAULT 'N',
  PARTITION_COMPRESS_TYPE         VARCHAR2(50 BYTE) ,
  ACTION_ADD_PART                 CHAR(1 BYTE)  DEFAULT 'N',
  PARTITION_ADD_COUNT             NUMBER        DEFAULT 1,
  PARTITION_NAME_PREFIX           VARCHAR2(50 BYTE) DEFAULT 'P',
  ACTION_DROP_PART                CHAR(1 BYTE)  DEFAULT 'N',
  ACTION_EXCHANGE_PART            CHAR(1 BYTE)  DEFAULT 'N',
  PARTITION_EXCHANGE_TABLE_NAME   VARCHAR2(50 BYTE),
  PARTITION_ARCHIVE_TABLE_NAME    VARCHAR2(50 BYTE),
  PARTITION_ARCHIVE_TABLESPACE    VARCHAR2(50 CHAR),
  ACTION_ARCHIVE_WITH_QUERY       CHAR(1 BYTE)  DEFAULT 'N',
  ACTION_APPEND_PART              CHAR(1 BYTE)  DEFAULT 'N',
  ARCHIVE_QUERY                   VARCHAR2(4000 BYTE),
  LAST_RUN_DATE                   DATE,
  LAST_RUN_RESULT                 VARCHAR2(10 BYTE),
  NEXT_RUN_DATE                   DATE,
  SCHEDULE                        VARCHAR2(300 BYTE),
  SEND_EMAIL_TOVARCHAR2(4000 BYTE) DEFAULT 'dbadmin_allarmi@nexi.it'
)
TABLESPACE DBA_OP_DATA
LOGGING 
NOCOMPRESS 
NOCACHE
MONITORING;


CREATE UNIQUE INDEX DBA_OP.MAINT_PART_CUS_PK ON DBA_OP.MAINT_PARTITIONS
(TABLE_ID)
LOGGING
TABLESPACE DBA_OP_DATA;



DECLARE

v_count    NUMBER ;
TAB_EXISTS NUMBER;
COL_EXISTS NUMBER ;

BEGIN

SELECT 
 COUNT(*) 
INTO TAB_EXISTS
FROM DBA_TABLES 
WHERE OWNER || '.' || TABLE_NAME = 'DBA_OP.TEMP_MAINT_PARTITIONS' ;


-- Checking if new column for this version exists on 
SELECT 
 COUNT(*)
INTO COL_EXISTS
FROM DBA_TAB_COLUMNS
WHERE COLUMN_NAME = 'ACTION_APPEND_PART'
  AND TABLE_NAME = 'TEMP_MAINT_PARTITIONS'
  AND OWNER = 'DBA_OP';


IF TAB_EXISTS > 0 
 THEN

  IF COL_EXISTS > 0 
   THEN
   -- for versione 2.32 or higher
	EXECUTE IMMEDIATE('INSERT INTO DBA_OP.MAINT_PARTITIONS SELECT * FROM DBA_OP.TEMP_MAINT_PARTITIONS ORDER BY TABLE_ID');
  ELSE
  -- for versione 2.31 or lower
    EXECUTE IMMEDIATE('INSERT INTO DBA_OP.MAINT_PARTITIONS (TABLE_ID,TABLE_NAME,ENABLED,PARTITION_RETENTION_UNIT,PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE,ACTION_EXPORT_DATA,EXPDP_DIRECTORY,ACTION_COMPRESS_PART,PARTITION_COMPRESS_TYPE,ACTION_ADD_PART,PARTITION_ADD_COUNT,PARTITION_NAME_PREFIX,ACTION_DROP_PART,ACTION_EXCHANGE_PART,PARTITION_EXCHANGE_TABLE_NAME,PARTITION_ARCHIVE_TABLE_NAME,PARTITION_ARCHIVE_TABLESPACE,ACTION_ARCHIVE_WITH_QUERY,ARCHIVE_QUERY,LAST_RUN_DATE,LAST_RUN_RESULT,NEXT_RUN_DATE,SCHEDULE,SEND_EMAIL_TO) SELECT TABLE_ID,TABLE_NAME,ENABLED,PARTITION_RETENTION_UNIT,PARTITION_RETENTION_UNIT_COUNT,PARALLEL_DEGREE,ACTION_EXPORT_DATA,EXPDP_DIRECTORY,ACTION_COMPRESS_PART,PARTITION_COMPRESS_TYPE,ACTION_ADD_PART,PARTITION_ADD_COUNT,PARTITION_NAME_PREFIX,ACTION_DROP_PART,ACTION_EXCHANGE_PART,PARTITION_EXCHANGE_TABLE_NAME,PARTITION_ARCHIVE_TABLE_NAME,PARTITION_ARCHIVE_TABLESPACE,ACTION_ARCHIVE_WITH_QUERY,ARCHIVE_QUERY,LAST_RUN_DATE,LAST_RUN_RESULT,NEXT_RUN_DATE,SCHEDULE,SEND_EMAIL_TO FROM DBA_OP.TEMP_MAINT_PARTITIONS ORDER BY TABLE_ID');
  END IF ;

END IF;
	
	SELECT 
	  COUNT(*)
	INTO v_count
	FROM DBA_OP.MAINT_PARTITIONS ;
	
	IF v_count = 0 THEN
	
--  I insert the aging record relating to the log table that holds 6 months of retention
		Insert into DBA_OP.MAINT_PARTITIONS
		   (TABLE_ID,TABLE_NAME, ENABLED, PARTITION_RETENTION_UNIT, PARTITION_RETENTION_UNIT_COUNT, 
			PARALLEL_DEGREE, ACTION_EXPORT_DATA, ACTION_COMPRESS_PART, PARTITION_COMPRESS_TYPE, ACTION_ADD_PART, 
			PARTITION_ADD_COUNT, PARTITION_NAME_PREFIX, ACTION_DROP_PART, ACTION_EXCHANGE_PART, ACTION_ARCHIVE_WITH_QUERY, 
			LAST_RUN_DATE, LAST_RUN_RESULT, NEXT_RUN_DATE, SCHEDULE, ACTION_APPEND_PART)
		Values
		   (1,'DBA_OP.MAINT_PARTITIONS_LOG', 'Y', 'YYYYMMWK', 24, 
			1, 'N', 'N', '', 'N', 
			1, 'P', 'Y', 'N', 'N', 
			NULL, 'OK', NULL, 'FREQ=WEEKLY;BYHOUR=1;BYMINUTE=0;BYSECOND=0','N');	
	
	END IF ;
	

EXCEPTION
 WHEN OTHERS
  THEN
   dbms_output.put_line(SQLERRM);
   dbms_output.put_line('ERROR: an error occurred during population of values from TEMP_MAINT_PARTITIONS. Do not continue as this may lead to data loss.');
    RAISE ;
END ;
/


BEGIN

  execute immediate('INSERT INTO DBA_OP.MAINT_PARTITIONS_EMAIL SELECT ENABLED, SMTP_HOST, SMTP_PORT, EMAIL_FROM, NULL AS CONTENT_INFO FROM DBA_OP.TEMP_MAINT_PARTITIONS_EMAIL');

   COMMIT ;

EXCEPTION
WHEN OTHERS
  THEN

    dbms_output.put_line('Table TEMP_MAINT_PARTITIONS_EMAIL seems does not exists. It seems the first installation. Continue');

END;
/


DECLARE

  v_count    NUMBER ;
  TAB_EXISTS NUMBER;
	
BEGIN
	 
		SELECT 
		  COUNT(*)
		INTO v_count
		FROM DBA_OP.MAINT_PARTITIONS_EMAIL ;
		
		IF v_count = 0 THEN
		
		--  I insert the aging record relating to the log table that holds 6 months of retention
			Insert into DBA_OP.MAINT_PARTITIONS_EMAIL
			   (ENABLED, SMTP_HOST, SMTP_PORT, EMAIL_FROM, CONTENT_INFO)
			 Values
			   ('N', '10.10.122.21', 25, 'dbanexi', 'SMTP Gateway Giotto');
			
			Insert into DBA_OP.MAINT_PARTITIONS_EMAIL
			   (ENABLED, SMTP_HOST, SMTP_PORT, EMAIL_FROM, CONTENT_INFO)
			 Values
			   ('N', '10.11.7.224', 25, 'dbanexi', 'SMTP GTATM');
			
			Insert into DBA_OP.MAINT_PARTITIONS_EMAIL
			   (ENABLED, SMTP_HOST, SMTP_PORT, EMAIL_FROM, CONTENT_INFO)
			 Values
			   ('N', '192.168.36.62', 25, 'dbanexi', 'SMTP Gateway FM2008');
			
			Insert into DBA_OP.MAINT_PARTITIONS_EMAIL
			   (ENABLED, SMTP_HOST, SMTP_PORT, EMAIL_FROM, CONTENT_INFO)
			 Values
			   ('N', '10.105.12.35', 25, 'dbanexi', 'SMTP Gateway GTPOS Pero');
			   
			Insert into DBA_OP.MAINT_PARTITIONS_EMAIL
			   (ENABLED, SMTP_HOST, SMTP_PORT, EMAIL_FROM, CONTENT_INFO)
			 Values
			   ('N', '10.205.12.35', 25, 'dbanexi', 'SMTP Gateway GTPOS Settimo');
		
		END IF ;
		
		COMMIT ;

EXCEPTION	
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Table DBA_OP.MAINT_PARTITIONS does not exist , but this is not a problem. It will be created later');
END;
/


-- Restore previous Grant on MAINT_PARTITIONS
begin

   FOR G_CUR IN ( select 
                    GRANT_CMD
                  from DBA_OP.TEMP_MAINT_PARTITIONS_GRANT ) 
   LOOP
   
        BEGIN
		
           execute immediate (G_CUR.GRANT_CMD) ;
		
		EXCEPTION	
		WHEN OTHERS
		 THEN
			 DBMS_OUTPUT.PUT_LINE('Error Executing : ' || G_CUR.GRANT_CMD );
		END;
		
   END LOOP ;

end ;
/

BEGIN
 
   execute immediate('TRUNCATE TABLE DBA_OP.TEMP_MAINT_PARTITIONS');
   execute immediate('DROP TABLE DBA_OP.TEMP_MAINT_PARTITIONS');
 
EXCEPTION
	WHEN OTHERS
	 THEN
		DBMS_OUTPUT.PUT_LINE('Table DBA_OP.TEMP_MAINT_PARTITIONS does not exist , but this is not a problem.' || SUBSTR(SQLERRM, 1, 64));
END;
/


BEGIN

   execute immediate('TRUNCATE TABLE DBA_OP.TEMP_MAINT_PARTITIONS_EMAIL');
   execute immediate('DROP TABLE DBA_OP.TEMP_MAINT_PARTITIONS_EMAIL');
 
EXCEPTION
	WHEN OTHERS
	 THEN
		 DBMS_OUTPUT.PUT_LINE('Table DBA_OP.TEMP_MAINT_PARTITIONS_EMAIL does not exist , but this is not a problem.' || SUBSTR(SQLERRM, 1, 64) );
END;
/



CREATE OR REPLACE TRIGGER DBA_OP.MAINT_PARTITIONS_TRG_TABLE_ID
BEFORE INSERT
ON DBA_OP.MAINT_PARTITIONS
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
BEGIN
   
       SELECT 
	     NVL(MAX(TABLE_ID),0) + 1
       INTO :NEW.TABLE_ID
       FROM DBA_OP.MAINT_PARTITIONS ;
   
END;
/


CREATE OR REPLACE TRIGGER DBA_OP.TRG_CHECK_INPUT_VALIDITY
BEFORE INSERT OR UPDATE
ON DBA_OP.MAINT_PARTITIONS
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
--
DECLARE
      v_table_exist       NUMBER ;
      v_count             NUMBER ;
      v_count_sep         NUMBER ;
      v_package_exist     NUMBER ;
      l_return_date_after TIMESTAMP WITH TIME ZONE ;
      l_next_run_date     TIMESTAMP WITH TIME ZONE ;
--
BEGIN
   ----------------------------------------------------------------------
   -- Consistency Check for Partition Retention Unit that must be an entity
   --  between DAY / MONTH / WEEK / YEAR
   ----------------------------------------------------------------------

   IF (:NEW.PARTITION_RETENTION_UNIT <> 'YYYYMMDD'   AND
      :NEW.PARTITION_RETENTION_UNIT <> 'YYYYMM'  AND
      :NEW.PARTITION_RETENTION_UNIT <> 'YYYY' AND
      :NEW.PARTITION_RETENTION_UNIT <> 'YYYYMMWK' )
   THEN

        -- May happen that this is a external function. Let's check if this funciotn exist
        select
           COUNT(*)
        into v_package_exist
        from dba_source
        where owner || '.' || name = :NEW.PARTITION_RETENTION_UNIT
        and type = 'PACKAGE'
        and ( upper(text) like '%GETPARTITIONNAMEFROMHV%'
          or  upper(text) like '%GETNEXTHV%'
          or  upper(text) like '%GETCURRENTPARTITIONHV%'
        );

        IF  v_package_exist != 3 THEN
          raise_application_error(-20000,'Partition Retention Unit must be an entity between YYYYMMDD / YYYYMM / YYYYMMWK / YYYY or a package with 3 function defined : GETPARTITIONNAMEFROMHV / GETNEXTHV / GETCURRENTPARTITIONHV');
        END IF ;

   END IF;

   IF (:NEW.ENABLED <> 'Y'   AND
      :NEW.ENABLED <> 'N' )
   THEN
       raise_application_error(-20000,'Enabled column accept values Y or N');
   END IF;

   IF (:NEW.ACTION_EXPORT_DATA <> 'Y'   AND
      :NEW.ACTION_EXPORT_DATA <> 'N' )
   THEN
       raise_application_error(-20000,'ACTION_EXPORT_DATA column accept values Y or N');
   END IF;

   IF (:NEW.ACTION_COMPRESS_PART <> 'Y'   AND
      :NEW.ACTION_COMPRESS_PART <> 'N' )
   THEN
       raise_application_error(-20000,'ACTION_COMPRESS_PART column accept values Y or N');
   END IF;

   IF (:NEW.ACTION_ADD_PART <> 'Y'   AND
      :NEW.ACTION_ADD_PART <> 'N' )
   THEN
       raise_application_error(-20000,'ACTION_ADD_PART column accept values Y or N');
   END IF;

   IF (:NEW.ACTION_DROP_PART <> 'Y'   AND
      :NEW.ACTION_DROP_PART <> 'N' )
   THEN
       raise_application_error(-20000,'ACTION_DROP_PART column accept values Y or N');
   END IF;
   
   IF (:NEW.ACTION_APPEND_PART <> 'Y'   AND
      :NEW.ACTION_APPEND_PART <> 'N' )
   THEN
       raise_application_error(-20000,'ACTION_APPEND_PART column accept values Y or N');
   END IF;

   IF (:NEW.ACTION_ARCHIVE_WITH_QUERY <> 'Y'   AND
      :NEW.ACTION_ARCHIVE_WITH_QUERY <> 'N' )
   THEN
       raise_application_error(-20000,'ACTION_ARCHIVE_WITH_QUERY column accept values Y or N');
   END IF;

   IF (:NEW.ACTION_EXPORT_DATA = 'Y' AND :NEW.EXPDP_DIRECTORY IS NULL )
   THEN
       raise_application_error(-20000,'If ACTION_EXPORT_DATA is Y , EXPDP_DIRECTORY column cannot be null');
   END IF ;

   IF (:NEW.ACTION_DROP_PART = 'Y' AND (:NEW.PARTITION_RETENTION_UNIT IS NULL OR :NEW.PARTITION_RETENTION_UNIT_COUNT IS NULL))
   THEN
       raise_application_error(-20000,'If ACTION_DROP_DATA is Y , PARTITION_RETENTION_UNIT and PARTITION_RETENTION_UNIT_COUNT cannot be null');
   END IF ;

   IF (:NEW.ACTION_EXCHANGE_PART = 'Y' AND (:NEW.PARTITION_ARCHIVE_TABLE_NAME IS NULL OR :NEW.PARTITION_EXCHANGE_TABLE_NAME IS NULL OR :NEW.PARTITION_RETENTION_UNIT IS NULL OR :NEW.PARTITION_RETENTION_UNIT_COUNT IS NULL))
   THEN
       raise_application_error(-20000,'If ACTION_EXCHANGE_PART is Y , PARTITION_EXCHANGE_TABLE_NAME and PARTITION_RETENTION_UNIT / PARTITION_RETENTION_UNIT_COUNT cannot be null');
   END IF ;

   IF (:NEW.ACTION_ARCHIVE_WITH_QUERY = 'Y' AND (:NEW.ACTION_EXCHANGE_PART = 'Y' OR :NEW.ACTION_DROP_PART = 'Y' OR :NEW.ACTION_ADD_PART = 'Y'))
   THEN
       raise_application_error(-20000,'If ACTION_ARCHIVE_WITH_QUERY is Y , ACTION_EXCHANGE_PART and ACTION_DROP_PART / ACTION_ADD_PART cannot be Y');
   END IF ;

   IF (:NEW.ARCHIVE_QUERY IS NOT NULL AND INSTR(UPPER(:NEW.ARCHIVE_QUERY),'WHERE' ) < 6 AND INSTR(UPPER(:NEW.ARCHIVE_QUERY),'WHERE' ) > 0 )
   THEN
       raise_application_error(-20000,'ARCHIVE QUERY COLUMN should not contain the WHERE word');
   END IF ;

   IF (:NEW.ACTION_APPEND_PART = 'Y' AND (:NEW.PARTITION_ARCHIVE_TABLE_NAME IS NULL OR :NEW.PARTITION_RETENTION_UNIT IS NULL OR :NEW.PARTITION_RETENTION_UNIT_COUNT IS NULL))
   THEN
       raise_application_error(-20000,'If ACTION_APPEND_PART is Y , PARTITION_ARCHIVE_TABLE_NAME and PARTITION_RETENTION_UNIT / PARTITION_RETENTION_UNIT_COUNT cannot be null');
   END IF ;
   
    -- Checking operation can be performed with EXCHANGE partition
   IF (:NEW.ACTION_EXCHANGE_PART = 'Y' AND :NEW.ACTION_DROP_PART = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Exchange and drop partitions at the same time');
   END IF ;

   IF (:NEW.ACTION_EXCHANGE_PART = 'Y' AND :NEW.ACTION_ARCHIVE_WITH_QUERY = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Exchange and Archive a table with query at the same time');
   END IF ;

   IF (:NEW.ACTION_EXCHANGE_PART = 'Y' AND :NEW.ACTION_COMPRESS_PART = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Exchange and Archive a table with query at the same time');
   END IF ;

   IF (:NEW.ACTION_EXCHANGE_PART = 'Y' AND :NEW.ACTION_EXPORT_DATA = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Exchange and Archive a table with query at the same time');
   END IF ;
   
   IF (:NEW.ACTION_EXCHANGE_PART = 'Y' AND :NEW.ACTION_APPEND_PART = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Exchange and Archive with Append at the same time');
   END IF ;

   -- Checking operation can be performed with DROP partition
   IF (:NEW.ACTION_DROP_PART = 'Y' AND :NEW.ACTION_COMPRESS_PART = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Drop and Compress partition at the same time');
   END IF ;

   IF (:NEW.ACTION_DROP_PART = 'Y' AND :NEW.ACTION_ARCHIVE_WITH_QUERY = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Drop and Archive data with a custom query at the same time');
   END IF ;

   IF (:NEW.ACTION_DROP_PART = 'Y' AND :NEW.ACTION_EXCHANGE_PART = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Drop and Exchange data at the same time');
   END IF ;

   IF (:NEW.ACTION_DROP_PART = 'Y' AND :NEW.ACTION_APPEND_PART = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Drop and Archive with Append at the same time');
   END IF ;
   
   -- Checking operation can be performed with ARCHIVE With Query
   IF (:NEW.ACTION_ARCHIVE_WITH_QUERY = 'Y' AND :NEW.ARCHIVE_QUERY IS NULL )
   THEN
       raise_application_error(-20000,'If ACTION_ARCHIVE_WITH_QUERY = Y , you should specify a value for ARCHIVE_QUERY. You can specify also PARTITION_ARCHIVE_TABLE_NAME if you want to backup to this table deleted rows.');
   END IF ;

   -- Checking operation can be performed with ADD Partition
   IF (:NEW.ACTION_ADD_PART = 'Y' AND :NEW.ACTION_EXPORT_DATA = 'Y' )
   THEN
       raise_application_error(-20000,'Cannot Add partitions and Export data at the same time');
   END IF ;

   -- Checking operation can be performed with EXPORT Partition
   IF (:NEW.ACTION_EXPORT_DATA = 'Y' AND ( :NEW.ACTION_EXCHANGE_PART = 'Y' OR :NEW.ACTION_COMPRESS_PART = 'Y' OR :NEW.ACTION_APPEND_PART = 'Y' ))
   THEN
       raise_application_error(-20000,'Cannot Export data and Exchange or Compress at the same time');
   END IF ;

   -- Export Data cannot be activated stand alone
   IF (:NEW.ACTION_EXPORT_DATA = 'Y' AND ( :NEW.ACTION_COMPRESS_PART = 'N' AND :NEW.ACTION_ARCHIVE_WITH_QUERY = 'N' AND :NEW.ACTION_DROP_PART = 'N' AND :NEW.ACTION_ADD_PART = 'N' AND :NEW.ACTION_EXCHANGE_PART = 'N' AND :NEW.ACTION_APPEND_PART = 'N'))
   THEN
       raise_application_error(-20000,'Export Data cannot be activated stand alone');
   END IF ;

   -- Checking operation can be performed with COMPRESS Partition
   IF (:NEW.ACTION_COMPRESS_PART = 'Y' AND ( :NEW.ACTION_ARCHIVE_WITH_QUERY = 'Y' OR :NEW.ACTION_DROP_PART = 'Y' OR :NEW.ACTION_EXPORT_DATA = 'Y' OR :NEW.ACTION_EXCHANGE_PART = 'Y' OR :NEW.ACTION_APPEND_PART = 'Y'))
   THEN
       raise_application_error(-20000,'Compression can be performed only with add partition or standalone');
   END IF ;

   -- Checking operation can be performed with ARCHIVE QUERY
   IF (:NEW.ACTION_ARCHIVE_WITH_QUERY = 'Y' AND ( :NEW.ACTION_DROP_PART = 'Y' OR :NEW.ACTION_COMPRESS_PART = 'Y' OR :NEW.ACTION_EXCHANGE_PART = 'Y' OR :NEW.ACTION_APPEND_PART = 'Y'))
   THEN
       raise_application_error(-20000,'Archive Query can be enabled only with add partition or with Export option');
   END IF ;


   -- Check if TABLE_NAME are in the correct format
   IF (:NEW.TABLE_NAME IS NULL )
   THEN
       raise_application_error(-20000,'TABLE_NAME cannot be null');
   END IF ;

   IF (INSTR(:NEW.TABLE_NAME,'.') = 0 )
   THEN
       raise_application_error(-20000,'TABLE_NAME format is not OWNER.TABLENAME');
   END IF ;

   IF (:NEW.PARTITION_ARCHIVE_TABLE_NAME IS NOT NULL AND INSTR(:NEW.PARTITION_ARCHIVE_TABLE_NAME,'.') = 0 )
   THEN
       raise_application_error(-20000,'PARTITION_ARCHIVE_TABLE_NAME format is not OWNER.TABLENAME');
   END IF ;


   IF ( :NEW.PARTITION_COMPRESS_TYPE != 'ARCHIVE LOW'
    AND :NEW.PARTITION_COMPRESS_TYPE != 'ARCHIVE HIGH'
    AND :NEW.PARTITION_COMPRESS_TYPE != 'QUERY LOW'
    AND :NEW.PARTITION_COMPRESS_TYPE != 'QUERY HIGH'
    AND :NEW.PARTITION_COMPRESS_TYPE != 'OLTP'
    AND :NEW.PARTITION_COMPRESS_TYPE != 'BASIC'
    AND :NEW.PARTITION_COMPRESS_TYPE != 'ADVANCED'
    AND :NEW.PARTITION_COMPRESS_TYPE IS NOT NULL )
    THEN

      raise_application_error(-20000,'PARTITION_COMPRESS_TYPE ' || :NEW.PARTITION_COMPRESS_TYPE || ' cannot be used for licensing purpose');

    END IF ;

   -- Checking if table exist

   SELECT
      COUNT(*)
   INTO V_TABLE_EXIST
   FROM DBA_TABLES
   WHERE OWNER || '.' || TABLE_NAME = :NEW.TABLE_NAME ;

   IF V_TABLE_EXIST = 0 THEN
       raise_application_error(-20000,'TABLE_NAME does not exist');
   END IF ;

   -- Checking if table exist
   IF (:NEW.PARTITION_ARCHIVE_TABLE_NAME IS NOT NULL)
   THEN
           SELECT
              COUNT(*)
           INTO V_TABLE_EXIST
           FROM DBA_TABLES
           WHERE OWNER || '.' || TABLE_NAME = :NEW.PARTITION_ARCHIVE_TABLE_NAME  ;

           IF V_TABLE_EXIST = 0 THEN
               raise_application_error(-20000,'PARTITION_ARCHIVE_TABLE_NAME does not exist');
           END IF ;

    END IF ;

    IF SUBSTR(:NEW.SCHEDULE,LENGTH(:NEW.SCHEDULE)) = ';'
    THEN
       raise_application_error(-20000,'SCHEDULE field cannot end with a semicolon ;');
    END IF ;

    -- Checking if schedule is valid or not
    BEGIN

       DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING(
          calendar_string   => :NEW.SCHEDULE,
          start_date        => nvl(:NEW.NEXT_RUN_DATE,SYSDATE),
          return_date_after => l_return_date_after,
          next_run_date     => l_next_run_date);

    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20000,'SCHEDULE field is not a valid schedule string');
    END ;

    -- Checking if directory exist

   -- Checking if table exist
   IF (:NEW.EXPDP_DIRECTORY IS NOT NULL)
   THEN
           SELECT
              COUNT(*)
           INTO V_TABLE_EXIST
           FROM DBA_DIRECTORIES
           WHERE DIRECTORY_NAME = :NEW.EXPDP_DIRECTORY  ;

           IF V_TABLE_EXIST = 0 THEN
               raise_application_error(-20000,'EXPDP_DIRECTORY does not exist');
           END IF ;

    END IF ;

    select
      REGEXP_COUNT( :NEW.SEND_EMAIL_TO, '@' )
into v_count
    from dual ;

        IF v_count > 1 THEN
          -- In this case there are more than one address specified. Check that separator is a semicol ";"
        select
           REGEXP_COUNT( :NEW.SEND_EMAIL_TO, ';' )
        into v_count_sep
        from dual ;

        IF v_count_sep < v_count - 1
         THEN
            raise_application_error(-20000,'Use ; as separator for different email addresses');
        END IF ;

    END IF ;

END;
/



ALTER TABLE DBA_OP.MAINT_PARTITIONS ADD (
  CONSTRAINT MAINT_PART_CUS_PK
  PRIMARY KEY
  (TABLE_ID)
  USING INDEX DBA_OP.MAINT_PART_CUS_PK
  ENABLE NOVALIDATE);


---- Creation of LOG Table  


BEGIN

  execute immediate('DROP TABLE DBA_OP.MAINT_PARTITIONS_LOG CASCADE CONSTRAINTS') ;
  
EXCEPTION 
WHEN OTHERS
 THEN
     DBMS_OUTPUT.PUT_LINE('Table DBA_OP.MAINT_PARTITIONS_EMAIL does not exist , but this is not a problem. It will be created later');
END;
/


CREATE TABLE DBA_OP.MAINT_PARTITIONS_LOG
(
  RUNID           NUMBER                        NOT NULL,
  DATETIME        TIMESTAMP(6)                  DEFAULT SYSTIMESTAMP,
  SEVERITY        VARCHAR2(10 BYTE),
  TABLE_NAME      VARCHAR2(100 BYTE),
  PROCEDURE_NAME  VARCHAR2(100 BYTE),
  MESSAGE         VARCHAR2(4000 BYTE)
)
NOCOMPRESS 
TABLESPACE DBA_OP_DATA
PCTUSED    0
PCTFREE    10
INITRANS   1
MAXTRANS   255
STORAGE    (
            BUFFER_POOL      DEFAULT
           )
PARTITION BY RANGE (DATETIME)
INTERVAL( NUMTODSINTERVAL(7,'DAY'))
(  
  PARTITION P20190909 VALUES LESS THAN (TIMESTAMP' 2019-09-10 00:00:00')
    LOGGING
    NOCOMPRESS 
    TABLESPACE DBA_OP_DATA
)
NOCACHE
MONITORING;


CREATE INDEX DBA_OP.IDX_MAINT_PARTITIONS_SEV_DATE ON DBA_OP.MAINT_PARTITIONS_LOG
(SEVERITY, DATETIME)
 TABLESPACE DBA_OP_DATA
 LOGGING
LOCAL ;


ALTER TABLE DBA_OP.MAINT_PARTITIONS_LOG ADD (
  CHECK ("DATETIME" IS NOT NULL)
  ENABLE NOVALIDATE,
  CHECK ("SEVERITY" IS NOT NULL)
  ENABLE NOVALIDATE);



COMMIT;


CREATE OR REPLACE PACKAGE DBA_OP.PARTITIONS_MANAGER IS

VERSIONE CONSTANT VARCHAR2(100) := 'v2.35';

    /* Global Variable to enable/disable Dry Run execution */
    gDryRun                    CHAR(1) := 'Y'  ;
    gRunId                     NUMBER ;
    gPartColumnDatatype        VARCHAR2(100) ;
    gRunDate                   DATE ;

    t_partition_work          pm_partition_list_type := pm_partition_list_type();
    t_partition_arc_work      pm_partition_list_type := pm_partition_list_type();

    /* Actions */
    B_COMPRESSION_ENABLED INTEGER := 0;
    B_DATAEXPORT_ENABLED  INTEGER := 0;
    B_ADD_PARTITION       INTEGER := 0;
    B_DROP_PARTITION      INTEGER := 0;
    B_EXCHANGE_PARTITION  INTEGER := 0;
    B_ARCHIVE_WITH_QUERY  INTEGER := 0;
    B_APPEND_PARTITION    INTEGER := 0;


    /* Log severities */
    gLogLevel             INTEGER          := 2  ;
    LOG_SEV_DEBUG         CONSTANT INTEGER := -1 ;
    LOG_SEV_INFO          CONSTANT INTEGER := 0  ;
    LOG_SEV_WARNING       CONSTANT INTEGER := 1  ;
    LOG_SEV_ERROR         CONSTANT INTEGER := 2  ;


    LAST_RANGE_PART          EXCEPTION ;
    PRAGMA EXCEPTION_INIT(LAST_RANGE_PART, -14758);


    /* Public methods */
    FUNCTION  CheckTableProperties( pTableName   DBA_TAB_PARTITIONS.table_name%TYPE) RETURN BOOLEAN;
    FUNCTION  CountPartitions( pTableName   DBA_TAB_PARTITIONS.table_name%TYPE) RETURN INTEGER;
    FUNCTION  IsNumber (p_string IN VARCHAR2) RETURN BOOLEAN ;
    FUNCTION  IsPartitionCompressed (pTableName IN VARCHAR2 ,pPartName IN VARCHAR2) RETURN BOOLEAN ;
    FUNCTION  IsTableSubPartitioned (pTableName IN VARCHAR2) RETURN BOOLEAN ;
    FUNCTION  IsIntervalPartitionedTable( pTableName DBA_TABLES.table_name%TYPE ) RETURN BOOLEAN ;
    PROCEDURE ArchiveRowWithQuery ( pEntry MAINT_PARTITIONS%ROWTYPE );
    PROCEDURE RenamePartitions ( pEntry MAINT_PARTITIONS%ROWTYPE, pTablePartList IN OUT pm_partition_list_type, pTableName VARCHAR2 );
    PROCEDURE RenameIntervalPartition ( pEntry MAINT_PARTITIONS%ROWTYPE, pTableName VARCHAR2 ) ;
    PROCEDURE StartMaintenance( pTableName VARCHAR2 , pDryrun VARCHAR DEFAULT 'Y', pLogLevel VARCHAR2 DEFAULT 2 ) ;
    PROCEDURE LogFacility( pSeverity INTEGER, pMessage  VARCHAR2, pTable VARCHAR2) ;
    PROCEDURE CheckParams( pDryRun CHAR, pLogLevel VARCHAR2) ;
    PROCEDURE ExecSqlCommand ( pSqlCmd VARCHAR2 , pTableName VARCHAR2 );
    PROCEDURE ExecSqlCommandInto ( pSqlCmd VARCHAR2 , pTableName VARCHAR2 , pInto OUT VARCHAR2 ) ;
    PROCEDURE AddPartitionList( pEntry MAINT_PARTITIONS%ROWTYPE );
    PROCEDURE ExchangePartitionList( pEntry MAINT_PARTITIONS%ROWTYPE ) ;
    PROCEDURE AppendPartitionList( pEntry MAINT_PARTITIONS%ROWTYPE ) ;
    PROCEDURE DropEmptyPartition( pTable DBA_TAB_PARTITIONS.table_name%TYPE,pName DBA_TAB_PARTITIONS.partition_name%TYPE) ;
    PROCEDURE GetEnabledActions( pEntry DBA_OP.MAINT_PARTITIONS%ROWTYPE) ;
    PROCEDURE TruncateTable(pTable DBA_TAB_PARTITIONS.table_name%TYPE);
    PROCEDURE ExchangePartition( pTable DBA_TAB_PARTITIONS.table_name%TYPE, pExchgTable DBA_TAB_PARTITIONS.table_name%TYPE, pPartName DBA_TAB_PARTITIONS.partition_name%TYPE);
    PROCEDURE CreatePartition( pTableName DBA_TAB_PARTITIONS.table_name%TYPE, pTablePartList pm_partition_list_type, pPartName DBA_TAB_PARTITIONS.partition_name%TYPE, pTblSpace DBA_TAB_PARTITIONS.Tablespace_Name%TYPE, pDate VARCHAR2, pRetentionUnit VARCHAR2, pNamePrefix VARCHAR2,pDegree NUMBER);
    PROCEDURE CompressSubPartition( pTable DBA_TAB_PARTITIONS.table_name%TYPE,pName  DBA_TAB_PARTITIONS.partition_name%TYPE,pDegree NUMBER,pCompressType VARCHAR2 , pTablespaceName DBA_TAB_PARTITIONS.tablespace_name%TYPE);
    PROCEDURE CompressPartition( pTable DBA_TAB_PARTITIONS.table_name%TYPE,pName  DBA_TAB_PARTITIONS.partition_name%TYPE,pDegree NUMBER,pCompressType VARCHAR2 , pTablespaceName DBA_TAB_PARTITIONS.tablespace_name%TYPE);
    FUNCTION  IsPartitionEmpty ( pTavola VARCHAR2, pPartiz VARCHAR2) RETURN  NUMBER;
    FUNCTION  IsTableEmpty ( pTavola VARCHAR2) RETURN  NUMBER;
    FUNCTION  GetPartitionListToAdd( pEntry MAINT_PARTITIONS%ROWTYPE) return pm_partition_list_type ;
    FUNCTION  GetPartitionListToRemove(pEntry MAINT_PARTITIONS%ROWTYPE) return pm_partition_list_type ;
    FUNCTION  GetPartitionListToCompress(pEntry MAINT_PARTITIONS%ROWTYPE)return pm_partition_list_type ;
    FUNCTION  GetNextPartitionWithRetention( pDate VARCHAR2, pRetentionUnit VARCHAR2, pRetentionValue NUMBER DEFAULT 1) return NUMBER ;
    FUNCTION  GetNextPartition(pTablePartitionList pm_partition_list_type, pPartDate VARCHAR2 , pRetentionUnit VARCHAR2, vNextPartName IN OUT DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE) RETURN NUMBER;
    FUNCTION  GetMinMaxPartitionDate (pTable MAINT_PARTITIONS.table_name%TYPE, pMinMax VARCHAR2 DEFAULT 'MIN' , vPartName IN OUT DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE, vPartTablespaceName IN OUT DBA_TAB_PARTITIONS.TABLESPACE_NAME%TYPE ) RETURN NUMBER;
    FUNCTION  CalculatePartitionName( pDate VARCHAR2, pUM VARCHAR2, pPrefix VARCHAR2) RETURN VARCHAR2 ;
    FUNCTION  PartitionExists( pTable DBA_TAB_PARTITIONS.table_name%TYPE, pName  DBA_TAB_PARTITIONS.partition_name%TYPE) RETURN BOOLEAN;
    FUNCTION  CalculateNextRunDate ( calendar_string VARCHAR2, start_date  TIMESTAMP WITH TIME ZONE ) RETURN TIMESTAMP;
    FUNCTION  DefaultPartition (pTable DBA_TAB_PARTITIONS.table_name%TYPE) RETURN DBA_TAB_PARTITIONS.partition_name%TYPE ;
    FUNCTION  CanBeOnline ( pOperation VARCHAR2 ) RETURN VARCHAR2 ;
    FUNCTION  IsIndexPartitionUnusable (pTableName VARCHAR2, pPartName VARCHAR2) RETURN  BOOLEAN ;
    FUNCTION  IsIndexSubPartitionUnusable (pTableName VARCHAR2, pPartName VARCHAR2) RETURN  BOOLEAN ;
    PROCEDURE CompressPartitionList( pEntry MAINT_PARTITIONS%ROWTYPE) ;
    PROCEDURE DropPartitionList( pEntry MAINT_PARTITIONS%ROWTYPE );
    PROCEDURE ExportPartition(pTable DBA_TAB_PARTITIONS.table_name%TYPE, pName DBA_TAB_PARTITIONS.partition_name%TYPE, pDirobj VARCHAR2 DEFAULT NULL);
    PROCEDURE ExportPartitionData ( pTable  IN VARCHAR2, pPeriod IN VARCHAR2, pQuery  IN VARCHAR2 DEFAULT  NULL, pDirobj IN VARCHAR2 DEFAULT  NULL );
    PROCEDURE CreateExchangeTable ( pEntry DBA_OP.MAINT_PARTITIONS%ROWTYPE);
    PROCEDURE MovePartitionTablespace( pTable DBA_TAB_PARTITIONS.table_name%TYPE,pPartName DBA_TAB_PARTITIONS.partition_name%TYPE, pDegree NUMBER, pTablespaceName DBA_TAB_PARTITIONS.tablespace_name%TYPE);
    PROCEDURE AlignExchangeTableIndex( vExchangeTablename VARCHAR2 , vOtherTableName VARCHAR2 ,pEntry DBA_OP.MAINT_PARTITIONS%ROWTYPE );
    PROCEDURE SendMail (pRunId INTEGER );
    PROCEDURE SendTestMail( vMailTo VARCHAR2 );

END Partitions_Manager;
/


CREATE OR REPLACE PACKAGE BODY DBA_OP.Partitions_Manager
IS
   /*
      Contributors: Fabio Olivo

      20190903      versione 1.0       Start Version

      20190908 version 1.1 Added management of undate partitions

      20190909 version 1.2 Added partition management via External Package

      20190910 version 1.3 Added check on the existence of only one partition.
                                       Bug Fix su Interval Partitioned Tables
                                       If the execution is DryRun, the last_run_date and next_run_date are not modified

      20190912 version 1.4 Fix on ArchivedRow. Added save exceptions management in case of errors in insert/delete
                                       Added ability to delete rows without storing them in another table
                                       Fixed constant login values
                                       Fixed Exception handler of the create exchange partition table
                                       Fixed Error Messages all in English
                                       Removed limitation on the destination table for the archive with query

      20190916 version 1.5 Added management of email reports from dbserver
                                       Fixed primary key creation on ExchangeTable
                                       Creata procedure AlignExchangeTableIndex
                                       Added ability to manage different primary key indexing between source and target tables of exchange partitions
                                       Modified MovePartition tablespace procedure to perform the Move on the exchange table instead of the final table

      20190924 version 1.6 Fixed Calculation of Partitions to remove/compress when retention_unit is a function
                                       Added email forwarding
                                       Fixed logging in Create Partition
                                       Eliminated PARALLEL 4 by default in the exchange partition
                                       Fixed behavior with Weekly partitions
                                       Fixed MovePartitionTablespace to avoid rebuilding indexes linked to lobs

      20191010 version 1.7 Adequate package with external Types
                                       Changed possibility to start PM even if tables is disabled (only with table mode passed as argument)
                                       Performed changes to install PM on Oracle 11R2
                                       Fixed Calculate PartitionName with MONDAY derivation depending on the language
                                       Fixed Rename Indexes
                                       Fixed split partition added update global indexes
                                       Fixed trash partition management
                                       Fixed Index partition name in RenamePartitions
                                       Fixed partition name string lenght in CalculatePartitionName
                                       Added inpunt TableName to GetCurrentPartitionHV function as per ICTEAM request

      20191013 version 1.8 Fixed bug in GetPartitionListToAdd when the only partition present is the trash one
                                       Added Email management
                                       Added SendTestEmail procedure to test sending notifications with one or more configured email servers
                                       Added Status: RUNNING when the table is being maintained by the package

      20191031 version 1.9 Fixed RenamePartition in the case of partition key with char
            Fixed RUNNING calculation
            Fixed query for extracting indices whose partition names are to be renamed in the case of partition key such as varchar2
            Fix RenamePartitions which in the case of partition key as varchar must take the portion of the date relating to the RetentionUnit format
                                       Fix use of MAXVALUE in the case of partition column varchar2
                                       Fixed CreatePartition if there is a default parttion with function as partition_retention_unit
            Fixed AlignExchangeTable to drop the Pk constraint if it is too many in the exchange table

      20191114 version 2.0 Changed management of the online clause on database versions >= 12.1 in the CompressPartition
                                       Modified the split function by replacing "update GLOBAL indexes" with "update indexes"
                                       Modified ONLINE rebuild of indexes in case the table is not partitioned

      20191128 version 2.1 Error 14758 also handled in the drop relating to the exchange partition
                                       Modified CreateExchangeTable procedure to create indexes on the correct owner
                                       Modified Create ExchangeTable / AlignExchnageTable to create indexes on the correct owner when the table and its exchange are on different schemas
                                       Changed AlignExchangeTable and CreateExchnageTable to limit the maximum size of automatically created index names

      20191202 version 2.2 Changed CreateExchangeTable to create indexes with fields in the correct order
                                       Modified AlignExchangeTable to create indexes with fields in the correct order
                                       Modified StartMaintenance and ProcessTable to set the fixed gRunDate instead of the SYSDATE

      20191213 version 2.3 SendMail commented out
                                       Changed loggin with tablename instead of PartitionName
                                       Added check that indexes are unusable before rebuilding anyway
                                       Added management of subpartitioned tables in compression CompressSubPartition + IsIndexSubpartitionUnusable
                                       Removed Return from ProcessTable because it prevented the mailing from being sent in the event of an error

      20191217 version 2.4 RenameIntervalpartitions function created to avoid reloading each exchange partition that created performance problems
                                       Management of last range partition on exchange to avoid spalling done at every run
                                       Modified SendMail so as not to send emails from tables that have not been modified in the last run even if their status is in error
                                       Changed DropPartitionList so that it truncates the last range partition of a table instead of dropping it (because it's not possible to drop it!!)
                                       Changed ExchangePartitionList so that if the partition of an interval partitioned table is a range and is empty, I don't proceed with the exchange
                                       because I would require throwing away the data present in the history table due to a previous exchange round
                                       Increased logging in ExchangePartitionList

      20191219 version 2.5 Changed GetPartitionListToAdd and GetNetxtPartitionWithRetention for yearly and monthly partitions when using date or timestamp column types

      20200110      versione 2.6       Fix Millennium Bug
                                       Changed GetPartitionListToAdd to correctly create number of partitions with PART_ADD_COUNT = 1
                                       Changed DropPartitionList procedure so that it only exports non-empty partitions
                                       Changed ExportPartitionData logging
                                       Modified RenamePartition to correctly handle HighValue = DEFAULT in the case of retention unit as a function
                                       Modified GetPartitionListToCompress to insert only existing partitions (in the case of function retention they may not exist)
                                       Modified GetPartitionListToRemove to insert only existing partitions (in the case of function retention they may not exist)
                                       Created IsPartitionCompressed to understand if the partition is compressed by also analyzing the subpartitions
                                       Modified GetPartitionListToRemove to manage the compression check also at subpartition level
                                       Fixed size of varchar2 returned by CanBeOnline function
                                       CreatePartition modified to correctly manage the split in the case of retention function and in the case of a trash partition with standard data type retention
                                       Changed CalculateNextPartitionName to rename the DefaultPartition with the date format 99990101
                                       Changed cCurIdxToDrop cursor in AlignExchangeTable to eliminate redundant union
                                       Modified AlignExchnageTableIndex to create indexes on the exchnage table that we have a name with 4 random digits
                                       Modified CalculateNextRunDate for correct calculation of the NextDate in the case of execution on the same day as the scheduling

       20200204 version 2.7 Modified CompressSubPartition to check unusable indexes correctly
                                       Modified CompressSubPartition to rebuild index subpartitions correctly

       20200221 version 2.8 CreatePartition modified to correctly manage the add partition in the case of retention_unit as a function
                                       Modified GetPartitionListToAdd function to fix the creation of one more partition than necessary in both the TIMESTAMP/Date case
                                       than in the case of external function
                                       Modified LogFacility to introduce trunc of the MESSAGE field to 4000 and avoid errors during insertion
                                       Enhancement on logging of all package procedures. Transformed some DEBUGS into INFO and improved the information reported in the log

       20200317 version 2.9 CreatePartition modified to correctly manage the add partition in the case of annual retention_unit

    20200609 version 2.10 Modified CompressPartitionList so as not to raise in case of exception during compress (see horussg)

    20200917 version 2.11 Removed ONLINE in the compress for licensing reasons

    20200918 version 2.12 Modified compress clause in CompressPartition

    20200921 version 2.13 Modified compress clause in CompressSubPartition

    20201001 version 2.14 Changed ExchangePartitionList to manage FK disabling in case of exchange partition

    20201001 version 2.15 Create IstableEmpty to manage checks on non-partitioned tables

    20201105 version 2.16 Modified trigger to prevent use of non-HCC or BASIC compressions

    20210305 version 2.17 ExportPartition procedures modified to adapt to version 19c

    20210714 version 2.18 Modified CompressPartition and CompressSubpartition procedures to introduce the FOR in the compress clause in the case of HCC

    20211001 version 2.20 Modified CreatePartition to fix the partition created by the split

    20211103 version 2.21 Changed GetPartitionListToRemove for bug that appeared on ECGP when partitions do not exist. Moved the vPartCount + 1 into the IF PART exists

    20220211 version 2.22 Introduced before create table as select , alter session required for exchange partition ORA-01497.
            ExportPartitionData bug fix for versions lower than 12.1

    20220309 version 2.23 Modified RenamePartition to avoid renaming the index partition of the last partition (which is presumably the "active" one
            Fixed CreatePartition problem which, in the case of a Recycle Bin partition, creates the default partition with the same name as the new partition
            Modified SendMail to lower priority to WARn in case the mail server is not reachable

    20220314 version 2.24 Modified CanBeOnline to reactivate the possibility of doing work online by activating Advanced Compression
                                       Modified CompressPartition to rebuild invalid index partitions following partition compression
                                       Modified CompressPartition to allow OLTP compression (default remains BASIC)
                                       Modified check trigger to allow oltp compress

       20220329 version 2.25 Changed ExchangePartitionList due to error in managing the create partition on week partitioned tables
                                       Changed GetNextPartitionWithRetention to add a +7 in the returned partition

       20220405 version 2.26 Modified Trigger for Compress for BASIC management.
            Changed installation script to restore grants prior to table drop.

       20220413 version 2.27 Allow COMPRESS ADVANCED compression value

    20220623 version 2.28 Changed management of the trigger that calculates the TABLE_ID
            Deleted sequence for TABLE_ID management

    20220801 version 2.29 Fix for algorithm in StartMaintenance that chooses table rows to execute

    20220915 version 2.30 Improvement for management of bitmap indexes on the exchange table

    20231020 version 2.31 New action introduced to manage rejuvenation with insert as select + drop partition
                                       Change of commit for ArchiveQuery functionality
                                       Modified start clause if Table _Name is specified so that the record must be enabled to be executed

    20231114 version 2.32 Fix logical compatibility triggers

    20240214   versione 2.33     Fix enable/disable fk per logica append

	20240314 version 2.34 Added exception in the export clause for partition already processed

	20241004 version 2.35 Added change to select in procedure "StartMaintenance" to avoid error "ORA-01555: snapshot too old"

   */

   PROCEDURE GetEnabledActions (pEntry DBA_OP.MAINT_PARTITIONS%ROWTYPE)
   AS
   BEGIN
      B_DATAEXPORT_ENABLED := 0;
      B_COMPRESSION_ENABLED := 0;
      B_ADD_PARTITION := 0;
      B_DROP_PARTITION := 0;
      B_EXCHANGE_PARTITION := 0;
      B_APPEND_PARTITION := 0;

      -- Check if Data Export is needed
      IF (pEntry.ACTION_EXPORT_DATA = 'Y')
      THEN
         LogFacility (
            LOG_SEV_INFO,
            'Dropped data/partitions will be exported before be dropped',
            pEntry.TABLE_NAME);
         B_DATAEXPORT_ENABLED := 1;
      ELSE
         LogFacility (
            LOG_SEV_INFO,
               'Dropped data/partitions will not be exported for table '
            || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
         B_DATAEXPORT_ENABLED := 0;
      END IF;

      -- Check if Partition Compression is needed :
      --
      IF (pEntry.ACTION_COMPRESS_PART = 'Y')
      THEN
         B_COMPRESSION_ENABLED := 1;
      ELSE
         LogFacility (
            LOG_SEV_INFO,
            'Compression will be disabled for table ' || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
         B_COMPRESSION_ENABLED := 0;
      END IF;

      --
      -- Check if Partition need to be created :
      --
      IF (pEntry.ACTION_ADD_PART = 'Y')
      THEN
         LogFacility (
            LOG_SEV_INFO,
            'Partition will added to this table ' || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
         B_ADD_PARTITION := 1;
      ELSE
         LogFacility (
            LOG_SEV_INFO,
            'Partition will not be added for table ' || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
         B_ADD_PARTITION := 0;
      END IF;

      --
      -- Check if Partition need to be created :
      --
      IF (pEntry.ACTION_DROP_PART = 'Y')
      THEN
         LogFacility (
            LOG_SEV_INFO,
            'Partition will dropped on this table ' || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
         B_DROP_PARTITION := 1;
      ELSE
         LogFacility (
            LOG_SEV_INFO,
            'Partition will not be dropped for table ' || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
         B_DROP_PARTITION := 0;
      END IF;

      --
      -- Check if Partition need to be created :
      --
      IF (pEntry.ACTION_EXCHANGE_PART = 'Y')
      THEN
         LogFacility (
            LOG_SEV_INFO,
               'Partition will be exchanged from this table '
            || pEntry.TABLE_NAME
            || ' to this table '
            || pEntry.Partition_Archive_Table_Name,
            pEntry.TABLE_NAME);
         B_EXCHANGE_PARTITION := 1;
      ELSE
         LogFacility (
            LOG_SEV_INFO,
            'Partition will not be exchanged for table ' || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
         B_EXCHANGE_PARTITION := 0;
      END IF;


      --
      -- Check if archiving should be performed with a SQL Query :
      --
      IF (pEntry.ACTION_ARCHIVE_WITH_QUERY = 'Y')
      THEN
         LogFacility (
            LOG_SEV_INFO,
               'Data will be archived row by row from this table '
            || pEntry.TABLE_NAME
            || ' to this table '
            || pEntry.Partition_Archive_Table_Name,
            pEntry.TABLE_NAME);
         B_ARCHIVE_WITH_QUERY := 1;
      ELSE
         LogFacility (LOG_SEV_INFO,
                      'Data will not be archived usign a custom query',
                      pEntry.TABLE_NAME);
         B_ARCHIVE_WITH_QUERY := 0;
      END IF;

      --
      -- Check if archiving should be performed with an insert append and part drop :
      --
      IF (pEntry.ACTION_APPEND_PART = 'Y')
      THEN
         LogFacility (
            LOG_SEV_INFO,
               'Data will be archived with an insert/append from this table '
            || pEntry.TABLE_NAME
            || ' to this table '
            || pEntry.Partition_Archive_Table_Name,
            pEntry.TABLE_NAME);
         B_APPEND_PARTITION := 1;
      ELSE
         LogFacility (LOG_SEV_INFO,
                      'Data will not be archived with an insert/append',
                      pEntry.TABLE_NAME);
         B_APPEND_PARTITION := 0;
      END IF;
   END;


   FUNCTION IsPartitionCompressed (pTableName   IN VARCHAR2,
                                   pPartName    IN VARCHAR2)
      RETURN BOOLEAN
   IS
      v_notcompressed_segs   NUMBER;
      v_ret_val              BOOLEAN;
      vStmt                  LONG;
   BEGIN
      -- To consider a partition as compressed it is necessary that all partitions and subpartitions are compressed, otherwise it is not
      vStmt :=
            'select sum(SEG_NOT_COMPRESSED) from (select count(*) SEG_NOT_COMPRESSED from dba_tab_partitions tp where 1=1 and tp.compression <> ''ENABLED'' AND tp.subpartition_count = 0 and tp.table_owner || ''.'' || tp.table_name = '''
         || pTableName
         || ''' and tp.partition_name = '''
         || pPartName
         || ''' union all select count(*) SEG_NOT_COMPRESSED from dba_tab_subpartitions tp where 1=1 and tp.compression <> ''ENABLED'' and tp.table_owner || ''.'' || tp.table_name = '''
         || pTableName
         || ''' and tp.partition_name = '''
         || pPartName
         || ''')';
      ExecSqlCommandInto (vStmt, pTableName, v_notcompressed_segs);

IF v_notcompressed_segs > 0
      THEN
         v_ret_val := FALSE;
      ELSE
         v_ret_val := TRUE;
      END IF;

      RETURN v_ret_val;
   END;


   FUNCTION IsFunction (f_string IN VARCHAR2)
      RETURN BOOLEAN
   IS
      vRetVat   BOOLEAN;
   BEGIN
      vRetVat := TRUE;

      IF INSTR (f_string, '.') > 0
      THEN
         vRetVat := TRUE;
      ELSE
         vRetVat := FALSE;
      END IF;

      RETURN vRetVat;
   EXCEPTION
      WHEN VALUE_ERROR
      THEN
         RETURN FALSE;
   END IsFunction;



   FUNCTION IsTableSubPartitioned (pTableName IN VARCHAR2)
      RETURN BOOLEAN
   IS
      vRetVal       BOOLEAN;
      vSubPartNum   NUMBER := 0;
   BEGIN
      SELECT COUNT (*)
        INTO vSubPartNum
        FROM DBA_TAB_SUBPARTITIONS
       WHERE TABLE_OWNER || '.' || TABLE_NAME = pTableName;

      IF vSubPartNum > 0
      THEN
         vRetVal := TRUE;
      ELSE
         vRetVal := FALSE;
      END IF;

      RETURN vRetVal;
   EXCEPTION
      WHEN VALUE_ERROR
      THEN
         RETURN FALSE;
   END IsTableSubpartitioned;



   FUNCTION IsNumber (p_string IN VARCHAR2)
      RETURN BOOLEAN
   IS
      v_new_num   NUMBER;
   BEGIN
      v_new_num := TO_NUMBER (p_string);
      RETURN TRUE;
   EXCEPTION
      WHEN VALUE_ERROR
      THEN
         RETURN FALSE;
   END IsNumber;


   PROCEDURE ExportPartitionData (pTable    IN VARCHAR2,
pPeriod IN VARCHAR2, -- partition name, OR a name to associate with the period specified by the subquery
pQuery IN VARCHAR2 DEFAULT NULL, -- subquery; if NULL, pPeriod must be a partition
                                  pDirobj   IN VARCHAR2 DEFAULT NULL -- directory object su cui esportare; se NULL, viene usata 'STOR_EXPDP'
                                                                    )
   AS
      --
      --Examples of use
      --
      -- PARTITIONED TABLE : export_data('MP_HISTORY.TICKET_QF_SPORT','P200508');
      -- NON-PARTITIONED TABLE: export_data('MP_HISTORY.AVVENTION','MONTH200508','where dataora_avv between...');
      -- Password may be required to import
      -- code history

      h1                       NUMBER;
      db_name                  VARCHAR2 (200);
      schema_name              VARCHAR2 (100);
      export_table_name        VARCHAR2 (100);
      partition_name           VARCHAR2 (100);
file_name VARCHAR2 (200);
      log_name                 VARCHAR2 (450);
      history_log              VARCHAR2 (200);
      run_log                  VARCHAR2 (200);
      base_name                VARCHAR2 (400);
      job_name                 VARCHAR2 (200);
      job_state                VARCHAR2 (50);
      lancio                   NUMBER;
      directory_object         VARCHAR2 (100);
      apice                    VARCHAR2 (1) := '''';
separator VARCHAR2 (1) := '_';
      max_filesize             VARCHAR2 (10) := NULL;
      file_exists              BOOLEAN;
      file_length              NUMBER (15);
      file_block               NUMBER (10);
      log_handle               UTL_FILE.file_type;
      l_text                   VARCHAR2 (2000);
      esito                    VARCHAR2 (2000);
start DATE;
end DATE;
      msg                      VARCHAR2 (2000);
      versione                 VARCHAR2 (30);
      encrypted_column_count   NUMBER (5);
      encrypted_export         BOOLEAN;
      is_pdb                   NUMBER;
      v_dbver                  NUMBER;
   BEGIN
      IF gDryRun = 'Y'
      THEN
         LogFacility (
            LOG_SEV_INFO,
            'Data will not be exported because this is a DryRun session',
            pTable);
         RETURN;
      END IF;

      LogFacility (LOG_SEV_INFO, 'Starting Export Table data', pTable);
      --
      -- pTable must have the format schema.table
      --
      schema_name := REGEXP_REPLACE (pTable, '\..*', '');
      export_table_name := REGEXP_REPLACE (pTable, '.*\.', '');

      IF NOT schema_name || '.' || export_table_name = pTable
      THEN
         RAISE_APPLICATION_ERROR (
            -20000,
'Usage: export_data(schema.tavola, partition | period[,subquery])');
      END IF;

      --
      --settings
      --
      schema_name := UPPER (schema_name);
      export_table_name := UPPER (export_table_name);
partition_name := UPPER (pPeriod);
      directory_object := NVL (UPPER (pDirobj), 'PM_EXPORTS');
      lancio := TO_NUMBER (TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS'));

      -- Checking if this is a pdb

      SELECT REPLACE (version, '.', '')
        INTO V_DBVER
        FROM PRODUCT_COMPONENT_VERSION
       WHERE PRODUCT LIKE 'Oracle Database%';

      -- When db is lower that 12.1, is truly not a pdb
      IF V_DBVER < 121020
      THEN
         SELECT NAME INTO DB_NAME FROM V$DATABASE;
      ELSE
         -- Here we check if we are on multitenant installation or not
         EXECUTE IMMEDIATE ('SELECT COUNT(*) FROM V$PDBS') INTO is_pdb;

         IF is_pdb = 1
         THEN
            EXECUTE IMMEDIATE ('SELECT NAME FROM V$PDBS') INTO DB_NAME;
         ELSE
            SELECT NAME INTO DB_NAME FROM V$DATABASE;
         END IF;
      END IF;

      base_name :=
            db_name
|| separator
         || schema_name
|| separator
         || export_table_name
|| separator
|| partition_name
|| separator
         || lancio;
      log_name := base_name || '.log';
      -- job_name is truncated to 30...
      job_name :=
         export_table_name || separatore || partition_name || '.' || lancio;
      history_log := 'export.history';
      run_log := 'export_run.log';
start := SYSDATE;

      LogFacility (LOG_SEV_INFO, 'Generated file is ' || base_name, pTable);

      --
      --output file name
      --
      file_name := base_name || '.dmp';

      --
      --Output files and log files do not have to pre-exist
      --
      UTL_FILE.fgetattr (directory_object,
file_name,
                         file_exists,
                         file_length,
                         file_block);

      IF file_exists
      THEN
         RAISE_APPLICATION_ERROR (
            -20000,
            '===ERRORE=== il file ' || file_name || ' already exist.');
      END IF;

      UTL_FILE.fgetattr (directory_object,
                         log_name,
                         file_exists,
                         file_length,
                         file_block);

      IF file_exists
      THEN
         RAISE_APPLICATION_ERROR (
            -20000,
            '===ERRORE=== il file ' || log_name || ' already exist.');
      END IF;

      LogFacility (
         LOG_SEV_INFO,
            'Starting export of partition :'
|| partition_name
         || '". Directory='
         || directory_object
         || '. File='
|| file_name
         || '.',
         pTable);

      --
      --launch start register: if I cannot access the dir, I will exit here, avoiding (unclear) errors in the construction of the job
      --
      log_handle :=
         UTL_FILE.fopen (directory_object,
                         run_log,
                         'a',
                         1000);
      msg :=
            TO_CHAR (SYSDATE, 'YYYY-MM-DD.HH24:MI:SS ')
         || 'lancio EXPORT_DATA '
|| file_name
         || '...';
      UTL_FILE.put_line (log_handle, msg);
      UTL_FILE.fclose (log_handle);

      --
      -- creation and definition of the job
      --
      LogFacility (LOG_SEV_DEBUG, 'Starting export job ' || job_name, pTable);

      h1 :=
         DBMS_DATAPUMP.OPEN ('EXPORT',
                             'TABLE',
                             NULL,
                             job_name);
      DBMS_DATAPUMP.add_file (h1,
file_name,
                              directory_object,
                              max_filesize,
                              DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE);
      DBMS_DATAPUMP.add_file (h1,
                              log_name,
                              directory_object,
                              NULL,
                              DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);
      DBMS_DATAPUMP.metadata_filter (h1,
                                     'SCHEMA_EXPR',
'=' || superscript || schema_name || apex,
                                     NULL);
      DBMS_DATAPUMP.metadata_filter (
         h1,
         'NAME_EXPR',
         '=' || apice || export_table_name || apice);

      IF pQuery IS NULL
      THEN
         DBMS_DATAPUMP.data_filter (h1,
                                    'PARTITION_LIST',
partition_name,
                                    NULL,
                                    NULL);
      ELSE
         DBMS_DATAPUMP.DATA_FILTER (h1,
                                    'SUBQUERY',
                                    pQuery,
                                    NULL,
                                    NULL);
      END IF;


      --
      -- starting, waiting for completion
      --
      DBMS_DATAPUMP.start_job (h1, 0);
      DBMS_DATAPUMP.wait_for_job (h1, job_state);
      DBMS_DATAPUMP.detach (h1);
end := SYSDATE;

      --
      -- verify job completed, log file existence
      --
      LogFacility (LOG_SEV_DEBUG,
                   'Checking that job...' || job_name || ' is completed',
                   pTable);

      IF job_state != 'COMPLETED'
      THEN
         LogFacility (
            LOG_SEV_ERROR,
               'Job '
            || job_name
            || ' competed with state : '
            || job_state
            || ' finished with error',
            pTable);
         RAISE_APPLICATION_ERROR (
            -20000,
            '===ERRORE=== Export job not completed, job_state=' || job_state);
      END IF;

      UTL_FILE.fgetattr (directory_object,
                         log_name,
                         file_exists,
                         file_length,
                         file_block);

      IF NOT file_exists
      THEN
         LogFacility (
            LOG_SEV_ERROR,
            'Logfile ' || log_name || ' after export does not exist.',
            pTable);
         RAISE_APPLICATION_ERROR (
            -20000,
               '===ERRORE=== LogFile '
            || log_name
            || ' after export does not exist.');
      END IF;

      --
      --log file analysis
      --
      log_handle :=
         UTL_FILE.fopen (directory_object,
                         log_name,
                         'r',
                         1000);

      --if no errors I set OK and continue; warning-encryption set OK and continue; else-NOW-I set KO and break loop
      -- (the KO must not be covered by subsequent warnings...)
      --
      esito := '??';

      BEGIN
         LOOP
            UTL_FILE.GET_LINE (log_handle, l_text);

            IF    l_text LIKE '%successfully completed%'
OR l_text LIKE '%completed in%'
            THEN
               --should imply no errors and no warnings
               esito := 'OK: ' || l_text;
               LogFacility (
                  LOG_SEV_INFO,
                  'Job Name ' || job_name || ' completed successfully',
                  pTable);
            END IF;

            IF l_text LIKE 'ORA-%'
            THEN
               esito := 'KO: ' || l_text;
               LogFacility (
                  LOG_SEV_ERROR,
                     'Job Name '
                  || job_name
                  || ' completed with error :'
                  || l_text,
                  pTable);
            END IF;

            IF l_text LIKE 'ORA-39173%'
            THEN
               esito := 'OK: ' || l_text;
               LogFacility (
                  LOG_SEV_ERROR,
                     'Job Name '
                  || job_name
                  || ' completed successfully :'
                  || l_text,
                  pTable);
            END IF;

			IF l_text LIKE 'ORA-02149%'
            THEN
               esito := 'OK: ' || l_text;
               LogFacility (
                  LOG_SEV_ERROR,
                     'Job Name '
                  || job_name
                  || ' completed successfully :'
                  || l_text,
                  pTable);
            END IF;

IF result LIKE 'KO%'
            THEN
               UTL_FILE.FCLOSE (log_handle);
               LogFacility (
                  LOG_SEV_INFO,
                  'Job Name ' || job_name || ' completed successfully',
                  pTable);
               EXIT;
            END IF;
         END LOOP;
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            UTL_FILE.FCLOSE (log_handle);
      END;

      --
      -- adding a summary line of times at the end of the log
      --
      log_handle :=
         UTL_FILE.fopen (directory_object,
                         log_name,
                         'a',
                         1000);
      UTL_FILE.put_line (
         log_handle,
            '=== NEXI === start: '
         || TO_CHAR(start, 'YYYY-MM-DD HH24:MI:SS')
         || ' end: '
         || TO_CHAR (fine, 'YYYY-MM-DD HH24:MI:SS')
         || ' minuti: '
|| ROUND ( (end - start) * 1440, 2));
      UTL_FILE.fclose (log_handle);

      --
      --interruption in case of error
      --
      /*  old version
      IF  l_text NOT LIKE '%successfully completed%'
      AND l_text NOT LIKE '%completed in%'
      */
IF outcome LIKE 'KO%' OR outcome LIKE '??%'
      THEN
         RAISE_APPLICATION_ERROR (-20000, '===ERRORE EXPORT=== ' || esito);
      END IF;

      LogFacility (
         LOG_SEV_INFO,
            'Export of partition :'
|| partition_name
         || '". Directory='
         || directory_object
         || '. File='
|| file_name
         || ' successfully finished',
         pTable);

      --
      -- execution completed successfully, recorded in the history_log
      --
      UTL_FILE.fgetattr (directory_object,
file_name,
                         file_exists,
                         file_length,
                         file_block);
      file_length := ROUND (file_length / (1024 * 1024), 1);
      msg :=
         TO_CHAR (SYSDATE, 'YYYY-MM-DD.HH24:MI:SS ') || file_name;
      msg := msg || ' [';

      msg :=
msg || ' minutes=' || ROUND ( (end - start) * 1440, 2);
      msg := msg || ' MB=' || file_length;
      msg := msg || ' db=' || db_name;
      msg := msg || ' ] ';

      IF pQuery IS NOT NULL
      THEN
         msg := msg || ' subquery=' || apice || pQuery || apice;
      END IF;

      log_handle :=
         UTL_FILE.fopen (directory_object,
                         history_log,
                         'a',
                         1000);
      UTL_FILE.put_line (log_handle, msg);
      UTL_FILE.fclose (log_handle);
   END;


   PROCEDURE LogFacility (pSeverity    INTEGER,
                          pMessage     VARCHAR2,
                          pTable       VARCHAR2)
   AS
      owautil_wcm_owner      VARCHAR2 (1024);
      owautil_wcm_name       VARCHAR (1024);
      owautil_wcm_lineno     NUMBER;
      owautil_wcm_caller_t   VARCHAR (1024);
   BEGIN
      SYS.OWA_UTIL.WHO_CALLED_ME (owautil_wcm_owner,
                                  owautil_wcm_name,
                                  owautil_wcm_lineno,
                                  owautil_wcm_caller_t);

      IF gRunId IS NULL
      THEN
         SELECT PARTITIONS_LOG_SEQ.NEXTVAL INTO gRunId FROM DUAL;
      END IF;

      -- Checking if requested logging severity is compatible with Logging level passed to the procedure
      IF (pSeverity < gLogLevel)
      THEN
         RETURN;
      END IF;

      DBMS_OUTPUT.put_line (
            pSeverity
         || '  '
         || pTable
         || ' : '
         || owautil_wcm_name
         || ':'
         || pMessage);

      INSERT INTO DBA_OP.MAINT_PARTITIONS_LOG (runid,
datetime,
                                               severity,
                                               procedure_name,
                                               MESSAGE,
                                               table_name)
         SELECT gRunId,
                SYSTIMESTAMP,
                DECODE (pSeverity,
                        -1, 'DEBUG',
                        0, 'INFO',
                        1, 'WARNING',
                        2, 'ERROR',
                        'INFO'),
                --pSeverity,
                owautil_wcm_name,
                SUBSTR (pMessage, 1, 3999),
                pTable
           FROM DUAL;

      COMMIT;
   EXCEPTION
      WHEN OTHERS
      THEN
         DBMS_OUTPUT.put_line (
               pSeverity
            || '  '
            || pTable
            || ' : '
            || owautil_wcm_name
            || ':'
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']');
         ROLLBACK;
   END;

   --

   FUNCTION GetPartitionListToAdd (pEntry MAINT_PARTITIONS%ROWTYPE)
      RETURN pm_partition_list_type
   AS
      vPartitionList           pm_partition_list_type := pm_partition_list_type ();
      vPartDate                NUMBER;
      vPartName                DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE;
      vPartTablespaceName      DBA_TAB_PARTITIONS.TABLESPACE_NAME%TYPE := NULL;
      vPartDateWithRetention   NUMBER;
      vPartCount               NUMBER;
      vPartCurrHV              VARCHAR2 (100);
   BEGIN
      LogFacility (
         LOG_SEV_DEBUG,
            'Starting GetPartitionListToAdd for table : '
         || UPPER (pEntry.Table_Name),
         pEntry.Table_Name);

      vPartDate :=
         GetMinMaxPartitionDate (pEntry.TABLE_NAME,
                                 'MAX',
                                 vPartName,
                                 vPartTablespaceName);

      IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
      THEN
         vPartDateWithRetention :=
            GetNextPartitionWithRetention (NULL                   /*SYSDATE,*/
                                               ,
                                           pEntry.Partition_Retention_Unit,
                                           pEntry.Partition_Add_Count);

         IF vPartDate IS NULL
         THEN
            vPartDate :=
               GetNextPartitionWithRetention (
                  NULL                                           /* SYSDATE */
                      ,
                  pEntry.Partition_Retention_Unit,
                  0);
            vPartName :=
CalculatePartitionName(vPartDate,
                                       pEntry.Partition_Retention_Unit,
                                       pEntry.Partition_Name_Prefix);
            vPartTablespaceName := NULL;
         END IF;
      ELSE
         ExecSqlCommandInto (
               'SELECT '
            || pEntry.PARTITION_RETENTION_UNIT
            || '.GetCurrentPartitionHV('''
            || pEntry.TABLE_NAME
            || ''') FROM DUAL',
            NULL,
            vPartCurrHV);
         --ExecSqlCommandInto('SELECT ' || pEntry.PARTITION_RETENTION_UNIT || '.GetNextHV(''' || pEntry.TABLE_NAME || ''' , ''' || vPartCurrHV || ''',1 ) FROM DUAL',NULL,vPartCurrHV);

         ExecSqlCommandInto (
               'SELECT '
            || pEntry.PARTITION_RETENTION_UNIT
            || '.GetNextHV('''
            || pEntry.TABLE_NAME
            || ''' , '''
            || vPartCurrHV
            || ''','
            || pEntry.Partition_Add_Count
            || ') FROM DUAL',
            NULL,
            vPartDateWithRetention);

         -- In this branch it must not be a concern, but if vPartDate is null, that is the only partition present is the DEFAULT partition,
         -- in this case we will start from current High value to create partitions
         IF vPartDate IS NULL
         THEN
            vPartDate := vPartCurrHV;
         END IF;
      END IF;

      vPartCount := 1;

      -- As the while loop below is done, I have to do the calculation with Partition_Add_Count -1 otherwise I create an unwanted extra partition
      WHILE (vPartDate < vPartDateWithRetention)
      LOOP
         IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
         THEN
            vPartDate :=
               GetNextPartitionWithRetention (
                  vPartDate,
                  pEntry.Partition_Retention_Unit,
                  pRetentionValue   => 0);
            vPartitionList.EXTEND;
            vPartitionList (vPartCount) :=
               pm_part_rec_type (NULL, NULL, NULL);
            vPartitionList (vPartCount).partition_high_value := vPartDate;
            vPartitionList (vPartCount).partition_name :=
CalculatePartitionName(vPartDate,
                                       pEntry.Partition_Retention_Unit,
                                       pEntry.Partition_Name_Prefix);
         ELSE
            vPartitionList.EXTEND;
            vPartitionList (vPartCount) :=
               pm_part_rec_type (NULL, NULL, NULL);

            ExecSqlCommandInto (
                  'SELECT '
               || pEntry.PARTITION_RETENTION_UNIT
               || '.GetNextHV('''
               || pEntry.Table_Name
               || ''' , '''
               || vPartDate
               || ''', 1 ) FROM DUAL',
               NULL,
               vPartDate);

            vPartitionList (vPartCount).partition_high_value := vPartDate;
            ExecSqlCommandInto (
                  'SELECT '
               || pEntry.PARTITION_RETENTION_UNIT
               || '.GetPartitionNameFromHV('''
               || pEntry.Table_Name
               || ''' , '''
               || vPartDate
               || ''') FROM DUAL',
               NULL,
               vPartName);
            vPartitionList (vPartCount).partition_name := vPartName;
         END IF;

         vPartCount := vPartCount + 1;
      END LOOP;

      LogFacility (
         LOG_SEV_DEBUG,
            'Finished GetPartitionListToAdd for table : '
         || UPPER (pEntry.Table_Name),
         pEntry.Table_Name);

      RETURN vPartitionList;
   END;



   FUNCTION GetPartitionListToRemove (pEntry MAINT_PARTITIONS%ROWTYPE)
      RETURN pm_partition_list_type
   AS
      vPartitionList           pm_partition_list_type := pm_partition_list_type ();
      vPartDate                NUMBER;
      vPartDateWithRetention   NUMBER;
      vPartName                DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE;
      vPartTablespaceName      DBA_TAB_PARTITIONS.TABLESPACE_NAME%TYPE;
      vPartCount               NUMBER;
      vPartCurrHV              VARCHAR2 (100);
   BEGIN
      LogFacility (
         LOG_SEV_DEBUG,
            'Starting GetPartitionListToRemove for table : '
         || UPPER (pEntry.Table_Name),
         pEntry.Table_Name);


      IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
      THEN
         vPartDate :=
            GetMinMaxPartitionDate (pEntry.TABLE_NAME,
                                    'MIN',
                                    vPartName,
                                    vPartTablespaceName);
         vPartDateWithRetention :=
            GetNextPartitionWithRetention (
               NULL                                               /*SYSDATE,*/
                   ,
               pEntry.PARTITION_RETENTION_UNIT,
               -pEntry.PARTITION_RETENTION_UNIT_COUNT);
      ELSE
         vPartDate :=
            GetMinMaxPartitionDate (pEntry.TABLE_NAME,
                                    'MIN',
                                    vPartName,
                                    vPartTablespaceName);
         ExecSqlCommandInto (
               'SELECT '
            || pEntry.PARTITION_RETENTION_UNIT
            || '.GetCurrentPartitionHV('''
            || pEntry.TABLE_NAME
            || ''') FROM DUAL',
            NULL,
            vPartCurrHV);
         ExecSqlCommandInto (
               'SELECT '
            || pEntry.PARTITION_RETENTION_UNIT
            || '.GetNextHV('''
            || pEntry.TABLE_NAME
            || ''' , '''
            || vPartCurrHV
            || ''','
            || -pEntry.PARTITION_RETENTION_UNIT_COUNT
            || ') FROM DUAL',
            NULL,
            vPartDateWithRetention);
      END IF;

      vPartCount := 1;

      WHILE (vPartDate < vPartDateWithRetention)
      LOOP
         IF PartitionExists (pEntry.TABLE_NAME, vPartName) = TRUE
         THEN
            vPartitionList.EXTEND;
            vPartitionList (vPartCount) :=
               pm_part_rec_type (NULL, NULL, NULL);

            vPartitionList (vPartCount).partition_name := vPartName;
            vPartitionList (vPartCount).partition_high_value := vPartDate;
            vPartitionList (vPartCount).tablespace_name :=
               vPartTablespaceName;

            vPartCount :=
               vPartCount + 1;
         END IF;

         IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
         THEN
            vPartDate :=
               GetNextPartition (t_partition_work,
                                 vPartDate,
                                 pEntry.PARTITION_RETENTION_UNIT,
                                 vPartName);
         ELSE
            ExecSqlCommandInto (
                  'SELECT '
               || pEntry.PARTITION_RETENTION_UNIT
               || '.GetNextHV('''
               || pEntry.Table_Name
               || ''' , '''
               || vPartDate
               || ''',1 ) FROM DUAL',
               NULL,
               vPartDate);
            ExecSqlCommandInto (
                  'SELECT '
               || pEntry.PARTITION_RETENTION_UNIT
               || '.GetPartitionNameFromHV('''
               || pEntry.Table_Name
               || ''' , '''
               || vPartDate
               || ''') FROM DUAL',
               NULL,
               vPartName);
         END IF;
      END LOOP;

      LogFacility (
         LOG_SEV_DEBUG,
            'Finished GetPartitionListToRemove for table : '
         || UPPER (pEntry.Table_Name),
         pEntry.Table_Name);

      RETURN vPartitionList;
   END;


   FUNCTION GetPartitionListToCompress (pEntry MAINT_PARTITIONS%ROWTYPE)
      RETURN pm_partition_list_type
   AS
      vPartitionList           pm_partition_list_type := pm_partition_list_type ();
      vPartName                DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE;
      vPartTablespaceName      DBA_TAB_PARTITIONS.TABLESPACE_NAME%TYPE;
      vPartDateWithRetention   NUMBER;
      vPartDate                NUMBER;
      vStmt                    LONG;
      isCompressed             NUMBER;
      vPartCount               NUMBER;
      vPartCurrHV              VARCHAR2 (100);
   BEGIN
      LogFacility (
         LOG_SEV_DEBUG,
            'Starting GetPartitionListToCompress for table : '
         || UPPER (pEntry.Table_Name),
         pEntry.Table_Name);


      IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
      THEN
         vPartDate :=
            GetMinMaxPartitionDate (pEntry.TABLE_NAME,
                                    'MIN',
                                    vPartName,
                                    vPartTablespaceName);
         vPartDateWithRetention :=
            GetNextPartitionWithRetention (
               NULL                                               /*SYSDATE,*/
                   ,
               pEntry.PARTITION_RETENTION_UNIT,
               -pEntry.PARTITION_RETENTION_UNIT_COUNT);
         vPartCount := 1;
      ELSE
         vPartDate :=
            GetMinMaxPartitionDate (pEntry.TABLE_NAME,
                                    'MIN',
                                    vPartName,
                                    vPartTablespaceName);
         ExecSqlCommandInto (
               'SELECT '
            || pEntry.PARTITION_RETENTION_UNIT
            || '.GetCurrentPartitionHV('''
            || pEntry.TABLE_NAME
            || ''') FROM DUAL',
            NULL,
            vPartCurrHV);
         ExecSqlCommandInto (
               'SELECT '
            || pEntry.PARTITION_RETENTION_UNIT
            || '.GetNextHV('''
            || pEntry.TABLE_NAME
            || ''' , '''
            || vPartCurrHV
            || ''','
            || -pEntry.PARTITION_RETENTION_UNIT_COUNT
            || ') FROM DUAL',
            NULL,
            vPartDateWithRetention);
         vPartCount := 1;
      END IF;



      WHILE (vPartDate < vPartDateWithRetention)
      LOOP
         IF (    PartitionExists (pEntry.Table_Name, vPartName) = TRUE
             AND isPartitionCompressed (pEntry.Table_Name, vPartName) = FALSE)
         THEN
            vPartitionList.EXTEND;
            vPartitionList (vPartCount) :=
               pm_part_rec_type (NULL, NULL, NULL);

            vPartitionList (vPartCount).partition_name := vPartName;
            vPartitionList (vPartCount).partition_high_value := vPartDate;
            vPartCount :=
               vPartCount + 1;
         END IF;

         IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
         THEN
            vPartDate :=
               GetNextPartition (t_partition_work,
                                 vPartDate,
                                 pEntry.PARTITION_RETENTION_UNIT,
                                 vPartName);
         ELSE
            ExecSqlCommandInto (
                  'SELECT '
               || pEntry.PARTITION_RETENTION_UNIT
               || '.GetNextHV('''
               || pEntry.Table_Name
               || ''' , '''
               || vPartDate
               || ''',1 ) FROM DUAL',
               NULL,
               vPartDate);
            ExecSqlCommandInto (
                  'SELECT '
               || pEntry.PARTITION_RETENTION_UNIT
               || '.GetPartitionNameFromHV('''
               || pEntry.Table_Name
               || ''' , '''
               || vPartDate
               || ''') FROM DUAL',
               NULL,
               vPartName);
         END IF;
      END LOOP;

      LogFacility (
         LOG_SEV_DEBUG,
            'Finished GetPartitionListToCompress for table : '
         || UPPER (pEntry.Table_Name),
         pEntry.Table_Name);

      RETURN vPartitionList;
   END;


   FUNCTION GetNextPartitionWithRetention (
      pDate              VARCHAR2,
      pRetentionUnit     VARCHAR2,
      pRetentionValue    NUMBER DEFAULT 1)
      RETURN NUMBER
   AS
      vPartDate        DATE;
      vDateFormatted   DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE;
      vMondayName      VARCHAR2 (10);
      vPartName        DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE;
   BEGIN
      -- The next partition is always calculated according with SYSDATE
      -- because we cannot use the highest partition in the table to calculate the date because the job
      -- may have not run for days and highest artition may be

      LogFacility (
         LOG_SEV_DEBUG,
         'Starting GetNextPartitionWithRetention for date :' || pDate,
         NULL);

      IF pDate IS NULL
      THEN
         IF pRetentionUnit = 'YYYYMMWK'
         THEN
            ExecSqlCommandInto (
               'SELECT TO_CHAR(SYSDATE,''YYYYMMDD'') FROM DUAL',
               NULL,
               vDateFormatted);
         ELSE
            ExecSqlCommandInto (
                  'SELECT TO_CHAR(SYSDATE,'''
               || pRetentionUnit
               || ''') FROM DUAL',
               NULL,
               vDateFormatted);
         END IF;
      ELSE
         vDateFormatted := pDate;
      END IF;


      IF (pRetentionUnit = 'YYYYMMDD')
      THEN
         vPartDate :=
            TRUNC (
               TO_DATE (vDateFormatted, pRetentionUnit) + pRetentionValue + 1);

         SELECT (TO_CHAR (vPartDate, pRetentionUnit))
           INTO vPartName
           FROM DUAL;
      ELSIF (pRetentionUnit = 'YYYYMMWK')
      THEN
         -- Checking the current NLS_LANGUAGE setup
         SELECT DECODE (VALUE, 'ITALIAN', 'LUNEDI', 'MONDAY')
           INTO vMondayName
           FROM nls_session_parameters
          WHERE parameter = 'NLS_LANGUAGE';

         vPartDate :=
            TRUNC (
               NEXT_DAY (
                    TO_DATE (vDateFormatted, 'YYYYMMDD')
                  + 7 * pRetentionValue
                  + 7,
                  vMondayName));

         SELECT (TO_CHAR (vPartDate, 'YYYYMMDD'))
           INTO vPartName
           FROM DUAL;
      ELSIF (pRetentionUnit = 'YYYYMM')
      THEN
         vPartDate :=
            ADD_MONTHS (TO_DATE (vDateFormatted, pRetentionUnit),
                        pRetentionValue + 1);

         SELECT (TO_CHAR (vPartDate, pRetentionUnit))
           INTO vPartName
           FROM DUAL;
      ELSIF (pRetentionUnit = 'YYYY')
      THEN
         vPartDate :=
            TRUNC (
               ADD_MONTHS (TO_DATE (vDateFormatted, pRetentionUnit),
                           pRetentionValue * 12 + 12),
               'YEAR');

         SELECT (TO_CHAR (vPartDate, pRetentionUnit))
           INTO vPartName
           FROM DUAL;
      ELSIF (IsNumber (vDateFormatted) = TRUE)
      THEN
         SELECT (TO_CHAR (pDate - pRetentionUnit))
           INTO vPartName
           FROM DUAL;
      END IF;

      LogFacility (LOG_SEV_DEBUG,
                   'Finished GetNextPartitionWithRetention',
                   NULL);

      RETURN vPartName;
   END;


   FUNCTION GetNextPartition (
      pTablePartitionList          pm_partition_list_type,
      pPartDate                    VARCHAR2,
      pRetentionUnit               VARCHAR2,
      vNextPartName         IN OUT DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE)
      RETURN NUMBER
   AS
      vNextPartDate   VARCHAR2 (100);
   BEGIN
      LogFacility (LOG_SEV_DEBUG, 'Starting GetNextPartition', NULL);

      SELECT partition_name, partition_high_value
        INTO vNextPartName, vNextPartDate
        FROM (  SELECT partition_name, partition_high_value
                  FROM TABLE (pTablePartitionList)
                 WHERE partition_high_value > pPartDate
              ORDER BY partition_high_value ASC)
       WHERE ROWNUM < 2;

      LogFacility (LOG_SEV_DEBUG, 'Finished GetNextPartition', NULL);

      RETURN vNextPartDate;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN NULL;
   END;


   FUNCTION GetMinMaxPartitionDate (
      pTable                       MAINT_PARTITIONS.table_name%TYPE,
      pMinMax                      VARCHAR2 DEFAULT 'MIN',
      vPartName             IN OUT DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE,
      vPartTablespaceName   IN OUT DBA_TAB_PARTITIONS.TABLESPACE_NAME%TYPE)
      RETURN NUMBER
   AS
      vPartDate   NUMBER;
   BEGIN
      LogFacility (
         LOG_SEV_DEBUG,
         'Starting GetMinMaxPartitionDate for partition name: ' || vPartName,
         NULL);

      IF pMinMax = 'MIN'
      THEN
         SELECT partition_name, partition_high_value, tablespace_name
           INTO vPartName, vPartDate, vPartTablespacename
           FROM TABLE (t_partition_work)
          WHERE partition_high_value =
                   (SELECT MIN (partition_high_value)
                      FROM TABLE (t_partition_work));
      ELSIF pMinMax = 'MAX'
      THEN
         BEGIN
            SELECT partition_name, partition_high_value, tablespace_name
              INTO vPartName, vPartDate, vPartTablespaceName
              FROM TABLE (t_partition_work)
             WHERE partition_high_value = (SELECT MAX (partition_high_value)
                                             FROM TABLE (t_partition_work)
                                            WHERE SUBSTR (
                                                     partition_high_value,
                                                     1,
                                                     4) <> '9999');
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               -- When no data found on first select , this means that default partition is the only one present in the table.
               -- According to this, we

               vPartName := NULL;
               vPartDate := NULL;
               vPartTablespaceName := NULL;
         END;
      END IF;

      LogFacility (
         LOG_SEV_DEBUG,
         'Finished GetMinMaxPartitionDate for partition name: ' || vPartName,
         NULL);

      RETURN vPartDate;
   END;


   PROCEDURE AppendPartitionList (pEntry MAINT_PARTITIONS%ROWTYPE)
   AS
      vPartitionList        pm_partition_list_type := pm_partition_list_type ();
      vPartName             DBA_TAB_PARTITIONS.partition_name%TYPE;
      vPartTablespaceName   DBA_TAB_PARTITIONS.tablespace_name%TYPE;
      vPartString           VARCHAR2 (100);
      vPartDate             VARCHAR2 (100);
      vStmt                 VARCHAR2 (4000);
      vRecordDiff           NUMBER;
	  comandi_disable       pm_constraint_list_type := pm_constraint_list_type (); -- comandi disable per tutte le fk entranti
      comandi_enable        pm_constraint_list_type := pm_constraint_list_type (); -- comandi enable novalidate per tutte le fk entranti
   BEGIN
      vPartitionList := GetPartitionListToRemove (pEntry);

      LogFacility (LOG_SEV_INFO,
                   'Starting Append Partition...',
                   pEntry.TABLE_NAME);


      FOR vCmdCount IN 1 .. vPartitionList.COUNT
      LOOP
         vPartName := vPartitionList (vCmdCount).partition_name;
         vPartDate := vPartitionList (vCmdCount).partition_high_value;
         vPartTablespaceName := vPartitionList (vCmdCount).tablespace_name;


         IF (CountPartitions (pEntry.TABLE_NAME) > 1)
         THEN
            IF PartitionExists (pEntry.Table_Name, vPartName)
            THEN
               LogFacility (
                  LOG_SEV_INFO,
                     'Archiving with Append partition : '
                  || vPartName
                  || ' from '
                  || TRIM (pEntry.Table_Name)
                  || ' to '
                  || pEntry.Partition_Archive_Table_Name,
                  pEntry.TABLE_NAME);

               -- If table partition exists but is empty, we try to drop the Partition without archiving it.
               IF (IsPartitionEmpty (pEntry.Table_Name, vPartName) = 1)
               THEN
                  LogFacility (
                     LOG_SEV_INFO,
                        'Partition '
                     || vPartName
                     || ' is empty and will be dropped without backing up data to archive table',
                     pEntry.TABLE_NAME);

                  -- Now dropping empty partition
                  DropEmptyPartition (pEntry.TABLE_NAME, vPartName);

                  -- Skip next steps in this case
                  CONTINUE;
               END IF;

               -- If partition not exists on target archive table creating it..if it is not an interval partitioned table
               IF NOT PartitionExists (pEntry.Partition_Archive_Table_Name,
                                       vPartName)
               THEN
                  IF NOT isIntervalPartitionedTable (
                            pEntry.Partition_Archive_Table_Name)
                  THEN
                     LogFacility (
                        LOG_SEV_INFO,
                           'Creating partition : '
                        || vPartName
                        || ' on table '
                        || TRIM (pEntry.Partition_Archive_Table_Name),
                        pEntry.TABLE_NAME);

                     CreatePartition (pEntry.Partition_Archive_Table_Name,
                                      t_partition_arc_work,
                                      vPartName,
                                      vPartTablespaceName,
                                      vPartDate,
                                      pEntry.Partition_Retention_Unit,
                                      pEntry.Partition_Name_Prefix,
                                      pEntry.Parallel_Degree);
                  ELSE
                     -- Unfortunately, the lock table command uses date in the command like the START period of the partition and not the high value like in the other process
                     -- we need to calculate the correct date to pass to the command in order to create the corret partition for vPartDate

                     IF IsFunction (pEntry.Partition_Retention_Unit) = FALSE
                     THEN
                        vPartDate :=
                           GetNextPartitionWithRetention (
                              vPartDate,
                              pEntry.Partition_Retention_Unit,
                              -2);
                     ELSE
                        ExecSqlCommandInto (
                              'SELECT '
                           || pEntry.Partition_Retention_Unit
                           || '.GetNextHV('''
                           || pEntry.TABLE_NAME
                           || ''' , '''
                           || vPartDate
                           || ''',-2 ) FROM DUAL',
                           pEntry.TABLE_NAME,
                           vPartDate);
                     END IF;

                     IF (   INSTR (gPartColumnDatatype, 'TIMESTAMP') > 0
                         OR gPartColumnDatatype = 'DATE')
                     THEN
                        IF (pEntry.Partition_Retention_Unit = 'YYYYMMWK')
                        THEN
                           vPartString :=
                                 'TO_DATE('' '
                              || TO_CHAR (TO_DATE (vPartDate, 'YYYYMMDD'),
                                          'YYYY-MM-DD HH24:MI:SS')
                              || ''', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')';
                        ELSE
                           vPartString :=
                                 'TO_DATE('' '
                              || TO_CHAR (
                                    TO_DATE (vPartDate,
                                             pEntry.Partition_Retention_Unit),
                                    'YYYY-MM-DD HH24:MI:SS')
                              || ''', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')';
                        END IF;
                     ELSE
                        vPartString := vPartDate;
                     END IF;

                     LogFacility (
                        LOG_SEV_INFO,
                           'Creating partition : '
                        || vPartName
                        || ' on interval partitioned table : '
                        || TRIM (pEntry.Partition_Archive_Table_Name),
                        pEntry.TABLE_NAME);

                     ExecSqlCommand (
                           'LOCK TABLE '
                        || pEntry.Partition_Archive_Table_Name
                        || ' PARTITION FOR ('
                        || vPartString
                        || ') IN SHARE MODE',
                        pEntry.TABLE_NAME);

                     -- Partition created in an interval partioned table is automatically created with SYS_XXX, we need to rename it to our default standard :
                     RenameIntervalPartition (
                        pEntry,
                        pEntry.Partition_Archive_Table_Name);
                  END IF;
               END IF;

               IF pEntry.Parallel_Degree > 1
               THEN
                  vStmt :=
                        'INSERT /*+ APPEND ENABLE_PARALLEL_DML PARALLEL(x,'
                     || pEntry.Parallel_Degree
                     || ') */ INTO '
                     || pEntry.Partition_Archive_Table_Name
                     || ' x SELECT /*+ PARALLEL(xx,'
                     || pEntry.Parallel_Degree
                     || ') */ * FROM '
                     || pEntry.TABLE_NAME
                     || ' PARTITION ('
                     || vPartName
                     || ') xx';
               ELSE
                  vStmt :=
                        'INSERT /*+ APPEND */ INTO '
                     || pEntry.Partition_Archive_Table_Name
                     || ' SELECT * FROM '
                     || pEntry.TABLE_NAME
                     || ' PARTITION ('
                     || vPartName
                     || ')';
               END IF;

               -- Exception handling to create a consistence point before/after insert errors
               BEGIN
                  ExecSqlCommand (vStmt, pEntry.TABLE_NAME);
                  COMMIT;

                  LogFacility (
                     LOG_SEV_INFO,
                        'Appended partition :'
                     || vPartName
                     || ' to '
                     || TRIM (pEntry.Partition_Archive_Table_Name)
                     || '".',
                     pEntry.TABLE_NAME);

                  FOR x
                     IN (SELECT child.owner || '.' || child.table_name
                                   fktable,
                                child.constraint_name fk
                           FROM dba_constraints child, dba_constraints parent
                          WHERE     child.CONSTRAINT_TYPE = 'R'
                                AND child.STATUS = 'ENABLED'
                                AND child.r_owner = parent.owner
                                AND child.r_constraint_name =
                                       parent.constraint_name
                                AND parent.OWNER || '.' || parent.table_name =
                                       UPPER (pEntry.TABLE_NAME))
                  LOOP
                     LogFacility (
                        LOG_SEV_INFO,
                           'Constraint '
                        || x.fk
                        || ' on table : '
                        || pEntry.TABLE_NAME
                        || ' will be disabled',
                        pEntry.TABLE_NAME);

commands_disable.EXTEND;
commands_enable.EXTEND;
commands_disable (comands_disable.COUNT) :=
                           'alter table '
                        || x.fktable
                        || ' disable constraint '
                        || x.fk;
commands_enable (commands_enable.COUNT) :=
                           'alter table '
                        || x.fktable
                        || ' enable novalidate constraint '
                        || x.fk;
                  END LOOP;


                  -- 20240214 esegui disable
FOR vCmdCount IN 1 .. commands_disable.COUNT
                  LOOP
                     BEGIN
                        LogFacility (LOG_SEV_INFO,
commands_disable (vCmdCount),
                                     pEntry.TABLE_NAME);
                        ExecSqlCommand (comandi_disable (vCmdCount),
                                        pEntry.TABLE_NAME);
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           LogFacility (
                              LOG_SEV_WARNING,
                                 'An error occurred during '
|| commands_disable (vCmdCount)
                              || ' : '
                              || SQLERRM
                              || ' [Code: '
                              || TO_CHAR (SQLCODE)
                              || ']',
                              pEntry.TABLE_NAME);
                     END;
                  END LOOP;

                  vStmt :=
                        'alter table '
                     || TRIM (pEntry.TABLE_NAME)
                     || ' drop partition '
                     || vPartName
                     || ' update indexes';
                  ExecSqlCommand (vStmt, pEntry.TABLE_NAME);

                  LogFacility (
                     LOG_SEV_INFO,
                        'Dropped partition :'
                     || vPartName
                     || ' on '
                     || TRIM (pEntry.Table_Name)
                     || '".',
                     pEntry.TABLE_NAME);

                  -- 20240214 esegui enable
                  FOR vCmdCount IN 1 .. comandi_enable.COUNT
                  LOOP
                     BEGIN
                        LogFacility (LOG_SEV_INFO,
commands_enable (vCmdCount),
                                     pEntry.TABLE_NAME);
                        ExecSqlCommand (comandi_enable (vCmdCount),
                                        pEntry.TABLE_NAME);
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           LogFacility (
                              LOG_SEV_WARNING,
                                 'An error occurred during '
|| commands_enable (vCmdCount)
                              || ' : '
                              || SQLERRM
                              || ' [Code: '
                              || TO_CHAR (SQLCODE)
                              || ']',
                              pEntry.TABLE_NAME);
                     END;
                  END LOOP;
               /*
                    -- Now checking that two partitions got the same rows
                    vStmt := 'with first as ( select COUNT(*) cnt from ' || pEntry.Table_Name || ' PARTITION ( '|| vPartName || ' )), second as (select count(*) cnt from ' || pEntry.Partition_Archive_Table_Name || ' PARTITION ( ' || vPartName || ' )) select first.cnt - second.cnt as DIFF from first,second' ;
                    ExecSqlCommandInto(vStmt, pEntry.TABLE_NAME , vRecordDiff) ;

                    IF vRecordDiff = 0 THEN

                        -- Committing previous insert to archive query
                        vStmt := 'alter table ' || TRIM(pEntry.TABLE_NAME) || ' drop partition ' || vPartName || ' update indexes' ;
                        ExecSqlCommand(vStmt,pEntry.TABLE_NAME);

                    ELSE

                        -- Something went wrong and there are differences in record between two tables, rollback previous insert in order to leave all data as they are
                        ROLLBACK ;

                        LogFacility(LOG_SEV_WARNING, 'Table Partition ' || vPartname || ' on table ' || pEntry.TABLE_NAME || ' has not the same record of corresponding partition on archive table name.Rolling back', pEntry.TABLE_NAME);

                         RAISE NOT_SAME_RECORDS ;

                    END IF ;

               */


               EXCEPTION
                  WHEN OTHERS
                  THEN
                     -- Something went wrong
                     ROLLBACK;
                     LogFacility (
                        LOG_SEV_ERROR,
                           'Errore executing Append partition on table '
                        || pEntry.Table_Name
                        || ' Partition: '
                        || vPartName
                        || SQLERRM
                        || ' [Code: '
                        || TO_CHAR (SQLCODE)
                        || '].',
                        pEntry.TABLE_NAME);
                     RAISE;
               END;
            END IF;
         ELSE
            LogFacility (
               LOG_SEV_INFO,
                  'Partition '
               || vPartName
               || ' is the only partition of the table. No archiving of partition will take place',
               pEntry.TABLE_NAME);
         END IF;
      END LOOP;

      LogFacility (LOG_SEV_INFO,
                   'Finished Append Partition',
                   pEntry.TABLE_NAME);
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (
            LOG_SEV_ERROR,
               'Errore executing Append partition on table.'
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            pEntry.TABLE_NAME);
         RAISE;
   END;


   PROCEDURE RenameIntervalPartition (pEntry        MAINT_PARTITIONS%ROWTYPE,
                                      pTableName    VARCHAR2)
   IS
      vSql          VARCHAR2 (4000);
      vParNewName   DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE;
      vHighValue    VARCHAR2 (100);
      vStmt         LONG;


      CURSOR cPartInfoDate
      IS
         SELECT high_value_in_date_format high_value,
partition_name,
                tablespace_name
           FROM (SELECT table_name,
                        table_owner,
partition_name,
                        NVL (
                           TO_DATE (
                              TRIM (
                                 '''' FROM REGEXP_SUBSTR (
                                              EXTRACTVALUE (
                                                 DBMS_XMLGEN.getxmltype (
                                                       'select high_value from all_tab_partitions where table_name='''
                                                    || table_name
                                                    || ''' and table_owner = '''
                                                    || table_owner
                                                    || ''' and partition_name = '''
|| partition_name
                                                    || ''''),
                                                 '//text()'),
                                              '''.*?''')),
                              'SYYYY-MM-DD HH24:MI:SS'),
                           TO_DATE ('9999-01-01', 'YYYY-MM-DD'))
                           high_value_in_date_format,
                        tablespace_name
                   FROM dba_tab_partitions
                  WHERE     UPPER (table_owner || '.' || table_name) =
                               UPPER (pTableName)
                        AND partition_name NOT LIKE
                               pEntry.PARTITION_NAME_PREFIX/* not possible, I rely on partition name for reasoning, it must be correct
                                                           and partition_position < ( select
                                                                                          max(partition_position)
                                                                                      FROM dba_tab_partitions
                                                                                      where upper(table_owner || '.' || table_name) = upper(pTableName) )
                                                                                      */
                );

      CURSOR cPartInfoNotDate
      IS
         SELECT table_name,
                table_owner,
partition_name,
                tablespace_name,
                high_value
           FROM dba_tab_partitions
          WHERE     UPPER (table_owner || '.' || table_name) =
                       UPPER (pTableName)
                AND partition_name NOT LIKE pEntry.PARTITION_NAME_PREFIX;
   /* not possible, I rely on partition name to make my reasoning, it must be correct
   and partition_position < ( select
                                  max(partition_position)
                              FROM dba_tab_partitions
                              where upper(table_owner || '.' || table_name) = upper(pTableName))
                              */

   BEGIN
      LogFacility (
         LOG_SEV_INFO,
         'Starting RenameIntervalPartitions for table : ' || pTableName,
         NULL);

      vStmt :=
            'select data_type from dba_part_key_columns pkc, dba_tab_columns tc where pkc.owner || ''.'' || pkc.name = '''
         || pTableName
         || ''' and pkc.name = tc.table_name and pkc.owner = tc.owner and pkc.column_name = tc.column_name';
      ExecSqlCommandInto (vStmt, pTableName, gPartColumnDatatype);

      IF (   INSTR (gPartColumnDatatype, 'TIMESTAMP') > 0
          OR gPartColumnDatatype = 'DATE')
      THEN
         -- Modify Table Partition names if needed
         FOR rPartInfoDate IN cPartInfoDate
         LOOP
            BEGIN
               IF pEntry.PARTITION_RETENTION_UNIT = 'YYYYMMWK'
               THEN
                  vHighValue :=
                     TO_CHAR (rPartInfoDate.high_value, 'YYYYMMDD');
               ELSE
                  vHighValue :=
                     TO_CHAR (rPartInfoDate.high_value,
                              pEntry.PARTITION_RETENTION_UNIT);
               END IF;

               IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
               THEN
                  vParNewName :=
                     CalculatePartitionName (vHighValue,
                                             pEntry.PARTITION_RETENTION_UNIT,
                                             pEntry.PARTITION_NAME_PREFIX);
               ELSE
                  ExecSqlCommandInto (
                        'SELECT '
                     || pEntry.PARTITION_RETENTION_UNIT
                     || '.GetPartitionNameFromHV('''
                     || pEntry.Table_Name
                     || ''' , '''
                     || vHighValue
                     || ''') FROM DUAL',
                     NULL,
                     vParNewName);
               END IF;

               IF rPartInfoDate.partition_name != vParNewName
               THEN
                  vSql :=
                        'ALTER TABLE '
                     || pTableName
                     || ' RENAME PARTITION '
                     || rPartInfoDate.partition_name
                     || ' TO '
                     || vParNewName;

                  LogFacility (
                     LOG_SEV_INFO,
                        'Renaming table partition '
                     || rPartInfoDate.partition_name
                     || ' executing : '
                     || vSql,
                     NULL);

                  ExecSqlCommand (vSql, pTableName);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  -- If I have errors when renaming the partitions, I continue processing the rest, these renames are not essential
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred during rename of interval partition '
                     || rPartInfoDate.partition_name
                     || ' of table  : '
                     || pTableName
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pTableName);
            END;
         END LOOP;
      ELSE
         -- Modify Table Partition names if needed when type is not a DATE
         FOR rPartInfoNotDate IN cPartInfoNotDate
         LOOP
            BEGIN
               vHighValue :=
                  REGEXP_REPLACE (rPartInfoNotDate.high_value, '''', '');

               IF vHighValue = 'MAXVALUE'
               THEN
                  vHighValue := '99990101';
               END IF;

               vHighValue :=
                  SUBSTR (vHighValue,
                          1,
                          LENGTH (pEntry.PARTITION_RETENTION_UNIT));

               IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
               THEN
                  vParNewName :=
                     CalculatePartitionName (vHighValue,
                                             pEntry.PARTITION_RETENTION_UNIT,
                                             pEntry.PARTITION_NAME_PREFIX);
               ELSE
                  ExecSqlCommandInto (
                        'SELECT '
                     || pEntry.PARTITION_RETENTION_UNIT
                     || '.GetPartitionNameFromHV('''
                     || pEntry.Table_Name
                     || ''' , '''
                     || vHighValue
                     || ''') FROM DUAL',
                     NULL,
                     vParNewName);
               END IF;


               IF rPartInfoNotDate.partition_name != vParNewName
               THEN
                  vSql :=
                        'ALTER TABLE '
                     || pTableName
                     || ' RENAME PARTITION '
                     || rPartInfoNotDate.partition_name
                     || ' TO '
                     || vParNewName;

                  LogFacility (
                     LOG_SEV_INFO,
                        'Renaming table partition '
                     || rPartInfoNotDate.partition_name
                     || ' executing : '
                     || vSql,
                     NULL);

                  ExecSqlCommand (vSql, pTableName);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  -- If I have errors when renaming the partitions, I continue processing the rest, these renames are not essential
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred renaming interval partition '
                     || rPartInfoNotDate.partition_name
                     || ' of table  : '
                     || pTableName
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pTableName);
            END;
         END LOOP;
      END IF;

      LogFacility (
         LOG_SEV_INFO,
         'Finished RenameIntervalPartition for table : ' || pTableName,
         NULL);
   EXCEPTION
      WHEN OTHERS
      THEN
         -- If I have errors when renaming the partitions, I continue processing the rest, these renames are not essential
         LogFacility (
            LOG_SEV_WARNING,
               'An error occurred renaming partition '
            || vParNewName
            || ' of table : '
            || pTableName
            || ' : '
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            pTableName);
   END;


   PROCEDURE RenamePartitions (
      pEntry                  MAINT_PARTITIONS%ROWTYPE,
      pTablePartList   IN OUT pm_partition_list_type,
      pTableName              VARCHAR2)
   IS
      vSql          VARCHAR2 (4000);
      vParNewName   DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE;
      vHighValue    VARCHAR2 (100);
      vStmt         LONG;
      vPartCount    NUMBER;


      CURSOR cPartInfoDate
      IS
         SELECT high_value_in_date_format high_value,
partition_name,
                tablespace_name
           FROM (  SELECT table_name,
                          table_owner,
partition_name,
                          NVL (
                             TO_DATE (
                                TRIM (
                                   '''' FROM REGEXP_SUBSTR (
                                                EXTRACTVALUE (
                                                   DBMS_XMLGEN.getxmltype (
                                                         'select high_value from all_tab_partitions where table_name='''
                                                      || table_name
                                                      || ''' and table_owner = '''
                                                      || table_owner
                                                      || ''' and partition_name = '''
|| partition_name
                                                      || ''''),
                                                   '//text()'),
                                                '''.*?''')),
                                'SYYYY-MM-DD HH24:MI:SS'),
                             TO_DATE ('9999-01-01', 'YYYY-MM-DD'))
                             high_value_in_date_format,
                          tablespace_name
                     FROM dba_tab_partitions
                    WHERE UPPER (table_owner || '.' || table_name) =
                             UPPER (pTableName)
                 /* not possible, I rely on partition name to make my reasoning, it must be correct
                and partition_position < ( select
                                               max(partition_position)
                                           FROM dba_tab_partitions
                where upper(table_owner || '.' || table_name) = upper(pTableName) )
                */
                 ORDER BY high_value_in_date_format ASC) partinto;


      CURSOR cPartInfoNotDate
      IS
           SELECT table_name,
                  table_owner,
partition_name,
                  tablespace_name,
                  high_value
             FROM dba_tab_partitions
            WHERE UPPER (table_owner || '.' || table_name) = UPPER (pTableName)
         /* not possible, I rely on partition name to make my reasoning, it must be correct
          and partition_position < ( select
                                        max(partition_position)
                                     FROM dba_tab_partitions
                                     where upper(table_owner || '.' || table_name) = upper(pTableName) )*/
         ORDER BY partition_name ASC;

      -- I rename all index partitions except the one with the highest partition position to avoid library cache lock
      CURSOR cIndPartNotDate
      IS
         WITH IDX_NAME
              AS (SELECT (index_owner || '.' || index_name) AS index_name,
partition_name,
                         high_value,
                         partition_position
                    FROM dba_ind_partitions
                   WHERE     index_name NOT LIKE 'SYS_IL%'
                         AND index_owner || '.' || index_name IN
                                (SELECT pi.owner || '.' || index_name
                                   FROM dba_part_indexes     pi,
                                        dba_part_key_columns kc,
                                        dba_tab_columns      colmn
                                  WHERE     (pi.owner || '.' || pi.table_name) =
                                               UPPER (pTableName)
                                        AND pi.partitioning_type = 'RANGE'
                                        AND pi.locality = 'LOCAL'
                                        AND kc.owner = pi.owner
                                        AND kc.name = pi.index_name
                                        AND kc.column_name =
                                               colmn.column_name
                                        AND pi.owner = colmn.owner
                                        AND pi.table_name = colmn.table_name)),
              maxpos
              AS (  SELECT mxpos.index_name,
                           MAX (mxpos.partition_position) mx_pos
                      FROM idx_name mxpos
                  GROUP BY index_name)
         SELECT idx.index_name, idx.partition_name, idx.high_value
           FROM idx_name idx, maxpos mp
          WHERE     idx.partition_position < mp.mx_pos
                AND idx.index_name = mp.index_name;

      -- I rename all index partitions except the one with the highest partition position to avoid library cache lock
      CURSOR cIndPartDate
      IS
         WITH IDX_NAME
              AS (SELECT index_name,
                         index_owner,
partition_name,
                         partition_position,
                         NVL (
                            TO_DATE (
                               TRIM (
                                  '''' FROM REGEXP_SUBSTR (
                                               EXTRACTVALUE (
                                                  DBMS_XMLGEN.getxmltype (
                                                        'select high_value from all_ind_partitions where index_name='''
                                                     || index_name
                                                     || ''' and index_owner = '''
                                                     || index_owner
                                                     || ''' and partition_name = '''
|| partition_name
                                                     || ''''),
                                                  '//text()'),
                                               '''.*?''')),
                               'SYYYY-MM-DD HH24:MI:SS'),
                            TO_DATE ('9999-01-01', 'YYYY-MM-DD'))
                            high_value,
                         tablespace_name
                    FROM dba_ind_partitions
                   WHERE index_owner || '.' || index_name IN
                            (SELECT pi.owner || '.' || index_name
                               FROM dba_part_indexes     pi,
                                    dba_part_key_columns kc,
                                    dba_tab_columns      colmn
                              WHERE     (pi.owner || '.' || pi.table_name) =
                                           UPPER (pTableName)
                                    AND pi.partitioning_type = 'RANGE'
                                    AND pi.locality = 'LOCAL'
                                    AND kc.owner = pi.owner
                                    AND kc.name = pi.index_name
                                    AND kc.column_name = colmn.column_name
                                    AND pi.owner = colmn.owner
                                    AND pi.table_name = colmn.table_name
AND ( colmn.data_type = 'DATE'
OR colmn.data_type LIKE
                                               '%TIMESTAMP%')
                                    AND index_name NOT LIKE 'SYS_IL%')),
              maxpos
              AS (  SELECT mxpos.index_owner,
                           mxpos.index_name,
                           MAX (mxpos.partition_position) mx_pos
                      FROM idx_name mxpos
                  GROUP BY mxpos.index_owner, mxpos.index_name)
         SELECT idx.index_owner,
                idx.index_name,
idx.partition_name,
                idx.high_value
           FROM idx_name idx, maxpos mp
          WHERE     idx.partition_position < mp.mx_pos
                AND idx.index_name = mp.index_name
                AND idx.index_owner = mp.index_owner;
   BEGIN
      LogFacility (LOG_SEV_INFO,
                   'Starting RenamePartitions for table : ' || pTableName,
                   NULL);

      vStmt :=
            'select data_type from dba_part_key_columns pkc, dba_tab_columns tc where pkc.owner || ''.'' || pkc.name = '''
         || pTableName
         || ''' and pkc.name = tc.table_name and pkc.owner = tc.owner and pkc.column_name = tc.column_name';
      ExecSqlCommandInto (vStmt, pTableName, gPartColumnDatatype);

      vPartCount := 1;
      pTablePartList.DELETE;


      IF (   INSTR (gPartColumnDatatype, 'TIMESTAMP') > 0
          OR gPartColumnDatatype = 'DATE')
      THEN
         -- Modify Table Partition names if needed
         FOR rPartInfoDate IN cPartInfoDate
         LOOP
            BEGIN
               IF pEntry.PARTITION_RETENTION_UNIT = 'YYYYMMWK'
               THEN
                  vHighValue :=
                     TO_CHAR (rPartInfoDate.high_value, 'YYYYMMDD');
               ELSE
                  vHighValue :=
                     TO_CHAR (rPartInfoDate.high_value,
                              pEntry.PARTITION_RETENTION_UNIT);
               END IF;

               IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
               THEN
                  vParNewName :=
                     CalculatePartitionName (vHighValue,
                                             pEntry.PARTITION_RETENTION_UNIT,
                                             pEntry.PARTITION_NAME_PREFIX);
               ELSE
                  ExecSqlCommandInto (
                        'SELECT '
                     || pEntry.PARTITION_RETENTION_UNIT
                     || '.GetPartitionNameFromHV('''
                     || pEntry.Table_Name
                     || ''' , '''
                     || vHighValue
                     || ''') FROM DUAL',
                     NULL,
                     vParNewName);
               END IF;

               IF rPartInfoDate.partition_name != vParNewName
               THEN
                  vSql :=
                        'ALTER TABLE '
                     || pTableName
                     || ' RENAME PARTITION '
                     || rPartInfoDate.partition_name
                     || ' TO '
                     || vParNewName;
                  LogFacility (
                     LOG_SEV_INFO,
                        'Renaming table partition '
                     || rPartInfoDate.partition_name
                     || ' executing : '
                     || vSql,
                     NULL);
                  ExecSqlCommand (vSql, pTableName);
               END IF;

               pTablePartList.EXTEND;
               pTablePartList (vPartCount) :=
                  pm_part_rec_type (NULL, NULL, NULL);
               pTablePartList (vPartCount).partition_name := vParNewName;
               pTablePartList (vPartCount).partition_high_value := vHighValue;
               pTablePartList (vPartCount).tablespace_name :=
                  rPartInfoDate.tablespace_name;

               vPartCount :=
                  vPartCount + 1;
            EXCEPTION
               WHEN OTHERS
               THEN
                  -- If I have errors when renaming the partitions, I continue processing the rest, these renames are not essential
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred during rename of partition '
                     || rPartInfoDate.partition_name
                     || ' of table  : '
                     || pTableName
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pTableName);
            END;
         END LOOP;

         -- Check for index partition names are consistent with the specified partition names
         FOR rIndPartDate IN cIndPartDate
         LOOP
            BEGIN
               IF pEntry.PARTITION_RETENTION_UNIT = 'YYYYMMWK'
               THEN
                  vHighValue := TO_CHAR (rIndPartDate.high_value, 'YYYYMMDD');
               ELSE
                  vHighValue :=
                     TO_CHAR (rIndPartDate.high_value,
                              pEntry.PARTITION_RETENTION_UNIT);
               END IF;

               IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
               THEN
                  vParNewName :=
                     CalculatePartitionName (vHighValue,
                                             pEntry.PARTITION_RETENTION_UNIT,
                                             pEntry.PARTITION_NAME_PREFIX);
               ELSE
                  ExecSqlCommandInto (
                        'SELECT '
                     || pEntry.PARTITION_RETENTION_UNIT
                     || '.GetPartitionNameFromHV('''
                     || pEntry.Table_Name
                     || ''' , '''
                     || vHighValue
                     || ''') FROM DUAL',
                     NULL,
                     vParNewName);
               END IF;

               IF rIndPartDate.partition_name != vParNewName
               THEN
                  vSql :=
                        'ALTER INDEX '
                     || rIndPartDate.index_owner
                     || '.'
                     || rIndPartDate.index_name
                     || ' RENAME PARTITION '
                     || rIndPartDate.partition_name
                     || ' TO '
                     || vParNewName;
                  LogFacility (
                     LOG_SEV_INFO,
                        'Renaming index partition '
                     || rIndPartDate.partition_name
                     || ' executing : '
                     || vSql,
                     NULL);
                  ExecSqlCommand (vSql, pTableName);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  -- If I have errors when renaming the partitions, I continue processing the rest, these renames are not essential
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred renaming partition '
                     || rIndPartDate.partition_name
                     || ' of index : '
                     || rIndPartDate.index_name
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pTableName);
            END;
         END LOOP;
      ELSE
         -- Modify Table Partition names if needed when type is not a DATE
         FOR rPartInfoNotDate IN cPartInfoNotDate
         LOOP
            BEGIN
               vHighValue :=
                  REGEXP_REPLACE (rPartInfoNotDate.high_value, '''', '');

               IF vHighValue = 'MAXVALUE'
               THEN
                  vHighValue := '99990101';
               END IF;

               IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
               THEN
                  vHighValue :=
                     SUBSTR (vHighValue,
                             1,
                             LENGTH (pEntry.PARTITION_RETENTION_UNIT));
                  vParNewName :=
                     CalculatePartitionName (vHighValue,
                                             pEntry.PARTITION_RETENTION_UNIT,
                                             pEntry.PARTITION_NAME_PREFIX);
               ELSE
                  ExecSqlCommandInto (
                        'SELECT '
                     || pEntry.PARTITION_RETENTION_UNIT
                     || '.GetPartitionNameFromHV('''
                     || pEntry.Table_Name
                     || ''' , '''
                     || vHighValue
                     || ''') FROM DUAL',
                     NULL,
                     vParNewName);
               END IF;


               IF rPartInfoNotDate.partition_name != vParNewName
               THEN
                  vSql :=
                        'ALTER TABLE '
                     || pTableName
                     || ' RENAME PARTITION '
                     || rPartInfoNotDate.partition_name
                     || ' TO '
                     || vParNewName;
                  LogFacility (
                     LOG_SEV_INFO,
                        'Renaming table partition '
                     || rPartInfoNotDate.partition_name
                     || ' executing : '
                     || vSql,
                     NULL);
                  ExecSqlCommand (vSql, pTableName);
               END IF;

               pTablePartList.EXTEND;
               pTablePartList (vPartCount) :=
                  pm_part_rec_type (NULL, NULL, NULL);
               pTablePartList (vPartCount).partition_name :=
                  rPartInfoNotDate.partition_name;
               pTablePartList (vPartCount).partition_high_value := vHighValue;
               pTablePartList (vPartCount).tablespace_name :=
                  rPartInfoNotDate.tablespace_name;

               vPartCount :=
                  vPartCount + 1;
            EXCEPTION
               WHEN OTHERS
               THEN
                  -- If I have errors when renaming the partitions, I continue processing the rest, these renames are not essential
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred renaming partition '
                     || rPartInfoNotDate.partition_name
                     || ' of table  : '
                     || pTableName
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pTableName);
            END;
         END LOOP;

         -- Check for index partition names are consistent with the specified partition names
         FOR rIndPartNotDate IN cIndPartNotDate
         LOOP
            BEGIN
               vHighValue :=
                  REGEXP_REPLACE (rIndPartNotDate.high_value, '''', '');

               IF vHighValue = 'MAXVALUE'
               THEN
                  vHighValue := '99990101';
               END IF;

               vHighValue :=
                  SUBSTR (vHighValue,
                          1,
                          LENGTH (pEntry.PARTITION_RETENTION_UNIT));

               IF IsFunction (pEntry.PARTITION_RETENTION_UNIT) = FALSE
               THEN
                  vParNewName :=
                     CalculatePartitionName (vHighValue,
                                             pEntry.PARTITION_RETENTION_UNIT,
                                             pEntry.PARTITION_NAME_PREFIX);
               ELSE
                  ExecSqlCommandInto (
                        'SELECT '
                     || pEntry.PARTITION_RETENTION_UNIT
                     || '.GetPartitionNameFromHV('''
                     || pEntry.Table_Name
                     || ''' , '''
                     || vHighValue
                     || ''') FROM DUAL',
                     NULL,
                     vParNewName);
               END IF;

               IF rIndPartNotDate.partition_name != vParNewName
               THEN
                  vSql :=
                        'ALTER INDEX '
                     || rIndPartNotDate.index_name
                     || ' RENAME PARTITION '
                     || rIndPartNotDate.partition_name
                     || ' TO '
                     || vParNewName;
                  LogFacility (
                     LOG_SEV_INFO,
                        'Renaming index partition '
                     || rIndPartNotDate.partition_name
                     || ' executing : '
                     || vSql,
                     NULL);
                  ExecSqlCommand (vSql, pTableName);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  -- If I have errors when renaming the partitions, I continue processing the rest, these renames are not essential
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred renaming partition '
                     || rIndPartNotDate.partition_name
                     || ' of index : '
                     || rIndPartNotDate.index_name
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pTableName);
            END;
         END LOOP;
      END IF;

      LogFacility (LOG_SEV_INFO,
                   'Finished RenamePartitions for table : ' || pTableName,
                   NULL);
   EXCEPTION
      WHEN OTHERS
      THEN
         -- If I have errors when renaming the partitions, I continue processing the rest, these renames are not essential
         LogFacility (
            LOG_SEV_WARNING,
               'An error occurred renaming partition '
            || vParNewName
            || ' of table : '
            || pTableName
            || ' : '
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            pTableName);
   END;


   FUNCTION CountPartitions (pTableName DBA_TAB_PARTITIONS.table_name%TYPE)
      RETURN INTEGER
   AS
      vPartionNumber   NUMBER;
   BEGIN
      LogFacility (
         LOG_SEV_DEBUG,
            'Starting checking how many partitions are in table : '
         || pTableName,
         pTableName);

      SELECT COUNT (*)
        INTO vPartionNumber
        FROM dba_tab_partitions
       WHERE (table_owner || '.' || table_name) = pTableName;

      IF vPartionNumber = 1
      THEN
         LogFacility (LOG_SEV_INFO,
                      'Table ' || pTableName || ' has just one partition',
                      pTableName);
      END IF;

      LogFacility (
         LOG_SEV_DEBUG,
            'Finished checking how many partitions are in table : '
         || pTableName
         || ' part#: '
         || vPartionNumber,
         pTableName);

      RETURN vPartionNumber;
   END;


   FUNCTION isIntervalPartitionedTable (
      pTableName    DBA_TABLES.table_name%TYPE)
      RETURN BOOLEAN
   AS
      vIntervalTable   NUMBER;
      vRetVal          BOOLEAN;
   BEGIN
      LogFacility (
         LOG_SEV_DEBUG,
            'Starting checking if table '
         || pTableName
         || ' is a interval partitioned table or not',
         pTableName);

      vRetVal := FALSE;

      SELECT COUNT (*)
        INTO vIntervalTable
        FROM dba_part_tables
       WHERE     (owner || '.' || table_name) = pTableName
             AND interval IS NOT NULL;

      IF vIntervalTable > 0
      THEN
         vRetVal := TRUE;
         LogFacility (
            LOG_SEV_INFO,
            'Table ' || pTableName || ' is an interval partitioned table',
            pTableName);
      END IF;

      LogFacility (
         LOG_SEV_DEBUG,
            'Finished checking if table '
         || pTableName
         || ' is a interval partitioned table or not',
         pTableName);

      RETURN vRetVal;
   END;


   PROCEDURE AddPartitionList (pEntry MAINT_PARTITIONS%ROWTYPE)
   AS
      vPartitionList   pm_partition_list_type := pm_partition_list_type ();
   BEGIN
      -- If this is an interval partitioned table, we do not need to create a new partition as it will be automatically created on first insert
      LogFacility (
         LOG_SEV_INFO,
         'Starting AddPartitionList for table : ' || pEntry.TABLE_NAME,
         pEntry.TABLE_NAME);
      LogFacility (LOG_SEV_INFO,
                   'Partitions will be added to table ' || pEntry.TABLE_NAME,
                   pEntry.TABLE_NAME);

      IF isIntervalPartitionedTable (pEntry.TABLE_NAME)
      THEN
         LogFacility (
            LOG_SEV_INFO,
               'Table '
            || pEntry.TABLE_NAME
            || 'is an interval partitioned table. Partitions will not be added',
            pEntry.TABLE_NAME);
         RETURN;
      ELSE
         LogFacility (
            LOG_SEV_DEBUG,
               'Table '
            || pEntry.TABLE_NAME
            || ' is not an interval partitioned table',
            pEntry.TABLE_NAME);
      END IF;

      vPartitionList := GetPartitionListToAdd (pEntry);

      IF vPartitionList.EXISTS (1)
      THEN
         FOR vPartCount IN 1 .. vPartitionList.COUNT
         LOOP
            BEGIN
               CreatePartition (
                  pEntry.Table_Name,
                  t_partition_work,
                  vPartitionList (vPartCount).partition_name,
                  vPartitionList (vPartCount).tablespace_name,
                  vPartitionList (vPartCount).partition_high_value,
                  pEntry.Partition_Retention_Unit,
                  pEntry.Partition_Name_Prefix,
                  pEntry.Parallel_Degree);
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_ERROR,
                        'Error creating partition '
                     || vPartitionList (vPartCount).partition_name
                     || ' in table : '
                     || pEntry.TABLE_NAME
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pEntry.TABLE_NAME);
                  RAISE;
            END;
         END LOOP;
      ELSE
         LogFacility (
            LOG_SEV_INFO,
            'No new partitions are needed in table ' || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
      END IF;

      LogFacility (
         LOG_SEV_INFO,
         'Finished AddPartitionList for table : ' || pEntry.TABLE_NAME,
         pEntry.TABLE_NAME);
   END;



   PROCEDURE DropPartitionList (pEntry MAINT_PARTITIONS%ROWTYPE)
   AS
      vStmt             LONG;
      comandi_disable   pm_constraint_list_type := pm_constraint_list_type (); -- comandi disable per tutte le fk entranti
      comandi_enable    pm_constraint_list_type := pm_constraint_list_type (); -- comandi enable novalidate per tutte le fk entranti
      vPartitionList    pm_partition_list_type := pm_partition_list_type ();
      vNewPartName      DBA_TAB_PARTITIONS.PARTITION_NAME%TYPE;
   BEGIN
      LogFacility (
         LOG_SEV_INFO,
         'Starting Dropping partitions for table : ' || pEntry.TABLE_NAME,
         pEntry.TABLE_NAME);

      vPartitionList := GetPartitionListToRemove (pEntry);

      IF vPartitionList.EXISTS (1)
      THEN
         FOR x
            IN (SELECT child.owner || '.' || child.table_name fktable,
                       child.constraint_name                  fk
                  FROM dba_constraints child, dba_constraints parent
                 WHERE     child.CONSTRAINT_TYPE = 'R'
                       AND child.STATUS = 'ENABLED'
                       AND child.r_owner = parent.owner
                       AND child.r_constraint_name = parent.constraint_name
                       AND parent.OWNER || '.' || parent.table_name =
                              UPPER (pEntry.TABLE_NAME))
         LOOP
            LogFacility (
               LOG_SEV_INFO,
                  'Constraint '
               || x.fk
               || ' on table : '
               || pEntry.TABLE_NAME
               || ' will be disabled',
               pEntry.TABLE_NAME);

commands_disable.EXTEND;
commands_enable.EXTEND;
commands_disable (comands_disable.COUNT) :=
               'alter table ' || x.fktable || ' disable constraint ' || x.fk;
commands_enable (commands_enable.COUNT) :=
                  'alter table '
               || x.fktable
               || ' enable novalidate constraint '
               || x.fk;
         END LOOP;

         -- 20121108 esegui disable
FOR vCmdCount IN 1 .. commands_disable.COUNT
         LOOP
            BEGIN
               LogFacility (LOG_SEV_INFO,
commands_disable (vCmdCount),
                            pEntry.TABLE_NAME);
               ExecSqlCommand (comandi_disable (vCmdCount),
                               pEntry.TABLE_NAME);
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred during '
|| commands_disable (vCmdCount)
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pEntry.TABLE_NAME);
            END;
         END LOOP;

         -- Drop Partitions out of retention period
         FOR vCmdCount IN 1 .. vPartitionList.COUNT
         LOOP
            BEGIN
               vNewPartName := vPartitionList (vCmdCount).partition_name;
               LogFacility (
                  LOG_SEV_INFO,
                     'Start dropping partition : '
                  || vNewPartName
                  || '" on table '
                  || pEntry.TABLE_NAME,
                  pEntry.TABLE_NAME);

               IF (CountPartitions (pEntry.TABLE_NAME) > 1)
               THEN
                  IF B_DATAEXPORT_ENABLED = 1
                  THEN
                     IF (IsPartitionEmpty (pEntry.Table_Name, vNewPartName) =
                            1)
                     THEN
                        LogFacility (
                           LOG_SEV_INFO,
                              'Partition : '
                           || vNewPartName
                           || ' in table '
                           || pEntry.TABLE_NAME
                           || ' is empty and will not be exported',
                           pEntry.TABLE_NAME);
                     ELSE
                        ExportPartition (pEntry.Table_Name,
                                         vNewPartName,
                                         pEntry.Expdp_Directory);
                     END IF;
                  END IF;

                  vStmt :=
                        'alter table '
                     || TRIM (pEntry.TABLE_NAME)
                     || ' drop partition '
                     || vNewPartName
                     || ' update indexes';
                  ExecSqlCommand (vStmt, pEntry.TABLE_NAME);
               ELSE
                  LogFacility (
                     LOG_SEV_INFO,
                        'The partition: '
                     || vNewPartName
                     || ' is the only one partition of the table : '
                     || pEntry.TABLE_NAME
                     || '. Cannot drop it !',
                     pEntry.TABLE_NAME);
               END IF;

               LogFacility (
                  LOG_SEV_INFO,
                  'Finished dropping partition : ' || vNewPartName || '"',
                  pEntry.TABLE_NAME);
            EXCEPTION
               WHEN LAST_RANGE_PART
               THEN
                  LogFacility (
                     LOG_SEV_INFO,
                        'The partition '
                     || vNewPartName
                     || ' of table '
                     || pEntry.TABLE_NAME
                     || ' is the last range partition of the table. Need further checks if this partition needs to be removed manually',
                     pEntry.TABLE_NAME);
                  LogFacility (
                     LOG_SEV_INFO,
                        'The partition '
                     || vNewPartName
                     || ' of table '
                     || pEntry.TABLE_NAME
                     || ' will be truncated instead of being dropped',
                     pEntry.TABLE_NAME);

                  -- Checking if partition is not empty. It need to be truncated insteadof beeing dropped as this is the last range partition of the table
                  IF (IsPartitionEmpty (pEntry.TABLE_NAME, vNewPartName) = 11)
                  THEN
                     vStmt :=
                           'alter table '
                        || TRIM (pEntry.TABLE_NAME)
                        || ' truncate partition '
                        || vNewPartName
                        || ' update indexes';
                     ExecSqlCommand (vStmt, pEntry.TABLE_NAME);
                  END IF;
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_ERROR,
                        'An error occurred during drop of partition '
                     || vNewPartName
                     || ' of table '
                     || pEntry.TABLE_NAME
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pEntry.TABLE_NAME);
                  RAISE;
            END;
         END LOOP;

         -- 20121108 esegui enable
         FOR vCmdCount IN 1 .. comandi_enable.COUNT
         LOOP
            BEGIN
               LogFacility (LOG_SEV_INFO,
commands_enable (vCmdCount),
                            pEntry.TABLE_NAME);
               ExecSqlCommand (comandi_enable (vCmdCount), pEntry.TABLE_NAME);
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred during '
|| commands_enable (vCmdCount)
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pEntry.TABLE_NAME);
            END;
         END LOOP;
      ELSE
         LogFacility (
            LOG_SEV_INFO,
               'No need to remove further partitions from this table '
            || pEntry.TABLE_NAME,
            pEntry.TABLE_NAME);
      END IF;

      LogFacility (
         LOG_SEV_INFO,
         'Finished dropping partitions for table : ' || pEntry.TABLE_NAME,
         pEntry.TABLE_NAME);
   END;


   FUNCTION IsIndexPartitionUnusable (pTableName    VARCHAR2,
                                      pPartName     VARCHAR2)
      RETURN BOOLEAN
   IS
      v_is_index_unsable   INTEGER;
      vRetVal              BOOLEAN;
   BEGIN
      SELECT COUNT (1)
        INTO v_is_index_unsable
        FROM dba_ind_partitions
       WHERE     index_name IN
                    (SELECT index_name
                       FROM dba_indexes
                      WHERE owner || '.' || table_name = pTableName)
AND partition_name = pPartName
             AND status <> 'USABLE';

      IF v_is_index_unsable > 0
      THEN
         vRetVal := TRUE;
      ELSE
         vRetVal := FALSE;
      END IF;

      RETURN vRetVal;
   END;


   FUNCTION IsIndexSubPartitionUnusable (pTableName    VARCHAR2,
                                         pPartName     VARCHAR2)
      RETURN BOOLEAN
   IS
      v_is_index_unsable   INTEGER;
      vRetVal              BOOLEAN;
   BEGIN
      SELECT COUNT (1)
        INTO v_is_index_unsable
        FROM dba_ind_subpartitions
       WHERE     index_name IN
                    (SELECT index_name
                       FROM dba_indexes
                      WHERE owner || '.' || table_name = pTableName)
AND partition_name = pPartName
             AND status <> 'USABLE';

      IF v_is_index_unsable > 0
      THEN
         vRetVal := TRUE;
      ELSE
         vRetVal := FALSE;
      END IF;

      RETURN vRetVal;
   END;

   FUNCTION IsTableEmpty (pTavola VARCHAR2)
      RETURN NUMBER
   IS
      /*

       return 1 if a /regardless if it is partitoned or not) table is empty
              0 if it contains data

      */
vcount NUMBER (10);
      vsql     VARCHAR2 (1000);
   BEGIN
      vsql := 'select count(1) from ' || pTavola || ' where rownum < 2';
ExecSqlCommandInto(vsql, pTable, vcount);

IF vaccount > 0
      THEN
         -- the table contains data
         LogFacility (
            LOG_SEV_DEBUG,
            'IsTableEmpty return 0 for not empty table : ' || pTavola,
            pTavola);
         RETURN 0;
      END IF;

      LogFacility (LOG_SEV_DEBUG,
                   'IsTableEmpty return 1 for empty table : ' || pTavola,
                   pTavola);
      RETURN 1;
   END;


   FUNCTION IsPartitionEmpty (pTavola VARCHAR2, pPartiz VARCHAR2)
      RETURN NUMBER
   IS
      /*
         returns: 0 if the table does not exist
                   1 if the partition is empty
                   2 if the table exists and is not partitioned
                  10 if the partition does not exist
                  11 if the partition exists and is not empty

                  99 if unexpected error
      */
vcount NUMBER (10);
      vsql     VARCHAR2 (1000);
   BEGIN
      LogFacility (LOG_SEV_DEBUG,
                   'Starting IsPartitionEmpty for table : ' || pTavola,
                   pTavola);

      vsql :=
            'SELECT COUNT(1) FROM dba_tables WHERE ( owner || ''.'' || table_name ) = UPPER('''
         || pTavola
         || ''')';
ExecSqlCommandInto(vsql, pTable, vcount);

IF vaccount = 0
      THEN
         -- la tavola non esiste
         LogFacility (LOG_SEV_DEBUG,
                      'IsPartitionEmpty return 0 for table : ' || pTavola,
                      pTavola);
         RETURN 0;
      END IF;

      vsql :=
            'SELECT COUNT(1) FROM dba_tables WHERE ( owner || ''.'' || table_name ) = UPPER('''
         || pTavola
         || ''') AND PARTITIONED=''YES''';
ExecSqlCommandInto(vsql, pTable, vcount);

IF vaccount = 0
      THEN
         --the table exists but is not partitioned
         LogFacility (LOG_SEV_DEBUG,
                      'IsPartitionEmpty return 2 for table : ' || pTavola,
                      pTavola);
         RETURN 2;
      END IF;


      vsql :=
            'SELECT COUNT(1) FROM dba_tab_partitions WHERE ( table_owner || ''.'' || table_name ) = UPPER('''
         || pTavola
         || ''') AND partition_name=UPPER('''
         || pPartiz
         || ''')';
ExecSqlCommandInto(vsql, pTable, vcount);

IF vaccount = 0
      THEN
         --the partition does not exist
         LogFacility (LOG_SEV_DEBUG,
                      'IsPartitionEmpty return 10 for table : ' || pTavola,
                      pTavola);
         RETURN 10;
      END IF;

      vsql :=
            'select count(1) from '
         || pTavola
         || ' partition ('
         || pPartiz
         || ') where rownum <= 1';
ExecSqlCommandInto(vsql, pTable, vcount);

IF vaccount = 0
      THEN
         --the partition is empty
         LogFacility (LOG_SEV_DEBUG,
                      'IsPartitionEmpty return 1 for table : ' || pTavola,
                      pTavola);
         RETURN 1;
      ELSE
         --the partition is not empty
         LogFacility (LOG_SEV_DEBUG,
                      'IsPartitionEmpty return 11 for table : ' || pTavola,
                      pTavola);
         RETURN 11;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN 99;
   END;


   PROCEDURE DropEmptyPartition (
      pTable    DBA_TAB_PARTITIONS.table_name%TYPE,
      pName     DBA_TAB_PARTITIONS.partition_name%TYPE)
   AS
      vStmt   LONG;
   BEGIN
      -- This procedure remove the partition only if it's empty ( after a exchange )
      LogFacility (
         LOG_SEV_INFO,
         'Start DropEmptyPartition for partition "' || pName || '" ...',
         pTable);

      -- Check if table partition to drop is empty

      IF (IsPartitionEmpty (pTable, pName) = 1)
      THEN
         BEGIN
            vStmt :=
                  'alter table '
               || TRIM (pTable)
               || ' drop partition '
               || pName
               || ' update indexes';
            LogFacility (LOG_SEV_INFO,
                         'Executing drop partition : ' || vStmt,
                         pTable);

            ExecSqlCommand (vStmt, pTable);

            LogFacility (LOG_SEV_INFO,
                         'Dropped partition :' || pName,
                         pTable);
         EXCEPTION
            WHEN LAST_RANGE_PART
            THEN
               LogFacility (
                  LOG_SEV_INFO,
                     'The partition '
                  || pName
                  || ' of table '
                  || pTable
                  || ' is the last range partition of the table. Need further checks if this partition needs to be remove manually',
                  pTable);
         END;
      ELSE
         LogFacility (
            LOG_SEV_WARNING,
               'Partition '
            || pName
            || ' of table '
            || pTable
            || ' is not empty',
            pTable);
      END IF;

      LogFacility (
         LOG_SEV_INFO,
         'Finished DropEmptyPartition for partition "' || pName || '"',
         pTable);
   END;

   PROCEDURE CompressPartitionList (pEntry MAINT_PARTITIONS%ROWTYPE)
   AS
      vPartitionList   pm_partition_list_type := pm_partition_list_type ();
      vSubPartTable    BOOLEAN;
   BEGIN
      vPartitionList := GetPartitionListToCompress (pEntry);

      LogFacility (LOG_SEV_INFO,
                   'Starting Compress Partition ',
                   pEntry.Table_Name);

      IF vPartitionList.EXISTS (1)
      THEN
         vSubPartTable := IsTableSubPartitioned (pEntry.Table_Name);

         FOR vCmdCount IN 1 .. vPartitionList.COUNT
         LOOP
            BEGIN
               IF vSubPartTable = FALSE
               THEN
                  CompressPartition (
                     pEntry.table_name,
                     vPartitionList (vCmdCount).partition_name,
                     pEntry.parallel_degree,
                     pEntry.Partition_Compress_Type,
                     pEntry.Partition_Archive_Tablespace);
               ELSE
                  CompressSubPartition (
                     pEntry.table_name,
                     vPartitionList (vCmdCount).partition_name,
                     pEntry.parallel_degree,
                     pEntry.Partition_Compress_Type,
                     pEntry.Partition_Archive_Tablespace);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_WARNING,
                        'Error during compression of partition : '
                     || vPartitionList (vCmdCount).partition_name
                     || ' of table '
                     || pEntry.TABLE_NAME
                     || ' '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pEntry.TABLE_NAME);
            END;
         END LOOP;
      END IF;

      LogFacility (LOG_SEV_INFO,
                   'Finished Compress Partition ',
                   pEntry.Table_Name);
   END;

   FUNCTION CanBeOnline (pOperation VARCHAR2)
      RETURN VARCHAR2
   IS
      V_DBVER      NUMBER := 0;
      V_ISONLINE   VARCHAR2 (20) := ' ';
   BEGIN
      -- We can only use the online clause for versions higher than (and not including) 11.2

      SELECT REPLACE (version, '.', '')
        INTO V_DBVER
        FROM PRODUCT_COMPONENT_VERSION
       WHERE PRODUCT LIKE 'Oracle Database%';

      -- Online move of a partition is implemented only on 12.1 or above
      IF pOperation = 'MOVE'
      THEN
         IF V_DBVER > 112040
         THEN
            V_ISONLINE := ' ONLINE';
         ELSE
            V_ISONLINE := ' ';
         END IF;
      ELSIF pOperation = 'SPLIT'
      THEN
         IF V_DBVER > 121020
         THEN
            V_ISONLINE := ' ONLINE';
         ELSE
            V_ISONLINE := ' UPDATE INDEXES ';
         END IF;
      END IF;

      RETURN V_ISONLINE;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN '';
   END;

   PROCEDURE CompressPartition (
      pTable             DBA_TAB_PARTITIONS.table_name%TYPE,
      pName              DBA_TAB_PARTITIONS.partition_name%TYPE,
      pDegree            NUMBER,
      pCompressType      VARCHAR2,
      pTablespaceName    DBA_TAB_PARTITIONS.tablespace_name%TYPE)
   AS
      vStmt             LONG;
      vTablespaceName   DBA_TAB_PARTITIONS.tablespace_name%TYPE;
   BEGIN
      -- This procedure remove the partition only if it's empty ( after a exchange )
      LogFacility (
         LOG_SEV_INFO,
            'Start compression of partition : "'
         || pName
         || '" on table '
         || pTable,
         pTable);

      IF pTablespaceName IS NOT NULL
      THEN
         vTablespaceName := ' tablespace ' || pTablespaceName;
      ELSE
         vTablespaceName := ' ';
      END IF;


      IF pName IS NOT NULL
      THEN
         SELECT    'alter table '
                || TRIM (pTable)
                || ' move partition '
                || pName
                || ' compress '
                || DECODE (pCompressType,
                           'ARCHIVE LOW', 'FOR ',
                           'ARCHIVE HIGH', 'FOR ',
                           'QUERY HIGH', 'FOR ',
                           'QUERY LOW', 'FOR ',
                           'OLTP', 'FOR ',
                           pCompressType)
                || pCompressType
                || vTablespaceName
                || ' update indexes parallel '
                || pDegree
                || CanBeOnline ('MOVE')
           INTO vStmt
           FROM DUAL;

         ExecSqlCommand (vStmt, pTable);

         IF IsIndexPartitionUnusable (pTable, pName) = TRUE
         THEN
            /*
                -- The safeguard rebuild is done below in NOT online mode, so I replace it with a built rebuild
                -- This is a safeguard rebuild, it should never be performed
                LogFacility(LOG_SEV_INFO, 'After compression of partition : ' || pName || ' some indexes were found unusable. Rebuilding...' , pTable);

                vStmt := 'alter table ' || TRIM(pTable) || ' modify partition ' || pName || ' rebuild unusable local indexes ' ;
                ExecSqlCommand(vStmt,pTable);

                LogFacility(LOG_SEV_INFO, 'Indexes rebuiled' , pTable);

             */

            LogFacility (
               LOG_SEV_INFO,
                  'Some partition of index in table '
               || pTable
               || ' were found invalid, rebuilding them all',
               pTable);

            FOR rPartToRebuild
               IN (SELECT    'ALTER INDEX '
                          || INDEX_OWNER
                          || '.'
                          || INDEX_NAME
                          || ' REBUILD PARTITION '
                          || PARTITION_NAME
                          || ' PARALLEL '
                          || pDegree
                          || ' ONLINE'
                             vStmt
                     FROM dba_ind_partitions
                    WHERE     status = 'UNUSABLE'
                          AND subpartition_count = 0
                          AND index_name IN (SELECT index_name
                                               FROM dba_indexes
                                              WHERE    owner
                                                    || '.'
                                                    || table_name = pTable))
            LOOP
               --This is a safeguard rebuild, it should never be performed
               ExecSqlCommand (vStmt, pTable);
            END LOOP;

            LogFacility (LOG_SEV_INFO,
                         'Finished rebuilding partition indexes',
                         pTable);
         END IF;

         LogFacility (
            LOG_SEV_INFO,
               'Finished compression of partition : "'
            || pName
            || '" on table '
            || pTable,
            pTable);
      ELSE
         -- This is the case when the table is not partitioned or supposed to be. In this case we move entire table and rebuild associated indexes
         LogFacility (
            LOG_SEV_DEBUG,
               'Starting compress table : '
            || pTable
            || ' in tablespace : '
            || pTablespaceName,
            pTable);

         -- this can happen not online because this is an exchange table
         vStmt :=
               'alter table '
            || TRIM (pTable)
            || ' move compress '
            || pCompressType
            || vTablespaceName
|| 'parallel'
            || pDegree
            || CanBeOnline ('MOVE');
         ExecSqlCommand (vStmt, pTable);

         -- In the versions currently present on Nexi, we can afford to rebuild the indexes online
         FOR rCurIndex
            IN (SELECT    'ALTER INDEX '
                       || OWNER
                       || '.'
                       || INDEX_NAME
                       || ' REBUILD '
                       || vTablespaceName
                       || ' ONLINE'
                          AS CMD
                  FROM DBA_INDEXES
                 WHERE OWNER || '.' || TABLE_NAME = pTable)
         LOOP
            BEGIN
               IF LENGTH (rCurIndex.cmd) > 0
               THEN
                  ExecSqlCommand (rCurIndex.cmd, pTable);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_ERROR,
                        'Error during indexe rebuild command :'
                     || rCurIndex.cmd
                     || ' with error : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pTable);
            END;
         END LOOP;
      END IF;
   END;


   PROCEDURE CompressSubPartition (
      pTable             DBA_TAB_PARTITIONS.table_name%TYPE,
      pName              DBA_TAB_PARTITIONS.partition_name%TYPE,
      pDegree            NUMBER,
      pCompressType      VARCHAR2,
      pTablespaceName    DBA_TAB_PARTITIONS.tablespace_name%TYPE)
   AS
      vStmt             LONG;
      vTablespaceName   DBA_TAB_PARTITIONS.tablespace_name%TYPE;

      CURSOR vSubPart (
         vTableName    VARCHAR2,
         vPartName     VARCHAR2)
      IS
           SELECT TABLE_OWNER,
                  TABLE_NAME,
                  PARTITION_NAME,
                  SUBPARTITION_NAME
             FROM DBA_TAB_SUBPARTITIONS
            WHERE     TABLE_OWNER || '.' || TABLE_NAME = vTableName
                  AND PARTITION_NAME = vPartName
         ORDER BY SUBPARTITION_POSITION;
   BEGIN
      -- This procedure remove the partition only if it's empty ( after a exchange )
      LogFacility (
         LOG_SEV_INFO,
            'Start compression of subpartitions of partition : "'
         || pName
         || '" on table '
         || pTable,
         pTable);

      IF pTablespaceName IS NOT NULL
      THEN
         vTablespaceName := ' tablespace ' || pTablespaceName;
      ELSE
         vTablespaceName := ' ';
      END IF;


      IF pName IS NOT NULL
      THEN
         FOR cSubPart IN vSubPart (pTable, pName)
         LOOP
            LogFacility (
               LOG_SEV_INFO,
                  'Start compression of subpartition '
               || cSubPart.subpartition_name
               || ' of partition '
               || pName,
               pTable);

            SELECT    'alter table '
                   || TRIM (pTable)
                   || ' move subpartition '
                   || cSubPart.subpartition_name
                   || ' compress '
                   || DECODE (pCompressType,
                              'ARCHIVE LOW', 'FOR ',
                              'ARCHIVE HIGH', 'FOR ',
                              'QUERY HIGH', 'FOR ',
                              'QUERY LOW', 'FOR ',
                              'OLTP', 'FOR ',
                              pCompressType)
                   || pCompressType
                   || vTablespaceName
                   || ' update indexes parallel '
                   || pDegree
                   || CanBeOnline ('MOVE')
              INTO vStmt
              FROM DUAL;

            ExecSqlCommand (vStmt, pTable);

            IF IsIndexSubPartitionUnusable (pTable, pName) = TRUE
            THEN
               LogFacility (
                  LOG_SEV_INFO,
                  'Some subpartition indexes were found invalid, rebuilding them all',
                  pTable);

               FOR rSubpartToRebuild
                  IN (SELECT    'ALTER INDEX '
                             || INDEX_OWNER
                             || '.'
                             || INDEX_NAME
                             || ' REBUILD SUBPARTITION '
                             || SUBPARTITION_NAME
                             || ' PARALLEL 4 ONLINE'
                                vStmt
                        FROM dba_ind_subpartitions
                       WHERE     status = 'UNUSABLE'
                             AND index_name IN
                                    (SELECT index_name
                                       FROM dba_indexes
                                      WHERE    owner
                                            || '.'
                                            || table_name = pTable))
               LOOP
                  --This is a safeguard rebuild, it should never be performed
                  ExecSqlCommand (vStmt, pTable);
               END LOOP;

               LogFacility (LOG_SEV_INFO,
                            'Finished rebuilding subpartition indexes',
                            pTable);
            END IF;

            LogFacility (
               LOG_SEV_INFO,
                  'Finished compression of subpartition '
               || cSubPart.subpartition_name
               || ' of partition '
               || pName,
               pTable);
         END LOOP;
      END IF;

      LogFacility (
         LOG_SEV_INFO,
            'Finished compression of subpartitions of partition : "'
         || pName
         || '" on table '
         || pTable,
         pTable);
   END;



   PROCEDURE MovePartitionTablespace (
      pTable             DBA_TAB_PARTITIONS.table_name%TYPE,
      pPartName          DBA_TAB_PARTITIONS.partition_name%TYPE,
      pDegree            NUMBER,
      pTablespaceName    DBA_TAB_PARTITIONS.tablespace_name%TYPE)
   AS
      vStmt   LONG;
   BEGIN
      IF pPartName IS NOT NULL
      THEN
         -- This procedure remove the partition only if it's empty ( after a exchange )
         LogFacility (
            LOG_SEV_INFO,
               'Starting move of partition : '
            || pPartName
            || ' in tablespace : '
            || pTablespaceName,
            pTable);

         vStmt :=
               'alter table '
            || TRIM (pTable)
            || ' move partition '
            || pPartName
            || ' tablespace '
            || pTablespaceName
            || ' update indexes parallel '
            || pDegree
            || CanBeOnline ('MOVE');
         ExecSqlCommand (vStmt, pTable);

         IF IsIndexPartitionUnusable (pTable, pPartName) = TRUE
         THEN
            vStmt :=
                  'alter table '
               || TRIM (pTable)
|| 'modify partition'
               || pPartName
               || ' rebuild unusable local indexes';
            ExecSqlCommand (vStmt, pTable);
         END IF;

         LogFacility (
            LOG_SEV_INFO,
               'Finished move of partition : '
            || pPartName
            || ' in tablespace : '
            || pTablespaceName,
            pTable);
      ELSE
         -- This is the case when the table is not partitioned or supposed to be. In this case we move entire table and rebuild associated indexes
         LogFacility (
            LOG_SEV_INFO,
               'Starting move table : '
            || pPartName
            || ' in tablespace : '
            || pTablespaceName,
            pTable);

         -- this can happen not online because this is an exchange table
         vStmt :=
               'alter table '
            || TRIM (pTable)
            || ' move tablespace '
            || pTablespaceName
|| 'parallel'
            || pDegree;
         ExecSqlCommand (vStmt, pTable);

         FOR rCurIndex
            IN (SELECT    'ALTER INDEX '
                       || OWNER
                       || '.'
                       || INDEX_NAME
                       || ' REBUILD TABLESPACE '
                       || pTablespaceName
                          AS CMD
                  FROM DBA_INDEXES
                 WHERE     OWNER || '.' || TABLE_NAME = pTable
                       AND index_name NOT IN (SELECT INDEX_NAME
                                                FROM dba_lobs
                                               WHERE    OWNER
                                                     || '.'
                                                     || TABLE_NAME = pTable))
         LOOP
            BEGIN
               IF LENGTH (rCurIndex.cmd) > 0
               THEN
                  ExecSqlCommand (rCurIndex.cmd, pTable);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_ERROR,
                        'Error during index rebuild command :'
                     || rCurIndex.cmd
                     || ' con errore : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pTable);
            END;
         END LOOP;

         LogFacility (
            LOG_SEV_INFO,
               'Finished move of table : '
            || pPartName
            || ' in tablespace : '
            || pTablespaceName,
            pTable);
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (
            LOG_SEV_ERROR,
               'Error during move on Table : '
            || pTable
            || ' Partition : '
            || pPartName
            || ' '
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            pTable);
         RAISE;
   END;


   FUNCTION CheckTableProperties (
      pTableName    DBA_TAB_PARTITIONS.table_name%TYPE)
      RETURN BOOLEAN
   AS
      vStmt                 LONG;
      vTablespaceName       DBA_TAB_PARTITIONS.tablespace_name%TYPE;
      vIsRangePartitioned   INTEGER;
      vColumnType           VARCHAR2 (100);
      vRetVal               BOOLEAN;
   BEGIN
      vRetVal := TRUE;

      -- This procedure remove the partition only if it's empty ( after a exchange )
      LogFacility (
         LOG_SEV_INFO,
         'Starting Check that table is partitioned and partitioned by range',
         pTableName);

      LogFacility (LOG_SEV_DEBUG,
                   'Starting Check that table is partitioned ',
                   pTableName);

      -- Check if Table_Name exists
      IF (       B_ARCHIVE_WITH_QUERY = 0
             AND IsPartitionEmpty (pTableName, 'DUMMYPARTNAME') != 10
          OR (    IsPartitionEmpty (pTableName, 'DUMMYPARTNAME') = 0
              AND B_ARCHIVE_WITH_QUERY = 1))
      THEN
         LogFacility (
            LOG_SEV_INFO,
               'Table '
            || pTableName
            || ' does not exist or is not partitioned. Cannot continue processing',
            pTableName);
         vRetVal := FALSE;
      ELSE
         -- We're only interested in checking if I'm not storing the data with a query. in that case the table can be of any type, partitioned or not.
         IF B_ARCHIVE_WITH_QUERY = 0
         THEN
            LogFacility (LOG_SEV_INFO, 'Table is partitioned ', pTableName);

            LogFacility (LOG_SEV_INFO,
                         'Starting Check that table is RANGE partitioned ',
                         pTableName);

            vStmt :=
                  'select decode ( PARTITIONING_TYPE,''RANGE'',1,0) as IS_RANGE_PARTIONED from dba_part_tables where owner || ''.'' || table_name = '''
               || pTableName
               || '''';
            ExecSqlCommandInto (vStmt, pTableName, vIsRangePartitioned);

            IF vIsRangePartitioned = 0
            THEN
               LogFacility (
                  LOG_SEV_ERROR,
                     'Table '
                  || pTableName
                  || ' is not a range partitioned table. Other table types are not allowed to be managed by this package.',
                  pTableName);
               vRetVal := FALSE;
            END IF;

            LogFacility (
               LOG_SEV_INFO,
               'Finished checking that table is RANGE partitioned ',
               pTableName);
         END IF;
      END IF;

      LogFacility (
         LOG_SEV_INFO,
         'End Check that table is partitioned and partitioned by range',
         pTableName);
      RETURN vRetVal;
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (
            LOG_SEV_WARNING,
               'Error executing checks on table.'
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            pTableName);
   END;



   PROCEDURE ExchangePartitionList (pEntry MAINT_PARTITIONS%ROWTYPE)
   AS
      vPartitionList        pm_partition_list_type := pm_partition_list_type ();
      vPartName             DBA_TAB_PARTITIONS.partition_name%TYPE;
      vPartTablespaceName   DBA_TAB_PARTITIONS.tablespace_name%TYPE;
      vPartDate             VARCHAR (100);
      vPartString           VARCHAR2 (100);
      comandi_disable       pm_constraint_list_type
                               := pm_constraint_list_type (); -- comandi disable per tutte le fk entranti
      comandi_enable        pm_constraint_list_type
                               := pm_constraint_list_type (); -- comandi enable novalidate per tutte le fk entranti
   BEGIN
      vPartitionList := GetPartitionListToRemove (pEntry);

      LogFacility (LOG_SEV_INFO,
                   'Starting Exchange Partition',
                   pEntry.TABLE_NAME);

      IF vPartitionList.EXISTS (1)
      THEN
         FOR x
            IN (SELECT child.owner || '.' || child.table_name fktable,
                       child.constraint_name                  fk
                  FROM dba_constraints child, dba_constraints parent
                 WHERE     child.CONSTRAINT_TYPE = 'R'
                       AND child.STATUS = 'ENABLED'
                       AND child.r_owner = parent.owner
                       AND child.r_constraint_name = parent.constraint_name
                       AND parent.OWNER || '.' || parent.table_name =
                              UPPER (pEntry.TABLE_NAME))
         LOOP
            LogFacility (
               LOG_SEV_INFO,
                  'Constraint '
               || x.fk
               || ' on table : '
               || pEntry.TABLE_NAME
               || ' will be disabled',
               pEntry.TABLE_NAME);

commands_disable.EXTEND;
commands_enable.EXTEND;
commands_disable (comands_disable.COUNT) :=
               'alter table ' || x.fktable || ' disable constraint ' || x.fk;
commands_enable (commands_enable.COUNT) :=
                  'alter table '
               || x.fktable
               || ' enable novalidate constraint '
               || x.fk;
         END LOOP;

         -- 20121108 esegui disable
FOR vCmdCount IN 1 .. commands_disable.COUNT
         LOOP
            BEGIN
               LogFacility (LOG_SEV_INFO,
commands_disable (vCmdCount),
                            pEntry.TABLE_NAME);
               ExecSqlCommand (comandi_disable (vCmdCount),
                               pEntry.TABLE_NAME);
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_WARNING,
                        'An error occurred during '
|| commands_disable (vCmdCount)
                     || ' : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pEntry.TABLE_NAME);
            END;
         END LOOP;
      END IF;

      FOR vCmdCount IN 1 .. vPartitionList.COUNT
      LOOP
         vPartName := vPartitionList (vCmdCount).partition_name;
         vPartDate := vPartitionList (vCmdCount).partition_high_value;
         vPartTablespaceName := vPartitionList (vCmdCount).tablespace_name;

         IF (CountPartitions (pEntry.TABLE_NAME) > 1)
         THEN
            IF PartitionExists (pEntry.Table_Name, vPartName)
            THEN
               LogFacility (
                  LOG_SEV_INFO,
                     'Exchanging partition : '
                  || vPartName
                  || ' from '
                  || TRIM (pEntry.Table_Name)
                  || ' to '
                  || pEntry.Partition_Exchange_Table_Name,
                  pEntry.TABLE_NAME);

               -- If table used to exchange is not empty , do not proceed with other actions
               IF (IsTableEmpty (pEntry.Partition_Exchange_Table_Name) = 0)
               THEN
                  LogFacility (
                     LOG_SEV_ERROR,
                        'Exchange Table configured : '
                     || pEntry.Partition_Exchange_Table_Name
                     || ' is not empty or does not exist. Please check if an error occurred and why this table is not empty. No further actions will be performed on this table to prevent data loss',
                     pEntry.TABLE_NAME);
                  RAISE_APPLICATION_ERROR (
                     -20000,
                        'Exchange Table configured : '
                     || pEntry.Partition_Exchange_Table_Name
                     || ' is not empty or does not exist. Please check if an error occurred and why this table is not empty. No further actions will be performed on this table to prevent data loss');
               END IF;

               -- If table partition exists but is empty, we try to drop the Partition without exchnage it.
               -- For an interval partitioned table with a range partition that cannot be dropped, we may loose data if we exchange the empty partition with the partition
               -- of _st table with plenty of data in it !!
               IF (IsPartitionEmpty (pEntry.Table_Name, vPartName) = 1)
               THEN
                  LogFacility (
                     LOG_SEV_INFO,
                        'Partition '
                     || vPartName
                     || ' is empty and will not be exchanged in order to avoid data loss for interval partitoned tables and range partition',
                     pEntry.TABLE_NAME);

                  -- Now dropping empty exchanged partition that should be already empty
                  DropEmptyPartition (pEntry.TABLE_NAME, vPartName);

                  -- Before skipping the next steps, I re-enable the FK constraints if they had ever been disabled

                  -- 20121108 esegui enable
                  FOR vCmdCount IN 1 .. comandi_enable.COUNT
                  LOOP
                     BEGIN
                        LogFacility (LOG_SEV_INFO,
commands_enable (vCmdCount),
                                     pEntry.TABLE_NAME);
                        ExecSqlCommand (comandi_enable (vCmdCount),
                                        pEntry.TABLE_NAME);
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           LogFacility (
                              LOG_SEV_WARNING,
                                 'An error occurred during '
|| commands_enable (vCmdCount)
                              || ' : '
                              || SQLERRM
                              || ' [Code: '
                              || TO_CHAR (SQLCODE)
                              || ']',
                              pEntry.TABLE_NAME);
                     END;
                  END LOOP;

                  -- Skip next steps in this case
                  CONTINUE;
               END IF;

               AlignExchangeTableIndex (pEntry.Partition_Exchange_Table_Name,
                                        pEntry.Table_Name,
                                        pEntry);

               ExchangePartition (pEntry.Table_Name,
                                  pEntry.Partition_Exchange_Table_Name,
                                  vPartName);

               LogFacility (
                  LOG_SEV_INFO,
                     'Exchanged partition : '
                  || vPartName
                  || ' from '
                  || TRIM (pEntry.Partition_Exchange_Table_Name)
                  || ' to '
                  || TRIM (pEntry.Partition_Archive_Table_Name),
                  pEntry.TABLE_NAME);

               IF B_COMPRESSION_ENABLED = 1
               THEN
                  CompressPartition (pEntry.Partition_Exchange_Table_Name,
                                     NULL,
                                     pEntry.Parallel_Degree,
                                     pEntry.Partition_Compress_Type,
                                     pEntry.Partition_Archive_Tablespace);
               ELSIF pEntry.Partition_Archive_Tablespace !=
                        vPartTablespaceName
               THEN
                  MovePartitionTablespace (
                     pEntry.Partition_Exchange_Table_Name,
                     NULL,
                     pEntry.Parallel_Degree,
                     pEntry.Partition_Archive_Tablespace);
               END IF;

               IF NOT PartitionExists (pEntry.Partition_Archive_Table_Name,
                                       vPartName)
               THEN
                  IF NOT isIntervalPartitionedTable (
                            pEntry.Partition_Archive_Table_Name)
                  THEN
                     LogFacility (
                        LOG_SEV_INFO,
                           'Creating partition : '
                        || vPartName
                        || ' on table '
                        || TRIM (pEntry.Partition_Archive_Table_Name),
                        pEntry.TABLE_NAME);

                     CreatePartition (pEntry.Partition_Archive_Table_Name,
                                      t_partition_arc_work,
                                      vPartName,
                                      vPartTablespaceName,
                                      vPartDate,
                                      pEntry.Partition_Retention_Unit,
                                      pEntry.Partition_Name_Prefix,
                                      pEntry.Parallel_Degree);
                  ELSE
                     -- Unfortunately, the lock table command uses date in the command like the START period of the partition and not the high value like in the other process
                     -- we need to calculate the correct date to pass to the command in order to create the corret partition for vPartDate

                     IF IsFunction (pEntry.Partition_Retention_Unit) = FALSE
                     THEN
                        vPartDate :=
                           GetNextPartitionWithRetention (
                              vPartDate,
                              pEntry.Partition_Retention_Unit,
                              -2);
                     ELSE
                        ExecSqlCommandInto (
                              'SELECT '
                           || pEntry.Partition_Retention_Unit
                           || '.GetNextHV('''
                           || pEntry.TABLE_NAME
                           || ''' , '''
                           || vPartDate
                           || ''',-2 ) FROM DUAL',
                           pEntry.TABLE_NAME,
                           vPartDate);
                     END IF;


                     IF (   INSTR (gPartColumnDatatype, 'TIMESTAMP') > 0
                         OR gPartColumnDatatype = 'DATE')
                     THEN
                        IF (pEntry.Partition_Retention_Unit = 'YYYYMMWK')
                        THEN
                           vPartString :=
                                 'TO_DATE('' '
                              || TO_CHAR (TO_DATE (vPartDate, 'YYYYMMDD'),
                                          'YYYY-MM-DD HH24:MI:SS')
                              || ''', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')';
                        ELSE
                           vPartString :=
                                 'TO_DATE('' '
                              || TO_CHAR (
                                    TO_DATE (vPartDate,
                                             pEntry.Partition_Retention_Unit),
                                    'YYYY-MM-DD HH24:MI:SS')
                              || ''', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')';
                        END IF;
                     ELSE
                        vPartString := vPartDate;
                     END IF;

                     LogFacility (
                        LOG_SEV_INFO,
                           'Creating partition : '
                        || vPartName
                        || ' on interval partitioned table : '
                        || TRIM (pEntry.Partition_Archive_Table_Name),
                        pEntry.TABLE_NAME);

                     ExecSqlCommand (
                           'LOCK TABLE '
                        || pEntry.Partition_Archive_Table_Name
                        || ' PARTITION FOR ('
                        || vPartString
                        || ') IN SHARE MODE',
                        pEntry.TABLE_NAME);

                     -- partition created in an interval partioned table is automatically created with SYS_XXX, we need to rename it to our default standard :
                     RenameIntervalPartition (
                        pEntry,
                        pEntry.Partition_Archive_Table_Name);
                  END IF;
               END IF;

               AlignExchangeTableIndex (pEntry.Partition_Exchange_Table_Name,
                                        pEntry.Partition_Archive_Table_Name,
                                        pEntry);

               ExchangePartition (pEntry.Partition_Archive_Table_Name,
                                  pEntry.Partition_Exchange_Table_Name,
                                  vPartName);

               LogFacility (
                  LOG_SEV_INFO,
                     'Exchanged partition :'
                  || vPartName
                  || ' with '
                  || TRIM (pEntry.Partition_Archive_Table_Name)
                  || '".',
                  pEntry.TABLE_NAME);

               -- Now dropping empty exchanged partition that should be already empty
               DropEmptyPartition (pEntry.TABLE_NAME, vPartName);


               --I rehabilitate the FKs
               FOR vCmdCount IN 1 .. comandi_enable.COUNT
               LOOP
                  BEGIN
                     LogFacility (LOG_SEV_INFO,
commands_enable (vCmdCount),
                                  pEntry.TABLE_NAME);
                     ExecSqlCommand (comandi_enable (vCmdCount),
                                     pEntry.TABLE_NAME);
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        LogFacility (
                           LOG_SEV_WARNING,
                              'An error occurred during '
|| commands_enable (vCmdCount)
                           || ' : '
                           || SQLERRM
                           || ' [Code: '
                           || TO_CHAR (SQLCODE)
                           || ']',
                           pEntry.TABLE_NAME);
                  END;
               END LOOP;
            END IF;
         -- The error is deliberately not handled because if an exchange partition fails it may happen that the exchange table remains full of records from the original partition which
         -- therefore it cannot be emptied and requires manual intervention
         ELSE
            LogFacility (
               LOG_SEV_INFO,
                  'Partition '
               || vPartName
               || ' is the only partition of the table. No exchange partition will take place',
               pEntry.TABLE_NAME);
         END IF;
      END LOOP;

      LogFacility (LOG_SEV_INFO,
                   'Finished Exchange Partition',
                   pEntry.TABLE_NAME);
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (
            LOG_SEV_ERROR,
               'Errore executing Exchange on table.'
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            pEntry.TABLE_NAME);
         RAISE;
   END;

   PROCEDURE ArchiveRowWithQuery (pEntry MAINT_PARTITIONS%ROWTYPE)
   AS
      curRowToArchive   SYS_REFCURSOR;

      TYPE rid_type IS TABLE OF ROWID;

      tabRow            rid_type;
      pQueryString      VARCHAR2 (4000);
      pColumnList       VARCHAR2 (4000);
      vErrMsg           VARCHAR2 (1000);
      vErrCount         NUMBER;
      bulk_errors       EXCEPTION;

      PRAGMA EXCEPTION_INIT (bulk_errors, -24381);
   BEGIN
      LogFacility (
         LOG_SEV_INFO,
         'Starting ArchiveRowWithQuery for table' || pEntry.TABLE_NAME,
         pEntry.TABLE_NAME);
      pQueryString := 'SELECT rowid FROM :table WHERE :where';

      pQueryString :=
         REGEXP_REPLACE (pQueryString, ':table', TRIM (pEntry.Table_Name));
      pQueryString :=
         REGEXP_REPLACE (pQueryString, ':where', TRIM (pEntry.Archive_Query));

        SELECT LISTAGG (column_name, ' ,') WITHIN GROUP (ORDER BY COLUMN_ID)
          INTO pColumnList
          FROM dba_tab_columns
         WHERE owner || '.' || table_name = pEntry.TABLE_NAME
      ORDER BY column_id;

      -- The target table does not need to be partitioned. If it is not specified, the records will be deleted without moving them anywhere. However, I warn the user
      --IF ( pEntry.Partition_Archive_Table_Name IS NULL OR (IsPartitionEmpty(pEntry.Partition_Archive_Table_Name, NULL) = 2 or isIntervalPartitionedTable(pEntry.Partition_Archive_Table_Name )))
      --THEN

      IF B_DATAEXPORT_ENABLED = 1
      THEN
         ExportPartitionData (pEntry.Table_Name,
                              NULL,
                              'where ' || TRIM (pEntry.Archive_Query),
                              pEntry.Expdp_Directory);
      ELSE
         IF (pEntry.Partition_Archive_Table_Name IS NULL)
         THEN
            LogFacility (
               LOG_SEV_INFO,
               'Data will be completely deleted without beeing move to another table because column PARTITION_ARCHIVE_TABLE_NAME is empty',
               pEntry.Table_Name);
         END IF;
      END IF;

      LogFacility (
         LOG_SEV_INFO,
            'Starting move of data with where condition "'
         || pQueryString
         || ' from table '
         || pEntry.Table_Name,
         pEntry.Table_Name);

      OPEN curRowToArchive FOR pQueryString;

      LOOP
         FETCH curRowToArchive BULK COLLECT INTO tabRow LIMIT 10000;

         BEGIN
            IF gDryRun = 'N'
            THEN
               IF (pEntry.Partition_Archive_Table_Name IS NOT NULL)
               THEN
                  FORALL i IN 1 .. tabRow.COUNT SAVE EXCEPTIONS
                     EXECUTE IMMEDIATE
                        (   'BEGIN INSERT INTO '
                         || pEntry.Partition_Archive_Table_Name
                         || ' ( '
                         || pColumnList
                         || ' ) SELECT '
                         || pColumnList
                         || ' FROM '
                         || pEntry.Table_Name
                         || ' where rowid = :1; DELETE FROM '
                         || pEntry.Table_Name
                         || ' where rowid = :1 ; END;')
                        USING tabRow (i);
               ELSE
                  FORALL i IN 1 .. tabRow.COUNT SAVE EXCEPTIONS
                     EXECUTE IMMEDIATE
                        (   'DELETE FROM '
                         || pEntry.Table_Name
                         || ' where rowid = :1')
                        USING tabRow (i);
               END IF;

               COMMIT;

               EXIT WHEN tabRow.COUNT != 10000;
            END IF;
         EXCEPTION
            WHEN bulk_errors
            THEN
               vErrCount := SQL%BULK_EXCEPTIONS.COUNT;

               FOR i IN 1 .. vErrCount
               LOOP
                  -- Print out details of each error during bulk insert
                  LogFacility (
                     LOG_SEV_WARNING,
                        'Errors occurred '
                     || vErrCount
                     || '# during archiving of Rowid# : '
                     || ' RowId : '
                     || tabRow (SQL%BULK_EXCEPTIONS (i).ERROR_INDEX)
                     || ' Error: '
                     || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE),
                     pEntry.Table_Name);
               END LOOP;
            WHEN OTHERS
            THEN
               LogFacility (
                  LOG_SEV_ERROR,
                     'Error occurred during row archiving : '
                  || SQLERRM
                  || ' [Code: '
                  || TO_CHAR (SQLCODE)
                  || ']',
                  pEntry.Table_Name);
               RAISE;
         END;
      END LOOP;

      CLOSE curRowToArchive;

      LogFacility (
         LOG_SEV_INFO,
            'Archived Rows: '
         || tabRow.COUNT
         || ' older than : '
         || pEntry.ARCHIVE_QUERY
         || ' for table '
         || pEntry.TABLE_NAME,
         pEntry.TABLE_NAME);

      COMMIT;

      LogFacility (
         LOG_SEV_INFO,
         'Finished ArchiveRowWithQuery for table ' || pEntry.TABLE_NAME,
         pEntry.TABLE_NAME);
   END;



   PROCEDURE ExportPartition (
      pTable     DBA_TAB_PARTITIONS.table_name%TYPE,
      pName      DBA_TAB_PARTITIONS.partition_name%TYPE,
      pDirobj    VARCHAR2 DEFAULT NULL)
   AS
   BEGIN
      ExportPartitionData (pTable,
                           pName,
                           NULL,
                           pDirobj);
   END;


   PROCEDURE TruncateTable (pTable DBA_TAB_PARTITIONS.table_name%TYPE)
   AS
   BEGIN
      LogFacility (LOG_SEV_INFO,
                   'Starting truncate of table : ' || pTable || '" ...',
                   pTable);

      ExecSqlCommand ('truncate table ' || TRIM (pTable), pTable);

      LogFacility (LOG_SEV_INFO,
                   'Finished truncating table : ' || pTable || '"',
                   pTable);
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (
            LOG_SEV_ERROR,
               'Error during truncate of table : '
            || pTable
            || ' : '
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            pTable);
   END;


   PROCEDURE ExchangePartition (
      pTable         DBA_TAB_PARTITIONS.table_name%TYPE,
      pExchgTable    DBA_TAB_PARTITIONS.table_name%TYPE,
      pPartName      DBA_TAB_PARTITIONS.partition_name%TYPE)
   AS
      vStmt   LONG;
   BEGIN
      LogFacility (
         LOG_SEV_INFO,
            'Starting Exchange Partition '
         || pPartName
         || ' from '
         || pTable
         || ' to '
         || TRIM (pExchgTable)
         || '"',
         pTable);

      vStmt :=
            'ALTER TABLE '
         || TRIM (pTable)
         || ' EXCHANGE PARTITION '
         || pPartName
         || ' WITH TABLE '
         || TRIM (pExchgTable)
         || ' INCLUDING INDEXES '
         || ' WITHOUT VALIDATION '
         || ' UPDATE GLOBAL INDEXES';

      LogFacility (LOG_SEV_INFO, 'Executing : ' || vStmt, pTable);
      ExecSqlCommand (vStmt, pTable);

      LogFacility (
         LOG_SEV_INFO,
            'Finished Exchange Partition '
         || pPartName
         || ' from '
         || pTable
         || ' to '
         || TRIM (pExchgTable)
         || '"',
         pTable);
   END;

   --
   FUNCTION CalculatePartitionName (pDate      VARCHAR2,
                                    pUM        VARCHAR2,
                                    pPrefix    VARCHAR2)
      RETURN VARCHAR2
   AS
      vPartName      VARCHAR2 (30);
      vPartDate      DATE;
      vFormattedHV   VARCHAR2 (100);
      vMondayName    VARCHAR2 (10);
   BEGIN
      LogFacility (LOG_SEV_DEBUG,
                   'Starting CalculatePartitionName for date: ' || pDate,
                   NULL);

      IF INSTR (pDate, '9999') > 0
      THEN
         --SELECT pPrefix || 'LAST' INTO vPartName FROM DUAL;
         SELECT (   pPrefix
                 || TO_CHAR (TO_DATE ('01/01/9999', 'DD/MM/YYYY'), pUM))
           INTO vPartName
           FROM DUAL;
      ELSIF (pUM = 'YYYYMMDD')
      THEN
         vPartDate := TRUNC (TO_DATE (pDate, pUM) - 1);

         SELECT (pPrefix || TO_CHAR (vPartDate, pUM))
           INTO vPartName
           FROM DUAL;
      ELSIF (pUM = 'YYYYMMWK')
      THEN
         -- Checking the current NLS_LANGUAGE setup
         SELECT DECODE (VALUE, 'ITALIAN', 'LUNEDI', 'MONDAY')
           INTO vMondayName
           FROM nls_session_parameters
          WHERE parameter = 'NLS_LANGUAGE';

         vPartDate :=
            TRUNC (NEXT_DAY (TO_DATE (pDate, 'YYYYMMDD') - 7, vMondayName));

         SELECT (pPrefix || TO_CHAR (vPartDate, 'YYYYMMDD'))
           INTO vPartName
           FROM DUAL;
      ELSIF (pUM = 'YYYYMM')
      THEN
         vPartDate := TRUNC (ADD_MONTHS (TO_DATE (pDate, pUM), -1), 'mm');

         SELECT (pPrefix || TO_CHAR (vPartDate, pUM))
           INTO vPartName
           FROM DUAL;
      ELSIF (pUM = 'YYYY')
      THEN
         vPartDate := TRUNC (ADD_MONTHS (TO_DATE (pDate, pUM), -12), 'YEAR');

         SELECT (pPrefix || TO_CHAR (vPartDate, pUM))
           INTO vPartName
           FROM DUAL;
      ELSIF (IsNumber (pDate) = TRUE)
      THEN
         SELECT (pPrefix || TO_CHAR (pDate - pUM))
           INTO vPartName
           FROM DUAL;
      END IF;

      LogFacility (LOG_SEV_DEBUG,
                   'Finished CalculatePartitionName for date: ' || pDate,
                   NULL);

      RETURN SUBSTR (vPartName, 1, 30);
   END;

   --
   --
   --
   FUNCTION PartitionExists (
      pTable    DBA_TAB_PARTITIONS.table_name%TYPE,
      pName     DBA_TAB_PARTITIONS.partition_name%TYPE)
      RETURN BOOLEAN
   AS
      vCount    INTEGER;
      vRetVal   BOOLEAN;
   BEGIN
      LogFacility (LOG_SEV_DEBUG,
                   'Verify if PartitionExists : "' || pName || '" ...',
                   pTable);

      SELECT COUNT (*)
        INTO vCount
        FROM DBA_TAB_PARTITIONS t
       WHERE     UPPER (t.table_owner || '.' || t.table_name) =
                    UPPER (TRIM (pTable))
             AND UPPER (t.partition_name) = UPPER (pName);

      IF (vCount > 0)
      THEN
         vRetVal := TRUE;
      ELSE
         vRetVal := FALSE;
      END IF;

      LogFacility (
         LOG_SEV_DEBUG,
         'Finished checking if PartitionExists : "' || pName || '" ...',
         pTable);

      RETURN vRetVal;
   END;

   FUNCTION DefaultPartition (pTable DBA_TAB_PARTITIONS.table_name%TYPE)
      RETURN DBA_TAB_PARTITIONS.partition_name%TYPE
   AS
      v_max    LONG;
      v_part   DBA_TAB_PARTITIONS.partition_name%TYPE;
   BEGIN
      SELECT high_value, partition_name
        INTO v_max, v_part
        FROM (  SELECT high_value, partition_name
                  FROM dba_tab_partitions t
                 WHERE UPPER (t.table_owner || '.' || t.table_name) =
                          UPPER (pTable)
              ORDER BY partition_position DESC)
       WHERE ROWNUM = 1;

      IF v_max = 'MAXVALUE' OR v_max = 'DEFAULT'
      THEN
         RETURN v_part;
      ELSE
         RETURN NULL;
      END IF;
   END;

   PROCEDURE CreatePartition (
      pTableName        DBA_TAB_PARTITIONS.table_name%TYPE,
      pTablePartList    pm_partition_list_type,
      pPartName         DBA_TAB_PARTITIONS.partition_name%TYPE,
      pTblSpace         DBA_TAB_PARTITIONS.Tablespace_Name%TYPE,
      pDate             VARCHAR2,
      pRetentionUnit    VARCHAR2,
      pNamePrefix       VARCHAR2,
      pDegree           NUMBER)
   AS
      vStmt                 LONG;
      vPartNameToSplit      DBA_TAB_PARTITIONS.partition_name%TYPE;
      vPartNextSplitValue   VARCHAR2 (100);
      vNewPartName          VARCHAR2 (100);
      vPartSplitValue       VARCHAR2 (100);
      vNewPartDate          NUMBER;
      vNewDefPartDate       NUMBER;
      vNewDefPartName       VARCHAR2 (100);
   BEGIN
      LogFacility (
         LOG_SEV_INFO,
            'Creating partition : '
         || pPartName
         || ' with high value '
         || pDate
         || ' on table '
         || pTableName,
         pTableName);

      IF IsFunction (pRetentionUnit) = FALSE
      THEN
         vPartNextSplitValue :=
            GetNextPartition (pTablePartList,
                              pDate,
                              pRetentionUnit,
                              vPartNameToSplit);

         --If we are in the situation of a trash partition
         IF SUBSTR (vPartNextSplitValue, 1, 4) = '9999'
         THEN
            -- If there is a trash partition, the name of the new partition must by default be equal to the oldest partition + 1
            vPartNameToSplit := DefaultPartition (pTableName);
            --vNewPartDate      := GetNextPartitionWithRetention(pDate, pRetentionUnit , 0) ;
            --vNewPartName      := CalculatePartitionName(pDate, pRetentionUnit, pNamePrefix);

            --We need to rename the trash partition to pDate + a RETENTION UNIT. The 0 in the function below is because the +1 is directly present in the function
            vNewDefPartDate :=
               GetNextPartitionWithRetention (pDate, pRetentionUnit, 0);
            vNewDefPartName :=
               CalculatePartitionName (vNewDefPartDate,
                                       pRetentionUnit,
                                       pNamePrefix);
         ELSIF vPartNextSplitValue IS NULL
         THEN
            -- For code readability only
            -- This is the situation in which the table does not have a maxvalue and the partition you are trying to create must not be split from an existing one, but created from 0
            NULL;
         ELSIF     vPartNextSplitValue IS NOT NULL
               AND SUBSTR (vPartNextSplitValue, 1, 4) <> '9999'
         THEN
            --If vPartNextSplitValue is not null then it means we need to split an existing partition.
            --vPartNameToSplit is enhanced by the GetNextPartition call above
            NULL;
         END IF;
      ELSE
         -- We are in the case of a retention unit with function
         vPartNameToSplit := DefaultPartition (pTableName);

         --If I don't have a trash partition, I might have a larger partition than I want to create, let's see if that's the case...
         IF vPartNameToSplit IS NULL
         THEN
            ExecSqlCommandInto (
                  'SELECT '
               || pRetentionUnit
               || '.GetNextHV('''
               || pTableName
               || ''' , '''
               || pDate
               || ''',1 ) FROM DUAL',
               NULL,
               vPartNextSplitValue);

            -- Compared to the High Value I want to create, I calculate the split high value of the immediately following partition
            -- the retention_unit function always returns a vPartNameToSplit, even if the partition does not exist
            --the IF below is always verified
            IF vPartNextSplitValue IS NOT NULL
            THEN
               -- the retention_unit function always returns a vPartNameToSplit, even if the partition does not exist, so I have to check whether it exists or not
               ExecSqlCommandInto (
                     'SELECT '
                  || pRetentionUnit
                  || '.GetPartitionNameFromHV('''
                  || pTableName
                  || ''' , '''
                  || vPartNextSplitValue
                  || ''' ) FROM DUAL',
                  NULL,
                  vPartNameToSplit);

               --I need to check whether the partition exists or not
               -- If it doesn't exist, then I need to do only ADD Partition and not split
               IF NOT PartitionExists (pTableName, vPartNameToSplit)
               THEN
                  vPartNameToSplit := NULL;
               -- If the next partition exists, then I need to split the next partition. calculated with the above call to GetPartitionNameFromHV
               ELSE
                  -- vPartNameToSplit is valid as the call immediately above
                  NULL;
               END IF;
            END IF;
         ELSE
            --this is the case when I have a trash partition
            -- Calculate the name of the new trash partition
            --ExecSqlCommandInto('SELECT ' || pRetentionUnit || '.GetNextHV(''' || pTableName || ''' , ''' || pDate || ''',1 ) FROM DUAL',NULL,vPartNextSplitValue);

            --I calculate the partition name based on the partition value +1
            --ExecSqlCommandInto('SELECT ' || pRetentionUnit || '.GetPartitionNameFromHV(''' || pTableName || ''' , ''' || vPartNextSplitValue || ''' ) FROM DUAL',NULL,vNewPartName);

            --I have to advance +1 to go beyond the pDate to give a consistent name to the Def Partition
            ExecSqlCommandInto (
                  'SELECT '
               || pRetentionUnit
               || '.GetNextHV('''
               || pTableName
               || ''' , '''
               || pDate
               || ''',1 ) FROM DUAL',
               NULL,
               vPartNextSplitValue);

            --I calculate the partition name based on the partition value +1
            ExecSqlCommandInto (
                  'SELECT '
               || pRetentionUnit
               || '.GetPartitionNameFromHV('''
               || pTableName
               || ''' , '''
               || vPartNextSplitValue
               || ''' ) FROM DUAL',
               NULL,
               vNewDefPartName);
         END IF;
      END IF;

      IF (   INSTR (gPartColumnDatatype, 'TIMESTAMP') > 0
          OR gPartColumnDatatype = 'DATE')
      THEN
         IF pRetentionUnit = 'YYYY'
         THEN
            vPartSplitValue :=
                  'to_date('' '
               || TO_CHAR (TO_DATE (pDate || '01', pRetentionUnit || 'MM'),
                           'YYYY-MM-DD HH24:MI:SS')
               || ''', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')';
         ELSE
            vPartSplitValue :=
                  'to_date('' '
               || TO_CHAR (TO_DATE (pDate, pRetentionUnit),
                           'YYYY-MM-DD HH24:MI:SS')
               || ''', ''SYYYY-MM-DD HH24:MI:SS'', ''NLS_CALENDAR=GREGORIAN'')';
         END IF;
      ELSE
         vPartSplitValue := pDate;
      END IF;

      IF (vPartNameToSplit IS NULL)
      THEN
         vStmt :=
               'alter table :table add partition :partition values less than ('
            || vPartSplitValue
            || ') update indexes';
      ELSE
         vStmt :=
               'alter table :table split partition :split_part at ('
            || vPartSplitValue
            || ')'
|| ' into ( partition :partition , partition :new_split_part ) '
            || CanBeOnline ('SPLIT')
|| ' parallel ( degree '
            || pDegree
            || ' )';
      END IF;

      vStmt := REGEXP_REPLACE (vStmt, ':table', TRIM (pTableName));
      vStmt := REGEXP_REPLACE (vStmt, ':partition', pPartName);

      -- If the new trash partition needs to be renamed (which happens in the case of functions like retention_unit)
      IF vNewDefPartName IS NOT NULL
      THEN
         vStmt := REGEXP_REPLACE (vStmt, ':new_split_part', vNewDefPartName);
      ELSE
         vStmt := REGEXP_REPLACE (vStmt, ':new_split_part', vPartNameToSplit);
      END IF;

      vStmt := REGEXP_REPLACE (vStmt, ':split_part', vPartNameToSplit);
      vStmt := REGEXP_REPLACE (vStmt, ':ts', pTblSpace);

      LogFacility (LOG_SEV_INFO, 'Executing : ' || vStmt, pTableName);

      ExecSqlCommand (vStmt, pTableName);

      LogFacility (
         LOG_SEV_INFO,
            'Finished creating partition : '
         || pPartName
         || ' with high value '
         || pDate
         || ' on table '
         || pTableName,
         pTableName);
   END;



   PROCEDURE CheckParams (pDryRun CHAR, pLogLevel VARCHAR2)
   AS
   BEGIN
      IF (    pLogLevel != 'DEBUG'
AND pLogLevel != 'INFO'
AND pLogLevel != 'WARNING'
          AND pLogLevel != 'ERROR')
      THEN
         RAISE_APPLICATION_ERROR (
            -20000,
            'LogLevel parameter is invalid. Valid Values are : -1 ( DEBUG ) / 0 ( INFO ) / 1 ( WARNING ) / 2 ( ERROR )');
      ELSE
         CASE pLogLevel
            WHEN 'DEBUG'
            THEN
               gLogLevel := -1;
            WHEN 'INFO'
            THEN
               gLogLevel := 0;
            WHEN 'WARNING'
            THEN
               gLogLevel := 1;
            WHEN 'ERROR'
            THEN
               gLogLevel := 2;
         END CASE;
      END IF;

      IF (pDryRun <> 'Y' AND pDryRun <> 'N')
      THEN
         RAISE_APPLICATION_ERROR (
            -20000,
            'DryRun parameter is invalid. Valid Values are : Y or N ');
      ELSE
         gDryRun := pDryRun;

         IF (pDryRun = 'Y')
         THEN
            LogFacility (
               LOG_SEV_INFO,
               'THis is a DRY RUN Session. No changes will be performed to database',
               NULL);
         END IF;
      END IF;
   END;


   PROCEDURE ExecSqlCommand (pSqlCmd VARCHAR2, pTableName VARCHAR2)
   AS
      vIsSelect   NUMBER;
   BEGIN
      IF (pSqlCmd IS NOT NULL)
      THEN
         LogFacility (LOG_SEV_DEBUG,
                      'Starting ExecSqlCommand command: ' || pSqlCmd,
                      pTableName);

         BEGIN
            -- Execute the command only if this is not a DryRun Sesssion
            IF    gDryRun = 'N'
               OR (    gDryRun = 'Y'
                   AND (   SUBSTR (pSqlCmd, 1, 6) = 'SELECT'
                        OR SUBSTR (pSqlCmd, 1, 6) = 'select'))
            THEN
               EXECUTE IMMEDIATE (pSqlCmd);
            END IF;
         EXCEPTION
            WHEN LAST_RANGE_PART
            THEN
               RAISE;
            WHEN OTHERS
            THEN
               LogFacility (
                  LOG_SEV_ERROR,
                  SQLERRM || ' [Code: ' || TO_CHAR (SQLCODE) || ']',
                  pTableName);
               RAISE;
         END;

         LogFacility (LOG_SEV_DEBUG,
                      'Finished ExecSqlCommand command: ' || pSqlCmd,
                      pTableName);
      END IF;
   END;


   PROCEDURE ExecSqlCommandInto (pSqlCmd          VARCHAR2,
                                 pTableName       VARCHAR2,
                                 pInto        OUT VARCHAR2)
   AS
      vIsSelect   NUMBER;
   BEGIN
      IF (pSqlCmd IS NOT NULL)
      THEN
         LogFacility (LOG_SEV_DEBUG,
                      'Executing ExecSqlCommandInto: ' || pSqlCmd,
                      pTableName);

         BEGIN
            -- If we are in Dryrun but the command executed is a select, then I execute it anyway

            -- Execute the commend only if this is not a DryRun Sesssion
            IF    gDryRun = 'N'
               OR (    gDryRun = 'Y'
                   AND (   SUBSTR (pSqlCmd, 1, 6) = 'SELECT'
                        OR SUBSTR (pSqlCmd, 1, 6) = 'select'))
            THEN
               EXECUTE IMMEDIATE (pSqlCmd) INTO pInto;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               LogFacility (
                  LOG_SEV_ERROR,
                  SQLERRM || ' [Code: ' || TO_CHAR (SQLCODE) || ']',
                  pTableName);
               RAISE;
         END;

         LogFacility (LOG_SEV_DEBUG,
                      'Finished executing ExecSqlCommandInto: ' || pSqlCmd,
                      pTableName);
      END IF;
   END;

   FUNCTION CalculateNextRunDate (
      calendar_string    VARCHAR2,
      start_date         TIMESTAMP WITH TIME ZONE)
      RETURN TIMESTAMP
   IS
      l_return_date_after   TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP;
      l_next_run_date       TIMESTAMP WITH TIME ZONE;
   BEGIN
      DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING (
calendar_string => calendar_string,
start_date => start_date,
         return_date_after   => l_return_date_after,
         next_run_date       => l_next_run_date);

      RETURN l_next_run_date;
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (
            LOG_SEV_WARNING,
               'An error occurred during the evaluation of SCHEDULE. The next run date has been calculated with FREQ=DAILY BYHOUR=1'
|| calendar_string
            || ' : '
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            NULL);

         DBMS_SCHEDULER.EVALUATE_CALENDAR_STRING (
            calendar_string     => 'FREQ=DAILY;BYHOUR=1;BYMINUTE=0;BYSECOND=0',
start_date => start_date,
            return_date_after   => l_return_date_after,
            next_run_date       => l_next_run_date);

         RETURN l_next_run_date;
   END;

   FUNCTION ProcessTable (pEntry DBA_OP.MAINT_PARTITIONS%ROWTYPE)
      RETURN BOOLEAN
   AS
   BEGIN
      LogFacility (LOG_SEV_INFO,
                   'Starting Processing Table ' || pEntry.Table_Name,
                   pEntry.TABLE_NAME);

      ExecSqlCommand ('alter session set ddl_lock_timeout=30',
                      pEntry.Table_Name);
      ExecSqlCommand (
         'alter session set nls_date_format=''DD/MM/YYYY HH24:MI:SS''',
         pEntry.Table_Name);


      IF gDryRun = 'N'
      THEN
         -- Setting to running the current table
         UPDATE DBA_OP.MAINT_PARTITIONS
            SET LAST_RUN_RESULT = 'RUNNING', LAST_RUN_DATE = gRunDate
          WHERE TABLE_ID = pEntry.TABLE_ID;
      END IF;

      -- Get current actions to be performed on this table
      GetEnabledActions (pEntry);

      IF CheckTableProperties (pEntry.Table_Name) = FALSE
      THEN
         LogFacility (
            LOG_SEV_ERROR,
            'Table is not a range partitioned table. Cannot continue',
            pEntry.Table_Name);
         RETURN FALSE;
      END IF;

      -- Add Partitions
      IF B_ADD_PARTITION = 1
      THEN
         -- If the table has names with no standard format. Partitions will be renamed
         RenamePartitions (pEntry, t_partition_work, pEntry.Table_Name);

         AddPartitionList (pEntry);
      END IF;


      IF B_DROP_PARTITION = 1
      THEN
         -- If the table has names with no standard format. Partitions will be renamed
         RenamePartitions (pEntry, t_partition_work, pEntry.Table_Name);

         DropPartitionList (pEntry);
      END IF;


      IF B_EXCHANGE_PARTITION = 1
      THEN
         -- If the table has names with no standard format. Partitions will be renamed
         RenamePartitions (pEntry, t_partition_work, pEntry.Table_Name);

         -- Check if Table_Name exists
         IF (IsPartitionEmpty (pEntry.Partition_Archive_Table_Name,
                               'DUMMYPARTNAME') != 0)
         THEN
            IF (IsPartitionEmpty (pEntry.Partition_Exchange_Table_Name,
                                  'DUMMYPARTNAME') = 0)
            THEN
               LogFacility (
                  LOG_SEV_INFO,
                     'Table '
                  || pEntry.Partition_Exchange_Table_Name
                  || ' does not exist. It will be created now',
                  pEntry.TABLE_NAME);
               CreateExchangeTable (pEntry);
            END IF;

            -- If the table has names with no standard format. Partitions will be renamed
            RenamePartitions (pEntry,
                              t_partition_arc_work,
                              pEntry.Partition_Archive_Table_Name);

            ExchangePartitionList (pEntry);
         ELSE
            LogFacility (
               LOG_SEV_ERROR,
                  'Table '
               || pEntry.Partition_Archive_Table_Name
               || ' does not exist. Cannot continue processing',
               pEntry.TABLE_NAME);
            RETURN FALSE;
         END IF;
      END IF;


      IF B_COMPRESSION_ENABLED = 1 AND B_EXCHANGE_PARTITION != 1
      THEN
         -- If the table has names with no standard format. Partitions will be renamed
         RenamePartitions (pEntry, t_partition_work, pEntry.Table_Name);

         CompressPartitionList (pEntry);
      END IF;


      IF B_ARCHIVE_WITH_QUERY = 1
      THEN
         ArchiveRowWithQuery (pEntry);
      END IF;


      IF B_APPEND_PARTITION = 1
      THEN
         -- If the table has names with no standard format. Partitions will be renamed
         RenamePartitions (pEntry, t_partition_work, pEntry.Table_Name);
         AppendPartitionList (pEntry);
      END IF;


      LogFacility (
         LOG_SEV_INFO,
         'Successfully Finished Processing Table ' || pEntry.Table_Name,
         pEntry.TABLE_NAME);

      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (LOG_SEV_ERROR,
                      'Error Processing Table ' || pEntry.Table_Name,
                      pEntry.TABLE_NAME);
         LogFacility (LOG_SEV_ERROR,
                      SQLERRM || ' [Code: ' || TO_CHAR (SQLCODE) || ']',
                      pEntry.Table_Name);
         RETURN FALSE;
   END;

   PROCEDURE SendMail (pRunId INTEGER)
   AS
      l_mail_conn   UTL_SMTP.connection;

      CURSOR cEmailConfig
      IS
         SELECT *
           FROM DBA_OP.MAINT_PARTITIONS_EMAIL
          WHERE enabled = 'Y';

      CURSOR cTableStatus
      IS
         SELECT table_id, table_name, send_email_to
           FROM dba_op.maint_partitions
          WHERE     enabled = 'Y'
                AND last_run_result IN ('ERROR', 'WARNING')
                AND last_run_date > gRunDate - 15 / 1440
                AND send_email_to IS NOT NULL;

      CURSOR cErrorText (
         vTableName    VARCHAR2)
      IS
           SELECT    '<tr style="border:2px solid grey; background-color:#fff8c9;">'
                  || UTL_TCP.crlf
                  || '<td style="border:2px solid grey; border-collapse:collapse;">'
                  || RUNID
                  || '&nbsp;&nbsp;</td>'
                  || UTL_TCP.crlf
                  || '<td style="border:2px solid grey; border-collapse:collapse;">'
                  || SEVERITY
                  || '&nbsp;&nbsp;</td>'
                  || UTL_TCP.crlf
                  || '<td style="border:2px solid grey; border-collapse:collapse;">'
                  || TO_CHAR (DATETIME, 'DD/MM/YYYY HH24:MI:SS.FF')
                  || '&nbsp;&nbsp;</td>'
                  || UTL_TCP.crlf
                  || '<td style="border:2px solid grey; border-collapse:collapse;">'
                  || TABLE_NAME
                  || '&nbsp;&nbsp;</td>'
                  || UTL_TCP.crlf
                  || '<td style="border:2px solid grey; border-collapse:collapse;">'
                  || MESSAGE
                  || '&nbsp;&nbsp;</td>'
                  || UTL_TCP.crlf
                  || '</tr>'
                  || UTL_TCP.crlf
                     AS HTML_TAB_ROW
             FROM dba_op.maint_partitions_log
            WHERE     severity IN ('ERROR', 'WARNING')
                  AND table_name = vTableName
                  AND runid = pRunId
ORDER BY datetime;

      vDbName       v$DATABASE.NAME%TYPE;
   BEGIN
      SELECT name INTO vDbName FROM v$database;

      FOR rwEmailConfig IN cEmailConfig
      LOOP
         FOR rTableStatus IN cTableStatus
         LOOP
            BEGIN
               l_mail_conn :=
                  UTL_SMTP.open_connection (rwEmailConfig.smtp_host,
                                            rwEmailConfig.smtp_port);

               UTL_SMTP.helo (l_mail_conn, rwEmailConfig.smtp_host);
               UTL_SMTP.mail (l_mail_conn, rwEmailConfig.email_from);

               -- Adding all addresses
               FOR rAddressReceipt
                  IN (    SELECT TRIM (REGEXP_SUBSTR (str,
                                                      '[^;]+',
                                                      1,
                                                      LEVEL))
                                    email_to
                            FROM (SELECT rTableStatus.send_email_to AS str
                                    FROM DUAL)
                      CONNECT BY INSTR (str,
                                        ';',
                                        1,
                                        LEVEL - 1) > 0)
               LOOP
                  UTL_SMTP.rcpt (l_mail_conn, rAddressReceipt.email_to);
               END LOOP;


               UTL_SMTP.open_data(l_mail_conn);

               UTL_SMTP.write_data (
                  l_mail_conn,
                     'Date: '
                  || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
                  || UTL_TCP.crlf);
               UTL_SMTP.write_data (
                  l_mail_conn,
                  'To: ' || rTableStatus.send_email_to || UTL_TCP.crlf);
               UTL_SMTP.write_data (
                  l_mail_conn,
                  'From: ' || rwEmailConfig.email_from || UTL_TCP.crlf);
               UTL_SMTP.write_data (
                  l_mail_conn,
                     'Subject: NEXI - PARTITIONS MANAGER : Errors occurred  on database '
                  || vDbName
                  || ' for TableName : '
                  || rTableStatus.Table_Name
                  || UTL_TCP.crlf);
               UTL_SMTP.write_data (
                  l_mail_conn,
                  'Reply-To: ' || rwEmailConfig.email_from || UTL_TCP.crlf);
               UTL_SMTP.write_data(l_mail_conn,
                                    'MIME-Version: 1.0' || UTL_TCP.crlf);

               UTL_SMTP.write_data (
                  l_mail_conn,
                     'Content-Type: text/html; charset="iso-8859-1"'
                  || UTL_TCP.crlf
                  || UTL_TCP.crlf);

               UTL_SMTP.write_data (
                  l_mail_conn,
                     '<h1 style="color: #5e9ca0;">NEXI Partition Manager</h1>
<p><strong>&nbsp;Errors occurred in RunId : '
                  || pRunId
                  || ' on Table : '
                  || rTableStatus.Table_Name
                  || '</strong></p>
<table style="border:2px solid grey; border-collapse:collapse;">
<thead>
<tr style="font-weight: bold; color: #fff; background-color: #2e6c80;">
<td style="border:2px solid grey; border-collapse:collapse;">&nbsp;RunID</td>
<td style="border:2px solid grey; border-collapse:collapse;">&nbsp;Severity</td>
<td style="border:2px solid grey; border-collapse:collapse;">&nbsp;Execution Date</td>
<td style="border:2px solid grey; border-collapse:collapse;">&nbsp;Table Name</td>
<td style="border:2px solid grey; border-collapse:collapse;">&nbsp;Error Message</td>
</tr>
</thead>
<tbody>
'                  );

               FOR rErrorMsg IN cErrorText (rTableStatus.Table_Name)
               LOOP
                  UTL_SMTP.write_data (l_mail_conn, rErrorMsg.HTML_TAB_ROW);
               END LOOP;

               UTL_SMTP.write_data (l_mail_conn, '</tbody>
</table>'       );

               UTL_SMTP.close_data(l_mail_conn);
               UTL_SMTP.quit (l_mail_conn);
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_WARNING,
                        'Error Sending Email for Table '
                     || rTableStatus.Table_Name
                     || ' Error: '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     rTableStatus.Table_Name);
            END;
         END LOOP;
      END LOOP;
   END;



   PROCEDURE SendTestMail (vMailTo VARCHAR2)
   AS
      l_mail_conn   UTL_SMTP.connection;

      CURSOR cEmailConfig
      IS
         SELECT *
           FROM DBA_OP.MAINT_PARTITIONS_EMAIL
          WHERE enabled = 'Y';

      vDbName       v$DATABASE.NAME%TYPE;
   BEGIN
      SELECT name INTO vDbName FROM v$database;

      FOR rwEmailConfig IN cEmailConfig
      LOOP
         BEGIN
            l_mail_conn :=
               UTL_SMTP.open_connection (rwEmailConfig.smtp_host,
                                         rwEmailConfig.smtp_port);

            UTL_SMTP.helo (l_mail_conn, rwEmailConfig.smtp_host);
            UTL_SMTP.mail (l_mail_conn, rwEmailConfig.email_from);

            -- Adding all addresses
            FOR rAddressReceipt IN (    SELECT TRIM (REGEXP_SUBSTR (str,
                                                                    '[^;]+',
                                                                    1,
                                                                    LEVEL))
                                                  email_to
                                          FROM (SELECT vMailTo AS str FROM DUAL)
                                    CONNECT BY INSTR (str,
                                                      ';',
                                                      1,
                                                      LEVEL - 1) > 0)
            LOOP
               UTL_SMTP.rcpt (l_mail_conn, rAddressReceipt.email_to);
            END LOOP;


            UTL_SMTP.open_data(l_mail_conn);

            UTL_SMTP.write_data (
               l_mail_conn,
                  'Date: '
               || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
               || UTL_TCP.crlf);
            UTL_SMTP.write_data(l_mail_conn,
                                 'To: ' || vMailTo || UTL_TCP.crlf);
            UTL_SMTP.write_data (
               l_mail_conn,
               'From: ' || rwEmailConfig.email_from || UTL_TCP.crlf);
            UTL_SMTP.write_data (
               l_mail_conn,
                  'Subject: NEXI - PARTITIONS MANAGER : Test Message on database '
               || UTL_TCP.crlf);
            UTL_SMTP.write_data (
               l_mail_conn,
               'Reply-To: ' || rwEmailConfig.email_from || UTL_TCP.crlf);
            UTL_SMTP.write_data(l_mail_conn,
                                 'MIME-Version: 1.0' || UTL_TCP.crlf);
            UTL_SMTP.write_data (
               l_mail_conn,
                  'Content-Type: text/html; charset="iso-8859-1"'
               || UTL_TCP.crlf
               || UTL_TCP.crlf);
            UTL_SMTP.write_data (
               l_mail_conn,
               '<h1 style="color: #5e9ca0;">NEXI Partition Manager</h1>
                      <p><strong>&nbsp;This is just a test Message</strong></p>');

            UTL_SMTP.close_data(l_mail_conn);
            UTL_SMTP.quit (l_mail_conn);
         EXCEPTION
            WHEN OTHERS
            THEN
               DBMS_OUTPUT.put_line (
                     'Error Sending Test Email Error: '
                  || SQLERRM
                  || ' [Code: '
                  || TO_CHAR (SQLCODE)
                  || ']');
         END;
      END LOOP;
   END;


   PROCEDURE StartMaintenance (pTableName    VARCHAR2,
                               pDryrun       VARCHAR DEFAULT 'Y',
                               pLogLevel     VARCHAR2 DEFAULT 2)
   AS
      CURSOR crTables IS
            SELECT *
            FROM DBA_OP.MAINT_PARTITIONS
            WHERE 1=1
              AND SCHEDULE IS NOT NULL
              AND ( pTableName = table_name
                      OR
                  ( pTableName IS NULL AND
                    SYSDATE >= nvl(TRUNC(NEXT_RUN_DATE,'MI'),SYSDATE-5/1440) 
                  )
                   ) AND enabled = 'Y'
            ORDER BY table_id
         FETCH FIRST 200 ROWS ONLY;

      rwTable       crTables%ROWTYPE;
      nErrorCount   INTEGER;
      vErrorMsg     VARCHAR2 (1024);
   BEGIN
      -- Resetting Error counts
      nErrorCount := 0;

      gRunDate := SYSDATE;

      -- Execute the check for valid data in parameter passed to procedure
      CheckParams (pDryrun, pLogLevel);

      LogFacility (LOG_SEV_INFO,
                   'Execution started on : (' || SYSDATE || ').',
                   pTableName);

      OPEN crTables;

      LOOP
         BEGIN
            FETCH crTables INTO rwTable;

            EXIT WHEN crTables%NOTFOUND;

            IF (ProcessTable (rwTable))
            THEN
               -- In the case of DryRun I do not modify the dates and the last result
               IF gDryRun = 'N'
               THEN
                  UPDATE DBA_OP.MAINT_PARTITIONS
                     SET LAST_RUN_RESULT = 'OK',
                         NEXT_RUN_DATE =
                            CalculateNextRunDate (SCHEDULE, gRunDate)
                   WHERE TABLE_ID = rwTable.TABLE_ID;
               END IF;
            ELSE
               nErrorCount := nErrorCount + 1;

               -- In the case of DryRun I do not modify the dates and the last result
               -- In the event of an error I give the job the opportunity to restart the next day
               -- if you set the next_date, in the event of an error it could happen that the job is executed even a year later!!!!
               IF gDryRun = 'N'
               THEN
                  UPDATE DBA_OP.MAINT_PARTITIONS
                     SET LAST_RUN_RESULT = 'ERROR', NEXT_RUN_DATE = NULL
                   WHERE TABLE_ID = rwTable.TABLE_ID;
               END IF;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               LogFacility (
                  LOG_SEV_ERROR,
                     'Error during processing of table : '
                  || rwTable.TABLE_NAME
                  || ' : '
                  || SQLERRM
                  || ' [Code: '
                  || TO_CHAR (SQLCODE)
                  || ']',
                  rwTable.TABLE_NAME);
         END;
      END LOOP;

      CLOSE crTables;

      IF (nErrorCount > 0)
      THEN
         vErrorMsg :=
               'Errors occurred : #'
            || TO_CHAR (nErrorCount)
            || '. Have a look to DBA_OP.PARTITIONS_LOG for details';

         LogFacility (
            LOG_SEV_ERROR,
               ' An error occurred during maintenance on table : '
            || pTableName
            || ' ErrMsg: '
            || vErrorMsg,
            pTableName);
      ELSE
         LogFacility (LOG_SEV_INFO,
'Execution completed successfully.',
                      pTableName);
      END IF;

      -- Notify Users with email if configured
      SendMail (gRunId);
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (LOG_SEV_ERROR,
                      SQLERRM || ' [Code: ' || TO_CHAR (SQLCODE) || ']',
                      pTableName);

         IF crTables%ISOPEN
         THEN
            CLOSE crTables;
         END IF;
   END;



   PROCEDURE AlignExchangeTableIndex (
      vExchangeTablename    VARCHAR2,
      vOtherTableName       VARCHAR2,
      pEntry                DBA_OP.MAINT_PARTITIONS%ROWTYPE)
   AS
      vExchangeTableNameNoOwner   DBA_TABLES.TABLE_NAME%TYPE;
      vIsPkConstraintAdded        NUMBER := 0;

      CURSOR vCurConstraintDrop (
         vExchangeTableName    VARCHAR2,
         vOtherTableName       VARCHAR2)
      IS
         WITH excTableCon
              AS (-- Drop pk constraints that are on otyher table but not in exchnage table
(SELECT position, column_name
                     FROM dba_cons_columns excCons, dba_constraints consE
                    WHERE     excCons.owner || '.' || excCons.table_name =
                                 vOtherTableName
                          AND consE.constraint_type = 'P'
                          AND excCons.table_name = consE.table_name
                          AND excCons.constraint_name = consE.constraint_name
                          AND excCons.owner = consE.owner
                   MINUS
                   SELECT position, column_name
                     FROM dba_cons_columns excCons, dba_constraints consE
                    WHERE     excCons.owner || '.' || excCons.table_name =
                                 vExchangeTableName
                          AND consE.constraint_type = 'P'
                          AND excCons.table_name = consE.table_name
                          AND excCons.constraint_name = consE.constraint_name
                          AND excCons.owner = consE.owner)
                  UNION
                  -- Drop pk constraints that are on Exchange table but not in Other table
(SELECT position, column_name
                     FROM dba_cons_columns excCons, dba_constraints consE
                    WHERE     excCons.owner || '.' || excCons.table_name =
                                 vExchangeTableName
                          AND consE.constraint_type = 'P'
                          AND excCons.table_name = consE.table_name
                          AND excCons.constraint_name = consE.constraint_name
                          AND excCons.owner = consE.owner
                   MINUS
                   SELECT position, column_name
                     FROM dba_cons_columns excCons, dba_constraints consE
                    WHERE     excCons.owner || '.' || excCons.table_name =
                                 vOtherTableName
                          AND consE.constraint_type = 'P'
                          AND excCons.table_name = consE.table_name
                          AND excCons.constraint_name = consE.constraint_name
                          AND excCons.owner = consE.owner))
         SELECT DISTINCT
                   'ALTER TABLE '
                || consE.owner
                || '.'
                || consE.table_name
                || ' DROP CONSTRAINT '
                || consE.constraint_name
                   AS CMD
           FROM dba_constraints consE, excTableCon excTbl
          WHERE     consE.owner || '.' || consE.table_name =
                       vExchangeTableName
                AND consE.constraint_type = 'P';


      CURSOR vCurConstraintCreate (
         vExchangeTableName                VARCHAR2,
         vOtherTableName                   VARCHAR2,
         vExchangeTableNameWithoutOwner    VARCHAR2)
      IS
         WITH tab_cons
              AS (SELECT DISTINCT cons.owner,
                                  cons.table_name,
                                  cons.index_name,
                                  tablespace_name,
                                  validated,
partitioned
                    FROM dba_constraints  cons,
                         dba_cons_columns conscol,
                         dba_indexes      idx
                   WHERE     CONSTRAINT_TYPE = 'P'
                         AND cons.OWNER || '.' || cons.TABLE_NAME =
                                vOtherTableName
                         AND idx.index_name = cons.index_name
                         AND index_type <> 'LOB'
                         AND cons.constraint_name = conscol.constraint_name
                         AND cons.owner = conscol.owner
                         AND NOT EXISTS
                                (SELECT 1
                                   FROM dba_cons_columns excCons,
                                        dba_constraints  consE
                                  WHERE     excCons.owner || '.' || excCons.table_name =
                                               vExchangeTableName
                                        AND excCons.column_name =
                                               conscol.column_name
                                        AND consE.constraint_type = 'P'
                                        AND consE.constraint_name =
                                               excCons.constraint_name
                                        AND consE.owner = excCons.owner))
         SELECT LISTAGG (CMD) WITHIN GROUP (ORDER BY ROWNUM) AS CMD
           FROM (SELECT ROWNUM,
                           'ALTER TABLE '
                        || vExchangeTableName
                        || ' ADD CONSTRAINT PK_'
                        || vExchangeTableNameWithoutOwner
                        || ' PRIMARY KEY ('
                           AS CMD
                   FROM tab_cons
                 UNION
                 SELECT ROWNUM + 10,
                        DECODE (ROWNUM, 1, '', ',') || column_name AS CMD
                   FROM dba_ind_columns ic, tab_cons cons
                  WHERE ic.index_name = cons.index_name
                 UNION ALL
                 SELECT 1000,
                           ')'
                        || DECODE (partitioned, 'YES', ' ENABLE', ' DISABLE')
                        || DECODE (validated,
                                   'VALIDATED', ' VALIDATE',
                                   ' NOVALIDATE')
                           AS CMD
                   FROM tab_cons
                 ORDER BY 1)
          WHERE CMD IS NOT NULL;

      CURSOR cCurIdxToDrop (
         pOtherTableName       VARCHAR2,
         pExchangeTableName    VARCHAR2)
      IS
         SELECT DISTINCT
                'DROP INDEX ' || i1.index_owner || '.' || i1.index_name
                   AS CMD
           FROM dba_ind_columns i1
          WHERE     i1.table_owner || '.' || i1.table_name =
                       pExchangeTableName
                AND NOT EXISTS
                       (SELECT 1
                          FROM dba_ind_columns  i2,
                               dba_indexes      idx,
                               dba_part_indexes pi
                         WHERE     i2.table_owner || '.' || i2.table_name =
                                      pOtherTableName
                               AND idx.partitioned = 'YES'
                               AND i2.index_owner = idx.owner
                               AND i2.index_name = idx.index_name
                               AND i1.column_name = i2.column_name
AND i1.column_position = i2.column_position
                               AND pi.index_name = idx.index_name
                               AND pi.owner = idx.owner
                               AND pi.locality = 'LOCAL')
                AND (i1.index_name, i1.index_owner) NOT IN
                       (SELECT index_name, owner
                          FROM dba_constraints cons
                         WHERE     constraint_type = 'P'
                               AND cons.owner || '.' || cons.table_name =
                                      pExchangeTableName
                               AND cons.index_name IS NOT NULL);

      /*
       union all
       --indexes that are on exchange table but not in othertable
      select
         distinct 'DROP INDEX ' || i1.index_owner || '.' || i1.index_name as CMD
      from dba_ind_columns i1
        where  i1.table_owner || '.' || i1.table_name = pExchangeTableName
        and not exists (
            select 1
            from dba_ind_columns i2,
                 dba_indexes idx ,
                 dba_part_indexes pi
            where  i2.table_owner || '.' || i2.table_name = pOtherTableName
            and    idx.partitioned    = 'YES'
            and    pi.owner     = idx.owner
            and    pi.index_name      = idx.index_name
            and    pi.locality = 'LOCAL'
            and    i2.index_owner     = idx.owner
            and    i2.index_name      = idx.index_name
            and    i1.column_name     = i2.column_name
            and i1.column_position = i2.column_position
      )
      and (i1.index_name,i1.index_owner ) not in (
          select
            index_name,
            owner
          from dba_constraints cons
          where constraint_type = 'P'
          and cons.owner || '.' || cons.table_name = pExchangeTableName
          and cons.index_name is not null
          );*/

      CURSOR cCurIdxToRecreate (
         pOtherTableName       VARCHAR2,
         pExchangeTableName    VARCHAR2)
      IS
         SELECT DISTINCT i1.index_owner, i1.index_name
           FROM dba_ind_columns i1, dba_indexes idx, dba_part_indexes pi
          WHERE     i1.index_owner || '.' || i1.table_name = pOtherTableName
                AND idx.partitioned = 'YES'
                AND i1.index_name = idx.index_name
                AND i1.index_owner = idx.owner
                AND pi.index_name = idx.index_name
                AND pi.owner = idx.owner
                AND pi.locality = 'LOCAL'
                AND NOT EXISTS
                       (SELECT 1
                          FROM dba_ind_columns i2
                         WHERE     i2.table_owner || '.' || i2.table_name =
                                      pExchangeTableName
                               AND i1.column_name = i2.column_name
AND i1.column_position = i2.column_position)
                AND (i1.index_name, i1.index_owner) NOT IN
                       (SELECT index_name, owner
                          FROM dba_constraints cons
                         WHERE     constraint_type = 'P'
                               AND cons.owner || '.' || cons.table_name =
                                      pOtherTableName
                               AND cons.index_name IS NOT NULL);
   BEGIN
      LogFacility (
         LOG_SEV_INFO,
            'Starting AlignExchangeTable for exchange table '
         || vExchangeTableName,
         pEntry.Table_Name);

      LogFacility (
         LOG_SEV_DEBUG,
         'Align primary key for exchange table ' || vExchangeTableName,
         pEntry.Table_Name);

      -- If primary key constrint is setup differently in Exchange table than in other table, we need to drop it first
      FOR rConstraintDrop
         IN vCurConstraintDrop (vExchangeTableName, vOtherTableName)
      LOOP
         BEGIN
            IF LENGTH (rConstraintDrop.cmd) > 0
            THEN
               ExecSqlCommand (rConstraintDrop.cmd, pEntry.Table_Name);
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               LogFacility (
                  LOG_SEV_ERROR,
                     'Error during constraint drop command :'
                  || rConstraintDrop.cmd
                  || ' con errore : '
                  || SQLERRM
                  || ' [Code: '
                  || TO_CHAR (SQLCODE)
                  || ']',
                  pEntry.Table_Name);
         END;
      END LOOP;

      vExchangeTableNameNoOwner :=
         SUBSTR (pEntry.Partition_Exchange_Table_Name,
                 INSTR (pEntry.Partition_Exchange_Table_Name, '.') + 1);

      -- If needed create the constraint ( this need to be created indipendently if previously has been dropped or not
      FOR rConstraintCreate
         IN vCurConstraintCreate (vExchangeTableName,
                                  vOtherTableName,
                                  vExchangeTableNameNoOwner)
      LOOP
         BEGIN
            IF LENGTH (rConstraintCreate.cmd) > 0
            THEN
               ExecSqlCommand (rConstraintCreate.cmd, pEntry.Table_Name);
               vIsPkConstraintAdded := vIsPkConstraintAdded + 1;
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               LogFacility (
                  LOG_SEV_ERROR,
                     'Error during constraint creation command :'
                  || rConstraintCreate.cmd
                  || ' con errore : '
                  || SQLERRM
                  || ' [Code: '
                  || TO_CHAR (SQLCODE)
                  || ']',
                  pEntry.Table_Name);
         END;
      END LOOP;

      LogFacility (
         LOG_SEV_DEBUG,
            'Finished Align primary key for exchange table '
         || vExchangeTableName,
         pEntry.Table_Name);

      LogFacility (
         LOG_SEV_DEBUG,
            'Start checking if indexes on exchange '
         || vExchangeTableName
         || ' table are aligned  with indexes on '
         || vOtherTableName,
         pEntry.Table_Name);

      -- Drop indexes that are defined differently in the exchange table than in the "Other" table
      FOR rCurIdxToDrop
         IN cCurIdxToDrop (vOtherTableName, vExchangeTableName)
      LOOP
         BEGIN
            IF LENGTH (rCurIdxToDrop.cmd) > 0
            THEN
               ExecSqlCommand (rCurIdxToDrop.cmd, pEntry.Table_Name);
            END IF;
         EXCEPTION
            WHEN OTHERS
            THEN
               LogFacility (
                  LOG_SEV_ERROR,
                     'Error during index drop command :'
                  || rCurIdxToDrop.cmd
                  || ' con errore : '
                  || SQLERRM
                  || ' [Code: '
                  || TO_CHAR (SQLCODE)
                  || ']',
                  pEntry.Table_Name);
         END;
      END LOOP;


      FOR rCurIdxToRecreate
         IN cCurIdxToRecreate (vOtherTableName, vExchangeTableName)
      LOOP
         FOR rIndexToCreate
            IN (WITH coluTbl
                     AS (SELECT ROWNUM + 10 NUMRIGA, CMD
                           FROM (  SELECT column_position,
DECODE (column_position,
                                                     1, '',
                                                     ',')
                                          || column_name
                                             AS CMD
                                     FROM dba_indexes   idx,
                                          dba_ind_columns indcol
                                    WHERE     indcol.index_name =
                                                 rCurIdxToRecreate.index_name
                                          AND indcol.index_owner =
                                                 rCurIdxToRecreate.index_owner
                                          AND idx.owner = indcol.index_owner
                                          AND idx.index_name =
                                                 indcol.index_name
                                 ORDER BY column_position))
                SELECT LISTAGG (CMD) WITHIN GROUP (ORDER BY ROWNUM) AS CMD
                  FROM (SELECT 0,
                                  'CREATE '
                               || DECODE (UNIQUENESS, 'UNIQUE', 'UNIQUE', '')
                               || ' '
                               || DECODE (index_type, 'BITMAP', 'BITMAP', '')
                               || ' INDEX '
                               || OWNER
                               || '.'
                               || SUBSTR (index_name, 1, 22)
                               || LPAD (
                                     TRUNC (DBMS_RANDOM.VALUE (100, 10000)),
                                     4,
                                     '0')
                               || '_EXC ON '
                               || vExchangeTableName
                               || ' ( '
                                  AS CMD
                          FROM dba_indexes idx
                         WHERE     idx.index_name =
                                      rCurIdxToRecreate.index_name
                               AND idx.owner = rCurIdxToRecreate.index_owner
                        UNION
                        SELECT NUMRIGA, CMD FROM coluTbl
                        UNION
                        SELECT 1000, ')' AS CMD
                          FROM dba_indexes
                         WHERE     index_name = rCurIdxToRecreate.index_name
                               AND owner = rCurIdxToRecreate.index_owner
                        ORDER BY 1))
         LOOP
            BEGIN
               IF LENGTH (rIndexToCreate.cmd) > 0
               THEN
                  ExecSqlCommand (rIndexToCreate.cmd, pEntry.Table_Name);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_ERROR,
                        'Error during index creation command :'
                     || rIndexToCreate.cmd
                     || ' con errore : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pEntry.Table_Name);
            END;
         END LOOP;
      END LOOP;

      -- Is in previous steps i created a PK Contraint on Exchnage table, we do not need to check if PK need to be enabled or disabled
      IF vIsPkConstraintAdded = 0
      THEN
         FOR rConstraintEnabDisable
            IN (SELECT    'ALTER TABLE '
                       || cons.owner
                       || '.'
                       || cons.table_name
                       || ' MODIFY CONSTRAINT '
                       || constraint_name
                       || DECODE (idxPartStatus.partitioned,
                                  'YES', ' ENABLE',
                                  ' DISABLE')
                       || DECODE (idxPartStatus.validated,
                                  'VALIDATED', ' VALIDATE',
                                  ' NOVALIDATE')
                          AS CMD
                  FROM dba_constraints cons,
                       (SELECT partitioned, validated
                          FROM dba_constraints cons, dba_indexes idx
                         WHERE     CONSTRAINT_TYPE = 'P'
                               AND cons.OWNER || '.' || cons.TABLE_NAME =
                                      vOtherTablename
                               AND idx.index_name = cons.index_name
                               AND idx.owner = cons.index_owner
                               AND index_type <> 'LOB') idxPartStatus
                 WHERE     cons.owner || '.' || cons.table_name =
                              vExchangeTablename
                       AND CONSTRAINT_TYPE = 'P')
         LOOP
            BEGIN
               IF LENGTH (rConstraintEnabDisable.cmd) > 0
               THEN
                  ExecSqlCommand (rConstraintEnabDisable.cmd,
                                  pEntry.Table_Name);
               END IF;
            EXCEPTION
               WHEN OTHERS
               THEN
                  LogFacility (
                     LOG_SEV_ERROR,
                        'Error during index creation command :'
                     || rConstraintEnabDisable.cmd
                     || ' con errore : '
                     || SQLERRM
                     || ' [Code: '
                     || TO_CHAR (SQLCODE)
                     || ']',
                     pEntry.Table_Name);
            END;
         END LOOP;
      END IF;

      LogFacility (
         LOG_SEV_DEBUG,
            'Finished checking if indexes are aligned for exchange table '
         || vExchangeTableName,
         pEntry.Table_Name);

      LogFacility (
         LOG_SEV_INFO,
            'Finished AlignExchangeTable for exchange table '
         || vExchangeTableName,
         pEntry.Table_Name);
   END;



   PROCEDURE CreateExchangeTable (pEntry DBA_OP.MAINT_PARTITIONS%ROWTYPE)
   AS
      vExchangeTableName    VARCHAR2 (32);
      vExchangeTableOwner   VARCHAR2 (32);

      CURSOR vCurConstraintCreate (
         vTableName                        VARCHAR2,
         vExchangeTableOwner               VARCHAR2,
         vExchangeTableNameWithoutOwner    VARCHAR2)
      IS
         WITH tab_cons
              AS (SELECT cons.owner,
                         cons.table_name,
                         cons.index_name,
                         tablespace_name,
partitioned
                    FROM DBA_CONSTRAINTS cons, dba_indexes idx
                   WHERE     CONSTRAINT_TYPE = 'P'
                         AND cons.OWNER || '.' || cons.TABLE_NAME =
                                vTableName
                         AND idx.index_name = cons.index_name
                         AND index_type <> 'LOB')
         SELECT LISTAGG (CMD) WITHIN GROUP (ORDER BY ROWNUM) AS CMD
           FROM (SELECT ROWNUM,
                           'ALTER TABLE '
                        || vExchangeTableOwner
                        || '.'
                        || vExchangeTableNameWithoutOwner
                        || ' ADD CONSTRAINT PK_'
                        || vExchangeTableNameWithoutOwner
                        || ' PRIMARY KEY ('
                           AS CMD
                   FROM tab_cons
                 UNION
                 SELECT ROWNUM + 10,
                        DECODE (ROWNUM, 1, '', ',') || column_name AS CMD
                   FROM dba_ind_columns ic, tab_cons cons
                  WHERE ic.index_name = cons.index_name
                 UNION ALL
                 SELECT 1000,
                           ')'
                        || DECODE (partitioned, 'YES', 'ENABLE', 'DISABLE')
                           AS CMD
                   FROM tab_cons
                 ORDER BY 1);

      -- Find Indexes that are not PK
      CURSOR vCurIdxToCreate (
         vTableNameWithOwner    VARCHAR2)
      IS
         SELECT idx.owner, idx.index_name
           FROM dba_indexes idx, dba_part_indexes pi
          WHERE     idx.OWNER || '.' || idx.TABLE_NAME = vTableNameWithOwner
                AND partitioned = 'YES'
                AND index_type <> 'LOB'
                AND partitioned = 'YES'
                AND idx.index_name = pi.index_name
                AND pi.owner = idx.owner
                AND pi.locality = 'LOCAL'
                AND (idx.index_name, idx.owner) NOT IN
                       (SELECT index_name, owner
                          FROM dba_constraints cons
                         WHERE     constraint_type = 'P'
                               AND cons.owner || '.' || cons.table_name =
                                      vTableNameWithOwner
                               AND cons.owner = idx.owner);
   BEGIN
      LogFacility (
         LOG_SEV_INFO,
            'Starting Creating Exchange Table : '
         || pEntry.Partition_Exchange_Table_Name,
         pEntry.Table_Name);

      IF (IsPartitionEmpty (pEntry.Partition_Exchange_Table_Name, NULL) != 0)
      THEN
         LogFacility (
            LOG_SEV_WARNING,
               'Exchange Table '
            || pEntry.Partition_Exchange_Table_Name
            || ' already exists. No action will be performed',
            pEntry.Table_Name);
         RETURN;
      END IF;

      -- Exchange Table Name on configuration table has pattern OWNER.TABLE_NAME_EXCHANGE so we need to sort out the owner and table name in order to
      -- This procedure will create a table without constriant exception for primary key. I t will create indsdes like in the primary table partition
      vExchangeTableOwner :=
         SUBSTR (pEntry.Partition_Exchange_Table_Name,
                 1,
                 INSTR (pEntry.Partition_Exchange_Table_Name, '.') - 1);
      vExchangeTableName :=
         SUBSTR (pEntry.Partition_Exchange_Table_Name,
                 INSTR (pEntry.Partition_Exchange_Table_Name, '.') + 1);


      -- Create exchange Table
      ExecSqlCommand (
         ' alter session set events ''14529 trace name context forever, level 2''',
         pEntry.Table_Name);
      ExecSqlCommand (
            'CREATE TABLE '
         || pEntry.Partition_Exchange_Table_Name
         || ' AS SELECT * FROM '
         || pEntry.Table_Name
         || ' WHERE 1=2',
         pEntry.Table_Name);
      ExecSqlCommand (
         ' alter session set events ''14529 trace name context off''',
         pEntry.Table_Name);


      LogFacility (LOG_SEV_INFO,
                   'Creating Exchange Table related constraints',
                   pEntry.Table_Name);

      -- Create PK Contraint and associated Primary Keys
      FOR rConstraintPk
         IN vCurConstraintCreate (pEntry.Table_Name,
                                  vExchangeTableOwner,
                                  vExchangeTableName)
      LOOP
         IF LENGTH (rConstraintPk.cmd) > 0
         THEN
            ExecSqlCommand (rConstraintPk.cmd, pEntry.Table_Name);
         END IF;
      END LOOP;

      LogFacility (LOG_SEV_INFO,
                   'Creating primary key index',
                   pEntry.Table_Name);

      -- Create Indexes other that PK
      FOR rIndexNoPk IN vCurIdxToCreate (pEntry.Table_Name)
      LOOP
         FOR rIndexToCreate
IN (WITH colTbl
                     AS (SELECT ROWNUM + 10 NUMRIGA, CMD
                           FROM (  SELECT column_position,
DECODE (column_position,
                                                     1, '',
                                                     ',')
                                          || column_name
                                             AS CMD
                                     FROM dba_indexes   idx,
                                          dba_ind_columns indcol
                                    WHERE     indcol.index_name =
                                                 rIndexNoPk.index_name
                                          AND indcol.index_owner =
                                                 rIndexNoPk.owner
                                          AND idx.owner = indcol.index_owner
                                          AND idx.index_name =
                                                 indcol.index_name
                                 ORDER BY column_position))
                SELECT LISTAGG (CMD) WITHIN GROUP (ORDER BY ROWNUM) AS CMD
                  FROM (SELECT 0,
                                  'CREATE '
                               || DECODE (UNIQUENESS, 'UNIQUE', 'UNIQUE', '')
                               || ' INDEX '
                               || vExchangeTableOwner
                               || '.'
                               || SUBSTR (index_name, 1, 26)
                               || '_EXC ON '
                               || pEntry.Partition_Exchange_Table_Name
                               || ' ( '
                                  AS CMD
                          FROM dba_indexes idx
                         WHERE     idx.index_name = rIndexNoPk.index_name
                               AND idx.owner = rIndexNoPk.owner
                        UNION
                        SELECT NUMRIGA, CMD FROM colTbl
                        UNION
                        SELECT 1000, ')' AS CMD
                          FROM dba_indexes
                         WHERE     index_name = rIndexNoPk.index_name
                               AND owner = rIndexNoPk.owner
                        ORDER BY 1))
         LOOP
            IF LENGTH (rIndexToCreate.cmd) > 0
            THEN
               ExecSqlCommand (rIndexToCreate.cmd, pEntry.Table_Name);
            END IF;
         END LOOP;
      END LOOP;

      LogFacility (
         LOG_SEV_INFO,
            'Finished creating exchange table :'
         || pEntry.Partition_Exchange_Table_Name,
         pEntry.Table_Name);
   EXCEPTION
      WHEN OTHERS
      THEN
         LogFacility (
            LOG_SEV_ERROR,
               'Error during Exchange Table Creation :'
            || SQLERRM
            || ' [Code: '
            || TO_CHAR (SQLCODE)
            || ']',
            pEntry.Table_Name);
         RAISE;
   END;
END Partitions_Manager;
/



-- Creating JOB
BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB(job_name => 'DBA_OP.MAINT_PARTITIONS_CUS_JOB') ;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Job DBA_OP.MAINT_PARTITIONS_CUS_JOB does not exist');
END;
/



BEGIN
  SYS.DBMS_SCHEDULER.DROP_JOB(job_name => 'DBA_OP.MAINT_PARTITIONS_JOB') ;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Job DBA_OP.MAINT_PARTITIONS_JOB does not exist , but this is not a problem. It will be created later');
END;
/



BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DBA_OP.MAINT_PARTITIONS_JOB'
      ,start_date      => TO_TIMESTAMP_TZ('2019/09/02 11:13:30.812806 Europe/Vienna','yyyy/mm/dd hh24:mi:ss.ff tzr')
      ,repeat_interval => 'FREQ=DAILY; BYHOUR=1; BYMINUTE=0;BYSECOND=0'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'PLSQL_BLOCK'
      ,job_action      => 'DECLARE
    -- Declarations
    var_PTABLENAME   VARCHAR2 (32767);
    var_PDRYRUN      VARCHAR2 (32767);
    var_PLOGLEVEL    VARCHAR2 (32767);
BEGIN
    --Initialization
    var_PTABLENAME := NULL;
    var_PDRYRUN := ''N'';
    var_PLOGLEVEL := ''INFO'';

    -- Call
    DBA_OP.PARTITIONS_MANAGER.STARTMAINTENANCE (
        PTABLENAME   => var_PTABLENAME,
        PDRYRUN      => var_PDRYRUN,
        PLOGLEVEL    => var_PLOGLEVEL);

    -- Transaction Control
    COMMIT;
END;
'
      ,comments        => NULL
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.MAINT_PARTITIONS_JOB'
,attribute => 'RESTARTABLE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.MAINT_PARTITIONS_JOB'
,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.MAINT_PARTITIONS_JOB'
,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.MAINT_PARTITIONS_JOB'
,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.MAINT_PARTITIONS_JOB'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.MAINT_PARTITIONS_JOB'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.MAINT_PARTITIONS_JOB'
,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.MAINT_PARTITIONS_JOB'
     ,attribute => 'AUTO_DROP'
     ,value     => FALSE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DBA_OP.MAINT_PARTITIONS_JOB');
END;
/
