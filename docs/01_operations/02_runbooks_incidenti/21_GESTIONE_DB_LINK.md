# Gestione e Controllo dei DB_LINK (Post-Clone / Refresh)

Quando si effettua un Export/Import da Produzione a Pre-Produzione o un refresh tramite RMAN Duplicate, i **Database Link** (DB_LINK) preesistenti possono rappresentare un rischio.

1. **Rischio di sicurezza/integrità**: I DB link copiati in Pre-Produzione punteranno originariamente agli stessi endpoint a cui puntavano in Produzione. Questo significa che un'elaborazione in Preprod potrebbe andare a modificare dati in un database remoto di Produzione.
2. **Password Nascoste**: Non è possibile estrarre le password in chiaro dei DB Link per ricrearli in automatico tramite Data Pump in modo semplice senza configurazioni aggiuntive o workaround.

Di seguito la procedura completa per la gestione sicura dei DB_LINK.

## 1. Censimento dei DB_LINK (Prima del Refresh/Import)
Prima di sovrascrivere l'ambiente di Pre-Produzione, è **fondamentale** salvarsi l'attuale configurazione dei DB_LINK validi in Pre-Produzione.
Eseguire questo script nel DB di **Pre-Produzione** (prima del refresh) e salvare l'output:

```sql
SET LINESIZE 300
COL owner FOR a20
COL db_link FOR a30
COL username FOR a20
COL host FOR a50
SELECT owner, db_link, username, host 
FROM dba_db_links 
ORDER BY owner, db_link;
```
*(Nota: le password non verranno mostrate. È necessario disporre di un password manager o di script vaultati per le password corrette degli ambienti di test).*

## 2. Drop dei DB_LINK Importati da Produzione
Subito dopo l'import o il clone, **tutti** i DB link presenti nell'ambiente di Pre-Produzione andrebbero analizzati o idealmente droppati per evitare connessioni accidentali in Produzione.

Per generare lo script di DROP di tutti i db_link:
```sql
SELECT 'DROP DATABASE LINK ' || db_link || ';' 
FROM dba_db_links 
WHERE owner = 'PUBLIC';

SELECT 'DROP DATABASE LINK ' || db_link || ';' 
FROM dba_db_links 
WHERE owner <> 'PUBLIC';
-- Attenzione: per i DB link privati, l'utente SYS non può dropparli direttamente con DROP DATABASE LINK.
-- Va eseguito il login con l'owner del dblink, oppure utilizzare procedure PL/SQL specifiche.
```
**Per eliminare DB Link privati come SYSDBA (workaround):**
```sql
-- Workaround per eliminare DB link di un altro utente
CREATE OR REPLACE PROCEDURE drop_db_link_as_sys (p_owner IN VARCHAR2, p_dblink IN VARCHAR2) IS
BEGIN
   EXECUTE IMMEDIATE 'DROP DATABASE LINK ' || p_dblink;
END;
/
-- Poi andrà richiamata con privilegi adeguati o usando DBMS_SYS_SQL.
```
*Il metodo più sicuro è collegarsi con l'utente owner ed eseguire la DROP.*

## 3. Ricreazione dei DB_LINK in Pre-Produzione
Utilizzare l'elenco salvato al **Punto 1** per ricreare i DB_LINK affinché puntino agli ambienti corretti di test/pre-produzione.

**Esempio di creazione (Public):**
```sql
CREATE PUBLIC DATABASE LINK dblink_name
CONNECT TO target_user IDENTIFIED BY "target_password"
USING '(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=test_host)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=test_service)))';
```

**Esempio di creazione (Privato):**
```sql
CONNECT schema_owner/password;
CREATE DATABASE LINK dblink_name
CONNECT TO target_user IDENTIFIED BY "target_password"
USING 'TEST_TNS_ALIAS';
```

## 4. Controllo e Test di Connettività
Una volta ricreati, è obbligatorio verificare che i link funzionino e puntino al posto giusto.

Generare lo script di test per tutti i DB link:
```sql
SET SERVEROUTPUT ON
DECLARE
  v_dummy VARCHAR2(1);
  v_sql   VARCHAR2(200);
BEGIN
  FOR r IN (SELECT owner, db_link FROM dba_db_links) LOOP
    v_sql := 'SELECT dummy FROM dual@"' || r.db_link || '"';
    BEGIN
      -- Se il link è privato, potrebbe fallire se eseguito da SYS a meno che non sia PUBLIC.
      -- È preferibile testarlo con l'owner corretto.
      EXECUTE IMMEDIATE v_sql INTO v_dummy;
      DBMS_OUTPUT.PUT_LINE('OK: ' || r.owner || ' -> ' || r.db_link);
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERRORE su: ' || r.owner || ' -> ' || r.db_link || ' - ' || SQLERRM);
    END;
  END LOOP;
END;
/
```
*(Nota bene: il test per i link privati fallirà se non eseguito dall'utente owner, quindi per i link non PUBLIC eseguire una `SELECT * FROM dual@nome_link;` loggati con l'utente proprietario).*

## 5. Best Practices
1. **Naming Convention:** Includere l'ambiente nel TNS alias o nel nome del link dove possibile.
2. **Global Names:** Se `GLOBAL_NAMES=TRUE`, il nome del dblink deve coincidere col global name del DB target.
3. **Firewall:** Assicurarsi che le rotte di rete dal server di Pre-Produzione verso i DB target (anch'essi di test/preprod) siano aperte.
