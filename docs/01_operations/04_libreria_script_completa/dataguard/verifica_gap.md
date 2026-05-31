# Verifica gap Data Guard

Controlla separatamente redo generato, ricevuto e applicato. `V$ARCHIVE_GAP`
si interroga sullo standby.

## Query

```sql
-- 1. Gap: solo sullo STANDBY
SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;

-- 2. Ultimo redo applicato: sullo STANDBY
SELECT thread#, MAX(sequence#) AS last_applied
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#;

-- 3. Ultimo redo generato: sul PRIMARY
SELECT thread#, MAX(sequence#) AS last_generated
FROM v$archived_log
GROUP BY thread#;

-- 4. Trasporto: sul PRIMARY
SELECT dest_id, status, error, gap_status
FROM v$archive_dest_status
WHERE status <> 'INACTIVE';
```

## Risoluzione progressiva

1. Verifica rete, listener, FRA, FAL e MRP.
2. Attendi FAL se i redo esistono.
3. Copia e registra gli archivelog mancanti:

```sql
ALTER DATABASE REGISTER PHYSICAL LOGFILE '<ARCHIVELOG_PATH>';
```

4. Se i redo originali sono persi, usa RMAN sullo standby:

```rman
RECOVER STANDBY DATABASE FROM SERVICE <PRIMARY_TNS_ALIAS>;
```

Un gap piccolo puo' essere transitorio in `ASYNC`; un gap crescente richiede
diagnosi.
