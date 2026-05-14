# Checklist Security Baseline (Lab → Produzione)

## Segreti e credenziali
- [ ] Nessuna password in chiaro nei file versionati
- [ ] Uso di Ansible Vault per variabili sensibili
- [ ] Nessun wallet/keystore in repository (`*.p12`, `cwallet.sso`, `ewallet.p12`)

## Hardening database
- [ ] Password policy attiva (complessità, rotazione, lockout)
- [ ] Auditing abilitato per operazioni critiche
- [ ] Privilegi SYS/SYSTEM minimizzati
- [ ] Account inutilizzati bloccati

## Hardening rete e accessi
- [ ] Accesso SSH solo con chiave
- [ ] Segmentazione rete tra nodi lab e host
- [ ] Listener esposto solo dove necessario

## Crittografia e protezione dati
- [ ] TDE pianificato/abilitato dove richiesto
- [ ] Backup cifrati in ambienti sensibili
- [ ] Verifica protezione dati export (Data Pump)

## Operatività sicura
- [ ] Runbook con sezione rischi + rollback
- [ ] Test periodici restore/DR
- [ ] Verifica alert log e audit trail nel morning check

## Cosa NON committare mai
- Password, token, chiavi private, wallet, dump con dati sensibili, file di log con dati personali.
