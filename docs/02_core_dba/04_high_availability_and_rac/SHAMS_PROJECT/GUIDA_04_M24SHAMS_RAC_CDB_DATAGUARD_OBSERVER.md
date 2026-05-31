# SHAMS PROJECT S4: M24SHAMS RAC CDB Data Guard e Observer

## Obiettivo operativo

Creare il blueprint enterprise preferito per nuovi database: RAC Oracle 19c a
due nodi, CDB con PDB applicativo, physical standby RAC, Broker, Active Data
Guard, servizi PDB role-based e Observer FSFO.

Usa la [baseline comune](./GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md),
l'[allegato host RAC](./GUIDA_07_HOST_RAC_GRID_ASM_19C.md) e la guida
[Observer FSFO](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

## Architettura

```text
PE RAC primary                              SE RAC physical standby
M24SHAMSPEC                                 M24SHAMSSEC
CDB M24SHAMS                               CDB M24SHAMS
PDB M24SHAMSC_APP                          PDB M24SHAMSC_APP
M24SHAMS1  M24SHAMS2                       M24SHAMS1  M24SHAMS2
THREAD 1    THREAD 2                       SRL T1      SRL T2
SCAN + ASM                                 SCAN + ASM
service M24SHAMSC_PRY                      service M24SHAMSC_RO
```

La role transition coinvolge l'intera CDB. I PDB non hanno un ruolo Data Guard
indipendente.

## Prerequisiti

| Gate | Valore |
| --- | --- |
| Blueprint | `S4` |
| Cluster PE e SE | `<OK/KO>` |
| SCAN | `<PRIMARY_SCAN>` / `<STANDBY_SCAN>` |
| PDB applicativo | `M24SHAMSC_APP` |
| Local undo PDB | `<SI/NO - decisione>` |
| Active Data Guard | `<EVIDENZA LICENZA>` |
| TDE | `<SI/NO - decisione Security>` |

## Procedura operativa

### 1. Creazione RAC CDB primary

Con DBCA:

1. `Create Database`;
2. `Advanced Configuration`;
3. RAC administrator-managed, due nodi;
4. `DB_NAME=M24SHAMS`;
5. seleziona `Create as Container database`;
6. crea PDB `M24SHAMSC_APP`;
7. seleziona local undo se richiesto dallo standard;
8. ASM OMF `+M24SHAMS_DATA`, FRA `+M24SHAMS_FRA`;
9. `ARCHIVELOG`;
10. genera script, esegui review e avvia la creazione controllata.

Verifica:

```sql
SELECT name, cdb, db_unique_name, open_mode, database_role
FROM v$database;

SELECT inst_id, instance_name, host_name, thread#, status
FROM gv$instance
ORDER BY inst_id;

SELECT con_id, name, open_mode
FROM v$pdbs
ORDER BY con_id;
```

### 2. Logging, redo e SRL

Applica la baseline PEYTECH:

- `ARCHIVELOG`;
- `FORCE LOGGING`;
- FRA e OMF;
- `STANDBY_FILE_MANAGEMENT=AUTO`;
- quattro online redo group da `4G` per thread come punto di partenza;
- almeno cinque SRL da `4G` per thread su primary e standby.

Non copiare sizing senza misurare redo e log switch.

### 3. Standby RAC CDB

Configura Net, password file e TDE. Se TDE e' attivo, distribuisci il keystore
prima del duplicate.

Avvia una sola auxiliary instance sul cluster SE:

```text
db_name='M24SHAMS'
db_unique_name='M24SHAMSSEC'
cluster_database=FALSE
db_create_file_dest='+M24SHAMS_DATA'
db_recovery_file_dest='+M24SHAMS_FRA'
```

Esegui:

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

Dopo duplicate abilita `cluster_database=TRUE`, registra entrambe le istanze
SE e valida SRL per thread 1 e 2.

### 4. PDB su Data Guard

Oracle crea un physical standby CDB come un normale standby, ma devi
considerare PDB e servizi.

Per PDB nuove create dal seed:

```sql
CREATE PLUGGABLE DATABASE M24SHAMSC_TEST
  ADMIN USER pdbadmin IDENTIFIED BY "<PASSWORD_INTERATTIVA>"
  STANDBYS=ALL;

ALTER PLUGGABLE DATABASE M24SHAMSC_TEST OPEN INSTANCES=ALL;
ALTER PLUGGABLE DATABASE M24SHAMSC_TEST SAVE STATE INSTANCES=ALL;
```

`STANDBYS=ALL` e' il default, ma dichiararlo rende il change leggibile. Per
clone remoto, plugin XML o esclusioni selettive, pianifica una procedura
separata: possono servire `ENABLED_PDBS_ON_STANDBY`,
`STANDBY_PDB_SOURCE_FILE_DBLINK` o copia file preventiva.

### 5. Active Data Guard e servizi PDB RAC

Apri standby `READ ONLY WITH APPLY`, poi verifica:

```sql
SELECT open_mode, database_role FROM v$database;

SELECT con_id, name, open_mode
FROM v$pdbs
ORDER BY con_id;

SELECT con_id, name, network_name
FROM cdb_services
ORDER BY con_id, name;
```

Servizi:

```text
M24SHAMSC_PRY -> PDB M24SHAMSC_APP, role PRIMARY, preferred istanze PE
M24SHAMSC_RO  -> PDB M24SHAMSC_APP, role PHYSICAL_STANDBY, preferred istanze SE
```

Non usare il service di default della CDB per l'applicazione.

### 6. Broker, switchover e Observer

Configura Broker e valida entrambi i database:

```text
SHOW CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
```

Durante switchover verifica:

1. ruolo CDB;
2. open mode PDB;
3. servizio `_PRY` sul nuovo primary;
4. servizio `_RO` sul nuovo standby;
5. apply su una sola istanza standby RAC.

Dopo stabilizzazione attiva FSFO seguendo
[Observer FSFO PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

## Validazione finale

| Check | Esito |
| --- | --- |
| RAC due nodi nei due siti | `<OK/KO>` |
| CDB `M24SHAMS`, PDB `M24SHAMSC_APP` | `<OK/KO>` |
| thread 1 e 2 con SRL completi | `<OK/KO>` |
| standby `READ ONLY WITH APPLY` | `<OK/KO>` |
| service PDB `_PRY` e `_RO` | `<OK/KO>` |
| Broker `SUCCESS` | `<OK/KO>` |
| switchover CDB e switchback | `<OK/KO>` |
| RMAN standby nel catalogo | `<OK/KO>` |
| Observer FSFO e auto-reinstate | `<OK/KO>` |

## Troubleshooting rapido

| Sintomo | Azione |
| --- | --- |
| PDB non compare sullo standby | verifica apply, `STANDBYS` e alert log |
| PDB compare ma service RAC no | controlla `-pdb`, role e preferred instances |
| apply thread 2 fermo | verifica SRL thread 2 e stato cluster |
| duplicate TDE fallisce | distribuisci keystore root/PDB sul cluster SE |
| failover CDB ma PDB chiusa | verifica saved state e startup service |
