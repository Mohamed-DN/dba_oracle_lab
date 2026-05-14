# Runbook: Diagnosi Root Cause Backup RMAN Falliti e Disaster Recovery

> Runbook operativo completo per identificare la causa radice (RCA) dei fallimenti
> backup RMAN, risolvere ogni tipo di errore e ripristinare il servizio quando
> i backup non esistono.
>
> Include: classificazione severita, triage, decision tree, 30+ codici errore
> con diagnostica e risoluzione, disaster recovery senza backup, post-mortem.
>
> **Target audience**: DBA Oracle in ambienti enterprise di produzione.

---

## PARTE I — CLASSIFICAZIONE E TRIAGE

---

## 1. Classificazione Severita e SLA

| Severita | Condizione | SLA Risposta | Azione |
|---|---|---|---|
| **P1 - Critico** | Nessun backup valido nelle ultime 48h + nessuna standby | 15 min | Escalation immediata, notifica management |
| **P2 - Alto** | Backup FAILED ma ultimo backup valido < 48h | 1 ora | Diagnosi e re-run backup |
| **P3 - Medio** | Backup COMPLETED WITH WARNINGS | 4 ore | Analisi warning, fix preventivo |
| **P4 - Basso** | Backup lento o sub-ottimale | Next business day | Tuning, review configurazione |
| **P5 - Info** | Backup OK ma metriche degradate | Prossima manutenzione | Monitoring trend |

### 1.1 Decision Matrix per Escalation

```
Backup FAILED?
  |-- SI --> Ultimo backup valido > 48h?
  |           |-- SI --> Esiste Standby DB?
  |           |           |-- SI --> P2 (la standby copre il rischio)
  |           |           |-- NO --> P1 CRITICO (rischio perdita dati)
  |           |-- NO --> P2 (fix e re-run entro SLA)
  |
  |-- NO --> COMPLETED WITH WARNINGS?
              |-- SI --> Warning critico (corruzione)?
              |           |-- SI --> P2 (potenziale data loss)
              |           |-- NO --> P3 (fix preventivo)
              |-- NO --> COMPLETED OK --> Nessuna azione
```

---

## 2. Triage Iniziale (Primi 5 Minuti)

### 2.1 Step 1: Identifica il Fallimento

```sql
-- Query 1: Status ultimi job RMAN (ultime 72 ore)
SELECT input_type,
       status,
       TO_CHAR(start_time, 'DD-MON HH24:MI') AS started,
       TO_CHAR(end_time, 'DD-MON HH24:MI') AS ended,
       ROUND(elapsed_seconds/60) AS duration_min,
       output_bytes_display AS output_size,
       output_device_type,
       session_key
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 3
ORDER BY start_time DESC;
```

| Status | Significato | Urgenza |
|---|---|---|
| COMPLETED | OK, nessun errore | Nessuna |
| COMPLETED WITH WARNINGS | Funzionato ma con avvisi | Media |
| COMPLETED WITH ERRORS | Errori parziali, alcuni file non backuppati | Alta |
| FAILED | Fallito completamente | Critica |
| RUNNING | Ancora in corso | Monitorare |
| RUNNING WITH WARNINGS | In corso con avvisi | Monitorare |
| RUNNING WITH ERRORS | In corso con errori | Intervenire |

### 2.2 Step 2: Trova l'Errore Specifico

```sql
-- Query 2: Errori dettagliati
SELECT TO_CHAR(start_time,'DD-MON HH24:MI') AS ts,
       operation, status, object_type,
       SUBSTR(output,1,300) AS error_msg
FROM v$rman_status
WHERE start_time > SYSDATE - 3
  AND status NOT IN ('COMPLETED','RUNNING')
ORDER BY start_time DESC;

-- Query 3: Output completo dell'ultimo job fallito
SELECT output
FROM v$rman_output
WHERE session_key = (
  SELECT MAX(session_key) FROM v$rman_backup_job_details
  WHERE status = 'FAILED'
)
ORDER BY recid;
```

### 2.3 Step 3: Check Alert Log

```bash
# Cerca errori RMAN/ORA nell'alert log
grep -E "ORA-|RMAN-" $ORACLE_BASE/diag/rdbms/*/trace/alert_*.log | tail -50

# Con ADRCI
adrci
set homepath diag/rdbms/prod/prod1
show alert -p "message_text like '%RMAN%' or message_text like '%ORA-19%' or message_text like '%ORA-27%' or message_text like '%ORA-00257%'"
```

