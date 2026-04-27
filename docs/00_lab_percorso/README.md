# 🗺️ Percorso Lab Oracle RAC — Indice Centralizzato

> Questo indice è il punto di partenza unico per il lab Oracle RAC.
> Segui le fasi **in ordine**: ogni fase dipende dalla precedente.

---

## Prerequisiti Generali

| Requisito | Dettaglio |
|---|---|
| **PC Host** | 32 GB RAM consigliati (minimo 16 GB per 2 nodi RAC) |
| **VirtualBox** | Ultima versione stabile |
| **Software Oracle** | Grid 19c, DB 19c, OEM 24ai, GoldenGate 19c/21c |
| **OS Guest** | Oracle Linux 7.9 |
| **Client SSH** | MobaXterm (gratuito) con X11-Forwarding |

---

## 🚀 Fasi del Lab

| # | Fase | Guida | Cosa Fai | Tempo |
|---|---|---|---|---|
| **0** | Setup Macchine | [GUIDA_FASE0](../01_lab_setup/GUIDA_FASE0_SETUP_MACCHINE.md) | Crea VM VirtualBox, DNS, dischi ASM | 3-4h |
| **1** | Preparazione OS | [GUIDA_FASE1](../01_lab_setup/GUIDA_FASE1_PREPARAZIONE_OS.md) | Rete, utenti, SSH, kernel, Golden Image, cloni | 2-3h |
| **2** | Grid + RAC | [GUIDA_FASE2](../01_lab_setup/GUIDA_FASE2_GRID_E_RAC.md) | Installazione Grid 19c, disk group, RAC DB, patching | 4-6h |
| **3** | RAC Standby | [GUIDA_FASE3](../02_high_availability/GUIDA_FASE3_RAC_STANDBY.md) | Cluster standby, RMAN Duplicate, SRL, MRP | 4-6h |
| **4** | Data Guard | [GUIDA_FASE4](../02_high_availability/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | Broker, switchover, failover, protection mode | 2-3h |
| **5** | RMAN Backup | [GUIDA_FASE5](../03_backup_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Strategia incrementale, test recovery, health check | 3-4h |
| **6** | Enterprise Manager | [GUIDA_FASE6](../08_monitoring/GUIDA_FASE6_ENTERPRISE_MANAGER.md) | OEM 24ai, monitoring, agent deploy, EMCLI | 4-6h |
| **7** | GoldenGate | [GUIDA_FASE7](../07_replication/GUIDA_FASE7_GOLDENGATE.md) | Replica logica Oracle→Oracle e Oracle→PostgreSQL | 4-6h |
| **8** | Test Verifica | [GUIDA_FASE8](../01_lab_setup/GUIDA_FASE8_TEST_VERIFICA.md) | Test end-to-end DG + RMAN + EM + GG | 2-3h |

---

## 📐 Architettura del Lab

```
╔══════════════════════════════════════════════════════╗
║              VirtualBox (Host PC)                    ║
║                                                      ║
║  ┌──────┐  ┌──────┐  ┌───────┐  ┌───────┐          ║
║  │ dns  │  │ rac1 │  │ rac2  │  │Host010│          ║
║  │ .50  │  │ .101 │  │ .102  │  │(OEM)  │          ║
║  │1G/1C │  │8G/4C │  │8G/4C  │  │8G/4C  │          ║
║  └──┬───┘  └──┬───┘  └──┬────┘  └──┬────┘          ║
║     │         │         │          │                ║
║     └────┬────┴────┬────┘          │                ║
║          │         │               │                ║
║     ┌────┴────┐ ┌──┴──────┐  ┌────┴─────┐          ║
║     │Host-Only│ │ASM Disks│  │OEM 24ai  │          ║
║     │.56.0/24 │ │CRS+DATA │  │Repository│          ║
║     └─────────┘ │+RECO    │  │DB 19c    │          ║
║                 └─────────┘  └──────────┘          ║
║                                                      ║
║  ┌───────┐  ┌───────┐                              ║
║  │racstby1│  │racstby2│   (Standby Cluster)          ║
║  │ .111  │  │ .112  │                              ║
║  └──┬────┘  └──┬────┘                              ║
║     └─────┬────┘                                    ║
║     ┌─────┴─────┐                                   ║
║     │ASM Stby   │                                   ║
║     │CRS+DATA   │                                   ║
║     │+RECO      │                                   ║
║     └───────────┘                                   ║
╚══════════════════════════════════════════════════════╝
```

---

## 🔗 Risorse

- [README principale del progetto](../../README.md)
- [Checklist DBA](../10_esami_carriera/archivio_extra/GUIDA_CHECKLIST_ATTIVITA_DBA.md)
- [Catalogo Attività DBA](../10_esami_carriera/archivio_extra/GUIDA_CATALOGO_ATTIVITA_DBA.md)
- [Archivio Script SQL](../../scripts/)

---

*Ultimo aggiornamento: Aprile 2026*
