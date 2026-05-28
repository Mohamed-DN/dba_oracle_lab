# GUIDA: Cross-Platform Transportable Tablespaces (XTTS) — Migrazioni Geografiche con Downtime Minimo

> [!NOTE]
> **DOCUMENTI DI MIGRAZIONE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Cross-Platform XTTS (questa guida)**: [GUIDA_MIGRAZIONE_XTTS_RMAN.md](./GUIDA_MIGRAZIONE_XTTS_RMAN.md) (migrazioni di database multi-TB cross-endian AIX/Solaris -> Linux con downtime minimo).
> - **Tuning Data Pump Enterprise**: [GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md](./GUIDA_TUNING_DATA_PUMP_ENTERPRISE.md) (ottimizzazione export/import per database >10 TB).
> - **Data Pump Base**: [GUIDA_DATA_PUMP.md](./GUIDA_DATA_PUMP.md) (import/export di base, remap schema e tablespace).
> - **RMAN Enterprise Completa**: [GUIDA_RMAN_COMANDI_ENTERPRISE.md](./GUIDA_RMAN_COMANDI_ENTERPRISE.md) (manuale di riferimento per backup, restore e duplication).

---

## 1. Il problema delle Migrazioni Cross-Platform e la soluzione XTTS

Quando dobbiamo migrare un database di grandi dimensioni (multi-terabyte) da un sistema operativo UNIX proprietario Big-Endian (es. **IBM AIX** o **HP-UX / Oracle Solaris**) verso una piattaforma moderna Little-Endian (**Oracle Linux x86_64** o Exadata), incontriamo due grossi ostacoli:
1.  I formati dei blocchi fisici a livello di file system sono incompatibili (diverso Endianness).
2.  Il downtime concesso dal business per la migrazione è estremamente ridotto (spesso poche ore).

```
   TRADIZIONALE TRANSPORTABLE TABLESPACES (TTS):
   Sorgente (AIX) in READ ONLY ──► Copia Datafile via Rete (Lungo!) ──► Conversione Endian ──► Import
   ⚠️ DOWNTIME = Tempo di copia di TUTTO il database (es. 20 ore per 10 TB). Inaccettabile in produzione.

   CROSS-PLATFORM INCREMENTAL BACKUPS (XTTS):
   1. Sorgente in READ WRITE ──► Backup iniziale (Full) ──► Copia ──► Conversione Endian (Target)
   2. Sorgente in READ WRITE ──► Cattura differenze (RMAN Incr) ──► Applica allo standby Target (Ripetuto)
   3. Sorgente in READ ONLY  ──► Ultimo inc. finale (Pochi MB!) ──► Applica ──► Metadata Import
   ✅ DOWNTIME = Solo il tempo di applicazione dell'ultimo incrementale + import metadati (~15-30 minuti!).
```

---

## 2. Verifica dell'Endianness delle Piattaforme

Prima di iniziare, verifica la compatibilità e il formato Endian delle piattaforme di origine e destinazione:

```sql
sqlplus / as sysdba

SELECT platform_id, platform_name, endian_format 
FROM   v$transportable_platform 
ORDER BY platform_name;
```
*Identifica il formato di origine (es. `AIX-Based Systems` -> `Big`) e quello di destinazione (`Linux x86 64-bit` -> `Little`).*

---

## 3. Workflow Operativo di Migrazione XTTS

La migrazione XTTS si articola in 4 fasi principali.

### Fase 1: Setup dei Prerequisiti & Download Script Ufficiale
Oracle fornisce un set di script (`xtt.pl` e `xttcnv.txt`) per automatizzare la conversione e l'applicazione dei backup incrementali (MOS Note 1389592.1).

1.  Scarica lo zip XTTS e scompattalo su entrambi i server (sorgente e target) sotto `/home/oracle/xtts/`.
2.  Configura il file `xtt.properties` su entrambi i server definendo i tablespace da migrare (es. `TS_APP1`):

