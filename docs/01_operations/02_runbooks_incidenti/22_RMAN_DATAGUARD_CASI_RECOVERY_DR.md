# Runbook Enterprise: Tutti i Casi RMAN e Data Guard per Recovery, DR e Incidenti

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
# Parte 1 - Scenari RMAN, Flashback e Backup/Recovery

## RMAN-001 - Database crash con istanza non avviabile

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-002 - Instance crash ma storage integro

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-003 - Perdita SPFILE o PFILE

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-004 - Perdita control file singolo multiplexed

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-005 - Perdita di tutti i control file

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-006 - Perdita datafile SYSTEM

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-007 - Perdita datafile SYSAUX

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-008 - Perdita datafile USERS non critico

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-009 - Perdita datafile UNDO

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-010 - Perdita datafile in tablespace applicativa

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-011 - Perdita tempfile TEMP

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-012 - Perdita membro redo log multiplexed

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-013 - Perdita gruppo redo log inattivo

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-014 - Perdita current redo log

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-015 - Corruzione blocco ORA-01578

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> VALIDATE DATABASE CHECK LOGICAL;
RMAN> LIST FAILURE;
RMAN> RECOVER CORRUPTION LIST;
RMAN> RECOVER DATAFILE <file#> BLOCK <block#>;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-016 - Corruzione blocchi rilevata da RMAN VALIDATE

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> VALIDATE DATABASE CHECK LOGICAL;
RMAN> LIST FAILURE;
RMAN> RECOVER CORRUPTION LIST;
RMAN> RECOVER DATAFILE <file#> BLOCK <block#>;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-017 - Corruzione dizionario o SYSTEM tablespace

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-018 - Tabella cancellata con DROP TABLE

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> FLASHBACK TABLE APP.TAB TO BEFORE DROP;

rman target /
RMAN> RECOVER TABLE APP.TAB UNTIL TIME "SYSDATE-1/24" AUXILIARY DESTINATION '/u02/aux';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-019 - Tabella svuotata con TRUNCATE

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-020 - DELETE senza WHERE o update massivo errato

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-021 - DROP USER CASCADE accidentale

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-022 - DROP TABLESPACE accidentale

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> FLASHBACK TABLE APP.TAB TO BEFORE DROP;

