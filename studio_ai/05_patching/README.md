# 05 — Oracle Patching

> Procedure per l'applicazione di patch Oracle in ambiente RAC Enterprise.
> Include Golden Images (OHCTL) e Release Update.

---

## Panoramica

Patching is a **critical and recurring** activity for every Enterprise DBA. Oracle releases quarterly Release Updates (RUs) that contain security and stability fixes.

In un ambiente RAC, il patching segue un ordine preciso:
1. **Grid Infrastructure** → `opatchauto` (as root)
2. **Database Home** → `opatchauto` + `opatch` per OJVM
3. **datapatch** → Applica le patch al dizionario dati

---

## File Contenuti

### [golden_images_ohctl.md](./golden_images_ohctl.md)
`OHCTL` script for managing Golden Images: creation, removal, and management of Oracle Home via pre-patched images.

### [patching_grid_12c.md](./patching_grid_12c.md)
Real example of Grid Infrastructure 12.1.0.2 patching (patch p28813884).

### [support_notes.md](./support_notes.md)
Note di supporto Oracle per i casi comuni di patching.

---

## 🔗 Collegamento
See also: [GUIDE_PHASE2_GRID_AND_RAC.md](../../GUIDE_PHASE2_GRID_AND_RAC.md) - patching section.
