# Guida Completa: Monitoraggio Oracle Database e Linux

> Come installare e configurare un sistema di monitoraggio opensource per i tuoi server Oracle e Linux.
> Confronto pratico tra le 3 opzioni migliori + guida installazione passo-passo.

---

## Quick Pick (scelta immediata)

| Scenario | Scelta consigliata | Perché |
|---|---|---|
| Vuoi partire subito in lab Oracle | **Checkmk** | Setup veloce, plugin Oracle nativo, discovery automatico |
| Hai tanti host e policy centrali complesse | **Zabbix** | Grande flessibilità e governance su larga scala |
| Sei già orientato Kubernetes/DevOps | **Prometheus + Grafana** | Standard cloud-native e dashboard avanzate |
| Vuoi alert robusti + dashboard top | **Checkmk + Grafana** | Alerting operativo + visualizzazione avanzata |

### Confronto rapido sintetico

| Tool | Oracle | Linux | Curva apprendimento | Setup |
|---|---|---|---|---|
| **Checkmk** | ⭐⭐⭐ nativo | ⭐⭐⭐ | 🟢 facile | singolo server |
| **Zabbix** | ⭐⭐⭐ template ODBC | ⭐⭐⭐ | 🔴 ripida | server + DB backend |
| **Prometheus + Grafana** | ⭐⭐ exporter | ⭐⭐⭐ | 🟡 media | stack multi-componente |

---

## OPZIONE 1: Checkmk (Consigliata per DBA)

### Perché Checkmk per Oracle?

- **Auto-discovery**: installi l'agent, Checkmk scopre automaticamente le istanze Oracle, tablespace, ASM
- **Plugin Oracle nativo**: monitora senza configurazione aggiuntiva:
  - Tablespace (uso %, autoextend, maxsize)
  - Sessions (attive, bloccanti, totali)
  - RMAN backup (stato, età ultimo backup)
  - Data Guard (lag, apply status)
  - ASM diskgroup (uso, rebalance)
  - Alert log (ORA- errors)
  - Performance (buffer cache hit, library cache)
- **Alert intelligenti**: soglie dinamiche che si adattano al tuo carico

### Installazione Checkmk (Oracle Linux / RHEL)

```bash
# ---- 1. INSTALLAZIONE SERVER (sul monitoring server) ----

# Scarica Checkmk Raw (Free) — ultima versione stabile
wget https://download.checkmk.com/checkmk/2.3.0p1/check-mk-raw-2.3.0p1-el8-38.x86_64.rpm

# Installa
sudo yum install -y check-mk-raw-2.3.0p1-el8-38.x86_64.rpm

# Crea un'istanza di monitoraggio (nome: oracledba)
sudo omd create oracledba

# Avvia l'istanza
sudo omd start oracledba

# Accedi alla web UI:
# http://<IP_SERVER>:5000/oracledba
# Username: cmkadmin
# Password: (mostrata dal comando omd create)


# ---- 2. INSTALLAZIONE AGENT (su OGNI server Oracle) ----

# Scarica l'agent dal server Checkmk:
wget http://<MONITORING_SERVER>:5000/oracledba/check_mk/agents/check-mk-agent-2.3.0-1.noarch.rpm

# Installa
sudo rpm -Uvh check-mk-agent-2.3.0-1.noarch.rpm

# Verifica che funziona
check_mk_agent | head -20


# ---- 3. ATTIVA IL PLUGIN ORACLE ----

# Copia il plugin Oracle sull'agent
sudo cp /opt/omd/versions/default/share/check_mk/agents/plugins/mk_oracle \
        /usr/lib/check_mk_agent/plugins/

# Crea la configurazione Oracle per l'agent
sudo mkdir -p /etc/check_mk
cat > /etc/check_mk/mk_oracle.cfg << 'EOF'
# Connessione al database Oracle
DBUSER=C##MONITOR:<MONITOR_DB_PASSWORD>:RACDB:localhost:1521
# Per ASM (opzionale):
# ASMUSER=ASMSNMP:<ASM_MONITOR_PASSWORD>

# Controlla tablespace, sessions, backup, alert log
SECTIONS="instance sessions logswitches undostat recovery_area processes
          tablespaces rman dataguard_stats performance"
EOF

# Imposta permessi
sudo chmod 600 /etc/check_mk/mk_oracle.cfg


# ---- 4. CREA L'UTENTE DI MONITORAGGIO NEL DB ----
# Esegui come SYS:
```

