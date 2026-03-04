# ðŸ—ï¸ Oracle RAC + Data Guard + GoldenGate + Cloud â€” Guida Definitiva

> Guida completa passo-passo per costruire un'architettura Oracle Enterprise in laboratorio.
> **Validata al 98%** contro le best practice ufficiali Oracle MAA Gold.

ðŸ‡¬ðŸ‡§ **[English version available here â†’](./en/README.md)**

---

## ðŸš€ DA DOVE INIZIARE

```
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘                          PERCORSO DI STUDIO                                  â•‘
â• â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•£
â•‘                                                                              â•‘
â•‘  ðŸ“– STEP 0: LEGGI PRIMA LA TEORIA (2 ore)                                  â•‘
â•‘  â”‚                                                                           â•‘
â•‘  â”‚  â‘  GUIDA_ARCHITETTURA_ORACLE.md  â† SGA, PGA, Redo, Undo, Temp, ASM      â•‘
â•‘  â”‚  â‘¡ GUIDA_COMANDI_DBA.md          â† Query SQL essenziali, script DBA      â•‘
â•‘  â”‚  â‘¢ PIANO_STUDIO_GIORNALIERO.md   â† Il TUO piano: 22 giorni Ã— 3h        â•‘
â•‘  â”‚                                                                           â•‘
â•‘  â–¼                                                                           â•‘
â•‘  ðŸ”§ STEP 1-7: COSTRUISCI IL LAB (â€ªSettimane 1-4)                            â•‘
â•‘  â”‚                                                                           â•‘
â•‘  â”‚  â‘£ FASE 0 â†’ Setup Macchine VirtualBox                                    â•‘
â•‘  â”‚  â‘¤ FASE 1 â†’ Preparazione OS (rete, DNS, utenti, SSH)                    â•‘
â•‘  â”‚  â‘¥ FASE 2 â†’ Grid Infrastructure + RAC Database                           â•‘
â•‘  â”‚  â‘¦ FASE 3 â†’ RAC Standby (RMAN Duplicate)                                â•‘
â•‘  â”‚  â‘§ FASE 4 â†’ Data Guard (DGMGRL, ADG)                                    â•‘
â•‘  â”‚  â‘¨ FASE 5 â†’ GoldenGate (Extract, Pump, Replicat)                        â•‘
â•‘  â”‚  â‘© FASE 6 â†’ Test e Verifica end-to-end                                  â•‘
â•‘  â”‚  â‘ª FASE 7 â†’ RMAN Backup Strategy                                        â•‘
â•‘  â”‚                                                                           â•‘
â•‘  â–¼                                                                           â•‘
â•‘  ðŸ—ï¸ STEP 8-11: OPERAZIONI AVANZATE (Settimana 4)                           â•‘
â•‘  â”‚                                                                           â•‘
â•‘  â”‚  â‘« Switchover Data Guard                                                 â•‘
â•‘  â”‚  â‘¬ Failover + Reinstate                                                  â•‘
â•‘  â”‚  â‘­ Migrazione zero-downtime con GoldenGate                               â•‘
â•‘  â”‚  â‘® Listener, Services, DBA Toolkit                                       â•‘
â•‘  â”‚                                                                           â•‘
â•‘  â–¼                                                                           â•‘
â•‘  â˜ï¸ STEP 12-14: CLOUD + DBA PRO (Settimana 5)                              â•‘
â•‘  â”‚                                                                           â•‘
â•‘  â”‚  â‘¯ Cloud GoldenGate su OCI ARM Free Tier                                â•‘
â•‘  â”‚  â‘° AttivitÃ  DBA (Batch, AWR, Patching, DataPump, Security)              â•‘
â•‘  â”‚  â‘± MAA Best Practices + Validazione                                      â•‘
â•‘  â”‚                                                                           â•‘
â•‘  â–¼                                                                           â•‘
â•‘  ðŸŽ“ COMPLETATO! â†’ Leggi GUIDA_DA_LAB_A_PRODUZIONE.md per il sizing reale   â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
```

> **ðŸ’¡ Consiglio**: Segui il [Piano di Studio Giornaliero](./PIANO_STUDIO_GIORNALIERO.md) â€” ti dice esattamente cosa fare ogni giorno in 3 ore.

---

## ðŸ“š Indice Completo â€” Tutte le Guide

### ðŸ“– Teoria (Leggi PRIMA di costruire)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| â‘  | **Architettura Oracle** | [GUIDA_ARCHITETTURA](./GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo Log, **Undo**, **Temp**, ASM, Cache Fusion |
| â‘¡ | **Comandi DBA** | [GUIDA_COMANDI_DBA](./GUIDA_COMANDI_DBA.md) | 100+ query SQL, script Oracle Base, health check |
| â‘¢ | **CDB/PDB, Utenti, EM Express** | [GUIDA_CDB_PDB](./GUIDA_CDB_PDB_UTENTI.md) | Multitenant, PDB create/clone/plug, utenti, ruoli, SQL Tuning |
| â‘£ | **Piano di Studio** | [PIANO_STUDIO](./PIANO_STUDIO_GIORNALIERO.md) | 25 giorni Ã— 3h/giorno (5 settimane), tips CV |

