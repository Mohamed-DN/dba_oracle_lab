SELECT TT.TABLESPACE_NAME TBS_NAME, 
       ROUND(USED_SPACE*TT.BLOCK_SIZE/1024/1024) USED_MB, 
       ROUND(TABLESPACE_SIZE*TT.BLOCK_SIZE/1024/1024) MAX_TBSP_SIZE_IN_MB, 
       ROUND(USED_PERCENT,2) USED_PERCENT
FROM DBA_TABLESPACE_USAGE_METRICS UM, DBA_TABLESPACES TT
WHERE UM.TABLESPACE_NAME = TT.TABLESPACE_NAME AND TT.TABLESPACE_NAME = 'SYSAUX'
ORDER BY 4;

select occupant_desc, space_usage_kbytes/1024 MB from v$sysaux_occupants where space_usage_kbytes > 0 order by space_usage_kbytes; 

col owner for a22
col segment_name for a33
select owner, segment_name, segment_type, round(sum(bytes/1024/1024)) MB, count(1) from dba_segments where tablespace_name='SYSAUX' 
group by owner, segment_name, segment_type having round(sum(bytes/1024/1024)) > 500 order by 4;

set timing on

alter table WRH$_LATCH enable row movement;
alter table WRH$_LATCH shrink space cascade;
alter table WRH$_LATCH disable row movement;

alter table WRH$_LATCH_MISSES_SUMMARY enable row movement;
alter table WRH$_LATCH_MISSES_SUMMARY shrink space cascade;
alter table WRH$_LATCH_MISSES_SUMMARY disable row movement;

alter table WRH$_ACTIVE_SESSION_HISTORY enable row movement;
alter table WRH$_ACTIVE_SESSION_HISTORY shrink space cascade;
alter table WRH$_ACTIVE_SESSION_HISTORY disable row movement;

alter table WRH$_SYSSTAT enable row movement; 
alter table WRH$_SYSSTAT shrink space cascade;
alter table WRH$_SYSSTAT disable row movement;

alter table WRH$_SQLSTAT enable row movement;
alter table WRH$_SQLSTAT shrink space cascade;
alter table WRH$_SQLSTAT disable row movement;

alter table WRH$_EVENT_HISTOGRAM enable row movement;
alter table WRH$_EVENT_HISTOGRAM shrink space cascade;
alter table WRH$_EVENT_HISTOGRAM disable row movement;

alter table WRH$_SERVICE_STAT enable row movement;
alter table WRH$_SERVICE_STAT shrink space cascade;
alter table WRH$_SERVICE_STAT disable row movement;

alter table WRH$_PARAMETER enable row movement;
alter table WRH$_PARAMETER shrink space cascade;
alter table WRH$_PARAMETER disable row movement;

alter table WRI$_OPTSTAT_SYNOPSIS$ enable row movement;
alter table WRI$_OPTSTAT_SYNOPSIS$ shrink space cascade;
alter table WRI$_OPTSTAT_SYNOPSIS$ disable row movement;

alter table WRH$_CON_SYSSTAT enable row movement;
alter table WRH$_CON_SYSSTAT shrink space cascade;
alter table WRH$_CON_SYSSTAT disable row movement;

alter table WRH$_CON_SYSTEM_EVENT enable row movement;
alter table WRH$_CON_SYSTEM_EVENT shrink space cascade;
alter table WRH$_CON_SYSTEM_EVENT disable row movement;

-- WRI$_OPTSTAT_HISTGRM_HISTORY cannot be shrinked... should contain 1 month of data

select min(SAVTIME) from SYS.WRI$_OPTSTAT_HISTGRM_HISTORY;
alter index I_WRI$_OPTSTAT_H_OBJ#_ICOL#_ST shrink space;
alter index I_WRI$_OPTSTAT_H_ST shrink space;

select min(SAVTIME) from SYS.WRI$_OPTSTAT_HISTHEAD_HISTORY;
alter index I_WRI$_OPTSTAT_HH_OBJ_ICOL_ST shrink space;
alter index I_WRI$_OPTSTAT_HH_ST shrink space;

