# Guida Enterprise: Export e Import da Produzione a Pre-Produzione (Data Pump)

Questo documento rappresenta la procedura definitiva e completa per la migrazione, il refresh e l'allineamento dei dati tra un ambiente di Produzione (PROD) e un ambiente di Pre-Produzione/Test (PREPROD). Trattandosi di ambienti mission-critical o ad alto volume, vengono adottate tecniche avanzate di parallelismo, data masking, tuning dell'I/O, e sicurezza enterprise.

---

## 1. Pianificazione, Pre-Requisiti e Sizing (Capacity Planning)
Prima di lanciare qualsiasi attività su Data Pump, è vitale verificare i limiti hardware e architetturali del database di destinazione e di origine.

### 1.1 Sizing dell'Export (PROD)
Calcolare accuratamente quanto spazio richiederà l'export. L'uso di `COMPRESSION=ALL` riduce tipicamente le dimensioni del 70-85%, ma dipende dall'entropia dei dati.
```sql
-- Stima della dimensione degli schemi da esportare
SELECT owner, SUM(bytes)/1024/1024/1024 AS size_gb
FROM dba_segments
WHERE owner IN ('SCHEMA_A', 'SCHEMA_B')
GROUP BY owner;
```
Assicurarsi che la directory logica `DATA_PUMP_DIR` (o custom) abbia spazio fisico a sufficienza sul server.
```sql
SELECT directory_name, directory_path FROM dba_directories WHERE directory_name = 'DATA_PUMP_DIR';
```

### 1.2 Sizing dell'Import (PREPROD)
L'importazione massiva su un database in modalità `ARCHIVELOG` produrrà un volume di redo enorme. 
**Rischio:** Riempimento della Flash Recovery Area (FRA) e blocco (hang) del database.

**Strategie di mitigazione:**
1. Mantenere l'import in `ARCHIVELOG` ma aumentare massivamente la FRA temporaneamente:
   ```sql
   ALTER SYSTEM SET db_recovery_file_dest_size=1000G SCOPE=BOTH;
   ```
2. Aumentare la frequenza dei backup archivelog. Aggiornare temporaneamente il crontab:
   ```bash
   # Crontab: Esegui backup archivelog ogni 15 minuti durante l'import
   */15 * * * * /u01/app/oracle/scripts/rman_backup_archivelog.sh
   ```
3. Passare temporaneamente il DB in `NOARCHIVELOG` (SOLO SE ACCETTABILE IN PREPROD). Questo abbatte i tempi di importazione del 40-50%.
   ```bash
   srvctl stop database -d PREPROD
   sqlplus / as sysdba
   STARTUP MOUNT;
   ALTER DATABASE NOARCHIVELOG;
   ALTER DATABASE OPEN;
   ```
   *Ricordare di rimettere in ARCHIVELOG e lanciare un FULL backup dopo l'import!*

### 1.3 Controllo UNDO e TEMP
Data Pump (soprattutto in fase di costruzione indici parallela) usa pesantemente la TEMP.
```sql
-- Aumentare temporaneamente la TEMP in Preprod
ALTER TABLESPACE TEMP ADD TEMPFILE '/u01/app/oracle/oradata/PREPROD/temp02.dbf' SIZE 32G AUTOEXTEND ON NEXT 1G MAXSIZE UNLIMITED;
```

---

## 2. Preparazione degli Oggetti di Sicurezza
Prima dell'import, l'ambiente di destinazione deve possedere le stesse strutture logiche (Ruoli, Profile, Tablespace) della produzione.

### 2.1 Estrazione e Creazione Ruoli (In PROD)
Data Pump esporta i ruoli, ma se si esportano *solo* schemi specifici, i ruoli generali potrebbero non venire trasferiti. È best practice ricrearli manualmente in anticipo.
```sql
SET LINESIZE 300 PAGESIZE 0 TRIMSPOOL ON FEEDBACK OFF VERIFY OFF
SPOOL create_roles_preprod.sql
PROMPT -- 1. Creazione Ruoli
SELECT 'CREATE ROLE "' || role || '";' FROM dba_roles WHERE oracle_maintained = 'N';
PROMPT -- 2. Assegnazione Grant di Sistema
SELECT 'GRANT ' || privilege || ' TO "' || grantee || '"' || CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION;' ELSE ';' END 
FROM dba_sys_privs WHERE grantee IN (SELECT role FROM dba_roles WHERE oracle_maintained = 'N');
PROMPT -- 3. Privilegi tra ruoli (Annidamento)
SELECT 'GRANT "' || granted_role || '" TO "' || grantee || '"' || CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION;' ELSE ';' END 
FROM dba_role_privs WHERE grantee IN (SELECT role FROM dba_roles WHERE oracle_maintained = 'N');
SPOOL OFF
```
*Eseguire `create_roles_preprod.sql` nel database PREPROD come SYSDBA.*

