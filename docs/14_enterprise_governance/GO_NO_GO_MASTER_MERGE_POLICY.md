# Go/No-Go Policy per Merge su main/master

Questa policy rende obbligatori i criteri minimi prima del merge verso branch protetto.

## Criteri Go/No-Go obbligatori

1. **Quality gates verdi**: CI, Security Gates e Release Governance devono essere in stato success.
2. **Impatto documentato**: aggiornare `CHANGELOG.md` (Unreleased) per cambi con impatto utente/operativo.
3. **Allineamento governance**: aggiornare scorecard/matrice/policy se la modifica cambia compatibilità o controllo MAA.
4. **Evidenze operative**: per cambi DR/RAC/DG allegare evidenza (artifact o log) oppure dichiarare N/A motivato.
5. **Security checklist**: check obbligatori completati in PR per modifiche ad automazione/governance.

## Criteri No-Go

- Workflow obbligatori falliti o mancanti.
- Checklist sicurezza incompleta quando richiesta.
- Mismatch fra comportamento introdotto e changelog/governance.

## Enforcement

- Template PR obbligatorio con sezione Go/No-Go.
- Workflow dedicato verifica presenza dei check obbligatori nel body PR.
