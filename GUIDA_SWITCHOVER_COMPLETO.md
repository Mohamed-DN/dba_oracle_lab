# Guida Completa: Switchover Data Guard (Passo per Passo)

> Lo switchover è un'operazione **pianificata** che inverte i ruoli tra Primary e Standby con **zero data loss**. È usato per manutenzione, patching, o test DR.

---

## Cosa Succede durante uno Switchover

```
PRIMA dello Switchover:
═══════════════════════
┌─────────────────┐      Redo Shipping      ┌─────────────────┐
│  RAC PRIMARY    │ ───────────────────────→ │  RAC STANDBY    │
│  RACDB          │                          │  RACDB_STBY     │
│  OPEN (R/W)     │                          │  MOUNT o ADG    │
│  ┌────┐ ┌────┐  │                          │  ┌────┐ ┌────┐  │
│  │DB1 │ │DB2 │  │                          │  │DB1 │ │DB2 │  │
│  └────┘ └────┘  │                          │  └────┘ └────┘  │
│  rac1    rac2   │                          │ stby1   stby2   │
└─────────────────┘                          └─────────────────┘
       CLIENTS ──→ si connettono qui


DURANTE lo Switchover (~30-60 secondi):
═══════════════════════════════════════
1. DGMGRL chiude il Primary (flush redo finale)
2. Il Primary diventa Standby
3. Lo Standby riceve l'ultimo redo e lo applica
4. Lo Standby diventa Primary
5. Si aprono i nuovi ruoli
   ⚠️ I client vengono disconnessi per ~30-60 secondi!


DOPO lo Switchover:
═══════════════════
┌─────────────────┐      Redo Shipping      ┌─────────────────┐
│  RAC STANDBY    │ ←─────────────────────── │  RAC PRIMARY    │
│  RACDB          │                          │  RACDB_STBY     │
│  MOUNT (standby)│                          │  OPEN (R/W)     │
│  ┌────┐ ┌────┐  │                          │  ┌────┐ ┌────┐  │
│  │DB1 │ │DB2 │  │                          │  │DB1 │ │DB2 │  │
│  └────┘ └────┘  │                          │  └────┘ └────┘  │
│  rac1    rac2   │                          │ stby1   stby2   │
└─────────────────┘                          └─────────────────┘
                                       CLIENTS ──→ si connettono QUI ora
```

---

## Preparazione (PRIMA di iniziare)

### 1. Verifica che Data Guard sia sano

```bash
dgmgrl sys/<password>@RACDB

SHOW CONFIGURATION;
# Configuration Status: SUCCESS  ← OBBLIGATORIO!
# Se mostra WARNING o ERROR → NON procedere, risolvi prima

SHOW DATABASE RACDB;
SHOW DATABASE RACDB_STBY;
# Entrambi: SUCCESS
```

### 2. Verifica che la sincronizzazione sia completa

```sql
-- Sul Primario
SELECT thread#, MAX(sequence#) FROM v$archived_log WHERE applied='YES' 
GROUP BY thread# ORDER BY thread#;

-- Sullo Standby
SELECT thread#, MAX(sequence#) FROM v$archived_log WHERE applied='YES' 
GROUP BY thread# ORDER BY thread#;

-- I numeri di sequenza devono corrispondere!
```

### 3. Verifica che lo switchover sia possibile

```
DGMGRL> VALIDATE DATABASE RACDB_STBY;
```

Output atteso:
```
  Ready for Switchover:  Yes       ← QUESTO È L'OK!
  
  Verify Flashback:      On
  Verify Redo Apply:     Running
  Verify Media Recovery: On
```

> ⚠️ Se mostra "Ready for Switchover: No", controlla i "Warnings" nel report e risolvili.

### 4. Snapshot VirtualBox (CRITICO!)

```bash
# Su TUTTE le macchine
VBoxManage snapshot "rac1" take "PRE-SWITCHOVER"
VBoxManage snapshot "rac2" take "PRE-SWITCHOVER"
VBoxManage snapshot "racstby1" take "PRE-SWITCHOVER"
VBoxManage snapshot "racstby2" take "PRE-SWITCHOVER"
```

---

## Esecuzione dello Switchover

### Step 1: Switchover con DGMGRL

