# Service READ ONLY su standby

Usa un servizio role-based solo dopo aver autorizzato Active Data Guard.

```bash
srvctl add service -db <DB_UNIQUE_NAME> -service <APP_RO> \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC
```

Per CDB/PDB aggiungi `-pdb <PDB_NAME>`. Per RAC aggiungi le istanze preferred
approvate. Definisci la configurazione equivalente sui due siti e verifica che
il servizio segua switchover e switchback.

Controlli:

```bash
srvctl config service -db <DB_UNIQUE_NAME>
srvctl status service -db <DB_UNIQUE_NAME>
```

Per configurazione completa:

- [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md)
- [SHAMS PROJECT: ADG e servizi](../../../02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_10_ACTIVE_DATAGUARD_SERVIZI_ROLE_BASED_PEYTECH_19C.md)
