# 10 — Partition Manager

> Package PL/SQL per la gestione automatica delle partizioni Oracle.
> Versioni dalla v2.31 alla v2.36, sviluppate e mantenute dal team DBA Nexi.

---

## Panoramica

Il **Partition Manager** è un package PL/SQL che automatizza:
- Creazione di nuove partizioni (es. mensili/giornaliere)
- Rotazione delle partizioni vecchie (drop o merge)
- Exchange partition per caricamenti fast
- Monitoraggio dello stato delle partizioni

In un ambiente Enterprise con migliaia di tabelle partizionate, l'automazione è **indispensabile**.

---

## Versioni Disponibili

| File | Versione | Note |
|---|---|---|
| `Script_Creazione_Partition_Manager_v2_36.sql` | v2.36 | **Ultima versione** — usare questa |
| `Script_Creazione_Partition_Manager_v2_35.sql` | v2.35 | Precedente |
| `Script_Creazione_Partition_Manager_v2_34.sql` | v2.34 | Standard + versione NORDICS |
| `dba_op_user_setup.sql` | — | Setup utente DBA_OP per il Partition Manager |
| `INSTANCE_ORA014097_Exchange_Partitions.sql` | — | Esempio exchange partition reale |

---

## Come Funziona

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
Le partizioni sono trattate anche nella [GUIDE_DBA_ACTIVITIES.md](../../GUIDE_DBA_ACTIVITIES.md) nella sezione batch/manutenzione.
