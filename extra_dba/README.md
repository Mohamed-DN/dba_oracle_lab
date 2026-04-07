# Extra DBA — Indice Attività Post-Laboratorio

> Indice curato delle attività DBA avanzate già presenti nel repository.
> Non sostituisce il percorso base Fase 0 → Fase 8: lo estende dopo che il lab è stabile.

## Documenti principali della cartella

| Documento | Quando usarlo | File |
|---|---|---|
| **Catalogo completo attività DBA** | Quando vuoi vedere tutto il perimetro del lavoro DBA Oracle, organizzato per dominio operativo | [GUIDA_CATALOGO_ATTIVITA_DBA.md](./GUIDA_CATALOGO_ATTIVITA_DBA.md) |
| **Checklist operativa DBA** | Quando vuoi una sequenza pratica giornaliera, settimanale, mensile, trimestrale e pre/post change | [GUIDA_CHECKLIST_ATTIVITA_DBA.md](./GUIDA_CHECKLIST_ATTIVITA_DBA.md) |
| **Guida domande DBA Oracle** | Quando vuoi ripassare domande tecniche, risposte chiare, scenari realistici e follow-up tipici | [GUIDA_DOMANDE_DBA_ORACLE.md](./GUIDA_DOMANDE_DBA_ORACLE.md) |
| **PDB + Data Guard + Services** | Quando vuoi testare la propagazione PDB verso standby e pubblicare servizi RAC | [GUIDA_PDB_DATAGUARD_SERVICES.md](./GUIDA_PDB_DATAGUARD_SERVICES.md) |

## Come usare questa area

- Completa prima il lab base e tieni il Data Guard in `MaxPerformance`.
- Usa questa area per operazioni day-2, hardening, esercizi avanzati e scenari DBA reali.
- `studio_ai` resta separato: contiene script e note operative; qui trovi solo il percorso guidato delle attività extra.

---

## Mappa Completa: Guide del Repo per Dominio

### 1. Data Guard & HA

| Attività | Guida |
|---|---|
| Protection Mode / switch modalità | [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../GUIDA_FASE4_DATAGUARD_DGMGRL.md) |
| Switchover pianificato | [GUIDA_SWITCHOVER_COMPLETO.md](../GUIDA_SWITCHOVER_COMPLETO.md) |
| Failover + Reinstate | [GUIDA_FAILOVER_E_REINSTATE.md](../GUIDA_FAILOVER_E_REINSTATE.md) |
| Flashback Database | [GUIDA_FLASHBACK_DATABASE.md](../GUIDA_FLASHBACK_DATABASE.md) |
| PDB propagation + services | [GUIDA_PDB_DATAGUARD_SERVICES.md](./GUIDA_PDB_DATAGUARD_SERVICES.md) |
| MAA best practices | [GUIDA_MAA_BEST_PRACTICES.md](../GUIDA_MAA_BEST_PRACTICES.md) |

### 2. RAC Operations & Services

| Attività | Guida |
|---|---|
| Listener, SCAN, TNS | [GUIDA_LISTENER_SERVICES_DBA.md](../GUIDA_LISTENER_SERVICES_DBA.md) |
| TAF, FAN, CLB/RLB | [GUIDA_SERVIZI_APPLICATIVI_RAC.md](../GUIDA_SERVIZI_APPLICATIVI_RAC.md) |
| Aggiunta dischi ASM | [GUIDA_AGGIUNTA_DISCHI_ASM.md](../GUIDA_AGGIUNTA_DISCHI_ASM.md) |
| Patching RAC | [GUIDA_PATCHING_RAC.md](../GUIDA_PATCHING_RAC.md) |
| Upgrade RU | [GUIDA_UPGRADE_RU_RAC.md](../GUIDA_UPGRADE_RU_RAC.md) |

### 3. Backup & Recovery

| Attività | Guida |
|---|---|
| RMAN strategia completa | [GUIDA_FASE5_RMAN_BACKUP.md](../GUIDA_FASE5_RMAN_BACKUP.md) |
| Flashback Database | [GUIDA_FLASHBACK_DATABASE.md](../GUIDA_FLASHBACK_DATABASE.md) |
| Data Pump export/import | [GUIDA_DATA_PUMP.md](../GUIDA_DATA_PUMP.md) |

### 4. Performance & Troubleshooting 🆕

| Attività | Guida |
|---|---|
| **Metodo troubleshooting da zero** | [GUIDA_TROUBLESHOOTING_COMPLETO.md](../GUIDA_TROUBLESHOOTING_COMPLETO.md) |
| Comandi avanzati AWR/ASH/ADDM | [GUIDA_AWR_ASH_ADDM.md](../GUIDA_AWR_ASH_ADDM.md) |
| Top 100 script DBA | [TOP_100_SCRIPT_DBA.md](../TOP_100_SCRIPT_DBA.md) |

### 5. Security & Encryption 🆕

| Attività | Guida |
|---|---|
| TDE, Auditing, Encryption | [GUIDA_SECURITY_HARDENING.md](../GUIDA_SECURITY_HARDENING.md) |
| Utenti, ruoli, profili | [GUIDA_CDB_PDB_UTENTI.md](../GUIDA_CDB_PDB_UTENTI.md) |

### 6. Database Administration

| Attività | Guida |
|---|---|
| CDB/PDB, Multitenant | [GUIDA_CDB_PDB_UTENTI.md](../GUIDA_CDB_PDB_UTENTI.md) |
| Comandi DBA essenziali | [GUIDA_COMANDI_DBA.md](../GUIDA_COMANDI_DBA.md) |
| Scheduler & Jobs | [GUIDA_SCHEDULER_JOBS.md](../GUIDA_SCHEDULER_JOBS.md) |
| Attività quotidiane DBA | [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md) |

### 7. Monitoring

| Attività | Guida |
|---|---|
| Enterprise Manager 13.5 | [GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md](../GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md) |

### 8. GoldenGate & Replication

| Attività | Guida |
|---|---|
| GoldenGate locale (Oracle + PG) | [GUIDA_FASE7_GOLDENGATE.md](../GUIDA_FASE7_GOLDENGATE.md) |
| Migrazione zero-downtime | [GUIDA_MIGRAZIONE_GOLDENGATE.md](../GUIDA_MIGRAZIONE_GOLDENGATE.md) |
| Oracle → PostgreSQL | [GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md](../GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md) |

### 9. Riferimenti

| Attività | Guida |
|---|---|
| Glossario 100+ termini | [GLOSSARIO_ORACLE.md](../GLOSSARIO_ORACLE.md) |
| Architettura Oracle | [GUIDA_ARCHITETTURA_ORACLE.md](../GUIDA_ARCHITETTURA_ORACLE.md) |

---

## Percorso consigliato post-lab

1. Protection Mode → Switchover → Failover + Reinstate
2. RMAN completo + Flashback Database
3. Performance: mega-guida troubleshooting + AWR/ASH
4. Security: TDE + Auditing + Hardening
5. Enterprise Manager
6. Scheduler & Jobs
7. MAA review finale + Domande colloquio
