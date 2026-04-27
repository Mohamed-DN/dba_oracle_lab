# 🖥️ Track Proxmox Moderno — Indice Area

> Pipeline moderna per passare da lab VM-centric a piattaforma service-centric: Proxmox → Terraform → Ansible/AWX → Oracle Silent → K3s/RKE2.

| Documento | Descrizione |
| --- | --- |
| [GUIDA_TRACK_PROXMOX_PRODUCTION_END_TO_END.md](./GUIDA_TRACK_PROXMOX_PRODUCTION_END_TO_END.md) | Guida completa production-grade del track (tutte le fasi) |
| [PHASE_1_PROXMOX_FOUNDATION.md](./PHASE_1_PROXMOX_FOUNDATION.md) | Fase 1 — Installazione e configurazione Proxmox VE |
| [PHASE_3_ANSIBLE_AWX.md](./PHASE_3_ANSIBLE_AWX.md) | Fase 3 — Ansible + AWX control plane |
| [PHASE_4_ORACLE_SILENT_AUTOMATION.md](./PHASE_4_ORACLE_SILENT_AUTOMATION.md) | Fase 4 — Oracle silent install e automazione |
| [PHASE_5_K8S_CAPSTONE.md](./PHASE_5_K8S_CAPSTONE.md) | Fase 5 — K3s/RKE2 capstone project |
| [ADOPTION_ROADMAP.md](./ADOPTION_ROADMAP.md) | Roadmap di adozione progressiva del track |

> 📌 **Fase 2 — Terraform Proxmox** è gestita in [`infrastructure/proxmox/terraform/`](../../infrastructure/proxmox/terraform/README.md).

<details>
  <summary>📁 Albero dei file</summary>

```
docs/15_proxmox_track/
├── GUIDA_TRACK_PROXMOX_PRODUCTION_END_TO_END.md
├── PHASE_1_PROXMOX_FOUNDATION.md
├── PHASE_3_ANSIBLE_AWX.md
├── PHASE_4_ORACLE_SILENT_AUTOMATION.md
├── PHASE_5_K8S_CAPSTONE.md
└── ADOPTION_ROADMAP.md

infrastructure/proxmox/terraform/   ← Fase 2 Terraform (percorso: ../../infrastructure/proxmox/terraform/)
```

</details>

---

Indice totale documentazione: [../README.md](../README.md)