### 2.4 Step 4: Check Spazio

```sql
-- FRA usage dettagliato
SELECT name,
       ROUND(space_limit/1024/1024/1024,1) AS limit_gb,
       ROUND(space_used/1024/1024/1024,1) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024,1) AS reclaimable_gb,
       ROUND(space_used/space_limit*100,1) AS pct_used,
       CASE WHEN space_used/space_limit > 0.90 THEN 'CRITICAL'
            WHEN space_used/space_limit > 0.80 THEN 'WARNING'
            ELSE 'OK' END AS status
FROM v$recovery_file_dest;

-- FRA per tipo file
SELECT file_type,
       ROUND(percent_space_used,1) AS pct_used,
       ROUND(percent_space_reclaimable,1) AS pct_reclaimable,
       number_of_files
FROM v$flash_recovery_area_usage
WHERE percent_space_used > 0
ORDER BY percent_space_used DESC;
```

```bash
# Filesystem OS
df -Th /backup /u01 /u02 /opt/oracle
# ASM
asmcmd lsdg
```

### 2.5 Step 5: Regola Aurea per Error Stack

**LEGGI L'ERROR STACK DAL BASSO VERSO L'ALTO.**

L'ultimo errore nello stack e la causa radice. Gli errori precedenti sono conseguenze.

```
RMAN-00569: =============== ERROR MESSAGE STACK FOLLOWS ===============
RMAN-00571: ===========================================================
RMAN-03009: failure of backup command on ORA_DISK_1 channel at ...
RMAN-10035: exception raised in Oracle process ...
RMAN-10027: ...
ORA-19502: write error on file "/backup/...", block number ...
ORA-27072: File I/O error                    <-- QUESTO E IL ROOT CAUSE
```

---

## PARTE II — ROOT CAUSE ANALYSIS PER CATEGORIA

---

## 3. CATEGORIA: Errori di Spazio (Storage)

### 3.1 ORA-19809 / ORA-19804: FRA Limit Exceeded

**Sintomo**: `ORA-19809: limit exceeded for recovery files`

**Root Cause**: La FRA ha raggiunto `db_recovery_file_dest_size`.

**Diagnostica**:
```sql
SELECT ROUND(SPACE_USED/1024/1024/1024,1) AS used_gb,
       ROUND(SPACE_LIMIT/1024/1024/1024,1) AS limit_gb,
       ROUND(SPACE_RECLAIMABLE/1024/1024/1024,1) AS reclaimable_gb,
       ROUND((SPACE_USED-SPACE_RECLAIMABLE)/SPACE_LIMIT*100,1) AS net_pct
FROM v$recovery_file_dest;

-- Cosa occupa la FRA?
SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files
FROM v$flash_recovery_area_usage ORDER BY percent_space_used DESC;
```

**Remediation immediata**:
```sql
-- Opzione A: Aumenta il limite (se c'e spazio disco OS/ASM)
ALTER SYSTEM SET db_recovery_file_dest_size = 200G SCOPE=BOTH;
```

```rman
-- Opzione B: Libera spazio via RMAN
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT OBSOLETE;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

-- Opzione C: Backup archivelog e poi cancella
BACKUP ARCHIVELOG ALL DELETE INPUT;
```

**Prevenzione**: Alert su FRA > 80%. Dimensiona FRA >= 2x DB size.

---

### 3.2 ORA-19815: FRA Warning Threshold

Come ORA-19809 ma e un warning. Intervieni PRIMA che diventi critico.

---

### 3.3 ORA-00257: Archiver Error / Archiver Stuck

**Sintomo**: `ORA-00257: archiver error. Connect internal only, until freed.`

**Root Cause**: L'archiver non puo scrivere archivelog. FRA piena o destinazione piena.

**IMPATTO CRITICO**: Il database blocca TUTTE le transazioni finche l'archiver non riparte!

**Diagnostica**:
```sql
SHOW PARAMETER log_archive_dest;
SHOW PARAMETER db_recovery_file_dest;
SELECT * FROM v$recovery_file_dest;
```
```bash
df -h $(dirname $(sqlplus -s / as sysdba <<< "SELECT value FROM v\$parameter WHERE name='log_archive_dest_1';"))
```

**Remediation**: Libera spazio FRA o nella destinazione archivelog. L'archiver riparte automaticamente.

---

### 3.4 ORA-19502: Write Error on File

