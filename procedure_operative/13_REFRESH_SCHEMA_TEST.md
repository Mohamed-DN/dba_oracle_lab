# 13 — Refresh Ambiente di Test (Data Pump)

> ⏱️ Tempo: Variabile (dipende dalla size) | 📅 Frequenza: Su richiesta Dev | 👤 Chi: DBA
> **Scenario**: Il team di sviluppo ti chiede "Potresti copiare lo schema PROD_APP in TEST_APP sull'ambiente di sviluppo per riprodurre un bug?"

---

## ⚠️ Prerequisiti

1. Avere una directory logica (Oracle Directory) valida sia in Produzione che in Test che punti allo stesso server SFTP/NFS, oppure copiare i file a mano.
2. Concordare una finestra temporale (lo schema di test non sarà disponibile durante il drop/import).
3. **MAI** fare DROP dello schema sull'ambiente di Produzione! Verifica tre volte la stringa di connessione.

---

## Step 1: Export da Produzione

Connettiti via terminale al server di Produzione (es. `rac1`).

```bash
# 1. Verifica che la directory Data Pump esista e quale path punti
sqlplus / as sysdba <<< "SELECT directory_name, directory_path FROM dba_directories WHERE directory_name = 'DATA_PUMP_DIR';"

# 2. Esegui l'export dello schema (schema PROD_APP)
# Nelle ultime versioni, "expdp" chiederà la password se non scritta in chiaro, meglio.
expdp userid=system directory=DATA_PUMP_DIR dumpfile=PROD_APP_exp_%u.dmp logfile=PROD_APP_exp.log schemas=PROD_APP parallel=4 compression=ALL
```
*Note: Il `%u` permette il parallelismo su più file.*

---

## Step 2: Trasferimento File (Solo se gli host sono diversi)

Se Database Prod e Database Test sono su server diversi e non condividono uno storage NFS:

```bash
# Entra nella cartella di export
cd /u01/app/oracle/admin/RACDB/dpdump/

# Trasferisci con SCP (o rsync)
scp PROD_APP_exp_*.dmp oracle@server_test:/u01/app/oracle/admin/RACDB_TEST/dpdump/
```

---

## Step 3: Preparazione Database di Test (Svuotamento)

Connettiti all'ambiente di **TEST/SVILUPPO**.
**🔴 ATTENZIONE: Assicurati al 100% di essere nel DB di TEST!**

```bash
sqlplus / as sysdba
```

```sql
-- Verifica il nome dell'istanza! DEVE essere l'ambiente di Test
SELECT instance_name FROM v$instance;

-- Kick degli utenti connessi prima del drop
ALTER SYSTEM ENABLE RESTRICTED SESSION;

-- Esegui il drop dell'utente CASCADE per pulire vecchi dati
DROP USER TEST_APP CASCADE;

-- Ricrea la "scatola" vuota dell'utente (assegna i tablespace corretti)
CREATE USER TEST_APP IDENTIFIED BY "TestApp123!" 
DEFAULT TABLESPACE test_data 
TEMPORARY TABLESPACE temp;

GRANT CONNECT, RESOURCE TO TEST_APP;
ALTER USER TEST_APP QUOTA UNLIMITED ON test_data;

ALTER SYSTEM DISABLE RESTRICTED SESSION;
```

---

## Step 4: Import nell'Ambiente di Test (Remapping)

Poiché lo stiamo importando in uno schema che si chiama `TEST_APP` (diverso dall'originale `PROD_APP`) e magari su un tablespace diverso (`test_data` invece di `prod_data`), dobbiamo mappare in volo:

```bash
# Sull'host di Test
impdp userid=system directory=DATA_PUMP_DIR dumpfile=PROD_APP_exp_%u.dmp logfile=TEST_APP_imp.log \
remap_schema=PROD_APP:TEST_APP \
remap_tablespace=PROD_DATA:TEST_DATA \
parallel=4 table_exists_action=REPLACE transform=OID:N:type
```
*Note:*
* *`remap_schema` converte tutti gli oggetti da PROD a TEST in volo.*
* *`transform=OID:N:type` previene problemi su viste con object id (spesso falliscono in import).*

---

## Step 5: Check Post-Refresh

```bash
# Verifica eventuali errori nel log
grep -i "ORA-" /u01/app/oracle/admin/RACDB_TEST/dpdump/TEST_APP_imp.log
```

```sql
sqlplus system

-- Ricompila oggetti invalidi (alcune viste potrebbero essere invalide)
EXEC DBMS_UTILITY.COMPILE_SCHEMA(schema => 'TEST_APP');

-- Verifica oggetti invalidi rimasti
SELECT object_name, object_type, status 
FROM dba_objects 
WHERE owner = 'TEST_APP' AND status = 'INVALID';

-- Aggiorna statistiche per evitare esecuzioni lente causate dal ricaricamento
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('TEST_APP');
```

---

## ✅ Checklist Finale

| Azione | Controllo |
|---|---|
| Numero di Linee / Tabelle | Corrisponde circa a quelle di Prod? |
| Viste Invalide | Compilate tutte o gestite dal team DEV? |
| Password Utente | Comunciata al team DEV (con la scadenza rimossa tramite Profile)? |
| File DMP Cancellati? | Cancella sempre i `.dmp` e `.log` dopo per non riempire i server. (es: `rm PROD_APP_exp*.dmp`) |
