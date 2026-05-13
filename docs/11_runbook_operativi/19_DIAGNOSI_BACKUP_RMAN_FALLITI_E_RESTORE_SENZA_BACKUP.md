# Runbook: Diagnosi Root Cause Backup RMAN Falliti e Disaster Recovery

> Runbook operativo completo per identificare la causa radice (RCA) dei fallimenti backup RMAN,
> risolvere ogni tipo di errore e ripristinare il servizio quando i backup non esistono.

---

## 1. Classificazione Severita e SLA

| Severita | Condizione | SLA Risposta | Azione |
|---|---|---|---|
| **P1 - Critico** | Nessun backup valido nelle ultime 48h + nessuna standby | 15 min | Escalation immediata, notifica management |
| **P2 - Alto** | Backup FAILED ma ultimo backup valido < 48h | 1 ora | Diagnosi e re-run backup |
| **P3 - Medio** | Backup COMPLETED WITH WARNINGS | 4 ore | Analisi warning, fix preventivo |
| **P4 - Basso** | Backup lento o sub-ottimale | Next business day | Tuning, review configurazione |

---

## 2. Triage Iniziale (Primi 5 Minuti)

### 2.0 Dal messaggio di alert al job RMAN (esempio KB3888789)

Esempio notifica:
`KB3888789 - Profile dk1-pdb-3_cp3neml3, instance CP3NEML3_DK1_CAIUM, DB INCR backup (start time 05/09/2026 05:00) ended at 05/09/2026 05:57 with status FAILED`

| Campo nel messaggio | Significato operativo | Come usarlo subito |
|---|---|---|
| **Profile** | Ambiente/cluster | Filtra i log del tool di scheduling (OEM/cron/backup manager) |
| **Instance** | Istanza Oracle | Connettiti alla giusta istanza o al CDB corretto |
| **DB INCR backup** | Tipo backup | Mappa su `input_type` (`DB INCR`, `DB FULL`, `ARCHIVELOG`) |
| **start/end time** | Finestra temporale | Usa la finestra per cercare il job in `v$rman_backup_job_details` |
| **status FAILED** | Esito | Avvia subito RCA, vedi sezioni 2.x e 3.x |

**Step A — Trova il job RMAN esatto**
```sql
-- Ultimi 7 giorni (aggiungi un filtro su input_type solo se necessario).
SELECT session_key, input_type, status,
       start_time, end_time,
       output_device_type,
       ROUND(elapsed_seconds/60) AS duration_min
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
  AND start_time < SYSDATE
ORDER BY start_time DESC;
```

**Step B — Estrarre lo stack di errore dal job**
```sql
SELECT start_time,
       operation, status, object_type,
       SUBSTR(output,1,200) AS error_msg
FROM v$rman_status
WHERE session_key = <session_key>
  AND start_time >= SYSDATE - 7
  AND status NOT IN ('COMPLETED','RUNNING')
ORDER BY start_time;
```

**Step C — Recupera il log RMAN completo**
```bash
# 1) Capisci da dove parte il job (cron/OEM/backup manager)
crontab -l | grep -i rman

# 2) Cerca lo script e il percorso log
grep -R "rman target" /home/oracle/scripts -n
grep -R "log=" /home/oracle/scripts -n

# 3) Apri il log del job fallito
tail -200 /path/log/rman_20260509_0500.log
```

> Se usi OEM/Cloud Control: apri il job → **Output** → copia l'errore RMAN/ORA.
> Se usi un backup manager (NetBackup/Commvault/etc), apri il **job log** nel tool.

### 2.1 Identifica il Fallimento

```sql
-- Query 1: Status ultimi job RMAN (ultime 48 ore)
SELECT input_type,
       status,
       TO_CHAR(start_time, 'DD-MON HH24:MI') AS started,
       TO_CHAR(end_time, 'DD-MON HH24:MI') AS ended,
       ROUND(elapsed_seconds/60) AS duration_min,
       output_bytes_display AS output_size,
       output_device_type
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 2
ORDER BY start_time DESC;
```

| Status | Significato | Urgenza |
|---|---|---|
| COMPLETED | OK | Nessuna |
| COMPLETED WITH WARNINGS | Funzionato con avvisi | Media |
| COMPLETED WITH ERRORS | Errori parziali | Alta |
| FAILED | Fallito completamente | Critica |
| RUNNING | In corso | Monitorare |

### 2.2 Trova l'Errore Specifico

```sql
-- Query 2: Errori dettagliati dall'ultimo job
SELECT TO_CHAR(start_time,'DD-MON HH24:MI') AS ts,
       operation, status, object_type,
       SUBSTR(output,1,200) AS error_msg
FROM v$rman_status
WHERE start_time > SYSDATE - 2
  AND status NOT IN ('COMPLETED','RUNNING')
ORDER BY start_time DESC;
```

