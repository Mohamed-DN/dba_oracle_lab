# Guida Troubleshooting Oracle — Errori Comuni e Soluzioni

> Un DBA passa il 60% del suo tempo a risolvere problemi. Questa guida centralizza tutti gli errori più frequenti con diagnosi e soluzioni pronte.

---

## 1. Clusterware (CRS/Grid Infrastructure)

### CRS non parte

```bash
# Sintomo: dopo reboot, il cluster non parte
crsctl check crs
# CRS-4639: Could not contact Oracle High Availability Services

# Diagnosi: controlla il log CRS
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/alertrac*.log
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/ocssd/ocssd.log

# Soluzione 1: Avvia manualmente CRS
crsctl start crs
# (come root)

# Soluzione 2: Se il votedisk è corrotto
crsctl replace votedisk +CRS

# Soluzione 3: Se il problema è l'OCR
ocrcheck
# Se corrotto: ocrconfig -restore <backup_file>
```

### Nodo evicted dal cluster

```bash
# Sintomo: un nodo scompare dal cluster
crsctl stat res -t
# Mostra un nodo OFFLINE

# Cause più comuni:
# 1. Interconnect down → ip addr show enp0s9
# 2. Heartbeat timeout → ocssd.log
# 3. Disco voting inaccessibile → crsctl query css votedisk

# Diagnosi
cat /u01/app/19.0.0/grid/log/$(hostname)/ocssd/ocssd.log | grep -i "evict\|reconfig"

# Soluzione: verifica la rete interconnect
ping -c 3 192.168.1.102   # ping al nodo remoto via interconnect
ifconfig enp0s9            # interfaccia interconnect attiva?
```

### VIP non migra

```bash
# Sintomo: dopo crash nodo, il VIP resta giù
srvctl config vip -n rac1
# Verifica subnet, interfaccia

# Soluzione
srvctl start vip -n rac1
# Se fallisce: verifica che l'interfaccia sia nella stessa subnet
```

---

## 2. Database — Errori ORA-*

### ORA-00600: Internal Error

```sql
-- È un BUG di Oracle. NON è un errore tuo.
-- Trova il trace file:
SELECT value FROM v$diag_info WHERE name = 'Default Trace File';

-- Cerca il bug su MOS (My Oracle Support):
-- Cerca il primo argomento: ORA-00600 [kdsgrp1]
-- Soluzione: quasi sempre una patch specifica è disponibile.

-- Nel frattempo: il database è spesso ancora funzionante.
-- Solo la sessione che ha colpito il bug è terminata.
```

### ORA-04031: Unable to Allocate Shared Memory

```sql
-- Lo Shared Pool è pieno (frammentato o sottodimensionato)
-- Diagnostica:
SELECT pool, name, bytes/1024/1024 AS mb
FROM v$sgastat WHERE pool = 'shared pool'
ORDER BY bytes DESC FETCH FIRST 10 ROWS ONLY;

-- Soluzione immediata:
ALTER SYSTEM FLUSH SHARED_POOL;
-- ⚠️ Questo invalida TUTTI i cursori cached! Performance drop temporaneo.

-- Soluzione permanente:
ALTER SYSTEM SET shared_pool_size = 512M SCOPE=BOTH SID='*';
-- O aumenta SGA_TARGET.
```

### ORA-01555: Snapshot Too Old

```sql
-- Una query lunga non trova più i dati UNDO necessari.
-- Causa: UNDO retention troppo basso o tablespace UNDO troppo piccolo.

-- Diagnostica:
SHOW PARAMETER undo_retention;
SELECT tablespace_name, ROUND(SUM(bytes)/1024/1024) AS undo_mb
FROM dba_data_files WHERE tablespace_name LIKE 'UNDO%'
GROUP BY tablespace_name;

-- Soluzione:
ALTER SYSTEM SET undo_retention = 3600 SCOPE=BOTH SID='*';
-- 3600 secondi = 1 ora. In produzione con query lunghe: 7200+.
-- Se serve, aumenta anche la dimensione del tablespace UNDO:
ALTER DATABASE DATAFILE '+DATA/RACDB/DATAFILE/undotbs1.dbf' RESIZE 2G;
```

### ORA-01578: Blocco Corrotto

```sql
-- Un blocco del datafile è fisicamente corrotto.
-- Diagnostica:
SELECT file#, block#, corruption_type FROM v$database_block_corruption;

-- Soluzione con RMAN (Block Media Recovery):
rman TARGET /
RECOVER CORRUPTION LIST;
-- ^^^ RMAN sostituisce SOLO i blocchi corrotti dal backup,
--     senza toccare il resto del database. Geniale.
```

---

## 3. Data Guard

### ORA-16698: LOG_ARCHIVE_DEST_n con SERVICE attribute

```sql
-- Il Broker non vuole destinazioni manuali che competono con le sue.
-- Soluzione: rimuovi le destinazioni manuali
ALTER SYSTEM SET log_archive_dest_2='' SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_state_2='DEFER' SCOPE=BOTH SID='*';
-- Poi lascia che DGMGRL gestisca la destinazione.
```

### Transport Lag Crescente

