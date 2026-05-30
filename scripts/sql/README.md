# 📚 Libreria SQL Oracle — ScriptDBA Collection

> **Fonte**: [scriptdba.com/query-sql](https://www.scriptdba.com/query-sql/)
> **Script totali**: 82 | **Ultima sincronizzazione**: 2026-05-15

Questa directory contiene tutti gli script SQL estratti dal sito [ScriptDBA.com](https://www.scriptdba.com/query-sql/), organizzati per categoria funzionale.

---

## 📂 Struttura delle Cartelle

| Cartella | # Script | Descrizione |
|---|---|---|
| `sessioni/` | 16 | Gestione sessioni Oracle: SID, lock, kill, RMAN, disconnect |
| `crs/` | 13 | Comandi CRS/SRVCTL: start/stop cluster, database, listener, service |
| `oggetti/` | 8 | Gestione oggetti: invalidi, LOB, top objects, compilazione |
| `tablespace/` | 6 | Spazio tablespace: datafile, tempfile, autoextend, recovery spazio |
| `job/` | 5 | Oracle Job: status, running, broken, remove, enable |
| `utenti/` | 5 | Gestione utenti: ruoli, privilegi sistema, oggetti, DDL, password |
| `indici/` | 4 | Indici: dimensione, invalidi, partizionati, rebuild |
| `asm/` | 4 | ASM: DiskGroup, LUN candidate, rebalance |
| `performance/` | 4 | Analisi performance: SQL_ID, explain plan, sessioni attive |
| `tuning/` | 3 | Tuning: SGA, Redo Log, Flashback, RAC |
| `redolog/` | 3 | Redo Log: status, switch count, archive production |
| `linux/` | 3 | Linux/VirtualBox: installazione, configurazione IP |
| `datapump/` | 2 | DataPump: export e import |
| `extent/` | 2 | Extent: dimensione e gestione |
| `misc/` | 3 | Varie: Multitenant, SQL Server, Plan Hash Value |
| `installazione/` | 1 | Moduli Oracle: DBD::Oracle |
| `ddl/` | 0 | Estrazione DDL oggetti (in espansione) |

---

## 🚀 Come Usare gli Script

Ogni file `.sql` contiene:
1. **Header** con link alla fonte originale e titolo
2. **Codice SQL** pronto all'uso in SQL*Plus, SQLcl o un qualsiasi client Oracle

### Eseguire in SQL*Plus
```bash
sqlplus /@//host:1521/ORCL as sysdba
SQL> @scripts/sql/sessioni/KILL_sessioni_UTENTE_Oracle.sql
```

### Eseguire con SQLcl
```bash
sql /@//host:1521/ORCL as sysdba
SQL> script scripts/sql/utenti/Query_stato_password_utente_Oracle.sql
```

---

## 🔍 Script Più Importanti per Categoria

### 🔒 Sessioni
- `Query_sessioni_SID_Oracle.sql` — Dettagli sessione da SID
- `KILL_sessioni_UTENTE_Oracle_su_RAC.sql` — Kill sessioni su tutte le istanze RAC
- `Query_sessioni_detentrici_di_LOCK.sql` — Chi detiene lock
- `Query_LOCK_e_numero_sessioni_Oracle.sql` — Blocco del database in breve tempo

### 👤 Utenti
- `DDL_di_creazione_UTENZA__RUOLI_e_PRIVILEGI.sql` — DDL completo di un utente
- `Query_PRIVILEGI_UTENTE_replicati.sql` — Clona privilegi tra utenti
- `Query_stato_password_utente_Oracle.sql` — Stato password, profilo, ruoli

### 📊 Performance
- `Query_per_estrarre_lo_statement_da_SQL_ID.sql` — Testo statement da SQL_ID
- `Query_per_vedere_i_consumi_di_risorse_delle_sessioni_attive.sql` — Top sessioni per risorse

### 💾 Tablespace / ASM
- `Query_per_vedere_le_dimensioni_di_tutte_le_TABLESPACE_del_database_Oracle.sql`
- `Query_ASM_LUN_CANDIDATE.sql` — LUN candidate per ASM
