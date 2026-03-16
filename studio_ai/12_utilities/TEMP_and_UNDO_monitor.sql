CREATE TABLE DBA_OP.TEMP_USE_HISTORY
(
  DATA           DATE,
  SID            NUMBER,
  INST           NUMBER,
  USED_TMP_BLKS  NUMBER,
  MB             NUMBER,
  SEGTYPE        VARCHAR2(9 BYTE),
  TABLESPACE     VARCHAR2(30 BYTE)              NOT NULL,
  USERNAME       VARCHAR2(30 BYTE),
  PROGRAM        VARCHAR2(48 BYTE),
  MACHINE        VARCHAR2(64 BYTE),
  MODULE         VARCHAR2(64 BYTE),
  SERVICE_NAME   VARCHAR2(64 BYTE),
  CURRENT_SQL    VARCHAR2(1000 BYTE),
  LAST_SQL       VARCHAR2(1000 BYTE)
)
TABLESPACE DBA_OP_DATA;


GRANT SELECT ON DBA_OP.TEMP_USE_HISTORY TO PUBLIC;


CREATE TABLE DBA_OP.UNDO_USE_HISTORY
(
  DATA          DATE,
  SID           NUMBER,
  INST          NUMBER,
  USED_UBLK     NUMBER,
  MB            NUMBER,
  USERNAME      VARCHAR2(30 BYTE),
  PROGRAM       VARCHAR2(48 BYTE),
  MACHINE       VARCHAR2(64 BYTE),
  MODULE        VARCHAR2(64 BYTE),
  SERVICE_NAME  VARCHAR2(64 BYTE),
  SQL_TEXT      VARCHAR2(1000 BYTE)
)
TABLESPACE DBA_OP_DATA
MONITORING;


GRANT SELECT ON DBA_OP.UNDO_USE_HISTORY TO PUBLIC;


CREATE OR REPLACE FORCE VIEW DBA_OP.TEMP_USE
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
   BEQUEATH DEFINER
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


CREATE OR REPLACE FORCE VIEW DBA_OP.UNDO_USE
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
   BEQUEATH DEFINER
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




BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
,start_date => SYSTIMESTAMP
      ,repeat_interval => 'FREQ=MINUTELY;INTERVAL=5;'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'PLSQL_BLOCK'
      ,job_action      => 'BEGIN DELETE FROM dba_op.TEMP_USE_HISTORY WHERE data < SYSDATE - 31; INSERT INTO dba_op.TEMP_USE_HISTORY SELECT * FROM dba_op.temp_use WHERE ROWNUM < 10; COMMIT; END;'
,comments => 'deletionDBA_OP.PURGE_TEMP_USE_HISTORY'
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
,attribute => 'RESTARTABLE'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
     ,attribute => 'AUTO_DROP'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_TEMP_USE_HISTORY'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DBA_OP.PURGE_TEMP_USE_HISTORY');
END;
/



BEGIN
  SYS.DBMS_SCHEDULER.CREATE_JOB
    (
       job_name        => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
,start_date => SYSTIMESTAMP
      ,repeat_interval => 'FREQ=MINUTELY;INTERVAL=5;'
      ,end_date        => NULL
      ,job_class       => 'DEFAULT_JOB_CLASS'
      ,job_type        => 'PLSQL_BLOCK'
      ,job_action      => 'BEGIN DELETE FROM dba_op.undo_use_history WHERE data < SYSDATE - 31;INSERT INTO dba_op.undo_use_history SELECT * FROM dba_op.undo_use WHERE ROWNUM < 5;COMMIT;END;'
,comments => 'delete dba_op.undo_use_history'
    );
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
,attribute => 'RESTARTABLE'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
,attribute => 'LOGGING_LEVEL'
     ,value     => SYS.DBMS_SCHEDULER.LOGGING_OFF);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
,attribute => 'MAX_FAILURES');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
,attribute => 'MAX_RUNS');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
     ,attribute => 'STOP_ON_WINDOW_CLOSE'
     ,value     => FALSE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
     ,attribute => 'JOB_PRIORITY'
     ,value     => 3);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE_NULL
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
,attribute => 'SCHEDULE_LIMIT');
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
     ,attribute => 'AUTO_DROP'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
     ,attribute => 'RESTART_ON_RECOVERY'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
     ,attribute => 'RESTART_ON_FAILURE'
     ,value     => TRUE);
  SYS.DBMS_SCHEDULER.SET_ATTRIBUTE
    ( name      => 'DBA_OP.PURGE_UNDO_USE_HISTORY'
     ,attribute => 'STORE_OUTPUT'
     ,value     => TRUE);

  SYS.DBMS_SCHEDULER.ENABLE
    (name                  => 'DBA_OP.PURGE_UNDO_USE_HISTORY');
END;
/
