# FASE 3: Preparazione e Creazione Oracle RAC Standby (tramite RMAN Duplicate)

> Questa fase copre la preparazione dei nodi standby (`racstby1`, `racstby2`) e la creazione del database standby fisico usando RMAN Duplicate from Active Database.

### 📸 Architettura Data Guard

![Architettura Data Guard RAC Primary → RAC Standby](./images/dataguard_architecture.png)

### Cosa Succede in Questa Fase

```
  PRIMA                                           DOPO
  ═════                                           ════

┌─────────────┐                          ┌─────────────┐
│ RAC PRIMARY │                          │ RAC PRIMARY │
│   RACDB     │                          │   RACDB     │
│ ┌────┐┌────┐│                          │ ┌────┐┌────┐│
│ │DB1 ││DB2 ││                          │ │DB1 ││DB2 ││
│ └────┘└────┘│                          │ └────┘└────┘│
│ rac1  rac2  │                          │ rac1  rac2  │
└─────────────┘                          └──────┬──────┘
                                                │ Redo Shipping
                                                │ (LGWR ASYNC)
┌─────────────┐                                 ▼
│ RAC STANDBY │   RMAN Duplicate     ┌──────────────────┐
│  (vuoto)    │  ═══════════════►    │ RAC STANDBY      │
│ Grid + SW   │   Copia DB via       │ RACDB_STBY       │
│ NO database │   rete in tempo      │ ┌────┐ ┌────┐   │
│ racstby1/2  │   reale!             │ │DB1 │ │DB2 │   │
└─────────────┘                      │ └────┘ └────┘   │
                                     │ MRP: Applica redo│
                                     │ in tempo reale   │
                                     └──────────────────┘
```

---

## 3.1 Prerequisiti sui Nodi Standby

Prima di iniziare, i nodi standby devono avere completato:
- ✅ **Fase 1 completa** (OS, DNS, utenti, SSH, etc.) su `racstby1` e `racstby2`
- ✅ **Grid Infrastructure installata** (stesso procedimento della Fase 2.1-2.6) su `racstby1` e `racstby2`
- ✅ **Software Database installato** (Fase 2.8, solo Software Only, NESSUN database creato) su `racstby1` e `racstby2`
- ✅ I Disk Group **DATA** e **FRA** devono esistere sullo standby con gli stessi nomi del primario

> **Perché stessi nomi dei Disk Group?** RMAN Duplicate cerca i disk group per nome. Se sul primario i datafile sono in `+DATA` e sullo standby non esiste `+DATA`, il duplicate fallisce.

---

> 🛑 **PRIMA DI CONTINUARE: CONNETTITI VIA MOBAXTERM!**
> Per tutte le operazioni seguenti (modifiche file, RMAN, etc.) è **obbligatorio** usare MobaXterm per poter fare copia-incolla e avere X11 funzionante. Assicurati di aprire sessioni SSH separate per ciascuna VM di cui avrai bisogno.
>
> **Tabella IP di Riferimento (Rete Pubblica):**
> - `rac1`: 192.168.56.101
> - `rac2`: 192.168.56.102
> - `racstby1`: 192.168.56.111
> - `racstby2`: 192.168.56.112

---

## 3.2 Configurazione Listener Statico sul Primario

Il Listener dinamico (registrato da PMON) non è sufficiente per Data Guard. Dobbiamo aggiungere un'entry **statica** perché il database standby deve potersi connettere anche quando l'istanza primaria non è completamente aperta.

### Sul Primario (`rac1`, come utente `grid`)

```bash
su - grid
vi $ORACLE_HOME/network/admin/listener.ora
```

Aggiungi alla fine:

```
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)
    )
  )
```

Fai lo stesso su `rac2` cambiando `SID_NAME = RACDB2`.

```bash
# Riavvia il listener
srvctl stop listener
srvctl start listener

# Verifica
lsnrctl status
# Deve mostrare le entry statiche
```

> **Perché il Listener Statico?** Quando il database è in mount (non aperto), il servizio PMON non fa la registrazione dinamica con il listener. Ma Data Guard ha bisogno di connettersi al database in mount per applicare i redo. Il listener statico risolve questo problema.

---

## 3.3 Configurazione Listener Statico sullo Standby

### Su `racstby1` (come utente `grid`)

```bash
su - grid
vi $ORACLE_HOME/network/admin/listener.ora
```

Aggiungi:

