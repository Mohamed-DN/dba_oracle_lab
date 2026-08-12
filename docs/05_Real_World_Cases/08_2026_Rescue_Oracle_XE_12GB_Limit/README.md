# Playbook di Emergenza: Sblocco Oracle XE 18c per limite 12GB
**Data:** Agosto 2026

Questo documento è una guida passo-passo "copia-incolla" pensata per essere eseguita a occhi chiusi. Serve per sbloccare e recuperare un database Oracle 18c XE andato in crash totale a causa del superamento del limite fisico di 12 GB (tipicamente per via della saturazione del tablespace `SYSAUX`).

## Sintomi del blocco
- Il database rifiuta le connessioni e non si apre in modalità `READ WRITE`.
- Impossibile fare manutenzione standard (es. pulizia statistiche).
- Errore riscontrato: `ORA-12954: The request exceeds the maximum allowed database size of 12 GB`.
- (Spesso accompagnato da `ORA-01653: unable to extend table SYS.WRI$_OPTSTAT_TAB_HISTORY in tablespace SYSAUX`).

---

## FASE 0: Estrazione della PDB bloccata dal server del Cliente (Windows)
Poiché la PDB è bloccata e rifiuta connessioni applicative, l'unico modo per salvarla è "scollegarla" (unplug) per portarla in laboratorio.
Collegati al database XE del cliente da SQL*Plus (sul CDB) come amministratore e lancia:
```sql
ALTER SESSION SET CONTAINER = CDB$ROOT;
-- Chiudi brutalmente la PDB
ALTER PLUGGABLE DATABASE CUST_PDB CLOSE IMMEDIATE;
-- Genera il file XML descrittivo per l'esportazione
ALTER PLUGGABLE DATABASE CUST_PDB UNPLUG INTO 'C:\tmp\cust_pdb.xml';
```
A questo punto, copia fisicamente l'intera cartella della PDB (es. `C:\app\...\oradata\XE\CUST_PDB`) e il file `cust_pdb.xml` appena generato per trasferirli nel tuo laboratorio Linux.

---

## FASE 1: Migrazione e sblocco nel Lab Linux (Enterprise)
Poiché il limite di 12 GB blocca ogni operazione nel server originale (XE), la procedura prevede l'uso di un server di laboratorio con **Oracle 19c Enterprise Edition** (che ignora i limiti di licenza).

### 1. Innesto della PDB corrotta
Copia a freddo l'intera cartella della PDB e il file manifest `.xml` dal server del cliente al server Linux (es. in `/u01/recupero/CUST_PDB`).
Dal server Linux, entra in SQL*Plus collegato al Container (CDB) come amministratore e lancia:
```sql
-- Creiamo la PDB appoggiandoci ai file trasferiti
CREATE PLUGGABLE DATABASE CUST_PDB_RECUPERO USING '/u01/recupero/CUST_PDB/cust_pdb.xml' NOCOPY TEMPFILE REUSE;

-- L'apriamo in modalità UPGRADE per poterla allineare alla versione 19c del laboratorio
ALTER PLUGGABLE DATABASE CUST_PDB_RECUPERO OPEN UPGRADE;
```

### 2. Esecuzione dell'Upgrade (Allineamento dizionario)
Esci da SQL*Plus e apri un terminale bash (Linux). Lancia il tool di upgrade per aggiornare il dizionario dati interno alla PDB. *(Attenzione: assicurati di usare il percorso dei log corretto per il tuo ambiente 19c)*:
```bash
$ORACLE_HOME/bin/dbupgrade -c CUST_PDB_RECUPERO -l /u01/app/oracle/product/19.0.0/dbhome_1/cfgtoollogs/
```
> [!NOTE] 
> **Falso Positivo:** Durante l'upgrade da Windows a Linux, potresti notare l'errore `SP2-0310: unable to open file dbmsclr.plb`. È un falso positivo sicuro da ignorare (riguarda librerie .NET esclusive per Windows).
> **Attenzione alla FRA:** Se durante l'upgrade il database si "pianta" o i log riportano `log file switch (archiving needed)`, la Fast Recovery Area del tuo lab si è riempita. Allargala temporaneamente (es. `ALTER SYSTEM SET db_recovery_file_dest_size=50G SCOPE=BOTH;`).

### 3. Estrazione Logica Pura (Data Pump)
Finito l'upgrade, il database è aperto e ignoriamo la spazzatura accumulata nel `SYSAUX`. Procediamo a estrarre **esclusivamente i dati dell'applicativo** in formato retro-compatibile.
Da terminale bash:
```bash
expdp userid=\"sys/password123@localhost/CUST_PDB_RECUPERO AS SYSDBA\" schemas=APP_SCHEMA directory=DIR_RECUPERO dumpfile=dati_app.dmp logfile=export_app.log VERSION=18.0
```

---

## FASE 2: Ripristino sul server del Cliente (Windows)
Prendi il file `dati_app.dmp` pulito appena generato e trasferiscilo sul server del cliente (es. in `C:\tmp`).

### 1. Distruzione della PDB guasta
Collegati al database XE del cliente da SQL*Plus (sul CDB) e pialla tutto, liberando spazio prezioso:
```sql
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER PLUGGABLE DATABASE CUST_PDB CLOSE;
DROP PLUGGABLE DATABASE CUST_PDB INCLUDING DATAFILES;
```

