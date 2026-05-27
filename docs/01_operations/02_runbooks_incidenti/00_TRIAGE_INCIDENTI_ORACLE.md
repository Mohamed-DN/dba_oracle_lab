# 00 - Triage Incidenti Oracle: da alert a runbook corretto

## Casi piu frequenti da aprire prima
- Applicazione non entra o login fallisce: parti da [08 ORA-Errors Comuni](./08_ORA_ERRORS.md), poi rete/listener o utenti.
- Database o istanza non disponibili: parti da [01 Morning Health Check](./01_MORNING_HEALTH_CHECK.md), poi [10 Start/Stop RAC](./10_START_STOP_RAC.md) e [22 RMAN/Data Guard](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md).
- Spazio pieno: parti da [06 Tablespace Pieno](./06_TABLESPACE_PIENO.md), [16 Resize TEMP](./16_RESIZE_TEMP.md), [17 Purge Log](./17_PURGE_LOG_ORACLE.md).
- Backup fallito o restore richiesto: parti da [02 Verifica Backup](./02_VERIFICA_BACKUP.md), poi [19 Diagnosi RMAN](./19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) e [22 RMAN/Data Guard](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md).
- Query lenta o CPU alta: parti da [05 Query Lenta](./05_QUERY_LENTA.md), [07 CPU Alta](./07_CPU_ALTA.md), poi [23 SQL Tuning Enterprise](./23_SQL_TUNING_CASI_ENTERPRISE.md).
- Data Guard in errore: parti da [03 Check Data Guard](./03_CHECK_DATAGUARD.md), poi [22 RMAN/Data Guard](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md).
- Refresh o clone preprod: parti da [20 Export/Import Prod-Preprod](./20_EXPORT_IMPORT_PROD_PREPROD.md), [21 DB Link](./21_GESTIONE_DB_LINK.md), [13 Refresh Schema Test](./13_REFRESH_SCHEMA_TEST.md).

## Indice rapido
- [Obiettivo](#obiettivo)
- [Regola operativa](#regola-operativa)
- [Decision tree in 90 secondi](#decision-tree-in-90-secondi)
- [Matrice alert -> runbook](#matrice-alert---runbook)
- [Severita e comunicazione](#severita-e-comunicazione)
- [Checklist minima da allegare al ticket](#checklist-minima-da-allegare-al-ticket)
- [Cosa non fare in produzione](#cosa-non-fare-in-produzione)
- [Fonti Oracle ufficiali utili](#fonti-oracle-ufficiali-utili)

## Obiettivo

Questo file e il punto di ingresso per gli incidenti Oracle. Serve a evitare due errori tipici:

1. aprire il runbook sbagliato e perdere tempo;
2. partire dal comando di fix senza aver raccolto evidenze minime.

In ambiente critico il DBA deve prima classificare il problema, poi scegliere la procedura. La priorita non e "provare comandi", ma ridurre il rischio operativo mantenendo tracciabilita.

## Regola operativa

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
| Applicazione bloccata | [04](./04_LOCK_SESSIONI_BLOCCATE.md) | [23](./23_SQL_TUNING_CASI_ENTERPRISE.md) | blocker, waiter, SQL_ID, evento wait |
| Query lenta | [05](./05_QUERY_LENTA.md) | [23](./23_SQL_TUNING_CASI_ENTERPRISE.md) | SQL_ID, plan hash, elapsed, buffer gets |
| CPU alta | [07](./07_CPU_ALTA.md) | [23](./23_SQL_TUNING_CASI_ENTERPRISE.md) | top process OS, ASH, AAS, SQL_ID |
| Tablespace pieno | [06](./06_TABLESPACE_PIENO.md) | [12](./12_CAPACITY_PLANNING_LIMITI.md) | tablespace, datafile, autoextend, maxsize |
| TEMP piena | [16](./16_RESIZE_TEMP.md) | [23](./23_SQL_TUNING_CASI_ENTERPRISE.md) | sessioni TEMP, SQL_ID, tempfile |
| FRA piena | [17](./17_PURGE_LOG_ORACLE.md) | [19](./19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) | v$recovery_area_usage, archivelog, DG applied |
| Backup failed | [02](./02_VERIFICA_BACKUP.md) | [19](./19_DIAGNOSI_BACKUP_RMAN_FALLITI_E_RESTORE_SENZA_BACKUP.md) | RMAN log, error stack, backup pieces |
| Drop table / delete errata | [22](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) | [RMAN cheat sheet](../01_cheat_sheets/RMAN_FULL_CHEATSHEET.md) | ora evento, oggetto, backup, flashback |
| Data Guard lag | [03](./03_CHECK_DATAGUARD.md) | [22](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md) | transport/apply lag, gap, alert log |
| DB link lento/rotto | [21](./21_GESTIONE_DB_LINK.md) | [23](./23_SQL_TUNING_CASI_ENTERPRISE.md) | connect string, ORA, remote SQL, network |
| Refresh preprod | [20](./20_EXPORT_IMPORT_PROD_PREPROD.md) | [13](./13_REFRESH_SCHEMA_TEST.md) | dump size, parfile, masking, checksum |
| Utente bloccato/accesso | [09](./09_GESTIONE_UTENTI.md) | [08](./08_ORA_ERRORS.md) | username, profile, audit, richiesta autorizzata |

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

## Fonti Oracle ufficiali utili

- Oracle Database 19c Backup and Recovery User's Guide.
- Oracle Database 19c Data Guard Concepts and Administration.
- Oracle Database 19c SQL Tuning Guide.
- Oracle Database 19c Utilities Guide: Data Pump e ADRCI.
- Oracle Database 19c Administrator's Guide: Scheduler, gestione database e diagnostica.
- Oracle Database 19c Security Guide: utenti, privilegi, auditing.
