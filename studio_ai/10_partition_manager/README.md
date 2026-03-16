# 10 — Partition Manager

> PL/SQL package for automatic management of Oracle partitions.
> Versions from v2.31 to v2.36, developed and maintained by the Nexi DBA team.

---

## Panoramica

The **Partition Manager** is a PL/SQL package that automates:
- Creation of new partitions (e.g. monthly/daily)
- Rotating old partitions (drop or merge)
- Exchange partition for fast uploads
- Partition status monitoring

In an Enterprise environment with thousands of partitioned tables, automation is **a must**.

---

## Versions Available

| File | Versione | Note |
|---|---|---|
| `Script_Creazione_Partition_Manager_v2_36.sql` | v2.36 |**Latest version** — use this one|
| `Script_Creazione_Partition_Manager_v2_35.sql` | v2.35 | Precedente |
| `Script_Creazione_Partition_Manager_v2_34.sql` | v2.34 | Standard + versione NORDICS |
| `dba_op_user_setup.sql` | — | DBA_OP user setup for the Partition Manager |
| `INSTANCE_ORA014097_Exchange_Partitions.sql` | — | Real exchange partition example |

---

## How It Works

```sql
--1. Install the package (run the script asDBA_OP)
@Script_Creazione_Partition_Manager_v2_36.sql

--2. The package creates a scheduled job that:
--- Check registered tables for automatic management
--- Create new partitions in advance (e.g. +3 months)
--- Delete partitions older than the configured retention

--3. Register a table for automatic management
EXEC DBA_OP.PKG_PARTITION_MANAGER.REGISTER_TABLE('SCHEMA', 'TABLE_NAME', 'RANGE', 'MONTHLY', 12);
```

---

## 🔗 Link
Partitions are also covered in [GUIDE_DBA_ACTIVITIES.md](../../GUIDE_DBA_ACTIVITIES.md) in the batch/maintenance section.
