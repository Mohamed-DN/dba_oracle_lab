# Compatibility Policy Ufficiale

## Stati supporto
- **supported**: pienamente testato in CI/DR drill.
- **deprecated**: supporto in uscita, migrazione raccomandata.
- **experimental**: utilizzo solo per lab/sperimentazione.

## Matrice compatibilità

| Componente | Versioni | Stato | Note |
|---|---|---|---|
| Oracle Database | 19c | supported | Baseline primaria del lab |
| Oracle Database | 26c | experimental | Presente in percorsi upgrade |
| Oracle Linux | 7.9 | supported | Baseline attuale Vagrant |
| VirtualBox | 7.x | supported | Hypervisor raccomandato |
| Ansible Core | >=2.15 | supported | Richiesto per playbook correnti |
| oravirt.oracle collection | >=3.2.0 | supported | Definita in collections_requirements.yml |
| community.oracle collection | >=1.3.0 | supported | Definita in collections_requirements.yml |
| community.general collection | >=9.0.0 | supported | Definita in collections_requirements.yml |

## Policy di modifica
- Ogni cambio di stato deve aggiornare questa tabella e il changelog.
- Le versioni deprecated devono avere finestra di deprecazione esplicita in release note.
- La versione machine-readable per release artifact è `reliability/release/compatibility_matrix.yml`.
