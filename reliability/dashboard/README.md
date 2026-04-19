# Public KPI Dashboard

Questa cartella contiene dashboard KPI pubblica in formato JSON + Markdown.

## Generazione

```bash
python3 scripts/generate_mock_kpi_dashboard.py
```

Input health-check: `reliability/evidence/ansible_health_checks/latest_healthcheck.json`
Output:
- `reliability/dashboard/public_kpi_dashboard.json`
- `reliability/dashboard/public_kpi_dashboard.md`

## Stack consigliato (operativo)

- **Checkmk**: raccolta rapida check Oracle/OS e alerting out-of-the-box
- **Prometheus + Grafana**: dashboard evolute e storico KPI/SLI
- **Approccio consigliato**: Checkmk per alert + Prometheus/Grafana per visual analytics