**Sintomo**: `ORA-19502: write error on file "...", block number ...`

**Root Cause**: Filesystem pieno, permessi errati, NFS timeout, hardware I/O failure.

**Diagnostica**:
```bash
df -Th /backup
ls -la /backup/
dmesg | tail -30
cat /var/log/messages | grep -i -E "error|fault|fail" | tail -20
mount | grep /backup  # verifica opzioni NFS
```

**Remediation**:
1. Libera spazio: `find /backup -name "*.bkp" -mtime +30 -exec ls -lh {} \;`
2. Fix permessi: `chown -R oracle:oinstall /backup; chmod 750 /backup`
3. Se NFS: verifica mount options (`hard,rsize=32768,wsize=32768,tcp`)
4. Se hardware: `smartctl -a /dev/sda`, escalation team storage

---

### 3.5 ORA-27072: File I/O Error (OS Level)

**Root Cause**: Errore I/O OS. Disco difettoso, RAID degradato, cable fault.

**Diagnostica**:
```bash
dmesg | grep -i -E "error|fault|fail|i/o" | tail -30
cat /var/log/messages | tail -50
smartctl -a /dev/sda
cat /proc/mdstat  # se RAID software
```

**Remediation**: Escalation team infrastruttura/storage.

---

### 3.6 ORA-15041: ASM Diskgroup Full

**Diagnostica**:
```sql
SELECT name, total_mb, free_mb, 
       ROUND(free_mb/total_mb*100,1) AS pct_free,
       state, type
FROM v$asm_diskgroup;
```

**Remediation**: Aggiungi dischi al DG o sposta backup su altro DG.


---

## 4. CATEGORIA: Errori di Metadata e Catalogo

### 4.1 RMAN-06059: Expected Archived Log Not Found

**Sintomo**: `RMAN-06059: expected archived log not found, loss of archived log compromises recoverability`

**Root Cause**: Archivelog registrato nel controlfile ma cancellato con `rm` dal filesystem.

**Diagnostica**:
```rman
LIST EXPIRED ARCHIVELOG ALL;
CROSSCHECK ARCHIVELOG ALL;
```

**Remediation**:
```rman
CROSSCHECK ARCHIVELOG ALL;
DELETE EXPIRED ARCHIVELOG ALL;
-- La catena di recovery e rotta: fai un nuovo Full L0
BACKUP INCREMENTAL LEVEL 0 DATABASE TAG 'POST_GAP_L0';
```

**Prevenzione**: MAI usare `rm` per cancellare archivelog. SEMPRE via RMAN.

---

### 4.2 RMAN-06054: Media Recovery Requires Archived Log

**Sintomo**: Durante RECOVER, RMAN richiede un archivelog non disponibile.

**Root Cause**: Gap nella sequenza archivelog.

**Diagnostica**:
```rman
LIST ARCHIVELOG ALL;
```
```sql
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;
```

