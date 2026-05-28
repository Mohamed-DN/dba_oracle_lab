# 31 - GoldenGate Incident Runbook

<!-- READY_SCRIPTS_START -->
## Script e guide collegati

- [Cheat Sheet GoldenGate](../01_cheat_sheets/CS_GOLDENGATE.md)
- [GoldenGate 19c completa](../../02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_19C_COMPLETA.md)
- [Runbook End-to-End GoldenGate 19c](../../02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_RUNBOOK_END_TO_END_19C.md)
- [GoldenGate ambienti critici](../../02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md)
<!-- READY_SCRIPTS_END -->

## Casi frequenti

- Extract, Pump o Replicat in `ABENDED`.
- Lag alto ma processi `RUNNING`.
- Trail pieno o filesystem GoldenGate pieno.
- Capture ferma per archive log mancanti.
- Replicat fermo per errore dati, constraint, mapping o privileges.
- Dopo failover Data Guard il capture punta al database sbagliato.
- Microservices UI raggiungibile ma processi non partono.

## Triage rapido

Da host GoldenGate:

```bash
ggsci
info all
send extract EXT1, status
send replicat REP1, status
lag extract EXT1
lag replicat REP1
view report EXT1
view report REP1
```

Microservices:

```bash
adminclient
connect https://gg-host:9001 deployment DEP1 as ggadmin password <password>
info all
info extract EXT1 detail
info replicat REP1 detail
```

OS:

```bash
df -h
du -sh $GG_HOME $OGG_VAR_HOME 2>/dev/null
ps -ef | egrep "mgr|extract|replicat|ServiceManager" | grep -v grep
```

## Se un processo e ABENDED

Leggere report e ggserr:

```bash
ggsci
view report EXT1
view ggsevt
```

oppure:

```bash
tail -200 $OGG_HOME/ggserr.log
find $OGG_VAR_HOME -name "*.rpt" -mtime -2 -type f -ls
```

Classifica errore:

| Sintomo | Possibile causa | Prima azione |
|---|---|---|
| `OGG-01296`, login DB | password/credential store/servizio DB | test `dblogin` |
| `OGG-00446`, archive missing | retention archive insufficiente | verificare RMAN/FRA, ripristinare archivelog |
| `OGG-01028`, mapping | tabella non presente o map errato | confrontare DDL e param file |
| ORA-00001 su Replicat | record gia presente | capire se conflict o restart non idempotente |
| ORA-01403 su Replicat | delete/update senza riga target | verificare consistenza source/target |
| Trail read error | trail corrotto o cancellato | stop, backup evidence, valutare reposition |

## Test connessione DB

Classic:

```bash
ggsci
dblogin useridalias ggadmin_src
info trandata SCHEMA.TABLE
```

SQL:

```sql
select supplemental_log_data_min, force_logging from v$database;
select username, account_status, lock_date, expiry_date from dba_users where username='GGADMIN';
select name, open_mode, database_role from v$database;
```

## Lag alto

Misurare dove nasce il lag:

```bash
ggsci
info all
lag extract EXT1
lag extract PUMP1
lag replicat REP1
send extract EXT1, showtrans
send replicat REP1, status
```

DB source:

```sql
select inst_id, event, count(*)
from gv$session
where username = 'GGADMIN'
group by inst_id, event
order by count(*) desc;

select thread#, sequence#, first_time, next_time, archived, applied
from v$archived_log
where first_time > sysdate - 1
order by thread#, sequence#;
```

Cause tipiche:

- transazione enorme aperta sul source;
- I/O lento su trail;
- network lento tra source e target;
- Replicat seriale su workload che richiede parallelismo;
- target con lock o indice mancante;
- statistiche target non aggiornate.

Interventi:

```bash
send extract EXT1, showtrans
send extract EXT1, cachemgr cachestats
send replicat REP1, status
stats replicat REP1, latest
```

Non aumentare parallelismo o cambiare parametri in produzione senza baseline e rollback.

## Archive mancanti per Extract

Verificare retention:

```sql
select sequence#, first_time, next_time, name
from v$archived_log
where first_time > sysdate - 3
order by sequence#;
```

Se l'archive manca:

1. Cercare backup RMAN.
2. Ripristinare archivelog sul path atteso o registrarlo.
3. Solo se approvato, valutare riposizionamento Extract con perdita controllata o reinstantiate.

RMAN esempio:

```rman
run {
  set archivelog destination to '/u99/restore_arch';
  restore archivelog from sequence 12345 thread 1;
}
```

## Replicat con errore dati

Non usare `HANDLECOLLISIONS` come fix permanente. Prima capire se e fase di initial load, resync o vera divergenza.

Raccogli:

```bash
view report REP1
stats replicat REP1, latest
info replicat REP1 detail
```

SQL target:

```sql
select owner, table_name, constraint_name, constraint_type, status
from dba_constraints
where owner='APP' and table_name='ORDERS';

select count(*) from app.orders where id = :id;
```

Opzioni:

- fix dati puntuale con approvazione applicativa;
- skip transazione solo se business accetta perdita/duplicazione;
- resync tabella con Data Pump e SCN coerente;
- rebuild Replicat checkpoint dopo backup dei checkpoint.

## Filesystem trail pieno

```bash
df -h
du -sh dirdat dirrpt dirchk dirpcs 2>/dev/null
find dirdat -type f -mtime +7 -ls | head
```

Non cancellare trail se un Replicat/Pump potrebbe doverli leggere.

Verifica checkpoint:

```bash
info extract PUMP1 detail
info replicat REP1 detail
```

Pulizia corretta: usare `PURGEOLDEXTRACTS` nei parametri, con retention allineata a SLA e recovery.

## Dopo failover Data Guard

Verificare role e service:

```sql
select name, database_role, open_mode, switchover_status from v$database;
```

GoldenGate deve puntare a un service role-based, non a hostname fisso.

Azioni:

1. Fermare processi GoldenGate.
2. Validare nuovo primary e archive availability.
3. Testare `dblogin`.
4. Avviare Extract solo dopo conferma SCN/checkpoint.
5. Monitorare lag e report.

## Validazione finale

```bash
ggsci
info all
lag extract EXT1
lag replicat REP1
stats extract EXT1, latest
stats replicat REP1, latest
```

SQL heartbeat se configurato:

```sql
select * from ggadmin.gg_heartbeat order by heartbeat_timestamp desc fetch first 10 rows only;
```

## Evidence ticket

```text
Deployment:
Processi coinvolti:
Sintomo:
Report/ggserr:
Lag iniziale:
Trail e checkpoint:
Errore DB:
Fix applicato:
Lag finale:
Rischio residuo:
```
