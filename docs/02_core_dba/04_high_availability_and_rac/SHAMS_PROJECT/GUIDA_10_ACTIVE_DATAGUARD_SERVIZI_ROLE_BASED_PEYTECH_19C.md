# SHAMS PROJECT: Active Data Guard e Servizi Role-Based PEYTECH Oracle 19c

## Obiettivo operativo

Aprire uno standby fisico in `READ ONLY WITH APPLY` e pubblicare servizi
role-based senza confondere il percorso Data Guard base con l'opzione Active
Data Guard (ADG).

Il physical standby in `MOUNTED` con Redo Apply e' il percorso base. La lettura
mentre apply continua e' un'estensione opzionale.

## Gate licenza

| Contesto | Regola |
| --- | --- |
| Laboratorio personale | Esercitazione ammessa solo nei limiti dei termini developer accettati al download, per sviluppo, test, prototipi o autoformazione |
| Produzione o uso aziendale | Attivare ADG solo con evidenza formale di entitlement |
| Oracle EE | Active Data Guard e' un'opzione extra-cost |

Fonte: [Oracle Database 19c Licensing Information](https://docs.oracle.com/en/database/oracle/oracle-database/19/dblic/Licensing-Information.html).

Non usare questa guida come parere legale. Nel change registra sempre
`<EVIDENZA_LICENZA oppure LAB_PERSONALE>`.

## Assessment

Prima dell'attivazione:

```sql
SELECT name, db_unique_name, database_role, open_mode
FROM v$database;

SELECT name, value, unit
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag', 'apply finish time');

SELECT process, status, thread#, sequence#
FROM v$managed_standby
WHERE process IN ('MRP0', 'RFS', 'ARCH');
```

Verifica inoltre:

- Broker `SUCCESS`;
- SRL completi per ogni thread;
- lag entro soglia;
- FRA con spazio;
- servizi `_PRY` e `_RO` definiti con owner applicativo;
- PDB applicativo aperto in lettura solo nei blueprint CDB.

## Procedura operativa

### 1. Attivazione ADG sullo standby

Sullo standby:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
ALTER DATABASE OPEN READ ONLY;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;

SELECT open_mode, database_role
FROM v$database;
```

Atteso:

```text
READ ONLY WITH APPLY | PHYSICAL STANDBY
```

Non usare `USING CURRENT LOGFILE`: in Oracle 19c e' una clausola storica e
deprecata. Gli SRL corretti abilitano real-time apply.

Per tornare al percorso base:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE CANCEL;
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE DISCONNECT FROM SESSION;
```

### 2. Servizi role-based

I servizi applicativi devono seguire il ruolo, non il nome del sito:

| Servizio | Ruolo | Uso |
| --- | --- | --- |
| `M24SHAMSC_PRY` | `PRIMARY` | traffico read-write |
| `M24SHAMSC_RO` | `PHYSICAL_STANDBY` | reporting read-only, solo con ADG autorizzato |

Prima dei comandi, verifica la sintassi della RU:

```bash
srvctl add service -help
srvctl modify service -help
```

Single instance, esempio da adattare:

```bash
srvctl add service -db M24SHAMSPEC -service M24SHAMSC_PRY \
  -role PRIMARY -policy AUTOMATIC

srvctl add service -db M24SHAMSSEC -service M24SHAMSC_RO \
  -role PHYSICAL_STANDBY -policy AUTOMATIC
```

RAC, esempio da adattare:

```bash
srvctl add service -db M24SHAMSPEC -service M24SHAMSC_PRY \
  -preferred M24SHAMSPEC1,M24SHAMSPEC2 \
  -role PRIMARY -policy AUTOMATIC

srvctl add service -db M24SHAMSSEC -service M24SHAMSC_RO \
  -preferred M24SHAMSSEC1,M24SHAMSSEC2 \
  -role PHYSICAL_STANDBY -policy AUTOMATIC
```

Definisci la configurazione equivalente nei due siti in modo che i servizi
seguano correttamente switchover e failover.

### 3. Variante CDB/PDB

Per `S2` e `S4`, collega il servizio alla PDB:

```bash
srvctl add service -db M24SHAMSPEC -service M24SHAMSC_PRY \
  -pdb M24SHAMSC_APP \
  -role PRIMARY -policy AUTOMATIC

srvctl add service -db M24SHAMSSEC -service M24SHAMSC_RO \
  -pdb M24SHAMSC_APP \
  -role PHYSICAL_STANDBY -policy AUTOMATIC
```

Per RAC aggiungi anche le istanze preferred approvate. Non usare il servizio
di default della CDB per l'applicazione.

Verifica:

```sql
SELECT con_id, name, open_mode
FROM v$pdbs
ORDER BY con_id;

SELECT con_id, name, network_name
FROM cdb_services
ORDER BY con_id, name;
```

### 4. Smoke test e role transition

Prima dello switchover:

```bash
srvctl config service -db M24SHAMSPEC
srvctl config service -db M24SHAMSSEC
srvctl status service -db M24SHAMSPEC
srvctl status service -db M24SHAMSSEC
```

Dopo switchover e switchback verifica:

1. `_PRY` disponibile solo sul nuovo primary;
2. `_RO` disponibile solo sul nuovo standby ADG;
3. scrittura consentita tramite `_PRY`;
4. scrittura rifiutata tramite `_RO`;
5. PDB aperta nel modo atteso per `S2` e `S4`;
6. MRP0 attivo sullo standby.

## Validazione finale

| Check | Atteso |
| --- | --- |
| Gate licenza | evidenza o marcatura lab personale |
| Standby | `READ ONLY WITH APPLY` |
| `_PRY` | solo ruolo `PRIMARY` |
| `_RO` | solo ruolo `PHYSICAL_STANDBY` |
| Apply | `MRP0` attivo |
| Gap | nessuna riga da `V$ARCHIVE_GAP` sullo standby |
| Switchover | servizi seguono i ruoli |
| Switchback | servizi ritornano ai ruoli iniziali |

## Troubleshooting rapido

| Sintomo | Prima azione |
| --- | --- |
| `OPEN READ ONLY` fallisce | cancella apply, controlla alert log e ruolo |
| `_RO` non parte | verifica gate licenza, open mode, ruolo e PDB |
| `_PRY` resta sul vecchio primary | controlla definizione role-based nei due siti |
| PDB chiusa dopo role transition | verifica saved state e startup policy |
| Apply lag cresce | controlla I/O, FRA, SRL e carico reporting |
| Query modifica dati sullo standby | interrompi test: `_RO` deve restare read-only |
