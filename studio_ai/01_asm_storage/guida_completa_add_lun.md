# Guida completa add LUN (ASMLib + AFD)

Questa nota operativa unifica il flusso di aggiunta LUN in ambiente RAC.

Passi consigliati:

1. Rescan dischi su tutti i nodi.
2. Identifica nuovo device e verifica WWN/LUN.
3. Configura ASMLib o AFD in base allo standard del cluster.
4. Aggiungi disco al diskgroup con `ALTER DISKGROUP ... ADD DISK`.
5. Monitora rebalance e spazio libero.

Procedure dettagliate gia presenti in questa cartella:

- [procedura_aggiunta_dischi_asm.md](./procedura_aggiunta_dischi_asm.md)
- [deallocazione_dischi_asm.md](./deallocazione_dischi_asm.md)

Riferimento formativo esteso:

- [GUIDA_AGGIUNTA_DISCHI_ASM.md](../../GUIDA_AGGIUNTA_DISCHI_ASM.md)
