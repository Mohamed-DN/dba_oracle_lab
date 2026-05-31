# Cheat Sheet SRVCTL & CRSCTL — Enterprise Completo ⚙️

> [!NOTE]
> **DOCUMENTI CORRELATI:**
> - **Guida Servizi Applicativi RAC**: [GUIDA_SERVIZI_APPLICATIVI_RAC.md](../../02_core_dba/01_administration_and_security/GUIDA_SERVIZI_APPLICATIVI_RAC.md)
> - **Guida Start/Stop RAC**: [RUNBOOK_10_START_STOP_RAC.md](../02_runbooks_incidenti/RUNBOOK_10_START_STOP_RAC.md)
> - **Guida Lab (Fase 2)**: [GUIDA_FASE2_GRID_E_RAC.md](../../03_infra_lab/02_oracle_installation_asm/GUIDA_FASE2_GRID_E_RAC.md)
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md)

---

## 1. CRSCTL — Gestione Clusterware

### 1.1 Status del Cluster
```bash
# Status globale del cluster (tutti i nodi)
crsctl stat res -t

# Status esteso (include target, state, server)
crsctl stat res -t -init

# Check del cluster health
crsctl check cluster
crsctl check cluster -all    # tutti i nodi

# Check CRS (Cluster Ready Services)
crsctl check crs

# Check specifico per componente
crsctl check css    # Cluster Synchronization Services
crsctl check evm    # Event Manager
crsctl check has    # High Availability Services (single node)
```

### 1.2 Start / Stop del Cluster
```bash
# Stop cluster su questo nodo (come root)
crsctl stop cluster

# Stop cluster su tutti i nodi
crsctl stop cluster -all

# Start cluster su questo nodo
crsctl start cluster

# Start cluster su tutti i nodi
crsctl start cluster -all

# Stop/Start CRS (più profondo, include OHASD)
crsctl stop crs
crsctl start crs

# Force stop (emergenza!)
crsctl stop crs -f
crsctl stop cluster -f
```

### 1.3 Abilitare/Disabilitare Auto-Start
```bash
# Abilitare auto-start del CRS al boot
crsctl enable crs

# Disabilitare auto-start (per manutenzione)
crsctl disable crs

# Verificare
crsctl config crs
```

### 1.4 Diagnostica Clusterware
```bash
# Versione del Clusterware
crsctl query crs activeversion
crsctl query crs softwareversion

# Stato dei nodi
olsnodes -n -i -s -t
# -n: node name, -i: VIP, -s: status, -t: type

# Stato CSS voting disk
crsctl query css votedisk

# Stato OCR (Oracle Cluster Registry)
ocrcheck
ocrcheck -local
ocrconfig -showbackup

# Backup manuale dell'OCR
ocrconfig -manualbackup

# Restore OCR (emergenza!)
ocrconfig -restore /u01/app/grid/cdata/backup_ocr.ocr
```

### 1.5 Gestione Risorse Custom
```bash
# Registrare una risorsa custom
crsctl add resource my_app_resource \
  -type local_resource \
  -attr "ACTION_SCRIPT=/scripts/my_app.sh, CHECK_INTERVAL=60"

# Start/Stop risorsa
crsctl start resource my_app_resource
crsctl stop resource my_app_resource

# Rimuovere risorsa
crsctl delete resource my_app_resource

# Relocare risorsa
crsctl relocate resource my_app_resource -n node2
```

---

## 2. SRVCTL — Gestione Database RAC

### 2.1 Status e Configurazione Database
```bash
# Status database
srvctl status database -d RACDB

# Configurazione completa
srvctl config database -d RACDB

# Lista tutti i database registrati
srvctl config database

# Dettagli
srvctl config database -d RACDB -a    # con dettagli avanzati
```

### 2.2 Start / Stop Database
```bash
# Start database (tutte le istanze)
srvctl start database -d RACDB

# Start con opzioni
srvctl start database -d RACDB -o mount
srvctl start database -d RACDB -o "read only"
srvctl start database -d RACDB -o restrict

# Stop database
srvctl stop database -d RACDB
srvctl stop database -d RACDB -o immediate
srvctl stop database -d RACDB -o abort      # emergenza!
srvctl stop database -d RACDB -o transactional
```