rman target /
RMAN> RECOVER TABLE APP.TAB UNTIL TIME "SYSDATE-1/24" AUXILIARY DESTINATION '/u02/aux';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-023 - DROP PDB accidentale

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-024 - PDB corrotto ma CDB sano

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-025 - PDB point-in-time recovery

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-026 - CDB point-in-time recovery

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-027 - TSPITR per tablespace applicativa

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-028 - Recovery di singola tabella con RMAN RECOVER TABLE

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-029 - Restore su nuovo host per test restore evidence

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target sys/<PASSWORD>@SOURCE auxiliary sys/<PASSWORD>@AUX
RMAN> DUPLICATE TARGET DATABASE TO <new_db_name> FROM ACTIVE DATABASE
  SPFILE
  PARAMETER_VALUE_CONVERT ('SOURCE','TARGET')
  SET DB_UNIQUE_NAME='<target_unique_name>'
  NOFILENAMECHECK;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-030 - Duplicate active database per clone preprod

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target sys/<PASSWORD>@SOURCE auxiliary sys/<PASSWORD>@AUX
RMAN> DUPLICATE TARGET DATABASE TO <new_db_name> FROM ACTIVE DATABASE
  SPFILE
  PARAMETER_VALUE_CONVERT ('SOURCE','TARGET')
  SET DB_UNIQUE_NAME='<target_unique_name>'
  NOFILENAMECHECK;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-031 - Duplicate da backup senza connessione source

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target sys/<PASSWORD>@SOURCE auxiliary sys/<PASSWORD>@AUX
RMAN> DUPLICATE TARGET DATABASE TO <new_db_name> FROM ACTIVE DATABASE
  SPFILE
  PARAMETER_VALUE_CONVERT ('SOURCE','TARGET')
  SET DB_UNIQUE_NAME='<target_unique_name>'
  NOFILENAMECHECK;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-032 - Migrazione storage filesystem verso ASM

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-033 - Migrazione host con stesso DB_NAME

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target sys/<PASSWORD>@SOURCE auxiliary sys/<PASSWORD>@AUX
RMAN> DUPLICATE TARGET DATABASE TO <new_db_name> FROM ACTIVE DATABASE
  SPFILE
  PARAMETER_VALUE_CONVERT ('SOURCE','TARGET')
  SET DB_UNIQUE_NAME='<target_unique_name>'
  NOFILENAMECHECK;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-034 - Ripristino con backup controlfile

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-035 - Recovery oltre RESETLOGS precedente

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-036 - Ripristino da incarnation precedente

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-037 - Archivelog mancanti durante recovery

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-038 - FRA piena con database bloccato

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-039 - Backup piece mancante o expired

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-040 - Catalogo RMAN non disponibile

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-041 - Recovery catalog corrotto o perso

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-042 - Control file record keep time insufficiente

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-043 - Backup encrypted con wallet non aperto

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-044 - Backup encrypted password-based

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-045 - TDE wallet perso o non sincronizzato

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-046 - NOARCHIVELOG database crash

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-047 - Backup cold consistente

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-048 - Backup incremental level 0 e level 1

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-049 - Incremental merge image copy

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-050 - Block Change Tracking corrotto

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-051 - Backup su NFS lento o instabile

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-052 - Backup su SBT/tape fallito

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-053 - Canali RMAN insufficienti

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-054 - Bigfile tablespace molto grande

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-055 - Section size per datafile enorme

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-056 - FILESPERSET e MAXPIECESIZE tuning

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-057 - Compressione RMAN e licensing

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-058 - Archivelog deletion policy con Data Guard

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-059 - Backup validate per audit

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> BACKUP VALIDATE CHECK LOGICAL DATABASE;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-060 - Restore validate per audit

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> BACKUP VALIDATE CHECK LOGICAL DATABASE;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-061 - Restore archivelog validate

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-062 - Recover database until time

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-063 - Recover database until SCN

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-064 - Recover database until sequence

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-065 - Restore singolo tablespace

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-066 - Restore singolo datafile online

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-067 - Restore controlfile da autobackup

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-068 - Restore SPFILE da autobackup

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-069 - Lost write detection e recovery

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-070 - NOLOGGING operation da recuperare

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-071 - Schema refresh con Data Pump non sufficiente

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-072 - Ripristino oggetti invalidi post recovery

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-073 - Resync catalog dopo restore

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-074 - Crosscheck dopo cancellazione manuale file

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-075 - Delete obsolete e retention window

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-076 - Report need backup

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-077 - Backup database plus archivelog

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-078 - Backup PDB singolo

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-079 - Restore PDB singolo

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-080 - Clone PDB da backup

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-081 - Ripristino standby tramite RMAN incremental

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-082 - Recovery dopo errore umano con Flashback Database

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-083 - Flashback Table per tabella modificata

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-084 - Flashback Drop da recycle bin

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-085 - Flashback Query per estrazione dati puntuale

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM APP.TAB AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);
SQL> FLASHBACK TABLE APP.TAB TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '30' MINUTE);

