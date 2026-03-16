# 07 — Performance & Tuning

> Procedures and scripts for Oracle performance analysis and SQL tuning.

---

## Panoramica

Performance tuning is a daily task for the Enterprise DBA. The main tools are:
- **AWR** (Automatic Workload Repository): periodic snapshots of statistics
- **ASH** (Active Session History): real-time sampling of active sessions
- **ADDM** (Automatic Database Diagnostic Monitor): automatic analysis
- **SPM** (SQL Plan Management): management of stable execution plans

---

## File Contents

### [statistics_check.md](./statistics_check.md)
Procedures for controlling and managing Oracle statistics (optimizer statistics).
Includes: verification, manual collection, lock/unlock, and troubleshooting.

### [spm_guide.md](./spm_guide.md)
Complete guide on SQL Plan Management: how to capture, verify, and force stable execution plans.

### Analysis Script
See also section [03_monitoring_scripts](../03_monitoring_scripts/) for ASH, CPU, I/O scripts.

---

## Quick Reference: Essential Commands

```sql
-- Generare un report AWR
@$ORACLE_HOME/rdbms/admin/awrrpt.sql

-- Generare un report ASH
@$ORACLE_HOME/rdbms/admin/ashrpt.sql

--Manually collecting statistics on a single schema
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('NOME_SCHEMA');

--Collect statistics on a single table with histograms
EXEC DBMS_STATS.GATHER_TABLE_STATS('SCHEMA', 'TABELLA', METHOD_OPT => 'FOR ALL COLUMNS SIZE AUTO');

--Check for unstable SQL plans (fromv$sql)
SELECT sql_id, plan_hash_value, executions, elapsed_time/executions avg_elapsed
FROM v$sql WHERE sql_id = '&sql_id';
```

---

## 🔗 Link
See also: [GUIDE_DBA_COMMANDS.md](../../GUIDE_DBA_COMMANDS.md)
