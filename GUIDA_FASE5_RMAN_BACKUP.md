# FASE 5: Strategia RMAN Backup su Tutti i Database

> Il backup è la tua ultima linea di difesa. Non importa quanto siano sofisticate le tue soluzioni di HA (RAC, Data Guard, GoldenGate): se un errore umano cancella una tabella, solo un backup RMAN può salvarti.

---

## 5.0 Ingresso da Fase 4 (gate operativo)

Prima di impostare la strategia RMAN, il sistema deve essere stabile:

```bash
# Data Guard
dgmgrl sys/<password>@RACDB "show configuration;"
```

```sql
-- Spazio FRA (primario e standby)
sqlplus / as sysdba
SELECT name, space_limit/1024/1024 mb_limit, space_used/1024/1024 mb_used
FROM v$recovery_file_dest;
```

Check minimi:

- DGMGRL `SUCCESS`
- FRA non satura (idealmente < 80%)

Se hai gia creato gli script RMAN in test precedenti, non ricrearli: validali e aggiorna solo retention/schedule.

---

## 5.1 La Strategia di Backup

### Backup su TUTTI e 3 i Database

```
                         ┌──────────────────────┐
                         │   RAC PRIMARY         │
                         │   (RACDB)             │
                         │   → Archivelog backup │───→ 🗄️ +FRA
                         │   → Level 1 leggero   │     (ogni 2h + giornaliero)
                         └──────────┬─────────────┘
                                    │ Redo Shipping
                                    ▼
                         ┌──────────────────────┐
                         │   RAC STANDBY (ADG)   │
                         │   (RACDB_STBY)        │
                         │   → BACKUP PRINCIPALE │───→ 🗄️ +FRA
                         │   Level 0 + Level 1   │     (full + incr + arch)
                         └──────────┬─────────────┘
                                    │ GoldenGate
                                    ▼
                         ┌──────────────────────┐
                         │   TARGET DB           │
                         │   (dbtarget)          │
                         │   → Backup separato   │───→ 🗄️ Disco locale
                         └──────────────────────┘
```

> **Perché il backup PRINCIPALE sullo standby?** RMAN Level 0 (full) usa molta CPU e I/O. Sullo standby queste risorse non servono ai client. Il backup fatto sullo standby è **identico** a quello fatto sul primario.
>
> **Perché backup ANCHE sul primario?** Per sicurezza aggiuntiva: se lo standby è in manutenzione o crasha, il backup degli archivelog sul primario ti protegge dalla perdita totale. Inoltre, un Level 1 leggero garantisce un RPO (Recovery Point Objective) più basso.

---

## 5.2 Configurazione RMAN Base (Valida per tutti i DB)

### Connessione RMAN

```bash
# Sul Primario
rman TARGET /

# Sullo Standby
rman TARGET /

# Sul Target
rman TARGET /
```

### Configurazione Iniziale (esegui su ogni DB)

```rman
-- Mostra la configurazione attuale
SHOW ALL;

-- Configura la retention policy (mantieni backup per 7 giorni)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

-- Configura il backup automatico del controlfile e SPFILE
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '+FRA/%F';

-- Configura la parallelizzazione (2 canali per usare 2 CPU)
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COMPRESSED BACKUPSET;

-- Abilita la compressione (riduce lo spazio ~60-70%)
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';

-- Configura il formato dei backup
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+FRA/RACDB/%U';

-- Abilita l'ottimizzazione (salta i file già backuppati che non sono cambiati)
CONFIGURE BACKUP OPTIMIZATION ON;

-- Abilita block change tracking (accelera gli incrementali)
-- SOLO SU PRIMARIO O STANDBY, NON SU ENTRAMBI
-- Consigliato sullo Standby se fai backup da lì
```

> **Spiegazione:**
> - `RECOVERY WINDOW OF 7 DAYS`: Mantiene abbastanza backup per poter ripristinare il DB a qualsiasi punto negli ultimi 7 giorni.
> - `COMPRESSED BACKUPSET`: Comprime i backup riducendo lo spazio disco.
> - `BACKUP OPTIMIZATION ON`: Se fai un backup full e un datafile non è cambiato dal backup precedente, RMAN lo salta.

