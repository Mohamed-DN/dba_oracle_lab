# 🏗️ Oracle RAC + Data Guard + GoldenGate + Cloud — Guida Definitiva

> Guida completa passo-passo per costruire un'architettura Oracle Enterprise in laboratorio.
> **Validata al 98%** contro le best practice ufficiali Oracle MAA Gold.

🇬🇧 **[English version available here →](./en/README.md)**

---

## 🚀 DA DOVE INIZIARE

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                          PERCORSO DI STUDIO                                  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  📖 STEP 0: LEGGI PRIMA LA TEORIA (2 ore)                                  ║
║  │                                                                           ║
║  │  ① GUIDA_ARCHITETTURA_ORACLE.md  ← SGA, PGA, Redo, Undo, Temp, ASM      ║
║  │  ② GUIDA_COMANDI_DBA.md          ← Query SQL essenziali, script DBA      ║
║  │  ③ PIANO_STUDIO_GIORNALIERO.md   ← Il TUO piano: 22 giorni × 3h        ║
║  │                                                                           ║
║  ▼                                                                           ║
║  🔧 STEP 1-7: COSTRUISCI IL LAB (‪Settimane 1-4)                            ║
║  │                                                                           ║
║  │  ④ FASE 0 → Setup Macchine VirtualBox                                    ║
║  │  ⑤ FASE 1 → Preparazione OS (rete, DNS, utenti, SSH)                    ║
║  │  ⑥ FASE 2 → Grid Infrastructure + RAC Database                           ║
║  │  ⑦ FASE 3 → RAC Standby (RMAN Duplicate)                                ║
║  │  ⑧ FASE 4 → Data Guard (DGMGRL, ADG)                                    ║
║  │  ⑨ FASE 5 → GoldenGate (Extract, Pump, Replicat)                        ║
║  │  ⑩ FASE 6 → Test e Verifica end-to-end                                  ║
║  │  ⑪ FASE 7 → RMAN Backup Strategy                                        ║
║  │                                                                           ║
║  ▼                                                                           ║
║  🏗️ STEP 8-11: OPERAZIONI AVANZATE (Settimana 4)                           ║
║  │                                                                           ║
║  │  ⑫ Switchover Data Guard                                                 ║
║  │  ⑬ Failover + Reinstate                                                  ║
║  │  ⑭ Migrazione zero-downtime con GoldenGate                               ║
║  │  ⑮ Listener, Services, DBA Toolkit                                       ║
║  │                                                                           ║
║  ▼                                                                           ║
║  ☁️ STEP 12-14: CLOUD + DBA PRO (Settimana 5)                              ║
║  │                                                                           ║
║  │  ⑯ Cloud GoldenGate su OCI ARM Free Tier                                ║
║  │  ⑰ Attività DBA (Batch, AWR, Patching, DataPump, Security)              ║
║  │  ⑱ MAA Best Practices + Validazione                                      ║
║  │                                                                           ║
║  ▼                                                                           ║
║  🎓 COMPLETATO! → Leggi GUIDA_DA_LAB_A_PRODUZIONE.md per il sizing reale   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

> **💡 Consiglio**: Segui il [Piano di Studio Giornaliero](./PIANO_STUDIO_GIORNALIERO.md) — ti dice esattamente cosa fare ogni giorno in 3 ore.

---

## 📚 Indice Completo — Tutte le Guide

### 📖 Teoria (Leggi PRIMA di costruire)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| ① | **Architettura Oracle** | [GUIDA_ARCHITETTURA](./GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo Log, **Undo**, **Temp**, ASM, Cache Fusion |
| ② | **Comandi DBA** | [GUIDA_COMANDI_DBA](./GUIDA_COMANDI_DBA.md) | 100+ query SQL, script Oracle Base, health check |
| ③ | **CDB/PDB, Utenti, EM Express** | [GUIDA_CDB_PDB](./GUIDA_CDB_PDB_UTENTI.md) | Multitenant, PDB create/clone/plug, utenti, ruoli, SQL Tuning |
| ④ | **Piano di Studio** | [PIANO_STUDIO](./PIANO_STUDIO_GIORNALIERO.md) | 25 giorni × 3h/giorno (5 settimane), tips CV |

---

### 🔧 Costruzione Lab (Segui in ordine!)

