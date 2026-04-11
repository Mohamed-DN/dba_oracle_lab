# 📋 Procedure Operative DBA Oracle 19c

> **Runbook pronti per l'uso quotidiano.** Ogni procedura è un flusso completo: prerequisiti → comandi → verifiche → rollback.
> Copia-incolla direttamente in produzione.

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

---

## Come Usare

1. **Apri la procedura** relativa al tuo scenario
2. **Segui i passi** nell'ordine indicato
3. **Verifica** con i check di conferma alla fine
4. **Documenta** l'esito nel tuo log operativo

> **Regola d'oro**: Non saltare i prerequisiti e i check di conferma.
