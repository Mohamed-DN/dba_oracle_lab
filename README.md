# Oracle RAC + Data Guard + GoldenGate + Cloud - Guida Definitiva

> Guida completa passo-passo per costruire un'architettura Oracle Enterprise in laboratorio.
> **Validata al 98%** contro le best practice ufficiali Oracle MAA Gold.

---

> ⚠️ **REQUISITI HARDWARE CRITICI**: Per far girare l'intero ambiente (4 Nodi RAC + 1 Nodo DNS ) **sono necessari almeno 32GB di RAM fisica** sul tuo PC. Se hai 16GB, puoi fare solo metà del lab (es. 2 nodi RAC senza Standby).

> 🤖 **AUTOMAZIONE DISPONIBILE**: Vuoi saltare i passaggi noiosi? Nella cartella `scripts/` troverai bash script pronti all'uso per autoconfigurare lo storage (`configure_storage.sh`) e installare il Grid (`install_grid.sh`). Le guide ti mostrano la strada manuale (per imparare), ma gli script sono a tua disposizione!

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
║  - GoldenGate: Extract/Pump su standby -> Replicat su dbtarget/OCI                 ║
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

1. [GUIDA_ARCHITETTURA_ORACLE.md](./GUIDA_ARCHITETTURA_ORACLE.md)
2. [GUIDA_COMANDI_DBA.md](./GUIDA_COMANDI_DBA.md)
3. [PIANO_STUDIO_GIORNALIERO.md](./PIANO_STUDIO_GIORNALIERO.md)

### 2) Esegui il lab base in ordine (Fasi 0 -> 8)

1. [GUIDA_FASE0_SETUP_MACCHINE.md](./GUIDA_FASE0_SETUP_MACCHINE.md)
2. [GUIDA_FASE1_PREPARAZIONE_OS.md](./GUIDA_FASE1_PREPARAZIONE_OS.md)
3. [GUIDA_FASE2_GRID_E_RAC.md](./GUIDA_FASE2_GRID_E_RAC.md)
4. [GUIDA_FASE3_RAC_STANDBY.md](./GUIDA_FASE3_RAC_STANDBY.md)
5. [GUIDA_FASE4_DATAGUARD_DGMGRL.md](./GUIDA_FASE4_DATAGUARD_DGMGRL.md)
6. [GUIDA_FASE5_GOLDENGATE.md](./GUIDA_FASE5_GOLDENGATE.md)
7. [GUIDA_FASE6_TEST_VERIFICA.md](./GUIDA_FASE6_TEST_VERIFICA.md)
8. [GUIDA_FASE7_RMAN_BACKUP.md](./GUIDA_FASE7_RMAN_BACKUP.md)
9. [GUIDA_FASE8_ENTERPRISE_MANAGER_13C.md](./GUIDA_FASE8_ENTERPRISE_MANAGER_13C.md)

### 3) Sprint GoldenGate esteso (40 test)

- Guida principale: [GUIDA_FASE5_GOLDENGATE.md](./GUIDA_FASE5_GOLDENGATE.md)
- Template log test: [TESTLOG_GOLDENGATE_TEMPLATE.md](./TESTLOG_GOLDENGATE_TEMPLATE.md)
- Pianificazione giornaliera: [PIANO_STUDIO_GIORNALIERO.md](./PIANO_STUDIO_GIORNALIERO.md) (addendum operativo GoldenGate)

### 4) Operazioni avanzate + Cloud + esami

1. Switchover / Failover / Migrazione: [GUIDA_SWITCHOVER_COMPLETO.md](./GUIDA_SWITCHOVER_COMPLETO.md), [GUIDA_FAILOVER_E_REINSTATE.md](./GUIDA_FAILOVER_E_REINSTATE.md), [GUIDA_MIGRAZIONE_GOLDENGATE.md](./GUIDA_MIGRAZIONE_GOLDENGATE.md)
2. Cloud e MAA: [GUIDA_GOLDENGATE_OCI_ARM.md](./GUIDA_GOLDENGATE_OCI_ARM.md), [GUIDA_MAA_BEST_PRACTICES.md](./GUIDA_MAA_BEST_PRACTICES.md)
3. Esami e PostgreSQL: [GUIDA_ESAME_REVIEW.md](./GUIDA_ESAME_REVIEW.md), [GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md](./GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md)