---

## 5.3 Block Change Tracking (BCT) — Accelera gli Incrementali

Il BCT tiene traccia di quali blocchi sono cambiati, rendendo i backup incrementali **10-100x più veloci**.

### Sul Primario (RACDB) — se fai backup dal primario:

```sql
sqlplus / as sysdba

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/RACDB/bct_racdb.dbf';

-- Verifica
SELECT filename, status, bytes/1024/1024 size_mb FROM v$block_change_tracking;
```

### Sullo Standby (RACDB_STBY) — CONSIGLIATO:

```sql
sqlplus / as sysdba

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/RACDB_STBY/bct_racdb_stby.dbf';
```

### Sul Target (dbtarget):

```sql
sqlplus / as sysdba

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '/u01/app/oracle/oradata/dbtarget/bct_dbtarget.dbf';
```

> **Perché il BCT?** Senza BCT, un backup incrementale deve leggere OGNI blocco del database per capire se è cambiato. Con BCT, Oracle tiene un "diario" dei blocchi modificati e RMAN legge solo quelli. Su un database da 100 GB, un incrementale senza BCT può richiedere 30 minuti; con BCT, 2 minuti.

---

## 5.4 Script di Backup — RAC Standby (Backup Principale)

Questo è il backup **più importante** della tua infrastruttura. Viene eseguito sullo standby ADG.

### Backup Level 0 (Full) — Domenica

```bash
cat > /home/oracle/scripts/rman_full_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_full_backup.sh — Backup Full (Level 0) dallo Standby
# Eseguire SOLO sullo Standby (RACDB_STBY)

source /home/oracle/.db_env
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_full_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;

    -- Backup Full Database (Level 0)
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 0
        DATABASE
        TAG 'FULL_WEEKLY'
        PLUS ARCHIVELOG
            TAG 'ARCH_WITH_FULL'
            DELETE INPUT;

    -- Backup del Controlfile e SPFILE
    BACKUP CURRENT CONTROLFILE TAG 'CTL_WEEKLY';
    BACKUP SPFILE TAG 'SPFILE_WEEKLY';

    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

-- Rimuovi i backup obsoleti secondo la retention policy
DELETE NOPROMPT OBSOLETE;

-- Crosscheck per rimuovere riferimenti a backup cancellati manualmente
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
EOF

# Controlla se RMAN ha avuto errori
if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
    # Qui puoi aggiungere una notifica email
else
    echo "Backup Full completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_full_backup.sh
```

> **Spiegazione:**
> - `INCREMENTAL LEVEL 0`: Backup full di tutti i blocchi. È la "base" per gli incrementali successivi.
> - `PLUS ARCHIVELOG DELETE INPUT`: Backuppa anche gli archivelog e li cancella dopo il backup (libera spazio su +FRA).
> - `DELETE NOPROMPT OBSOLETE`: Rimuove i backup più vecchi della retention window (7 giorni).
> - `CROSSCHECK`: Verifica che i file di backup esistano fisicamente. Se qualcuno li ha cancellati a mano, RMAN li marca come EXPIRED.

### Backup Level 1 (Incrementale) — Tutti i giorni

```bash
cat > /home/oracle/scripts/rman_incr_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_incr_backup.sh — Backup Incrementale (Level 1) dallo Standby

source /home/oracle/.db_env
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_incr_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;

    -- Backup Incrementale Level 1
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1
        DATABASE
        TAG 'INCR_DAILY'
        PLUS ARCHIVELOG
            TAG 'ARCH_WITH_INCR'
            DELETE INPUT;

    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

-- Pulizia
DELETE NOPROMPT OBSOLETE;
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;
EOF

if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
else
    echo "Backup Incrementale completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_incr_backup.sh
```

> **Perché Level 1 e non Level 0 ogni giorno?** Un Level 0 copia TUTTI i blocchi. Un Level 1 copia SOLO i blocchi cambiati dal Level 0 (o dal Level 1 precedente). Su un DB da 50 GB dove ogni giorno cambiano 2 GB di dati, il Level 1 è 25x più veloce e usa 25x meno spazio.