rman target /
RMAN> RUN { SET UNTIL TIME "TO_DATE('2026-05-27 10:00:00','YYYY-MM-DD HH24:MI:SS')"; RESTORE DATABASE; RECOVER DATABASE; }
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-086 - PITR con tabella senza recycle bin

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-087 - PITR con vincoli cross-tablespace

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> OFFLINE';
RMAN> RESTORE DATAFILE <file#>;
RMAN> RECOVER DATAFILE <file#>;
RMAN> SQL 'ALTER DATABASE DATAFILE <file#> ONLINE';
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-088 - Restore su ambiente isolato per forensics

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-089 - Validazione checksum backup offsite

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-090 - Restore da backup copiati manualmente

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-091 - Catalog start with per backup non catalogati

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-092 - RMAN in RAC con backup locale non condiviso

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-093 - RMAN in RAC con canali su istanze diverse

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-094 - Ripristino dopo patch fallita

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-095 - Rollback applicativo con guaranteed restore point

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-096 - DR test annuale con misurazione RTO/RPO

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-097 - Emergenza ORA-19809 FRA limit exceeded

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-098 - Emergenza ORA-01113 file needs media recovery

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-099 - Emergenza RMAN-06059 archivelog expected not found

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## RMAN-100 - Emergenza ORA-19504 failed to create file

Dominio: RMAN
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: RMAN / Flashback / SQL*Plus

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il problema e fisico, preferire restore/recover mirato prima del full restore.
- Se il problema e logico, valutare prima Flashback; poi RMAN RECOVER TABLE, TSPITR o PITR su clone.
- Non fare RESETLOGS o PITR senza approvazione e restore point/evidence se la produzione e coinvolta.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
rman target /
RMAN> LIST BACKUP SUMMARY;
RMAN> REPORT SCHEMA;
RMAN> RESTORE DATABASE PREVIEW SUMMARY;
RMAN> RESTORE DATABASE VALIDATE;
RMAN> RECOVER DATABASE;
```

### Validazione tecnica
```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT file#, error, change#, time FROM v$recover_file ORDER BY file#;
SELECT * FROM v$database_block_corruption;
SELECT file_type, percent_space_used, percent_space_reclaimable FROM v$recovery_area_usage;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Backup and Recovery User's Guide 19c, Backup and Recovery Reference 19c, Flashback/TSPITR chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

# Parte 2 - Scenari Data Guard, Broker, Standby e Disaster Recovery

