# 17 — Purge Log Oracle (ADR, Audit, Archivelog)

<!-- RUNBOOK_NAV_START -->
## Casi piu frequenti da aprire prima
- Filesystem diag/trace/audit pieno.
- FRA piena per archivelog o backup obsoleti.
- ADR alert/trace cresciuti dopo incidente.
- Unified audit trail troppo grande.
- Serve purge sicuro senza cancellare evidenze recenti.

## Indice rapido
- [Casi piu frequenti da aprire prima](#casi-piu-frequenti-da-aprire-prima)
- [Obiettivi](#obiettivi)
- [Procedura Operativa](#procedura-operativa)
  - [Step 1: Identifica quale log sta crescendo](#step-1-identifica-quale-log-sta-crescendo)
  - [Step 2: Purge log diagnostici ADR (alert/trace/incidents)](#step-2-purge-log-diagnostici-adr-alerttraceincidents)
  - [Step 3: Purge archivelog in sicurezza (RMAN)](#step-3-purge-archivelog-in-sicurezza-rman)
  - [Step 4: Purge Unified Audit Trail (se cresce troppo)](#step-4-purge-unified-audit-trail-se-cresce-troppo)
- [Validazione Finale](#validazione-finale)
- [Troubleshooting rapido e guardrail importanti](#troubleshooting-rapido-e-guardrail-importanti)
<!-- RUNBOOK_NAV_END -->

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- [03_fra_archivelog.sql](../03_scripts_pronti/03_fra_archivelog.sql) - diagnosi FRA piena, archivelog, ORA-19809, ORA-00257.
- [12_log_purge_audit.sql](../03_scripts_pronti/12_log_purge_audit.sql) - FRA, unified audit cleanup, audit recenti.
<!-- READY_SCRIPTS_END -->
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

Questa e' una procedura autorizzata separata dal backup. Prima esegui i gate
dello [standard directory backup RMAN](../../02_core_dba/02_backup_and_recovery/GUIDA_STANDARD_DIRECTORY_BACKUP_RMAN_19C.md):
due catene Level 0 recuperabili, controlfile/SPFILE, lag, sequenze applied e
`V$ARCHIVE_GAP` sullo standby.

```rman
rman target /

SHOW ARCHIVELOG DELETION POLICY;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;

-- Cancella solo archivelog già backuppati almeno 1 volta
DELETE NOPROMPT ARCHIVELOG ALL BACKED UP 1 TIMES TO DEVICE TYPE DISK;

-- opzionale: pulizia backup obsoleti
DELETE NOPROMPT OBSOLETE;
```

> In Data Guard, verifica prima transport/apply lag e applica una policy coerente,
> ad esempio `CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;`.
> Se lo standby e' irraggiungibile e la FRA del primary e' piena, non applicare
> una cancellazione cieca: usa il caso
> [DG-061](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md#dg-061---primary-fra-piena-per-standby-lag).

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

## Troubleshooting rapido e guardrail importanti

- Non cancellare archivelog non ancora backuppati/applicati su standby.
- Evita `rm` diretto dei file Oracle senza passare da RMAN/ADRCI dove richiesto.
- Documenta policy retention (giorni) nel ticket di change.
- `DELETE FORCE` ignora la deletion policy RMAN: e' una misura Sev1 autorizzata,
  non una procedura periodica.
