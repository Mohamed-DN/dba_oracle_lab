
/*****************************************************************
****                                                          ****
****                CREATE VIEW                               ****
****                                                          ****
******************************************************************

SCRIPT NAME      : XXXXNNNNDDDD(_ROLLBACK).sql   

AUTHOR           : Name, First Name (phone xxx)   

RESPONSIBLE      : Name, First Name (phone xxx)   

SYSTEM           :

MODULE           : 

VERSION          : 1.1 - DD/MM/YYYY 
                   1.2 - DD/MM/YYYY - Modification Description
                   1.3 - DD/MM/YYYY - Modification Description
                   
DESCRIPTION      :

CONSTRAINT       :

WARNING          :

DATABASE         : DATABASE1,DATABASE2,DATABASE3,....

SCHEMA           : 
         
*****************************************************************
*****************************************************************/

set time on
set timing on
set echo on
set head off
set define on

WHENEVER SQLERROR EXIT FAILURE ROLLBACK;

REM********************************
REM* Change the spool logfile name
REM********************************

col DATASPOOL noprint new_value NOME_REPORT

select '<nomescript>_'||to_char(sysdate ,'YYYYMMDDHH24MISS')     DATASPOOL
  from dual ;

spool      &&NOME_REPORT..log

SELECT user FROM dual;


set serveroutput on
set define off

CREATE OR REPLACE VIEW <owner>.<nomeview> as 
	<subquery>
;

GRANT SELECT ON <owner>.<nomeview> TO <utente_ruolo_ro>;
GRANT SELECT ON <owner>.<nomeview> TO <utente_ruolo_rw>;

spool off
