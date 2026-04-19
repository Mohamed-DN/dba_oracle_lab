# Reliability KPI Baseline

Questa cartella definisce i KPI/SLO minimi da tracciare con evidenze continue.

## KPI/SLO richiesti

| KPI | Descrizione | Target iniziale |
|---|---|---|
| switchover_time_seconds | Tempo end-to-end di switchover controllato | <= 600 |
| dataguard_apply_lag_seconds_max | Massimo apply lag osservato nel drill | <= 900 |
| backup_success_rate | Backup RMAN riusciti / backup pianificati | >= 0.98 |
| restore_test_pass_rate | Restore test passati / test eseguiti | >= 0.95 |

## Evidenze

- Salvare i log in `reliability/evidence/`.
- Ogni drill o test deve produrre artifact.
- Le evidenze vanno collegate nella scorecard MAA SOT.

## KPI pubblici aggiuntivi (governance)

| KPI | Descrizione | Target iniziale |
|---|---|---|
| ci_success_rate_30d | Success rate workflow principali su 30 giorni | >= 0.95 |
| mttr_incident_hours | Tempo medio ripristino incidenti P1/P2 | <= 24 |
| validated_runbook_coverage | Copertura runbook critici validati | >= 0.90 |
| docs_link_health | Salute link documentazione in CI | >= 0.99 |

