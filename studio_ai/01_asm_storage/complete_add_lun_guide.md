# Complete guide add LUN (ASMLib + AFD)

This action note unifies the LUN addition flow in the RAC environment.

Passi consigliati:

1. Rescan disks on all nodes.
2. Identify new device and verify WWN/LUN.
3. Configura ASMLib o AFD in base allo standard del cluster.
4. Add disk to diskgroup with `ALTER DISKGROUP ... ADD DISK`.
5. Monitora rebalance e spazio libero.

Procedure dettagliate gia presenti in questa cartella:

- [asm_disk_add_procedure.md](./asm_disk_add_procedure.md)
- [asm_disk_deallocation.md](./asm_disk_deallocation.md)

Riferimento formativo esteso:

- [GUIDE_ADD_ASM_DISK.md](../../GUIDE_ADD_ASM_DISK.md)
