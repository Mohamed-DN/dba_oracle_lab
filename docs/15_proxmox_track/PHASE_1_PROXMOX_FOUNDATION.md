# Fase 1 - Proxmox Foundation

## Obiettivo

Installare Proxmox VE bare metal e standardizzare networking/storage prima di ogni automazione.

## Scope minimo

- Installazione Proxmox VE su host dedicato.
- Linux bridge standard (`vmbr0` management, bridge workload separati se richiesto).
- Storage model esplicito (local-lvm, NFS, Ceph o ZFS) con criteri capacità/snapshot.
- Chiarezza operativa su differenze KVM vs LXC.

## Standard template Cloud-Init (obbligatorio)

Template unico Debian o Ubuntu da riusare in tutte le fasi:

- `qemu-guest-agent` preinstallato.
- SSH key-based access.
- Utente amministrativo non-root con sudo.
- `cloud-init` attivo con datasource Proxmox.
- Naming template: `tmpl-debian12-cloudinit-v1` oppure `tmpl-ubuntu2204-cloudinit-v1`.

## Acceptance checklist

- [ ] Host Proxmox operativo e raggiungibile da rete management.
- [ ] Bridge e subnet documentati con finalità esplicita.
- [ ] Storage pool con policy snapshot/retention definita.
- [ ] Almeno 1 template cloud-init validato con clone bootabile.
