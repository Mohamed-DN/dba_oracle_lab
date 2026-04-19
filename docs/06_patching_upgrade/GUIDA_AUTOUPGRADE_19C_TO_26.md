# Oracle AutoUpgrade: da 19c a 26c (26.1)

> Guida per l'upgrade alla **prima Long-Term Release post-19c**: Oracle Database 26c.
> Copre le novità specifiche del path 19c→26c, il nuovo config.cfg e le differenze rispetto all'upgrade 12c→19c.

---

## 1. Contesto: Perché 26c

Oracle 26c (rilasciata Q1 2026) è la nuova **Long-Term Support Release**:
- Support Premier fino al 2031, Extended fino al 2034
- Successore diretto di 19c (21c e 23ai erano Innovation Releases)
- Path di upgrade diretto supportato: **19c → 26c** ✅
- Path NON supportato: 12c → 26c diretto (devi passare per 19c prima)

```
12.1 → 12.2 → 19c → 26c ✅  (path supportato)
12.2 → 19c → 26c         ✅  (path supportato)
19c → 26c                ✅  (path diretto)
12.1 → 26c               ❌  (NON supportato — serve 19c intermedio)
```

---

## 2. Prerequisiti Specifici 26c

### 2.1 Software

| Componente | Requisito |
|---|---|
| Source DB | Oracle 19c con RU ≥ 19.21 (consigliato ultimo RU) |
| Target ORACLE_HOME | Oracle 26c (26.1) già installato (software only) |
| AutoUpgrade JAR | Versione 26c o successiva (MOS Doc ID 2485457.1) |
| Compatible | Source deve avere `compatible` ≥ 19.0.0 |
| OS | Oracle Linux 8.x o 9.x (OL7 è deprecato per 26c) |

> **⚠️ IMPORTANTE**: Oracle 26c richiede almeno Oracle Linux 8. Se sei su OL7, devi prima migrare l'OS o installare il 26c su un nuovo server.

### 2.2 Spazio e Architettura

```sql
-- Verifica che il source sia almeno 19c con RU recente
SELECT version_full FROM v$instance;
-- Atteso: 19.21.0.0.0 o superiore

-- Verifica che compatible sia corretto
SHOW PARAMETER compatible;
-- DEVE essere 19.0.0 o superiore

-- Verifica CDB o Non-CDB
SELECT cdb FROM v$database;
-- 26c: Oracle raccomanda fortemente l'architettura Multitenant (CDB)
-- Il Non-CDB è DEPRECATO dalla 21c in poi
```

### 2.3 Novità da Considerare Prima dell'Upgrade

| Cambiamento in 26c | Impatto |
|---|---|
| Deprecazione Non-CDB | Se hai un Non-CDB, convertilo a CDB+PDB prima o durante l'upgrade |
| Deprecazione `DBMS_JOB` | Migra a `DBMS_SCHEDULER` (vedi nostra guida) |
| Unified Auditing obbligatorio | Il Traditional Auditing non è più supportato |
| Nuovi default per `optimizer_features_enable` | Potrebbero cambiare piani SQL — testa! |
| Password file format change | Il formato ORAPWD cambia — rigenerarlo post-upgrade |

---

## 3. File di Configurazione (config.cfg)

```ini
# /home/oracle/autoupgrade/config_19_to_26.cfg
#
# ---- GLOBAL ----
global.autoupg_log_dir=/home/oracle/autoupgrade/logs_26c

# ---- DATABASE: RACDB ----
upg1.dbname=RACDB
upg1.start_time=NOW
upg1.source_home=/u01/app/oracle/product/19c/dbhome_1
upg1.target_home=/u01/app/oracle/product/26c/dbhome_1
upg1.sid=RACDB
upg1.log_dir=/home/oracle/autoupgrade/logs_26c/RACDB
upg1.upgrade_node=localhost
upg1.target_version=26
upg1.restoration=yes
upg1.drop_grp_after_upgrade=yes

# ---- CONVERSIONE NON-CDB → CDB (opzionale ma CONSIGLIATA) ----
# Se il tuo source è Non-CDB e vuoi convertirlo durante l'upgrade:
#upg1.target_cdb=CDB26
#upg1.target_pdb_name=RACPDB
#upg1.target_pdb_copy_option=file_name_convert=('/u01/app/oracle/oradata/RACDB','/u01/app/oracle/oradata/CDB26/RACPDB')

# ---- PARALLELISMO ----
#upg1.parallel_degree=4

# ---- OPZIONI AVANZATE 26c ----
upg1.timezone_upg=yes
upg1.raise_compatible=yes
```

### Parametri 26c-Specifici

| Parametro | Note |
|---|---|
| `target_version=26` | Obbligatorio per 26c |
| `target_cdb` | Se specifichi questo, AutoUpgrade converte il Non-CDB in un PDB dentro un nuovo CDB |
| `raise_compatible=yes` | In 26c è consigliato alzare compatible a `26.0.0` subito |

---

## 4. Fase ANALYZE

```bash
# Imposta variabili TARGET (26c)
export ORACLE_HOME=/u01/app/oracle/product/26c/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

# Lancia analyze
$ORACLE_HOME/jdk/bin/java -jar $ORACLE_HOME/rdbms/admin/autoupgrade.jar \
  -config /home/oracle/autoupgrade/config_19_to_26.cfg \
  -mode analyze
```

