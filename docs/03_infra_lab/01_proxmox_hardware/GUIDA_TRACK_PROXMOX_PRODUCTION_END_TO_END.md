# Guida Completa Production-Grade: Proxmox -> Terraform -> AWX/Ansible -> Oracle Silent -> K3s/RKE2

Questa guida consolida in un unico documento il percorso moderno del repository (Fasi 1->5) con focus **production readiness**, governance e controlli operativi.

> Scopo: fornire una baseline enterprise coerente, verificabile e ripetibile.

---

## 1) Obiettivo

- Definire un'architettura operativa moderna alternativa al percorso Vagrant classico.
- Standardizzare provisioning, configurazione e deploy applicativo con dipendenza Oracle.
- Ridurre drift e rischio operativo con pipeline unica, checklist e gate qualità/sicurezza.

---

## 2) Prerequisiti

### 2.1 Prerequisiti infrastrutturali (host Proxmox)

- Server x86_64 con virtualizzazione hardware abilitata (VT-x/AMD-V).
- Capacità iniziale consigliata per lab enterprise minimo:
  - CPU: >= 16 vCPU host
  - RAM: >= 64 GB
  - Storage SSD/NVMe con separazione OS/data (consigliato)
- Rete L2/L3 con segmentazione management/workload/storage.
- DNS/NTP affidabili per tutti i nodi.

### 2.2 Prerequisiti software

- Proxmox VE aggiornato a release supportata.
- Terraform CLI versione pin-nata nel progetto IaC.
- Ansible Core + collections necessarie.
- AWX (preferibilmente via AWX Operator su Kubernetes dedicato).
- Oracle Database media/install package e response file validati.
- K3s o RKE2 in versione stabile supportata.

### 2.3 Prerequisiti di governance/security

- Secret management obbligatorio (Ansible Vault o backend esterno).
- Nessun secret in chiaro su repository.
- Tracciabilità change (PR, changelog, evidenze).
- Gate CI attivi su markdown/link/lint e controlli security già presenti.

---

## 3) Rischi e Impatto

### Rischi principali

- Drift tra Terraform state, inventario AWX e stato reale host.
- Errore di segmentazione rete/bridge con perdita reachability.
- Inconsistenze Oracle runtime variables tra ambienti.
- Misconfiguration Kubernetes (CNI/storage) con impatto su disponibilità app.

### Impatto operativo

- Potenziale downtime durante fase bootstrap cluster/Oracle install.
- Aumento superficie d'attacco se RBAC/credenziali AWX non governati.

### Mitigazioni

- Pipeline idempotente con validazione a ogni fase.
- Standard naming e metadata condivisi.
- Rollback esplicito per fase.
- Evidenze obbligatorie (artifact/log/runbook).

---

## 4) Procedura Operativa End-to-End

## Fase 1 - Proxmox Foundation (baseline obbligatoria)

### Obiettivo

Stabilire piattaforma hypervisor standard e template riusabili.

### Attività obbligatorie

1. Installare Proxmox VE su host dedicato secondo hardening base.
2. Configurare networking con Linux bridge:
   - `vmbr0` per management
   - bridge dedicati per workload e/o storage se richiesto
3. Definire storage model (LVM-thin, ZFS, NFS, Ceph) con policy snapshot/retention.
4. Definire standard virtualizzazione:
   - **KVM** per workload completi (Oracle, control-plane K8s, middleware)
   - **LXC** solo per servizi leggeri non critici/non stateful Oracle
5. Creare template cloud-init unico Debian/Ubuntu:
   - `cloud-init` installato
   - `qemu-guest-agent` installato
   - accesso SSH key-based
   - utente admin non-root con sudo
   - naming standard: `tmpl-debian12-cloudinit-v1` / `tmpl-ubuntu2204-cloudinit-v1`

### Output verificabile

- Host Proxmox raggiungibile
- Bridge documentati
- Storage policy documentata
- Template cloud-init clonabile e bootabile

### Acceptance checklist

- [ ] Piattaforma Proxmox pronta e patchata
- [ ] Bridge rete verificati end-to-end
- [ ] Storage model scelto e validato
- [ ] Template standard creato e testato

---

## Fase 2 - Terraform su Proxmox (provisioning standard)

### Obiettivo

Creare/distruggere infrastruttura VM in modo dichiarativo, ripetibile e tracciabile.

### Standard IaC

- Struttura file minima:
  - `providers.tf`
  - `variables.tf`
  - `main.tf`
  - `outputs.tf`
  - `terraform.tfvars` per ambiente
- Naming convention ambienti: `<environment>-<vm_key>`
- Variabili tipizzate e sensibili marcate come `sensitive`.
- Output espliciti per consumo downstream.

