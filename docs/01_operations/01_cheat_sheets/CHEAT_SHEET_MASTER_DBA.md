# Oracle DBA Master Cheat Sheet (Consolidata & Completa)

> **Scopo:** Questa è la guida operativa "gigante" del DBA, che raccoglie in un unico punto di riferimento tutti i comandi, le sintassi, i precheck e le procedure di troubleshooting relativi ai principali strumenti di amministrazione Oracle 19c. 

> [!TIP]
> **GUIDE DI PRODUZIONE E PROCEDURE OPERATIVE CORRELATE:**
> - **Backup & Recovery**: [FASE 5: Strategia RMAN Backup](../../02_core_dba/02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md) | [RMAN Enterprise](../../02_core_dba/02_backup_and_recovery/GUIDA_RMAN_COMANDI_ENTERPRISE.md)
> - **RAC & High Availability**: [RAC Primary + Standby Data Guard](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) | [Single Node Data Guard](../../02_core_dba/04_high_availability_and_rac/GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md)
> - **Data Guard Operations**: [Configurazione Broker (Fase 4)](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md) | [Switchover](../../02_core_dba/04_high_availability_and_rac/GUIDA_SWITCHOVER_COMPLETO.md) | [Failover & Reinstate](../../02_core_dba/04_high_availability_and_rac/GUIDA_FAILOVER_E_REINSTATE.md)
> - **Patching & Upgrades**: [Patching RAC](../../02_core_dba/05_patching_and_upgrades/GUIDA_PATCHING_RAC.md) | [Upgrade RU RAC](../../02_core_dba/05_patching_and_upgrades/GUIDA_UPGRADE_RU_RAC.md)
> - **Replicazione GoldenGate**: [GoldenGate Microservices (Fase 7)](../../02_core_dba/07_replication_goldengate/GUIDA_FASE7_GOLDENGATE.md) | [GoldenGate 19c Completa](../../02_core_dba/07_replication_goldengate/GUIDA_GOLDENGATE_19C_COMPLETA.md)

---

