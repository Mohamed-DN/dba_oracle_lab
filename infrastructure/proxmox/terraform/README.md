# Terraform Proxmox Baseline (Fase 2)

Questa cartella fornisce una baseline IaC per Proxmox con:

- naming coerente per ambiente,
- provisioning di 3 VM con un solo comando,
- export automatico metadati host in JSON per Ansible/AWX.

## File principali

- `providers.tf`: provider Proxmox + local file output.
- `variables.tf`: variabili standard e naming conventions.
- `main.tf`: provisioning VM e generazione `terraform_metadata.json`.
- `outputs.tf`: output strutturati per pipeline downstream.
- `terraform.tfvars.example`: esempio configurazione lab.

## Naming convention

`<environment>-<vm_key>` (esempio: `lab-vm01`, `lab-vm02`, `lab-vm03`).

## Uso rapido

```bash
cd infrastructure/proxmox/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

> Nota sicurezza: `pm_tls_insecure` ha default `false`; usare `true` solo in lab con certificati non trusted.

Destroy completo:

```bash
terraform destroy
```

## Export metadati per inventory dinamico

Dopo `terraform apply` viene generato:

- `terraform_metadata.json` (host, IP, ruolo, timestamp)

Questo file è consumabile da job AWX o pipeline Ansible per creare inventory dinamico.

## Integrazione minima AWX

1. Job Terraform produce `terraform_metadata.json`.
2. Inventory source AWX importa il JSON.
3. Job template Ansible esegue bootstrap host per gruppi/ruoli.
