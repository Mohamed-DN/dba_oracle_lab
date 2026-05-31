# 🏛️ Core Lab 0→8 — Indice Area

> Percorso principale del repository per costruire il lab Oracle RAC + Data Guard.

## Contratto del lab

- `RACDB`: CDB RAC primary con istanze `RACDB1` e `RACDB2`.
- `RACDBPDB`: PDB applicativa creata da DBCA nella Fase 2.
- `RACDB_STBY`: physical standby RAC del CDB primary.
- `observer1`: VM FSFO manuale; `observer2` è il backup opzionale.
- Oracle Linux 7.9: track legacy riproducibile.
- Oracle Linux 8: track raccomandato per nuove VM tramite
  [appendice OL8 e ASMLib v3](./GUIDA_PERCORSO_ORACLE_LINUX8_ASMLIB_V3.md).

Il percorso contiene dieci checkpoint: `0`, `1`, `2`, `3`, `4`, `4B`, `5`,
`6`, `7`, `8`.

## Fasi principali

| Fase | Guida | Output |
| --- | --- | --- |
| 0 | [Setup Macchine](./GUIDA_FASE0_SETUP_MACCHINE.md) | VM, DNS, dischi ASM |
| 1 | [Preparazione OS](./GUIDA_FASE1_PREPARAZIONE_OS.md) | OS baseline + rete |
| 2 | [Grid + RAC](./GUIDA_FASE2_GRID_E_RAC.md) | Cluster RAC, CDB `RACDB` e PDB `RACDBPDB` |
| 3 | [RAC Standby](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE3_RAC_STANDBY.md) | Standby cluster operativo |
| 4 | [Data Guard Broker](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | Broker e role transitions |
| 4B | [Observer FSFO](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4B_FSFO_OBSERVER.md) | Observer dedicato e failover automatico |
| 5 | [RMAN Backup](../../02_core_dba/02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | Backup e restore test |
| 6 | [Enterprise Manager](../../02_core_dba/06_monitoring_systems/GUIDA_FASE6_ENTERPRISE_MANAGER.md) | Monitoring OEM |
| 7 | [GoldenGate](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md) | MA TLS: Extract, Distribution Path e Replicat |
| 8 | [Test Verifica](./GUIDA_FASE8_TEST_VERIFICA.md) | Validazione finale |

## Checklist e percorsi alternativi

- [Obiettivi e checklist Fasi 0→8](./OBIETTIVI_E_CHECKLIST_FASI_0_8.md)
- [Percorso Oracle Linux 8 e ASMLib v3](./GUIDA_PERCORSO_ORACLE_LINUX8_ASMLIB_V3.md)
- [Percorso Lite Single Node](./GUIDA_PERCORSO_LITE_SINGLE_NODE.md)
- [Setup SSH Keys RAC](./GUIDA_SSH_KEYS_RAC.md)

---

Indice totale documentazione: [../README.md](../README.md)
