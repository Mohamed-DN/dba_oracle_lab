# FASE 7: Oracle GoldenGate — Replica in Tempo Reale (Target Locale + PostgreSQL)

> Questa fase configura Oracle GoldenGate Classic Architecture per replicare dati dal RAC Primary verso un database Oracle target su un PC/VM separato, e opzionalmente verso PostgreSQL. L'approccio è 100% manuale, riga per riga, per massimizzare l'apprendimento.

---

## 7.0 Teoria Profonda: Cos'è GoldenGate e Come Funziona

Prima di toccare un solo comando, devi capire l'architettura.

### 7.0.1 Il Problema che GoldenGate Risolve

```
SCENARIO: Hai un database di produzione Oracle RAC.
Vuoi copiare le modifiche in tempo reale verso:
  - Un database Oracle su un altro server (reporting, analytics, migrazione)
  - Un database PostgreSQL (eterogeneità, cloud-native)

SOLUZIONI POSSIBILI:
  1. Data Guard → SOLO Oracle-to-Oracle, SOLO copia completa, SOLO 1 standby attivo
  2. Data Pump (expdp/impdp) → NON in tempo reale, è un export/import batch
  3. Database Links → Sincrono, lento, accoppiamento stretto
  4. GoldenGate → In tempo reale, asincrono, eterogeneo, filtrabile ✅
```

### 7.0.2 I 5 Processi di GoldenGate (Spiegazione Dettagliata)

```
  SOURCE DATABASE (rac1)                          TARGET DATABASE (dbtarget)
  ═══════════════════════                         ═══════════════════════════

  ┌──────────────────┐                            ┌──────────────────┐
  │  Oracle Database │                            │  Oracle Database │
  │  (RACDB)         │                            │  (o PostgreSQL)  │
  │                  │                            │                  │
  │  Redo Log Files  │                            │  Tabelle Target  │
  │  ┌────────────┐  │                            │  ┌────────────┐  │
  │  │redo01.log  │  │                            │  │ HR.EMPLOYEES│ │
  │  │redo02.log  │──┤                            │  │ HR.DEPARTMENTS│
  │  │redo03.log  │  │                            │  └────────────┘  │
  │  └────────────┘  │                            └────────┬─────────┘
  └────────┬─────────┘                                     ▲
           │                                               │
           ▼                                               │
  ┌────────────────────┐                          ┌────────┴───────────┐
  │ 1. EXTRACT         │                          │ 5. REPLICAT        │
  │ (Integrato)        │                          │                    │
  │ Legge i redo log   │                          │ Legge il trail     │
  │ tramite LogMiner   │                          │ remoto e applica   │
  │ interno di Oracle. │                          │ INSERT/UPDATE/     │
  │ Cattura ogni       │                          │ DELETE sul target. │
  │ INSERT, UPDATE,    │                          │                    │
  │ DELETE committato. │                          │ È "l'ultimo anello│
  │                    │                          │ della catena".     │
  └────────┬───────────┘                          └────────▲───────────┘
           │                                               │
           ▼                                               │
  ┌────────────────────┐                          ┌────────┴───────────┐
  │ 2. LOCAL TRAIL     │                          │ 4. REMOTE TRAIL    │
  │ (file su disco)    │                          │ (file su disco     │
  │                    │                          │  del TARGET)       │
  │ File sequenziali   │     ═══ RETE ═══►       │                    │
  │ che contengono     │                          │ Identico al local  │
  │ le transazioni     ├─────────────────────────►│ trail ma sul disco │
  │ catturate.         │                          │ del target.        │
  │ Formato: ./dirdat/ │                          │ Formato: ./dirdat/ │
  │ Nome: er000001     │                          │ Nome: rt000001     │
  └────────┬───────────┘                          └────────────────────┘
           │
           ▼
  ┌────────────────────┐
  │ 3. DATA PUMP       │
  │ (processo Extract  │
  │  secondario)       │
  │                    │
  │ Legge il local     │
  │ trail e lo SPEDISCE│
  │ via TCP/IP al      │
  │ target. NON legge  │
  │ il database, solo  │
  │ il file trail.     │
  │                    │
  │ "Il postino" della │
  │ catena.            │
  └────────────────────┘

  PROCESSO TRASVERSALE:
  ┌────────────────────┐
  │ MANAGER (MGR)      │
  │ Gira su entrambi   │
  │ i lati. Gestisce   │
  │ porte, auto-       │
  │ restart, pulizia   │
  │ trail vecchi.      │
  │ È il "supervisore".│
  └────────────────────┘
```

### 7.0.3 Trail Files — Il Cuore del Sistema

```
Cos'è un Trail File?
═══════════════════════

Un trail file è un file binario sequenziale che contiene le operazioni
DML (INSERT, UPDATE, DELETE) catturate dal database sorgente.

Caratteristiche:
  - Formato proprietario Oracle GoldenGate (non leggibile da umani)
  - Organizzato in segmenti da 250 MB (default) o custom
  - Naming convention: <prefisso><sequenza>
    Esempio: er000001, er000002, er000003, ...
  - Ogni segmento è immutabile una volta chiuso

Ciclo di vita:
  1. L'Extract scrive nel trail locale (es. ./dirdat/er000001)
  2. Quando il file raggiunge la dimensione massima, ne apre uno nuovo
  3. Il Data Pump legge il trail locale e lo copia nel trail remoto
  4. Il Replicat legge il trail remoto e applica le operazioni
  5. Il Manager cancella i trail vecchi (PURGEOLDEXTRACTS)

ANALOGIA: Pensa ai trail file come a un "nastro trasportatore"
di modifiche. L'Extract mette le scatole (operazioni) sul nastro,
il Pump le trasporta alla destinazione, il Replicat le scarica.
```

### 7.0.4 Integrated Extract vs Classic Extract

```
CLASSIC EXTRACT (vecchio modo):
  - GoldenGate apre direttamente i file redo log del database
  - Problemi: conflitti con ASM, locking, compatibilità RAC limitata
  - NON più raccomandato da Oracle

INTEGRATED EXTRACT (modo moderno — quello che usiamo noi):
  - GoldenGate si "registra" dentro il database come un consumer LogMiner
  - Oracle stesso (il server process) legge i redo log e li passa a GG
  - Vantaggi:
    * Funziona nativamente con RAC (logico, non fisico)
    * Funziona con ASM senza problemi
    * Supporta DDL filtering
    * Supporta compressione Oracle, TDE, ecc.
  - È l'unica modalità supportata per Oracle 12c+ in ambienti RAC

COME SI ATTIVA:
  GGSCI> ADD EXTRACT ext_rac, INTEGRATED TRANLOG, BEGIN NOW
  ^^^ La keyword "INTEGRATED" dice a GG di usare LogMiner interno
```