### 2.3 Start / Stop Istanza Singola
```bash
# Start una sola istanza
srvctl start instance -d RACDB -i RACDB1

# Stop una sola istanza (le sessioni migrano se configurato TAF/AC)
srvctl stop instance -d RACDB -i RACDB1
srvctl stop instance -d RACDB -i RACDB1 -o immediate

# Relocare istanze (per manutenzione nodo)
srvctl relocate database -d RACDB -c "rac1" -n "rac2"
```

### 2.4 Abilitare/Disabilitare Auto-Start DB
```bash
# Abilitare l'avvio automatico
srvctl enable database -d RACDB
srvctl enable instance -d RACDB -i RACDB1

# Disabilitare (per patching/manutenzione)
srvctl disable database -d RACDB
srvctl disable instance -d RACDB -i RACDB1

# Verificare policy
srvctl config database -d RACDB | grep -i "start\|policy\|enabled"
```

---

## 3. SRVCTL — Gestione Servizi Applicativi

### 3.1 Creare Servizi
```bash
# Servizio con preferred/available (HA)
srvctl add service -d RACDB -s APP_SVC \
  -preferred RACDB1 -available RACDB2 \
  -policy AUTOMATIC \
  -failovertype SELECT \
  -failovermethod BASIC \
  -failoverretry 30 \
  -failoverdelay 5

# Servizio per Application Continuity (AC)
srvctl add service -d RACDB -s APP_AC_SVC \
  -preferred RACDB1,RACDB2 \
  -policy AUTOMATIC \
  -failovertype TRANSACTION \
  -commit_outcome TRUE \
  -replay_init_time 1800 \
  -retention 86400 \
  -drain_timeout 60

# Servizio read-only (per Active Data Guard)
srvctl add service -d RACDB -s REPORT_SVC \
  -preferred RACDB1,RACDB2 \
  -role PHYSICAL_STANDBY \
  -policy AUTOMATIC
```

### 3.2 Operazioni sui Servizi
```bash
# Status
srvctl status service -d RACDB
srvctl status service -d RACDB -s APP_SVC

# Config
srvctl config service -d RACDB
srvctl config service -d RACDB -s APP_SVC

# Start / Stop
srvctl start service -d RACDB -s APP_SVC
srvctl stop service -d RACDB -s APP_SVC

# Stop con drain (zero downtime)
srvctl stop service -d RACDB -s APP_SVC -drain_timeout 120

# Relocare servizio su un altro nodo
srvctl relocate service -d RACDB -s APP_SVC \
  -oldinst RACDB1 -newinst RACDB2

# Modificare servizio
srvctl modify service -d RACDB -s APP_SVC \
  -preferred RACDB2 -available RACDB1

# Rimuovere servizio
srvctl remove service -d RACDB -s APP_SVC
```

---

## 4. SRVCTL — Listener e SCAN

### 4.1 Listener Locale
```bash
# Status listener
srvctl status listener
srvctl status listener -l LISTENER

# Config
srvctl config listener
srvctl config listener -a   # con dettagli

# Start / Stop
srvctl start listener
srvctl stop listener
```

### 4.2 SCAN Listener
```bash
# Status SCAN
srvctl status scan
srvctl status scan_listener

# Config SCAN
srvctl config scan
srvctl config scan_listener

# Start / Stop SCAN
srvctl start scan
srvctl start scan_listener
srvctl stop scan_listener

# Aggiornare SCAN (dopo cambio DNS)
srvctl modify scan -n new-scan-name.domain.com
```

---

## 5. SRVCTL — ASM e Diskgroup

```bash
# Status ASM
srvctl status asm
srvctl status asm -n rac1

# Config ASM
srvctl config asm

# Diskgroup
srvctl status diskgroup -g DATA
srvctl start diskgroup -g DATA
srvctl stop diskgroup -g DATA
```

---

## 6. SRVCTL — Network e VIP

```bash
# Status VIP
srvctl status vip -n rac1

# Config VIP
srvctl config vip -n rac1

# Status rete
srvctl status nodeapps
srvctl config nodeapps -a

# Modificare VIP (raro)
srvctl modify nodeapps -n rac1 -A new-vip/255.255.255.0/eth0
```

---

## 7. SRVCTL — Data Guard Broker