### 2.3 Check Alert Log

```bash
# Cerca errori RMAN/ORA nell'alert log
grep -E "ORA-|RMAN-" $ORACLE_BASE/diag/rdbms/*/trace/alert_*.log | tail -50

# Con ADRCI
adrci
set homepath diag/rdbms/prod/prod1
show alert -p "message_text like '%RMAN%' or message_text like '%ORA-19%' or message_text like '%ORA-27%'"
```

### 2.4 Check Spazio (FRA e Filesystem)

```sql
-- FRA usage
SELECT name,
       ROUND(space_limit/1024/1024/1024,1) AS limit_gb,
       ROUND(space_used/1024/1024/1024,1) AS used_gb,
       ROUND(space_used/space_limit*100,1) AS pct_used
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
df -Th /backup /u01 /u02
# ASM
asmcmd lsdg
```

---

## 3. Root Cause Analysis per Categoria di Errore

### 3.1 ERRORI DI SPAZIO (Storage)

#### ORA-19809 / ORA-19804: FRA Limit Exceeded

**Sintomo**: `ORA-19809: limit exceeded for recovery files` oppure `ORA-19804: cannot reclaim ... bytes disk space from ... limit`

**Root Cause**: La Fast Recovery Area ha raggiunto il limite definito in `db_recovery_file_dest_size`. RMAN non puo creare nuovi file.

**Diagnostica**:
```sql
SELECT SPACE_USED/1024/1024/1024 "USED_GB",
       SPACE_LIMIT/1024/1024/1024 "LIMIT_GB",
       SPACE_RECLAIMABLE/1024/1024/1024 "RECLAIMABLE_GB"
FROM v$recovery_file_dest;
```

**Remediation**:
```sql
-- Opzione A: Aumenta il limite (se c'e spazio disco)
ALTER SYSTEM SET db_recovery_file_dest_size = 200G SCOPE=BOTH;

-- Opzione B: Libera spazio via RMAN
-- RMAN> CROSSCHECK BACKUP;
-- RMAN> CROSSCHECK ARCHIVELOG ALL;
-- RMAN> DELETE NOPROMPT OBSOLETE;
-- RMAN> DELETE NOPROMPT EXPIRED BACKUP;
-- RMAN> DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

-- Opzione C: Backup archivelog su tape e poi cancella
-- RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
```

**Prevenzione**: Imposta alert su FRA > 80%. Dimensiona FRA >= 2x dimensione DB.

---

#### ORA-19815: FRA Warning Threshold

**Sintomo**: Warning nel alert log su db_recovery_file_dest_size.

**Remediation**: Come ORA-19809. Intervieni prima che diventi critico.

---

#### ORA-00257: Archiver Error / Archiver Stuck

**Sintomo**: `ORA-00257: archiver error. Connect internal only, until freed.`

**Root Cause**: L'archiver non riesce a scrivere archivelog. Causa piu comune: FRA piena o destinazione archivelog piena.

**Remediation**:
```sql
-- Verifica destinazione
SHOW PARAMETER log_archive_dest;
SHOW PARAMETER db_recovery_file_dest;
```
```bash
df -h $(grep -i "log_archive_dest" $ORACLE_HOME/dbs/init*.ora | awk -F= '{print $2}')
```
Libera spazio e l'archiver riparte automaticamente.

---

#### ORA-19502: Write Error on File

**Sintomo**: `ORA-19502: write error on file "...", block number ... `

**Root Cause**: RMAN non riesce a scrivere sulla destinazione. Filesystem pieno, permessi errati, NFS timeout, o hardware I/O failure.

**Diagnostica**:
```bash
# Check spazio
df -Th /backup
# Check permessi
ls -la /backup/
# Check errori OS
dmesg | tail -30
cat /var/log/messages | grep -i error | tail -20
```

**Remediation**:
1. Libera spazio sul filesystem target
2. Fix permessi: `chown -R oracle:oinstall /backup; chmod 750 /backup`
3. Se NFS: verifica mount options (`hard,rsize=32768,wsize=32768,tcp`)
4. Se hardware: contatta team storage

---

#### ORA-27072: File I/O Error (OS Level)

**Root Cause**: Errore I/O a livello sistema operativo. Disco difettoso, controller RAID degradato, cable fault.

**Diagnostica**:
```bash
dmesg | grep -i -E "error|fault|fail" | tail -20
smartctl -a /dev/sda  # se SMART disponibile
cat /proc/mdstat      # se software RAID
```