### 7.0.5 GoldenGate vs Data Guard — Le Differenze

| Aspetto | Data Guard | GoldenGate |
|---------|-----------|------------|
| **Scopo** | Disaster Recovery (copia 1:1) | Replica selettiva e trasformazione |
| **Target** | Solo Oracle, stessa versione | Oracle, PostgreSQL, MySQL, Kafka, ecc. |
| **Granularità** | Intero database | Schema, tabella, colonna singola |
| **Direzione** | Unidirezionale (Primary→Standby) | Bidirezionale possibile |
| **Filtro dati** | No (replica tutto) | Sì (WHERE clause, column mapping) |
| **Trasformazione** | No | Sì (rename, convert, merge) |
| **Modalità** | Fisico (blocchi) o Logico | Logico (DML statements) |
| **Latenza** | ~0 secondi (sincrono possibile) | Secondi (asincrono) |
| **Uso tipico** | HA/DR | Migrazione, reporting, ETL |

---

## 7.0A Ingresso da Fase 6 (check obbligatorio)

GoldenGate ha senso solo se il database è stabile.

```bash
dgmgrl sys/<password>@RACDB
SHOW CONFIGURATION;
SHOW DATABASE RACDB;
SHOW DATABASE RACDB_STBY;
```

```sql
sqlplus / as sysdba
SELECT name, open_mode, database_role, db_unique_name FROM v$database;
SELECT force_logging, supplemental_log_data_min FROM v$database;
```

Criteri minimi:
- Broker `SUCCESS` o warning già compresi
- Primary `READ WRITE` e ruolo `PRIMARY`
- Standby sano e apply attivo
- Source stabile prima di toccare GoldenGate

Se Data Guard non è stabile, torna a [GUIDA_FASE4_DATAGUARD_DGMGRL.md](./GUIDA_FASE4_DATAGUARD_DGMGRL.md).

---

## 7.1 Architettura del Lab

```
  ┌─────────────────────────────┐
  │ RAC PRIMARY (rac1)          │
  │ RACDB — Oracle 19c          │
  │ IP: 192.168.56.101          │
  │                             │
  │ ┌─────────────────────────┐ │
  │ │ GoldenGate Home         │ │
  │ │ /u01/app/goldengate     │ │
  │ │                         │ │
  │ │ ● Manager (porta 7809)  │ │
  │ │ ● Extract (ext_rac)     │ │
  │ │ ● Data Pump (pump_rac)  │ │
  │ └─────────────────────────┘ │
  └─────────────┬───────────────┘
                │
                │ TCP/IP porta 7809
                │ Trail remoto via rete
                │
  ┌─────────────▼───────────────┐     ┌─────────────────────────────┐
  │ PERCORSO A: Oracle Target   │     │ PERCORSO B: PostgreSQL      │
  │ dbtarget — Oracle 19c/21c   │     │ pghost — PostgreSQL 15/16   │
  │ IP: 192.168.56.120 (esempio)│     │ IP: 192.168.56.130 (esempio)│
  │                             │     │                             │
  │ ┌─────────────────────────┐ │     │ ┌─────────────────────────┐ │
  │ │ GoldenGate Home         │ │     │ │ GG for Big Data / JDBC  │ │
  │ │ Manager + Replicat      │ │     │ │ Manager + Replicat JDBC │ │
  │ └─────────────────────────┘ │     │ └─────────────────────────┘ │
  └─────────────────────────────┘     └─────────────────────────────┘

  In PARALLELO, Data Guard continua:
  rac1/rac2 ──(redo)──> racstby1/racstby2 (standby, DR)
```

> **Nota**: GoldenGate e Data Guard coesistono senza conflitti. Data Guard protegge il database (copia 1:1 per DR), GoldenGate replica SCHEMi specifici verso target diversi.

---

## 7.2 Prerequisiti Database Source (RACDB su rac1)

### 7.2.1 Abilitare la Replica GoldenGate

```sql
-- === Su rac1 come oracle, connettiti al Primary ===
sqlplus / as sysdba

-- 1. Abilita il parametro GoldenGate (hidden parameter)
--    Questo dice a Oracle di permettere a GoldenGate di registrarsi
--    come consumer dei redo log tramite LogMiner.
--    Senza questo, l'Integrated Extract fallisce con errore.
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
-- ^^^ SID='*' = vale per TUTTE le istanze RAC (rac1 + rac2)
--     SCOPE=BOTH = modifica sia l'SPFILE (permanente) che la memoria (immediato)

-- 2. Attiva FORCE LOGGING
--    Questo forza Oracle a scrivere REDO per TUTTE le operazioni,
--    anche quelle che normalmente lo evitano (es. INSERT /*+ APPEND */).
--    Senza questo, GoldenGate perde operazioni NOLOGGING.
ALTER DATABASE FORCE LOGGING;
-- ^^^ Puoi verificare: SELECT force_logging FROM v$database;

-- 3. Attiva Supplemental Logging
--    Il supplemental log aggiunge al redo le informazioni necessarie
--    per identificare univocamente le righe modificate.
--    Senza supplemental log, GoldenGate NON può ricostruire le UPDATE/DELETE
--    perché non sa quali colonne formano la chiave primaria.
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
-- ^^^ Questo abilita il MINIMAL supplemental log: aggiunge al redo
--     le colonne della Primary Key (o la ROWID se non c'è PK).

ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
-- ^^^ Questo abilita il supplemental log COMPLETO: aggiunge al redo
--     TUTTE le colonne della riga, non solo quelle modificate.
--     È più pesante ma garantisce che il Replicat abbia sempre
--     tutti i dati necessari per ricostruire la riga target.
--     In produzione potresti usare solo (PRIMARY KEY) COLUMNS
--     per ridurre il volume di redo generato.

-- 4. Verifica tutto
SELECT force_logging,
       supplemental_log_data_min,
       supplemental_log_data_all
FROM   v$database;
```

**Output atteso:**
```
FORCE_LOGGING  SUPPLEMENTAL_LOG_DATA_MIN  SUPPLEMENTAL_LOG_DATA_ALL
-------------- ------------------------- -------------------------
YES            YES                       YES
```

---

## 7.3 Creazione Utente GoldenGate

### 7.3.1 Sul Source (RACDB — rac1)

