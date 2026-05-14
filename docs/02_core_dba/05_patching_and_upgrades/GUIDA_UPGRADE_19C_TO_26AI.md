# Runbook Enterprise: Upgrade da Oracle 19c a Oracle 26ai (AutoUpgrade)

Questo **Runbook** documenta la procedura canonica, testata in scenari *Mission Critical*, per effettuare l'upgrade di un database da Oracle 19c (Long Term Release storica) a **Oracle 26ai** (Nuova Long Term Release con funzionalità AI Native).
A differenza di un semplice upgrade di laboratorio, questa procedura include mitigazioni dei rischi, punti di fallback istantaneo e strategie per minimizzare il downtime (Zero-Downtime Data Guard).

---

## 0. Fallback Strategy: Guaranteed Restore Point (GRP)
La primissima regola di un upgrade Enterprise è la garanzia di un rollback immediato. Se durante la fase di Deploy l'AutoUpgrade si corrompe o se l'applicativo post-upgrade rileva un crollo prestazionale inaccettabile, non si fa il "restore del backup" (che richiede ore/giorni). Si usa il Flashback Database.

**Operazioni preliminari (sul DB 19c):**
```sql
-- Abilita Flashback se spento
ALTER SYSTEM SET db_recovery_file_dest_size = 500G SCOPE=BOTH;
ALTER SYSTEM SET db_recovery_file_dest = '+FRA' SCOPE=BOTH;
ALTER DATABASE FLASHBACK ON;

-- Crea il Punto di Ripristino Garantito (OBBLIGATORIO)
CREATE RESTORE POINT PRE_UPG_26AI GUARANTEE FLASHBACK DATABASE;
```
*In caso di disastro assoluto, basterà un `FLASHBACK DATABASE TO RESTORE POINT PRE_UPG_26AI;` per tornare alla situazione originaria in 2 minuti.*

---

## 1. Fase Pre-Volo (Igiene del Database 19c)
Un database "sporco" rallenta l'AutoUpgrade e causa invalidazioni a catena.
Esegui questi step sul database 19c originario 24h prima della finestra di manutenzione:

1. **Svuota il Recycle Bin (Cestino)**: L'upgrade del dizionario si "incastra" se cerca di aggiornare tabelle cestinate.
   ```sql
   PURGE DBA_RECYCLEBIN;
   ```
2. **Ricompila gli oggetti invalidi**: Non iniziare mai un upgrade se ci sono oggetti utente invalidi.
   ```bash
   $ORACLE_HOME/perl/bin/perl $ORACLE_HOME/rdbms/admin/utlrp.sql
   ```
3. **Raccogli Statistiche del Dizionario**: L'AutoUpgrade usa pesantemente il catalogo di sistema. Statistiche vecchie causano upgrade lentissimi (ore invece di minuti).
   ```sql
   EXEC DBMS_STATS.GATHER_DICTIONARY_STATS;
   EXEC DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;
   ```

---

## 2. Configurazione AutoUpgrade Tool
Il tool AutoUpgrade (`autoupgrade.jar`) rimpiazza il vecchio `dbua` (Database Upgrade Assistant) e il lentissimo `catupgrd.sql`.
Scarica sempre l'ultimissima versione rilasciata su MyOracleSupport (Doc ID 2485457.1), e non usare quella fornita di default nella ORACLE_HOME 26ai.

Crea un file di configurazione (`config_26ai.cfg`):
```ini
global.autoupg_log_dir=/u01/app/oracle/admin/autoupgrade
# Parametri del DB
upg1.dbname=PRDDB
upg1.start_time=NOW
upg1.source_home=/u01/app/oracle/product/19.0.0/dbhome_1
upg1.target_home=/u01/app/oracle/product/26.0.0/dbhome_1
upg1.sid=PRDDB
upg1.log_dir=/u01/app/oracle/admin/autoupgrade/PRDDB
upg1.target_version=26
# Disabilita il timezone upgrade automatico (meglio farlo a mano dopo test)
upg1.timezone_upg=no
```

---

## 3. Esecuzione Multi-Fase (Analyze, Fixups, Deploy)

