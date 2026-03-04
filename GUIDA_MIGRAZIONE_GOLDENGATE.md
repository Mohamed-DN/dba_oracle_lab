# Guida: Migrazione Database con Oracle GoldenGate (Zero Downtime)

> GoldenGate permette di migrare un database da un sistema all'altro con **zero o quasi-zero downtime**. Questo è il metodo usato nelle grandi aziende per migrare database da un data center a un altro, da on-premise a cloud, o tra versioni diverse di Oracle.

---

## Architettura della Migrazione

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    MIGRAZIONE CON GOLDENGATE                          ║
║                                                                       ║
║  FASE 1: Initial Load (copia completa dei dati)                      ║
║  ┌──────────────┐              ┌──────────────┐                      ║
║  │  SOURCE DB   │  Data Pump   │  TARGET DB   │                      ║
║  │  (vecchio)   │═══expdp════►│  (nuovo)     │                      ║
║  │              │   impdp      │              │                      ║
║  └──────────────┘              └──────────────┘                      ║
║                                                                       ║
║  FASE 2: Sincronizzazione continua (CDC — Change Data Capture)       ║
║  ┌──────────────┐              ┌──────────────┐                      ║
║  │  SOURCE DB   │   GG Extract │  TARGET DB   │                      ║
║  │  (vecchio)   │═══════════►│  (nuovo)     │                      ║
║  │  ancora attivo│   GG Repli- │  sincronizzato│                      ║
║  │  con utenti!  │   cat       │  in tempo     │                      ║
║  └──────────────┘              │  reale        │                      ║
║                                └──────────────┘                      ║
║                                                                       ║
║  FASE 3: Cutover (switch del traffico)                               ║
║  ┌──────────────┐              ┌──────────────┐                      ║
║  │  SOURCE DB   │  STOP        │  TARGET DB   │                      ║
║  │  (vecchio)   │  Extract     │  (nuovo)     │                      ║
║  │  ⛔ FERMA    │              │  ✅ ATTIVO   │                      ║
║  │  gli utenti  │              │  Gli utenti  │                      ║
║  │              │              │  si connett. │                      ║
║  └──────────────┘              │  QUI ora     │                      ║
║                                └──────────────┘                      ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

## Scenari di Migrazione Comuni

| Da | A | GoldenGate? |
|---|---|---|
| Oracle 11g → Oracle 19c | ✅ Versioni diverse | |
| Oracle on-prem → Oracle Cloud (OCI) | ✅ Cross-platform | |
| Oracle FS → Oracle ASM | ✅ Storage diverso | |
| Singolo nodo → RAC | ✅ Architettura diversa | |
| Oracle Linux → AIX/Solaris | ✅ Cross-OS | |
| Datacenter A → Datacenter B | ✅ Cross-datacenter | |
| Oracle → PostgreSQL | ⚠️ Possibile ma complesso (GG for Big Data) | |

---

## Step-by-Step: Migrazione Oracle → Oracle

### Prerequisiti

```sql
-- Su SOURCE (vecchio DB)
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
ALTER DATABASE FORCE LOGGING;

-- Crea utente GG su Source
CREATE USER ggadmin IDENTIFIED BY <password>
    DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT DBA TO ggadmin;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');

-- Su TARGET (nuovo DB)
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
-- Crea stesso utente ggadmin con stessi privilegi
```

### Step 1: Initial Load con Data Pump

```bash
# Su SOURCE: Export completo dello schema
expdp ggadmin/<password> \
    SCHEMAS=HR,FINANCE,INVENTORY \
    DIRECTORY=DATA_PUMP_DIR \
    DUMPFILE=migration_%U.dmp \
    FILESIZE=2G \
    PARALLEL=4 \
    LOGFILE=export_migration.log \
    FLASHBACK_TIME=SYSTIMESTAMP

# Annota il SCN dell'export (nel log file):
# Export done in xxx consistent at SCN 12345678
```

> **Perché `FLASHBACK_TIME=SYSTIMESTAMP`?** Garantisce che l'export sia consistente a un punto nel tempo. L'Extract GG partirà da questo SCN esatto, assicurando zero dati persi e zero duplicati.

```bash
# Trasferisci il dump file al TARGET
scp migration_*.dmp oracle@target:/u01/app/oracle/datapump/

# Su TARGET: Import
impdp ggadmin/<password> \
    SCHEMAS=HR,FINANCE,INVENTORY \
    DIRECTORY=DATA_PUMP_DIR \
    DUMPFILE=migration_%U.dmp \
    PARALLEL=4 \
    LOGFILE=import_migration.log \
    TABLE_EXISTS_ACTION=REPLACE
```

### Step 2: Configura GoldenGate Extract su Source

```bash
cd $OGG_HOME && ./ggsci

DBLOGIN USERID ggadmin PASSWORD <password>
REGISTER EXTRACT ext_migr DATABASE

ADD EXTRACT ext_migr, INTEGRATED TRANLOG, SCN 12345678
# ^^^^^^ Usa il SCN dell'export Data Pump!

ADD EXTTRAIL ./dirdat/em, EXTRACT ext_migr, MEGABYTES 200

EDIT PARAMS ext_migr
```

```
EXTRACT ext_migr
USERID ggadmin, PASSWORD <password>
EXTTRAIL ./dirdat/em
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT

TABLE HR.*;
TABLE FINANCE.*;
TABLE INVENTORY.*;
```

### Step 3: Configura Data Pump (Ship trails al Target)

