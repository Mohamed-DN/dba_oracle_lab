# FASE 4B: Observer Server e Fast-Start Failover (FSFO)

> Target lab: Oracle Database 19c, RAC primary `RACDB`, RAC physical standby
> `RACDB_STBY`, Data Guard Broker già operativo.

Questa fase viene dopo la [Fase 4: Data Guard Broker](./GUIDA_FASE4_DATAGUARD_DGMGRL.md)
e prima della [Fase 5: RMAN Backup](../02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md).

## 1. Obiettivo

Rendere operativo il failover automatico Data Guard con:

- un Observer dedicato `observer1.localdomain` (`192.168.56.121`);
- Fast-Start Failover (FSFO) in modalità `MaxAvailability` + `SYNC`;
- wallet Oracle SEPS, senza password in chiaro nella command line;
- validazione prima in modalità `OBSERVE ONLY`, poi in modalità attiva;
- un secondo Observer opzionale `observer2.localdomain` (`192.168.56.122`).

L'Observer non contiene dati del database. È un client OCI leggero che monitora
primary e standby tramite Data Guard Broker e decide il failover quando le
condizioni FSFO sono soddisfatte.

## 2. Prerequisiti

### 2.1 Topologia

| Host | IP | Risorse Lab | Obbligatorio | Ruolo |
| --- | --- | --- | --- | --- |
| `observer1.localdomain` | `192.168.56.121` | 1 vCPU, 2 GB RAM, 20 GB disco | Sì | Master Observer |
| `observer2.localdomain` | `192.168.56.122` | 1 vCPU, 2 GB RAM, 20 GB disco | No | Backup Observer |

> [!IMPORTANT]
> L'Observer deve stare su un host separato da primary e standby. Il modulo
> `vagrant_rac_dataguard` non provisiona queste VM: creale manualmente come VM
> Oracle Linux leggere o usa host equivalenti in un terzo dominio di guasto.

### 2.2 Gate Data Guard

Prima di configurare FSFO, esegui da `rac1`:

```bash
dgmgrl sys@RACDB
```

```dgmgrl
SHOW CONFIGURATION;
VALIDATE DATABASE RACDB;
VALIDATE DATABASE RACDB_STBY;
SHOW DATABASE VERBOSE RACDB;
SHOW DATABASE VERBOSE RACDB_STBY;
```

Gate minimo:

- `SHOW CONFIGURATION` restituisce `SUCCESS`;
- `RACDB_STBY` riceve redo direttamente da `RACDB`;
- standby redo log presenti su entrambi i database per gestire i role change;
- `DGConnectIdentifier` risolvibili dagli host Observer;
- static listener Broker già validati dalla Fase 4.

Verifica gli standby redo log su primary e standby:

```sql
SELECT thread#, group#, sequence#, bytes / 1024 / 1024 AS size_mb, status
FROM   v$standby_log
ORDER  BY thread#, group#;
```

### 2.3 Flashback Database

Oracle raccomanda Flashback Database su primary e standby per permettere il
reinstate automatico del vecchio primary. FSFO può essere abilitato senza
Flashback Database, ma il Broker segnala un warning e il reinstate rapido non è
garantito.

```sql
SELECT db_unique_name, flashback_on FROM v$database;
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;
```

Se necessario, abilitalo seguendo
[Guida Flashback Database](./GUIDA_FLASHBACK_DATABASE.md).

## 3. Rischi e Impatto

- FSFO attivo può promuovere automaticamente lo standby: non abilitarlo prima
  di aver validato rete, servizi applicativi e procedure di reinstate.
- Il profilo base usa `MaxAvailability` + `SYNC`: offre zero data loss mode, ma
  aggiunge latenza ai commit. Misura la latenza prima dell'uso in produzione.
- Un normale `SHUTDOWN IMMEDIATE` non genera FSFO. Per un drill serve un crash o
  un isolamento improvviso controllato.
- `DISABLE FAST_START FAILOVER FORCE` durante una partizione di rete richiede
  cautela: eseguilo prima sul target standby per evitare ruoli primary
  concorrenti.

## 4. Procedura Operativa

### 4.1 Creare la VM Observer

Crea manualmente `observer1` con Oracle Linux 7.9 o 8.x:

- hostname: `observer1.localdomain`;
- IP host-only: `192.168.56.121/24`;
- DNS: `192.168.56.50`;
- risorse: 1 vCPU, 2 GB RAM, 20 GB disco.

Sul DNS node aggiungi:

```text
192.168.56.121   observer1.localdomain   observer1
192.168.56.122   observer2.localdomain   observer2
```

La seconda entry prepara il backup Observer opzionale.

Da `observer1` verifica:

```bash
getent hosts rac-scan racstby-scan observer1
ping -c 2 rac-scan
ping -c 2 racstby-scan
```

### 4.2 Installare Oracle Client Administrator 19c

Scarica Oracle Database Client 19c dal portale Oracle ed esegui l'installer
scegliendo il tipo **Administrator**. Questo tipo include `dgmgrl`, `mkstore`,
`sqlplus` e `tnsping`.