> **Consiglio**: il piano completo e aggiornato e' su [PIANO_STUDIO_GIORNALIERO.md](./PIANO_STUDIO_GIORNALIERO.md), 8 settimane (40 giorni) a 3 ore/giorno.

---

## Roadmap Studio Ribilanciata (8 settimane, 3h/giorno)

Questa roadmap sintetica allinea il README al piano aggiornato in [PIANO_STUDIO_GIORNALIERO.md](./PIANO_STUDIO_GIORNALIERO.md).

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
- catalogo certificazioni Oracle (EN): https://education.oracle.com/sites/default/files/2026-02/Oracle%20Certification%20Catalog.pdf

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

- guida: [GUIDA_FASE5_GOLDENGATE.md](./GUIDA_FASE5_GOLDENGATE.md)
- template testlog: [TESTLOG_GOLDENGATE_TEMPLATE.md](./TESTLOG_GOLDENGATE_TEMPLATE.md)

---

## Indice Completo

### Teoria (Leggi PRIMA di costruire)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 1 | **Architettura Oracle** | [GUIDA_ARCHITETTURA](./GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo Log, Undo, Temp, ASM, Cache Fusion |
| 2 | **Comandi DBA** | [GUIDA_COMANDI_DBA](./GUIDA_COMANDI_DBA.md) | 100+ query SQL, script Oracle Base, health check |
| 3 | **CDB/PDB, Utenti, EM Express** | [GUIDA_CDB_PDB_UTENTI](./GUIDA_CDB_PDB_UTENTI.md) | Multitenant, PDB create/clone/plug, utenti, ruoli, SQL Tuning |
| 4 | **Piano di Studio** | [PIANO_STUDIO](./PIANO_STUDIO_GIORNALIERO.md) | 8 settimane (40 giorni) x 3h/giorno, roadmap e milestone |
| 5 | **Top 100 Script DBA** | [TOP_100_SCRIPT](./TOP_100_SCRIPT_DBA.md) | I 100 script piu utili ogni giorno - lock, AWR, tuning, ASM, I/O |
| 6 | **Attivita Lab RAC** | [ATTIVITA_LAB](./GUIDA_ATTIVITA_LAB_RAC.md) | 10 esercizi pratici: health check, AWR, switchover, GG test |

---

### Costruzione Lab (Segui in ordine!)

