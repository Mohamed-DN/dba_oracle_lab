# 📅 Daily Study Plan — 3 Hours per Day

> **Goal**: Complete the entire Oracle RAC + Data Guard + GoldenGate lab ASAP.
> **Pace**: 3 hours/day, 5-7 days/week.
> **Estimated Time**: ~15 working days (3 weeks).

---

## 🗓️ Week 1: Foundations (Days 1-5)

```
╔═══════════╦═══════════════════════════════════╦════════════════════════════╗
║   DAY     ║  WHAT YOU DO (3 hours)            ║  END-OF-DAY GOAL           ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 📖 30min: Read ARCHITECTURE       ║                            ║
║   Day 1   ║ 💻 2h: Download software + create ║ rac1 VM created, OL 7.9    ║
║           ║    rac1 VM (Phase 0)              ║ installed                  ║
║           ║ 📸 30min: SNAP-01                 ║ 📸 SNAP-01                 ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 2h: Configure network on rac1  ║                            ║
║   Day 2   ║    (hosts, DNS BIND, ifcfg)       ║ rac1 with network+DNS OK   ║
║           ║ 💻 1h: Firewall, packages,        ║ nslookup rac-scan OK       ║
║           ║    oracle-preinstall-19c           ║ 📸 SNAP-02                 ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 1.5h: Users, groups, SSH,      ║                            ║
║   Day 3   ║    directories, env vars, kernel  ║ rac1 ready for Grid        ║
║           ║ 💻 1h: Clone rac1 → rac2          ║ rac2 cloned, IP changed    ║
║           ║ 💻 30min: Fix hostname/IP on rac2 ║ ping rac1↔rac2 OK         ║
║           ║    + test SSH                     ║ 📸 SNAP-03 ⭐              ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 1h: ASM disks (oracleasm)      ║                            ║
║   Day 4   ║ 💻 30min: cluvfy → PASSED         ║ ASM disks visible +        ║
║           ║ 💻 1.5h: Grid installer GUI       ║    cluvfy PASSED            ║
║           ║    (WAIT for root.sh)             ║ 📸 SNAP-05 🔴              ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 1h: Finish Grid + root.sh      ║                            ║
║   Day 5   ║ 💻 1h: DATA + FRA disk groups     ║ CRS ONLINE + Disk Groups   ║
║           ║ 💻 1h: Patch Grid (OPatch + RU)   ║ Grid patched               ║
║           ║                                   ║ 📸 SNAP-06 ⭐ + SNAP-07    ║
╚═══════════╩═══════════════════════════════════╩════════════════════════════╝
```

---

## 🗓️ Week 2: Database + Standby (Days 6-10)

```
╔═══════════╦═══════════════════════════════════╦════════════════════════════╗
║   DAY     ║  WHAT YOU DO (3 hours)            ║  END-OF-DAY GOAL           ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 1h: Install DB Software        ║                            ║
║   Day 6   ║ 💻 1h: Patch DB Home (RU + OJVM)  ║ DB Software patched        ║
║           ║ 💻 1h: DBCA → create RACDB        ║ RACDB RUNNING on 2 nodes!  ║
║           ║                                   ║ 📸 SNAP-09 ⭐              ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 30min: Force Logging, datapatch║                            ║
║   Day 7   ║ 💻 2.5h: Create racstby1 VM +     ║ Standby VM created, OS     ║
║           ║    install OL 7.9 (Phase 0)       ║ installed                  ║
║           ║                                   ║ 📸 SNAP-01-stby            ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 2h: Phase 1 on racstby1        ║                            ║
║   Day 8   ║    (network, DNS, users, SSH...)  ║ racstby1 prepared          ║
║           ║ 💻 1h: Clone → racstby2 +         ║ 2 standby nodes ready      ║
║           ║    fix hostname/IP                ║ 📸 SNAP-03-stby ⭐         ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 3h: Grid + DB Software on      ║                            ║
║   Day 9   ║    standby (Phase 2 w/o DBCA)     ║ Grid + DB SW installed     ║
║           ║    ASM disks, Grid, root.sh,      ║ on standby                 ║
║           ║    DATA+FRA, patch RU+OJVM        ║ (NO database yet!)         ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 1h: Static listener + TNS      ║                            ║
║  Day 10   ║ 💻 30min: Standby Redo Logs       ║ RMAN Duplicate complete!   ║
║           ║ 💻 1.5h: RMAN Duplicate           ║ MRP active, 0 gap          ║
║           ║    (wait 20-60min...)             ║ 📸 SNAP-11🔴 + SNAP-12⭐   ║
╚═══════════╩═══════════════════════════════════╩════════════════════════════╝
```

