# Guida Completa: Failover Data Guard + Reinstate del Vecchio Primary

> Il Failover è l'operazione di **emergenza** quando il Primary è MORTO e non può essere recuperato in tempo utile. A differenza dello switchover, il failover può causare **perdita di dati** (dipende dalla protection mode).

---

## ⚠️ AVVERTENZA LAB: Snapshot VirtualBox e Test di Failover

> **DOMANDA FREQUENTE**: *"Visto che sono su VirtualBox, posso fare uno snapshot di tutte e 4 le macchine, testare il failover, e poi rimettere gli snapshot per tornare indietro velocemente?"*
> 
> 🛑 **RISPOSTA: ASSOLUTAMENTE NO! Corromperai tutto il cluster.**
> 
> **Perché?** In VirtualBox, i dischi configurati come **"Condivisibili" (Shareable)** (come i nostri `asm_crs`, `asm_data`, ecc.) sono intenzionalmente **ESCLUSI** dagli snapshot delle VM. 
> Se fai un failover (che scrive e modifica i dischi ASM condivisi) e poi ripristini le VM a uno snapshot precedente, i dischi OS delle macchine torneranno indietro nel tempo, ma i dischi ASM rimarranno nello stato futuro post-failover. Questo causerà un disallineamento fatale tra il sistema operativo/Clusterware e i dati su disco (Split Brain o OCR corruption).
> 
> ✅ **COME TESTARE IN MODO SICURO (Cold Backup Fisico):**
> Se vuoi "salvare" lo stato dell'intero scenario per poter tornare indietro senza impazzire col comando REINSTATE, devi fare un **backup fisico a freddo**:
> 1. Fallo come useresti una chiavetta USB: **Spegni completamente** le 4 VM (rac1, rac2, racstby1, racstby2).
> 2. Vai nella cartella di Windows dove tieni le macchine virtuali e in quella dei dischi virtuali (`.vdi`).
> 3. Clicca col tasto destro e **zippa/copia-incolla** l'intera cartella delle VM e l'intera cartella con tutti i dischi ASM in una directory di backup (es. `Backup_RAC_PreFailover`).
> 4. Accendi le VM, devasta tutto col failover, fai i tuoi test.
> 5. Quando hai finito, spegni le VM, **cancella** i file correnti e unzippa il tuo backup fisico al loro posto. Tornerai magicamente a 10 minuti prima.

---

## Switchover vs Failover — La Differenza Cruciale

```
╔═══════════════════════╦════════════════════════════╦════════════════════════════╗
║                       ║     SWITCHOVER             ║     FAILOVER               ║
╠═══════════════════════╬════════════════════════════╬════════════════════════════╣
║ Quando si usa?        ║ Manutenzione pianificata   ║ EMERGENZA — Primary morto! ║
║ Data loss?            ║ ZERO (sempre)              ║ Possibile (MaxPerformance) ║
║                       ║                            ║ Zero (MaxAvailability)     ║
║ Primary è attivo?     ║ Sì                         ║ NO — è crashato!           ║
║ Reversibile?          ║ Sì (switchback)            ║ Richiede REINSTATE o       ║
║                       ║                            ║ ricostruzione completa     ║
║ Tempo di downtime     ║ ~30-60 secondi             ║ ~1-5 minuti                ║
║ Comando               ║ SWITCHOVER TO ...          ║ FAILOVER TO ...            ║
╚═══════════════════════╩════════════════════════════╩════════════════════════════╝
```

---

## Scenario: Il Primary è Morto

```
┌─────────────────┐                          ┌─────────────────┐
│  RAC PRIMARY    │                          │  RAC STANDBY    │
│  RACDB          │                          │  RACDB_STBY     │
│                 │      ✕ MORTO! ✕          │  Tutti i redo   │
│  💀 💀 💀      │      Nessun redo         │  applicati fino │
│  Server rotto   │      viene spedito!      │  all'ultimo     │
│  Disco corrotto │                          │  ricevuto       │
│  Datacenter KO  │                          │                 │
└─────────────────┘                          └─────────────────┘
                                                     │
                    Il DBA deve decidere:            │
                    FAILOVER → promuovo lo           │
                    standby a Primary                ▼
                                             ┌─────────────────┐
                                             │  NUOVO PRIMARY  │
                                             │  RACDB_STBY     │
                                             │  OPEN (R/W)     │
                                             │  I client si    │
                                             │  connettono QUI │
                                             └─────────────────┘
```

---

## Fase 1: Verificare che il Primary Sia Realmente Morto

> **NON fare failover se il Primary è ancora vivo!** Se entrambi sono aperti in R/W, ottieni uno **split brain** con corruzione dati irreversibile.

```bash
# Prova a connetterti al Primary
sqlplus sys/<password>@RACDB as sysdba
# Se timeout → il Primary è probabilmente morto

# Prova SSH
ssh root@rac1
ssh root@rac2
# Se entrambi non rispondono → conferma che il Primary è down

# Controlla il DGMGRL
dgmgrl sys/<password>@RACDB_STBY
SHOW CONFIGURATION;
# Se RACDB mostra "Error" → conferma
```

---

## Fase 2: Esecuzione del Failover

### Con DGMGRL (consigliato)

```bash
dgmgrl sys/<password>@RACDB_STBY

# Verifica quanti dati si perderebbero
SHOW DATABASE RACDB_STBY;
# Apply Lag: mostra quanto redo NON è stato ancora applicato

# Failover!
FAILOVER TO RACDB_STBY;
```

### Cosa fa DGMGRL internamente:

