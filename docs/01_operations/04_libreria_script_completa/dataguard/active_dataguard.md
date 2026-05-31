# Active Data Guard (READ ONLY WITH APPLY)

Active Data Guard e' opzionale e richiede verifica licenza in produzione. Il
percorso Data Guard base resta standby `MOUNTED` con Redo Apply.

Sequenza 19c sullo standby:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE OPEN READ ONLY;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

Verifiche:

```sql
SELECT open_mode, database_role FROM v$database;
SELECT process, status, sequence# FROM v$managed_standby;
```

Non usare `USING CURRENT LOGFILE`: e' una clausola storica deprecata. Con SRL
corretti Oracle 19c abilita real-time apply senza quella sintassi.

Approfondimento:

- [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md)
- [SHAMS PROJECT: ADG e servizi](../../../02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_10_ACTIVE_DATAGUARD_SERVIZI_ROLE_BASED_PEYTECH_19C.md)
