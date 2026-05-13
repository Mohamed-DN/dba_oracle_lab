# Guida ADRCI e Diagnostica Oracle per DBA

> ⚠️ **Questa guida è stata consolidata nella versione Enterprise.**
>
> Per la guida completa con gestione incidenti, IPS, multi-home RAC/ASM, e retention/purge:
>
> 👉 [GUIDA_ADRCI_TRACE_ENTERPRISE.md](../17_adrci_trace/GUIDA_ADRCI_TRACE_ENTERPRISE.md)

## Quick Reference (comandi essenziali)

```bash
adrci
show homes
set homepath diag/rdbms/<db_unique_name>/<instance_name>
show alert -tail -f
show alert -p "message_text like '%ORA-%'"
show incident -mode detail
show problem -mode detail
ips create package incident <incident_id>
ips generate package <package_id> in /tmp
```

## Runbook collegati

- [ADRCI & Trace Enterprise](../17_adrci_trace/GUIDA_ADRCI_TRACE_ENTERPRISE.md)
- [08_ORA_ERRORS](../11_runbook_operativi/08_ORA_ERRORS.md)
- [05_QUERY_LENTA](../11_runbook_operativi/05_QUERY_LENTA.md)
- [11_REVIEW_AWR](../11_runbook_operativi/11_REVIEW_AWR.md)