```sql
-- Crea utente dedicato al monitoraggio (read-only!)
CREATE USER C##MONITOR IDENTIFIED BY "<MONITOR_DB_PASSWORD>"
    DEFAULT TABLESPACE USERS
    QUOTA 0 ON USERS
    CONTAINER=ALL;

-- Grant MINIMI necessari (principio least-privilege)
GRANT CREATE SESSION TO C##MONITOR CONTAINER=ALL;
GRANT SELECT_CATALOG_ROLE TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$DATABASE TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$INSTANCE TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$SESSION TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$LOG TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$TABLESPACE TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$ARCHIVED_LOG TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$DATAGUARD_STATS TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$RMAN_BACKUP_JOB_DETAILS TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$ASM_DISKGROUP TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$RECOVERY_FILE_DEST TO C##MONITOR CONTAINER=ALL;
GRANT SELECT ON SYS.V_$DIAG_ALERT_EXT TO C##MONITOR CONTAINER=ALL;
```

```bash
# ---- 5. REGISTRA L'HOST IN CHECKMK ----

# Dalla Web UI:
# Setup → Hosts → Add host
# Hostname: rac1
# IP: 192.168.56.101
# Save → Run service discovery → Activate changes

# Ripeti per rac2, racstby1, racstby2, dnsnode
```

### Cosa Monitora Checkmk su Oracle (automaticamente)

| Check | Cosa Mostra | Alert Default |
|---|---|---|
| Tablespace Usage | % uso con maxsize | WARN 85%, CRIT 95% |
| Sessions | Attive, totali, bloccanti | CRIT se > max_sessions |
| RMAN Backup | Età ultimo backup | WARN > 24h, CRIT > 48h |
| Alert Log | ORA- errors nelle ultime 24h | WARN se presente |
| Data Guard Lag | Transport + Apply lag | WARN > 30min |
| ASM Diskgroup | % uso per diskgroup | WARN 85%, CRIT 95% |
| Processes | Uso vs max_processes | WARN 80%, CRIT 90% |

### Checkmk enterprise-ready (TLS + Agent Update + SMART/RAID)

> Runbook operativo dedicato: [15 Checkmk Agent TLS + SMART/RAID Troubleshooting](../../01_operations/02_runbooks_incidenti/RUNBOOK_15_CHECKMK_AGENT_TLS_SMART_RAID_TROUBLESHOOTING.md)

#### Obiettivo

Portare in produzione un onboarding Checkmk sicuro e ripetibile su host Linux Oracle, con:
- registrazione TLS dell'agent controller
- auto-update agent via HTTPS
- monitoraggio dischi SAS/RAID con SMART
- checklist di validazione e rollback.

#### Naming standard EDC (host/site/folder)

- `site`: `edc_<environment>` (es. `edc_lab`, `edc_prod`)
- `folder`: `/EDC/<ENVIRONMENT>/ORACLE` (es. `/EDC/LAB/ORACLE`)
- `host`: `edc-<environment>-<hostname>` (es. `edc-lab-rac1`)

#### Prerequisiti OS

```bash
sudo apt update
sudo apt install -y smartmontools lsscsi pciutils
```

> Sicurezza: ruota sempre credenziali/token prima dell'uso e non salvare password in chiaro in guide, ticket o shell history.

#### Procedura operativa

##### 1) Onboarding host e DNS/hosts (senza sovrascrivere `/etc/hosts`)

```bash
# Validare risoluzione (preferibile DNS)
getent hosts <CHECKMK_SERVER_FQDN> || true

# Solo se necessario, aggiungere entry in coda (mai usare ">" su /etc/hosts)
HOSTS_LINE="<CHECKMK_SERVER_IP> <CHECKMK_SERVER_FQDN> <CHECKMK_SERVER_ALIAS>"
grep -qxF "$HOSTS_LINE" /etc/hosts || echo "$HOSTS_LINE" | sudo tee -a /etc/hosts
grep -qxF "$HOSTS_LINE" /etc/hosts && echo "hosts entry OK" || { echo "hosts entry FAILED"; exit 1; }
```

