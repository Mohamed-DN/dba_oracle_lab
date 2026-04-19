# Oracle RAC + Data Guard — Enterprise DBA Lab

> Guida completa passo-passo per costruire un'architettura Oracle Enterprise in laboratorio.
> **Validata al 98%** contro le best practice ufficiali Oracle MAA Gold.

---

> ⚠️ **REQUISITI HARDWARE CRITICI**: Per far girare l'intero ambiente (4 Nodi RAC + 1 Nodo DNS ) **sono necessari almeno 32GB di RAM fisica** sul tuo PC. Se hai 16GB, puoi fare solo metà del lab (es. 2 nodi RAC senza Standby).

> 🤖 **AUTOMAZIONE DISPONIBILE**: Vuoi saltare i passaggi noiosi?
> - **Infrastruttura Parziale**: Nella cartella `scripts/` troverai bash script pronti all'uso per autoconfigurare lo storage base e installare il Grid.
> - **Infrastruttura Completa (RAC + Data Guard 5 Nodi)**: Vai nella cartella [`vagrant_rac_dataguard`](vagrant_rac_dataguard/README.md) per un ambiente Vagrant *"One-Click"* che automatizza interamente le **Fasi da 0 a 4** (Grid, Database, Standby RMAN Duplicate, DGMGRL Broker). Assicurati di avere almeno 33GB di RAM per questa soluzione.
> - **Ansible Automation**: Nella cartella [`automation/`](./automation/README.md) troverai 5 playbook production-grade per installazione, patching, upgrade, health check e backup RMAN.

---

## Architettura Lab (Vista Grafica)

```text
╔════════════════════════════════════════════════════════════════════════════════════╗
║                           IL TUO PC (HOST VIRTUALBOX)                             ║
║                                                                                    ║
║  ┌──────────────────────────────────────────────────────────────────────────────┐  ║
║  │              Rete Host-Only #1 (192.168.56.0/24)                             │  ║
║  │                   "Pubblica" per cluster, DNS e management                    │  ║
║  └──┬──────────┬──────────┬────────────┬────────────┬─────────────┬────────────┘  ║
║     │          │          │            │            │             │               ║
║  ┌──┴──────┐ ┌─┴───────┐ ┌┴─────────┐ ┌┴──────────┐ ┌┴──────────┐ ┌┴───────────┐  ║
║  │ dnsnode │ │  rac1   │ │  rac2    │ │ racstby1  │ │ racstby2  │ │   emcc1    │  ║
║  │ .56.50  │ │ .56.101 │ │ .56.102  │ │ .56.111   │ │ .56.112   │ │ EM 13.5    │  ║
║  │ 1GB/1CPU│ │ 8GB/4CPU│ │ 8GB/4CPU │ │ 8GB/4CPU  │ │ 8GB/4CPU  │ │ OMS+Agent  │  ║
║  └─────────┘ └───┬─────┘ └────┬─────┘ └────┬──────┘ └────┬──────┘ └────────────┘  ║
║                  │            │            │             │                           ║
║             ┌────┴────────────┴───┐   ┌────┴─────────────┴───┐                       ║
║             │ Host-Only #2         │   │ Host-Only #3         │                       ║
║             │ 192.168.1.0/24       │   │ 192.168.2.0/24       │                       ║
║             │ Interconnect PRIMARY │   │ Interconnect STANDBY │                       ║
║             └──────────────────────┘   └──────────────────────┘                       ║
║                                                                                    ║
║  Flussi logici:                                                                    ║
║  - Cache Fusion: rac1 <-> rac2  |  racstby1 <-> racstby2                           ║
║  - Data Guard: RACDB (primary) -> RACDB_STBY (LGWR ASYNC)                          ║
║  - GoldenGate: Extract/Pump sul primary -> Replicat su dbtarget/OCI                ║
║  - Enterprise Manager (emcc1): monitora tutti i nodi + target                      ║
║                                                                                    ║
║  Dischi Condivisi (Shareable VDI):                                                 ║
║  ┌──────────────────────────────┐     ┌──────────────────────────────┐              ║
║  │ rac1 + rac2 (PRIMARY)        │     │ racstby1 + racstby2 (STBY)   │              ║
║  │ asm-crs-disk1    2GB         │     │ asm-stby-crs-1      2GB      │              ║
║  │ asm-crs-disk2    2GB         │     │ asm-stby-crs-2      2GB      │              ║
║  │ asm-crs-disk3    2GB         │     │ asm-stby-crs-3      2GB      │              ║
║  │ asm-data-disk1  20GB         │     │ asm-stby-data      20GB      │              ║
║  │ asm-reco-disk1  15GB         │     │ asm-stby-reco      15GB      │              ║
║  └──────────────────────────────┘     └──────────────────────────────┘              ║
║                                                                                    ║
║  Target esterno: dbtarget (OCI/Cloud) per replica Oracle oppure PostgreSQL         ║
╚════════════════════════════════════════════════════════════════════════════════════╝
```