**Remediation**: Se il gap e irrecuperabile, usa PITR prima del gap:
```rman
RUN {
  SET UNTIL SEQUENCE <seq_before_gap> THREAD 1;
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

---

### 4.3 RMAN-06169: Catalog Connection Failed

**Root Cause**: RMAN non si connette al Recovery Catalog DB.

**Diagnostica**:
```bash
tnsping CATDB
lsnrctl status
sqlplus rman_admin/pwd@CATDB
```

**Remediation**: Fix TNS/listener del catalog. Dopo: `RESYNC CATALOG;`

---

### 4.4 RMAN-20242: Specification Does Not Match Any Backup

**Root Cause**: Il backup specificato non esiste nel repository.

**Remediation**:
```rman
LIST BACKUP SUMMARY;
LIST BACKUP TAG 'nome_tag';
-- Se i file esistono ma non sono catalogati:
CATALOG START WITH '/path/to/backup/';
```

---

### 4.5 RMAN-06004: Recovery Area Error

**Root Cause**: Problema di configurazione della FRA o path non accessibile.

**Diagnostica**:
```sql
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;
```

**Remediation**: Verifica che il path esista e sia scrivibile dall'utente oracle.

---

## 5. CATEGORIA: Errori di Corruzione

### 5.1 ORA-01578 / RMAN-08120: Block Corruption

**Sintomo**: `ORA-01578: ORACLE data block corrupted (file # x, block # y)`

**Root Cause**: Corruzione fisica o logica di blocchi del datafile.

**Diagnostica**:
```sql
-- Blocchi corrotti noti
SELECT file#, block#, blocks, corruption_type, corruption_change#
FROM v$database_block_corruption
ORDER BY file#, block#;

-- Identifica gli oggetti coinvolti
SELECT owner, segment_name, segment_type, partition_name
FROM dba_extents
WHERE file_id = &file_id
  AND &block_id BETWEEN block_id AND block_id + blocks - 1;
```

**Remediation**:
```rman
-- Opzione A: Block Media Recovery (zero downtime)
BLOCKRECOVER DATAFILE <file#> BLOCK <block#>;

-- Opzione B: Se molti blocchi, restore intero datafile
SQL "ALTER DATABASE DATAFILE <file#> OFFLINE";
RESTORE DATAFILE <file#>;
RECOVER DATAFILE <file#>;
SQL "ALTER DATABASE DATAFILE <file#> ONLINE";
```

**Per backuppare anche con corruzioni presenti:**
```rman
RUN {
  SET MAXCORRUPT FOR DATAFILE <file#> TO 10;
  BACKUP DATABASE TAG 'WITH_CORRUPTION';
}
```

**Prevenzione**: `VALIDATE DATABASE CHECK LOGICAL;` schedulato settimanalmente.

---

### 5.2 ORA-19566: Exceeded Limit of Corrupt Blocks

**Root Cause**: RMAN ha trovato piu blocchi corrotti del limite consentito (default 0).

**Remediation**: Come 5.1 ma usa `SET MAXCORRUPT` se il backup e urgente.

---

## 6. CATEGORIA: Errori Encryption / TDE / Wallet

### 6.1 ORA-28365: Wallet is Not Open

**Root Cause**: Encryption configurata ma Keystore/Wallet non aperto.

**Diagnostica**:
```sql
SELECT wrl_type, status, wallet_type, wallet_order, con_id
FROM v$encryption_wallet;
-- status deve essere OPEN
```

**Remediation**:
```sql
-- Apri wallet manualmente
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "wallet_password";

-- Per auto-login (consigliato per backup schedulati):
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE 
  FROM KEYSTORE '/path/to/wallet' IDENTIFIED BY "wallet_password";
```

---

### 6.2 ORA-46658: Keystore Error

**Root Cause**: Path del wallet errato o file wallet corrotto/mancante.

**Diagnostica**:
```bash
ls -la $ORACLE_BASE/admin/$ORACLE_SID/wallet/
cat $ORACLE_HOME/network/admin/sqlnet.ora | grep -i wallet
```

**Remediation**: Verifica `ENCRYPTION_WALLET_LOCATION` in sqlnet.ora.

---

### 6.3 RMAN-12016: Cannot Use TDE

**Root Cause**: TDE non abilitato/licenziato.

**Remediation** (workaround con password):
```rman
SET ENCRYPTION ON IDENTIFIED BY 'backup_password' ONLY;
BACKUP DATABASE;
```

---

## 7. CATEGORIA: Errori Channel / Tape / SBT

### 7.1 RMAN-03009: Failure of Channel Command

**Root Cause**: Il canale non riesce a operare. Su tape: MML non raggiungibile.

**Diagnostica**:
```rman
SHOW ALL;
```
```bash
# Verifica SBT library
ls -la /usr/openv/netbackup/bin/libobk.so64
sbttest test_file.tst
# Check media manager status
bpclntcmd -pn
```

**Remediation**: Fix parametri ENV del canale SBT, verifica servizio tape attivo.

---

### 7.2 ORA-19511: Media Manager Error

**Root Cause**: Il media manager (NetBackup, CommVault, etc.) ha respinto l'operazione.

**Diagnostica**: Leggi `sbtio.log` nella directory trace:
```bash
cat $ORACLE_BASE/diag/rdbms/prod/prod1/trace/sbtio.log
```

**Remediation**: Consulta la documentazione del vendor specifico.

---

### 7.3 ORA-27211: SBT Library Load Failed

**Root Cause**: La libreria SBT non e trovata o non e caricabile.

**Diagnostica**:
```bash
ls -la /path/to/libobk.so64
ldd /path/to/libobk.so64  # verifica dipendenze
```

**Remediation**: Fix path nella configurazione CHANNEL, verifica permessi e dipendenze.

---

### 7.4 RMAN-10035 / RMAN-10038: Exception During Backup

**Root Cause**: Eccezione I/O durante scrittura backup piece.

**Remediation**: Verifica subsystem I/O (storage, rete per NFS/tape). Retry.

---

## 8. CATEGORIA: Errori di Permessi e OS

### 8.1 ORA-27040 / ORA-27041: File Creation/Open Error

**Root Cause**: L'utente oracle non ha permessi per creare/aprire file.

**Diagnostica**:
```bash
ls -la /backup/
id oracle
groups oracle
namei -l /backup/rman/
```

**Remediation**:
```bash
chown -R oracle:oinstall /backup
chmod 750 /backup
# Se SELinux:
restorecon -Rv /backup
```

---

### 8.2 ORA-01031: Insufficient Privileges

**Root Cause**: L'utente RMAN non ha SYSDBA o SYSBACKUP.

**Remediation**:
```sql
GRANT SYSBACKUP TO backup_user;
-- Connessione corretta:
-- rman target '"backup_user/pwd@PROD as sysbackup"'
```

---

## 9. CATEGORIA: Errori di Rete e Connessione

### 9.1 ORA-12154: TNS Could Not Resolve

**Diagnostica**:
```bash
tnsping TARGET_DB
cat $ORACLE_HOME/network/admin/tnsnames.ora | grep -A5 TARGET_DB
```

**Remediation**: Fix tnsnames.ora con il TNS alias corretto.

---

### 9.2 ORA-12541: No Listener

**Diagnostica**:
```bash
lsnrctl status
netstat -tlnp | grep 1521
```

**Remediation**: `lsnrctl start`

---

### 9.3 ORA-03113 / ORA-03135: Connection Lost

**Root Cause**: Connessione interrotta durante backup. Timeout, firewall, crash processo.

**Diagnostica**: Alert log per crash. Check firewall settings.

**Remediation**:
```sql
ALTER SYSTEM SET sqlnet.recv_timeout=300 SCOPE=SPFILE;
ALTER SYSTEM SET sqlnet.send_timeout=300 SCOPE=SPFILE;
```

---

## 10. CATEGORIA: Errori Data Guard Specifici

### 10.1 ORA-16055: FAL Request Rejected

**Diagnostica**:
```sql
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;
```

**Remediation**: Verifica FAL_SERVER/FAL_CLIENT. Fix rete primary-standby.

---

### 10.2 ORA-16014: Log Not Archived

Come ORA-00257. Libera spazio per archivelog.

---

### 10.3 Backup da Standby Fallito

**Diagnostica**:
```sql
-- Sulla standby
SELECT database_role, open_mode FROM v$database;
SELECT process, status FROM v$managed_standby;
```

**Remediation**: La standby deve essere in OPEN READ ONLY (Active Data Guard).


---

## PARTE III — DISASTER RECOVERY SENZA BACKUP

---

## 11. Verifica: Davvero Non Ci Sono Backup?

Prima di andare nel panico, verifica TUTTO:

```rman
-- 1. Verifica inventory completo
LIST BACKUP SUMMARY;
LIST BACKUP OF DATABASE;
LIST COPY OF DATABASE;

-- 2. Crosscheck per aggiornare metadata
CROSSCHECK BACKUP;
CROSSCHECK COPY;

-- 3. Cerca backup non catalogati su disco
CATALOG START WITH '/backup/';
CATALOG START WITH '+RECO/';
CATALOG START WITH '/u01/backup/';

-- 4. Cerca autobackup controlfile
RESTORE CONTROLFILE FROM AUTOBACKUP;
-- Se FRA non standard:
RESTORE CONTROLFILE FROM AUTOBACKUP
  DB_RECOVERY_FILE_DEST='/backup/fra';

-- 5. Verifica Recovery Catalog (se esiste)
-- rman target / catalog rman/pwd@CATDB
-- LIST BACKUP SUMMARY;

-- 6. Cerca backup su tape/cloud
-- Verifica con il team backup/storage
```

---

## 12. Opzioni di Recovery Senza Backup RMAN

### 12.1 Opzione 1: Failover su Standby (Data Guard)

Se esiste un database fisico standby — OPZIONE MIGLIORE.

```bash
# Con DGMGRL (raccomandato)
dgmgrl sys/pwd@STBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO 'stby_db' IMMEDIATE;
```

```sql
-- Se DGMGRL non disponibile:
-- Sulla STANDBY:
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE FINISH;
ALTER DATABASE ACTIVATE STANDBY DATABASE;
ALTER DATABASE OPEN;

-- Verifica ruolo
SELECT database_role, open_mode FROM v$database;
```

**RPO**: Zero (SYNC) o minuti (ASYNC).
**RTO**: Minuti.

---

### 12.2 Opzione 2: Flashback Database

Se il database si avvia in MOUNT e il Flashback era abilitato.
Utile per errori LOGICI (DROP TABLE, UPDATE sbagliato).

```sql
-- Verifica se Flashback e abilitato
SELECT flashback_on, current_scn FROM v$database;
SELECT oldest_flashback_scn, oldest_flashback_time 
FROM v$flashback_database_log;

-- Lista restore point garantiti
SELECT name, scn, time, guarantee_flashback_database
FROM v$restore_point;
```

```sql
-- Flashback a un punto nel tempo
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO TIMESTAMP 
  TO_TIMESTAMP('2026-05-14 10:00:00','YYYY-MM-DD HH24:MI:SS');
ALTER DATABASE OPEN RESETLOGS;

-- Oppure a un restore point
FLASHBACK DATABASE TO RESTORE POINT before_upgrade;
ALTER DATABASE OPEN RESETLOGS;

-- Oppure a un SCN
FLASHBACK DATABASE TO SCN 1234567;
ALTER DATABASE OPEN RESETLOGS;
```

**RPO**: Fino al punto di flashback.

---

### 12.3 Opzione 3: Storage Snapshot / SAN Recovery

Se i LUN sono protetti da snapshot a livello storage (NetApp, EMC, PureStorage, ZFS).

**Procedura**:
1. `SHUTDOWN ABORT` dell'istanza Oracle
2. Contatta team storage per il restore dello snapshot
3. Dopo il restore dei LUN:
   ```sql
   STARTUP MOUNT;
   -- Se online redo log sopravvissuti:
   RECOVER DATABASE;
   ALTER DATABASE OPEN;
   -- Se redo persi:
   ALTER DATABASE OPEN RESETLOGS;
   ```

**RPO**: Dipende dalla frequenza degli snapshot.

---

### 12.4 Opzione 4: Ricostruzione da Data Pump

Ultimo resort se NESSUNA altra opzione.

1. Installa un database vuoto
2. `impdp` dell'ultimo export Data Pump disponibile
3. Riallinea dati da log applicativi o sorgenti batch
4. Verifica completezza dati con application team

```bash
impdp system/pwd@NEWDB \
  DIRECTORY=dpump_dir \
  DUMPFILE=full_export_%U.dmp \
  FULL=YES \
  LOGFILE=import.log
```

**RPO**: Fino al momento dell'ultimo export (potenzialmente giorni).

---

### 12.5 Opzione 5: LogMiner (Recupero Parziale)

Se hai gli archivelog ma non i datafile backup:

```sql
-- Avvia LogMiner
EXEC DBMS_LOGMNR.ADD_LOGFILE('/archive/arch_100.log', DBMS_LOGMNR.NEW);
EXEC DBMS_LOGMNR.ADD_LOGFILE('/archive/arch_101.log', DBMS_LOGMNR.ADDFILE);

EXEC DBMS_LOGMNR.START_LOGMNR(OPTIONS => DBMS_LOGMNR.DICT_FROM_ONLINE_CATALOG);

-- Cerca le operazioni da recuperare
SELECT sql_redo, sql_undo, timestamp, operation
FROM v$logmnr_contents
WHERE seg_name = 'IMPORTANT_TABLE'
  AND operation IN ('INSERT','UPDATE','DELETE')
ORDER BY timestamp;

EXEC DBMS_LOGMNR.END_LOGMNR;
```

---

## PARTE IV — POST-MORTEM, PREVENZIONE, MONITORING

---

## 13. Post-Mortem e Incident Report

### 13.1 Template Incident Report

```
========================================
INCIDENT REPORT - Backup RMAN Failed
========================================
Data/Ora Incidente   :
Database             :
Ambiente             : PROD / UAT / DEV
Tipo Backup          : FULL / INCR L0 / INCR L1 / ARCH
Errore Rilevato      : ORA-XXXXX / RMAN-XXXXX
Root Cause           :
Impatto              :
  - RPO attuale      :
  - Ultimo backup OK :
  - Dati a rischio   :
Timeline             :
  - Rilevazione      :
  - Inizio analisi   :
  - Fix applicato    :
  - Backup re-run OK :
MTTR (minuti)        :
Remediation Applicata:
Azioni Preventive    :
Approvazione         :
========================================
```

### 13.2 Root Cause Categories (per reporting)

| Categoria | Esempio | Azione Preventiva |
|---|---|---|
| Storage/Spazio | FRA piena, disco pieno | Alert proattivo su FRA > 80% |
| Metadata | Archivelog cancellato con rm | Policy: mai rm, sempre RMAN DELETE |
| Corruzione | Block corruption | VALIDATE schedulato settimanalmente |
| Encryption | Wallet non aperto | Auto-login wallet per backup schedulati |
| Media Manager | SBT/Tape non raggiungibile | Health check MML pre-backup |
| Permessi | chown/chmod errati | Ansible/Puppet per enforcement |
| Network | TNS/Listener down | Monitoring listener con CheckMK/OEM |
| Configurazione | Parametri RMAN errati | Review trimestrale configurazione |
| Hardware | Disco difettoso, RAID degradato | Hardware monitoring proattivo |

---

## 14. Checklist Preventiva

```
[ ] FRA monitorata con alert su > 80%
[ ] CROSSCHECK + DELETE OBSOLETE schedulati (settimanale)
[ ] RESTORE VALIDATE schedulato (settimanale)
[ ] VALIDATE DATABASE CHECK LOGICAL schedulato (settimanale)
[ ] Backup wallet/keystore separato e verificato
[ ] Test di restore completo (trimestrale)
[ ] Alert su v$rman_backup_job_details.status = 'FAILED'
[ ] Archivelog deletion policy corretta per Data Guard
[ ] Log RMAN centralizzati e monitorati
[ ] Documentazione runbook aggiornata
[ ] Auto-login wallet per backup schedulati
[ ] CONTROL_FILE_RECORD_KEEP_TIME >= retention + 7 giorni
[ ] Script backup con error handling e email alert
[ ] Separazione storage backup (diverso da production)
[ ] Snapshot SAN/storage come layer aggiuntivo
[ ] Data Pump export periodico come safety net
```

---

## 15. Query di Monitoring Proattivo

```sql
-- ============================================
-- MONITORING PROATTIVO BACKUP — Integra in OEM/CheckMK
-- ============================================

-- 1. Alert: nessun backup nelle ultime 24 ore
SELECT 'CRITICAL: No backup in 24h for ' || d.name AS alert_msg
FROM v$database d
WHERE NOT EXISTS (
  SELECT 1 FROM v$rman_backup_job_details
  WHERE status = 'COMPLETED'
    AND input_type IN ('DB FULL','DB INCR')
    AND start_time > SYSDATE - 1
);

-- 2. Alert: FRA > 85%
SELECT 'WARNING: FRA at ' || ROUND(space_used/space_limit*100,1) || '%' AS alert_msg
FROM v$recovery_file_dest
WHERE space_used/space_limit > 0.85;

-- 3. Alert: corruzioni presenti
SELECT 'CRITICAL: ' || COUNT(*) || ' corrupt blocks in DB ' || 
       (SELECT name FROM v$database) AS alert_msg
FROM v$database_block_corruption
HAVING COUNT(*) > 0;

-- 4. Alert: archivelog non backuppati > 50
SELECT 'WARNING: ' || COUNT(*) || ' archivelog non backuppati' AS alert_msg
FROM v$archived_log
WHERE backed_up = 'NO' AND deleted = 'NO'
HAVING COUNT(*) > 50;

-- 5. Alert: backup duration anomala (> 2x media)
WITH avg_duration AS (
  SELECT input_type, AVG(elapsed_seconds) AS avg_sec
  FROM v$rman_backup_job_details
  WHERE status = 'COMPLETED' AND start_time > SYSDATE - 30
  GROUP BY input_type
)
SELECT 'WARNING: Backup ' || j.input_type || ' took ' || 
       ROUND(j.elapsed_seconds/60) || ' min (avg: ' || 
       ROUND(a.avg_sec/60) || ' min)' AS alert_msg
FROM v$rman_backup_job_details j
JOIN avg_duration a ON j.input_type = a.input_type
WHERE j.start_time > SYSDATE - 1
  AND j.elapsed_seconds > a.avg_sec * 2;

-- 6. Report: storico backup ultimi 30 giorni
SELECT TO_CHAR(start_time,'YYYY-MM-DD') AS data,
       input_type, status,
       ROUND(elapsed_seconds/60) AS min,
       output_bytes_display
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 30
ORDER BY start_time DESC;
```

---

## 16. Tabella Riassuntiva Completa Errori

| # | Errore | Categoria | Causa | Risoluzione Rapida |
|---|---|---|---|---|
| 1 | ORA-19809/19804 | Storage | FRA piena | Aumenta FRA o DELETE OBSOLETE |
| 2 | ORA-19815 | Storage | FRA warning | Estendi FRA |
| 3 | ORA-00257 | Storage | Archiver stuck | Libera FRA |
| 4 | ORA-19502 | Storage | Write error | Libera disco, fix permessi |
| 5 | ORA-27072 | Storage | I/O OS error | Check hardware |
| 6 | ORA-15041 | Storage | ASM DG pieno | Aggiungi dischi |
| 7 | RMAN-06059 | Metadata | Archivelog mancante | CROSSCHECK+DELETE EXPIRED |
| 8 | RMAN-06054 | Metadata | Recovery needs arch | SET UNTIL o restore arch |
| 9 | RMAN-06169 | Metadata | Catalog connection | Fix TNS, RESYNC |
| 10 | RMAN-20242 | Metadata | No matching backup | CATALOG START WITH |
| 11 | RMAN-06004 | Metadata | Recovery area error | Fix FRA config |
| 12 | ORA-01578 | Corruption | Block corruption | BLOCKRECOVER |
| 13 | ORA-19566 | Corruption | Troppi corrotti | SET MAXCORRUPT |
| 14 | RMAN-08120 | Corruption | Piece corrotto | Rigenera backup |
| 15 | ORA-28365 | Encryption | Wallet non aperto | Apri keystore |
| 16 | ORA-46658 | Encryption | Keystore error | Fix wallet path |
| 17 | RMAN-12016 | Encryption | TDE non disponibile | Password encryption |
| 18 | RMAN-03009 | Channel | Channel failure | Fix canali/SBT |
| 19 | ORA-19511 | Channel | Media manager error | Check sbtio.log |
| 20 | ORA-27211 | Channel | SBT library fail | Fix path SBT |
| 21 | RMAN-10035 | Channel | Exception backup | Retry, check I/O |
| 22 | RMAN-10038 | Channel | I/O error | Check storage |
| 23 | ORA-27040/27041 | OS | Permessi file | chown oracle:oinstall |
| 24 | ORA-01031 | OS | Privileges | GRANT SYSBACKUP |
| 25 | ORA-12154 | Network | TNS not resolved | Fix tnsnames.ora |
| 26 | ORA-12541 | Network | Listener down | lsnrctl start |
| 27 | ORA-03113/03135 | Network | Connection lost | Check network |
| 28 | ORA-12170 | Network | TNS timeout | Check firewall |
| 29 | ORA-16055 | DataGuard | FAL rejected | Fix FAL params |
| 30 | ORA-16014 | DataGuard | Log not archived | Libera spazio |
| 31 | ORA-04031 | Memory | Shared pool full | Aumenta shared_pool |
| 32 | RMAN-00569 | General | Error stack banner | Analizza bottom-up |

---

## 17. Escalation a Oracle Support

### 17.1 Quando Aprire una SR

- ORA-600 o ORA-7445 durante backup
- Corruzione persistente non risolvibile con BMR
- Bug RMAN sospetto
- Comportamento non documentato

### 17.2 Informazioni da Raccogliere

1. Output completo del log RMAN
2. Alert log dell'intervallo errore
3. Output di `SHOW ALL` da RMAN
4. Output di `LIST FAILURE ALL`
5. IPS Package (da ADRCI)
6. AWR report dell'intervallo
7. OS info: `uname -a`, `df -h`, `free -m`, `uptime`
8. Patch level: `opatch lspatches`

---

## 18. Riferimenti Ufficiali

- Oracle Backup and Recovery User's Guide 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- Oracle RMAN Troubleshooting
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/troubleshooting-rman-operations.html
- MOS: RMAN Best Practices (Doc ID 394521.1)
- MOS: RMAN Troubleshooting Guide (Doc ID 360416.1)
- MOS: ORA-19809 (Doc ID 315098.1)
- MOS: How to Identify RMAN Backup Failures (Doc ID 1534280.1)
- MOS: Backup Recovery with RMAN FAQ (Doc ID 1593233.1)

---

**Documento confidenziale ad uso interno DBA. Aggiornare dopo ogni incidente. Ultima revisione: Maggio 2026.**
