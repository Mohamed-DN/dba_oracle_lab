# Oracle GoldenGate 19c Completa - Guida Enterprise

> [!NOTE]
> **DOCUMENTI GOLDENGATE CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Guida di Laboratorio (Fase 7)**: [GUIDA_FASE7_GOLDENGATE.md](./GUIDA_FASE7_GOLDENGATE.md) (configurazione passo-passo per il lab a Microservizi).
> - **Cheat Sheet Operativo (Veloce)**: [CS_GOLDENGATE.md](../../01_operations/01_cheat_sheets/CS_GOLDENGATE.md) (comandi rapidi, lag, stop/start).
> - **Cheat Sheet Verticale 19c**: [CHEAT_SHEET_GOLDENGATE_19C.md](./CHEAT_SHEET_GOLDENGATE_19C.md) (comandi analitici e grant).

> Versione principale del percorso: **Oracle GoldenGate 19c (19.1)**. Questa guida spiega i concetti che devi conoscere prima di installare o amministrare GoldenGate in produzione: architettura, prerequisiti DB, sicurezza, scenari di replica, monitoraggio, troubleshooting e integrazione con RAC/Data Guard.

---

## 1. Cosa fa GoldenGate

GoldenGate e' una piattaforma di **replica logica** e **Change Data Capture (CDC)**. Legge le modifiche transazionali dal redo/archivelog del source, le trasforma in record logici dentro trail file e le applica sul target tramite Replicat.

Non e' la stessa cosa di Data Guard:

| Tecnologia | Tipo replica | Granularita | Uso tipico |
| --- | --- | --- | --- |
| Data Guard | Fisica o SQL Apply | Database intero | Disaster Recovery, HA, standby |
| GoldenGate | Logica | Tabelle/schema/sottoinsiemi | Migrazione, integrazione, replica eterogenea, active-active |
| Data Pump | Copia batch | Oggetti/schema/database | Initial load, export/import |

Regola mentale:

- **Data Guard** protegge un database intero e mantiene una copia fisica coerente.
- **GoldenGate** muove transazioni selezionate tra sistemi anche diversi.
- In produzione spesso convivono: Data Guard per DR, GoldenGate per migrazione o integrazione real-time.

---

## 2. Architettura logica

### 2.1 Flusso base Oracle -> Oracle

```text
SOURCE ORACLE 19c (RACDB)                         TARGET ORACLE / OCI / DBTARGET
================================================  ================================================

Redo / Archive Log
      |
      v
+-------------------+       +----------------+     +----------------+     +-------------------+
| Integrated Extract| ----> | Local Trail    | --> | Remote Trail   | --> | Integrated Replicat|
| EXT_RAC           |       | ./dirdat/ea    |     | ./dirdat/rt    |     | REP_TGT           |
+-------------------+       +----------------+     +----------------+     +-------------------+
      |                         ^                      ^                         |
      | checkpoint              |                      | checkpoint               v
      |                         |                      |                  Target tables
      v                         |                      |
LogMiner Server                 +-- Pump / Distribution Server ------------------+
```

Componenti chiave:

| Componente | Ruolo |
| --- | --- |
| Extract | Cattura le transazioni dal source. In Oracle 19c preferire Integrated Extract per Oracle DB. |
| LogMiner Server | Processo DB usato dall'Integrated Extract per leggere redo in modo supportato. |
| Local Trail | File GoldenGate locali dove Extract scrive le modifiche catturate. |
| Data Pump / Distribution Path | Spedisce trail dal source al target. In Classic e' un Extract secondario; in MA e' Distribution Server. |
| Remote Trail | Trail file sul target, letti dal Replicat. |
| Replicat | Applica le modifiche al target. Integrated Replicat e' lo standard Oracle-to-Oracle enterprise. |
| Checkpoint | Punto di restart sicuro: permette ripartenza senza perdere o duplicare transazioni. |

### 2.2 Concetto di trail file

Il trail e' il formato proprietario GoldenGate che contiene record logici di cambiamento:

```text
Trail record = metadata tabella + before/after image + transaction info + commit order
```

Perche' esiste:

- disaccoppia cattura e apply;
- permette restartability;
- permette shipping asincrono;
- permette fan-out verso piu target;
- permette debug con `logdump`.

Best practice:

- non mettere trail su filesystem temporanei;
- dimensionare trail per sopportare backlog;
- usare purge con checkpoint, non cancellazione manuale;
- monitorare crescita trail se Replicat e' fermo.

### 2.3 Commit order e consistenza

GoldenGate deve preservare l'ordine dei commit per evitare dati incoerenti. Questo e' critico quando:

- esistono foreign key;
- piu tabelle partecipano alla stessa transazione;
- si usa parallelismo;
- il target riceve DML da piu sorgenti.

Integrated Replicat e Parallel Replicat migliorano il throughput, ma il DBA deve capire la differenza tra:

| Modalita | Obiettivo | Rischio da controllare |
| --- | --- | --- |
| Serial apply | Massima semplicita | throughput limitato |
| Coordinated/Parallel | throughput alto | dipendenze, conflitti, tuning |
| Integrated Replicat | integrazione DB Oracle | richiede privilegi e DB config corretti |

---

## 2.4 Collegamento tra source e target

GoldenGate non replica tramite una connessione diretta database-to-database. Il collegamento reale e' formato da:

- Extract che si collega al source DB tramite TNS/credential store;
- Pump o Distribution Server che invia trail al target host;
- Replicat che si collega al target DB tramite TNS, ODBC/libpq o connettore supportato.

Per la configurazione completa leggi: [Collegamento Source e Target](./GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md). Per banche o ambienti regolati, aggiungi anche i controlli di [GoldenGate in Ambienti Critici Bancari](./GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md).

---
## 3. Classic vs Microservices in GoldenGate 19c

| Area | Classic Architecture | Microservices Architecture |
| --- | --- | --- |
| Interfaccia | `ggsci` | Web UI, Admin Client, REST API |
| Processo padre | Manager | Service Manager |
| Shipping trail | Data Pump + Collector | Distribution Server + Receiver Server |
| Automazione | script shell + `ggsci` | REST/API + Admin Client |
| Sicurezza | credential store, wallet, parametri | utenti/ruoli deployment, TLS, REST |
| Uso tipico | ambienti legacy, troubleshooting | nuove installazioni e standard moderno |

Scelta consigliata:

- Nuovo lab e nuove installazioni: **Microservices 19c**.
- Ambienti vecchi o esercizi da colloquio/produzione legacy: conoscere **Classic** e `ggsci`.
- Upgrade verso 26ai: preferire percorso Microservices.

---

## 4. Prerequisiti Oracle Database 19c

### 4.1 ARCHIVELOG

Extract ha bisogno dei redo online e degli archivelog. Se un archivio necessario sparisce prima che Extract lo legga, la replica puo' fermarsi.

```sql
ARCHIVE LOG LIST;
```

Se non e' in archivelog:

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

### 4.2 ENABLE_GOLDENGATE_REPLICATION

Parametro obbligatorio per servizi DB usati da capture/apply GoldenGate.

```sql
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
SHOW PARAMETER enable_goldengate_replication;
```

In RAC tutte le istanze devono avere lo stesso valore.

### 4.3 FORCE LOGGING

GoldenGate cattura dal redo. Operazioni `NOLOGGING` possono creare buchi logici.

```sql
ALTER DATABASE FORCE LOGGING;
SELECT force_logging FROM v$database;
```

Nota: `FORCE LOGGING` aumenta redo, quindi devi dimensionare FRA/archive, ma in replica enterprise e' una protezione necessaria.

### 4.4 Supplemental Logging

Oracle redo normale e' pensato per recovery fisico, non sempre contiene tutte le colonne necessarie per ricostruire SQL logico su target. Supplemental logging aggiunge colonne chiave al redo.

Livelli importanti:

| Livello | Comando | Quando |
| --- | --- | --- |
| Minimal DB | `ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;` | Sempre richiesto per GoldenGate |
| Schema | `ADD SCHEMATRANDATA schema;` | Per tutte le tabelle presenti/future di uno schema |
| Table | `ADD TRANDATA schema.tabella;` | Per tabelle specifiche |
| ALLCOLS | `ADD TRANDATA schema.tabella ALLCOLS;` | Active-active, conflict detection, target con chiavi diverse |