## DG-001 - Creazione physical standby da active duplicate

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-002 - Creazione physical standby da backup

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-003 - Configurazione Data Guard Broker

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-004 - Primary database down totale

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-005 - Failover manuale a standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-006 - Switchover pianificato

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-007 - Reinstate failed primary con flashback

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-008 - Recreate failed primary senza flashback

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-009 - Fast-Start Failover con observer

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-010 - Observer down o isolato

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-011 - Maximum Performance baseline

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-012 - Maximum Availability con SYNC AFFIRM

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-013 - Maximum Protection e rischio stall primary

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-014 - Cambio protection mode

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-015 - Redo transport destination error

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-016 - ORA-12514 listener non conosce service

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-017 - ORA-12154 TNS resolution

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-018 - Password file mismatch primary standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-019 - DB_UNIQUE_NAME errato

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-020 - LOG_ARCHIVE_CONFIG errata

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-021 - FAL_SERVER o FAL_CLIENT errati

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-022 - Archive gap su physical standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-023 - V$ARCHIVE_GAP non vuoto

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-024 - Archivelog mancante sul primary

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-025 - Manual gap resolution

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-026 - Standby apply lag crescente

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-027 - Transport lag crescente

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-028 - Redo apply tuning

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-029 - Standby redo logs mancanti

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-030 - Standby redo logs dimensione errata

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-031 - RFS non riceve redo

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-032 - MRP0 non parte

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-033 - MRP0 WAIT_FOR_GAP

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-034 - Apply bloccato da NOLOGGING operation

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-035 - Standby unrecoverable datafile

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-036 - Roll-forward standby con incremental from SCN

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

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

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-037 - Standby datafile missing

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-038 - Standby controlfile da ricreare

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-039 - Standby database corruption

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-040 - Primary lost write rilevato da standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-041 - Standby snapshot per test applicativi

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO SNAPSHOT STANDBY;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO PHYSICAL STANDBY;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-042 - Convert snapshot standby back to physical

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO SNAPSHOT STANDBY;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO PHYSICAL STANDBY;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-043 - Active Data Guard read only with apply

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-044 - Query reporting su standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-045 - Standby services per read-only workload

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-046 - Role-based services con srvctl

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-047 - RAC primary e RAC standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-048 - Switchover con RAC

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-049 - Failover con RAC

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-050 - Broker warning ORA-168xx

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-051 - DGMGRL status non SUCCESS

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-052 - Validate database broker

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-053 - Static listener per broker

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-054 - Redo routes e cascaded standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-055 - Cascading standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-056 - Far Sync instance

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-057 - Zero data loss planning

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-058 - Network partition e split brain prevention

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-059 - Primary isolato ma ancora aperto

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-060 - Standby FRA piena

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-061 - Primary FRA piena per standby lag

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-062 - RMAN archivelog deletion policy in Data Guard

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-063 - Backup su standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-064 - Restore primary usando backup standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-065 - Offload backup to standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-066 - TDE wallet su primary e standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-067 - PDB creation replicated to standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-068 - PDB open mode dopo switchover

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-069 - Data Guard con CDB/PDB

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-070 - Data Guard rolling upgrade

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-071 - DBMS_ROLLING overview

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-072 - Patch GI/DB con standby disponibile

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-073 - Application connection string dopo role transition

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-074 - Service relocation dopo switchover

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-075 - Standby rebuild completo

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-076 - Broker configuration file perso

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-077 - Config drift tra init parameters

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-078 - Archive destination mandatory bloccante

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-079 - Alternate archive destination

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-080 - Standby in recovery ma lag zero

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-081 - Data Guard health check giornaliero

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-082 - Data Guard disaster recovery drill

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-083 - Data Guard failback dopo failover

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-084 - Switchover status NOT ALLOWED

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE VERBOSE <standby_db_unique_name>;
DGMGRL> SWITCHOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-085 - Flashback standby dopo errore operativo

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-086 - Logical corruption replicata allo standby

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-087 - Errore umano: tabella cancellata con Data Guard attivo

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-088 - Standby non protegge da DROP TABLE replicato

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-089 - Quando usare RMAN invece di Data Guard

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-090 - Quando usare Flashback invece di failover

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@STANDBY
DGMGRL> SHOW CONFIGURATION;
DGMGRL> FAILOVER TO <standby_db_unique_name>;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> REINSTATE DATABASE <old_primary_db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-091 - Quando usare Snapshot Standby invece di clone

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO SNAPSHOT STANDBY;
DGMGRL> SHOW CONFIGURATION;
DGMGRL> CONVERT DATABASE <standby_db_unique_name> TO PHYSICAL STANDBY;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-092 - Quando usare GoldenGate invece di Data Guard

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-093 - Data Guard in cloud/on-prem hybrid

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-094 - Latency alta tra regioni

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-095 - SYNC vs ASYNC decisione bancaria

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-096 - FSFO falso positivo da rete instabile

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-097 - Data Guard broker disabilitato temporaneamente

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION VERBOSE;
DGMGRL> SHOW DATABASE VERBOSE <db_unique_name>;
DGMGRL> VALIDATE DATABASE VERBOSE <db_unique_name>;
DGMGRL> SHOW DATABASE <db_unique_name> STATUSREPORT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-098 - Redo transport compression e encryption

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-099 - Data Guard dopo resetlogs

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT database_role, open_mode, switchover_status FROM v$database;
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;

dgmgrl sys/<PASSWORD>@PRIMARY
DGMGRL> SHOW CONFIGURATION;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-100 - Gap dopo manutenzione lunga

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT * FROM v$archive_gap;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> ALTER DATABASE REGISTER PHYSICAL LOGFILE '<archivelog_path>';
SQL> ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

## DG-101 - Apply parallelism e performance

Dominio: DATA_GUARD
Severita tipica: SEV1/SEV2 se produzione impattata; SEV3 se test controllato.
Tool primario: Data Guard Broker / SQL*Plus / RMAN