> In basso trovi anche la sezione **Architettura Complessiva** in formato ASCII con dettagli rete/dischi.

---

## Da Dove Iniziare (Percorso Consigliato)

### 1) Teoria iniziale (2 ore)

1. [GUIDA_ARCHITETTURA_ORACLE.md](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md)
2. [GUIDA_COMANDI_DBA.md](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md)
3. [PIANO_STUDIO_GIORNALIERO.md](./docs/00_fondamenti/PIANO_STUDIO_GIORNALIERO.md)

### 2) Esegui il lab base in ordine (Fasi 0 -> 8)

1. [GUIDA_FASE0_SETUP_MACCHINE.md](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md)
2. [GUIDA_FASE1_PREPARAZIONE_OS.md](./docs/01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md)
3. [GUIDA_FASE2_GRID_E_RAC.md](./docs/01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md)
4. [GUIDA_FASE3_RAC_STANDBY.md](./docs/02_high_availability/GUIDA_FASE3_RAC_STANDBY.md)
5. [GUIDA_FASE4_DATAGUARD_DGMGRL.md](./docs/02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) - include anche `Protection Mode`, `MaxPerformance`, `MaxAvailability`, `MaxProtection`, `FASTSYNC`
6. [GUIDA_FASE5_RMAN_BACKUP.md](./docs/03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md)
7. [GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md)
8. [GUIDA_FASE7_GOLDENGATE.md](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md)
9. [GUIDA_FASE8_TEST_VERIFICA.md](./docs/01_lab_setup/GUIDA_FASE8_TEST_VERIFICA.md)

### 3) Guide Operative e Approfondimenti

#### Data Guard & HA
- [GUIDA_SWITCHOVER_COMPLETO.md](./docs/02_high_availability/GUIDA_SWITCHOVER_COMPLETO.md) — Switchover passo-passo con diagrammi
- [GUIDA_FAILOVER_E_REINSTATE.md](./docs/02_high_availability/GUIDA_FAILOVER_E_REINSTATE.md) — Failover di emergenza e reinstate ⚠️ **Vedi nota sotto**
- [GUIDA_FLASHBACK_DATABASE.md](./docs/02_high_availability/GUIDA_FLASHBACK_DATABASE.md) — 🆕 Flashback Database: macchina del tempo Oracle
- [GUIDA_MAA_BEST_PRACTICES.md](./docs/02_high_availability/GUIDA_MAA_BEST_PRACTICES.md) — Oracle Maximum Availability Architecture

> ⚠️ **NOTA SUL FAILOVER**: Il Failover **NON è obbligatorio** nel lab. È un'operazione distruttiva che può rompere l'ambiente.
> **Prima di tentare il failover**, proteggi il tuo lavoro:
> 1. **Spegni TUTTE le VM** (`vagrant halt` o shutdown da VirtualBox)
> 2. **Copia l'intera cartella del progetto VirtualBox** in un backup:
>    ```bash
>    # Windows
>    xcopy /E /I "C:\Users\TuoUser\VirtualBox VMs" "D:\backup_lab_oracle"
>    # oppure comprimi tutto in uno zip
>    ```
> 3. **Dopo il failover**, se l'ambiente si rompe, ripristina dalla copia.
> Il failover è un esercizio avanzato da fare solo quando sei sicuro del tuo switchover.

#### Database Architecture & Admin
- [GUIDA_CDB_PDB_UTENTI.md](./docs/04_administration/GUIDA_CDB_PDB_UTENTI.md) — Multitenant: CDB, PDB, utenti, service
- [GUIDA_LISTENER_SERVICES_DBA.md](./docs/04_administration/GUIDA_LISTENER_SERVICES_DBA.md) — Listener, services, TNS in dettaglio
- [GUIDA_SERVIZI_APPLICATIVI_RAC.md](./docs/04_administration/GUIDA_SERVIZI_APPLICATIVI_RAC.md) — 🆕 TAF, FAN, CLB/RLB, Application Continuity
- [GUIDA_COMANDI_DBA.md](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md) — Comandi DBA essenziali da terminale
- [GUIDA_DATA_PUMP.md](./docs/03_backup_recovery/GUIDA_DATA_PUMP.md) — 🆕 Export/Import con Data Pump (expdp/impdp)
- [GUIDA_AGGIUNTA_DISCHI_ASM.md](./docs/04_administration/GUIDA_AGGIUNTA_DISCHI_ASM.md) — Aggiungere dischi ASM
- [GUIDA_SCHEDULER_JOBS.md](./docs/04_administration/GUIDA_SCHEDULER_JOBS.md) — 🆕 Oracle Scheduler: job, chain, auto-tasks, monitoring
- [GUIDA_SSH_KEYS_RAC.md](./docs/01_lab_setup/GUIDA_SSH_KEYS_RAC.md) — Equivalenza utenti SSH in RAC (incluso anche nelle Fasi 1-2)