```
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB_STBY_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)
    )
    (SID_DESC =
      (GLOBAL_DBNAME = RACDB_STBY)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = RACDB1)
    )
  )
```

Stesso su `racstby2` con `SID_NAME = RACDB2`.

```bash
srvctl stop listener
srvctl start listener
```

---

## 3.4 Configurazione TNS Names

Il file `tnsnames.ora` deve essere identico su **TUTTI** i nodi (primario e standby).

### Sul Primario e Standby (`$ORACLE_HOME/network/admin/tnsnames.ora`, come utente `oracle`)

```bash
su - oracle
cat > $ORACLE_HOME/network/admin/tnsnames.ora <<'EOF'
RACDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB)
    )
  )

RACDB_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB_STBY)
      (UR=A)
    )
  )

RACDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = RACDB1)
    )
  )

RACDB2 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = RACDB2)
    )
  )

RACDB1_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby1.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = RACDB1)
      (UR=A)
    )
  )

RACDB2_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby2.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = RACDB2)
      (UR=A)
    )
  )
EOF
```

> **Perché tnsnames.ora identico ovunque?** Data Guard usa questi alias TNS per comunicare tra primario e standby. Se manca un'entry su un nodo, il redo shipping fallisce.

> **Cos'è `(UR=A)`?** "Use Role = Any" — permette la connessione anche quando il database è in stato NOMOUNT o MOUNT (non solo OPEN). Essenziale per lo standby che non è mai in READ WRITE. Senza `UR=A`, `tnsping` funziona ma `sqlplus sys@RACDB_STBY as sysdba` fallisce con timeout.

### Test Connettività TNS

```bash
# Da rac1 verso lo standby
tnsping RACDB1_STBY
tnsping RACDB_STBY

# Da racstby1 verso il primario
tnsping RACDB1
tnsping RACDB
```

---

## 3.5 Configurazione del Primario per Data Guard

```sql
-- Connettiti al primario come sysdba
sqlplus / as sysdba

-- 1. Verifica Force Logging (già fatto in Fase 2)
SELECT force_logging FROM v$database;

-- 2. Configura Standby Redo Logs
-- Regola: N. di Standby Redo Log Groups = (N. Online Redo Log Groups + 1) PER THREAD
-- Se hai 3 online redo log groups per thread, crea 4 standby redo log groups per thread

-- Verifica quanti online redo log groups hai
SELECT thread#, group#, bytes/1024/1024 size_mb FROM v$log ORDER BY thread#, group#;

-- Crea Standby Redo Logs (esempio: 3 ORL per thread -> 4 SRL per thread)
-- Thread 1 (rac1)
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1
  GROUP 11 ('+DATA') SIZE 200M,
  GROUP 12 ('+DATA') SIZE 200M,
  GROUP 13 ('+DATA') SIZE 200M,
  GROUP 14 ('+DATA') SIZE 200M;

-- Thread 2 (rac2)
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2
  GROUP 21 ('+DATA') SIZE 200M,
  GROUP 22 ('+DATA') SIZE 200M,
  GROUP 23 ('+DATA') SIZE 200M,
  GROUP 24 ('+DATA') SIZE 200M;

-- Verifica
SELECT group#, thread#, bytes/1024/1024 size_mb, status FROM v$standby_log;
```

> **Perché i Standby Redo Logs?** Quando i redo log arrivano dal primario, lo standby li scrive prima negli Standby Redo Logs e POI li applica. Senza SRL, usa gli archived redo logs, che sono più lenti. La regola "+1" garantisce che ci sia sempre uno SRL disponibile anche durante un log switch.

```sql
-- 3. Imposta i parametri Data Guard
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(RACDB,RACDB_STBY)' SCOPE=BOTH SID='*';

ALTER SYSTEM SET log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB' SCOPE=BOTH SID='*';

ALTER SYSTEM SET log_archive_dest_2='SERVICE=RACDB_STBY LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB_STBY' SCOPE=BOTH SID='*';

ALTER SYSTEM SET log_archive_dest_state_1=ENABLE SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_state_2=ENABLE SCOPE=BOTH SID='*';

ALTER SYSTEM SET fal_server='RACDB_STBY' SCOPE=BOTH SID='*';
ALTER SYSTEM SET fal_client='RACDB' SCOPE=BOTH SID='*';

ALTER SYSTEM SET standby_file_management=AUTO SCOPE=BOTH SID='*';

ALTER SYSTEM SET db_file_name_convert='+DATA/RACDB_STBY/','+DATA/RACDB/' SCOPE=SPFILE SID='*';
ALTER SYSTEM SET log_file_name_convert='+DATA/RACDB_STBY/','+DATA/RACDB/','+FRA/RACDB_STBY/','+FRA/RACDB/' SCOPE=SPFILE SID='*';
```