```sql
sqlplus / as sysdba

-- 1. Crea l'utente dedicato GoldenGate
--    MAI usare SYS o SYSTEM per GoldenGate. Crea sempre un utente dedicato.
CREATE USER ggadmin IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;
-- ^^^ QUOTA UNLIMITED: GG ha bisogno di creare tabelle di checkpoint
--     nel tablespace USERS per tracciare la sua posizione nei trail.

-- 2. Grants di base
GRANT CREATE SESSION TO ggadmin;
-- ^^^ Permette a GG di connettersi al database.

GRANT RESOURCE TO ggadmin;
-- ^^^ Permette di creare tabelle (per checkpoint table).

GRANT ALTER SESSION TO ggadmin;
-- ^^^ Permette di cambiare formato data e NLS durante l'estrazione.

GRANT SELECT ANY DICTIONARY TO ggadmin;
-- ^^^ Permette a GG di leggere le viste del dizionario dati
--     (V$DATABASE, DBA_TABLES, ecc.) per la discovery degli oggetti.

GRANT SELECT ANY TABLE TO ggadmin;
-- ^^^ Permette di leggere qualsiasi tabella per l'initial load
--     e per la verifica dei dati.

GRANT FLASHBACK ANY TABLE TO ggadmin;
-- ^^^ Necessario per query SCN-consistent durante l'initial load
--     (usato da Data Pump con FLASHBACK_SCN).

GRANT EXECUTE ON DBMS_LOCK TO ggadmin;
-- ^^^ Usato internamente da GG per sincronizzazione.

-- 3. Il grant più importante: Admin Privilege di GoldenGate
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
-- ^^^ Questo singolo comando concede TUTTI i privilegi necessari
--     per l'Integrated Extract: accesso a LogMiner, V$LOGMNR_*,
--     X$ views, e la registrazione come consumer dei redo.
--     Senza questo, l'Extract non può registrarsi.
```

### 7.3.2 Sul Target Oracle (dbtarget)

```sql
sqlplus / as sysdba

CREATE USER ggadmin IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

-- Il target ha bisogno di meno privilegi del source
GRANT CREATE SESSION, RESOURCE, ALTER SESSION TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;

-- In lab concediamo DBA per semplicità.
-- In produzione: GRANT INSERT, UPDATE, DELETE solo sugli schemi replicati.
GRANT DBA TO ggadmin;

EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
```

### 7.3.3 Sul Target PostgreSQL (pghost) — Percorso B

```bash
# Su pghost come utente postgres:
sudo -u postgres psql

-- Crea utente GoldenGate
CREATE USER ggadmin WITH PASSWORD '<password>' SUPERUSER;
-- ^^^ SUPERUSER in lab per semplicità.
--     In produzione: usa solo i privilegi necessari.

-- Crea il database target
CREATE DATABASE targetdb OWNER ggadmin;

-- Connettiti al database target
\c targetdb

-- Crea le tabelle target (devono esistere PRIMA del Replicat)
-- Le tabelle devono avere la stessa struttura del source Oracle.
-- Le differenze di tipi dati (es. NUMBER → NUMERIC) si gestiscono
-- nella configurazione del Replicat con DEFGEN/SOURCECHARSET.
```

---

## 7.4 Abilitazione GoldenGate sul Target Oracle

```sql
-- Sul target Oracle (dbtarget)
sqlplus / as sysdba

ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
-- ^^^ Stesso parametro del source, necessario anche sul target
--     per permettere al Replicat Integrato di funzionare.
```

---

## 7.5 Installazione Software GoldenGate

### 7.5.1 Dove Scaricare

