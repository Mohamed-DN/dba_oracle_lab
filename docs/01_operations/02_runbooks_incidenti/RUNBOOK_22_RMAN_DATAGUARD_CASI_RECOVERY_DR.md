# Runbook Enterprise: Tutti i Casi RMAN e Data Guard per Recovery, DR e Incidenti

<!-- RUNBOOK_NAV_START -->
## Indice operativo rapido

### Playbook RMAN
- [Triage recovery](#rman-p01---triage-recovery-prima-di-cambiare-stato)
- [SPFILE e controlfile](#rman-p03---perdita-spfile-o-controlfile)
- [Datafile e tablespace](#rman-p04---perdita-datafile-o-tablespace)
- [Corruzione blocchi](#rman-p05---corruzione-blocchi)
- [Errore logico e RECOVER TABLE](#rman-p06---errore-logico-e-recover-table)
- [FRA piena](#rman-p08---fra-piena-con-database-bloccato)

### Playbook Data Guard
- [Diagnosi lag e gap](#dg-p01---diagnosi-transport-lag-apply-lag-e-gap)
- [Switchover pianificato](#dg-p02---switchover-pianificato)
- [Failover e reinstate](#dg-p03---failover-e-reinstate)
- [Observer e FSFO](#dg-p04---observer-e-fsfo)
- [Primary FRA piena con standby in lag](#dg-061---primary-fra-piena-per-standby-lag)
- [Riallineamento standby](#dg-062---riallineamento-standby-dopo-gap)

### Come usare il documento
Apri il playbook che descrive il danno reale, esegui prima la diagnosi e usa la
matrice finale per i casi secondari. Non scegliere un comando soltanto perche'
compare vicino al sintomo: verifica prerequisiti, ruolo database e rischio.
<!-- RUNBOOK_NAV_END -->

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- [08_rman_backup_status.sql](../03_scripts_pronti/08_rman_backup_status.sql) - ultimo backup, backup falliti, config RMAN, archivelog non backuppati.
- [09_dataguard_status.sql](../03_scripts_pronti/09_dataguard_status.sql) - ruolo DB, transport/apply lag, gap, MRP, switchover readiness.
- [03_fra_archivelog.sql](../03_scripts_pronti/03_fra_archivelog.sql) - diagnosi FRA piena, archivelog, ORA-19809, ORA-00257.
<!-- READY_SCRIPTS_END -->
> Documento operativo per DBA Oracle 19c in ambienti critici. Copre scenari RMAN, Flashback, Data Guard, Broker, RAC, CDB/PDB, incidenti logici, crash fisici, errori umani, gap redo, failover e switchover. Il focus e' decisionale: quale tecnologia usare, quando usarla, quali comandi lanciare, come validare e quali rischi evitare.

---

## Obiettivi

- Scegliere il recovery path con blast radius minimo compatibile con RPO e RTO.
- Preservare redo e backup necessari prima delle mitigazioni di emergenza.
- Validare database e Data Guard dopo restore, recovery o role transition.

## Procedura operativa

Parti dal pre-check universale, individua lo scenario RMAN o Data Guard e applica
la sequenza documentata. Nei Sev1 registra evidenze, autorizzazioni e rischio
residuo prima di ogni comando irreversibile.

## Validazione finale

Chiudi lo scenario solo dopo aver verificato ruolo database, alert log, workload,
backup recuperabili e stato Data Guard coerente con il livello di protezione.

## Troubleshooting rapido

Se mancano redo o backup, non improvvisare cancellazioni o role transition:
ferma il change, conserva output e usa escalation e fallback documentati.

## Spiegazione didattica: come raccontare RMAN e Data Guard

Questa sezione serve per spiegare il documento a voce, in riunione tecnica, in audit o durante un colloquio. I comandi sono importanti, ma un DBA senior deve prima spiegare **perche'** sceglie una tecnologia e quali rischi controlla.

### 1. RMAN in una frase

RMAN e' il motore Oracle supportato per backup, restore e recovery fisico del database. Lavora con datafile, control file, SPFILE, archivelog, backupset, image copy, incarnation e metadata di recovery.

```text
Problema fisico o bisogno PITR -> pensa prima a RMAN / Flashback.
Problema disponibilita sito primary -> pensa prima a Data Guard.
Errore logico replicato -> Data Guard non basta, serve Flashback/RMAN/clone.
```

### 2. Data Guard in una frase

Data Guard mantiene una o piu copie fisiche o logiche del database sincronizzate tramite redo. Serve per alta disponibilita, disaster recovery e offload read/backup, ma non e' una macchina del tempo per errori logici: se fai `DROP TABLE` sul primary, il redo del drop arriva anche allo standby.

### 3. Differenza chiave: physical recovery vs role transition

| Tema | RMAN | Data Guard |
|---|---|---|
| Scopo | ripristinare dati/file nel tempo | mantenere un database secondario pronto |
| Granularita | blocco, datafile, tablespace, PDB, database, tabella | database/ruolo primary-standby |
| Protegge da storage loss | si, se backup buoni | si, se standby sano |
| Protegge da errore umano | si, con PITR/Flashback/RECOVER TABLE | no, errore logico viene replicato |
| Riduce RTO | dipende da restore size | si, con switchover/failover |
| Richiede test restore | sempre | sempre, con DR drill |

### 4. Come scegliere in 60 secondi

```text
1. Il database e' down per perdita sito? -> Data Guard failover.
2. Il database e' down per file perso/corrotto? -> RMAN restore/recover mirato.
3. Una tabella e' stata cancellata? -> Flashback Drop, poi RMAN RECOVER TABLE/PITR.
4. Un DELETE/UPDATE errato e' stato committato? -> Flashback Query/Table se undo basta, altrimenti RMAN PITR su clone.
5. Lo standby e' in gap? -> Data Guard gap resolution o RMAN incremental roll-forward.
6. Mancano archivelog? -> fermati, verifica backup/copy/offsite prima di cancellare altro.
```

### 5. Concetti RMAN da saper spiegare

| Concetto | Spiegazione semplice |
|---|---|
| Backupset | formato RMAN ottimizzato, contiene blocchi usati, puo' essere compresso/cifrato |
| Image copy | copia fisica datafile, utile per incremental merge |
| Archivelog | redo storico necessario per recovery point-in-time |
| Control file autobackup | ancora di salvezza se perdi control file/SPFILE |
| Incarnation | storia del database dopo `OPEN RESETLOGS` |
| Recovery catalog | repository centrale metadata RMAN, utile in enterprise |
| Validate | prova leggibilita backup/file senza restore reale |
| Preview | mostra cosa servira' al restore |
| BMR | block media recovery, ripara blocchi corrotti senza full restore |
| TSPITR | point-in-time recovery di tablespace con auxiliary instance |
| PDB PITR | recovery puntuale di un PDB in CDB |

### 6. Concetti Data Guard da saper spiegare

| Concetto | Spiegazione semplice |
|---|---|
| Redo transport | invio redo dal primary allo standby |
| Redo apply | applicazione redo sullo standby fisico |
| RFS | processo standby che riceve redo |
| MRP0 | managed recovery process che applica redo |
| Standby redo log | redo log lato standby per real-time apply |
| FAL | fetch archive log per recuperare gap |
| Switchover | cambio ruolo pianificato, senza perdita dati se tutto sano |
| Failover | promozione emergenziale dello standby |
| Reinstate | rientro del vecchio primary come standby dopo failover |
| FSFO | failover automatico con broker/observer |
| Snapshot standby | standby temporaneamente aperto read-write per test, poi riconvertito |

### 7. Frasi corrette in ambiente bancario

- "Prima di agire salvo evidence: alert log, RMAN log, DGMGRL output, SCN, stato backup e stato standby."
- "Non cancello archivelog finche non so se servono a recovery, Data Guard o GoldenGate."
- "Data Guard riduce RTO, RMAN garantisce recuperabilita storica: servono entrambi."
- "Lo switchover e' manutenzione controllata; il failover e' procedura di emergenza."
- "Il restore non testato non e' una garanzia, e' solo una speranza."

### 8. Errori da evitare

| Errore | Perche' e' grave |
|---|---|
| Fare failover per un errore logico | lo standby contiene lo stesso errore |
| Aprire RESETLOGS senza decisione formale | cambia incarnation e impatta recovery strategy |
| Cancellare archivelog per liberare FRA senza check | puoi distruggere la possibilita di recovery |
| Non testare wallet TDE | backup cifrato inutilizzabile in emergenza |
| Non misurare RTO/RPO | promesse non dimostrabili in audit |
| Confondere apply lag con transport lag | diagnosi sbagliata tra rete e apply |

### 9. Mini storytelling tecnico

Quando spieghi un incidente, usa questa struttura:

```text
Sintomo: cosa e' successo.
Impatto: chi e' fermo e quale dato e' a rischio.
Diagnosi: file/processo/redo/standby coinvolto.
Decisione: RMAN, Flashback, Data Guard o combinazione.
Esecuzione: comandi con log salvato.
Validazione: query tecniche e smoke test applicativo.
Prevenzione: cosa cambia per evitare ricorrenza.
```

---

## Come usare questo documento

- Se il database e' caduto o non apre: parti dalle sezioni RMAN fisiche.
- Se qualcuno ha cancellato dati o tabelle: parti dagli scenari Flashback/RMAN PITR.
- Se il primary e' perso o isolato: parti dagli scenari Data Guard failover.
- Se lo standby e' in ritardo o bloccato: parti dagli scenari gap/apply/transport.
- Se hai dubbi tra RMAN e Data Guard: usa la matrice decisionale.

---

## Regola bancaria fondamentale

In produzione critica non si sceglie il comando piu veloce, si sceglie il comando piu sicuro rispetto a RPO, RTO, compliance, audit, possibilita di rollback e impatto applicativo.

```text
RMAN      = protezione backup/recovery fisica e point-in-time.
Flashback = correzione veloce se preparato prima e se retention basta.
Data Guard = disponibilita e disaster recovery fisico, non protezione dagli errori logici replicati.
Data Pump  = migrazione/logical refresh, non sostituisce RMAN per recovery.
GoldenGate = replica logica/eterogenea, non sostituisce Data Guard fisico.
```

---

## Matrice decisionale rapida

| Problema | Prima scelta | Alternativa | Nota critica |
|---|---|---|---|
| Istanza crash, file sani | restart instance/RAC | Data Guard se storage perso | nessun PITR richiesto |
| Datafile perso | RMAN restore/recover datafile | restore da snapshot storage validata | serve archivelog |
| Blocco corrotto | RMAN Block Media Recovery | restore datafile | downtime minimo |
| DROP TABLE recente | Flashback Drop | RMAN RECOVER TABLE / PITR | recycle bin deve essere disponibile |
| TRUNCATE o DELETE massivo | Flashback Table/Query | RMAN RECOVER TABLE / TSPITR | dipende da undo/backup |
| DROP USER CASCADE | RMAN PITR su clone + export/import | full DB PITR | non usare Data Guard: errore gia replicato |
| Primary perso | Data Guard failover | restore RMAN | Data Guard riduce RTO |
| Standby gap grande | incremental roll-forward | apply archivelog manuale | attenzione SCN |
| NOLOGGING su primary | restore affected files / incremental | rebuild standby | standby puo' essere unrecoverable |
| FRA piena | RMAN deletion policy + backup archivelog | aumentare FRA | non cancellare archivelog necessari |

---

## Pre-check universale prima di qualsiasi recovery

```sql
SELECT name, db_unique_name, open_mode, database_role, log_mode, force_logging FROM v$database;
SELECT instance_name, status FROM v$instance;
SELECT file#, name, status FROM v$datafile ORDER BY file#;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT name, value, unit FROM v$dataguard_stats WHERE name IN ('transport lag','apply lag','apply finish time');
```

```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> REPORT NEED BACKUP;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
```

---

## Convenzione dei livelli di severita

| Severita | Significato | Azione |
|---|---|---|
| SEV1 | produzione down o rischio perdita dati | war room, freeze change, backup evidence |
| SEV2 | servizio degradato, standby non sano, lag alto | incident bridge DBA/app/rete/storage |
| SEV3 | problema circoscritto, workaround disponibile | change controllato |
| SEV4 | miglioramento o test | backlog/runbook |

---

## Manuali Oracle usati come riferimento

- Oracle Backup and Recovery User's Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- Oracle Backup and Recovery Reference 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/
- Oracle Flashback and DBPITR 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-performing-flashback-dbpitr.html
- Oracle RMAN TSPITR 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/performing-rman-tspitr.html
- Oracle Data Guard Concepts and Administration 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/
- Data Guard Broker Switchover/Failover 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html
- Data Guard Troubleshooting 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/troubleshooting-oracle-data-guard.html
- Redo Transport Services 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html
- Redo Apply Troubleshooting and Tuning: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/redo-apply-troubleshooting-and-tuning.html

---

## Comandi man utili su Linux

```bash
man rman
man sqlplus
man adrci
man oerr
man tnsping
man find
man rsync
man sha256sum
man date
```

---

## Blocco comune per tutti gli scenari RMAN/Data Guard

Questa sezione sostituisce i blocchi ripetuti dentro ogni caso. Nei singoli scenari restano la decisione rapida e i comandi specifici; prerequisiti, validazione, rischi ed escalation valgono sempre salvo nota contraria.

### Quando usare questi scenari
- Evento reale o errore operativo che impatta disponibilita, consistenza, recovery o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, backup, standby, RAC o CDB/PDB.
- Necessita di decidere rapidamente tra RMAN, Flashback, Data Guard, rebuild standby o failover.

### Decisione rapida comune
- Problema fisico su file, blocchi, control file o SPFILE: parti da RMAN/restore mirato, non da full restore se puoi evitarlo.
- Errore logico come drop, truncate o update sbagliato: valuta prima Flashback; poi RMAN `RECOVER TABLE`, TSPITR o PITR su clone.
- Primary perso o sito indisponibile: usa Data Guard failover solo dopo aver dichiarato RPO/RTO e verificato lag.
- Primary sano ma standby rotto: non fare failover; ripara standby, gap o rebuild.
- Operazione pianificata: preferisci switchover o restore testato, mai improvvisare in produzione.
### Prerequisiti universali
- Backup disponibili e leggibili, archivelog necessari e retention non compromessa.
- Wallet/TDE disponibile se il database o i backup sono cifrati.
- Stato control file, SPFILE/PFILE, recovery catalog e incarnation verificati.
- Spazio sufficiente in FRA, filesystem, ASM e destinazione ausiliaria.
- Alert log, RMAN log e output DGMGRL salvati prima del fix.

### Validazione tecnica universale
```sql
SELECT name, open_mode, database_role, protection_mode FROM v$database;
SELECT instance_name, host_name, status FROM gv$instance;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
```

Per Data Guard:

```sql
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest WHERE dest_id IN (1,2,3);
```

### Criterio PASS universale
- Database, PDB o standby nello stato atteso: `OPEN`, `MOUNT`, `READ ONLY WITH APPLY` o ruolo corretto.
- Nessun errore critico nuovo in alert log/ADRCI.
- Recovery evidence allegata: comandi, timestamp, SCN/time, log RMAN/DGMGRL.
- Smoke test applicativo o query funzionale completata.
- Backup post-recovery pianificato o eseguito quando richiesto.

### Rischi enterprise comuni
- Non cancellare archivelog finche non sai se servono a RMAN, standby, GoldenGate o audit.
- Non fare `OPEN RESETLOGS` senza sapere impatto su incarnation, standby e backup strategy.
- In RAC verifica sempre tutte le istanze e i servizi, non solo il nodo dove stai lavorando.
- In CDB/PDB chiarisci se il recovery e di CDB intero, PDB, tablespace o singola tabella.
- Se il problema e logico e gia replicato, Data Guard da solo non risolve: valuta Flashback/RMAN/clone.

### Escalation universale
- Mancano archivelog o backup: war room DBA/storage/backup immediata.
- Corruzione dizionario, `ORA-00600`, `ORA-07445`, lost write: preparare SR Oracle con IPS package.
- Failover o perdita dati potenziale: decisione formale con owner applicativo e management.
- Wallet/TDE mancante: coinvolgere security/key management prima di tentativi distruttivi.

# Parte 1 - Playbook RMAN, Flashback e Backup/Recovery

## RMAN-P01 - Triage recovery prima di cambiare stato

### Quando usarlo

Usa questo blocco prima di ogni restore o recover. Lo scopo e' capire se il danno
e' logico o fisico, quale RPO e' accettabile e quali backup sono davvero leggibili.

### Procedura

1. Registra impatto, timestamp, database, container e ultimo evento noto buono.
2. Conserva alert log, error stack RMAN e stato storage.
3. Controlla backup, archivelog e preview prima di avviare un restore.
4. Scegli il recupero con blast radius minimo: blocco, file, tablespace, tabella,
   PDB o intero database.

```rman
rman target /

LIST BACKUP SUMMARY;
REPORT SCHEMA;
REPORT NEED BACKUP;
RESTORE DATABASE PREVIEW SUMMARY;
```

### Validazione

Il ticket deve indicare oggetto coinvolto, punto di recovery, backup scelto,
archivelog necessari, rollback e smoke test applicativo.

## RMAN-P02 - Instance crash con storage integro

### Decisione

Un instance crash non richiede automaticamente restore. Se datafile, redo e
controlfile sono integri, Oracle esegue crash recovery applicando redo al riavvio.

```sql
sqlplus / as sysdba

STARTUP;
SELECT instance_name, status, database_status FROM v$instance;
SELECT name, open_mode FROM v$database;
```

Se l'istanza non apre, torna a RMAN-P01 e identifica l'errore fisico reale.

## RMAN-P03 - Perdita SPFILE o controlfile

### Decisione

Per SPFILE e controlfile usa autobackup RMAN. Conserva il `DBID` fuori dal
database: in un disaster recovery puo' essere indispensabile.

```rman
rman target /

SET DBID <dbid>;
STARTUP NOMOUNT;
RESTORE SPFILE FROM AUTOBACKUP;
STARTUP FORCE NOMOUNT;
RESTORE CONTROLFILE FROM AUTOBACKUP;
ALTER DATABASE MOUNT;
```

Completa `RESTORE DATABASE` e `RECOVER DATABASE` soltanto se i datafile lo
richiedono. Un singolo membro controlfile perso va prima ripristinato dalla copia
multiplexed sana, non trattato come perdita totale.

## RMAN-P04 - Perdita datafile o tablespace

### Decisione

Per un file applicativo isola il file, ripristina e applica redo. `SYSTEM`,
`SYSAUX` e `UNDO` richiedono una valutazione piu' prudente e spesso downtime.

```rman
rman target /

SQL "ALTER DATABASE DATAFILE <file_number> OFFLINE";
RESTORE DATAFILE <file_number>;
RECOVER DATAFILE <file_number>;
SQL "ALTER DATABASE DATAFILE <file_number> ONLINE";
```

Per un tablespace usa `RESTORE TABLESPACE <name>` e `RECOVER TABLESPACE <name>`.
Valida alert log e una query funzionale sull'oggetto applicativo coinvolto.

## RMAN-P05 - Corruzione blocchi

### Decisione

Non ripristinare l'intero database per un singolo blocco corrotto. Identifica
file, blocco e oggetto; usa Block Media Recovery quando applicabile.

```rman
rman target /

VALIDATE DATABASE CHECK LOGICAL;
LIST FAILURE;
ADVISE FAILURE;
RECOVER CORRUPTION LIST;
```

```sql
SELECT * FROM v$database_block_corruption;
```

Per errori `ORA-00600`, `ORA-07445`, dizionario o lost write conserva evidenze e
apri SR Oracle prima di modifiche distruttive.

## RMAN-P06 - Errore logico e RECOVER TABLE

### Decisione

Per `DROP TABLE ... PURGE`, `TRUNCATE` o perdita logica limitata valuta prima
Flashback. Se undo o recycle bin non bastano, usa `RECOVER TABLE`: Data Guard non
risolve l'errore logico perche' replica anche la modifica sbagliata.

```rman
rman target /

RECOVER TABLE HR.ORDERS
  UNTIL TIME 'SYSDATE-1'
  AUXILIARY DESTINATION '/u01/rman_table_aux'
  REMAP TABLE 'HR'.'ORDERS':'ORDERS_RECOVERED';

RECOVER TABLE HR.ORDERS OF PLUGGABLE DATABASE APPPDB
  UNTIL SCN <scn_before_error>
  AUXILIARY DESTINATION '/u01/rman_table_aux'
  DATAPUMP DESTINATION '/u01/rman_table_dump'
  DUMP FILE 'orders_recovered.dmp'
  NOTABLEIMPORT;
```

### Guardrail

Il target deve essere locale, aperto read-write e in `ARCHIVELOG`. Servono
backup e archivelog continui, spazio per l'auxiliary database e Data Pump.
`SYS`, `SYSTEM`, `SYSAUX`, physical standby e alcuni oggetti con constraint
nominati non sono supportati. Lo schema target di un remap cross-schema deve
esistere prima del recover.

## RMAN-P07 - Perdita server e restore su nuovo host

### Decisione

Prepara un host compatibile, ripristina wallet TDE se necessario, usa autobackup
per bootstrap e completa restore/recover. Per clone o standby usa `DUPLICATE`
con autenticazione wallet-backed oppure prompt interattivo, mai password negli
argomenti shell.

```rman
rman TARGET /@SOURCE AUXILIARY /@AUX

DUPLICATE TARGET DATABASE TO CLONEDB
  FROM ACTIVE DATABASE
  NOFILENAMECHECK;
```

### Validazione

Verifica ruolo, open mode, incarnation, alert log, servizi e smoke test.

## RMAN-P08 - FRA piena con database bloccato

### Decisione

Con `ORA-00257`, prima misura quota FRA, spazio fisico e file reclaimable.
Non usare `rm` sui file Oracle e non cancellare archivelog alla cieca per eta'.

```sql
SELECT name,
       ROUND(space_limit/1024/1024/1024, 2) AS limit_gb,
       ROUND(space_used/1024/1024/1024, 2) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024, 2) AS reclaimable_gb
FROM   v$recovery_file_dest;

SELECT file_type, percent_space_used, percent_space_reclaimable
FROM   v$recovery_area_usage;
```

```rman
rman target /

SHOW ARCHIVELOG DELETION POLICY;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
DELETE NOPROMPT OBSOLETE;
```

Se Data Guard e' in lag o irraggiungibile, passa a DG-061 prima di eliminare
archivelog.

## Matrice RMAN dei casi secondari

| Sintomo | Playbook | Nota |
| --- | --- | --- |
| Perdita tempfile TEMP | RMAN-P02 | Ricrea tempfile; non e' oggetto di restore RMAN |
| Redo log member perso | RMAN-P02 | Verifica multiplexing e stato gruppo prima di operare |
| Tablespace applicativo perso | RMAN-P04 | Restore e recover mirati |
| Corruzione singolo blocco | RMAN-P05 | Preferisci BMR |
| `DROP`, `TRUNCATE`, `DELETE` errato | RMAN-P06 | Flashback oppure `RECOVER TABLE` |
| Clone preproduzione | RMAN-P07 | `DUPLICATE`, wallet e validazione servizi |
| Backup piece assente | RMAN-P01 | `CROSSCHECK`, `LIST EXPIRED`, verifica storage |
| FRA piena | RMAN-P08 | Verifica Data Guard prima del purge |

# Parte 2 - Playbook Data Guard, Broker, Standby e Disaster Recovery

## DG-P01 - Diagnosi transport lag, apply lag e gap

### Decisione

Separa sempre rete e apply. Sul primary controlla le destinazioni; sullo standby
controlla lag, processi e `v$archive_gap`.

```sql
-- Primary
SELECT dest_id, status, target, error, destination
FROM   v$archive_dest_status
ORDER  BY dest_id;

-- Standby
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;
```

```text
dgmgrl /@RACDB
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE RACDB_STBY;
VALIDATE DATABASE RACDB_STBY;
```

## DG-P02 - Switchover pianificato

### Decisione

Lo switchover e' manutenzione controllata. Eseguilo solo con configurazione
`SUCCESS`, lag accettabile, servizi verificati e rollback documentato.

```text
dgmgrl /@RACDB
SHOW CONFIGURATION;
VALIDATE DATABASE RACDB_STBY;
SWITCHOVER TO RACDB_STBY;
SHOW CONFIGURATION;
```

Valida ruolo database, servizi applicativi e redo transport nel verso opposto.

## DG-P03 - Failover e reinstate

### Decisione

Il failover e' una scelta di emergenza: dichiara perdita dati potenziale secondo
protection mode e lag osservato. Non usarlo per correggere errori logici.
Prima della promozione applica fencing al vecchio primary e allega evidenza:
un timeout di rete non basta a prevenire split-brain.

```text
dgmgrl /@RACDB_STBY
SHOW CONFIGURATION;
FAILOVER TO RACDB_STBY;
SHOW CONFIGURATION;
REINSTATE DATABASE RACDB;
```

Se il reinstate non e' disponibile, verifica Flashback Database; in assenza dei
flashback log necessari ricostruisci il vecchio primary con RMAN Duplicate.

## DG-P04 - Observer e FSFO

La configurazione FSFO e' centralizzata nella
[Fase 4B Observer Server e FSFO](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4B_FSFO_OBSERVER.md).
Usa un host dedicato, wallet SEPS, fase iniziale `OBSERVE ONLY`,
`VALIDATE FAST_START FAILOVER` e servizio `systemd`. Non avviare Observer con
password nella command line.

## DG-061 - Primary FRA piena per standby lag

### Scenario Severity 1

Il primary restituisce `ORA-00257`, la FRA e' al 100% e lo standby non e'
raggiungibile. Gli archivelog accumulati potrebbero essere indispensabili per
colmare il gap quando la rete tornera' disponibile.

### Procedura operativa

1. Registra alert log, spazio reale, destinazioni `MANDATORY`, deletion policy e
   sequenze non ancora spedite o applicate.
2. Preferisci aumento temporaneo della FRA solo con storage realmente
   disponibile oppure backup controllato verso storage alternativo.
3. Elimina soltanto file eleggibili secondo retention e deletion policy.
4. Se il business autorizza il degrado DR e non esiste alternativa, usa
   `DELETE FORCE` per il minimo intervallo necessario e registra le sequenze.

```rman
rman target /

SHOW ARCHIVELOG DELETION POLICY;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
DELETE NOPROMPT OBSOLETE;

-- Ultima scelta autorizzata: ignora la deletion policy.
DELETE FORCE NOPROMPT ARCHIVELOG FROM SEQUENCE <first_sequence>
  UNTIL SEQUENCE <last_sequence> THREAD <thread_number>;
```

### Validazione finale

- Il primary accetta transazioni.
- L'alert log non genera nuovi `ORA-00257`.
- Il ticket contiene sequenze preservate ed eventualmente eliminate.
- Esiste un piano esplicito di riallineamento tramite DG-062.

## DG-062 - Riallineamento standby dopo gap

### Log ancora disponibili

Lascia lavorare FAL oppure copia i log sullo standby e registrali:

```sql
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;
ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

### Log persi

Ferma MRP e usa roll-forward dalla rete:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
```

```rman
rman target /
RECOVER STANDBY DATABASE FROM SERVICE <primary_service>;
```

Se la rete non consente il recupero diretto, crea sul primary un
`BACKUP INCREMENTAL FROM SCN <standby_scn> DATABASE`, trasferiscilo, catalogalo
sullo standby e completa il recover. Ricostruisci lo standby soltanto quando il
roll-forward incrementale non e' praticabile.

### Validazione finale

```sql
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
```

```text
dgmgrl /@RACDB
SHOW CONFIGURATION;
SHOW DATABASE RACDB_STBY;
```

## Matrice Data Guard dei casi secondari

| Sintomo | Playbook | Nota |
| --- | --- | --- |
| Transport destination error | DG-P01 | Controlla rete e `v$archive_dest_status` sul primary |
| Apply lag crescente | DG-P01 | Controlla MRP, I/O standby e workload ADG |
| Archive gap | DG-P01, DG-062 | Interroga `v$archive_gap` sullo standby |
| Switchover manutentivo | DG-P02 | Prima `VALIDATE DATABASE` |
| Primary perso | DG-P03 | Dichiarare RPO osservato |
| Reinstate non disponibile | DG-P03 | Flashback oppure RMAN Duplicate |
| Observer down | DG-P04 | Nessun failover automatico finche' Observer non torna sano |
| FRA primary piena con standby down | DG-061 | Preserva redo prima del purge |

## Validazione finale

- Ruolo database coerente con l'azione eseguita.
- Alert log senza errori bloccanti.
- Backup, archivelog e wallet recuperabili.
- `SHOW CONFIGURATION` coerente con il livello di protezione atteso.
- Smoke test applicativo completato.

## Troubleshooting rapido

Se mancano backup o redo, interrompi le modifiche distruttive, conserva output e
attiva escalation DBA, storage e owner applicativo. Un restore non provato non e'
una strategia di recovery.
