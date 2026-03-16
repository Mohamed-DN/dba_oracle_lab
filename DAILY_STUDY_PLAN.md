# 📅 Daily Study Plan — 3 Hours a Day

> **Objective**: Complete the Oracle RAC + DG + GG + Cloud + PostgreSQL lab → then prepare for exams 1Z0-082 and 1Z0-083.
> **Pace**: 3 hours a day, 5 days a week.
> **Duration**: 8 weeks (40 days).

---

## 📊 Map of the 8 Weeks

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║ THE 8 WEEKS — WITH MILESTONE EXAMS ║
╠═════════════╦════════════════════════════════════════╦══════════════════════════╣
║ WEEK ║ WHAT YOU LEARN ║ RESULT ║
╠═════════════╬════════════════════════════════════════╬══════════════════════════╣
║  1 (G 1-5)  ║ Teoria + VirtualBox + OS + Grid       ║ Cluster RAC ONLINE      ║
║ 2 (G 6-10) ║ Database + Standby RAC ║ RMAN Duplicate OK ║
║  3 (G11-15) ║ Data Guard + GoldenGate + RMAN        ║ DG + GG + Backup OK     ║
║ 4 (G16-20) ║ Switch/Failover + Migration + DBA ║ HA complete tested ║
║ 5 (G21-25) ║ OCI target + network + MAA ║ 🏆 LAB COMPLETE!     ║
╠═════════════╬════════════════════════════════════════╬══════════════════════════╣
║             ║  ═══ MILESTONE: LAB FINITO ═══         ║                         ║
╠═════════════╬════════════════════════════════════════╬══════════════════════════╣
║ 6 (G26-30) ║ Exam Review + Oracle→PostgreSQL ║ PG Migration OK ║
║  7 (G31-35) ║ 🎯 PREP ESAME 1Z0-082 (Admin I+SQL)  ║ ⭐ PRONTO PER ESAME 1  ║
║  8 (G36-40) ║ 🎯 PREP ESAME 1Z0-083 (DBA Pro 2)    ║ ⭐ PRONTO PER ESAME 2  ║
╚═════════════╩════════════════════════════════════════╩══════════════════════════╝
```

---

## 🗓️ WEEK 1: Foundation (Days 1-5)

> **Objective**: Read the theory, create the VMs, configure the OS, install Grid Infrastructure.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║ DAY ║ WHAT YOU DO (3 hours) ║ END OF THE DAY OBJECTIVE ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1h: Read ARCHITECTURE GUIDE ║ ║
║ Day 1 ║ (SGA, PGA, Redo, Undo, Temp, ASM) ║ Assimilated theory ║
║ ║ 📖 30min: Read GUIDA_CDB_PDB (P.1) ║ Downloaded the entire SW ║
║ ║ 💻 1.5h: Download all software ║ ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1.5h: Crea VM rac1 in VirtualBox ║                           ║
║ Day 2 ║ (CPU, RAM, disks, 2 NICs) ║ rac1: OL7.9 installed ║
║           ║ 💻 1.5h: Installa Oracle Linux 7.9   ║ 📸 SNAP-01               ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 1h: Configure network on rac1 ║ ║
║ Day 3 ║ (hosts, DNS BIND, ifcfg) ║ rac1: network + DNS OK ║
║           ║ 💻 1h: Pacchetti, firewall, kernel   ║ nslookup rac-scan OK      ║
║ ║ 💻 1h: Users, SSH, env vars ║ 📸 SNAP-02 ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Clona rac1 → rac2             ║                           ║
║ Day 4 ║ (adjust hostname, IP) ║ rac1↔rac2 ping+SSH OK ║
║ ║ 💻 1h: ASM disks (oracleasm/ASMLib) ║ ASM disks visible ║
║ ║ 💻 1h: cluvfy → all checks PASSED ║ 📸 SNAP-03 ⭐ ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 2h: Grid installer (GUI o silent) ║                           ║
║ Day 5 ║ + root.sh node 1 then node 2 ║ CRS ONLINE on 2 nodes!     ║
║           ║ 💻 1h: crsctl check crs + DATA/FRA  ║ 📸 SNAP-05 ⭐            ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🗓️ WEEK 2: Database and RAC Standby (Days 6-10)

> **Goal**: Create RACDB database, prepare standby nodes, run RMAN Duplicate.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║ DAY ║ WHAT YOU DO (3 hours) ║ END OF THE DAY OBJECTIVE ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Patch Grid (opatchauto RU)    ║                           ║
║ Day 6 ║ 💻 1h: Install DB Software + patch ║ DB Software patched ║
║           ║ 💻 1h: DBCA → crea RACDB (GUI)      ║ RACDB RUNNING 2 nodi!     ║
║           ║                                       ║ 📸 SNAP-09 ⭐            ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 30min: Force Logging + datapatch ║ ║
║ Day 7 ║ 💻 2.5h: Create racstby1 VM ║ Standby VM created ║
║ ║ install OL 7.9 (as Phase 0) ║ OL7.9 installed ║
║           ║                                       ║ 📸 SNAP-01-stby          ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 2h: Phase 1 on racstby1 ║ ║
║ Day 8 ║ (network, DNS, users, SSH...) ║ racstby1 prepared ║
║ ║ 💻 1h: Clone → racstby2 + fix IP ║ 2 standby nodes ready ║
║           ║                                       ║ 📸 SNAP-03-stby ⭐      ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 3h: Grid + DB Software on standby ║ ║
║ Day 9 ║ (Phase 2 WITHOUT DBCA) ║ Grid + DB SW on standby ║
║ ║ ASM, Grid, root.sh, DATA+FRA, ║ (NO database yet) ║
║           ║   patch RU + OJVM                     ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 1h: Static listener + TNS ║ ║
║ Day 10 ║ 💻 30min: Standby Redo Logs ║ RMAN Duplicate OK!        ║
║           ║ 💻 1.5h: RMAN DUPLICATE from active  ║ MRP attivo, 0 gap         ║
║ ║ (warning: ~30-60 min wait) ║ 📸 SNAP-12 ⭐ ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🗓️ WEEK 3: Data Guard + GoldenGate + Backup (Days 11-15)

> **Objective**: Configure DGMGRL, install GoldenGate, configure RMAN backup.

GG route update:

- correct base flow uses `Integrated Extract` on `primary`, not on standby;
- `dbtarget`local remains optional;
- if you choose OCI, you must first close network and target following `GUIDE_LAB_NETWORK_OCI_GOLDENGATE.md` and `GUIDE_GOLDENGATE_OCI_ARM.md`.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║ DAY ║ WHAT YOU DO (3 hours) ║ END OF THE DAY OBJECTIVE ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: DGMGRL create + enable        ║                           ║
║ Day 11 ║ 💻 1h: SHOW CONFIG → SUCCESS ║ DG Broker operational ║
║           ║ 💻 1h: Test switchover rapido         ║ Switch + Switchback OK    ║
║           ║                                       ║ 📸 SNAP-14 ⭐            ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 30min: Active Data Guard (ADG)    ║                           ║
║ Day 12 ║ 💻 1h: Choose target: dbtarget or OCI ║ target decided ║
║           ║ 💻 1.5h: DB Software + DBCA target   ║ DB target creato          ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 1.5h: Install GG on primary + ║ ║
║ Day 13 ║ target, configure Manager ║ GG installed ║
║           ║ 💻 1.5h: Extract su primary +        ║ Processi configurati      ║
║           ║   Replicat                            ║ 📸 SNAP-16               ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Initial Load (expdp/impdp)    ║                           ║
║ Day 14 ║ 💻 1h: Start all processes GG ║ GG RUNNING!               ║
║           ║ 💻 1h: Test DML end-to-end            ║ Lag < 10 secondi          ║
║ ║ (INSERT on primary → target arrives)║ 📸 SNAP-17 ⭐ ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read GUIDE_PHASE7 (RMAN) ║ ║
║ Day 15 ║ 💻 1h: RMAN backup on standby ║ Backup on standby OK ║
║           ║ 💻 1h: RMAN backup su primary        ║ Backup su primary OK      ║
║           ║ 💻 30min: Crontab + health check      ║ 📸 SNAP-18               ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🗓️ WEEK 4: Advanced HA + Listener + DBA Pro (Days 16-20)

> **Objective**: Switchover, Failover, Migration, Listener/Services, daily DBA tasks.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║ DAY ║ WHAT YOU DO (3 hours) ║ END OF THE DAY OBJECTIVE ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read GUIDA_SWITCHOVER ║ ║
║ Day 16 ║ 💻 1h: RACDB Switchover → STBY ║ Successful Switchover ║
║           ║ 💻 1h: Switchback → torna al primary ║ Switchback riuscito       ║
║ ║ 💻 30min: Check GG after switch ║ GG works after switch!  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read FAILOVER_GUIDE ║ ║
║ Day 17 ║ 📸 SNAP before failover!          ║ ║
║ ║ 💻 1h: Shut down rac1+rac2 (violence!) ║ Failover complete!      ║
║ ║ 💻 1h: FAILOVER TO RACDB_STBY ║ Standby is new Primary ║
║ ║ 💻 30min: Reinstate with Flashback ║ Reinstate Successful ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read MIGRATION_GUIDE ║ ║
║ Day 18 ║ 💻 1h: Simulate migration DD: ║ Zero-downtime migration ║
║ ║ expdp/impdp + Extract from SCN ║ simulated successfully ║
║ ║ 💻 1h: Sync + cutover ║ ║
║ ║ 💻 30min: Check migrated data ║ ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read GUIDA_LISTENER_DBA ║ ║
║ Day 19 ║ 💻 1h: Configure Services with srvctl ║ Services configured ║
║           ║ 💻 1h: EM Express (porta 5500)        ║ EM Express funzionante    ║
║ ║ 💻 30min: Create custom DBA user ║ Lab_dba user created ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read DBA_ACTIVITY_GUIDE ║ ║
║ Day 20 ║ 💻 1h: Create batch jobs ║ Stats + health check ║
║           ║   (DBMS_SCHEDULER: stats, health)    ║ schedulati                ║
║           ║ 💻 1h: Genera AWR + ADDM report       ║ Report AWR generato       ║
║           ║ 💻 30min: Test Data Pump exp/imp      ║ expdp/impdp OK            ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🗓️ WEEK 5: Cloud + MAA + Final Review (Days 21-25)

> **Objective**: Build OCI target, clarify network, prepare GG migration to cloud and validate MAA.

Cloud path update:

- the main lab OCI target should not be confused with `GoldenGate Free` as the base path;
- the focus is: `compute target`, `listener`, `porte`, `NSG o VPN`, `initial load`, `cutover`;
- `GoldenGate Free` resta una variante separata per mini-lab `Free-to-Free`, non la base del lab RAC 19c.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║ DAY ║ WHAT YOU DO (3 hours) ║ END OF THE DAY OBJECTIVE ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read GUIDA_CLOUD_GG ║ ║
║ Day 21 ║ 💻 1.5h: Create OCI, VCN, NSG and ║ ARM VM created on OCI ║
║           ║   Security List, VM ARM               ║ SSH funzionante           ║
║           ║ 💻 1h: Installa target Oracle coerente        ║ DB CLOUDDB creato         ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 1h: Check target GG model ║ ║
║ Day 22 ║ 💻 1h: TNS, ports, NSG or VPN ║ GG Replicat on OCI OK ║
║           ║ 💻 1h: Initial load + Replicat cloud          ║ Primary→Cloud ✅         ║
║           ║   test INSERT → OCI                   ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read MAA_GUIDE ║ ║
║ Day 23 ║ 💻 1h: Apply MAA fix ║ DB_BLOCK_CHECKING ON ║
║           ║   (block checking, flashback, FSFO)  ║ Flashback ON              ║
║           ║ 💻 1h: Security (profile, audit)      ║ FSFO configurato          ║
║           ║ 💻 30min: FAN + Connection String     ║ Lab MAA GOLD! ✅         ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Reread CDB/PDB + Commands ║ ║
║ Day 24 ║ 💻 1h: SQL Tuning Advisor on RACDB ║ SQL Tuning tested ║
║           ║ 💻 1h: Patching workflow (dry run)    ║ Patching compreso         ║
║ ║ 💻 30min: Check VALIDATION_BP ║ 54/54 check ✅ ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 1h: Review: turn everything on, ║ ║
║ Day 25 ║ check DG + GG + Cloud ║ EVERYTHING works!           ║
║ ║ 💻 1h: Complete end-to-end test ║ Final test passed ║
║ ║ 📝 1h: Update CV with skills ║ 🏆 LAB COMPLETED! 🏆 ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 📊 Visual Progress

```
Day: 1 5 10 15 20 25 30 35 40
         │    │    │    │    │    │    │    │    │
Sett 1:  ████████████              Teoria + VM + OS + Grid
Sept 2: ████████████ Database + Standby + RMAN Dup
Sett 3:            ████████████    DG + GG + Backup
Sept 4: ███████████ Switch/Fail + Listener + DBA
Sept 5: ██████████ Cloud + MAA + Review
         │ ────── 🏆 MILESTONE: LAB FINITO ─────  │
Sept 6: ██████████ Oracle→PG Migration
Sett 7:                                ██████████ 🎯 ESAME 1Z0-082
Sett 8:                                     ██████████ 🎯 ESAME 1Z0-083
         │    │    │    │    │    │    │    │    │
         S1   S1   S2   S3   S4   S5   S6   S7   S8
```

---

## 🗓️ WEEK 6: Exam Review + Oracle Migration → PostgreSQL (Days 26-30)

> **Objective**: Complete review of exam topics (1Z0-082 + 1Z0-083), Oracle→PostgreSQL migration with GoldenGate.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║ DAY ║ WHAT YOU DO (3 hours) ║ END OF THE DAY OBJECTIVE ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1.5h: Read EXAM_GUIDE Parts 1-5 ║ ║
║ Day 26 ║ (Architecture, Instance, Users, ║ Basic concepts revised ║
║ ║ Storage, Data Movement) ║ ║
║ ║ 💻 1.5h: SQL Exercises (Part 10) ║ Fluent SQL ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1h: Read EXAM_GUIDE Parts 6-9 ║ ║
║ Day 27 ║ (Tools, Net Services, Tablespace, ║ Net Services + Undo OK ║
║           ║    Undo)                              ║                           ║
║ ║ 💻 2h: Read Part 11 (DBA Pro 2) ║ 1Z0-083 topics revised ║
║           ║   AWR/ADDM/ASH, Resource Manager      ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 30min: Read MIGRATION_GUIDE_PG ║ ║
║ Day 28 ║ 💻 1h: Install PostgreSQL 16 ║ PG installed ║
║ ║ 💻 1h: hour2pg + convert scheme ║ HR scheme on PG ║
║           ║ 💻 30min: Configura ODBC + GG for PG  ║ GG for PG pronto          ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Configura Extract + Pump       ║                           ║
║ Day 29 ║ 💻 1h: Initial Load + Replicat ║ Oracle→PG Replica active ║
║           ║ 💻 1h: Test CDC (INSERT/UPDATE/DELETE)║ CDC funzionante!          ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Cutover simulato              ║                           ║
║ Day 30 ║ 💻 1h: Post-migration validation ║ Migration complete!    ║
║ ║ 📝 1h: Update CV + final review ║ 🏆 COMPLETE LAB! 🏆 ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🏗️ WEEK 7: 🎯 Exam Preparation 1Z0-082 — Admin I + SQL (Days 31-35)

> **Objective**: Intensive review of all 1Z0-082 exam topics. SQL practice and administration concepts.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║ DAY ║ WHAT YOU DO (3 hours) ║ END OF THE DAY OBJECTIVE ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1h: Review Part 1-2 (Architect- ║ ║
║ Day 31 ║ ture, Instance Mgmt, Startup/SHUT) ║ Architecture OK ║
║           ║ 💻 1h: Pratica startup/shutdown su   ║ V$ e DBA_ views OK        ║
║           ║   lab RAC + query V$, DBA_ views     ║                           ║
║ ║ 📖 1h: Review Part 3 (Users/Roles) ║ Profiles + Audit OK ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1h: Review Part 4-5 (Storage, ║ ║
║ Day 32 ║ Data Movement, External Tables) ║ DataPump + SQL*Loader OK ║
║           ║ 💻 1h: Pratica expdp/impdp + sqlldr  ║                           ║
║ ║ 📖 1h: Review Part 7 (Net Svc) ║ Listener + TNS OK ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1h: Review Part 8-9 (Tablespace ║ ║
║ Day 33 ║ Undo, OMF) ║ Tablespace + Undo OK ║
║ ║ 💻 2h: Intensive SQL Part 10 — ║ 100 SQL queries executed ║
║           ║   JOIN, subqueries, group functions   ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 💻 2h: Advanced SQL — DDL, DML, ║ ║
║ Day 34 ║ SET operators, conversions, NVL, ║ SQL mastered ║
║           ║   sequences, views, constraints      ║                           ║
║ ║ 💻 1h: Lab practice with HR scheme ║ ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📝 2h: 1Z0-082 exam simulation ║ ║
║ Day 35 ║ (online practice exam) ║ Score ≥ 75% target ║
║ ║ 📖 1h: Review incorrect answers ║ ⭐ READY FOR 1Z0-082!   ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🏗️ WEEK 8: 🎯 Preparation for Exam 1Z0-083 — DBA Professional 2 (Days 36-40)

> **Objective**: Intensive review of advanced topics 1Z0-083. Multitenant, RMAN, Performance, Security, Patching.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║ DAY ║ WHAT YOU DO (3 hours) ║ END OF THE DAY OBJECTIVE ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1.5h: Review 11.8 (Multitenant ║ ║
║ Day 36 ║ CDB/PDB, App containers, Lockdown)║ Multitenant mastered ║
║           ║ 💻 1.5h: Pratica CDB/PDB su lab —   ║ Plug/Unplug testato       ║
║           ║   create, clone, plug, unplug PDB    ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1h: Review 11.9 (RMAN Backup & ║ ║
║ Day 37 ║ Recovery Workshop, Flashback) ║ Advanced RMAN OK ║
║           ║ 💻 1h: Pratica RMAN su lab — backup  ║ Flashback PDB testato     ║
║           ║   PDB, validate, flashback table     ║                           ║
║ ║ 📖 1h: Review 11.10 (Deploy/Patch) ║ Upgrade path included ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1h: Review 11.12 (Performance ║ ║
║ Day 38 ║ AWR/ADDM/ASH, Memory, Wait Events)║ AWR report generated ║
║ ║ 💻 1h: Generate AWR/ADDM on RAC lab ║ ADDM recommendations OK ║
║ ║ 📖 1h: Review 11.13 (SQL Tuning ║ Optimizer included ║
║           ║   Advisor, Optimizer Statistics)      ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📖 1h: Review 11.1-11.2 (ASM, RAC ║ ║
║ Day 39 ║ Data Guard, HA, Security) ║ HA + Security OK ║
║ ║ 💻 1h: Review 11.6 (TDE, Audit) ║ TDE clear concepts ║
║ ║ 📖 1h: Review 11.11 (19c Features) ║ New Features included ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║ ║ 📝 2h: 1Z0-083 exam simulation ║ ║
║ Day 40 ║ (online practice exam) ║ Score ≥ 75% target ║
║ ║ 📖 1h: Review incorrect answers ║ ⭐ READY FOR 1Z0-083!   ║
║ ║ ║ 🏆🏆 COMPLETE ROUTE! 🏆🏆║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## ⚡ Tips for Going Fast

|Advise| Why |
|---|---|
| **Download EVERYTHING on day one** | Don't waste time waiting for 3GB downloads mid-installation |
| **Usa 2 terminali** | One for commands, one for alert log (`tail -f alert*.log`) |
| **Copy commands from guide** |Don't type them by hand — typos = enemy #1|
| **ALWAYS take a snapshot FIRST** |30 second snapshot vs 3 hour reinstallation|
| **If something fails, read the alert log** | The answer is almost always there |
| **Non saltare i test intermedi** | A `ping` that fails on day 2 becomes a nightmare on day 10 |

---

## 🎯 After the Lab: What to Put in your CV

```
┌──────────────────────────────────────────────────────────────┐
│                    COMPETENZE ORACLE                         │
│                                                              │
│  ✅ Oracle RAC 19c (2-Node cluster, Cache Fusion, ASM)       │
│ ✅ Oracle Data Guard (Physical Standby, DGMGRL, ADG) │
│  ✅ Data Guard Switchover & Failover (FSFO, Reinstate)       │
│  ✅ Oracle GoldenGate (Integrated Extract, CDC, Migration)   │
│ ✅ Oracle → PostgreSQL Migration with GoldenGate │
│  ✅ Oracle Cloud Infrastructure (OCI) — Free Tier ARM        │
│  ✅ Hybrid Architecture (On-Prem → Cloud via SSH Tunnel)     │
│ ✅ Zero-Downtime Migration with GoldenGate │
│  ✅ RMAN Backup/Recovery (Level 0/1, BCT, Restore)           │
│  ✅ CDB/PDB Multitenant Architecture                         │
│  ✅ Oracle Linux Administration (7.9, 8.10, ARM)             │
│  ✅ Grid Infrastructure & Clusterware                        │
│  ✅ ASM Storage Management (NORMAL/HIGH redundancy, ASMLib)  │
│  ✅ Oracle Patching (OPatch, opatchauto, datapatch)           │
│  ✅ Performance Tuning (AWR, ADDM, ASH, SQL Tuning Advisor)  │
│  ✅ DBA Automation (DBMS_SCHEDULER, Health Checks)            │
│  ✅ Security (Profiles, Unified Auditing, TDE concepts)      │
│  ✅ Oracle MAA Gold Architecture (FSFO, FAN, Block Checking)  │
│  ✅ PostgreSQL 16 Administration (basics)                     │
│                                                              │
│ Lab Project: Hybrid enterprise architecture with │
│  RAC → Data Guard → GoldenGate → OCI Cloud → PostgreSQL   │
│  su 6+ nodi                                                  │
└──────────────────────────────────────────────────────────────┘
```

---

## 📚 Risorse Extra: Enterprise DBA Toolkit (studio_ai/)

> Use these resources to enrich your study with real-world operational procedures and scripts.

| Week | Quando Usare |Studio_ai folder|
|---|---|---|
| **Week. 1** (Day 4: ASM disks) | After configuring ASMLib | [01_asm_storage/](./studio_ai/01_asm_storage/) + [GUIDA_AGGIUNTA_DISCHI_ASM](./GUIDE_ADD_ASM_DISK.md) |
| **Week. 2** (Day 9: Grid) | After installing Grid | [05_patching/](./studio_ai/05_patching/) |
| **Week. 3** (Day 11: DG) | After configuring Data Guard |[02_dataguard/](./studio_ai/02_dataguard/)|
| **Week. 3** (Day 15: RMAN) | After configuring RMAN | [06_backup_recovery/](./studio_ai/06_backup_recovery/) |
| **Week. 4** (Day 19: Listener) | After Listener/Services | [04_user_management/](./studio_ai/04_user_management/) |
| **Week. 4** (Day 20: DBA) | After DBA activity |[03_monitoring_scripts/](./studio_ai/03_monitoring_scripts/) + [07_performance_tuning/](./studio_ai/07_performance_tuning/)|
| **Week. 5** (Day 24: Patching) | Afterwards I review patching | [08_tde_security/](./studio_ai/08_tde_security/) |

---

## Operational Addendum: Sprint GoldenGate Extended (40 tests)

To stress the GoldenGate lab with as many cases as possible, use [GUIDE_PHASE5_GOLDENGATE.md](Z./GUIDE_PHASE5_GOLDENGATE.md) as the main reference.

### Practical Plan (Week 3 -> Week 4)

1. Day 13: Run `GG-01..GG-08` (DML, LOB, transactions, commit storm).
2. Day 14: Run `GG-09..GG-18` (DDL policy, network, restart processes, lag stress).
3. Day 15: Run `GG-19..GG-28` (DG switchover/failover, re-instantiate, long tx, concurrency).
4. Day 16-17: Run `GG-29..GG-40` (charset/timezone, restart DB/host, purge trail, credentials, 120 minute dress rehearsal).

### Exit KPIs (required)

- almeno `32/40` in-state testing `PASS`
- critical test passes:`GG-01`, `GG-05`, `GG-12`, `GG-19`, `GG-20`, `GG-33`, `GG-35`, `GG-40`
- no trial`ABENDED` oltre 10 minuti
- lag within threshold in prolonged test window

### Deliverable to create in the repo

1. `TESTLOG_GOLDENGATE.md` with columns: Date/Time, Test ID, Scenario, Result, Max Lag, Evidence, Notes/Fix (starting from `TESTLOG_GOLDENGATE_TEMPLATE.md`).
2. Screenshot/log folder with evidence of `INFO ALL`, `LAG`, `VIEW REPORT`, query count/checksum.
3. Mini-runbook for each fail: symptom, root cause, fix, post-fix validation.

### Adjust time/resources for home lab

- If you're short on time, close `GG-01..GG-24` during the week first.
- Complete `GG-25..GG-40` over the weekend or in two dedicated sessions.

---

## Addendum 2026: Rebalanced Study Load (recommended)

This block updates the existing plan to better distribute mental effort, lab practice, and review.
The rule remains **3 hours a day**, but with different intensities.

### 1) Fixed daily model (3 hours)

- `Blocco A (50 min)`: theory focused on a single theme
- `Pausa (10 min)`
- `Blocco B (50 min)`: practical lab on the same topic
- `Pausa (10 min)`
- `Blocco C (50 min)`: active verification (quiz, rote commands, mini runbook)

### 2) Recommended weekly pattern

| Day |Intensity| Recommended use |
|---|---|---|
| Day 1 | HIGH | New topic + new lab |
| Day 2 | HIGH | Continuazione + troubleshooting |
| Day 3 | MEDIUM | Consolidamento e test guidati |
| Day 4 | HIGH | New technical block |
| Day 5 | LIGHT | Active review + documentation + backlog fix |
| Day 6 (optional) | BUFFER | Recupero task slittati o test extra |
| Day 7 | OFF | Technical stop (light reading only, max 30 min) |

### 3) Distributed review (spaced repetition)

For every new topic made in `D0`, pianifica:

- `D+1`: 20 minutes of recall without notes
- `D+3`: 20 minute quiz + 1 quick practice test
- `D+7`: 30 minutes of mini simulation + error correction

### 4) Rebalanced load for the 8 weeks

| Week | Focus | HIGH days | MEDIUM days | LIGHT/BUFFER days |Minimum output|
|---|---|---|---|---|---|
| 1 | OS + Grid + ASM | 3 | 1 |1 + optional buffer|Stable grid + prerequisite checklist|
| 2 | RAC + standby prep | 3 | 1 |1 + optional buffer| RAC operational + standby ready |
| 3 | Data Guard + RMAN + GG base | 2 | 2 |1 + optional buffer| broker ok + backup validato + GG base |
| 4 |Advanced GG + HA test| 3 | 1 |1 + optional buffer|at least 24 GG tests closed|
| 5 |EM + monitoring + cloud| 2 | 2 |1 + optional buffer| OMS/agent attivi + dashboard utili |
| 6 |Oracle->PostgreSQL migration| 2 | 2 |1 + optional buffer| end-to-end migration flow |
| 7 | Esame 1Z0-082 prep | 2 | 2 |1 + optional buffer|2 mocks + classified error log|
| 8 | Esame 1Z0-083 prep | 2 | 2 |1 + optional buffer| 2 mock + runbook finali |

### 5) Anti-overload rules (practical)

- Never do two "new and critical" tasks on the same day.
- If a block goes through 30 minutes of troubleshooting without progress, move it to backlog and move on to the next block.
- Maintain only one “must close” technical goal per day.
- Always close with written evidence: 5-10 lines of what worked, what didn't, next step.

### 6) Cadence mock exam (aligned to Oracle)

Values ​​verified on Oracle Japan (consulted on March 13, 2026):

- `1Z0-082-JPN`: `120 minuti`, `72 domande`, `passing score 60%`
- `1Z0-083-JPN`: `120 minuti`, `68 domande`, `passing score 57%`

Practical use in the lab:

- Week 7: 2 simulations of 120 minutes (day 3 and day 5)
- Week 8: 2 simulations of 120 minutes (day 2 and day 5)
- After each mock: 40-60 minutes of "error review" by category (SQL, backup, HA, security, tuning)

### 7) GoldenGate reallocation (more cases, less stress)

Per i 40 test GoldenGate:

- week 3: `GG-01..GG-16`
- week 4: `GG-17..GG-32`
- week 4/5 buffer: `GG-33..GG-40` + fail retest

Criterion: at least `8 test` per week must be "hard" (failover, lag, restart, recovery trail).

### 8) Sources used (internet + official Oracle)

- Oracle University Japan, `1Z0-082-JPN` exam page: https://www.oracle.com/jp/education/certification/certification-exam-list/dba-i-1z0-082-exam/
- Oracle University Japan, `1Z0-083-JPN` exam page: https://www.oracle.com/jp/education/certification/certification-exam-list/dba-ii-1z0-083-exam/
- Oracle exam registration FAQ: https://education.oracle.com/oracle-certification-exams-registration-faq
- Oracle Database 19c Administrator's Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/index.html
- Oracle Database 19c Backup and Recovery User's Guide: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/index.html
- Oracle Data Guard Broker 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/index.html
- Oracle RAC Installation Guide 19c (Linux/UNIX): https://docs.oracle.com/en/database/oracle/oracle-database/19/rilin/index.html
- Karpicke et al., retrieval practice and retention (PubMed): https://pubmed.ncbi.nlm.nih.gov/20951630/
- Cepeda et al., distributed practice review (PubMed): https://pubmed.ncbi.nlm.nih.gov/16719566/


