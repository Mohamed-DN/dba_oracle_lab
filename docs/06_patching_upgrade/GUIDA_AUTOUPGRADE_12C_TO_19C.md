# Oracle AutoUpgrade: da 12c (12.2) a 19c

> Guida completa per l'upgrade automatizzato tramite il tool **AutoUpgrade** di Oracle.
> Copre prerequisiti, configurazione, analisi, deploy e verifiche post-upgrade.

---

## 1. Cos'è AutoUpgrade

AutoUpgrade è il tool ufficiale Oracle (introdotto con 19c, backportato a 12c/18c) che automatizza l'intero ciclo di vita di un upgrade database:

```
ANALYZE → FIXUPS → DEPLOY → POSTUPGRADE
```

**Vantaggi rispetto all'upgrade manuale (DBUA/catctl.pl):**
- Esegue automaticamente i pre-check e i fixup
- Gestisce Guaranteed Restore Point (GRP) per rollback
- Supporta upgrade paralleli di più database contemporaneamente
- Produce log strutturati e report HTML
- È il metodo **raccomandato da Oracle** per tutti gli upgrade a partire dalla 19c

---

## 2. Prerequisiti

### 2.1 Software

| Componente | Requisito |
|---|---|
| Source DB | Oracle 12.2.0.1 (con ultimo RU consigliato) |
| Target ORACLE_HOME | Oracle 19c (19.3+) già installato (software only) |
| AutoUpgrade JAR | Versione più recente da MOS (Doc ID 2485457.1) |
| Java | JDK presente nel target ORACLE_HOME (usato automaticamente) |
| OS | Oracle Linux 7.x / 8.x / RHEL equivalente |

```bash
# Scarica l'ultimo autoupgrade.jar da My Oracle Support
# Doc ID 2485457.1 — "AutoUpgrade Tool"
# Copialo nel target ORACLE_HOME:
cp autoupgrade.jar /u01/app/oracle/product/19c/dbhome_1/rdbms/admin/
```

### 2.2 Spazio Disco

| Area | Minimo |
|---|---|
| Target ORACLE_HOME | Già installato |
| /tmp | ≥ 2 GB |
| Flash Recovery Area | Spazio per il GRP (≥ 15 GB consigliati) |
| Archivelog area | Sufficiente per il redo generato durante l'upgrade |

### 2.3 Backup (OBBLIGATORIO)

```bash
# Prima di QUALSIASI upgrade — backup completo
rman TARGET /
RMAN> BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG;
RMAN> BACKUP CURRENT CONTROLFILE;
```

> **Regola d'oro**: MAI iniziare un upgrade senza backup RMAN verificato.

### 2.4 Verifiche Pre-Upgrade

```sql
-- Sul source database (12.2)
sqlplus / as sysdba

-- Verifica versione
SELECT version, version_full FROM v$instance;

-- Verifica compatible
SHOW PARAMETER compatible;
-- Deve essere 12.2.0 o inferiore

-- Verifica timezone version
SELECT version FROM v$timezone_file;

-- Verifica componenti installati
SELECT comp_id, comp_name, version, status FROM dba_registry;

-- Oggetti invalidi (risolvili PRIMA)
SELECT COUNT(*) FROM dba_objects WHERE status = 'INVALID';
@$ORACLE_HOME/rdbms/admin/utlrp.sql

-- Verifica che ARCHIVELOG sia attivo
SELECT log_mode FROM v$database;
-- DEVE essere ARCHIVELOG

-- Verifica password file
SELECT * FROM v$pwfile_users;
```

---

## 3. File di Configurazione (config.cfg)

Il file `config.cfg` è il cuore di AutoUpgrade. Definisce il source, il target e le opzioni.

