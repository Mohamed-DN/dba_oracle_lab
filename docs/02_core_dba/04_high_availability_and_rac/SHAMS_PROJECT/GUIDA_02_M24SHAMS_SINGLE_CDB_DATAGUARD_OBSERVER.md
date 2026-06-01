# SHAMS PROJECT S2: M24SHAMS Single Instance CDB Data Guard e Observer

## Obiettivo operativo

Creare un database Oracle 19c CDB single instance con PDB applicativo,
physical standby, Data Guard Broker, Active Data Guard opzionale e Observer
FSFO.

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
| Active Data Guard | `<PRODUZIONE_CON_EVIDENZA/LAB_PERSONALE/NO>` |
| PDB name | `M24SHAMSC_APP` |
| Local undo | `<SI/NO - decisione>` |
| TDE | `<SI/NO - decisione Security>` |
| RMAN catalog | `<RMAN_CATALOG_TNS>` |

### Scheda sostituzioni per riuso

| Oggetto | Esempio collaudo | Valore approvato |
| --- | --- | --- |
| `DB_NAME` | `M24SHAMS` | `<DB_NAME>` |
| Ambiente | `C` | `<ENV>` |
| Primary / standby `DB_UNIQUE_NAME` | `M24SHAMSPEC` / `M24SHAMSSEC` | `<PRIMARY_UNIQUE_NAME>` / `<STANDBY_UNIQUE_NAME>` |
| Broker configuration | `DR_M24SHAMSC_CONF` | `DR_<DB_NAME><ENV>_CONF` |
| PDB | `M24SHAMSC_APP` | `<PDB_NAME>` |
| Servizi | `M24SHAMSC_PRY` / `M24SHAMSC_RO` | `<PRIMARY_SERVICE>` / `<STANDBY_RO_SERVICE>` |
| ASM | `+M24SHAMS_DATA` / `+M24SHAMS_FRA` | `<ASM_DATA>` / `<ASM_FRA>` |

## Procedura operativa

### 0. Prepara host e inventario

Completa l'[allegato host single](./GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md)
su PE e SE. Registra host, IP DG, DNS, NTP, RU Grid/DB, diskgroups, FRA,
`ORACLE_HOME`, `GRID_HOME`, keystore e recovery catalog. Non procedere se RU,
rete o storage non sono allineati.

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

Se sostituisci redo esistenti, aggiungi prima i nuovi gruppi OMF, esegui log
switch controllati e rimuovi soltanto i gruppi precedenti `INACTIVE`. Non
eliminare gruppi `CURRENT` o `ACTIVE`.

Configura responsabilità distinte:

```text
M24SHAMSPEC_DG  -> redo, FAL e DGConnectIdentifier
M24SHAMSSEC_DG  -> redo, FAL e DGConnectIdentifier
M24SHAMSSEC_AUX -> static listener temporaneo per RMAN NOMOUNT
*_DGMGRL        -> restart Broker quando richiesto
```

Se TDE e' richiesto, distribuisci il keystore allo standby prima del duplicate
e verifica root e PDB.

### 4. RMAN duplicate dello standby

Sul server SE crea `<ORACLE_BASE>/admin/M24SHAMSSEC/adump`, prepara un PFILE
minimo con `DB_NAME`, `DB_UNIQUE_NAME`, destinazioni ASM, FRA e
`AUDIT_FILE_DEST`, quindi avvia auxiliary `M24SHAMSSEC` in `NOMOUNT`.

Usa prompt interattivo:

```bash
rman target sys@M24SHAMSPEC_DG auxiliary sys@M24SHAMSSEC_AUX
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

Dopo il duplicate crea lo SPFILE in ASM, lascia nel DB Home il pointer file,
registra primary e standby con `srvctl add database` su Oracle Restart e
prova `srvctl stop database` / `srvctl start database`. Non usare
`srvctl add instance`: appartiene a RAC.

### 5. PDB e Active Data Guard

Esegui questa sezione solo dopo il gate della guida
[Active Data Guard e servizi](./GUIDA_10_ACTIVE_DATAGUARD_SERVIZI_ROLE_BASED_PEYTECH_19C.md).
Senza ADG mantieni standby `MOUNTED` con Redo Apply.

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

Prima del Broker salva parametri e rollback SQL. Rimuovi in modo mirato le
destinazioni redo remote manuali incompatibili: sul primary prima di
`CREATE CONFIGURATION`, sullo standby prima di `ADD DATABASE`. Non azzerare
parametri di rete o destinazioni FRA.

Configura Broker:

```text
CREATE CONFIGURATION 'DR_M24SHAMSC_CONF' AS
  PRIMARY DATABASE IS M24SHAMSPEC
  CONNECT IDENTIFIER IS M24SHAMSPEC_DG;

ADD DATABASE M24SHAMSSEC AS
  CONNECT IDENTIFIER IS M24SHAMSSEC_DG
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
VALIDATE DATABASE M24SHAMSPEC SPFILE;
VALIDATE DATABASE M24SHAMSSEC SPFILE;
VALIDATE NETWORK CONFIGURATION FOR ALL;
VALIDATE STATIC CONNECT IDENTIFIER FOR ALL;
```

`DR_M24SHAMSC_CONF` usa il `DB_NAME` condiviso e l'ambiente `C`, quindi resta
stabile dopo switchover. Esegui switchover e switchback, verificando CDB, PDB,
servizio `_PRY`, eventuale `_RO`, lag e apply. Dopo stabilizzazione completa
l'[Observer FSFO](./GUIDA_05_OBSERVER_FSFO_PEYTECH.md).

## Validazione finale

| Check | Esito |
| --- | --- |
| primary e standby `CDB=YES` | `<OK/KO>` |
| PDB `M24SHAMSC_APP` presente nei due siti | `<OK/KO>` |
| standby `MOUNTED` oppure `READ ONLY WITH APPLY` autorizzato | `<OK/KO>` |
| service `_PRY`; `_RO` solo se ADG autorizzato | `<OK/KO/N.A.>` |
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
