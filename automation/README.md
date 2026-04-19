# Oracle DBA Automation with Ansible

> Production-grade playbooks for Oracle DBA activity automation.
> Inspired by the best practices of [oravirt/ansible-oracle](https://github.com/oravirt/ansible-oracle) (366★),
> [CruGlobal/ansible-oracle-db-upgrade](https://github.com/CruGlobal/ansible-oracle-db-upgrade),
> and [Oracle DevOps Series](https://medium.com/oracledevs).

---

## Why Ansible (and NOT Jenkins)

| Criterion | Ansible ✅ | Jenkins ❌ |
|---|---|---|
| Architecture | **Agentless** (SSH) — nothing to install on DB servers | Requires Java Agent on every server |
| Nature | Configuration Management + Orchestration | CI/CD Pipeline (built for builds) |
| Idempotency | **Native** — every module is idempotent by default | Must be managed manually in Groovy |
| Oracle Support | Oracle publishes official Ansible Collections | No native Oracle plugin |
| Security | SSH key-based + **Ansible Vault** for passwords | Tokens/credentials in Jenkins Store |
| DBA-friendly | **Declarative YAML** — a DBA can read it immediately | Groovy Pipeline DSL — steep curve |
| Rollback | Native `block/rescue` module for error handling | Try/catch in Groovy to be developed |

> **Verdict**: For managing Oracle infrastructure (install, patch, upgrade, backup, health check), Ansible is the right tool. Jenkins is superior only for CI/CD pipelines of software applications.

---

## Directory Structure

```
automation/
├── README.md                              ← This file
├── ansible.cfg                            ← Ansible configuration
├── inventory/
│   ├── production.ini                     ← Production servers
│   └── lab.ini                            ← Lab servers
├── group_vars/
│   ├── all.yml                            ← Global variables
│   ├── oracle_primary.yml                 ← RAC Primary variables
│   └── oracle_standby.yml                 ← RAC Standby variables
├── playbooks/
│   ├── 01_oracle_install.yml              ← 19c Software-Only installation
│   ├── 02_oracle_patching.yml             ← RU Patching (rolling RAC)
│   ├── 03_oracle_autoupgrade.yml          ← AutoUpgrade (3 phases CruGlobal-style)
│   ├── 04_daily_health_check.yml          ← Daily Health Check
│   ├── 05_rman_backup.yml                 ← RMAN Backup with validation
│   ├── 06_dataguard_switchover.yml        ← Automated DG Switchover
│   ├── 07_create_users_tablespaces.yml    ← User/Tablespace Automation
│   ├── 08_gather_stats.yml                ← Schema statistics collection
│   ├── 09_datapump_export.yml             ← Logical backup with expdp
│   └── 10_manage_services.yml             ← RAC services management
├── templates/
│   ├── grid_install.rsp.j2                ← Silent Install Grid Template (19c)
│   ├── db_install.rsp.j2                  ← Silent Install RDBMS Template (19c)
│   ├── dbca_rac.rsp.j2                    ← RAC DB Creation Template
│   └── netca_rac.rsp.j2                   ← Network Configuration Template
└── roles/
    ├── oracle_precheck/                   ← Common pre-flight checks
    │   └── tasks/main.yml
    ├── oracle_install/                    ← DB software installation
    │   ├── tasks/main.yml
    │   ├── templates/db_install.rsp.j2
    │   └── defaults/main.yml
    ├── oracle_patching/                   ← RU Patching
    │   ├── tasks/main.yml
    │   └── defaults/main.yml
    └── oracle_health_check/               ← Health check
        ├── tasks/main.yml
        └── templates/health_check.sql.j2
```

---

## Prerequisites

```bash
# 1. Install Ansible on the Control Node (your PC/jump host)
pip install ansible
# or on RHEL/OL 8+:
dnf install ansible-core

# 2. SSH key-based auth to Oracle servers
ssh-copy-id oracle@rac1
ssh-copy-id oracle@rac2
ssh-copy-id oracle@racstby1
ssh-copy-id oracle@racstby2

# 3. Verify connectivity
ansible -i inventory/lab.ini all -m ping
```

---

## Quick Usage

```bash
# ---- DAILY HEALTH CHECK ----
ansible-playbook -i inventory/production.ini playbooks/04_daily_health_check.yml

# ---- DATAGUARD SWITCHOVER ----
ansible-playbook -i inventory/production.ini playbooks/06_dataguard_switchover.yml

# ---- RMAN BACKUP ----
ansible-playbook -i inventory/production.ini playbooks/05_rman_backup.yml

# ---- DATAPUMP EXPORT ----
ansible-playbook -i inventory/production.ini playbooks/09_datapump_export.yml

# ---- PATCHING (rolling, zero downtime) ----
# Dry-run first:
ansible-playbook -i inventory/production.ini playbooks/02_oracle_patching.yml --check
# Real execution:
ansible-playbook -i inventory/production.ini playbooks/02_oracle_patching.yml

# ---- AUTOUPGRADE (3 phases) ----
# Phase 1: Pre-upgrade (24h before, NO downtime):
ansible-playbook -i inventory/production.ini playbooks/03_oracle_autoupgrade.yml --tags pre_upgrade
# Phase 2: Real upgrade (DOWNTIME!):
ansible-playbook -i inventory/production.ini playbooks/03_oracle_autoupgrade.yml --tags upgrade
# Phase 3: Finalization (7 days after, NO downtime):
ansible-playbook -i inventory/production.ini playbooks/03_oracle_autoupgrade.yml --tags finalize

# ---- SOFTWARE INSTALLATION ----
ansible-playbook -i inventory/lab.ini playbooks/01_oracle_install.yml
```

---

## Security: Ansible Vault

Passwords must NEVER be stored in plain text. Use Ansible Vault:

```bash
# Create the vault
ansible-vault create group_vars/vault.yml
# Content:
#   vault_oracle_sys_password: "MiaPassword123!"
#   vault_oracle_rman_password: "BackupSecure!"

# Use the vault in playbooks:
ansible-playbook playbooks/05_rman_backup.yml --ask-vault-pass
```

---

## References

- [oravirt/ansible-oracle](https://github.com/oravirt/ansible-oracle) — Complete collection (366★, 56 releases)
- [CruGlobal/ansible-oracle-db-upgrade](https://github.com/CruGlobal/ansible-oracle-db-upgrade) — 3-phase pattern for upgrades
- [Oracle DevOps Series: Automate 19c with Ansible](https://medium.com/oracledevs/devops-series-automate-oracle-19c-rdbms-installations-with-ansible-github-43cfdf344a4a)
- [oravirt Feature List](https://github.com/oravirt/ansible-oracle/blob/master/doc/featurelist.adoc) — Full compatibility matrix
