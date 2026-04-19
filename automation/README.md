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
│   ├── all.yml                            ← Variabili globali
│   ├── oracle_primary.yml                 ← Variabili RAC Primary
│   └── oracle_standby.yml                 ← Variabili RAC Standby
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
│   └── 10_manage_services.yml             ← Gestione RAC services
└── roles/
    ├── oracle_precheck/                   ← Pre-flight checks comuni
    │   └── tasks/main.yml
    ├── oracle_install/                    ← Installazione DB software
    │   ├── tasks/main.yml
    │   ├── templates/db_install.rsp.j2
    │   └── defaults/main.yml
    ├── oracle_patching/                   ← Patching RU
    │   ├── tasks/main.yml
    │   └── defaults/main.yml
    └── oracle_health_check/               ← Health check
        ├── tasks/main.yml
        └── templates/health_check.sql.j2
```

---

## Prerequisiti

```bash
# 1. Installa Ansible sul Control Node (il tuo PC/jump host)
pip install ansible
# oppure su RHEL/OL 8+:
dnf install ansible-core

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

# Usa il vault nei playbook:
ansible-playbook playbooks/05_rman_backup.yml --ask-vault-pass
```

---

## Riferimenti

- [oravirt/ansible-oracle](https://github.com/oravirt/ansible-oracle) — Collection completa (366★, 56 release)
- [CruGlobal/ansible-oracle-db-upgrade](https://github.com/CruGlobal/ansible-oracle-db-upgrade) — Pattern 3-fasi per upgrade
- [Oracle DevOps Series: Automate 19c with Ansible](https://medium.com/oracledevs/devops-series-automate-oracle-19c-rdbms-installations-with-ansible-github-43cfdf344a4a)
- [oravirt Feature List](https://github.com/oravirt/ansible-oracle/blob/master/doc/featurelist.adoc) — Matrice compatibilità completa