#### Performance & Diagnostica
- [GUIDA_TROUBLESHOOTING_COMPLETO.md](./docs/05_performance/GUIDA_TROUBLESHOOTING_COMPLETO.md) — 🆕 **MEGA-GUIDA**: metodo da zero, wait events, scenari reali, SQL tuning, monitoring
- [GUIDA_AWR_ASH_ADDM.md](./docs/05_performance/GUIDA_AWR_ASH_ADDM.md) — 🆕 Comandi avanzati AWR/ASH/ADDM, SQL Monitor, SPM, SQL Quarantine

#### Sicurezza
- [GUIDA_SECURITY_HARDENING.md](./docs/04_administration/GUIDA_SECURITY_HARDENING.md) — 🆕 TDE, Auditing, Encryption, Password Profiles

#### Patching & Upgrade
- [GUIDA_PATCHING_RAC.md](./docs/06_patching_upgrade/GUIDA_PATCHING_RAC.md) — Patching post-installazione con Combo Patch
- [GUIDA_UPGRADE_RU_RAC.md](./docs/06_patching_upgrade/GUIDA_UPGRADE_RU_RAC.md) — Upgrade Release Update in RAC
- [GUIDA_AUTOUPGRADE_12C_TO_19C.md](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_12C_TO_19C.md) — 🆕 AutoUpgrade da 12c a 19c
- [GUIDA_AUTOUPGRADE_19C_TO_26.md](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_19C_TO_26.md) — 🆕 AutoUpgrade da 19c a 26c

#### GoldenGate & Replica
- [GUIDA_FASE7_GOLDENGATE.md](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md) — GoldenGate locale (Oracle + PostgreSQL target)
- [GUIDA_MIGRAZIONE_GOLDENGATE.md](./docs/07_replication/GUIDA_MIGRAZIONE_GOLDENGATE.md) — Cutover e migrazione con GG
- [GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md](./docs/07_replication/GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) — Migrazione Oracle → PostgreSQL

#### Produzione & Esami
- [GUIDA_DA_LAB_A_PRODUZIONE.md](./docs/10_esami_carriera/GUIDA_DA_LAB_A_PRODUZIONE.md) — Sizing lab vs produzione
- [GUIDA_ESAME_REVIEW.md](./docs/10_esami_carriera/GUIDA_ESAME_REVIEW.md) — Preparazione esami Oracle
- [GUIDA_ATTIVITA_DBA.md](./docs/10_esami_carriera/GUIDA_ATTIVITA_DBA.md) — Attività quotidiane del DBA
- [VALIDAZIONE_BEST_PRACTICES.md](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md) — Validazione best practice Oracle

#### 📋 Procedure Operative (Runbook Giornalieri)
- [procedure_operative/](./procedure_operative/README.md) — 🆕 **13 procedure pronte all'uso** per il lavoro quotidiano:
  - Morning Health Check, Verifica Backup, Check Data Guard
  - Lock/Blocchi, Query Lenta, Tablespace Pieno, CPU Alta, ORA-Errors
  - Gestione Utenti, Start/Stop RAC, Review AWR Settimanale
  - Capacity Planning, Refresh Schema Test

#### 🤖 Automazione Ansible
- [automation/](./automation/README.md) — 🆕 **5 playbook production-grade**:
  - Installazione 19c silent, Rolling Patching RAC, AutoUpgrade 3-fasi
  - Daily Health Check automatizzato, RMAN Backup + Validate

#### Script & Riferimenti
- [GLOSSARIO_ORACLE.md](./docs/00_fondamenti/GLOSSARIO_ORACLE.md) — 🆕 100+ acronimi e termini Oracle spiegati
- [GUIDA_ARCHITETTURA_ORACLE.md](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md) — Architettura Oracle: SGA, PGA, processi, storage
- [TOP_100_SCRIPT_DBA.md](./docs/05_performance/TOP_100_SCRIPT_DBA.md) — Top 100 script DBA
- [extra_dba/](./extra_dba/README.md) — Guide extra (domande colloquio, checklist, catalogo attività)
- [studio_ai/](./studio_ai/README.md) — Script AI per studio (12 categorie: ASM, DataGuard, monitoring, ecc.)
- [vagrant_rac_dataguard/](./vagrant_rac_dataguard/README.md) — Automazione Vagrant "One-Click" (Fasi 0→4)

#### Cloud OCI (Opzionale Avanzato)

> Le guide seguenti documentano un percorso **alternativo avanzato**: replicare verso Oracle Cloud (OCI ARM Free Tier). Il percorso principale del lab è **locale** (vedi Fase 7).