```
1. Ferma il redo apply sullo standby
2. Applica tutti i redo ricevuti ma non ancora applicati (riduce la perdita dati)
3. Apre lo standby come Primary
   → ALTER DATABASE ACTIVATE STANDBY DATABASE;
   → oppure FAILOVER TO usando End-Of-Redo (se i redo finali sono disponibili)
4. Cambia il database_role da PHYSICAL STANDBY a PRIMARY
5. Attiva il redo logging
```

### Verifica dopo il Failover

```
DGMGRL> SHOW CONFIGURATION;
```

```
Configuration - dg_config
  Protection Mode: MaxPerformance
  Members:
  RACDB_STBY - Primary database     ← ORA È IL PRIMARY!
    RACDB    - Physical standby (disabled)  ← DISABILITATO!
                                               Non è più sincronizzato
Configuration Status: SUCCESS
```

```sql
-- Verifica sul nuovo Primary
sqlplus / as sysdba
SELECT name, database_role, open_mode FROM v$database;
-- RACDB_STBY | PRIMARY | READ WRITE

-- Testa il DML
INSERT INTO testdg.test_replica VALUES (8888, 'Post-Failover!', SYSTIMESTAMP);
COMMIT;
-- Se funziona → failover riuscito!
```

---

## Fase 3: Reinstate del Vecchio Primary (FONDAMENTALE!)

> Dopo un failover, il vecchio Primary (RACDB) è in uno stato "divergente" — i suoi redo non coincidono più con quelli del nuovo Primary. Devi farlo tornare in linea come standby.

### Opzione A: Reinstate con Flashback Database (VELOCE — pochi minuti)

> **Prerequisito**: Flashback Database deve essere stato abilitato PRIMA del crash!

```sql
-- Verifica sul vecchio Primary (se è ripartito)
sqlplus / as sysdba
SELECT flashback_on FROM v$database;
-- Se YES → puoi usare questa opzione!
```

```bash
# 1. Spegni il vecchio Primary
srvctl stop database -d RACDB

# 2. Avvia in MOUNT
sqlplus / as sysdba
STARTUP MOUNT;

# 3. Flashback al punto PRIMA del failover
# Il SCN di failover si trova nel nuovo Primary:
# SELECT to_char(standby_became_primary_scn) FROM v$database; (sul nuovo primary)
FLASHBACK DATABASE TO SCN <failover_scn>;

# 4. Converti in Standby
ALTER DATABASE CONVERT TO PHYSICAL STANDBY;

# 5. Riavvia
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
```

```bash
# 6. Reinstate con DGMGRL
dgmgrl sys/<password>@RACDB_STBY

REINSTATE DATABASE RACDB;

# 7. Verifica
SHOW CONFIGURATION;
# RACDB_STBY - Primary database
# RACDB      - Physical standby      ← Tornato come standby!
# Configuration Status: SUCCESS
```

### Opzione B: Ricostruzione Completa con RMAN Duplicate (LENTO — 30-60 min)

> Se Flashback non era abilitato o il vecchio Primary è troppo divergente.

```bash
# 1. Cancella il vecchio database
sqlplus / as sysdba
STARTUP MOUNT RESTRICT;
DROP DATABASE;

# 2. Rifai l'RMAN Duplicate (come nella Fase 3)
rman TARGET sys/<password>@RACDB_STBY AUXILIARY sys/<password>@RACDB1

DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET db_unique_name='RACDB'
    SET cluster_database='TRUE'
    SET fal_server='RACDB_STBY'
  NOFILENAMECHECK;
```

```bash
# 3. Registra nel DGMGRL
dgmgrl sys/<password>@RACDB_STBY

ENABLE DATABASE RACDB;

SHOW CONFIGURATION;
# SUCCESS → Reinstate completato!
```

---

## Opzione Avanzata: Fast-Start Failover (FSFO) — Failover AUTOMATICO

```
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│  RAC PRIMARY    │        │  RAC STANDBY    │        │   OBSERVER      │
│  RACDB          │        │  RACDB_STBY     │        │  (su dbtarget)  │
│                 │        │                 │        │                 │
│                 │◄══════►│                 │◄══════►│  Monitora lo    │
│                 │  DG    │                 │        │  stato di       │
│                 │  Redo  │                 │        │  entrambi i DB  │
└─────────────────┘        └─────────────────┘        │                 │
                                                      │  Se Primary     │
                                                      │  muore →        │
                                                      │  FAILOVER       │
                                                      │  AUTOMATICO!    │
                                                      └─────────────────┘
```

```bash
dgmgrl sys/<password>@RACDB

# Configura FSFO
ENABLE FAST_START FAILOVER;

# Avvia l'Observer (su una terza macchina, es. dbtarget)
dgmgrl sys/<password>@RACDB
START OBSERVER;
# L'observer gira in foreground — mettilo in un screen/tmux!
```

> **FSFO**: Se il Primary non risponde per `FastStartFailoverThreshold` secondi (default 30), l'Observer ordina automaticamente il failover allo standby. **Zero intervento umano!**

---

## Diagramma Decisionale

```
Il Primary è down?
        │
        ├── NO ────→ È manutenzione pianificata?
        │                    │
        │                    ├── SÌ → SWITCHOVER (→ vedi guida switchover)
        │                    │
        │                    └── NO → Non fare niente
        │
        └── SÌ ────→ Riesci a riavviarlo in < 5 minuti?
                         │
                         ├── SÌ → Riavvia e aspetta il recovery automatico
                         │
                         └── NO → FAILOVER!
                                    │
                                    └── Dopo → Vecchio Primary è ripartito?
                                                  │
                                                  ├── SÌ → Flashback attivo?
                                                  │            │
                                                  │            ├── SÌ → REINSTATE
                                                  │            │
                                                  │            └── NO → RMAN DUPLICATE
                                                  │
                                                  └── NO → Ricostruisci il server,
                                                            poi RMAN DUPLICATE
```
