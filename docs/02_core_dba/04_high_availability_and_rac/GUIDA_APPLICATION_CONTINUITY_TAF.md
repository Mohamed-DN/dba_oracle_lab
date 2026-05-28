# GUIDA MONUMENTALE: Application Continuity (AC) & TAF — Failover Client Trasparente & Resilienza Applicativa


## [ARCHITETTURA VISIVA] Application Continuity
```text

                               +---------------+
                               |  Applicazione |
                               |  (JDBC/UCP)   |
                               +-------+-------+
                                       |
                                       v
                               +---------------+
                               | SCAN Listener |
                               +---+-------+---+
                                   |       |
      (Connessione Iniziale) ----> |       | <---- (Replay Automatico)
                                   v       v
                       +-------------+   +-------------+
                       | Istanza N.1 |   | Istanza N.2 |
                       |   (Crash)   |   |   (Attiva)  |
                       +-------------+   +-------------+
```

> [!NOTE]
> **DOCUMENTI DI ALTA AFFIDABILITÀ CORRELATI (SCEGLI QUELLO PIÙ ADATTO):**
> - **Application Continuity & Failover (questa guida)**: [GUIDA_APPLICATION_CONTINUITY_TAF.md](./GUIDA_APPLICATION_CONTINUITY_TAF.md) (transparent application failover, JDBC, UCP, Transaction Guard).
> - **Data Guard Far Sync**: [GUIDA_FAR_SYNC_DATAGUARD.md](./GUIDA_FAR_SYNC_DATAGUARD.md) (architettura, setup, SYNC a corto raggio, ASYNC a lungo raggio, Broker & Redo Routes).
> - **Single Node Data Guard**: [GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_SINGLE_NODE_DATAGUARD_NON_CDB.md) (architettura a singolo nodo primario e standby).
> - **RAC Data Guard**: [GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md](./GUIDA_PRODUZIONE_RAC_DATAGUARD_NON_CDB.md) (architettura multi-nodo primario e standby).

---

## 1. Il problema del Failover Client e l'evoluzione tecnologica

Nelle architetture ad alta affidabilità (Real Application Clusters - RAC e Data Guard), lo switchover pianificato o il failover sposta i servizi del database sulle istanze integre in pochi secondi. Tuttavia, senza un'adeguata configurazione lato client, le connessioni applicative attive subiscono interruzioni drastiche (errori del tipo `ORA-03113: end-of-file on communication channel` o `ORA-12541: TNS:no listener`), causando lo svuotamento dei carrelli degli utenti, transazioni incomplete a metà e crash di processi batch critici con conseguenti disallineamenti di dati.

Per risolvere questo problema, Oracle ha sviluppato tre generazioni di tecnologie di failover client:

```
  TAF (Transparent Application Failover) --&gt; TRANSACTION GUARD --&gt; APPLICATION CONTINUITY
  - Sviluppata negli anni '90 (OCI/SQL*Plus)  - Introdotta in 12c      - Stato dell'arte (19c/21c/23ai)
  - Ripristina solo le SELECT                 - Risolve l'incertezza   - Buffering intelligente in memoria
  - Le DML attive falliscono                  - Ritorna con certezza   - Ricollega la sessione e
  - Rischio di doppia esecuzione                se il COMMIT è           REPLAYA le DML non committate
    involontaria di una DML                     avvenuto o meno          in modo invisibile.
```

---

## 2. Architettura & Funzionamento di Application Continuity (AC)

**Application Continuity (AC)** scherma le applicazioni dagli incidenti infrastrutturali mascherando le interruzioni in background. Si basa su due pilastri fondamentali:

### Pilastro 1: Il Replay Intelligente
Mentre l'applicazione esegue operazioni SQL all'interno di una transazione, il driver JDBC memorizza temporaneamente le chiamate all'interno di un buffer in memoria protetto. Se si verifica un crash:
1.  Il driver intercetta l'errore di rete e blocca la propagazione dell'eccezione verso l'applicazione.
2.  Usa le notifiche **Fast Application Notification (FAN)** per individuare istantaneamente una nuova istanza attiva del database.
3.  Stabilisce una nuova connessione in background, ripristina lo stato della sessione (variabili, schemi) e **riesegue (replays) le DML** non ancora committate memorizzate nel buffer.

### Pilastro 2: Transaction Guard
Durante la riesecuzione di una transazione interrotta a metà, esiste il rischio critico che il database avesse già completato il `COMMIT` prima del crash ma non fosse riuscito a inviare la risposta al client. Rieseguire ciecamente la transazione provocherebbe una **doppia transazione** (es. doppio addebito su conto).

**Transaction Guard** elimina questa incertezza fornendo un identificativo logico di transazione unico globale (**Logical Transaction ID - LTXID**). In fase di replay, il driver interroga Transaction Guard tramite la procedura interna `DBMS_APP_CONT.GET_LTXID_OUTCOME` per verificare lo stato atomico del commit.
*   Se la transazione era già committata: il database restituisce il successo all'applicazione senza rieseguirla.
*   Se la transazione non era committata: il database autorizza il replay delle DML in totale sicurezza.

---

## 3. Configurazione Database (Setup del Servizio RAC)

L'Application Continuity viene abilitata configurando proprietà specifiche all'interno del **Servizio Database** registrato in Grid Infrastructure tramite `srvctl`.