```ini
# /home/oracle/autoupgrade/config.cfg
#
# ---- GLOBAL ----
global.autoupg_log_dir=/home/oracle/autoupgrade/logs

# ---- DATABASE: ORCL12C ----
upg1.dbname=ORCL12C
upg1.start_time=NOW
upg1.source_home=/u01/app/oracle/product/12.2.0/dbhome_1
upg1.target_home=/u01/app/oracle/product/19c/dbhome_1
upg1.sid=ORCL12C
upg1.log_dir=/home/oracle/autoupgrade/logs/ORCL12C
upg1.upgrade_node=localhost
upg1.target_version=19
upg1.restoration=yes
upg1.drop_grp_after_upgrade=yes

# ---- RAC (se applicabile) ----
#upg1.target_cdb=CDB19C         # se vuoi convertire a CDB durante l'upgrade

# ---- PARALLELISMO ----
#upg1.parallel_degree=4         # default: auto (basato su CPU)

# ---- OPZIONI AVANZATE ----
#upg1.timezone_upg=yes           # aggiorna timezone file se necessario
#upg1.raise_compatible=yes       # imposta compatible a 19.0.0 post-upgrade
```

### Parametri Chiave

| Parametro | Descrizione | Default |
|---|---|---|
| `source_home` | Path dell'ORACLE_HOME 12c | (obbligatorio) |
| `target_home` | Path dell'ORACLE_HOME 19c | (obbligatorio) |
| `restoration` | Crea Guaranteed Restore Point per rollback | `yes` |
| `drop_grp_after_upgrade` | Rimuove il GRP dopo upgrade riuscito | `yes` |
| `target_version` | Versione target | `19` |
| `raise_compatible` | Alza il parametro `compatible` automaticamente | `no` |

---

## 4. Fase ANALYZE (Dry Run)

Questa fase analizza il database senza apportare modifiche. **Eseguila SEMPRE prima del deploy.**

```bash
# Imposta le variabili d'ambiente del TARGET (19c)
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

# Lancia AutoUpgrade in modalità ANALYZE
$ORACLE_HOME/jdk/bin/java -jar $ORACLE_HOME/rdbms/admin/autoupgrade.jar \
  -config /home/oracle/autoupgrade/config.cfg \
  -mode analyze
```

### Output atteso

```
AutoUpgrade 24.8.241107  launched with default internal options
Processing config file ...
+--------------------------------+
| Starting AutoUpgrade execution |
+--------------------------------+
Type 'help' to list console commands
upg> Job 100 completed
------------------ Final Summary ------------------
Number of databases   [ 1 ]
Jobs finished         [1]
Jobs failed           [0]
```

### Leggi il Report

```bash
# Report HTML (il più leggibile)
cat /home/oracle/autoupgrade/logs/ORCL12C/100/prechecks/ORCL12C_preupgrade.html

# Report testuale
cat /home/oracle/autoupgrade/logs/ORCL12C/100/prechecks/ORCL12C_preupgrade.log
```

| Severità | Significato | Azione |
|---|---|---|
| `PASS` | Check superato | Nessuna |
| `WARNING` | Non bloccante, ma da correggere | Consigliato fix |
| `FIXABLE` | Bloccante, ma AutoUpgrade lo risolve | Automatico in fase fixups |
| `ERROR` | Bloccante, intervento manuale richiesto | **Devi risolverlo tu** |

---

## 5. Fase FIXUPS (Pre-Upgrade Corrections)

Se l'analyze ha trovato problemi `FIXABLE`, puoi lanciare la fase fixups:

```bash
$ORACLE_HOME/jdk/bin/java -jar $ORACLE_HOME/rdbms/admin/autoupgrade.jar \
  -config /home/oracle/autoupgrade/config.cfg \
  -mode fixups
```

Questa fase corregge automaticamente:
- Statistiche del data dictionary mancanti
- Parametri deprecati
- Timezone version mismatch (se `timezone_upg=yes`)
- Gathering di statistiche su tabelle fixed

---

## 6. Fase DEPLOY (Upgrade Reale)

**⚠️ Questa fase esegue l'upgrade effettivo. Il database sarà DOWN durante il processo.**

```bash
# ULTIMO CHECK: hai il backup RMAN valido?
# ULTIMO CHECK: hai comunicato il downtime?

$ORACLE_HOME/jdk/bin/java -jar $ORACLE_HOME/rdbms/admin/autoupgrade.jar \
  -config /home/oracle/autoupgrade/config.cfg \
  -mode deploy
```

### Cosa succede durante il deploy

