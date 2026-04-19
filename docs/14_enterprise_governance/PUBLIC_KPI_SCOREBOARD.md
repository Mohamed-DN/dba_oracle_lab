# Public KPI Scoreboard

Questa pagina definisce i KPI pubblici minimi per misurare la qualità reale del repository.

## KPI obbligatori

| KPI | Definizione | Target | Fonte evidenza |
|---|---|---|---|
| ci_success_rate_30d | % workflow principali conclusi con successo negli ultimi 30 giorni | >= 95% | GitHub Actions (CI, Security Gates, Release Governance) |
| mttr_incident_hours | Mean Time To Recovery per incidenti P1/P2 di automazione/governance | <= 24h | Issue/PR timeline + postmortem |
| validated_runbook_coverage | % runbook critici validati con evidenza negli ultimi 90 giorni | >= 90% | `docs/11_runbook_operativi/` + `reliability/evidence/` |
| docs_link_health | % link markdown validi sul perimetro CI | >= 99% | workflow CI markdown link check |

## KPI track Proxmox (sperimentale)

| KPI | Definizione | Target iniziale | Fonte evidenza |
|---|---|---|---|
| provisioning_success_rate | % run Terraform Proxmox completati con `apply` e `destroy` riusciti | >= 90% | pipeline IaC + log Terraform |
| bootstrap_success_rate | % run bootstrap AWX/Ansible completati senza drift critico | >= 90% | Job Templates AWX + artifact run |
| mean_deploy_time_minutes | Tempo medio deploy end-to-end (Terraform -> AWX -> App) | <= 30 min | report CI/CD + evidenze laboratorio |

## Regole operative

1. Ogni release deve riportare lo stato dei KPI obbligatori nella sezione Unreleased del changelog o nella release note.
2. Se un KPI obbligatorio o KPI Proxmox in stato stabile scende sotto target, il merge su `main/master` richiede piano di remediation.
3. Le evidenze devono essere verificabili da repository/artifact CI.

## Dashboard pubblica KPI

- Output machine-readable: `reliability/dashboard/public_kpi_dashboard.json`
- Output leggibile: `reliability/dashboard/public_kpi_dashboard.md`
- Generazione automatica: workflow `.github/workflows/kpi-dashboard.yml`
