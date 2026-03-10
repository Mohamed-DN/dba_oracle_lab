# 01 — ASM & Storage Management

> Procedure operative per la gestione dello storage Oracle ASM in ambiente Enterprise RAC.
> Include sia il metodo **ASMLib** che **AFD** (ASM Filter Driver).

---

## Panoramica

In un ambiente Oracle RAC Enterprise, lo storage è gestito da ASM (Automatic Storage Management).
Le operazioni più frequenti sono:
- **Aggiunta di nuove LUN** per espandere i Disk Group (es. `+DATA`, `+FRA`)
- **Deallocazione di dischi** durante migrazioni storage (es. da VMAX a Pure Storage)
- **Migrazione dello storage** tra diversi tipi di array

---

## File Contenuti in Questa Sezione

### 📋 Procedure Operative

#### [procedura_aggiunta_dischi_asm.md](./procedura_aggiunta_dischi_asm.md)
Procedura completa passo-passo per aggiungere un disco a un Disk Group esistente.
Copre: SCSI rescan, partizionamento, creazione disco ASMLib/AFD, ADD DISK SQL, verifica rebalance.

#### [guida_completa_add_lun.md](./guida_completa_add_lun.md)
Guida completa unificata per l'aggiunta di LUN, con procedure parallele ASMLib e AFD.
Include: LUN scan, partizionamento con `parted`, labels ASMLib/AFD, ADD DISK, e note sulla FRA.

#### [deallocazione_dischi_asm.md](./deallocazione_dischi_asm.md)
Procedura per rimuovere dischi da un Disk Group ASM (es. durante migrazione array).

#### [esempio_aggiunta_afd_produzione.md](./esempio_aggiunta_afd_produzione.md)
Esempio reale di aggiunta dischi AFD in produzione (database P1NDREHP).

---

## 🔗 Collegamento
Vedi anche la guida formativa: [GUIDE_ADD_ASM_DISK.md](../../GUIDE_ADD_ASM_DISK.md)