##### 2) Installazione agent + registrazione TLS

```bash
# Esempio pacchetto scaricato dalla UI Checkmk (Agents)
sudo dpkg -i /home/<USER>/check-mk-agent_<VERSION>_all.deb

# Verifica certificati endpoint (443 consigliato; 8000 opzionale secondo setup sito)
openssl s_client -showcerts -connect <CHECKMK_SERVER_IP>:443 </dev/null 2>/dev/null | sed -n -e '/BEGIN CERTIFICATE/,/END CERTIFICATE/ p'

# Registrazione controller TLS (preferire automation user/token o secret manager)
sudo cmk-agent-ctl register \
  --server <CHECKMK_SERVER_FQDN> \
  --site <CHECKMK_SITE_ID> \
  --hostname "$(hostname -f)" \
  -U <AUTOMATION_USER> \
  -P '<AUTOMATION_SECRET>'
```

##### 3) Registrazione update agent + verifica

```bash
sudo cmk-update-agent register \
  -s <CHECKMK_SERVER_FQDN> \
  -i <CHECKMK_SITE_ID> \
  -H "$(hostname -f)" \
  -p https \
  -U <AUTOMATION_USER> \
  -P '<AUTOMATION_SECRET>' \
  -v

sudo cmk-update-agent -v
# Forza update check immediato dal server (se configurato)
sudo check_mk_agent -u
```

##### 4) Validazione finale

```bash
sudo systemctl status cmk-agent-ctl-daemon --no-pager
sudo systemctl status cmk-update-agent.timer --no-pager
check_mk_agent | head -20
sudo cmk-agent-ctl status
```

##### 5) Troubleshooting rapido

- `cmk-agent-ctl register` fallisce: verificare CN/SAN del certificato e risoluzione FQDN.
- `cmk-update-agent` non aggiorna: verificare registration status, proxy e accesso HTTPS al site.
- host senza servizi scoperti: rifare service discovery e activate changes dalla UI.

#### SAS + MegaRAID + SMART (casi reali)

Quando il server espone dischi SAS dietro controller (`megaraid_sas`), mappare sempre controller, device Linux e seriali.

```bash
sudo lspci | grep -i -E "raid|sas|scsi|storage"
lsblk -o NAME,HCTL,TYPE,SIZE,MODEL,SERIAL
sudo lsscsi -v
lsmod | grep -E 'megaraid|mpt3sas|mpt2sas|aacraid|hpsa|3w_9xxx|arcmsr|isci'
sudo smartctl -a /dev/sda
```

| Scenario | Metodo consigliato | Output atteso |
|---|---|---|
| Disco SAS visibile come `/dev/sdX` | `smartctl -a /dev/sdX` | SMART Health, temperatura, error counter, self-test |
| RAID controller presente + dischi non diretti | Plugin controller Checkmk + comandi vendor | Stato virtual drive, stato physical drive, predictive failure |
| Doppia visibilità (OS + controller) | Usare entrambe le fonti con naming coerente | Correlazione seriale/HCTL/controller slot |

**Check minimi obbligatori (disco fisico):**
- SMART Health Status
- temperatura corrente e soglia/trip
- error counter log (uncorrected/non-medium errors)
- età ultimo self-test + durata extended test.

---

## OPZIONE 2: Prometheus + Grafana (Dashboard Migliori)

### Architettura

```
+-----------------+     +------------------+     +--------------+
| Oracle DB Server |     | Prometheus Server |     |   Grafana    |
|                  |     |                  |     |              |
| +--------------+ |     | Scrape ogni 30s  |     | Dashboard    |
| | oracledb     |-+----&gt;| Salva metriche   |----&gt;| interattive  |
| | _exporter    | |     | Alert rules      |     | + alert      |
| | :9161        | |     | :9090            |     | :3000        |
| +--------------+ |     +------------------+     +--------------+
| +--------------+ |
| | node         |-+----&gt; (metriche OS: CPU, RAM, disco, rete)
| | _exporter    | |
| | :9100        | |
| +--------------+ |
+-----------------+
```

### Installazione Prometheus + Grafana

