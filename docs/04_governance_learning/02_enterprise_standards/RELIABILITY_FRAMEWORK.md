# RUNBOOK ENTERPRISE: SITE RELIABILITY ENGINEERING (SRE) FOR ORACLE DATABASE

> **Document Classification:** GOVERNANCE / RELIABILITY  
> **Last Updated:** Maggio 2026  
> **Target Audience:** SREs, DBA Managers, DevOps Engineers  
> **Purpose:** Definire il framework operativo per gestire i database Oracle secondo i principi SRE, spostando il focus dal "mantenimento" alla "affidabilità scalabile".

## SOMMARIO
1. [I Pilastri dell'SRE applicati al DBA](#1-i-pilastri-dellsre-applicati-al-dba)
2. [Matematica dell'Affidabilità: SLI, SLO, SLA](#2-matematica-dellaffidabilita-sli-slo-sla)
3. [Error Budgets e Policy di Rilascio](#3-error-budgets-e-policy-di-rilascio)
4. [Toil Elimination: Eliminazione del Lavoro Ripetitivo](#4-toil-elimination-eliminazione-del-lavoro-ripetitivo)
5. [Gestione degli Incidenti e Post-Mortem Blameless](#5-gestione-degli-incidenti-e-post-mortem-blameless)
6. [Capacity Planning Predittivo](#6-capacity-planning-predittivo)
7. [Automazione come Codice (Ansible & Terraform)](#7-automazione-come-codice-ansible--terraform)
8. [Monitoraggio e Osservabilità (Golden Signals)](#8-monitoraggio-e-osservabilita-golden-signals)
9. [Change Management e Gestione del Rischio](#9-change-management-e-gestione-del-rischio)
10. [Conclusione e Roadmap Evolutiva](#10-conclusione-e-roadmap-evolutiva)

---

## 1. I Pilastri dell'SRE applicati al DBA

L'SRE non è un ruolo, è un approccio. Un DBA SRE dedica il 50% del tempo alle operazioni e il 50% allo sviluppo di sistemi che automatizzano tali operazioni.

- **Affidabilità come prerequisito**: Se il database non è affidabile, nessuna feature applicativa ha valore.
- **Accettazione del rischio**: Il downtime 0% è un mito costoso. Definiamo quanto downtime possiamo permetterci.
- **Automazione implacabile**: Qualsiasi compito eseguito più di due volte deve essere automatizzato.
- **Design per il fallimento**: Assumiamo che i nodi, la rete e lo storage falliranno. Il sistema deve recuperare autonomamente.

---

## 2. Matematica dell'Affidabilità: SLI, SLO, SLA

Dobbiamo misurare l'affidabilità con dati oggettivi, non con "sensazioni".

### 2.1. Service Level Indicators (SLI)
Metriche reali misurate nel tempo.
- **Disponibilità**: `% di connessioni andate a buon fine / totale connessioni`.
- **Latenza**: `Tempo di risposta medio (Elapsed Time) delle query core`.
- **Integrità**: `% di backup verificati con successo ogni 24 ore`.
- **Throughput**: `Numero di transazioni al secondo (TPS) supportate senza degradazione`.

### 2.2. Service Level Objectives (SLO)
Il target interno che vogliamo raggiungere.
- **Esempio**: Il database deve rispondere al 99.9% delle query entro 200ms.
- **Esempio**: La disponibilità mensile deve essere del 99.95%.

### 2.3. Service Level Agreements (SLA)
Il contratto legale con il business o il cliente.
- **Regola d'oro**: Lo SLO deve essere sempre più stringente dello SLA. (Se lo SLA è 99.9%, lo SLO deve essere 99.95%). Questo crea un "cuscinetto" per gestire gli imprevisti senza violare il contratto.

---

## 3. Error Budgets e Policy di Rilascio

L'Error Budget è la quantità di downtime che possiamo permetterci prima di violare lo SLO.

### 3.1. Calcolo dell'Error Budget
Per uno SLO del 99.95% mensile:
- **Tempo Totale**: 43.200 minuti (30 giorni).
- **Budget di Errore**: 21 minuti e 36 secondi al mese.

### 3.2. Conseguenze del Budget Esaurito
Se in un mese abbiamo consumato i nostri 21 minuti a causa di bug o configurazioni errate:
- **BLOCCO DEI RILASCI**: Nessuna nuova feature applicativa può essere promossa in produzione finché il database non torna stabile.
- **Focus sulla Stabilità**: Il team dev deve collaborare con il DBA per risolvere i problemi tecnici (Toil/Bug) invece di sviluppare nuove funzioni.
- **Pressione Positiva**: L'error budget allinea gli incentivi di Dev (velocità) e Ops (stabilità).

---

## 4. Toil Elimination: Eliminazione del Lavoro Ripetitivo

Il "Toil" è il lavoro manuale, ripetitivo, tattico e privo di valore a lungo termine.

| Compito | Toil? | Soluzione SRE |
|---|---|---|
| Creazione nuovi utenti | SÌ | Self-service Portal o script Ansible tramite GitOps |
| Patching trimestrale | SÌ | Fleet Patching and Provisioning (FPP) automatizzato |
| Risoluzione ORA-01555 | SÌ | Tuning automatico dell'Undo Retention e monitoraggio ASH |
| Review degli Explain Plan | NO | Questo è lavoro ingegneristico di valore che richiede intelligenza umana |
| Restore di database per test | SÌ | Snapshot storage o clonazione automatizzata via Terraform |

**Obiettivo**: Mantenere il Toil al di sotto del 50% del tempo lavorativo. Se supera il 50%, il team SRE deve essere autorizzato a rifiutare nuovi compiti per automatizzare quelli esistenti.

---

## 5. Gestione degli Incidenti e Post-Mortem Blameless

Quando accade un incidente (P1), l'obiettivo non è trovare un colpevole, ma trovare il fallimento del sistema.

### 5.1. Il Post-Mortem Blameless (Senza Colpa)
Documento scritto dopo ogni incidente critico che risponde a:
- **Cosa è successo?** (Timeline dettagliata, minuto per minuto).
- **Perché è successo?** (Analisi dei 5 Perché).
- **Como evitiamo che riaccada?** (Azioni correttive tracciabili e assegnate).

**Cultura**: Se un DBA lancia un `DROP TABLE` per errore, il sistema ha fallito nel non avere controlli, conferme o permessi adeguati. Non è un fallimento umano, è un fallimento di design del sistema di gestione.

---

## 6. Capacity Planning Predittivo

Smettere di reagire ai dischi pieni ("Firefighting").
- **Metriche**: Tracciare la crescita degli spazi ASM e dei Tablespace negli ultimi 6-12 mesi.
- **Trend**: Utilizzare modelli di regressione lineare o algoritmi predittivi per prevedere quando il disco raggiungerà il 90%.
- **Azione**: L'ordine dello storage o l'espansione del cloud deve essere triggerata automaticamente dalla pipeline quando la previsione a 30 giorni incrocia la soglia critica.

---

## 7. Automazione come Codice (Ansible & Terraform)

Il database deve essere trattato come "Bestiame" (Cattle), non come "Animali domestici" (Pets).

- **Terraform**: Gestisce i "muri" (Infrastruttura, VM, Rete, Storage).
- **Ansible**: Gestisce l'"arredamento" (Installazione binari, Patching, Hardening, Configurazione parametri).
- **Liquibase / Flyway**: Gestisce il "contenuto" (Cambiamenti di schema SQL, indici, DDL).

Ogni cambiamento deve passare per una Pull Request approvata. **Nessun cambio manuale in console o via SQL*Plus direttamente su PRD senza tracciamento Git.**

---

## 8. Monitoraggio e Osservabilità (Golden Signals)

Un database SRE-managed deve esporre i 4 "Golden Signals":
1. **Latency**: Tempo per completare una transazione o una query.
2. **Traffic**: Numero di transazioni al secondo o IOPS.
3. **Errors**: Numero di ORA-errors, timeout, o connessioni fallite.
4. **Saturation**: Quanto siamo vicini al limite di CPU, RAM, o I/O throughput.

**Strumenti**: Prometheus con `oracledb_exporter`, Grafana per la visualizzazione, e Alertmanager per la gestione delle notifiche intelligenti.

---

## 9. Change Management e Gestione del Rischio

Ogni cambiamento introduce rischio. L'SRE valuta il rischio prima di procedere.
- **Canary Deployments**: Applicare la patch a un nodo del RAC alla volta (Rolling Patching).
- **Blue-Green Deployments**: Utilizzare Data Guard per fare l'upgrade sulla standby e poi fare lo switchover.
- **Rollback Test**: Un cambiamento non è approvato se non è stato testato con successo il suo piano di rollback.

---

## 10. Conclusione e Roadmap Evolutiva

L'adozione del framework SRE per Oracle Database richiede un cambiamento culturale profondo.
- **Fase 1**: Misurazione (SLI/SLO).
- **Fase 2**: Automazione del Toil primario (Backup, Monitoraggio).
- **Fase 3**: Self-service e GitOps (Deployment automatizzato).
- **Fase 4**: Autoguarigione (Scripting che reagisce agli errori comuni ORA-).

---
**Standard SRE validato dal Global Reliability Board - Oracle Lab.**
