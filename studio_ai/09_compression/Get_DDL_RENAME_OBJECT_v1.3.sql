
drop function get_object_ddl;
drop type ddl_ty_tb;

CREATE OR REPLACE TYPE ddl_ty AS 
OBJECT (   object_type VARCHAR2(30),   
           orig_schema VARCHAR2(30),
           orig_name   VARCHAR2(30),   
           new_schema  varchar2(30),   
           new_name    VARCHAR2(30),
           orig_ts     VARCHAR2(30), 
           new_ts      VARCHAR2(30), 
           orig_ddl    CLOB ) ;
/ 

CREATE OR REPLACE TYPE ddl_ty_tb AS TABLE OF ddl_ty; 
/

-- Give privileges to the schema that owns the function


define user_schema=FSPADA
Grant execute on dbms_metadata to &USER_SCHEMA;
grant select on dba_tab_comments to &USER_SCHEMA;
grant select on dba_col_comments to &USER_SCHEMA;
 
----------------------------------------------------------------------------- FUNZIONE 
CREATE OR REPLACE FUNCTION get_object_ddl 
(input_values SYS_REFCURSOR)
RETURN ddl_ty_tb PIPELINED  AUTHID CURRENT_USER IS
 
ddl_comments clob;

PRAGMA AUTONOMOUS_TRANSACTION;

-- variables to be passed in by sys_refcursor */ 
object_type  VARCHAR2(30); 
orig_schema  VARCHAR2(30);
new_schema   VARCHAR2(30);
orig_name    VARCHAR2(30); 
new_name     VARCHAR2(30); 
orig_ts      VARCHAR2(30);
new_ts       VARCHAR2(30);


-- setup output record of  TYPE table ddl_ty 

out_rec ddl_ty  := ddl_ty(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL);

/* setup handles to be used for setup and fetching metadata
information handles are used to keep track of the different objects
(DDL) we will be referencing in the PL/SQL code */ 

hOpenOrig   number; 
hModifyOrig NUMBER;  
Orig_ddl    CLOB; 
ret         NUMBER; 
BEGIN   

/* Strip off Attributes not concerned with in DDL. If you are concerned with
     TABLESPACE, STORAGE, or SEGMENT information just comment out these few lines. */   
     

  -- Loop through each of the rows passed in by the reference cursor
  
LOOP
    /* Fetch the input cursor into PL/SQL variables */
    FETCH input_values 
     INTO object_type,
          orig_schema,
          new_schema,
          orig_name,
          new_name,
          orig_ts,
          new_ts
          ;
    EXIT WHEN input_values%NOTFOUND;

    hOpenOrig := dbms_metadata.open(object_type);
    dbms_metadata.set_filter(hOpenOrig,'NAME',orig_name);
    dbms_metadata.set_filter(hOpenOrig,'SCHEMA',orig_schema);

-- REMAP OPTION 

    hModifyOrig := dbms_metadata.add_transform(hOpenOrig,'MODIFY');
 if new_schema is not null 
  then
    dbms_metadata.set_remap_param(hModifyOrig,'REMAP_SCHEMA',orig_schema,null);
 end if;

 if new_name is not null 
  then
    dbms_metadata.set_remap_param(hModifyOrig,'REMAP_NAME',orig_name,new_name);
 end if;

 if new_ts is not null 
 and orig_ts is not null
   then
    dbms_metadata.set_remap_param(hModifyOrig,'REMAP_TABLESPACE',orig_ts,new_ts);
   end if;

-- TRASFORM OPTION 
-- This states to created DDL instead of XML to be compared
hModifyOrig := dbms_metadata.add_transform(hOpenOrig ,'DDL');

 if orig_ts is null 
  then  
    dbms_metadata.set_transform_param(hModifyOrig, 'TABLESPACE', FALSE);   
  end if;

 dbms_metadata.set_transform_param(hModifyOrig, 'PRETTY', TRUE);  
 dbms_metadata.set_transform_param(hModifyOrig, 'SQLTERMINATOR', TRUE);