-- WRH$_ACTIVE_SESSION_HISTORY Does Not Get Purged Based Upon the Retention Policy (Doc ID 387914.1)

exec DBMS_WORKLOAD_REPOSITORY.DROP_SNAPSHOT_RANGE(1,100);

-- Usage and Storage Management of SYSAUX tablespace occupants SM/AWR, SM/ADVISOR, SM/OPTSTAT and SM/OTHER (Doc ID 329984.1)
select min(BEGIN_INTERVAL_TIME) from dba_hist_snapshot;
exec DBMS_STATS.PURGE_STATS(to_timestamp_tz('01-09-2006 00:00:00 Europe/London','DD-MM-YYYY HH24:MI:SS TZR'));
exec DBMS_STATS.PURGE_STATS(sysdate-30);

-- Automatic SQL Tuning Sets (ASTS) 19c RU 19.7 Onwards (Doc ID 2686869.1)

Begin
DBMS_Auto_Task_Admin.Disable(
Client_Name => 'Auto STS Capture Task',
Operation => NULL,
Window_name => NULL);
End;
/

-- AUTOMATIC SQL TUNING SETS

Automatic SQL Tuning Sets (ASTS) 19c RU 19.7 Onwards (Doc ID 2686869.1)
How to clear SYSAUX space consumption by WRI$_SQLSET_PLAN_LINES (Doc ID 2857648.1)

https://community.oracle.com/mosc/discussion/4329725/oracle-19-7-se2-sysaux-growing-because-of-wri-sqlset-plan-lines

select count(1) from WRI$_SQLSET_PLAN_LINES;
select count(1) from WRI$_SQLSET_PLANS;
select count(1) from WRI$_SQLSET_STATISTICS;
select count(1) from WRI$_SQLSET_STATEMENTS;
select count(1) from WRI$_SQLTEXT_REFCOUNT;
select count(1) from WRI$_SQLSET_MASK;

truncate table WRI$_SQLSET_PLAN_LINES;
truncate table WRI$_SQLSET_PLANS;
truncate table WRI$_SQLSET_STATISTICS;
truncate table WRI$_SQLSET_STATEMENTS;
truncate table WRI$_SQLTEXT_REFCOUNT;
truncate table WRI$_SQLSET_MASK;

https://mikedietrichde.com/2020/05/28/do-you-love-unexpected-surprises-sys_auto_sts-in-oracle-19-7-0/

-- STATISTICS ADVISOR
-- SYSAUX Tablespace Grows Rapidly After Upgrading Database to 12.2.0.1 or Above Due To Statistics Advisor (Doc ID 2305512.1)
-- How To Purge Optimizer Statistics Advisor Old Records From 12.2 Onwards (Doc ID 2660128.1)
-- NEXI: GBWEB(P1AVP, P1SECP, P1RSKP, P1WCBP) pulite 07 maggio 25
-- SIA: RABNLP,RAMPSP,RAEDKP,RACSIP / GTATMGEP / MIRP / FALCON / T2SMTX / pwcdbpep/sep

OWNER                  SEGMENT_NAME                      SEGMENT_TYPE               MB   COUNT(1)
---------------------- --------------------------------- ------------------ ---------- ----------
SYS                    WRI$_ADV_OBJECTS_PK               INDEX                    2758          1
SYS                    WRI$_ADV_OBJECTS_IDX_02           INDEX                    3530          1
SYS                    WRI$_ADV_OBJECTS_IDX_01           INDEX                    4145          1
SYS                    WRI$_ADV_OBJECTS                  TABLE                    8390          1

set timing on

SELECT COUNT(*) CNT FROM DBA_ADVISOR_OBJECTS WHERE TASK_NAME ='AUTO_STATS_ADVISOR_TASK';

SELECT COUNT(*) FROM WRI$_ADV_OBJECTS WHERE TASK_ID=(SELECT DISTINCT ID FROM WRI$_ADV_TASKS WHERE NAME='AUTO_STATS_ADVISOR_TASK');