## Indice della Guida
1. [SRVCTL & CRSCTL (Clusterware & RAC Management)](#1-srvctl--crsctl-clusterware--rac-management)
2. [ASMCMD (ASM Storage Command Line)](#2-asmcmd-asm-storage-command-line)
3. [ADRCI (Diagnostic Repository Command Interpreter)](#3-adrci-diagnostic-repository-command-interpreter)
4. [DGMGRL (Data Guard Broker Command Line)](#4-dgmgrl-data-guard-broker-command-line)
5. [RMAN (Recovery Manager - Complete Reference)](#5-rman-recovery-manager---complete-reference)
6. [GoldenGate (GGSCI Command Line)](#6-goldengate-ggsci-command-line)
7. [SQLPlus, SQLcl, DBCA & NETCA](#7-sqlplus-sqlcl-dbca--netca)
8. [SQL Assessment DBA (Query Rapide)](#8-sql-assessment-dba-query-rapide)
9. [OPatch, OPatchAuto & Datapatch (Patching & Upgrades)](#9-opatch-opatchauto--datapatch-patching--upgrades)

---

## 1. SRVCTL & CRSCTL (Clusterware & RAC Management)

### Differenza Fondamentale
*   **`srvctl` (Server Control):** Gestisce le risorse Oracle a livello applicativo (database, istanze, servizi, listener, SCAN, ASM, diskgroup) registrate in Grid Infrastructure.
*   **`crsctl` (Clusterware Control):** Gestisce e diagnostica lo stack infrastrutturale del Clusterware stesso (CRS, CSS, EVM, OCR, voting disk, nodi del cluster).

*Regola di produzione:* Per le risorse Oracle (prefisso `ora.*`), prediligi sempre `srvctl`. Usa `crsctl` per la salute del Clusterware e la diagnostica generale.

### Comandi Help e Versione
```bash
srvctl -version
srvctl -help
srvctl status database -help
srvctl config service -help

crsctl -help
crsctl query crs activeversion
crsctl query crs softwareversion
```

### Health Check RAC / Grid
```bash
# Controlla la salute del Clusterware sul nodo locale
crsctl check crs

# Verifica lo stack del Clusterware su tutti i nodi
crsctl check cluster -all

# Visualizza lo stato di tutte le risorse del cluster in formato tabellare
crsctl stat res -t

# Visualizza lo stato sintattico iniziale (avvio) delle risorse locali
crsctl stat res -t -init

# Elenca i nodi del cluster con il rispettivo ID e stato
olsnodes -n -s -t
```

### Diagnostica OCR e Voting Disk
```bash
# Esegue un controllo di integrità dell'Oracle Cluster Registry (OCR)
ocrcheck

# Elenca i backup automatici e manuali dell'OCR
ocrconfig -showbackup

# Mostra i dischi di voto del cluster (voting disks) e il loro stato
crsctl query css votedisk
```

### Network Cluster e SCAN
```bash
# Mostra le interfacce di rete configurate nel Clusterware
oifcfg getif

# Mostra la configurazione di rete del database
srvctl config network

# Mostra la configurazione e gli indirizzi IP dello SCAN (Single Client Access Name)
srvctl config scan

# Mostra lo stato dei listener SCAN
srvctl status scan

# Mostra lo stato di tutti i listener SCAN del cluster
srvctl status scan_listener
```

### Gestione Database RAC (SRVCTL)
```bash
# Mostra la lista dei database registrati
srvctl config database

# Mostra la configurazione dettagliata di un database specifico
srvctl config database -d <DB_UNIQUE_NAME>

# Mostra la configurazione completa (compresi gli attributi aggiuntivi)
srvctl config database -d <DB_UNIQUE_NAME> -a

# Mostra lo stato di esecuzione di tutte le istanze del database
srvctl status database -d <DB_UNIQUE_NAME>

# Visualizza lo stato del database in modalità dettagliata (verbose)
srvctl status database -d <DB_UNIQUE_NAME> -v

# Mostra lo stato di una singola istanza specifica
srvctl status instance -d <DB_UNIQUE_NAME> -i <INSTANCE_NAME>
```

#### Start, Stop e Restart
```bash
# Avvia il database (tutte le istanze) su tutti i nodi del cluster
srvctl start database -d <DB_UNIQUE_NAME>

# Arresto ordinario (aspetta che le sessioni terminino)
srvctl stop database -d <DB_UNIQUE_NAME>

# Arresto immediato (consigliato in manutenzione)
srvctl stop database -d <DB_UNIQUE_NAME> -o immediate

# Arresto transazionale
srvctl stop database -d <DB_UNIQUE_NAME> -o transactional

# Gestione della singola istanza
srvctl start instance -d <DB_UNIQUE_NAME> -i <INSTANCE_NAME>
srvctl stop instance -d <DB_UNIQUE_NAME> -i <INSTANCE_NAME> -o immediate
```

#### Configurazione della Startup Policy
```bash
# Verifica la policy impostata (AUTOMATIC o MANUAL)
srvctl config database -d <DB_UNIQUE_NAME> | grep -i "management policy"

# Imposta la risorsa per avviarsi in automatico con il server/Grid
srvctl modify database -d <DB_UNIQUE_NAME> -policy AUTOMATIC

# Imposta l'avvio manuale (fortemente consigliato per Standby e ambienti di DR)
srvctl modify database -d <DB_UNIQUE_NAME> -policy MANUAL
```

### Gestione Servizi RAC (Role-Based)
```bash
# Visualizza l'elenco dei servizi registrati sul database
srvctl config service -d <DB_UNIQUE_NAME>

# Mostra lo stato attivo/inattivo dei servizi e su quali istanze girano
srvctl status service -d <DB_UNIQUE_NAME>

# Creazione di un servizio preferito per il ruolo PRIMARY
srvctl add service -d <DB_UNIQUE_NAME> -s APP_RW \
  -preferred <INST1>,<INST2> \
  -role PRIMARY \
  -policy AUTOMATIC

# Creazione di un servizio per il ruolo PHYSICAL_STANDBY (Active Data Guard)
srvctl add service -d <DB_UNIQUE_NAME> -s APP_RO \
  -preferred <INST1>,<INST2> \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC

# Avvio e Stop di un servizio specifico
srvctl start service -d <DB_UNIQUE_NAME> -s APP_RW
srvctl stop service -d <DB_UNIQUE_NAME> -s APP_RW

# Spostamento dinamico di un servizio da un'istanza all'altra (Relocate)
srvctl relocate service -d <DB_UNIQUE_NAME> -s APP_RW -oldinst <INST1> -newinst <INST2>
```

#### Validazione SQL dei Servizi
```sql
-- Verifica i servizi abilitati definiti a dizionario
select name, network_name, enabled from dba_services order by name;

-- Mostra i servizi attualmente attivi istanza per istanza
select inst_id, name from gv$active_services order by name, inst_id;
```

### Gestione Listener, SCAN e ASM
```bash
# Controllo e gestione dei Listener
srvctl status listener
srvctl config listener
srvctl start listener
srvctl stop listener

# Controllo e gestione dei Listener SCAN
srvctl status scan_listener
srvctl config scan_listener
srvctl start scan_listener
srvctl stop scan_listener

# Controllo listener classico da OS
lsnrctl status
lsnrctl services
```

#### ASM e Diskgroup
```bash
# Mostra lo stato dell'istanza ASM nel cluster
srvctl status asm

# Mostra la configurazione dell'istanza ASM
srvctl config asm

# Mostra lo stato di un diskgroup specifico
srvctl status diskgroup -g DATA

# Avvia/Monta un diskgroup su tutti i nodi del cluster
srvctl start diskgroup -g DATA

# Arresta/Smonta un diskgroup su tutti i nodi
srvctl stop diskgroup -g DATA
```

### Manutenzione Clusterware (Stop/Start totali)
```bash
# Avvio/Stop del CRS sul nodo locale (Grid Infrastructure)
crsctl stop crs
crsctl start crs

# Avvio/Stop di Clusterware e servizi su TUTTI i nodi del cluster (Alto Impatto!)
crsctl stop cluster -all
crsctl start cluster -all
```

---

## 2. ASMCMD (ASM Storage Command Line)

### Avvio e Connessione
```bash
# Imposta le variabili d'ambiente corrette puntando alla Grid Home e all'istanza ASM local
export ORACLE_SID=+ASM1
export ORACLE_HOME=<GRID_HOME>
export PATH=$ORACLE_HOME/bin:$PATH
asmcmd
```

#### Esecuzione non interattiva
```bash
asmcmd lsdg
asmcmd ls +DATA
asmcmd du +DATA/<DB_UNIQUE_NAME>
```

### Comandi Read-Only Sicuri
```bash
# Elenca lo stato, dimensione e spazio libero dei diskgroup
lsdg

# Elenca i client del database connessi a ciascun diskgroup
lsct

# Elenca i file e le directory all'interno del diskgroup
ls +DATA
ls +FRA

# Mostra il percorso di directory corrente
pwd

# Mostra lo spazio totale utilizzato da una directory
du +DATA/<DB_UNIQUE_NAME>

# Cerca file corrispondenti a un pattern
find +DATA spfile*

# Mostra gli attributi di un diskgroup specifico
lsattr -G DATA

# Elenca i file aperti dai client del database
lsof
```

### Struttura dei File ASM (Cosa stai guardando)
| Path ASM | Tipo di File | Descrizione |
|---|---|---|
| `+DATA/DB/DATAFILE` | Datafile | File dei dati del database |
| `+DATA/DB/TEMPFILE` | Tempfile | File temporanei per ordinamenti SQL |
| `+DATA/DB/ONLINELOG` | Redo Online | File di redo log attivi |
| `+DATA/DB/CONTROLFILE`| Controlfile | File di controllo del database |
| `+FRA/DB/ARCHIVELOG` | Archivelog | File di redo archiviati |
| `+FRA/DB/BACKUPSET` | RMAN Backup | Set di backup generati da RMAN |
| `+DATA/DB/PASSWORD` | Password File| File delle password SYS/amministrative |
| `+DATA/DB/PARAMETERFILE`| SPFILE | Server Parameter File di avvio |

### Operazioni di Copia File (ASMCMD cp)
Il comando `cp` di `asmcmd` supporta la copia bidirezionale tra ASM e File System OS, oltre alla copia interna tra diskgroup.

```bash
# Da ASM a File System locale (es. estrarre uno spfile o controlfile)
asmcmd cp +DATA/SOLE/PARAMETERFILE/spfile.123.456 /tmp/spfileSOLE.ora

# Da File System locale ad ASM (es. caricare un password file)
asmcmd cp /tmp/orapwSOLE +DATA/SOLE/PASSWORD/orapwsole

# Da ASM ad ASM (es. copiare un file verso un diskgroup di DR o altro DB)
asmcmd cp +DATA/SOLE/PASSWORD/orapwsole +DATA/M24/PASSWORD/orapwm24
```

### Password File in ASM
```bash
# Ottiene il percorso del password file registrato per un database
asmcmd pwget --dbuniquename SOLE

# Copia un password file ASM in un'altra locazione
asmcmd pwcopy +DATA/SOLE/PASSWORD/orapwsole +DATA/M24/PASSWORD/orapwm24

# Associa un password file ASM specifico al database nel cluster
asmcmd pwset --dbuniquename M24 +DATA/M24/PASSWORD/orapwm24
```

### Gestione Diskgroup e Rebalance (SQL)
Le operazioni strutturali sui dischi e i diskgroup vengono eseguite via SQL collegandosi come `sysasm`:

```sql
sqlplus / as sysasm

-- Verifica dettagliata dello stato e dell'efficienza dei diskgroup
select name, state, type, total_mb, free_mb, required_mirror_free_mb, usable_file_mb
from v$asm_diskgroup
order by name;

-- Mostra lo stato e il path dei dischi fisici ASM
select group_number, disk_number, name, path, header_status, mode_status, state
from v$asm_disk
order by group_number, disk_number;

-- Monitora il progresso delle operazioni di rebalance in corso
select group_number, operation, state, power, sofar, est_work, est_minutes
from v$asm_operation;

-- Forza un'operazione di rebalance per velocizzarla (power da 1 a 11+)
alter diskgroup DATA rebalance power 4;

-- Effettua una verifica logica del diskgroup senza riparare gli errori
alter diskgroup DATA check all norepair;
```

---

## 3. ADRCI (Diagnostic Repository Command Interpreter)

### Avvio e Selezione Home
L' utility ADRCI consente di analizzare i file di log diagnostici, gli alert log e le informazioni di trace centralizzate nell'Automatic Diagnostic Repository.

```bash
# Avvia l'utility
adrci

# Mostra il percorso base ADR
show base

# Elenca tutte le Diagnostic Home presenti sul server (DB, Grid, ASM, Listener)
show homes
```

#### Impostazione della Home corretta
```text
set homepath diag/rdbms/<db_unique_name>/<instance_name>

-- Esempi pratici:
set homepath diag/rdbms/sole/SOLE1
set homepath diag/asm/+asm/+ASM1
set homepath diag/tnslsnr/dbhost01/listener
```

### Alert Log (Lettura e Monitoraggio)
```text
# Visualizza le ultime 100 righe dell'alert log della home selezionata
show alert -tail 100

# Esegue il monitoring in tempo reale (equivalente a tail -f)
show alert -tail -f

# Filtra l'alert log alla ricerca di errori specifici
show alert -p "message_text like '%ORA-%'"
show alert -p "message_text like '%TNS-%'"
show alert -p "message_text like '%CRS-%'"

# Filtra i log degli errori nelle ultime due ore
show alert -p "originating_timestamp > systimestamp - interval '2' hour"
```

### Gestione Incidenti e Creazione Pacchetti IPS (Supporto)
Gli incidenti critici (es. `ORA-00600`, `ORA-07445`) generano dei file diagnostici strutturati che possono essere pacchettizzati automaticamente per essere caricati su My Oracle Support (MOS).

```text
# Elenca i problemi diagnostici rilevati
show problem

# Mostra l'elenco completo degli incidenti registrati
show incident

# Filtra gli incidenti legati a un errore specifico
show incident -p "problem_key like '%ORA 600%'"

# Mostra i dettagli analitici di un incidente specifico
show incident -mode detail -p "incident_id=<INCIDENT_ID>"

# IPS: Creazione automatica del pacchetto zip per Oracle Support
ips create package incident <INCIDENT_ID>
ips show package
ips generate package <PACKAGE_ID> in /tmp
```

### Pulizia dei Log Diagnostici (Retention Purge)
```text
# Mostra le impostazioni correnti di retention (SHORTP_POLICY e LONGP_POLICY in ore)
show control

# Esegue la rimozione manuale dei file di trace più vecchi di 30 giorni (43200 minuti)
purge -age 43200 -type trace

# Esegue la rimozione degli incidenti più vecchi di 90 giorni (129600 minuti)
purge -age 129600 -type incident
```

---

## 4. DGMGRL (Data Guard Broker Command Line)

### Avvio e Connessione
```bash
# Connessione locale con credenziali sys/sysdba/sysdg
dgmgrl /

# Connessione remota sicura tramite alias di rete dedicati
dgmgrl sys/password@SOLE_DG
```

### Comandi di Diagnostica e Stato (Sicuri)
```text
# Mostra lo stato generale della configurazione Data Guard
SHOW CONFIGURATION;

# Visualizza dettagli strutturali completi di un database specifico
SHOW DATABASE VERBOSE 'SOLE';
SHOW DATABASE VERBOSE 'M24';

# Visualizza la configurazione e le regole del Fast-Start Failover
SHOW FAST_START FAILOVER;

# Esegue una validazione profonda e precheck di salute su un database
VALIDATE DATABASE 'SOLE';
VALIDATE DATABASE VERBOSE 'M24';
```

### Modifica Proprietà e Parametri del Broker
```text
# Abilita o disabilita temporaneamente la configurazione
ENABLE CONFIGURATION;
DISABLE CONFIGURATION;

# Modifica il profilo di trasporto di redo log (es. ASYNC o SYNC)
EDIT DATABASE 'SOLE' SET PROPERTY LogXptMode='ASYNC';
EDIT DATABASE 'M24' SET PROPERTY LogXptMode='ASYNC';

# Modifica lo stato operativo del database (es. accende/spegne l'apply log)
EDIT DATABASE 'M24' SET STATE='LOG-APPLY-OFF';
EDIT DATABASE 'M24' SET STATE='APPLY-ON';

# Imposta la modalità di protezione dei dati della configurazione
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
```

### Ruoli e Transizioni (Switchover / Failover / Reinstate)
```text
# Esegue uno switchover pianificato e indolore promuovendo il database di standby
SWITCHOVER TO 'M24';

# Esegue un failover di emergenza promuovendo lo standby a seguito di disastro sul primario
FAILOVER TO 'M24';

# Reintegra un vecchio primario disallineato dopo un failover, riallineandolo come standby
REINSTATE DATABASE 'SOLE';
```

---

## 5. RMAN (Recovery Manager - Complete Reference)

### 1) Connessione a RMAN
```bash
# Connessione locale target come sysdba
rman target /

# Connessione a target con catalogo di ripristino esterno
rman target / catalog rman/password@catdb

# Connessione a istanza auxiliary di clone/standby in NOMOUNT
rman target sys/password@SOLE_DG auxiliary sys/password@M24_DG
```

### 2) Backup Database (Strategie e Comandi)
```rman
-- Backup classico del database
BACKUP DATABASE;

-- Backup del database e archivelog correnti
BACKUP DATABASE PLUS ARCHIVELOG;

-- Backup database, archivelog e successiva rimozione dei log fisici dal disco
BACKUP DATABASE PLUS ARCHIVELOG DELETE INPUT;

-- Backup compresso del database (consigliato per risparmiare spazio)
BACKUP AS COMPRESSED BACKUPSET DATABASE;

-- Backup specificando una locazione fisica e un formato di naming specifico
BACKUP DATABASE FORMAT '/backup/%d_%T_%s_%p.bkp';
```

#### Backup Incrementali (Level 0 e Level 1)
```rman
-- Backup di baseline (equivalente a un backup full ma abilitante la catena incrementale)
BACKUP INCREMENTAL LEVEL 0 DATABASE;

-- Backup incrementale differenziale (cattura solo i blocchi modificati dall'ultimo backup Level 0 o Level 1)
BACKUP INCREMENTAL LEVEL 1 DATABASE;

-- Backup incrementale cumulativo (cattura tutti i blocchi modificati dall'ultimo backup Level 0)
BACKUP INCREMENTAL LEVEL 1 CUMULATIVE DATABASE;
```

*Nota di Performance:* Per velocizzare i backup incrementali abilitare il Block Change Tracking (BCT) via SQL:
```sql
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '/u01/oradata/orcl/bct.dbf';
```

#### Backup dei singoli Oggetti
```rman
-- Backup di tablespace specifici
BACKUP TABLESPACE users, system;

-- Backup di un singolo datafile identificato dal numero o dal percorso
BACKUP DATAFILE 4;
BACKUP DATAFILE '/u01/oradata/orcl/users01.dbf';

-- Backup manuale del controlfile e del server parameter file (spfile)
BACKUP CURRENT CONTROLFILE;
BACKUP SPFILE;
```

#### Backup e Gestione Archivelog
```rman
-- Esegue il backup di tutti gli archivelog
BACKUP ARCHIVELOG ALL;

-- Esegue il backup e rimuove gli archivelog dal disco (consigliato per liberare FRA)
BACKUP ARCHIVELOG ALL DELETE INPUT;

-- Backup limitato a una sequenza specifica di log
BACKUP ARCHIVELOG FROM SEQUENCE 100 UNTIL SEQUENCE 200;

-- Backup degli archivelog generati nell'ultimo giorno
BACKUP ARCHIVELOG FROM TIME 'SYSDATE-1';
```

### 3) Restore & Recovery (Procedure e Scenari)
```rman
-- Ripristina e applica il recovery completo del database
RESTORE DATABASE;
RECOVER DATABASE;

-- Restore e Recovery specifici per un tablespace o un singolo datafile
RESTORE TABLESPACE users;
RECOVER TABLESPACE users;
RESTORE DATAFILE 4;
RECOVER DATAFILE 4;
```

#### Point-in-Time Recovery (PITR / Incompleto)
Usato in caso di errori logici applicativi (es. drop accidentale di tabelle).

```rman
-- Ripristino ad una data specifica
RESTORE DATABASE UNTIL TIME "TO_DATE('2026-05-28 10:00:00','YYYY-MM-DD HH24:MI:SS')";
RECOVER DATABASE UNTIL TIME "TO_DATE('2026-05-28 10:00:00','YYYY-MM-DD HH24:MI:SS')";

-- Ripristino ad un System Change Number (SCN) specifico
RESTORE DATABASE UNTIL SCN 1234567;
RECOVER DATABASE UNTIL SCN 1234567;
```

*IMPORTANTE:* Dopo un Point-in-Time Recovery (incompleto) è obbligatorio reimpostare la catena di log all'apertura del DB:
```sql
ALTER DATABASE OPEN RESETLOGS;
```

#### Ripristino del Controlfile e dello SPFILE (Disaster Recovery)
```rman
-- Ripristina lo spfile dall'autobackup automatico
RESTORE SPFILE FROM AUTOBACKUP;

-- Ripristina il controlfile dall'autobackup (richiede DB in stato NOMOUNT)
RESTORE CONTROLFILE FROM AUTOBACKUP;

-- Ripristina il controlfile da un file di backup fisico specifico
RESTORE CONTROLFILE FROM '/backup/ctl_backup.bkp';
```

#### Block Media Recovery (Riparazione Corruzione di Blocchi Singoli)
Consente di riparare blocchi corrotti specifici senza mettere offline il database o il datafile.

```rman
-- Ripara il blocco 100 all'interno del datafile 4
BLOCKRECOVER DATAFILE 4 BLOCK 100;

-- Ripara un gruppo di blocchi corrotti
BLOCKRECOVER DATAFILE 4 BLOCK 100,101,102;
```

### 4) Manutenzione del Catalogo RMAN, Crosscheck e Cleanup
```rman
-- Sincronizza il dizionario/catalogo RMAN con i file fisici effettivamente presenti a disco
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;

-- Rimuove dal catalogo i record dei backup marcati come "EXPIRED" (non più presenti fisicamente)
DELETE EXPIRED BACKUP;

-- Elenca e mostra i backup obsoleti che eccedono la retention policy definita
REPORT OBSOLETE;

-- Elimina i backup obsoleti liberando fisicamente spazio sul disco/FRA
DELETE OBSOLETE;
DELETE NOPROMPT OBSOLETE;

-- Elimina i backup e gli archivelog più vecchi di una settimana
DELETE BACKUP COMPLETED BEFORE 'SYSDATE-7';
DELETE ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-7';
```

### 5) Configurazione Globale RMAN (Best Practices)
```rman
-- Mostra tutti i parametri e le configurazioni attive
SHOW ALL;

-- Imposta la retention policy basata su una finestra temporale (consigliato: 7 o 14 giorni)
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;

-- Abilita l'autobackup automatico del controlfile e dello spfile ad ogni backup
CONFIGURE CONTROLFILE AUTOBACKUP ON;

-- Abilita l'ottimizzazione dei backup (salta i file immutabili già salvati)
CONFIGURE BACKUP OPTIMIZATION ON;

-- Imposta il parallelismo a 4 canali per velocizzare i processi di backup/restore
CONFIGURE DEVICE TYPE DISK PARALLELISM 4;

-- Ripristina i parametri di fabbrica predefiniti
CONFIGURE RETENTION POLICY CLEAR;
```

### 6) Catalogazione Manuale (Catalog)
```rman
-- Registra nel catalogo di RMAN un file di backup spostato o non rilevato
CATALOG BACKUPPIECE '/backup/backup.bkp';

-- Cataloga tutti i file di backup presenti all'interno di una directory specifica
CATALOG START WITH '/backup/';
```

### 7) Validazione e Simulazione (Validate / Preview)
Consente di verificare la leggibilità fisica dei file di backup e simulare le operazioni senza modificare lo stato del database.

```rman
-- Scansiona il database per verificare la presenza di corruzioni fisiche e logiche dei blocchi
VALIDATE DATABASE;
VALIDATE CHECK LOGICAL DATABASE;

-- Simula e verifica un'operazione di restore del database senza ripristinare alcun dato
RESTORE DATABASE VALIDATE;

-- Mostra in anteprima (Preview) quali backupset verranno utilizzati per il restore
RESTORE DATABASE PREVIEW;
```

### 8) Duplicazione Database (Duplicate)
```rman
-- Duplicazione classica da backup
DUPLICATE TARGET DATABASE TO newdb;

-- Duplicazione attiva via rete (Active Duplicate) senza richiedere backup fisici preventivi
DUPLICATE TARGET DATABASE TO newdb FROM ACTIVE DATABASE;

-- Active Duplicate con impostazioni specifiche di conversione path e spfile
DUPLICATE TARGET DATABASE TO M24
  FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
    PARAMETER_VALUE_CONVERT 'SOLE','M24'
    SET DB_UNIQUE_NAME='M24'
    SET DB_CREATE_FILE_DEST='+DATA_STBY'
    SET DB_RECOVERY_FILE_DEST='+FRA_STBY'
  NOFILENAMECHECK;
```

---

## 6. GoldenGate (GGSCI Command Line)

### Avvio e Connessione
```bash
# Avvia l'interfaccia a linea di comando di GoldenGate
ggsci
```

### Comandi di Stato e Monitoraggio (Read-Only)
```text
# Visualizza lo stato di salute di tutti i processi (Extract, Pump, Replicat) e dei Manager
INFO ALL

# Mostra i dettagli analitici, i percorsi trail e le statistiche di un processo specifico
INFO EXTRACT EX_PROD, DETAIL
INFO REPLICAT RE_PROD, DETAIL

# Calcola e visualizza il ritardo di replica (lag) corrente
LAG EXTRACT EX_PROD
LAG REPLICAT RE_PROD

# Mostra l'ultimo report di esecuzione, gli errori e le informazioni operative del processo
VIEW REPORT EX_PROD

# Mostra le statistiche sui volumi di record inseriti, modificati o cancellati (DML)
STATS EXTRACT EX_PROD, TOTAL
```

### Comandi Operativi (Change e Controllo)
```text
# Avvio e spegnimento controllato dei processi di replica
START EXTRACT EX_PROD
STOP EXTRACT EX_PROD

START REPLICAT RE_PROD
STOP REPLICAT RE_PROD

# Avvia e spegne il processo di coordinamento centrale (Manager)
START MANAGER
STOP MANAGER
```

---

## 7. SQLPlus, SQLcl, DBCA & NETCA

### Connessione con SQLPlus e SQLcl
```bash
# Connessione locale con autenticazione a livello di sistema operativo
sqlplus / as sysdba
sqlplus / as sysasm

# Connessione remota sicura
sqlplus system@//dbhost01:1521/SOLE_SERVICE
sqlplus sys@//dbhost01:1521/SOLE_SERVICE as sysdba
```

### Setup Standard dell'Ambiente DBA in SQLPlus
Per formattare correttamente gli output ed evitare testi spezzati in console:

```sql
set lines 220 pages 200 trimspool on tab off
set long 100000 longchunksize 100000
column name format a30
column value format a80
set timing on
set serveroutput on

-- Prompt personalizzato che mostra l'utente e il database corrente
set sqlprompt "_user'@'_connect_identifier> "

-- Esecuzione di uno spool pulito per raccogliere evidenze diagnostiche
spool /tmp/evidence_diagnostica.log
SELECT name, open_mode, database_role FROM v$database;
spool off
```

### Comandi di Startup e Shutdown Database (SQLPlus)
```sql
-- Startup del Database
STARTUP;            -- Avvia l'istanza, monta e apre il database in Read/Write
STARTUP MOUNT;      -- Avvia l'istanza e monta il database (necessario per backup/DR)
STARTUP NOMOUNT;    -- Avvia solo l'istanza in memoria (necessario per creare DB/duplicate)

-- Shutdown del Database
SHUTDOWN IMMEDIATE; -- Arresto controllato standard (rollback transazioni attive)
SHUTDOWN ABORT;     -- Spegnimento brutale immediato (consigliato solo in emergenza)
```

---

## 8. SQL Assessment DBA (Query Rapide)

Queste query consentono di raccogliere rapidamente metriche, sizing, lock, crescita e volumi di attività su database attivi.

### 1) Calcolo della Dimensione Allocata Totale del Database
```sql
SELECT
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM dba_data_files), 2) AS datafiles_gb,
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM dba_temp_files), 2) AS tempfiles_gb,
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM v$log), 2) AS redo_logs_gb,
    ROUND(
        (SELECT SUM(bytes)/1024/1024/1024 FROM dba_data_files) +
        (SELECT SUM(bytes)/1024/1024/1024 FROM dba_temp_files) +
        (SELECT SUM(bytes)/1024/1024/1024 FROM v$log)
    , 2) AS total_allocated_gb
FROM dual;
```

### 2) Monitoraggio e Analisi delle Sessioni Bloccate (Lock/Contese)
```sql
SELECT
    s1.username || '@' || s1.machine || ' ( SID=' || s1.sid || ' )' AS sessione_bloccante,
    s2.username || '@' || s2.machine || ' ( SID=' || s2.sid || ' )' AS sessione_bloccata,
    sq.sql_text AS sql_bloccato
FROM v$lock l1
JOIN v$session s1 ON l1.sid = s1.sid
JOIN v$lock l2 ON l1.id1 = l2.id1 AND l1.id2 = l2.id2
JOIN v$session s2 ON l2.sid = s2.sid
JOIN v$sql sq ON s2.sql_address = sq.address
WHERE l1.block = 1 AND l2.request > 0;
```

#### Kill di una sessione bloccante
```sql
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
```

### 3) Analisi dello Spazio Libero e Utilizzato nei Tablespace
```sql
SELECT 
    df.tablespace_name,
    ROUND(df.spazio_allocato_mb, 2) AS allocato_mb,
    ROUND(df.spazio_allocato_mb - fs.spazio_libero_mb, 2) AS usato_mb,
    ROUND(fs.spazio_libero_mb, 2) AS libero_mb,
    ROUND(((df.spazio_allocato_mb - fs.spazio_libero_mb) / df.spazio_allocato_mb) * 100, 2) AS percentuale_usato
FROM (
    SELECT tablespace_name, SUM(bytes)/1024/1024 AS spazio_allocato_mb 
    FROM dba_data_files GROUP BY tablespace_name
) df
JOIN (
    SELECT tablespace_name, SUM(bytes)/1024/1024 AS spazio_libero_mb 
    FROM dba_free_space GROUP BY tablespace_name
) fs ON df.tablespace_name = fs.tablespace_name
ORDER BY percentuale_usato DESC;
```

### 4) Calcolo del Volume Giornaliero di Redo Log Generato (Redo Rate)
Fornisce metriche precise necessarie per il dimensionamento della FRA e dei canali di replica Data Guard e GoldenGate.

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS ora,
       ROUND(SUM(blocks * block_size)/1024/1024/1024,2) redo_gb
FROM   v$archived_log
WHERE  first_time > SYSDATE - 7
GROUP  BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER  BY ora;
```

---

## 9. OPatch, OPatchAuto & Datapatch (Patching & Upgrades)

### Strumenti e Differenze
*   **`opatch`:** Applica modifiche binarie a livello software su una specifica Oracle Home.
*   **`opatchauto`:** Gestisce il patching binarie in ambienti cluster RAC automatizzando stop, upgrade di Grid e DB, e riavvio dei nodi.
*   **`datapatch`:** Applica le patch SQL a livello di dizionario dati all'interno del database.

### Precheck e Informazioni di Versione
```bash
# Verifica la versione corrente di OPatch installata
$ORACLE_HOME/OPatch/opatch version

# Visualizza l'elenco delle patch binarie applicate a questa Oracle Home
$ORACLE_HOME/OPatch/opatch lsinventory
```

### Procedura Standby-First Patching (Best Practices MAA)

> [!WARNING]
> **COMPATIBILITÀ OJVM IN DATA GUARD (MOS Note 1929745.1)**
> Le patch **OJVM non supportano l'interoperabilità di versioni diverse tra Primario e Standby**. 
> Se devi applicare patch OJVM in configurazioni Data Guard, adotta una delle seguenti strategie:
> 1. **Downtime Coordinato (Consigliato):** Stop del redo apply, spegnimento di entrambi i DB, patching dei binari su entrambi i siti, avvio del primario, esecuzione di `datapatch` sul primario (la parte SQL si propaga via redo allo standby montato).
> 2. **Out-of-Place Patching:** Creazione di nuove Oracle Home patchate complete a monte sia sul primario che sullo standby, minimizzando il downtime al solo riavvio dei servizi.

#### 1) Aggiornamento preventivo di OPatch (Obbligatorio)
Prima di lanciare qualsiasi installazione, scarica la patch **6880880** da MOS Note **274526.1** ed estraila su tutti i nodi:
```bash
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_old_backup
unzip -q p6880880_190000_Linux-x86-64.zip -d $ORACLE_HOME
```

#### 2) Stop Redo Apply e spegnimento Standby (Sito Standby)
Dal Broker Data Guard:
```text
DGMGRL> EDIT DATABASE 'M24' SET STATE='LOG-APPLY-OFF';
```
Sul server Standby:
```sql
sqlplus / as sysdba
SHUTDOWN IMMEDIATE;
```
Fermare il listener DG:
```bash
lsnrctl stop LISTENER_DG
```

#### 3) Applicazione Patch Binarie su Standby
```bash
cd /path/to/patch/RU
$ORACLE_HOME/OPatch/opatch apply -silent

cd /path/to/patch/OJVM
$ORACLE_HOME/OPatch/opatch apply -silent
```

#### 4) Avvio Standby e Patching Primario
Avviare lo standby in stato `MOUNT`:
```bash
lsnrctl start LISTENER_DG
```
```sql
sqlplus / as sysdba
STARTUP MOUNT;
```
Ripetere i passaggi dello spegnimento e dell'applicazione delle patch binarie (RU + OJVM) sul server **Primario**.

#### 5) Esecuzione di Datapatch sul Primario Attivo
Una volta che entrambi i siti (Primario e Standby) eseguono lo stesso livello di binari patchati, connettersi **esclusivamente al Primario** ed eseguire:

```bash
cd $ORACLE_HOME/OPatch
./datapatch -verbose
```

*Nota Importante:* Non lanciare mai `datapatch` sul database Standby Fisico.

#### 6) Ricompilazione e Verifica
```sql
sqlplus / as sysdba

-- Ricompila gli eventuali oggetti invalidati dalle modifiche SQL del dizionario
@?/rdbms/admin/utlrp.sql

-- Interroga lo stato storico dell'applicazione delle patch SQL nel DB
SET LINES 200 PAGES 100
COL version FORMAT A12
COL status FORMAT A15
COL description FORMAT A60
SELECT patch_id, patch_uid, version, status, description 
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;
```

#### 7) Riattivazione Data Guard
Dal Broker:
```text
DGMGRL> EDIT DATABASE 'M24' SET STATE='APPLY-ON';
DGMGRL> SHOW CONFIGURATION;
DGMGRL> VALIDATE DATABASE 'M24';
```
