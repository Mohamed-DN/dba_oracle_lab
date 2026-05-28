# GUIDA COMPLETA: Cross-Platform Transportable Tablespaces (XTTS) — Migrazioni Geografiche con Downtime Minimo

> [!NOTE]
> **DOCUMENTI DI MIGRAZIONE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cross-Platform XTTS (questa guida)**: [GUIDA_MIGRAZIONE_XTTS_RMAN.md](./GUIDA_MIGRAZIONE_XTTS_RMAN.md) (migrazioni di database multi-TB cross-endian AIX/Solaris -> Linux con downtime minimo).
> - **Tuning Data Pump Enterprise**: [GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md](./GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md) (ottimizzazione export/import per database >10 TB).
> - **Data Pump Base**: [GUIDA_DATA_PUMP.md](./GUIDA_DATA_PUMP.md) (import/export di base, remap schema e tablespace).
> - **RMAN Enterprise Completa**: [GUIDA_RMAN_COMANDI_ENTERPRISE.md](./GUIDA_RMAN_COMANDI_ENTERPRISE.md) (manuale di riferimento per backup, restore e duplication).

---

## 1. Il problema delle Migrazioni Cross-Platform e la soluzione XTTS

Quando dobbiamo migrare un database di grandi dimensioni (multi-terabyte) da un sistema operativo UNIX proprietario Big-Endian (es. **IBM AIX**, **HP-UX** o **Oracle Solaris**) verso una piattaforma moderna Little-Endian (**Oracle Linux x86_64**, **Exadata** o **OCI Database Cloud Services**), incontriamo due enormi ostacoli:
1.  I formati fisici dei blocchi a livello di file system sono incompatibili a causa del diverso Endianness.
2.  La finestra temporale di manutenzione (downtime consentito) concessa dal business è estremamente ridotta, spesso limitata a poche ore durante il weekend.

```
   TRADIZIONALE TRANSPORTABLE TABLESPACES (TTS):
   Sorgente (AIX) in READ ONLY ──► Copia Datafile via Rete (Lungo!) ──► Conversione Endian ──► Import
   ⚠️ DOWNTIME = Tempo di copia di TUTTO il database (es. 20 ore per 10 TB). Inaccettabile in produzione.

   CROSS-PLATFORM INCREMENTAL BACKUPS (XTTS):
   1. Sorgente in READ WRITE ──► Backup iniziale (Full / Level 0) ──► Copia ──► Conversione Endian (Target)
   2. Sorgente in READ WRITE ──► Cattura differenze (RMAN Incr) ──► Applica allo standby Target (Ripetuto)
   3. Sorgente in READ ONLY  ──► Ultimo inc. finale (Pochi MB!) ──► Applica ──► Metadata Import
   ✅ DOWNTIME = Solo il tempo di applicazione dell'ultimo incrementale + import metadati (~15-30 minuti!).
```

---

## 2. Verifica dell'Endianness delle Piattaforme

Prima di iniziare, verifica la compatibilità e il formato Endian delle piattaforme di origine e destinazione interrogando la vista di sistema:

```sql
sqlplus / as sysdba

SELECT platform_id, platform_name, endian_format 
FROM   v$transportable_platform 
ORDER BY platform_name;
```
*Identifica il formato di origine (es. `AIX-Based Systems` -> `Big`) e quello di destinazione (`Linux x86 64-bit` -> `Little`).*

---

## 3. Configurazione di `xtt.properties`

Oracle fornisce un set di script (`xtt.pl` e `xttcnv.txt`) per automatizzare la conversione e l'applicazione dei backup incrementali (MOS Note 1389592.1).

### Il file di configurazione `xtt.properties`
Questo file controlla l'operatività del tool e deve essere configurato in modo speculare sia sul server sorgente che su quello di destinazione.

