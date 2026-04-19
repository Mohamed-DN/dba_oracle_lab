# Automazione Oracle AutoUpgrade

## Ansible vs Jenkins — Analisi Rapida

| Criterio | Ansible | Jenkins |
|---|---|---|
| **Architettura** | Agentless (SSH) | Richiede Agent sui nodi |
| **Natura** | Configuration Management + Orchestration | CI/CD Pipeline |
| **Idempotenza** | Nativa (ogni modulo è idempotente) | Da gestire manualmente negli script |
| **Curva di apprendimento** | YAML dichiarativo — immediato | Groovy/Pipeline DSL — più complesso |
| **Oracle Support** | Oracle fornisce Ansible Collections ufficiali | Nessun plugin Oracle nativo |
| **Sicurezza** | SSH key-based, Ansible Vault per segreti | Token/credenziali in Jenkins Credential Store |
| **Scalabilità** | Ottima per 1-100 host | Migliore per pipeline CI/CD complesse |
| **Installazione richiesta** | Solo sul Control Node (il tuo PC/jump host) | Server Jenkins + Agent su ogni target |

### Verdetto: **Ansible** ✅

Per l'AutoUpgrade sui server Oracle, Ansible è la scelta giusta:
1. **Agentless**: non devi installare nulla sui server DB (spesso controllati dal team Security)
2. **Oracle Collections**: `oracle.oci` e community collections Oracle-specifiche
3. **Idempotenza**: puoi rieseguire il playbook senza effetti collaterali
4. **Semplicità**: un DBA può leggere e modificare il YAML senza essere un developer

Jenkins è migliore per pipeline CI/CD software (build, test, deploy di applicazioni), non per gestione infrastrutturale di database.

---

## File del Progetto

```
automation/
├── README.md              ← Questo file
├── inventory.ini          ← Lista server target
└── playbooks/
    └── oracle_autoupgrade.yml  ← Playbook principale
```

## Prerequisiti

1. Ansible installato sul Control Node:
   ```bash
   pip install ansible
   # oppure
   dnf install ansible-core    # RHEL/OL 8+
   ```

2. SSH key-based authentication verso i server Oracle:
   ```bash
   ssh-copy-id oracle@rac1
   ssh-copy-id oracle@rac2
   ```

3. Il target ORACLE_HOME (19c o 26c) deve essere già installato (software only) sui server.

4. L'autoupgrade.jar aggiornato deve essere già presente (il playbook verifica).

## Utilizzo

```bash
# 1. Check connettività
ansible -i inventory.ini oracle_servers -m ping

# 2. Dry run (solo analyze, NESSUNA modifica)
ansible-playbook -i inventory.ini playbooks/oracle_autoupgrade.yml --tags analyze

# 3. Deploy reale (ATTENZIONE: esegue l'upgrade!)
ansible-playbook -i inventory.ini playbooks/oracle_autoupgrade.yml --tags deploy
```
