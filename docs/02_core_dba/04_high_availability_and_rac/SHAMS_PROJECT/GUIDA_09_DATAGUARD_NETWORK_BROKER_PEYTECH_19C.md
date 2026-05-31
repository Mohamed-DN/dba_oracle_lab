# SHAMS PROJECT: Data Guard Network e Broker PEYTECH Oracle 19c

## Obiettivo operativo

Configurare la parte comune Data Guard dei blueprint `S1`-`S4`: rete dedicata,
listener, alias Oracle Net, prerequisiti database, duplicate RMAN, Redo Apply e
Data Guard Broker. Questa guida non sostituisce il blueprint scelto: lo completa.

Usa un solo percorso:

| Blueprint | Topologia locale | Percorso rete |
| --- | --- | --- |
| `S1`, `S2` | Single instance con Oracle Restart/HAS | listener DG dedicato |
| `S3`, `S4` | RAC con Clusterware | rete DG RAC dedicata, se approvata |

## Fonti Oracle ufficiali

- [Standby fisico con RMAN](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/creating-data-guard-standby-database-using-RMAN.html)
- [Redo Transport Services](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-redo-transport-services.html)
- [Protection Modes](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/oracle-data-guard-protection-modes.html)
- [Requisiti Data Guard Broker](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/oracle-data-guard-broker-installation-requirements.html)
- [Troubleshooting Data Guard](https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/troubleshooting-oracle-data-guard.html)

## Assessment

### 1. Inventario obbligatorio

Non eseguire i comandi con placeholder irrisolti.

| Campo | Primary PE | Standby SE |
| --- | --- | --- |
| `DB_NAME` | `M24SHAMS` | `M24SHAMS` |
| `DB_UNIQUE_NAME` | `M24SHAMSPEC` | `M24SHAMSSEC` |
| Endpoint DG | `<PRIMARY_DG_ENDPOINT>` | `<STANDBY_DG_ENDPOINT>` |
| IP rete DG | `<PRIMARY_DG_IPS>` | `<STANDBY_DG_IPS>` |
| Listener DG | `1531/TCP` | `1531/TCP` |
| Oracle Home | `<ORACLE_HOME>` | `<ORACLE_HOME>` |
| Grid Home | `<GRID_HOME>` | `<GRID_HOME>` |
| RU approvata | `<RU>` | `<RU>` |
| ASM DATA | `+M24SHAMS_DATA` | `+M24SHAMS_DATA` |
| ASM FRA | `+M24SHAMS_FRA` | `+M24SHAMS_FRA` |
| Keystore TDE | `<PATH oppure N/A>` | `<PATH oppure N/A>` |

Registra inoltre latenza PE-SE, firewall, DNS, route, MTU, banda disponibile,
redo medio/picco e owners di rete, DBA, Security e storage.

### 2. Controlli database primary

```sql
SELECT name, db_unique_name, database_role, open_mode,
       log_mode, force_logging, flashback_on
FROM v$database;

SHOW PARAMETER db_create_file_dest
SHOW PARAMETER db_recovery_file_dest
SHOW PARAMETER standby_file_management
SHOW PARAMETER log_archive_config

SELECT thread#, group#, bytes / 1024 / 1024 AS mb, status
FROM v$log
ORDER BY thread#, group#;

SELECT thread#, group#, bytes / 1024 / 1024 AS mb, status
FROM v$standby_log
ORDER BY thread#, group#;
```

Atteso:

- `ARCHIVELOG`;
- `FORCE LOGGING=YES`;
- `STANDBY_FILE_MANAGEMENT=AUTO`;
- SRL su entrambi i ruoli: online redo group + 1 per thread, stessa dimensione;
- Flashback Database raccomandato sui due siti per reinstate rapido.

## Procedura operativa

### 1. Scelta rete single/HAS

Oracle Restart/HAS non gestisce una seconda rete RAC. Configura un listener
dedicato sulla rete DG, senza creare risorse CRS di network o VIP RAC.

Esempio da adattare:

```bash
srvctl add listener -listener LISTENER_DG \
  -oraclehome <GRID_HOME> \
  -endpoints TCP:1531

srvctl start listener -listener LISTENER_DG
srvctl status listener -listener LISTENER_DG
```

Verifica che l'endpoint ascolti sull'interfaccia approvata. Se l'installazione
richiede un indirizzo esplicito, registralo nel change e valida con `lsnrctl`.

### 2. Scelta rete RAC

Per `S3` e `S4`, usa la rete DG dedicata solo dopo approvazione networking.
Il disegno standard prevede:

```text
rete DG dedicata
  +-- VIP DG per ogni nodo PE e SE
  +-- DG SCAN per ogni sito
  +-- SCAN listener DG su 1531/TCP
  +-- listener locale DG su 1531/TCP
```

Prima di applicare comandi `srvctl`, verifica la sintassi disponibile nella RU:

```bash
srvctl add network -help
srvctl add vip -help
srvctl add scan -help
srvctl add scan_listener -help
srvctl add listener -help
```

Non copiare valori `LOCAL_LISTENER`, `REMOTE_LISTENER` o `LISTENER_NETWORKS`
da un altro cluster. Quando esistono piu reti, registra il mapping approvato e
valida la registrazione dinamica su ogni nodo con:

