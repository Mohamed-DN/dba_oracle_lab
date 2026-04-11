# 08 — ORA-Errors Comuni: Diagnosi e Fix

> ⏱️ Tempo: variabile | 📅 Frequenza: Su errore | 👤 Chi: DBA on-call
> **Riferimento**: Dizionario errori Oracle: https://docs.oracle.com/en/error-help/db/

---

## Errori di Connessione

### ORA-12514: TNS:listener does not currently know of service requested

**Causa**: Il listener non conosce il service name richiesto dal client.

```bash
# Diagnosi
lsnrctl status                    # Vedi quali servizi sono registrati
srvctl status service -d RACDB    # Stato servizi RAC
srvctl config service -d RACDB    # Configurazione servizi

# Fix comuni
srvctl start service -d RACDB -s &service_name   # Avvia il servizio
ALTER SYSTEM REGISTER;                             # Forza registrazione dinamica
```

### ORA-12541: TNS:no listener

**Causa**: Il listener non è attivo o non raggiungibile.

```bash
lsnrctl start                     # Avvia listener locale
srvctl start listener             # Avvia listener RAC
srvctl start scan_listener        # Avvia SCAN listener
ping &hostname                    # Verifica rete
tnsping &service_name             # Verifica connettività TNS
```

### ORA-01017: invalid username/password; logon denied

**Causa**: Credenziali errate o password scaduta.

```sql
SELECT username, account_status, expiry_date
FROM dba_users WHERE username = UPPER('&user');

-- Se EXPIRED:
ALTER USER &username IDENTIFIED BY "&new_password";
ALTER USER &username ACCOUNT UNLOCK;
```

### ORA-28000: the account is locked

```sql
ALTER USER &username ACCOUNT UNLOCK;

-- Verifica il profilo
SELECT username, profile FROM dba_users WHERE username = '&user';
SELECT resource_name, limit FROM dba_profiles WHERE profile = '&profile';
```

---

## Errori di Spazio

### ORA-01653 / ORA-01654: unable to extend table/index

**Causa**: Tablespace pieno, il segmento non può crescere.

→ Vai a **Procedura 06 — Tablespace Pieno**

### ORA-01652: unable to extend temp segment

**Causa**: TEMP tablespace pieno.

```sql
-- Chi usa TEMP?
SELECT s.sid, s.serial#, s.username, s.sql_id,
       ROUND(t.blocks * 8192 / 1024 / 1024) AS temp_mb
FROM v$sort_usage t
JOIN v$session s ON t.session_addr = s.saddr
ORDER BY t.blocks DESC;

-- Aggiungi tempfile
ALTER TABLESPACE TEMP ADD TEMPFILE '+DATA' SIZE 2G AUTOEXTEND ON;
```

### ORA-19815 / ORA-19809: FRA piena

```bash
rman TARGET /
RMAN> CROSSCHECK BACKUP;
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> DELETE OBSOLETE;
RMAN> DELETE EXPIRED BACKUP;
RMAN> DELETE EXPIRED ARCHIVELOG ALL;
```

```sql
-- Se non basta, espandi FRA
ALTER SYSTEM SET db_recovery_file_dest_size = 50G SCOPE=BOTH;
```

---

## Errori di Consistenza

### ORA-01555: snapshot too old

**Causa**: Undo insufficiente per garantire read consistency a query lunghe.

```sql
-- Verifica undo retention
SHOW PARAMETER undo_retention;

-- Aumenta retention
ALTER SYSTEM SET undo_retention = 3600 SCOPE=BOTH;  -- 1 ora

-- Se persiste, aggiungi undo space
ALTER TABLESPACE UNDOTBS1 ADD DATAFILE '+DATA' SIZE 2G AUTOEXTEND ON;

-- Garantisci la retention
ALTER SYSTEM SET undo_retention = 7200 SCOPE=BOTH;
ALTER TABLESPACE UNDOTBS1 RETENTION GUARANTEE;
```

### ORA-04031: unable to allocate shared memory

**Causa**: Shared Pool frammentata o troppo piccola.

```sql
-- Verifica Shared Pool
SELECT pool, name, ROUND(bytes/1024/1024) AS mb
FROM v$sgastat
WHERE pool = 'shared pool'
ORDER BY bytes DESC
FETCH FIRST 10 ROWS ONLY;

-- Fix:
-- 1. Flush shared pool (palliativo)
ALTER SYSTEM FLUSH SHARED_POOL;

-- 2. Aumenta shared_pool_size (se non AMM)
ALTER SYSTEM SET shared_pool_size = 2G SCOPE=BOTH;

-- 3. Riduci hard parse (fix applicativo con bind variables)
```

---

## Errori di Instance/Startup

### ORA-01034: ORACLE not available

**Causa**: L'istanza non è avviata.

```bash
# Verifica lo stato
srvctl status database -d RACDB
sqlplus / as sysdba <<< "SELECT status FROM v\$instance;"

# Avvia
srvctl start database -d RACDB
# oppure
sqlplus / as sysdba <<< "STARTUP;"

# Se non parte, controlla alert log
tail -100 $ORACLE_BASE/diag/rdbms/racdb/RACDB1/trace/alert_RACDB1.log
```

### ORA-00600: internal error code

**Causa**: Bug Oracle interno.

```
1. NON riavviare subito (se il DB è ancora su)
2. Salva tutto: alert log, trace file, v$diag_info
3. Cerca il bug su My Oracle Support (MOS) usando il codice [argomenti]
4. Apri SR con Oracle Support se necessario
5. Applica il patch raccomandato
```

```sql
-- Trova i file trace correlati
SELECT value FROM v$diag_info WHERE name = 'Default Trace File';
```

---

## Errori Data Guard

### ORA-16816: incorrect database role

```sql
-- Verifica il ruolo corrente
SELECT database_role, switchover_status FROM v$database;
-- Fix: potrebbe servire un reinstate dopo failover
```

### ORA-16047: DGID mismatch

```sql
-- Password file non allineato tra primary e standby
-- Ricopia il password file dal primary allo standby
-- In ASM:
asmcmd cp '+DATA/RACDB/orapwRACDB' '+DATA/RACDB_STBY/orapwRACDB_STBY'
```

---

## ⚡ Regola d'Oro per Qualsiasi ORA-

```
1. SEMPRE controlla l'alert log PRIMA di ogni altra cosa
2. CERCA il codice su: https://docs.oracle.com/en/error-help/db/
3. SALVA evidenze (timestamp, output, trace)
4. FAI una sola modifica alla volta
5. VERIFICA l'effetto dopo ogni modifica
```