```properties
tablespaces=TS_APP1
platformid=6  -- ID di IBM AIX (sorgente)
src_conn_str=sys/SecurePassword123#@AIX_SRC
dest_conn_str=sys/SecurePassword123#@LINUX_TGT
dfcopydir=/u01/app/oracle/backup/xtts_stage  -- Directory temporanea di transito
backupformat=/u01/app/oracle/backup/xtts_backups
stageondest=/u01/app/oracle/backup/xtts_stage
storageondest=+DATA
```

---

### Fase 2: Creazione del Backup Iniziale (Full / Level 0)
Mentre il database di origine è **in esecuzione ed aperto in lettura/scrittura** (`READ WRITE`), eseguiamo la copia iniziale.

```bash
# Sul server SORGENTE (AIX), come utente oracle:
export ORACLE_SID=srcdb
perl xtt.pl -p
```
*Questo comando crea una copia dei datafile dei tablespace indicati in formato compatibile con la sorgente e genera un file descrittore `xttplan.txt`.*

Trasferisci i datafile generati e lo staging directory sul server di destinazione tramite `scp` o `rsync` veloce:
```bash
scp /u01/app/oracle/backup/xtts_stage/* oracle@linux_target:/u01/app/oracle/backup/xtts_stage/
```

Sul server di destinazione (Target), converti i datafile nel formato Little-Endian e caricali in ASM:
```bash
# Sul server TARGET (Linux), come utente oracle:
export ORACLE_SID=tgtdb
perl xtt.pl -c
```
*Ora il database target ha una copia fisica dei dati, ma ferma al momento dell'esecuzione del backup iniziale.*

---

### Fase 3: Sincronizzazione Incrementale (Ripetuta periodicamente)
Mentre il tempo passa e gli utenti continuano a lavorare sulla sorgente, eseguiamo dei backup incrementali per allineare il target, riducendo progressivamente la distanza.

#### Step 1: Eseguire il backup incrementale sulla Sorgente
```bash
# Sul server SORGENTE
perl xtt.pl -a
```
*Questo rileva le modifiche avvenute dal backup precedente e crea un file incrementale compatto.*

#### Step 2: Trasferire il file incrementale sul Target
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

> **Best Practice**: Ripeti questa Fase 3 ogni notte (o ogni poche ore) per tutta la settimana precedente alla migrazione finale. In questo modo l'ultimo backup incrementale da fare durante il cutover conterrà pochissimi megabyte di modifiche e si applicherà in pochi minuti.

---

### Fase 4: Cutover Finale (Finestra di Manutenzione)

Durante la finestra di manutenzione concordata con il business:

#### Step 1: Mettere i Tablespace in sola lettura sulla Sorgente
```sql
-- Sul server SORGENTE
sqlplus / as sysdba
ALTER TABLESPACE TS_APP1 READ ONLY;
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
Poiché i datafile contengono solo tabelle ed indici, dobbiamo esportare la struttura logica (dizionario dati, grant, sinonimi) da collegare al target:

```bash
# Sul server SORGENTE
expdp system/<password> \
  transport_tablespaces=TS_APP1 \
  transport_full_check=y \
  directory=DPUMP_DIR \
  dumpfile=xtts_metadata.dmp \
  logfile=xtts_export.log
```

#### Step 5: Importare i metadati sul Target (Plugging del Tablespace)
Trasferisci il file dump sul target e collega fisicamente i datafile convertiti al nuovo database:

```bash
# Sul server TARGET
impdp system/<password> \
  transport_datafiles='+DATA/tgtdb/datafile/ts_app1.dbf' \
  directory=DPUMP_DIR \
  dumpfile=xtts_metadata.dmp \
  logfile=xtts_import.log
```

#### Step 6: Mettere i Tablespace in READ WRITE sul Target
```sql
-- Sul server TARGET
sqlplus / as sysdba
ALTER TABLESPACE TS_APP1 READ WRITE;
```

**MIGRAZIONE COMPLETATA CON SUCCESSO!** Il database target è ora attivo e aggiornato, con un disservizio per gli utenti limitato solo alla durata della Fase 4.
