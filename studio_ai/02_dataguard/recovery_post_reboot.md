# Recovery Data Guard Post-Reboot

> **Problema**: Dopo un riavvio improvviso del server (es. crash, manutenzione HW), spesso il Data Guard Broker perde la sincronizzazione e il MRP (Managed Recovery Process) non riparte automaticamente.

---

## Sintomi

- Lo standby è in stato `MOUNT` ma il MRP non è attivo
- Il Broker mostra `ORA-16766: Redo Apply is stopped`
- GAP crescente tra primary e standby
- I log archivi non vengono spediti

---

## Procedura di Recovery

### 1. Verifica lo stato del Broker

```sql
-- Sul PRIMARY o STANDBY
dgmgrl sys/<password>

DGMGRL> show configuration;

-- Se mostra errore, verifica lo stato del database
DGMGRL> show database 'NOME_DB_STANDBY';
```

### 2. Verifica i log e il GAP

```sql
-- Sullo STANDBY
SELECT * FROM v$standby_log;
SELECT * FROM v$archive_gap;
SELECT THREAD#, MAX(SEQUENCE#) FROM v$archived_log WHERE APPLIED = 'YES' GROUP BY THREAD#;
```

### 3. Riavvia il MRP (Apply)

```sql
-- Sullo STANDBY come SYS
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;
```

### 4. Se il Broker è corrotto, ricrealo

```sql
-- Disabilita e poi riabilita il Broker su entrambi i lati
-- SUL PRIMARY
ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
-- Attendi 30 secondi
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';

-- SULLO STANDBY (stessa cosa)
ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

### 5. Riedita la configurazione nel Broker (se necessario)

```sql
dgmgrl sys/<password>

-- Esempio: edit database con il connect identifier corretto
DGMGRL> edit database 'NOME_DB' SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=hostname)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=NOME_DB_DGMGRL)(INSTANCE_NAME=NOME_DB1)(SERVER=DEDICATED)))';
```

> [!WARNING]
> In RAC, il `StaticConnectIdentifier` deve puntare al **static listener** dedicato al Data Guard, NON al SCAN listener!
