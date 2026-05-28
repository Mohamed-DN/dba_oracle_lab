# GUIDA: Application Continuity (AC) & TAF — Failover Client Trasparente e Resilienza Applicativa

> [!NOTE]
> **DOCUMENTI DI ALTA AFFIDABILITÀ CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Application Continuity & Failover (questa guida)**: [GUIDA_APPLICATION_CONTINUITY_TAF.md](./GUIDA_APPLICATION_CONTINUITY_TAF.md) (transparent application failover, JDBC, UCP).
> - **Data Guard Far Sync**: [GUIDA_FAR_SYNC_DATAGUARD.md](./GUIDA_FAR_SYNC_DATAGUARD.md) (architettura, setup, SYNC a corto raggio, ASYNC a lungo raggio).
> - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
> - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).

---

## 1. Il problema del Failover Client e l'evoluzione Oracle

Quando avviene un evento di failover o uno switchover pianificato in RAC o Data Guard, il database sposta rapidamente i servizi sulle istanze attive o sul sito secondario. Tuttavia, cosa succede alle applicazioni connesse?

*   **Senza configurazioni (Comportamento di base)**: Tutte le sessioni client attive ricevono immediatamente errori irreversibili (`ORA-03113: end-of-file on communication channel` o `ORA-12541: TNS:no listener`). I carrelli degli acquisti degli utenti si svuotano, i pagamenti falliscono a metà e i batch applicativi crashano richiedendo un recupero manuale.

Oracle ha evoluto le tecnologie di failover client nel tempo per risolvere questo problema:

```
  TAF (Transparent Application Failover) ──► TRANSACTION GUARD ──► APPLICATION CONTINUITY
  - Legacy (Anni '90)                       - Introdotto in 12c    - Stato dell'arte (19c/23ai)
  - Ripristina solo SELECT                  - Garantisce il        - Riconnette e REPLAYA
  - Le INSERT/UPDATE falliscono             - "Commit Outcome"     - Le DML attive vengono
  - Rischio di doppia esecuzione            - Zero transazioni       ri-eseguite in modo
    di una transazione (DML fallite)          orfane o doppie        invisibile all'applicazione
```

---

## 2. Cos'è Application Continuity (AC)?

**Application Continuity (AC)** è una tecnologia disponibile a partire da Oracle 12c e consolidata in **19c** che scherma le applicazioni dagli incidenti infrastrutturali (crash di nodi, switchover, problemi di rete).

Quando avviene un'interruzione:
1.  AC cattura l'errore di rete, blocca l'eccezione verso l'applicazione e **riconnette automaticamente** la sessione a un'istanza superstite del cluster (o sul sito DR).
2.  AC interroga **Transaction Guard** per conoscere l'esito dell'ultima transazione:
    *   Se l'ultimo `COMMIT` era già andato a buon fine prima del crash, restituisce il successo all'applicazione.
    *   Se il `COMMIT` non era ancora avvenuto, **Application Continuity riesegue (replays) in background l'intera transazione** (tutte le INSERT/UPDATE/DELETE precedenti non committate) in modo trasparente.
3.  L'applicazione riprende l'esecuzione come se nulla fosse accaduto, riscontrando solo un leggerissimo ritardo temporaneo (~1-2 secondi) dovuto alla riconnessione.

---

## 3. Requisiti Architetturali

Per abilitare Application Continuity è necessario disporre di tre componenti allineati:

1.  **Database**: Oracle Database Enterprise Edition 19c+.
2.  **Driver Client**: JDBC Thin Driver versione 19c (o superiore), che supporti il buffering delle chiamate SQL in memoria.
3.  **Connection Pool**: **Oracle Universal Connection Pool (UCP)**, WebLogic Active GridLink, o driver OCI/ODBC compatibili.

---

## 4. Configurazione Database (Setup del Servizio RAC)

Application Continuity viene controllato e attivato a livello di **Servizio del Database** registrato in Grid Infrastructure tramite `srvctl`. Non si applica alle connessioni dirette tramite `SYS` o SID.

### Creazione di un Servizio ad Alta Affidabilità per l'applicazione
Creiamo il servizio `APP_AC` sul database RAC `RACDB`:

```bash
# Esegui come utente oracle sul Nodo 1
srvctl add service -d RACDB -s APP_AC \
  -preferred RACDB1,RACDB2 \
  -failovertype TRANSACTION \
  -failovermethod BASIC \
  -commit_outcome TRUE \
  -replay_init_time 1800 \
  -retention 86400 \
  -notification TRUE \
  -clbgoal LONG \
  -rlbgoal SERVICE_TIME
```

