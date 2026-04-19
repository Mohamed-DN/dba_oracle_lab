# Contributing

Contributi, fix e suggerimenti sono benvenuti!

## Come Contribuire

1. **Fork** del repository
2. Crea un **branch** con un nome descrittivo (`fix/tablespace-script`, `feat/new-guide`)
3. Fai le modifiche e testa
4. Apri una **Pull Request** con descrizione chiara

## Regole

- **Script SQL**: Testa sempre su un lab prima di proporre
- **Guide**: Mantieni il formato Markdown consistente con le guide esistenti
- **Naming**: Segui le convenzioni di naming (MAIUSCOLO per guide, snake_case per script)
- **Lingua**: Le guide sono in italiano, i commenti SQL in italiano/inglese
- **Release hygiene**: Se cambi comportamento utente, aggiorna `CHANGELOG.md` (sezione Unreleased) e verifica `VERSION` semantico

## Segnala un Bug

Apri una [Issue](https://github.com/Mohamed-DN/dba_oracle_lab/issues) con:
- Versione Oracle in uso
- Fase del lab o script coinvolto
- Errore completo (copia/incolla dall'alert log o terminale)
- Cosa hai già provato

## Idee per Contributi

- [ ] Nuove procedure operative per scenari non coperti
- [ ] Script per Oracle 23ai / 26c
- [ ] Template Grafana dashboard per Oracle
- [ ] Playbook Ansible aggiuntivi (es. DR automation)
- [ ] Traduzione guide in inglese
- [ ] Issue etichettate [good first issue](https://github.com/Mohamed-DN/dba_oracle_lab/labels/good%20first%20issue)
- [ ] Percorso contributor: [Community Onboarding Path](./docs/14_enterprise_governance/COMMUNITY_ONBOARDING_PATH.md)

## Governance minima per PR

- Compila il template PR, inclusa sezione **Go/No-Go**.
- Per modifiche in `automation/`, `policy/`, `docs/14_enterprise_governance/` o workflow, completa la **Security Checklist**.
- Se cambi compatibilità o standard MAA, aggiorna `docs/14_enterprise_governance/` nello stesso PR.
- Usa le issue template per bug/proposte così da mantenere KPI e roadmap tracciabili.
