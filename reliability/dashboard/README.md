# Public KPI Dashboard

Questa cartella contiene dashboard KPI pubblica in formato JSON + Markdown.

## Generazione

```bash
python3 scripts/generate_mock_kpi_dashboard.py
```

Input health-check: `reliability/evidence/ansible_health_checks/latest_healthcheck.json`

Il KPI `ci_success_rate_30d` viene calcolato con priorità da GitHub Actions
(`ci.yml`, `security-gates.yml`, `release-governance.yml`, ultimi 30 giorni),
considerando l'ultimo run completato per workflow in ciascun giorno.
Se l'API non è disponibile, viene usato il fallback dai dati health-check locali.
Output:
- `reliability/dashboard/public_kpi_dashboard.json`
- `reliability/dashboard/public_kpi_dashboard.md`

## Stack consigliato (operativo)

- **Checkmk**: raccolta rapida check Oracle/OS e alerting out-of-the-box
- **Prometheus + Grafana**: dashboard evolute e storico KPI/SLI
- **Approccio consigliato**: Checkmk per alert + Prometheus/Grafana per visual analytics