### Backup Archivelog — Ogni 2 ore

```bash
cat > /home/oracle/scripts/rman_arch_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_arch_backup.sh — Backup Archivelog

source /home/oracle/.db_env

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_arch_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    TAG 'ARCH_HOURLY'
    DELETE INPUT;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_arch_backup.sh
```

> **Perché ogni 2 ore?** Gli archivelog si accumulano nella FRA. Se non li backuppi e cancelli regolarmente, la FRA si riempie e il database si ferma (non può più scrivere redo). `NOT BACKED UP 1 TIMES` assicura che vengano backuppati almeno una volta prima di essere cancellati.

---

## 5.5 Script di Backup — Target (dbtarget)

Il target GoldenGate ha una strategia più semplice perché può sempre essere ricreato ricarcando i dati dal primario.

```bash
cat > /home/oracle/scripts/rman_target_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_target_backup.sh — Backup per il DB Target GoldenGate

source /home/oracle/.db_env

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_target_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 3 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u01/backup/dbtarget/%F';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/u01/backup/dbtarget/%U';

RUN {
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1 CUMULATIVE
        DATABASE
        TAG 'TARGET_DAILY'
        PLUS ARCHIVELOG
            TAG 'TARGET_ARCH'
            DELETE INPUT;

    BACKUP CURRENT CONTROLFILE TAG 'TARGET_CTL';
}

DELETE NOPROMPT OBSOLETE;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_target_backup.sh
```

> **Perché `CUMULATIVE`?** Un Level 1 Cumulative include TUTTE le modifiche dal Level 0, non solo quelle dal Level 1 precedente. Il restore è più veloce perché servono solo il Level 0 + l'ultimo Level 1 Cumulative (non tutti i Level 1 intermedi).

```bash
# Crea la directory di backup sul Target
mkdir -p /u01/backup/dbtarget
chown oracle:oinstall /u01/backup/dbtarget
```

---

## 5.5b Script di Backup — RAC PRIMARIO (RACDB)

Anche il primario ha il suo backup — leggero ma essenziale come rete di sicurezza.

```bash
cat > /home/oracle/scripts/rman_primary_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_primary_backup.sh — Backup dal Primario
# Level 1 incrementale + archivelog
# PIÙ LEGGERO di quello sullo standby

source /home/oracle/.db_env
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_primary_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;

    -- Solo Level 1 (NON Level 0 full per non sovraccaricare)
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1
        DATABASE
        TAG 'PRIMARY_INCR_DAILY'
        PLUS ARCHIVELOG
            TAG 'PRIMARY_ARCH'
            DELETE INPUT;

    -- Backup Controlfile + SPFILE
    BACKUP CURRENT CONTROLFILE TAG 'PRIMARY_CTL';
    BACKUP SPFILE TAG 'PRIMARY_SPFILE';

    RELEASE CHANNEL ch1;
}

DELETE NOPROMPT OBSOLETE;
EOF

if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
else
    echo "Backup Primario completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_primary_backup.sh
```

> **Perché solo Level 1 sul primario?** Il Level 0 (full) è pesante e lo fa già lo standby la domenica. Il primario fa solo il Level 1, che è leggero e veloce grazie al BCT. Se lo standby crasha, hai comunque un backup recente dal primario.

---

## 5.6 Schedulazione con Cron

```bash
# Come utente oracle, su OGNI macchina
crontab -e
```

### Sul Primario (rac1):

```cron
# Backup Incrementale — Ogni giorno alle 04:00 (sfalsato dallo standby)
0 4 * * * /home/oracle/scripts/rman_primary_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# Backup Archivelog — Ogni 2 ore
0 */2 * * * /home/oracle/scripts/rman_arch_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

### Sullo Standby (racstby1):

```cron
# Backup Full — Domenica alle 02:00
0 2 * * 0 /home/oracle/scripts/rman_full_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# Backup Incrementale — Lun-Sab alle 02:00
0 2 * * 1-6 /home/oracle/scripts/rman_incr_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# Backup Archivelog — Ogni 2 ore
0 */2 * * * /home/oracle/scripts/rman_arch_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