> **Spiegazione parametri chiave:**
> - `log_archive_dest_2`: Dice al primario "spedisci i redo allo standby tramite LGWR ASYNC". LGWR = Log Writer (più veloce di ARCH). ASYNC = non aspettare la conferma dallo standby (performance migliore, possibile perdita minima di dati).
> - `fal_server/fal_client`: "Fetch Archive Log" — se lo standby scopre un gap nei redo, sa dove andarli a prendere.
> - `standby_file_management=AUTO`: Se crei un tablespace sul primario, lo standby lo crea automaticamente.

### Come Funziona il Redo Shipping

```
PRIMARIO (RACDB)                              STANDBY (RACDB_STBY)
════════════════                              ═════════════════════

Utente fa COMMIT
     │
     ▼
┌──────────┐                                  
│  LGWR    │──── Scrive ───►┌──────────────┐  
│          │                │ Online Redo  │  
│          │                │ Log (locale) │  
│          │                └──────┬───────┘  
│          │                       │          
│          │── Spedisce ──────────────────────►┌──────────────┐
│          │   (ASYNC via rete)               │ Standby Redo │
└──────────┘                                  │ Log (SRL)    │
                                              └──────┬───────┘
                                                     │
                                                     ▼
                                              ┌──────────────┐
                                              │  MRP (Managed│
                                              │  Recovery    │
                                              │  Process)    │
                                              │              │
                                              │  Applica i   │
                                              │  redo ai     │
                                              │  datafile    │
                                              └──────────────┘
```

---

## 3.6 Creazione Password File e Copia

### Se il password file è su ASM (caso più comune in RAC)

```bash
# Sul primario (rac1) come oracle — prima trova il file in ASM
su - oracle
. grid.env
asmcmd
ASMCMD> cd +DATA/RACDB/PASSWORD
ASMCMD> ls
pwdracdb.256.1188432663
ASMCMD> pwcopy pwdracdb.256.1188432663 /tmp/orapwRACDB1
ASMCMD> exit
```

### Se il password file è nel filesystem

```bash
# Sul primario (rac1) come oracle
cd $ORACLE_HOME/dbs
orapwd file=orapwRACDB1 password=<tua_password_sys> entries=10 force=y
```

### Copia sullo standby (IMPORTANTE: nome = orapw<SID>)

```bash
# Il nome del password file DEVE essere orapw<SID>!
# Se il SID è RACDB1 → il file deve chiamarsi orapwRACDB1

scp /tmp/orapwRACDB1 oracle@racstby1:$ORACLE_HOME/dbs/orapwRACDB1
scp /tmp/orapwRACDB1 oracle@racstby2:$ORACLE_HOME/dbs/orapwRACDB2

# Verifica owner e permessi (DEVE essere oracle:oinstall)
ls -la $ORACLE_HOME/dbs/orapw*
# -rw-r----- 1 oracle oinstall 2048 ... orapwRACDB1
```

> **Perché copiare il password file?** Data Guard usa il password file per autenticare la connessione redo transport tra primario e standby. Le password SYS devono essere identiche. Se ricevi `ORA-01017: invalid username/password`, controlla che il nome del file sia `orapw<SID>` e che l'owner sia l'utente oracle.

---

## 3.7 Creazione del PFILE per lo Standby

```bash
# Sul primario come oracle
sqlplus / as sysdba
CREATE PFILE='/tmp/initRACDB_stby.ora' FROM SPFILE;
EXIT;
```

Modifica il pfile per lo standby:

```bash
vi /tmp/initRACDB_stby.ora
```

Modifica questi parametri:

```
*.db_unique_name='RACDB_STBY'
*.fal_server='RACDB'
*.fal_client='RACDB_STBY'
*.log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB_STBY'
*.log_archive_dest_2='SERVICE=RACDB LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB'
RACDB1.instance_number=1
RACDB2.instance_number=2
RACDB1.thread=1
RACDB2.thread=2
RACDB1.undo_tablespace='UNDOTBS1'
RACDB2.undo_tablespace='UNDOTBS2'
*.cluster_database=TRUE
*.remote_listener='racstby-scan.localdomain:1521'
```