Verifica:

```bash
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/client_1
export PATH=$ORACLE_HOME/bin:$PATH
export TNS_ADMIN=$ORACLE_HOME/network/admin

dgmgrl -help
mkstore -help
sqlplus -v
tnsping RACDB
```

Persisti `ORACLE_HOME`, `PATH` e `TNS_ADMIN` nel profilo dell'utente `oracle`.

### 4.3 Configurare Oracle Net

Crea `$TNS_ADMIN/tnsnames.ora` su `observer1`:

```text
RACDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA = (SERVICE_NAME = RACDB))
  )

RACDB_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA = (SERVICE_NAME = RACDB_STBY))
  )
```

Verifica:

```bash
tnsping RACDB
tnsping RACDB_STBY
```

### 4.4 Creare il wallet SEPS

Il comando `START OBSERVER IN BACKGROUND` legge le credenziali da Oracle Wallet.
Non inserire password negli script o nella command line.

```bash
mkdir -p /home/oracle/admin/fsfo/wallet
chmod 700 /home/oracle/admin/fsfo
chmod 700 /home/oracle/admin/fsfo/wallet

mkstore -wrl /home/oracle/admin/fsfo/wallet -create
mkstore -wrl /home/oracle/admin/fsfo/wallet -createCredential RACDB sys
mkstore -wrl /home/oracle/admin/fsfo/wallet -createCredential RACDB_STBY sys
mkstore -wrl /home/oracle/admin/fsfo/wallet -listCredential
```

Aggiungi a `$TNS_ADMIN/sqlnet.ora`:

```text
WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /home/oracle/admin/fsfo/wallet)
    )
  )

SQLNET.WALLET_OVERRIDE = TRUE
```

Verifica il login senza password in chiaro:

```bash
sqlplus /@RACDB as sysdba
sqlplus /@RACDB_STBY as sysdba
dgmgrl /@RACDB
```

### 4.5 Impostare zero data loss mode

Da una sessione DGMGRL:

```bash
dgmgrl /@RACDB
```

```dgmgrl
EDIT DATABASE RACDB_STBY SET PROPERTY LogXptMode='SYNC';
EDIT DATABASE RACDB SET PROPERTY LogXptMode='SYNC';
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;

EDIT DATABASE RACDB SET PROPERTY FastStartFailoverTarget='RACDB_STBY';
EDIT DATABASE RACDB_STBY SET PROPERTY FastStartFailoverTarget='RACDB';
EDIT CONFIGURATION SET PROPERTY FastStartFailoverThreshold=30;
EDIT CONFIGURATION SET PROPERTY FastStartFailoverLagLimit=0;
EDIT CONFIGURATION SET PROPERTY FastStartFailoverAutoReinstate=TRUE;

SHOW CONFIGURATION;
```

Il valore `30` secondi è adatto al lab. In produzione deve essere calibrato
sulla stabilità della rete e sul tempo di recovery richiesto.

### 4.6 Avviare prima in OBSERVE ONLY

Da `observer1`:

```bash
dgmgrl /@RACDB
```

```dgmgrl
ENABLE FAST_START FAILOVER OBSERVE ONLY;

START OBSERVER observer1 IN BACKGROUND
  CONNECT IDENTIFIER IS RACDB
  FILE IS '/home/oracle/admin/fsfo/observer1.dat'
  LOGFILE IS '/home/oracle/admin/fsfo/observer1.log';

VALIDATE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

In modalità `OBSERVE ONLY`, Broker registra nei log cosa avrebbe fatto, ma non
promuove realmente lo standby.

Controlla il log:

```bash
tail -f /home/oracle/admin/fsfo/observer1.log
```

### 4.7 Passare alla modalità attiva

Quando la validazione non segnala blocchi:

```dgmgrl
DISABLE FAST_START FAILOVER;
ENABLE FAST_START FAILOVER;

VALIDATE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Output atteso:

```text
Fast-Start Failover: Enabled in Zero Data Loss Mode
  Protection Mode: MaxAvailability
  Lag Limit:       0 seconds
```

### 4.8 Variante ASYNC con possibile perdita dati

Usa questa variante solo quando la latenza `SYNC` non è accettabile:

```dgmgrl
DISABLE FAST_START FAILOVER;
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT DATABASE RACDB_STBY SET PROPERTY LogXptMode='ASYNC';
EDIT DATABASE RACDB SET PROPERTY LogXptMode='ASYNC';
EDIT CONFIGURATION SET PROPERTY FastStartFailoverLagLimit=30;
ENABLE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
```

Con `MaxPerformance`, FSFO può causare perdita dati fino al limite configurato.

### 4.9 Aggiungere observer2 come backup opzionale

Prepara `observer2` come `observer1`, con wallet SEPS e file Oracle Net propri.
Poi avvia un secondo Observer con nome univoco:

```dgmgrl
START OBSERVER observer2 IN BACKGROUND
  CONNECT IDENTIFIER IS RACDB
  FILE IS '/home/oracle/admin/fsfo/observer2.dat'
  LOGFILE IS '/home/oracle/admin/fsfo/observer2.log';

SHOW OBSERVER;
```