1. Vai su [Oracle Software Delivery Cloud](https://edelivery.oracle.com/)
2. Cerca "Oracle GoldenGate" → seleziona la piattaforma Linux x86-64
3. Scarica la versione **21.x** (compatibile con Oracle 19c)
4. Per PostgreSQL, scarica anche **GoldenGate for Big Data 21.x**

### 7.5.2 Installazione sul Source (rac1)

```bash
# === Come utente oracle su rac1 ===

# 1. Crea la directory di installazione
mkdir -p /u01/app/goldengate
# ^^^ Scegliamo /u01/app/goldengate come OGG_HOME
#     Tienila separata da ORACLE_HOME per chiarezza.

# 2. Estrai il software
cd /u01/app/goldengate
unzip /tmp/fbo_ggs_Linux_x64_Oracle_shiphome.zip
# ^^^ Il file ZIP contiene un installer OUI (Oracle Universal Installer)
#     o uno ZIP diretto a seconda della versione scaricata.

# Per installazione da ZIP diretto (versioni recenti):
cd /u01/app/goldengate
unzip /tmp/ggs_Linux_x64_Oracle_21c.zip -d ogg
# ^^^ Crea la directory "ogg" con tutti i binari GoldenGate.

# Per installazione con runInstaller (versioni con OUI):
cd /u01/app/goldengate/fbo_ggs_Linux_x64_Oracle_shiphome/Disk1
./runInstaller
# ^^^ Seguire il wizard: scegliere "Oracle GoldenGate for Oracle Database 21c"
#     Software Home: /u01/app/goldengate/ogg
#     Database Location: /u01/app/oracle/product/19.0.0/dbhome_1

# 3. Configura le variabili ambiente
cat >> /home/oracle/.bash_profile <<'EOF'
export OGG_HOME=/u01/app/goldengate/ogg
export PATH=$OGG_HOME:$PATH
export LD_LIBRARY_PATH=$OGG_HOME/lib:$ORACLE_HOME/lib:$LD_LIBRARY_PATH
EOF

source /home/oracle/.bash_profile

# 4. Verifica l'installazione
cd $OGG_HOME
./ggsci
# ^^^ Se vedi il prompt "GGSCI>" l'installazione è corretta.
# Digita EXIT per uscire.

# 5. Crea le sottodirectory di GoldenGate
./ggsci <<EOF
CREATE SUBDIRS
EXIT
EOF
```

> **Cosa fa `CREATE SUBDIRS`?** Crea 8 directory nella OGG_HOME:
> ```
> dirdat/     → Trail files (il cuore del sistema)
> dirdef/     → File di definizione tabelle (per target eterogenei)
> dirdmp/     → Dump files di GoldenGate
> dirpcs/     → File di stato dei processi
> dirrpt/     → Report e log dei processi
> dirsql/     → Script SQL usati da GG
> dirtmp/     → File temporanei
> dirchk/     → Checkpoint files (dove GG salva la sua posizione)
> ```

### 7.5.3 Installazione sul Target Oracle (dbtarget)

Ripeti gli stessi identici passi del source: estrai, imposta variabili, `CREATE SUBDIRS`.

### 7.5.4 Installazione sul Target PostgreSQL (pghost) — Percorso B

```bash
# Per PostgreSQL, usi "GoldenGate for Big Data"
# (supporta JDBC verso PostgreSQL, MySQL, Kafka, ecc.)

mkdir -p /u01/app/goldengate
cd /u01/app/goldengate
unzip /tmp/ggs_Linux_x64_BigData_21c.zip -d ogg_bd

# Variabili ambiente
export OGG_HOME=/u01/app/goldengate/ogg_bd
export PATH=$OGG_HOME:$PATH
# ^^^ NON serve LD_LIBRARY_PATH verso Oracle: usa JDBC

# Installa il driver JDBC PostgreSQL
mkdir -p $OGG_HOME/dirprm/jdbc
cp /tmp/postgresql-42.7.*.jar $OGG_HOME/dirprm/jdbc/
# ^^^ Scarica il driver da https://jdbc.postgresql.org/

cd $OGG_HOME
./ggsci <<EOF
CREATE SUBDIRS
EXIT
EOF
```

---

## 7.6 Configurazione del Manager

Il Manager è il processo supervisore. Gira su ENTRAMBI i lati (source e target).

### 7.6.1 Manager sul Source (rac1)

```bash
cd $OGG_HOME
./ggsci
```

```
GGSCI> EDIT PARAMS MGR
```

Inserisci questo contenuto (ogni riga spiegata):

```text
-- PORTA su cui il Manager ascolta connessioni dai Pump e da altri Manager
PORT 7809
-- ^^^ La porta 7809 è il default di GoldenGate.
--     Il Data Pump del source si connette alla porta 7809 del target
--     per spedire i trail. Assicurati che il firewall la permetta.

-- Range di porte dinamiche per i processi Extract/Pump
DYNAMICPORTLIST 7810-7820
-- ^^^ Quando un Extract o Pump parte, il Manager gli assegna
--     una porta da questo range per le comunicazioni.
--     Servono tante porte quanti processi contemporanei hai.

-- Auto-restart dei processi in caso di crash
AUTORESTART EXTRACT *, RETRIES 3, WAITMINUTES 5, RESETMINUTES 60
-- ^^^ Se un Extract crasha, il Manager prova a riavviarlo 3 volte,
--     aspettando 5 minuti tra un tentativo e l'altro.
--     Dopo 60 minuti, il contatore retry si resetta.
--     L'asterisco (*) significa "tutti gli Extract".

-- Pulizia automatica dei trail file vecchi
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 24
-- ^^^ Il Manager cancella i trail file che sono già stati letti
--     da TUTTI i processi che li usano (USECHECKPOINTS).
--     Mantiene almeno le ultime 24 ore di trail (MINKEEPHOURS 24)
--     come buffer di sicurezza.
```

```
GGSCI> START MGR
GGSCI> INFO MGR
```

**Output atteso:**
```
Manager is running (IP port 7809, Process ID 12345).
```

### 7.6.2 Manager sul Target Oracle (dbtarget)

Identico, cambia solo la riga `AUTORESTART`:

```text
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTORESTART REPLICAT *, RETRIES 3, WAITMINUTES 5, RESETMINUTES 60
-- ^^^ Sul target restartamo i REPLICAT, non gli Extract.
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 24
```

### 7.6.3 Manager sul Target PostgreSQL (Percorso B)

Stesso identico file parametri del target Oracle.

---

## 7.7 Configurazione Extract sul Source (rac1)

### 7.7.1 Login e Registrazione

```bash
cd $OGG_HOME
./ggsci
```

```
-- 1. Login al database come utente GoldenGate
GGSCI> DBLOGIN USERID ggadmin PASSWORD <password>
-- ^^^ GoldenGate si connette al database Oracle usando l'utente ggadmin.
--     Da questo momento, ogni comando GGSCI che tocca il database
--     usa questa sessione.

-- 2. Registra l'Extract nel database
GGSCI> REGISTER EXTRACT ext_rac DATABASE
-- ^^^ Questo comando dice a Oracle: "sto creando un consumer LogMiner
--     chiamato ext_rac che leggerà i tuoi redo log."
--     Oracle crea internamente una sessione LogMiner dedicata.
--     Puoi verificarla con: SELECT * FROM dba_goldengate_capture;

-- 3. Crea l'Extract come Integrated
GGSCI> ADD EXTRACT ext_rac, INTEGRATED TRANLOG, BEGIN NOW
-- ^^^ ADD EXTRACT: definisce un nuovo processo Extract
--     ext_rac: nome del processo (max 8 caratteri)
--     INTEGRATED TRANLOG: usa il modo integrato (LogMiner)
--     BEGIN NOW: inizia a catturare da ADESSO (SCN corrente)
--     Alternativa: BEGIN <timestamp> per partire da un momento specifico

-- 4. Assegna un trail file locale all'Extract
GGSCI> ADD EXTTRAIL ./dirdat/er, EXTRACT ext_rac, MEGABYTES 250
-- ^^^ ADD EXTTRAIL: definisce dove l'Extract scrive le operazioni catturate
--     ./dirdat/er: prefisso del trail file (genererà er000001, er000002, ...)
--     EXTRACT ext_rac: lega questo trail a quell'Extract
--     MEGABYTES 250: ogni segmento di trail sarà max 250 MB
--     Quando un segmento è pieno, se ne apre uno nuovo automaticamente.
```

### 7.7.2 File Parametri dell'Extract

```
GGSCI> EDIT PARAMS ext_rac
```

Inserisci questo contenuto:

```text
-- Nome del processo Extract (deve corrispondere a quello registrato)
EXTRACT ext_rac

-- Credenziali database per la sessione Extract
USERID ggadmin, PASSWORD <password>
-- ^^^ L'Extract usa queste credenziali per la sessione LogMiner.
--     In produzione usa un credential store criptato con:
--     USERIDALIAS ggadmin DOMAIN OGG

-- Dove scrivere il trail locale
EXTTRAIL ./dirdat/er
-- ^^^ Deve corrispondere a quello definito con ADD EXTTRAIL

-- Supplemental log: cattura tutte le colonne per le operazioni DDL/DML
LOGALLSUPCOLS
-- ^^^ Forza GG a includere nel trail TUTTE le colonne supplemental,
--     non solo quelle modificate. Ridondante con il supplemental log
--     ALL COLUMNS che abbiamo attivato a livello DB, ma è una sicurezza
--     aggiuntiva caso il supplemental venisse cambiato.

-- Formato compatto per le UPDATE: include solo le colonne modificate
UPDATERECORDFORMAT COMPACT
-- ^^^ Per le UPDATE, il trail contiene solo i valori "prima" e "dopo"
--     delle colonne effettivamente modificate, più la chiave primaria.
--     Riduce la dimensione dei trail file.

-- DDL: replica anche le operazioni DDL (CREATE TABLE, ALTER TABLE, ecc.)
DDL INCLUDE MAPPED
-- ^^^ "MAPPED" = replica DDL solo sulle tabelle che sono nella MAP.
--     Alternativa: DDL INCLUDE ALL (replica TUTTE le DDL)
--     Alternativa: DDL EXCLUDE ALL (NON replica DDL, solo DML)

-- Parametri per il LogMiner integrato
TRANLOGOPTIONS INTEGRATEDPARAMS (MAX_SGA_SIZE 256)
-- ^^^ Limita la memoria SGA usata dal LogMiner integrato a 256 MB.
--     In produzione con alto volume DML, aumenta a 512 o 1024.
--     Troppo basso = l'Extract rallenta perché deve spillare su disco.

-- Tabelle da catturare
TABLE HR.*;
TABLE APP.*;
-- ^^^ Cattura TUTTE le tabelle degli schemi HR e APP.
--     Puoi essere più granulare:
--     TABLE HR.EMPLOYEES;
--     TABLE HR.DEPARTMENTS;
--     TABLE HR.*, EXCLUDETABLE HR.AUDIT_LOG;
--     TABLE APP.ORDERS, COLS (ORDER_ID, STATUS, AMOUNT);
```

---

## 7.8 Configurazione Data Pump

Il Data Pump è un processo Extract secondario che legge il trail locale e lo spedisce al target via rete.

```
GGSCI> ADD EXTRACT pump_rac, EXTTRAILSOURCE ./dirdat/er
-- ^^^ EXTTRAILSOURCE: il Pump legge dal trail locale er000001, er000002...
--     NON legge il database! Legge solo i trail file.

GGSCI> ADD RMTTRAIL ./dirdat/rt, EXTRACT pump_rac, MEGABYTES 250
-- ^^^ RMTTRAIL: il trail REMOTO che il Pump crea sul TARGET
--     ./dirdat/rt: di fatto questo path è sul filesystem del TARGET
--     Il Pump si connette al Manager del target (porta 7809) e
--     scrive il trail lì.

GGSCI> EDIT PARAMS pump_rac
```

Contenuto:

```text
-- Tipo di processo
EXTRACT pump_rac

-- Credenziali (anche se il Pump non tocca il DB, servono per la sessione)
USERID ggadmin, PASSWORD <password>

-- Destinazione remota: il target Oracle
RMTHOST dbtarget, MGRPORT 7809
-- ^^^ RMTHOST: hostname o IP del target (deve risolvere da rac1!)
--     MGRPORT: porta del Manager sul target
--     Il Pump apre una connessione TCP verso dbtarget:7809
--     e spedisce i dati del trail.

-- Trail remoto sul target
RMTTRAIL ./dirdat/rt
-- ^^^ Corrisponde a quello definito con ADD RMTTRAIL

-- Il Pump NON modifica i dati, li passa attraverso
PASSTHRU
-- ^^^ PASSTHRU = "passa tutto così com'è, senza trasformazioni"
--     Se volessi trasformare i dati durante il trasporto,
--     potresti togliere PASSTHRU e aggiungere MAP con filtri.

-- Tabelle (devono corrispondere a quelle dell'Extract)
TABLE HR.*;
TABLE APP.*;
```

---

## 7.9 Initial Load: Caricamento Dati Iniziale

> **CRITICO**: GoldenGate NON copia i dati esistenti. Replica solo le MODIFICHE future. Prima devi caricare i dati iniziali con Data Pump (expdp/impdp).

### 7.9.1 Prendi un SCN Consistente

```sql
-- Sul source (rac1)
sqlplus / as sysdba

-- L'SCN (System Change Number) è il "numero di versione" del database.
-- Ogni transazione committata incrementa l'SCN.
-- Noi fissiamo un punto nel tempo (SCN) e facciamo l'export a quello stato.
SELECT CURRENT_SCN FROM v$database;
-- ^^^ Esempio output: 3847291
-- SALVATI QUESTO NUMERO! Lo userai per allineare l'Extract.
```

### 7.9.2 Export Consistente dal Source

```bash
# Su rac1 come oracle
expdp ggadmin/<password> \
  SCHEMAS=HR,APP \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=gg_init_%U.dmp \
  FILESIZE=2G \
  PARALLEL=4 \
  FLASHBACK_SCN=3847291
# ^^^ SCHEMAS=HR,APP: esporta solo questi 2 schemi
#     FLASHBACK_SCN=3847291: l'export è consistente a QUEL momento esatto
#     Tutti i dati esportati riflettono lo stato del database all'SCN 3847291
#     PARALLEL=4: usa 4 worker paralleli per velocizzare
#     FILESIZE=2G: ogni file dump max 2 GB (%U crea file multipli)
```

### 7.9.3 Trasferisci e Importa sul Target Oracle

```bash
# Copia i file dump sul target
scp /u01/app/oracle/admin/RACDB/dpdump/gg_init_*.dmp oracle@dbtarget:/tmp/

# Sul target (dbtarget) come oracle
impdp ggadmin/<password> \
  SCHEMAS=HR,APP \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=gg_init_%U.dmp \
  PARALLEL=4 \
  TABLE_EXISTS_ACTION=REPLACE
# ^^^ TABLE_EXISTS_ACTION=REPLACE: se le tabelle esistono già, le ricrea
#     Dopo questo comando, il target ha una copia esatta dei dati al SCN 3847291
```

### 7.9.4 Initial Load verso PostgreSQL (Percorso B)

```bash
# Per PostgreSQL, usiamo ora_migrator o un export CSV + COPY:

# Opzione 1: Con ora2pg (tool open source)
ora2pg -t TABLE -o output.sql -s HR --pg_dsn "dbi:Pg:dbname=targetdb;host=pghost" \
  -u ggadmin -w <password>

# Opzione 2: Export CSV da Oracle + COPY PostgreSQL
# Su Oracle:
sqlplus ggadmin/<password>@RACDB
SET MARKUP CSV ON
SPOOL /tmp/employees.csv
SELECT * FROM HR.EMPLOYEES;
SPOOL OFF

# Su PostgreSQL:
psql -U ggadmin -d targetdb
\COPY hr.employees FROM '/tmp/employees.csv' WITH CSV HEADER
```

### 7.9.5 Allinea l'Extract all'SCN dell'Export

```
GGSCI> DBLOGIN USERID ggadmin PASSWORD <password>

-- Rimuovi l'Extract creato con "BEGIN NOW"
GGSCI> DELETE EXTRACT ext_rac

-- Ricrealo partendo dal SCN dell'export
GGSCI> ADD EXTRACT ext_rac, INTEGRATED TRANLOG, SCN 3847291
-- ^^^ SCN 3847291: l'Extract inizia a catturare dal PUNTO ESATTO
--     dove l'export ha "fotografato" i dati.
--     Questo garantisce ZERO buchi e ZERO duplicati:
--     l'export contiene i dati FINO al SCN 3847291,
--     l'Extract cattura le modifiche DOPO il SCN 3847291.

-- Ricrea il trail (l'ADD EXTTRAIL si perde col DELETE)
GGSCI> ADD EXTTRAIL ./dirdat/er, EXTRACT ext_rac, MEGABYTES 250

-- Il file parametri è ancora lì, non serve rifarlo.
```

---

## 7.10 Configurazione Replicat — Percorso A: Target Oracle

```bash
# Sul target Oracle (dbtarget) come oracle
cd $OGG_HOME
./ggsci
```

```
-- 1. Login al database target
GGSCI> DBLOGIN USERID ggadmin PASSWORD <password>

-- 2. Crea la checkpoint table
GGSCI> ADD CHECKPOINTTABLE ggadmin.ggchkpt
-- ^^^ La checkpoint table è una tabella nel database target dove
--     il Replicat salva la sua posizione nel trail.
--     Se il Replicat crasha e riparte, legge il checkpoint per sapere
--     da dove riprendere, evitando duplicati.
--     La tabella si chiamerà: GGADMIN.GGCHKPT

-- 3. Aggiungi il Replicat
GGSCI> ADD REPLICAT rep_rac, INTEGRATED, EXTTRAIL ./dirdat/rt, CHECKPOINTTABLE ggadmin.ggchkpt
-- ^^^ INTEGRATED: usa il modo integrato (applica tramite Oracle internal)
--     EXTTRAIL ./dirdat/rt: legge dal trail remoto (scritto dal Pump)
--     CHECKPOINTTABLE: usa la tabella di checkpoint creata sopra

-- 4. Configura i parametri del Replicat
GGSCI> EDIT PARAMS rep_rac
```

Contenuto del file parametri Replicat:

```text
-- Nome del processo
REPLICAT rep_rac

-- Credenziali per il database target
USERID ggadmin, PASSWORD <password>

-- Assume che le tabelle target hanno la stessa struttura del source
ASSUMETARGETDEFS
-- ^^^ Con ASSUMETARGETDEFS, il Replicat si aspetta che le tabelle
--     target siano IDENTICHE a quelle source (stessi nomi colonne,
--     stessi tipi dati, stesso ordine).
--     Se le tabelle fossero diverse (es. target PostgreSQL),
--     dovresti usare SOURCEDEFS con un file di definizione.

-- File di scarto per le operazioni fallite
DISCARDFILE ./dirrpt/rep_rac.dsc, APPEND, MEGABYTES 100
-- ^^^ Se il Replicat non riesce ad applicare un'operazione
--     (es. constraint violation), la scrive in questo file
--     invece di fermarsi. MEGABYTES 100 = max 100 MB di scarti.
--     APPEND = aggiunge, non sovrascrive.

-- Gestione collisioni durante l'initial load
HANDLECOLLISIONS
-- ^^^ Durante la convergenza iniziale (quando Extract e import
--     si sovrappongono), ci possono essere duplicati.
--     HANDLECOLLISIONS gestisce automaticamente:
--     - INSERT duplicato → convertito in UPDATE
--     - UPDATE su riga non trovata → convertito in INSERT
--     - DELETE su riga non trovata → ignorato
--
--     ⚠️ IMPORTANTE: RIMUOVI questa riga dopo che la convergenza
--     è completata e il sistema è stabile! Altrimenti nasconde
--     errori reali di replica.

-- Mapping delle tabelle
MAP HR.*, TARGET HR.*;
MAP APP.*, TARGET APP.*;
-- ^^^ MAP source.tabella, TARGET target.tabella
--     L'asterisco mappa tutte le tabelle dello schema.
--     Puoi essere granulare:
--     MAP HR.EMPLOYEES, TARGET HR.EMPLOYEES;
--     MAP HR.DEPARTMENTS, TARGET HR.DEPARTMENTS,
--         COLMAP (USEDEFAULTS, LAST_UPDATE = @GETENV('JULIANTIMESTAMP'));
```

---

## 7.11 Configurazione Replicat — Percorso B: Target PostgreSQL

Questa sezione documenta la replica verso PostgreSQL usando GoldenGate for Big Data con connettore JDBC.

### 7.11.1 File di Definizione Tabelle (DEFGEN)

Prima devi generare un file di definizione che descrive la struttura delle tabelle Oracle. Il Replicat PostgreSQL usa questo file per mappare i tipi dati.

```bash
# Sul SOURCE (rac1), genera il file di definizione
cd $OGG_HOME
./defgen paramfile ./dirprm/defgen.prm
```

Crea prima il file parametri:
```bash
cat > $OGG_HOME/dirprm/defgen.prm <<'EOF'
-- DEFGEN: genera un file con la struttura delle tabelle Oracle
DEFSFILE ./dirdef/oracle_defs.def
USERID ggadmin, PASSWORD <password>
TABLE HR.*;
TABLE APP.*;
EOF
```

```bash
# Esegui
cd $OGG_HOME
./defgen paramfile ./dirprm/defgen.prm
# ^^^ Genera il file ./dirdef/oracle_defs.def
#     Contiene la definizione di ogni colonna, tipo dati, lunghezza, nullable.

# Copia il file di definizione sul target PostgreSQL
scp $OGG_HOME/dirdef/oracle_defs.def oracle@pghost:/u01/app/goldengate/ogg_bd/dirdef/
```

### 7.11.2 Configurazione JDBC Properties

```bash
# Sul target PostgreSQL (pghost)
cat > $OGG_HOME/dirprm/pg_jdbc.properties <<'EOF'
# Driver e connessione JDBC
gg.handler.jdbc.type=jdbc
gg.handler.jdbc.driver=org.postgresql.Driver
gg.handler.jdbc.url=jdbc:postgresql://localhost:5432/targetdb
gg.handler.jdbc.userName=ggadmin
gg.handler.jdbc.password=<password>

# Classpath del driver
gg.classpath=/u01/app/goldengate/ogg_bd/dirprm/jdbc/postgresql-42.7.*.jar
EOF
```

### 7.11.3 File Parametri Replicat JDBC

```bash
cd $OGG_HOME
./ggsci

GGSCI> ADD REPLICAT rep_pg, EXTTRAIL ./dirdat/rt
GGSCI> EDIT PARAMS rep_pg
```

```text
REPLICAT rep_pg

-- Sorgente dei dati: file di definizione Oracle
SOURCEDEFS ./dirdef/oracle_defs.def
-- ^^^ Poiché Oracle e PostgreSQL hanno tipi dati diversi,
--     usiamo SOURCEDEFS (invece di ASSUMETARGETDEFS)
--     per dire al Replicat come interpretare i dati Oracle.

-- Handler JDBC per PostgreSQL
TARGETDB LIBFILE libggjava.so SET property=./dirprm/pg_jdbc.properties
-- ^^^ TARGETDB LIBFILE: dice al Replicat di usare il connettore Java
--     libggjava.so: libreria Java di GoldenGate
--     SET property: punta al file JDBC di configurazione

-- Gestione errori
DISCARDFILE ./dirrpt/rep_pg.dsc, APPEND, MEGABYTES 100
HANDLECOLLISIONS

-- Mapping tabelle
-- ⚠️ PostgreSQL usa lowercase per default!
MAP HR.*, TARGET hr.*;
MAP APP.*, TARGET app.*;
-- ^^^ Oracle usa UPPERCASE per default (HR.EMPLOYEES),
--     PostgreSQL usa lowercase (hr.employees).
--     Questo mapping gestisce la conversione.
```

### 7.11.4 Mapping Tipi Dati Oracle → PostgreSQL

| Oracle | PostgreSQL | Note |
|--------|-----------|------|
| `NUMBER(p,s)` | `NUMERIC(p,s)` | Conversione diretta |
| `NUMBER` (no scale) | `NUMERIC` o `BIGINT` | Dipende dal range |
| `VARCHAR2(n)` | `VARCHAR(n)` | Identico |
| `DATE` | `TIMESTAMP` | Oracle DATE include l'ora! |
| `TIMESTAMP` | `TIMESTAMP` | Identico |
| `CLOB` | `TEXT` | Conversione automatica |
| `BLOB` | `BYTEA` | Conversione automatica |
| `RAW(n)` | `BYTEA` | Conversione automatica |

---

## 7.12 Ordine di Avvio e Verifica

L'ordine è CRITICO. Se avvii i processi nell'ordine sbagliato, perdi dati.

```
ORDINE CORRETTO:
═══════════════════════════════════════════════════
1. Manager SOURCE  (rac1)         → supervisore
2. Manager TARGET  (dbtarget)     → supervisore
3. Extract         (rac1)         → inizia a catturare
4. Data Pump       (rac1)         → inizia a spedire
5. Replicat        (dbtarget)     → inizia ad applicare

ORDINE DI STOP (inverso):
═══════════════════════════════════════════════════
1. Replicat        (dbtarget)     → smette di applicare
2. Data Pump       (rac1)         → smette di spedire
3. Extract         (rac1)         → smette di catturare
4. Manager TARGET  (dbtarget)     → ultimo
5. Manager SOURCE  (rac1)         → ultimo
```

```bash
# === Sul SOURCE (rac1) ===
cd $OGG_HOME && ./ggsci

GGSCI> START MGR
GGSCI> INFO MGR
# Manager is running (IP port 7809)

GGSCI> START EXTRACT ext_rac
GGSCI> START EXTRACT pump_rac

# Aspetta 10 secondi, poi verifica
GGSCI> INFO ALL
```

```bash
# === Sul TARGET (dbtarget) ===
cd $OGG_HOME && ./ggsci

GGSCI> START MGR
GGSCI> START REPLICAT rep_rac   # (o rep_pg per PostgreSQL)

GGSCI> INFO ALL
```

**Output atteso (source):**
```
Program     Status      Group       Lag at Chkpt  Time Since Chkpt
MANAGER     RUNNING
EXTRACT     RUNNING     EXT_RAC     00:00:01      00:00:03
EXTRACT     RUNNING     PUMP_RAC    00:00:00      00:00:02
```

**Output atteso (target):**
```
Program     Status      Group       Lag at Chkpt  Time Since Chkpt
MANAGER     RUNNING
REPLICAT    RUNNING     REP_RAC     00:00:02      00:00:04
```

---

## 7.13 Verifica Lag e Statistiche

```
-- Sul source
GGSCI> LAG EXTRACT ext_rac
-- Output: "00:00:01 (updated 00:00:03 ago)"
-- ^^^ Il primo numero è il lag: quanto "indietro" è l'Extract
--     rispetto al redo corrente. 1 secondo = perfetto.

GGSCI> STATS EXTRACT ext_rac, TOTAL
-- Mostra quante operazioni INSERT/UPDATE/DELETE sono state catturate

GGSCI> STATS EXTRACT pump_rac, TOTAL
-- Mostra quante operazioni sono state trasportate al target

-- Sul target
GGSCI> LAG REPLICAT rep_rac
-- Output: "00:00:02 (updated 00:00:04 ago)"
-- ^^^ 2 secondi di lag = i dati arrivano quasi in tempo reale

GGSCI> STATS REPLICAT rep_rac, TOTAL
-- Mostra quante operazioni INSERT/UPDATE/DELETE sono state applicate
```

---

## 7.14 Test Pratici DML

### 7.14.1 Test INSERT + UPDATE + DELETE

```sql
-- Sul SOURCE (rac1) come oracle
sqlplus ggadmin/<password>@RACDB

-- INSERT
INSERT INTO HR.REGIONS (REGION_ID, REGION_NAME) VALUES (500, 'GG_TEST_REGION');
COMMIT;

-- UPDATE
UPDATE HR.REGIONS SET REGION_NAME='GG_UPDATED' WHERE REGION_ID=500;
COMMIT;

-- DELETE
DELETE FROM HR.REGIONS WHERE REGION_ID=500;
COMMIT;
```

```sql
-- Sul TARGET (dbtarget) — dopo pochi secondi
sqlplus ggadmin/<password>@dbtarget

-- Verifica che la riga 500 NON esista (è stata inserita e poi cancellata)
SELECT * FROM HR.REGIONS WHERE REGION_ID = 500;
-- no rows selected ← CORRETTO! La DELETE è stata replicata.

-- Verifica le statistiche sul Replicat
-- Torna in ggsci sul target:
-- GGSCI> STATS REPLICAT rep_rac, LATEST
-- Dovresti vedere: 1 INSERT, 1 UPDATE, 1 DELETE
```

### 7.14.2 Test Bulk (Stress)

```sql
-- Sul SOURCE
sqlplus ggadmin/<password>@RACDB

CREATE TABLE HR.GG_STRESS_TEST (
    id NUMBER PRIMARY KEY,
    payload VARCHAR2(200),
    ts TIMESTAMP DEFAULT SYSTIMESTAMP
);

BEGIN
    FOR i IN 1..10000 LOOP
        INSERT INTO HR.GG_STRESS_TEST VALUES (i, 'Row ' || i, SYSTIMESTAMP);
    END LOOP;
    COMMIT;
END;
/
```

```sql
-- Sul TARGET — aspetta 30-60 secondi
SELECT COUNT(*) FROM HR.GG_STRESS_TEST;
-- Output atteso: 10000
-- Se è meno, aspetta un po' e ricontrolla. Se LAG è basso, sono in transito.
```

### 7.14.3 Test DDL (se abilitato)

```sql
-- Sul SOURCE
ALTER TABLE HR.GG_STRESS_TEST ADD (extra_col VARCHAR2(50));
INSERT INTO HR.GG_STRESS_TEST (id, payload, ts, extra_col)
VALUES (99999, 'DDL test', SYSTIMESTAMP, 'new_column_value');
COMMIT;

-- Sul TARGET — verifica che la colonna esista
DESC HR.GG_STRESS_TEST;
SELECT extra_col FROM HR.GG_STRESS_TEST WHERE id = 99999;
```

### 7.14.4 Pulizia dopo i test

```sql
-- Sul SOURCE (si replicherà automaticamente sul target)
DROP TABLE HR.GG_STRESS_TEST PURGE;
```

---

## 7.15 Rimozione di HANDLECOLLISIONS (Post-Convergenza)

> [!WARNING]
> **Dopo che l'initial load è completato e il sistema è stabile (lag < 5 secondi, nessun errore nel discard file), DEVI rimuovere HANDLECOLLISIONS!**
> Se lo lasci attivo, il Replicat nasconderà errori reali.

```
-- Sul target
GGSCI> STOP REPLICAT rep_rac

GGSCI> EDIT PARAMS rep_rac
-- Rimuovi la riga: HANDLECOLLISIONS

GGSCI> START REPLICAT rep_rac
```

---

## 7.16 Monitoring e Troubleshooting

### 7.16.1 Comandi Diagnostici Essenziali

```
-- Stato di tutti i processi
GGSCI> INFO ALL

-- Dettaglio di un singolo processo
GGSCI> INFO EXTRACT ext_rac, DETAIL

-- Trail files esistenti
GGSCI> INFO EXTTRAIL ./dirdat/er, DETAIL

-- Visualizzare il report/log di un processo
GGSCI> VIEW REPORT ext_rac
-- ^^^ Mostra l'ultimo report con statistiche, errori, warning.
--     I report sono in ./dirrpt/ext_rac.rpt

-- Dump di un trail file (per debug avanzato)
./logdump
LOGDUMP> OPEN ./dirdat/er000001
LOGDUMP> GHDR ON
LOGDUMP> NEXT
-- ^^^ Mostra ogni operazione nel trail: tabella, tipo (I/U/D), colonne.
```

### 7.16.2 Problemi Comuni e Soluzioni

| Problema | Causa | Soluzione |
|----------|-------|-----------|
| Extract `ABENDED` | Supplemental log mancante | `ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;` |
| Extract `ABENDED` | `enable_goldengate_replication` non attivo | `ALTER SYSTEM SET enable_goldengate_replication=TRUE;` |
| Replicat `ABENDED` | Tabella non esiste sul target | Crea la tabella con lo stesso DDL del source |
| Replicat `ABENDED` | Primary Key violation (duplicato) | Attiva `HANDLECOLLISIONS` temporaneamente |
| Lag alto | Rete lenta | Verifica banda con `iperf3` tra source e target |
| Lag alto | Target lento | Aumenta `BATCHSQL` nel Replicat |
| `ORA-12514` | Service non registrato | Verifica `lsnrctl status` e `tnsnames.ora` |
| `ORA-01017` | Password errata | Usa `ALTER USER ggadmin IDENTIFIED BY <password>;` |
| Trail pieno | Pump fermo | `START EXTRACT pump_rac` e verifica rete |
| Trail pieno | Manager non pulisce | Verifica `PURGEOLDEXTRACTS` nel param MGR |

### 7.16.3 Dove Trovare i Log

```bash
# Report dei processi
cat $OGG_HOME/dirrpt/ext_rac.rpt    # Extract
cat $OGG_HOME/dirrpt/pump_rac.rpt   # Data Pump
cat $OGG_HOME/dirrpt/rep_rac.rpt    # Replicat

# File di scarto (operazioni fallite)
cat $OGG_HOME/dirrpt/rep_rac.dsc    # Se vuoto = nessun errore

# Log del Manager
cat $OGG_HOME/dirrpt/MGR.rpt
```

---

## 7.17 Manutenzione: Pulizia e Best Practice

### Pulizia Trail Manuale

```
GGSCI> PURGE EXTTRAIL ./dirdat/er
-- ^^^ Cancella i trail che sono già stati letti da tutti i consumer.
--     Normalmente il Manager lo fa automaticamente (PURGEOLDEXTRACTS),
--     ma puoi forzarlo manualmente se lo spazio è critico.
```

### Backup della Configurazione GoldenGate

```bash
# Backup di tutti i file di configurazione
tar czf /tmp/ogg_config_backup_$(date +%Y%m%d).tar.gz \
    $OGG_HOME/dirprm/ \
    $OGG_HOME/dirdef/ \
    $OGG_HOME/dirchk/
# ^^^ Salva: parametri dei processi, definizioni tabelle, checkpoint files.
#     NON serve salvare dirdat/ (i trail sono transitori).
```

---

## 7.18 Criteri di Successo Fase 7

| Criterio | Verifica | ✅/❌ |
|----------|----------|-------|
| Source primary stabile | `v$database`: `READ WRITE`, `PRIMARY` | |
| Target raggiungibile | `ping dbtarget` + `nc -vz dbtarget 7809` | |
| Initial load completato | `SELECT COUNT(*)` identico su source e target | |
| Extract `RUNNING` | `GGSCI> INFO EXTRACT ext_rac` | |
| Pump `RUNNING` | `GGSCI> INFO EXTRACT pump_rac` | |
| Replicat `RUNNING` | `GGSCI> INFO REPLICAT rep_rac` | |
| Lag < 10 secondi | `GGSCI> LAG EXTRACT` + `LAG REPLICAT` | |
| INSERT replicato | Test INSERT → visibile sul target | |
| UPDATE replicato | Test UPDATE → modifiche sul target | |
| DELETE replicato | Test DELETE → riga cancellata sul target | |
| Stress test OK | 10.000 righe → COUNT identico | |
| `HANDLECOLLISIONS` rimosso | Verifica param Replicat | |
| Data Guard ancora sano | `dgmgrl SHOW CONFIGURATION`: `SUCCESS` | |

---

## 7.19 Fonti Oracle Ufficiali

- GoldenGate 21c Installing: https://docs.oracle.com/en/middleware/goldengate/core/21.3/installing/
- GoldenGate 21c Administering: https://docs.oracle.com/en/middleware/goldengate/core/21.3/coredoc/
- GoldenGate for Big Data (JDBC/PostgreSQL): https://docs.oracle.com/en/middleware/goldengate/big-data/21.1/gadbd/
- Integrated Extract: https://docs.oracle.com/en/middleware/goldengate/core/21.3/coredoc/extract-integrated-mode.html
- Supplemental Logging: https://docs.oracle.com/en/middleware/goldengate/core/21.3/coredoc/configuring-oracle-goldengate-database.html
- DEFGEN utility: https://docs.oracle.com/en/middleware/goldengate/core/21.3/gclir/defgen.html

---

**→ Prossimo: [FASE 8: Test di Verifica (Data Guard + RMAN + EM + GoldenGate)](./GUIDA_FASE8_TEST_VERIFICA.md)**
