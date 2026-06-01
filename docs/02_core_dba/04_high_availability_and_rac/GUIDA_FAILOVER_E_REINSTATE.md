# Guida Completa: Failover Data Guard + Reinstate del Vecchio Primary

> [!NOTE]
> **DOCUMENTI CORRELATI - ALTA AFFIDABILITÀ, RAC E DATA GUARD (SCEGLI QUELLO PIÙ ADATTO):**
> - **Procedure di Produzione (Non-CDB)**:
>   - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
>   - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).
> - **Guide di Laboratorio (RAC 19c Multi-Tenant/CDB)**:
>   - **Preparazione e Creazione Standby (Fase 3)**: [GUIDA_FASE3_RAC_STANDBY.md](./GUIDA_FASE3_RAC_STANDBY.md) (RMAN duplicate active database).
>   - **Configurazione Broker DGMGRL (Fase 4)**: [GUIDA_FASE4_DATAGUARD_DGMGRL.md](./GUIDA_FASE4_DATAGUARD_DGMGRL.md) (creazione e ottimizzazione broker).
>   - **Manuale Switchover Completo**: [GUIDA_SWITCHOVER_COMPLETO.md](./GUIDA_SWITCHOVER_COMPLETO.md) (passaggi sicuri di switchover).
>   - **Manuale Failover & Reinstate (questa guida)**: [GUIDA_FAILOVER_E_REINSTATE.md](./GUIDA_FAILOVER_E_REINSTATE.md) (gestione dei disastri e ripristino).
> - **Cheat Sheet Operativi (Pronto Intervento)**:
>   - **DGMGRL (Broker)**: [CS_DGMGRL.md](../../01_operations/01_cheat_sheets/CS_DGMGRL.md) (lag, switchover rapido, comandi broker).
>   - **SRVCTL & CRSCTL**: [CS_SRVCTL_CRSCTL.md](../../01_operations/01_cheat_sheets/CS_SRVCTL_CRSCTL.md) (gestione risorse cluster RAC e Grid).
>   - **ASMCMD**: [CS_ASMCMD.md](../../01_operations/01_cheat_sheets/CS_ASMCMD.md) (gestione storage ASM).
>   - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](../../01_operations/01_cheat_sheets/CS_MASTER_DBA.md) (tutti i comandi consolidati).

> Il Failover è l'operazione di **emergenza** quando il Primary è MORTO e non può essere recuperato in tempo utile. A differenza dello switchover, il failover può causare **perdita di dati** (dipende dalla protection mode).

---

## Obiettivo

Gestire un failover manuale di emergenza e il successivo reinstate. Per il failover
automatico usa la [Fase 4B: Observer Server e FSFO](./GUIDA_FASE4B_FSFO_OBSERVER.md).

## Procedura Operativa

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
> 3. Copia l'intera cartella delle VM e tutti i dischi ASM in una directory di backup verificata.
> 4. Accendi le VM, esegui il drill di failover e raccogli evidenze.
> 5. Per il rollback spegni tutte le VM e ripristina l'intero set in modo
>    consistente, seguendo una checklist e conservando una copia dello stato
>    post-test fino alla validazione.

---

## Switchover vs Failover — La Differenza Cruciale

```
+-----------------------+----------------------------+----------------------------+
|                       |     SWITCHOVER             |     FAILOVER               |
+-----------------------+----------------------------+----------------------------+
| Quando si usa?        | Manutenzione pianificata   | EMERGENZA — Primary morto! |
| Data loss?            | ZERO (sempre)              | Possibile (MaxPerformance) |
|                       |                            | Zero (MaxAvailability)     |
| Primary è attivo?     | Sì                         | NO — è crashato!           |
| Reversibile?          | Sì (switchback)            | Richiede REINSTATE o       |
|                       |                            | ricostruzione completa     |
| Tempo di downtime     | ~30-60 secondi             | ~1-5 minuti                |
| Comando               | SWITCHOVER TO ...          | FAILOVER TO ...            |
+-----------------------+----------------------------+----------------------------+
```

---

## Scenario: Il Primary è Morto

