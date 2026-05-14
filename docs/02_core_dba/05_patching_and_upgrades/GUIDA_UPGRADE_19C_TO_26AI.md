# Upgrade a Oracle AI Database 26ai (Tramite AutoUpgrade)

Questa guida illustra il processo per effettuare un upgrade out-of-place dalla vecchia Long Term Release (Oracle 19c) verso la nuova pietra miliare di settore: **Oracle AI Database 26ai**.

L'aggiornamento viene eseguito utilizzando lo strumento Oracle ufficiale **AutoUpgrade**, che minimizza il tempo di downtime, gestisce la pre-analisi, l'upgrade effettivo e le fix post-upgrade.

---

## 1. Perché 26ai? (Cosa c'è di nuovo per il DBA)
A differenza di 19c, l'edizione 26ai ha integrato nativamente concetti di intelligenza artificiale direttamente nel motore RDBMS, rivoluzionando lo sviluppo applicativo e l'amministrazione:

- **AI Vector Search**: Possibilità di memorizzare vettori di embedding come tipi di dato nativi ed eseguire ricerche di similarità (es. `ORDER BY VECTOR_DISTANCE`) fusi in query SQL tradizionali con dati relazionali, spaziali e grafi.
- **Oracle Select AI Agent**: Un framework per creare agenti LLM (Agentic AI) autonomi che vivono dentro al DB.
- **JSON Relational Duality**: I dati possono essere letti/scritti tramite REST come documenti JSON, pur essendo salvati in tabelle altamente normalizzate, eliminando il divario relazionale/documentale.
- **SQL Firewall**: Blocco in tempo reale delle SQL injection direttamente a livello Kernel, isolando e proteggendo i payload malevoli in input.

---

## 2. Prerequisiti per l'Upgrade
Prima di iniziare il processo su un ambiente di Produzione o nel nostro Lab:

1. **Software Oracle 26ai**: Installare la Grid Infrastructure e il Database Software (Oracle Home) versione 26ai sui nodi target.
2. **AutoUpgrade Tool**: Assicurarsi di scaricare l'ultima versione di `autoupgrade.jar` dal supporto Oracle (Doc ID 2485457.1).
3. **Validazione OS**: Oracle 26ai richiede Oracle Linux 8.x o 9.x.
4. **Backup**: Eseguire un Guaranteed Restore Point (GRP) o un backup Full RMAN prima dell'upgrade.

---

## 3. Preparazione: Il File di Configurazione (autoupgrade.cfg)
AutoUpgrade lavora su un file dichiarativo. Creare un file `upgrade_19c_26ai.cfg`:

```ini
global.autoupg_log_dir=/u01/app/oracle/autoupgrade
# Configurazione per il database 'ORCL'
upg1.dbname=ORCL
upg1.start_time=NOW
upg1.source_home=/u01/app/oracle/product/19.3.0/dbhome_1
upg1.target_home=/u01/app/oracle/product/26.0.0/dbhome_1
upg1.sid=ORCL
upg1.log_dir=/u01/app/oracle/autoupgrade/ORCL
upg1.upgrade_node=rac-node-1
upg1.target_version=26
```

---

## 4. Esecuzione del Processo in Fasi

AutoUpgrade consiglia un approccio a fasi. Entra nell'ambiente con le variabili del database 19c caricate.

### Fase 1: Analyze (Verifica Pre-Upgrade)
Esegue solo controlli (sola lettura) per identificare blocchi all'upgrade (es. componenti dismessi, dizionari non validi, timezone vecchie).

```bash
java -jar autoupgrade.jar -config upgrade_19c_26ai.cfg -mode analyze
```
Verifica il report generato nella directory dei log e risolvi i warning bloccanti.

### Fase 2: Fixups (Correzione Automatica)
Esegue correzioni a livello di database per le issue riscontrate in fase di `analyze`.

```bash
java -jar autoupgrade.jar -config upgrade_19c_26ai.cfg -mode fixups
```

### Fase 3: Deploy (Upgrade Reale)
Questo comando fermerà l'istanza 19c, la riavvierà sotto la nuova Oracle Home 26ai, e applicherà tutti gli script del dizionario dati.

```bash
java -jar autoupgrade.jar -config upgrade_19c_26ai.cfg -mode deploy
```

Puoi monitorare lo stato aprendo un'altra console di AutoUpgrade e digitando:
```bash
lsj  # List Jobs
status -job 101 # Status dettaglio del job
```

---

## 5. Post-Upgrade e Verifica

Una volta che il comando `deploy` termina con esito positivo:
1. Verifica l'orario di avvio e i warning dell'alert log del nuovo database 26ai.
2. Controlla il livello di compatibilità (generalmente non viene alzato in automatico a 26 per permettere downgrade):
   ```sql
   SELECT name, value FROM v$parameter WHERE name = 'compatible';
   ```
   *Se sei sicuro di non voler tornare indietro, eleva la compatibilità a '26.0.0'*.
3. Avvia i test applicativi!

> [!CAUTION]
> L'innalzamento del parametro `compatible` a `26.0.0` è irreversibile. Una volta impostato, **non potrai fare il downgrade a 19c** né montare i backup vecchi sulla nuova istanza. Fallo solo dopo il sign-off finale dell'applicativo.
