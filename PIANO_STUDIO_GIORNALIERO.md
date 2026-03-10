# 📅 Piano di Studio Giornaliero — 3 Ore al Giorno

> **Obiettivo**: Completare il lab Oracle RAC + DG + GG + Cloud + PostgreSQL → poi preparare esami 1Z0-082 e 1Z0-083.
> **Ritmo**: 3 ore al giorno, 5 giorni a settimana.
> **Durata**: 8 settimane (40 giorni).

---

## 📊 Mappa delle 8 Settimane

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                    LE 8 SETTIMANE — CON MILESTONE ESAMI                         ║
╠═════════════╦════════════════════════════════════════╦══════════════════════════╣
║ SETTIMANA   ║ COSA IMPARI                            ║ RISULTATO               ║
╠═════════════╬════════════════════════════════════════╬══════════════════════════╣
║  1 (G 1-5)  ║ Teoria + VirtualBox + OS + Grid       ║ Cluster RAC ONLINE      ║
║  2 (G 6-10) ║ Database + Standby RAC                ║ RMAN Duplicate OK       ║
║  3 (G11-15) ║ Data Guard + GoldenGate + RMAN        ║ DG + GG + Backup OK     ║
║  4 (G16-20) ║ Switch/Failover + Migrazione + DBA    ║ HA completa testata     ║
║  5 (G21-25) ║ Cloud OCI + DBA Pro + MAA             ║ 🏆 LAB COMPLETATO!     ║
╠═════════════╬════════════════════════════════════════╬══════════════════════════╣
║             ║  ═══ MILESTONE: LAB FINITO ═══         ║                         ║
╠═════════════╬════════════════════════════════════════╬══════════════════════════╣
║  6 (G26-30) ║ Ripasso Esame + Oracle→PostgreSQL     ║ Migrazione PG OK        ║
║  7 (G31-35) ║ 🎯 PREP ESAME 1Z0-082 (Admin I+SQL)  ║ ⭐ PRONTO PER ESAME 1  ║
║  8 (G36-40) ║ 🎯 PREP ESAME 1Z0-083 (DBA Pro 2)    ║ ⭐ PRONTO PER ESAME 2  ║
╚═════════════╩════════════════════════════════════════╩══════════════════════════╝
```

---

## 🗓️ SETTIMANA 1: Fondamenta (Giorni 1-5)

> **Obiettivo**: Leggere la teoria, creare le VM, configurare l'OS, installare Grid Infrastructure.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║  GIORNO   ║  COSA FAI (3 ore)                    ║  OBIETTIVO FINE GIORNATA  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1h: Leggi GUIDA_ARCHITETTURA      ║                           ║
║ Giorno 1  ║   (SGA, PGA, Redo, Undo, Temp, ASM) ║ Teoria assimilata         ║
║           ║ 📖 30min: Leggi GUIDA_CDB_PDB (P.1)  ║ Scaricato tutto il SW     ║
║           ║ 💻 1.5h: Scarica tutto il software    ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1.5h: Crea VM rac1 in VirtualBox ║                           ║
║ Giorno 2  ║   (CPU, RAM, dischi, 2 NIC)          ║ rac1: OL7.9 installato    ║
║           ║ 💻 1.5h: Installa Oracle Linux 7.9   ║ 📸 SNAP-01               ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Configura rete su rac1        ║                           ║
║ Giorno 3  ║   (hosts, DNS BIND, ifcfg)           ║ rac1: rete + DNS OK       ║
║           ║ 💻 1h: Pacchetti, firewall, kernel   ║ nslookup rac-scan OK      ║
║           ║ 💻 1h: Utenti, SSH, env vars          ║ 📸 SNAP-02               ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Clona rac1 → rac2             ║                           ║
║ Giorno 4  ║   (aggiusta hostname, IP)            ║ rac1↔rac2 ping+SSH OK    ║
║           ║ 💻 1h: Dischi ASM (oracleasm/ASMLib) ║ Dischi ASM visibili       ║
║           ║ 💻 1h: cluvfy → tutti i check PASSED ║ 📸 SNAP-03 ⭐            ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 2h: Grid installer (GUI o silent) ║                           ║
║ Giorno 5  ║   + root.sh nodo 1 poi nodo 2        ║ CRS ONLINE su 2 nodi!     ║
║           ║ 💻 1h: crsctl check crs + DATA/FRA  ║ 📸 SNAP-05 ⭐            ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🗓️ SETTIMANA 2: Database e RAC Standby (Giorni 6-10)

> **Obiettivo**: Creare il database RACDB, preparare i nodi standby, eseguire RMAN Duplicate.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║  GIORNO   ║  COSA FAI (3 ore)                    ║  OBIETTIVO FINE GIORNATA  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Patch Grid (opatchauto RU)    ║                           ║
║ Giorno 6  ║ 💻 1h: Installa DB Software + patch ║ DB Software patchato      ║
║           ║ 💻 1h: DBCA → crea RACDB (GUI)      ║ RACDB RUNNING 2 nodi!     ║
║           ║                                       ║ 📸 SNAP-09 ⭐            ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 30min: Force Logging + datapatch  ║                           ║
║ Giorno 7  ║ 💻 2.5h: Crea VM racstby1           ║ Standby VM creata         ║
║           ║   installa OL 7.9 (come Fase 0)      ║ OL7.9 installato          ║
║           ║                                       ║ 📸 SNAP-01-stby          ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 2h: Fase 1 su racstby1            ║                           ║
║ Giorno 8  ║   (rete, DNS, utenti, SSH...)        ║ racstby1 preparato        ║
║           ║ 💻 1h: Clona → racstby2 + fix IP    ║ 2 nodi standby pronti     ║
║           ║                                       ║ 📸 SNAP-03-stby ⭐      ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 3h: Grid + DB Software su standby ║                           ║
║ Giorno 9  ║   (Fase 2 SENZA DBCA)               ║ Grid + DB SW su standby   ║
║           ║   ASM, Grid, root.sh, DATA+FRA,      ║ (NO database ancora)      ║
║           ║   patch RU + OJVM                     ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Listener statico + TNS        ║                           ║
║ Giorno 10 ║ 💻 30min: Standby Redo Logs          ║ RMAN Duplicate OK!        ║
║           ║ 💻 1.5h: RMAN DUPLICATE from active  ║ MRP attivo, 0 gap         ║
║           ║   (attenzione: ~30-60 min di attesa) ║ 📸 SNAP-12 ⭐            ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🗓️ SETTIMANA 3: Data Guard + GoldenGate + Backup (Giorni 11-15)

> **Obiettivo**: Configurare DGMGRL, installare GoldenGate, configurare RMAN backup.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║  GIORNO   ║  COSA FAI (3 ore)                    ║  OBIETTIVO FINE GIORNATA  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: DGMGRL create + enable        ║                           ║
║ Giorno 11 ║ 💻 1h: SHOW CONFIG → SUCCESS        ║ DG Broker operativo       ║
║           ║ 💻 1h: Test switchover rapido         ║ Switch + Switchback OK    ║
║           ║                                       ║ 📸 SNAP-14 ⭐            ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 30min: Active Data Guard (ADG)    ║                           ║
║ Giorno 12 ║ 💻 1h: Crea VM dbtarget + OS         ║ dbtarget pronto           ║
║           ║ 💻 1.5h: DB Software + DBCA target   ║ DB target creato          ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1.5h: Installa GG su standby +   ║                           ║
║ Giorno 13 ║   target, configura Manager          ║ GG installato             ║
║           ║ 💻 1.5h: Extract + Data Pump +        ║ Processi configurati      ║
║           ║   Replicat                            ║ 📸 SNAP-16               ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Initial Load (expdp/impdp)    ║                           ║
║ Giorno 14 ║ 💻 1h: Start tutti i processi GG    ║ GG RUNNING!               ║
║           ║ 💻 1h: Test DML end-to-end            ║ Lag < 10 secondi          ║
║           ║   (INSERT su primary → arriva target)║ 📸 SNAP-17 ⭐            ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_FASE7 (RMAN)   ║                           ║
║ Giorno 15 ║ 💻 1h: RMAN backup su standby       ║ Backup su standby OK      ║
║           ║ 💻 1h: RMAN backup su primary        ║ Backup su primary OK      ║
║           ║ 💻 30min: Crontab + health check      ║ 📸 SNAP-18               ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🗓️ SETTIMANA 4: HA Avanzata + Listener + DBA Pro (Giorni 16-20)

> **Obiettivo**: Switchover, Failover, Migrazione, Listener/Services, attività DBA quotidiane.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║  GIORNO   ║  COSA FAI (3 ore)                    ║  OBIETTIVO FINE GIORNATA  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_SWITCHOVER     ║                           ║
║ Giorno 16 ║ 💻 1h: Switchover RACDB → STBY      ║ Switchover riuscito       ║
║           ║ 💻 1h: Switchback → torna al primary ║ Switchback riuscito       ║
║           ║ 💻 30min: Verifica GG dopo switch    ║ GG funziona dopo switch!  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_FAILOVER       ║                           ║
║ Giorno 17 ║ 📸 SNAP prima del failover!          ║                           ║
║           ║ 💻 1h: Spegni rac1+rac2 (violenza!) ║ Failover completato!      ║
║           ║ 💻 1h: FAILOVER TO RACDB_STBY        ║ Standby è nuovo Primary   ║
║           ║ 💻 30min: Reinstate con Flashback    ║ Reinstate riuscito        ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_MIGRAZIONE     ║                           ║
║ Giorno 18 ║ 💻 1h: Simula migrazione GG:        ║ Migrazione zero-downtime  ║
║           ║   expdp/impdp + Extract da SCN       ║ simulata con successo     ║
║           ║ 💻 1h: Sincronizza + cutover          ║                           ║
║           ║ 💻 30min: Verifica dati migrati       ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_LISTENER_DBA   ║                           ║
║ Giorno 19 ║ 💻 1h: Configura Services con srvctl ║ Services configurati      ║
║           ║ 💻 1h: EM Express (porta 5500)        ║ EM Express funzionante    ║
║           ║ 💻 30min: Crea utente DBA custom     ║ Utente lab_dba creato     ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_ATTIVITA_DBA   ║                           ║
║ Giorno 20 ║ 💻 1h: Crea batch jobs               ║ Stats + health check      ║
║           ║   (DBMS_SCHEDULER: stats, health)    ║ schedulati                ║
║           ║ 💻 1h: Genera AWR + ADDM report       ║ Report AWR generato       ║
║           ║ 💻 30min: Test Data Pump exp/imp      ║ expdp/impdp OK            ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🗓️ SETTIMANA 5: Cloud + MAA + Ripasso Finale (Giorni 21-25)

> **Obiettivo**: Setup OCI Cloud, validazione MAA, ripasso e preparazione CV.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║  GIORNO   ║  COSA FAI (3 ore)                    ║  OBIETTIVO FINE GIORNATA  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_CLOUD_GG       ║                           ║
║ Giorno 21 ║ 💻 1.5h: Crea account OCI, VCN,     ║ VM ARM creata su OCI      ║
║           ║   Security List, VM ARM               ║ SSH funzionante           ║
║           ║ 💻 1h: Installa Oracle 19c ARM        ║ DB CLOUDDB creato         ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Installa GG ARM + Manager     ║                           ║
║ Giorno 22 ║ 💻 1h: SSH Tunnel + TNS config       ║ GG Replicat su OCI OK     ║
║           ║ 💻 1h: Pump + Replicat cloud          ║ Primary→Cloud ✅         ║
║           ║   test INSERT → OCI                   ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_MAA             ║                           ║
║ Giorno 23 ║ 💻 1h: Applica MAA fix               ║ DB_BLOCK_CHECKING ON      ║
║           ║   (block checking, flashback, FSFO)  ║ Flashback ON              ║
║           ║ 💻 1h: Security (profile, audit)      ║ FSFO configurato          ║
║           ║ 💻 30min: FAN + Connection String     ║ Lab MAA GOLD! ✅         ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Rileggi CDB/PDB + Comandi ║                           ║
║ Giorno 24 ║ 💻 1h: SQL Tuning Advisor su RACDB  ║ SQL Tuning testato        ║
║           ║ 💻 1h: Patching workflow (dry run)    ║ Patching compreso         ║
║           ║ 💻 30min: Verifica VALIDAZIONE_BP     ║ 54/54 check ✅           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Ripasso: accendi tutto,        ║                           ║
║ Giorno 25 ║   verifica DG + GG + Cloud            ║ TUTTO funziona!           ║
║           ║ 💻 1h: Test completo end-to-end       ║ Test finale superato      ║
║           ║ 📝 1h: Aggiorna CV con competenze    ║ 🏆 LAB COMPLETATO! 🏆    ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 📊 Progresso Visivo

```
Giorno:  1    5    10   15   20   25   30   35   40
         │    │    │    │    │    │    │    │    │