SQL minimo lato DB:

```sql
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
SELECT supplemental_log_data_min FROM v$database;
```

Da GoldenGate, dopo login DB:

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
ADD SCHEMATRANDATA HR
INFO SCHEMATRANDATA HR

ADD TRANDATA HR.EMPLOYEES
INFO TRANDATA HR.EMPLOYEES

ADD TRANDATA HR.EMPLOYEES ALLCOLS
INFO TRANDATA HR.EMPLOYEES
```

Scelta pratica:

- Tabelle con PK stabile: `ADD TRANDATA` normale e' spesso sufficiente.
- Schema intero in replica: `ADD SCHEMATRANDATA` e' piu gestibile.
- Active-active o conflict detection: valutare `ALLCOLS`.
- Tabelle senza PK/UI: aggiungere una chiave vera o usare `KEYCOLS`; evitare di replicare heap senza identificatore stabile.

Verifiche SQL:

```sql
SELECT supplemental_log_data_min,
       supplemental_log_data_pk,
       supplemental_log_data_ui,
       force_logging
FROM   v$database;

SELECT owner, log_group_name, table_name, log_group_type, always
FROM   dba_log_groups
WHERE  owner IN ('HR','APP')
ORDER  BY owner, table_name;

SELECT owner, table_name, column_name, position
FROM   dba_log_group_columns
WHERE  owner IN ('HR','APP')
ORDER  BY owner, table_name, position;
```

---

## 5. Utente GGADMIN e sicurezza

### 5.1 Principio least privilege

Non usare `SYS`, `SYSTEM` o `DBA` role per i processi GoldenGate in produzione. Usa un utente dedicato e privilegi tramite `DBMS_GOLDENGATE_AUTH`.

In CDB Oracle 19c puoi usare:

- utente comune `C##GGADMIN` se devi gestire piu PDB;
- utente locale `GGADMIN` nel PDB se la replica e' confinata a un PDB.

### 5.2 Esempio CDB common user

```sql
-- Connesso a CDB$ROOT come SYSDBA
CREATE USER c##ggadmin IDENTIFIED BY "<PASSWORD_SICURA>" CONTAINER=ALL;
GRANT CREATE SESSION TO c##ggadmin CONTAINER=ALL;
GRANT CREATE VIEW TO c##ggadmin CONTAINER=ALL;
GRANT ALTER SYSTEM TO c##ggadmin CONTAINER=ALL;
GRANT ALTER USER TO c##ggadmin CONTAINER=ALL;
ALTER USER c##ggadmin QUOTA UNLIMITED ON USERS CONTAINER=ALL;
ALTER USER c##ggadmin SET CONTAINER_DATA=ALL CONTAINER=CURRENT;

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'C##GGADMIN',
    privilege_type          => '*',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'ALL');
END;
/
```

### 5.3 Esempio PDB local user

```sql
ALTER SESSION SET CONTAINER = PDB1;

CREATE USER ggadmin IDENTIFIED BY "<PASSWORD_SICURA>"
  DEFAULT TABLESPACE USERS
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO ggadmin;
GRANT CREATE VIEW TO ggadmin;

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'GGADMIN',
    privilege_type          => '*',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'CURRENT');
END;
/
```

Per separare i ruoli:

```sql
-- Source capture only
BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN','CAPTURE');
END;
/

-- Target apply only
BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN','APPLY');
END;
/
```

Verifica:

```sql
SELECT * FROM dba_goldengate_privileges WHERE username IN ('GGADMIN','C##GGADMIN');
```

### 5.5 Grant target per Replicat

`DBMS_GOLDENGATE_AUTH` prepara l'utente GoldenGate, ma Replicat deve anche poter applicare DML sulle tabelle target.