**Remediation**: Escalation a team infrastruttura/storage.

---

#### ORA-15041: ASM Diskgroup Full

**Root Cause**: Il diskgroup ASM usato come destinazione backup non ha spazio.

**Diagnostica**:
```sql
SELECT name, total_mb, free_mb, ROUND(free_mb/total_mb*100,1) AS pct_free
FROM v$asm_diskgroup;
```

**Remediation**: Aggiungi dischi al diskgroup o sposta backup su altro DG.

---

### 3.2 ERRORI DI METADATA E CATALOGO

#### RMAN-06059: Expected Archived Log Not Found

**Sintomo**: `RMAN-06059: expected archived log not found, loss of archived log compromises recoverability`

**Root Cause**: Un archivelog registrato nel controlfile/catalog non esiste piu sul disco. Tipicamente cancellato con `rm` invece di RMAN.

**Diagnostica**:
```rman
LIST EXPIRED ARCHIVELOG ALL;
CROSSCHECK ARCHIVELOG ALL;
```

**Remediation**:
```rman
-- 1. Sincronizza metadata
CROSSCHECK ARCHIVELOG ALL;

-- 2. Rimuovi references orfane
DELETE EXPIRED ARCHIVELOG ALL;

-- 3. Rilancia backup
BACKUP DATABASE PLUS ARCHIVELOG;

-- NOTA: La catena di recovery e rotta. Valuta un nuovo Full L0.
```

**Prevenzione**: MAI usare `rm` per cancellare archivelog. Sempre `RMAN> DELETE ARCHIVELOG...`

---

#### RMAN-06054: Media Recovery Requires Archived Log

**Sintomo**: Durante il RECOVER, RMAN richiede un archivelog che non trova.

**Root Cause**: Gap nella sequenza archivelog. Archivelog cancellato o mai generato.

