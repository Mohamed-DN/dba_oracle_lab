-- Source: https://www.scriptdba.com/come-estendere-una-tablespace-oracle/
-- Title: Come estendere un TABLESPACE Oracle

alter database datafile '/path/nome_datafile' resize --dimensione_datafile;

alter database datafile '/path/nome_datafile' resize --dimensione_datafile;

alter database datafile '/DBTEST_DATI/DBTEST/DATI01.DBF' resize 512m;

alter database datafile '/DBTEST_DATI/DBTEST/DATI01.DBF' resize 512m;

alter database datafile '/path/nome_datafile' autoextend on next --dimensione_extent maxsize --dimenizione_maxsize;

alter database datafile '/path/nome_datafile' autoextend on next --dimensione_extent maxsize --dimenizione_maxsize;

alter database datafile '/DBTEST_DATI/DBTEST/DATI01.DBF' autoextend on next 128m maxsize 1024m;

alter database datafile '/DBTEST_DATI/DBTEST/DATI01.DBF' autoextend on next 128m maxsize 1024m;

alter tablespace --nome_tablespace add datafile '/path/nome_datafile03' size --dimensione_datafile;

alter tablespace --nome_tablespace add datafile '/path/nome_datafile03' size --dimensione_datafile;

alter tablespace DATI add datafile '/DBTEST_DATI/DBTEST/DATI03.dbf' size 2048m;

alter tablespace DATI add datafile '/DBTEST_DATI/DBTEST/DATI03.dbf' size 2048m;

alter tablespace --nome_tablespace add datafile '/path/nome_datafile03' size --dimensione_initial_extent autoextend on next --dimensione_extent_successivi maxsize --dimensione_maxsize;

alter tablespace --nome_tablespace add datafile '/path/nome_datafile03' size --dimensione_initial_extent autoextend on next --dimensione_extent_successivi maxsize --dimensione_maxsize;

alter tablespace DATI add datafile '/DBTEST_DATI/DBTEST/DATI03.dbf' size 256m autoextend on next 256m maxsize 5096m;

alter tablespace DATI add datafile '/DBTEST_DATI/DBTEST/DATI03.dbf' size 256m autoextend on next 256m maxsize 5096m;

