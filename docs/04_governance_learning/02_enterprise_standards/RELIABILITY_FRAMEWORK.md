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

---

## 1. I Pilastri dell'SRE applicati al DBA

L'SRE non è un ruolo, è un approccio. Un DBA SRE dedica il 50% del tempo alle operazioni e il 50% allo sviluppo di sistemi che automatizzano tali operazioni.

- **Affidabilità come prerequisito**: Se il database non è affidabile, nessuna feature applicativa ha valore.
- **Accettazione del rischio**: Il downtime 0% è un mito costoso. Definiamo quanto downtime possiamo permetterci.
- **Automazione implacabile**: Qualsiasi compito eseguito più di due volte deve essere automatizzato.

---

## 2. Matematica dell'Affidabilità: SLI, SLO, SLA

Dobbiamo misurare l'affidabilità con dati oggettivi, non con "sensazioni".

### 2.1. Service Level Indicators (SLI)
Metriche reali misurate nel tempo.
- **Disponibilità**: `% di connessioni andate a buon fine / totale connessioni`.
- **Latenza**: `Tempo di risposta medio (Elapsed Time) delle query core`.
- **Integrità**: `% di backup verificati con successo ogni 24 ore`.

### 2.2. Service Level Objectives (SLO)
Il target interno che vogliamo raggiungere.
- **Esempio**: Il database deve rispondere al 99.9% delle query entro 200ms.
- **Esempio**: La disponibilità mensile deve essere del 99.95%.

### 2.3. Service Level Agreements (SLA)
Il contratto legale con il business o il cliente.
- **Regola d'oro**: Lo SLO deve essere sempre più stringente dello SLA. (Se lo SLA è 99.9%, lo SLO deve essere 99.95%).

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

---

## 4. Toil Elimination: Eliminazione del Lavoro Ripetitivo

Il "Toil" è il lavoro manuale, ripetitivo, tattico e privo di valore a lungo termine.

| Compito | Toil? | Soluzione SRE |
|---|---|---|
| Creazione nuovi utenti | SÌ | Self-service Portal o script Ansible |
| Patching trimestrale | SÌ | Fleet Patching and Provisioning (FPP) automatizzato |
| Risoluzione ORA-01555 | SÌ | Tuning automatico dell'Undo Retention |
| Review degli Explain Plan | NO | Questo è lavoro ingegneristico di valore |

**Obiettivo**: Mantenere il Toil al di sotto del 50% del tempo lavorativo.

---

## 5. Gestione degli Incidenti e Post-Mortem Blameless

Quando accade un incidente (P1), l'obiettivo non è trovare un colpevole, ma trovare il fallimento del sistema.

### 5.1. Il Post-Mortem Blameless (Senza Colpa)
Documento scritto dopo ogni incidente critico che risponde a:
- **Cosa è successo?** (Timeline dettagliata).
- **Perché è successo?** (Analisi dei 5 Perché).
- **Come evitiamo che riaccada?** (Azioni correttive tracciabili).

**Cultura**: Se un DBA lancia un `DROP TABLE` per errore, il sistema ha fallito nel non avere controlli o permessi adeguati. Non è un fallimento umano, è un fallimento di design.

---

## 6. Capacity Planning Predittivo

Smettere di reagire ai dischi pieni.
- **Metriche**: Tracciare la crescita degli spazi ASM e dei Tablespace negli ultimi 6 mesi.
- **Trend**: Utilizzare modelli di regressione lineare per prevedere quando il disco sarà pieno al 90%.
- **Azione**: Ordinare lo storage 3 mesi prima della data prevista.

---

## 7. Automazione come Codice (Ansible & Terraform)

Il database deve essere trattato come "Bestiame" (Cattle), non come "Animali domestici" (Pets).

- **Terraform**: Gestisce i "muri" (Infrastruttura, VM, Rete).
- **Ansible**: Gestisce l'"arredamento" (Installazione binari, Patching, Hardening).
- **Liquibase**: Gestisce il "contenuto" (Cambiamenti di schema SQL).

Ogni cambiamento deve essere una Pull Request approvata. **Nessun cambio manuale in console o via SQL*Plus direttamente su PRD.**

---
**Standard SRE validato dal Global Reliability Board - Oracle Lab.**
