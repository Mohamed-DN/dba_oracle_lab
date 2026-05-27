# 17 — Purge Log Oracle (ADR, Audit, Archivelog)

> ⏱️ Tempo: 15-30 minuti | 📅 Frequenza: Settimanale o su saturazione spazio | 👤 Chi: DBA
> **Scenario tipico**: filesystem diagnostici pieni, FRA in crescita, trail audit troppo grande.

---

## Obiettivi

Eseguire la pulizia periodica o straordinaria dei log diagnostici (ADR), dei file di audit e degli archivelog obsoleti per mantenere l'integrità del filesystem e dello spazio in FRA.

## Procedura Operativa

### Step 1: Identifica quale log sta crescendo

```bash
# lato OS (esempio Linux)
du -sh $ORACLE_BASE/diag/*
du -sh /u01/app/oracle/diag/rdbms/*/*/trace
```

```sql
sqlplus / as sysdba

-- FRA usage
SELECT name,
       ROUND(space_limit/1024/1024/1024,2) AS fra_limit_gb,
       ROUND(space_used/1024/1024/1024,2)  AS fra_used_gb,
       ROUND(space_reclaimable/1024/1024/1024,2) AS reclaimable_gb
FROM v$recovery_file_dest;
```

---

### Step 2: Purge log diagnostici ADR (alert/trace/incidents)

```bash
adrci exec="show homes"
adrci exec="set home diag/rdbms/racdb/RACDB1; show control"

# purge vecchi di 7 giorni (604800 secondi)
adrci exec="set home diag/rdbms/racdb/RACDB1; purge -age 604800 -type trace"
adrci exec="set home diag/rdbms/racdb/RACDB1; purge -age 604800 -type alert"
adrci exec="set home diag/rdbms/racdb/RACDB1; purge -age 604800 -type incident"
```

> In RAC ripeti per ogni home/istanza.

---

### Step 3: Purge archivelog in sicurezza (RMAN)

```rman
rman target /

CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

-- Cancella solo archivelog già backuppati almeno 1 volta
DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;

-- opzionale: pulizia backup obsoleti
DELETE NOPROMPT OBSOLETE;
```

> In Data Guard, applica policy coerente con retention e lag standby.

---

### Step 4: Purge Unified Audit Trail (se cresce troppo)

```sql
BEGIN
  DBMS_AUDIT_MGMT.SET_LAST_ARCHIVE_TIMESTAMP(
    audit_trail_type  => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    last_archive_time => SYSTIMESTAMP - INTERVAL '30' DAY
  );

  DBMS_AUDIT_MGMT.CLEAN_AUDIT_TRAIL(
    audit_trail_type         => DBMS_AUDIT_MGMT.AUDIT_TRAIL_UNIFIED,
    use_last_arch_timestamp  => TRUE
  );
END;
/
```

---

## Validazione Finale

```sql
SELECT ROUND(space_used/1024/1024/1024,2) AS fra_used_gb,
       ROUND(space_reclaimable/1024/1024/1024,2) AS fra_reclaimable_gb
FROM v$recovery_file_dest;
```

```bash
du -sh $ORACLE_BASE/diag/rdbms/*/*/trace
```

**Atteso**:
- Riduzione uso spazio ADR/FRA
- Nessun errore RMAN/DBMS_AUDIT_MGMT
- Backup policy invariata e compliance mantenuta

---

## Troubleshooting / Guardrail importanti

- Non cancellare archivelog non ancora backuppati/applicati su standby.
- Evita `rm` diretto dei file Oracle senza passare da RMAN/ADRCI dove richiesto.
- Documenta policy retention (giorni) nel ticket di change.