- [GUIDA_CLOUD_GOLDENGATE.md](./docs/09_cloud_oci/GUIDA_CLOUD_GOLDENGATE.md) — GoldenGate verso OCI ARM (setup completo)
- [GUIDA_GOLDENGATE_OCI_ARM.md](./docs/09_cloud_oci/GUIDA_GOLDENGATE_OCI_ARM.md) — Target DB su OCI: scelta percorso Free vs Enterprise
- [GUIDA_RETE_LAB_OCI_GOLDENGATE.md](./docs/09_cloud_oci/GUIDA_RETE_LAB_OCI_GOLDENGATE.md) — Networking locale ↔ OCI (VPN, SSH tunnel, IP pubblico)

> **Consiglio**: il piano completo e aggiornato e' su [PIANO_STUDIO_GIORNALIERO.md](./docs/00_fondamenti/PIANO_STUDIO_GIORNALIERO.md), 8 settimane (40 giorni) a 3 ore/giorno.

---

## Roadmap Studio Ribilanciata (8 settimane, 3h/giorno)

Questa roadmap sintetica allinea il README al piano aggiornato in [PIANO_STUDIO_GIORNALIERO.md](./docs/00_fondamenti/PIANO_STUDIO_GIORNALIERO.md).

### Pattern settimanale consigliato

| Giorno | Intensita | Focus |
|---|---|---|
| 1 | HIGH | Nuovo tema + lab nuovo |
| 2 | HIGH | Continuazione + troubleshooting |
| 3 | MEDIUM | Consolidamento + test guidati |
| 4 | HIGH | Nuovo blocco tecnico |
| 5 | LIGHT | Ripasso attivo + backlog fix + documentazione |
| 6 (opzionale) | BUFFER | Recupero task o test extra |
| 7 | OFF | Riposo tecnico (max 30 min lettura leggera) |

### Carico per fase (vista rapida)

| Settimana | Focus | Uscita minima |
|---|---|---|
| 1 | OS + Grid + ASM | Grid stabile + prerequisiti chiusi |
| 2 | RAC + standby prep | RAC operativo + standby pronto |
| 3 | Data Guard + RMAN + GG base | broker ok + backup validato + GG base |
| 4 | GG avanzato + HA test | almeno 24 test GG chiusi |
| 5 | Enterprise Manager + monitoraggio + cloud | OMS/Agent attivi + alerting base funzionante |
| 6 | Migrazione Oracle -> PostgreSQL | flusso end-to-end completato |
| 7 | Preparazione 1Z0-082 | 2 mock exam + revisione errori |
| 8 | Preparazione 1Z0-083 | 2 mock exam + runbook finali |

### Mock exam Oracle (allineamento pratico)

Riferimento esami in inglese (Oracle University, verificato il 14 marzo 2026):

- `1Z0-082` (Oracle Database Administration I)
- `1Z0-083` (Oracle Database Administration II)
- pagina esame EN 1Z0-082: https://education.oracle.com/oracle-database-administration-i/pexam_1Z0-082
- pagina esame EN 1Z0-083: https://education.oracle.com/oracle-database-administration-ii/pexam_1Z0-083

Nota: numero domande e passing score possono cambiare per lingua/track; verifica sempre nel portale Oracle prima della prenotazione.

Calendario consigliato:

- settimana 7: 2 simulazioni da 120 minuti
- settimana 8: 2 simulazioni da 120 minuti
- dopo ogni mock: 40-60 minuti di error review per categoria

### Sprint GoldenGate (40 test) senza overload

- settimana 3: `GG-01..GG-16`
- settimana 4: `GG-17..GG-32`
- buffer settimana 4/5: `GG-33..GG-40` + retest fail

Materiale operativo:

- guida: [GUIDA_FASE7_GOLDENGATE.md](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md)
- template testlog: [TESTLOG_GOLDENGATE_TEMPLATE.md](./docs/07_replication/TESTLOG_GOLDENGATE_TEMPLATE.md)

---

## Indice Completo

### Teoria (Leggi PRIMA di costruire)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 1 | **Architettura Oracle** | [GUIDA_ARCHITETTURA](./docs/00_fondamenti/GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo Log, Undo, Temp, ASM, Cache Fusion |
| 2 | **Comandi DBA** | [GUIDA_COMANDI_DBA](./docs/00_fondamenti/GUIDA_COMANDI_DBA.md) | 100+ query SQL, script Oracle Base, health check |
| 3 | **CDB/PDB, Utenti, EM Express** | [GUIDA_CDB_PDB_UTENTI](./docs/04_administration/GUIDA_CDB_PDB_UTENTI.md) | Multitenant, PDB create/clone/plug, utenti, ruoli, SQL Tuning |
| 4 | **Piano di Studio** | [PIANO_STUDIO](./docs/00_fondamenti/PIANO_STUDIO_GIORNALIERO.md) | 8 settimane (40 giorni) x 3h/giorno, roadmap e milestone |
| 5 | **Top 100 Script DBA** | [TOP_100_SCRIPT](./docs/05_performance/TOP_100_SCRIPT_DBA.md) | I 100 script piu utili ogni giorno - lock, AWR, tuning, ASM, I/O |
| 6 | **Attivita Lab RAC** | [ATTIVITA_LAB](./docs/10_esami_carriera/GUIDA_ATTIVITA_LAB_RAC.md) | 10 esercizi pratici: health check, AWR, switchover, GG test |