```bash
# Registrare il database con ruolo specifico
srvctl modify database -d STANDBY_DB -r PHYSICAL_STANDBY -s MOUNT

# Verificare il start options per standby
srvctl config database -d STANDBY_DB | grep -i "start\|role\|policy"
```

## 8. OPatch & Patching RAC (Rolling Patching)

In ambiente RAC 19c, l'utility `opatchauto` orchestra in modo automatico lo stop/start
dello stack Grid Infrastructure (GI) e del Database per permettere il **Rolling Patching**
(zero downtime applicativo). Va eseguito come utente `root`.

```bash
# 1. Prerequisiti: eseguire sempre come root
export PATH=$GRID_HOME/OPatch:$PATH

# 2. Analyze (Dry-run, verifica conflitti senza installare)
opatchauto apply /u01/stage/35042068 -analyze

# 3. Applica la patch sul nodo corrente (eseguire nodo per nodo per Zero Downtime)
opatchauto apply /u01/stage/35042068

# 4. Applica patch solo a un Oracle Home specifico (es. solo DB Home)
opatchauto apply /u01/stage/35042068 -oh $ORACLE_HOME

# 5. Rollback di una patch (sempre come root)
opatchauto rollback -id 35042068

# 6. Riprendere un'installazione fallita dopo aver risolto l'errore
opatchauto resume
```

### 8.1 Verifiche OPatch (utente oracle/grid)
```bash
# Mostra l'inventario delle patch installate
$ORACLE_HOME/OPatch/opatch lsinventory

# Cerca una patch specifica
$ORACLE_HOME/OPatch/opatch lsinventory | grep 35042068
```

---

## 9. Troubleshooting Rapido

| Sintomo | Diagnostica | Fix |
|---|---|---|
| CRS non si avvia | `crsctl check crs`, alert log Grid | `crsctl start crs`, check voting disk |
| Istanza non si avvia | `srvctl status database`, alert log DB | `srvctl start instance`, check spfile |
| VIP offline | `srvctl status vip -n node` | `crsctl start res ora.node.vip` |
| SCAN non risponde | `srvctl status scan_listener` | `srvctl start scan_listener`, check DNS |
| Servizio non parte | `srvctl config service -d DB -s SVC` | Verificare preferred/available, `srvctl start service` |
| Risorsa UNKNOWN | `crsctl stat res -t` | `crsctl stop/start resource <name>` |
| OCR corrotto | `ocrcheck` | `ocrconfig -restore` da backup |
| Patching fallito | `$GRID_HOME/cfgtoollogs/opatchauto` | `opatchauto resume` post fix |

### Log importanti
```bash
# CRS alert log
$GRID_HOME/log/<hostname>/alertrac1.log

# CRSD/OHASD logs
$GRID_HOME/log/<hostname>/crsd/crsd.log
$GRID_HOME/log/<hostname>/ohasd/ohasd.log

# Trace CSSD
$GRID_HOME/log/<hostname>/cssd/

# Listener log Grid
$GRID_HOME/log/diag/tnslsnr/<hostname>/listener_scan*/
```

---

## 10. Quick Reference

```text
+-------------------------------+----------------------------------------------+
| OPERAZIONE                    | COMANDO                                      |
+-------------------------------+----------------------------------------------+
| Cluster status                | crsctl stat res -t                           |
| Check cluster                 | crsctl check cluster -all                    |
| DB status                     | srvctl status database -d DB                 |
| DB start                      | srvctl start database -d DB                  |
| DB stop                       | srvctl stop database -d DB -o immediate      |
| Instance stop                 | srvctl stop instance -d DB -i DB1            |
| Service status                | srvctl status service -d DB                  |
| Service relocate              | srvctl relocate service -d DB -s SVC ...     |
| Service drain stop            | srvctl stop service -d DB -s SVC -drain 120  |
| Listener status               | srvctl status listener                       |
| SCAN status                   | srvctl status scan_listener                  |
| ASM status                    | srvctl status asm                            |
| VIP status                    | srvctl status vip -n node                    |
| Nodes                         | olsnodes -n -i -s -t                         |
| OCR check                     | ocrcheck                                     |
| Voting disk                   | crsctl query css votedisk                    |
+-------------------------------+----------------------------------------------+
```
