# Guida Servizi Applicativi RAC — TAF, FAN, Load Balancing

> In RAC, usare il "default service" è un errore grave. I servizi applicativi sono il meccanismo Oracle per gestire dove vanno le connessioni, cosa succede durante un failover, e come bilanciare il carico.

---

## 1. Perché NON Usare il Default Service

```
DEFAULT SERVICE (il nome del database, es. "RACDB"):
  - Le connessioni vanno su un nodo qualsiasi (random)
  - Durante un failover, le connessioni NON vengono riconnesse
  - Nessun bilanciamento intelligente del carico
  - Nessuna distinzione tra OLTP e BATCH
  - NON supporta Application Continuity

SERVIZI APPLICATIVI:
  - Definiti con srvctl (sotto controllo del Clusterware)
  - Failover automatico verso l'altro nodo
  - Load balancing basato sul carico reale
  - Separazione OLTP vs BATCH
  - Supporto TAF, FCF, Application Continuity
```

---

## 2. Creazione Servizi con srvctl

### 2.1 Servizio OLTP (Transazionale)

```bash
# Crea un servizio per le applicazioni transazionali
srvctl add service -d RACDB -s OLTP_SRV \
  -preferred "RACDB1,RACDB2" \
  -failovertype TRANSACTION \
  -failovermethod BASIC \
  -commit_outcome TRUE \
  -replay_init_time 600 \
  -clbgoal SHORT \
  -rlbgoal SERVICE_TIME
# ^^^ Spiegazione di OGNI parametro:
#
# -d RACDB: il database RAC
# -s OLTP_SRV: nome del servizio (usato nel connection string)
# -preferred "RACDB1,RACDB2": il servizio gira su ENTRAMBE le istanze
#   (se un nodo cade, il servizio continua sull'altro)
# -failovertype TRANSACTION: failover a livello di transazione
#   (la transazione in corso viene rollbackata e rieseguita)
# -failovermethod BASIC: metodo standard (TAF)
# -commit_outcome TRUE: salva l'esito del COMMIT (per Application Continuity)
# -replay_init_time 600: tempo massimo (secondi) per il replay
# -clbgoal SHORT: Connection Load Balancing goal = connessioni brevi (OLTP)
# -rlbgoal SERVICE_TIME: Runtime Load Balancing = manda connessioni
#   al nodo con il tempo di servizio più basso

# Avvia il servizio
srvctl start service -d RACDB -s OLTP_SRV

# Verifica
srvctl status service -d RACDB -s OLTP_SRV
```

### 2.2 Servizio BATCH (Reportistica Pesante)

```bash
srvctl add service -d RACDB -s BATCH_SRV \
  -preferred "RACDB2" \
  -available "RACDB1" \
  -clbgoal LONG \
  -rlbgoal THROUGHPUT
# ^^^ Differenze chiave dal servizio OLTP:
# -preferred "RACDB2": i job batch girano SOLO su rac2 (non disturbano OLTP su rac1)
# -available "RACDB1": se rac2 cade, i batch possono migrare su rac1
# -clbgoal LONG: connessioni lunghe (sessioni batch che durano ore)
# -rlbgoal THROUGHPUT: ottimizza per throughput, non per latenza

srvctl start service -d RACDB -s BATCH_SRV
```

---

## 3. Connection String Corrette

### 3.1 JDBC (Java)

```
# OLTP — usa il servizio OLTP_SRV via SCAN
jdbc:oracle:thin:@//rac-scan.localdomain:1521/OLTP_SRV

# BATCH — usa il servizio BATCH_SRV via SCAN
jdbc:oracle:thin:@//rac-scan.localdomain:1521/BATCH_SRV
```

### 3.2 tnsnames.ora

```
OLTP_SRV =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = OLTP_SRV)
      (FAILOVER_MODE =
        (TYPE = SELECT)
        (METHOD = BASIC)
        (RETRIES = 30)
        (DELAY = 5)
      )
    )
  )
```

---

## 4. TAF — Transparent Application Failover

```
TAF permette al client di riconnettersi automaticamente dopo un failover.

SENZA TAF:
  Client connesso a rac1 → rac1 crasha → ORA-03113: end-of-file
  L'applicazione deve riconnettersi manualmente e rieseguire la query.

CON TAF (TYPE=SELECT):
  Client connesso a rac1, sta eseguendo una SELECT → rac1 crasha
  → TAF riconnette automaticamente il client a rac2
  → La SELECT riparte dalla riga dove era rimasta!
  → L'applicazione non vede l'interruzione.
```

### Verifica TAF

```sql
-- Verifica che TAF sia attivo per la sessione
SELECT username, service_name, failover_type, failover_method
FROM v$session
WHERE username IS NOT NULL;
-- Deve mostrare: FAILOVER_TYPE=SELECT, FAILOVER_METHOD=BASIC
```

---

## 5. FAN — Fast Application Notification

```
FAN è un sistema di "eventi push" che avvisa istantaneamente
i client quando un nodo crasha, SENZA aspettare il timeout TCP.

SENZA FAN:
  Client connesso a rac1 → rac1 crasha
  → Il client aspetta il TCP timeout (30-300 secondi!)
  → Solo dopo il timeout riceve l'errore

CON FAN:
  Client connesso a rac1 → rac1 crasha
  → CRS invia un evento FAN a TUTTI i listener e client registrati
  → Il client riceve l'evento in 1-3 secondi
  → Failover immediato!
```

```sql
-- Verifica che FAN sia abilitato per il servizio
srvctl config service -d RACDB -s OLTP_SRV
-- AQ HA notifications: TRUE
```

---

## 6. CLB e RLB — Load Balancing

```
CLB (Connection Load Balancing):
  Dove va una NUOVA connessione?
  - SHORT: al nodo con meno connessioni attive (OLTP, connessioni brevi)
  - LONG: round-robin (BATCH, connessioni persistenti)

RLB (Runtime Load Balancing):
  Dove va il PROSSIMO LAVORO per una connessione già aperta?
  - SERVICE_TIME: al nodo con il tempo di risposta più basso (OLTP)
  - THROUGHPUT: al nodo con le risorse più libere (BATCH)
  - Richiede Connection Pool (JDBC, OCI, ecc.)
```

---

## 7. Riepilogo Servizi per il Lab

| Servizio | Preferred | Available | CLB | RLB | Uso |
|----------|-----------|-----------|-----|-----|-----|
| `OLTP_SRV` | RACDB1, RACDB2 | — | SHORT | SERVICE_TIME | App transazionali |
| `BATCH_SRV` | RACDB2 | RACDB1 | LONG | THROUGHPUT | Report, ETL, batch |
| `GG_SRV` | RACDB1 | — | — | — | GoldenGate Extract |
| `RMAN_SRV` | RACDB_STBY1 | — | — | — | Backup RMAN |

---

## 8. Fonti Oracle Ufficiali

- Application Services in RAC: https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/ensuring-application-continuity.html
- TAF: https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/configuring-transparent-application-failover.html
- FAN: https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/fast-application-notification.html
