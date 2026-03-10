# 07 — Performance & Tuning

> Procedure e script per l'analisi delle performance Oracle e il tuning SQL.

---

## Panoramica

Il tuning delle performance è un'attività quotidiana per il DBA Enterprise. Gli strumenti principali sono:
- **AWR** (Automatic Workload Repository): snapshot periodiche delle statistiche
- **ASH** (Active Session History): campionamento real-time delle sessioni attive
- **ADDM** (Automatic Database Diagnostic Monitor): analisi automatica
- **SPM** (SQL Plan Management): gestione dei piani di esecuzione stabili

---

## File Contenuti

### [controllo_statistiche.md](./controllo_statistiche.md)
Procedure per il controllo e la gestione delle statistiche Oracle (optimizer statistics).
Include: verifica, raccolta manuale, lock/unlock, e troubleshooting.

### [spm_guide.md](./spm_guide.md)
Guida completa su SQL Plan Management: come catturare, verificare, e forzare piani di esecuzione stabili.

### Script di Analisi
Vedi anche la sezione [03_monitoring_scripts](../03_monitoring_scripts/) per gli script ASH, CPU, I/O.

---

## Quick Reference: Comandi Essenziali

```sql
-- Generare un report AWR
@$ORACLE_HOME/rdbms/admin/awrrpt.sql

-- Generare un report ASH
@$ORACLE_HOME/rdbms/admin/ashrpt.sql

-- Raccolta manuale statistiche su un singolo schema
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('NOME_SCHEMA');

-- Raccolta statistiche su una singola tabella con istogrammi
EXEC DBMS_STATS.GATHER_TABLE_STATS('SCHEMA', 'TABELLA', METHOD_OPT => 'FOR ALL COLUMNS SIZE AUTO');

-- Verificare piani SQL instabili (da v$sql)
SELECT sql_id, plan_hash_value, executions, elapsed_time/executions avg_elapsed
FROM v$sql WHERE sql_id = '&sql_id';
```

---

## 🔗 Collegamento
Vedi anche: [GUIDE_DBA_COMMANDS.md](../../GUIDE_DBA_COMMANDS.md)
