# Runbook Enterprise: Gestione Avanzata dei Database Link (DB_LINK)

I Database Link (DB_LINK) sono il ponte nervoso che permette a database distinti di comunicare. Tuttavia, se gestiti erroneamente (in particolar modo durante refresh di ambienti, cloni, o migrazioni), diventano la **falla di sicurezza piÃ¹ pericolosa** di un'infrastruttura. Un DB Link copiato da un DB di Produzione verso uno di Test manterrÃ  i riferimenti di connessione al database target di Produzione. Un'operazione di `DELETE` o `UPDATE` lanciata in test si propagherÃ  silente al database di Produzione, causando una severa corruzione logica.

Questo runbook approfondisce la messa in sicurezza post-refresh, le tecniche crittografiche, il troubleshooting di rete avanzato e la risoluzione di deadlocks distribuiti.

---

## 1. Architettura e Tipologia dei DB Link
Per gestire correttamente i link, devi sapere quale tipo stai manipolando. L'architettura prevede:

1. **Private DB Link**: Creato e visibile solo a uno specifico owner (es. `SCHEMA_A`). L'amministratore SYS non puÃ² visualizzarne la password o testarlo con una query `SELECT ... FROM dual@link`, a meno che non si impersoni l'utente.
2. **Public DB Link**: Creato e visibile da tutti gli utenti nel database. Altissimo rischio di sicurezza se l'account remoto ha privilegi eccessivi.
3. **Global DB Link**: Integrati con directory di rete (es. OID). Poco usati in architetture cloud-native moderne.
4. **Current User DB Link**: Link speciale (`CONNECT TO CURRENT_USER`) che utilizza le credenziali dell'utente che invoca la sessione, senza memorizzare password (richiede Enterprise User Security, Kerberos, o architetture trust).

```sql
-- Identificazione globale di tutti i DB Link e loro classificazione
SELECT owner, db_link, username, host, created
FROM dba_db_links
ORDER BY owner, db_link;
```

---

## 2. Fase Critica Post-Clone: Drop Immediato
Subito dopo l'esecuzione di un *RMAN Duplicate* da Prod a Preprod, o dopo l'import massivo via *Data Pump*, il primo script assoluto da eseguire **prima che gli applicativi si connettano** Ã¨ la sanificazione.

### 2.1 Generazione script Drop di Sicurezza
PoichÃ© non si possono droppare agevolmente i link privati, forniamo un PL/SQL di sistema che forza il clean-up:

```sql
SET SERVEROUTPUT ON
DECLARE
    v_sql VARCHAR2(1000);
BEGIN
    FOR r IN (SELECT owner, db_link FROM dba_db_links) LOOP
        BEGIN
            IF r.owner = 'PUBLIC' THEN
                v_sql := 'DROP PUBLIC DATABASE LINK "' || r.db_link || '"';
                EXECUTE IMMEDIATE v_sql;
                DBMS_OUTPUT.PUT_LINE('SUCCESSO: Dropped PUBLIC link ' || r.db_link);
            ELSE
                -- Uso di un trucco PL/SQL: si imposta la sessione come owner e poi si esegue il drop.
                -- ATTENZIONE: Questo workaround necessita privilegi SYS. Altrimenti si genera il grant/drop DDL.
                DBMS_OUTPUT.PUT_LINE('ATTENZIONE: Droppare il link privato di ' || r.owner || ':');
                DBMS_OUTPUT.PUT_LINE('EXEC dbms_sys_sql.parse_as_user(uid=>..., sql=>''DROP DATABASE LINK "' || r.db_link || '"'');');

                -- Metodo alternativo tramite EXECUTE IMMEDIATE e impersonificazione (richiede 18c+)
                -- v_sql := 'DROP DATABASE LINK "' || r.db_link || '"';
                -- dbms_output.put_line(v_sql);
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('ERRORE drop su ' || r.owner || '.' || r.db_link || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/
```
**Regola D'oro:** Un DB Link droppato Ã¨ un DB Link sicuro. Salva preventivamente i metadati o rigenerali dai repository aziendali sicuri (Vault).

---

## 3. Sicurezza delle Credenziali nei DB Link

### 3.1 Il problema di SYS.LINK$
Le password dei DB Link in Oracle (fino a 11gR2) potevano essere in parte decriptate o ottenute tramite l'export della tabella base `SYS.LINK$`. A partire dalla 12c, le password sono hasheate e offuscate usando SHA-512 e salting, legate al DBID, rendendo impossibile trasportarle "a crudo" tra database con un RMAN diverso (salvo mantenere lo stesso DBID).

Se un DBA ha necessitÃ  di aggiornare le password per un cambio schedulato, deve ricostruire il DB Link:
```sql
ALTER DATABASE LINK my_link CONNECT TO usr IDENTIFIED BY "<PASSWORD_DA_VAULT>";
```