---

### Costruzione Lab (Segui in ordine!)

| # | Fase | File | Cosa Fai |
|---|---|---|---|
| 7 | **Fase 0** | [SETUP MACCHINE](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md) | Crea VM VirtualBox, DNS Dnsmasq, dischi ASM oracleasm, installa OL 7.9 |
| 8 | **Fase 1** | [PREPARAZIONE OS](./docs/01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md) | Configura rete, DNS, utenti, SSH, kernel |
| 9 | **Fase 2** | [GRID + RAC](./docs/01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md) | Installa Grid, ASM, DB Software, crea RACDB |
| 10 | **Fase 3** | [RAC STANDBY](./docs/02_high_availability/GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener statico, MRP |
| 11 | **Fase 4** | [DATA GUARD](./docs/02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Active Data Guard, Protection Mode (`MaxPerformance`, `MaxAvailability`, `MaxProtection`, `FASTSYNC`) |
| 12 | **Fase 5** | [RMAN BACKUP](./docs/03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Strategia backup, script, cron, BCT, restore |
| 13 | **Fase 6** | [ENTERPRISE MANAGER](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) | Setup Cloud Control 13.5: OMS, Agent, target discovery, alerting, jobs |
| 14 | **Fase 7** | [GOLDENGATE](./docs/07_replication/GUIDA_FASE7_GOLDENGATE.md) | Extract integrato sul primary, Pump, Replicat target locale/OCI + varianti avanzate documentate |
| 15 | **Fase 8** | [TEST VERIFICA](./docs/01_lab_setup/GUIDA_FASE8_TEST_VERIFICA.md) | Test end-to-end DataGuard + RMAN + EM + GoldenGate + stress + node crash |
| 16 | **RMAN Completa** | [GUIDA_RMAN_19C](./docs/03_backup_recovery/GUIDA_RMAN_COMPLETA_19C.md) | Runbook RMAN completo + test lab: config, backup, validate, recovery, catalog |

---

### Operazioni Avanzate (Dopo il lab base)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 17 | **Protection Mode** | [GUIDA_FASE4_DG](./docs/02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | Cambio modalita Data Guard: `MaxPerformance`, `MaxAvailability`, `MaxProtection`, `FASTSYNC` |
| 18 | **Switchover** | [GUIDA_SWITCHOVER](./docs/02_high_availability/GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback passo-passo |
| 19 | **Failover + Reinstate** | [GUIDA_FAILOVER](./docs/02_high_availability/GUIDA_FAILOVER_E_REINSTATE.md) | ⚠️ Failover emergenza, reinstate, FSFO — **NON obbligatorio nel lab** (fai backup/zip prima!) |
| 20 | **Migrazione GG** | [GUIDA_MIGRAZIONE](./docs/07_replication/GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration con GoldenGate |
| 21 | **Patching & RU** | [GUIDA_PATCHING](./docs/06_patching_upgrade/GUIDA_PATCHING_RAC.md) | Combo Patch, OJVM, e pulizia filesystem |
| 22 | **Upgrade RU** | [GUIDA_UPGRADE_RU](./docs/06_patching_upgrade/GUIDA_UPGRADE_RU_RAC.md) | Skip version, rollback auto, upgrade workflow |
| 23 | **PDB + Services + DG** | [GUIDA_PDB_DG](./extra_dba/GUIDA_PDB_DATAGUARD_SERVICES.md) | Creazione PDB sul primary, propagazione sullo standby, servizi RAC e listener |
| 24 | **Attivita Lab RAC** | [GUIDA_ATTIVITA_LAB](./docs/10_esami_carriera/GUIDA_ATTIVITA_LAB_RAC.md) | 10 esercizi pratici sul lab: health check, AWR, lock, switchover, GG test |

### Extra DBA (Post-lab)

| Documento | File | Descrizione |
|---|---|---|
| **Indice Extra DBA** | [EXTRA_DBA](./extra_dba/README.md) | Attivita extra laboratorio gia presenti nel repo: Data Guard avanzato, RAC operations, backup/recovery, monitoring e day-2 |
| **Catalogo attivita DBA** | [CATALOGO_DBA](./extra_dba/GUIDA_CATALOGO_ATTIVITA_DBA.md) | Panorama completo delle attivita Oracle DBA reali: availability, backup, performance, security, TDE, HA/DR, multitenant, patching |
| **Checklist operativa DBA** | [CHECKLIST_DBA](./extra_dba/GUIDA_CHECKLIST_ATTIVITA_DBA.md) | Runbook giornaliero, settimanale, mensile, trimestrale, pre-change e post-incident |
| **Guida domande DBA Oracle** | [DOMANDE_DBA](./extra_dba/GUIDA_DOMANDE_DBA_ORACLE.md) | Domande tecniche, risposte chiare, follow-up e scenari realistici su Oracle DBA |

> `extra_dba` e `studio_ai` restano separati: `extra_dba` e un indice di percorsi avanzati del lab, `studio_ai` resta la libreria operativa di script e note reali.

---

### Cloud e DBA Professionale (Settimana 5)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 25 | **Cloud GoldenGate** | [GUIDA_CLOUD_GG](./docs/09_cloud_oci/GUIDA_GOLDENGATE_OCI_ARM.md) | OCI compute target, scelta tra free validation e migration target coerente |
| 26 | **Rete lab + OCI** | [GUIDA_RETE_OCI](./docs/09_cloud_oci/GUIDA_RETE_LAB_OCI_GOLDENGATE.md) | Host-only, NAT, IP pubblico, VPN, NSG, listener e porte GoldenGate |
| 27 | **Attivita DBA** | [GUIDA_ATTIVITA_DBA](./docs/10_esami_carriera/GUIDA_ATTIVITA_DBA.md) | Batch Jobs, AWR/ADDM/ASH, Patching, DataPump, Security |
| 28 | **MAA Best Practices** | [GUIDA_MAA](./docs/02_high_availability/GUIDA_MAA_BEST_PRACTICES.md) | Validazione lab vs Oracle MAA Gold |

---

### Esame + Migrazione PostgreSQL (Settimane 6-8)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 29 | **Ripasso Esame** | [GUIDA_ESAME_REVIEW](./docs/10_esami_carriera/GUIDA_ESAME_REVIEW.md) | Tutti gli argomenti 1Z0-082 + 1Z0-083 (Admin + SQL + DBA Pro 2) |
| 30 | **Oracle -> PostgreSQL** | [GUIDA_MIGRAZIONE_PG](./docs/07_replication/GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) | Migrazione Oracle->PostgreSQL con GoldenGate, ora2pg, ODBC |

---

### Riferimento e Approfondimento

| Documento | File | Descrizione |
|---|---|---|
| **Da Lab a Produzione** | [GUIDA_PRODUZIONE](./docs/10_esami_carriera/GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security, monitoring |
| **Validazione Oracle BP** | [VALIDAZIONE_BP](./docs/10_esami_carriera/VALIDAZIONE_BEST_PRACTICES.md) | Audit 54 punti, scorecard 98%, GUI vs CLI |
| **Analisi Oracle Base** | [ANALISI_ORACLEBASE](./ANALISI_ORACLEBASE_VAGRANT.md) | Confronto con Oracle Base Vagrant |
| **Gestione Dischi ASM** | [GUIDA_ASM_DISK](./docs/04_administration/GUIDA_AGGIUNTA_DISCHI_ASM.md) | Aggiungere/Creare dischi ASM (ASMLib + AFD) |
| **Guida RMAN Completa 19c** | [GUIDA_RMAN_19C](./docs/03_backup_recovery/GUIDA_RMAN_COMPLETA_19C.md) | Backup, restore, recovery, Data Guard e test pratici con fonti ufficiali Oracle |
| **Guida SSH Keys RAC** | [GUIDA_SSH_KEYS](./docs/01_lab_setup/GUIDA_SSH_KEYS_RAC.md) | User equivalence per `grid`/`oracle`/`root`, reset rapido e troubleshooting `PRVG-2019` |
| **Guida Fase 6 Enterprise Manager** | [GUIDA_EM13C](./docs/08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) | Setup completo OEM Cloud Control 13.5, monitoraggio operativo e runbook test |
| **Template Test GoldenGate** | [TESTLOG_GG_TEMPLATE](./docs/07_replication/TESTLOG_GOLDENGATE_TEMPLATE.md) | Template pronto per tracciare PASS/FAIL, lag, evidenze e fix |
| **AutoUpgrade 12c → 19c** | [GUIDA_AUTOUPGRADE_12C](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_12C_TO_19C.md) | Guida completa AutoUpgrade con config.cfg, analyze, deploy, rollback |
| **AutoUpgrade 19c → 26c** | [GUIDA_AUTOUPGRADE_26C](./docs/06_patching_upgrade/GUIDA_AUTOUPGRADE_19C_TO_26.md) | Upgrade alla nuova Long-Term Release |

---

### 📚 Enterprise DBA Toolkit (Studio AI)

> Raccolta di script e procedure operative reali da ambienti Enterprise di produzione.
> Estratti e organizzati dalla cartella `studio/` con appunti operativi.

| # | Area | Descrizione |
|---|---|---|
| 01 | [ASM & Storage](./studio_ai/01_asm_storage/) | Aggiunta/rimozione dischi ASM, migrazione LUN (ASMLib + AFD) |
| 02 | [Data Guard](./studio_ai/02_dataguard/) | Configurazione DG, Active DG, verifica GAP, recovery DR |
| 03 | [Script Monitoring](./studio_ai/03_monitoring_scripts/) | 48 script SQL: sessioni, lock, CPU, I/O, ASH, ASM |
| 04 | [Gestione Utenti](./studio_ai/04_user_management/) | Template creazione utenti, policy password, Vault |
| 05 | [Patching](./studio_ai/05_patching/) | Patching Oracle, Golden Images (OHCTL) |
| 06 | [Backup & Recovery](./studio_ai/06_backup_recovery/) | Flashback, Restore Point, verifiche RMAN |
| 07 | [Performance & Tuning](./studio_ai/07_performance_tuning/) | SPM, analisi AWR, gestione statistiche |
| 08 | [TDE & Sicurezza](./studio_ai/08_tde_security/) | Transparent Data Encryption, Oracle Vault |
| 09 | [Compressione](./studio_ai/09_compression/) | DBMS_REDEFINITION online, near-zero downtime |
| 10 | [Partition Manager](./studio_ai/10_partition_manager/) | Package gestione automatica partizioni |
| 11 | [Template SQL](./studio_ai/11_sql_templates/) | Template DDL/DML standard con error handling |
| 12 | [Utility](./studio_ai/12_utilities/) | Monitor TEMP/UNDO, MView refresh, DBA utility package |

---

### 📋 Procedure Operative (Runbook Giornalieri)

**13 procedure pronte al copia-incolla** → [procedure_operative/README.md](./procedure_operative/README.md)

| # | Procedura | Quando |
|---|---|---|
| 01 | [Morning Health Check](./procedure_operative/01_MORNING_HEALTH_CHECK.md) | Ogni mattina |
| 02 | [Verifica Backup](./procedure_operative/02_VERIFICA_BACKUP.md) | Ogni mattina |
| 03 | [Check Data Guard](./procedure_operative/03_CHECK_DATAGUARD.md) | Ogni mattina + incidenti |
| 04 | [Lock e Sessioni Bloccate](./procedure_operative/04_LOCK_SESSIONI_BLOCCATE.md) | "App bloccata!" |
| 05 | [Query Lenta](./procedure_operative/05_QUERY_LENTA.md) | "La query è lentissima!" |
| 06 | [Tablespace Pieno](./procedure_operative/06_TABLESPACE_PIENO.md) | Alert > 85% |
| 07 | [CPU Alta](./procedure_operative/07_CPU_ALTA.md) | Alert > 90% |
| 08 | [ORA-Errors Comuni](./procedure_operative/08_ORA_ERRORS.md) | Qualsiasi ORA- |
| 09 | [Gestione Utenti](./procedure_operative/09_GESTIONE_UTENTI.md) | Creazione/modifica utente |
| 10 | [Start/Stop RAC](./procedure_operative/10_START_STOP_RAC.md) | Manutenzione pianificata |
| 11 | [Review AWR](./procedure_operative/11_REVIEW_AWR.md) | Ogni venerdì |
| 12 | [Capacity Planning](./procedure_operative/12_CAPACITY_PLANNING_LIMITI.md) | Controllo mensile |
| 13 | [Refresh Schema Test](./procedure_operative/13_REFRESH_SCHEMA_TEST.md) | Richiesta Dev |

---

### 🤖 Automazione Ansible

**5 playbook production-grade** → [automation/README.md](./automation/README.md)

| # | Playbook | Descrizione | Uso |
|---|---|---|---|
| 01 | [Oracle Install](./automation/playbooks/01_oracle_install.yml) | Installazione 19c silent (prereq + response file) | `ansible-playbook ... 01_oracle_install.yml` |
| 02 | [Oracle Patching](./automation/playbooks/02_oracle_patching.yml) | Rolling patch RAC (un nodo alla volta, zero downtime) | `ansible-playbook ... 02_oracle_patching.yml` |
| 03 | [AutoUpgrade 3-fasi](./automation/playbooks/03_oracle_autoupgrade.yml) | Pre-upgrade → Upgrade → Finalize (CruGlobal pattern) | `--tags pre_upgrade / upgrade / finalize` |
| 04 | [Daily Health Check](./automation/playbooks/04_daily_health_check.yml) | Morning check automatizzato (7 controlli) | Schedulare con cron |
| 05 | [RMAN Backup](./automation/playbooks/05_rman_backup.yml) | Backup + crosscheck + validate + report | `ansible-playbook ... 05_rman_backup.yml` |

---

## Architettura Complessiva

```
+===========================================================================+
|                      VIRTUALBOX HOST (Il tuo PC)                          |
|                                                                           |
|  Host-Only #1: 192.168.56.0/24 (Pubblica)                                |
|  Host-Only #2: 192.168.1.0/24  (Interconnect Primario)                   |
|  Host-Only #3: 192.168.2.0/24  (Interconnect Standby)                    |
|                                                                           |
|  +----------+   +----------+----------+   +----------+----------+        |
|  | dnsnode  |   | rac1     | rac2     |   | racstby1 | racstby2 |        |
|  | .56.50   |   | .56.101  | .56.102  |   | .56.111  | .56.112  |        |
|  | Dnsmasq  |   | VIP .103 | VIP .104 |   | VIP .113 | VIP .114 |        |
|  | 1GB/1CPU |   | 8GB/4CPU | 8GB/4CPU |   | 8GB/4CPU | 8GB/4CPU |        |
|  +----------+   +-----+----+----+-----+   +-----+----+----+-----+        |
|                       |         |               |         |               |
|                  +----+---------+----+     +----+---------+----+          |
|                  | Interconnect     |     | Interconnect     |           |
|                  | 192.168.1.101-102|     | 192.168.2.111-112|           |
|                  | (Cache Fusion)   |     | (Cache Fusion)   |           |
|                  +------------------+     +------------------+           |
|                                                                           |
|  SCAN Primary: rac-scan       --> 192.168.56.105, .106, .107             |
|  SCAN Standby: racstby-scan   --> 192.168.56.115, .116, .117             |
|                                                                           |
|  +-------------------------------+   +-------------------------------+   |
|  | RAC PRIMARY (RACDB)           |   | RAC STANDBY (RACDB_STBY)     |   |
|  | Grid 19c + RU                 |   | Active Data Guard            |   |
|  | ASM: +CRS(2GBx3) +DATA(20GB) |   | READ ONLY WITH APPLY         |   |
|  |      +RECO(15GB)              |   | GG Extract + Data Pump       |   |
|  +---------------+---------------+   +-------------------------------+   |
|                  |                                                        |
|                  | Data Guard: Redo Shipping (LGWR ASYNC)                 |
|                  v                                                        |
|  +---------------------------------------------------------------+        |
|  | TARGET ENVIRONMENT (dbtarget / Cloud OCI / Altra VM)          |        |
|  | - Oracle Database Target (Replica Oracle-Oracle)              |        |
|  | - PostgreSQL 16 Target   (Migrazione Oracle-PostgreSQL)       |        |
|  |   --> Riceve dati via GoldenGate Replicat                     |        |
|  +---------------------------------------------------------------+        |
+===========================================================================+
```

---

## Prerequisiti Software

| Software | Versione | Download |
|---|---|---|
| Oracle Linux | 7.9 (VM) | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Oracle Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c o 21c | [eDelivery](https://edelivery.oracle.com) |
| Oracle Enterprise Manager | 13.5 | [Oracle Software Delivery Cloud](https://edelivery.oracle.com) |
| VirtualBox | Ultimo | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> Scarica TUTTO prima di iniziare! Guarda la lista completa in [FASE 0](./docs/01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md).

---

## Piano IP

| Hostname | IP Pubblica | IP Privata | IP VIP | Note |
|---|---|---|---|---|
| dnsnode | 192.168.56.50 | -- | -- | Dnsmasq DNS |
| rac1 | 192.168.56.101 | 192.168.1.101 | 192.168.56.103 | RAC Primary N.1 |
| rac2 | 192.168.56.102 | 192.168.1.102 | 192.168.56.104 | RAC Primary N.2 |
| rac-scan | 192.168.56.105-107 | -- | -- | SCAN (3 IP) |
| racstby1 | 192.168.56.111 | 192.168.2.111 | 192.168.56.113 | Standby N.1 |
| racstby2 | 192.168.56.112 | 192.168.2.112 | 192.168.56.114 | Standby N.2 |
| racstby-scan | 192.168.56.115-117 | -- | -- | SCAN Standby (3 IP) |
| dbtarget | Cloud OCI | -- | -- | GoldenGate Replicat |

---

## Crediti e Riferimenti

- [Oracle Base - RAC 19c on VirtualBox](https://oracle-base.com/articles/19c/oracle-db-19c-rac-installation-on-oracle-linux-7-using-virtualbox)
- [Oracle MAA Best Practices](https://www.oracle.com/database/technologies/high-availability/maa.html)
- [My Oracle Support](https://support.oracle.com) - Doc ID 2118136.2 per le Release Update
- [oravirt/ansible-oracle](https://github.com/oravirt/ansible-oracle) - Collection Ansible per installazione Oracle
- [CruGlobal/ansible-oracle-db-upgrade](https://github.com/CruGlobal/ansible-oracle-db-upgrade) - Pattern 3-fasi per upgrade
