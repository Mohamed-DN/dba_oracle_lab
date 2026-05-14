# Terraform: Infrastruttura OCI Enterprise per Oracle 26ai

Questa directory contiene l'architettura **Infrastructure as Code (IaC)** di livello Enterprise per il provisioning dell'infrastruttura sottostante ad Oracle 26ai su Oracle Cloud Infrastructure (OCI). 
A differenza di un lab locale su Vagrant, questo ambiente rispetta le best practice di security e scalabilità cloud.

---

## 1. Architettura di Rete (VCN & Subnets)
Il codice `network.tf` genera una topologia sicura:
- **Virtual Cloud Network (VCN)**: Allocata con un CIDR `/16` (es. `10.0.0.0/16`), fungendo da confine logico isolato.
- **Internet Gateway (IGW)**: Il perimetro verso l'esterno, agganciato a una *Route Table* dedicata.
- **Public Subnet**: Una subnet bastion/frontend (`10.0.1.0/24`). In un ambiente di Produzione Enterprise puro, il database risiederebbe in una **Private Subnet**, acceduta solo tramite un Bastion Host o OCI Bastion Service. Per semplicità didattica di questo Lab, è esposta, ma protetta da Security List ferree.
- **Security Lists (Stateful)**: 
  - Ingress TCP 22 (SSH): Limitata idealmente solo al tuo IP pubblico aziendale.
  - Ingress TCP 1521 (Oracle Net): Isolata al perimetro applicativo.

---

## 2. Gestione Enterprise dello State (Remote Backend)
In ambienti collaborativi, lo *state file* (`terraform.tfstate`) **non deve mai** risiedere sul laptop del singolo sviluppatore. Contiene dati sensibili e porta a conflitti (split-brain).
Per abilitare il backend remoto su OCI Object Storage, aggiungi a `main.tf`:

```hcl
terraform {
  backend "http" {
    update_method = "PUT"
    # L'URL Pre-Autenticato (PAR) del bucket Object Storage
    address       = "https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/.../b/tf-state/o/terraform.tfstate"
  }
}
```
Prima del `terraform apply`, la lock viene acquisita, garantendo l'assenza di race-condition tra i DBA.

---

## 3. Gestione Sicura dei Secrets (OCI Vault)
Non scrivere **mai** chiavi SSH o password in chiaro nei file `.tfvars`. 
L'approccio Enterprise prevede l'uso di **OCI Vault (KMS)**. 

Definisci un blocco `data` per recuperare il secret al volo:
```hcl
data "oci_secrets_secretbundle" "ssh_key_secret" {
    secret_id = "ocid1.vaultsecret.oc1.eu-frankfurt-1.xxxx"
}
```
In questo modo, al momento della creazione della risorsa Compute (`compute.tf`), la chiave pubblica viene iniettata dinamicamente estraendola da `base64decode(data.oci_secrets_secretbundle.ssh_key_secret.secret_bundle_content[0].content)`.

---

## 4. Pipeline CI/CD (GitOps)
Per automatizzare l'infrastruttura, Terraform deve essere eseguito da una pipeline (es. GitHub Actions o GitLab CI).
1. Crea un Service Principal (OCI IAM User) dedicato a Terraform.
2. Salva i parametri (Tenancy OCID, User OCID, API Key) nei **GitHub Secrets**.
3. Usa l'action ufficiale:
   ```yaml
   steps:
     - uses: hashicorp/setup-terraform@v3
     - run: terraform init
     - run: terraform plan -out=tfplan
     - run: terraform apply -auto-approve tfplan
   ```

---

## 5. Deployment Operativo
1. Crea il file `terraform.tfvars` (inserito nel `.gitignore`) con i tuoi OCID personali.
2. Inizializza l'ambiente:
   ```bash
   terraform init
   ```
3. Verifica le modifiche proposte:
   ```bash
   terraform plan
   ```
4. Esegui il provisioning:
   ```bash
   terraform apply
   ```
5. **Teardown**: Per distruggere il lab ed evitare addebiti OCI a fine giornata:
   ```bash
   terraform destroy -auto-approve
   ```
