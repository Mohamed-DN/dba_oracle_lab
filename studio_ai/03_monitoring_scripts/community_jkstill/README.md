# 📦 Oracle Script Library — Community Scripts (jkstill)

> **Fonte**: [github.com/jkstill/oracle-script-lib](https://github.com/jkstill/oracle-script-lib)
> **Licenza**: MIT License
> **Autore**: Jared Still — Oracle DBA veterano con oltre 30 anni di esperienza

Questa raccolta contiene script SQL professionali selezionati dalla libreria open source di Jared Still.
Sono organizzati per categoria e pronti all'uso con SQL*Plus.

---

## 📂 Organizzazione

### 🔥 ash_awr/ — Active Session History e Automatic Workload Repository
Script fondamentali per l'analisi delle performance. Qui trovi tutto per:
- Calcolare **Average Active Sessions** (AAS)
- Trovare i **top SQL** per consumo risorse
- Identificare **blockers** storici
- Generare **report AWR non-interattivi** (utilissimo per automazione!)
- Analisi **CPU** storica

| Script | Descrizione |
|---|---|
| `aas.sql` | Average Active Sessions da gv$sysmetric |
| `ash-blocker-waits.sql` | Trova i blockers principali in ASH |
| `ash-current-waits.sql` | Waits correnti per SQL per classe ed evento |
| `ash-top-events.sql` | Top 10 eventi in ASH (per istanza e cluster) |
| `ash_blocking.sql` | Row lock: bloccati e bloccanti con SQL_ID |
| `ash_cpu_hist.sql` | Storico CPU da dba_hist_sysmetric_history (12c+) |
| `ashtop.sql` | Script di Tanel Poder per top ASH events |
| `awr-cpu-stats.sql` | Report CPU simile a `sar` da AWR |
| `awr-top-5-events.sql` | Top 5 eventi degli ultimi 7 giorni |
| `awr-top-10-daily.sql` | Top 10 eventi per giorno da AWR |
| `awr_defined.sql` | Report AWR non-interattivo (specificando snap_id) |
| `awr_RAC_defined.sql` | Report AWR non-interattivo su RAC |
| `top10-sql-ash.sql` | Top SQL (per frequenza) da ASH |
| `top10-sql-awr.sql` | Top SQL (per frequenza) da AWR ultimi 30 giorni |
| `get-binds.sql` | Valori bind da dba_hist_sqlbind |
| `getsql-awr.sql` | Testo SQL da AWR per SQL_ID |

---

### 🔒 locks_waits/ — Lock, Waits, Latches e Performance
| Script | Descrizione |
|---|---|
| `showlock2.sql` | Lock con waiters e blockers (12c+, raccomandato) |
| `showlatch.sql` | Latches e statistiche |
| `snapper.sql` | Script leggendario di Tanel Poder |
| `sesswait.sql` | Waits da v$session_wait |
| `active_status.sql` | Sessioni attive su CPU |
| `concurrency-waits-sqlid.sql` | Concurrency waits per SQL_ID |
| `itl_waits.sql` | ITL waits (incrementare initrans se presenti) |

---

### 💽 io/ — Input/Output e Redo
| Script | Descrizione |
|---|---|
| `avg_disk_times.sql` | Tempi medi read/write fisici |
| `ioweight.sql` | I/O per tablespace ordinato per peso |
| `lfsdiag.sql` | Diagnosi logfile sync (fondamentale per performance!) |
| `redo-per-second.sql` | Min/max redo generato al secondo |
| `redo-rate.sql` | Redo rate in tempo reale |
| `showtrans.sql` | Transazioni correnti con I/O |
| `trans_per_hour.sql` | Transazioni per ora con statistiche |

---

### 🎯 tuning/ — SQL Tuning
| Script | Descrizione |
|---|---|
| `dbms-sqltune-sqlid.sql` | Crea ed esegui un Tuning Task per un SQL_ID |
| `find-expensive-sql.sql` | Trova SQL costosi (alto LIO) da AWR |
| `profile_from_awr.sql` | Crea un SQL Profile da un piano in AWR |

---

### 💾 storage/ — Tablespace, Datafile, Undo
| Script | Descrizione |
|---|---|
| `showdf.sql` | Tutti i datafile con informazioni |
| `showtbs.sql` | Tutti i tablespace con info |
| `showfree.sql` | Spazio libero per tablespace |
| `dfshrink-gen.sql` | Genera codice per shrink datafile |
| `undo_stats.sql` | Statistiche UNDO (ORA-1555 detection) |
| `undo_blocks_required.sql` | Calcolo spazio UNDO necessario |

---

### 📀 asm/ — Automatic Storage Management
| Script | Descrizione |
|---|---|
| `asm_diskgroups.sql` | Stato diskgroup |
| `asm_disks.sql` | Dettaglio dischi ASM |
| `asm_disk_errors.sql` | Errori disco ASM |
| `asm_disk_stats.sql` | Statistiche I/O per disco |
| `asm_failgroup_members.sql` | Membri per failgroup |
| `asm_files.sql` | File nei diskgroup |
| `asm_files_path.sql` | File ASM con path completo |
| `asm_extent_distribution.sql` | Distribuzione extent tra dischi |

---

### 📊 stats_optimizer/ — Statistiche e Optimizer
| Script | Descrizione |
|---|---|
| `show-stale-stats.sql` | Tabelle con statistiche obsolete |
| `table-last-analyzed.sql` | Data ultimo ANALYZE per tabella |
| `optimizer-env.sql` | Ambiente optimizer corrente |
| `extended-stats.sql` | Statistiche estese (multi-colonna) |

---

### 🔧 Altre Categorie
- **sessions/** — Query `who*.sql` per vedere sessioni attive
- **memory/** — SGA/PGA advisor e configurazione
- **parameters/** — Parametri (inclusi hidden)
- **execution_plans/** — Visualizzazione piani di esecuzione
- **cdb_pdb/** — Script specifici per Container/Pluggable DB
- **scheduler/** — Job schedulati e autotask
- **instance_db/** — Info istanza, SGA, DB links, registry
- **backup_recovery/** — Progresso RMAN, restore point
- **auditing/** — Unified Auditing

---

## 🎯 Come Usarli

```bash
# Connettiti come DBA
sqlplus / as sysdba

# Esempio: trova i top 10 SQL da ASH
@/path/to/studio_ai/03_monitoring_scripts/community_jkstill/ash_awr/top10-sql-ash.sql

# Esempio: report AWR non-interattivo
@/path/to/studio_ai/03_monitoring_scripts/community_jkstill/ash_awr/awr_defined.sql
```

> [!TIP]
> Lo script `snapper.sql` di Tanel Poder è considerato uno degli script Oracle più potenti mai creati.
> Permette di fare sampling delle sessioni in tempo reale senza impatto sulle performance.