### Spiegazione dettagliata delle opzioni operative:
*   `-failovertype TRANSACTION`: **Abilita Application Continuity**. Dice al driver di memorizzare le transazioni in un buffer locale per poterne fare il replay in caso di crash.
*   `-commit_outcome TRUE`: **Abilita Transaction Guard**. Consente di tracciare in modo atomico lo stato di ogni commit.
*   `-replay_init_time 1800`: Tempo massimo (in secondi) dall'inizio dell'interruzione entro cui è consentito rieseguire il replay (impedisce che transazioni vecchie vengano rieseguite ore dopo).
*   `-notification TRUE`: Abilita le notifiche Fast Application Notification (FAN) per avvisare istantaneamente il connection pool di eliminare le connessioni morte.

### Avvia il Servizio
```bash
srvctl start service -d RACDB -s APP_AC
srvctl status service -d RACDB -s APP_AC
```

---

## 5. Configurazione Client (TNSnames & Connection String)

Il client deve disporre di una stringa di connessione che supporti la tolleranza d'errore del listener e la ricezione immediata degli eventi di failover.

### Stringa TNSnames.ora Consigliata per Application Continuity:
```ini
APP_AC_TNS =
  (DESCRIPTION =
    (CONNECT_TIMEOUT = 120) (RETRY_COUNT = 30) (RETRY_DELAY = 3)
    (TRANSPORT_CONNECT_TIMEOUT = 3)
    (ADDRESS_LIST =
      (LOAD_BALANCE = ON)
      (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = APP_AC)
    )
  )
```

### Spiegazione dei Parametri Client:
*   `CONNECT_TIMEOUT=120`: Tempo massimo totale che l'applicazione aspetta prima di fallire (consente il tempo di switchover o riavvio).
*   `RETRY_COUNT=30` e `RETRY_DELAY=3`: Tenta la riconnessione per 30 volte distanziate da 3 secondi ciascuna (copre un disservizio fino a 90 secondi).
*   `TRANSPORT_CONNECT_TIMEOUT=3`: Se un IP dello SCAN non risponde entro 3 secondi (es. perché il nodo è spento), passa istantaneamente all'IP SCAN successivo senza attendere il timeout TCP standard di 60 secondi.

---

## 6. Configurazione Connection Pool (Esempio Java UCP)

Per fare in modo che il driver esegua il buffering delle transazioni, il pool di connessioni Java deve essere configurato abilitando Fast Connection Failover (FCF):

```java
import oracle.ucp.jdbc.PoolDataSourceFactory;
import oracle.ucp.jdbc.PoolDataSource;

public class AppConnectionPool {
  public static void main(String[] args) throws Exception {
    PoolDataSource pds = PoolDataSourceFactory.getPoolDataSource();
    
    // Configura i driver e la stringa TNS
    pds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource");
    pds.setURL("jdbc:oracle:thin:@APP_AC_TNS");
    pds.setUser("hr");
    pds.setPassword("SecurePassword123#");
    
    // ABILITA FAST CONNECTION FAILOVER (Indispensabile per Application Continuity)
    pds.setFastConnectionFailoverEnabled(true);
    
    // Dimensioni del pool
    pds.setInitialPoolSize(5);
    pds.setMinPoolSize(5);
    pds.setMaxPoolSize(20);
    
    System.out.println("UCP Connection Pool inizializzato con successo con Application Continuity!");
  }
}
```

---

## 7. Test Pratico & Verifica del Replay

Per dimostrare l'efficacia di Application Continuity nel tuo laboratorio, puoi simulare un crash del nodo mentre una transazione DML è attiva.

### Test Step-by-Step:
1.  Avvia un client applicativo connesso al servizio `APP_AC` ed esegui una DML pesante senza fare commit:
    ```sql
    -- Connesso come hr via servizio APP_AC
    UPDATE hr.employees SET salary = salary * 1.05 WHERE department_id = 50;
    -- (La transazione è attiva ma NON committata)
    ```
2.  **Senza chiudere la sessione SQL**, simula il crash brutale del nodo RAC primario in esecuzione su cui risiede la sessione (es. `rac1`):
    ```bash
    # Come root su rac1, spegni brutalmente l'istanza o scollega la rete
    crsctl stop crs -f
    ```
3.  **Osserva il client**: 
    *   Noterai che il comando SQL si congela per circa 2-3 secondi (mentre FAN notifica la morte del nodo 1 e UCP ricollega la sessione sul nodo 2).
    *   La sessione **NON riceve errori** ORA-03113.
    *   Se lanci un `COMMIT` immediatamente dopo, la transazione viene salvata correttamente sul database superstite.
    *   Il log del driver JDBC confermerà: `Application Continuity: Transaction replayed successfully on instance RACDB2`.