### Quando succede
- Evento reale o errore operativo che impatta disponibilita, consistenza o protezione del database.
- Possibile coinvolgimento di storage, rete, redo, archivelog, FRA, standby, utente applicativo o change fallito.
- In banca considerare subito impatto su RPO/RTO, audit, customer impact e data integrity.

### Decisione rapida
- Se il primary e sano, evitare failover: preferire switchover o riparazione standby.
- Se il primary e perso, failover controllato con Broker e validazione servizi.
- Ricordare che Data Guard replica anche errori logici: DROP TABLE e DELETE errati arrivano allo standby.

### Prerequisiti da verificare
- Backup disponibili, archivelog necessari, wallet/TDE disponibile se usato.
- Stato del control file, recovery catalog e retention policy.
- Spazio in FRA, filesystem backup, ASM, auxiliary destination.
- Stato applicativo: sessioni attive, job batch, servizi RAC, listener e connessioni client.
- Approvazione change/incident commander se si tratta di produzione.

### Comandi base
```bash
sqlplus / as sysdba
SQL> SELECT name, value, unit FROM v$dataguard_stats;
SQL> SELECT process, status, thread#, sequence# FROM v$managed_standby;
SQL> SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;

DGMGRL> SHOW DATABASE <db_unique_name>;
```

### Validazione tecnica
```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT dest_id, status, error FROM v$archive_dest_status ORDER BY dest_id;
```

### Criterio PASS
- Database o standby nello stato atteso.
- Nessun errore critico in alert log/ADR.
- Backup/recovery evidence allegata al ticket.
- Query applicativa di smoke test eseguita.
- RPO/RTO misurati e comunicati.

### Rischi e note enterprise
- Evitare comandi distruttivi senza copia dell evidenza corrente.
- Non cancellare archivelog finche non sai se servono a RMAN, standby o GoldenGate.
- In RAC verificare se il problema e locale a un nodo o comune a tutto il cluster.
- Con TDE verificare wallet/keystore prima del restore.
- Con CDB/PDB verificare container corrente e servizi applicativi.

### Escalation
- Se mancano archivelog o backup, aprire immediatamente war room DBA/storage/backup.
- Se ci sono errori ORA-00600/ORA-07445/corruzioni dizionario, preparare SR Oracle.
- Se coinvolge dati cliente o PII, coinvolgere security/compliance secondo policy.

### Riferimenti
- Oracle Data Guard Concepts and Administration 19c, Broker guide, troubleshooting and redo transport chapters.
- Collegare sempre alert log, RMAN log, DGMGRL output e query di validazione al ticket.

---

# Appendice finale - Checklist unica incident RMAN + Data Guard

```text
[ ] Identificato tipo incidente: fisico, logico, rete, storage, standby, utente.
[ ] Congelati change non necessari.
[ ] Salvato alert log e trace principali.
[ ] Salvato output RMAN LIST BACKUP SUMMARY.
[ ] Salvato SHOW CONFIGURATION Data Guard se presente.
[ ] Verificato se Data Guard replica l'errore logico.
[ ] Verificato se Flashback e' disponibile e retention sufficiente.
[ ] Verificato se serve restore su clone prima di agire in produzione.
[ ] Definito RPO/RTO realistico.
[ ] Comunicata decisione a incident commander.
[ ] Eseguito comando recovery con log completo.
[ ] Validato database, servizi, applicazione e standby.
[ ] Allegata evidence al ticket.
[ ] Pianificata root cause e prevenzione.
```

## Fonti ufficiali principali

- Oracle Backup and Recovery User's Guide 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- Oracle Backup and Recovery Reference 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/
- RMAN Flashback and DBPITR: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-performing-flashback-dbpitr.html
- RMAN TSPITR: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/performing-rman-tspitr.html
- Oracle Data Guard Concepts and Administration 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/
- Data Guard Broker switchover/failover: https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html
- Data Guard troubleshooting: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/troubleshooting-oracle-data-guard.html
- Redo transport services: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html
- Redo apply troubleshooting and tuning: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/redo-apply-troubleshooting-and-tuning.html
