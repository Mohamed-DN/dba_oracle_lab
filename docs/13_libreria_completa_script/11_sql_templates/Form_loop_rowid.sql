 
-- creazione tabella rowid
create table FPAD_RSS_OBJ.rowid_trx tablespace FPAD_RSS_data as select /*+ PARALLEL(16) +*/ rowid "RECORD" from FPAD_RSS_OBJ.trx_test where CONDIZIONI;
 
create index fpad_rss_obj.rowid_trx_idx on fpad_rss_obj.rowid_trx (record) tablespace fpad_rss_indx parallel 16;

alter index fpad_rss_obj.rowid_trx_idx noparallel;


-- esecuzione procedura di update
set serveroutput on;
DECLARE
  MAX_RECORDS CONSTANT INTEGER := 20000;
  vCT NUMBER(38) := 0;
BEGIN
  FOR t IN (
        SELECT /*+ PARALLEL(16) +*/ record
        FROM FPAD_RSS_OBJ.rowid_trx
  ) 
  LOOP
    --dbms_output.put_line('delete '||t.id);
    update FPAD_RSS_OBJ.trx_test set ID_PROCESSINGTIMESTAMP_2=ID_PROCESSINGTIMESTAMP WHERE rowid = t.record;
	delete from FPAD_RSS_OBJ.rowid_trx WHERE record = t.record;
    vCT := vCT + 1;
    IF MOD(vCT, MAX_RECORDS) = 0 THEN
        dbms_output.put_line('vCT is '||vCT);
        COMMIT;
    END IF;
  END LOOP;
  COMMIT;
END;
/
 

 
select count(*) from FPAD_RSS_OBJ.rowid_trx;
 
 
drop table FPAD_RSS_OBJ.rowid_trx;