# 03. Infra Lab
Questa directory documenta il setup a basso livello dell'infrastruttura sottostante al database Oracle.

## Struttura
- **`01_proxmox_hardware/`**: Setup di Hypervisor (es. Proxmox) e configurazione hardware simulata per il lab.
- **`02_oracle_installation_asm/`**: Guide passo-passo del percorso "Fase 0 → Fase 8", includendo la preparazione dell'OS, il setup della rete (DNS/Vagrant), e l'installazione di Grid Infrastructure (ASM).
- **`03_cloud_oci/`**: Guide all'estensione del laboratorio on-premise verso il Cloud, usando Oracle Cloud Infrastructure (OCI ARM Free Tier, connettività VPN, ecc.).
- **`04_containerization/`**: Guida Podman/Docker per il percorso opzionale Oracle Database 26ai Free.

## Implementazioni Alla Radice

- [Vagrant RAC + Data Guard](../../vagrant_rac_dataguard/README.md): provisioning del lab VirtualBox.
- [Terraform OCI](../../terraform/oci_base_infrastructure/README.md): infrastruttura cloud gestita come codice.