| # | Fase | File | Cosa Fai |
|---|---|---|---|
| ④ | **Fase 0** | [SETUP MACCHINE](./GUIDA_FASE0_SETUP_MACCHINE.md) | Crea VM VirtualBox, dischi ASM, installa OL 7.9 |
| ⑤ | **Fase 1** | [PREPARAZIONE OS](./GUIDA_FASE1_PREPARAZIONE_OS.md) | Configura rete, DNS BIND, utenti, SSH, kernel |
| ⑥ | **Fase 2** | [GRID + RAC](./GUIDA_FASE2_GRID_E_RAC.md) | Installa Grid, ASM, DB Software, crea RACDB |
| ⑦ | **Fase 3** | [RAC STANDBY](./GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener statico, MRP |
| ⑧ | **Fase 4** | [DATA GUARD](./GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Active Data Guard |
| ⑨ | **Fase 5** | [GOLDENGATE](./GUIDA_FASE5_GOLDENGATE.md) | Extract sullo Standby, Pump, Replicat Target |
| ⑩ | **Fase 6** | [TEST VERIFICA](./GUIDA_FASE6_TEST_VERIFICA.md) | Test DG + GG + stress + node crash |
| ⑪ | **Fase 7** | [RMAN BACKUP](./GUIDA_FASE7_RMAN_BACKUP.md) | Strategia backup, script, cron, BCT, restore |

---

### 🏗️ Operazioni Avanzate (Dopo il lab base)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| ⑫ | **Switchover** | [GUIDA_SWITCHOVER](./GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback passo-passo |
| ⑬ | **Failover + Reinstate** | [GUIDA_FAILOVER](./GUIDA_FAILOVER_E_REINSTATE.md) | Failover emergenza, reinstate, FSFO |
| ⑭ | **Migrazione GG** | [GUIDA_MIGRAZIONE](./GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration con GoldenGate |
| ⑮ | **Listener + Services** | [GUIDA_LISTENER_DBA](./GUIDA_LISTENER_SERVICES_DBA.md) | Listener RAC, SCAN, Services, DBA Toolkit |

---

### ☁️ Cloud e DBA Professionale (Settimana 5)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| ⑯ | **Cloud GoldenGate** | [GUIDA_CLOUD_GG](./GUIDA_CLOUD_GOLDENGATE.md) | OCI Free Tier ARM, setup ibrido, SSH tunnel |
| ⑰ | **Attività DBA** | [GUIDA_ATTIVITA_DBA](./GUIDA_ATTIVITA_DBA.md) | Batch Jobs, AWR/ADDM/ASH, Patching, DataPump, Security |
| ⑱ | **MAA Best Practices** | [GUIDA_MAA](./GUIDA_MAA_BEST_PRACTICES.md) | Validazione lab vs Oracle MAA Gold |

---

### 📋 Riferimento e Approfondimento

| Documento | File | Descrizione |
|---|---|---|
| **Da Lab a Produzione** | [GUIDA_PRODUZIONE](./GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security, monitoring |
| **Validazione Oracle BP** | [VALIDAZIONE_BP](./VALIDAZIONE_BEST_PRACTICES.md) | Audit 54 punti, scorecard 98%, GUI vs CLI |
| **Analisi Oracle Base** | [ANALISI_ORACLEBASE](./ANALISI_ORACLEBASE_VAGRANT.md) | Confronto con Oracle Base Vagrant |

---

## Architettura Complessiva

```
╔══════════════════════════════════════════════════════════════════════════════════════════╗
║                              VIRTUALBOX HOST (Il tuo PC)                                ║
║                                                                                          ║
║   LAN 192.168.1.0/24 (Bridged)          Host-Only 10.10.10.0/24 (Interconnect)          ║
║   ═══════════╤═══════════╤═══════════════════╤═══════════╤════════════════════           ║
║              │           │                   │           │                               ║
║   ┌──────────┴────┐ ┌────┴──────────┐  ┌─────┴─────┐ ┌──┴──────────┐                   ║
║   │    rac1       │ │    rac2       │  │  rac1     │ │   rac2      │                   ║
║   │ .101   VIP.111│ │ .102   VIP.112│  │ 10.10.10.1│ │ 10.10.10.2 │                   ║
║   └──────┬────────┘ └──────┬────────┘  └─────┬─────┘ └──────┬─────┘                   ║
║          │                 │           Cache Fusion          │                           ║
║          │  ┌──────────────┤           (GCS/GES)             │                           ║
║          │  │ SCAN: .120   │◄═══════════════════════════════►│                           ║
║          │  │       .121   │                                 │                           ║
║          │  │       .122   │                                 │                           ║
║          │  └──────────────┘                                 │                           ║
║   ┌──────┴───────────────────────────────────────────────────┴──────┐                   ║
║   │                    RAC PRIMARY (RACDB)                          │                   ║
║   │         Grid Infrastructure 19c + Release Update               │                   ║
║   │         Database 19c + RU + OJVM Patch                         │                   ║
║   │         ASM: +CRS (5GB) │ +DATA (20GB) │ +FRA (15GB)          │                   ║
║   │         Force Logging: ON │ Archivelog: ON                     │                   ║
║   └──────────────────────────┬─────────────────────────────────────┘                   ║
║                              │                                                          ║
║                    Data Guard│  Redo Shipping (LGWR ASYNC)                              ║
║                              ▼                                                          ║
║   ┌──────────────────────────┴─────────────────────────────────────┐                   ║
║   │                   RAC STANDBY (RACDB_STBY)                     │                   ║
║   │         racstby1 (.201, VIP .211) + racstby2 (.202, VIP .212) │                   ║
║   │         Active Data Guard: READ ONLY WITH APPLY                │                   ║
║   │         SCAN: racstby-scan (.220, .221, .222)                  │                   ║
║   │         RMAN Backup + GG Extract (Integrated) + GG Data Pump  │                   ║
║   └───────────────────────────────────────────┬────────────────────┘                   ║
║                                               │                                        ║
║                                               ▼                                        ║
║   ┌───────────────────────────────────────────────────────────────┐                    ║
║   │                    TARGET DB (dbtarget)                        │                    ║
║   │         IP: 192.168.1.150 │ Single Instance │ Oracle 19c      │                    ║
║   │         GG Replicat (Integrated) │ RMAN Backup ✅             │                    ║
║   └───────────────────────────────────────────────────────────────┘                    ║
║                                                                                        ║
║   ═══════════ SSH Tunnel / VPN ══════════════════════════════════════                  ║
║                                               │                                        ║
║   🌐 ORACLE CLOUD (OCI Free Tier)              ▼                                        ║
║   ┌───────────────────────────────────────────────────────────────┐                    ║
║   │                    OCI ARM DB (oci-dbcloud)                    │                    ║
║   │         VM.Standard.A1.Flex │ 4 OCPU ARM │ 24 GB RAM          │                    ║
║   │         Oracle Linux 8 (aarch64) │ Oracle 19c EE              │                    ║
║   │         GG Replicat (Integrated) │ Target Cloud ☁️            │                    ║
║   └───────────────────────────────────────────────────────────────┘                    ║
╚══════════════════════════════════════════════════════════════════════════════════════════╝
```

---

## 🔧 Prerequisiti Software

| Software | Versione | Download |
|---|---|---|
| Oracle Linux | 7.9 (VM) / 8.10 (fisico) | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Oracle Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c o 21c | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | Ultimo | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> **⬇️ Scarica TUTTO prima di iniziare!** Guarda la lista completa in [FASE 0](./GUIDA_FASE0_SETUP_MACCHINE.md#software-da-scaricare-prima-di-iniziare).

---

## 📋 Piano IP

| Hostname | IP Pubblica | IP Privata | IP VIP |
|---|---|---|---|
| rac1 | 192.168.1.101 | 10.10.10.1 | 192.168.1.111 |
| rac2 | 192.168.1.102 | 10.10.10.2 | 192.168.1.112 |
| rac-scan | 192.168.1.120-122 | — | — |
| racstby1 | 192.168.1.201 | 10.10.10.11 | 192.168.1.211 |
| racstby2 | 192.168.1.202 | 10.10.10.12 | 192.168.1.212 |
| racstby-scan | 192.168.1.220-222 | — | — |
| dbtarget | 192.168.1.150 | — | — |
| oci-dbcloud | IP pubblica OCI | 10.0.0.2 (VCN) | — |
