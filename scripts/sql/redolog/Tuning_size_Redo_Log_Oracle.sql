-- Source: https://www.scriptdba.com/tuning-size-redo-log-oracle/
-- Title: Tuning size Redo Log Oracle

GROUP# MEMBER                              STATUS                  Size MB
------- ----------------------------------- -------------------- ----------
      1 /dati/XE/redo01.log                 CURRENT                     200
      2 /dati/XE/redo02.log                 INACTIVE                    200
      3 /dati/XE/redo03.log                 ACTIVE                      200

GROUP# MEMBER                              STATUS                  Size MB
------- ----------------------------------- -------------------- ----------
      1 /dati/XE/redo01.log                 CURRENT                     200
      2 /dati/XE/redo02.log                 INACTIVE                    200
      3 /dati/XE/redo03.log                 ACTIVE                      200

alter database add logfile group 4 '/dati/XE/redo04.log' size 300M;
 alter database add logfile group 5 '/dati/XE/redo05.log' size 300M;
 alter database add logfile group 6 '/dati/XE/redo06.log' size 300M;

alter database add logfile group 4 '/dati/XE/redo04.log' size 300M;
 alter database add logfile group 5 '/dati/XE/redo05.log' size 300M;
 alter database add logfile group 6 '/dati/XE/redo06.log' size 300M;

alter system checkpoint;
alter system switch logfile;

alter system checkpoint;
alter system switch logfile;

alter database drop logfile group 1;
alter database drop logfile group 2;
alter database drop logfile group 3;

alter database drop logfile group 1;
alter database drop logfile group 2;
alter database drop logfile group 3;

