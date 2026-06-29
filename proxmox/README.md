# Indice Percorso Lab: Oracle 19c RAC su Proxmox VE (OL 8.10)

Benvenuto nel percorso "Da zero a Enterprise DBA" adattato specificamente per un'infrastruttura bare-metal su **Proxmox VE** usando **Oracle Linux 8.10**. 

Questo laboratorio ti guiderà passo dopo passo nella costruzione di un intero ecosistema Oracle ad alta affidabilità (Real Application Clusters + Data Guard), simulando la complessità di una vera architettura aziendale, ma scalata per girare sul tuo home server.

---

## 🏗️ Modulo 1: Costruzione dell'Infrastruttura (Isole)

In questo modulo creiamo l'hardware virtuale, le reti isolate e prepariamo il sistema operativo. È la base su cui poggerà tutto il cluster.

* 📍 **[FASE 0: Setup delle Macchine (Proxmox VE + Dischi ASM)](./GUIDA_FASE0_SETUP_MACCHINE.md)**
  * *Pianificazione IP, Reti Linux Bridge, Creazione della VM "Golden" e configurazione storage RAW condiviso con iothread e NUMA.*
* 📍 **[FASE 1: Preparazione Sistema Operativo e Golden Image](./GUIDA_FASE1_PREPARAZIONE_OS.md)**
  * *Installazione requisiti OS OL8, tuning KVM avanzato, configurazione di `tmpfs`, ASMLib v3 e clonazione massiva dei nodi RAC.*

---

## 🧠 Modulo 2: Il Cuore (Oracle Grid e RAC)

In questo modulo abbandoniamo le vesti da Sistemista Linux e indossiamo quelle da Database Administrator.

* 📍 **[FASE 2: Installazione Grid Infrastructure e Binari Database](./GUIDA_FASE2_GRID_E_RAC.md)**
  * *Validazione pre-installazione con `cluvfy`, setup del Clusterware 19c e deploy dei binari RDBMS su tutti i nodi.*
* 📍 **FASE 3: Creazione del Database (DBCA)** *(In Arrivo)*
  * *Creazione del Container Database (CDB) RAC e della Pluggable Database (PDB) applicativa su storage ASM.*

---

## 🛡️ Modulo 3: Disaster Recovery e Alta Affidabilità (Data Guard)

Creiamo un sito secondario geograficamente distante (simulato) per proteggerci dalla perdita totale del data center primario.

* 📍 **FASE 4: Oracle Data Guard (Fisico) e Broker** *(In Arrivo)*
  * *Clonazione attiva via RMAN, configurazione dei Redo Log di standby e setup del Data Guard Broker (DGMGRL).*
* 📍 **FASE 4B: Fast-Start Failover (FSFO) Observer** *(In Arrivo)*
  * *Automatizzazione del failover geografico senza intervento umano.*
* 📍 **FASE 5: Simulazione Disastri (Switchover e Failover)** *(In Arrivo)*
  * *Test pratici: spegnimento brutale dei nodi, switchover pianificato, e failover non pianificato.*

---

## 🛠️ Modulo 4: Manutenzione e Sicurezza (Lifecycle Management)

Gestione ordinaria e straordinaria dell'infrastruttura.

* 📍 **FASE 6: Patching Out-Of-Place (OPatch / RU)** *(In Arrivo)*
  * *Applicazione delle Release Update (RU) trimestrali senza downtime per le applicazioni (Rolling Patch).*
* 📍 **FASE 7: Strategia di Backup (RMAN)** *(In Arrivo)*
  * *Setup del catalogo RMAN, backup incrementali e prove di ripristino (Point-in-Time Recovery).*
* 📍 **FASE 8: Replica Logica (GoldenGate)** *(In Arrivo)*
  * *Configurazione di Oracle GoldenGate Microservices per la replica attiva-attiva o reportistica offload.*

---

> **Consiglio per affrontare il lab:** Non avere fretta. Le architetture RAC non perdonano errori di superficialità sui permessi OS o sulle risoluzioni DNS. Se un test fallisce, fermati, usa i log di diagnostica e non passare alla fase successiva finché tutto non è verde. Buon lavoro!
