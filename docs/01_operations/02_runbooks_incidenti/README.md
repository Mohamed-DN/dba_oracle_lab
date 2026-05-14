# 📋 Procedure Operative DBA Oracle 19c

> **Runbook pronti per l'uso quotidiano.** Ogni procedura segue un flusso: prerequisiti → comandi → verifiche → rollback.
> Navigazione avanzata: [Indice Centrale Runbook + Top20](./INDICE_CENTRALE_RUNBOOK_TOP20.md)
> Decision tree centralizzato: [Troubleshooting Decision Tree](../../04_governance_learning/02_enterprise_standards/TROUBLESHOOTING_DECISION_TREE.md)

---

## ⚡ Priorità operativa (prima da aprire)

1. [01 Morning Health Check](./01_MORNING_HEALTH_CHECK.md)
2. [02 Verifica Backup RMAN](./02_VERIFICA_BACKUP.md)
3. [03 Check Data Guard](./03_CHECK_DATAGUARD.md)
4. [08 ORA-Errors Comuni](./08_ORA_ERRORS.md)

---

## 🧾 Cheat Sheet specialistiche

- (../01_cheat_sheets/CHEAT_SHEET_RMAN.md)
- (../01_cheat_sheets/CHEAT_SHEET_RMAN_ESSENZIALE.md)
- (../01_cheat_sheets/CHEAT_SHEET_DGMGRL.md)
- (../01_cheat_sheets/CHEAT_SHEET_GOLDENGATE.md)
- [Guida ADRCI + Diagnostica Oracle](../../02_core_dba/03_performance_and_diagnostics/GUIDA_ADRCI_DIAGNOSTICA_ORACLE.md)

---

## 📁 Indice Procedure

### Giornaliere (ogni mattina)
| # | Procedura | Quando |
|---|---|---|
| 01 | [Morning Health Check](./01_MORNING_HEALTH_CHECK.md) | Ogni mattina, primo check della giornata |
| 02 | [Verifica Backup RMAN](./02_VERIFICA_BACKUP.md) | Ogni mattina, dopo il check iniziale |
| 03 | [Check Data Guard](./03_CHECK_DATAGUARD.md) | Ogni mattina + ogni incidente |

### Su Incidente / Ticket
| # | Procedura | Quando |
|---|---|---|
| 04 | [Lock e Sessioni Bloccate](./04_LOCK_SESSIONI_BLOCCATE.md) | Ticket: "l'applicazione è bloccata" |
| 05 | [Query Lenta — Diagnosi](./05_QUERY_LENTA.md) | Ticket: "la query è lentissima" |
| 06 | [Tablespace Pieno](./06_TABLESPACE_PIENO.md) | Alert: tablespace > 85% |
| 07 | [CPU Alta](./07_CPU_ALTA.md) | Alert: CPU > 90% |
| 08 | [ORA-Errors Comuni](./08_ORA_ERRORS.md) | Qualsiasi errore ORA- |
| 19 | [Diagnosi Backup RMAN Falliti + Restore Senza Backup](./19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) | Backup falliti o assenza di backup RMAN |

### Manutenzione Pianificata
| # | Procedura | Quando |
|---|---|---|
| 09 | [Gestione Utenti e Privilegi](./09_GESTIONE_UTENTI.md) | Richiesta creazione/modifica utente |
| 10 | [Start/Stop Database RAC](./10_START_STOP_RAC.md) | Manutenzione pianificata |

### Settimanale / Mensile
| # | Procedura | Quando |
|---|---|---|
| 11 | [Review AWR Settimanale](./11_REVIEW_AWR.md) | Ogni venerdì |
| 12 | [Capacity Planning e Hard Limits](./12_CAPACITY_PLANNING_LIMITI.md) | Controllo mensile limiti ASM/Tablespace |
| 13 | [Refresh Ambiente di Test](./13_REFRESH_SCHEMA_TEST.md) | Clone schema produzione su Sviluppo (DataPump) |
| 14 | [Chaos Network Partition Data Guard](./14_CHAOS_NETWORK_PARTITION_DATAGUARD.md) | Drill resilienza rete su laboratorio |
| 15 | [Checkmk Agent TLS + SMART/RAID Troubleshooting](./15_CHECKMK_AGENT_TLS_SMART_RAID_TROUBLESHOOTING.md) | Onboarding host e troubleshooting monitoraggio disco/RAID |
| 16 | [Resize TEMP (Tempfile) in Sicurezza](./16_RESIZE_TEMP.md) | ORA-01652, sort su disco, temp al limite |
| 17 | [Purge Log Oracle (ADR, Audit, Archivelog)](./17_PURGE_LOG_ORACLE.md) | Saturazione spazio log/FRA/diag |
| 18 | [Gestione Statistiche Optimizer (DBMS_STATS)](./18_GESTIONE_STATISTICHE_OPTIMIZER.md) | Regressioni query e statistiche stale |

---

## Come Usare

1. Apri la procedura per scenario
2. Segui i passi nell'ordine
3. Esegui validazione finale
4. Documenta esito e tempi nel ticket

> Regola d'oro: non saltare prerequisiti e check finali.
