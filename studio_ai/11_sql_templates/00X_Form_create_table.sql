
/*****************************************************************
****                                                          ****
****                        CREATE TABLE                      ****
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

with DATASPOOL noprint new_valueNOME_REPORT

select '<nomescript>_'||to_char(sysdate ,'YYYYMMDDHH24MISS')     DATASPOOL
  from dual ;

spool       &&NOME_REPORT..log

SELECT user FROM dual;


set serveroutput on
set define off

CREATE TABLE <owner>.<tablename>
(
<tablefield>
<tablefield>
<tablefield>
<tablefield>
)
TABLESPACE <nometablespace>;


--If there is a _RO / _RW Role, assign the grants to the role
GRANT  SELECT ON <owner>.<tablename> TO <owner_ruolo_RO>;
GRANT  SELECT, INSERT, UPDATE, DELETE ON <owner>.<tablename> TO <owner_ruolo_RW>;

CREATE SYNONYM <owner_sv>.<tablename> FOR <owner_obj>.<tablename>;

spool off