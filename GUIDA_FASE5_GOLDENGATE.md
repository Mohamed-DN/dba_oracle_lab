# FASE 5: Oracle GoldenGate verso Target Locale o OCI

> In questa fase configuriamo GoldenGate in modo coerente con il lab reale. La scelta base e supportata e questa: `Integrated Extract sul primary RACDB`, Data Pump verso target, Replicat sul target. Data Guard resta la tua piattaforma di DR e HA, non il punto di capture predefinito per GoldenGate.

---

## 5.0 Decisione Architetturale Prima di Partire

La documentazione Oracle impone una distinzione netta.

### Percorso base del repo

- `source capture`: `RACDB` primary
- `capture mode`: `Integrated Extract`
- `transport`: Data Pump GoldenGate
- `target`: `dbtarget` locale oppure OCI compute target
- `Data Guard`: continua a proteggere il source, ma non e il punto di capture base

### Perche ho corretto il flusso

Nel draft precedente il lab assumeva `Integrated Extract` sullo standby Active Data Guard. Questo non e il percorso base supportato da Oracle.

Punti tecnici chiave:

- `Integrated Extract` non cattura da uno standby fisico;
- `GoldenGate Free` non e il percorso corretto per il lab RAC 19c + DG principale;
- il target OCI free va separato dal percorso enterprise/licensed.

Conclusione pragmatica:

- Fase 5 base = capture sul primary;
- varianti con offload dal redo o standby = sezione avanzata, non flusso principale.

Schema:

```text
PRIMARY RAC (RACDB)
     |
     | Integrated Extract
     v
  Local Trail
     |
     | Data Pump
     v
TARGET
  - dbtarget locale
  - OCI compute target

Data Guard continua in parallelo come DR.
```

---

## 5.0A Ingresso da Fase 4 (check obbligatorio)

GoldenGate ha senso solo se Fase 4 e stabile.

```bash
dgmgrl sys/<password>@RACDB
SHOW CONFIGURATION;
SHOW DATABASE RACDB;
SHOW DATABASE RACDB_STBY;
```

```sql
sqlplus / as sysdba
SELECT name, open_mode, database_role, db_unique_name FROM v$database;
SELECT force_logging, supplemental_log_data_min FROM v$database;
```

Criteri minimi:

- Broker `SUCCESS` o warning gia compresi;
- primary `READ WRITE` e ruolo `PRIMARY`;
- standby sano e apply attivo;
- source stabile prima di toccare GoldenGate.

Se Fase 4 non e chiusa, torna a [GUIDA_FASE4_DATAGUARD_DGMGRL.md](./GUIDA_FASE4_DATAGUARD_DGMGRL.md).

---

## 5.0B Scegli il Target: Locale o OCI

### Opzione 1 - `dbtarget` locale

Usala se vuoi:

- ridurre variabili di rete;
- imparare GoldenGate prima del cloud;
- avere debug piu semplice.

### Opzione 2 - target OCI compute

Usala se vuoi:

- imparare una migrazione locale -> cloud;
- allenarti su listener, rete, NSG e target remoto.

Prima di usare OCI leggi:

- [GUIDA_RETE_LAB_OCI_GOLDENGATE.md](./GUIDA_RETE_LAB_OCI_GOLDENGATE.md)
- [GUIDA_GOLDENGATE_OCI_ARM.md](./GUIDA_GOLDENGATE_OCI_ARM.md)

---

## 5.1 Rete e Naming

Qualunque target tu scelga, il source deve risolvere e raggiungere il target.

### Per il target locale

Assumi `dbtarget.localdomain` raggiungibile da `rac1`.

### Per il target OCI

Assumi `dbtarget.localdomain` o `dbtarget` puntato all'IP corretto nel file `/etc/hosts` oppure nel DNS usato dal lab.

Test obbligatori da `rac1`:

```bash
ping dbtarget
nc -vz dbtarget 1521
# se target GG classic/core
nc -vz dbtarget 7809
# se target GG microservices
nc -vz dbtarget 9011
nc -vz dbtarget 9014
tnsping DBTARGET
```

Se questi test falliscono, non partire con GG.

---

## 5.2 Architettura Supportata del Lab

Flusso base:

```text
rac1/rac2 (PRIMARY RACDB)
   |
   | Integrated Extract on primary
   v
Local trail
   |
   | Pump
   v
Target DB
   |
   +--> locale
   +--> OCI compute
```