```bash
# ============================================================
# STEP 1: node_exporter (su OGNI server Oracle)
# Monitora: CPU, RAM, disco, rete, filesystem
# ============================================================

# Scarica
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# Crea servizio systemd
sudo cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nobody
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Verifica: http://<IP>:9100/metrics


# ============================================================
# STEP 2: oracle_exporter (su OGNI server Oracle)
# Monitora: tablespace, sessions, wait events, backup, DG
# ============================================================

# Usa l'exporter ufficiale:
# https://github.com/iamseth/oracledb_exporter
wget https://github.com/iamseth/oracledb_exporter/releases/latest/download/oracledb_exporter-linux-amd64.tar.gz
tar xzf oracledb_exporter-linux-amd64.tar.gz
sudo cp oracledb_exporter /usr/local/bin/

# Configura connessione Oracle
export DATA_SOURCE_NAME="C##MONITOR/<MONITOR_DB_PASSWORD>@//localhost:1521/RACDB"
# Oppure crea un file di env:
sudo cat > /etc/default/oracledb_exporter << 'EOF'
DATA_SOURCE_NAME=C##MONITOR/<MONITOR_DB_PASSWORD>@//localhost:1521/RACDB
EOF

# Crea servizio systemd
sudo cat > /etc/systemd/system/oracledb_exporter.service << 'EOF'
[Unit]
Description=Oracle DB Exporter
After=network.target

[Service]
User=oracle
EnvironmentFile=/etc/default/oracledb_exporter
ExecStart=/usr/local/bin/oracledb_exporter \
    --web.listen-address=:9161 \
    --default.metrics=/etc/oracledb_exporter/default-metrics.toml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now oracledb_exporter

# Verifica: http://<IP>:9161/metrics


# ============================================================
# STEP 3: Prometheus (sul monitoring server)
# ============================================================

cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.50.0/prometheus-2.50.0.linux-amd64.tar.gz
tar xzf prometheus-2.50.0.linux-amd64.tar.gz
sudo cp prometheus-2.50.0.linux-amd64/{prometheus,promtool} /usr/local/bin/
sudo mkdir -p /etc/prometheus /var/lib/prometheus

# Configurazione: chi monitorare
sudo cat > /etc/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 30s
  evaluation_interval: 30s

# Regole di alert
rule_files:
  - "oracle_alerts.yml"

scrape_configs:
  # OS Metrics (tutti i server)
  - job_name: 'node'
    static_configs:
      - targets:
        - 'rac1:9100'
        - 'rac2:9100'
        - 'racstby1:9100'
        - 'racstby2:9100'
        - 'dnsnode:9100'

  # Oracle DB Metrics
  - job_name: 'oracle'
    static_configs:
      - targets:
        - 'rac1:9161'
        - 'rac2:9161'
        - 'racstby1:9161'
        - 'racstby2:9161'
    labels:
      env: 'lab'
EOF

# Alert rules per Oracle
sudo cat > /etc/prometheus/oracle_alerts.yml << 'EOF'
groups:
  - name: oracle_alerts
    rules:
      - alert: OracleTablespaceFull
        expr: oracledb_tablespace_used_percent > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Tablespace {{ $labels.tablespace }} al {{ $value }}%"

      - alert: OracleBackupOld
        expr: (time() - oracledb_last_backup_timestamp) > 86400
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "Nessun backup nelle ultime 24h!"

      - alert: HighCPU
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "CPU al {{ $value }}% su {{ $labels.instance }}"

      - alert: DiskFull
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 15
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disco < 15% libero su {{ $labels.mountpoint }}"
EOF

# Servizio systemd
sudo cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --storage.tsdb.retention.time=90d
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo useradd -rs /bin/false prometheus
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus

# Verifica: http://<IP>:9090


# ============================================================
# STEP 4: Grafana (sul monitoring server)
# ============================================================

# Aggiungi repository Grafana
sudo cat > /etc/yum.repos.d/grafana.repo << 'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

sudo yum install -y grafana
sudo systemctl enable --now grafana-server

# Accedi: http://<IP>:3000
# Username: admin / Password: admin (cambiarla subito!)

# Configura Prometheus come Data Source:
# Configuration → Data Sources → Add → Prometheus
# URL: http://localhost:9090 → Save & Test
```

### Dashboard Grafana Consigliate

Importa queste dashboard già pronte dalla community (Dashboard → Import → ID):

