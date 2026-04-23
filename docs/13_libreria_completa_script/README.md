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
├── 01_asm_storage/          ← Gestione dischi ASM: add, remove, migrate LUN
├── 02_dataguard/            ← Data Guard: config, verifica GAP, recovery DR
├── 03_monitoring_scripts/   ← 586 script monitoraggio (sessioni, lock, I/O, ASH, rete)
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
├── 04_user_management/      ← Creazione utenti, profili password, Oracle Vault
├── 05_patching/             ← Procedure patching, Golden Images (OHCTL)
├── 06_backup_recovery/      ← Flashback, Restore Point, verifiche RMAN
├── 07_performance_tuning/   ← 225 script: SPM, AWR analysis, statistiche
│   └── community_scripts/   ← Script performance dalla community Oracle
│
├── 08_tde_security/         ← Transparent Data Encryption, Vault, audit
├── 09_compression/          ← Compressione HCC, DBMS_REDEFINITION online
├── 10_partition_manager/    ← Package gestione automatica partizioni
├── 11_sql_templates/        ← Template DDL/DML standard con error handling
└── 12_utilities/            ← Utility: TEMP/UNDO monitor, MView refresh, profili
    └── community_scripts/   ← 98 script utility dalla community
        ├── bin/             ← Script bash/perl operativi
        ├── cdb_pdb/         ← Query CDB/PDB
        ├── scheduler/       ← Oracle Scheduler jobs
        └── storage/         ← Storage e tablespace
```

---

<details>
  <summary>🧭 Dettaglio rapido per sottodirectory principali (click per espandere)</summary>

- [01_asm_storage/](./01_asm_storage/) — add/remove ASM disk, procedure storage, note operative.
- [02_dataguard/](./02_dataguard/) — runbook e note Data Guard (gap, recovery, servizi read-only).
- [03_monitoring_scripts/](./03_monitoring_scripts/) — monitoraggio esteso (sessioni, lock, I/O, ASH, rete) + community.
- [04_user_management/](./04_user_management/) — template per utenti, ruoli, profili password.
- [05_patching/](./05_patching/) — asset di patching e golden image workflow.
- [06_backup_recovery/](./06_backup_recovery/) — RMAN check, flashback, restore point.
- [07_performance_tuning/](./07_performance_tuning/) — tuning SQL e performance scripts (SPM/AWR/stats).
- [08_tde_security/](./08_tde_security/) — script e note security/TDE.
- [09_compression/](./09_compression/) — compressione e supporto a redefinition.
- [10_partition_manager/](./10_partition_manager/) — automazione gestione partizioni.
- [11_sql_templates/](./11_sql_templates/) — template SQL standardizzati con error handling.
- [12_utilities/](./12_utilities/) — utility operative (TEMP/UNDO, scheduler, CDB/PDB, storage).

</details>

---

## 📊 Indice per Area (conteggio script operativi)

| # | Area | Script operativi | Cosa Trovi | Quando Lo Usi |
|---|---|---|---|---|
| 01 | [ASM & Storage](./01_asm_storage/) | 26 | Add/remove disco ASM, health check storage, failgroup | Capacity planning, sostituzione LUN |
| 02 | [Data Guard](./02_dataguard/) | 0 | Categoria documentale/runbook DG | Setup standby, troubleshooting replica |
| 03 | [Monitoring](./03_monitoring_scripts/) | **560** | Sessioni, lock, CPU, I/O, ASH, rete, DRCP, MView | **Ogni giorno!** Morning check, incident |
| 04 | [Utenti](./04_user_management/) | 5 | Template creazione utenti, profili, password policy | Richiesta HR, nuova applicazione |
| 05 | [Patching](./05_patching/) | 2 | Template/asset patching operativi | Quarterly patching window |
| 06 | [Backup & Recovery](./06_backup_recovery/) | 12 | Flashback, Restore Point, RMAN checks | Pre-upgrade, disaster recovery |
| 07 | [Performance](./07_performance_tuning/) | **230** | SPM, AWR, analisi statistiche, SQL tuning | Query lente, capacity, review settimanale |
| 08 | [TDE & Security](./08_tde_security/) | 8 | Transparent Data Encryption, audit, Vault | Compliance, audit sicurezza |
| 09 | [Compressione](./09_compression/) | 1 | DDL di supporto a compressione/redefinition | Ridurre storage, near-zero downtime |
| 10 | [Partition Manager](./10_partition_manager/) | 2 | Package gestione partizioni automatiche | Tabelle > 100M righe |
| 11 | [Template SQL](./11_sql_templates/) | 17 | Template DDL/DML standard con error handling | Sviluppo, standardizzazione |
| 12 | [Utility](./12_utilities/) | **102** | TEMP/UNDO monitor, MView refresh, profili UNIX | Supporto quotidiano, troubleshooting |
| | **TOTALE** | **965** | | |

---

## 🔍 Guida Rapida: "Ho un problema, quale script mi serve?"

| Problema | Dove Cercare | Script Chiave |
|---|---|---|
| "L'app è bloccata!" | `03_monitoring_scripts/community_jkstill/sessions_locks/` | `blocking_sessions.sql`, `lock_tree.sql` |
| "Il database è lento!" | `07_performance_tuning/community_scripts/` | Top SQL, wait events, ASH |
| "Tablespace pieno!" | `12_utilities/community_scripts/storage/` | `showdf.sql`, `showfree.sql`, `showtbs.sql` |
| "UNDO pieno!" | `12_utilities/community_scripts/storage/` | `undo_stats.sql`, `undo_retention_available.sql` |
| "Chi è connesso?" | `03_monitoring_scripts/community_jkstill/users_logged/` | Login audit, sessioni attive |
| "Job fallito" | `12_utilities/community_scripts/scheduler/` | `dba_jobs_running.sql`, `show_jobs.sql` |
| "MView non refresha" | `03_monitoring_scripts/community_jkstill/mviews/` | MView log, refresh status |
| "Serve un nuovo utente" | `04_user_management/` | Template con profili e grant |
| "Data Guard in GAP" | `02_dataguard/` | Verifica GAP, MRP status |
| "Serve compressione" | `09_compression/` | DBMS_REDEFINITION online |

---

## 🚀 Come Usare Questa Libreria

```bash
# 1. Collegati al database
sqlplus / as sysdba

# 2. Esegui lo script che ti serve
@libreria_oracle/03_monitoring_scripts/community_jkstill/sessions_locks/blocking_sessions.sql

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
| ASM & Storage | Guida Aggiunta Dischi | [04_administration/](../04_administration/) |
| Monitoring | Comandi DBA + Health Check | [11_runbook_operativi/](../11_runbook_operativi/) |
| Data Guard | Fase 4 Data Guard + DGMGRL | [02_high_availability/](../02_high_availability/) |
| Performance | Guida Troubleshooting | [05_performance/](../05_performance/) |
| Backup | Guida RMAN Completa | [03_backup_recovery/](../03_backup_recovery/) |

> Vedi anche: [12_scripts_sql_pronti/](../12_scripts_sql_pronti/) — 10 script SQL sintetici per scenario (la versione "quick" di questa libreria).
