# Cheat Sheet DGMGRL (Data Guard Broker)

> [!NOTE]
> **DOCUMENTI CORRELATI - ALTA AFFIDABILITÀ, RAC E DATA GUARD (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cheat Sheet Operativi (Pronto Intervento)**:
>   - **DGMGRL (Broker - questa scheda)**: [CHEAT_SHEET_DGMGRL.md](./CHEAT_SHEET_DGMGRL.md) (lag, switchover rapido, comandi broker).
>   - **SRVCTL & CRSCTL**: [CHEAT_SHEET_SRVCTL_CRSCTL.md](./CHEAT_SHEET_SRVCTL_CRSCTL.md) (gestione risorse cluster RAC e Grid).
>   - **ASMCMD**: [CHEAT_SHEET_ASMCMD.md](./CHEAT_SHEET_ASMCMD.md) (gestione storage ASM).
>   - **Master DBA Cheat Sheet**: [CHEAT_SHEET_MASTER_DBA.md](./CHEAT_SHEET_MASTER_DBA.md) (tutti i comandi consolidati).
> - **Procedure di Produzione (Non-CDB)**:
>   - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
>   - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).
> - **Guide di Laboratorio (RAC 19c Multi-Tenant/CDB)**:
>   - **Preparazione e Creazione Standby (Fase 3)**: [GUIDA_FASE3_RAC_STANDBY.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE3_RAC_STANDBY.md) (RMAN duplicate active database).
>   - **Configurazione Broker DGMGRL (Fase 4)**: [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md) (creazione e ottimizzazione broker).
>   - **Manuale Switchover Completo**: [GUIDA_SWITCHOVER_COMPLETO.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_SWITCHOVER_COMPLETO.md) (passaggi sicuri di switchover).
>   - **Manuale Failover & Reinstate**: [GUIDA_FAILOVER_E_REINSTATE.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FAILOVER_E_REINSTATE.md) (gestione dei disastri e ripristino).

## Obiettivo

Fornire una scheda rapida per gestire Data Guard Broker con DGMGRL: stato, switchover, failover e monitoraggio lag.

## Teoria

- **DGMGRL** controlla Data Guard Broker in modo centralizzato.
- Riduce errori rispetto ai comandi manuali distribuiti tra primary/standby.
- Focus: stato config, lag, readiness switchover, protezione dati.

## Quando usarla

- Check giornaliero replica
- Validazione pre-manutenzione
- Switchover pianificato
- Diagnosi problemi di trasporto/apply redo

## Comandi essenziali

### Read-only (sicuri)

- `SHOW CONFIGURATION;`
- `SHOW DATABASE VERBOSE <db_unique_name>;`
- `SHOW FAST_START FAILOVER;`
- `VALIDATE DATABASE VERBOSE <db_unique_name>;`

### Impattanti (change obbligatoria)

- `SWITCHOVER TO <db_unique_name>;`
- `FAILOVER TO <db_unique_name>;`
- `REINSTATE DATABASE <db_unique_name>;`
- `EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;`

## Procedura operativa

### 1) Pre-check broker

```text
dgmgrl /
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE <primary_db_unique_name>;
SHOW DATABASE VERBOSE <standby_db_unique_name>;
```

### 2) Verifiche SQL supporto

```sql
SELECT name, value, unit FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag','apply finish time');

SELECT process, status, sequence# FROM v$managed_standby;
```

### 3) Switchover pianificato (alto impatto)

```text
VALIDATE DATABASE VERBOSE <target_standby>;
SWITCHOVER TO <target_standby>;
SHOW CONFIGURATION;
```

## Validazione finale

- `SHOW CONFIGURATION` in stato `SUCCESS`
- Lag coerente con SLO
- MRP/RFS attivi lato standby
- Servizi applicativi allineati al nuovo ruolo

## Monitoraggio operativo

- Trasporto redo: `transport lag`
- Apply redo: `apply lag`
- Salute broker: `SHOW CONFIGURATION`
- Readiness: `VALIDATE DATABASE VERBOSE ...`

## Troubleshooting rapido

- **ORA-167xx broker status**: eseguire `VALIDATE DATABASE VERBOSE`, verificare connect identifier e listener
- **Apply fermo**: controllare MRP, SRL, spazio FRA/archivelog
- **Transport lag alto**: verificare rete, async/sync mode, congestione I/O
- **Switchover non pronto**: risolvere warning broker prima del cambio ruolo

## Link correlati

- Runbook: [03 Check Data Guard](../02_runbooks_incidenti/03_CHECK_DATAGUARD.md)
- Command center: [Oracle Tools Command Center](./CHEAT_SHEET_ORACLE_TOOLS_COMMAND_CENTER.md)
- Guida estesa: [GUIDA_FASE4_DATAGUARD_DGMGRL](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md)
- Guida operativa: [GUIDA_SWITCHOVER_COMPLETO](../../02_core_dba/04_high_availability_and_rac/GUIDA_SWITCHOVER_COMPLETO.md)
- Oracle ufficiale: <https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/>
