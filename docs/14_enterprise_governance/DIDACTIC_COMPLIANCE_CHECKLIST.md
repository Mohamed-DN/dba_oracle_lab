# Didactic Compliance Checklist (Repository-wide)

Questa checklist standardizza la qualità didattica di tutte le guide.

## Standard obbligatorio per ogni guida

- [ ] Sezione **Teoria**
- [ ] Sezione **Esempio**
- [ ] Sezione **Validazione**
- [ ] Sezione **Troubleshooting**

## Criteri minimi di conformità

1. Ogni sezione deve essere esplicita e rintracciabile nel documento.
2. La validazione deve avere almeno un criterio pass/fail.
3. Il troubleshooting deve includere almeno 2 failure mode reali.
4. La guida deve dichiarare versione Oracle target (19c/21c/23ai/26c quando rilevante).

## Workflow di verifica

1. Autore aggiorna guida usando `docs/00_fondamenti/TEMPLATE_GUIDA_STANDARD.md`.
2. Reviewer applica questa checklist in PR.
3. CI esegue `scripts/validate_didactic_compliance.py` sulle guide modificate (`GUIDA*.md` e `RUNBOOK*.md`).
4. Se mancano sezioni obbligatorie: PR in stato changes requested.

## Audit trimestrale

- Campione minimo: 15 guide core.
- Obiettivo compliance: >= 90%.
- Evidenze salvate in `reliability/evidence/`.