Copia sullo standby:

```bash
scp /tmp/initRACDB_stby.ora oracle@racstby1:$ORACLE_HOME/dbs/initRACDB1.ora
```

---

## 3.8 Creazione Cartelle Audit sullo Standby

```bash
# Su racstby1 e racstby2 come oracle
mkdir -p /u01/app/oracle/admin/RACDB_STBY/adump
mkdir -p /u01/app/oracle/admin/RACDB/adump
```

---

## 3.9 Avvio Istanza Standby in NOMOUNT

```bash
# Su racstby1 come oracle
export ORACLE_SID=RACDB1
sqlplus / as sysdba
STARTUP NOMOUNT PFILE='$ORACLE_HOME/dbs/initRACDB1.ora';
EXIT;
```

---

## 3.10 RMAN Duplicate da Active Database

Questa è la magia! RMAN copia il database dal primario allo standby **in tempo reale**, senza bisogno di backup fisici.

> 📸 **SNAPSHOT — "SNAP-11: Pre-Duplicate" 🔴 CRITICO**
> L'RMAN Duplicate è l'operazione più delicata. Se fallisce (e succede spesso la prima volta), torni qui e risparmi MOLTO tempo.
> **Fai snapshot su TUTTE le VM (rac1, rac2, racstby1, racstby2)!**
> ```
> VBoxManage snapshot "rac1" take "SNAP-11_Pre_Duplicate"
> VBoxManage snapshot "rac2" take "SNAP-11_Pre_Duplicate"
> VBoxManage snapshot "racstby1" take "SNAP-11_Pre_Duplicate"
> VBoxManage snapshot "racstby2" take "SNAP-11_Pre_Duplicate"
> ```

```bash
# Da racstby1 come oracle
rman TARGET sys/<password>@RACDB AUXILIARY sys/<password>@RACDB1_STBY
```

> **Per database grandi (>50 GB)**, lancia con `nohup` o in un `screen`/`tmux` per evitare che un timeout SSH interrompa l'operazione:
> ```bash
> nohup rman TARGET sys/<password>@RACDB AUXILIARY sys/<password>@RACDB1_STBY <<EOF > /tmp/duplicate.log 2>&1 &
> DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE DORECOVER ...
> EOF
> tail -f /tmp/duplicate.log   # Per monitorare il progresso
> ```

```rman
DUPLICATE TARGET DATABASE
  FOR STANDBY
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    SET db_unique_name='RACDB_STBY'
    SET cluster_database='TRUE'
    SET remote_listener='racstby-scan.localdomain:1521'
    SET fal_server='RACDB'
    SET log_archive_dest_2='SERVICE=RACDB LGWR ASYNC VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB'
  NOFILENAMECHECK;
```

> **Spiegazione del comando RMAN:**
> - `FOR STANDBY`: Crea un database standby, non un clone.
> - `FROM ACTIVE DATABASE`: Copia i datafile direttamente via rete, senza bisogno di un backup su disco.
> - `DORECOVER`: Applica automaticamente gli archivelog mancanti dopo la copia.
> - `SPFILE SET ...`: Sovrascrive i parametri nel SPFILE dello standby.
> - `NOFILENAMECHECK`: Non verificare che i path dei file siano diversi (utile perché usiamo gli stessi nomi ASM).

L'operazione può richiedere 20-60 minuti a seconda della dimensione del DB.

---

## 3.11 Creazione SPFILE in ASM e Pointer File

Dopo il duplicate, l'SPFILE potrebbe essere nel filesystem locale. Per un RAC, deve stare in ASM (condiviso tra i nodi).

```sql
-- Su racstby1 come sysdba
sqlplus / as sysdba

-- Verifica dove si trova lo SPFILE attuale
SHOW PARAMETER spfile;

-- Se è locale, spostalo in ASM:
CREATE SPFILE='+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora'
  FROM PFILE='$ORACLE_HOME/dbs/initRACDB1.ora';

-- Shutdown
SHUTDOWN IMMEDIATE;
```