Perche il primary e il default giusto:

- e il percorso Oracle piu lineare e supportato per `Integrated Extract`;
- riduce ambiguita con Active Data Guard;
- semplifica troubleshooting e inizializzazione.

---

## 5.3 Prerequisiti Database sul Source

Sul primary `RACDB`:

```sql
sqlplus / as sysdba

ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
ALTER DATABASE FORCE LOGGING;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

SELECT force_logging,
       supplemental_log_data_min,
       supplemental_log_data_all
FROM   v$database;
```

Atteso:

- `FORCE_LOGGING = YES`
- `SUPPLEMENTAL_LOG_DATA_MIN = YES`
- `SUPPLEMENTAL_LOG_DATA_ALL = YES`

Nota:

- `FORCE LOGGING` e importante per Data Guard e GoldenGate, per evitare buchi di redo non loggato.

---

## 5.4 Prerequisiti sul Target

Sul target Oracle:

```sql
sqlplus / as sysdba
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH;
```

Se il target e multitenant:

- crea o scegli il PDB target;
- definisci un service dedicato;
- verifica listener e `tnsping`.

---

## 5.5 Creazione Utente GoldenGate

### Sul source

```sql
sqlplus / as sysdba

CREATE USER ggadmin IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, RESOURCE, ALTER SESSION TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT SELECT ANY TABLE TO ggadmin;
GRANT FLASHBACK ANY TABLE TO ggadmin;
GRANT EXECUTE ON DBMS_LOCK TO ggadmin;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
```

### Sul target

```sql
sqlplus / as sysdba

CREATE USER ggadmin IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, RESOURCE, ALTER SESSION TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
GRANT DBA TO ggadmin;
EXEC DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
```

Nel lab va bene essere larghi con i privilegi. In produzione li restringi.

---

## 5.6 Installazione Software GoldenGate

### Sul source

Installa GoldenGate nel nodo da cui gestirai l'Extract, tipicamente `rac1`.

Percorso esempio:

```bash
mkdir -p /u01/app/goldengate
chown oracle:oinstall /u01/app/goldengate
```

Poi installa il software GoldenGate coerente con il database source.

### Sul target

- se target locale: installa GoldenGate sul server target;
- se target OCI: segui [GUIDA_GOLDENGATE_OCI_ARM.md](./GUIDA_GOLDENGATE_OCI_ARM.md) per capire se stai usando un target `free validation` o un target realmente coerente con il lab principale.

### Variabili ambiente

```bash
cat >> /home/oracle/.bash_profile <<'EOF'
export OGG_HOME=/u01/app/goldengate/ogg
export PATH=$OGG_HOME:$PATH
export LD_LIBRARY_PATH=$OGG_HOME/lib:$ORACLE_HOME/lib:$LD_LIBRARY_PATH
EOF

source /home/oracle/.bash_profile
```

---

## 5.7 Configurazione Manager

### Sul source

```bash
cd $OGG_HOME
./ggsci
```

```text
GGSCI> CREATE SUBDIRS
GGSCI> EDIT PARAMS MGR
```

Parametri esempio:

```text
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTORESTART EXTRACT *, RETRIES 3, WAITMINUTES 5, RESETMINUTES 60
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPHOURS 24
```

```text
GGSCI> START MGR
GGSCI> INFO MGR
```

### Sul target

Manager analogo, adattando `AUTORESTART REPLICAT *`.

---

## 5.8 Configurazione Extract sul Primary

### 5.8.1 Login e registrazione

Su `rac1` come `oracle`:

```bash
cd $OGG_HOME
./ggsci
```

```text
GGSCI> DBLOGIN USERID ggadmin PASSWORD <password>
GGSCI> REGISTER EXTRACT ext_rac DATABASE
GGSCI> ADD EXTRACT ext_rac, INTEGRATED TRANLOG, BEGIN NOW
GGSCI> ADD EXTTRAIL ./dirdat/er, EXTRACT ext_rac, MEGABYTES 200
```

### 5.8.2 Parametri Extract

```text
GGSCI> EDIT PARAMS ext_rac
```

Esempio base:

```text
EXTRACT ext_rac
USERID ggadmin, PASSWORD <password>
EXTTRAIL ./dirdat/er
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT
DDL INCLUDE MAPPED
TRANLOGOPTIONS INTEGRATEDPARAMS (MAX_SGA_SIZE 256)

TABLE HR.*;
TABLE APP.*;
```

