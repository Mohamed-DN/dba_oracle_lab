# SHAMS PROJECT: Data Guard Evidence e Drill Test Book PEYTECH Oracle 19c

## Obiettivo operativo

Raccogliere evidenze ripetibili per setup, switchover, gap, servizi, Observer e
rollback dei blueprint SHAMS PROJECT. Il test book deve essere compilato
durante il change: non e' una checklist da completare a memoria dopo il test.

## Assessment

### Scheda change

| Campo | Valore |
| --- | --- |
| Change ID | `<CHANGE_ID>` |
| Blueprint | `<S1/S2/S3/S4>` |
| Ambiente | `C` |
| Primary iniziale | `M24SHAMSPEC` |
| Standby iniziale | `M24SHAMSSEC` |
| Data e finestra | `<TIMESTAMP>` |
| DBA owner | `<NOME>` |
| Application owner | `<NOME>` |
| Networking | `<NOME>` |
| Security / licensing | `<NOME>` |
| Rollback owner | `<NOME>` |

### Evidence pack minimo

Salva output con timestamp:

```text
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE M24SHAMSPEC;
SHOW DATABASE VERBOSE M24SHAMSSEC;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
VALIDATE NETWORK CONFIGURATION FOR ALL;
```

Sullo standby:

```sql
SELECT database_role, open_mode, protection_mode, switchover_status
FROM v$database;

SELECT name, value, unit
FROM v$dataguard_stats;

SELECT process, status, thread#, sequence#
FROM v$managed_standby;

SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;
```

`V$ARCHIVE_GAP` si interroga sullo standby. Non usarla come query primaria sul
primary.

## Procedura operativa

### Drill 1: preflight e duplicate

| Check | Evidenza | Esito |
| --- | --- | --- |
| DNS e porta `1531/TCP` dai due siti | `tnsping`, `lsnrctl services` | `<OK/KO>` |
| RU Grid e DB Home allineata | `opatch lsinventory` | `<OK/KO>` |
| Password file trasferito senza esposizione | ticket Security | `<OK/KO>` |
| Keystore distribuito se TDE | backup e apertura wallet | `<OK/KO/N.A.>` |
| Auxiliary in `NOMOUNT` | alert log e listener | `<OK/KO>` |
| Duplicate RMAN completato | log RMAN | `<OK/KO>` |
| SRL completi sui due ruoli | query `V$LOG`, `V$STANDBY_LOG` | `<OK/KO>` |
| Redo Apply attivo | `MRP0` | `<OK/KO>` |

### Drill 2: Broker

1. abilita Broker;
2. esegui `SHOW CONFIGURATION`;
3. valida i due database;
4. valida rete e static connect;
5. allega output prima e dopo eventuali correzioni.

Pass criteria:

- Broker `SUCCESS`;
- redo transport e apply senza errori;
- connect identifier raggiungibili dai due siti;
- nessuna password nel log.

### Drill 3: switchover e switchback

1. drena o congela il traffico applicativo secondo il change;
2. verifica Broker `SUCCESS`, lag e readiness;
3. esegui `SWITCHOVER TO M24SHAMSSEC`;
4. verifica ruolo, scrittura `_PRY`, lettura `_RO` se ADG autorizzato e apply;
5. esegui switchback verso `M24SHAMSPEC`;
6. ripeti le verifiche.

Non usare snapshot VM per rollback quando esistono dischi ASM condivisi. Per
un laboratorio distruttivo usa backup fisico consistente a VM spente oppure
ricostruzione documentata.

### Drill 4: interruzione rete Data Guard

Solo in laboratorio o ambiente non produttivo autorizzato:

1. registra interfaccia e regola `tc`;
2. lascia FSFO disabilitato oppure in observe-only, salvo test failover dedicato;
3. introduci latenza o packet loss sulla sola rete DG;
4. osserva transport lag, apply lag e alerting;
5. rimuovi sempre la regola;
6. misura il tempo di riallineamento.

Pass criteria:

- primary resta disponibile;
- lag rientra entro soglia dopo rollback rete;
- nessun gap permanente;
- Broker ritorna `SUCCESS`.

### Drill 5: gap redo

