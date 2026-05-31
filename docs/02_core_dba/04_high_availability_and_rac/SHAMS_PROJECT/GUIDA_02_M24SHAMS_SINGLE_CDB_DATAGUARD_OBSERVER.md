# SHAMS PROJECT S2: M24SHAMS Single Instance CDB Data Guard e Observer

## Obiettivo operativo

Creare un database Oracle 19c CDB single instance con PDB applicativo,
physical standby, Data Guard Broker, Active Data Guard e Observer FSFO.

Usa prima la [baseline comune](./GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md) e
l'[allegato host single](./GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md).
FSFO viene attivato dopo stabilizzazione tramite
[Observer PEYTECH](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

## Architettura

```text
PE primary                              SE physical standby
M24SHAMSPEC                             M24SHAMSSEC
CDB M24SHAMS                            CDB M24SHAMS
PDB M24SHAMSC_APP                       PDB M24SHAMSC_APP
Oracle Restart + ASM                    Oracle Restart + ASM
M24SHAMSC_PRY                           M24SHAMSC_RO
```

Data Guard protegge l'intera CDB. Uno switchover o failover modifica il ruolo
della CDB, non di una singola PDB.

## Prerequisiti

| Gate | Valore |
| --- | --- |
| Blueprint | `S2` |
| Host guide completata | `<OK/KO>` |
| Licenza Active Data Guard | `<EVIDENZA>` |
| PDB name | `M24SHAMSC_APP` |
| Local undo | `<SI/NO - decisione>` |
| TDE | `<SI/NO - decisione Security>` |
| RMAN catalog | `<RMAN_CATALOG_TNS>` |

## Procedura operativa

### 1. Creazione primary CDB

Con DBCA scegli:

1. `Create a database`;
2. `Advanced configuration`;
3. single instance;
4. Global Database Name `M24SHAMSPEC` oppure
   `M24SHAMSPEC.<DB_DOMAIN>` se previsto;
5. SID `M24SHAMSPEC`;
6. in `All Initialization Parameters` verifica o imposta
   `DB_NAME=M24SHAMS` e `DB_UNIQUE_NAME=M24SHAMSPEC`, includendoli nello
   SPFILE;
7. `Create as Container database`;
8. una PDB iniziale `M24SHAMSC_APP`;
9. ASM OMF su `+M24SHAMS_DATA`;
10. FRA su `+M24SHAMS_FRA`;
11. `ARCHIVELOG`;
12. `Generate Database Creation Scripts`, review ed esecuzione controllata.

DBCA crea solo il primary PE. Il physical standby SE mantiene
`DB_NAME=M24SHAMS`, ma usa `DB_UNIQUE_NAME=M24SHAMSSEC` e SID
locale auxiliary `M24SHAMSSEC` durante il duplicate RMAN. Per verificare ogni
scelta GUI usa la
[matrice campi DBCA](./GUIDA_08_DBCA_GUI_FIELD_MATRIX_PEYTECH_19C.md).

Verifica:

```sql
SELECT name, cdb, db_unique_name, open_mode, database_role
FROM v$database;

SELECT con_id, name, open_mode, restricted
FROM v$pdbs
ORDER BY con_id;
```

Atteso: `NAME=M24SHAMS`, `CDB=YES`, `DB_UNIQUE_NAME=M24SHAMSPEC`, SID
`M24SHAMSPEC` e PDB `M24SHAMSC_APP` aperta `READ WRITE`.

### 2. Parametri e logging

Da `CDB$ROOT`:

```sql
ALTER DATABASE FORCE LOGGING;

ALTER SYSTEM SET db_unique_name='M24SHAMSPEC' SCOPE=SPFILE;
ALTER SYSTEM SET db_create_file_dest='+M24SHAMS_DATA' SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest='+M24SHAMS_FRA' SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest_size=<FRA_BYTES> SCOPE=BOTH;
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH;
ALTER SYSTEM SET log_archive_config=
  'DG_CONFIG=(M24SHAMSPEC,M24SHAMSSEC)' SCOPE=BOTH;
```

Se necessario abilita `ARCHIVELOG` a database montato.

### 3. Redo, SRL, Net e TDE

Per single instance usa solo `THREAD 1`. Applica sizing e query della baseline.
Con quattro online redo group da `4G`, predisponi almeno cinque SRL da `4G` su
primary e standby.

Configura alias e static listener:

```text
M24SHAMSPEC_DG -> <PRIMARY_DG_FQDN>:1531
M24SHAMSSEC_DG -> <STANDBY_DG_FQDN>:1531
```

Se TDE e' richiesto, distribuisci il keystore allo standby prima del duplicate
e verifica root e PDB.

### 4. RMAN duplicate dello standby

Avvia auxiliary `M24SHAMSSEC` in `NOMOUNT`, quindi usa prompt interattivo:

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
      SET db_create_file_dest='+M24SHAMS_DATA'
      SET db_recovery_file_dest='+M24SHAMS_FRA'
      SET db_recovery_file_dest_size='<FRA_BYTES>'
      SET log_archive_config='DG_CONFIG=(M24SHAMSPEC,M24SHAMSSEC)'
      SET fal_server='M24SHAMSPEC_DG'
      SET standby_file_management='AUTO'
    NOFILENAMECHECK;
}
```

Usa `NOFILENAMECHECK` solo su storage realmente separato.

### 5. PDB e Active Data Guard

Apri lo standby:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE OPEN READ ONLY;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

SELECT open_mode, database_role FROM v$database;
SELECT con_id, name, open_mode FROM v$pdbs ORDER BY con_id;
```

