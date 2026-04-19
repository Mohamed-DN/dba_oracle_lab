# Production Profile (separato dal percorso lab)

Questo profilo applica baseline più restrittive rispetto al lab didattico.

## Obiettivo

- Mantenere il lab fruibile per apprendimento.
- Offrire un percorso "production-ready" con controlli più severi.

## Baseline consigliata

1. Usare `automation/inventory/production.ini` con host reali.
2. Abilitare Vault per tutte le credenziali.
3. Eseguire guardrail MAA:

```bash
cd automation
ansible-playbook -i inventory/production.ini playbooks/13_maa_guardrails.yml \
  -e maa_enforce_compliance=true \
  -e maa_set_broker_thresholds=true
```

4. Eseguire DR drill periodico e conservare artifact.
5. Agganciare scorecard MAA al ciclo di change/release.

## Delta principale rispetto al lab

| Tema | Lab didattico | Production profile |
|---|---|---|
| FSFO | opzionale/documentato | da pianificare e validare operativamente |
| Parametri protezione dati | raccomandati | enforce con guardrail |
| Evidenze | manuali + guide | artifact CI obbligatori |
| Governance release | consigliata | gate obbligatorio |