### 3.2 Network Encryption per DB Link
Tutto il traffico tra un database locale e uno remoto attraverso un DB_LINK viaggia in chiaro sulla rete se non si abilita la **Native Network Encryption**.
Nel file `sqlnet.ora` di *entrambi* i server database impostare:
```ini
SQLNET.ENCRYPTION_SERVER = REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER = (AES256)
SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)
```
Questo garantisce che i pacchetti `SELECT` distribuiti, cosÃ¬ come lo scambio di credenziali durante l'apertura della sessione remota via DB Link, siano cifrati AES-256 e non intercettabili.

---

## 4. Troubleshooting Avanzato della Rete (ORA-12154, ORA-12514)

L'errore piÃ¹ comune creando un DB Link in test verso un altro sistema di test:
`ORA-12154: TNS:could not resolve the connect identifier specified`

1. **Il DB_LINK usa un nome TNS?**
   ```sql
   CREATE DATABASE LINK dblink_test CONNECT TO usr IDENTIFIED BY "<PASSWORD_DA_VAULT>" USING 'TNS_ALIAS';
   ```
   *Problema:* RMAN, Data Pump o i background processes di Oracle spesso non conoscono il `$TNS_ADMIN` in base a come sono avviati.
   *Soluzione Enterprise:* Usa l'Easy Connect (`host:port/service`) o l'EZCONNECT TNS string directly nel comando `USING`. Questo bypassa totalmente il file `tnsnames.ora`.
   ```sql
   CREATE DATABASE LINK dblink_test
   CONNECT TO usr IDENTIFIED BY "<PASSWORD_DA_VAULT>"
   USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=10.1.5.22)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=SRV_TEST)))';
   ```

2. **Timeout Latenti e Firewall:**
   Se una query distribuita impiega minuti e poi cade (`ORA-03113: end-of-file on communication channel`), il firewall (Cisco, Fortinet) potrebbe troncare le connessioni silenti (idle connection drop).
   Impostare `SQLNET.EXPIRE_TIME = 10` nel `sqlnet.ora` invia pacchetti "keep-alive" (DCD - Dead Connection Detection) ogni 10 minuti, impedendo al firewall di segare le code.

3. **GLOBAL_NAMES = TRUE**
   Se si riceve `ORA-02085: database link DB_LNK.DOMAIN connects to PROD.DOMAIN`:
   Il parametro di sistema `global_names` Ã¨ impostato a TRUE, imponendo che il nome del DB link corrisponda ESATTAMENTE al *global_name* del database remoto (`SELECT * FROM global_name;` nel target).
   *Fix:* Rinominare il dblink oppure (solitamente preferibile in Test) disabilitare la restrizione:
   ```sql
   ALTER SYSTEM SET global_names=FALSE SCOPE=BOTH;
   ```

---

## 5. Gestione Transazioni Distribuite e In-Doubt (2PC)

Le query distribuite di modifica (`UPDATE table@dblink`) usano il **Two-Phase Commit (2PC)**. Se durante il commit il link di rete va giÃ¹, la transazione rimane "in-doubt", mantenendo lock di riga (o peggio, di tabella) in entrambi i database all'infinito!

### 5.1 Identificazione di Lock Distribuiti
Sul database in cui l'applicativo ha generato l'operazione (Local):
```sql
SELECT local_tran_id, global_tran_id, state, mixed, host, commit#
FROM dba_2pc_pending;
```

### 5.2 Risoluzione Forzata di un 2PC In-Doubt
Se il record in `dba_2pc_pending` si trova in stato `PREPARED`, questo causa lock sui dati e blocca persino i job Data Pump. Bisogna forzare il commit (se si vuole applicare) o il rollback.

**Passaggio 1: Rollback forzato (Manuale)**
```sql
ROLLBACK FORCE 'global_tran_id';
-- Esempio: ROLLBACK FORCE '1.14.521';
```

**Passaggio 2: Pulizia del Dizionario**
Se Oracle non riesce a ripulire la view (spesso accade se il remote DB Ã¨ irraggiungibile definitivamente):
```sql
EXECUTE DBMS_TRANSACTION.PURGE_LOST_DB_ENTRY('global_tran_id');
```
Se ricevi l'errore `ORA-06512` e la purge non funziona, non procedere subito con DML diretto sulle tabelle `SYS`. In ambienti critici aprire SR/MOS o usare procedura aziendale break-glass. Il seguente approccio e' solo ultima istanza, dopo backup e autorizzazione formale:
```sql
ALTER SESSION SET "_smu_debug_mode" = 4;
DELETE FROM sys.pending_trans$ WHERE local_tran_id = 'global_tran_id';
DELETE FROM sys.pending_sessions$ WHERE local_tran_id = 'global_tran_id';
DELETE FROM sys.pending_sub_sessions$ WHERE local_tran_id = 'global_tran_id';
COMMIT;
```