In un ambiente Enterprise non si lancia l'upgrade in un colpo solo.

### Fase A: `analyze` (Lettura Non Invasiva)
Si può eseguire anche giorni prima in pieno orario lavorativo. Analizza il DB 19c e identifica problemi strutturali.
```bash
java -jar autoupgrade.jar -config config_26ai.cfg -mode analyze
```
*Leggere il file `PRDDB_preupgrade.html` nei log.*

### Fase B: `fixups` (Correzioni Automatiche)
Esegue piccoli script sul 19c per risolvere i warning pre-upgrade.
```bash
java -jar autoupgrade.jar -config config_26ai.cfg -mode fixups
```

### Fase C: `deploy` (Downtime Iniziato)
**ATTENZIONE**: Inizio del disservizio applicativo. L'istanza verrà chiusa e riaperta sotto i binari 26ai.
```bash
java -jar autoupgrade.jar -config config_26ai.cfg -mode deploy
```
Monitoraggio in una seconda shell:
```bash
java -jar autoupgrade.jar -console
autoupgrade> lsj
autoupgrade> status -job 100
```

---

## 4. Architetture Zero-Downtime (Rolling su Data Guard)
Se un fermo di 1-2 ore è inaccettabile (SLA stringenti), non si esegue l'upgrade diretto in-place. Si utilizza **Transient Logical Standby (DBMS_ROLLING)**.
In breve:
1. Si converte temporaneamente il Data Guard Physical Standby in un Logical Standby.
2. Si fa l'upgrade dell'istanza Logical (ex-Standby) a 26ai *mentre la Primary 19c è ancora attiva e serve i clienti*.
3. Si esegue uno switchover fulmineo.
4. Quella che era la Primary 19c viene ricostruita direttamente agganciandosi alla nuova Primary 26ai.

---

## 5. Attività Post-Upgrade Obbligatorie
Se l'AutoUpgrade conclude in "Completed", non cantare vittoria, segui questa checklist:

1. **Check Compatibilità**:
   Di default l'AutoUpgrade lascia `COMPATIBLE=19.0.0`. Questo permette il downgrade. Se i test applicativi vanno bene e decidi di rimanere su 26ai, alza il parametro:
   ```sql
   ALTER SYSTEM SET compatible='26.0.0' SCOPE=SPFILE;
   -- Riavvia istanza
   ```
   *(Attenzione: Da questo istante, il comando Flashback per il downgrade è permanentemente disattivato).*

2. **Aggiornamento Timezone (DBMS_DST)**:
   Ogni major release ha file di fuso orario aggiornati.
   Esegui gli script `$ORACLE_HOME/rdbms/admin/utltz_upg_check.sql` e `utltz_upg_apply.sql`.

3. **Upgrade Catalogo RMAN**:
   Se usi un catalogo di ripristino esterno, collegati al catalogo RMAN 26ai e aggiornalo:
   ```bash
   rman target / catalog rman/pass@RCAT
   RMAN> UPGRADE CATALOG;
   RMAN> UPGRADE CATALOG; -- Va ripetuto due volte per sicurezza per bug noti.
   ```

4. **Drop Restore Point**:
   Una volta ottenuto il *Sign-Off* dall'applicativo e dal business, il GRP consuma pesantemente la FRA bloccando gli archivelog. Droppalo per evitare di intasare lo storage e fermare il DB:
   ```sql
   DROP RESTORE POINT PRE_UPG_26AI;
   ```

---

## 6. Perché ai Devs piacerà 26ai? (Cosa Abilitare)
Dopo l'upgrade, potrai abilitare per gli sviluppatori:
- **AI Vector Search**: Crea colonne di tipo `VECTOR` nelle tabelle esistenti per far loro eseguire similarity search con Embeddings presi da un LLM, fusi con SQL relazionale.
- **SQL Firewall**: Addestra il database a intercettare SQL injection analizzando un periodo di log e creando una whitelist autorizzata (`DBMS_SQL_FIREWALL`).
- **Lock-Free Reservations**: Converti le classiche colonne di giacenza (es. `saldo_conto`) per evitare il lock di riga (`FOR UPDATE`) sui micro-aggiornamenti concomitanti.
