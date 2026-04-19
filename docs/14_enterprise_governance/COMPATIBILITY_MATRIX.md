# Compatibility Matrix (Ufficiale)

Questa matrice definisce il perimetro supportato e testato del repository.

## Runtime e toolchain

| Componente | Versioni supportate | Note |
|---|---|---|
| Oracle Database | 19c (target primario), 26ai (guide di evoluzione) | Lab centrato su 19c |
| Oracle Linux | OL7.9 (lab attuale), OL8+ (automazione consigliata) | Alcune guide richiamano OL7 per allineamento a VirtualBox |
| Ansible Core | >= 2.14 | Allineato a oravirt/ansible-oracle |
| Collections | `oravirt.oracle`, `community.oracle`, `community.general` | Vedi `automation/collections_requirements.yml` |
| Vagrant | latest stabile | Per topologia one-click |
| VirtualBox | 7.x | Richiesto per lab locale |

## Workflow GitHub supportati

| Workflow | Trigger | Scopo |
|---|---|---|
| CI/CD & Code Quality | push/pull_request | lint Ansible, shell, markdown, link check |
| Security Gates | push/pull_request | gitleaks, CodeQL, Checkov, Conftest |
| E2E Lab Smoke | pull_request/workflow_dispatch | validazione asset su PR + E2E ridotto self-hosted |
| DR Drill Periodic | schedule/workflow_dispatch | drill periodico DR con artifact |
| Release Governance | pull_request/workflow_dispatch | SemVer + changelog + policy |

## Policy di aggiornamento

- Se viene introdotta una nuova versione target (DB/OS/tool), aggiornare questa matrice nello stesso PR.
- Ogni incompatibilità nota va documentata qui prima del merge.