### Check Specifici 19c→26c

L'analyze controllerà in più rispetto a 12c→19c:
- **Unified Auditing**: se non è già abilitato, verrà flaggato come WARNING
- **DBMS_JOB deprecato**: se hai job con DBMS_JOB, verrà flaggato
- **Desupport features**: alcune feature rimosse in 26c
- **Optimizer stats**: verifica che le statistiche siano fresche

---

## 5. Fase DEPLOY

```bash
# ULTIMO CHECK: backup RMAN verificato?
# ULTIMO CHECK: downtime comunicato?
# ULTIMO CHECK: analyze senza ERROR?

$ORACLE_HOME/jdk/bin/java -jar $ORACLE_HOME/rdbms/admin/autoupgrade.jar \
  -config /home/oracle/autoupgrade/config_19_to_26.cfg \
  -mode deploy
```

### Monitorare

```
upg> status -job 100
upg> logs -job 100

# In un'altra shell, monitora:
tail -f /home/oracle/autoupgrade/logs_26c/RACDB/100/autoupgrade_*.log
```

### Tempo Stimato (19c→26c)

| Dimensione | Tempo |
|---|---|
| < 100 GB | 30-90 min |
| 100-500 GB | 1-4 ore |
| > 500 GB | 4-10 ore |

> L'upgrade 19c→26c è tipicamente più veloce di 12c→19c perché ci sono meno cambiamenti di catalogo.

---

## 6. Rollback

```bash
# Rollback automatico via AutoUpgrade
$ORACLE_HOME/jdk/bin/java -jar $ORACLE_HOME/rdbms/admin/autoupgrade.jar \
  -config /home/oracle/autoupgrade/config_19_to_26.cfg \
  -mode deploy -restore -jobs 100
```

```sql
-- Rollback manuale (dall'ORACLE_HOME 19c)
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
sqlplus / as sysdba

STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT AUTOUPGRADE_<jobid>_RACDB;
ALTER DATABASE OPEN RESETLOGS;
```

---

## 7. Controlli Post-Upgrade

```sql
-- Connettiti con ORACLE_HOME 26c
export ORACLE_HOME=/u01/app/oracle/product/26c/dbhome_1
sqlplus / as sysdba

-- 1. Verifica versione
SELECT version_full FROM v$instance;
-- ATTESO: 26.1.x.x.x

-- 2. Banner completo
SELECT banner_full FROM v$version;

-- 3. Componenti
SELECT comp_id, comp_name, version, status FROM dba_registry;
-- Tutti VALID

-- 4. Compatible
SHOW PARAMETER compatible;
-- Se raise_compatible=yes → 26.0.0

-- 5. Unified Auditing abilitato?
SELECT value FROM v$option WHERE parameter = 'Unified Auditing';
-- ATTESO: TRUE

-- 6. Oggetti invalidi
SELECT COUNT(*) FROM dba_objects WHERE status = 'INVALID';
@$ORACLE_HOME/rdbms/admin/utlrp.sql

-- 7. Datapatch
$ORACLE_HOME/OPatch/datapatch -verbose

-- 8. Statistiche post-upgrade
EXEC DBMS_STATS.GATHER_DICTIONARY_STATS;
EXEC DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;

-- 9. Timezone
SELECT version FROM v$timezone_file;

-- 10. Verifica nuovi parametri 26c
SELECT name, value, isdefault
FROM v$parameter
WHERE isdefault = 'FALSE'
ORDER BY name;
```

---

## 8. Post-Upgrade: Azioni Consigliate

### 8.1 Converti Non-CDB a CDB (se non l'hai fatto durante l'upgrade)

```sql
-- Da 26c, il Non-CDB è deprecato. Converti:
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE OPEN READ ONLY;

-- Genera lo script di descrizione
EXEC DBMS_PDB.DESCRIBE(pdb_descr_file => '/tmp/noncdb_desc.xml');

-- Crea il CDB 26c e plug il Non-CDB come PDB
-- (segui Oracle Doc: "Converting a Non-CDB to a PDB")
```

### 8.2 Aggiorna Password File

```bash
orapwd file=$ORACLE_HOME/dbs/orapwRACDB password=<sys_password> format=12.2
```

### 8.3 Testa le Performance

```sql
-- Confronta AWR prima/dopo upgrade
-- Forza il vecchio optimizer se necessario (temporaneo):
ALTER SESSION SET optimizer_features_enable = '19.1.0';
-- Se funziona meglio, indaga la query specifica
```

---

## 9. Riferimenti Oracle

- **AutoUpgrade Tool**: MOS Doc ID 2485457.1
- **Oracle 26c Upgrade Guide**: https://docs.oracle.com/en/database/oracle/oracle-database/26/upgrd/
- **Supported Upgrade Paths 26c**: https://docs.oracle.com/en/database/oracle/oracle-database/26/upgrd/supported-upgrade-paths.html
- **Non-CDB Deprecation**: MOS Doc ID 2667959.1
- **New Features 26c**: https://docs.oracle.com/en/database/oracle/oracle-database/26/newft/
