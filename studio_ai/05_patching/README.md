# 05 — Oracle Patching

> Procedure per l'applicazione di patch Oracle in ambiente RAC Enterprise.
> Include Golden Images (OHCTL) e Release Update.

---

## Panoramica

Il patching è un'attività **critica e ricorrente** per ogni DBA Enterprise. Oracle rilascia Release Update (RU) trimestrali che contengono fix di sicurezza e stabilità.

In un ambiente RAC, il patching segue un ordine preciso:
1. **Grid Infrastructure** → `opatchauto` (come root)
2. **Database Home** → `opatchauto` + `opatch` per OJVM
3. **datapatch** → Applica le patch al dizionario dati

---

## File Contenuti

### [golden_images_ohctl.md](./golden_images_ohctl.md)
Script `OHCTL` per la gestione di Golden Images: creazione, rimozione, e gestione di Oracle Home tramite immagini pre-patchate.

### [patching_grid_12c.md](./patching_grid_12c.md)
Esempio reale di patching Grid Infrastructure 12.1.0.2 (patch p28813884).

### [support_notes.md](./support_notes.md)
Note di supporto Oracle per i casi comuni di patching.

---

## 🔗 Collegamento
Vedi anche: [GUIDE_PHASE2_GRID_AND_RAC.md — Sezione Patching](../../GUIDE_PHASE2_GRID_AND_RAC.md)