Nota pratica:

- in RAC il capture e logico sul database, ma l'istanza da cui amministri e `rac1`;
- usa servizi corretti per il login Oracle e per gli oggetti replicati.

---

## 5.9 Configurazione Data Pump

```text
GGSCI> ADD EXTRACT pump_rac, EXTTRAILSOURCE ./dirdat/er
GGSCI> ADD RMTTRAIL ./dirdat/rt, EXTRACT pump_rac, MEGABYTES 200
GGSCI> EDIT PARAMS pump_rac
```

Esempio:

```text
EXTRACT pump_rac
USERID ggadmin, PASSWORD <password>
RMTHOST dbtarget, MGRPORT 7809
RMTTRAIL ./dirdat/rt
PASSTHRU

TABLE HR.*;
TABLE APP.*;
```

Se usi microservices sul target, sostituisci il modello `RMTHOST/MGRPORT` con il percorso Distribution/Receiver coerente col deployment scelto.

---

## 5.10 Initial Load (Instanziazione)

GoldenGate non sostituisce l'initial load. Prima carichi i dati, poi applichi il delta.

### Step 1 - Prendi SCN consistente sul source

```sql
sqlplus / as sysdba
SELECT current_scn FROM v$database;
```

### Step 2 - Export consistente

```bash
expdp ggadmin/<password> \
  SCHEMAS=HR,APP \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=gg_init_%U.dmp \
  FILESIZE=2G \
  PARALLEL=4 \
  FLASHBACK_SCN=<SCN>
```

### Step 3 - Import sul target

```bash
impdp ggadmin/<password> \
  SCHEMAS=HR,APP \
  DIRECTORY=DATA_PUMP_DIR \
  DUMPFILE=gg_init_%U.dmp \
  PARALLEL=4 \
  TABLE_EXISTS_ACTION=REPLACE
```

### Step 4 - Allinea Extract allo stesso SCN

```text
GGSCI> DELETE EXTRACT ext_rac
GGSCI> ADD EXTRACT ext_rac, INTEGRATED TRANLOG, SCN <SCN>
GGSCI> ADD EXTTRAIL ./dirdat/er, EXTRACT ext_rac, MEGABYTES 200
```

Poi rimetti il parameter file `ext_rac`.

Questa e la logica corretta per evitare buchi o duplicati durante il bootstrap.

---

## 5.11 Configurazione Replicat sul Target

Sul target:

```bash
cd $OGG_HOME
./ggsci
```

```text
GGSCI> DBLOGIN USERID ggadmin PASSWORD <password>
GGSCI> ADD CHECKPOINTTABLE ggadmin.ggchkpt
GGSCI> ADD REPLICAT rep_rac, INTEGRATED, EXTTRAIL ./dirdat/rt
GGSCI> EDIT PARAMS rep_rac
```

Esempio:

```text
REPLICAT rep_rac
USERID ggadmin, PASSWORD <password>
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_rac.dsc, APPEND, MEGABYTES 100
HANDLECOLLISIONS

MAP HR.*, TARGET HR.*;
MAP APP.*, TARGET APP.*;
```

Nota:

- `HANDLECOLLISIONS` serve solo nella fase iniziale;
- dopo la convergenza, lo rimuovi e riavvii Replicat.

---

## 5.12 Ordine di Avvio

Ordine consigliato:

1. `START MGR` sul source
2. `START MGR` sul target
3. `START EXTRACT ext_rac`
4. `START EXTRACT pump_rac`
5. `START REPLICAT rep_rac`

Verifica:

```text
GGSCI> INFO ALL
GGSCI> STATS EXTRACT ext_rac, TOTAL
GGSCI> STATS EXTRACT pump_rac, TOTAL
GGSCI> STATS REPLICAT rep_rac, TOTAL
GGSCI> LAG EXTRACT ext_rac
GGSCI> LAG REPLICAT rep_rac
```

---

## 5.13 Criteri di Successo Fase 5

La fase e considerata chiusa se hai tutti questi punti:

- source primary stabile;
- target raggiungibile via rete e TNS;
- initial load completato;
- Extract `RUNNING`;
- Pump `RUNNING`;
- Replicat `RUNNING`;
- `lag` basso e controllato;
- DML di test replicato correttamente;
- Data Guard ancora sana dopo l'abilitazione GG.

