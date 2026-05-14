# Terraform: Infrastruttura OCI per Oracle 26ai

Questa directory contiene i manifesti Terraform per creare l'infrastruttura di base su **Oracle Cloud Infrastructure (OCI)** necessaria per il deploy di Oracle 26ai tramite i nostri playbook Ansible.

## Risorse Generate
- **VCN (Virtual Cloud Network)** (`10.0.0.0/16`) e Internet Gateway.
- **Subnet Pubblica** (`10.0.1.0/24`) con Route Table associata.
- **Security List** con apertura delle porte 22 (SSH) e 1521 (Oracle Listener).
- **Compute Instance** ARM "Always Free" (VM.Standard.A1.Flex, 4 OCPU, 24GB RAM) con Oracle Linux 8.

## Prerequisiti
1. Installare [Terraform](https://www.terraform.io/downloads.html).
2. Generare le chiavi API su OCI (Profilo Utente -> API Keys).
3. Creare un file `terraform.tfvars` (ignorato da git) in questa directory con i seguenti valori:
   ```hcl
   tenancy_ocid     = "ocid1.tenancy.oc1..xxxx"
   user_ocid        = "ocid1.user.oc1..xxxx"
   fingerprint      = "xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx"
   private_key_path = "~/.oci/oci_api_key.pem"
   compartment_ocid = "ocid1.compartment.oc1..xxxx"
   ssh_public_key   = "ssh-rsa AAAA..."
   region           = "eu-frankfurt-1"
   ```

## Utilizzo
1. Inizializzare il provider:
   ```bash
   terraform init
   ```
2. Verificare il piano di esecuzione:
   ```bash
   terraform plan
   ```
3. Applicare la configurazione:
   ```bash
   terraform apply
   ```
Al termine, Terraform restituirà l'indirizzo IP pubblico dell'istanza (`oracle_26ai_public_ip`), che potrai inserire nell'inventario di Ansible per procedere con l'installazione del database.
