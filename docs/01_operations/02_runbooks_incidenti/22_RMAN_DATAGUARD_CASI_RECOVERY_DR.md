# Runbook Enterprise: Tutti i Casi RMAN e Data Guard per Recovery, DR e Incidenti

<!-- RUNBOOK_NAV_START -->
## Indice operativo rapido

### Casi piu frequenti da aprire prima
- [Database crash con istanza non avviabile](#rman-001---database-crash-con-istanza-non-avviabile)
- [Instance crash ma storage integro](#rman-002---instance-crash-ma-storage-integro)
- [Tabella cancellata con DROP TABLE](#rman-018---tabella-cancellata-con-drop-table)
- [DELETE senza WHERE o update massivo errato](#rman-020---delete-senza-where-o-update-massivo-errato)
- [Corruzione blocco ORA-01578](#rman-015---corruzione-blocco-ora-01578)
- [Recovery di singola tabella con RMAN RECOVER TABLE](#rman-028---recovery-di-singola-tabella-con-rman-recover-table)
- [Duplicate active database per clone preprod](#rman-030---duplicate-active-database-per-clone-preprod)
- [Primary database down totale](#dg-004---primary-database-down-totale)
- [Failover manuale a standby](#dg-005---failover-manuale-a-standby)
- [Switchover pianificato](#dg-006---switchover-pianificato)
- [Archive gap su physical standby](#dg-022---archive-gap-su-physical-standby)
- [Standby apply lag crescente](#dg-026---standby-apply-lag-crescente)
- [MRP0 non parte](#dg-032---mrp0-non-parte)
- [Roll-forward standby con incremental from SCN](#dg-036---roll-forward-standby-con-incremental-from-scn)

### Macro-aree
- [Spiegazione didattica](#spiegazione-didattica-come-raccontare-rman-e-data-guard)
- [Matrice decisionale rapida](#matrice-decisionale-rapida)
- [Pre-check universale](#pre-check-universale-prima-di-qualsiasi-recovery)
- [Blocco comune per tutti gli scenari](#blocco-comune-per-tutti-gli-scenari-rmandata-guard)
- [Parte 1 - Scenari RMAN, Flashback e Backup/Recovery](#parte-1---scenari-rman-flashback-e-backuprecovery)
- [Parte 2 - Scenari Data Guard, Broker, Standby e Disaster Recovery](#parte-2---scenari-data-guard-broker-standby-e-disaster-recovery)

### Come spiegare il documento
Parti sempre dal danno reale: indisponibilita, perdita dati logica, corruzione fisica, gap Data Guard o richiesta di clone. Poi dichiara RTO/RPO, verifica backup e archivelog, scegli tra RMAN, Flashback, Data Guard o rebuild, e chiudi con evidenze di validazione.
<!-- RUNBOOK_NAV_END -->

> Documento operativo per DBA Oracle 19c in ambienti critici. Copre scenari RMAN, Flashback, Data Guard, Broker, RAC, CDB/PDB, incidenti logici, crash fisici, errori umani, gap redo, failover e switchover. Il focus e' decisionale: quale tecnologia usare, quando usarla, quali comandi lanciare, come validare e quali rischi evitare.

---

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

# Parte 1 - Scenari RMAN, Flashback e Backup/Recovery

## RMAN-001 - Database crash con istanza non avviabile

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-002 - Instance crash ma storage integro

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-003 - Perdita SPFILE o PFILE

### Comandi base
```bash
rman target /
RMAN> SET DBID <DBID>;
RMAN> STARTUP NOMOUNT;
RMAN> RESTORE SPFILE FROM AUTOBACKUP;
RMAN> RESTORE CONTROLFILE FROM AUTOBACKUP;
RMAN> ALTER DATABASE MOUNT;
RMAN> RECOVER DATABASE;
```

## RMAN-004 - Perdita control file singolo multiplexed

### Comandi base
```bash
rman target /
RMAN> SET DBID <DBID>;
RMAN> STARTUP NOMOUNT;
RMAN> RESTORE SPFILE FROM AUTOBACKUP;
RMAN> RESTORE CONTROLFILE FROM AUTOBACKUP;
RMAN> ALTER DATABASE MOUNT;
RMAN> RECOVER DATABASE;
```

## RMAN-005 - Perdita di tutti i control file

### Comandi base
```bash
rman target /
RMAN> SET DBID <DBID>;
RMAN> STARTUP NOMOUNT;
RMAN> RESTORE SPFILE FROM AUTOBACKUP;
RMAN> RESTORE CONTROLFILE FROM AUTOBACKUP;
RMAN> ALTER DATABASE MOUNT;
RMAN> RECOVER DATABASE;
```

## RMAN-006 - Perdita datafile SYSTEM

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-007 - Perdita datafile SYSAUX

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-008 - Perdita datafile USERS non critico

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-009 - Perdita datafile UNDO

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-010 - Perdita datafile in tablespace applicativa

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-011 - Perdita tempfile TEMP

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-012 - Perdita membro redo log multiplexed

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-013 - Perdita gruppo redo log inattivo

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-014 - Perdita current redo log

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-015 - Corruzione blocco ORA-01578

### Comandi base
```bash
rman target /
RMAN> VALIDATE DATABASE CHECK LOGICAL;
RMAN> LIST FAILURE;
RMAN> RECOVER CORRUPTION LIST;
RMAN> RECOVER DATAFILE <file#> BLOCK <block#>;
```

## RMAN-016 - Corruzione blocchi rilevata da RMAN VALIDATE

### Comandi base
```bash
rman target /
RMAN> VALIDATE DATABASE CHECK LOGICAL;
RMAN> LIST FAILURE;
RMAN> RECOVER CORRUPTION LIST;
RMAN> RECOVER DATAFILE <file#> BLOCK <block#>;
```

## RMAN-017 - Corruzione dizionario o SYSTEM tablespace

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-018 - Tabella cancellata con DROP TABLE

### Comandi base
```bash
sqlplus / as sysdba
SQL> FLASHBACK TABLE APP.TAB TO BEFORE DROP;

rman target /
RMAN> RECOVER TABLE APP.TAB UNTIL TIME "SYSDATE-1/24" AUXILIARY DESTINATION '/u02/aux';
```

## RMAN-019 - Tabella svuotata con TRUNCATE

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

## RMAN-020 - DELETE senza WHERE o update massivo errato

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

## RMAN-021 - DROP USER CASCADE accidentale

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-022 - DROP TABLESPACE accidentale

### Comandi base
```bash
sqlplus / as sysdba
SQL> FLASHBACK TABLE APP.TAB TO BEFORE DROP;

rman target /
RMAN> RECOVER TABLE APP.TAB UNTIL TIME "SYSDATE-1/24" AUXILIARY DESTINATION '/u02/aux';
```

## RMAN-023 - DROP PDB accidentale

### Comandi base
```bash
rman target /
RMAN> RUN {
  ALTER PLUGGABLE DATABASE <pdb_name> CLOSE;
  SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE <pdb_name>;
  RECOVER PLUGGABLE DATABASE <pdb_name>;
  ALTER PLUGGABLE DATABASE <pdb_name> OPEN RESETLOGS;
}
```

## RMAN-024 - PDB corrotto ma CDB sano

### Comandi base
```bash
rman target /
RMAN> RUN {
  ALTER PLUGGABLE DATABASE <pdb_name> CLOSE;
  SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE <pdb_name>;
  RECOVER PLUGGABLE DATABASE <pdb_name>;
  ALTER PLUGGABLE DATABASE <pdb_name> OPEN RESETLOGS;
}
```

## RMAN-025 - PDB point-in-time recovery

### Comandi base
```bash
rman target /
RMAN> RUN {
  ALTER PLUGGABLE DATABASE <pdb_name> CLOSE;
  SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE <pdb_name>;
  RECOVER PLUGGABLE DATABASE <pdb_name>;
  ALTER PLUGGABLE DATABASE <pdb_name> OPEN RESETLOGS;
}
```

## RMAN-026 - CDB point-in-time recovery

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-027 - TSPITR per tablespace applicativa

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-028 - Recovery di singola tabella con RMAN RECOVER TABLE

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-029 - Restore su nuovo host per test restore evidence

### Comandi base
```bash
rman target sys/<PASSWORD>@SOURCE auxiliary sys/<PASSWORD>@AUX
RMAN> DUPLICATE TARGET DATABASE TO <new_db_name> FROM ACTIVE DATABASE
  SPFILE
  PARAMETER_VALUE_CONVERT ('SOURCE','TARGET')
  SET DB_UNIQUE_NAME='<target_unique_name>'
  NOFILENAMECHECK;
```

## RMAN-030 - Duplicate active database per clone preprod

### Comandi base
```bash
rman target sys/<PASSWORD>@SOURCE auxiliary sys/<PASSWORD>@AUX
RMAN> DUPLICATE TARGET DATABASE TO <new_db_name> FROM ACTIVE DATABASE
  SPFILE
  PARAMETER_VALUE_CONVERT ('SOURCE','TARGET')
  SET DB_UNIQUE_NAME='<target_unique_name>'
  NOFILENAMECHECK;
```

## RMAN-031 - Duplicate da backup senza connessione source

### Comandi base
```bash
rman target sys/<PASSWORD>@SOURCE auxiliary sys/<PASSWORD>@AUX
RMAN> DUPLICATE TARGET DATABASE TO <new_db_name> FROM ACTIVE DATABASE
  SPFILE
  PARAMETER_VALUE_CONVERT ('SOURCE','TARGET')
  SET DB_UNIQUE_NAME='<target_unique_name>'
  NOFILENAMECHECK;
```

## RMAN-032 - Migrazione storage filesystem verso ASM

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-033 - Migrazione host con stesso DB_NAME

### Comandi base
```bash
rman target sys/<PASSWORD>@SOURCE auxiliary sys/<PASSWORD>@AUX
RMAN> DUPLICATE TARGET DATABASE TO <new_db_name> FROM ACTIVE DATABASE
  SPFILE
  PARAMETER_VALUE_CONVERT ('SOURCE','TARGET')
  SET DB_UNIQUE_NAME='<target_unique_name>'
  NOFILENAMECHECK;
```

## RMAN-034 - Ripristino con backup controlfile

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-035 - Recovery oltre RESETLOGS precedente

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-036 - Ripristino da incarnation precedente

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-037 - Archivelog mancanti durante recovery

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-038 - FRA piena con database bloccato

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-039 - Backup piece mancante o expired

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-040 - Catalogo RMAN non disponibile

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-041 - Recovery catalog corrotto o perso

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-042 - Control file record keep time insufficiente

### Comandi base
```bash
rman target /
RMAN> SET DBID <DBID>;
RMAN> STARTUP NOMOUNT;
RMAN> RESTORE SPFILE FROM AUTOBACKUP;
RMAN> RESTORE CONTROLFILE FROM AUTOBACKUP;
RMAN> ALTER DATABASE MOUNT;
RMAN> RECOVER DATABASE;
```

## RMAN-043 - Backup encrypted con wallet non aperto

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-044 - Backup encrypted password-based

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-045 - TDE wallet perso o non sincronizzato

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-046 - NOARCHIVELOG database crash

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-047 - Backup cold consistente

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-048 - Backup incremental level 0 e level 1

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-049 - Incremental merge image copy

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-050 - Block Change Tracking corrotto

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-051 - Backup su NFS lento o instabile

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-052 - Backup su SBT/tape fallito

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-053 - Canali RMAN insufficienti

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-054 - Bigfile tablespace molto grande

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-055 - Section size per datafile enorme

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-056 - FILESPERSET e MAXPIECESIZE tuning

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-057 - Compressione RMAN e licensing

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-058 - Archivelog deletion policy con Data Guard

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-059 - Backup validate per audit

### Comandi base
```bash
rman target /
RMAN> BACKUP VALIDATE CHECK LOGICAL DATABASE;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
```

## RMAN-060 - Restore validate per audit

### Comandi base
```bash
rman target /
RMAN> BACKUP VALIDATE CHECK LOGICAL DATABASE;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
```

## RMAN-061 - Restore archivelog validate

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-062 - Recover database until time

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-063 - Recover database until SCN

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-064 - Recover database until sequence

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-065 - Restore singolo tablespace

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-066 - Restore singolo datafile online

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-067 - Restore controlfile da autobackup

### Comandi base
```bash
rman target /
RMAN> SET DBID <DBID>;
RMAN> STARTUP NOMOUNT;
RMAN> RESTORE SPFILE FROM AUTOBACKUP;
RMAN> RESTORE CONTROLFILE FROM AUTOBACKUP;
RMAN> ALTER DATABASE MOUNT;
RMAN> RECOVER DATABASE;
```

## RMAN-068 - Restore SPFILE da autobackup

### Comandi base
```bash
rman target /
RMAN> SET DBID <DBID>;
RMAN> STARTUP NOMOUNT;
RMAN> RESTORE SPFILE FROM AUTOBACKUP;
RMAN> RESTORE CONTROLFILE FROM AUTOBACKUP;
RMAN> ALTER DATABASE MOUNT;
RMAN> RECOVER DATABASE;
```

## RMAN-069 - Lost write detection e recovery

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-070 - NOLOGGING operation da recuperare

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-071 - Schema refresh con Data Pump non sufficiente

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-072 - Ripristino oggetti invalidi post recovery

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-073 - Resync catalog dopo restore

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-074 - Crosscheck dopo cancellazione manuale file

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-075 - Delete obsolete e retention window

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

## RMAN-076 - Report need backup

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-077 - Backup database plus archivelog

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-078 - Backup PDB singolo

### Comandi base
```bash
rman target /
RMAN> RUN {
  ALTER PLUGGABLE DATABASE <pdb_name> CLOSE;
  SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE <pdb_name>;
  RECOVER PLUGGABLE DATABASE <pdb_name>;
  ALTER PLUGGABLE DATABASE <pdb_name> OPEN RESETLOGS;
}
```

## RMAN-079 - Restore PDB singolo

### Comandi base
```bash
rman target /
RMAN> RUN {
  ALTER PLUGGABLE DATABASE <pdb_name> CLOSE;
  SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE <pdb_name>;
  RECOVER PLUGGABLE DATABASE <pdb_name>;
  ALTER PLUGGABLE DATABASE <pdb_name> OPEN RESETLOGS;
}
```

## RMAN-080 - Clone PDB da backup

### Comandi base
```bash
rman target /
RMAN> RUN {
  ALTER PLUGGABLE DATABASE <pdb_name> CLOSE;
  SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE PLUGGABLE DATABASE <pdb_name>;
  RECOVER PLUGGABLE DATABASE <pdb_name>;
  ALTER PLUGGABLE DATABASE <pdb_name> OPEN RESETLOGS;
}
```

## RMAN-081 - Ripristino standby tramite RMAN incremental

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-082 - Recovery dopo errore umano con Flashback Database

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

## RMAN-083 - Flashback Table per tabella modificata

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

## RMAN-084 - Flashback Drop da recycle bin

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

## RMAN-085 - Flashback Query per estrazione dati puntuale

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

## RMAN-086 - PITR con tabella senza recycle bin

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-087 - PITR con vincoli cross-tablespace

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

## RMAN-088 - Restore su ambiente isolato per forensics

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-089 - Validazione checksum backup offsite

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-090 - Restore da backup copiati manualmente

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-091 - Catalog start with per backup non catalogati

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-092 - RMAN in RAC con backup locale non condiviso

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-093 - RMAN in RAC con canali su istanze diverse

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-094 - Ripristino dopo patch fallita

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-095 - Rollback applicativo con guaranteed restore point

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-096 - DR test annuale con misurazione RTO/RPO

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## RMAN-097 - Emergenza ORA-19809 FRA limit exceeded

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-098 - Emergenza ORA-01113 file needs media recovery

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-099 - Emergenza RMAN-06059 archivelog expected not found

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$recovery_area_usage;
SQL> ALTER SYSTEM SET db_recovery_file_dest_size=<new_size> SCOPE=BOTH;

rman target /
RMAN> CROSSCHECK ARCHIVELOG ALL;
RMAN> BACKUP ARCHIVELOG ALL DELETE INPUT;
RMAN> DELETE NOPROMPT OBSOLETE;
```

## RMAN-100 - Emergenza ORA-19504 failed to create file

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

## DG-001 - Creazione physical standby da active duplicate

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-002 - Creazione physical standby da backup

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-003 - Configurazione Data Guard Broker

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

## DG-004 - Primary database down totale

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

## DG-005 - Failover manuale a standby

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

## DG-006 - Switchover pianificato

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

## DG-007 - Reinstate failed primary con flashback

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-008 - Recreate failed primary senza flashback

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-009 - Fast-Start Failover con observer

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

## DG-010 - Observer down o isolato

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-011 - Maximum Performance baseline

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-012 - Maximum Availability con SYNC AFFIRM

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-013 - Maximum Protection e rischio stall primary

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-014 - Cambio protection mode

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-015 - Redo transport destination error

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-016 - ORA-12514 listener non conosce service

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-017 - ORA-12154 TNS resolution

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-018 - Password file mismatch primary standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-019 - DB_UNIQUE_NAME errato

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-020 - LOG_ARCHIVE_CONFIG errata

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-021 - FAL_SERVER o FAL_CLIENT errati

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-022 - Archive gap su physical standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-023 - V$ARCHIVE_GAP non vuoto

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-024 - Archivelog mancante sul primary

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-025 - Manual gap resolution

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-026 - Standby apply lag crescente

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-027 - Transport lag crescente

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-028 - Redo apply tuning

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-029 - Standby redo logs mancanti

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-030 - Standby redo logs dimensione errata

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-031 - RFS non riceve redo

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-032 - MRP0 non parte

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-033 - MRP0 WAIT_FOR_GAP

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-034 - Apply bloccato da NOLOGGING operation

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-035 - Standby unrecoverable datafile

### Comandi base
```bash
-- On standby
SQL> SELECT current_scn FROM v$database;

-- On primary, create incremental from standby SCN
rman target /
RMAN> BACKUP INCREMENTAL FROM SCN <standby_scn> DATABASE FORMAT '/tmp/for_standby_%U';

-- On standby
RMAN> CATALOG START WITH '/tmp/';
RMAN> RECOVER DATABASE NOREDO;
```

## DG-036 - Roll-forward standby con incremental from SCN

### Comandi base
```bash
-- On standby
SQL> SELECT current_scn FROM v$database;

-- On primary, create incremental from standby SCN
rman target /
RMAN> BACKUP INCREMENTAL FROM SCN <standby_scn> DATABASE FORMAT '/tmp/for_standby_%U';

-- On standby
RMAN> CATALOG START WITH '/tmp/';
RMAN> RECOVER DATABASE NOREDO;
```

## DG-037 - Standby datafile missing

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-038 - Standby controlfile da ricreare

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-039 - Standby database corruption

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-040 - Primary lost write rilevato da standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-041 - Standby snapshot per test applicativi

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO SNAPSHOT STANDBY;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO PHYSICAL STANDBY;
```

## DG-042 - Convert snapshot standby back to physical

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO SNAPSHOT STANDBY;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO PHYSICAL STANDBY;
```

## DG-043 - Active Data Guard read only with apply

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-044 - Query reporting su standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-045 - Standby services per read-only workload

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-046 - Role-based services con srvctl

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-047 - RAC primary e RAC standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-048 - Switchover con RAC

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

## DG-049 - Failover con RAC

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

## DG-050 - Broker warning ORA-168xx

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

## DG-051 - DGMGRL status non SUCCESS

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

## DG-052 - Validate database broker

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

## DG-053 - Static listener per broker

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

## DG-054 - Redo routes e cascaded standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-055 - Cascading standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-056 - Far Sync instance

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-057 - Zero data loss planning

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-058 - Network partition e split brain prevention

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-059 - Primary isolato ma ancora aperto

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-060 - Standby FRA piena

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-061 - Primary FRA piena per standby lag

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-062 - RMAN archivelog deletion policy in Data Guard

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-063 - Backup su standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-064 - Restore primary usando backup standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-065 - Offload backup to standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-066 - TDE wallet su primary e standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-067 - PDB creation replicated to standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-068 - PDB open mode dopo switchover

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

## DG-069 - Data Guard con CDB/PDB

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-070 - Data Guard rolling upgrade

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-071 - DBMS_ROLLING overview

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-072 - Patch GI/DB con standby disponibile

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-073 - Application connection string dopo role transition

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-074 - Service relocation dopo switchover

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

## DG-075 - Standby rebuild completo

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-076 - Broker configuration file perso

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

## DG-077 - Config drift tra init parameters

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-078 - Archive destination mandatory bloccante

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-079 - Alternate archive destination

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-080 - Standby in recovery ma lag zero

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-081 - Data Guard health check giornaliero

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-082 - Data Guard disaster recovery drill

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-083 - Data Guard failback dopo failover

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

## DG-084 - Switchover status NOT ALLOWED

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

## DG-085 - Flashback standby dopo errore operativo

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-086 - Logical corruption replicata allo standby

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-087 - Errore umano: tabella cancellata con Data Guard attivo

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-088 - Standby non protegge da DROP TABLE replicato

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-089 - Quando usare RMAN invece di Data Guard

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-090 - Quando usare Flashback invece di failover

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

## DG-091 - Quando usare Snapshot Standby invece di clone

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO SNAPSHOT STANDBY;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO PHYSICAL STANDBY;
```

## DG-092 - Quando usare GoldenGate invece di Data Guard

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-093 - Data Guard in cloud/on-prem hybrid

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-094 - Latency alta tra regioni

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-095 - SYNC vs ASYNC decisione bancaria

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-096 - FSFO falso positivo da rete instabile

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-097 - Data Guard broker disabilitato temporaneamente

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

## DG-098 - Redo transport compression e encryption

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

## DG-099 - Data Guard dopo resetlogs

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

## DG-100 - Gap dopo manutenzione lunga

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

## DG-101 - Apply parallelism e performance

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```