### Sul Target (dbtarget):

```cron
# Backup Daily — Ogni giorno alle 03:00
0 3 * * * /home/oracle/scripts/rman_target_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

---

## 5.7 Verifica dei Backup

### Report dei backup

```rman
rman TARGET /

-- Lista tutti i backup
LIST BACKUP SUMMARY;

-- Lista backup recenti del DB
LIST BACKUP OF DATABASE COMPLETED AFTER 'SYSDATE-1';

-- Lista backup degli archivelog
LIST BACKUP OF ARCHIVELOG ALL;

-- Verifica l'integrità di tutti i backup (controlla che siano leggibili)
-- ATTENZIONE: questo legge fisicamente i file, può richiedere tempo
VALIDATE BACKUP;

-- Report dei file non backuppati
REPORT NEED BACKUP;

-- Report dei file unrecoverable
REPORT UNRECOVERABLE DATABASE;
```

### Script di Report Automatico

```bash
cat > /home/oracle/scripts/rman_report.sh <<'SCRIPT'
#!/bin/bash
source /home/oracle/.db_env

echo "=== RMAN BACKUP REPORT === $(date)"
echo ""

rman TARGET / <<EOF
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
CROSSCHECK BACKUP;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_report.sh
```

---

## 5.8 Test di Restore (FONDAMENTALE!)

> **Un backup mai testato è un backup che non esiste.** Testa il restore regolarmente.

### Test 1: Restore di una tabella singola (Point-in-Time Recovery)

```rman
-- Questo test NON modifica il database reale
-- Usa RMAN Table Point-in-Time Recovery (TSPITR)

rman TARGET /

-- Verifica che il backup sia utilizzabile per il restore
RESTORE DATABASE PREVIEW;
RESTORE DATABASE VALIDATE;
```

### Test 2: Restore su una location alternativa

```rman
-- Se hai spazio, puoi fare un restore completo su un path diverso
-- per verificare che tutto funzioni

RUN {
    SET NEWNAME FOR DATAFILE 1 TO '/tmp/restore_test/system01.dbf';
    SET NEWNAME FOR DATAFILE 2 TO '/tmp/restore_test/sysaux01.dbf';
    -- ... etc.
    RESTORE DATABASE;
    -- NON fare RECOVER: è solo un test
}
```

### Test 3: Verifica Restore da Standby al Primario

```rman
-- Connettiti al primario usando il catalog dello standby
rman TARGET sys/<password>@RACDB AUXILIARY sys/<password>@RACDB_STBY

-- Il backup fatto sullo standby è usabile per il primario
RESTORE DATABASE PREVIEW;
```

---

## 5.9 Schema Riassuntivo della Strategia

| Database | Tipo Backup | Frequenza | Retention | Dove |
|---|---|---|---|---|
| **RACDB (Primary)** | Level 1 Incremental | Ogni giorno 04:00 | 7 giorni | +FRA |
| **RACDB (Primary)** | Archivelog | Ogni 2 ore | — | +FRA |
| **RACDB_STBY (Standby)** | Level 0 Full | Domenica 02:00 | 7 giorni | +FRA |
| **RACDB_STBY (Standby)** | Level 1 Incr | Lun-Sab 02:00 | 7 giorni | +FRA |
| **RACDB_STBY (Standby)** | Archivelog | Ogni 2 ore | — | +FRA |
| **dbtarget (Target GG)** | Level 1 Cumulative | Ogni giorno 03:00 | 3 giorni | /u01/backup |

---

## 5.10 Statistiche, Health Check e Manutenzione Automatica

> **Perché le statistiche?** Oracle usa le statistiche degli oggetti (tabelle, indici) per calcolare il piano di esecuzione ottimale delle query. Statistiche vecchie = piani sbagliati = query lente. Sono il carburante dell'ottimizzatore.

### Raccolta Statistiche (Automatica — già attiva di default)

Oracle raccoglie automaticamente le statistiche tramite il job `GATHER_STATS_JOB` che gira nella maintenance window (di notte). Verifica che sia attivo:

```sql
-- Verifica che la raccolta automatica sia attiva
SELECT client_name, status FROM dba_autotask_client 
WHERE client_name = 'auto optimizer stats collection';
-- Deve mostrare: ENABLED

