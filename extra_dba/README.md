# Extra DBA - Post-Laboratory Activity Index

> Curated index of advanced DBA activities already present in the repository.
> It does not replace the basic path Phase 0 -> Phase 8: it extends it after the lab is stable.

## Main documents in the folder

| Documento | Quando usarlo | File |
|---|---|---|
| **Full catalog of DBA activities** | When you want to see the entire scope of Oracle DBA work, organized by operational domain | [GUIDE_DBA_ACTIVITY_CATALOG.md](./GUIDE_DBA_ACTIVITY_CATALOG.md) |
| **DBA Operational Checklist** | Quando vuoi una sequenza pratica giornaliera, settimanale, mensile, trimestrale e pre/post change | [GUIDE_DBA_ACTIVITY_CHECKLIST.md](./GUIDE_DBA_ACTIVITY_CHECKLIST.md) |
| **Oracle DBA Question Guide** | When you want to review technical questions, clear answers, realistic scenarios and typical follow-ups | [GUIDE_ORACLE_DBA_QUESTIONS.md](./GUIDE_ORACLE_DBA_QUESTIONS.md) |

## How to use this area

- Complete the basic lab first and keep the Data Guard in `MaxPerformance`.
- Use this area for day-2 operations, hardening, advanced exercises and real DBA scenarios.
- `studio_ai` remains separate: contains scripts and operational notes; here you will only find the guided tour of the extra activities.

## 1. Data Guard avanzato

| Activity | Quando usarla | Guide |
|---|---|---|
| **Protection Mode / switch modalita** | Immediately after Phase 4, if you want to understand when to use `MaxPerformance`, `MaxAvailability`, `MaxProtection` or `FASTSYNC` | [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md) |
| **Switchover** | When you want to test planned role transition without data loss | [GUIDE_FULL_SWITCHOVER.md](../GUIDE_FULL_SWITCHOVER.md) |
| **Failover + Reinstate** | Quando vuoi simulare perdita del primary e recupero controllato | [GUIDE_FAILOVER_AND_REINSTATE.md](../GUIDE_FAILOVER_AND_REINSTATE.md) |
| **Active Data Guard** | When you want to keep standby in `READ ONLY WITH APPLY`, also for GoldenGate | [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md) |
| **PDB propagation + services** | When you want to create a PDB on the primary, check its appearance on the standby and publish correct RAC services | [GUIDE_PDB_DATAGUARD_SERVICES.md](./GUIDE_PDB_DATAGUARD_SERVICES.md) |

### Practical note on changing modes

- `MaxPerformance`: default del lab, minima latenza, redo in `ASYNC`.
- `MaxAvailability`: to be used if you want zero data loss on the first fault and the network holds `SYNC` or `FASTSYNC`.
- `MaxProtection`: to be used only if you accept the maximum impact on the availability of the primary.

The technical guide remains in [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md), section `4.4 Configurazione Protection Mode`.

## 2. RAC operations

| Activity | Quando usarla | Guide |
|---|---|---|
| **Listeners and Services** | When you need to understand SCAN, static listeners, RAC services and troubleshooting `ORA-12514` | [GUIDE_LISTENER_SERVICES_DBA.md](../GUIDE_LISTENER_SERVICES_DBA.md) |
| **PDB services role-based** | When you want to publish PDB services on the primary and, with Active Data Guard, on the read-only standby | [GUIDE_PDB_DATAGUARD_SERVICES.md](./GUIDE_PDB_DATAGUARD_SERVICES.md) |
| **Patching RAC** | When you need to apply RU/OJVM or clean up home after patching | [GUIDE_RAC_PATCHING.md](../GUIDE_RAC_PATCHING.md) |
| **Upgrade RU workflow** | Quando vuoi simulare upgrade RU piu strutturati e rollback | [GUIDE_RAC_RU_UPGRADE.md](../GUIDE_RAC_RU_UPGRADE.md) |

## 3. Backup e recovery

| Activity | Quando usarla | Guide |
|---|---|---|
| **RMAN lab base** | Whenever you want the lab operational strategy with backup, cron and guided restore | [GUIDE_PHASE7_RMAN_BACKUP.md](../GUIDE_PHASE7_RMAN_BACKUP.md) |
| **RMAN complete 19c** | When you want a more extensive runbook with recovery, catalog, validate and Data Guard cases | [GUIDE_RMAN_COMPLETE_19C.md](../GUIDE_RMAN_COMPLETE_19C.md) |

## 4. Monitoring e day-2

| Activity | Quando usarla | Guide |
|---|---|---|
| **Enterprise Manager 13.5** | Quando vuoi monitorare OMS, agent, target RAC/Data Guard e job operativi | [GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md](../GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md) |
| **Essential DBA Activities** | Quando vuoi runbook su AWR/ADDM/ASH, Data Pump, security e patching | [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md) |
| **MAA best practices** | When you want to compare the lab with Oracle HA/DR recommendations | [GUIDE_MAA_BEST_PRACTICES.md](../GUIDE_MAA_BEST_PRACTICES.md) |
| **Oracle DBA Questions** | Quando vuoi consolidare architettura, recovery, Data Guard, RAC, ASM, performance e troubleshooting | [GUIDE_ORACLE_DBA_QUESTIONS.md](./GUIDE_ORACLE_DBA_QUESTIONS.md) |

## 5. Security e encryption

| Activity | Quando usarla | Guide |
|---|---|---|
| **TDE / keystore / wallet** | Quando vuoi configurare Transparent Data Encryption, capire il ruolo del wallet e ricordarti il backup del keystore | [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md) |
| **Toolkit TDE e audit** | Quando vuoi script pratici per audit trail, controlli sicurezza e note operative riusabili | [studio_ai/08_tde_security](../studio_ai/08_tde_security/) |

### Nota pratica su TDE

- in the repo the most concrete part today is in [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md), section `5.3 Transparent Data Encryption (TDE)`;
- the critical point is not just creating the master key, but managing `keystore`, backup wallets and administrative users (`SYSKM`) well;
- `TDE` protegge i dati a riposo, non sostituisce backup, auditing o network encryption.

## Recommended post-lab path

1. Protection Mode
2. Switchover
3. Failover + Reinstate
4. Full RMAN
5. TDE / wallet / security review
6. Enterprise Manager
7. MAA review finale