```properties
# 1. Elenco dei tablespace da migrare (separati da virgola)
tablespaces=TS_APP_DATA,TS_APP_INDEX,TS_LOB_DATA

# 2. Platform ID della piattaforma sorgente (es. 6 = IBM AIX)
platformid=6

# 3. Stringhe di connessione TNS per amministrazione (SYSDBA)
src_conn_str=sys/SecurePassword123#@AIX_SRC
dest_conn_str=sys/SecurePassword123#@LINUX_TGT

# 4. Directory di staging temporanea sul server sorgente
dfcopydir=/u01/app/oracle/backup/xtts_stage

# 5. Percorso in cui RMAN scriverà i backup incrementali
backupformat=/u01/app/oracle/backup/xtts_backups

# 6. Directory di staging sul server di destinazione
stageondest=/u02/app/oracle/backup/xtts_stage

# 7. Percorso di destinazione finale in ASM sul server target
storageondest=+DATA
```

---

## 4. Validazione Preliminare del Transportable Set

Prima di lanciare qualsiasi backup, dobbiamo assicurarci che il set di tablespace selezionato sia **autosufficiente (self-contained)**. Se ci sono relazioni logiche (es. un indice presente in un tablespace non incluso nella lista che punta a una tabella in un tablespace incluso), la migrazione fallirà in fase di plugging.

