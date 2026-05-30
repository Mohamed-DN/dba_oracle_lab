# RUNBOOK ENTERPRISE: UPGRADE MISSION-CRITICAL DA ORACLE 19C A 26AI

> **Document Classification:** STRICTLY CONFIDENTIAL / ENTERPRISE OPERATIONS  
> **Last Updated:** Maggio 2026  
> **Target Audience:** Senior DBA, Database Architects, SREs  
> **Estimated Execution Time:** 4-6 ore (In-place), 2-3 ore (Zero-Downtime DBMS_ROLLING)

## SOMMARIO ELETTRONICO
1. [Introduzione e Obiettivi di Business](#1-introduzione-e-obiettivi-di-business)
2. [Fase 0: Assessment Architetturale e Prerequisiti Hardware/OS](#2-fase-0-assessment-architetturale-e-prerequisiti-hardwareos)
3. [Fase 1: Pre-Volo e Bonifica del Database (Igiene)](#3-fase-1-pre-volo-e-bonifica-del-database-igiene)
4. [Fase 2: Disaster Recovery & Fallback Strategy (Il Paracadute)](#4-fase-2-disaster-recovery--fallback-strategy-il-paracadute)
5. [Fase 3: AutoUpgrade State Machine (In-Place Upgrade)](#5-fase-3-autoupgrade-state-machine-in-place-upgrade)
6. [Fase 4: Zero-Downtime Upgrade tramite DBMS_ROLLING (Data Guard)](#6-fase-4-zero-downtime-upgrade-tramite-dbms_rolling-data-guard)
7. [Fase 5: Post-Upgrade Checklist & Timezone Patching](#7-fase-5-post-upgrade-checklist--timezone-patching)
8. [Fase 6: Validazione Applicativa e Troubleshooting Avanzato](#8-fase-6-validazione-applicativa-e-troubleshooting-avanzato)

---

## 1. Introduzione e Obiettivi di Business

L'aggiornamento da Oracle 19c (la Long Term Release predominante del decennio 2019-2025) a **Oracle AI Database 26ai** rappresenta un salto architetturale epocale. Oracle 26ai non è un semplice aggiornamento incrementale, ma introduce il motore **AI Vector Search**, il **JSON Relational Duality**, e l'**SQL Firewall** integrato nel Kernel RDBMS. 

Questo documento è un **Method of Procedure (MOP)** di livello Enterprise. Ogni singolo comando, output e possibile eccezione è documentato. L'operatore non deve MAI assumere nulla: deve copiare, incollare e validare.

---

## 2. Fase 0: Assessment Architetturale e Prerequisiti Hardware/OS

### 2.1. Matrice di Compatibilità OS
Oracle 26ai impone vincoli stringenti sul sistema operativo sottostante.
- **Supportato**: Oracle Linux 8.8+, Oracle Linux 9.2+, Red Hat Enterprise Linux 8.8+, Red Hat Enterprise Linux 9.2+.
- **NON Supportato**: Qualsiasi versione di Oracle Linux 7 o RHEL 7.

*Comando di verifica (Eseguire su tutti i nodi RAC/DataGuard):*
```bash
cat /etc/os-release | egrep '^(NAME|VERSION)='
uname -r
```

*Output Atteso:*
```text
NAME="Oracle Linux Server"
VERSION="8.9"
5.15.0-202.135.2.el8uek.x86_64
```

### 2.2. Dimensionamento Memoria (SGA/PGA)
Le nuove feature di intelligenza artificiale (Vector Search, True Cache) richiedono un footprint di memoria leggermente superiore rispetto a 19c.
- **Delta richiesto**: +15% SGA, +10% PGA rispetto ai valori attuali di 19c.

*Comando di verifica (Eseguire su SQL*Plus as SYSDBA):*
```sql
SELECT name, value/1024/1024 AS MB FROM v$parameter WHERE name IN ('sga_target', 'pga_aggregate_target');
```

### 2.3. Controllo Spazio Disco (FRA e Oracle Home)
L'installazione dei nuovi binari 26ai (Out-of-place) richiede almeno 15GB di spazio nella partizione `/u01`.
Inoltre, il Flashback Database (Guaranteed Restore Point) richiederà abbondante spazio nella Fast Recovery Area (FRA) per conservare l'immagine pre-upgrade.

*Comando di verifica:*
```bash
df -h /u01
```
*Output Atteso:* Minimo 20G Available.

```sql
SELECT name, space_limit/1024/1024/1024 AS Limit_GB, space_used/1024/1024/1024 AS Used_GB 
FROM v$recovery_file_dest;
```
*Azione:* Garantire che (Limit - Used) sia > 200GB. In caso contrario, svuotare la FRA o estendere il LUN ASM.

---

## 3. Fase 1: Pre-Volo e Bonifica del Database (Igiene)

L'upgrade fallisce o si prolunga per ore se il dizionario dati 19c è "sporco". L'igiene è tassativa e va eseguita **48 ore prima** della finestra di fermo.

### 3.1. Svuotamento Recycle Bin
Il dizionario Oracle tenterà di analizzare e convertire oggetti presenti nel cestino.
```sql
-- Esecuzione: SYSDBA
PURGE DBA_RECYCLEBIN;
```
*Output Atteso:*
```text
DBA Recyclebin purged.
```

### 3.2. Risoluzione Transazioni Distribuite In Sospeso (2PC)
Transazioni pendenti bloccheranno il db in fase di upgrade causandone il crash immediato.
```sql
SELECT local_tran_id, state FROM dba_2pc_pending;
```
*Output Atteso:* `no rows selected`.
*Contingency (se restituisce righe):*
```sql
EXECUTE DBMS_TRANSACTION.PURGE_LOST_DB_ENTRY('<local_tran_id>');
COMMIT;
```

### 3.3. Compilazione Oggetti Invalidi
Non avviare mai un upgrade se ci sono oggetti utente invalidi.
```bash
$ORACLE_HOME/perl/bin/perl $ORACLE_HOME/rdbms/admin/utlrp.sql
```
Verifica:
```sql
SELECT owner, object_type, count(*) 
FROM dba_objects 
WHERE status='INVALID' 
GROUP BY owner, object_type ORDER BY 1;
```
*Output Atteso:* Righe restituite limitate a schemi non essenziali o `no rows selected`.

### 3.4. Raccolta Statistiche Dizionario
Lo step più critico per le performance di AutoUpgrade.
```sql
EXEC DBMS_STATS.GATHER_DICTIONARY_STATS;
EXEC DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;
```
*Attenzione: Questi comandi possono durare dai 5 ai 45 minuti a seconda della frammentazione della Shared Pool.*

---

## 4. Fase 2: Disaster Recovery & Fallback Strategy (Il Paracadute)

In caso l'upgrade si blocchi al 60% per un bug Oracle o un problema di data dictionary corruption, il restore da un backup RMAN di un DB da 10TB richiederebbe 12 ore. Inaccettabile.
Utilizzeremo un **Guaranteed Restore Point (GRP)**.

### 4.1. Creazione del GRP (Eseguire 5 minuti prima del fermo)
```sql
-- Verificare stato Archivelog e Flashback
SELECT log_mode, flashback_on FROM v$database;
-- Se FLASHBACK_ON è NO, attivarlo:
ALTER DATABASE FLASHBACK ON;

-- Creare il GRP
CREATE RESTORE POINT FALLBACK_TO_19C GUARANTEE FLASHBACK DATABASE;

-- Verificare la corretta creazione
SELECT name, guarantee_flashback_database, time FROM v$restore_point WHERE name = 'FALLBACK_TO_19C';
```

### 4.2. Procedura di Emergenza (MOP Rollback)
*Scenario:* L'AutoUpgrade fallisce irreversibilmente. Il Management ordina l'abort.
*Execution Time:* 5 Minuti.
```sql
-- Aprire con la VECCHIA Oracle Home (19c)
STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT FALLBACK_TO_19C;
ALTER DATABASE OPEN RESETLOGS;
-- Il database è tornato esattamente allo stato pre-upgrade.
```

---

## 5. Fase 3: AutoUpgrade State Machine (In-Place Upgrade)

L'AutoUpgrade tool orchestrerà il tutto tramite un file `.cfg`.

### 5.1. Costruzione autoupgrade.cfg
Creare il file `/u01/app/oracle/admin/autoupgrade/config_26ai.cfg`:
```ini
global.autoupg_log_dir=/u01/app/oracle/admin/autoupgrade
upg1.dbname=PRDDB
upg1.start_time=NOW
upg1.source_home=/u01/app/oracle/product/19.3.0/dbhome_1
upg1.target_home=/u01/app/oracle/product/26.0.0/dbhome_1
upg1.sid=PRDDB
upg1.log_dir=/u01/app/oracle/admin/autoupgrade/PRDDB
upg1.target_version=26
upg1.timezone_upg=no
upg1.run_utlrp=yes
```

### 5.2. Mode ANALYZE (Sola lettura, Nessun Downtime)
```bash
java -jar autoupgrade.jar -config config_26ai.cfg -mode analyze
```
*Esaminare l'HTML generato in `/u01/app/oracle/admin/autoupgrade/PRDDB/100/prechecks/prddb_preupgrade.html`.*

### 5.3. Mode DEPLOY (DOWNTIME INIZIATO)
Fermare le applicazioni. Spegnere i listeners. Lanciare il deploy.
```bash
java -jar autoupgrade.jar -config config_26ai.cfg -mode deploy
```

La console interattiva mostrerà i Job ID.
```text
autoupgrade> lsj
+----+-------+---------+---------+-------+--------------+--------+
|Job#|DB_NAME|    STAGE|OPERATION| STATUS|    START_TIME| UPDATED|
+----+-------+---------+---------+-------+--------------+--------+
| 101|  PRDDB|DBUPGRADE|EXECUTING|RUNNING|26/05 02:00:00|02:15:00|
+----+-------+---------+---------+-------+--------------+--------+
```
Comandi utili della console:
- `status -job 101`: Mostra la percentuale esatta dell'avanzamento.
- `tasks`: Mostra quali worker RDBMS stanno compilando i file PLB.
- `resume -job 101`: Se il job va in errore per un tablespace pieno, allarga il datafile da un altro terminale e poi lancia resume.

---

## 6. Fase 4: Zero-Downtime Upgrade tramite DBMS_ROLLING (Data Guard)

Per SLA rigorosi (99.999%), un fermo di 2 ore non è ammissibile. Si procede con l'architettura **Transient Logical Standby**. 
L'infrastruttura DEVE avere un Oracle Data Guard Physical Standby in Maximum Performance mode.

### 6.1. Inizializzazione
Sulla Primary 19c:
```sql
EXEC DBMS_ROLLING.INIT_PLAN(future_primary => 'STANDBY_DB_UNIQUE_NAME');
```
*Output: Il piano viene generato nel dizionario dati.*

### 6.2. Costruzione
```sql
EXEC DBMS_ROLLING.BUILD_PLAN;
```
*Il Physical Standby viene convertito silenziosamente in un Logical Standby e il processo SQL Apply inizia a convertire i redo log in statement DML.*

### 6.3. Upgrade della Logical Standby a 26ai
Si ferma l'istanza Standby. Si monta il software 26ai. Si apre il database in UPGRADE mode ed esegue `dbupgrade`.
Le applicazioni *continuano* a scrivere sulla Primary 19c. Lo Standby logico si accoda bufferizzando.

### 6.4. Switchover (Il momento della verità)
Quando il business autorizza 30 secondi di micro-downtime:
Sulla Primary 19c:
```sql
EXEC DBMS_ROLLING.SWITCHOVER;
```
Le connessioni TAF (Transparent Application Failover) o Application Continuity vengono dirottate sulla ex-Standby (ormai 26ai). Le applicazioni riprendono senza accorgersi della nuova versione RDBMS sottostante.

### 6.5. Ricostruzione Vecchia Primary
L'ultimo step è sincronizzare la vecchia Primary 19c convertendola in una Physical Standby 26ai.
```sql
EXEC DBMS_ROLLING.FINISH_PLAN;
```
*La procedura elimina l'architettura Logical e ristabilisce il Physical Data Guard pulito.*

---

## 7. Fase 5: Post-Upgrade Checklist & Timezone Patching

Una volta che il DB è aperto su 26ai, si deve finalizzare l'asset.

### 7.1. Innalzamento Compatibilità
Durante il testing post-upgrade, il parametro `compatible` resta ancorato a 19.0.0. Questo permette ancora il downgrade.
Una volta approvato l'ambiente (Sign-Off), innalzarlo per sbloccare le feature 26ai.
```sql
ALTER SYSTEM SET COMPATIBLE='26.0.0' SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP;
```
**ATTENZIONE:** Il downgrade ora è matematicamente impossibile.

### 7.2. Upgrade del File Timezone (DBMS_DST)
Le nuove release Oracle aggiornano le tavole DST globali (fusi orari, ora legale).
```sql
-- Identificare la versione corrente
SELECT version FROM v$timezone_file;

-- Applicare la nuova (es. V44 o superiore)
EXEC DBMS_DST.BEGIN_UPGRADE(44);
-- Riavviare il DB due volte (come richiesto dallo script) e poi:
EXEC DBMS_DST.END_UPGRADE(44);
```

### 7.3. Rimozione GRP
Per evitare che la FRA si riempia e blocchi il DB:
```sql
DROP RESTORE POINT FALLBACK_TO_19C;
```

---

## 8. Fase 6: Validazione Applicativa e Troubleshooting Avanzato

### 8.1. Check Componenti Core
Verificare che non ci siano componenti RDBMS rimasti in stato `INVALID` o `OPTION OFF`.
```sql
SELECT comp_name, version, status FROM dba_registry ORDER BY comp_name;
```
*Output Atteso:* Tutti i componenti (Oracle Database Catalog, Oracle XML Database, ecc.) devono mostrare stato `VALID` e versione `26.0.0.0.0`.

### 8.2. Validazione AI Vector Search
Per dimostrare al management l'avvenuto passaggio, esegui un test di creazione di una colonna vettoriale (Feature iconica di 26ai):
```sql
CREATE TABLE ai_demo_docs (
    doc_id NUMBER PRIMARY KEY,
    doc_content CLOB,
    doc_embedding VECTOR(1536, FLOAT32)
);
INSERT INTO ai_demo_docs (doc_id, doc_content) VALUES (1, 'Test 26ai completato con successo');
COMMIT;
```

### 8.3. Troubleshooting: ORA-04023
Se alcune view rimangono in stato `INVALID` persistente e `utlrp.sql` non le risolve:
```sql
ALTER VIEW <nome_vista> COMPILE;
-- Se fallisce per object dependency, fare rebuild delle statistiche fisse
EXEC DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;
```

### 8.4. ORA-28040: No matching authentication protocol
I client antichissimi (Oracle Client 10g/11g) non riescono a connettersi a 26ai di default.
Modificare il `sqlnet.ora` lato RDBMS Server:
```text
SQLNET.ALLOWED_LOGON_VERSION_SERVER=11
SQLNET.ALLOWED_LOGON_VERSION_CLIENT=11
```
Riavviare il listener.

---

## 9. Considerazioni Specifiche per Ambienti RAC

In un cluster Oracle RAC (Real Application Clusters), l'upgrade segue un pattern leggermente diverso rispetto al Single Instance.

### 9.1. Upgrade dell'Oracle Home in Parallelo (Out-of-Place)
L'approccio raccomandato per RAC è l'upgrade **Out-of-Place**:
1. Installare i binari 26ai in una **nuova Oracle Home** su TUTTI i nodi del cluster simultaneamente.
2. Il vecchio Oracle Home 19c resta intatto fino al completamento dell'upgrade.
3. In caso di rollback, basta puntare i binari alla vecchia Home.

```bash
# Verificare le Oracle Home esistenti su tutti i nodi
cat /etc/oratab
# Output atteso:
# PRDDB:/u01/app/oracle/product/19.3.0/dbhome_1:N   <-- Vecchia
# PRDDB:/u01/app/oracle/product/26.0.0/dbhome_1:N   <-- Nuova (dopo installazione)
```

### 9.2. Spegnimento Rolling dei Nodi
Prima di lanciare AutoUpgrade, i nodi RAC devono essere fermati in ordine:
```bash
# Sul nodo 1 (ultimo a rimanere attivo):
srvctl stop database -db PRDDB -stopoption IMMEDIATE
# Verificare
crsctl stat res -t | grep -A 3 PRDDB
```

### 9.3. Post-Upgrade: Riavvio del Cluster
```bash
# Riavviare il database sotto la nuova Oracle Home 26ai
srvctl modify database -db PRDDB -oraclehome /u01/app/oracle/product/26.0.0/dbhome_1
srvctl start database -db PRDDB
# Verificare tutti i nodi
srvctl status database -db PRDDB -verbose
```
*Output Atteso:*
```text
Instance PRDDB1 is running on node rac-node-1. Instance status: Open.
Instance PRDDB2 is running on node rac-node-2. Instance status: Open.
```

### 9.4. Upgrade dei Componenti Clusterware (Grid Infrastructure)
Se anche la Grid Infrastructure deve passare a 26ai (raccomandato):
```bash
# Eseguire come utente grid, NON come oracle
cd /u01/app/26.0.0/grid/
./gridSetup.sh -applyRU /path/to/patch -applyOneOffs /path/to/oneoff
```
L'upgrade della GI avviene in modalità **Rolling** (un nodo alla volta), senza downtime del cluster.

---

## 10. SQL Performance Analyzer (SPA): Test di Regressione Pre/Post Upgrade

### 10.1. Perché SPA è Indispensabile
L'upgrade del dizionario dati e dell'ottimizzatore SQL possono causare **regressioni prestazionali** su query critiche. SPA cattura il workload SQL prima dell'upgrade e lo riproduce dopo, confrontando i piani di esecuzione e i tempi.

### 10.2. Fase Pre-Upgrade: Cattura del Workload (sul DB 19c)
```sql
-- Creare un SQL Tuning Set (STS) dalla cache attiva
BEGIN
  DBMS_SQLTUNE.CREATE_SQLSET(
    sqlset_name  => 'PRE_UPG_WORKLOAD',
    description  => 'Workload catturato prima dell upgrade a 26ai'
  );
END;
/

-- Popolare l'STS dal Cursor Cache (ultime 24h di attività)
BEGIN
  DBMS_SQLTUNE.CAPTURE_CURSOR_CACHE_SQLSET(
    sqlset_name     => 'PRE_UPG_WORKLOAD',
    time_limit      => 86400,     -- 24 ore di campionamento
    repeat_interval => 60         -- Campiona ogni 60 secondi
  );
END;
/

-- Oppure, popolare l'STS dagli snapshot AWR (più completo)
DECLARE
  l_cursor DBMS_SQLTUNE.SQLSET_CURSOR;
BEGIN
  OPEN l_cursor FOR
    SELECT VALUE(p) FROM TABLE(
      DBMS_SQLTUNE.SELECT_WORKLOAD_REPOSITORY(
        begin_snap => 1000,
        end_snap   => 1050,
        basic_filter => 'parsing_schema_name NOT IN (''SYS'',''SYSTEM'')'
      )
    ) p;
  DBMS_SQLTUNE.LOAD_SQLSET(
    sqlset_name => 'PRE_UPG_WORKLOAD',
    populate_cursor => l_cursor
  );
END;
/
```

### 10.3. Fase Post-Upgrade: Replay e Confronto (sul DB 26ai)
```sql
-- Creare il SPA Task
EXEC DBMS_SQLPA.CREATE_ANALYSIS_TASK(
  task_name   => 'SPA_19C_VS_26AI',
  sqlset_name => 'PRE_UPG_WORKLOAD',
  description => 'Confronto prestazionale 19c vs 26ai'
);

-- Eseguire il Trial con l'ottimizzatore 19c (simulato)
EXEC DBMS_SQLPA.EXECUTE_ANALYSIS_TASK(
  task_name      => 'SPA_19C_VS_26AI',
  execution_type => 'CONVERT SQLSET',
  execution_name => 'TRIAL_19C'
);

-- Eseguire il Trial con l'ottimizzatore 26ai (reale)
EXEC DBMS_SQLPA.EXECUTE_ANALYSIS_TASK(
  task_name      => 'SPA_19C_VS_26AI',
  execution_type => 'TEST EXECUTE',
  execution_name => 'TRIAL_26AI'
);

-- Generare il Report di Confronto
SELECT DBMS_SQLPA.REPORT_ANALYSIS_TASK(
  task_name       => 'SPA_19C_VS_26AI',
  type            => 'HTML',
  section         => 'ALL',
  execution_name1 => 'TRIAL_19C',
  execution_name2 => 'TRIAL_26AI'
) FROM DUAL;
```
*Il report HTML mostrerà per ogni SQL:*
- **Tempo di esecuzione**: Prima vs Dopo.
- **Piano di esecuzione**: Cambiato o invariato.
- **Classificazione**: Improved, Regressed, Unchanged.

### 10.4. Gestione delle Regressioni
Se SPA identifica query regredite:
```sql
-- Fissare il piano di esecuzione al vecchio piano (SQL Plan Baseline)
DECLARE
  l_plans PLS_INTEGER;
BEGIN
  l_plans := DBMS_SPM.LOAD_PLANS_FROM_SQLSET(
    sqlset_name => 'PRE_UPG_WORKLOAD',
    basic_filter => 'sql_id = ''abcdef123456'''
  );
  DBMS_OUTPUT.PUT_LINE('Piani caricati: ' || l_plans);
END;
/
```

---

## 11. Upgrade del Catalogo RMAN e Data Pump

### 11.1. RMAN Recovery Catalog
Se utilizzi un Recovery Catalog esterno (raccomandato in Enterprise), questo deve essere aggiornato alla versione 26ai:
```bash
rman target / catalog /@RCAT_DB
```
```text
RMAN> UPGRADE CATALOG;
# Oracle richiederà conferma: digitare YES

recovery catalog upgraded to version 26.00.00.00.00
DBMS_RCVCAT package upgraded to version 26.00.00.00

RMAN> UPGRADE CATALOG;
# RIPETERE due volte (requisito noto per bug documentato)

recovery catalog owner is rman_user
recovery catalog upgraded to version 26.00.00.00.00 (no changes)
```

### 11.2. Data Pump: Nuove Feature
Data Pump su 26ai supporta nativamente:
- **Export/Import di colonne VECTOR**: I tipi vettoriali vengono serializzati/deserializzati correttamente.
- **Duality Views**: Vengono esportate sia le tabelle sottostanti che le definizioni JSON delle Duality View.
Verificare la versione di Data Pump:
```bash
expdp help=yes | head -5
# Output atteso: Export: Release 26.0.0.0.0
```

---

## 12. Template di Change Management (CAB/ITIL)

### 12.1. Modulo di Richiesta di Cambio (RFC)
Per ambienti regolamentati (banche, telecomunicazioni, sanità), ogni upgrade deve essere approvato dal Change Advisory Board (CAB). Di seguito un template ITIL-compliant:

```
=====================================================
MODULO RFC - CHANGE REQUEST FORM
=====================================================
ID Change:          CHG-2026-0042
Titolo:             Upgrade Oracle Database da 19c a 26ai
Categoria:          Major Change (Infrastructure)
Priorità:           P2 - Alta
Ambiente Target:    Produzione (PRDDB)
Finestra di Fermo:  Sabato 31/05/2026, 02:00 - 08:00 CEST (6 ore)
Downtime Previsto:  2-4 ore (in-place) / 30 sec (DBMS_ROLLING)
Impatto:            Servizi dipendenti dal database Oracle PRDDB
                    (App1, App2, Batch notturno)
Rischio:            MEDIO (mitigato da Guaranteed Restore Point)
=====================================================
PIANO DI ROLLBACK:
  Tempo Stimato:    5 minuti
  Metodo:           Flashback Database to RESTORE POINT FALLBACK_TO_19C
  Responsabile:     DBA Senior (Mohamed)
=====================================================
PIANO DI COMUNICAZIONE:
  T-7 giorni:       Email a tutti gli stakeholder
  T-1 giorno:       Conferma del GO/NO-GO
  T+0 (inizio):     SMS/Slack al team di guardia
  T+0 (fine):       Email di chiusura e conferma servizio
=====================================================
APPROVAZIONI:
  [ ] DBA Lead
  [ ] Application Owner
  [ ] Security Officer
  [ ] Change Manager
=====================================================
```

---

## 13. Checklist di Esecuzione Stampabile

Questa checklist è pensata per essere stampata e compilata a penna durante l'esecuzione notturna dell'upgrade.

```
CHECKLIST UPGRADE 19C → 26AI
Data: ___/___/______  Operatore: ___________________

PRE-UPGRADE
[ ] ___:___ Backup RMAN Full verificato
[ ] ___:___ PURGE DBA_RECYCLEBIN completato
[ ] ___:___ Transazioni 2PC: nessuna pendente
[ ] ___:___ utlrp.sql: 0 oggetti invalidi
[ ] ___:___ DBMS_STATS.GATHER_DICTIONARY_STATS completato
[ ] ___:___ DBMS_STATS.GATHER_FIXED_OBJECTS_STATS completato
[ ] ___:___ Flashback Database: ON
[ ] ___:___ RESTORE POINT FALLBACK_TO_19C creato
[ ] ___:___ Applicazioni fermate
[ ] ___:___ Listener fermato

UPGRADE
[ ] ___:___ AutoUpgrade mode ANALYZE completato (0 errori bloccanti)
[ ] ___:___ AutoUpgrade mode DEPLOY lanciato (Job ID: ___)
[ ] ___:___ Deploy completato (status: COMPLETED)

POST-UPGRADE
[ ] ___:___ SELECT * FROM v$version → 26.0.0.0.0
[ ] ___:___ SELECT comp_name, status FROM dba_registry → tutti VALID
[ ] ___:___ utlrp.sql post-upgrade completato
[ ] ___:___ DBMS_DST timezone upgrade completato
[ ] ___:___ RMAN UPGRADE CATALOG completato (x2)
[ ] ___:___ Listener riavviato
[ ] ___:___ Applicazioni riavviate e testate
[ ] ___:___ Sign-off dal business ricevuto

POST-STABILIZZAZIONE (dopo 7 giorni)
[ ] ___:___ ALTER SYSTEM SET COMPATIBLE='26.0.0' SCOPE=SPFILE
[ ] ___:___ DROP RESTORE POINT FALLBACK_TO_19C
[ ] ___:___ Chiusura RFC nel sistema ITSM
```
