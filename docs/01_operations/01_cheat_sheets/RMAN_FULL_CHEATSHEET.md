# Enterprise RMAN (Recovery Manager) - Cheat Sheet & Architettura

> [!NOTE]
> **DOCUMENTI RMAN CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cheat Sheet Veloce**: [CHEAT_SHEET_RMAN_ESSENZIALE.md](./CHEAT_SHEET_RMAN_ESSENZIALE.md) (comandi rapidi quotidiani).
> - **Cheat Sheet Operativo**: [CHEAT_SHEET_RMAN.md](./CHEAT_SHEET_RMAN.md) (scenari operativi comuni).
> - **Manuale Comandi Core**: [GUIDA_RMAN_COMANDI_ENTERPRISE.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md) (riferimento completo dei parametri).
> - **Guida Architetturale Core**: [GUIDA_RMAN_COMPLETA_19C.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMPLETA_19C.md) (fondamenti teorici e scenari avanzati).

Questo documento rappresenta la guida di riferimento definitiva per l'architettura di backup e ripristino Oracle (RMAN) in ambienti Enterprise, Multi-tenant (CDB/PDB), e Cloud-Hybrid. Contiene scenari di disastro estremi, recovery a livello di blocco, tuning dei canali I/O e logica di retention profonda.

---

## 1. Architettura Enterprise RMAN

Un ambiente RMAN robusto non si basa solo sul Controlfile locale, ma utilizza un'infrastruttura separata.

### 1.1 Recovery Catalog
Il Recovery Catalog è un database separato che memorizza i metadati di RMAN di multipli database (Target). Consente di bypassare il limite di tempo (definito da `CONTROL_FILE_RECORD_KEEP_TIME`, di default 7 giorni) per il mantenimento dello storico dei backup.

**Creazione del Catalog (su database separato):**
```sql
-- Sul DB del Catalog:
CREATE TABLESPACE rman_cat_ts DATAFILE '+DATA' SIZE 2G AUTOEXTEND ON;
CREATE USER rcvcat_owner IDENTIFIED BY "<PASSWORD_CATALOGO>" DEFAULT TABLESPACE rman_cat_ts QUOTA UNLIMITED ON rman_cat_ts;
GRANT RECOVERY_CATALOG_OWNER TO rcvcat_owner;

-- Da shell (registrazione del target):
rman target sys/<PASSWORD_SYS>@PROD catalog rcvcat_owner/<PASSWORD_CATALOGO>@CATALOG_DB
RMAN> CREATE CATALOG;
RMAN> REGISTER DATABASE;
```

### 1.2 Architettura Multitenant (CDB/PDB)
In 19c+, i Pluggable Database (PDB) cambiano la logica di restore.
- Puoi eseguire un backup a livello intero di CDB (protegge tutti i PDB).
- Puoi eseguire backup e restore isolati a livello di PDB (molto utile in SaaS/Cloud).

---

## 2. Tuning Scientifico dell'I/O e dei Canali

I colli di bottiglia nei backup RMAN sono causati dal limite del disco di destinazione o da un'errata configurazione dei canali.

### 2.1 File per Set e Max Piece Size
Se stai backuppando su un filesystem Cloud o NFS che ha limiti di file size (es. 2TB max), usa `MAXPIECESIZE`.
```sql
RMAN> CONFIGURE CHANNEL DEVICE TYPE DISK MAXPIECESIZE 100G;
```

Per evitare colli di bottiglia in lettura, si usa `FILESPERSET` per aggregare piccoli datafile.
```sql
BACKUP AS COMPRESSED BACKUPSET DATABASE FILESPERSET 4;
```

### 2.2 Section Size (Bigfile Tablespaces)
In ambienti Enterprise con Bigfile (Datafile unici da 10-32 TB), il parallelismo standard non funziona (1 canale = 1 datafile). Usa `SECTION SIZE` per dividere il file in chunk processati in parallelo.
```sql
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c3 DEVICE TYPE DISK;
  ALLOCATE CHANNEL c4 DEVICE TYPE DISK;
  BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE SECTION SIZE 32G;
}
```
*Tutti e 4 i canali attaccheranno lo stesso datafile contemporaneamente leggendo blocchi da 32G.*