Check Data Guard post-GG:

```sql
SELECT dest_id, status, error FROM v$archive_dest WHERE dest_id = 2;
```

---

## 5.14 Test Minimi Obbligatori

### DML smoke test

```sql
INSERT INTO HR.REGIONS (REGION_ID, REGION_NAME) VALUES (500, 'GG_TEST');
COMMIT;
UPDATE HR.REGIONS SET REGION_NAME='GG_TEST_UPD' WHERE REGION_ID=500;
COMMIT;
DELETE FROM HR.REGIONS WHERE REGION_ID=500;
COMMIT;
```

### Bulk test

- insert massivo in tabella di test;
- update di massa;
- delete di massa;
- verifica lag e throughput.

### DDL policy test

Se hai abilitato DDL replication, prova:

```sql
CREATE TABLE HR.GG_DDL_TEST (ID NUMBER, TXT VARCHAR2(30));
DROP TABLE HR.GG_DDL_TEST PURGE;
```

---

## 5.15 Varianti Avanzate e Limiti

### Variante A - Offload dal redo o standby

Non e il percorso base del repo.

Perche:

- `Integrated Extract` non cattura direttamente da physical standby;
- `Classic Extract` su Active Data Guard e un tema avanzato con limiti importanti;
- in ambienti multitenant o moderni e facile finire in combinazioni poco pulite.

### Variante B - Downstream mining database

Questa e la variante piu pulita se vuoi offload serio dal source:

- source continua a generare redo;
- redo viene spedito a un mining database dedicato;
- GoldenGate legge li.

E un caso avanzato, non la Fase 5 base.

### Variante C - GoldenGate Free

Usalo solo in un sotto-lab dedicato `Free-to-Free`.

Non usarlo come fondazione implicita del lab RAC 19c principale.

---

## 5.16 Troubleshooting Rapido

### `ORA-12514`

- service non registrato;
- alias TNS errato;
- target non nello stato giusto.

### `ORA-01017`

- password file/credenziali errate;
- utente GG non corretto.

### Extract `ABENDED`

- supplemental logging mancante;
- `enable_goldengate_replication` mancante;
- privilege GG incompleti;
- log mining issue.

### Replicat `ABENDED`

- oggetto assente sul target;
- collisioni non gestite;
- datatype mapping errato;
- constraint o chiavi non coerenti.

### Lag alto

- rete lenta;
- target lento;
- trail saturi;
- redo generation alta;
- parallelismo o sizing insufficienti.

---

## 5.17 Collegamento con la Migrazione Locale -> OCI

Per usare questa fase come migrazione cloud reale:

1. costruisci il target OCI con [GUIDA_GOLDENGATE_OCI_ARM.md](./GUIDA_GOLDENGATE_OCI_ARM.md)
2. chiarisci la rete con [GUIDA_RETE_LAB_OCI_GOLDENGATE.md](./GUIDA_RETE_LAB_OCI_GOLDENGATE.md)
3. usa [GUIDA_MIGRAZIONE_GOLDENGATE.md](./GUIDA_MIGRAZIONE_GOLDENGATE.md) per il cutover

Sequenza corretta:

- initial load al target cloud;
- delta continuo con GG;
- validazione conteggi/checksum;
- freeze applicativo;
- convergenza a lag 0;
- cutover del service applicativo verso cloud.

---

## 5.18 Fonti Oracle Ufficiali

- Integrated Extract cannot capture from standby: https://docs.oracle.com/en/middleware/goldengate/core/21.3/ggcab/overview-capture-active-data-guard-only-mode.html
- Active Data Guard only mode and classic capture notes: https://docs.oracle.com/en/middleware/goldengate/core/21.3/coredoc/extract-oracle-active-data-guard-only-mode.html
- Downstream capture overview: https://docs.oracle.com/en/middleware/goldengate/core/21.3/coredoc/extract-create-logmining-server-downstream-mining-database.html
- GoldenGate Free FAQ: https://docs.oracle.com/en/middleware/goldengate/free/23/overview/oracle-goldengate-free-faq.html

---

## 5.19 Conclusione Operativa

La Fase 5 del repo ora ha una regola semplice:

- Data Guard protegge;
- GoldenGate migra e replica;
- il capture base parte dal primary;
- OCI si aggancia come target solo dopo che rete e compatibilita sono state chiarite.
