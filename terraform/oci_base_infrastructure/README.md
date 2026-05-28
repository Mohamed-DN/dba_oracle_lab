# RUNBOOK ENTERPRISE: INFRASTRUTTURA OCI CON TERRAFORM PER ORACLE 26AI

> **Document Classification:** ENTERPRISE OPERATIONS / INFRASTRUCTURE AS CODE  
> **Last Updated:** Maggio 2026  
> **Target Audience:** Senior DBA, Cloud Architects, DevOps/SRE Engineers  
> **Prerequisiti:** Account OCI, Terraform CLI, conoscenza base di networking

## SOMMARIO
1. [Introduzione all'Infrastructure as Code (IaC)](#1-introduzione-allinfrastructure-as-code-iac)
2. [Architettura di Rete OCI (VCN, Subnet, Security)](#2-architettura-di-rete-oci-vcn-subnet-security)
3. [Prerequisiti e Configurazione Ambiente](#3-prerequisiti-e-configurazione-ambiente)
4. [Autenticazione e Gestione Sicura dei Secrets](#4-autenticazione-e-gestione-sicura-dei-secrets)
5. [I Manifesti Terraform Spiegati Riga per Riga](#5-i-manifesti-terraform-spiegati-riga-per-riga)
6. [Remote State e Locking (Lavoro in Team)](#6-remote-state-e-locking-lavoro-in-team)
7. [Deployment Operativo Step-by-Step](#7-deployment-operativo-step-by-step)
8. [Integrazione con Ansible (Post-Provisioning)](#8-integrazione-con-ansible-post-provisioning)
9. [Pipeline CI/CD (GitOps con GitHub Actions)](#9-pipeline-cicd-gitops-con-github-actions)
10. [Gestione del Lifecycle (Scale, Modify, Destroy)](#10-gestione-del-lifecycle-scale-modify-destroy)
11. [Troubleshooting e Errori Comuni](#11-troubleshooting-e-errori-comuni)

---

## 1. Introduzione all'Infrastructure as Code (IaC)

### 1.1. Perché Terraform e non la Console Web OCI?
In un ambiente Enterprise, l'infrastruttura non si crea cliccando sulla Console Web.
Ogni risorsa deve essere:
- **Versionata**: Il codice Terraform vive in Git, ogni modifica è tracciabile.
- **Riproducibile**: Lo stesso `terraform apply` genera lo stesso ambiente identico in qualsiasi region OCI.
- **Revisionabile**: Un collega può fare code review della tua infrastruttura via Pull Request.
- **Distruttibile**: Un `terraform destroy` ripulisce tutto, evitando risorse orfane che generano costi.

### 1.2. Terraform vs OCI Resource Manager
OCI offre il proprio servizio di IaC (Resource Manager), che è essenzialmente un wrapper gestito di Terraform. Per il nostro lab usiamo Terraform CLI direttamente perché:
- È vendor-agnostico (funziona anche con AWS, Azure, GCP).
- Permette il pieno controllo dello state file.
- Si integra nativamente con GitHub Actions.

### 1.3. Architettura Target
Il codice in questa directory crea la seguente infrastruttura:
```
OCI Region (eu-frankfurt-1)
+-- Compartment: Oracle_Lab
    +-- VCN: Oracle_26ai_VCN (10.0.0.0/16)
        +-- Internet Gateway (IGW)
        +-- Route Table (Public)
        +-- Security List (SSH + Oracle Net)
        +-- Public Subnet (10.0.1.0/24)
            +-- Compute Instance: oracle-26ai-primary
                +-- Shape: VM.Standard.A1.Flex (ARM, 4 OCPU, 24GB)
                +-- OS: Oracle Linux 8.9
                +-- Boot Volume: 100 GB
                +-- Public IP: (dinamico, output di Terraform)
```

---

## 2. Architettura di Rete OCI (VCN, Subnet, Security)

### 2.1. Virtual Cloud Network (VCN)
La VCN è l'equivalente OCI di un VPC (Virtual Private Cloud) su AWS. È il confine logico isolato in cui risiedono tutte le risorse di rete.
- **CIDR Block**: `10.0.0.0/16` (65.534 indirizzi IP disponibili).
- **DNS Label**: `oraclevcn` (permette la risoluzione interna dei nomi, es. `oracle-26ai-primary.public.oraclevcn.oraclevcn.eu-frankfurt-1.oci.oraclecloud.com`).

### 2.2. Internet Gateway (IGW)
Il perimetro verso l'esterno. Senza un IGW, le istanze nella VCN non possono raggiungere Internet (né essere raggiunte).

### 2.3. Route Table
Associata alla Subnet, instrada il traffico verso l'IGW:
```
Destinazione: 0.0.0.0/0 → Target: IGW
```

### 2.4. Security Lists (Stateful Firewall)
Le Security List sono firewall stateful a livello di subnet. Ogni regola specifica:
- **Direzione**: Ingress (in entrata) o Egress (in uscita).
- **Protocollo**: TCP, UDP, ICMP.
- **Source/Destination CIDR**: Chi può accedere.
- **Porte**: Quali porte sono aperte.

**Regole configurate nel nostro lab:**

| Direzione | Protocollo | Porta | Source | Motivo |
|---|---|---|---|---|
| Ingress | TCP | 22 | 0.0.0.0/0 | SSH (restringere in PROD al tuo IP) |
| Ingress | TCP | 1521 | 0.0.0.0/0 | Oracle Net Listener |
| Egress | ALL | ALL | 0.0.0.0/0 | Traffico in uscita libero |

> **ATTENZIONE (Ambiente di Produzione):** In produzione il database **NON** deve avere un IP pubblico e **NON** deve risiedere in una Public Subnet. L'architettura corretta prevede:
> - Database in **Private Subnet** (senza route verso IGW).
> - Accesso SSH tramite **OCI Bastion Service** o **Bastion Host** nella Public Subnet.
> - Accesso applicativo tramite **Load Balancer** nella Public Subnet che fa proxy verso la Private Subnet.

### 2.5. Subnet Pubblica
- **CIDR**: `10.0.1.0/24` (254 host).
- **Tipo**: Pubblica (le istanze ricevono un IP pubblico).
- **Route Table**: Associata alla Public Route Table (traffico verso IGW).
- **Security List**: Associata alla Oracle Security List.

---

## 3. Prerequisiti e Configurazione Ambiente

### 3.1. Installazione Terraform CLI
```bash
# Oracle Linux / RHEL
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo dnf install -y terraform
terraform --version
# Output atteso: Terraform v1.8.x
```

```bash
# macOS (Homebrew)
brew install terraform
```

```powershell
# Windows (Chocolatey)
choco install terraform
```

### 3.2. Generazione delle Chiavi API OCI
Per autenticare Terraform verso OCI, serve una coppia di chiavi RSA.

```bash
mkdir -p ~/.oci
# Genera la chiave privata (2048 bit RSA)
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod 600 ~/.oci/oci_api_key.pem
# Genera la chiave pubblica corrispondente
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem
# Genera il fingerprint (servirà nel terraform.tfvars)
openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key.pem | openssl md5 -c
# Output: MD5(stdin)= aa:bb:cc:dd:ee:ff:...
```

### 3.3. Caricamento della Chiave Pubblica su OCI
1. Accedere alla Console OCI → Identity & Security → Users → Il tuo utente.
2. Sezione "API Keys" → Add API Key → Paste Public Key.
3. Incollare il contenuto di `~/.oci/oci_api_key_public.pem`.
4. Salvare. OCI mostrerà i parametri da usare nel provider Terraform.

### 3.4. Raccolta degli OCID Necessari
Per popolare il file `terraform.tfvars`, servono i seguenti identificatori:

| Parametro | Dove Trovarlo |
|---|---|
| `tenancy_ocid` | Console OCI → Administration → Tenancy Details |
| `user_ocid` | Console OCI → Identity → Users → Il tuo utente |
| `compartment_ocid` | Console OCI → Identity → Compartments |
| `fingerprint` | Output del comando `openssl md5` sopra |

---

## 4. Autenticazione e Gestione Sicura dei Secrets

### 4.1. Il File terraform.tfvars (Locale, Mai in Git)
Crea il file `terraform.tfvars` nella stessa directory dei `.tf`:
```hcl
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaxxxxxxxxx"
user_ocid        = "ocid1.user.oc1..aaaaaaaxxxxxxxxx"
fingerprint      = "aa:bb:cc:dd:ee:ff:11:22:33:44:55:66:77:88:99:00"
private_key_path = "~/.oci/oci_api_key.pem"
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaxxxxxxxxx"
ssh_public_key   = "ssh-rsa AAAAB3NzaC1yc2EAAAA... user@host"
region           = "eu-frankfurt-1"
```

**CRITICO:** Questo file contiene credenziali sensibili. Assicurarsi che sia nel `.gitignore`:
```bash
echo "terraform.tfvars" >> .gitignore
echo "*.tfstate*" >> .gitignore
echo ".terraform/" >> .gitignore
```

### 4.2. Gestione Enterprise dei Secrets (OCI Vault / KMS)
In ambienti Enterprise, le credenziali non devono mai risiedere su file locali. Usare **OCI Vault**:

**Creazione del Vault e del Secret (Console OCI):**
1. Console OCI → Identity & Security → Vault → Create Vault.
2. Creare una Master Encryption Key (MEK).
3. Creare un Secret contenente la chiave SSH pubblica.
4. Copiare l'OCID del Secret.

**Consumo del Secret da Terraform:**
```hcl
data "oci_secrets_secretbundle" "ssh_key_secret" {
  secret_id = "ocid1.vaultsecret.oc1.eu-frankfurt-1.xxxxxxxxxxxx"
}

locals {
  ssh_public_key_from_vault = base64decode(
    data.oci_secrets_secretbundle.ssh_key_secret.secret_bundle_content[0].content
  )
}
```
Poi nel blocco `compute.tf`, sostituire `var.ssh_public_key` con `local.ssh_public_key_from_vault`.

---

## 5. I Manifesti Terraform Spiegati Riga per Riga

### 5.1. `main.tf` — Provider e Versioni
```hcl
terraform {
  required_version = ">= 1.5.0"      # Versione minima di Terraform CLI
  required_providers {
    oci = {
      source  = "oracle/oci"          # Provider ufficiale Oracle
      version = "~> 5.0"             # Qualsiasi 5.x (backward-compatible)
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
```

### 5.2. `variables.tf` — Parametri Configurabili
Ogni variabile senza `default` è **obbligatoria** e deve essere fornita nel `terraform.tfvars`:
```hcl
variable "tenancy_ocid" {
  description = "OCID del Tenancy OCI"
}
variable "user_ocid" {
  description = "OCID dell'utente API"
}
variable "fingerprint" {
  description = "Fingerprint della chiave API"
}
variable "private_key_path" {
  description = "Path alla chiave privata PEM"
}
variable "region" {
  description = "Region OCI target"
  default     = "eu-frankfurt-1"
}
variable "compartment_ocid" {
  description = "OCID del Compartment in cui creare le risorse"
}
variable "vcn_cidr_block" {
  description = "CIDR della VCN"
  default     = "10.0.0.0/16"
}
variable "public_subnet_cidr" {
  description = "CIDR della Public Subnet"
  default     = "10.0.1.0/24"
}
variable "ssh_public_key" {
  description = "Chiave pubblica SSH per l'accesso alle istanze"
}
```

### 5.3. `network.tf` — Rete Completa
Contiene VCN, IGW, Route Table, Security List e Subnet (vedi sezione 2 per i dettagli architetturali).

### 5.4. `compute.tf` — Istanza Oracle 26ai
```hcl
data "oci_core_images" "ol8" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "oracle_26ai_node" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "oracle-26ai-primary"
  shape               = "VM.Standard.A1.Flex"  # ARM Always Free

  shape_config {
    ocpus         = 4    # 4 core ARM (Always Free Tier)
    memory_in_gbs = 24   # 24 GB RAM (Always Free Tier)
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol8.images[0].id
    boot_volume_size_in_gbs = 100  # 100GB per OS + Oracle Home
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

output "oracle_26ai_public_ip" {
  description = "IP pubblico dell'istanza Oracle per la connessione SSH e Ansible"
  value       = oci_core_instance.oracle_26ai_node.public_ip
}
```

---

## 6. Remote State e Locking (Lavoro in Team)

### 6.1. Il Problema dello State Locale
Di default, `terraform apply` genera un file `terraform.tfstate` nella directory corrente. Questo file contiene:
- L'inventario completo di tutte le risorse create.
- Password, IP, OCID e altri dati sensibili in chiaro.

**In un team di DBA, questo è letale:**
- Due persone che lanciano `apply` contemporaneamente corrompono lo state (split-brain).
- Se il laptop del DBA si rompe, lo state è perso e Terraform non sa più cosa ha creato.

### 6.2. Soluzione: Remote Backend su OCI Object Storage
Creare un bucket OCI per ospitare lo state:
1. Console OCI → Object Storage → Create Bucket → Nome: `tf-state-oracle-lab`.
2. Creare un **Pre-Authenticated Request (PAR)** con permesso Read/Write sull'oggetto `terraform.tfstate`.

Aggiungere al `main.tf`:
```hcl
terraform {
  backend "http" {
    update_method = "PUT"
    address       = "https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/<PAR_TOKEN>/n/<namespace>/b/tf-state-oracle-lab/o/terraform.tfstate"
  }
}
```

Dopo aver aggiunto il backend, eseguire la migrazione dello state:
```bash
terraform init -migrate-state
# Terraform chiederà conferma per spostare lo state locale nel backend remoto
```

---

## 7. Deployment Operativo Step-by-Step

### 7.1. Inizializzazione
```bash
cd terraform/oci_base_infrastructure
terraform init
```
*Output Atteso:*
```text
Initializing the backend...
Initializing provider plugins...
- Finding oracle/oci versions matching "~> 5.0"...
- Installing oracle/oci v5.46.0...
Terraform has been successfully initialized!
```

### 7.2. Piano di Esecuzione (Dry Run)
```bash
terraform plan -out=tfplan
```
*Output Atteso (riassunto):*
```text
Plan: 5 to add, 0 to change, 0 to destroy.
Changes to Outputs:
  + oracle_26ai_public_ip = (known after apply)
```

### 7.3. Applicazione
```bash
terraform apply tfplan
```
*Tempo stimato: 2-5 minuti.*

*Output Atteso:*
```text
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
Outputs:
  oracle_26ai_public_ip = "152.70.xx.xx"
```

### 7.4. Primo Accesso SSH
```bash
ssh -i ~/.oci/oci_api_key.pem opc@$(terraform output -raw oracle_26ai_public_ip)
```
L'utente `opc` è l'utente di default sulle immagini Oracle Linux in OCI, con accesso `sudo` senza password.

---

## 8. Integrazione con Ansible (Post-Provisioning)

Dopo che Terraform ha creato l'infrastruttura, Ansible completa la configurazione software (installazione Oracle, tuning OS, ecc.).

### 8.1. Inventario Dinamico
Generare automaticamente l'inventario Ansible dall'output di Terraform:
```bash
echo "[oracle_servers]" > ../automation/inventory/oci_hosts.ini
echo "oracle-26ai-primary ansible_host=$(terraform output -raw oracle_26ai_public_ip) ansible_user=opc ansible_ssh_private_key_file=~/.oci/oci_api_key.pem" >> ../automation/inventory/oci_hosts.ini
```

### 8.2. Lancio dei Playbook
```bash
cd ../automation
ansible-playbook -i inventory/oci_hosts.ini playbooks/oracle_install.yml
```

---

## 9. Pipeline CI/CD (GitOps con GitHub Actions)

### 9.1. Workflow Completo
Salvare in `.github/workflows/terraform.yml`:
```yaml
name: Terraform OCI Infrastructure
on:
  push:
    paths: ['terraform/**']
    branches: [master]
  pull_request:
    paths: ['terraform/**']

env:
  TF_VAR_tenancy_ocid: ${{ secrets.OCI_TENANCY_OCID }}
  TF_VAR_user_ocid: ${{ secrets.OCI_USER_OCID }}
  TF_VAR_fingerprint: ${{ secrets.OCI_FINGERPRINT }}
  TF_VAR_compartment_ocid: ${{ secrets.OCI_COMPARTMENT_OCID }}
  TF_VAR_ssh_public_key: ${{ secrets.OCI_SSH_PUBLIC_KEY }}
  TF_VAR_private_key_path: /tmp/oci_key.pem

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.8.0"
      - name: Inject OCI API Key
        run: echo "${{ secrets.OCI_PRIVATE_KEY }}" > /tmp/oci_key.pem && chmod 600 /tmp/oci_key.pem
      - name: Terraform Init
        working-directory: terraform/oci_base_infrastructure
        run: terraform init
      - name: Terraform Plan
        working-directory: terraform/oci_base_infrastructure
        run: terraform plan -no-color
```

---

## 10. Gestione del Lifecycle (Scale, Modify, Destroy)

### 10.1. Scaling Verticale (Aumentare CPU/RAM)
Modificare `compute.tf`:
```hcl
shape_config {
  ocpus         = 8    # Da 4 a 8 core
  memory_in_gbs = 48   # Da 24 a 48 GB
}
```
Poi:
```bash
terraform plan   # Verificherà il diff
terraform apply  # L'istanza verrà ricreata con le nuove specifiche
```

### 10.2. Teardown Completo (Fine Lab)
```bash
terraform destroy -auto-approve
```
*Output Atteso:*
```text
Destroy complete! Resources: 5 destroyed.
```
**ATTENZIONE:** Questo distrugge TUTTO, inclusi i dati. Eseguire un backup prima se necessario.

---

## 11. Troubleshooting e Errori Comuni

### 11.1. `Error: 401-NotAuthenticated`
**Causa:** Le chiavi API sono scadute, il fingerprint non corrisponde, o l'utente non ha i permessi IAM.
**Soluzione:** Rigenerare le chiavi API (sezione 3.2) e ricaricarle sulla Console OCI.

### 11.2. `Error: 500-InternalError` durante la creazione Compute
**Causa:** La capacity della region è esaurita per lo shape `A1.Flex` (molto comune nel Free Tier).
**Soluzione:** Cambiare `region` nel `terraform.tfvars` (provare `eu-amsterdam-1`, `uk-london-1` o `eu-zurich-1`).

### 11.3. `Error: 409-Conflict` sulla VCN
**Causa:** Esiste già una VCN con lo stesso nome nel Compartment (residuo di un `destroy` fallito).
**Soluzione:** Eliminare manualmente la VCN dalla Console OCI, oppure importarla nello state: `terraform import oci_core_vcn.oracle_vcn <OCID_della_VCN>`.