-- Vedi quando ha girato l'ultima volta
SELECT client_name, window_name, jobs_created, jobs_started, jobs_completed
FROM dba_autotask_client_history 
WHERE client_name LIKE '%stats%' 
ORDER BY window_start_time DESC FETCH FIRST 5 ROWS ONLY;
```

### Raccolta Statistiche Manuale (per tabelle specifiche)

```sql
-- Statistiche su uno schema intero
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR', CASCADE => TRUE, DEGREE => 4);

-- Statistiche su una tabella specifica
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'EMPLOYEES', CASCADE => TRUE);

-- Statistiche su TUTTO il database (pesante — fallo solo se necessario)
EXEC DBMS_STATS.GATHER_DATABASE_STATS(DEGREE => 4);
```

> **`CASCADE => TRUE`**: Raccoglie anche le statistiche degli indici della tabella.
> **`DEGREE => 4`**: Usa 4 processi paralleli per velocizzare.

### Verifica Tabelle con Statistiche Vecchie

```sql
-- Tabelle con statistiche più vecchie di 7 giorni e > 10% righe modificate
SELECT owner, table_name, last_analyzed, num_rows, stale_stats
FROM dba_tab_statistics 
WHERE stale_stats = 'YES' 
AND owner NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN')
ORDER BY num_rows DESC;
```

### Health Check Completo del Database

```sql
-- ============= HEALTH CHECK SCRIPT =============
-- Eseguilo una volta al giorno o dopo ogni intervento

-- 1. Stato dell'istanza
SELECT inst_id, instance_name, status, startup_time FROM gv$instance;

-- 2. Spazio Tablespace (> 85% = WARNING, > 95% = CRITICAL)
SELECT tablespace_name, 
       ROUND(used_percent, 1) AS "Used%",
       CASE WHEN used_percent > 95 THEN '🔴 CRITICAL'
            WHEN used_percent > 85 THEN '🟡 WARNING'
            ELSE '🟢 OK' END AS status
FROM dba_tablespace_usage_metrics
ORDER BY used_percent DESC;

-- 3. Spazio ASM
SELECT name, state, type, 
       ROUND(total_mb/1024,1) AS total_gb, 
       ROUND(free_mb/1024,1) AS free_gb,
       ROUND((1-free_mb/total_mb)*100,1) AS "Used%"
FROM v$asm_diskgroup;

-- 4. Alert log errori recenti (ORA-)
SELECT originating_timestamp, message_text 
FROM v$diag_alert_ext 
WHERE originating_timestamp > SYSDATE - 1
AND message_text LIKE '%ORA-%'
ORDER BY originating_timestamp DESC FETCH FIRST 20 ROWS ONLY;

-- 5. Sessioni attive per wait class
SELECT wait_class, COUNT(*) AS sessions
FROM gv$session WHERE status = 'ACTIVE' AND wait_class != 'Idle'
GROUP BY wait_class ORDER BY sessions DESC;

-- 6. Data Guard lag (solo sullo standby)
SELECT name, value, datum_time FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- 7. Job falliti nelle ultime 24 ore
SELECT job_name, status, actual_start_date, run_duration
FROM dba_scheduler_job_run_details
WHERE actual_start_date > SYSDATE - 1 AND status = 'FAILED';

-- 8. Invalid objects
SELECT owner, object_type, object_name FROM dba_objects 
WHERE status = 'INVALID' 
AND owner NOT IN ('SYS','SYSTEM','PUBLIC')
ORDER BY owner, object_type;

-- 9. FRA usage
SELECT * FROM v$flash_recovery_area_usage;
SELECT ROUND(space_limit/1024/1024/1024,2) AS limit_gb, 
       ROUND(space_used/1024/1024/1024,2) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024,2) AS reclaimable_gb
