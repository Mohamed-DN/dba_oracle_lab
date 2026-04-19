# Active Data Guard (READ ONLY WITH APPLY)

Comandi tipici:

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

- [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../../GUIDA_FASE4_DATAGUARD_DGMGRL.md)