```bash
srvctl config listener
srvctl config scan_listener
srvctl status listener
srvctl status scan_listener
lsnrctl services LISTENER_DG
```

### 3. Alias Oracle Net

Distribuisci gli alias nei DB Home coinvolti, nel Grid Home quando richiesto
dai tool e sull'Observer. Usa endpoint raggiungibili da entrambi i siti.

```text
M24SHAMSPEC_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <PRIMARY_DG_ENDPOINT>)(PORT = 1531))
    (CONNECT_DATA = (SERVICE_NAME = M24SHAMSPEC_DG))
  )

M24SHAMSSEC_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = <STANDBY_DG_ENDPOINT>)(PORT = 1531))
    (CONNECT_DATA = (SERVICE_NAME = M24SHAMSSEC_DG))
  )
```

Test:

```bash
tnsping M24SHAMSPEC_DG
tnsping M24SHAMSSEC_DG
```

### 4. Registrazione statica temporanea per duplicate

L'auxiliary RMAN parte in `NOMOUNT`, quindi la registrazione dinamica non basta.
Sul nodo standby scelto per il duplicate aggiungi una registrazione statica
temporanea a `LISTENER_DG`.

```text
SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = M24SHAMSSEC_DG)
      (ORACLE_HOME = <ORACLE_HOME>)
      (SID_NAME = <M24SHAMSSEC oppure M24SHAMSSEC1>)
    )
  )
```

```bash
lsnrctl reload LISTENER_DG
lsnrctl services LISTENER_DG
```

Dopo il duplicate, rimuovi la registrazione temporanea se non serve piu.
La registrazione necessaria al Broker per startup e restart e' una decisione
separata: prima valida quanto gestito da Oracle Restart o Clusterware.

### 5. Password file e TDE

Trasferisci il password file con canale sicuro e permessi minimi. Non scrivere
password in shell, file versionati o process list. Usa autenticazione OS locale,
prompt interattivo oppure wallet SEPS.

Se TDE e' attivo:

1. copia il keystore sul sito standby prima del duplicate;
2. verifica apertura wallet e backup keystore;
3. ripeti distribuzione e validazione dopo ogni rekey.

### 6. Auxiliary e duplicate RMAN

Sul standby avvia una sola auxiliary instance in `NOMOUNT`. Per RAC usa
temporaneamente `cluster_database=FALSE`.

```bash
export ORACLE_SID=<M24SHAMSSEC oppure M24SHAMSSEC1>
rman target sys@M24SHAMSPEC_DG auxiliary sys@M24SHAMSSEC_DG
```

Le password vengono richieste interattivamente.

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

Usa `NOFILENAMECHECK` solo con storage realmente separato. Per RAC, completa
registrazione Clusterware e parametri per istanza seguendo il blueprint scelto.

### 7. Avvio Redo Apply

Su standby montato:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

In Oracle 19c gli SRL permettono il real-time apply senza la clausola storica
`USING CURRENT LOGFILE`, deprecata da Oracle Database 12c.

### 8. Broker

Attiva Broker su entrambi i siti:

```sql
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

Da `dgmgrl`, usando prompt interattivo o wallet:

```text
CREATE CONFIGURATION M24SHAMS_DG AS
  PRIMARY DATABASE IS M24SHAMSPEC
  CONNECT IDENTIFIER IS M24SHAMSPEC_DG;

ADD DATABASE M24SHAMSSEC AS
  CONNECT IDENTIFIER IS M24SHAMSSEC_DG
  MAINTAINED AS PHYSICAL;

ENABLE CONFIGURATION;
SHOW CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
```

Se erano presenti destinazioni remote manuali incompatibili con la gestione
Broker, registra il prima/dopo e trasferisci ownership al Broker in modo
controllato. Non azzerare parametri di rete o archiviazione alla cieca.

## Validazione finale

```text
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE M24SHAMSPEC;
SHOW DATABASE VERBOSE M24SHAMSSEC;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
VALIDATE NETWORK CONFIGURATION FOR ALL;
```

Sul standby:

```sql
SELECT database_role, open_mode FROM v$database;
SELECT name, value, unit FROM v$dataguard_stats;
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT thread#, low_sequence#, high_sequence# FROM v$archive_gap;
```

Il setup base e' valido con standby `MOUNTED` e Redo Apply attivo. Per aprire
lo standby in lettura usa la guida Active Data Guard dopo il gate licenza.

## Rollback rapido

Se il profilo sincrono impatta i commit:

```text
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT DATABASE M24SHAMSSEC SET PROPERTY LogXptMode='ASYNC';
SHOW CONFIGURATION;
```

Se lo standby non e' affidabile, mantieni il primary aperto, preserva gli
archivelog e pianifica il riallineamento. Non improvvisare failover o purge.

## Troubleshooting rapido

| Sintomo | Prima azione |
| --- | --- |
| Auxiliary non raggiungibile | static listener, `tnsping`, password file, firewall |
| `ORA-12514` | `lsnrctl services LISTENER_DG`, alias e `SERVICE_NAME` |
| `ORA-01017` | riallinea password file senza esporre credenziali |
| `ORA-28365` | verifica keystore TDE e copia approvata |
| `ORA-16698` | rivedi destinazioni redo manuali prima della presa in carico Broker |
| Apply fermo | alert log, `MRP0`, SRL, gap e spazio FRA |
| Gap redo | usa il test book e il runbook DG-062 |