Sul standby:

```sql
SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;
```

Risolvi con escalation progressiva:

1. verifica rete, listener, FRA, FAL e MRP;
2. attendi il recupero automatico FAL se i redo esistono;
3. copia archivelog mancanti con canale controllato e registra:

```sql
ALTER DATABASE REGISTER PHYSICAL LOGFILE '<ARCHIVELOG_PATH>';
```

4. se i redo originali sono persi, ferma MRP e usa RMAN sullo standby:

```rman
RECOVER STANDBY DATABASE FROM SERVICE M24SHAMSPEC_DG;
```

5. se la rete non consente recovery from service, usa incremental
   `FROM SCN` con procedura approvata;
6. ricostruisci lo standby solo come ultima scelta.

Riavvia apply:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

### Drill 6: Active Data Guard e servizi

Esegui soltanto con `<EVIDENZA_LICENZA oppure LAB_PERSONALE>`:

1. apri standby `READ ONLY WITH APPLY`;
2. valida `_PRY` e `_RO`;
3. prova lettura su `_RO`;
4. prova una scrittura controllata e conferma che venga rifiutata;
5. verifica lag durante il carico reporting;
6. ripeti dopo switchover e switchback.

### Drill 7: Observer FSFO

Esegui dopo stabilizzazione seguendo
[Observer FSFO PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

Sequenza:

1. abilita observe-only;
2. esegui `VALIDATE FAST_START FAILOVER`;
3. verifica `SHOW FAST_START FAILOVER` e `SHOW OBSERVER`;
4. prova la perdita del solo host Observer;
5. pianifica il crash o isolamento improvviso del primary in un change separato;
6. valida promozione, servizio applicativo e reinstate.

Un normale `SHUTDOWN IMMEDIATE` non e' un evento FSFO valido per il drill.

## Validazione finale

| Area | Evidenza | Esito |
| --- | --- | --- |
| Setup | log duplicate, parametri, listener | `<OK/KO>` |
| Broker | show e validate | `<OK/KO>` |
| Apply | lag, MRP0, gap | `<OK/KO>` |
| SRL | online group + 1 per thread | `<OK/KO>` |
| Switchover | andata e ritorno | `<OK/KO>` |
| Servizi | `_PRY`, `_RO` se autorizzato | `<OK/KO/N.A.>` |
| Gap drill | riallineamento completato | `<OK/KO>` |
| Observer | observe-only e test approvato | `<OK/KO/N.A.>` |
| Segreti | nessuna password nei log | `<OK/KO>` |

Firme:

| Ruolo | Nome | Firma / ticket |
| --- | --- | --- |
| DBA | `<NOME>` | `<RIFERIMENTO>` |
| Application owner | `<NOME>` | `<RIFERIMENTO>` |
| Networking | `<NOME>` | `<RIFERIMENTO>` |
| Security / licensing | `<NOME>` | `<RIFERIMENTO>` |
| Change manager | `<NOME>` | `<RIFERIMENTO>` |

## Rollback rapido

| Problema | Rollback |
| --- | --- |
| Commit lenti in sync | `MaxPerformance` + `ASYNC` |
| Standby instabile | mantieni primary, preserva redo, sospendi role transition |
| ADG non autorizzato | torna a standby `MOUNTED` con apply |
| Servizio errato | ferma service, correggi role policy, ripeti smoke test |
| Regola chaos rimasta attiva | rimuovi `tc qdisc`, verifica route e lag |
| FSFO genera falsi positivi | torna observe-only o disabilita FSFO |

## Troubleshooting rapido

| Sintomo | Prima azione |
| --- | --- |
| Gap non si chiude | conserva sequence mancanti, verifica FAL e FRA |
| Recovery from service fallisce | password file, TNS, primary raggiungibile, alert log |
| Broker `WARNING` dopo rete ripristinata | `SHOW DATABASE VERBOSE`, lag e connect identifier |
| `_RO` scrivibile | interrompi test e verifica ruolo/alias |
| FSFO non promuove | Observer, target, lag limit, Broker e reachability |
| Vecchio primary torna online dopo failover | applica fencing prima di consentire traffico |
