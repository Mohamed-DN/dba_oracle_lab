# 10 — Start/Stop Database RAC

<!-- RUNBOOK_NAV_START -->
## Casi piu frequenti da aprire prima
- Stop/start pianificato del database RAC.
- Rolling restart di una singola istanza.
- Stop servizi applicativi prima del database.
- Stop cluster per manutenzione OS/nodo.
- Verifica CRS, listener e servizi dopo riavvio.

## Indice rapido
- [Casi piu frequenti da aprire prima](#casi-piu-frequenti-da-aprire-prima)
- [Obiettivi](#obiettivi)
- [Procedura Operativa](#procedura-operativa)
  - [PREREQUISITI](#prerequisiti)
  - [STOP — Ordine Corretto](#stop-ordine-corretto)
  - [1. Ferma i Servizi Applicativi](#1-ferma-i-servizi-applicativi)
  - [2. Ferma il Database RAC](#2-ferma-il-database-rac)
  - [3. Verifica Stop](#3-verifica-stop)
  - [4. Ferma anche lo Standby (se necessario)](#4-ferma-anche-lo-standby-se-necessario)
  - [5. Per Manutenzione OS — Ferma il Cluster](#5-per-manutenzione-os-ferma-il-cluster)
  - [START — Ordine Corretto](#start-ordine-corretto)
  - [1. Avvia il Cluster (se fermato)](#1-avvia-il-cluster-se-fermato)
  - [2. Avvia il Database RAC](#2-avvia-il-database-rac)
  - [3. Avvia i Servizi](#3-avvia-i-servizi)
  - [4. Avvia lo Standby](#4-avvia-lo-standby)
  - [5. Verifica Post-Start Completa](#5-verifica-post-start-completa)
- [Validazione Finale](#validazione-finale)
- [Troubleshooting](#troubleshooting)
<!-- RUNBOOK_NAV_END -->

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- [09_dataguard_status.sql](../03_scripts_pronti/09_dataguard_status.sql) - ruolo DB, transport/apply lag, gap, MRP, switchover readiness.
<!-- READY_SCRIPTS_END -->
> ⏱️ Tempo: 10-30 minuti | 📅 Frequenza: Manutenzione pianificata | 👤 Chi: DBA
> **Scenario tipico**: Manutenzione OS, patching, riavvio controllato

---

## Obiettivi

Eseguire l'arresto e l'avvio controllato di un database Oracle RAC, dei relativi servizi e del cluster per attività di manutenzione ordinaria o straordinaria.

## Procedura Operativa

### PREREQUISITI

- Backup RMAN recente verificato
- Blackout EM attivo (se Enterprise Manager è in uso)
- Comunicazione al team applicativo
- Piano di rollback pronto

---

### STOP — Ordine Corretto

### 1. Ferma i Servizi Applicativi

```bash
# Come oracle
. ~/.db_env

# Lista servizi attivi
srvctl status service -d RACDB

# Ferma i servizi applicativi (NON il servizio default)
srvctl stop service -d RACDB -s &app_service
```

### 2. Ferma il Database RAC

```bash
# Ferma tutte le istanze
srvctl stop database -d RACDB

# Oppure ferma un'istanza alla volta (rolling)
srvctl stop instance -d RACDB -i RACDB2
srvctl stop instance -d RACDB -i RACDB1
```

### 3. Verifica Stop

```bash
srvctl status database -d RACDB
# ATTESO: Database is not running

crsctl stat res -t | grep -A2 "ora.racdb"
```

### 4. Ferma anche lo Standby (se necessario)

```bash
# Sullo STANDBY
srvctl stop database -d RACDB_STBY
```

### 5. Per Manutenzione OS — Ferma il Cluster

```bash
# ⚠️ SOLO se devi riavviare il nodo!
# Come root:
crsctl stop crs

# Per fermare il cluster su tutti i nodi:
crsctl stop cluster -all
```

---

### START — Ordine Corretto

### 1. Avvia il Cluster (se fermato)

```bash
# Come root:
crsctl start crs

# Per avviare il cluster su tutti i nodi:
crsctl start cluster -all

# Verifica CRS
crsctl check crs
crsctl stat res -t
```

### 2. Avvia il Database RAC

```bash
# Come oracle
. ~/.db_env

# Avvia tutte le istanze
srvctl start database -d RACDB

# Verifica
srvctl status database -d RACDB -v
```

### 3. Avvia i Servizi

```bash
srvctl start service -d RACDB -s &app_service
srvctl status service -d RACDB
```

### 4. Avvia lo Standby

```bash
srvctl start database -d RACDB_STBY

# Verifica che l'apply riprenda
sqlplus / as sysdba <<EOF
SELECT process, status FROM v\$managed_standby WHERE process = 'MRP0';
SELECT name, value FROM v\$dataguard_stats WHERE name LIKE '%lag%';
EOF
```

### 5. Verifica Post-Start Completa

```sql
sqlplus / as sysdba

-- Database aperto
SELECT inst_id, instance_name, status, host_name FROM gv$instance;

-- Tablespace OK
SELECT tablespace_name, ROUND(used_percent, 1) AS pct
FROM dba_tablespace_usage_metrics WHERE used_percent > 85;

-- Alert log pulito
SELECT originating_timestamp, message_text
FROM v$diag_alert_ext
WHERE originating_timestamp > SYSDATE - 1/24
  AND message_text LIKE '%ORA-%'
ORDER BY originating_timestamp DESC;

-- Backup schedulati OK
SELECT job_name, enabled, state FROM dba_scheduler_jobs
WHERE job_name LIKE '%RMAN%' OR job_name LIKE '%BACKUP%';
```

```bash
# Listener e SCAN
srvctl status listener
srvctl status scan_listener
lsnrctl status

# Broker (se attivo)
dgmgrl / "SHOW CONFIGURATION"
```

---

## Validazione Finale

| Fase | Controllo | Atteso |
|---|---|---|
| POST-STOP | `srvctl status database` | not running |
| POST-START | Tutte le istanze | OPEN |
| POST-START | Listener/SCAN | ONLINE |
| POST-START | Servizi applicativi | Running |
| POST-START | Data Guard | Lag < soglia |
| POST-START | Alert log | Nessun ORA- critico |

## Troubleshooting

1. **Il Database non si ferma**: Una sessione applicativa potrebbe essere rimasta appesa. Usare `srvctl stop database -d RACDB -f` (force) per forzare l'arresto.
2. **Il Cluster (CRS) non parte**: Verificare lo stato dei dischi di voto (Voting Disks) con `crsctl query css votedisk`.
3. **Servizi non salgono automaticamente**: Verificare la configurazione del servizio con `srvctl config service` e assicurarsi che i nodi preferiti/disponibili siano corretti.
