/*****************************************************************
****                                                          ****
****               PL/SQL WITH PARTIAL COMMIT                 ****
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
set linesize 300
set trim on
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

ACCEPT val PROMPT "INSERIRE IL VALORE PER L'INTERVALLO DI COMMIT >"

SELECT user FROM dual;

set serveroutput on 
set define off


DECLARE
        err_num         NUMBER;
        err_msg         VARCHAR2(100);  
        nrows                   INTEGER := 0;
        time_var                CHAR(20);

        -- Exctract rowid
        CURSOR cr_GROUPID IS
                SELECT rowid
                FROM <nome_tabella>
                where    <condizione> ;
BEGIN
        DBMS_OUTPUT.ENABLE(1000000);

        -- debug 
        -- time_var := TO_CHAR(SYSDATE,'DD-MON-YY HH24:MI:SS');
        -- DBMS_OUTPUT.PUT_LINE('Time: '||time_var||' - passo 1');

        -- Fetch from the cursor
        FOR riga IN cr_GROUPID
        LOOP
                nrows := nrows + 1;

                -- Es: update records identified by rowid
                -- UPDATE <nome_tabella>
                -- SET <modifiche>
                -- WHERE rowid = riga.rowid;

                -- Es: delete records identified by rowid
                -- DELETE <nome_tabella>
                -- WHERE rowid = riga.rowid;

                -- Commit after 1(parameter) records
                IF MOD(cr_GROUPID%ROWCOUNT, &val) = 0 THEN
                        DBMS_OUTPUT.PUT_LINE (cr_GROUPID%ROWCOUNT||' COMMIT');
                        COMMIT;
            END IF;
        END LOOP;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE ('Righe processate: '||nrows);
        time_var := TO_CHAR(SYSDATE,'DD-MON-YY HH24:MI:SS');
        DBMS_OUTPUT.PUT_LINE ('Time: '||time_var);                                                              

EXCEPTION 
WHEN OTHERS THEN
        err_num := SQLCODE;
        err_msg := SUBSTR(SQLERRM, 1, 100);
        DBMS_OUTPUT.PUT_LINE ('OPERAZIONE FALLITA');
        DBMS_OUTPUT.PUT_LINE ('Righe processate: '||nrows);
        DBMS_OUTPUT.PUT_LINE(chr(10));
        DBMS_OUTPUT.PUT_LINE('ERROR:'||err_num||' '||err_msg);
        IF cr_GROUPID%ISOPEN THEN
                CLOSE cr_GROUPID;
        END IF;
        -- Rollback the transaction
        ROLLBACK;
END;
/

spool off