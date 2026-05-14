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
| RMAN Enterprise | ~1350 | [../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md) |
| ADRCI Enterprise | ~1150 | [../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_TRACE_ENTERPRISE.md](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_TRACE_ENTERPRISE.md) |
| Backup RCA Runbook | ~1300 | [../../01_operations/02_runbooks_incidenti/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md](../../01_operations/02_runbooks_incidenti/19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) |
| SQL Scripts Pronti | 14 script | [../../01_operations/03_scripts_pronti/](../../01_operations/03_scripts_pronti/) |

---

## Uso Rapido

```bash
# Dal terminale: cerca un comando rapidamente
grep -i "switchover" docs/01_operations/01_cheat_sheets/*.md
grep -i "backup" docs/01_operations/01_cheat_sheets/CHEAT_SHEET_RMAN*.md
```