---

### ðŸ”§ Costruzione Lab (Segui in ordine!)

| # | Fase | File | Cosa Fai |
|---|---|---|---|
| â‘£ | **Fase 0** | [SETUP MACCHINE](./GUIDA_FASE0_SETUP_MACCHINE.md) | Crea VM VirtualBox, dischi ASM, installa OL 7.9 |
| â‘¤ | **Fase 1** | [PREPARAZIONE OS](./GUIDA_FASE1_PREPARAZIONE_OS.md) | Configura rete, DNS BIND, utenti, SSH, kernel |
| â‘¥ | **Fase 2** | [GRID + RAC](./GUIDA_FASE2_GRID_E_RAC.md) | Installa Grid, ASM, DB Software, crea RACDB |
| â‘¦ | **Fase 3** | [RAC STANDBY](./GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener statico, MRP |
| â‘§ | **Fase 4** | [DATA GUARD](./GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Active Data Guard |
| â‘¨ | **Fase 5** | [GOLDENGATE](./GUIDA_FASE5_GOLDENGATE.md) | Extract sullo Standby, Pump, Replicat Target |
| â‘© | **Fase 6** | [TEST VERIFICA](./GUIDA_FASE6_TEST_VERIFICA.md) | Test DG + GG + stress + node crash |
| â‘ª | **Fase 7** | [RMAN BACKUP](./GUIDA_FASE7_RMAN_BACKUP.md) | Strategia backup, script, cron, BCT, restore |

---

### ðŸ—ï¸ Operazioni Avanzate (Dopo il lab base)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| â‘« | **Switchover** | [GUIDA_SWITCHOVER](./GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback passo-passo |
| â‘¬ | **Failover + Reinstate** | [GUIDA_FAILOVER](./GUIDA_FAILOVER_E_REINSTATE.md) | Failover emergenza, reinstate, FSFO |
| â‘­ | **Migrazione GG** | [GUIDA_MIGRAZIONE](./GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration con GoldenGate |
| â‘® | **Listener + Services** | [GUIDA_LISTENER_DBA](./GUIDA_LISTENER_SERVICES_DBA.md) | Listener RAC, SCAN, Services, DBA Toolkit |

---

### â˜ï¸ Cloud e DBA Professionale (Settimana 5)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| â‘¯ | **Cloud GoldenGate** | [GUIDA_CLOUD_GG](./GUIDA_CLOUD_GOLDENGATE.md) | OCI Free Tier ARM, setup ibrido, SSH tunnel |
| â‘° | **AttivitÃ  DBA** | [GUIDA_ATTIVITA_DBA](./GUIDA_ATTIVITA_DBA.md) | Batch Jobs, AWR/ADDM/ASH, Patching, DataPump, Security |
| â‘± | **MAA Best Practices** | [GUIDA_MAA](./GUIDA_MAA_BEST_PRACTICES.md) | Validazione lab vs Oracle MAA Gold |

---

### ðŸ“‹ Riferimento e Approfondimento

| Documento | File | Descrizione |
|---|---|---|
| **Da Lab a Produzione** | [GUIDA_PRODUZIONE](./GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security, monitoring |
| **Validazione Oracle BP** | [VALIDAZIONE_BP](./VALIDAZIONE_BEST_PRACTICES.md) | Audit 54 punti, scorecard 98%, GUI vs CLI |
| **Analisi Oracle Base** | [ANALISI_ORACLEBASE](./ANALISI_ORACLEBASE_VAGRANT.md) | Confronto con Oracle Base Vagrant |

---

## Architettura Complessiva

```
â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
â•‘                              VIRTUALBOX HOST (Il tuo PC)                                â•‘
â•‘                                                                                          â•‘
â•‘   LAN 192.168.1.0/24 (Bridged)          Host-Only 192.168.1.0/24 (Interconnect)          â•‘
â•‘   â•â•â•â•â•â•â•â•â•â•â•â•¤â•â•â•â•â•â•â•â•â•â•â•â•¤â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•¤â•â•â•â•â•â•â•â•â•â•â•â•¤â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•           â•‘
â•‘              â”‚           â”‚                   â”‚           â”‚                               â•‘
â•‘   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â” â”Œâ”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”  â”Œâ”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â” â”Œâ”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                   â•‘
â•‘   â”‚    rac1       â”‚ â”‚    rac2       â”‚  â”‚  rac1     â”‚ â”‚   rac2      â”‚                   â•‘
â•‘   â”‚ .101   VIP.111â”‚ â”‚ .102   VIP.112â”‚  â”‚ 192.168.1.1â”‚ â”‚ 192.168.1.2 â”‚                   â•‘
â•‘   â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”˜ â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”˜  â””â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”˜ â””â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”˜                   â•‘
â•‘          â”‚                 â”‚           Cache Fusion          â”‚                           â•‘
â•‘          â”‚  â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¤           (GCS/GES)             â”‚                           â•‘
â•‘          â”‚  â”‚ SCAN: .120   â”‚â—„â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â–ºâ”‚                           â•‘
â•‘          â”‚  â”‚       .121   â”‚                                 â”‚                           â•‘
â•‘          â”‚  â”‚       .122   â”‚                                 â”‚                           â•‘
â•‘          â”‚  â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                                 â”‚                           â•‘
â•‘   â”Œâ”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”                   â•‘
â•‘   â”‚                    RAC PRIMARY (RACDB)                          â”‚                   â•‘
â•‘   â”‚         Grid Infrastructure 19c + Release Update               â”‚                   â•‘
â•‘   â”‚         Database 19c + RU + OJVM Patch                         â”‚                   â•‘
â•‘   â”‚         ASM: +CRS (5GB) â”‚ +DATA (20GB) â”‚ +FRA (15GB)          â”‚                   â•‘
â•‘   â”‚         Force Logging: ON â”‚ Archivelog: ON                     â”‚                   â•‘
â•‘   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                   â•‘
â•‘                              â”‚                                                          â•‘
â•‘                    Data Guardâ”‚  Redo Shipping (LGWR ASYNC)                              â•‘
â•‘                              â–¼                                                          â•‘
â•‘   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”´â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                   â•‘
â•‘   â”‚                   RAC STANDBY (RACDB_STBY)                     â”‚                   â•‘
â•‘   â”‚         racstby1 (.201, VIP .211) + racstby2 (.202, VIP .212) â”‚                   â•‘
â•‘   â”‚         Active Data Guard: READ ONLY WITH APPLY                â”‚                   â•‘
â•‘   â”‚         SCAN: racstby-scan (.220, .221, .222)                  â”‚                   â•‘
â•‘   â”‚         RMAN Backup + GG Extract (Integrated) + GG Data Pump  â”‚                   â•‘
â•‘   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”¬â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                   â•‘
â•‘                                               â”‚                                        â•‘
â•‘                                               â–¼                                        â•‘
â•‘   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                    â•‘
â•‘   â”‚                    TARGET DB (dbtarget)                        â”‚                    â•‘
â•‘   â”‚         IP: 192.168.1.150 â”‚ Single Instance â”‚ Oracle 19c      â”‚                    â•‘
â•‘   â”‚         GG Replicat (Integrated) â”‚ RMAN Backup âœ…             â”‚                    â•‘
â•‘   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                    â•‘
â•‘                                                                                        â•‘
â•‘   â•â•â•â•â•â•â•â•â•â•â• SSH Tunnel / VPN â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•                  â•‘
â•‘                                               â”‚                                        â•‘
â•‘   ðŸŒ ORACLE CLOUD (OCI Free Tier)              â–¼                                        â•‘
â•‘   â”Œâ”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”                    â•‘
â•‘   â”‚                    OCI ARM DB (oci-dbcloud)                    â”‚                    â•‘
â•‘   â”‚         VM.Standard.A1.Flex â”‚ 4 OCPU ARM â”‚ 24 GB RAM          â”‚                    â•‘
â•‘   â”‚         Oracle Linux 8 (aarch64) â”‚ Oracle 19c EE              â”‚                    â•‘
â•‘   â”‚         GG Replicat (Integrated) â”‚ Target Cloud â˜ï¸            â”‚                    â•‘
â•‘   â””â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”˜                    â•‘
â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
```

---

## ðŸ”§ Prerequisiti Software

| Software | Versione | Download |
|---|---|---|
| Oracle Linux | 7.9 (VM) / 8.10 (fisico) | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Oracle Grid Infrastructure | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) | [eDelivery](https://edelivery.oracle.com) |
| Oracle GoldenGate | 19c o 21c | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | Ultimo | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

> **â¬‡ï¸ Scarica TUTTO prima di iniziare!** Guarda la lista completa in [FASE 0](./GUIDA_FASE0_SETUP_MACCHINE.md#software-da-scaricare-prima-di-iniziare).

---

## ðŸ“‹ Piano IP

| Hostname | IP Pubblica | IP Privata | IP VIP |
|---|---|---|---|
| rac1 | 192.168.56.101 | 192.168.1.1 | 192.168.56.103 |
| rac2 | 192.168.56.102 | 192.168.1.2 | 192.168.56.104 |
| rac-scan | 192.168.56.105-122 | â€” | â€” |
| racstby1 | 192.168.56.111 | 192.168.1.11 | 192.168.1.211 |
| racstby2 | 192.168.56.112 | 192.168.1.12 | 192.168.1.212 |
| racstby-scan | 192.168.1.220-222 | â€” | â€” |
| dbtarget | 192.168.1.150 | â€” | â€” |
| oci-dbcloud | IP pubblica OCI | 10.0.0.2 (VCN) | â€” |