### Export metadati VM (obbligatorio)

Generare metadata machine-readable (es. `terraform_metadata.json`) contenente:

- hostname
- indirizzo IP
- ruolo (control-plane, worker, db, bastion, ecc.)
- environment

Questi metadati alimentano inventory dinamico Ansible/AWX.

### Obiettivo minimo verificabile

Un unico workflow deve riuscire in:

1. `terraform init/plan/apply`
2. Provisioning di **3 VM**
3. Export metadati
4. `terraform destroy`

### Acceptance checklist

- [ ] Provisioning 3 VM completato con naming corretto
- [ ] Metadata export disponibile e coerente
- [ ] Destroy completo senza risorse residue
- [ ] Log/apply state archiviati

---

## Fase 3 - Ansible + AWX (control plane)

### Obiettivo

Applicare configurazione idempotente su VM create da Terraform e orchestrare i job centralmente.

### Standard inventory dinamico

- Fonte inventory: metadati Terraform.
- Raggruppamenti minimi:
  - `control_plane`
  - `workers`
  - `oracle_hosts` (se presenti)
- Variabili host/group separate da secret.

### Ruoli minimi standard

- `os_baseline`: utenti, sudo, patching base, NTP, DNS, logging.
- `os_hardening`: policy sicurezza, audit, limiti, firewall baseline.
- `middleware_bootstrap`: runtime, agent, dipendenze applicative.

### Architettura AWX consigliata

- **Project**: repository Git ufficiale.
- **Credentials**:
  - Machine/SSH
  - SCM
  - Vault/secret backend
- **Job Templates** separati:
  - bootstrap OS
  - hardening
  - middleware/oracle prerequisites
- **Workflow Template** unico per catena Terraform -> bootstrap -> config.
- **RBAC** minimo:
  - Platform Admin
  - Operator
  - Auditor (read-only + evidenze)

### Flusso GitOps

- Change via PR.
- Merge solo con gate verdi.
- AWX sincronizza Project da branch controllato.
- Execution template versionati per ambiente.

### Acceptance checklist

- [ ] Inventory AWX popolato da metadata Terraform
- [ ] Job idempotenti su run ripetute
- [ ] Workflow completo eseguibile senza intervento manuale
- [ ] RBAC e credenziali allineati a policy

---

## Fase 4 - Oracle Silent Automation (milestone enterprise)

### Obiettivo

Installazione Oracle completamente non interattiva con standard team.

### Standard tecnici team

- Prerequisiti Linux codificati (kernel, limits, package, utenti/gruppi).
- Variabili runtime uniformi:
  - `ORACLE_BASE`
  - `ORACLE_HOME`
  - `ORACLE_SID`
- Response file `.rsp` versionati e gestiti come configurazione controllata.

### Policy sicurezza obbligatoria

- Password/segreti solo via vault/secret manager.
- Nessun secret in plain text nei playbook.
- Minimo privilegio su utenti/ruoli di automazione.

### Post-install validation runbook

Verifiche minime:

- listener attivo
- instance state corretto
- inventory Oracle coerente
- connettività applicativa testabile
- output log e prove archiviate

### Integrazione con quality/security del repository

- Lint Ansible per playbook.
- Check markdown/link per documentazione.
- Security gates e policy checks del repository.

### Acceptance checklist

- [ ] Installazione silent completata con response file
- [ ] Runtime Oracle coerente tra nodi
- [ ] Test post-install PASS con evidenza
- [ ] Nessuna violazione di policy security

---

## Fase 5 - K3s/RKE2 + App (capstone)

### Obiettivo

Deploy cluster Kubernetes e applicazione con dipendenza Oracle orchestrando tutto via AWX.

### Topologia minima consigliata

- 3 VM Linux:
  - 1 control-plane
  - 2 worker
- Segmentazione rete:
  - management
  - cluster overlay/underlay
  - eventuale storage network

### Scelta runtime/container model (Docker vs Podman)

Decisione da formalizzare per team:

- requisiti sicurezza
- compatibilità stack applicativo
- operatività day-2 (troubleshooting, immagini, policy)

### K3s vs RKE2 (criterio pratico)

- **K3s**: lightweight, avvio rapido, footprint ridotto.
- **RKE2**: orientamento enterprise/hardening, controllo maggiore su componenti.

### Orchestrazione AWX

Workflow template con due macro step:

1. bootstrap cluster (install/control-plane/worker join)
2. deploy applicativo (namespace, secret, deployment/service/ingress)

con dipendenza Oracle verificata a livello applicativo.

### Test end-to-end obbligatori

- cluster bootstrap da zero
- deploy applicazione riuscito
- readiness/liveness probes verdi
- test connessione app -> Oracle
- smoke test funzionale