```
ADD EXTRACT pump_migr, EXTTRAILSOURCE ./dirdat/em
ADD RMTTRAIL ./dirdat/rm, EXTRACT pump_migr, MEGABYTES 200

EDIT PARAMS pump_migr
```

```
EXTRACT pump_migr
USERID ggadmin, PASSWORD <password>
RMTHOST target_host, MGRPORT 7809
RMTTRAIL ./dirdat/rm

TABLE HR.*;
TABLE FINANCE.*;
TABLE INVENTORY.*;
```

### Step 4: Configura Replicat su Target

```bash
cd $OGG_HOME && ./ggsci

DBLOGIN USERID ggadmin PASSWORD <password>

ADD REPLICAT rep_migr, INTEGRATED, EXTTRAIL ./dirdat/rm

EDIT PARAMS rep_migr
```

```
REPLICAT rep_migr
USERID ggadmin, PASSWORD <password>
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_migr.dsc, APPEND, MEGABYTES 100

-- Gestione conflitti: il target vince (per safety)
MAP HR.*, TARGET HR.*, HANDLECOLLISIONS;
MAP FINANCE.*, TARGET FINANCE.*;
MAP INVENTORY.*, TARGET INVENTORY.*;
```

> **`HANDLECOLLISIONS`**: Durante l'initial load, ci possono essere righe "duplicate" (già inserite dal Data Pump ma anche catturate dall'Extract). HANDLECOLLISIONS le gestisce senza errori. **Rimuovilo dopo che la sincronizzazione è stabile!**

### Step 5: Avvia tutto (in ordine!)

```
-- Su Source
START EXTRACT ext_migr
START EXTRACT pump_migr

-- Su Target
START REPLICAT rep_migr

-- Monitora
INFO ALL
LAG EXTRACT ext_migr
LAG REPLICAT rep_migr
```

### Step 6: Attendi la sincronizzazione

```bash
# Attendi che il lag scenda a 0
GGSCI> LAG EXTRACT ext_migr
# At 2024-03-15 14:30:00 Lag 0 seconds    ← PRONTO!

GGSCI> LAG REPLICAT rep_migr
# At 2024-03-15 14:30:03 Lag 3 seconds     ← Quasi pronto

# Quando il lag è stabile a < 5 secondi per 30+ minuti → sei pronto per il cutover
```

---

## Step 7: Cutover (Il Momento Critico!)

```
TIMELINE:
─────────────────────────────────────────────────────────────────────
  T-30min: Avvisa gli utenti del downtime (breve)
  T-5min:  Verifica lag = 0
  T-0:     STOP applicazione → nessun nuovo DML su Source
  T+1min:  Aspetta che GG applichi gli ultimi record
  T+2min:  Verifica conteggi  Source == Target
  T+3min:  STOP Extract e Replicat
  T+4min:  Riconfigura la connessione dell'app → TARGET
  T+5min:  Riavvia l'applicazione sul TARGET
─────────────────────────────────────────────────────────────────────
  Downtime totale: ~5 minuti!
```

### Procedura Cutover Dettagliata

```bash
# 1. Ferma l'applicazione (nessun nuovo DML)
# (dipende dalla tua app)

# 2. Aspetta che GG finisca di applicare
GGSCI> LAG REPLICAT rep_migr
# Lag 0 seconds → PRONTO

# 3. Verifica la consistenza dei dati
```

```sql
-- Su Source
SELECT COUNT(*) FROM hr.employees;
SELECT COUNT(*) FROM hr.departments;
SELECT MAX(employee_id) FROM hr.employees;

-- Su Target (stesse query, stessi numeri?)
SELECT COUNT(*) FROM hr.employees;
SELECT COUNT(*) FROM hr.departments;
SELECT MAX(employee_id) FROM hr.employees;
```

```bash
# 4. Ferma GoldenGate
GGSCI> STOP EXTRACT ext_migr
GGSCI> STOP EXTRACT pump_migr
# Su Target:
GGSCI> STOP REPLICAT rep_migr

# 5. Rimuovi HANDLECOLLISIONS (non serve più)
# 6. Riconfigura l'app per connettersi al TARGET
# 7. Avvia l'app → Migrazione completata! 🎉
```

---

## Migrazione Bidirezionale (Fallback Safety)

Per avere un piano di rollback, configura GoldenGate anche al contrario:

```
Source ──Extract──► Target    (migrazione)
Source ◄──Replicat── Target    (fallback)
```

Se qualcosa va storto dopo il cutover, puoi riportare il traffico sul Source senza perdere i dati inseriti sul Target.

---

## Checklist Migrazione

```
PRE-MIGRAZIONE:
  □ Supplemental logging attivo
  □ Force logging attivo
  □ GG installato su Source e Target
  □ Utente ggadmin creato su entrambi
  □ Rete Source↔Target funzionante
  □ Export Data Pump completato
  □ Import Data Pump completato
  □ SCN dell'export annotato

SINCRONIZZAZIONE:
  □ Extract avviato dal SCN corretto
  □ Pump trasmette i trail
  □ Replicat applica senza errori
  □ Lag stabile < 5 secondi per 30+ minuti
  □ HANDLECOLLISIONS rimosso dopo stabilizzazione

CUTOVER:
  □ Utenti avvisati
  □ Applicazione fermata
  □ Lag = 0 confermato
  □ COUNT(*) Source == Target per tutte le tabelle
  □ GG fermato
  □ App riconfigurata per Target
  □ App riavviata e funzionante
```
