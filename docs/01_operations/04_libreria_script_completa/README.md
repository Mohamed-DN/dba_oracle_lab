# 📚 Libreria Oracle DBA — Script e Procedure Enterprise

> **~1000 script SQL e procedure** organizzati per area operativa, estratti da ambienti Enterprise reali.
> Ogni sezione ha un README che spiega **cosa fa**, **quando usarlo**, e **come eseguirlo**.

📘 **Nuovo catalogo completo script-per-script**: [CATALOGO_COMPLETO_SCRIPT.md](./CATALOGO_COMPLETO_SCRIPT.md)
  
🏷️ **Etichette script**: [SCRIPT_QUALITY_LABELS.csv](./SCRIPT_QUALITY_LABELS.csv) · [Policy etichette](./SCRIPT_LABELING_POLICY.md)  
✅ **Top script certificati**: [TOP_SCRIPT_CERTIFICATI.md](./TOP_SCRIPT_CERTIFICATI.md)

---

## 🗂️ Mappa della Libreria

```
libreria_oracle/
│
├── asm_storage/          ← Gestione dischi ASM: add, remove, migrate LUN
├── dataguard/            ← Data Guard: config, verifica GAP, recovery DR
├── monitoring_scripts/   ← 586 script monitoraggio (sessioni, lock, I/O, ASH, rete)
│   ├── community_gwenshap/  ← 25 script da GwenShap (Oracle ACE)
│   └── community_jkstill/   ← 509 script da Jared Still (Oracle guru)
│       ├── sessions_locks/  ← Lock, blocking, kill session
│       ├── io_redo/         ← I/O statistiche, redo log analysis
│       ├── users_logged/    ← Utenti connessi, audit login
│       ├── dates/           ← Funzioni data Oracle
│       ├── drcp/            ← Database Resident Connection Pooling
│       ├── instance_db/     ← Parametri istanza, NLS, versione
│       ├── metrics/         ← V$METRIC, V$SYSMETRIC
│       ├── mviews/          ← Materialized Views: refresh, log, stato
│       ├── plsql/           ← PL/SQL utilities
│       ├── rdbms_utilities/ ← DBMS_SCHEDULER, DBMS_STATS, etc.
│       ├── resource_manager/← Resource Manager plans
│       ├── temp_sorts/      ← TEMP usage, sort operations
│       └── general/         ← 359 script generali (il cuore della collezione)
│
├── user_management/      ← Creazione utenti, profili password, Oracle Vault
├── patching/             ← Procedure patching, Golden Images (OHCTL)
├── backup_recovery/      ← Flashback, Restore Point, verifiche RMAN
├── performance_tuning/   ← 225 script: SPM, AWR analysis, statistiche
│   └── community_scripts/   ← Script performance dalla community Oracle
│
├── tde_security/         ← Transparent Data Encryption, Vault, audit
├── compression/          ← Compressione HCC, DBMS_REDEFINITION online
├── partition_manager/    ← Package gestione automatica partizioni
├── sql_templates/        ← Template DDL/DML standard con error handling
└── utilities/            ← Utility: TEMP/UNDO monitor, MView refresh, profili
    └── community_scripts/   ← 98 script utility dalla community
        ├── bin/             ← Script bash/perl operativi
        ├── cdb_pdb/         ← Query CDB/PDB
        ├── scheduler/       ← Oracle Scheduler jobs
        └── storage/         ← Storage e tablespace
```

---

<details>
  <summary>🧭 Dettaglio rapido per sottodirectory principali (click per espandere)</summary>

- [asm_storage/](./asm_storage/) — add/remove ASM disk, procedure storage, note operative.
- [dataguard/](./dataguard/) — runbook e note Data Guard (gap, recovery, servizi read-only).
- [monitoring_scripts/](./monitoring_scripts/) — monitoraggio esteso (sessioni, lock, I/O, ASH, rete) + community.
- [user_management/](./user_management/) — template per utenti, ruoli, profili password.
- [patching/](./patching/) — asset di patching e golden image workflow.
- [backup_recovery/](./backup_recovery/) — RMAN check, flashback, restore point.
- [performance_tuning/](./performance_tuning/) — tuning SQL e performance scripts (SPM/AWR/stats).
- [tde_security/](./tde_security/) — script e note security/TDE.
- [compression/](./compression/) — compressione e supporto a redefinition.
- [partition_manager/](./partition_manager/) — automazione gestione partizioni.
- [sql_templates/](./sql_templates/) — template SQL standardizzati con error handling.
- [utilities/](./utilities/) — utility operative (TEMP/UNDO, scheduler, CDB/PDB, storage).

</details>

---

## 📊 Indice per Area (conteggio script operativi)