### KPI capstone

- `provisioning_success_rate`
- `bootstrap_success_rate`
- `mean_deploy_time_minutes`

### Acceptance checklist

- [ ] Cluster operativo e stabile
- [ ] App deployata e raggiungibile
- [ ] Dipendenza Oracle validata
- [ ] KPI misurati e pubblicati

---

## 5) Rollback

### Rollback per fase

- **Fase 1**: rollback rete/storage da snapshot config host e change window controllata.
- **Fase 2**: `terraform destroy` + verifica residue via API Proxmox.
- **Fase 3**: revert branch/playbook + riesecuzione workflow AWX precedente stabile.
- **Fase 4**: deinstall/cleanup Oracle secondo runbook + ripristino snapshot VM.
- **Fase 5**: teardown cluster + redeploy versione precedente nota-stabile.

### Regole rollback

- rollback attivato su failure criteria predefiniti.
- evidenza rollback sempre archiviata (log, timestamp, owner, motivazione).

---

## 6) Validazione Finale

### Criteri Go/No-Go

- Tutte le acceptance checklist fasi interessate complete.
- Pipeline CI/Governance verdi.
- Security gate senza findings bloccanti.
- Evidenze operative disponibili e riproducibili.

### Deliverable minimi

- runbook aggiornati
- output Terraform + metadati
- log AWX workflow
- report test Oracle post-install
- report test E2E applicativo

---

## 7) Troubleshooting Rapido

### Problema: VM create ma AWX non vede host

- Verificare integrità `terraform_metadata.json`.
- Verificare mapping gruppi inventory.
- Verificare credenziali SSH e reachability rete.

### Problema: job AWX fallisce per credenziali

- Verificare source credential/input source linking.
- Verificare secret backend reachability e permessi.

### Problema: Oracle silent fallisce

- Verificare prerequisiti OS (kernel/limits/packages).
- Verificare path assoluti response file.
- Verificare owner/group OFA e permessi directory.

### Problema: cluster K3s/RKE2 non converge

- Verificare porte richieste (API, etcd/join, CNI).
- Verificare hostname univoci.
- Verificare allineamento versione/runtime nodo.

---

## 8) Riferimenti Ufficiali (Internet)

### Proxmox

- Proxmox VE Wiki Main Page: https://pve.proxmox.com/wiki/Main_Page
- Proxmox Network Configuration: https://pve.proxmox.com/wiki/Network_Configuration
- Proxmox Cloud-Init Support: https://pve.proxmox.com/wiki/Cloud-Init_Support

### Terraform

- Terraform Variables: https://developer.hashicorp.com/terraform/language/values/variables
- Terraform Outputs: https://developer.hashicorp.com/terraform/language/values/outputs
- Terraform CLI install/get started: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

### Ansible / AWX

- Ansible YAML inventory plugin: https://docs.ansible.com/ansible/latest/collections/ansible/builtin/yaml_inventory.html
- AWX Overview (official docs): https://raw.githubusercontent.com/ansible/awx/devel/docs/overview.md
- AWX Workflow (official docs): https://raw.githubusercontent.com/ansible/awx/devel/docs/workflow.md
- AWX Credential plugins/secrets: https://raw.githubusercontent.com/ansible/awx/devel/docs/credentials/credential_plugins.md
- AWX Operator docs: https://ansible.readthedocs.io/projects/awx-operator/en/latest/

### Oracle Silent Install

- Running OUI (19c): https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/running-oracle-universal-installer-to-install-oracle-database.html
- Running OUI using response file (19c): https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/running-oracle-universal-installer-using-a-response-file.html

### Kubernetes distributions

- K3s docs: https://docs.k3s.io/
- K3s requirements: https://docs.k3s.io/installation/requirements
- RKE2 docs: https://docs.rke2.io/
- RKE2 quickstart: https://docs.rke2.io/install/quickstart

---

## 9) Link interni repository

- Track Proxmox: `docs/15_proxmox_track/README.md`
- Fase 1: `docs/15_proxmox_track/PHASE_1_PROXMOX_FOUNDATION.md`
- Fase 3: `docs/15_proxmox_track/PHASE_3_ANSIBLE_AWX.md`
- Fase 4: `docs/15_proxmox_track/PHASE_4_ORACLE_SILENT_AUTOMATION.md`
- Fase 5: `docs/15_proxmox_track/PHASE_5_K8S_CAPSTONE.md`
- Terraform baseline: `infrastructure/proxmox/terraform/README.md`
- Governance KPI: `docs/04_governance_learning/02_enterprise_standards/PUBLIC_KPI_SCOREBOARD.md`

