# Cheat Sheet GoldenGate (Operativa)

## Obiettivo

Fornire una scheda rapida GoldenGate per controllo processi, lag replica, checkpoint e troubleshooting base.

## Teoria

- GoldenGate abilita replica logica near-real-time (Extract, Pump, Replicat).
- Utile per migrazione con downtime ridotto e integrazione eterogenea.
- KPI principali: lag, checkpoint, errori trail/processi.

## Quando usarla

- Check giornaliero replicazione
- Cutover migrazione
- Diagnosi lag/errori in catena Extract/Pump/Replicat

## Comandi essenziali

### Read-only (sicuri)

- `INFO ALL`
- `INFO EXTRACT <name>, DETAIL`
- `INFO REPLICAT <name>, DETAIL`
- `LAG EXTRACT <name>`
- `LAG REPLICAT <name>`
- `VIEW REPORT <process_name>`

### Impattanti (change obbligatoria)

- `START EXTRACT <name>` / `STOP EXTRACT <name>`
- `START REPLICAT <name>` / `STOP REPLICAT <name>`
- `ALTER EXTRACT ...` / `ALTER REPLICAT ...`
- `ADD/DELETE EXTRACT|REPLICAT`

## Procedura operativa

### 1) Pre-check GGSCI

```text
GGSCI> INFO ALL
GGSCI> LAG EXTRACT <extract_name>
GGSCI> LAG REPLICAT <replicat_name>
```

### 2) Verifica checkpoint/stato

```text
GGSCI> INFO EXTRACT <extract_name>, DETAIL
GGSCI> INFO REPLICAT <replicat_name>, DETAIL
GGSCI> VIEW REPORT <extract_name>
GGSCI> VIEW REPORT <replicat_name>
```

### 3) Post-change check

```text
GGSCI> INFO ALL
GGSCI> STATS EXTRACT <extract_name>, TOTAL
GGSCI> STATS REPLICAT <replicat_name>, TOTAL
```

## Validazione finale

- Processi in `RUNNING`
- Lag entro soglia operativa
- Nessun errore critico nei report
- Checkpoint in avanzamento regolare

## Monitoraggio operativo

- `INFO ALL` ogni turno
- Lag e throughput (`LAG`, `STATS`)
- Report/error log processi
- Coerenza dati campione su source/target (query business)

## Troubleshooting rapido

- **Lag crescente**: verificare rete, I/O, throughput trail e carico target
- **Processo ABENDED**: analizzare `VIEW REPORT` e correggere errore a monte
- **Checkpoint fermo**: controllare lock/constraint lato target
- **Dati mancanti/duplicati**: verificare posizione CSN/SCN e parametri di mapping

## Link correlati

- Guida lab: [GUIDA_FASE7_GOLDENGATE](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md)
- Migrazione: [GUIDA_MIGRAZIONE_GOLDENGATE](../../02_core_dba/07_replication_goldengate/GUIDA_MIGRAZIONE_GOLDENGATE.md)
- Test template: [TESTLOG_GOLDENGATE_TEMPLATE](../../02_core_dba/07_replication_goldengate/TESTLOG_GOLDENGATE_TEMPLATE.md)
- Oracle ufficiale: <https://docs.oracle.com/en/middleware/goldengate/core/21.3/>