| ID | Dashboard | Cosa Mostra |
|---|---|---|
| **1860** | Node Exporter Full | CPU, RAM, disco, rete, I/O per host |
| **3333** | Oracle DB Overview | Sessioni, tablespace, wait events |
| **14175** | Oracle Performance | Buffer cache, redo, undo, temp |

---

## OPZIONE 3: Zabbix (per ambienti grandi)

### Installazione Rapida

```bash
# ---- SERVER ----
# Zabbix 7.0 LTS su Oracle Linux 8
sudo rpm -Uvh https://repo.zabbix.com/zabbix/7.0/oracle/8/x86_64/zabbix-release-7.0-1.el8.noarch.rpm
sudo dnf install -y zabbix-server-pgsql zabbix-web-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent

# Crea DB PostgreSQL per Zabbix
sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix

# Configura e avvia
sudo systemctl enable --now zabbix-server zabbix-agent nginx php-fpm
# Web UI: http://<IP>/zabbix

# ---- AGENT (su ogni server Oracle) ----
sudo rpm -Uvh https://repo.zabbix.com/zabbix/7.0/oracle/8/x86_64/zabbix-release-7.0-1.el8.noarch.rpm
sudo dnf install -y zabbix-agent2 zabbix-agent2-plugin-oracle-database
sudo systemctl enable --now zabbix-agent2
```

### Template Oracle per Zabbix

Zabbix 7.0 include un **template nativo** per Oracle:
1. Web UI → Configuration → Templates → "Oracle by ODBC"
2. Applica al tuo host
3. Configura le macro: `{$ORACLE.DSN}`, `{$ORACLE.USER}`, `{$ORACLE.PASSWORD}`

---

## Best Practice Comuni (Tutti i Tool)

### 1. Utente Monitoraggio Dedicato

```sql
-- SEMPRE creare un utente read-only dedicato. MAI usare SYS o SYSTEM!
CREATE USER C##MONITOR IDENTIFIED BY "<MONITOR_DB_PASSWORD>"
    DEFAULT TABLESPACE USERS QUOTA 0 ON USERS CONTAINER=ALL;
GRANT CREATE SESSION TO C##MONITOR CONTAINER=ALL;
GRANT SELECT_CATALOG_ROLE TO C##MONITOR CONTAINER=ALL;
```

### 2. Cosa Monitorare (Checklist)

| Layer | Metriche | Alert |
|---|---|---|
| **OS** | CPU, RAM, swap, disco, I/O, rete | CPU >90%, disco <15%, swap >50% |
| **Database** | Sessioni, tablespace, buffer cache | TBS >85%, backup >24h, invalids |
| **Data Guard** | Transport lag, apply lag, GAP | Lag >30min, GAP presente |
| **ASM** | Diskgroup usage, rebalance | DG >85% |
| **Alert Log** | ORA- errors, WARNING | Qualsiasi ORA- critico |
| **Backup** | Ultimo backup, validate | >24h senza backup |
| **Listener** | Stato, connessioni reject | Listener down |

### 3. Frequenza di Controllo

| Metriche | Intervallo | Note |
|---|---|---|
| CPU, RAM, rete | 30 secondi | Real-time |
| Tablespace, sessioni | 5 minuti | Non troppo frequente |
| Backup, Data Guard | 15 minuti | |
| Alert log | 5 minuti | Cerca pattern ORA- |
| Capacity trend | 1 ora | Per grafici storici |

### 4. Alert: NON Esagerare!

> ⚠️ **Alert fatigue** è il nemico #1. Se ricevi 100 alert al giorno, finirai per ignorarli tutti.
>
> Regola d'oro: **Se un alert non richiede un'azione immediata, NON è un alert — è un log.**
>
> - **CRITICAL** = Qualcuno deve agire ADESSO (svegliare il reperibile)
> - **WARNING** = Da gestire domani mattina
> - **INFO** = Solo dashboard, niente notifiche

---

## Riepilogo: Quale Scegliere

```
Hai 1-10 server Oracle?                    → Checkmk (setup in 1 ora)
Hai 50+ server, ambiente enterprise?       → Zabbix (investimento iniziale alto, poi scala)
Hai Kubernetes/Docker/DevOps?              → Prometheus + Grafana
Vuoi dashboard belle + alert affidabili?   → Prometheus + Grafana (dashboard) + Checkmk (alert)
```