### 2.2 Tablespace in PREPROD
Estrarre il DDL da PROD e riadattare i percorsi.
```sql
SET LONG 100000
SELECT dbms_metadata.get_ddl('TABLESPACE', tablespace_name) FROM dba_tablespaces 
WHERE tablespace_name NOT IN ('SYSTEM', 'SYSAUX', 'UNDOTBS1', 'TEMP');
```
*Se in Preprod si usano percorsi ASM diversi (es. `+DATA_PRE` invece di `+DATA_PROD`), modificare lo script di conseguenza, o affidarsi al parametro `REMAP_TABLESPACE` in fase di import.*

---

## 3. Fase 1: Data Pump Export Avanzato (PROD)
Utilizziamo tecniche Enterprise per esportare velocemente e senza bloccare il database.

### 3.1 Utilizzo di un Parameter File (export.par)
Creare il file `/u01/app/oracle/admin/PROD/dpdump/export.par`:
```ini
DIRECTORY=DATA_PUMP_DIR
DUMPFILE=exp_prod_%U.dmp
LOGFILE=exp_prod_run.log
SCHEMAS=SCHEMA_A, SCHEMA_B
PARALLEL=8
COMPRESSION=ALL
METRICS=Y
LOGTIME=ALL
JOB_NAME=EXP_PROD_REFRESH
FLASHBACK_TIME=SYSTIMESTAMP
EXCLUDE=STATISTICS
EXCLUDE=INDEX:"LIKE '%_TMP_IDX%'"
```
**Spiegazione parametri Enterprise:**
- `FLASHBACK_TIME`: Fondamentale! Garantisce la consistenza point-in-time a livello di transazione su tabelle multiple. Tutti i dati estratti apparterranno allo stesso esatto SCN temporale, anche se l'export dura ore.
- `PARALLEL=8`: Divide il carico (se si hanno core disponibili). Usa `%U` nel dumpfile per creare `exp_prod_01.dmp`, `exp_prod_02.dmp` ecc.
- `COMPRESSION=ALL`: Comprime dati e metadati.
- `METRICS=Y` & `LOGTIME=ALL`: Traccia tempi esatti e timestamp nel log per debugging prestazionale.
- `EXCLUDE=STATISTICS`: Da 11g in poi, l'import delle statistiche di tabelle enormi rallenta l'import in maniera drastica. Meglio ricalcolarle post-import.

