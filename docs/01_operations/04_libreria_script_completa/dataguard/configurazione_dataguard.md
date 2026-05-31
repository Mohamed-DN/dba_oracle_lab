# Configurazione Data Guard: sintesi operativa

## Checklist

1. Verifica `ARCHIVELOG`, `FORCE LOGGING`, FRA e
   `STANDBY_FILE_MANAGEMENT=AUTO`.
2. Crea SRL su primary e standby: online redo group + 1 per thread.
3. Configura password file, alias TNS e listener senza password inline.
4. Crea standby con `RMAN DUPLICATE ... FOR STANDBY`.
5. Avvia Redo Apply sullo standby.
6. Abilita Broker, valida rete e database.
7. Prova switchover e switchback.

```sql
-- Sullo standby montato
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

```text
SHOW CONFIGURATION;
VALIDATE DATABASE <PRIMARY_DB_UNIQUE_NAME>;
VALIDATE DATABASE <STANDBY_DB_UNIQUE_NAME>;
```

## Approfondimenti

- [Fase 4: Data Guard Broker](../../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md)
- [SHAMS PROJECT: Network e Broker](../../../02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_09_DATAGUARD_NETWORK_BROKER_PEYTECH_19C.md)
