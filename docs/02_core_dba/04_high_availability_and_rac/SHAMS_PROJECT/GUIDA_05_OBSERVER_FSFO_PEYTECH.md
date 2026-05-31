# SHAMS PROJECT: Observer Server e FSFO PEYTECH

## Obiettivo operativo

Attivare Fast-Start Failover (FSFO) dopo il collaudo di Data Guard Broker e
switchover manuale. La procedura vale per single instance, RAC, CDB e non-CDB:
FSFO opera sul database o sull'intera CDB, non sul singolo PDB.

Questa guida applica il modello della
[Fase 4B Observer FSFO](../GUIDA_FASE4B_FSFO_OBSERVER.md) al progetto SHAMS.

## Architettura

```text
                   observer1.<DOMAIN>
                   Oracle Client Administrator 19c
                   wallet SEPS + dgmgrl
                     /                 \
                    /                   \
       M24SHAMSPEC primary       M24SHAMSSEC standby
       Broker enabled            Broker enabled
```

L'Observer deve risiedere in un terzo dominio di guasto. Non installarlo sui
nodi primary o standby.

| Campo | Valore |
| --- | --- |
| Host Observer | `<OBSERVER1_FQDN>` |
| Backup Observer opzionale | `<OBSERVER2_FQDN>` |
| Oracle Client | Administrator 19c |
| Directory | `/home/oracle/admin/fsfo` |
| Wallet | `/home/oracle/admin/fsfo/wallet` |
| Config file | `/home/oracle/admin/fsfo/m24shams_observer1.dat` |
| Log | `/home/oracle/admin/fsfo/m24shams_observer1.log` |

## Prerequisiti

Prima di iniziare:

```text
SHOW CONFIGURATION;
VALIDATE DATABASE M24SHAMSPEC;
VALIDATE DATABASE M24SHAMSSEC;
```

Gate:

- Broker `SUCCESS`;
- SRL completi su entrambi i ruoli;
- redo diretto primary-standby;
- switchover e switchback validati;
- servizi role-based collaudati;
- Flashback Database raccomandato su entrambi i ruoli per auto-reinstate;
- rete Observer verso entrambi i siti verificata.

## Procedura operativa

### 1. Installazione Oracle Client

Installare Oracle Client Administrator 19c, che include `dgmgrl`, `mkstore`,
`sqlplus` e `tnsping`.

```bash
export ORACLE_HOME=<CLIENT_ORACLE_HOME>
export PATH="$ORACLE_HOME/bin:$PATH"
export TNS_ADMIN="$ORACLE_HOME/network/admin"

dgmgrl -help
mkstore -help
sqlplus -v
```

### 2. Oracle Net

Creare gli alias:

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

Per RAC, `<*_DG_ENDPOINT>` puo' essere uno SCAN o un endpoint dedicato
approvato. Verificare il comportamento durante indisponibilita' di un nodo.

```bash
tnsping M24SHAMSPEC_DG
tnsping M24SHAMSSEC_DG
```

### 3. Wallet SEPS

Non inserire password in command line o script:

```bash
mkdir -p /home/oracle/admin/fsfo/wallet
chmod 700 /home/oracle/admin/fsfo
chmod 700 /home/oracle/admin/fsfo/wallet

mkstore -wrl /home/oracle/admin/fsfo/wallet -create
mkstore -wrl /home/oracle/admin/fsfo/wallet \
  -createCredential M24SHAMSPEC_DG sys
mkstore -wrl /home/oracle/admin/fsfo/wallet \
  -createCredential M24SHAMSSEC_DG sys
```

Configurare `sqlnet.ora`:

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

Test:

```bash
sqlplus /@M24SHAMSPEC_DG as sysdba
sqlplus /@M24SHAMSSEC_DG as sysdba
dgmgrl /@M24SHAMSPEC_DG
```

### 4. Configurazione FSFO

Da DGMGRL:

```text
EDIT DATABASE M24SHAMSSEC SET PROPERTY LogXptMode='SYNC';
EDIT DATABASE M24SHAMSPEC SET PROPERTY LogXptMode='SYNC';
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;

EDIT DATABASE M24SHAMSPEC
  SET PROPERTY FastStartFailoverTarget='M24SHAMSSEC';
EDIT DATABASE M24SHAMSSEC
  SET PROPERTY FastStartFailoverTarget='M24SHAMSPEC';

EDIT CONFIGURATION SET PROPERTY FastStartFailoverThreshold=30;
EDIT CONFIGURATION SET PROPERTY FastStartFailoverLagLimit=0;
EDIT CONFIGURATION SET PROPERTY FastStartFailoverAutoReinstate=TRUE;
```

Il valore `30` e' un punto di partenza. Calibrarlo su RTO, stabilita' rete e
tempo di recovery.

### 5. Observe-only

```text
ENABLE FAST_START FAILOVER OBSERVE ONLY;
VALIDATE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
```

Avviare Observer con wallet:

```text
START OBSERVER observer1 IN BACKGROUND
  CONNECT IDENTIFIER IS M24SHAMSPEC_DG
  FILE IS '/home/oracle/admin/fsfo/m24shams_observer1.dat'
  LOGFILE IS '/home/oracle/admin/fsfo/m24shams_observer1.log';
```

Oracle documenta che `START OBSERVER ... IN BACKGROUND` ignora la connessione
DGMGRL corrente e usa il wallet. Senza wallet il comando fallisce.

Lasciare observe-only per la finestra approvata e verificare log, falsi positivi
e reachability.

### 6. Attivazione

```text
DISABLE FAST_START FAILOVER;
ENABLE FAST_START FAILOVER;
VALIDATE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

### 7. Backup Observer opzionale

Sul secondo host ripetere Oracle Client, TNS e wallet, poi:

```text
START OBSERVER observer2 IN BACKGROUND
  CONNECT IDENTIFIER IS M24SHAMSPEC_DG
  FILE IS '/home/oracle/admin/fsfo/m24shams_observer2.dat'
  LOGFILE IS '/home/oracle/admin/fsfo/m24shams_observer2.log';
```

Verificare quale Observer e' master:

```text
SHOW OBSERVER;
```

## Validazione finale

```text
SHOW CONFIGURATION;
VALIDATE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
SHOW OBSERVER;
```

Sul database:

```sql
SELECT * FROM v$fs_failover_stats;
```

Drill autorizzato:

1. eseguire backup e raccogliere evidenze;
2. isolare improvvisamente il primary secondo change approvato;
3. verificare promozione automatica, servizi e applicazione;
4. ripristinare connettivita';
5. verificare auto-reinstate o eseguire reinstate controllato;
6. provare perdita del solo host Observer senza causare failover.

Un normale `SHUTDOWN IMMEDIATE` non e' un test FSFO valido.

## Rollback

```text
DISABLE FAST_START FAILOVER;
SHOW FAST_START FAILOVER;
```

Se necessario ridurre l'impatto commit:

```text
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT DATABASE M24SHAMSSEC SET PROPERTY LogXptMode='ASYNC';
```

Non forzare disabilitazioni durante una partizione di rete senza aver
identificato il ruolo autorevole.

## Troubleshooting rapido

| Sintomo | Azione |
| --- | --- |
| Observer non parte | verifica wallet SEPS, alias, permessi e log |
| `VALIDATE FAST_START FAILOVER` fallisce | correggi Broker, SRL, target o protection mode |
| Reinstate non automatico | verifica Flashback Database e FRA |
| Commit lenti | valuta rollback autorizzato ad `ASYNC` |
| Observer master perso | verifica promozione backup Observer |
| CDB valida ma PDB non disponibile | controlla open state e servizi PDB role-based |
