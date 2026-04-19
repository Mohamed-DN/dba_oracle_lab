# 🎮 Road-Map: Da Zero a Senior DBA (Il Percorso)

> **Benvenuto nel Laboratorio Oracle RAC "Enterprise Gold".**
> Questo non è un semplice elenco di guide, ma una vera e propria **Road-Map didattica a livelli**. Immaginalo come un videogioco: non puoi affrontare i boss della *Fase 4* (Disaster Recovery e Automazione) se prima non hai farmato le skill della *Fase 1* (Sopravvivenza su Linux e Storage).

Se segui questo percorso passo passo, investirai circa **8 settimane (3 ore al giorno)**, ma alla fine avrai una preparazione tecnica pratica superiore all'80% dei DBA Junior/Mid in circolazione.

---

## 🟢 Livello 1: "The Core" (DBA Junior)
*L'obiettivo di questo livello è farti capire su cosa poggia un database Oracle. Imparerai a muoverti su Linux, a capire lo storage condiviso e l'architettura Multitenant (CDB/PDB).*

| Step | Nome Missione | Link alla Guida | Cosa Sblocchi |
|:---:|---|---|---|
| **1.1** | **Studio Architettura Base** | [GUIDA_ATTIVITA_LAB_RAC.md](../10_esami_carriera/GUIDA_ATTIVITA_LAB_RAC.md) | Capisci cosa sono SGA, PGA, e Redo Logs. |
| **1.2** | **Setup Virtuale e Rete** | [Fase 0: Setup Macchine e DNS](../01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md) | Scopri come VirtualBox emula l'hardware e come DNS/Bind e NAT fanno parlare le VM. |
| **1.3** | **Hardening OS (Linux)** | [Fase 1: Preparazione OS (Linux 7.9)](../01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md) | Sconfiggi il mostro Systemd, impari i limiti kernel e crei l'utente `oracle`. |
| **1.4** | **Dominare i PDB & CDB** | [CDB, PDB e Ruoli](../04_administration/GUIDA_CDB_PDB_UTENTI.md) | Impari a creare Pluggable Database, clonarli e creare utenze `C##` vs locali. |
| **1.5** | **Basi Sicurezza** | [Security Hardening](../04_administration/GUIDA_SECURITY_HARDENING.md) | Applichi l'auditing unificato, password profile e impari cosa è la TDE (Transparent Data Encryption). |

---

## 🟡 Livello 2: "Disaster & Recovery" (Mid-Level)
*I database esplodono. È un dato di fatto. In questo livello imparerai l'arte di non perdere i dati del cliente e di dormire sereno di notte.*