Oracle Database 19c supporta fino a tre Observer per configurazione: uno master
e gli altri backup. Per verificare il failover dell'Observer, arresta solo il
processo su `observer1` e controlla da `observer2` che un Observer registrato
rimanga disponibile. Non spegnere i database durante questo test.

## 5. Persistenza systemd

`START OBSERVER IN BACKGROUND` è il metodo DGMGRL preferito. Per riavviarlo dopo
un reboot della VM, crea `/etc/systemd/system/dg-observer.service`:

```ini
[Unit]
Description=Oracle Data Guard FSFO Observer
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=oracle
Environment=ORACLE_HOME=/u01/app/oracle/product/19.0.0/client_1
Environment=TNS_ADMIN=/u01/app/oracle/product/19.0.0/client_1/network/admin
Environment=PATH=/u01/app/oracle/product/19.0.0/client_1/bin:/usr/bin:/bin
ExecStart=/bin/bash -lc "echo \"START OBSERVER observer1 IN BACKGROUND CONNECT IDENTIFIER IS RACDB FILE IS '/home/oracle/admin/fsfo/observer1.dat' LOGFILE IS '/home/oracle/admin/fsfo/observer1.log';\" | dgmgrl /@RACDB"
ExecStop=/bin/bash -lc "echo \"STOP OBSERVER observer1;\" | dgmgrl /@RACDB"

[Install]
WantedBy=multi-user.target
```

Attiva e valida:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now dg-observer
systemctl status dg-observer
echo "SHOW OBSERVER;" | dgmgrl /@RACDB
```

## 6. Rollback

Con primary e standby connessi:

```dgmgrl
DISABLE FAST_START FAILOVER;
STOP OBSERVER observer1;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Per tornare alla baseline della Fase 4:

```dgmgrl
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT DATABASE RACDB_STBY SET PROPERTY LogXptMode='ASYNC';
EDIT DATABASE RACDB SET PROPERTY LogXptMode='ASYNC';
SHOW CONFIGURATION;
```

> [!WARNING]
> Durante una partizione di rete, leggi la procedura Oracle per
> `DISABLE FAST_START FAILOVER FORCE`. Se devi usare `FORCE`, applicalo prima
> dal target standby e conferma il ruolo corrente dei database.

## 7. Validazione Finale

Esegui:

```dgmgrl
SHOW CONFIGURATION;
VALIDATE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

```sql
SELECT last_failover_time, last_failover_reason
FROM   v$fs_failover_stats;
```

Checklist pass/fail:

- [ ] `SHOW CONFIGURATION` = `SUCCESS`
- [ ] `VALIDATE FAST_START FAILOVER` senza blocchi
- [ ] FSFO = `Enabled in Zero Data Loss Mode`
- [ ] `Protection Mode` = `MaxAvailability`
- [ ] `Lag Limit` = `0 seconds`
- [ ] `observer1` registrato e raggiungibile
- [ ] wallet e log Observer leggibili solo dall'utente `oracle`

Per il drill distruttivo opzionale continua con
[Fase 8: Test di Verifica](../../03_infra_lab/02_oracle_installation_asm/GUIDA_FASE8_TEST_VERIFICA.md).

## 8. Troubleshooting Rapido

| Sintomo | Causa probabile | Azione |
| --- | --- | --- |
| `START OBSERVER IN BACKGROUND` fallisce | Wallet mancante o alias non presente | Verifica `mkstore -listCredential`, `sqlnet.ora` e `tnsping` |
| `ORA-16819` | Observer non avviato | Esegui `SHOW OBSERVER`, controlla log e servizio `systemd` |
| `VALIDATE FAST_START FAILOVER` segnala lag | Standby fuori soglia | Risolvi transport/apply lag prima di abilitare FSFO attivo |
| Warning Flashback disabilitato | Reinstate rapido non garantito | Abilita Flashback Database su entrambi i database |
| Commit più lenti dopo `SYNC` | Latenza rete | Misura RTT; valuta `FASTSYNC` o la variante `ASYNC` con RPO esplicito |
| Observer master non disponibile | Host Observer guasto | Avvia `observer2` e verifica gli Observer registrati |

## 9. Riferimenti

- [Oracle Data Guard Installation](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/oracle-data-guard-broker-installation-requirements.html)
- [Switchover and Failover Operations](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/using-data-guard-broker-to-manage-switchovers-failovers.html)
- [DGMGRL Command Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/dgbkr/oracle-data-guard-broker-commands.html)
- [Secure External Password Store](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-authentication.html)
- [Failover e Reinstate](./GUIDA_FAILOVER_E_REINSTATE.md)

---

**← [FASE 4: Data Guard Broker](./GUIDA_FASE4_DATAGUARD_DGMGRL.md)** |
**→ [FASE 5: RMAN Backup](../02_backup_and_recovery/GUIDA_FASE5_RMAN_BACKUP.md)**
