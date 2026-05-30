# RUNBOOK ENTERPRISE: INCIDENT RESPONSE & KEDB (Known Error Database)

> **Document Classification:** STRICTLY CONFIDENTIAL / ENTERPRISE OPERATIONS  
> **Last Updated:** Maggio 2026  
> **Target Audience:** On-Call DBA, L2/L3 Support, SREs  
> **Purpose:** Fornire procedure di risoluzione deterministiche (SOP) per gli incidenti P1/P2 in ambienti Oracle Database Mission-Critical.

## SOMMARIO ELETTRONICO
1. [Metodologia di Triage Iniziale](#1-metodologia-di-triage-iniziale)
2. [Gestione Memoria (ORA-04031, ORA-04030)](#2-gestione-memoria-ora-04031-ora-04030)
3. [Gestione Spazio (ORA-01555, ASM ORA-15041)](#3-gestione-spazio-ora-01555-asm-ora-15041)
4. [Gestione Lock & Performance (enq: TX - row lock)](#4-gestione-lock--performance-enq-tx---row-lock)
5. [Disaster Recovery & Data Guard Gaps](#5-disaster-recovery--data-guard-gaps)
6. [Gestione Corruzioni (ORA-01578, ORA-00600)](#6-gestione-corruzioni-ora-01578-ora-00600)
7. [Listener & Connectivity (ORA-12170, TNS-12541)](#7-listener--connectivity-ora-12170-tns-12541)

---

## 1. Metodologia di Triage Iniziale

Quando scatta un allarme critico (PagerDuty, CheckMK) alle 3:00 di notte, l'operatore non deve improvvisare. Deve seguire il "Golden Path" del Triage.

### 1.1. L'Istanza è Raggiungibile?
- **NO**: 
  1. Ping IP / SSH sull'host.
  2. Verifica processo PMON: `ps -ef | grep pmon`. Se assente, l'istanza è crashata. Cercare `ORA-` nell'Alert Log.
  3. Verifica Listener: `lsnrctl status`.
- **SI, ma lentezza estrema**:
  1. Connessione BEQ (Bequest) bypassing il listener: `sqlplus -prelim / as sysdba`.
  2. Esecuzione script di Hanganalyze (vedi sezione Performance).

### 1.2. Alert Log Mining (Gli ultimi 1000 eventi)
```bash
# Entrare in ADRCI
adrci
adrci> show alert -tail 1000
```
Cercare specificamente: `ORA-00600`, `ORA-07445`, `Evicting node`, `Deadlock`.

---

## 2. Gestione Memoria (ORA-04031, ORA-04030)

### 2.1. ORA-04031: Unable to allocate X bytes of shared memory
**Significato**: La Shared Pool (parte della SGA) è completamente frammentata o esaurita. Il database rifiuterà nuove connessioni e fallirà il parsing SQL.

**Diagnosi Immediata**:
```sql
SELECT pool, name, bytes/1024/1024 AS MB
FROM v$sgastat
WHERE pool = 'shared pool'
ORDER BY bytes DESC
FETCH FIRST 10 ROWS ONLY;
```
*Se `free memory` è < 10MB e ci sono enormi `KGLH0` o `sql area`, l'applicazione non sta usando bind variables.*

**Risoluzione Tattica (Workaround immediato per ripristinare il servizio):**
L'unico modo per pulire la frammentazione senza riavviare l'istanza è eseguire un flush.
```sql
-- ATTENZIONE: Questo causerà uno spike di CPU immediato per il ri-parsing.
ALTER SYSTEM FLUSH SHARED_POOL;
```
Se il comando si "appende" o fallisce, è necessario l'intervento drastico:
```sql
ALTER SYSTEM SET shared_pool_size = <VALORE_MAGGIORE> SCOPE=MEMORY;
```

**Risoluzione Strategica (Post-Mortem):**
- Obbligare gli sviluppatori ad usare Bind Variables.
- Impostare `CURSOR_SHARING = FORCE` (solo previo assenso dell'Application Owner).

### 2.2. ORA-04030: Out of process memory when trying to allocate X bytes
**Significato**: Un processo utente (shadow process) ha esaurito la memoria PGA o ha saturato la RAM/Swap dell'OS.

**Diagnosi OS**:
```bash
# Verificare RAM e Swap
free -m
# Identificare i processi Oracle più voraci
top -u oracle -o %MEM
```

**Diagnosi SQL**:
```sql
SELECT s.sid, s.serial#, p.spid, s.username, s.program, p.pga_used_mem/1024/1024 AS PGA_MB
FROM v$session s JOIN v$process p ON s.paddr = p.addr
ORDER BY p.pga_used_mem DESC
FETCH FIRST 5 ROWS ONLY;
```

**Risoluzione**:
- Killare la sessione che consuma troppa PGA (generalmente colpa di `ORDER BY` o `HASH JOIN` immensi senza filtri).
```sql
ALTER SYSTEM KILL SESSION 'SID,SERIAL#' IMMEDIATE;
```

---

## 3. Gestione Spazio (ORA-01555, ASM ORA-15041)

### 3.1. ORA-01555: Snapshot too old
**Significato**: Una query molto lunga (solitamente un report o un export) sta tentando di leggere una versione del blocco passata, ma le informazioni di rollback nel tablespace UNDO sono state sovrascritte da transazioni più recenti.

**Diagnosi**:
Trovare quale query è andata in errore:
```sql
SELECT sql_id, maxquerylen, ssolderrcnt
FROM v$undostat
WHERE ssolderrcnt > 0;
```

**Risoluzione Tattica**:
L'errore ORA-01555 "si cura da solo" interrompendo la query. Non impatta il resto del database. Tuttavia, per permettere alla query di finire al prossimo tentativo:
1. **Aumentare l'Undo Retention**:
```sql
ALTER SYSTEM SET undo_retention = 21600 SCOPE=BOTH; -- (6 ore)
```
2. **Aumentare il Tablespace UNDO**: Se il disco lo permette, aggiungere un datafile.

### 3.2. ORA-15041: Diskgroup space exhausted (ASM)
**Significato**: Un Disk Group ASM (es. `+DATA` o `+FRA`) ha esaurito lo spazio. Se è il `+FRA`, il database si frizerà (non può scrivere archivelog).

**Diagnosi Immediata**:
```bash
# Come utente grid
asmcmd lsdg
```

**Risoluzione Tattica (se +FRA è pieno al 100%)**:
Il database è fermo. Gli archivelog non possono essere scritti.
1. Accedere a RMAN, verificare policy e pulire solo file eleggibili:
```bash
rman target /
RMAN> SHOW ARCHIVELOG DELETION POLICY;
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
RMAN> DELETE NOPROMPT OBSOLETE;
```
Se Data Guard e' in lag o irraggiungibile, preservare prima gli archivelog e
usare `RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md`, scenario DG-061.

**Risoluzione Tattica (se +DATA è pieno)**:
Aggiungere urgentemente un disco LUN (richiede il team Storage).
```sql
-- Dalla shell ASM:
ALTER DISKGROUP DATA ADD DISK '/dev/mapper/mpath_new' REBALANCE POWER 11;
```

---

## 4. Gestione Lock & Performance (enq: TX - row lock)

### 4.1. "Il Database è lento / Tutto fermo" (Lock Chain)
**Significato**: Una sessione ha eseguito un `UPDATE` o `DELETE` su un record senza fare `COMMIT`. Centinaia di altre sessioni stanno tentando di aggiornare lo stesso record e sono in attesa.

**Diagnosi Immediata (Ricerca del Blocker Originale)**:
Non killare le sessioni a caso. Trova la radice dell'albero.
```sql
SELECT
    blocking_session AS "Blocker",
    sid AS "Victim",
    event,
    seconds_in_wait
FROM v$session
WHERE blocking_session IS NOT NULL
ORDER BY seconds_in_wait DESC;
```
Se il risultato mostra dozzine di "Victims" tutte bloccate da un singolo "Blocker", hai trovato il colpevole.

**Informazioni sul Blocker**:
```sql
SELECT s.sid, s.serial#, s.username, s.machine, s.program, q.sql_text
FROM v$session s
LEFT JOIN v$sql q ON s.sql_id = q.sql_id
WHERE s.sid = <ID_DEL_BLOCKER>;
```

**Risoluzione**:
Contattare il proprietario della macchina/programma se possibile. Se non reperibile, e i lock superano i 15 minuti su record critici, uccidere il blocker:
```sql
ALTER SYSTEM KILL SESSION 'SID,SERIAL#' IMMEDIATE;
```
*Il database eseguirà un rollback automatico dei dati del blocker, liberando istantaneamente tutte le vittime.*

### 4.2. Hanganalyze (Quando non si riesce a fare login)
Se il DB è talmente bloccato che non si riesce a entrare in SQL*Plus:
```bash
sqlplus -prelim / as sysdba
SQL> oradebug setmypid
SQL> oradebug hanganalyze 3
```
Analizzare il file di trace generato nella directory ADRCI.

---

## 5. Disaster Recovery & Data Guard Gaps

### 5.1. Risoluzione ORA-16147: Standby Database is in a GAP
**Significato**: Il database Standby ha perso dei redo log (es. disconnessione di rete per giorni) e non può più applicare le modifiche.

**Procedura di Roll Forward da SCN (Nuovo Metodo Enterprise RMAN)**:
Invece di ricostruire la Standby da zero (che richiede terabyte di rete), usiamo un backup incrementale basato sull'SCN.

1. **Sulla STANDBY**, trova l'SCN bloccato:
```sql
SELECT current_scn FROM v$database;
-- Assumiamo SCN = 1000000
```
2. **Sulla PRIMARY**, crea un backup incrementale da quell'SCN:
```bash
rman target /
RMAN> BACKUP INCREMENTAL FROM SCN 1000000 DATABASE FORMAT '/tmp/ForStandby_%U' tag 'FORSTANDBY';
RMAN> BACKUP CURRENT CONTROLFILE FOR STANDBY FORMAT '/tmp/ForStandby_ctrl.bck';
```
3. Scp dei file da Primary a Standby in `/tmp`.
4. **Sulla STANDBY**, applica il backup:
```bash
rman target /
RMAN> RECOVER DATABASE NOREDO;
RMAN> SHUTDOWN IMMEDIATE;
RMAN> STARTUP NOMOUNT;
RMAN> RESTORE STANDBY CONTROLFILE FROM '/tmp/ForStandby_ctrl.bck';
RMAN> ALTER DATABASE MOUNT;
```
5. Riavviare il processo MRP sulla Standby:
```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT;
```

---

## 6. Gestione Corruzioni (ORA-01578, ORA-00600)

### 6.1. ORA-01578: ORACLE data block corrupted
**Significato**: Corruzione fisica su disco.

**Risoluzione (Block Media Recovery)**:
Se il database è in archivelog mode (OBBLIGATORIO) e hai backup validi, RMAN può riparare il singolo blocco *senza downtime*.
```bash
rman target /
-- Esempio errore: Block 12345 file 7
RMAN> BLOCKRECOVER DATAFILE 7 BLOCK 12345;
```

### 6.2. ORA-00600 / ORA-07445: Internal Error
**Significato**: Bug di Oracle C-Kernel o eccezione OS non gestita.

**Risoluzione**:
L'operatore NON PUÒ risolvere questi errori da solo.
1. Eseguire l'ADRCI IPS Packager:
```bash
adrci
adrci> ips pack incident <INCIDENT_ID>
```
2. Aprire immediatamente una SR (Service Request) Severity 1 su MyOracleSupport allegando il file ZIP generato.

---

## 7. Listener & Connectivity (ORA-12170, TNS-12541)

### 7.1. TNS-12541: TNS:no listener
**Diagnosi**: Il processo listener `tnslsnr` è morto.
```bash
lsnrctl start
```
Se muore immediatamente, controllare `/u01/app/oracle/diag/tnslsnr/<host>/listener/trace/listener.log`.
*Causa comune:* Il file `listener.log` ha superato i 4GB di dimensione massima supportata dall'OS.
*Fix:* Rinominare il file `listener.log` a `listener.log.old` e riavviare il listener (il file verrà ricreato fresco).

### 7.2. ORA-12170: TNS:Connect timeout occurred
**Causa**: Firewall OS (iptables/firewalld) o di Rete.
**Verifica da client**:
```bash
telnet <database_ip> 1521
```
Se va in timeout, far aprire la porta al team networking.

---

## 8. Performance Troubleshooting Avanzato (AWR & ASH)

Quando il database non è bloccato (no row locks), ma le query sono estremamente lente, il problema solitamente risiede nell'I/O (latenza storage) o nei piani di esecuzione errati (CBO regressions).

### 8.1. Estrazione Rapida AWR (Automatic Workload Repository)
Se ti chiamano per un "rallentamento generale dalle 14:00 alle 15:00", il primo step è sempre estrarre l'AWR.

```sql
-- Identificare gli Snapshot ID del range interessato
SELECT snap_id, begin_interval_time, end_interval_time
FROM dba_hist_snapshot
WHERE begin_interval_time > SYSDATE - 1
ORDER BY snap_id DESC;

-- Eseguire lo script interattivo per generare il report HTML
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
-- Inserire: HTML -> 1 (giorni) -> begin_snap -> end_snap -> nome_file.html
```
Cosa cercare nel report AWR:
1. **Top 5 Timed Events**: Se c'è `db file sequential read`, è colpa di I/O (dischi lenti) o indici non utilizzati. Se c'è `log file sync`, il sottosistema di REDO è congestionato (rischio crash).
2. **SQL ordered by Elapsed Time**: Individua la Query killer.

### 8.2. Active Session History (ASH) per Analisi Real-Time
Se il problema sta accadendo *ORA*:
```sql
SELECT session_id,
       session_state,
       event,
       wait_time,
       time_waited,
       sql_id,
       blocking_session
FROM v$active_session_history
WHERE sample_time > SYSDATE - (5/1440) -- Ultimi 5 minuti
ORDER BY sample_time DESC;
```

### 8.3. Fixing CBO Regression (SQL Plan Management)
Se una query specifica è esplosa dopo la raccolta statistiche (cambio piano d'esecuzione):
```sql
-- Trovare il vecchio piano buono in AWR
SELECT sql_id, plan_hash_value, timestamp
FROM dba_hist_sql_plan
WHERE sql_id = 'tuo_sql_id_qui';

-- Fissare il vecchio piano (SQL Plan Baseline)
DECLARE
  l_plans PLS_INTEGER;
BEGIN
  l_plans := DBMS_SPM.LOAD_PLANS_FROM_AWR(
    begin_snap      => <SNAP_ID_BUONO_INIZIO>,
    end_snap        => <SNAP_ID_BUONO_FINE>,
    basic_filter    => 'sql_id = ''tuo_sql_id_qui'''
  );
END;
/
```

---

## 9. Archivelog & Recovery Area Exhaustion

### 9.1. FRA (Fast Recovery Area) Piena al 100%
**Sintomi:** Database bloccato. Messaggio `ORA-19809: limit exceeded for recovery files` e `ORA-19804`.
Il database si ferma perché non può più scrivere archivelog (e quindi non garantisce la durabilità ACID).

**Risoluzione (Aggiunta Spazio Dinamica):**
L'operazione è istantanea e fa ripartire il DB immediatamente:
```sql
ALTER SYSTEM SET db_recovery_file_dest_size = 1000G SCOPE=BOTH;
-- Il DB sblocca immediatamente le transazioni in coda.
```

**Risoluzione (Pulizia RMAN d'Emergenza):**
Se il disco fisico è pieno e non puoi aumentare il parametro:
```bash
rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> SHOW ARCHIVELOG DELETION POLICY;
RMAN> DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
RMAN> DELETE NOPROMPT OBSOLETE;
```
*Attenzione: Se Data Guard e' in lag o irraggiungibile, preservare prima i redo.
`DELETE FORCE` ignora la deletion policy e richiede autorizzazione Sev1 esplicita.*

---

## 10. Data Guard: Risoluzione ORA-16708 (State is Unknown)
Se DGMGRL mostra il database in stato sconosciuto:
```text
DGMGRL> show configuration;
Error: ORA-16708: state of the database is unknown
```
**Fix (Re-inviare il metadata DG):**
```sql
ALTER SYSTEM SET log_archive_dest_state_2 = DEFER SCOPE=MEMORY;
ALTER SYSTEM SET log_archive_dest_state_2 = ENABLE SCOPE=MEMORY;
```

---

## 11. Escrow e Contatti
In caso di incidenti catastrofici (perdita disco `SYSTEM` senza RMAN backup validi), contattare immediatamente l'Oracle ACS (Advanced Customer Services).
Numero Verde Enterprise: `800-XXX-YYY`.
Codice CSI (Customer Support Identifier): `XXXXXX`.
Tenere pronto il bundle AWR e gli alert log zippati.
