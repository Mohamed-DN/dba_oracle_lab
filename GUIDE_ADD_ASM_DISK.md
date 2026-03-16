# Guide: Creating and Adding ASM Disks (Training Purpose)

This guide explains the operating procedure for managing disks in Oracle ASM (Automatic Storage Management). 

> [!IMPORTANT]
> **Metodo ASMLib vs Udev**
> Nel nostro laboratorio e nell'architettura di riferimento usiamo **ASMLib** (`oracleasm`). 
> There is also another widely used method based on **udev rules** (configuring `/etc/udev/rules.d/` e `scsi_id`). Both methods are valid, but throughout our guide we will rely exclusively on **ASMLib** for simplicity and operational consistency.

---

## 1. Why add or create ASM disks?

In an Enterprise environment, space management is dynamic and fundamental:
*   **Capacity Expansion**: When the free space of a Disk Group (e.g. `+DATA`) drops below an alert threshold (usually 15-20%), you need to add new physical disks. ASM allows this hot operation, **without any downtime**.
*   **Performance Balancing (Rebalance)**: ASM natively distributes data across all disks in a Disk Group (*striping* operation). When you add a new disk, ASM starts an automatic *Rebalance* process that moves blocks of data from the old disks to the new one. This distributes the I/O load and improves performance.
*   **Separazione Logica**: In scenari avanzati, si creano Disk Group dedicati (es. `+RECO` per i backup o FRA) per isolare l'I/O critico.

---

## 2. High Level Steps (Fasi di Alto Livello)

Whether you are creating a Disk Group from scratch or expanding one, these are the main steps:

1.  **Backend** - *Provision new disks from Storage*: Provision new physical or virtual disks from storage (e.g. VMware, VirtualBox, SAN).
2.  **root** - *Create Disk Partitions using `fdisk`*: Crea una partizione primaria per riservare il disco ed evitare sovrascritture involontarie.
3.  **root** - *Mark Disk as ASM Disks using `oracleasm createdisk`*: Register the disk in the ASMLib driver so Oracle can recognize it.
4.  **grid** - *Create new disk group using `CREATE DISKGROUP` command*: Crea (o espandi usando `ALTER`) il Disk Group dalla riga di comando o grafica ASMCA.

---

## 3. Scopo Formativo: Creare un Disk Group da zero

Below is a pure SQL example to create a new Disk Group, starting from the disks marked by ASMLib. Let's assume that the commands `oracleasm createdisk DATA` e `RECO` have already been launched.

```sql
# Come utente grid (proprietario del software Grid Infrastructure)
su - grid

-- Connettiti all'istanza ASM locale (+ASM1)
sqlplus / as sysasm

-- Crea disk group DATA (Usiamo il path fisico effettivo del driver oracleasm)
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK '/dev/oracleasm/disks/DATA'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

-- Crea disk group RECO
CREATE DISKGROUP RECO EXTERNAL REDUNDANCY
  DISK '/dev/oracleasm/disks/RECO'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

-- Verifica i Disk Group appena creati
SELECT name, state, type, total_mb, free_mb FROM v$asm_diskgroup;

EXIT;
```

---

## 4. Practical Example: Adding a Disk for Expansion

If instead you want to expand an existing Disk Group (e.g. we already have `+DATA` and we want to give it more space), here are the complete steps starting from the OS:

### System Administrator phase
1. **Backend**: A new disk (e.g. 10 GB) is assigned to the virtual machine. It becomes visible as `/dev/sdf`.
2. **rac1 (root)**: Partizionamento:
   ```bash
   fdisk /dev/sdf
   # Premi n, p, 1, invio, invio, w
   ```
3. **rac1 (root)**: Marcatura ASMLib:
   ```bash
   oracleasm createdisk DATA_EXP1 /dev/sdf1
   ```
4. **rac2 (root)**: Discovering the new disk on the other cluster location:
   ```bash
   oracleasm scandisks
   oracleasm listdisks
   ```

### DBA phase
1. **rac1 (grid)**: Adding disk to Disk Group via SQL:
   ```sql
   su - grid
   sqlplus / as sysasm

   -- Aggiungi il disco al Disk Group DATA con priorità di rebalance 4 (valore medio-alto)
   ALTER DISKGROUP DATA ADD DISK 'ORCL:DATA_EXP1' REBALANCE POWER 4;
   
   -- Monitora l'avanzamento dell'operazione asincrona in background
   SELECT * FROM v$asm_operation;
   
   -- Verifica la nuova dimensione al termine dell'operazione
   SELECT name, total_mb, free_mb FROM v$asm_diskgroup WHERE name = 'DATA';
   ```

> [!NOTE]
> Il nome stringa `'ORCL:DATA_EXP1'` is the standard prefix that ASMLib uses to present its disks to the se database `asm_diskstring` is configured as `'ORCL:*'`, which is the default.

---

## 📚 Approfondisci

Per procedure operative reali da ambiente Enterprise (con multipath, VMAX, Pure Storage), consulta:
- [Procedure for Adding ASM Disks (from Production)](./studio_ai/01_asm_storage/asm_disk_add_procedure.md)
- [ASM Disk Deallocation](./studio_ai/01_asm_storage/asm_disk_deallocation.md)

*Return to the main guide for [Storage and Grid Preparation] activities(./GUIDE_PHASE2_GRID_AND_RAC.md).*
