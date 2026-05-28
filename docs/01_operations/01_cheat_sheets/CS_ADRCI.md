# Cheat Sheet ADRCI

ADRCI e spesso scritto male come `adric`; il comando corretto e `adrci`.

## Quando usarlo

- Leggere alert log senza cercare file manualmente.
- Seguire alert log in tempo reale.
- Cercare errori `ORA-`, `TNS-`, `CRS-`, `DIA-`.
- Vedere incidenti e problemi ADR.
- Creare IPS package per Oracle Support.
- Pulire trace/incidenti vecchi secondo retention.

## Avvio e home

```bash
adrci
show base
show homes
```

Seleziona home:

```text
set homepath diag/rdbms/<db_unique_name>/<instance_name>
```

Esempi:

```text
set homepath diag/rdbms/sole/SOLE1
set homepath diag/asm/+asm/+ASM1
set homepath diag/tnslsnr/dbhost01/listener
```

## Alert log

Ultime righe:

```text
show alert -tail 100
```

Follow live:

```text
show alert -tail -f
```

Filtro errori:

```text
show alert -p "message_text like '%ORA-%'"
show alert -p "message_text like '%TNS-%'"
show alert -p "message_text like '%CRS-%'"
```

Filtro temporale:

```text
show alert -p "originating_timestamp > systimestamp - interval '2' hour"
```

## Incidenti e problemi

```text
show problem
show problem -mode detail
show incident
show incident -mode detail
show incident -p "problem_key like '%ORA 600%'"
```

Dettaglio incidente:

```text
show incident -mode detail -p "incident_id=<ID>"
```

## IPS package per Oracle Support

```text
ips create package incident <INCIDENT_ID>
ips show package
ips generate package <PACKAGE_ID> in /tmp
```

Package per problema:

```text
ips create package problem <PROBLEM_ID>
ips generate package <PACKAGE_ID> in /tmp
```

## Purge diagnostica

Verifica policy:

```text
show control
```

Purge trace piu vecchi di 30 giorni:

```text
purge -age 43200 -type trace
```

Purge incidenti piu vecchi di 90 giorni:

```text
purge -age 129600 -type incident
```

`-age` e in minuti. Non fare purge prima di raccogliere evidence per incidenti aperti.

## Uso non interattivo

```bash
adrci exec="show homes"
adrci exec="set homepath diag/rdbms/sole/SOLE1; show alert -tail 50"
adrci exec="set homepath diag/rdbms/sole/SOLE1; show incident"
```

## Flusso P1 consigliato

```text
show homes
set homepath <home corretta>
show alert -tail 200
show problem -mode detail
show incident -mode detail
ips create package incident <id>
ips generate package <pkg> in /tmp
```

## Link collegati

- [ADRCI Enterprise](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_TRACE_ENTERPRISE.md)
- [ADRCI Diagnostica Oracle](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)
- [08 ORA Errors](../02_runbooks_incidenti/RUNBOOK_08_ORA_ERRORS.md)
- [32 Enterprise Manager Alert Handling](../02_runbooks_incidenti/RUNBOOK_32_ENTERPRISE_MANAGER_ALERT_RUNBOOK.md)
