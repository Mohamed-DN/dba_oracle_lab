# RMAN (Recovery Manager) - Full Cheatsheet e Calcoli

Questa guida copre tutti gli scenari principali di RMAN, dalle configurazioni di base al calcolo delle retention, fino agli script di backup e restore complessi.

## 1. Configurazione Iniziale e Retention Policy

### Mostrare e Modificare i Parametri
```bash
rman target /
RMAN> SHOW ALL;
```

### Calcolo e Impostazione della Retention Policy
La retention policy determina per quanto tempo i backup devono essere conservati.

**Opzione A: Recovery Window (Consigliata per ambienti Produttivi)**
Garantisce di poter fare un Point-in-Time Recovery (PITR) fino a N giorni nel passato.
```sql
RMAN> CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
```
*Calcolo spazio richiesto (Recovery Window):*
`Spazio = (Dimensione DB + Dimensione Archivelog Giornalieri * Giorni) + 1 Backup Full extra`
*Per una finestra di 7 giorni, servono i backup che coprono gli ultimi 7 giorni, PIÙ il backup full antecedente a quei 7 giorni.*

**Opzione B: Redundancy (Consigliata per ambienti di Test/Sviluppo)**
Conserva esattamente N copie dei backup di ogni datafile.
```sql
RMAN> CONFIGURE RETENTION POLICY TO REDUNDANCY 2;
```
*Calcolo spazio richiesto (Redundancy 2):*
`Spazio = Dimensione DB * 2 + Archivelog generati tra i backup`

### Altri Parametri Essenziali
```sql
-- Autodelete degli Archivelog già backuppati (utile in FRA)
RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO DEVICE TYPE DISK;

-- Abilitare il Backup Controlfile automatico
RMAN> CONFIGURE CONTROLFILE AUTOBACKUP ON;

-- Abilitare la compressione di default
RMAN> CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;
```

## 2. Block Change Tracking (Ottimizzazione Incrementali)
Essenziale per velocizzare i backup incrementali. Invece di scansionare tutto il database, RMAN legge questo file.
```sql
-- Da SQL*Plus:
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '/u01/app/oracle/oradata/DBNAME/bct01.trc';

-- Controllo:
SELECT status, filename FROM v$block_change_tracking;
```

## 3. Comandi di Backup

### Backup FULL Database (Level 0) + Archivelog
```bash
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c3 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c4 DEVICE TYPE DISK;
  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE FORMAT '/backup/db_%U.bkp';
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL NOT BACKED UP 1 TIMES FORMAT '/backup/arc_%U.bkp';
  DELETE NOPROMPT OBSOLETE;
}
```

### Backup Incrementale (Level 1)
Prende solo i blocchi modificati dall'ultimo Level 0 (se differenziale) o Level 1 (se cumulativo).
```bash
-- Differenziale (default)
BACKUP INCREMENTAL LEVEL 1 DATABASE;

-- Cumulativo (prende tutto dall'ultimo Level 0)
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE;
```

### Backup Singoli
```sql
-- Backup di una specifica tablespace
BACKUP TABLESPACE users;

-- Backup di un datafile
BACKUP DATAFILE 4;

-- Backup del Controlfile
BACKUP CURRENT CONTROLFILE;
```

## 4. Manutenzione (Crosscheck e Delete)
Allineare il repository di RMAN (o controlfile) con i file fisici presenti su disco/nastro.

```sql
-- Verifica dell'esistenza fisica dei file
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;

-- Cancellare i riferimenti a file spariti fisicamente (EXPIRED)
DELETE NOPROMPT EXPIRED BACKUP;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

-- Cancellare i file che superano la Retention Policy (OBSOLETE)
DELETE NOPROMPT OBSOLETE;

-- Forzare la cancellazione di archivelog vecchi (es. emergenza spazio FRA)
DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';
```

## 5. Esempi di RESTORE e RECOVER

### Scenario A: Ripristino Completo con Controlfile integro
```bash
RMAN> STARTUP MOUNT;
RMAN> RESTORE DATABASE;
RMAN> RECOVER DATABASE;
RMAN> ALTER DATABASE OPEN;
```

### Scenario B: Ripristino da Perdita di Controlfile e SPFILE
```bash
RMAN> STARTUP NOMOUNT;
RMAN> SET DBID 123456789; -- Obbligatorio se si usa autobackup senza repository
RMAN> RESTORE SPFILE FROM AUTOBACKUP;
RMAN> STARTUP FORCE NOMOUNT;
RMAN> RESTORE CONTROLFILE FROM AUTOBACKUP;
RMAN> ALTER DATABASE MOUNT;
RMAN> RESTORE DATABASE;
RMAN> RECOVER DATABASE;
RMAN> ALTER DATABASE OPEN RESETLOGS;
```

### Scenario C: Point-in-Time Recovery (PITR)
Riportare il DB a ieri alle ore 14:00.
```bash
RMAN> RUN {
  SET UNTIL TIME "TO_DATE('2026-05-26 14:00:00', 'YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
RMAN> ALTER DATABASE OPEN RESETLOGS;
```

### Scenario D: Restore di una singola Tablespace
La tablespace deve essere offline. Il resto del DB può rimanere aperto.
```bash
RMAN> SQL "ALTER TABLESPACE users OFFLINE IMMEDIATE";
RMAN> RESTORE TABLESPACE users;
RMAN> RECOVER TABLESPACE users;
RMAN> SQL "ALTER TABLESPACE users ONLINE";
```

## 6. Calcolo del Parallelismo (Allocazione Canali)
Il parallelismo ideale dipende da:
1. **CPU Cores:** Non allocare più canali dei core disponibili.
2. **Dischi:** Se il target di backup è un singolo disco lento (es. 1 HDD USB), aumentare i canali causerà I/O contention (degradando le performance). Se il target è uno storage NAS ad alte performance o NVMe, più canali satureranno la banda.
3. **Datafiles:** Il numero di canali non dovrebbe superare il numero di datafiles del database da backuppare (poiché un singolo datafile non viene splitato su più canali a meno che non si usi "SECTION SIZE").

**Uso di SECTION SIZE (Per Bigfile Tablespaces):**
Se hai un datafile da 1 TB e 4 canali, normalmente 1 canale farebbe il backup di quel file in 10 ore, mentre 3 canali sarebbero fermi.
```sql
BACKUP AS BACKUPSET DATABASE SECTION SIZE 10G;
-- Ora il file da 1TB viene diviso in "chunk" da 10GB, e tutti e 4 i canali lavoreranno in parallelo sullo stesso file.
```