```bash
# Crea pointer file su racstby1
cd $ORACLE_HOME/dbs
mv initRACDB1.ora initRACDB1.ora.bkp   # Backup del pfile
echo "SPFILE='+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora'" > initRACDB1.ora

# Crea pointer file su racstby2
scp initRACDB1.ora oracle@racstby2:$ORACLE_HOME/dbs/initRACDB2.ora

# Verifica
more $ORACLE_HOME/dbs/initRACDB1.ora
# SPFILE='+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora'
```

```sql
-- Riavvia e verifica
STARTUP MOUNT;
SHOW PARAMETER spfile;
-- Deve mostrare il path ASM: +DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora
```

> **Perché SPFILE in ASM?** In un RAC, i parametri devono essere condivisi tra tutti i nodi. Se l'SPFILE è nel filesystem locale di racstby1, racstby2 non lo troverà! Mettendolo in ASM, è accessibile da entrambi i nodi.

---

## 3.12 Registrazione nel Cluster (OCR) e Avvio Secondo Nodo

Dopo il duplicate, devi registrare il database standby nell'Oracle Cluster Registry (OCR) perché il Clusterware possa gestirlo.

```bash
# Su racstby1 come oracle
srvctl add database -d RACDB_STBY \
  -oraclehome $ORACLE_HOME \
  -spfile '+DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora' \
  -role PHYSICAL_STANDBY \
  -startoption MOUNT

srvctl add instance -d RACDB_STBY -instance RACDB1 -node racstby1
srvctl add instance -d RACDB_STBY -instance RACDB2 -node racstby2

# Copia password file su racstby2
scp $ORACLE_HOME/dbs/orapwRACDB1 oracle@racstby2:$ORACLE_HOME/dbs/orapwRACDB2

# Avvia il database (entrambe le istanze)
srvctl start database -d RACDB_STBY

# Verifica
srvctl status database -d RACDB_STBY -v
# Instance RACDB1 is running on node racstby1...
# Instance RACDB2 is running on node racstby2...

crsctl stat res -t | grep -A2 RACDB_STBY
```

---

## 3.13 Avvio Redo Apply (MRP)

```sql
-- Su racstby1 come sysdba
sqlplus / as sysdba

-- Avvia il Managed Recovery Process (MRP)
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT FROM SESSION;

-- Verifica che MRP sia attivo
SELECT process, status, thread#, sequence# FROM v$managed_standby WHERE process = 'MRP0';
-- STATUS deve essere APPLYING_LOG
```

> **Perché `USING CURRENT LOGFILE`?** Questo abilita il **Real-Time Apply**: lo standby applica i redo APPENA arrivano, senza aspettare che l'archivelog sia completo. Il ritardo è tipicamente di pochi secondi.

```sql
-- Comandi utili per gestire MRP
-- Fermare MRP:
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;

-- Verificare MRP a livello OS:
-- ps -ef | grep mrp
```

---

## 3.14 Configura Archivelog Deletion Policy

```bash
# Sullo standby come oracle
rman target /

RMAN> SHOW ARCHIVELOG DELETION POLICY;
# default: NONE

RMAN> CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

RMAN> SHOW ARCHIVELOG DELETION POLICY;
# CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;
```

> **Perché?** Senza questa policy, gli archivelog si accumulano nella FRA fino a riempirla (ORA-19502). Con questa policy, RMAN elimina automaticamente gli archivelog che sono già stati applicati sullo standby.

---

## 3.15 Verifica Sincronizzazione

```sql
-- Sul PRIMARIO: esegui alcuni log switch per testare
ALTER SYSTEM SWITCH LOGFILE;   -- Thread 1
ALTER SYSTEM SWITCH LOGFILE;

-- Sul PRIMARIO: verifica ultimo sequence archiviato
SELECT thread#, MAX(sequence#) FROM v$archived_log
WHERE archived='YES' GROUP BY thread#;

-- Sullo STANDBY: verifica ultimo sequence applicato
SELECT thread#, MAX(sequence#) FROM v$archived_log
WHERE applied='YES' GROUP BY thread#;

-- I numeri DEVONO corrispondere!
```

---

## 3.16 Troubleshooting Fase 3

