# 24 - Gap Analysis Copertura Runbook DBA Oracle

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- [05_asm_storage.sql](../03_scripts_pronti/05_asm_storage.sql) - diskgroup, dischi ASM, AU size, capacity e limiti fisici.
- [13_monitor_ddl_package.sql](../03_scripts_pronti/13_monitor_ddl_package.sql) - audit operativo DDL con tabella, package e trigger.
<!-- READY_SCRIPTS_END -->
## Casi piu frequenti da aprire prima
- Se devi capire cosa studiare dopo: parti da [Priorita consigliata](#priorita-consigliata).
- Se vuoi capire cosa e stato aggiunto per produzione enterprise: vai a [Copertura enterprise aggiunta](#copertura-enterprise-aggiunta).
- Se vuoi capire cosa resta opzionale: vai a [Gap residui da valutare](#gap-residui-da-valutare).
- Se vuoi trasformare il repo in runbook operativo: vai a [Backlog documentale suggerito](#backlog-documentale-suggerito).
- Se vuoi evitare duplicazioni: vai a [Cosa e gia coperto bene](#cosa-e-gia-coperto-bene).

## Indice rapido
- [Obiettivo](#obiettivo)
- [Cosa e gia coperto bene](#cosa-e-gia-coperto-bene)
- [Copertura enterprise aggiunta](#copertura-enterprise-aggiunta)
- [Gap residui da valutare](#gap-residui-da-valutare)
- [Priorita consigliata](#priorita-consigliata)
- [Backlog documentale suggerito](#backlog-documentale-suggerito)
- [Criteri di qualita per i prossimi runbook](#criteri-di-qualita-per-i-prossimi-runbook)

## Obiettivo

Questo documento non e un runbook di emergenza. E una fotografia della copertura documentale del repository per capire cosa manca rispetto a un perimetro DBA Oracle enterprise: banca, assicurazione, PA critica, telco o grande retail.

## Cosa e gia coperto bene

| Area | Stato | Documenti principali |
|---|---|---|
| Health check giornaliero | Buono | [01](./RUNBOOK_01_MORNING_HEALTH_CHECK.md) |
| Backup RMAN e diagnosi fallimenti | Molto buono | [02](./RUNBOOK_02_VERIFICA_BACKUP.md), [19](./RUNBOOK_19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md), [22](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) |
| Data Guard operativo e DR | Molto buono | [03](./RUNBOOK_03_CHECK_DATAGUARD.md), [22](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) |
| SQL tuning | Molto buono | [05](./RUNBOOK_05_QUERY_LENTA.md), [11](./RUNBOOK_11_REVIEW_AWR.md), [18](./RUNBOOK_18_GESTIONE_STATISTICHE_OPTIMIZER.md), [23](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md) |
| Spazio, TEMP, FRA, log | Buono | [06](./RUNBOOK_06_TABLESPACE_PIENO.md), [16](./RUNBOOK_16_RESIZE_TEMP.md), [17](./RUNBOOK_17_PURGE_LOG_ORACLE.md) |
| Data Pump refresh | Buono | [13](./RUNBOOK_13_REFRESH_SCHEMA_TEST.md), [20](./RUNBOOK_20_EXPORT_IMPORT_PROD_PREPROD.md) |
| DB link e 2PC | Buono | [21](./RUNBOOK_21_GESTIONE_DB_LINK.md) |
| Utenti e privilegi | Buono | [09](./RUNBOOK_09_GESTIONE_UTENTI.md) |
| RAC start/stop | Base solida | [10](./RUNBOOK_10_START_STOP_RAC.md) |
| ASM/storage operativo | Buono | [25](./RUNBOOK_25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md) |
| Listener, SCAN e services | Buono | [26](./RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md) |
| TDE wallet/keystore | Buono | [27](./RUNBOOK_27_TDE_WALLET_KEYSTORE_RUNBOOK.md) |
| Scheduler jobs e AutoTask | Buono | [28](./RUNBOOK_28_SCHEDULER_JOBS_AUTOTASKS_RUNBOOK.md) |
| Patching RAC/Data Guard | Buono | [29](./RUNBOOK_29_PATCHING_ORACLE_RAC_DATAGUARD.md) |
| Multitenant CDB/PDB | Buono | [30](./RUNBOOK_30_MULTITENANT_PDB_OPERATIONS.md) |
| GoldenGate incidenti | Buono | [31](./RUNBOOK_31_GOLDENGATE_INCIDENT_RUNBOOK.md) |
| OEM/EM alert handling | Buono | [32](./RUNBOOK_32_ENTERPRISE_MANAGER_ALERT_RUNBOOK.md) |
| Audit/compliance/evidence | Buono | [33](./RUNBOOK_33_AUDIT_COMPLIANCE_EVIDENCE.md) |
| TCPS/certificati | Buono | [34](./RUNBOOK_34_TCPS_WALLET_CERTIFICATI.md) |
| Capacity forecast | Buono | [35](./RUNBOOK_35_CAPACITY_FORECAST_ENTERPRISE.md) |

## Copertura enterprise aggiunta

| Area | Perche conta | Documento |
|---|---|---|
| Incidenti ASM e storage | In RAC molti incidenti partono da diskgroup, path multipath, latency o rebalance | [25](./RUNBOOK_25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md) |
| Listener, SCAN, servizi e FAN/ONS | Molti outage applicativi sono service/listener, non database down | [26](./RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md) |
| TDE wallet/keystore | Critico per startup, refresh, clone e restore cifrati | [27](./RUNBOOK_27_TDE_WALLET_KEYSTORE_RUNBOOK.md) |
| Scheduler jobs e AutoTask | Job bloccati o finestre manutentive generano impatti reali | [28](./RUNBOOK_28_SCHEDULER_JOBS_AUTOTASKS_RUNBOOK.md) |
| Patching RU/RUR e rollback | Serve procedura con precheck, OPatch/datapatch, rolling e rollback | [29](./RUNBOOK_29_PATCHING_ORACLE_RAC_DATAGUARD.md) |
| Multitenant CDB/PDB operations | 19c richiede competenza PDB anche se alcuni ambienti restano non-CDB | [30](./RUNBOOK_30_MULTITENANT_PDB_OPERATIONS.md) |
| GoldenGate incidenti | Lag, abend, trail pieno, extract fermo, replicat conflict | [31](./RUNBOOK_31_GOLDENGATE_INCIDENT_RUNBOOK.md) |
| OEM/EM alert handling | In produzione gli incidenti spesso arrivano da EM, non da query manuali | [32](./RUNBOOK_32_ENTERPRISE_MANAGER_ALERT_RUNBOOK.md) |
| Audit, compliance e evidence | Ambienti regolati richiedono tracciabilita e output before/after | [33](./RUNBOOK_33_AUDIT_COMPLIANCE_EVIDENCE.md) |
| Encryption network e certificates | TCPS, wallet client/server e rotazione certificati causano outage applicativi | [34](./RUNBOOK_34_TCPS_WALLET_CERTIFICATI.md) |
| Capacity forecasting avanzato | Serve prevenire incidenti spazio con trend AWR/DBA_HIST | [35](./RUNBOOK_35_CAPACITY_FORECAST_ENTERPRISE.md) |

## Gap residui da valutare

Questi non sono bloccanti per un percorso DBA Oracle 19c enterprise generico, ma possono diventare importanti in aziende specifiche.

| Gap residuo | Quando serve | Nota |
|---|---|---|
| Resource Manager incidenti | Consolidamento CDB/PDB, CPU governance, batch vs online | Da aggiungere se il cliente usa consumer group e plan complessi |
| Application Continuity/FAN/TAF deep dive | Java pool, UCP, servizi RAC con failover trasparente | Parte coperta da [26](./RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md), ma manca runbook applicativo dedicato |
| Exadata/storage appliance | Celle Exadata, Smart Scan, IORM, cellcli | Non aggiungere se non c'e Exadata nel perimetro |
| Data masking e subsetting | Refresh prod-preprod con dati sensibili | Collegato a [20](./RUNBOOK_20_EXPORT_IMPORT_PROD_PREPROD.md) e compliance |
| ZDLRA/backup appliance | Backup enterprise centralizzati | Solo se presente in infrastruttura |

## Priorita consigliata

1. [25 ASM/storage incidenti](./RUNBOOK_25_ASM_STORAGE_INCIDENTI_ENTERPRISE.md): impatta RAC, RMAN, FRA, Data Guard e performance.
2. [26 Listener/SCAN/services](./RUNBOOK_26_LISTENER_SCAN_SERVICES_RAC.md): molto frequente nei ticket applicativi.
3. [27 TDE wallet/keystore](./RUNBOOK_27_TDE_WALLET_KEYSTORE_RUNBOOK.md): essenziale per ambienti regolati e restore cifrati.
4. [29 Patching RAC/Data Guard](./RUNBOOK_29_PATCHING_ORACLE_RAC_DATAGUARD.md): necessario per parlare di produzione vera.
5. [32 Enterprise Manager alert](./RUNBOOK_32_ENTERPRISE_MANAGER_ALERT_RUNBOOK.md): chiude il ciclo monitoraggio -> runbook -> evidence.
6. [33 Audit/compliance/evidence](./RUNBOOK_33_AUDIT_COMPLIANCE_EVIDENCE.md): obbligatorio dove ogni intervento deve essere tracciato.
7. [35 Capacity forecast](./RUNBOOK_35_CAPACITY_FORECAST_ENTERPRISE.md): evita incidenti spazio ripetitivi.
8. [31 GoldenGate incidenti](./RUNBOOK_31_GOLDENGATE_INCIDENT_RUNBOOK.md): prioritario se il percorso punta a replica/migrazioni.
9. [30 Multitenant PDB operations](./RUNBOOK_30_MULTITENANT_PDB_OPERATIONS.md): prioritario se il cliente usa CDB/PDB.

## Backlog documentale suggerito

Il backlog principale 25-35 e stato trasformato in runbook operativi. Per nuove aggiunte usare questa priorita:

1. Resource Manager incidenti se trovi workload CDB/PDB consolidato.
2. Application Continuity/FAN/TAF se il cliente usa UCP/JDBC failover avanzato.
3. Data masking/subsetting se fai refresh preprod con dati personali.
4. Exadata solo se il perimetro reale include Exadata.
5. ZDLRA solo se il backup e centralizzato su Recovery Appliance.

## Criteri di qualita per i prossimi runbook

Ogni nuovo runbook dovrebbe avere sempre:

- casi frequenti in alto;
- indice rapido;
- precheck;
- procedura con comandi;
- validazione finale;
- rollback o piano di rientro;
- rischi enterprise;
- riferimenti ufficiali;
- template ticket/evidence se l'operazione e critica.
