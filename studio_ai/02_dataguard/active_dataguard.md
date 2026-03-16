# Active Data Guard (READ ONLY WITH APPLY)

Typical commands:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
ALTER DATABASE OPEN READ ONLY;
```

Verifiche:

```sql
SELECT open_mode, database_role FROM v$database;
SELECT process, status, sequence# FROM v$managed_standby;
```

Approfondimento:

- [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../../GUIDE_PHASE4_DATAGUARD_DGMGRL.md)
