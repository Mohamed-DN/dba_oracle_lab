# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog,
and this project follows Semantic Versioning.

## [Unreleased]

### Added
- PR Go/No-Go gate workflow and mandatory PR checklist template for merge readiness.
- Critical scenario regression workflow with periodic and PR-triggered RAC/DG controls validation.
- Governance docs: public KPI scoreboard, go/no-go merge policy, didactic excellence standard, and community roadmap.
- GitHub issue templates for structured bug reports and feature requests.
- Reliability KPI baseline extended with public governance KPIs (CI success rate, MTTR, runbook coverage, docs/link health).
- Real E2E CI workflow scaffold for reduced Oracle lab verification.
- Security gate workflow with secret scanning, SAST, IaC scan, and policy-as-code checks.
- Periodic DR drill workflow and evidence artifact publication.
- CIS-like machine-readable hardening profile and compliance scorecard example.
- Release governance checks with SemVer and changelog validation.
- Enterprise governance docs: compatibility policy, 10-minute quickstart, troubleshooting decision tree, reliability framework.
- MAA scorecard single source of truth (`docs/14_enterprise_governance/MAA_SCORECARD_SOURCE_OF_TRUTH.yml`).
- Governance docs for compatibility matrix and production profile.
- Reliability KPI baseline document (`reliability/kpi/README.md`).
- New role-based Ansible baseline (`automation/roles/maa_guardrails`) and playbook `13_maa_guardrails.yml`.
- PR E2E asset validation now uploads mandatory evidence artifact.
- README root enhanced: added live CI/CD, Security Gates, and Release Governance badges (branch=master); added Level-1 Quick Navigation index and architecture/lab-phases collapsible sections.

## [0.1.0] - 2026-04-19

### Added
- Initial project governance baseline for release/versioning and operational reliability.
