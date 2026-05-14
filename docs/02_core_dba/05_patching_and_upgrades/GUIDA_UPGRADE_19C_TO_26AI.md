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