```bash
dgmgrl sys/<password>@RACDB

# Comando singolo — DGMGRL gestisce tutto automaticamente
SWITCHOVER TO RACDB_STBY;
```

### Cosa fa DGMGRL internamente:

```
1. Verifica che tutti i redo siano stati spediti
2. Chiude il database RACDB (Primary → Standby)
   → ALTER DATABASE COMMIT TO SWITCHOVER TO STANDBY WITH SESSION SHUTDOWN
3. Monta RACDB come physical standby
4. Apre RACDB_STBY come Primary
   → ALTER DATABASE COMMIT TO SWITCHOVER TO PRIMARY
5. Avvia redo apply sul nuovo standby (RACDB)
6. Riapre il database se configurato per AUTO open
```

### Step 2: Verifica il nuovo stato

```
DGMGRL> SHOW CONFIGURATION;
```

Output atteso:
```
Configuration - dg_config
  Protection Mode: MaxPerformance
  Members:
  RACDB_STBY - Primary database     ← ERA Standby, ora è Primary!
    RACDB    - Physical standby      ← ERA Primary, ora è Standby!

Fast-Start Failover: DISABLED
Configuration Status: SUCCESS
```

### Step 3: Verifica le istanze

```bash
# Sul NUOVO Primary (racstby1)
srvctl status database -d RACDB_STBY
# Instance RACDB_STBY1 is running on node racstby1
# Instance RACDB_STBY2 is running on node racstby2

# Sul NUOVO Standby (rac1)
srvctl status database -d RACDB
# Instance RACDB1 is running on node rac1
# Instance RACDB2 is running on node rac2
```

### Step 4: Verifica che redo shipping funzioni al contrario

```sql
-- Sul NUOVO Primary (RACDB_STBY)
SELECT dest_id, status, error FROM v$archive_dest WHERE dest_id = 2;
-- STATUS = VALID → redo viene spedito al nuovo standby

-- Sul NUOVO Standby (RACDB)
SELECT process, status FROM v$managed_standby WHERE process = 'MRP0';
-- STATUS = APPLYING_LOG → redo viene applicato
```

### Step 5: Test DML sul nuovo Primary

```sql
sqlplus testdg/testdg123@RACDB_STBY

INSERT INTO test_replica VALUES (7777, 'Switchover completato!', SYSTIMESTAMP);
COMMIT;

-- Verifica sul nuovo standby
sqlplus / as sysdba @RACDB
SELECT * FROM testdg.test_replica WHERE id = 7777;
-- Deve esistere!
```

---

## Switchback (Ritorno alla Configurazione Originale)

```bash
dgmgrl sys/<password>@RACDB_STBY

# Verifica
VALIDATE DATABASE RACDB;
# Ready for Switchover: Yes

# Esegui
SWITCHOVER TO RACDB;

# Verifica
SHOW CONFIGURATION;
# RACDB è di nuovo Primary
# RACDB_STBY è di nuovo Standby
```

---

## Troubleshooting Switchover

| Problema | Causa | Soluzione |
|---|---|---|
| "Ready for Switchover: No" | Apply lag, redo gap | Aspetta che il lag scenda a 0, forza log switch |
| ORA-16467: switchover target is not in sync | Redo non applicato | `ALTER SYSTEM SWITCH LOGFILE;` sul primary, aspetta |
| Switchover stalled | Sessioni attive resistono | Aggiungi `WITH SESSION SHUTDOWN` se manuale |
| Nuovo standby non applica redo | Listener non raggiungibile | `lsnrctl status` sul nuovo standby, controlla tnsnames |
| ORA-01017 dopo switchover | Password file non sincronizzato | Copia `orapw` dal nuovo primary al nuovo standby |

---

## Quando Usare lo Switchover

| Scenario | Switchover? |
|---|---|
| Patching programmato del primario | ✅ Sì — switchover, patcha, switchback |
| Test annuale di DR | ✅ Sì — verifica che tutto funzioni |
| Migrazione verso nuovo hardware | ✅ Sì — switchover verso nuovo HW |
| Hardware failure del primario | ❌ No — usa **Failover** (vedi guida dedicata) |
| Corruzione dati sul primario | ❌ No — usa **Flashback Database** o RMAN restore |
