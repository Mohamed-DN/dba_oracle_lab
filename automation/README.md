# Automazione Oracle DBA con Ansible

> Playbook production-grade per l'automazione delle attività Oracle DBA.
> Ispirati alle best practice di [oravirt/ansible-oracle](https://github.com/oravirt/ansible-oracle) (366★),
> [CruGlobal/ansible-oracle-db-upgrade](https://github.com/CruGlobal/ansible-oracle-db-upgrade),
> e [Oracle DevOps Series](https://medium.com/oracledevs).

---

## Perché Ansible (e NON Jenkins)

| Criterio | Ansible ✅ | Jenkins ❌ |
|---|---|---|
| Architettura | **Agentless** (SSH) — nulla da installare sui DB server | Richiede Agent Java su ogni server |
| Natura | Configuration Management + Orchestration | CI/CD Pipeline (nato per builds) |
| Idempotenza | **Nativa** — ogni modulo è idempotente di default | Da gestire manualmente in Groovy |
| Oracle Support | Oracle pubblica Ansible Collections ufficiali | Nessun plugin Oracle nativo |
| Sicurezza | SSH key-based + **Ansible Vault** per password | Token/credenziali in Jenkins Store |
| DBA-friendly | **YAML dichiarativo** — un DBA lo legge subito | Groovy Pipeline DSL — curva ripida |
| Rollback | Modulo `block/rescue` nativo per error handling | Try/catch in Groovy da sviluppare |

> **Verdetto**: Per gestire infrastruttura Oracle (install, patch, upgrade, backup, health check), Ansible è lo strumento corretto. Jenkins è superiore solo per pipeline CI/CD di applicazioni software.

---

## Struttura Directory

```
automation/
├── README.md                              ← Questo file
├── ansible.cfg                            ← Configurazione Ansible
├── inventory/
│   ├── production.ini                     ← Server di produzione
│   └── lab.ini                            ← Server del lab
├── group_vars/
│   └── all.yml                            ← Variabili globali (lab + produzione)
├── collections_requirements.yml           ← Collections consigliate (oravirt/community)
├── playbooks/
│   ├── 01_oracle_install.yml              ← Installazione 19c Software-Only
│   ├── 02_oracle_patching.yml             ← Patching RU (rolling RAC)
│   ├── 03_oracle_autoupgrade.yml          ← AutoUpgrade (3 fasi CruGlobal-style)
│   ├── 04_daily_health_check.yml          ← Health Check giornaliero
│   ├── 05_rman_backup.yml                 ← Backup RMAN con validazione
│   ├── 06_dataguard_switchover.yml        ← Switchover DG automatizzato
│   ├── 07_create_users_tablespaces.yml    ← Automazione User/Tablespace
│   ├── 08_gather_stats.yml                ← Raccolta statistiche schema
│   ├── 09_datapump_export.yml             ← Logical backup con expdp
│   ├── 10_manage_services.yml             ← Gestione RAC services
│   ├── 11_create_cdb_pdb.yml              ← Creazione CDB/PDB idempotente (safe gate)
│   ├── 12_dba_maintenance.yml             ← Maintenance DBA periodica
│   └── 13_maa_guardrails.yml              ← Guardrail MAA (DG validate + parametri)
├── roles/
│   ├── maa_guardrails/                    ← Ruolo MAA baseline enterprise
│   ├── oracle_daily_health/               ← Ruolo riusabile health-check
│   ├── oracle_rman_backup/                ← Ruolo riusabile RMAN backup
│   └── oracle_dataguard_switchover/       ← Ruolo riusabile switchover DG
├── templates/
│   ├── grid_install.rsp.j2                ← Template Silent Install Grid (19c)
│   ├── db_install.rsp.j2                  ← Template Silent Install RDBMS (19c)
│   ├── dbca_rac.rsp.j2                    ← Template Creazione RAC DB
│   └── netca_rac.rsp.j2                   ← Template Configurazione Reti
└── Struttura in transizione playbook-centric → role-centric.
```

---

## Prerequisiti

```bash
# 1. Installa Ansible sul Control Node (il tuo PC/jump host)
pip install ansible
# oppure su RHEL/OL 8+:
dnf install ansible-core

# 1b. Installa collections Oracle (oravirt + community)
ansible-galaxy collection install -r collections_requirements.yml

# 2. SSH key-based auth verso i server Oracle
ssh-copy-id oracle@rac1
ssh-copy-id oracle@rac2
ssh-copy-id oracle@racstby1
ssh-copy-id oracle@racstby2

# 3. Verifica connettività
ansible -i inventory/lab.ini all -m ping
```

---

## Uso Rapido

```bash
# ---- HEALTH CHECK GIORNALIERO ----
ansible-playbook -i inventory/production.ini playbooks/04_daily_health_check.yml

# ---- DATAGUARD SWITCHOVER ----
ansible-playbook -i inventory/production.ini playbooks/06_dataguard_switchover.yml

# ---- BACKUP RMAN ----
ansible-playbook -i inventory/production.ini playbooks/05_rman_backup.yml

# ---- DATAPUMP EXPORT ----
ansible-playbook -i inventory/production.ini playbooks/09_datapump_export.yml

# ---- PATCHING (rolling, zero downtime) ----
# Dry-run prima:
ansible-playbook -i inventory/production.ini playbooks/02_oracle_patching.yml --check
# Esecuzione reale:
ansible-playbook -i inventory/production.ini playbooks/02_oracle_patching.yml

# ---- AUTOUPGRADE (3 fasi) ----
# Fase 1: Pre-upgrade (24h prima, NO downtime):
ansible-playbook -i inventory/production.ini playbooks/03_oracle_autoupgrade.yml --tags pre_upgrade
# Fase 2: Upgrade reale (DOWNTIME!):
ansible-playbook -i inventory/production.ini playbooks/03_oracle_autoupgrade.yml --tags upgrade
# Fase 3: Finalizzazione (7 gg dopo, NO downtime):
ansible-playbook -i inventory/production.ini playbooks/03_oracle_autoupgrade.yml --tags finalize

# ---- INSTALLAZIONE SOFTWARE ----
ansible-playbook -i inventory/lab.ini playbooks/01_oracle_install.yml

# ---- CDB/PDB (se mancanti) ----
ansible-playbook -i inventory/lab.ini playbooks/11_create_cdb_pdb.yml \
  -e cdb_create_if_missing=true --ask-vault-pass

# ---- DBA MAINTENANCE (invalid objects, stats dizionario, audit purge) ----
ansible-playbook -i inventory/production.ini playbooks/12_dba_maintenance.yml

# ---- MAA GUARDRAILS (baseline production) ----
ansible-playbook -i inventory/production.ini playbooks/13_maa_guardrails.yml \
  -e maa_enforce_compliance=true \
  -e maa_set_broker_thresholds=true
```

---

## Sicurezza: Ansible Vault

Le password NON vanno mai in chiaro. Usa Ansible Vault:

```bash
# Crea il vault
ansible-vault create group_vars/vault.yml
# Contenuto:
#   vault_oracle_sys_password: "MiaPassword123!"
#   vault_oracle_rman_password: "BackupSecure!"
#   vault_app_user_password: "StrongAppUserPassword!"
#   vault_cdb_admin_password: "StrongCdbPassword!"

# Usa il vault nei playbook:
ansible-playbook playbooks/05_rman_backup.yml --ask-vault-pass
```

---

## Riferimenti

- [oravirt/ansible-oracle](https://github.com/oravirt/ansible-oracle) — Collection completa (366★, 56 release)
- [CruGlobal/ansible-oracle-db-upgrade](https://github.com/CruGlobal/ansible-oracle-db-upgrade) — Pattern 3-fasi per upgrade
- [Oracle DevOps Series: Automate 19c with Ansible](https://medium.com/oracledevs/devops-series-automate-oracle-19c-rdbms-installations-with-ansible-github-43cfdf344a4a)
- [oravirt Feature List](https://github.com/oravirt/ansible-oracle/blob/master/doc/featurelist.adoc) — Matrice compatibilità completa

---

## Test funzionali E2E ripetibili

Suite locale mockata (senza Oracle installato) per verificare il comportamento reale
dei playbook principali:

```bash
tests/e2e/ansible/run_functional_e2e.sh
```

La stessa suite è eseguita automaticamente nel workflow GitHub Actions:
`.github/workflows/e2e-functional-playbooks.yml`.
