# 03 - Check Data Guard

## Obiettivi

Separare rapidamente problemi di trasporto, apply, gap, spazio e Broker senza
eseguire correzioni distruttive. Usa questo runbook per morning check,
pre-switchover e incidenti di lag.

## Script pronti collegati

- [09_dataguard_status.sql](../03_scripts_pronti/09_dataguard_status.sql) -
  ruolo, lag, gap, MRP e readiness.
- [03_fra_archivelog.sql](../03_scripts_pronti/03_fra_archivelog.sql) -
  FRA, archivelog e deletion policy.

## Procedura operativa

### 1. Identifica i ruoli

Esegui sui due siti:

```sql
SELECT name, db_unique_name, database_role, open_mode,
       protection_mode, switchover_status
FROM v$database;
```

Atteso:

- un solo `PRIMARY`;
- un solo `PHYSICAL STANDBY`;
- standby `MOUNTED` oppure `READ ONLY WITH APPLY` se ADG e' autorizzato.

### 2. Controlla il trasporto sul primary

```sql
SELECT dest_id, status, target, destination, error
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

SELECT dest_id, status, type, database_mode, recovery_mode, gap_status
FROM v$archive_dest_status
WHERE status <> 'INACTIVE'
ORDER BY dest_id;
```

Se la destinazione remota e' in errore, salva l'errore prima di modificare
stato o parametri.

### 3. Controlla apply e lag sullo standby

```sql
SELECT name, value, unit, datum_time, time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag', 'apply finish time');

SELECT process, status, thread#, sequence#, block#
FROM v$managed_standby
WHERE process IN ('MRP0', 'RFS', 'ARCH')
ORDER BY process;
```

`MRP0` deve essere attivo. Distingui:

- transport lag: rete, listener, primary o FRA;
- apply lag: MRP, I/O standby, SRL o carico reporting ADG.

### 4. Controlla il gap sullo standby

```sql
SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;
```

Zero righe significa nessun gap noto. Se esistono righe, registra thread e
sequence prima di agire.

### 5. Controlla Broker

```text
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE <PRIMARY_DB_UNIQUE_NAME>;
SHOW DATABASE VERBOSE <STANDBY_DB_UNIQUE_NAME>;
VALIDATE DATABASE <PRIMARY_DB_UNIQUE_NAME>;
VALIDATE DATABASE <STANDBY_DB_UNIQUE_NAME>;
```

## Troubleshooting rapido

### MRP fermo

Sullo standby, dopo aver letto alert log e gap:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

### Gap redo

Segui una escalation progressiva:

1. verifica rete, listener, FRA, FAL e MRP;
2. attendi FAL se i log esistono;
3. copia e registra gli archivelog mancanti:

```sql
ALTER DATABASE REGISTER PHYSICAL LOGFILE '<ARCHIVELOG_PATH>';
```

4. se i redo sono persi, usa RMAN sullo standby:

```rman
RECOVER STANDBY DATABASE FROM SERVICE <PRIMARY_TNS_ALIAS>;
```

5. usa incremental `FROM SCN` o rebuild solo come fallback approvato.

### Destinazione redo in errore

Cause comuni:

| Errore | Controllo |
| --- | --- |
| `ORA-12514`, `ORA-12541` | listener, alias, firewall |
| `ORA-01017` | password file coerente |
| timeout | route, rete DG, MTU, latenza |
| FRA piena | spazio reale e deletion policy |

Non azzerare `LOCAL_LISTENER`, `REMOTE_LISTENER`, `LISTENER_NETWORKS` o
`LOG_ARCHIVE_DEST_n` alla cieca.

## Validazione finale

| Check | Atteso |
| --- | --- |
| Ruoli | un primary e un physical standby |
| Destinazione redo | nessun errore bloccante |
| Transport lag | entro soglia approvata |
| Apply lag | entro soglia approvata |
| `MRP0` | attivo |
| `V$ARCHIVE_GAP` sullo standby | zero righe |
| Broker | `SUCCESS` |

## Approfondimenti

- [RMAN e Data Guard Recovery/DR](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md)
- [SHAMS PROJECT: Evidence e drill](../../02_core_dba/04_high_availability_and_rac/SHAMS_PROJECT/GUIDA_11_DATAGUARD_EVIDENCE_DRILL_TESTBOOK_PEYTECH_19C.md)
