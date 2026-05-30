# Guida alla Migrazione: MAA Best Practices

<!-- RUNBOOK_NAV_START -->
## Casi piu frequenti da aprire prima
- Allineare il lab a pratiche MAA prima di produzione.
- Rivedere RMAN, Data Guard, Enterprise Manager e GoldenGate.
- Ridurre SPOF e configurazioni solo-lab.
- Preparare rollback e validazione per ogni migrazione.
- Separare cosa e accettabile in home lab da cosa serve in banca.

## Indice rapido
- [Casi piu frequenti da aprire prima](#casi-piu-frequenti-da-aprire-prima)
- [Obiettivi](#obiettivi)
- [Procedura Operativa](#procedura-operativa)
  - [1. Migrazione RMAN: Bilanciamento del Carico RAC (Fase 5)](#1-migrazione-rman-bilanciamento-del-carico-rac-fase-5)
  - [Qual era il problema della vecchia configurazione?](#qual-era-il-problema-della-vecchia-configurazione)
  - [Come applicare la Best Practice](#come-applicare-la-best-practice)
  - [2. Tuning Memoria Enterprise Manager (Fase 6)](#2-tuning-memoria-enterprise-manager-fase-6)
  - [Qual era il problema della vecchia configurazione?](#qual-era-il-problema-della-vecchia-configurazione)
  - [Come applicare la Best Practice (Memory Clamping)](#come-applicare-la-best-practice-memory-clamping)
  - [3. Aggiunta del Fast-Start Failover (Observer) (Fase 4B)](#3-aggiunta-del-fast-start-failover-observer-fase-4b)
  - [Qual era il problema della vecchia configurazione?](#qual-era-il-problema-della-vecchia-configurazione)
  - [Come applicare la Best Practice](#come-applicare-la-best-practice)
  - [4. Migrazione a GoldenGate Microservices Architecture (MA) (Fase 7)](#4-migrazione-a-goldengate-microservices-architecture-ma-fase-7)
  - [Qual era il problema della vecchia configurazione?](#qual-era-il-problema-della-vecchia-configurazione)
  - [Differenze strutturali: Classic vs MA](#differenze-strutturali-classic-vs-ma)
  - [Come migrare (Passo-Passo)](#come-migrare-passo-passo)
- [Validazione Finale](#validazione-finale)
- [Troubleshooting](#troubleshooting)
<!-- RUNBOOK_NAV_END -->

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- [08_rman_backup_status.sql](../03_scripts_pronti/08_rman_backup_status.sql) - ultimo backup, backup falliti, config RMAN, archivelog non backuppati.
- [09_dataguard_status.sql](../03_scripts_pronti/09_dataguard_status.sql) - ruolo DB, transport/apply lag, gap, MRP, switchover readiness.
- [07_performance_quick.sql](../03_scripts_pronti/07_performance_quick.sql) - top SQL, wait event, ASH real-time, piani SQL.
<!-- READY_SCRIPTS_END -->
## Obiettivi

Allineare l'infrastruttura Oracle esistente ai nuovi standard **Oracle Maximum Availability Architecture (MAA)**, migliorando il bilanciamento del carico, la stabilità della memoria, l'automazione del failover e la modernizzazione dell'architettura di replica.

## Procedura Operativa

---

### 1. Migrazione RMAN: Bilanciamento del Carico RAC (Fase 5)

### Qual era il problema della vecchia configurazione?
Negli script precedenti, eseguivamo il backup Full e Incrementale su `racstby1` (Standby Node 1) allocando due o più canali locali:
```rman
ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;
```
**Cosa fa esattamente un "canale" RMAN?** Un canale RMAN non è altro che un processo server (un thread) sul database. Se esegui il comando sopra da `racstby1`, Oracle avvierà due processi server *sull'istanza di racstby1*. Questi due processi leggeranno i dati dallo storage (ASM) e li comprimeranno usando la CPU di `racstby1`.

**Perché è un problema?**
Anche se lo storage ASM è condiviso tra `racstby1` e `racstby2`, il lavoro di I/O (la lettura attraverso l'HBA) e il lavoro di compressione (la CPU) saranno interamente a carico di `racstby1`. La CPU di `racstby1` schizzerà al 100%, la sua scheda di rete sarà saturata, mentre `racstby2` rimarrà fermo a non fare nulla. In un cluster RAC (che nasce proprio per distribuire il carico), questo è uno spreco enorme.

### Come applicare la Best Practice
Devi modificare gli script di backup (`rman_full_backup.sh` e `rman_incr_backup.sh`) per forzare RMAN a connettersi a istanze diverse del cluster. Questo "spalmerà" i processi server su più macchine fisiche.

1. Apri i tuoi script sul nodo da cui lanci il cronjob (es. `racstby1`).
2. Sostituisci i vecchi `ALLOCATE CHANNEL` con questi:

```rman
    -- Bilanciamento RAC: un canale lavora sul nodo 1, l'altro sul nodo 2
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK CONNECT 'sys/<tua_password>@RACDB1_STBY';
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK CONNECT 'sys/<tua_password>@RACDB2_STBY';
```

**Cosa succede ora dietro le quinte?**
- `ch1` aprirà un processo su `racstby1`, leggendo il 50% dei datafile e comprimendoli usando la CPU di `racstby1`.
- `ch2` aprirà una sessione di rete via TNS verso `RACDB2_STBY`, avvierà un processo su `racstby2`, leggerà l'altro 50% dei datafile e li comprimerà usando la CPU di `racstby2`.
- Entrambi scriveranno il risultato nella Fast Recovery Area (+FRA), che essendo su ASM è visibile da entrambi.
- Risultato: il backup è quasi due volte più veloce e nessun server va in sofferenza termica o di saturazione.

> [!NOTE]
> Ricordati di fare la stessa cosa per lo script del primario (`rman_primary_backup.sh`), puntando però a `RACDB1` e `RACDB2`.

---

### 2. Tuning Memoria Enterprise Manager (Fase 6)

### Qual era il problema della vecchia configurazione?
Creavamo il database di repository (EMREP) per l'Enterprise Manager (OEM) assegnandogli 2GB di RAM. Tuttavia, Oracle di default abilita l'**Automatic Memory Management (AMM)**, impostando il parametro `memory_target`.

**Il disastro dell'AMM su macchine piccole:**
AMM fonde insieme la System Global Area (SGA - cache dati e shared pool) e la Program Global Area (PGA - memoria privata per le sessioni). Se il database sente di avere bisogno di più memoria per una query pesante, l'AMM cerca di espandersi, rubando memoria al sistema operativo. 
Su un server da 8 o 16 GB, l'OEM installa un application server mastodontico: **Oracle WebLogic**. WebLogic per l'Oracle Management Service (OMS) ha bisogno di enormi heap Java (spesso 4-6 GB). 
Quando WebLogic chiede RAM al sistema operativo e contemporaneamente il database EMREP si espande per via dell'AMM, Linux esaurisce la memoria fisica e lo spazio di Swap. A quel punto interviene l'**OOM (Out Of Memory) Killer** di Linux, che spara senza pietà al processo che consuma di più, causando crash improvvisi del database o dell'OMS.

### Come applicare la Best Practice (Memory Clamping)
Dobbiamo disabilitare l'AMM e passare all'**ASMM** (Automatic Shared Memory Management), che fissa dei "tetti" (limiti rigidi) impossibili da superare.

1. Connettiti alla macchina dell'OEM come utente `oracle`.
2. Esegui questo script SQL sul database EMREP:

```sql
sqlplus / as sysdba

-- 1. Disabilita l'espansione dinamica globale (AMM)
ALTER SYSTEM SET memory_target=0 SCOPE=BOTH;
ALTER SYSTEM SET memory_max_target=0 SCOPE=BOTH;

-- 2. Fissa un tetto alla SGA. Il database gestirà dinamicamente le sue
--    strutture interne (buffer cache, shared pool) MA senza mai 
--    superare i 2GB totali concessi.
ALTER SYSTEM SET sga_target=2G SCOPE=BOTH;
ALTER SYSTEM SET sga_max_size=2G SCOPE=SPFILE;

-- 3. Applica un limite assoluto alla PGA.
--    In Oracle 12c+ è stato introdotto pga_aggregate_limit. Se le
--    sessioni cercano di allocare più di 2GB di memoria privata
--    (es. per enormi ordinamenti in memoria - ORDER BY), Oracle 
--    killerà le sessioni Oracle colpevoli con un ORA-04036, 
--    SALVANDO così il server intero dall'OOM Killer di Linux.
ALTER SYSTEM SET pga_aggregate_target=1G SCOPE=BOTH;
ALTER SYSTEM SET pga_aggregate_limit=2G SCOPE=BOTH;

-- 4. Riavvia per applicare le modifiche allo SPFILE (sga_max_size)
SHUTDOWN IMMEDIATE;
STARTUP;
```

---

### 3. Aggiunta del Fast-Start Failover (Observer) (Fase 4B)

### Qual era il problema della vecchia configurazione?
Avevamo configurato il Data Guard Broker. Se il database primario veniva spento o la macchina crashava, i dati erano al sicuro sul Physical Standby, ma il servizio si interrompeva. Il DBA doveva ricevere una notifica, svegliarsi (magari alle 3 di notte), collegarsi in VPN, aprire `dgmgrl` e digitare `FAILOVER TO RACDB_STBY`. 
Questo introduce tempi di inattività (RTO) inaccettabili in una **Maximum Availability Architecture (MAA)**.

### Come applicare la Best Practice
Serve un componente terzo: l'**Observer**. Nel lab usa la VM dedicata
`observer1.localdomain`, non il primary, lo standby o il server OEM.

La procedura completa è nella
[Fase 4B: Observer Server e FSFO](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4B_FSFO_OBSERVER.md).
Configura Oracle Client Administrator 19c, wallet SEPS, fase iniziale `OBSERVE ONLY`
e validazione Broker prima di attivare il failover automatico.

L'avvio supportato Oracle usa credenziali wallet-backed e non espone password:

```dgmgrl
START OBSERVER observer1 IN BACKGROUND
  CONNECT IDENTIFIER IS RACDB
  FILE IS '/home/oracle/admin/fsfo/observer1.dat'
  LOGFILE IS '/home/oracle/admin/fsfo/observer1.log';
```

> [!TIP]
> L'auto-reinstate richiede Flashback Database e
> `FastStartFailoverAutoReinstate=TRUE`. In assenza dei flashback log necessari,
> ricostruisci il vecchio primary con RMAN Duplicate.

---

### 4. Migrazione a GoldenGate Microservices Architecture (MA) (Fase 7)

### Qual era il problema della vecchia configurazione?
La "Classic Architecture" (basata su `ggsci`) richiedeva di fare login tramite SSH sul server del database per ogni operazione. Mancava di metriche moderne (Prometheus, Grafana), non offriva sicurezza nativa (i file viaggiavano in chiaro sulla rete) e configurare il componente `Data Pump` era controintuitivo.

### Differenze strutturali: Classic vs MA
1. **Manager vs Service Manager**: Il vecchio `MGR` è stato spacchettato in una dashboard web generale (Service Manager) e un server operativo (Admin Server).
2. **GGSCI vs Admin Server**: Non digiti più comandi in un terminale nero. Ti colleghi con il browser all'Admin Server (porta 9012) e configuri Extract e Replicat con una GUI molto intuitiva (che dietro le quinte usa API REST).
3. **Data Pump vs Distribution Server**: Nella Classic, dovevi creare un Extract secondario (il pump) e passargli il parametro `PASSTHRU`. Nella MA, il Data Pump non esiste più come entità di tipo Extract. Ora esiste il **Distribution Server**: un servizio dedicato solo al trasferimento dei trail file, che configura "percorsi" (Paths) da A a B crittografati via WSS (WebSockets Secure).

### Come migrare (Passo-Passo)

Migrare da Classic a MA non è un "aggiornamento" (non c'è un pulsante "upgrade"). Devi creare i nuovi servizi paralleli e spostare il carico.

#### Step 1: Fermare il vecchio traffico
Devi assicurarti che tutti i dati in transito vengano processati e fermare i vecchi processi `ggsci`.
```bash
# Sulla vecchia interfaccia GGSCI
GGSCI> SEND EXTRACT ext_rac, LOGEND
# Aspetta che l'Extract finisca di leggere i redo
GGSCI> STOP EXTRACT ext_rac
GGSCI> STOP EXTRACT pump_rac
GGSCI> STOP REPLICAT rep_tgt
GGSCI> STOP MGR
```

#### Step 2: Installare il software MA e creare i Deployment
Il software MA va scaricato separatamente dal portale Oracle (Oracle GoldenGate 21c Microservices).
Non sovrascrivere la vecchia cartella (es. `/u01/app/goldengate`). Installa in un path pulito (es. `/u01/app/oracle/product/ogg_ma`).

Usa il tool `oggca.sh` per generare le Web UI su specifiche porte. (Segui la [Fase 7 aggiornata](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md)).

#### Step 3: Ricostruzione via Web UI e Initial Load con Network Link
Nella vecchia guida usavamo l'utility `expdp` creando file di dump enormi sul disco, trasferendoli con `scp` e importandoli con `impdp`. 

**La nuova Best Practice (Zero Downtime Initial Load):**
Ora usiamo **Data Pump via Network Link**.
1. Si crea un `DATABASE LINK` dal target al source.
2. Si trova l'SCN corrente del Source: `SELECT current_scn FROM v$database@source_db_link;` (es. 1234567).
3. Si lancia l'`impdp` sul target specificando `NETWORK_LINK=... FLASHBACK_SCN=1234567`.

**Cosa fa Oracle?**
Senza scrivere un solo kilobyte su file di dump, il database target "risucchia" i dati tramite la rete direttamente dalla memoria del database source. I dati che arrivano sono coerenti *esattamente* al momento in cui l'SCN era 1234567. 
Nel frattempo, il tuo Extract MA su GoldenGate cattura tutte le modifiche.
Quando il Data Pump finisce, avvii il Replicat MA dicendogli: `START REPLICAT rep_tgt, AFTERCSN 1234567`. Il Replicat applicherà solo le differenze accumulate dopo quel preciso momento. Niente dati persi, niente duplicati.

Segui la [Fase 7 aggiornata](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md) per i dettagli operativi per implementare questo workflow.

## Validazione Finale

1. Verificare che i canali RMAN siano distribuiti sui nodi del cluster tramite `v$rman_output`.
2. Confermare che i limiti di memoria SGA/PGA siano rispettati monitorando `v$sga` e `v$pgastat`.
3. Testare il failover automatico simulando un crash controllato del primario.
4. Verificare il flusso dei dati in GoldenGate tramite la Web UI dell'Admin Server.

## Troubleshooting

1. **Observer non connette**: Verificare la risoluzione del nome TNS dal server dell'Observer verso Primary e Standby.
2. **ORA-04036 (PGA limit exceeded)**: Se accade spesso, riconsiderare il valore di `pga_aggregate_limit` in base al numero di sessioni concorrenti previste.
3. **Distribuzione RMAN sbilanciata**: Assicurarsi che i nodi RAC abbiano la stessa potenza di calcolo e che la rete verso lo storage sia bilanciata.
