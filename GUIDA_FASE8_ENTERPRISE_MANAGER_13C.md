# FASE 8: Oracle Enterprise Manager Cloud Control 13.5 (Single OMS Lab)

Aggiornata: 13 marzo 2026
Target lab: Oracle Linux 7.9/8.x, Oracle DB 19c, RAC + Data Guard + GoldenGate gia operativi.

Questa fase aggiunge una console centralizzata per monitorare e governare tutto il laboratorio:

- host e metriche OS
- database single instance e RAC
- ASM, listener, Data Guard
- alerting, incident management, notification, jobs, blackout
- monitoraggio backup RMAN

## 8.1 Obiettivo operativo

A fine fase devi avere:

- 1 VM dedicata `emcc1` con OMS + local Agent
- repository database 19c per EM
- target registrati (host + DB + ASM + listener)
- rule set incidenti e notifiche email
- dashboard operative giornaliere
- runbook test alert validato

## 8.2 Architettura consigliata nel tuo lab

Scelta bloccata: Single OMS su VM dedicata.

```text
+------------------------+            +---------------------------+
| emcc1                  |            | dbtarget (o emcc1 local) |
| OMS + Agent + Console  |----------->| Repository DB 19c         |
| Porta console HTTPS    |            | SYSMAN schema             |
+------------+-----------+            +-------------+-------------+
             |
             | Agent uploads / discovery
             v
+----------------+  +----------------+  +----------------+
| RAC primary    |  | RAC standby    |  | dbtarget       |
| host/db/asm    |  | host/db/asm    |  | host/db/listnr |
+----------------+  +----------------+  +----------------+
```

Nota pratica:

- In lab puoi mettere repository DB su `dbtarget` per risparmiare RAM.
- In produzione si preferisce separazione dedicata OMS vs repository.

## 8.3 Prerequisiti minimi

## 8.3.1 Hardware VM `emcc1`

Minimo lab:

- vCPU: 4
- RAM: 12 GB (16 GB consigliati)
- Disk: 120 GB

Con 8 GB RAM OMS tende a saturarsi durante discovery e patching console.

## 8.3.2 Software

- Oracle Linux 7.9 o 8.x
- JDK supportato dalla release EM 13.5
- pacchetti OS richiesti dall installer
- install media EM 13.5 + eventuale RU

## 8.3.3 Rete e porte

Apri almeno:

- 7802/7803 (upload/communication, dipende da configurazione)
- 3872 (agent)
- 4903, 4904 (OMS internal)
- 1521 (repository DB)
- 5500 o porta custom console HTTPS OMS

Usa DNS risolvibile per:

- `emcc1`
- nodi RAC e standby
- host repository DB

## 8.3.4 Utenti e path consigliati

- utente software OMS: `oracle` (lab) o `omsuser` (enterprise)
- base directory: `/u01/app/oracle`
- middleware home OMS: `/u01/app/oracle/middleware`
- software media: `/u01/software/em13c`

## 8.4 Preparazione VM emcc1

```bash
# hostname e risoluzione
hostnamectl set-hostname emcc1

# swap consigliata per OMS in lab
free -h
swapon --show

# controlli kernel/network (esempio)
ulimit -n
sysctl -a | egrep "fs.file-max|net.core.somaxconn" 
```

Verifica NTP/chrony su tutte le VM, altrimenti avrai falsi alert e metriche incoerenti.

## 8.5 Repository DB 19c per Enterprise Manager

Puoi usare:

- opzione A: repository nel database `dbtarget`
- opzione B: repository locale su `emcc1`

Per lab e sufficiente opzione A.

Checklist repository DB:

- ARCHIVELOG ON
- character set supportato
- spazio tablespace adeguato per SYSMAN/MGMT_TABLESPACE
- listener e service raggiungibili da `emcc1`

Controlli rapidi:

```sql
SELECT name, open_mode, log_mode FROM v$database;
SELECT value FROM v$parameter WHERE name='compatible';
```

## 8.6 Installazione OMS 13.5 da zero

## 8.6.1 Installazione grafica (consigliata in lab)

1. Copia software EM su `emcc1`.
2. Estrai/esegui installer.
3. Seleziona "Install a new Enterprise Manager System".
4. Inserisci connessione repository DB.
5. Definisci password SYSMAN e porta console.
6. Completa prereq check e install.

Esempio avvio installer:

```bash
cd /u01/software/em13c
chmod +x em13500_linux64.bin
./em13500_linux64.bin
```

## 8.6.2 Comandi post-install obbligatori

```bash
# OMS status
/u01/app/oracle/middleware/bin/emctl status oms -details

# Agent locale status
/u01/app/oracle/agent/agent_inst/bin/emctl status agent

# URL console
/u01/app/oracle/middleware/bin/emctl status oms -details | egrep "Console URL|Upload URL"
```

Login console:

- URL: `https://emcc1:<porta_oms>/em`
- user: `SYSMAN`

## 8.7 Deploy agent sui target host

Per ogni host target (rac1, rac2, racstby1, racstby2, dbtarget):

1. Deploy Agent da console (Add Host Targets).
2. Configura named credentials SSH + sudo.
3. Verifica upload heartbeat agent.

Comandi diagnostici su host target:

```bash
$AGENT_HOME/bin/emctl status agent
$AGENT_HOME/bin/emctl upload agent
$AGENT_HOME/bin/emctl clearstate agent
```

## 8.8 Onboarding target Oracle

Ordine consigliato:

1. Host target
2. Listener
3. Database instances
4. ASM instance + diskgroups
5. RAC database target
6. Data Guard association

