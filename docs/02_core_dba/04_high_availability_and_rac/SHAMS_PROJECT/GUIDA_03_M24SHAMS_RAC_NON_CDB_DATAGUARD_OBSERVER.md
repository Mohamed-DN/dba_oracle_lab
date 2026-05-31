# SHAMS PROJECT S3: M24SHAMS RAC Non-CDB Data Guard e Observer

## Obiettivo operativo

Creare un RAC Oracle 19c non-CDB a due nodi in PE e un physical standby RAC a
due nodi in SE, con ASM, Broker, Active Data Guard, servizi role-based e
Observer FSFO.

Usa la [baseline comune](./GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md) e
l'[allegato host RAC](./GUIDA_07_HOST_RAC_GRID_ASM_19C.md). Per nuove
installazioni valuta prima il blueprint
[S4 RAC CDB](./GUIDA_04_M24SHAMS_RAC_CDB_DATAGUARD_OBSERVER.md): non-CDB e'
supportato in 19c ma deprecato.

## Architettura

```text
PE RAC primary                            SE RAC physical standby
M24SHAMSPEC                               M24SHAMSSEC
M24SHAMS1  M24SHAMS2                      M24SHAMS1  M24SHAMS2
THREAD 1    THREAD 2                      SRL T1      SRL T2
SCAN + ASM                                SCAN + ASM
```

## Prerequisiti

| Gate | Valore |
| --- | --- |
| Blueprint | `S3` |
| Cluster PE e SE | `<OK/KO>` |
| Nodi per sito | `2` |
| SCAN PE / SE | `<PRIMARY_SCAN>` / `<STANDBY_SCAN>` |
| RU allineata | `<RU_APPROVATA>` |
| Active Data Guard | `<EVIDENZA LICENZA>` |
| TDE | `<SI/NO - decisione Security>` |

## Procedura operativa

### 1. Creazione RAC primary

Con DBCA dal DB Home:

1. `Create Database`;
2. `Advanced Configuration`;
3. Oracle RAC administrator-managed a due nodi;
4. `DB_NAME=M24SHAMS`;
5. non selezionare CDB;
6. ASM OMF `+M24SHAMS_DATA`, FRA `+M24SHAMS_FRA`;
7. `ARCHIVELOG`;
8. `Generate Database Creation Scripts`, review ed esecuzione.

Verifica:

```sql
SELECT name, cdb, db_unique_name, log_mode, force_logging
FROM v$database;

SELECT inst_id, instance_name, host_name, thread#, status
FROM gv$instance
ORDER BY inst_id;
```

### 2. Parametri RAC e Data Guard

Classifica i parametri:

```text
Globali:     db_name, db_unique_name, cluster_database, storage, DG
Per istanza: instance_number, thread, undo_tablespace, local_listener
Cluster:     remote_listener, SCAN, servizi, policy
```

Imposta:

```sql
ALTER DATABASE FORCE LOGGING;
ALTER SYSTEM SET db_unique_name='M24SHAMSPEC' SCOPE=SPFILE SID='*';
ALTER SYSTEM SET db_create_file_dest='+M24SHAMS_DATA' SCOPE=BOTH SID='*';
ALTER SYSTEM SET db_recovery_file_dest='+M24SHAMS_FRA' SCOPE=BOTH SID='*';
ALTER SYSTEM SET db_recovery_file_dest_size=<FRA_BYTES> SCOPE=BOTH SID='*';
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_config=
  'DG_CONFIG=(M24SHAMSPEC,M24SHAMSSEC)' SCOPE=BOTH SID='*';
```

### 3. Redo e SRL per thread

Ogni istanza primary usa un thread. Con quattro online redo group da `4G` per
thread crea almeno cinque SRL da `4G` per thread su primary e standby.

```sql
SELECT thread#, group#, bytes / 1024 / 1024 AS mb, status
FROM v$log
ORDER BY thread#, group#;

SELECT thread#, group#, bytes / 1024 / 1024 AS mb, status
FROM v$standby_log
ORDER BY thread#, group#;
```

Esempio per gruppi liberi:

```sql
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 11 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 12 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 13 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 14 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 15 SIZE 4G;

ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 21 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 22 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 23 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 24 SIZE 4G;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 25 SIZE 4G;
```

### 4. Duplicate standby RAC

Configura static listener e alias DG verso endpoint approvati. Sullo standby
avvia una sola auxiliary instance in `NOMOUNT` con
`cluster_database=FALSE`.

```bash
rman target sys@M24SHAMSPEC_DG auxiliary sys@M24SHAMSSEC_DG
```

```rman
RUN {
  DUPLICATE TARGET DATABASE
    FOR STANDBY
    FROM ACTIVE DATABASE
    DORECOVER
    SPFILE
      SET db_unique_name='M24SHAMSSEC'
      SET cluster_database='FALSE'
      SET db_create_file_dest='+M24SHAMS_DATA'
      SET db_recovery_file_dest='+M24SHAMS_FRA'
      SET db_recovery_file_dest_size='<FRA_BYTES>'
      SET fal_server='M24SHAMSPEC_DG'
      SET standby_file_management='AUTO'
    NOFILENAMECHECK;
}
```

Dopo duplicate:

1. imposta `cluster_database=TRUE`;
2. registra database e istanze standby con `srvctl`;
3. aggiungi l'istanza nodo 2;
4. avvia apply su una sola istanza standby;
5. crea o valida SRL per entrambi i thread.

### 5. Servizi RAC role-based

```text
M24SHAMSC_PRY -> role PRIMARY, preferred instances del cluster primary
M24SHAMSC_RO  -> role PHYSICAL_STANDBY, preferred instances standby ADG
```

Verifica:

```bash
srvctl config database -db M24SHAMSPEC
srvctl config service -db M24SHAMSPEC
srvctl status service -db M24SHAMSPEC
crsctl stat res -t
```

### 6. Broker e Observer

Configura Broker usando gli alias DG, valida entrambi i database e prova
switchover/switchback. In RAC e' normale che `MRP0` sia attivo su una sola
istanza standby.

Dopo stabilizzazione usa
[Observer FSFO PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md). Testa anche:

- perdita di un nodo RAC senza failover Data Guard;
- indisponibilita' completa del sito primary con promozione standby;
- ripartenza servizi SCAN e role-based.

## Validazione finale

| Check | Esito |
| --- | --- |
| due istanze PE e due istanze SE | `<OK/KO>` |
| thread 1 e 2 online | `<OK/KO>` |
| cinque SRL per thread o sizing approvato | `<OK/KO>` |
| apply su una sola istanza standby | `<OK/KO>` |
| SCAN e servizi role-based | `<OK/KO>` |
| Broker `SUCCESS` | `<OK/KO>` |
| switchover e switchback | `<OK/KO>` |
| failover nodo singolo senza DG failover | `<OK/KO>` |
| Observer FSFO | `<OK/KO>` |

## Troubleshooting rapido

| Sintomo | Azione |
| --- | --- |
| redo thread 2 non applicato | verifica SRL thread 2 e stato istanza nodo 2 |
| auxiliary RAC non parte | avvia una sola istanza con `cluster_database=FALSE` |
| servizio non segue ruolo | controlla `srvctl config service` e role policy |
| nodo RAC cade e FSFO scatta | correggi soglie e reachability: il cluster locale deve gestire il nodo |
| SCAN non raggiungibile dall'Observer | valida DNS, listener e endpoint DG |
