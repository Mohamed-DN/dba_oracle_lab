# Extra DBA - Indice Attivita Post-Laboratorio

> Indice curato delle attivita DBA avanzate gia presenti nel repository.
> Non sostituisce il percorso base Fase 0 -> Fase 8: lo estende dopo che il lab e stabile.

## Documenti principali della cartella

| Documento | Quando usarlo | File |
|---|---|---|
| **Catalogo completo attivita DBA** | Quando vuoi vedere tutto il perimetro del lavoro DBA Oracle, organizzato per dominio operativo | [GUIDA_CATALOGO_ATTIVITA_DBA.md](./GUIDA_CATALOGO_ATTIVITA_DBA.md) |
| **Checklist operativa DBA** | Quando vuoi una sequenza pratica giornaliera, settimanale, mensile, trimestrale e pre/post change | [GUIDA_CHECKLIST_ATTIVITA_DBA.md](./GUIDA_CHECKLIST_ATTIVITA_DBA.md) |

## Come usare questa area

- Completa prima il lab base e tieni il Data Guard in `MaxPerformance`.
- Usa questa area per operazioni day-2, hardening, esercizi avanzati e scenari DBA reali.
- `studio_ai` resta separato: contiene script e note operative; qui trovi solo il percorso guidato delle attivita extra.

## 1. Data Guard avanzato

| Attivita | Quando usarla | Guida |
|---|---|---|
| **Protection Mode / switch modalita** | Subito dopo Fase 4, se vuoi capire quando usare `MaxPerformance`, `MaxAvailability`, `MaxProtection` o `FASTSYNC` | [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../GUIDA_FASE4_DATAGUARD_DGMGRL.md) |
| **Switchover** | Quando vuoi testare role transition pianificata senza data loss | [GUIDA_SWITCHOVER_COMPLETO.md](../GUIDA_SWITCHOVER_COMPLETO.md) |
| **Failover + Reinstate** | Quando vuoi simulare perdita del primary e recupero controllato | [GUIDA_FAILOVER_E_REINSTATE.md](../GUIDA_FAILOVER_E_REINSTATE.md) |
| **Active Data Guard** | Quando vuoi tenere lo standby in `READ ONLY WITH APPLY`, anche per GoldenGate | [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../GUIDA_FASE4_DATAGUARD_DGMGRL.md) |

### Nota pratica sul cambio modalita

- `MaxPerformance`: default del lab, minima latenza, redo in `ASYNC`.
- `MaxAvailability`: da usare se vuoi zero data loss sul primo fault e la rete regge `SYNC` o `FASTSYNC`.
- `MaxProtection`: da usare solo se accetti l'impatto massimo sulla disponibilita del primary.

La guida tecnica resta in [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../GUIDA_FASE4_DATAGUARD_DGMGRL.md), sezione `4.4 Configurazione Protection Mode`.

## 2. RAC operations

| Attivita | Quando usarla | Guida |
|---|---|---|
| **Listener e Services** | Quando devi capire SCAN, listener statici, servizi RAC e troubleshooting `ORA-12514` | [GUIDA_LISTENER_SERVICES_DBA.md](../GUIDA_LISTENER_SERVICES_DBA.md) |
| **Patching RAC** | Quando devi applicare RU/OJVM o ripulire l'home dopo il patching | [GUIDA_PATCHING_RAC.md](../GUIDA_PATCHING_RAC.md) |
| **Upgrade RU workflow** | Quando vuoi simulare upgrade RU piu strutturati e rollback | [GUIDA_UPGRADE_RU_RAC.md](../GUIDA_UPGRADE_RU_RAC.md) |

## 3. Backup e recovery

| Attivita | Quando usarla | Guida |
|---|---|---|
| **RMAN lab base** | Quando vuoi la strategia operativa del lab con backup, cron e restore guidato | [GUIDA_FASE7_RMAN_BACKUP.md](../GUIDA_FASE7_RMAN_BACKUP.md) |
| **RMAN completa 19c** | Quando vuoi un runbook piu esteso con recovery, catalog, validate e casi Data Guard | [GUIDA_RMAN_COMPLETA_19C.md](../GUIDA_RMAN_COMPLETA_19C.md) |

## 4. Monitoring e day-2

| Attivita | Quando usarla | Guida |
|---|---|---|
| **Enterprise Manager 13.5** | Quando vuoi monitorare OMS, agent, target RAC/Data Guard e job operativi | [GUIDA_FASE8_ENTERPRISE_MANAGER_13C.md](../GUIDA_FASE8_ENTERPRISE_MANAGER_13C.md) |
| **Attivita DBA essenziali** | Quando vuoi runbook su AWR/ADDM/ASH, Data Pump, security e patching | [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md) |
| **MAA best practices** | Quando vuoi confrontare il lab con raccomandazioni Oracle HA/DR | [GUIDA_MAA_BEST_PRACTICES.md](../GUIDA_MAA_BEST_PRACTICES.md) |

## 5. Security e encryption

| Attivita | Quando usarla | Guida |
|---|---|---|
| **TDE / keystore / wallet** | Quando vuoi configurare Transparent Data Encryption, capire il ruolo del wallet e ricordarti il backup del keystore | [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md) |
| **Toolkit TDE e audit** | Quando vuoi script pratici per audit trail, controlli sicurezza e note operative riusabili | [studio_ai/08_tde_security](../studio_ai/08_tde_security/) |

### Nota pratica su TDE

- nel repo la parte piu concreta oggi sta in [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md), sezione `5.3 Transparent Data Encryption (TDE)`;
- il punto critico non e solo creare la master key, ma gestire bene `keystore`, backup wallet e utenti amministrativi (`SYSKM`);
- `TDE` protegge i dati a riposo, non sostituisce backup, auditing o network encryption.

## Percorso consigliato post-lab

1. Protection Mode
2. Switchover
3. Failover + Reinstate
4. RMAN completo
5. TDE / wallet / security review
6. Enterprise Manager
7. MAA review finale
