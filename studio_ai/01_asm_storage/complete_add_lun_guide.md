# Complete guide add LUN (ASMLib + AFD)

This action note unifies the LUN addition flow in the RAC environment.

Recommended steps:

1. Rescan disks on all nodes.
2. Identify new device and verify WWN/LUN.
3. Configure ASMLib or AFD according to the cluster standard.
4. Add disk to diskgroup with `ALTER DISKGROUP ... ADD DISK`.
5. Monitor rebalance and free space.

Detailed procedures already present in this folder:

- [asm_disk_add_procedure.md](./asm_disk_add_procedure.md)
- [asm_disk_deallocation.md](./asm_disk_deallocation.md)

Extended training reference:

- [GUIDE_ADD_ASM_DISK.md](../../GUIDE_ADD_ASM_DISK.md)