CREATE TABLE WRI$_ADV_OBJECTS_NEW AS SELECT * FROM WRI$_ADV_OBJECTS WHERE TASK_ID !=(SELECT DISTINCT ID FROM WRI$_ADV_TASKS WHERE NAME='AUTO_STATS_ADVISOR_TASK');
SELECT COUNT(*) FROM WRI$_ADV_OBJECTS_NEW;

TRUNCATE TABLE WRI$_ADV_OBJECTS;

INSERT INTO WRI$_ADV_OBJECTS("ID" ,"TYPE" ,"TASK_ID" ,"EXEC_NAME" ,"ATTR1" ,"ATTR2" ,"ATTR3" ,"ATTR4" ,"ATTR5" ,"ATTR6" ,"ATTR7" ,"ATTR8" ,"ATTR9" ,"ATTR10","ATTR11","ATTR12","ATTR13","ATTR14","ATTR15","ATTR16","ATTR17",
"ATTR18","ATTR19","ATTR20","OTHER" ,"SPARE_N1" ,"SPARE_N2" ,"SPARE_N3" ,"SPARE_N4" ,"SPARE_C1" ,"SPARE_C2" ,"SPARE_C3" ,"SPARE_C4" ) 
SELECT "ID" ,"TYPE" ,"TASK_ID" ,"EXEC_NAME" ,"ATTR1" ,"ATTR2" ,"ATTR3" ,"ATTR4" ,"ATTR5" ,"ATTR6" ,"ATTR7" ,"ATTR8" ,"ATTR9" , "ATTR10","ATTR11","ATTR12","ATTR13","ATTR14","ATTR15","ATTR16","ATTR17","ATTR18","ATTR19",
"ATTR20","OTHER" ,"SPARE_N1" , "SPARE_N2" ,"SPARE_N3" ,"SPARE_N4" ,"SPARE_C1" ,"SPARE_C2" ,"SPARE_C3" ,"SPARE_C4" FROM WRI$_ADV_OBJECTS_NEW;

COMMIT;

DECLARE
v_tname VARCHAR2(32767);
BEGIN
v_tname := 'AUTO_STATS_ADVISOR_TASK';
DBMS_STATS.DROP_ADVISOR_TASK(v_tname);
END;
/

EXEC DBMS_STATS.INIT_PACKAGE();

DROP TABLE WRI$_ADV_OBJECTS_NEW PURGE;

-- How To Disable Optimizer Statistics Advisor From 12.2 Onwards (Doc ID 2686022.1)

-- HEATMAP
-- HEATMAP Segment Size Is Large In SYSAUX Even When Heatmap=Off (Doc ID 2024036.1)

col owner for a22
col segment_name for a33
select owner, segment_name, segment_type, round(sum(bytes/1024/1024)) MB, count(1) from dba_segments where tablespace_name='SYSAUX'
group by owner, segment_name, segment_type having round(sum(bytes/1024/1024)) > 500 order by 4;

OWNER                  SEGMENT_NAME                      SEGMENT_TYPE               MB   COUNT(1)
---------------------- --------------------------------- ------------------ ---------- ----------
XDB                    SYS_LOB0000057047C00025$$         LOBSEGMENT                502          1
SYS                    HEATMAP                           SYSTEM STATISTICS        1378          1

ALTER SYSTEM SET "_drop_stat_segment" =1;

select owner, segment_name, segment_type, round(sum(bytes/1024/1024)) MB, count(1) from dba_segments where tablespace_name='SYSAUX'
group by owner, segment_name, segment_type having round(sum(bytes/1024/1024)) > 500 order by 4;

OWNER                  SEGMENT_NAME                      SEGMENT_TYPE               MB   COUNT(1)
---------------------- --------------------------------- ------------------ ---------- ----------
XDB                    SYS_LOB0000057047C00025$$         LOBSEGMENT                502          1

-- How to Manually Purge Orphan Rows from AWR Repository Tables In Sysaux Tablespace (Doc ID 2536631.1)