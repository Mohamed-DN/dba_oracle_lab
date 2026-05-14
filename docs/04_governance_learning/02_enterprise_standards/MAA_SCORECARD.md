# RUNBOOK ENTERPRISE: MAXIMUM AVAILABILITY ARCHITECTURE (MAA) SCORECARD & AUDIT FRAMEWORK

> **Document Classification:** ARCHITECTURE STANDARD / MISSION CRITICAL  
> **Last Updated:** Maggio 2026  
> **Target Audience:** Enterprise Architects, Infrastructure Leads, Senior DBA  
> **Purpose:** Fornire un framework di auditing oggettivo per certificare la resilienza di un database Oracle secondo gli standard MAA (Gold/Platinum).

## SOMMARIO
1. [Definizione degli Standard MAA (Bronze, Silver, Gold, Platinum)](#1-definizione-degli-standard-maa)
2. [Matrice di Certificazione delle Soluzioni](#2-matrice-di-certificazione-delle-soluzioni)
3. [Scorecard di Audit: Infrastruttura e Rete](#3-scorecard-di-audit-infrastruttura-e-rete)
4. [Scorecard di Audit: High Availability (RAC/Grid)](#4-scorecard-di-audit-high-availability-racgrid)
5. [Scorecard di Audit: Disaster Recovery (Data Guard)](#5-scorecard-di-audit-disaster-recovery-data-guard)
6. [Validazione Applicativa: Application Continuity (AC)](#6-validazione-applicativa-application-continuity-ac)
7. [Chaos Engineering: Protocolli di Test Distruttivi](#7-chaos-engineering-protocolli-di-test-distruttivi)
8. [Piano di Rimedio e Gap Analysis](#8-piano-di-rimedio-e-gap-analysis)

---

## 1. Definizione degli Standard MAA

L'architettura MAA di Oracle non è un prodotto, ma un insieme di best practice e configurazioni validate per minimizzare il downtime pianificato e non pianificato.

| Tier | Nome | Target RPO | Target RTO | Tecnologie Chiave |
|---|---|---|---|---|
| **Bronze** | Single Instance | Minuti/Ore | Ore | Restart automatico, RMAN, Backup su Cloud |
| **Silver** | High Availability | 0 | Minuti | RAC (Real Application Clusters), ASM, DBFS |
| **Gold** | Disaster Recovery | 0 (Sync) | Secondi | Data Guard, Active Data Guard, FSFO (Observer) |
| **Platinum** | Zero Downtime | 0 | 0 | GoldenGate, Edition-Based Redefinition (EBR), Global Data Services |

---

## 2. Matrice di Certificazione delle Soluzioni

Ogni database di produzione deve essere classificato. L'audit deve verificare la presenza dei seguenti componenti.

### 2.1. Requisiti Gold Standard (Il minimo Enterprise)
- [ ] **Data Guard Sync**: Protezione completa contro la corruzione dei dati.
- [ ] **Fast-Start Failover (FSFO)**: Failover automatico gestito da un Observer in una terza location.
- [ ] **Application Continuity**: Replay automatico delle transazioni in caso di fallimento del nodo.
- [ ] **Flashback Database**: Abilitato su Primary e Standby per rollback istantanei.

### 2.2. Requisiti Platinum Standard (Mission Critical)
- [ ] **GoldenGate Active-Active**: Replica bidirezionale con risoluzione dei conflitti.
- [ ] **ZDLRA (Zero Data Loss Recovery Appliance)**: Backup real-time con protezione continua.
- [ ] **EBR (Edition-Based Redefinition)**: Patching e upgrade senza fermo applicativo.

---

## 3. Scorecard di Audit: Infrastruttura e Rete

### 3.1. Ridondanza Storage (ASM)
- **Check 1**: Tutti i Diskgroup critici (+DATA, +FRA, +REDO) usano Normal o High Redundancy?
- **Check 2**: I dischi ASM sono mappati tramite Multipathing (MPIO) correttamente configurato?
- **Check 3**: È presente un piano di espansione storage (Capacity Planning) con alert all'80%?

### 3.2. Networking e Connettività
- **Check 4**: Scan Listeners (RAC) sono bilanciati su almeno 3 indirizzi IP?
- **Check 5**: Il file `sqlnet.ora` implementa il timeout di connessione (`SQLNET.INBOUND_CONNECT_TIMEOUT`)?
- **Check 6**: La rete Heartbeat (Private Interconnect) è isolata e su switch ridondati (Jumbo Frames attivi)?

---

## 4. Scorecard di Audit: High Availability (RAC/Grid)

### 4.1. Configurazione Clusterware
- **Check 7**: Il Voting Disk e l'OCR sono distribuiti su un numero dispari di siti (Quorum)?
- **Check 8**: I servizi database sono configurati con preferenza/disponibilità corretta (`srvctl config service`)?
- **Check 9**: È configurato il FAN (Fast Application Notification) per notificare i client in tempo reale?

### 4.2. Parametri Istanza RAC
- **Check 10**: Il parametro `PARALLEL_FORCE_LOCAL` è impostato correttamente per evitare traffico cross-interconnect inutile?
- **Check 11**: `FAST_START_MTTR_TARGET` è configurato per garantire un crash recovery rapido?

---

## 5. Scorecard di Audit: Disaster Recovery (Data Guard)

### 5.1. Trasmissione Redo
- **Check 12**: La modalità di protezione è `MAXIMUM AVAILABILITY` o `MAXIMUM PROTECTION`?
- **Check 13**: Il parametro `NET_TIMEOUT` è impostato a 30 secondi o meno per il rilascio rapido dei lock in caso di failure di rete?
- **Check 14**: Gli Standby Redo Logs (SRL) sono presenti e correttamente dimensionati (n+1 rispetto agli Online Redo Logs)?

### 5.2. Automazione Failover (FSFO)
- **Check 15**: L'Observer è in esecuzione in una location geograficamente distinta da Primary e Standby?
- **Check 16**: `FastStartFailoverThreshold` è impostato in base alla stabilità della rete (Default 30s)?
- **Check 17**: La configurazione DGMGRL è priva di errori o avvisi (`show configuration`)?

---

## 6. Validazione Applicativa: Application Continuity (AC)

L'HA non serve a nulla se l'utente riceve un errore "Connection Lost". La vera MAA nasconde il fallimento del database all'applicazione.

### 6.1. Configurazione dei Servizi per AC
```sql
-- Esempio di creazione servizio con Application Continuity abilitata
srvctl add service -db PRDDB -service app_srv -preferred inst1 -available inst2   -failovertype TRANSACTION -failovermethod BASIC -clbgoal LONG -rlbgoal SERVICE_TIME   -failoverretry 30 -failoverdelay 10 -commit_outcome_outcome TRUE
```

### 6.2. Test di Validazione Client
1. Avviare un'applicazione/script che esegue DML continui.
2. Eseguire un `kill -9` del processo PMON sul nodo Primary.
3. **Risultato Atteso**: L'applicazione subisce un rallentamento (hang) di 10-20 secondi, ma la transazione viene completata correttamente senza errori `ORA-03113`.

---

## 7. Chaos Engineering: Protocolli di Test Distruttivi

Per certificare la scorecard, è necessario eseguire periodicamente dei test distruttivi (DR Exercises).

### 7.1. Test 1: Network Partition (Split-Brain)
- **Azione**: Droppare i pacchetti sulla porta 1521 e sulla rete privata tra i nodi tramite `iptables`.
- **Obiettivo**: Verificare che il cluster espella il nodo instabile e che l'Observer Data Guard non faccia un failover non necessario (o lo faccia se previsto).

### 7.2. Test 2: Storage Failure
- **Azione**: Mettere offline un disco di un diskgroup `High Redundancy`.
- **Obiettivo**: Verificare che il database continui a servire i dati senza interruzioni e che ASM inizi il rebalance automatico.

### 7.3. Test 3: Data Guard Switchover
- **Azione**: Eseguire `switchover to standby` tramite DGMGRL.
- **Obiettivo**: Verificare che il tempo totale di switch (RTO) sia conforme agli SLA aziendali (Target < 60s).

---

## 8. Piano di Rimedio e Gap Analysis

Se un database non raggiunge il punteggio minimo (100% dei check per il Tier assegnato):
1. **Identificazione Gap**: Elencare i check falliti.
2. **Analisi Impatto**: Qual è il rischio di business associato?
3. **Roadmap**: Definire le date di implementazione dei fix (es. upgrade a Active Data Guard, configurazione servizi AC).
4. **Rivalutazione**: Eseguire nuovamente l'audit dopo i cambiamenti.

---
**Firmato dagli Architetti Senior del Cluster DBA Lab.**
