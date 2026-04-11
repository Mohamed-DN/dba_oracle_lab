# 03 — Check Data Guard

> ⏱️ Tempo: 5 minuti | 📅 Frequenza: Ogni mattina + su incidente | 👤 Chi: DBA on-call

---

## Obiettivo

Verificare che Data Guard funzioni correttamente: redo trasportato, redo applicato, nessun gap.

---

## Step 1: Stato Trasporto dal PRIMARY

```sql
-- Connettiti al PRIMARY
sqlplus / as sysdba

-- 1A. Destinazione standby
SELECT dest_id, status, error,
       archived_thread#, archived_seq#
FROM v$archive_dest
WHERE dest_id = 2;

-- ATTESO: STATUS = VALID, ERROR vuoto
-- 🔴 Se STATUS = ERROR → rete, listener, o standby giù
```

```sql
-- 1B. Ultimo archivelog spedito per thread
SELECT thread#,
       MAX(sequence#) AS last_archived,
       MAX(next_time) AS last_time
FROM v$archived_log
WHERE dest_id = 1
GROUP BY thread#
ORDER BY thread#;
```

## Step 2: Stato Apply sullo STANDBY

```sql
-- Connettiti allo STANDBY
sqlplus / as sysdba

-- 2A. Lag di trasporto e apply
SELECT name, value, datum_time, time_computed
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag', 'apply finish time');

-- ATTESO:
-- transport lag = +00 00:00:00 (o pochi secondi)
-- apply lag     = +00 00:00:00 (o pochi secondi)
```

```sql
-- 2B. Processi managed recovery
SELECT process, pid, status, thread#, sequence#, block#
FROM v$managed_standby
WHERE process IN ('MRP0', 'RFS', 'ARCH')
ORDER BY process;

-- ATTESO: MRP0 in APPLYING_LOG o WAIT_FOR_LOG
-- ⚠️ Se MRP0 assente → apply fermo!
```

```sql
-- 2C. Ultimo archivelog applicato
SELECT thread#,
       MAX(sequence#) AS last_applied,
       MAX(next_time) AS last_time
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#
ORDER BY thread#;
```

## Step 3: Gap Archive

```sql
-- Sullo STANDBY
SELECT * FROM v$archive_gap;

-- ATTESO: 0 righe = nessun gap
-- 🔴 Se ci sono gap → redo mancante!
```

## Step 4: Stato Database Standby

```sql
SELECT name, db_unique_name, open_mode, database_role,
       protection_mode, switchover_status
FROM v$database;

-- ATTESO:
-- DATABASE_ROLE = PHYSICAL STANDBY
-- OPEN_MODE    = MOUNTED (o READ ONLY WITH APPLY se Active DG)
-- SWITCHOVER_STATUS = NOT ALLOWED o TO PRIMARY (se pronto)
```

## Step 5: Data Guard Broker (se attivo)

```bash
dgmgrl /

DGMGRL> SHOW CONFIGURATION;
# ATTESO: SUCCESS

DGMGRL> SHOW DATABASE 'RACDB';
DGMGRL> SHOW DATABASE 'RACDB_STBY';
# ATTESO: entrambi SUCCESS, transport/apply ON

DGMGRL> SHOW DATABASE 'RACDB_STBY' 'StatusReport';
# Dettaglio errori se presenti
```

---

## 🔴 Troubleshooting Comune

### MRP0 non attivo (apply fermo)

```sql
-- Sullo standby, riavvia recovery
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;
```

### Gap di archivelog

```sql
-- Sul PRIMARY: forza archiviazione
ALTER SYSTEM ARCHIVE LOG CURRENT;
ALTER SYSTEM SWITCH LOGFILE;  -- per ogni thread

-- Sullo STANDBY: verifica se il gap si chiude
SELECT * FROM v$archive_gap;
```

### DEST_ID=2 in ERROR

```sql
-- Sul PRIMARY: leggi l'errore
SELECT dest_id, status, error FROM v$archive_dest WHERE dest_id = 2;

-- Cause comuni:
-- ORA-12514: listener standby giù o service sbagliato
-- ORA-01017: password file non allineato
-- Network timeout: rete tra primary e standby

-- Prova a ri-abilitare:
ALTER SYSTEM SET log_archive_dest_state_2 = 'DEFER';
ALTER SYSTEM SET log_archive_dest_state_2 = 'ENABLE';
```

### Lag alto ma nessun errore

```sql
-- Sullo STANDBY: verifica apply rate
SELECT SOFAR, ELAPSED_SECONDS,
       ROUND(SOFAR/ELAPSED_SECONDS, 1) AS blocks_per_sec
FROM v$recovery_progress
WHERE item = 'Active Apply Rate';

-- Se apply lento: potrebbe essere I/O, redo size alto,
-- o parametri recovery sottodimensionati
```

---

## ✅ Check di Conferma

| Controllo | Atteso |
|---|---|
| DEST_ID=2 | STATUS = VALID |
| transport lag | < 30 secondi |
| apply lag | < 1 minuto |
| MRP0 | APPLYING_LOG |
| v$archive_gap | 0 righe |
| Broker | SUCCESS |