Atteso: CDB `READ ONLY WITH APPLY`. Apri la PDB in lettura se previsto dal
servizio reporting.

Per PDB create successivamente, il default `STANDBYS=ALL` replica su tutti gli
standby. Dichiaralo comunque nei change importanti:

```sql
CREATE PLUGGABLE DATABASE M24SHAMSC_TEST
  ADMIN USER pdbadmin IDENTIFIED BY "<PASSWORD_INTERATTIVA>"
  STANDBYS=ALL;
```

Non inserire password reali nei file di script versionati.

### 6. Servizi role-based

Configura servizi legati alla PDB:

```text
M24SHAMSC_PRY -> PDB M24SHAMSC_APP, role PRIMARY
M24SHAMSC_RO  -> PDB M24SHAMSC_APP, role PHYSICAL_STANDBY
```

Verifica:

```sql
SELECT con_id, name, network_name
FROM cdb_services
ORDER BY con_id, name;
```

### 7. Broker, switchover e Observer

Configura Broker:

```text
CREATE CONFIGURATION M24SHAMS_DG AS
  PRIMARY DATABASE IS M24SHAMSPEC
  CONNECT IDENTIFIER IS M24SHAMSPEC_DG;

ADD DATABASE M24SHAMSSEC AS
  CONNECT IDENTIFIER IS M24SHAMSSEC_DG
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
```

Esegui switchover e switchback. Dopo stabilizzazione completa
l'[Observer FSFO](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

## Validazione finale

| Check | Esito |
| --- | --- |
| primary e standby `CDB=YES` | `<OK/KO>` |
| PDB `M24SHAMSC_APP` presente nei due siti | `<OK/KO>` |
| standby `READ ONLY WITH APPLY` | `<OK/KO>` |
| service `_PRY` e `_RO` role-based | `<OK/KO>` |
| SRL completi su entrambi i ruoli | `<OK/KO>` |
| Broker `SUCCESS` | `<OK/KO>` |
| switchover CDB e switchback | `<OK/KO>` |
| RMAN standby nel catalogo | `<OK/KO>` |
| Observer FSFO validato | `<OK/KO>` |

## Troubleshooting rapido

| Sintomo | Azione |
| --- | --- |
| PDB assente sullo standby | verifica `STANDBYS`, apply e alert log |
| PDB presente ma service assente | controlla PDB open state e `CDB_SERVICES` |
| Clone PDB complesso | valida requisiti ADG, DB link o copia file prima del change |
| Duplicate fallisce con TDE | distribuisci e apri keystore root/PDB |
| Switchover riuscito ma app non connette | verifica servizio `_PRY` sul nuovo primary |