### 2.3 Compressione Enterprise (Advanced Compression Option)
La compressione `BASIC` (gratuita) usa molta CPU ma è lenta. Con la licenza ACO, puoi usare gli algoritmi ottimizzati.
```sql
-- LOW: LZO (Veloce, leggero su CPU, poca compressione)
-- MEDIUM: ZLIB (Ottimo bilanciamento)
-- HIGH: BZIP2 (Lentissimo, pesantissimo su CPU, massima compressione)
RMAN> CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';
RMAN> CONFIGURE DEVICE TYPE DISK BACKUP TYPE TO COMPRESSED BACKUPSET;
```

---

## 3. Sicurezza: Transparent Data Encryption (TDE) nei Backup

Se i tuoi datafile non sono criptati (TDE Tablespace), chiunque rubi il file `.bkp` di RMAN può fare restore su un proprio server. 
**Per criptare i backup RMAN (Dual-Mode, Password + Wallet):**
```sql
RMAN> SET ENCRYPTION ON IDENTIFIED BY "<RMAN_ENCRYPTION_PASSWORD>" ONLY;
RMAN> BACKUP DATABASE;
```
*Durante il restore bisognerà fornire `SET DECRYPTION IDENTIFIED BY "<RMAN_ENCRYPTION_PASSWORD>"`;*

---

## 4. Troubleshooting e Gestione FRA al 100%

Quando la `db_recovery_file_dest` (FRA) si riempie, il database va in "hang" (blocca tutte le transazioni finché non si fa spazio).

**Risoluzione d'Emergenza (Database Hung):**
1. (Se hai spazio su disco) Aumentare al volo la FRA:
```sql
ALTER SYSTEM SET db_recovery_file_dest_size=2000G SCOPE=MEMORY;
```
2. (Se NON hai spazio su disco) Eliminare forzatamente archivelog vecchi ignorando la policy:
```bash
rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-1';
```
3. Capire cosa occupa la FRA:
```sql
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```
*I file `reclaimable` verranno sovrascritti in automatico da Oracle, non causano l'hang.*

---

## 5. Scenari di Recovery Estremi (BMR e TSPITR)

### 5.1 Block Media Recovery (BMR)
Un errore `ORA-01578: ORACLE data block corrupted (file # 4, block # 10322)` indica una corruzione hardware/storage parziale.
*Non è necessario fare un restore completo da Terabytes per 1 blocco rotto.*
```bash
rman target /
RMAN> RECOVER CORRUPTION LIST;  -- Legge da V$DATABASE_BLOCK_CORRUPTION
-- OPPURE manualmente:
RMAN> RECOVER DATAFILE 4 BLOCK 10322;
```
*RMAN accederà al backup, estrarrà solo QUEL blocco e lo riscriverà a caldo, senza downtime applicativo!*

### 5.2 Point In Time Recovery del singolo PDB (CDB Architecture)
Se qualcuno ha lanciato una `DROP TABLE` nel PDB "HR_PROD", non devi abbassare tutto il server.
```bash
rman target /
RMAN> RUN {
  ALTER PLUGGABLE DATABASE hr_prod CLOSE;
  SET UNTIL TIME "TO_DATE('2026-05-26 14:00:00', 'YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE hr_prod;
  RECOVER PLUGGABLE DATABASE hr_prod;
  ALTER PLUGGABLE DATABASE hr_prod OPEN RESETLOGS;
}
```

### 5.3 Tablespace Point In Time Recovery (TSPITR)
Riporta *solo* una tablespace indietro nel tempo, usando un'istanza ausiliaria nascosta.
```bash
rman target /
RMAN> RECOVER TABLESPACE users UNTIL TIME "SYSDATE-1" 
      AUXILIARY DESTINATION '/u01/app/oracle/oradata/aux_dest';
```

### 5.4 Active Database Duplication (Clone Rete)
Creare un ambiente di preproduzione partendo dalla produzione, *senza* passare per i file di dump, clonando i blocchi in diretta via rete.
```bash
rman target sys/<PASSWORD_PROD>@PROD auxiliary sys/<PASSWORD_PREPROD>@PREPROD
RMAN> DUPLICATE TARGET DATABASE TO PREPROD FROM ACTIVE DATABASE
      SPFILE
      PARAMETER_VALUE_CONVERT ('PROD', 'PREPROD')
      SET DB_NAME='PREPROD'
      SET DB_FILE_NAME_CONVERT='+DATA_PROD','+DATA_PREPROD'
      NOFILENAMECHECK;
```

---

