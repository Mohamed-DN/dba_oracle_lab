# Recovery Data Guard Post-Reboot

> **Problem**: After a sudden server restart (e.g. crash, HW maintenance), the Data Guard Broker often loses synchronization and the MRP (Managed Recovery Process) does not restart automatically.

---

## Sintomi

- Standby is on `MOUNT` state but MRP is not active
- Il Broker mostra `ORA-16766: Redo Apply is stopped`
- Growing gap between primary and standby
- Archive logs are not sent

---

## Recovery procedure

### 1. Check the status of the Broker

```sql
-- Sul PRIMARY o STANDBY
dgmgrl sys/<password>

DGMGRL> show configuration;

--If it shows error, check the database status
DGMGRL> show database 'NOME_DB_STANDBY';
```

### 2. Check the logs and GAP

```sql
--On STANDBY
SELECT * FROM v$standby_log;
SELECT * FROM v$archive_gap;
SELECT THREAD#, MAX(SEQUENCE#) FROM v$archived_log WHERE APPLIED = 'YES' GROUP BY THREAD#;
```

### 3. Restart the MRP (Apply)

```sql
--On STANDBY as SYS
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;
```

### 4. If the Broker is corrupt, recreate it

```sql
--Disable and then re-enable the Broker on both sides
-- SUL PRIMARY
ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
--Wait 30 seconds
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';

--ON STANDBY (same thing)
ALTER SYSTEM SET dg_broker_start=FALSE SCOPE=BOTH SID='*';
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

### 5. Re-edit the configuration in the Broker (if necessary)

```sql
dgmgrl sys/<password>

--Example: edit database with the correct connect identifier
DGMGRL> edit database 'NOME_DB' SET PROPERTY StaticConnectIdentifier='(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=hostname)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=NOME_DB_DGMGRL)(INSTANCE_NAME=NOME_DB1)(SERVER=DEDICATED)))';
```

> [!WARNING]
> In RAC, the `StaticConnectIdentifier` must point to the **static listener** dedicated to the Data Guard, NOT the SCAN listener!
