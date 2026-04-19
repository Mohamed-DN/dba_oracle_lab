# Fase 3 - Ansible + AWX Control Plane

## Obiettivo

Usare Terraform per creare VM e AWX/Ansible per configurarle in modo idempotente.

## Standard operativo

- Dynamic inventory da metadati Terraform (`terraform_metadata.json`).
- Role baseline OS (utenti, hardening, pacchetti base, logging, time sync).
- Job templates AWX separati per:
  - bootstrap host
  - middleware/platform
  - Oracle prerequisites

## Architettura AWX

- Deploy AWX su piccola istanza K3s dedicata (isolata dal cluster applicativo finale).
- Project AWX collegato a questo repository Git.
- Credentials AWX basate su SSH key e vault/secret backend.
- RBAC minimo: admin platform, operator, auditor.

## Pipeline Terraform -> AWX

1. Terraform apply crea VM + esporta metadati.
2. AWX inventory source importa metadati dinamici.
3. Job template bootstrap configura OS.
4. Job template middleware/Oracle esegue provisioning applicativo.

## Acceptance checklist

- [ ] AWX legge correttamente host e gruppi dalle VM terraformate.
- [ ] Job bootstrap idempotente su 3 esecuzioni consecutive.
- [ ] Evidenze run AWX archiviate in artifact/log.