Approccio consigliato:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.CUSTOMERS TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.ORDERS TO ggadmin;
```

Approccio temporaneo per migrazione ampia, da approvare e revocare:

```sql
GRANT SELECT ANY TABLE TO ggadmin;
GRANT INSERT ANY TABLE TO ggadmin;
GRANT UPDATE ANY TABLE TO ggadmin;
GRANT DELETE ANY TABLE TO ggadmin;
```

Runbook completo dei privilegi: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

---

## 6. Redo, archive log e FRA

### 6.1 Perche' la FRA e' critica

Extract legge redo online e archivelog. Se Extract si ferma per ore e RMAN/FRA cancella archivelog necessari, GoldenGate puo' andare in abend e potresti dover re-instanziare il target.

Sintomi:

- Extract ABENDED con archive log missing;
- FRA al 90-100%;
- database bloccato con ORA-00257;
- lag che cresce anche se processi risultano RUNNING.

### 6.2 Formula sizing rapida

```text
FRA minima per GoldenGate = redo_per_ora * ore_outage_extract * safety_factor

Esempio:
redo_per_ora = 20 GB
outage tollerato = 8 ore
safety_factor = 1.5
spazio minimo GG = 20 * 8 * 1.5 = 240 GB
```

Poi aggiungi:

- retention RMAN;
- flashback logs;
- archivelog per Data Guard;
- margine patch/manutenzione.

### 6.3 Query redo rate

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS ora,
       ROUND(SUM(blocks * block_size) / 1024 / 1024 / 1024, 2) AS redo_gb
FROM   v$archived_log
WHERE  first_time > SYSDATE - 7
GROUP  BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER  BY ora;
```

### 6.4 Query FRA

```sql
SELECT name,
       space_limit/1024/1024/1024 AS limit_gb,
       space_used/1024/1024/1024 AS used_gb,
       ROUND(space_used*100/space_limit,2) AS pct_used
FROM   v$recovery_file_dest;

SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files
FROM   v$flash_recovery_area_usage
ORDER  BY percent_space_used DESC;
```

### 6.5 Regole operative

- Non cancellare archivelog a mano mentre Extract e' fermo.
- Prima di purge, controlla checkpoint e lag Extract.
- Configura alert su FRA > 80% e > 90%.
- Se Extract e' fermo, aumenta retention o riparti subito.
- Usa `PURGEOLDEXTRACTS ... USECHECKPOINTS` per trail, non `rm` manuale.

---

## 6.6 Knowledge Hub e topologie enterprise

Oltre al lab base, GoldenGate copre topologie unidirectional, bidirectional, peer-to-peer, broadcast, consolidation e distribution/cascading. Oracle raccoglie percorsi di studio, workshop e LiveLabs nel GoldenGate Knowledge Hub.

Per la vista completa: [Use Case, Topologie e Knowledge Hub](./GUIDA_GOLDENGATE_USE_CASES_KNOWLEDGE_HUB.md).

---
## 7. Scenari principali

### 7.1 Oracle -> Oracle one-way

Uso tipico:

- reporting database;
- migrazione zero/near-zero downtime;
- replica verso cloud;
- integrazione real-time.

Pattern:

```text
Oracle Source -> Extract -> Trail -> Replicat -> Oracle Target
```

### 7.2 Oracle -> PostgreSQL

Uso tipico:

- modernizzazione applicativa;
- migrazione eterogenea;
- feed verso piattaforme open source.

Attenzioni:

- datatype mapping;
- sequenze e identity;
- timezone e character set;
- DDL non sempre equivalente;
- case sensitivity nomi oggetti;
- gestione LOB;
- test di update/delete su tabelle con PK.

### 7.3 Bidirectional / active-active

Richiede progettazione seria:

- conflict detection/resolution;
- range di chiavi separati;
- sequence cache gestita;
- loop detection;
- supplemental logging piu ricco;
- test su update concorrenti.

Non e' un setup da fare copiando parametri one-way.

### 7.4 RAC + Data Guard + GoldenGate

Pattern raccomandato:

```text
RAC Primary --Data Guard--> RAC Standby
     |
     +-- GoldenGate Extract --> Target reporting/migration/cloud
```

Note:

- Capture normalmente dal primary.
- Dopo switchover Data Guard devi verificare servizi, alias TNS, Extract e source DB role.
- Usare service name stabile e SCAN quando possibile.
- Documentare runbook post-switchover per GoldenGate.

