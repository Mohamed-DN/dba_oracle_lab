# Guida ADRCI e Diagnostica Oracle per DBA

## Obiettivo

Spiegare in modo operativo come usare ADRCI e le utility diagnostiche Oracle per il flusso incidente: **diagnosi → raccolta evidenze → escalation**.

## Teoria

### Perché ADRCI è centrale

- ADR (Automatic Diagnostic Repository) centralizza alert log, trace, incident e package diagnostici.
- ADRCI è la CLI ufficiale per consultare e filtrare rapidamente questi dati.
- Riduce i tempi di MTTR perché evita ricerca manuale disordinata nei filesystem.

### Cosa misura/controlla

- eventi critici database/ASM/listener
- incidenti correlati a ORA-600/ORA-7445 e internal errors
- health monitor output e pack diagnostici per supporto Oracle

### Limiti e rischi operativi

- output rumoroso se non filtri per tempo/home/problema
- purge aggressivo può eliminare evidenze utili a RCA
- raccolta incompleta può rallentare escalation verso Oracle Support

## Procedura operativa

### 1) Accesso e contesto ADR

```bash
adrci
show base
show homes
set homepath diag/rdbms/<db_unique_name>/<instance_name>
```

### 2) Alert log e incidenti

```text
show alert -tail -f
show incident -mode detail
show problem -mode detail
```

### 3) Tracce e file diagnostici

```text
show tracefile
show tracefile -t <trace_name>
```

### 4) Packaging evidenze per escalation

```text
ips create package problem <problem_id>
ips generate package <package_id> in /tmp
```

### 5) Utility Oracle complementari (uso pratico DBA)

- `oradebug` (solo utenti esperti): dump mirati su processi/sessioni
- AWR/ASH (`v$active_session_history`, report AWR): analisi performance incidente
- `lsnrctl status/services`: verifica layer connessione
- `srvctl`/`crsctl` in RAC: stato risorse cluster e servizi

## Esempio

### Scenario

Ticket: picco ORA-600 con blocchi applicativi intermittenti.

### Flusso rapido

1. `adrci` + `show alert -tail -f` per orario evento
2. `show incident -mode detail` per incident_id e trace associati
3. `ips create package problem ...` per bundle escalation
4. correlazione con AWR/ASH nello stesso intervallo
5. aggiornamento runbook incidente con evidenze raccolte

## Validazione finale

- Alert e trace rilevanti raccolti con timestamp coerenti
- Incident/problem ID documentati nel ticket
- Package IPS generato e allegato per escalation
- Timeline incidente verificata con ASH/AWR e log applicativi

## Troubleshooting rapido

- **ADRCI non vede home**: controllare `ORACLE_BASE` e `diag` path
- **Troppi eventi non utili**: filtrare per finestra temporale e homepath corretti
- **Nessun incident ma errore applicativo**: integrare con listener log, AWR/ASH e OS metrics
- **Escalation incompleta**: rigenerare package IPS includendo trace e alert completi

## Runbook collegati

- [08_ORA_ERRORS](../11_runbook_operativi/08_ORA_ERRORS.md)
- [05_QUERY_LENTA](../11_runbook_operativi/05_QUERY_LENTA.md)
- [11_REVIEW_AWR](../11_runbook_operativi/11_REVIEW_AWR.md)

## Riferimenti ufficiali

- ADRCI command interpreter: <https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-adr-command-interpreter-adrci.html>
- Diagnosability framework (Oracle Database 19c docs): <https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-diagnostic-data.html>
- Oracle Support (accesso clienti): <https://support.oracle.com>