```
+-----------------+                          +-----------------+
|  RAC PRIMARY    |                          |  RAC STANDBY    |
|  RACDB          |                          |  RACDB_STBY     |
|                 |      ✕ MORTO! ✕          |  Tutti i redo   |
|  💀 💀 💀      |      Nessun redo         |  applicati fino |
|  Server rotto   |      viene spedito!      |  all'ultimo     |
|  Disco corrotto |                          |  ricevuto       |
|  Datacenter KO  |                          |                 |
+-----------------+                          +-----------------+
                                                     |
                    Il DBA deve decidere:            |
                    FAILOVER → promuovo lo           |
                    standby a Primary                v
                                             +-----------------+
                                             |  NUOVO PRIMARY  |
                                             |  RACDB_STBY     |
                                             |  OPEN (R/W)     |
                                             |  I client si    |
                                             |  connettono QUI |
                                             +-----------------+
```

---

## Fase 1: Verificare che il Primary Sia Realmente Morto

> **NON fare failover se il Primary è ancora vivo!** Se entrambi sono aperti in R/W, ottieni uno **split brain** con corruzione dati irreversibile.

Prima della promozione registra nel ticket il fencing applicato al vecchio
primary: isolamento rete, storage o alimentazione secondo la topologia del lab.
Un timeout SSH non basta. Il failover e' autorizzabile solo quando il vecchio
primary non puo' accettare traffico o tornare online senza controllo.

```bash
# Prova a connetterti al Primary
sqlplus /@RACDB as sysdba
# Se timeout → il Primary è probabilmente morto

# Prova SSH
ssh root@rac1
ssh root@rac2
# Se entrambi non rispondono → conferma che il Primary è down

# Controlla il DGMGRL
dgmgrl /@RACDB_STBY
SHOW CONFIGURATION;
# Se RACDB mostra "Error" → conferma
```

---

## Fase 2: Esecuzione del Failover

Gate obbligatorio: allega evidenza del fencing e dichiara l'RPO osservato dal
lag dello standby. Senza fencing non eseguire `FAILOVER TO`.

### Con DGMGRL (consigliato)

```bash
dgmgrl /@RACDB_STBY

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
Configuration - DR_RACDB_CONF
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
dgmgrl /@RACDB_STBY

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
# 1. Solo con change distruttivo approvato: ricrea il vecchio database.
#    Non eseguire DROP DATABASE come primo tentativo di reinstate.
sqlplus / as sysdba
STARTUP MOUNT RESTRICT;
DROP DATABASE;

# 2. Rifai l'RMAN Duplicate (come nella Fase 3)
rman TARGET /@RACDB_STBY AUXILIARY /@RACDB1

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
dgmgrl /@RACDB_STBY

ENABLE DATABASE RACDB;

SHOW CONFIGURATION;
# SUCCESS → Reinstate completato!
```

---

## Opzione Avanzata: Fast-Start Failover (FSFO)

La configurazione operativa di FSFO è centralizzata nella
[Fase 4B: Observer Server e FSFO](./GUIDA_FASE4B_FSFO_OBSERVER.md). La procedura usa
un host `observer1` dedicato, wallet SEPS, `ENABLE FAST_START FAILOVER OBSERVE ONLY`
e `VALIDATE FAST_START FAILOVER` prima dell'attivazione.

Non usare credenziali nella command line e non ospitare l'Observer su primary,
standby o server OEM condivisi con altri ruoli critici.

---

## Diagramma Decisionale

```
Il Primary è down?
        |
        +-- NO ----→ È manutenzione pianificata?
        |                    |
        |                    +-- SÌ → SWITCHOVER (→ vedi guida switchover)
        |                    |
        |                    +-- NO → Non fare niente
        |
        +-- SÌ ----→ Riesci a riavviarlo in < 5 minuti?
                         |
                         +-- SÌ → Riavvia e aspetta il recovery automatico
                         |
                         +-- NO → FAILOVER!
                                    |
                                    +-- Dopo → Vecchio Primary è ripartito?
                                                  |
                                                  +-- SÌ → Flashback attivo?
                                                  |            |
                                                  |            +-- SÌ → REINSTATE
                                                  |            |
                                                  |            +-- NO → RMAN DUPLICATE
                                                  |
                                                  +-- NO → Ricostruisci il server,
                                                            poi RMAN DUPLICATE
```

## Validazione Finale

Dopo il reinstate verifica `SHOW CONFIGURATION`, il ruolo dei database e la ripresa
del trasporto redo. Per FSFO verifica anche `SHOW FAST_START FAILOVER` e
`SHOW OBSERVER` seguendo la Fase 4B.

## Troubleshooting Rapido

Se `REINSTATE DATABASE` non è disponibile, verifica Flashback Database. In assenza
dei flashback log necessari ricostruisci il vecchio primary con RMAN Duplicate.