**Remediation**:
```rman
-- Verifica gap
LIST ARCHIVELOG ALL;

-- Se il gap e irrecuperabile, usa PITR prima del gap
RUN {
  SET UNTIL SEQUENCE <seq_before_gap> THREAD 1;
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

---

#### RMAN-06169: Catalog Connection Failed

**Root Cause**: RMAN non riesce a connettersi al Recovery Catalog DB.

**Diagnostica**:
```bash
tnsping CATDB
lsnrctl status
```

**Remediation**: Fix TNS/listener del catalog DB. Dopo il fix: `RESYNC CATALOG;`

---

#### RMAN-20242: Specification Does Not Match Any Backup

**Root Cause**: Il backup specificato (per tag, time, o SCN) non esiste nel repository.

**Remediation**:
```rman
LIST BACKUP SUMMARY;
LIST BACKUP TAG 'nome_tag';
-- Se i file esistono ma non sono catalogati:
CATALOG START WITH '/path/to/backup/';
```

---

### 3.3 ERRORI DI CORRUZIONE

#### ORA-01578 / RMAN-08120: Block Corruption

**Sintomo**: `ORA-01578: ORACLE data block corrupted (file # x, block # y)`

**Root Cause**: Corruzione fisica o logica di uno o piu blocchi del datafile.

**Diagnostica**:
```sql
-- Blocchi corrotti noti
SELECT file#, block#, blocks, corruption_type, corruption_change#
FROM v$database_block_corruption
ORDER BY file#, block#;
```

**Remediation**:
```rman
-- Opzione A: Block Media Recovery (no downtime completo)
BLOCKRECOVER DATAFILE <file#> BLOCK <block#>;

-- Opzione B: Se molti blocchi, restore intero datafile
SQL "ALTER DATABASE DATAFILE <file#> OFFLINE";
RESTORE DATAFILE <file#>;
RECOVER DATAFILE <file#>;
SQL "ALTER DATABASE DATAFILE <file#> ONLINE";

-- Per permettere il backup anche con corruzioni:
RUN {
  SET MAXCORRUPT FOR DATAFILE <file#> TO 10;
  BACKUP DATABASE TAG 'WITH_CORRUPTION';
}
```

**Prevenzione**: `VALIDATE DATABASE CHECK LOGICAL;` schedulato settimanalmente.

---

### 3.4 ERRORI ENCRYPTION / TDE / WALLET

#### ORA-28365: Wallet is Not Open

**Root Cause**: RMAN con encryption configurata ma il Keystore/Wallet non e aperto.

**Diagnostica**:
```sql
SELECT wrl_type, status, wallet_type FROM v$encryption_wallet;
-- status deve essere OPEN o OPEN_NO_MASTER_KEY
```

**Remediation**:
```sql
-- Apri il wallet manualmente
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "wallet_password";

-- Per auto-login wallet (consigliato per backup schedulati):
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE FROM KEYSTORE '/path/to/wallet'
  IDENTIFIED BY "wallet_password";
```

---

#### RMAN-12016: Cannot Use TDE

**Root Cause**: TDE non abilitato/licenziato oppure wallet completamente assente.

**Remediation**: Usa cifratura con password come workaround:
```rman
SET ENCRYPTION ON IDENTIFIED BY 'backup_password' ONLY;
BACKUP DATABASE;
```

---

### 3.5 ERRORI CHANNEL / TAPE / SBT

#### RMAN-03009: Failure of Channel Command

**Root Cause**: Il canale (DISK o SBT) non riesce a operare. Su tape: libreria MML non raggiungibile.

**Diagnostica**:
```rman
SHOW ALL;
-- Verifica parametri CHANNEL e PARMS
```

```bash
# Test SBT library
sbttest test_file
# Verifica libreria MML
ls -la /usr/openv/netbackup/bin/libobk.so64
```

**Remediation**: Fix parametri ENV del media manager, verifica che il servizio tape sia attivo.

---

#### RMAN-10035 / RMAN-10038: Exception in Backup

**Root Cause**: Eccezione durante la scrittura di un backup piece. I/O error, timeout, o interruzione processo.

**Remediation**: Verifica subsystem I/O (storage, rete per NFS/tape). Retry il backup.

---

### 3.6 ERRORI DI PERMESSI E OS

#### ORA-27040 / ORA-27041: File Creation / Open Error

**Root Cause**: L'utente oracle non ha permessi per creare o aprire file nella directory di backup.

**Diagnostica**:
```bash
ls -la /backup/
id oracle
groups oracle
```

**Remediation**:
```bash
chown -R oracle:oinstall /backup
chmod 750 /backup
```

---

#### ORA-01031: Insufficient Privileges

**Root Cause**: L'utente RMAN non ha SYSDBA o SYSBACKUP.

**Remediation**:
```sql
GRANT SYSBACKUP TO backup_user;
```

---

### 3.7 ERRORI DI RETE E CONNESSIONE

#### ORA-12154: TNS Could Not Resolve / ORA-12541: No Listener

**Root Cause**: RMAN non riesce a risolvere il TNS alias o il listener e down.

**Diagnostica**:
```bash
tnsping TARGET_DB
lsnrctl status
cat $ORACLE_HOME/network/admin/tnsnames.ora | grep -A5 TARGET_DB
```

**Remediation**: Fix tnsnames.ora, start/restart listener.

---

#### ORA-03113 / ORA-03135: End-of-File on Communication Channel

**Root Cause**: La connessione di rete si e interrotta durante il backup. Timeout, firewall, o crash del processo.

**Diagnostica**: Check alert log per crash di processo. Check firewall/network timeout settings.

**Remediation**:
```sql
-- Aumenta timeout se necessario
ALTER SYSTEM SET sqlnet.recv_timeout=300 SCOPE=SPFILE;
```

---

### 3.8 ERRORI DATA GUARD SPECIFICI

#### ORA-16055: FAL Request Rejected

**Root Cause**: La standby non riesce a richiedere archivelog al primary.

**Diagnostica**:
```sql
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;
```

**Remediation**: Verifica parametri FAL_SERVER/FAL_CLIENT. Fix rete tra primary e standby.

---

#### ORA-16014: Log Not Archived

**Root Cause**: L'archiver non riesce a archiviare il redo log corrente.

**Remediation**: Come ORA-00257. Libera spazio per archivelog.

---

## 4. Disaster Recovery: Ripristino SENZA Backup RMAN

Quando i backup RMAN risultano inutilizzabili o inesistenti.

### 4.1 Verifica: Davvero Non Ci Sono Backup?

```rman
-- Verifica inventory
LIST BACKUP SUMMARY;

-- Crosscheck per aggiornare metadata
CROSSCHECK BACKUP;

-- Cerca backup non catalogati su disco
CATALOG START WITH '/backup/';
CATALOG START WITH '+RECO/';

-- Cerca autobackup controlfile (puo esistere anche se il rest non c'e)
RESTORE CONTROLFILE FROM AUTOBACKUP;
```

Se dopo tutti i check non ci sono backup, usa le opzioni sotto.

### 4.2 Opzione 1: Failover su Standby (Data Guard)

Se esiste un database fisico standby:

```bash
# Con DGMGRL
dgmgrl sys/pwd@STBY
DGMGRL> FAILOVER TO 'stby_db' IMMEDIATE;
```

```sql
-- Se DGMGRL non disponibile:
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE FINISH;
ALTER DATABASE ACTIVATE STANDBY DATABASE;
ALTER DATABASE OPEN;
```

**RPO**: Zero (se SYNC mode) o minuti (se ASYNC).

### 4.3 Opzione 2: Flashback Database

Se il database si avvia in MOUNT e Flashback era abilitato:

```sql
SELECT flashback_on FROM v$database;
SELECT oldest_flashback_scn, oldest_flashback_time FROM v$flashback_database_log;
```

```sql
-- Ripristina a un punto nel tempo
FLASHBACK DATABASE TO TIMESTAMP TO_TIMESTAMP('2026-05-13 14:00:00','YYYY-MM-DD HH24:MI:SS');
ALTER DATABASE OPEN RESETLOGS;

-- Oppure a un restore point
FLASHBACK DATABASE TO RESTORE POINT before_upgrade;
ALTER DATABASE OPEN RESETLOGS;
```

### 4.4 Opzione 3: Storage Snapshot / SAN Recovery

Se i LUN sono protetti da snapshot a livello storage (NetApp, EMC, PureStorage):

1. `SHUTDOWN ABORT` dell'istanza Oracle
2. Ripristina snapshot a livello storage
3. `STARTUP MOUNT`
4. Se online redo log sopravvissuti: `RECOVER DATABASE;` poi `ALTER DATABASE OPEN;`
5. Se redo persi: `ALTER DATABASE OPEN RESETLOGS;`

### 4.5 Opzione 4: Ricostruzione Logica (Data Pump)

Ultimo resort se nessuna altra opzione:

1. Installa un database vuoto temporaneo
2. Importa l'ultimo export Data Pump (`impdp`)
3. Riallinea dati da log applicativi o sorgenti batch

---

## 5. Post-Mortem e Prevenzione

### 5.1 Template Incident Report

Dopo ogni backup fallito P1/P2, documenta:

```
INCIDENT REPORT - Backup RMAN Failed
=====================================
Data/Ora Incidente:
Database:
Tipo Backup (Full/Incr/Arch):
Errore Rilevato:
Root Cause:
Impatto (RPO attuale, dati a rischio):
Remediation Applicata:
Tempo di Risoluzione (MTTR):
Azioni Preventive:
```

### 5.2 Checklist Preventiva

- [ ] FRA monitorata con alert su > 80%
- [ ] CROSSCHECK + DELETE OBSOLETE schedulati (settimanale)
- [ ] RESTORE VALIDATE schedulato (settimanale)
- [ ] VALIDATE DATABASE CHECK LOGICAL schedulato (settimanale)
- [ ] Backup wallet/keystore separato e verificato
- [ ] Test di restore completo (trimestrale)
- [ ] Alert su `v$rman_backup_job_details.status = 'FAILED'`
- [ ] Archivelog deletion policy corretta per Data Guard
- [ ] Log RMAN centralizzati e monitorati
- [ ] Documentazione runbook aggiornata

### 5.3 Query di Monitoring Proattivo

```sql
-- Alert: ultimo backup > 24 ore
SELECT 'ALERT: No backup in 24h for ' || d.name AS alert_msg
FROM v$database d
WHERE NOT EXISTS (
  SELECT 1 FROM v$rman_backup_job_details
  WHERE status = 'COMPLETED'
    AND input_type = 'DB FULL'
    AND start_time > SYSDATE - 1
);

-- Alert: FRA > 85%
SELECT 'ALERT: FRA at ' || ROUND(space_used/space_limit*100,1) || '%' AS alert_msg
FROM v$recovery_file_dest
WHERE space_used/space_limit > 0.85;

-- Alert: Corruzioni presenti
SELECT 'ALERT: ' || COUNT(*) || ' corrupt blocks detected' AS alert_msg
FROM v$database_block_corruption
HAVING COUNT(*) > 0;
```

---

## 6. Escalation a Oracle Support

### 6.1 Quando Aprire una SR

- ORA-600 o ORA-7445 durante backup
- Corruzione persistente non risolvibile con BMR
- Bug RMAN sospetto (comportamento non documentato)

### 6.2 Informazioni da Raccogliere

1. Output completo del backup RMAN (log file)
2. Alert log dell'intervallo dell'errore
3. Output di `SHOW ALL` da RMAN
4. Output di `LIST FAILURE ALL`
5. IPS Package: `adrci> ips create package incident <id>; ips generate package <pkg> in /tmp`
6. AWR report dell'intervallo
7. OS info: `uname -a`, `df -h`, `free -m`

---

**Documento ad uso interno DBA. Aggiornare dopo ogni incidente.**