```bash
# Esegui come utente oracle sul nodo primario

# 1. Creazione del servizio applicativo ad alta affidabilità
srvctl add service -d RACDB -s CRM_APP_AC \
  -preferred RACDB1,RACDB2 \
  -failovertype TRANSACTION \    # Forza il replay transazionale (AC)
  -failovermethod BASIC \
  -commit_outcome TRUE \          # Abilita Transaction Guard per tracciare il commit outcome
  -replay_init_time 1800 \        # Tempo massimo tollerabile per il replay (in secondi)
  -retention 86400 \              # Mantiene l'esito di Transaction Guard per 24 ore
  -notification TRUE \            # Abilita le notifiche FAN per connection pools
  -clbgoal LONG \
  -rlbgoal SERVICE_TIME

# 2. Avvia il servizio
srvctl start service -d RACDB -s CRM_APP_AC
```

---

## 4. Configurazione Client (TNSnames & Connessione JDBC)

La stringa di connessione deve essere ottimizzata per evitare timeout TCP standard del sistema operativo (che possono richiedere fino a 15 minuti) e passare istantaneamente all'IP SCAN successivo in caso di nodo spento.

### Stringa TNSnames.ora Standard Enterprise per Application Continuity:
```ini
CRM_APP_AC_TNS =
  (DESCRIPTION =
    (CONNECT_TIMEOUT = 120) (RETRY_COUNT = 30) (RETRY_DELAY = 3)
    (TRANSPORT_CONNECT_TIMEOUT = 3)
    (ADDRESS_LIST =
      (LOAD_BALANCE = ON)
      (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan.localdomain)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = CRM_APP_AC)
    )
  )
```

---

## 5. Setup del Connection Pool (Esempio Completo Java UCP)

Per consentire il buffering delle transazioni in memoria, l'applicazione deve sfruttare i driver JDBC ufficiali di Oracle (versione 19c+) e abilitare il Fast Connection Failover (FCF) all'interno del pool di connessioni **Oracle Universal Connection Pool (UCP)**.

```java
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Properties;
import oracle.ucp.jdbc.PoolDataSourceFactory;
import oracle.ucp.jdbc.PoolDataSource;

public class HighAvailabilityApp {
  public static void main(String[] args) throws Exception {
    // 1. Inizializzazione del PoolDataSource abilitato per UCP
    PoolDataSource pds = PoolDataSourceFactory.getPoolDataSource();
    
    // 2. Configura la classe di connessione Oracle nativa
    pds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource");
    pds.setURL("jdbc:oracle:thin:@CRM_APP_AC_TNS");
    pds.setUser("hr");
    pds.setPassword("SecurePassword123#");
    
    // 3. ABILITA IL FAST CONNECTION FAILOVER (FCF) per integrare le notifiche FAN
    pds.setFastConnectionFailoverEnabled(true);
    
    // 4. Configurazione parametri JDBC specifici per l'ottimizzazione del Replay
    Properties prop = new Properties();
    prop.put("oracle.jdbc.autoCommitSpecCompliant", "true");
    prop.put("oracle.jdbc.replayAllowed", "true"); // Consente esplicitamente il buffering delle DML
    pds.setConnectionProperties(prop);
    
    // 5. Dimensionamento ed impostazioni del Pool
    pds.setInitialPoolSize(5);
    pds.setMinPoolSize(5);
    pds.setMaxPoolSize(25);
    pds.setConnectionHarvestTriggerCount(2);
    
    System.out.println("UCP Connection Pool inizializzato con successo con supporto Application Continuity!");
    
    // Esecuzione di prova di una query protetta da Replay
    Connection conn = null;
    PreparedStatement pstmt = null;
    try {
      conn = pds.getConnection();
      pstmt = conn.prepareStatement("UPDATE hr.employees SET salary = salary * 1.02 WHERE department_id = 50");
      pstmt.executeUpdate();
      
      // La transazione è in memoria nel buffer di UCP. In caso di crash di rac1 ora,
      // la connessione si ripristinerà su rac2 ed esegui il replay prima del commit!
      conn.commit();
      System.out.println("Transazione completata con successo.");
    } catch (Exception e) {
      System.err.println("Errore di esecuzione: " + e.getMessage());
    } finally {
      if (pstmt != null) pstmt.close();
      if (conn != null) conn.close();
    }
  }
}
```

---

## 6. Validazione, Log e Troubleshooting

### 6.1 Verificare l'attività di Replay nei Log del Driver JDBC
Per diagnosticare se Application Continuity sta effettivamente intercettando i crash ed eseguendo il replay delle transazioni, è possibile abilitare il logging di dettaglio del driver JDBC configurando il logger java:

```properties
# Aggiungi alle opzioni di avvio della JVM dell'applicazione
-Doracle.jdbc.Trace=true
-Djava.util.logging.config.file=logging.properties
```
*Nel file di log risultante, cercare stringhe come `Replay: startReplay` e `Replay: Replay succeeded` per confermare che il failover è stato mascherato correttamente.*

### 6.2 Monitorare Transaction Guard lato Database
Puoi ispezionare le statistiche relative alle chiamate di verifica dei LTXID per valutare l'efficienza dei controlli dei commit:

```sql
SELECT inst_id,
       service_name,
       commit_outcome_calls,
       commit_outcome_success
FROM   gv$service_stats
WHERE  service_name = 'CRM_APP_AC';
```
