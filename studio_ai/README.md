# 📚 AI Studio — Oracle DBA Operational Collection

> This directory contains operational procedures, SQL scripts, and technical guides based on DBA Enterprise experience.
> Each section is organized by topic and contains a dedicated README that explains the context and use of each script.

---

## 📂 Folder Structure

| # |Folder|Content| Livello |
|---|---|---|---|
| 01 | [ASM & Storage](./01_asm_storage/) | Added ASM disks (ASMLib + AFD), deallocation, storage migration | ⭐⭐⭐ Fondamentale |
| 02 | [Data Guard](./02_dataguard/) | DG configuration, Active DG, Service Read-Only, GAP verification, DR recovery | ⭐⭐⭐ Fondamentale |
| 03 | [Monitoring Scripts](./03_monitoring_scripts/) |48 SQL scripts for monitoring: sessions, locks, CPU, I/O, ASM, ASH, AWR, Redo|⭐⭐⭐ Daily use|
| 04 | [User Management](./04_user_management/) | Creation of users (nominal, DB, applications), profiles, passwords, Vault | ⭐⭐ Importante |
| 05 | [Patching](./05_patching/) | Procedure patching Oracle, Golden Images (OHCTL), Release Update | ⭐⭐ Importante |
| 06 | [Backup & Recovery](./06_backup_recovery/) | Flashback, Restore Point, RMAN checks | ⭐⭐ Importante |
| 07 | [Performance & Tuning](./07_performance_tuning/) | SQL Plan Management (SPM), AWR analysis, statistiche |⭐⭐⭐ Daily use|
| 08 | [TDE & Security](./08_tde_security/) | Transparent Data Encryption, Oracle Vault | ⭐⭐ Importante |
| 09 |[Compression (HCC)](./09_compression/)| DBMS_REDEFINITIONonline, near-zero downtime compression|⭐ Advanced|
| 10 | [Partition Manager](./10_partition_manager/) | Automatic partition management package |⭐ Advanced|
| 11 | [SQL Templates](./11_sql_templates/) | Template DDL/DML standard: CREATE TABLE, INDEX, VIEW, TRIGGER, PACKAGE, ecc. | ⭐⭐ Importante |
| 12 | [Utilities](./12_utilities/) | TEMP/UNDO monitor, MView refresh, truncate procedure, profili UNIX |⭐ Support|

---

## Top 20 Script Catalog

To have a sorted view of the scripts (with Top 20 by category where possible), use:

- [TOP20_SCRIPT_CATALOG_BY_CATEGORY.md](./TOP20_SCRIPT_CATALOG_BY_CATEGORY.md)

The catalog includes:
- volume script per ciascuna categoria
- operational grouping (monitoring, tuning, backup, security, etc.)
- Top recommended scripts for study and daily use

---

## 🎯 How to Use This Collection

1. **Study**: Read the README of each folder to understand the *why* of each procedure.
2. **Practice**: Replicate the scripts in your RAC lab (adapting host/DB names).
3. **Compare**: Each procedure here reflects real Enterprise practices — compare it to the theoretical guides in the main project.

---

## 🔗 Link to Main Project

This collection enriches the main Oracle RAC project:
- The ASM procedures integrate the [Adding Disks Guide](../GUIDE_ADD_ASM_DISK.md)
- The monitoring scripts complete the [DBA Command Guide](../GUIDE_DBA_COMMANDS.md)
- DataGuard procedures link to [Phase 4](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md)
