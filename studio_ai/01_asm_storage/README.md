# 01 — ASM & Storage Management

> Operating procedures for managing Oracle ASM storage in an Enterprise RAC environment.
> Includes both **ASMLib** and **AFD** (ASM Filter Driver) methods.

---

## Panoramica

In an Oracle RAC Enterprise environment, storage is managed by Automatic Storage Management (ASM).
The most frequent operations are:
- **Add new LUNs** to expand Disk Groups (e.g. `+DATA`, `+FRA`)
- **Disk deallocation** during storage migrations (e.g. from VMAX to Pure Storage)
- **Storage migration** between different array types

---

## Files Contained in This Section

### 📋 Procedure Operative

#### [asm_disk_add_procedure.md](./asm_disk_add_procedure.md)
Complete step-by-step procedure to add a disk to an existing Disk Group.
Covers: SCSI rescan, partitioning, ASMLib/AFD disk creation, ADD DISK SQL, rebalance verification.

#### [complete_add_lun_guide.md](./complete_add_lun_guide.md)
Complete unified guide for adding LUNs, with parallel ASMLib and AFD procedures.
Includes: LUN scan, partitioning with `parted`, ASMLib/AFD labels, ADD DISK, and FRA notes.

#### [asm_disk_deallocation.md](./asm_disk_deallocation.md)
Procedure for removing disks from an ASM Disk Group (e.g. during array migration).

#### [production_afd_add_example.md](./production_afd_add_example.md)
Real example of adding AFD disks in production (P1NDREHP database).

---

## 🔗 Link
See also the training guide: [GUIDE_ADD_ASM_DISK.md](../../GUIDE_ADD_ASM_DISK.md)