| # | Fase | File | Cosa Fai |
|---|---|---|---|
| 7 | **Fase 0** | [SETUP MACCHINE](./GUIDA_FASE0_SETUP_MACCHINE.md) | Crea VM VirtualBox, DNS Dnsmasq, dischi ASM oracleasm, installa OL 7.9 |
| 8 | **Fase 1** | [PREPARAZIONE OS](./GUIDA_FASE1_PREPARAZIONE_OS.md) | Configura rete, DNS, utenti, SSH, kernel |
| 9 | **Fase 2** | [GRID + RAC](./GUIDA_FASE2_GRID_E_RAC.md) | Installa Grid, ASM, DB Software, crea RACDB |
| 10 | **Fase 3** | [RAC STANDBY](./GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener statico, MRP |
| 11 | **Fase 4** | [DATA GUARD](./GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Active Data Guard |
| 12 | **Fase 5** | [GOLDENGATE](./GUIDA_FASE5_GOLDENGATE.md) | Extract sullo Standby, Pump, Replicat Target + test matrix estesa (40 scenari) |
| 13 | **Fase 6** | [TEST VERIFICA](./GUIDA_FASE6_TEST_VERIFICA.md) | Test DG + GG + stress + node crash |
| 14 | **Fase 7** | [RMAN BACKUP](./GUIDA_FASE7_RMAN_BACKUP.md) | Strategia backup, script, cron, BCT, restore |
| 15 | **Fase 8** | [ENTERPRISE MANAGER](./GUIDA_FASE8_ENTERPRISE_MANAGER_13C.md) | Setup Cloud Control 13.5: OMS, Agent, target discovery, alerting, jobs |
| 16 | **RMAN Completa** | [GUIDA_RMAN_19C](./GUIDA_RMAN_COMPLETA_19C.md) | Runbook RMAN completo + test lab: config, backup, validate, recovery, catalog |

---

### Operazioni Avanzate (Dopo il lab base)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 17 | **Switchover** | [GUIDA_SWITCHOVER](./GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback passo-passo |
| 18 | **Failover + Reinstate** | [GUIDA_FAILOVER](./GUIDA_FAILOVER_E_REINSTATE.md) | Failover emergenza, reinstate, FSFO |
| 19 | **Migrazione GG** | [GUIDA_MIGRAZIONE](./GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration con GoldenGate |
| 20 | **Patching & RU** | [GUIDA_PATCHING](./GUIDA_PATCHING_RAC.md) | Combo Patch, OJVM, e pulizia filesystem |
| 21 | **Upgrade RU** | [GUIDA_UPGRADE_RU](./GUIDA_UPGRADE_RU_RAC.md) | Skip version, rollback auto, upgrade workflow |
| 22 | **Attivita Lab RAC** | [GUIDA_ATTIVITA_LAB](./GUIDA_ATTIVITA_LAB_RAC.md) | 10 esercizi pratici sul lab: health check, AWR, lock, switchover, GG test |

---

### Cloud e DBA Professionale (Settimana 5)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 23 | **Cloud GoldenGate** | [GUIDA_CLOUD_GG](./GUIDA_GOLDENGATE_OCI_ARM.md) | OCI Free Tier ARM, setup ibrido 23ai Free, SSH tunnel |
| 24 | **Attivita DBA** | [GUIDA_ATTIVITA_DBA](./GUIDA_ATTIVITA_DBA.md) | Batch Jobs, AWR/ADDM/ASH, Patching, DataPump, Security |
| 25 | **MAA Best Practices** | [GUIDA_MAA](./GUIDA_MAA_BEST_PRACTICES.md) | Validazione lab vs Oracle MAA Gold |

---

### Esame + Migrazione PostgreSQL (Settimane 6-8)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 26 | **Ripasso Esame** | [GUIDA_ESAME_REVIEW](./GUIDA_ESAME_REVIEW.md) | Tutti gli argomenti 1Z0-082 + 1Z0-083 (Admin + SQL + DBA Pro 2) |
| 27 | **Oracle -> PostgreSQL** | [GUIDA_MIGRAZIONE_PG](./GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) | Migrazione Oracle->PostgreSQL con GoldenGate, ora2pg, ODBC |

---

### Riferimento e Approfondimento

| Documento | File | Descrizione |
|---|---|---|
| **Da Lab a Produzione** | [GUIDA_PRODUZIONE](./GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security, monitoring |
| **Validazione Oracle BP** | [VALIDAZIONE_BP](./VALIDAZIONE_BEST_PRACTICES.md) | Audit 54 punti, scorecard 98%, GUI vs CLI |
| **Analisi Oracle Base** | [ANALISI_ORACLEBASE](./ANALISI_ORACLEBASE_VAGRANT.md) | Confronto con Oracle Base Vagrant |
| **Gestione Dischi ASM** | [GUIDA_ASM_DISK](./GUIDA_AGGIUNTA_DISCHI_ASM.md) | Aggiungere/Creare dischi ASM (ASMLib + AFD) |
| **Guida RMAN Completa 19c** | [GUIDA_RMAN_19C](./GUIDA_RMAN_COMPLETA_19C.md) | Backup, restore, recovery, Data Guard e test pratici con fonti ufficiali Oracle |
| **Guida Fase 8 Enterprise Manager** | [GUIDA_EM13C](./GUIDA_FASE8_ENTERPRISE_MANAGER_13C.md) | Setup completo OEM Cloud Control 13.5, monitoraggio operativo e runbook test |
| **Template Test GoldenGate** | [TESTLOG_GG_TEMPLATE](./TESTLOG_GOLDENGATE_TEMPLATE.md) | Template pronto per tracciare PASS/FAIL, lag, evidenze e fix |

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

> Scarica TUTTO prima di iniziare! Guarda la lista completa in [FASE 0](./GUIDA_FASE0_SETUP_MACCHINE.md).

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

