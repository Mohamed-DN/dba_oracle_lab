----------
-- DOCS --
----------

How to perform Flashback in a Data Guard/RAC- Environment (Doc ID 1342165.1)
How To Flashback Primary Database In Standby Configuration (Doc ID 728374.1)

-------------------------------
-- ATTIVAZIONE RESTORE POINT --
-------------------------------

-- DESCHEDULE DELETE ARCHIVELOG SCRIPT ON THE DR SERVER

commentare script

-- STOP APPLY
-- Per avere una seconda modalità di restore già pronta

dgmgrl
connect sys
show configuration
show database 'INBDRDB';
edit database 'INBDRDB' set state = 'APPLY-OFF';
exit

-- RESTORE POINT ON INBDRDB

show parameter reco
show parameter flashback
alter database flashback on;

-- su DB primario

alter system archive log current;

-- su DB standby

select flashback_on from v$database;
select * from V$FLASHBACK_DATABASE_LOG;

col current_scn for 999999999999999
select current_scn from v$database;

     CURRENT_SCN
----------------
   6108811009511

create restore point before_fix guarantee flashback database;
select * from v$restore_point;

-- RESTORE POINT ON INBANDB

show parameter reco
show parameter flashback
alter database flashback on;

select flashback_on from v$database;
select * from V$FLASHBACK_DATABASE_LOG;

col current_scn for 999999999999999
select current_scn from v$database;

     CURRENT_SCN
----------------
   6108811011829

create restore point before_fix guarantee flashback database;
select * from v$restore_point;

Sun Oct 22 19:42:17 2017
alter database flashback on
Sun Oct 22 19:42:17 2017
RVWR started with pid=206, OS id=20667
Allocated 285630400 bytes in shared pool for flashback generation buffer
Sun Oct 22 19:42:42 2017
Flashback Database Enabled at SCN 6108811011713
Completed: alter database flashback on
Sun Oct 22 19:43:12 2017
Created guaranteed restore point BEFORE_FIX

...
...
...
...

-- CHECK RICEZIONE ARCHIVELOGS SU STANDBY
-- CHECK FRA SU STANDBY
-- CHECK FRA SU PRIMARIO

-------------------------
-- RIMOZIONE FLASHBACK --
-------------------------

-- DROP RESTORE POINT su entrambi i DB!!!

drop restore point before_fix;
alter database flashback off;

-- RESTART APPLY SU STANDBY

dgmgrl
connect sys
show configuration
edit database 'INBDRDB' set state = 'APPLY-ON';
exit

-- Rischedulare DELETE ARCHIVELOG sullo standby

--------------------------
-- IN CASO DI FLASHBACK --
--------------------------

-- How to determine the required archivelog files for a guaranteed restore point (Doc ID 1524217.1)

  SELECT DISTINCT al.thread#, al.sequence#, al.resetlogs_change#, al.resetlogs_time
    FROM v$archived_log al,
         (select grsp.rspfscn               from_scn,
                 grsp.rspscn                to_scn,
                 dbinc.resetlogs_change#    resetlogs_change#,
                 dbinc.resetlogs_time       resetlogs_time
            from x$kccrsp grsp,  v$database_incarnation dbinc
           where grsp.rspincarn = dbinc.incarnation#
             and bitand(grsp.rspflags, 2) != 0
             and bitand(grsp.rspflags, 1) = 1 -- guaranteed
             and grsp.rspfscn <= grsp.rspscn -- filter clean grp
             and grsp.rspfscn != 0
         ) grsp
      WHERE al.next_change#   >= grsp.from_scn
          AND al.first_change#    <= (grsp.to_scn + 1)
          AND al.resetlogs_change# = grsp.resetlogs_change#
          AND al.resetlogs_time       = grsp.resetlogs_time
          AND al.archived = 'YES';