1. **Pre-upgrade checks** (ri-esecuzione analyze)
2. **Creazione GRP** (Guaranteed Restore Point per rollback)
3. **Shutdown** del database source
4. **Startup** con il target ORACLE_HOME (19c) in UPGRADE mode
5. **Esecuzione catctl.pl** (catalogo upgrade, in parallelo)
6. **Post-upgrade fixups** (ricompilazione, stats, timezone)
7. **Startup NORMAL** del database con 19c
8. **Drop GRP** (se `drop_grp_after_upgrade=yes`)

### Monitorare il Progresso

Durante il deploy, la console AutoUpgrade è interattiva:

```
upg> status -job 100
upg> logs -job 100
upg> lsj            # lista job attivi
```

### Tempo Stimato

| Dimensione DB | Tempo Tipico |
|---|---|
| < 50 GB | 30-60 min |
| 50-500 GB | 1-3 ore |
| > 500 GB | 3-8 ore |

---

## 7. Rollback (se l'upgrade fallisce)

```bash
# Se il deploy fallisce, AutoUpgrade offre il rollback automatico via GRP
$ORACLE_HOME/jdk/bin/java -jar $ORACLE_HOME/rdbms/admin/autoupgrade.jar \
  -config /home/oracle/autoupgrade/config.cfg \
  -mode deploy -restore -jobs 100
```

Oppure manualmente:
```bash
# Dall'ORACLE_HOME source (12c)
export ORACLE_HOME=/u01/app/oracle/product/12.2.0/dbhome_1
sqlplus / as sysdba

STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT AUTOUPGRADE_<jobid>_<dbname>;
ALTER DATABASE OPEN RESETLOGS;
```

---

## 8. Controlli Post-Upgrade

```sql
-- Connettiti con il nuovo ORACLE_HOME (19c)
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
sqlplus / as sysdba

-- 1. Verifica versione
SELECT version, version_full FROM v$instance;
-- ATTESO: 19.x.x.x.x

SELECT banner_full FROM v$version;

-- 2. Verifica stato componenti
SELECT comp_id, comp_name, version, status FROM dba_registry;
-- ATTESO: tutti in VALID

-- 3. Verifica compatible
SHOW PARAMETER compatible;
-- Se vuoi alzarlo (IRREVERSIBILE!):
-- ALTER SYSTEM SET compatible = '19.0.0' SCOPE=SPFILE;
-- SHUTDOWN IMMEDIATE;
-- STARTUP;

-- 4. Oggetti invalidi
SELECT owner, object_type, COUNT(*) 
FROM dba_objects WHERE status = 'INVALID'
GROUP BY owner, object_type ORDER BY 3 DESC;

-- Ricompila
@$ORACLE_HOME/rdbms/admin/utlrp.sql

-- 5. Verifica timezone
SELECT version FROM v$timezone_file;

-- 6. Patch post-upgrade
SELECT * FROM dba_registry_sqlpatch ORDER BY action_time DESC;

-- 7. Esegui datapatch (se hai applicato RU sul target ORACLE_HOME)
$ORACLE_HOME/OPatch/datapatch -verbose
```

---

## 9. Specifiche RAC (se applicabile)

Per un upgrade RAC, AutoUpgrade gestisce automaticamente lo shutdown/startup delle istanze.

```ini
# Nel config.cfg, specifica:
upg1.sid=ORCL12C1                 # SID della prima istanza
upg1.upgrade_node=rac1            # nodo dove eseguire l'upgrade
upg1.target_version=19
```

```bash
# Prima dell'upgrade, ferma tutte le istanze tranne quella di upgrade
srvctl stop instance -d ORCL12C -i ORCL12C2

# Dopo l'upgrade, aggiorna il cluster
srvctl upgrade database -d ORCL12C -o /u01/app/oracle/product/19c/dbhome_1
srvctl start database -d ORCL12C
```

---

## 10. Riferimenti Oracle

- **AutoUpgrade Tool (MOS)**: Doc ID 2485457.1
- **Guida Upgrade 19c**: https://docs.oracle.com/en/database/oracle/oracle-database/19/upgrd/
- **AutoUpgrade Best Practices (MOS)**: Doc ID 2568623.1
- **Supported Upgrade Paths**: https://docs.oracle.com/en/database/oracle/oracle-database/19/upgrd/supported-upgrade-paths.html
