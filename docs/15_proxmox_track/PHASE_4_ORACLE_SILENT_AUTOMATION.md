# Fase 4 - Oracle Silent Automation

## Obiettivo

Installare Oracle Database in modalità totalmente non interattiva.

## Standard team

- Prerequisiti Linux codificati in Ansible (kernel, limiti, utenti `oracle`/`grid`, pacchetti).
- Response files `.rsp` versionati e parametrizzati.
- Variabili runtime Oracle centralizzate: `ORACLE_BASE`, `ORACLE_HOME`, `ORACLE_SID`.

## Requisiti sicurezza

- Nessuna password in chiaro nei playbook.
- Secret gestiti tramite Ansible Vault o backend equivalente.
- Allineamento con policy security/gates già presenti nel repository.

## Validazione post-install

- Verifica listener, instance state, servizi e inventory Oracle.
- Runbook di test post-install con evidenze ripetibili.
- Integrazione nei workflow qualità (lint, markdown/link check, security gates).

## Acceptance checklist

- [ ] Installazione silent completata senza interventi manuali.
- [ ] Variabili Oracle consistenti tra host e playbook.
- [ ] Evidenza di health check post-install archiviata.