Sett 1:  ████████████              Teoria + VM + OS + Grid
Sett 2:       ████████████         Database + Standby + RMAN Dup
Sett 3:            ████████████    DG + GG + Backup
Sett 4:                 ███████████ Switch/Fail + Listener + DBA
Sett 5:                      ██████████ Cloud + MAA + Ripasso
         │ ────── 🏆 MILESTONE: LAB FINITO ─────  │
Sett 6:                           ██████████ Migrazione Oracle→PG
Sett 7:                                ██████████ 🎯 ESAME 1Z0-082
Sett 8:                                     ██████████ 🎯 ESAME 1Z0-083
         │    │    │    │    │    │    │    │    │
         S1   S1   S2   S3   S4   S5   S6   S7   S8
```

---

## 🗓️ SETTIMANA 6: Ripasso Esame + Migrazione Oracle → PostgreSQL (Giorni 26-30)

> **Obiettivo**: Ripasso completo argomenti esame (1Z0-082 + 1Z0-083), migrazione Oracle→PostgreSQL con GoldenGate.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║  GIORNO   ║  COSA FAI (3 ore)                    ║  OBIETTIVO FINE GIORNATA  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1.5h: Leggi GUIDA_ESAME Parti 1-5 ║                           ║
║ Giorno 26 ║   (Architettura, Instance, Users,    ║ Concetti base rivisti     ║
║           ║    Storage, Data Movement)            ║                           ║
║           ║ 💻 1.5h: Esercizi SQL (Parte 10)     ║ SQL fluente               ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1h: Leggi GUIDA_ESAME Parti 6-9   ║                           ║
║ Giorno 27 ║   (Tools, Net Services, Tablespace,  ║ Net Services + Undo OK    ║
║           ║    Undo)                              ║                           ║
║           ║ 💻 2h: Leggi Parte 11 (DBA Pro 2)    ║ 1Z0-083 topics rivisti    ║
║           ║   AWR/ADDM/ASH, Resource Manager      ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 30min: Leggi GUIDA_MIGRAZIONE_PG  ║                           ║
║ Giorno 28 ║ 💻 1h: Installa PostgreSQL 16         ║ PG installato             ║
║           ║ 💻 1h: ora2pg + converti schema       ║ Schema HR su PG           ║
║           ║ 💻 30min: Configura ODBC + GG for PG  ║ GG for PG pronto          ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Configura Extract + Pump       ║                           ║
║ Giorno 29 ║ 💻 1h: Initial Load + Replicat        ║ Replica Oracle→PG attiva  ║
║           ║ 💻 1h: Test CDC (INSERT/UPDATE/DELETE)║ CDC funzionante!          ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 1h: Cutover simulato              ║                           ║
║ Giorno 30 ║ 💻 1h: Validazione post-migrazione    ║ Migrazione completata!    ║
║           ║ 📝 1h: Aggiorna CV + ripasso finale   ║ 🏆 LAB COMPLETO! 🏆       ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🏗️ SETTIMANA 7: 🎯 Preparazione Esame 1Z0-082 — Admin I + SQL (Giorni 31-35)

> **Obiettivo**: Ripasso intensivo di tutti gli argomenti d'esame 1Z0-082. Pratica SQL e concetti di amministrazione.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║  GIORNO   ║  COSA FAI (3 ore)                    ║  OBIETTIVO FINE GIORNATA  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1h: Ripasso Parte 1-2 (Architet-  ║                           ║
║ Giorno 31 ║   tura, Instance Mgmt, Startup/SHUT) ║ Architecture OK           ║
║           ║ 💻 1h: Pratica startup/shutdown su   ║ V$ e DBA_ views OK        ║
║           ║   lab RAC + query V$, DBA_ views     ║                           ║
║           ║ 📖 1h: Ripasso Parte 3 (Users/Roles) ║ Profiles + Audit OK       ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1h: Ripasso Parte 4-5 (Storage,   ║                           ║
║ Giorno 32 ║   Data Movement, External Tables)    ║ DataPump + SQL*Loader OK  ║
║           ║ 💻 1h: Pratica expdp/impdp + sqlldr  ║                           ║
║           ║ 📖 1h: Ripasso Parte 7 (Net Svc)     ║ Listener + TNS OK         ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1h: Ripasso Parte 8-9 (Tablespace ║                           ║
║ Giorno 33 ║   Undo, OMF)                         ║ Tablespace + Undo OK      ║
║           ║ 💻 2h: SQL intensivo Parte 10 —      ║ 100 query SQL eseguite     ║
║           ║   JOIN, subqueries, group functions   ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 💻 2h: SQL avanzato — DDL, DML,      ║                           ║
║ Giorno 34 ║   SET operators, conversioni, NVL,   ║ SQL padroneggiato         ║
║           ║   sequences, views, constraints      ║                           ║
║           ║ 💻 1h: Pratica su lab con HR schema   ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📝 2h: Simulazione esame 1Z0-082     ║                           ║
║ Giorno 35 ║   (practice exam online)              ║ Score ≥ 75% target        ║
║           ║ 📖 1h: Rivedi risposte sbagliate     ║ ⭐ PRONTO PER 1Z0-082!   ║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## 🏗️ SETTIMANA 8: 🎯 Preparazione Esame 1Z0-083 — DBA Professional 2 (Giorni 36-40)

> **Obiettivo**: Ripasso intensivo argomenti avanzati 1Z0-083. Multitenant, RMAN, Performance, Security, Patching.

```
╔═══════════╦══════════════════════════════════════╦═══════════════════════════╗
║  GIORNO   ║  COSA FAI (3 ore)                    ║  OBIETTIVO FINE GIORNATA  ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1.5h: Ripasso 11.8 (Multitenant  ║                           ║
║ Giorno 36 ║   CDB/PDB, App containers, Lockdown)║ Multitenant padroneggiato ║
║           ║ 💻 1.5h: Pratica CDB/PDB su lab —   ║ Plug/Unplug testato       ║
║           ║   create, clone, plug, unplug PDB    ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1h: Ripasso 11.9 (RMAN Backup &  ║                           ║
║ Giorno 37 ║   Recovery Workshop, Flashback)      ║ RMAN avanzato OK          ║
║           ║ 💻 1h: Pratica RMAN su lab — backup  ║ Flashback PDB testato     ║
║           ║   PDB, validate, flashback table     ║                           ║
║           ║ 📖 1h: Ripasso 11.10 (Deploy/Patch)  ║ Upgrade path compreso     ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1h: Ripasso 11.12 (Performance   ║                           ║
║ Giorno 38 ║   AWR/ADDM/ASH, Memory, Wait Events)║ AWR report generato       ║
║           ║ 💻 1h: Genera AWR/ADDM su lab RAC    ║ ADDM raccomandazioni OK   ║
║           ║ 📖 1h: Ripasso 11.13 (SQL Tuning     ║ Optimizer compreso        ║
║           ║   Advisor, Optimizer Statistics)      ║                           ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📖 1h: Ripasso 11.1-11.2 (ASM, RAC  ║                           ║
║ Giorno 39 ║   Data Guard, HA, Security)          ║ HA + Security OK          ║
║           ║ 💻 1h: Ripasso 11.6 (TDE, Audit)    ║ TDE concetti chiari       ║
║           ║ 📖 1h: Ripasso 11.11 (19c Features) ║ New Features comprese     ║
╠═══════════╬══════════════════════════════════════╬═══════════════════════════╣
║           ║ 📝 2h: Simulazione esame 1Z0-083     ║                           ║
║ Giorno 40 ║   (practice exam online)              ║ Score ≥ 75% target        ║
║           ║ 📖 1h: Rivedi risposte sbagliate     ║ ⭐ PRONTO PER 1Z0-083!   ║
║           ║                                      ║ 🏆🏆 PERCORSO COMPLETO! 🏆🏆║
╚═══════════╩══════════════════════════════════════╩═══════════════════════════╝
```

---

## ⚡ Consigli per Andare Veloce

| Consiglio | Perché |
|---|---|
| **Scarica TUTTO il primo giorno** | Non perdere tempo aspettando download da 3GB a metà installazione |
| **Usa 2 terminali** | Uno per i comandi, uno per l'alert log (`tail -f alert*.log`) |
| **Copia i comandi dalla guida** | Non digitarli a mano — errori di battitura = nemico n.1 |
| **Fai SEMPRE lo snapshot PRIMA** | 30 secondi di snapshot vs 3 ore di reinstallazione |
| **Se qualcosa fallisce, leggi l'alert log** | La risposta è quasi sempre lì |
| **Non saltare i test intermedi** | Un `ping` che fallisce al giorno 2 diventa un incubo al giorno 10 |

---

## 🎯 Dopo il Lab: Cosa Mettere nel CV

```
┌──────────────────────────────────────────────────────────────┐
│                    COMPETENZE ORACLE                         │
│                                                              │
│  ✅ Oracle RAC 19c (2-Node cluster, Cache Fusion, ASM)       │
│  ✅ Oracle Data Guard (Physical Standby, DGMGRL, ADG)        │
│  ✅ Data Guard Switchover & Failover (FSFO, Reinstate)       │
│  ✅ Oracle GoldenGate (Integrated Extract, CDC, Migration)   │
│  ✅ Oracle → PostgreSQL Migration con GoldenGate             │
│  ✅ Oracle Cloud Infrastructure (OCI) — Free Tier ARM        │
│  ✅ Hybrid Architecture (On-Prem → Cloud via SSH Tunnel)     │
│  ✅ Zero-Downtime Migration con GoldenGate                   │
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
│  Progetto Lab: Architettura enterprise ibrida con            │
│  RAC → Data Guard → GoldenGate → OCI Cloud → PostgreSQL   │
│  su 6+ nodi                                                  │
└──────────────────────────────────────────────────────────────┘
```

---

## 📚 Risorse Extra: Enterprise DBA Toolkit (studio_ai/)

> Usa queste risorse per arricchire lo studio con procedure e script operativi reali.

| Settimana | Quando Usare | Cartella studio_ai |
|---|---|---|
| **Sett. 1** (Giorno 4: ASM disks) | Dopo aver configurato ASMLib | [01_asm_storage/](../studio_ai/01_asm_storage/) + [GUIDA_AGGIUNTA_DISCHI_ASM](../GUIDA_AGGIUNTA_DISCHI_ASM.md) |
| **Sett. 2** (Giorno 9: Grid) | Dopo aver installato Grid | [05_patching/](../studio_ai/05_patching/) |
| **Sett. 3** (Giorno 11: DG) | Dopo aver configurato Data Guard | [02_dataguard/](../studio_ai/02_dataguard/) |
| **Sett. 3** (Giorno 15: RMAN) | Dopo aver configurato RMAN | [06_backup_recovery/](../studio_ai/06_backup_recovery/) |
| **Sett. 4** (Giorno 19: Listener) | Dopo Listener/Services | [04_user_management/](../studio_ai/04_user_management/) |
| **Sett. 4** (Giorno 20: DBA) | Dopo attività DBA | [03_monitoring_scripts/](../studio_ai/03_monitoring_scripts/) + [07_performance_tuning/](../studio_ai/07_performance_tuning/) |
| **Sett. 5** (Giorno 24: Patching) | Dopo ripasso patching | [08_tde_security/](../studio_ai/08_tde_security/) |

---

> 💡 **Suggerimento finale**: Quando fai un colloquio, non dire "ho seguito una guida". Dì "ho progettato e implementato da zero un'architettura Oracle RAC con Data Guard e GoldenGate su 6 nodi, inclusa integrazione cloud con OCI". È la verità — la guida l'hai letta, ma i comandi li hai eseguiti tu, gli errori li hai risolti tu, e la comprensione è tua.