FROM v$recovery_file_dest;
```

### Script Health Check Automatico

```bash
cat > /home/oracle/scripts/daily_health_check.sh <<'SCRIPT'
#!/bin/bash
# daily_health_check.sh — Report giornaliero del database
source /home/oracle/.db_env

LOG=/home/oracle/scripts/logs/health_$(date +%Y%m%d).log
echo "=== DAILY HEALTH CHECK — $(date) ===" > $LOG

sqlplus -s / as sysdba >> $LOG <<SQL
SET LINESIZE 200 PAGESIZE 100

PROMPT
PROMPT === INSTANCE STATUS ===
SELECT inst_id, instance_name, status FROM gv\$instance;

PROMPT
PROMPT === TABLESPACE USAGE ===
SELECT tablespace_name, ROUND(used_percent,1) AS pct_used FROM dba_tablespace_usage_metrics WHERE used_percent > 80 ORDER BY used_percent DESC;

PROMPT
PROMPT === ASM DISKGROUP ===
SELECT name, ROUND((1-free_mb/total_mb)*100,1) AS pct_used FROM v\$asm_diskgroup;

PROMPT
PROMPT === STALE STATISTICS ===
SELECT owner, COUNT(*) AS stale_tables FROM dba_tab_statistics WHERE stale_stats='YES' AND owner NOT IN ('SYS','SYSTEM') GROUP BY owner;

PROMPT
PROMPT === RECENT ORA ERRORS ===
SELECT originating_timestamp, SUBSTR(message_text,1,120) FROM v\$diag_alert_ext WHERE originating_timestamp > SYSDATE-1 AND message_text LIKE '%ORA-%' FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT === INVALID OBJECTS ===
SELECT owner, object_type, COUNT(*) FROM dba_objects WHERE status='INVALID' AND owner NOT IN ('SYS','SYSTEM','PUBLIC') GROUP BY owner, object_type;
SQL

echo "" >> $LOG
echo "=== END HEALTH CHECK ===" >> $LOG
cat $LOG
SCRIPT

chmod +x /home/oracle/scripts/daily_health_check.sh
```

Aggiungi al cron su TUTTI i database:

```cron
# Health Check giornaliero — Ogni giorno alle 08:00
0 8 * * * /home/oracle/scripts/daily_health_check.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

---

## ✅ Checklist Fine Fase 5

```bash
# 1. BCT attivo sui DB dove esegui incrementali
sqlplus -s / as sysdba <<< "SELECT status FROM v\$block_change_tracking;"

# 2. Backup eseguito con successo
rman TARGET / <<< "LIST BACKUP SUMMARY;"

# 3. Cron configurato
crontab -l

# 4. Restore testato
rman TARGET / <<< "RESTORE DATABASE VALIDATE;"
```

---

**→ Prossimo consigliato: [FASE 6: Enterprise Manager Cloud Control](./GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md)**

---

## 🎉 Congratulazioni (Core Stack Completato)

Hai completato il core dell'architettura Oracle (HA + DR + replica + backup):

```
RAC Primary (RACDB)
    ├── Data Guard → RAC Standby (RACDB_STBY)
    │                    ├── RMAN Backup (Level 0 + Level 1)
    │                    └── GoldenGate Extract
    │                            └── → Target DB (dbtarget)
    │                                      └── RMAN Backup (Cumulative)
    └── Force Logging + Archivelog Mode
```

Hai imparato:
1. **RAC**: High Availability locale con failover automatico.
2. **Data Guard**: Disaster Recovery con standby fisico.
3. **GoldenGate**: Replica logica cross-platform verso un target indipendente.
4. **RMAN**: Backup & Recovery professionale su TUTTI i database.
5. **Statistiche & Maintenance**: Health check, statistiche dell'ottimizzatore, monitoraggio proattivo.
6. **Patching**: OPatch, opatchauto, datapatch per Grid e Database.

Passo successivo naturale: centralizzare monitoraggio e governance con Enterprise Manager (Fase 6).
