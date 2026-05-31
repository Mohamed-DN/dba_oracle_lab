# Recovery Data Guard post-reboot

Dopo un reboot verifica prima stato risorse, Broker, rete e MRP. Non assumere
che il Broker sia corrotto: spesso apply e' solo fermo o la rete non e' pronta.

## Sintomi

- Standby `MOUNTED`, ma MRP non attivo.
- Broker `ORA-16766: Redo Apply is stopped`.
- Gap crescente o trasporto in errore.

## Procedura

### 1. Broker e risorse

```text
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE <STANDBY_DB_UNIQUE_NAME>;
```

```bash
srvctl status database -db <DB_UNIQUE_NAME>
lsnrctl services LISTENER_DG
```

### 2. Gap sullo standby

```sql
SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;

SELECT thread#, MAX(sequence#)
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#;
```

### 3. Riavvia MRP

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

### 4. Riavvia Broker solo se necessario

Salva evidence e verifica prima rete, listener e processi. Se il change lo
autorizza:

```sql
ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

Non ricreare la configurazione Broker come prima risposta a un reboot.
