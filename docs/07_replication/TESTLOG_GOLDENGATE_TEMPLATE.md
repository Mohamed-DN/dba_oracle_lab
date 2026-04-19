# TESTLOG GoldenGate Template

Usa questo file come base per tracciare tutti i test della matrice GoldenGate.

## Metadati sessione

- Data sessione:
- Ambiente source:
- Ambiente target:
- Versione GoldenGate:
- Operatore:

## KPI rapidi

- Test PASS:
- Test FAIL:
- Lag massimo osservato (sec):
- Processi ABENDED (>10 min):

## Registro test

| Data/Ora | ID Test | Scenario | Esito | Lag max (sec) | Evidenza (screenshot/log) | Note/Fix |
|---|---|---|---|---:|---|---|
| 2026-03-13 21:00 | GG-01 | DML base INSERT | PASS | 1 | SNAP-GG-01.png | - |
| 2026-03-13 21:15 | GG-02 | DML UPDATE | PASS | 2 | SNAP-GG-02.png | - |
| 2026-03-13 21:30 | GG-03 | DML DELETE | PASS | 1 | SNAP-GG-03.png | - |

## Runbook fail (compila solo se FAIL)

### ID Test

- Sintomo:
- Root cause:
- Fix applicato:
- Verifica post-fix:
- Tempo totale recovery:
