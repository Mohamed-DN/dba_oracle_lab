## Summary

<!-- Descrivi cosa cambia e perché -->

## Go/No-Go (obbligatorio)

- [ ] Ho verificato che i workflow obbligatori siano verdi (CI, Security Gates, Release Governance)
- [ ] Ho aggiornato `CHANGELOG.md` (Unreleased) se c'è impatto utente/operativo
- [ ] Ho aggiornato documenti governance interessati (scorecard/matrice/policy) oppure dichiaro N/A
- [ ] Ho allegato evidenze operative (artifact/log) per cambi DR/RAC/DG oppure dichiaro N/A

## Security Checklist (obbligatoria per modifiche in automation/, policy/, docs/04_governance_learning/02_enterprise_standards/, .github/workflows/)

- [ ] Nessun secret hardcoded introdotto
- [ ] Variabili sensibili gestite con Vault/placeholder sicuro
- [ ] Controlli policy/security aggiornati quando necessario

## Validation

- [ ] Ho eseguito i controlli locali rilevanti
- [ ] Non ho introdotto regressioni note
