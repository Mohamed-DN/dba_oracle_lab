# 🗂️ Cheat Sheet Centralizzati — Quick Reference

> Tutti i cheat sheet in un unico posto. Accesso rapido durante il lavoro quotidiano.
> Ogni altra directory punta qui tramite link.

---

## Indice

| Cheat Sheet | Descrizione | Link |
|---|---|---|
| **RMAN** | Comandi RMAN completi (backup, restore, catalog, validate) | [CHEAT_SHEET_RMAN.md](CHEAT_SHEET_RMAN.md) |
| **RMAN Essenziale** | I 10 comandi RMAN che usi ogni giorno | [CHEAT_SHEET_RMAN_ESSENZIALE.md](CHEAT_SHEET_RMAN_ESSENZIALE.md) |
| **Data Guard / DGMGRL** | Switchover, failover, reinstate, show configuration | [CHEAT_SHEET_DGMGRL.md](CHEAT_SHEET_DGMGRL.md) |
| **GoldenGate** | Start/stop replicat, stats, lag, troubleshooting | [CHEAT_SHEET_GOLDENGATE.md](CHEAT_SHEET_GOLDENGATE.md) |

---

## Guide Enterprise Complete (link)

Per guide dettagliate e approfondite, vedi le sezioni dedicate:

| Guida | Righe | Link |
|---|---|---|
| RMAN Enterprise | ~1350 | [../15_rman_comandi/GUIDA_RMAN_COMANDI_ENTERPRISE.md](../15_rman_comandi/GUIDA_RMAN_COMANDI_ENTERPRISE.md) |
| ADRCI Enterprise | ~1150 | [../17_adrci_trace/GUIDA_ADRCI_TRACE_ENTERPRISE.md](../17_adrci_trace/GUIDA_ADRCI_TRACE_ENTERPRISE.md) |
| Backup RCA Runbook | ~1300 | [../11_runbook_operativi/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md](../11_runbook_operativi/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) |
| SQL Scripts Pronti | 14 script | [../12_scripts_sql_pronti/](../12_scripts_sql_pronti/) |

---

## Uso Rapido

```bash
# Dal terminale: cerca un comando rapidamente
grep -i "switchover" docs/00_cheat_sheet/*.md
grep -i "backup" docs/00_cheat_sheet/CHEAT_SHEET_RMAN*.md
```