| # | Area | Script operativi | Cosa Trovi | Quando Lo Usi |
|---|---|---|---|---|
| 01 | [ASM & Storage](./asm_storage/) | 26 | Add/remove disco ASM, health check storage, failgroup | Capacity planning, sostituzione LUN |
| 02 | [Data Guard](./dataguard/) | 0 | Categoria documentale/runbook DG | Setup standby, troubleshooting replica |
| 03 | [Monitoring](./monitoring_scripts/) | **560** | Sessioni, lock, CPU, I/O, ASH, rete, DRCP, MView | **Ogni giorno!** Morning check, incident |
| 04 | [Utenti](./user_management/) | 5 | Template creazione utenti, profili, password policy | Richiesta HR, nuova applicazione |
| 05 | [Patching](./patching/) | 2 | Template/asset patching operativi | Quarterly patching window |
| 06 | [Backup & Recovery](./backup_recovery/) | 12 | Flashback, Restore Point, RMAN checks | Pre-upgrade, disaster recovery |
| 07 | [Performance](./performance_tuning/) | **230** | SPM, AWR, analisi statistiche, SQL tuning | Query lente, capacity, review settimanale |
| 08 | [TDE & Security](./tde_security/) | 8 | Transparent Data Encryption, audit, Vault | Compliance, audit sicurezza |
| 09 | [Compressione](./compression/) | 1 | DDL di supporto a compressione/redefinition | Ridurre storage, near-zero downtime |
| 10 | [Partition Manager](./partition_manager/) | 2 | Package gestione partizioni automatiche | Tabelle > 100M righe |
| 11 | [Template SQL](./sql_templates/) | 17 | Template DDL/DML standard con error handling | Sviluppo, standardizzazione |
| 12 | [Utility](./utilities/) | **102** | TEMP/UNDO monitor, MView refresh, profili UNIX | Supporto quotidiano, troubleshooting |
| | **TOTALE** | **965** | | |

---

## 🔍 Guida Rapida: "Ho un problema, quale script mi serve?"

| Problema | Dove Cercare | Script Chiave |
|---|---|---|
| "L'app è bloccata!" | `monitoring_scripts/sessions_locks/` | `blocking_sessions.sql`, `lock_tree.sql` |
| "Il database è lento!" | `performance_tuning/` | Top SQL, wait events, ASH |
| "Tablespace pieno!" | `utilities/storage/` | `showdf.sql`, `showfree.sql`, `showtbs.sql` |
| "UNDO pieno!" | `utilities/storage/` | `undo_stats.sql`, `undo_retention_available.sql` |
| "Chi è connesso?" | `monitoring_scripts/users_logged/` | Login audit, sessioni attive |
| "Job fallito" | `utilities/scheduler/` | `dba_jobs_running.sql`, `show_jobs.sql` |
| "MView non refresha" | `monitoring_scripts/mviews/` | MView log, refresh status |
| "Serve un nuovo utente" | `user_management/` | Template con profili e grant |
| "Data Guard in GAP" | `dataguard/` | Verifica GAP, MRP status |
| "Serve compressione" | `compression/` | DBMS_REDEFINITION online |

---

## 🚀 Come Usare Questa Libreria

```bash
# 1. Collegati al database
sqlplus / as sysdba

# 2. Esegui lo script che ti serve
@libreria_oracle/monitoring_scripts/sessions_locks/blocking_sessions.sql

# 3. Oppure copia-incolla i blocchi SQL che ti servono
```

### ⚠️ Regole di Sicurezza

- **Leggi SEMPRE lo script prima di eseguirlo** — alcuni fanno modifiche (ALTER, DROP)
- **Testa in lab PRIMA** della produzione
- **I community_scripts** vengono da DBA Oracle riconosciuti, ma adatta a tuo ambiente

---

## 🔗 Collegamento al Progetto Principale

| Libreria | Si collega a | Nel progetto |
|---|---|---|
| ASM & Storage | Guida Aggiunta Dischi | [02_core_dba/01_administration_and_security/](../../02_core_dba/01_administration_and_security/) |
| Monitoring | Comandi DBA + Health Check | [01_operations/02_runbooks_incidenti/](../../01_operations/02_runbooks_incidenti/) |
| Data Guard | Fase 4 Data Guard + DGMGRL | [02_core_dba/04_high_availability_and_rac/](../../02_core_dba/04_high_availability_and_rac/) |
| Performance | Guida Troubleshooting | [02_core_dba/03_performance_and_diagnostics/](../../02_core_dba/03_performance_and_diagnostics/) |
| Backup | Guida RMAN Completa | [02_core_dba/02_backup_and_recovery/](../../02_core_dba/02_backup_and_recovery/) |

> Vedi anche: [01_operations/03_scripts_pronti/](../../01_operations/03_scripts_pronti/) — 10 script SQL sintetici per scenario (la versione "quick" di questa libreria).
