# Data Guard Management

Riferimenti rapidi per Oracle Data Guard 19c. Le pagine valgono per single
instance e RAC: prima di eseguire un comando identifica ruolo database,
topologia, protection mode e ownership Broker.

## Percorso rapido

| Esigenza | Documento |
| --- | --- |
| Setup e Broker | [Configurazione Data Guard](./configurazione_dataguard.md) |
| Standby aperto in lettura | [Active Data Guard](./active_dataguard.md) |
| Gap e lag | [Verifica gap](./verifica_gap.md) |
| Reporting read-only | [Servizio role-based](./service_read_only.md) |
| Apply fermo dopo reboot | [Recovery post-reboot](./recovery_post_reboot.md) |

## Regole operative

- Il percorso Data Guard base usa standby `MOUNTED` con Redo Apply.
- `READ ONLY WITH APPLY` richiede Active Data Guard autorizzato.
- In 19c avvia apply con `DISCONNECT FROM SESSION`; non usare la clausola
  storica `USING CURRENT LOGFILE`.
- Interroga `V$ARCHIVE_GAP` sullo standby.
- Non inserire password negli argomenti shell.

## Approfondimenti

- [Fase 4: Data Guard Broker](../../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md)
- [SHAMS PROJECT: Network e Broker](../../../02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_09_DATAGUARD_NETWORK_BROKER_PEYTECH_19C.md)
- [Runbook Check Data Guard](../../02_runbooks_incidenti/RUNBOOK_03_CHECK_DATAGUARD.md)