---

## 8. Troubleshooting essenziale

| Problema | Dove guardare | Azione |
| --- | --- | --- |
| Extract ABENDED | report Extract, alert DB, archive log | verifica archivelog mancanti, redo retention, DB login |
| Replicat ABENDED | report Replicat, discard file | controlla mapping, constraint, dati mancanti |
| Lag Extract alto | DB load, I/O, LogMiner | verifica redo rate, CPU, archive availability |
| Lag Replicat alto | target waits, indexes, constraints | tuning apply, parallelismo, batchsql |
| Trail cresce | Pump/Distribution o Replicat fermo | riparti processi, controlla rete e spazio |
| ORA-01031 | privilegi GGADMIN | riesegui `DBMS_GOLDENGATE_AUTH` |
| ORA-01291 / log missing | archive cancellato | restore archivelog o re-instanzia |
| Dati divergenti | compare query / Veridata | stop, analisi, resync mirato |

Comandi diagnostici Classic:

```text
INFO ALL
LAG EXTRACT ext1
LAG REPLICAT rep1
SEND EXTRACT ext1, STATUS
SEND REPLICAT rep1, STATUS
VIEW REPORT ext1
VIEW REPORT rep1
STATS EXTRACT ext1, TOTAL
STATS REPLICAT rep1, TOTAL
```

Comandi diagnostici DB:

```sql
SELECT capture_name, state, total_messages_captured, total_messages_enqueued
FROM   v$goldengate_capture;

SELECT apply_name, state, total_messages_applied
FROM   v$gg_apply_reader;

SELECT inst_id, name, value
FROM   gv$parameter
WHERE  name = 'enable_goldengate_replication';
```

---

## 9. Checklist production-grade

Prima di avviare GoldenGate:

- [ ] DB source in ARCHIVELOG.
- [ ] `ENABLE_GOLDENGATE_REPLICATION=TRUE` su tutte le istanze RAC.
- [ ] `FORCE LOGGING` attivo.
- [ ] Supplemental logging minimo attivo.
- [ ] `ADD SCHEMATRANDATA` o `ADD TRANDATA` per oggetti replicati.
- [ ] Tabelle hanno PK o chiave stabile.
- [ ] `GGADMIN` creato con least privilege.
- [ ] Credential store configurato, niente password nei param file.
- [ ] FRA dimensionata per outage Extract.
- [ ] Trail filesystem dimensionato e monitorato.
- [ ] Backup di parametri, wallet, deployment e trail critici.
- [ ] Runbook di stop/start e recovery pronto.
- [ ] Test insert/update/delete completato.
- [ ] Test restart Extract/Replicat completato.
- [ ] Test lag e alerting completato.

---

## 10. Fonti ufficiali

- Oracle GoldenGate 19c - Preparing the Database: https://docs.oracle.com/en/middleware/goldengate/core/19.1/oracle-db/preparing-database-oracle-goldengate.html
- Oracle Database 19c - ENABLE_GOLDENGATE_REPLICATION: https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ENABLE_GOLDENGATE_REPLICATION.html
- Oracle Database 19c - DBMS_GOLDENGATE_AUTH: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_GOLDENGATE_AUTH.html
- Oracle GoldenGate 19c - Microservices Components: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/overview-components-oracle-goldengate-microservices-architecture.html
- Oracle GoldenGate - Log Retention: https://docs.oracle.com/en/middleware/goldengate/core/19.1/oracle-db/determining-how-much-data-retain.html
- Grant e privilegi GoldenGate 19c nel lab: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md)

## Obiettivo
Fornire una guida end-to-end su GoldenGate 19c: architettura, installazione, configurazione, esercizio operativo e recovery.

## Procedura operativa
Seguire i blocchi della guida (prerequisiti, setup, configurazione processi, monitoraggio e gestione incident) come percorso completo.

## Validazione finale
Confermare readiness operativa completa: processi stabili, replication lag sotto soglia e procedure di fallback testate.

## Troubleshooting rapido
In caso di malfunzionamenti, usare la sezione di diagnostica per isolare layer coinvolto (DB, rete, trail, processi OGG).