--dbms_metadata.set_transform_param(hModifyOrig, 'STORAGE', FALSE);  

if object_type='TABLE' then 
  dbms_metadata.set_transform_param(hModifyOrig, 'REF_CONSTRAINTS',FALSE);   
  dbms_metadata.set_transform_param(hModifyOrig, 'CONSTRAINTS',FALSE);   
 ---  dbms_metadata.set_transform_param(hModifyOrig, 'CONSTRAINTS_AS_ALTER',TRUE);   
end if;

---- DA VERIFICARE !!!
---if object_type ='INDEX' then    
-----DBMS_METADATA.SET_TRANSFORM_PARAM ( hModifyOrig, 'PRESERVE_LOCAL' , TRUE); 
---end if ;

--    dbms_metadata.set_transform_param(hModifyOrig, 'SEGMENT_ATTRIBUTES',FALSE);   

    dbms_metadata.set_transform_param(hModifyOrig, 'PRETTY', TRUE);  
    dbms_metadata.set_transform_param(hModifyOrig, 'SQLTERMINATOR', TRUE);
    DBMS_METADATA.set_transform_param (dbms_metadata.session_transform,'SQLTERMINATOR',TRUE);
    DBMS_METADATA.set_transform_param (dbms_metadata.session_transform,'PRETTY', TRUE);
    
    Orig_ddl := dbms_metadata.fetch_clob(hOpenOrig);
    
-- ADD COMMENT ON TABLE    
   if object_type='TABLE' then 
   select  decode ( new_schema,
                    null,
                    decode ( new_name,
                                 null, dbms_metadata.get_dependent_ddl( 'COMMENT', orig_name, orig_schema ),
                                        replace ( dbms_metadata.get_dependent_ddl( 'COMMENT', orig_name, orig_schema ) ,orig_name,new_name ) 
                           ),
                    replace (
                      decode ( new_name,
                                 null, dbms_metadata.get_dependent_ddl( 'COMMENT', orig_name, orig_schema ),
                                       replace ( dbms_metadata.get_dependent_ddl( 'COMMENT', orig_name, orig_schema ) ,orig_name,new_name ) 
                             )
                             ,orig_schema,new_schema
                            ) 
                   ) DDL 
into ddl_comments
    from 
     (select owner,table_name 
        from dba_tab_comments a
       where comments is not null
        and table_name =orig_name
        and owner      =orig_schema) ;
  
      Orig_ddl := Orig_ddl||chr(10)||ddl_comments;
   end if;
   
   ------ FUNCTION OUT
        
      out_rec.object_type := object_type;
      out_rec.orig_schema := orig_schema;
      out_rec.new_schema  := new_schema;
      out_rec.orig_name   := orig_name;
      out_rec.new_name    := new_name;
      out_rec.orig_ts     := orig_ts;
      out_rec.new_ts      := new_ts;
      out_rec.orig_ddl    := Orig_ddl;
      PIPE ROW(out_rec);

    -- Cleanup and release the handles
    dbms_metadata.close(hOpenOrig);

  END LOOP;   
  RETURN; 
END get_object_ddl; 
/ 
------------------------------------------------ TEST
set long 1000000000
SELECT *   FROM 
TABLE(get_object_ddl(CURSOR (SELECT  'TABLE',owner,null,table_name,'INT_'||table_name,tablespace_name,tablespace_name||'COMP'
FROM dba_tables  WHERE owner = 'EQ'
 AND table_name  ='TBEQ_AU_PTLF')));
 
----- SELECT *   FROM 
-----TABLE(get_object_ddl(CURSOR (SELECT object_name, owner, object_type
-----                               FROM dba_objects
-----                              WHERE owner = 'EMP'
-----                                    AND object_type IN
-----                                    ('VIEW',
-----                                         'TABLE',
-----                                         'TYPE',
-----                                         'PACKAGE',
-----                                         'PROCEDURE',
-----                                         'FUNCTION',
-----                                         'SEQUENCE')))); 