---

## 6. Tuning delle Performance su DB Link
Le query eseguite via database link sono famose per avere performance tremende. Questo perchÃ© l'Optimizer ha difficoltÃ  a comprendere indici e cardinalitÃ  remote.

### 6.1 DRIVING_SITE Hint
Costringe Oracle a spostare il pezzo di join leggero sul server remoto, processando lÃ¬ la logica e riportando solo i risultati finali.
```sql
SELECT /*+ DRIVING_SITE(r) */ l.customer_id, r.order_tot
FROM local_customers l
JOIN remote_orders@dblink r ON l.customer_id = r.customer_id
WHERE l.status = 'ACTIVE';
```

### 6.2 Evitare CLOB/BLOB su DB Link
Oracle per ragioni di LOB-locator su protocollo SQLNet non riesce ad accedere direttamente a un CLOB via database link (`ORA-22992`).
**Workaround:** Utilizzare `GLOBAL TEMPORARY TABLE` per importare via array (DBMS_SQL / CTAS limitata) i dati fisicamente in locale e poi trattare il CLOB.

### 6.3 Ottimizzazione Fetch Size
I dati trasmessi via rete generano pacchetti. Maggiore Ã¨ il SDU (Session Data Unit) e il Fetch Array Size, minori saranno i round-trip (RTT) di rete.
A livello applicativo (JDBC/ODBC) e di strumento (SQL*Plus `SET ARRAYSIZE 5000`), aumentare la fetch per saturare la banda senza picchi continui.

---

## 7. Hardening Enterprise dei DB Link

### 7.1 Regole di sicurezza

```text
[ ] Vietare DB link public salvo eccezione approvata.
[ ] Vietare link da PREPROD/TEST verso PROD.
[ ] Usare account remoti dedicati e read-only dove possibile.
[ ] Non usare utenti applicativi owner come utenti remoti del link.
[ ] Documentare owner, target, service, porta, schema remoto e finalita.
[ ] Abilitare Native Network Encryption o TLS secondo standard aziendale.
[ ] Revisionare DB link dopo ogni clone/import/RMAN duplicate.
```

### 7.2 Inventory completo

```sql
SELECT owner, db_link, username, host, created
FROM   dba_db_links
ORDER  BY owner, db_link;

SELECT *
FROM   dba_db_link_sources
ORDER  BY owner, db_link;
```

### 7.3 Test sicuro del link

```sql
SELECT 1 FROM dual@NOME_LINK;

SELECT sys_context('USERENV','DB_NAME') remote_db,
       sys_context('USERENV','SERVICE_NAME') remote_service,
       sys_context('USERENV','SESSION_USER') remote_user
FROM dual@NOME_LINK;
```

### 7.4 Pattern per ricreare link in PREPROD

```sql
CREATE DATABASE LINK app_to_dwh_preprod
  CONNECT TO app_ro IDENTIFIED BY "<PASSWORD_DA_VAULT>"
  USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=dwh-preprod.localdomain)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=DWH_PREPROD)))';
```

### 7.5 Privilegi per transazioni in-doubt

Per `COMMIT FORCE` o `ROLLBACK FORCE` serve privilegio operativo adeguato (`FORCE TRANSACTION` o privilegi DBA controllati). Non delegare questi comandi a utenti applicativi.

```sql
GRANT FORCE TRANSACTION TO dba_operator;
```

---

## 8. Manuali e riferimenti

Oracle:

- Managing a Distributed Database 19c: https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/managing-a-distributed-database.html
- Managing Distributed Transactions: https://docs.oracle.com/en/database/oracle/oracle-database/18/admin/managing-distributed-transactions.html
- SQL Language Reference - CREATE DATABASE LINK: https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/CREATE-DATABASE-LINK.html
- SQL Language Reference - COMMIT: https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/COMMIT.html
- SQL Language Reference - ROLLBACK: https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/ROLLBACK.html
- Oracle Net sqlnet.ora parameters: https://docs.oracle.com/en/database/oracle/oracle-database/19/netrf/parameters-for-the-sqlnet.ora.html

Comandi/man utili:

```bash
tnsping <alias>
oerr ora 12154
oerr ora 12514
oerr ora 2085
man sqlplus
man openssl
```

Checklist post-refresh:

```text
[ ] Nessun DB link da PREPROD verso PROD.
[ ] Nessun PUBLIC DB LINK non autorizzato.
[ ] Tutti i link testati con SELECT 1 FROM dual@link.
[ ] Native Network Encryption/TLS verificata.
[ ] DBA_2PC_PENDING vuota o giustificata.
[ ] Job/scheduler che usano link disabilitati o reindirizzati.
```