| Step | Nome Missione | Link alla Guida | Cosa Sblocchi |
|:---:|---|---|---|
| **2.1** | **Basi di Backup Assoluto** | [Fase 5: RMAN & CRON](../03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Scrivi il tuo primo script Bash di backup incrementale (Level 0 e Level 1) schedulato via cron. |
| **2.2** | **Restore Completo RMAN** | [Guida RMAN Completa 19c](../03_backup_recovery/GUIDA_RMAN_COMPLETA_19C.md) | Impari a distruggere volontariamente un datafile del DB e a ripristinarlo senza fermare tutto. |
| **2.3** | **La Macchina del Tempo** | [Flashback Database](../02_high_availability/GUIDA_FLASHBACK_DATABASE.md) | Usi la tecnologia Flashback per "riavvolgere" il database nel tempo prima di una `DROP TABLE` accidentale. |
| **2.4** | **Muovere i Dati (Logico)** | [Oracle Data Pump](../03_backup_recovery/GUIDA_DATA_PUMP.md) | Capisci la differenza tra backup fisico e logico. Usi `expdp/impdp` via network link e PARFILE. |

---

## 🟠 Livello 3: "High Availability" (DBA Senior)
*Qui si fa sul serio. Se perdi il server primario, il business non se ne deve nemmeno accorgere.*

| Step | Nome Missione | Link alla Guida | Cosa Sblocchi |
|:---:|---|---|---|
| **3.1** | **Costruire il Cluster (RAC)** | [Fase 2: Grid & RAC](../01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md) | Usalo per installare Clusterware. Affronti dischi ASM e Patching `opatchauto`. Sblocca il tuo primo DB a 2 Nodi. |
| **3.2** | **Gestire lo Storage Pieno** | [Aggiunta/Rimozione Dischi ASM](../04_administration/GUIDA_AGGIUNTA_DISCHI_ASM.md) | Espandi il cluster a caldo aggiungendo dischi ad ASM senza `downtime`. |
| **3.3** | **Lo Standby Fisico** | [Fase 3: Standby Database](../02_high_availability/GUIDA_FASE3_RAC_STANDBY.md) | Usando *RMAN Active Duplicate*, duplichi un cluster intero via rete su un datacenter secondario. |
| **3.4** | **Data Guard Broker** | [Fase 4: Configurare Data Guard](../02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | Installi il Broker (`dgmgrl`) per gestire la sincronizzazione in tempo reale e fare Switchover. |
| **3.5** | **Servizi Infrangibili** | [Servizi Applicativi RAC](../04_administration/GUIDA_SERVIZI_APPLICATIVI_RAC.md) | Impari Load Balancing (CLB/RLB) e Application Continuity (le query non cadono se un nodo muore). |

---

## 🔴 Livello 4: "Il Risolutore" (Architect)
*Oracle è lento e i programmatori danno la colpa al Database. Devi imparare a leggere Matrix (Wait Events).*

| Step | Nome Missione | Link alla Guida | Cosa Sblocchi |
|:---:|---|---|---|
| **4.1** | **Come fare Troubleshooting** | [Troubleshooting Completo](../05_performance/GUIDA_TROUBLESHOOTING_COMPLETO.md) | Il manuale definitivo top-down. Impari a leggere le *Wait Classes* ("Db file sequential read"). Sblocca la skill più rara. |
| **4.2** | **Misurare le Prestazioni** | [Guida AWR, ASH e ADDM](../05_performance/GUIDA_AWR_ASH_ADDM.md) | Generi i report `awrrpt.sql` e interpreti i grafici. Metti in quarantena SQL lenti (SQL Plan Management). |
| **4.3** | **Schedulare Lavori** | [Oracle Scheduler](../04_administration/GUIDA_SCHEDULER_JOBS.md) | Sostituisci il banale `cron` di Linux con i potentissimi Job e Chains interni ad Oracle. |
| **4.4** | **Libreria Script DBA** | [Directory Scripts Operativi](../../scripts_operativi/README.md) | Smetti di scrivere query a mano. Usa la nostra raccolta di script SQL pronti all'uso per vedere lock, CPU session e top I/O. |
| **4.5** | **Esportazione Eterogenea** | [GoldenGate (Oracle -> PostgreSQL)](../07_replication/GUIDA_FASE7_GOLDENGATE.md) | Usi la replica logica estrema per mandare i commit da Oracle verso un database PostgreSQL. L'esame finale di architettura. |

---

## 🔮 Livello 5: "The Automator" (DevOps / SRE)
*Perché fare le cose a mano quando i robot possono farle per te? L'apice moderno del DBA.*

| Step | Nome Missione | Link alla Guida | Cosa Sblocchi |
|:---:|---|---|---|
| **5.1** | **Vagrant (Infrastruttura Come Codice)** | [Vagrant 1-Click](../../vagrant_rac_dataguard/README.md) | Smetti di usare la GUI di VirtualBox. Lanci `vagrant up` e lui costruisce l'intero DataCenter (Macchine, IP, Storage) da solo. |
| **5.2** | **Automation via Ansible** | [Ansible Playbook Library](../../automation/README.md) | Impari perché Ansible ha sostituito Jenkins per le patch Oracle. Esegui patching rolling e check mattutini con playbook pronti. |
| **5.3** | **Templates (Jinja2)** | [Ansible Templates Guide](../04_administration/GUIDA_ANSIBLE_TEMPLATES.md) | Il segreto delle Enterprise: esegui le installazioni (Grid, RDBMS, DBCA) in modalità `silent` al 100% nascondendo le password nel Vault. |
| **5.4** | **Runbook Giornaliero** | [Procedure Operative Standard](../../procedure_operative/README.md) | Impari i processi da DBA turnista. Cosa guardare alle 8:30 del mattino (Health Check), come reagire ai ticket P1. |
| **BOSS** | **L'Intervista Tecnica** | [Ripasso Concetti DBA (Colloquio)](../10_esami_carriera/GUIDA_RIPASSO_CONCETTI_DBA.md) | Metti alla prova tutto. Domande trappola su architettura (Split Brain, Node Eviction, Hard Parse, Multiplexing) scritte da un vero CTO. |

---

## 🎯 Consigli per Sopravvivere al Lab

1. **Snapshots are your best friends**: Fai snapshot su VirtualBox alla fine del *Livello 1* e prima di iniziare il *Livello 3*. Se spacchi l'ASM (succederà), torni indietro in 10 secondi e risparmi una giornata di reinstallazione.
2. **Non fare copia-incolla cieco**: I PDF e le guide sul web non funzionano mai al primo colpo perché `19.3` non si comporta come `12c` o `23ai`. Cerca di capire *perché* stai eseguendo `root.sh` e cosa ci sta nei log.
3. **MobaXterm obbligatorio**: Usa X11-forwarding e la funzione *Multi-Exec* per lanciare gli stessi comandi di rete su 4 macchine in simultanea.

Mettiti le cuffie, apri il terminale, e comincia lo *Step 1.1*!