```sql
sqlplus / as sysdba

-- Esegui la validazione per i tablespace TS_APP_DATA, TS_APP_INDEX e TS_LOB_DATA
EXEC DBMS_TTS.TRANSPORT_SET_CHECK('TS_APP_DATA,TS_APP_INDEX,TS_LOB_DATA', TRUE);

-- Verifica se ci sono violazioni (la query deve restituire ZERO righe)
SELECT * FROM transport_set_violations;
```
*Se la vista restituisce violazioni (es. tabelle con LOB memorizzati all'esterno del set), devi risolvere le incongruenze spostando gli oggetti o includendo i tablespace mancanti nella lista di migrazione.*

---

## 5. Workflow Operativo di Migrazione XTTS

### Fase 1: Creazione del Backup Iniziale (Full / Level 0)
Mentre il database di origine è **in esecuzione ed aperto in lettura/scrittura** (`READ WRITE`), eseguiamo la copia iniziale.

```bash
# Sul server SORGENTE (AIX), come utente oracle:
export ORACLE_SID=srcdb
cd /home/oracle/xtts
perl xtt.pl -p
```
*Questo comando crea una copia dei datafile dei tablespace indicati in formato compatibile con la sorgente e genera il file descrittore `xttplan.txt`.*

Trasferisci i datafile generati e lo staging directory sul server di destinazione tramite `scp` o `rsync` veloce:
```bash
scp /u01/app/oracle/backup/xtts_stage/* oracle@linux_target:/u02/app/oracle/backup/xtts_stage/
```

Sul server di destinazione (Target), converti i datafile nel formato Little-Endian e caricali in ASM:
```bash
# Sul server TARGET (Linux), come utente oracle:
export ORACLE_SID=tgtdb
cd /home/oracle/xtts
perl xtt.pl -c
```
*Ora il database target ha una copia fisica dei dati, ma ferma al momento dell'esecuzione del backup iniziale.*

---

### Fase 2: Sincronizzazione Incrementale (Ripetuta periodicamente)
Mentre gli utenti continuano a lavorare sulla sorgente, eseguiamo dei backup incrementali per allineare il target, riducendo progressivamente la distanza.

#### Step 1: Eseguire il backup incrementale sulla Sorgente
```bash
# Sul server SORGENTE
perl xtt.pl -a
```
*Questo rileva le modifiche avvenute dal backup precedente e crea un file incrementale compatto.*

#### Step 2: Trasferire il file incrementale e il piano aggiornato sul Target
```bash
scp /u01/app/oracle/backup/xtts_backups/* oracle@linux_target:/u01/app/oracle/backup/xtts_backups/
scp /home/oracle/xtts/xttplan.txt oracle@linux_target:/home/oracle/xtts/
```

#### Step 3: Convertire ed applicare l'incrementale sul Target
```bash
# Sul server TARGET
perl xtt.pl -r
```
*Gli incrementali vengono convertiti al volo in Little-Endian ed applicati (tramite `RMAN RECOVER`) ai datafile già caricati in ASM.*

> [!TIP]
> **Best Practice**: Ripeti questa Fase 2 ogni notte (o ogni poche ore) per tutta la settimana precedente alla migrazione finale. In questo modo l'ultimo backup incrementale da fare durante il cutover conterrà pochissimi megabyte di modifiche e si applicherà in pochi minuti.

---

### Fase 3: Cutover Finale (Finestra di Manutenzione)

Durante la finestra di manutenzione concordata con il business:

#### Step 1: Mettere i Tablespace in sola lettura sulla Sorgente
```sql
-- Sul server SORGENTE
sqlplus / as sysdba
ALTER TABLESPACE TS_APP_DATA READ ONLY;
ALTER TABLESPACE TS_APP_INDEX READ ONLY;
ALTER TABLESPACE TS_LOB_DATA READ ONLY;
```

#### Step 2: Eseguire l'ultimo backup incrementale finale
```bash
# Sul server SORGENTE
perl xtt.pl -a
```
*Questo cattura le ultimissime modifiche eseguite fino a un secondo prima del READ ONLY.*

#### Step 3: Trasferire e applicare l'ultimo incrementale sul Target
```bash
# Sul TARGET
scp /u01/app/oracle/backup/xtts_backups/* oracle@linux_target:/u01/app/oracle/backup/xtts_backups/
perl xtt.pl -r
```
*Ora i datafile del target in ASM sono sincronizzati al 100% bit-per-bit con la sorgente.*

#### Step 4: Esportare i metadati dal database Sorgente
```bash
# Sul server SORGENTE
expdp system/SecurePwd123# \
  transport_tablespaces=TS_APP_DATA,TS_APP_INDEX,TS_LOB_DATA \
  transport_full_check=y \
  directory=DPUMP_DIR \
  dumpfile=xtts_metadata.dmp \
  logfile=xtts_export.log
```

#### Step 5: Importare i metadati sul Target (Plugging del Tablespace)
Trasferisci il file dump sul target e collega fisicamente i datafile convertiti al nuovo database:

```bash
# Sul server TARGET
impdp system/SecurePwd123# \
  transport_datafiles='+DATA/tgtdb/datafile/ts_app_data.dbf','+DATA/tgtdb/datafile/ts_app_index.dbf','+DATA/tgtdb/datafile/ts_lob_data.dbf' \
  directory=DPUMP_DIR \
  dumpfile=xtts_metadata.dmp \
  logfile=xtts_import.log
```

#### Step 6: Mettere i Tablespace in READ WRITE sul Target
```sql
-- Sul server TARGET
sqlplus / as sysdba
ALTER TABLESPACE TS_APP_DATA READ WRITE;
ALTER TABLESPACE TS_APP_INDEX READ WRITE;
ALTER TABLESPACE TS_LOB_DATA READ WRITE;
```

---

## 6. Risoluzione Problemi, Partizioni & Grandi LOB

### 6.1 Gestione delle Tabelle Partizionate e dei LOB SecureFiles
Durante la migrazione XTTS, le tabelle partizionate ed i relativi segmenti LOB vengono migrati fisicamente senza problemi poiché l'operazione avviene a livello di blocco di tablespace. Tuttavia, occorre prestare attenzione alle **statistiche degli oggetti**: se la migrazione avviene tra versioni differenti (es. 12.1 ➔ 19c), è fortemente consigliato rigenerare le statistiche del dizionario a fine migrazione sul target per evitare regressioni nei piani d'esecuzione.

### 6.2 Risoluzione dei Gap negli Incrementali XTTS
Se si verifica un errore durante l'applicazione di un incrementale (`xtt.pl -r` fallisce), non è necessario ripartire da zero:
1.  Verificare il file di log `xttout.txt` per identificare su quale datafile è avvenuto l'errore.
2.  Controllare il file `xttplan.txt` che tiene traccia dei SCN (*System Change Number*) di sincronizzazione.
3.  Se RMAN ha perso traccia di un incrementale, è possibile forzare la sincronizzazione manuale ricreando il file delle modifiche tramite RMAN nativo partendo dal SCN memorizzato come *Last Backup SCN* in `xttplan.txt`.
