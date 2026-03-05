# Oracle RAC + Data Guard + GoldenGate + Cloud - Guida Definitiva

> Guida completa passo-passo per costruire un'architettura Oracle Enterprise in laboratorio.
> **Validata al 98%** contro le best practice ufficiali Oracle MAA Gold.

---

## DA DOVE INIZIARE

**PERCORSO DI STUDIO**

```
STEP 0: LEGGI PRIMA LA TEORIA (2 ore)
  |
  |  1. GUIDA_ARCHITETTURA_ORACLE.md   <-- SGA, PGA, Redo, Undo, Temp, ASM
  |  2. GUIDA_COMANDI_DBA.md           <-- Query SQL essenziali, script DBA
  |  3. PIANO_STUDIO_GIORNALIERO.md    <-- Il TUO piano: 25 giorni x 3h
  |
  v
STEP 1-7: COSTRUISCI IL LAB (Settimane 1-4)
  |
  |  4. FASE 0 --> Setup Macchine VirtualBox (DNS, RAC, Storage)
  |  5. FASE 1 --> Preparazione OS (rete, DNS, utenti, SSH)
  |  6. FASE 2 --> Grid Infrastructure + RAC Database
  |  7. FASE 3 --> RAC Standby (RMAN Duplicate)
  |  8. FASE 4 --> Data Guard (DGMGRL, ADG)
  |  9. FASE 5 --> GoldenGate (Extract, Pump, Replicat)
  | 10. FASE 6 --> Test e Verifica end-to-end
  | 11. FASE 7 --> RMAN Backup Strategy
  |
  v
STEP 8-11: OPERAZIONI AVANZATE (Settimana 4)
  |
  | 12. Switchover Data Guard
  | 13. Failover + Reinstate
  | 14. Migrazione zero-downtime con GoldenGate
  | 15. Listener, Services, DBA Toolkit
  |
  v
STEP 12-14: CLOUD + DBA PRO (Settimana 5)
  |
  | 16. Cloud GoldenGate su OCI ARM Free Tier
  | 17. Attivita DBA (Batch, AWR, Patching, DataPump, Security)
  | 18. MAA Best Practices + Validazione
  |
  v
COMPLETATO! --> Leggi GUIDA_DA_LAB_A_PRODUZIONE.md per il sizing reale
```

> **Consiglio**: Segui il [Piano di Studio Giornaliero](./PIANO_STUDIO_GIORNALIERO.md) -- ti dice esattamente cosa fare ogni giorno in 3 ore.

---

## Indice Completo - Tutte le Guide

### Teoria (Leggi PRIMA di costruire)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 1 | **Architettura Oracle** | [GUIDA_ARCHITETTURA](./GUIDA_ARCHITETTURA_ORACLE.md) | SGA, PGA, Redo Log, Undo, Temp, ASM, Cache Fusion |
| 2 | **Comandi DBA** | [GUIDA_COMANDI_DBA](./GUIDA_COMANDI_DBA.md) | 100+ query SQL, script Oracle Base, health check |
| 3 | **CDB/PDB, Utenti, EM Express** | [GUIDA_CDB_PDB_UTENTI](./GUIDA_CDB_PDB_UTENTI.md) | Multitenant, PDB create/clone/plug, utenti, ruoli, SQL Tuning |
| 4 | **Piano di Studio** | [PIANO_STUDIO](./PIANO_STUDIO_GIORNALIERO.md) | 25 giorni x 3h/giorno (5 settimane), tips CV |

---

### Costruzione Lab (Segui in ordine!)

