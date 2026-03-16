######## CREAZIONE VISTE, TABLE E JOB ######## 

-- Connect with DBA_OP user

CREATE OR REPLACE VIEW dba_op.temp_use AS
/* 
   ATTENZIONE la stima dei MB va corretta in base alle dimensioni del blocco *********************************
   sql da v$tempseg_usage e' lultimo eseguito, NON quello in esecuzione nella sesssione, li registro entrambi
   cfr http://yong321.freeshell.org/oranotes/v$sort_usage.txt
   v$tempseg_usage is a synonym of v$sort_usage
*/ 
SELECT SYSDATE data,  s.sid,  t.inst_id inst, 
   t.blocks used_tmp_blks, ROUND(t.blocks*ts.block_size/(1024*1024),0) MB, t.segtype, ts.TABLESPACE_NAME tablespace,  
   s.username, s.program, s.machine, s.MODULE, s.service_name,
   a.sql_text current_sql, a1.sql_text last_sql
FROM gv$tempseg_usage t, gv$session s , gv$sqlarea a, gv$sqlarea a1, dba_tablespaces ts
WHERE 	s.inst_id=t.inst_id AND s.saddr = t.session_addr
AND		s.inst_id=a.inst_id(+) AND s.sql_address=a.address(+)
AND		t.inst_id=a1.inst_id(+) AND t.sqladdr=a1.address(+)
AND     t.TABLESPACE = ts.TABLESPACE_NAME
ORDER BY t.blocks DESC;


SELECT * FROM dba_op.temp_use;

drop table dba_op.TEMP_USE_HISTORY;

CREATE TABLE dba_op.TEMP_USE_HISTORY AS SELECT * FROM dba_op.temp_use WHERE 1=0;

GRANT SELECT ON dba_op.temp_use_history to public;

-- interrogazione utilizzi nel momento di massimo consumo
select * from TEMP_USE_HISTORY
where data = (
   select data from (
      SELECT data, sum(used_tmp_blks) totale  FROM TEMP_USE_HISTORY group by data order by totale desc
   ) where rownum=1
)
;


CREATE OR REPLACE FORCE VIEW dba_op.UNDO_USE
(DATA, SID, INST, USED_UBLK, MB, 
 USERNAME, PROGRAM, MACHINE, MODULE, SERVICE_NAME, 
 SQL_TEXT)
AS 
SELECT  SYSDATE data,
		s.sid, t.inst_id inst,
        t.used_ublk, ROUND(t.used_ublk*16/1024,0) MB,
		s.username, s.program, s.machine, s.MODULE, s.service_name,
		a.sql_text
FROM gv$session s, gv$transaction t, gv$sqlarea a
WHERE 	s.inst_id=t.inst_id(+)
AND		s.inst_id=a.inst_id(+)
AND		s.saddr = t.ses_addr
AND   s.sql_address=a.address(+)
AND s.username IS NOT NULL
AND t.used_ublk > 1000
ORDER BY t.used_ublk DESC;
/

CREATE TABLE dba_op.UNDO_USE_HISTORY AS SELECT * FROM dba_op.undo_use WHERE 1=0;

GRANT SELECT ON dba_op.UNDO_USE_HISTORY TO PUBLIC;


-- JOB CREATION

DECLARE
  X NUMBER;
BEGIN
  SYS.DBMS_JOB.SUBMIT
  ( job       => X 
   ,what      => 'BEGIN 
DELETE FROM dba_op.TEMP_USE_HISTORY WHERE data < SYSDATE - 31; 
INSERT INTO dba_op.TEMP_USE_HISTORY SELECT * FROM dba_op.temp_use WHERE ROWNUM < 10; 
COMMIT; 
END;'
   ,next_date => to_date('29/09/2017 09:00:00','dd/mm/yyyy hh24:mi:ss')
   ,interval  => 'SYSDATE+5/1440'
   ,no_parse  => FALSE
  );
  SYS.DBMS_OUTPUT.PUT_LINE('Job Number is: ' || to_char(x));
COMMIT;
END;
/


DECLARE
  X NUMBER;
BEGIN
  SYS.DBMS_JOB.SUBMIT
  ( job       => X 
   ,what      => 'BEGIN
DELETE FROM dba_op.undo_use_history WHERE data < SYSDATE - 31;
--DELETE FROM sisal_dba.undo_space_detail_history WHERE data < SYSDATE - 31;
INSERT INTO dba_op.undo_use_history SELECT * FROM dba_op.undo_use WHERE ROWNUM < 5;
--INSERT INTO sisal_dba.undo_space_detail_history SELECT * FROM sisal_dba.undo_space_detail;
COMMIT;
END;'
   ,next_date => to_date('25/08/2017 16:11:50','dd/mm/yyyy hh24:mi:ss')
   ,interval  => 'SYSDATE+5/1440'
   ,no_parse  => FALSE
  );
  SYS.DBMS_OUTPUT.PUT_LINE('Job Number is: ' || to_char(x));
COMMIT;
END;
/


