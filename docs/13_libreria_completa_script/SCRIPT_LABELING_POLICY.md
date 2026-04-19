# Policy Etichette Script (Qualità / Rischio / Versione Oracle)

## Etichette obbligatorie

Ogni script deve avere metadati nei cataloghi:

- `quality_label`: `certified`, `reviewed`, `community`
- `risk_label`: `BASSO`, `MEDIO`, `ALTO`
- `oracle_version`: una o più versioni target (`19c`, `21c`, `23ai`, `26c`)
- `test_evidence`: riferimento a evidenza in `reliability/evidence/`

## Definizione qualità

- `certified`: script testato in lab e con evidenza tracciata.
- `reviewed`: script verificato da reviewer ma non ancora testato end-to-end.
- `community`: script importato da community, richiede validazione locale.

## Regola operativa

Nuovi script senza etichetta non devono essere classificati "Top certificati".