```bash
# Diagnostica:
dgmgrl sys/<password>@RACDB "SHOW DATABASE RACDB_STBY;"
# transport lag: 00:05:30 ← problematico se cresce

# Cause:
# 1. Rete lenta tra primary e standby
# 2. Listener standby down
# 3. Destinazione in DEFER

# Soluzione:
# Su standby: lsnrctl status
# Su primary:
SELECT dest_id, status, error FROM v$archive_dest WHERE dest_id = 2;
ALTER SYSTEM SET log_archive_dest_state_2 = 'ENABLE' SCOPE=BOTH;
ALTER SYSTEM SWITCH LOGFILE;
```

### Apply Lag Crescente

```sql
-- Sullo standby:
SELECT process, status, thread#, sequence#
FROM v$managed_standby WHERE process = 'MRP0';
-- Se MRP0 non è presente: apply non è attivo!

-- Soluzione:
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

### GAP di Archivelog

```sql
-- Sullo standby:
SELECT * FROM v$archive_gap;
-- Mostra i thread e le sequenze mancanti

-- Soluzione: il FAL (Fetch Archive Log) dovrebbe risolverlo automaticamente
ALTER SYSTEM SET fal_server='RACDB' SCOPE=BOTH SID='*';
-- Se non funziona: copia manualmente gli archivelog mancanti dal primary.
```

---

## 4. RMAN

### FRA Piena (ORA-19809)

```rman
rman TARGET /
-- Pulizia aggressiva:
DELETE NOPROMPT OBSOLETE;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;

-- Se ancora piena, aumenta la FRA:
SQL "ALTER SYSTEM SET db_recovery_file_dest_size = 25G SCOPE=BOTH SID='*'";
```

### Backup Corrotto (RMAN-06059)

```rman
-- Verifica quali backup sono validi
CROSSCHECK BACKUP;
-- marca i corrotti come EXPIRED

DELETE EXPIRED BACKUP;
-- rimuovi dal catalogo i backup non più validi

-- Fai un nuovo backup FULL
BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE;
```

---

## 5. Listener e TNS

### ORA-12514: TNS: listener does not currently know of service

```bash
# Il servizio non è registrato nel listener
lsnrctl status
# Cerca il servizio nella lista "Services Summary"

# Soluzione 1: registrazione dinamica (attendi 60 secondi)
sqlplus / as sysdba
ALTER SYSTEM REGISTER;

# Soluzione 2: verifica il parametro local_listener
SHOW PARAMETER local_listener;
# Deve puntare al listener corretto

# Soluzione 3: registrazione statica in listener.ora
# Aggiungi SID_LIST nel listener.ora del nodo
```

### ORA-12541: TNS: no listener

```bash
# Il listener non è in esecuzione
lsnrctl status
# Errore di connessione

# Soluzione:
lsnrctl start
# Se in RAC:
srvctl start listener -n rac1
```

---

## 6. Performance — Quick Wins

### Database Lento (Diagnosi Rapida)

```sql
-- 1. Chi sta aspettando cosa ADESSO?
SELECT sid, serial#, username, event, wait_class,
       seconds_in_wait, sql_id
FROM v$session
WHERE status = 'ACTIVE' AND username IS NOT NULL
ORDER BY seconds_in_wait DESC;

-- 2. Sessioni bloccanti (lock)
SELECT
    s1.sid AS blocking_sid,
    s1.serial# AS blocking_serial,
    s2.sid AS blocked_sid,
    s2.serial# AS blocked_serial,
    s2.event
FROM v$session s1, v$session s2
WHERE s1.sid = s2.blocking_session;

-- 3. Kill della sessione bloccante (con cautela!)
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;

-- 4. Tablespace quasi pieno
SELECT tablespace_name, ROUND(used_percent, 1) AS pct_used
FROM dba_tablespace_usage_metrics
WHERE used_percent > 85
ORDER BY used_percent DESC;

-- 5. ASM quasi pieno
SELECT name,
       ROUND(total_mb/1024) AS total_gb,
       ROUND(free_mb/1024) AS free_gb,
       ROUND((1-free_mb/total_mb)*100, 1) AS pct_used
FROM v$asm_diskgroup;
```

---

## 7. Dove Trovare i Log

```bash
# Alert Log (IL PIÙ IMPORTANTE)
adrci
SHOW ALERT -tail 100

# Oppure direttamente:
tail -200 $ORACLE_BASE/diag/rdbms/racdb/RACDB1/trace/alert_RACDB1.log

# Log CRS/Grid
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/alert$(hostname).log

# Log CSSD (cluster membership)
tail -100 /u01/app/19.0.0/grid/log/$(hostname)/ocssd/ocssd.log

# Log Listener
tail -100 /u01/app/19.0.0/grid/log/diag/tnslsnr/$(hostname)/listener/trace/listener.log

# Log GoldenGate
cat $OGG_HOME/dirrpt/*.rpt
```

---

## 8. Fonti Oracle Ufficiali

- Oracle Error Messages: https://docs.oracle.com/en/database/oracle/oracle-database/19/errmg/
- Troubleshooting Oracle RAC: https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/troubleshooting-oracle-rac.html
- Data Guard Troubleshooting: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/troubleshooting-oracle-data-guard.html
