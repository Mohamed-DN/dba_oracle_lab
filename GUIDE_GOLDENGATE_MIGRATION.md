# Guide: Database Migration with Oracle GoldenGate (Zero Downtime)

> GoldenGate allows you to migrate a database from one system to another with **zero or near-zero downtime**. This is the method used in large enterprises to migrate databases from one data center to another, from on-premise to cloud, or between different versions of Oracle.

---

## Migration Architecture

```
╔═══════════════════════════════════════════════════════════════════════╗
║ MIGRATION WITH GOLDENGATE ║
║                                                                       ║
║ PHASE 1: Initial Load (complete copy of the data) ║
║  ┌──────────────┐              ┌──────────────┐                      ║
║  │  SOURCE DB   │  Data Pump   │  TARGET DB   │                      ║
║ │ (old) │═══expdp════►│ (new) │ ║
║  │              │   impdp      │              │                      ║
║  └──────────────┘              └──────────────┘                      ║
║                                                                       ║
║ PHASE 2: Continuous synchronization (CDC — Change Data Capture) ║
║  ┌──────────────┐              ┌──────────────┐                      ║
║  │  SOURCE DB   │   GG Extract │  TARGET DB   │                      ║
║ │ (old) │═══════════►│ (new) │ ║
║ │ still active│ GG Repli- │ synchronized│ ║
║ │ with users!  │ cat │ on time │ ║
║  └──────────────┘              │  reale        │                      ║
║                                └──────────────┘                      ║
║                                                                       ║
║ PHASE 3: Cutover (traffic switch) ║
║  ┌──────────────┐              ┌──────────────┐                      ║
║  │  SOURCE DB   │  STOP        │  TARGET DB   │                      ║
║ │ (old) │ Extract │ (new) │ ║
║  │  ⛔ FERMA    │              │  ✅ ATTIVO   │                      ║
║ │ users │ │ users │ ║
║  │              │              │  si connett. │                      ║
║  └──────────────┘              │  QUI ora     │                      ║
║                                └──────────────┘                      ║
╚═══════════════════════════════════════════════════════════════════════╝
```

---

## Municipal Migration Scenarios

| Da | A | GoldenGate? |
|---|---|---|
| Oracle 11g → Oracle 19c | ✅ Versioni diverse | |
| Oracle on-prem → Oracle Cloud (OCI) | ✅ Cross-platform | |
| Oracle FS → Oracle ASM | ✅ Storage diverso | |
| Single node → RAC | ✅ Architettura diversa | |
| Oracle Linux → AIX/Solaris | ✅ Cross-OS | |
| Datacenter A → Datacenter B | ✅ Cross-datacenter | |
| Oracle → PostgreSQL | ⚠️ Possibile ma complesso (GG for Big Data) | |

---

## Scenario del Repo: Locale RAC 19c -> OCI

Per il tuo lab, lo scenario piu realistico non e un generico `source -> target`, ma questo:

- `source`: RAC 19c locale
- `HA/DR`: Data Guard locale
- `capture GG`: on the local primary
- `target`: database Oracle su OCI compute
- `rete`: Restricted public IP or VPN, based on [GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md)

Documents to read before cutover:

1. [GUIDE_PHASE5_GOLDENGATE.md](./GUIDE_PHASE5_GOLDENGATE.md)
2. [GUIDE_GOLDENGATE_OCI_ARM.md](./GUIDE_GOLDENGATE_OCI_ARM.md)
3. [GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md](./GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md)

Regola importante:

- il target OCI `Always Free` va bene per imparare OCI e target Oracle;
- but truly core lab-consistent GG migration requires a target and GG version compatible with source 19c, not a confusing shortcut with `GoldenGate Free`.

---

## Step-by-Step: Oracle Migration → Oracle

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

### Step 1: Initial Load with Data Pump

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

> **Why `FLASHBACK_TIME=SYSTIMESTAMP`?** Ensures the export is consistent at a point in time. The Extract GG will start from this exact SCN, ensuring zero lost data and zero duplicates.

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

-- Conflict management: the target wins (for safety)
MAP HR.*, TARGET HR.*, HANDLECOLLISIONS;
MAP FINANCE.*, TARGET FINANCE.*;
MAP INVENTORY.*, TARGET INVENTORY.*;
```

> **`HANDLECOLLISIONS`**: During initial load, there may be "duplicated" rows (already inserted by the Data Pump but also captured by the Extract). HANDLECOLLISIONS handles them without errors. **Remove it after sync is stable!**

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
  T-30min: Warn users of downtime (short)
  T-5min: Check lag = 0
  T-0: STOP application → no new DML on Source
  T+1min:  Aspetta che GG applichi gli ultimi record
  T+2min: Check counts Source == Target
  T+3min:  STOP Extract e Replicat
  T+4min:  Riconfigura la connessione dell'app → TARGET
  T+5min: Restart the application on the TARGET
─────────────────────────────────────────────────────────────────────
  Downtime totale: ~5 minuti!
```

### Detailed Cutover Procedure

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

## Bidirectional Migration (Fallback Safety)

To have a rollback plan, configure GoldenGate also in reverse:

```
Source ──Extract──► Target (migration)
Source ◄──Replicat── Target    (fallback)
```

If something goes wrong after the cutover, you can move the traffic back to the Source without losing the data placed on the Target.

---

## Migration Checklist

```
PRE-MIGRATION:
  □ Supplemental logging attivo
  □ Force logging attivo
  □ GG installato su Source e Target
  □ ggadmin user created on both
  □ Source↔Target network working
  □ Export Data Pump completato
  □ Import Data Pump completato
  □ SCN dell'export annotato

SINCRONIZZAZIONE:
  □ Extract avviato dal SCN corretto
  □ Pump trasmette i trail
  □ Replicat applies without errors
  □ Lag stabile < 5 secondi per 30+ minuti
  □ HANDLECOLLISIONS removed after stabilization

CUTOVER:
  □ Users warned
  □ Applicazione fermata
  □ Lag = 0 confermato
  □ COUNT(*) Source == Target for all tables
  □ GG fermato
  □ App riconfigurata per Target
  □ App riavviata e funzionante
```