### 2. Ricreazione di una PDB vergine
Sempre dal CDB, ricrea una PDB intonsa a partire dal template base 18c:
```sql
CREATE PLUGGABLE DATABASE CUST_PDB ADMIN USER app_admin IDENTIFIED BY password123 FILE_NAME_CONVERT = ('pdbseed', 'CUST_PDB');
ALTER PLUGGABLE DATABASE CUST_PDB OPEN;
```

### 3. Preparazione Tablespace e Directory
Entra nella nuova PDB appena nata e prepara il terreno per importare i dati (adatta i percorsi Windows al tuo caso):
```sql
ALTER SESSION SET CONTAINER = CUST_PDB;

-- Crea il tablespace USERS
CREATE TABLESPACE USERS DATAFILE 'C:\app\Administrator\product\18.0.0\oradata\XE\CUST_PDB\users01.dbf' SIZE 100M AUTOEXTEND ON NEXT 100M MAXSIZE UNLIMITED;
ALTER DATABASE DEFAULT TABLESPACE USERS;

-- Crea la directory che punta alla cartella dove hai incollato il file .dmp
CREATE OR REPLACE DIRECTORY DIR_RECUPERO AS 'C:\tmp';
```

### 4. Importazione dei dati (Data Pump)
Apri il Prompt dei Comandi (CMD) di Windows come Amministratore e lancia l'import.
> [!IMPORTANT]
> Usa **obbligatoriamente** `SYS AS SYSDBA` (come nel comando sotto, facendo attenzione ai backslash `\"` su Windows) perché l'utente admin creato di default su XE potrebbe non avere il ruolo `DATAPUMP_IMP_FULL_DATABASE`.
```cmd
impdp userid=\"sys/password123@localhost/CUST_PDB AS SYSDBA\" schemas=APP_SCHEMA directory=DIR_RECUPERO dumpfile=dati_app.dmp logfile=import.log
```

### 5. Ricompilazione degli oggetti (Post-Import)
A importazione terminata, assicurati che non vi siano viste o procedure "appese":
```sql
ALTER SESSION SET CONTAINER = CUST_PDB;
EXEC DBMS_UTILITY.compile_schema(schema => 'APP_SCHEMA', compile_all => false);

-- Verifica che non ci siano oggetti invalidi (non deve restituire righe)
SELECT object_type, count(*) FROM dba_objects WHERE owner='APP_SCHEMA' AND status='INVALID' GROUP BY object_type;
```

---

## FASE 3: Hardening e Messa in Sicurezza (Prevenzione)
Per evitare categoricamente che il DB del cliente finisca di nuovo in blocco totale (saturandosi di log inutili), applica queste restrizioni chirurgiche.
Eseguile da SQL*Plus collegato dentro `CUST_PDB`.

### 1. Limite Fisico di 11 GB (Il Salvavita)
Questo blocco assicura che in caso di saturazione vada in errore solo il tablespace, evitando che l'intero servizio Oracle vada in coma (poiché si previene l'hard-limit dei 12GB di XE).
```sql
-- Identifica esattamente dove Oracle ha salvato il file
SELECT file_name FROM dba_data_files WHERE tablespace_name = 'SYSAUX';

-- Applica il limite (sostituisci il percorso tra apici con quello ottenuto sopra)
ALTER DATABASE DATAFILE 'C:\INCOLLA\IL\PERCORSO\SYSAUX01.DBF' AUTOEXTEND ON MAXSIZE 11G;
```

### 2. Svuotamento ciclico (Tuning AWR/Stats)
Abbassa drasticamente le policy di storicizzazione per mantenere il database sempre al minimo delle dimensioni.
```sql
-- Abbassa la storicità delle vecchie statistiche a soli 7 giorni (di default è 31)
EXEC DBMS_STATS.ALTER_STATS_HISTORY_RETENTION(7);

-- Abbassa la finestra tecnica di paragone a 3 giorni (obbligatorio prima del prossimo step)
EXEC DBMS_WORKLOAD_REPOSITORY.MODIFY_BASELINE_WINDOW_SIZE(window_size => 3);

-- Spegne le macro-analitiche tenendo log AWR limitatissimi (3 giorni e foto orarie)
EXEC DBMS_WORKLOAD_REPOSITORY.modify_snapshot_settings(retention => 4320, interval => 60);
```

---

## FASE 4: Pulizia del Laboratorio Linux (Cleanup)
Una volta verificato che il cliente è tornato operativo, pulisci il tuo server di laboratorio per non sprecare spazio.
Da SQL*Plus:
```sql
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER PLUGGABLE DATABASE CUST_PDB_RECUPERO CLOSE;
DROP PLUGGABLE DATABASE CUST_PDB_RECUPERO INCLUDING DATAFILES;
-- (Se avevi allargato la FRA, ricordati di ripristinare il limite originale)
```
Da terminale Bash:
```bash
rm -rf /u01/recupero/CUST_PDB
rm -f /u01/recupero/*.dmp /u01/recupero/*.log
```

Il database del cliente è ora pienamente ripristinato, nettamente più leggero e blindato "a prova di idiota" per il futuro.
