# 📚 Studio AI — Raccolta Operativa DBA Oracle

> Questa directory contiene procedure operative, script SQL, e guide tecniche basate su esperienza DBA Enterprise.
> Ogni sezione è organizzata per argomento e contiene un README dedicato che spiega il contesto e l'uso di ciascuno script.

---

## 📂 Struttura delle Cartelle

| # | Cartella | Contenuto | Livello |
|---|---|---|---|
| 01 | [ASM & Storage](./01_asm_storage/) | Aggiunta dischi ASM (ASMLib + AFD), deallocazione, migrazione storage | ⭐⭐⭐ Fondamentale |
| 02 | [Data Guard](./02_dataguard/) | Configurazione DG, Active DG, Service Read-Only, verifica GAP, DR recovery | ⭐⭐⭐ Fondamentale |
| 03 | [Monitoring Scripts](./03_monitoring_scripts/) | 48 script SQL per monitoraggio: sessioni, lock, CPU, I/O, ASM, ASH, AWR, Redo | ⭐⭐⭐ Uso Quotidiano |
| 04 | [User Management](./04_user_management/) | Creazione utenti (nominali, DB, applicativi), profili, password, Vault | ⭐⭐ Importante |
| 05 | [Patching](./05_patching/) | Procedure patching Oracle, Golden Images (OHCTL), Release Update | ⭐⭐ Importante |
| 06 | [Backup & Recovery](./06_backup_recovery/) | Flashback, Restore Point, RMAN checks | ⭐⭐ Importante |
| 07 | [Performance & Tuning](./07_performance_tuning/) | SQL Plan Management (SPM), AWR analysis, statistiche | ⭐⭐⭐ Uso Quotidiano |
| 08 | [TDE & Security](./08_tde_security/) | Transparent Data Encryption, Oracle Vault | ⭐⭐ Importante |
| 09 | [Compression (HCC)](./09_compression/) | DBMS_REDEFINITION online, compressione near-zero downtime | ⭐ Avanzato |
| 10 | [Partition Manager](./10_partition_manager/) | Package gestione partizioni automatiche | ⭐ Avanzato |
| 11 | [SQL Templates](./11_sql_templates/) | Template DDL/DML standard: CREATE TABLE, INDEX, VIEW, TRIGGER, PACKAGE, ecc. | ⭐⭐ Importante |
| 12 | [Utilities](./12_utilities/) | TEMP/UNDO monitor, MView refresh, truncate procedure, profili UNIX | ⭐ Supporto |

---

## 🎯 Come Usare Questa Raccolta

1. **Studia**: Leggi il README di ogni cartella per capire il *perché* di ogni procedura.
2. **Pratica**: Replica gli script nel tuo laboratorio RAC (adattando nomi di host/DB).
3. **Confronta**: Ogni procedura qui riflette pratiche Enterprise reali — confrontala con le guide teoriche nel progetto principale.

---

## 🔗 Collegamento al Progetto Principale

Questa raccolta arricchisce il progetto Oracle RAC principale:
- Le procedure ASM integrano la [Guida Aggiunta Dischi](../GUIDA_AGGIUNTA_DISCHI_ASM.md)
- Gli script di monitoring completano la [Guida Comandi DBA](../GUIDA_COMANDI_DBA.md)
- Le procedure DataGuard si collegano alla [Fase 4](../GUIDA_FASE4_DATAGUARD_DGMGRL.md)
