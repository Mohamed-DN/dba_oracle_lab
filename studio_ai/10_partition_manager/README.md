# 10 — Partition Manager

> PL/SQL package for automatic management of Oracle partitions.
> Versioni dalla v2.31 alla v2.36, sviluppate e mantenute dal team DBA Nexi.

---

## Panoramica

The **Partition Manager** is a PL/SQL package that automates:
- Creation of new partitions (e.g. monthly/daily)
- Rotating old partitions (drop or merge)
- Exchange partition per caricamenti fast
- Partition status monitoring

In an Enterprise environment with thousands of partitioned tables, automation is **a must**.

---

## Versioni Disponibili

| File | Versione | Note |
|---|---|---|
| `Script_Creazione_Partition_Manager_v2_36.sql` | v2.36 | **Ultima versione** — usare questa |
| `Script_Creazione_Partition_Manager_v2_35.sql` | v2.35 | Precedente |
| `Script_Creazione_Partition_Manager_v2_34.sql` | v2.34 | Standard + versione NORDICS |
| `dba_op_user_setup.sql` | — | DBA_OP user setup for the Partition Manager |
| `INSTANCE_ORA014097_Exchange_Partitions.sql` | — | Real exchange partition example |

---

## How It Works

```sql
-- 1. Installare il package (eseguire lo script come DBA_OP)
@Script_Creazione_Partition_Manager_v2_36.sql

-- 2. Il package crea un job schedulato che:
--    - Controlla le tabelle registrate per la gestione automatica
--    - Crea nuove partizioni in anticipo (es. +3 mesi)
--    - Elimina partizioni più vecchie della retention configurata

-- 3. Registrare una tabella per la gestione automatica
EXEC DBA_OP.PKG_PARTITION_MANAGER.REGISTER_TABLE('SCHEMA', 'TABLE_NAME', 'RANGE', 'MONTHLY', 12);
```

---

## 🔗 Collegamento
Partitions are also covered in [GUIDE_DBA_ACTIVITIES.md](../../GUIDE_DBA_ACTIVITIES.md) in the batch/maintenance section.
