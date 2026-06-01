# 00 - Triage Incidenti Oracle: da alert a runbook corretto

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- [07_performance_quick.sql](../03_scripts_pronti/07_performance_quick.sql) - top SQL, wait event, ASH real-time, piani SQL.
- [08_rman_backup_status.sql](../03_scripts_pronti/08_rman_backup_status.sql) - ultimo backup, backup falliti, config RMAN, archivelog non backuppati.
- [09_dataguard_status.sql](../03_scripts_pronti/09_dataguard_status.sql) - ruolo DB, transport/apply lag, gap, MRP, switchover readiness.
- [03_fra_archivelog.sql](../03_scripts_pronti/03_fra_archivelog.sql) - diagnosi FRA piena, archivelog, ORA-19809, ORA-00257.
<!-- READY_SCRIPTS_END -->
## Casi piu frequenti da aprire prima
- Applicazione non entra o login fallisce: parti da [08 ORA-Errors Comuni](./RUNBOOK_08_ORA_ERRORS.md), poi rete/listener o utenti.
- Database o istanza non disponibili: parti da [01 Morning Health Check](./RUNBOOK_01_MORNING_HEALTH_CHECK.md), poi [10 Start/Stop RAC](./RUNBOOK_10_START_STOP_RAC.md) e [22 RMAN/Data Guard](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md).
- Spazio pieno: parti da [06 Tablespace Pieno](./RUNBOOK_06_TABLESPACE_PIENO.md), [16 Resize TEMP](./RUNBOOK_16_RESIZE_TEMP.md), [17 Purge Log](./RUNBOOK_17_PURGE_LOG_ORACLE.md).
- Backup fallito o restore richiesto: parti da [02 Verifica Backup](./RUNBOOK_02_VERIFICA_BACKUP.md), poi [19 Diagnosi RMAN](./RUNBOOK_19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) e [22 RMAN/Data Guard](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md).
- Query lenta o CPU alta: parti da [05 Query Lenta](./RUNBOOK_05_QUERY_LENTA.md), [07 CPU Alta](./RUNBOOK_07_CPU_ALTA.md), poi [23 SQL Tuning Enterprise](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md).
- Data Guard in errore: parti da [03 Check Data Guard](./RUNBOOK_03_CHECK_DATAGUARD.md), poi [22 RMAN/Data Guard](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md).
- Refresh o clone preprod: parti da [20 Export/Import Prod-Preprod](./RUNBOOK_20_EXPORT_IMPORT_PROD_PREPROD.md), [21 DB Link](./RUNBOOK_21_GESTIONE_DB_LINK.md), [13 Refresh Schema Test](./RUNBOOK_13_REFRESH_SCHEMA_TEST.md).

