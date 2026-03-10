Ciao, NPG è tornata sulla gestione delle code Oracle (rimpiazzate dal modello Kafka, che dopo il deploy di oggi non funziona come da attese)


-- grant da dare anche all'utente OWNER delle queue tables per corretto funzionamento
grant AQ_ADMINISTRATOR_ROLE      to dba_change;
grant execute on DBMS_AQ         to dba_change;
grant execute on DBMS_AQADM      to dba_change;
grant execute on DBMS_AQ_BQVIEW  to dba_change;
grant execute on DBMS_LOCK       to dba_change;
grant AQ_ADMINISTRATOR_ROLE      to phoenix_obj;
grant execute on DBMS_AQ         to phoenix_obj;
grant execute on DBMS_AQADM      to phoenix_obj;
grant execute on DBMS_AQ_BQVIEW  to phoenix_obj;
grant execute on DBMS_LOCK       to phoenix_obj;


-- query per visualizzare lo stato delle code
set lines 500;
col queue for a70;
col queue_table for a40
col owner for a30;
col name for a30;

SELECT owner||'.'||name as "Queue", queue_type, queue_table, waiting, ready, expired, enqueue_enabled, dequeue_enabled
FROM dba_queues q
JOIN gv$aq v ON q.qid = v.qid
where owner = 'PHOENIX_OBJ'
order by 1;


-- Queue                                                                  QUEUE_TYPE           QUEUE_TABLE                       WAITING      READY    EXPIRED ENQUEUE DEQUEUE
-- ---------------------------------------------------------------------- -------------------- ------------------------------ ---------- ---------- ---------- ------- -------
-- ENEA.AQ$_OBJMSGS_QTAB_BATCH_E                                          EXCEPTION_QUEUE      OBJMSGS_QTAB_BATCH                      0          0          0   NO      NO
-- ENEA.AQ$_OBJMSGS_QTAB_DPAN_E                                           EXCEPTION_QUEUE      OBJMSGS_QTAB_DPAN                       0          0          0   NO      NO
-- ENEA.AQ$_OBJMSGS_QTAB_E                                                EXCEPTION_QUEUE      OBJMSGS_QTAB                            0          0          0   NO      NO
-- ENEA.MSG_QUEUE                                                         NORMAL_QUEUE         OBJMSGS_QTAB                            0        -11          0   YES     YES
-- ENEA.MSG_QUEUE_BATCH                                                   NORMAL_QUEUE         OBJMSGS_QTAB_BATCH                      0          0          0   YES     YES
-- ENEA.MSG_QUEUE_DPAN                                                    NORMAL_QUEUE         OBJMSGS_QTAB_DPAN                       0          0          0   YES     YES
-- 
-- 6 rows selected.



-- comandi per start/stop delle code

-- exec DBMS_AQADM.START_QUEUE(QUEUE_NAME,ENQUEUE,DEQUEUE);  

exec DBMS_AQADM.START_QUEUE('PHOENIX_OBJ.TRXDENORMALIZATIONINITIATORQ',TRUE,TRUE);  
exec DBMS_AQADM.START_QUEUE('PHOENIX_OBJ.TRXDENORMALIZATIONERRORQ',TRUE,TRUE);  
exec DBMS_AQADM.STOP_QUEUE('PHOENIX_OBJ.TRXDENORMALIZATIONINITIATORQ');  
exec DBMS_AQADM.STOP_QUEUE('PHOENIX_OBJ.TRXDENORMALIZATIONERRORQ');  




-- purge della queue table associata alla queue
DECLARE
po_t dbms_aqadm.aq$_purge_options_t;
BEGIN
  dbms_aqadm.purge_queue_table('PHOENIX_OBJ.TRXDENORMALIZATIONINITIATORQ_T', NULL, po_t);
END;
/



-- tabella di log delle eccezioni in fase di enqueue/dequeue generale per PHOENIX_OBJ.
-- con questa select vengono visualizzati tutti gli errori più recenti 

select * from PHOENIX_OBJ.ERROR_LOG
where error_time > trunc(sysdate)
order by error_time
/


