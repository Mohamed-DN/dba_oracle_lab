# GUIDE: DBA Operational Checklist

> Practical checklist for transforming the DBA activity catalog into an executable routine.
> Use it in the lab as an operational runbook, then adapt it to production with real owners, times and SLAs.

## 1. Checklist giornaliera

### Apertura giornata

- check database / instances / services status
- check listener and cluster resources
- controlla alert log e ultimi errori `ORA-`
- controlla ultimi backup RMAN
- controlla `SHOW CONFIGURATION` Data Guard e lag
- controlla tablespace critici, FRA e ASM disk group
- controlla incidenti o target down in Enterprise Manager

Evidenza minima:
- EM screenshot or status output
- note su anomalie aperte
- owner assegnato per ogni issue

## 2. Checklist giornaliera su ticket o anomalie

- identifies whether the problem is availability, performance, storage, security or network
- collect evidence before changing parameters
- save query, output and event time
- only make one change at a time whenever possible
- immediately check the effect of the correction
- aggiorna il runbook se il caso non era documentato

## 3. Checklist settimanale

- genera o analizza AWR / ADDM
- verify `RESTORE VALIDATE`
- controlla crescita storage e trend tablespace
- rivedi job scheduler falliti e catene lunghe
- Check expired/blocked users and exceptional grants
- Check GG lag / processes if GoldenGate is active
- controlla invalid objects e warning applicativi noti

## 4. Checklist mensile

- review patch level, OPatch version e backlog RU/OJVM
- review capacity planning with growth last month
- review auditing, privilegi potenti e directory object
- controlled maintenance tests on services/listeners
- review soglie e notifiche Enterprise Manager
- review operational documentation and rollback plan

## 5. Checklist trimestrale

- esegui switchover drill
- esegui restore drill o clone di recovery
- prova failover/reinstate nel lab
- complete security review, wallet, backup wallet, privileged users
- pulizia backlog runbook e standardizzazione naming/script

## 6. Checklist pre-change

- definisci obiettivo, finestra, owner e rollback
- verify recent backup and credible restore path
- save baseline: services status, DG lag, patch level, top alert, key parameters
- check for enough space for patch / export / clone / recovery
- verify impact on RAC, Data Guard, GoldenGate, EM
- prepare post-check queries before starting

## 7. Checklist post-change

- check startup and service status
- check alert log and new errors
- checks Data Guard, backup, scheduler and monitoring
- checks basic performance against the baseline
- documents what has really changed
- close only if you have technical evidence, not due to the absence of visible errors

## 8. Checklist per incident response

- classify the problem: crash, lag, space issue, lock, security, network
- Determine the impact now: users, services, RPO/RTO, data risk
- evita cambi multipli non tracciati
- use correct views and tools before rebooting
- evaluate whether immediate escalation on storage, OS, network or security is needed
- save root cause, workaround and final fix separately

## 9. Checklist per refresh / clone / Data Pump

- conferma sorgente, target e versione
- verify required privileges
- check dump space or clone destination
- check schema/tablespace/PDB mapping
- valid import or clone with objects, invalids and statistics
- documenta tempi reali e colli di bottiglia

## 10. Checklist per backup e recovery readiness

- backup full/incremental riusciti
- archivelog backup coerente
- controlfile e spfile protetti
- retention valida
- crosscheck e delete obsolete eseguiti secondo policy
- ultimo restore test documentato
- recovery path noto per datafile, tablespace, controlfile, spfile, PDB, table recovery

## 11. Checklist per HA/DR

- `SHOW CONFIGURATION` in `SUCCESS`
- lag trasporto/apply entro soglia
- protection mode consistent with the policy
- standby log present and apply active
- switchover readiness verificata
- observer / FSFO valutato se scenario lo richiede
- backup continuity verified even after role transition

## 12. Checklist per security

- review users with privileges `ANY`, `DBA`, `EXP_FULL_DATABASE`, `IMP_FULL_DATABASE`
- review account dormienti, scaduti o non conformi
- review directory object e uso Data Pump
- review auditing e accessi amministrativi
- review wallet/TDE e backup wallet
- apply least privilege with `SYSBACKUP`, `SYSDG`, `SYSKM` when possible

## 13. Sequenza consigliata nel tuo lab

1. use [GUIDE_DBA_ACTIVITY_CATALOG.md](./GUIDE_DBA_ACTIVITY_CATALOG.md) to see the full perimeter
2. do the daily checklist for a week
3. do a week with AWR, RMAN validate and review security
4. do a switchover drill
5. do a restore test
6. close with EM + MAA review

## 14. Guide del repo da tenere affiancate

- [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md)
- [GUIDE_DBA_COMMANDS.md](../GUIDE_DBA_COMMANDS.md)
- [GUIDE_RMAN_COMPLETE_19C.md](../GUIDE_RMAN_COMPLETE_19C.md)
- [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md)
- [GUIDE_LISTENER_SERVICES_DBA.md](../GUIDE_LISTENER_SERVICES_DBA.md)
- [GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md](../GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md)