---

## 🗓️ Week 3: Data Guard + GoldenGate + Backup (Days 11-15)

```
╔═══════════╦═══════════════════════════════════╦════════════════════════════╗
║   DAY     ║  WHAT YOU DO (3 hours)            ║  END-OF-DAY GOAL           ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 1h: DGMGRL create + enable     ║                            ║
║  Day 11   ║ 💻 1h: SHOW CONFIG = SUCCESS      ║ DG Broker operational      ║
║           ║ 💻 1h: Switchover + Switchback    ║ Switchover tested OK       ║
║           ║                                   ║ 📸 SNAP-14⭐ + SNAP-15     ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 30min: Active Data Guard       ║                            ║
║  Day 12   ║ 💻 1h: Create dbtarget VM +       ║ dbtarget ready +           ║
║           ║    OS + DB Software               ║ target DB created          ║
║           ║ 💻 1.5h: Create target DB (DBCA)  ║                            ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 📸 SNAP-16🔴                      ║                            ║
║  Day 13   ║ 💻 1.5h: Install GG on standby   ║ GoldenGate installed       ║
║           ║    + target, configure Manager    ║ on standby and target      ║
║           ║ 💻 1.5h: Extract+Pump+Replicat   ║ Processes configured       ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 1h: Initial Load (Data Pump)   ║                            ║
║  Day 14   ║ 💻 1h: Start GG processes +       ║ GG RUNNING everywhere!     ║
║           ║    verify INFO ALL                ║ Lag < 10 seconds           ║
║           ║ 💻 1h: End-to-end DML test        ║ 📸 SNAP-17⭐ FINAL         ║
╠═══════════╬═══════════════════════════════════╬════════════════════════════╣
║           ║ 💻 1h: RMAN backup on standby     ║                            ║
║  Day 15   ║ 💻 1h: RMAN backup on target      ║ Backup working on          ║
║           ║ 💻 1h: Test restore + DBA cmds    ║ all 3 databases            ║
║           ║                                   ║ 🏆 LAB COMPLETE!           ║
╚═══════════╩═══════════════════════════════════╩════════════════════════════╝
```

---

## 📊 Visual Progress

```
Day:     1    2    3    4    5    6    7    8    9   10   11   12   13   14   15
         │    │    │    │    │    │    │    │    │    │    │    │    │    │    │
Phase 0: ████                                                              
Phase 1:      ████████                                                     
Phase 2:                █████████████                                      
Standby:                             █████████████████                     
Phase 3:                                             ████                  
Phase 4:                                                  █████            
Phase 5:                                                       ████████    
Phase 6+7:                                                             ████
         └────────────┘ └────────────┘ └────────────┘ └────────────────────┘
          Week 1          Week 2          Week 3            Week 4         
```

---

## 🎯 After the Lab: What to Put on Your CV

```
┌──────────────────────────────────────────────────────────────┐
│                    ORACLE SKILLS                             │
│                                                              │
│  ✅ Oracle RAC 19c (2-Node cluster, Cache Fusion, ASM)       │
│  ✅ Oracle Data Guard (Physical Standby, DGMGRL, ADG)        │
│  ✅ Oracle GoldenGate (Integrated Extract, CDC)              │
│  ✅ RMAN Backup/Recovery (Level 0/1, BCT, Restore)           │
│  ✅ Oracle Linux Administration (7.9, 8.10)                   │
│  ✅ Grid Infrastructure & Clusterware                        │
│  ✅ ASM Storage Management                                   │
│  ✅ Oracle Patching (OPatch, opatchauto, datapatch)           │
│  ✅ Performance Tuning (AWR, Wait Events, Top SQL)            │
│  ✅ VirtualBox Infrastructure (Networking, Shared Storage)    │
│                                                              │
│  Lab Project: Complete enterprise architecture with          │
│  RAC → Data Guard → GoldenGate → RMAN on 5 nodes            │
└──────────────────────────────────────────────────────────────┘
```
