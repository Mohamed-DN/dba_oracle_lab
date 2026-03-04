# 🏗️ Oracle RAC + Data Guard + GoldenGate — Definitive Guide

> Complete step-by-step guide to build an Oracle Enterprise architecture in a lab environment.

## Overall Architecture

```
╔══════════════════════════════════════════════════════════════════════════════════════════╗
║                              VIRTUALBOX HOST (Your PC)                                   ║
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
║                    Data Guard│  Redo Shipping                                           ║
║                    (LGWR     │  ASYNC)                                                  ║
║                              │                                                          ║
║                              ▼                                                          ║
║   ┌──────────────────────────┴─────────────────────────────────────┐                   ║
║   │                   RAC STANDBY (RACDB_STBY)                     │                   ║
║   │         racstby1 (.201, VIP .211) + racstby2 (.202, VIP .212) │                   ║
║   │         Active Data Guard: READ ONLY WITH APPLY                │                   ║
║   │         SCAN: racstby-scan (.220, .221, .222)                  │                   ║
║   │         Centralized RMAN Backup ✅                             │                   ║
║   │                                                                │                   ║
║   │         ┌──────────────────┐                                   │                   ║
║   │         │  GG Extract      │                                   │                   ║
║   │         │  (Integrated)    │── Trail ──► GG Data Pump          │                   ║
║   │         └──────────────────┘              │                    │                   ║
║   └───────────────────────────────────────────┼────────────────────┘                   ║
║                                               │                                        ║
║                                               │ TCP/IP (port 7809)                     ║
║                                               ▼                                        ║
║   ┌───────────────────────────────────────────────────────────────┐                    ║
║   │                    TARGET DB (dbtarget)                        │                    ║
║   │         IP: 192.168.1.150                                     │                    ║
║   │         Single Instance │ Oracle 19c                          │                    ║
║   │         GG Replicat (Integrated) │ RMAN Backup ✅             │                    ║
║   └───────────────────────────────────────────────────────────────┘                    ║
╚══════════════════════════════════════════════════════════════════════════════════════════╝
```

### Data Flow

```
App/User ──► SCAN Listener ──► RAC Primary (RACDB1/RACDB2)
                                       │
                                       │ 1. INSERT/UPDATE/DELETE
                                       │ 2. Generates Redo Record
                                       │ 3. LGWR writes Redo Log
                                       ▼
                              ┌─────────────────┐
                              │  Online Redo Log │
                              │  (on +DATA ASM)  │
                              └────────┬────────┘
                                       │
                        ┌──────────────┼──────────────┐
                        ▼              ▼              ▼
               ┌────────────┐  ┌────────────┐  ┌────────────┐
               │ ARCn       │  │ LGWR ASYNC │  │ GoldenGate │
               │ Archives   │  │ Ships to   │  │ (after DG) │
               │ to +FRA    │  │ Standby    │  │ Reads redo │
               └────────────┘  └─────┬──────┘  └─────┬──────┘
                                     │               │
                                     ▼               ▼
                              ┌────────────┐  ┌────────────┐
                              │  Standby   │  │  Target DB │
                              │  MRP Apply │  │  Replicat  │
                              │  Real-Time │  │  Apply     │
                              └────────────┘  └────────────┘
```

## 📚 Guide — Phase Index

| # | Phase | File | Description |
|---|---|---|---|
| 0 | **Machine Setup** | [GUIDE_PHASE0](./GUIDE_PHASE0_MACHINE_SETUP.md) | VirtualBox VM creation, shared ASM disks, OL 7.9 install |
| 1 | **OS Preparation** | [GUIDE_PHASE1](./GUIDE_PHASE1_OS_PREPARATION.md) | Network, DNS, users, SSH, kernel, NTP |
| 2 | **Grid + RAC** | [GUIDE_PHASE2](./GUIDE_PHASE2_GRID_AND_RAC.md) | ASM, Grid Infrastructure, DB Software, Patching, DBCA |
| 3 | **RAC Standby** | [GUIDE_PHASE3](./GUIDE_PHASE3_RAC_STANDBY.md) | RMAN Duplicate, Listener, TNS, Redo Apply |
| 4 | **Data Guard** | [GUIDE_PHASE4](./GUIDE_PHASE4_DATAGUARD_DGMGRL.md) | DGMGRL, Switchover, Failover, ADG |
| 5 | **GoldenGate** | [GUIDE_PHASE5](./GUIDE_PHASE5_GOLDENGATE.md) | Extract on Standby, Pump, Replicat on Target |
| 6 | **Testing** | [GUIDE_PHASE6](./GUIDE_PHASE6_TESTING.md) | End-to-end DG + GG testing |
| 7 | **RMAN Backup** | [GUIDE_PHASE7](./GUIDE_PHASE7_RMAN_BACKUP.md) | Backup strategy, scripts, cron, BCT, restore |

## 📖 Additional Documents

| Document | File | Description |
|---|---|---|
| **Oracle Architecture** | [GUIDE_ARCHITECTURE](./GUIDE_ARCHITECTURE_ORACLE.md) | SGA, PGA, Redo, Undo, ASM, Cache Fusion |
| **DBA Commands** | [GUIDE_DBA_COMMANDS](./GUIDE_DBA_COMMANDS.md) | Essential queries, oracle-base.com scripts, health check |
| **Daily Study Plan** | [DAILY_STUDY_PLAN](./DAILY_STUDY_PLAN.md) | 15-day plan (3h/day) to complete the entire lab |

## 🔧 Software Prerequisites

| Software | Version | Download |
|---|---|---|
| Oracle Linux | 7.9 (VM) | [Oracle Linux ISOs](https://yum.oracle.com/oracle-linux-isos.html) |
| Oracle Grid Infrastructure | 19c (19.3) + RU | [eDelivery](https://edelivery.oracle.com) |
| Oracle Database | 19c (19.3) + RU + OJVM | [eDelivery](https://edelivery.oracle.com) |
| OPatch | p6880880 | [support.oracle.com](https://support.oracle.com) |
| Oracle GoldenGate | 19c or 21c | [eDelivery](https://edelivery.oracle.com) |
| VirtualBox | Latest | [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) |

## 📋 IP Plan

| Hostname | Public IP | Private IP | VIP |
|---|---|---|---|
| rac1 | 192.168.1.101 | 10.10.10.1 | 192.168.1.111 |
| rac2 | 192.168.1.102 | 10.10.10.2 | 192.168.1.112 |
| rac-scan | 192.168.1.120-122 | — | — |
| racstby1 | 192.168.1.201 | 10.10.10.11 | 192.168.1.211 |
| racstby2 | 192.168.1.202 | 10.10.10.12 | 192.168.1.212 |
| racstby-scan | 192.168.1.220-222 | — | — |
| dbtarget | 192.168.1.150 | — | — |
