# GUIDE: DBA Operational Checklist

> Practical checklist for transforming the DBA activity catalog into an executable routine.
> Use it in the lab as an operational runbook, then adapt it to production with real owners, times and SLAs.

## 1. Checklist giornaliera

### Opening day

- check database / instances / services status
- check listener and cluster resources
- check alert log and latest errors`ORA-`
- check latest RMAN backups
- check`SHOW CONFIGURATION`Data Guard and lag
- check critical tablespaces, FRAs and ASM disk groups
- check incidents or target downs in Enterprise Manager

Minimum evidence:
- EM screenshot or status output
- notes on open anomalies
- owner assigned for each issue

## 2. Checklist giornaliera su ticket o anomalie

- identifies whether the problem is availability, performance, storage, security or network
- collect evidence before changing parameters
- save query, output and event time
- only make one change at a time whenever possible
- immediately check the effect of the correction
- update the runbook if the case was not documented

## 3. Checklist settimanale

- generate or analyze AWR/ADDM
- verify `RESTORE VALIDATE`
- monitor storage growth and tablespace trends
- review failed job schedulers and long chains
- Check expired/blocked users and exceptional grants
- Check GG lag / processes if GoldenGate is active
- controlla invalid objects e warning applicativi noti

## 4. Checklist mensile

- review patch level, OPatch version e backlog RU/OJVM
- review capacity planning with growth last month
- review auditing, privilegi potenti e directory object
- controlled maintenance tests on services/listeners
- review Enterprise Manager thresholds and notifications
- review operational documentation and rollback plan

## 5. Checklist trimestrale

- esegui switchover drill
- run restore drill or recovery clone
- test failover/reinstate in the lab
- complete security review, wallet, backup wallet, privileged users
- runbook backlog cleaning and naming/script standardization

## 6. Checklist pre-change

- define goal, window, owner and rollback
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
- avoid multiple untracked changes
- use correct views and tools before rebooting
- evaluate whether immediate escalation on storage, OS, network or security is needed
- save root cause, workaround and final fix separately

## 9. Checklist per refresh / clone / Data Pump

- confirm source, target and version
- verify required privileges
- check dump space or clone destination
- check schema/tablespace/PDB mapping
- valid import or clone with objects, invalids and statistics
- documents real times and bottlenecks

## 10. Checklist per backup e recovery readiness

- successful full/incremental backups
- archivelog backup coerente
- protected controlfiles and spfiles
- valid retention
- crosscheck and delete obsolete performed according to policy
- last documented restore test
- recovery path noto per datafile, tablespace, controlfile, spfile, PDB, table recovery

## 11. Checklist per HA/DR

- `SHOW CONFIGURATION` in `SUCCESS`
- transport/apply lag within threshold
- protection mode consistent with the policy
- standby log present and apply active
- switchover readiness verificata
- observer / FSFO evaluated if scenario requires it
- backup continuity verified even after role transition

## 12. Checklist per security

- review users with privileges `ANY`, `DBA`, `EXP_FULL_DATABASE`, `IMP_FULL_DATABASE`
- dormant, expired or non-compliant review accounts
- review directory object e uso Data Pump
- review auditing and administrative access
- review wallet/TDE e backup wallet
- apply least privilege with `SYSBACKUP`, `SYSDG`, `SYSKM` when possible

## 13. Recommended sequence in your lab

1. use [GUIDE_DBA_ACTIVITY_CATALOG.md](./GUIDE_DBA_ACTIVITY_CATALOG.md) to see the full perimeter
2. do the daily checklist for a week
3. do a week with AWR, RMAN validate and review security
4. do a switchover drill
5. do a restore test
6. close with EM + MAA review

## 14. Repo guides to keep side by side

- [GUIDE_DBA_ACTIVITIES.md](../GUIDE_DBA_ACTIVITIES.md)
- [GUIDE_DBA_COMMANDS.md](../GUIDE_DBA_COMMANDS.md)
- [GUIDE_RMAN_COMPLETE_19C.md](../GUIDE_RMAN_COMPLETE_19C.md)
- [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../GUIDE_PHASE4_DATAGUARD_DGMGRL.md)
- [GUIDE_LISTENER_SERVICES_DBA.md](../GUIDE_LISTENER_SERVICES_DBA.md)
- [GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md](../GUIDE_PHASE8_ENTERPRISE_MANAGER_13C.md)
