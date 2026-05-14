# RUNBOOK ENTERPRISE: ORACLE 26AI SU PODMAN/DOCKER

> **Document Classification:** ENTERPRISE OPERATIONS  
> **Last Updated:** Maggio 2026  
> **Target Audience:** Senior DBA, DevOps Engineers, SREs  
> **Prerequisiti:** Conoscenza base di Linux, networking TCP/IP, Oracle Database

## SOMMARIO
1. [Architettura e Scelta del Runtime](#1-architettura-e-scelta-del-runtime-container)
2. [Prerequisiti Hardware e Software](#2-prerequisiti-hardware-e-software)
3. [Autenticazione al Container Registry](#3-autenticazione-al-container-registry-oracle)
4. [Kernel Tuning e Sicurezza SELinux](#4-kernel-tuning-e-sicurezza-selinux)
5. [Deployment con Docker Compose](#5-deployment-con-docker-compose)
6. [Bootstrap Automatico e Provisioning Schemi](#6-bootstrap-automatico-e-provisioning-schemi)
7. [Connessione e Validazione](#7-connessione-e-validazione)
8. [Operazioni di Manutenzione](#8-operazioni-di-manutenzione)
9. [Backup e Restore del Container](#9-backup-e-restore-del-container)
10. [Networking Avanzato e Multi-Container](#10-networking-avanzato-e-multi-container)
11. [Monitoraggio e Alerting](#11-monitoraggio-e-alerting)
12. [Troubleshooting Enciclopedico](#12-troubleshooting-enciclopedico)
13. [Integrazione CI/CD](#13-integrazione-cicd)

---

## 1. Architettura e Scelta del Runtime Container

### 1.1. Docker vs Podman: Analisi Comparativa Enterprise

| Criterio | Docker CE | Podman |
|---|---|---|
| **Demone** | Richiede `dockerd` (root daemon) | Daemonless (nessun processo persistente root) |
| **Sicurezza** | Privilege escalation possibile | Rootless by design, compatible con SELinux |
| **Compatibilità CLI** | Nativa | 100% drop-in (`alias docker=podman`) |
| **Compose** | `docker compose` (plugin V2) | `podman-compose` (Python) o `podman compose` |
| **Certificazione Oracle** | Supportata per dev/test | Supportata e raccomandata da Red Hat/Oracle |
| **Systemd Integration** | Limitata | Nativa (`podman generate systemd`) |

In contesti Enterprise (Red Hat Enterprise Linux, Oracle Linux), il demone Docker in esecuzione come root rappresenta un rischio critico di sicurezza. Un container compromesso potrebbe fare privilege escalation fino al livello host.

**Lo standard di settore è Podman**, che esegue i container in modalità rootless senza alcun demone privilegiato persistente. L'immagine ufficiale Oracle 26ai Free è certificata per girare rootless.

### 1.2. Architettura Interna del Container Oracle

L'immagine `container-registry.oracle.com/database/free:latest` contiene:
- **Oracle Linux 8** (base layer)
- **Oracle Database 26ai Free** (binari preinstallati in `/opt/oracle/product/26c/dbhomeFree`)
- **Entrypoint Script** (`/opt/oracle/runOracle.sh`): Orchestra la creazione del database al primo avvio e il semplice startup ai boot successivi
- **Utente interno**: `oracle` (UID `54321`, GID `54321`)
- **Listener**: Preconfigurato sulla porta `1521`
- **EM Express**: Preconfigurato sulla porta `5500` (HTTPS)

Il flusso di avvio è:
```
Container Start → runOracle.sh → [Primo avvio?]
    ├── SÌ → createDB.sh → dbca -silent → listener start → "DATABASE IS READY"
    └── NO → startDB.sh → sqlplus STARTUP → listener start → "DATABASE IS READY"
```

---

## 2. Prerequisiti Hardware e Software

### 2.1. Requisiti Minimi Host

| Risorsa | Minimo | Raccomandato (Lab Enterprise) |
|---|---|---|
| **CPU** | 2 core | 4+ core |
| **RAM** | 4 GB liberi | 8 GB+ |
| **Disco** | 15 GB | 50 GB+ (SSD/NVMe) |
| **OS Host** | Oracle Linux 8+, RHEL 8+, Ubuntu 22.04+ | Oracle Linux 8.9+ |

### 2.2. Installazione del Runtime

**Oracle Linux / RHEL (Podman — raccomandato):**
```bash
# Podman è preinstallato su OEL 8+, ma aggiorniamolo
sudo dnf install -y podman podman-compose
podman --version
# Output atteso: podman version 4.x.x
```

**Ubuntu / Debian (Docker):**
```bash
# Rimuovere vecchie installazioni
sudo apt-get remove -y docker docker-engine docker.io containerd runc
# Installare Docker CE
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
docker --version
# Output atteso: Docker version 26.x.x
```

**Windows / macOS (Docker Desktop):**
Scaricare Docker Desktop da <https://www.docker.com/products/docker-desktop/>.
Impostare nelle Settings → Resources → Memory: **minimo 4 GB** (ideale 8 GB).

### 2.3. Verifica della Configurazione cgroup
Oracle richiede cgroup v2 per il corretto funzionamento della memoria condivisa:
```bash
stat -fc %T /sys/fs/cgroup/
# Output atteso: cgroup2fs
```
Se l'output è `tmpfs` (cgroup v1), aggiungere al GRUB:
```bash
sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"
sudo reboot
```

---

## 3. Autenticazione al Container Registry Oracle

L'immagine Oracle Database è ospitata nel **Oracle Container Registry (OCR)**, che richiede accettazione della licenza.

### 3.1. Accettazione Licenza (Una Tantum)
1. Navigare a <https://container-registry.oracle.com/>
2. Fare login con il proprio Oracle Account (gratuito).
3. Cercare `database/free` nel catalogo.
4. Cliccare sul repository e accettare la **Oracle Standard Terms and Restrictions**.

### 3.2. Login da CLI
```bash
# Docker
docker login container-registry.oracle.com
# Username: il tuo Oracle Account email
# Password: la tua password Oracle Account

# Podman
podman login container-registry.oracle.com
```

### 3.3. Pull dell'Immagine
```bash
podman pull container-registry.oracle.com/database/free:latest
```
*Tempo stimato: 5-15 minuti (immagine ~3.5 GB compressa).*

Verifica:
```bash
podman images | grep oracle
# Output atteso:
# container-registry.oracle.com/database/free   latest   abc123def456   2 weeks ago   8.72 GB
```

---

## 4. Kernel Tuning e Sicurezza SELinux

### 4.1. Il Problema Critico: `/dev/shm` e ORA-00845
Oracle Database utilizza estensivamente la **System Global Area (SGA)** tramite la memoria condivisa del kernel (`/dev/shm`).
I container Docker/Podman allocano di default solo **64 MB** a questa partizione.
Se l'SGA di Oracle supera questo limite (e lo supera SEMPRE, anche nella Free Edition), l'istanza va in crash con:
```
ORA-00845: MEMORY_TARGET not supported on this system
```

**Soluzione:** Impostare `shm_size: '2gb'` nel file Compose (o `--shm-size=2g` da CLI).

### 4.2. Il Flagello di SELinux: "Permission Denied" sui Volumi

Quando si monta un volume host in un container su una macchina con SELinux attivo (Oracle Linux, RHEL), il container **non può scrivere** nella directory host, anche se i permessi Unix (`chmod 777`) sembrano corretti.

Questo accade perché SELinux assegna un *contesto di sicurezza* differente al processo del container rispetto alla directory host. Il kernel blocca l'accesso a livello MAC (Mandatory Access Control), prima ancora di controllare i permessi DAC (chmod).

**Diagnosi:**
```bash
# Verificare se SELinux è attivo
getenforce
# Output: Enforcing  <-- SE questo è "Enforcing", DEVI gestire i contesti

# Controllare i log di audit per capire cosa è stato bloccato
sudo ausearch -m avc -ts recent | grep oracle
```

**Soluzione (nel Compose):**
Aggiungere il suffisso `:Z` (condivisione privata esclusiva per questo container) ai volumi:
```yaml
volumes:
  - /u01/docker_data/oradata:/opt/oracle/oradata:Z
```

**MAI disabilitare SELinux** (`setenforce 0`). È una violazione di sicurezza gravissima in ambiente Enterprise.

### 4.3. Configurazione dell'Ownership dei Volumi
L'utente all'interno del container Oracle è `oracle` con UID/GID `54321`.
La directory host che viene montata deve appartenere a quell'utente:
```bash
sudo mkdir -p /u01/docker_data/oracle_26ai/{oradata,scripts/startup,scripts/setup}
sudo chown -R 54321:54321 /u01/docker_data/oracle_26ai
sudo chmod -R 750 /u01/docker_data/oracle_26ai
```
*Se salti questo step, il container uscirà con `Exited (1)` immediatamente senza produrre alcun log utile.*

---

## 5. Deployment con Docker Compose

### 5.1. Il File docker-compose.yml Completo e Commentato

Crea la directory di lavoro e salva il seguente file:
```bash
mkdir -p ~/oracle-26ai-lab && cd ~/oracle-26ai-lab
```

`docker-compose.yml`:
```yaml
version: '3.8'

services:
  oracle26ai:
    image: container-registry.oracle.com/database/free:latest
    container_name: oracle26ai_ent_dev

    # ===== KERNEL TUNING =====
    # OBBLIGATORIO: Alloca 2GB di memoria condivisa per SGA/PGA.
    # Senza questo parametro, Oracle crasherà con ORA-00845.
    shm_size: '2gb'

    # ===== VARIABILI D'AMBIENTE =====
    environment:
      # Password per SYS, SYSTEM e PDBADMIN. Sarà impostata solo al PRIMO avvio.
      - ORACLE_PWD=EnterpriseSuperSecure_2026!
      # SID del Container Database (CDB)
      - ORACLE_SID=FREE
      # Abilita l'archivelog mode per simulare scenari di backup/recovery
      - ENABLE_ARCHIVELOG=true

    # ===== PORTE =====
    ports:
      # Oracle Listener (SQL*Net)
      - "1521:1521"
      # Enterprise Manager Express (interfaccia web HTTPS)
      - "5500:5500"

    # ===== VOLUMI (PERSISTENZA DATI) =====
    volumes:
      # Volume principale: Datafile, Controlfile, Redo Log
      # Il suffisso :Z è OBBLIGATORIO su sistemi con SELinux attivo (OEL/RHEL)
      - /u01/docker_data/oracle_26ai/oradata:/opt/oracle/oradata:Z
      # Script eseguiti UNA VOLTA alla creazione iniziale del DB (setup schema)
      - /u01/docker_data/oracle_26ai/scripts/setup:/opt/oracle/scripts/setup:Z
      # Script eseguiti ad OGNI avvio del container (manutenzione ricorrente)
      - /u01/docker_data/oracle_26ai/scripts/startup:/opt/oracle/scripts/startup:Z

    # ===== POLICY DI RIAVVIO =====
    # Il container si riavvia automaticamente dopo un crash o un reboot host.
    # NON si riavvia se fermato manualmente con `docker stop`.
    restart: unless-stopped

    # ===== HEALTHCHECK =====
    # Verifica lo stato reale del database interrogando il processo PMON di Oracle.
    healthcheck:
      test: ["CMD-SHELL", "ps -ef | grep pmon | grep -v grep || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 300s  # Attende 5 minuti prima di iniziare i check (primo boot lento)
```

### 5.2. Avvio del Container
```bash
# Con Docker
docker compose up -d

# Con Podman
podman-compose up -d
```

### 5.3. Monitoraggio del Primo Avvio
Il primo boot crea il database da zero e può richiedere **dai 5 ai 15 minuti**.
```bash
podman logs -f oracle26ai_ent_dev
```

*Output tipico durante l'inizializzazione:*
```text
ORACLE EDITION: FREE
ORACLE PASSWORD FOR SYS, SYSTEM AND PDBADMIN: ****
LSNRCTL for Linux: Version 26.0.0.0.0 - Production
...
Completing Database Creation
...
Pluggable database FREEPDB1 opened with restricted access.
...
#########################
DATABASE IS READY TO USE!
#########################
```

**Attendere SEMPRE il messaggio `DATABASE IS READY TO USE` prima di tentare qualsiasi connessione.**

---

## 6. Bootstrap Automatico e Provisioning Schemi

### 6.1. Differenza tra `setup/` e `startup/`
L'immagine Oracle supporta due hook di automazione:

| Directory Host | Directory Container | Quando Esegue |
|---|---|---|
| `.../scripts/setup/` | `/opt/oracle/scripts/setup/` | **Solo al primo avvio** (creazione DB) |
| `.../scripts/startup/` | `/opt/oracle/scripts/startup/` | **Ad ogni avvio** del container |

Gli script vengono eseguiti in ordine alfabetico. Supportano `.sql` e `.sh`.

### 6.2. Esempio: Creazione Automatica Schema Applicativo

Crea il file `/u01/docker_data/oracle_26ai/scripts/setup/01_create_app_schema.sql`:
```sql
-- ============================================================
-- BOOTSTRAP: Creazione schema applicativo "CORE_APP" su FREEPDB1
-- Eseguito automaticamente al primo avvio del container
-- ============================================================

-- Connettersi al PDB applicativo
ALTER SESSION SET CONTAINER = FREEPDB1;

-- Creare il tablespace dedicato
CREATE TABLESPACE ts_core_app
    DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/ts_core_app01.dbf'
    SIZE 500M AUTOEXTEND ON NEXT 100M MAXSIZE 5G;

-- Creare l'utente applicativo
CREATE USER core_app IDENTIFIED BY "CoreApp_Enterprise_2026"
    DEFAULT TABLESPACE ts_core_app
    TEMPORARY TABLESPACE temp
    QUOTA UNLIMITED ON ts_core_app;

-- Assegnare i privilegi (principio del minimo privilegio)
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER TO core_app;

-- Tabella di esempio con la nuova feature 26ai: VECTOR type
CREATE TABLE core_app.documenti (
    doc_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    titolo    VARCHAR2(500) NOT NULL,
    contenuto CLOB,
    embedding VECTOR(1536, FLOAT32),
    creato_il TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Indice vettoriale per Approximate Nearest Neighbor search
CREATE VECTOR INDEX idx_doc_embedding ON core_app.documenti(embedding)
    ORGANIZATION NEIGHBOR PARTITIONS
    WITH DISTANCE COSINE;
```

### 6.3. Esempio: Script di Startup Ricorrente (Health Check)

Crea il file `/u01/docker_data/oracle_26ai/scripts/startup/99_health_log.sh`:
```bash
#!/bin/bash
# Scrive un record nel syslog Oracle ad ogni riavvio del container
sqlplus -s / as sysdba <<EOF
SET SERVEROUTPUT ON
BEGIN
    DBMS_SYSTEM.KSDWRT(2, 'CONTAINER STARTUP: Health check OK at ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
END;
/
-- Verifica stato PDB
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN READ WRITE;
SELECT name, open_mode FROM v\$pdbs;
EXIT;
EOF
```

---

## 7. Connessione e Validazione

### 7.1. Connessione da Shell Interna (sqlplus)
```bash
# Connessione come SYSDBA al CDB root
podman exec -it oracle26ai_ent_dev sqlplus / as sysdba

# Connessione come SYSTEM al PDB applicativo
podman exec -it oracle26ai_ent_dev sqlplus system/EnterpriseSuperSecure_2026!@FREEPDB1
```

### 7.2. Connessione Esterna (SQL Developer, DBeaver, SQLcl)
Parametri:
- **Host**: `localhost` (o l'IP del server Docker)
- **Port**: `1521`
- **Service Name**: `FREEPDB1`
- **Username**: `SYSTEM` (o `core_app` se hai usato il bootstrap)
- **Password**: quella definita in `ORACLE_PWD`

### 7.3. Connessione con stringa Easy Connect
```bash
sqlcl system/EnterpriseSuperSecure_2026!@localhost:1521/FREEPDB1
```

### 7.4. Validazione della Versione 26ai
```sql
SELECT banner_full FROM v$version;
```
*Output Atteso:*
```text
Oracle Database 26ai Free Release 26.0.0.0.0 - Production
```

### 7.5. Test delle Feature Esclusive 26ai
```sql
-- Test AI Vector Search
SELECT doc_id, titolo
FROM core_app.documenti
ORDER BY VECTOR_DISTANCE(embedding, VECTOR('[0.1, 0.2, ...]', 1536, FLOAT32), COSINE)
FETCH FIRST 5 ROWS ONLY;

-- Test JSON Relational Duality View
CREATE JSON RELATIONAL DUALITY VIEW doc_dv AS
    SELECT JSON {'docId': d.doc_id, 'titolo': d.titolo, 'creato': d.creato_il}
    FROM core_app.documenti d WITH INSERT UPDATE DELETE;
```

---

## 8. Operazioni di Manutenzione

### 8.1. Stop e Start del Container
```bash
# Stop (il database fa shutdown immediate internamente)
podman stop oracle26ai_ent_dev

# Start (il database fa startup internamente)
podman start oracle26ai_ent_dev
```

### 8.2. Restart con Rebuild
Se devi cambiare variabili d'ambiente o volumi:
```bash
podman compose down
# Modifica il docker-compose.yml
podman-compose up -d
```
**I dati persistono** perché risiedono nel volume host `/u01/docker_data/oracle_26ai/oradata`.

### 8.3. Accesso alla Shell del Container
```bash
podman exec -it oracle26ai_ent_dev bash
# Ora sei dentro come utente "oracle"
echo $ORACLE_HOME
# /opt/oracle/product/26c/dbhomeFree
```

### 8.4. Cambio Password Post-Deploy
```bash
podman exec -it oracle26ai_ent_dev ./setPassword.sh NuovaPassword_2026!
```

---

## 9. Backup e Restore del Container

### 9.1. Export del Volume (Backup a Freddo)
```bash
podman stop oracle26ai_ent_dev
sudo tar czf /backup/oracle26ai_oradata_$(date +%Y%m%d).tar.gz \
    -C /u01/docker_data/oracle_26ai/oradata .
podman start oracle26ai_ent_dev
```

### 9.2. RMAN dentro il Container (Backup a Caldo)
```bash
podman exec -it oracle26ai_ent_dev bash -c "rman target /" <<'EOF'
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
BACKUP AS COMPRESSED BACKUPSET DATABASE PLUS ARCHIVELOG;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT OBSOLETE;
EOF
```

### 9.3. Commit dell'Immagine (Snapshot)
Per salvare lo stato completo del container come nuova immagine (utile per clonare ambienti di test):
```bash
podman stop oracle26ai_ent_dev
podman commit oracle26ai_ent_dev oracle26ai_snapshot:$(date +%Y%m%d)
podman start oracle26ai_ent_dev
```

---

## 10. Networking Avanzato e Multi-Container

### 10.1. Rete Dedicata Bridge
Per isolare il traffico Oracle dal resto dei container:
```bash
podman network create oracle_net
```
Aggiungi al `docker-compose.yml`:
```yaml
networks:
  default:
    name: oracle_net
    external: true
```

### 10.2. Setup Multi-PDB (Simulazione Multi-Tenant)
Dopo il primo avvio, puoi creare PDB aggiuntivi:
```sql
CREATE PLUGGABLE DATABASE pdb_test ADMIN USER pdb_admin IDENTIFIED BY "PdbAdmin_2026"
    FILE_NAME_CONVERT=('/opt/oracle/oradata/FREE/pdbseed/','/opt/oracle/oradata/FREE/pdb_test/');
ALTER PLUGGABLE DATABASE pdb_test OPEN;
ALTER PLUGGABLE DATABASE pdb_test SAVE STATE;
```

---

## 11. Monitoraggio e Alerting

### 11.1. Enterprise Manager Express (Integrato)
Oracle EM Express è preconfigurato sulla porta `5500`. Accedervi da browser:
```
https://localhost:5500/em
```
Credenziali: `SYS` / la password impostata in `ORACLE_PWD`.

### 11.2. Monitoraggio con Prometheus/Grafana
Per ambienti Enterprise con stack di osservabilità centralizzato, aggiungere un container `oracledb-exporter`:
```yaml
  oracledb_exporter:
    image: ghcr.io/iamseth/oracledb_exporter:latest
    container_name: oracle_exporter
    environment:
      - DATA_SOURCE_NAME=system/EnterpriseSuperSecure_2026!@oracle26ai_ent_dev:1521/FREEPDB1
    ports:
      - "9161:9161"
    depends_on:
      oracle26ai:
        condition: service_healthy
```

---

## 12. Troubleshooting Enciclopedico

### 12.1. Container esce con `Exited (1)` senza log
**Causa**: Permessi errati sul volume host o SELinux che blocca.
**Soluzione**:
```bash
sudo chown -R 54321:54321 /u01/docker_data/oracle_26ai/oradata
# Se SELinux attivo:
sudo chcon -Rt svirt_sandbox_file_t /u01/docker_data/oracle_26ai/oradata
```

### 12.2. ORA-00845: MEMORY_TARGET not supported
**Causa**: `shm_size` non impostato o troppo piccolo.
**Soluzione**: Aggiungere `shm_size: '2gb'` al compose e ricreare il container.

### 12.3. TNS-12541: TNS:no listener
**Causa**: Il database non ha ancora completato l'inizializzazione.
**Soluzione**: Attendere il messaggio `DATABASE IS READY TO USE` nei log.

### 12.4. ORA-65096: invalid common user or role name
**Causa**: Stai creando un utente nel CDB root senza il prefisso `C##`.
**Soluzione**: Connettersi al PDB (`ALTER SESSION SET CONTAINER=FREEPDB1`) prima di creare utenti applicativi.

### 12.5. Spazio disco esaurito nel container
```bash
podman exec -it oracle26ai_ent_dev bash -c "df -h /opt/oracle/oradata"
```
Se lo spazio è insufficiente, espandere il volume host o pulire gli archivelog:
```sql
-- Dentro sqlplus
DELETE ARCHIVELOG ALL COMPLETED BEFORE 'SYSDATE-3';
```

---

## 13. Integrazione CI/CD

### 13.1. GitHub Actions: Database Effimero per Test
```yaml
name: Integration Tests with Oracle 26ai
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      oracle:
        image: container-registry.oracle.com/database/free:latest
        env:
          ORACLE_PWD: TestPassword123
        ports:
          - 1521:1521
        options: --shm-size=2g --health-cmd="ps -ef | grep pmon | grep -v grep"
                 --health-interval=30s --health-timeout=10s --health-retries=20
                 --health-start-period=300s
    steps:
      - uses: actions/checkout@v4
      - name: Wait for Oracle to be ready
        run: |
          for i in $(seq 1 60); do
            if docker exec ${{ job.services.oracle.id }} sqlplus -s system/TestPassword123@FREEPDB1 <<< "SELECT 1 FROM DUAL;" 2>/dev/null | grep -q "1"; then
              echo "Oracle is ready!"
              break
            fi
            echo "Waiting for Oracle... ($i/60)"
            sleep 10
          done
      - name: Run SQL tests
        run: |
          docker exec ${{ job.services.oracle.id }} sqlplus -s system/TestPassword123@FREEPDB1 @tests/schema_test.sql
```