| # | Fase | File | Cosa Fai |
|---|---|---|---|
| 4 | **Fase 0** | [SETUP MACCHINE](./GUIDA_FASE0_SETUP_MACCHINE.md) | Crea VM VirtualBox, DNS Dnsmasq, dischi ASM oracleasm, installa OL 7.9 |
| 5 | **Fase 1** | [PREPARAZIONE OS](./GUIDA_FASE1_PREPARAZIONE_OS.md) | Configura rete, DNS, utenti, SSH, kernel |
| 6 | **Fase 2** | [GRID + RAC](./GUIDA_FASE2_GRID_E_RAC.md) | Installa Grid, ASM, DB Software, crea RACDB |
| 7 | **Fase 3** | [RAC STANDBY](./GUIDA_FASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener statico, MRP |
| 8 | **Fase 4** | [DATA GUARD](./GUIDA_FASE4_DATAGUARD_DGMGRL.md) | DGMGRL Broker, Active Data Guard |
| 9 | **Fase 5** | [GOLDENGATE](./GUIDA_FASE5_GOLDENGATE.md) | Extract sullo Standby, Pump, Replicat Target |
| 10 | **Fase 6** | [TEST VERIFICA](./GUIDA_FASE6_TEST_VERIFICA.md) | Test DG + GG + stress + node crash |
| 11 | **Fase 7** | [RMAN BACKUP](./GUIDA_FASE7_RMAN_BACKUP.md) | Strategia backup, script, cron, BCT, restore |

---

### Operazioni Avanzate (Dopo il lab base)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 12 | **Switchover** | [GUIDA_SWITCHOVER](./GUIDA_SWITCHOVER_COMPLETO.md) | Switchover + Switchback passo-passo |
| 13 | **Failover + Reinstate** | [GUIDA_FAILOVER](./GUIDA_FAILOVER_E_REINSTATE.md) | Failover emergenza, reinstate, FSFO |
| 14 | **Migrazione GG** | [GUIDA_MIGRAZIONE](./GUIDA_MIGRAZIONE_GOLDENGATE.md) | Zero-downtime migration con GoldenGate |
| 15 | **Listener + Services** | [GUIDA_LISTENER_DBA](./GUIDA_LISTENER_SERVICES_DBA.md) | Listener RAC, SCAN, Services, DBA Toolkit |

---

### Cloud e DBA Professionale (Settimana 5)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 16 | **Cloud GoldenGate** | [GUIDA_CLOUD_GG](./GUIDA_CLOUD_GOLDENGATE.md) | OCI Free Tier ARM, setup ibrido, SSH tunnel |
| 17 | **Attivita DBA** | [GUIDA_ATTIVITA_DBA](./GUIDA_ATTIVITA_DBA.md) | Batch Jobs, AWR/ADDM/ASH, Patching, DataPump, Security |
| 18 | **MAA Best Practices** | [GUIDA_MAA](./GUIDA_MAA_BEST_PRACTICES.md) | Validazione lab vs Oracle MAA Gold |

---

### Esame + Migrazione PostgreSQL (Settimana 6)

| # | Documento | File | Cosa Impari |
|---|---|---|---|
| 19 | **Ripasso Esame** | [GUIDA_ESAME_REVIEW](./GUIDA_ESAME_REVIEW.md) | Tutti gli argomenti 1Z0-082 + 1Z0-083 (Admin + SQL + DBA Pro 2) |
| 20 | **Oracle → PostgreSQL** | [GUIDA_MIGRAZIONE_PG](./GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) | Migrazione Oracle→PostgreSQL con GoldenGate, ora2pg, ODBC |

---

### Riferimento e Approfondimento

| Documento | File | Descrizione |
|---|---|---|
| **Da Lab a Produzione** | [GUIDA_PRODUZIONE](./GUIDA_DA_LAB_A_PRODUZIONE.md) | Sizing, HugePages, security, monitoring |
| **Validazione Oracle BP** | [VALIDAZIONE_BP](./VALIDAZIONE_BEST_PRACTICES.md) | Audit 54 punti, scorecard 98%, GUI vs CLI |
| **Analisi Oracle Base** | [ANALISI_ORACLEBASE](./ANALISI_ORACLEBASE_VAGRANT.md) | Confronto con Oracle Base Vagrant |

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
|  dbtarget + GoldenGate --> su cloud OCI o altra macchina                  |
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