Verifiche minime in console:

- target status: Up
- metric collection senza errori
- availability timeline coerente

## 8.9 Setup operativo giornaliero

## 8.9.1 Dashboard e homepage

Crea homepage operative:

- Infrastructure Overview
- Database Group (RAC primary)
- Database Group (standby + target)
- Critical Incidents

## 8.9.2 Metric thresholds

Definisci soglie realistiche per lab:

- CPU host > 85% per 15 min
- Filesystem usage > 85%
- Tablespace usage > 85%
- Failed login attempts
- Data Guard transport/apply lag

## 8.9.3 Incident Rules

Crea almeno due rule set:

- `LAB_CRITICAL_DB`
- `LAB_WARNING_INFRA`

Routing esempio:

- Critical -> email immediata
- Warning -> digest ogni 30 minuti

## 8.9.4 Notifications (SMTP)

Configura:

- SMTP server
- sender address
- recipient groups (DBA team)

Testa con invio notifica di prova e con incidente reale simulato.

## 8.9.5 Jobs e library

Crea job standard:

- SQL health check giornaliero
- check FRA usage
- verifica Data Guard lag
- stato backup RMAN

Salva job template nella library per riuso.

## 8.9.6 Blackout

Usa blackout per manutenzione:

- patching Grid/DB
- reboot host
- test failover/switchover

Regola: nessuna attivita pianificata senza blackout aperto.

## 8.10 Monitoraggio specifico RMAN

In EM crea viste/favorite su:

- ultimo backup job
- backup failed negli ultimi 7 giorni
- recovery area usage
- missing archived logs

Cross-check SQL utile:

```sql
SELECT session_key, input_type, status, start_time, end_time
FROM v$rman_backup_job_details
ORDER BY session_key DESC;
```

Collega questa fase alla tua guida:

- `GUIDA_RMAN_COMPLETA_19C.md`

## 8.11 Runbook test pratici (lab)

Ogni test deve registrare: data, obiettivo, tempo rilevazione alert, esito.

## Test 1 - Alert CPU host

1. genera carico CPU su `dbtarget`
2. attende superamento soglia
3. verifica incidente e notifica email

Esito atteso:

- incidente warning/critical creato
- email ricevuta

## Test 2 - Tablespace alert

1. riempi tablespace test oltre soglia
2. verifica evento in EM
3. riduci uso tablespace e chiudi incidente

Esito atteso:

- incidente auto-clear dopo rientro soglia

## Test 3 - Listener down

1. stop listener su host target
2. verifica target unavailable
3. restart listener

Esito atteso:

- stato target torna Up e incidente chiuso

## Test 4 - Data Guard lag

1. simula backlog apply (lab controllato)
2. verifica metrica lag e incidente
3. ripristina apply realtime

Esito atteso:

- alert DG visibile nella dashboard

## Test 5 - Job fail/success

1. crea job SQL con errore intenzionale
2. verifica fallimento e notifica
3. correggi job e riesegui

Esito atteso:

- storico job mostra fail poi success

## 8.12 Troubleshooting piu comune

## Agent down

Sintomi:

- host target Down
- last upload timestamp vecchio

Azioni:

```bash
$AGENT_HOME/bin/emctl status agent
$AGENT_HOME/bin/emctl start agent
$AGENT_HOME/bin/emctl upload agent
```

## Upload backlog OMS

Sintomi:

- metriche in ritardo
- pending uploads alto

Azioni:

- verifica risorse OMS (CPU/RAM/disk)
- controlla repository DB load
- riavvio controllato OMS in finestra manutenzione

```bash
$OMS_HOME/bin/emctl status oms -details
$OMS_HOME/bin/emctl stop oms -all
$OMS_HOME/bin/emctl start oms
```

## Target unavailable ma host raggiungibile

Azioni:

- valida credentials target
- forzare rediscovery
- controlla listener/service

## Metric collection error

Azioni:

- review metric extension e collection schedule
- verifica privilegio DB user monitor
- controlla clock drift host/OMS

## 8.13 Hardening minimo consigliato in lab

- password policy forte per SYSMAN e named credentials
- backup periodico repository DB
- snapshot VM pre-change
- audit delle modifiche di soglie/rules/job

## 8.14 Checklist di completamento fase 8

- OMS Up e console accessibile
- agent deployato su tutti i nodi target
- RAC + standby + dbtarget visibili e monitorati
- rule set incidenti attivo
- notifiche email testate
- almeno 5 test runbook eseguiti con esito registrato

## 8.15 Integrazione con il resto del lab

Dopo questa fase puoi:

- usare EM per seguire switchover/failover in tempo reale
- correlare alert DG con backup RMAN
- schedulare controlli DBA periodici
- avere evidenze operative per review/cv

## 8.16 Riferimenti ufficiali Oracle (13.5)

- Oracle Enterprise Manager Cloud Control Basic Installation Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/embsc/index.html
- Oracle Enterprise Manager Cloud Control Advanced Installation and Configuration Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadv/index.html
- Oracle Enterprise Manager Cloud Control Administrator's Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/index.html
- Oracle Enterprise Manager Cloud Control Monitoring Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emmon/index.html
- Incidents and Problems in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/managing-incidents.html
- Management Agent administration in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/management-agent.html
- Blackouts in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/administering-blackouts.html
- Jobs and Automation in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/administering-jobs.html
- Notifications in EM 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/managing-notifications.html

---

Note:

- Questa guida copre setup e operativita quotidiana in ambiente lab.
- Per setup HA/multi-OMS serve un design separato con capacity planning dedicato.
