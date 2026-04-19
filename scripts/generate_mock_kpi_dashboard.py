#!/usr/bin/env python3
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / 'reliability/evidence/ansible_health_checks/latest_healthcheck.json'
OUT_JSON = ROOT / 'reliability/dashboard/public_kpi_dashboard.json'
OUT_MD = ROOT / 'reliability/dashboard/public_kpi_dashboard.md'


def pct(num, den):
    return round((num / den) * 100, 2) if den else 0.0


def ratio(num, den):
    return round((num / den), 4) if den else 0.0


def load_input():
    if INPUT.exists():
        return json.loads(INPUT.read_text(encoding='utf-8'))
    return {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'ansible_health_checks': {
            'runbook_validation_passed': 9,
            'runbook_validation_total': 10,
            'e2e_passed': 3,
            'e2e_total': 4,
            'ci_success_runs': 38,
            'ci_total_runs': 40,
            'docs_links_ok': 980,
            'docs_links_total': 1000,
            'incidents': [{'id': 'SIM-1', 'mttr_hours': 12.0}]
        }
    }


def build_dashboard(data):
    hc = data['ansible_health_checks']
    incidents = hc.get('incidents', [])
    mttr = round(sum(i.get('mttr_hours', 0) for i in incidents) / len(incidents), 2) if incidents else 0.0

    dashboard = {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'source': str(INPUT.relative_to(ROOT)),
        'kpi': {
            'ci_success_rate_30d': {
                'value': ratio(hc['ci_success_runs'], hc['ci_total_runs']),
                'display_percent': pct(hc['ci_success_runs'], hc['ci_total_runs']),
                'target': 0.95,
                'status': 'PASS' if ratio(hc['ci_success_runs'], hc['ci_total_runs']) >= 0.95 else 'FAIL'
            },
            'mttr_incident_hours': {
                'value': mttr,
                'target': 24,
                'status': 'PASS' if mttr <= 24 else 'FAIL'
            },
            'validated_runbook_coverage': {
                'value': ratio(hc['runbook_validation_passed'], hc['runbook_validation_total']),
                'display_percent': pct(hc['runbook_validation_passed'], hc['runbook_validation_total']),
                'target': 0.90,
                'status': 'PASS' if ratio(hc['runbook_validation_passed'], hc['runbook_validation_total']) >= 0.90 else 'FAIL'
            },
            'docs_link_health': {
                'value': ratio(hc['docs_links_ok'], hc['docs_links_total']),
                'display_percent': pct(hc['docs_links_ok'], hc['docs_links_total']),
                'target': 0.99,
                'status': 'PASS' if ratio(hc['docs_links_ok'], hc['docs_links_total']) >= 0.99 else 'FAIL'
            }
        },
        'sli': {
            'e2e_pass_rate': {
                'value': ratio(hc['e2e_passed'], hc['e2e_total']),
                'display_percent': pct(hc['e2e_passed'], hc['e2e_total'])
            }
        }
    }
    return dashboard


def render_md(d):
    k = d['kpi']
    s = d['sli']
    lines = [
        '# Public KPI Dashboard (Mock)',
        '',
        f"Aggiornato: `{d['generated_at']}`",
        f"Fonte: `{d['source']}`",
        '',
        '| KPI | Valore | Target | Stato |',
        '|---|---:|---:|---|',
        f"| ci_success_rate_30d | {k['ci_success_rate_30d']['display_percent']}% | 95% | {k['ci_success_rate_30d']['status']} |",
        f"| mttr_incident_hours | {k['mttr_incident_hours']['value']}h | <=24h | {k['mttr_incident_hours']['status']} |",
        f"| validated_runbook_coverage | {k['validated_runbook_coverage']['display_percent']}% | 90% | {k['validated_runbook_coverage']['status']} |",
        f"| docs_link_health | {k['docs_link_health']['display_percent']}% | 99% | {k['docs_link_health']['status']} |",
        '',
        '| SLI | Valore |',
        '|---|---:|',
        f"| e2e_pass_rate | {s['e2e_pass_rate']['display_percent']}% |",
        ''
    ]
    return '\n'.join(lines)


def main():
    data = load_input()
    d = build_dashboard(data)
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(d, indent=2) + '\n', encoding='utf-8')
    OUT_MD.write_text(render_md(d) + '\n', encoding='utf-8')
    print(f'Wrote: {OUT_JSON}')
    print(f'Wrote: {OUT_MD}')


if __name__ == '__main__':
    main()