## Indice rapido
- [Obiettivo](#obiettivo)
- [Procedura operativa](#procedura-operativa)
- [Decision tree in 90 secondi](#decision-tree-in-90-secondi)
- [Matrice alert -> runbook](#matrice-alert---runbook)
- [Severita e comunicazione](#severita-e-comunicazione)
- [Checklist minima da allegare al ticket](#checklist-minima-da-allegare-al-ticket)
- [Cosa non fare in produzione](#cosa-non-fare-in-produzione)
- [Validazione finale](#validazione-finale)
- [Troubleshooting rapido](#troubleshooting-rapido)
- [Fonti Oracle ufficiali utili](#fonti-oracle-ufficiali-utili)

## Obiettivo

Questo file e il punto di ingresso per gli incidenti Oracle. Serve a evitare due errori tipici:

1. aprire il runbook sbagliato e perdere tempo;
2. partire dal comando di fix senza aver raccolto evidenze minime.

In ambiente critico il DBA deve prima classificare il problema, poi scegliere la procedura. La priorita non e "provare comandi", ma ridurre il rischio operativo mantenendo tracciabilita.

## Procedura operativa

Prima di qualunque intervento raccogli sempre:

```sql
-- Identita database e ruolo
SELECT name, open_mode, database_role, protection_mode FROM v$database;
SELECT instance_name, host_name, status FROM gv$instance;

-- Eventuali errori recenti
SELECT originating_timestamp, message_text
FROM   v$diag_alert_ext
WHERE  originating_timestamp > SYSTIMESTAMP - INTERVAL '2' HOUR
AND    (message_text LIKE '%ORA-%' OR message_text LIKE '%error%')
ORDER  BY originating_timestamp DESC;
```

Se il database non e accessibile, usa OS/cluster:

```bash
srvctl status database -d <DB_UNIQUE_NAME>
crsctl stat res -t
adrci
```

## Decision tree in 90 secondi

```text
ALERT / TICKET
   |
   +-- Database non raggiungibile?
   |      +-- CRS/istanza down -> 01, 10, 22
   |      +-- listener/service/TNS -> 08, 10
   |
   +-- Errore ORA specifico?
   |      +-- spazio/FRA/TEMP -> 06, 16, 17, 19
   |      +-- login/account -> 08, 09
   |      +-- internal/corruption -> 08, 22
   |
   +-- Performance?
   |      +-- singola query -> 05, 23
   |      +-- CPU host/DB -> 07, 11, 23
   |      +-- lock -> 04
   |
   +-- Backup/restore?
   |      +-- backup failed -> 02, 19
   |      +-- restore/recovery -> 22
   |
   +-- Data Guard?
          +-- lag/gap/transport -> 03, 22
          +-- role transition -> 22
```

## Matrice alert -> runbook

| Alert o sintomo | Primo runbook | Escalation documentale | Evidenza minima |
|---|---|---|---|
| Applicazione bloccata | [04](./RUNBOOK_04_LOCK_SESSIONI_BLOCCATE.md) | [23](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md) | blocker, waiter, SQL_ID, evento wait |
| Query lenta | [05](./RUNBOOK_05_QUERY_LENTA.md) | [23](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md) | SQL_ID, plan hash, elapsed, buffer gets |
| CPU alta | [07](./RUNBOOK_07_CPU_ALTA.md) | [23](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md) | top process OS, ASH, AAS, SQL_ID |
| Tablespace pieno | [06](./RUNBOOK_06_TABLESPACE_PIENO.md) | [12](./RUNBOOK_12_CAPACITY_PLANNING_LIMITI.md) | tablespace, datafile, autoextend, maxsize |
| TEMP piena | [16](./RUNBOOK_16_RESIZE_TEMP.md) | [23](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md) | sessioni TEMP, SQL_ID, tempfile |
| FRA piena | [17](./RUNBOOK_17_PURGE_LOG_ORACLE.md) | [19](./RUNBOOK_19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) | v$recovery_area_usage, archivelog, DG applied |
| Backup failed | [02](./RUNBOOK_02_VERIFICA_BACKUP.md) | [19](./RUNBOOK_19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) | RMAN log, error stack, backup pieces |
| Drop table / delete errata | [22](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) | [RMAN cheat sheet](../01_cheat_sheets/CS_RMAN.md) | ora evento, oggetto, backup, flashback |
| Data Guard lag | [03](./RUNBOOK_03_CHECK_DATAGUARD.md) | [22](./RUNBOOK_22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) | transport/apply lag, gap, alert log |
| DB link lento/rotto | [21](./RUNBOOK_21_GESTIONE_DB_LINK.md) | [23](./RUNBOOK_23_SQL_TUNING_CASI_ENTERPRISE.md) | connect string, ORA, remote SQL, network |
| Refresh preprod | [20](./RUNBOOK_20_EXPORT_IMPORT_PROD_PREPROD.md) | [13](./RUNBOOK_13_REFRESH_SCHEMA_TEST.md) | dump size, parfile, masking, checksum |
| Utente bloccato/accesso | [09](./RUNBOOK_09_GESTIONE_UTENTI.md) | [08](./RUNBOOK_08_ORA_ERRORS.md) | username, profile, audit, richiesta autorizzata |

## Severita e comunicazione

| Severita | Esempio | Comunicazione |
|---|---|---|
| SEV1 | DB primario down, corruzione, perdita dati, blocco totale business | War room, timeline ogni 15 minuti, nessun comando distruttivo senza approvazione |
| SEV2 | Servizio degradato, DG lag alto, backup principale fallito | Aggiornamento ogni 30 minuti, workaround e piano definitivo |
| SEV3 | Singola query lenta, spazio sopra soglia ma non critico | Ticket standard con evidenze before/after |
| SEV4 | Hardening, capacity, review settimanale | Pianificazione change e documentazione |

## Checklist minima da allegare al ticket

```text
Database:
Istanza/nodo:
Ruolo Data Guard:
Ora inizio incidente:
Sintomo visto dall'utente/app:
Errore ORA o alert:
SQL_ID / job / oggetto coinvolto:
Runbook usato:
Comandi eseguiti:
Esito validazione:
Rischio residuo:
Prossima azione:
```

## Cosa non fare in produzione

- Non cancellare archivelog senza sapere se sono stati applicati su tutti gli standby richiesti.
- Non killare sessioni senza identificare transazione, utente, modulo e impatto.
- Non aggiungere datafile con autoextend illimitato senza verificare limite filesystem/ASM.
- Non cambiare parametri optimizer globali per risolvere una singola query.
- Non fare failover Data Guard se non hai dichiarato RPO/RTO e confermato ruolo/lag.
- Non usare account con privilegi eccessivi se esiste una procedura least privilege.

## Validazione finale

Prima di chiudere il triage verifica che il ticket contenga database, nodo,
ruolo, orario, sintomo, evidenze raccolte e runbook scelto. Se hai già eseguito
un fix, registra anche comando, output di verifica e rischio residuo.

## Troubleshooting rapido

Se il database non risponde, passa subito ai controlli OS e Clusterware. Se il
sintomo non rientra nella matrice, conserva alert log e timeline e apri il
decision tree generale prima di provare modifiche.

## Fonti Oracle ufficiali utili

- Oracle Database 19c Backup and Recovery User's Guide.
- Oracle Database 19c Data Guard Concepts and Administration.
- Oracle Database 19c SQL Tuning Guide.
- Oracle Database 19c Utilities Guide: Data Pump e ADRCI.
- Oracle Database 19c Administrator's Guide: Scheduler, gestione database e diagnostica.
- Oracle Database 19c Security Guide: utenti, privilegi, auditing.