## 6. Retention Policy e Archivelog Deletion Policy

In un ambiente Enterprise, c'è un legame stretto tra RMAN e Data Guard. Non eliminare *mai* un archivelog se non è stato ancora applicato in Standby (Data Guard).

**Configurazione Perfetta per un DB Primary in Data Guard:**
```sql
-- Conserva 15 giorni per Point In Time
RMAN> CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 15 DAYS;

-- Elimina gli archivelog SOLO se sono stati backuppati su nastro/disco e GIA' applicati sulla Standby
RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY BACKED UP 1 TIMES TO DEVICE TYPE DISK;
```

**Verifica dei backup obsoleti (reportistica):**
```sql
RMAN> REPORT OBSOLETE;
RMAN> REPORT NEED BACKUP;  -- Quali file non soddisfano la retention?
```

---

## 7. Validazione Enterprise: non basta avere backup, devi provare il restore

In ambienti bancari la domanda corretta non e' "hai il backup?", ma "hai una restore evidence recente?".

### 7.1 Validare backup e leggibilita blocchi

```bash
rman target /
RMAN> BACKUP VALIDATE CHECK LOGICAL DATABASE;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
```

### 7.2 Restore preview

```bash
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE PREVIEW RECALL;
```

### 7.3 Crosscheck e catalogo

```bash
RMAN> CROSSCHECK BACKUP;
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> LIST FAILURE;
RMAN> ADVISE FAILURE;
RMAN> REPAIR FAILURE PREVIEW;
```

---

## 8. Configurazione baseline consigliata

```bash
rman target /
RMAN> CONFIGURE CONTROLFILE AUTOBACKUP ON;
RMAN> CONFIGURE BACKUP OPTIMIZATION ON;
RMAN> CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 15 DAYS;
RMAN> CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;
RMAN> CONFIGURE COMPRESSION ALGORITHM 'BASIC';
```

Se usi catalog:

```bash
rman target / catalog rcvcat_owner/<PASSWORD>@CATALOG_DB
RMAN> RESYNC CATALOG;
RMAN> REPORT SCHEMA;
```

Block Change Tracking per incrementali:

```sql
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA';
SELECT status, filename FROM v$block_change_tracking;
```

---

## 9. RMAN in RAC, Data Guard e CDB/PDB

### 9.1 RAC

```bash
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK CONNECT 'sys/<PASSWORD>@RACDB1';
  ALLOCATE CHANNEL c2 DEVICE TYPE DISK CONNECT 'sys/<PASSWORD>@RACDB2';
  BACKUP DATABASE PLUS ARCHIVELOG;
}
```

Usare storage condiviso o destinazioni accessibili da tutti i nodi. Se il filesystem e' locale, controllare dove finiscono backup piece e archivelog.

### 9.2 Data Guard

```bash
RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
RMAN> REPORT SCHEMA;
RMAN> LIST ARCHIVELOG ALL;
```

Prima di cancellare archivelog, verificare apply lag e policy standby.

### 9.3 PDB PITR

PDB PITR richiede attenzione a auxiliary destination, FRA e dipendenze applicative:

```bash
RUN {
  SET UNTIL TIME "TO_DATE('2026-05-26 14:00:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE hr_prod;
  RECOVER PLUGGABLE DATABASE hr_prod;
  ALTER PLUGGABLE DATABASE hr_prod OPEN RESETLOGS;
}
```

---

## 10. Manuali e riferimenti

Oracle:

- Backup and Recovery User's Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- Backup and Recovery Reference 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/
- Backing Up the Database: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/backing-up-database.html
- Advanced Backup Topics: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/backing-up-database-advanced.html
- TSPITR and auxiliary database concepts: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/performing-rman-tspitr.html

Comandi/man utili:

```bash
rman target /
RMAN> HELP BACKUP
RMAN> HELP RESTORE
RMAN> HELP RECOVER
oerr ora 19504
oerr ora 19809
oerr rman 06059
man find
man gzip
man sha256sum
```

Checklist restore evidence:

```text
[ ] Restore validate eseguito.
[ ] Almeno un restore reale su host isolato eseguito periodicamente.
[ ] Recovery catalog testato o controlfile autobackup verificato.
[ ] Wallet/TDE disponibile e testato per restore.
[ ] Backup offsite/immutabile verificato.
[ ] Runbook DR con tempi RTO/RPO misurati, non stimati.
```