| Problema | Causa | Soluzione |
|---|---|---|
| `ORA-01017` su `sqlplus sys@RACDB_STBY` | Password file errato | Verifica nome = `orapw<SID>`, owner = `oracle` |
| `ORA-12528: TNS:listener: all ... blocked` | DB in NOMOUNT senza `UR=A` | Aggiungi `(UR=A)` nel TNS dello standby |
| `ORA-16055: FAL request rejected` | `log_archive_dest` errato | Correggi su ENTRAMBI i lati (vedi sotto) |
| RMAN Duplicate timeout/hang | Rete lenta o sessione SSH caduta | Usa `nohup` o `screen`, verifica rete |
| MRP non parte: `ORA-00270` | FRA piena sullo standby | Pulisci archivelog: `DELETE NOPROMPT ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-2';` |
| `v$archive_gap` mostra gap | Archivelog mancante | `ALTER SYSTEM SET fal_server='RACDB' SCOPE=BOTH;` → FAL recupera automaticamente |

### Fix ORA-16055 (Comune!)

```sql
-- Il problema: i parametri log_archive_dest non sono simmetrici.
-- Fix sul PRIMARIO:
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=USE_DB_RECOVERY_FILE_DEST
  VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB' SID='*' SCOPE=BOTH;

ALTER SYSTEM SET LOG_ARCHIVE_DEST_2='SERVICE=RACDB_STBY ASYNC
  VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB_STBY' SID='*' SCOPE=BOTH;

-- Fix sullo STANDBY:
ALTER SYSTEM SET LOG_ARCHIVE_DEST_1='LOCATION=USE_DB_RECOVERY_FILE_DEST
  VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=RACDB_STBY' SID='*' SCOPE=BOTH;

ALTER SYSTEM SET LOG_ARCHIVE_DEST_2='SERVICE=RACDB ASYNC
  VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=RACDB' SID='*' SCOPE=BOTH;
```

> **Riferimento**: MOS Doc ID 2988948.1 — "ORA-16055: FAL Request Rejected on primary alert log"

---

## ✅ Checklist Fine Fase 3

```bash
# 1. Standby in mount su entrambi i nodi
srvctl status database -d RACDB_STBY -v

# 2. MRP attivo e APPLYING_LOG
sqlplus -s / as sysdba <<< "SELECT process, status FROM v\$managed_standby WHERE process='MRP0';"

# 3. Nessun gap
sqlplus -s / as sysdba <<< "SELECT * FROM v\$archive_gap;"
# (nessuna riga = tutto OK)

# 4. Sequence primario == standby
# Sul primario:
sqlplus -s / as sysdba <<< "SELECT thread#, max(sequence#) FROM v\$archived_log WHERE applied='YES' GROUP BY thread#;"

# 5. SPFILE in ASM (non locale!)
SHOW PARAMETER spfile;
# +DATA/RACDB_STBY/PARAMETERFILE/spfileRACDB_STBY.ora

# 6. Archivelog deletion policy configurata
rman target / <<< "SHOW ARCHIVELOG DELETION POLICY;"

# 7. Errori nel alert log?
adrci
SHOW ALERT -tail 30
```

> 📸 **SNAPSHOT — "SNAP-12: RMAN Duplicate Completato" ⭐ MILESTONE**
> Lo standby è operativo con MRP attivo e 0 gap! Questo è probabilmente lo snapshot più importante dopo SNAP-09.
> ```
> VBoxManage snapshot "rac1" take "SNAP-12_Duplicate_OK"
> VBoxManage snapshot "rac2" take "SNAP-12_Duplicate_OK"
> VBoxManage snapshot "racstby1" take "SNAP-12_Duplicate_OK"
> VBoxManage snapshot "racstby2" take "SNAP-12_Duplicate_OK"
> ```

---

## 📋 Comandi Data Guard Utili — Riferimento Rapido

```sql
-- Verificare errori DG sul primario
SELECT error FROM v$archive_dest WHERE dest_id = 2;

-- Stato MRP completo sullo standby
SELECT PROCESS, CLIENT_PROCESS, STATUS, THREAD#, SEQUENCE#, BLOCK#, BLOCKS
FROM GV$MANAGED_STANDBY;

-- Ruolo attuale del database
SELECT name, open_mode, database_role, db_unique_name FROM v$database;

-- Parametri DG attuali
SELECT name, value FROM v$parameter
WHERE name IN ('db_name','db_unique_name','log_archive_config',
  'log_archive_dest_1','log_archive_dest_2','fal_server','fal_client',
  'standby_file_management','db_file_name_convert','log_file_name_convert');
```

---

**→ Prossimo: [FASE 4: Configurazione Data Guard e DGMGRL](./GUIDA_FASE4_DATAGUARD_DGMGRL.md)**