### 3.2 Avvio dell'Export in Background (Nohup)
```bash
nohup expdp system/<PASSWORD>@PROD parfile=export.par > expdp_out.log 2>&1 &
```
### 3.3 Monitoraggio in Real-Time (Interactive e SQL)
Per monitorare lo stato di `expdp`:
1. **Interactive mode:** `expdp system/<PASSWORD> attach=EXP_PROD_REFRESH` (Digita `status` per vedere il progresso. Digita `continue_client` per uscire dall'interactive).
2. **SQL Monitoring (Session Longops):**
```sql
SELECT opname, target_desc, sofar, totalwork, trunc(sofar/totalwork*100,2) as pct_complete, time_remaining
FROM v$session_longops
WHERE opname LIKE '%EXP_PROD_REFRESH%';
```

---

## 4. Trasferimento Dati Sicuro e Veloce
I file di dump possono raggiungere svariati Terabyte. Il trasferimento deve essere tollerante ai fault di rete e performante.

### 4.1 Utilizzo di Rsync (Multi-threaded)
Invece di un singolo scp che satura un solo core, se si hanno molti file `%U.dmp` usare tool in parallelo come xargs:
```bash
# Sulla macchina PROD
cd /u01/app/oracle/admin/PROD/dpdump/
ls exp_prod_*.dmp | xargs -n 1 -P 4 -I {} rsync -avz --progress {} oracle@preprod-server:/u01/app/oracle/admin/PREPROD/dpdump/
```
Questo trasferirà 4 file alla volta.

### 4.2 Controllo di Integrità (Checksum)
Su file enormi, la rete può introdurre corruzioni silenziose. Prima di importare:
```bash
# Su PROD:
sha256sum exp_prod_*.dmp > checksums.sha256
# Copiare checksums.md5 su PREPROD e verificare:
sha256sum -c checksums.sha256
```

---

## 5. Fase 2: Data Pump Import Avanzato (PREPROD)
Prima di importare, dobbiamo gestire gli schemi preesistenti se si tratta di un refresh.

### 5.1 Drop Pulito degli Schemi Esistenti (se Refresh)
Se gli schemi esistono già in Preprod, l'opzione `TABLE_EXISTS_ACTION=REPLACE` dropa e ricrea le tabelle, ma non cancella viste vecchie, procedure orfane e type. La best practice per un ambiente "pulito" è droppare completamente lo schema.
```sql
-- Assicurarsi che nessuna sessione tenga lo schema bloccato
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
DROP USER SCHEMA_A CASCADE;
DROP USER SCHEMA_B CASCADE;
```
*(Nota: Il cascade su schemi con 50k tabelle può impiegare ore. In alternativa usare DBMS_DATAPUMP per svuotarlo).*

### 5.2 Parameter File di Import (import.par)
Creare `/u01/app/oracle/admin/PREPROD/dpdump/import.par`:
```ini
DIRECTORY=DATA_PUMP_DIR
DUMPFILE=exp_prod_%U.dmp
LOGFILE=imp_preprod_run.log
SCHEMAS=SCHEMA_A, SCHEMA_B
PARALLEL=8
METRICS=Y
LOGTIME=ALL
JOB_NAME=IMP_PREPROD_REFRESH
TABLE_EXISTS_ACTION=REPLACE
TRANSFORM=DISABLE_ARCHIVE_LOGGING:Y
```
**Spiegazione parametri Enterprise:**
- `TRANSFORM=DISABLE_ARCHIVE_LOGGING:Y`: Parametro **FENOMENALE** introdotto in 12c. Forza la creazione di tabelle e indici in NOLOGGING *durante l'import*, riducendo il redo per le operazioni eleggibili. Non elimina tutto il redo/undo: metadata, dizionario, vincoli e alcune operazioni continueranno a generare redo. Inoltre FORCE LOGGING a livello database/tablespace puo' neutralizzare il beneficio. In ambienti con Data Guard o requisiti PITR, concordare prima la strategia.
- `REMAP_TABLESPACE=TS_PROD:TS_PREPROD`: (Opzionale) Usare se i nomi delle tablespace cambiano tra i due ambienti.

### 5.3 Data Masking (REMAP_DATA)
Se si passano dati sensibili verso Pre-Produzione (ambiente non sicuro), è obbligatorio il GDPR/Masking.
```ini
-- Nel file import.par aggiungere:
REMAP_DATA=SCHEMA_A.CUSTOMERS.SSN:PKG_MASKING.MASK_SSN
REMAP_DATA=SCHEMA_A.CUSTOMERS.EMAIL:PKG_MASKING.MASK_EMAIL
```
Il package `PKG_MASKING` deve essere creato nel database prima di avviare l'import, e la funzione deve restituire il valore anonimizzato.

### 5.4 Esecuzione dell'Import
```bash
nohup impdp system/<PASSWORD>@PREPROD parfile=import.par > impdp_out.log 2>&1 &
```

---

## 6. Risoluzione Problemi e Troubleshooting (ORA- Errors)

Durante le ore (o giorni) di import, potresti incorrere in errori critici.

- **ORA-31626 / ORA-31684 (Job already exists)**: Il Job Name specificato è rimasto bloccato o orfano da un'esecuzione precedente.
  *Fix:* `DROP TABLE system.IMP_PREPROD_REFRESH;`
- **ORA-01653 (Unable to extend table in tablespace)**: Spazio insufficiente.
  *Fix:* Aggiungere datafile dinamicamente da SQL*Plus. Il Data Pump si "sospenderà" temporaneamente e, appena aggiunto lo spazio, riprenderà automaticamente o digitando `continue_client`.
- **ORA-39083 (Object type FAILED to create with error)**: Molto comune su Viste o Procedure invalidi per colpa di dipendenze incrociate, oggetti in sys o DBLINK non esistenti. Questi verranno compilati nel passaggio 7, ma è bene esaminare i log alla ricerca di conflitti.

```bash
# Analisi rapida degli errori post-import:
grep "ORA-" imp_preprod_run.log | sort | uniq -c | sort -nr
```

---

## 7. Attività Post-Import

### 7.1 Recompile Invalide e Verifica Oggetti
Eseguire la ricompilazione nativa (multi-threaded in 12c+).
```sql
-- Eseguito come SYSDBA
@?/rdbms/admin/utlrp.sql
```

Verificare gli oggetti rimasti invalidi. Spesso sono viste che puntano a DB_LINK non presenti, o tabelle di altri schemi per cui mancano le GRANT.
```sql
SELECT owner, object_type, object_name, status
FROM dba_objects
WHERE status = 'INVALID'
ORDER BY owner, object_type;
```

### 7.2 Restore delle Grant Orfane
Ripetere lo script delle grant dei ruoli per utenti specifici se l'import schema-level le ha saltate:
```sql
SELECT 'GRANT "' || granted_role || '" TO "' || grantee || '";'
FROM dba_role_privs@DBLINK_PROD
WHERE grantee IN ('SCHEMA_A', 'SCHEMA_B', 'DWH', 'DBA_OP');
```

### 7.3 Ricalcolo delle Statistiche dell'Optimizer
Avendo escluso le statistiche (`EXCLUDE=STATISTICS`), l'Optimizer di Oracle crederà che tutte le tabelle importate siano vuote, scatenando Piani di Esecuzione (Execution Plans) disastrosi e lentezza assoluta delle applicazioni in Preprod. 

**Ricalcolo Immediato Parallelo (Massima Priorità):**
```sql
EXEC DBMS_STATS.GATHER_SCHEMA_STATS( -
    ownname          => 'SCHEMA_A', -
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE, -
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO', -
    degree           => DBMS_STATS.DEFAULT_DEGREE, -
    cascade          => TRUE, -
    options          => 'GATHER AUTO');
```
*L'uso del degree=DEFAULT (e parallel in sessione) o manuale (es. degree=>8) sfrutterà le CPU per terminare in minuti anziché ore.*

### 7.4 Controllo Consistenza Metadati e Dati
Un DBA Enterprise non si fida solo dell'assenza di ORA- nel log. Confrontare matematicamente le strutture.

**Controllo Numero Oggetti:**
```sql
SELECT owner, object_type, count(*) as cnt
FROM dba_objects 
WHERE owner IN ('SCHEMA_A', 'SCHEMA_B')
GROUP BY owner, object_type ORDER BY owner, object_type;
-- Confrontare questo output con quello della Produzione
```

**Controllo Record di Tabelle Strategiche:**
Se in produzione ci sono 40 Milioni di record in `ORDERS`, verificare in Preprod:
```sql
SELECT count(*) FROM SCHEMA_A.ORDERS;
```

---

## 8. Considerazioni Architetturali su RAC e Data Guard
- **RAC (Real Application Clusters):** Se l'import o l'export avviene in RAC, usare il parametro `CLUSTER=N` nel file `.par`. Data Pump proverà ad avviare worker nodes su tutti i nodi RAC. Se i file `.dmp` si trovano su un filesystem locale (e non condiviso come ACFS o NFS), i worker remoti non troveranno i file e andranno in crash. `CLUSTER=N` forza tutti i worker sul nodo da cui viene lanciato il comando.
- **Data Guard:** Se il DB di Preprod ha a sua volta una Physical Standby, l'enorme ammontare di Redo generato dall'import potrebbe causare ritardi (Transport Lag / Apply Lag) letali sulla rete. Si consiglia di mettere in pausa l'apply sulla standby (`ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL`), finire l'import in NOLOGGING sulla Primary, eseguire un Incremental Backup dalla Primary e applicarlo (Roll-Forward) sulla Standby per recuperare, oppure ricreare la standby da zero (Duplicate).

---

## 9. Next Steps Obbligatori
Dopo ogni refresh di ambiente (da un DB all'altro), devi immediatamente agire sulle vulnerabilità introdotte dalla clonazione dei dati.
Le priorità assolute sono:
1. **Gestione dei DB_LINK:** I DB link appena importati stanno ancora puntando alla Produzione! Seguire ciecamente la procedura nel runbook [21_GESTIONE_DB_LINK.md](./21_GESTIONE_DB_LINK.md).
2. **Password Utenti App:** Spesso i DB di Preprod devono avere password diverse (oppure note ai developer). I file di DataPump mantengono gli hash delle password di produzione. Eseguire uno script standard per resettarle: `ALTER USER my_app_usr IDENTIFIED BY <PASSWORD_PREPROD>;`.
3. **Schedulatori Job:** Controllare `DBA_SCHEDULER_JOBS`. I job (es. invio fatture, email, interfacce batch) appena importati potrebbero essere attivi. Disabilitare immediatamente quelli non desiderati in Preprod!
```sql
EXEC DBMS_SCHEDULER.DISABLE('SCHEMA_A.NOME_JOB');
```

---

## 10. Addendum Enterprise: Decisioni che vanno approvate prima del refresh

In ambienti bancari il refresh PROD -> PREPROD non e' solo un'attivita tecnica. Deve avere un change con owner applicativo, DBA, security e privacy.

| Decisione | Perche' conta | Evidenza richiesta |
|---|---|---|
| Uso di `COMPRESSION=ALL` | puo' richiedere licenza Advanced Compression | conferma licensing |
| Uso di `TRANSFORM=DISABLE_ARCHIVE_LOGGING` | riduce redo ma impatta recovery/Data Guard | approvazione DBA/DR |
| Dati PII in PREPROD | rischio GDPR/compliance | masking approvato |
| DB link importati | rischio puntamenti verso PROD | bonifica tramite runbook DB link |
| Scheduler job importati | rischio batch reali/email/pagamenti | disable script post-import |
| Export consistente | evita dati incoerenti tra tabelle | `FLASHBACK_TIME` o `FLASHBACK_SCN` |
| Performance import | evita saturazione storage/FRA | capacity plan |

---

## 11. Pre-check SQL completo prima dell'export

```sql
SELECT name, log_mode, force_logging, open_mode FROM v$database;
SELECT name, ROUND(space_limit/1024/1024/1024,2) limit_gb,
       ROUND(space_used/1024/1024/1024,2) used_gb,
       ROUND(space_used*100/space_limit,2) pct_used
FROM   v$recovery_file_dest;

SELECT directory_name, directory_path FROM dba_directories ORDER BY directory_name;

SELECT owner, object_type, count(*) cnt
FROM   dba_objects
WHERE  owner IN ('SCHEMA_A','SCHEMA_B')
AND    status <> 'VALID'
GROUP  BY owner, object_type
ORDER  BY owner, object_type;

SELECT owner, segment_name, segment_type, ROUND(bytes/1024/1024/1024,2) gb
FROM   dba_segments
WHERE  owner IN ('SCHEMA_A','SCHEMA_B')
AND    segment_type LIKE 'TABLE%'
ORDER  BY bytes DESC
FETCH FIRST 30 ROWS ONLY;
```

---

## 12. Modalita Data Pump da conoscere

| Modalita | Quando usarla | Nota |
|---|---|---|
| Schema mode | refresh applicativo standard | `SCHEMAS=...` |
| Table mode | refresh mirato | `TABLES=...` |
| Full mode | clone logico ampio | attenzione a ruoli, profili, system grants |
| Network link | import diretto senza dump file | richiede DB link sicuro e rete stabile |
| Transportable tablespace | grandi volumi, downtime pianificato | ottimo per terabyte, ma piu vincolante |

Esempio `NETWORK_LINK` solo in reti controllate:

```ini
NETWORK_LINK=PROD_TO_PREPROD_SAFE_LINK
SCHEMAS=SCHEMA_A,SCHEMA_B
EXCLUDE=STATISTICS
LOGTIME=ALL
METRICS=Y
```

Non usare `NETWORK_LINK` se il DB link punta a produzione senza controllo di ACL/firewall/change.

---

## 13. Manuali e comandi di riferimento

Oracle:

- Oracle Data Pump Export 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump-export-utility.html
- Oracle Data Pump Import 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/datapump-import-utility.html
- Oracle Data Pump Best Practices White Paper: https://www.oracle.com/a/tech/docs/oracle-database-utilities-data-pump-bp-2019.pdf
- Oracle Database Utilities Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/

Comandi/man utili su Linux:

```bash
expdp HELP=YES
impdp HELP=YES
man nohup
man rsync
man sha256sum
man find
man xargs
```

Checklist finale:

```text
[ ] Export log senza ORA- critici.
[ ] Checksum dump verificato su PREPROD.
[ ] Import log analizzato con grep ORA-.
[ ] Oggetti invalidi ricompilati o giustificati.
[ ] DB link bonificati.
[ ] Scheduler job non autorizzati disabilitati.
[ ] Password app ruotate per PREPROD.
[ ] Statistiche optimizer raccolte.
[ ] Data masking verificato su campione PII.
```