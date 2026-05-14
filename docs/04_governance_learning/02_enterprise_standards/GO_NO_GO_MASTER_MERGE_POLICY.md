# RUNBOOK ENTERPRISE: CI/CD GITOPS DATABASE DEPLOYMENT & GO/NO-GO POLICY

> **Document Classification:** GOVERNANCE / DEPLOYMENT STANDARD  
> **Last Updated:** Maggio 2026  
> **Target Audience:** DevOps Engineers, Release Managers, DBA, Sviluppatori  
> **Purpose:** Stabilire le regole ferree per la promozione di modifiche al database (DDL/DML) negli ambienti di produzione tramite pipeline automatizzate.

## SOMMARIO
1. [Il Modello Dichiarativo: Database as Code](#1-il-modello-dichiarativo-database-as-code)
2. [Gestione dei Cambiamenti di Schema (Liquibase)](#2-gestione-dei-cambiamenti-di-schema-liquibase)
3. [Il Processo di Pull Request e Code Review](#3-il-processo-of-pull-request-e-code-review)
4. [La Checklist di GO / NO-GO (Pre-Deployment)](#4-la-checklist-di-go--no-go-pre-deployment)
5. [Strategie di Rollback Enterprise](#5-strategie-di-rollback-enterprise)
6. [Validazione Post-Deployment](#6-validazione-post-deployment)
7. [Governance del Master Branch](#7-governance-del-master-branch)
8. [Ambienti e Flusso di Promozione](#8-ambienti-e-flusso-di-promozione)
9. [Gestione degli Hotfix in Produzione](#9-gestione-degli-hotfix-in-produzione)
10. [Audit e Compliance post-deploy](#10-audit-e-compliance-post-deploy)

---

## 1. Il Modello Dichiarativo: Database as Code

Nessun cambiamento deve essere eseguito manualmente tramite SQL*Plus o interfacce grafiche sugli ambienti controllati (TEST, UAT, PRD).

- **Sorgente della Verità**: Il repository Git. Il database è una proiezione dello stato definito nel codice.
- **Stato Desiderato**: Definito nei file SQL o XML/YAML tracciati.
- **Automazione**: Una pipeline (GitHub Actions, Jenkins) confronta lo stato attuale del DB con quello nel repository e applica solo le differenze (Migrations).
- **Vantaggi**: Auditing nativo, tracciabilità totale, possibilità di rollback rapido.

---

## 2. Gestione dei Cambiamenti di Schema (Liquibase)

Utilizziamo Liquibase per tracciare ogni modifica. Ogni file è un "Changeset" unico e immutabile.

### 2.1. Regole per il Changeset
- **Idempotenza**: Lo script deve poter girare più volte senza rompere nulla o creare duplicati.
- **Atomicità**: Un changeset = Una singola azione logica (es. aggiunta di una colonna, creazione di un indice).
- **Rollback integrato**: Ogni changeset deve avere una sezione `<rollback>` definita e testata.
- **Commenti**: Ogni changeset deve avere una descrizione chiara del motivo del cambiamento.

**Esempio di Changeset Buono:**
```sql
--changeset mrossi:01
--comment: Aggiunta colonna email per notifica utenti
ALTER TABLE utenti ADD (email VARCHAR2(255));
--rollback ALTER TABLE utenti DROP COLUMN email;
```

---

## 3. Il Processo di Pull Request e Code Review

Ogni modifica al database deve superare un'ispezione tecnica rigorosa prima di essere unita al branch principale.

### 3.1. Checklist del Revisore (DBA)
- [ ] **Data Types**: Sono stati usati i tipi corretti? (es. `NUMBER` invece di `VARCHAR2` per ID numerici).
- [ ] **Performance**: La nuova colonna richiede un indice? Se sì, è stato creato?
- [ ] **Sintassi 26ai**: Sono state sfruttate le nuove feature (es. `BOOLEAN` type, `VECTOR` type, `JSON` duality views) dove appropriato?
- [ ] **Naming Convention**: Rispetta gli standard aziendali (es. tabelle `T_`, indici `IDX_`, vincoli `FK_`).
- [ ] **Tablespace**: È stata specificata la corretta clausola `TABLESPACE` per evitare che gli oggetti finiscano in `SYSTEM`?

### 3.2. Analisi Automatica degli Explain Plan
La pipeline di CI deve eseguire un `EXPLAIN PLAN` automatico su tutte le nuove query e fallire se viene rilevato un "Full Table Scan" su tabelle critiche di produzione.

---

## 4. La Checklist di GO / NO-GO (Pre-Deployment)

30 minuti prima dell'inizio della finestra di manutenzione, il Release Manager e il Lead DBA devono validare il GO.

### 4.1. Criteri per il GO (Verde)
- [ ] Tutti i test di regressione e performance in ambiente UAT sono passati.
- [ ] Il backup RMAN (Full o Incrementale) pre-deployment è completato e verificato.
- [ ] Il team DBA e il team App sono "On-Call" e pronti per il supporto.
- [ ] È stato creato un **Guaranteed Restore Point (GRP)** per permettere il flashback istantaneo.
- [ ] La documentazione di deployment è completa e approvata dal CAB.

### 4.2. Criteri per il NO-GO (Rosso)
- [ ] Esistono incidenti critici (P1/P2) aperti sull'infrastruttura di rete, storage o database.
- [ ] Il backup dell'ultima notte è fallito o non è stato verificato.
- [ ] Si prevede un peggioramento delle condizioni meteo che potrebbe impattare il datacenter (per siti on-premise).
- [ ] Il lead engineer responsabile dello script non è reperibile.

---

## 5. Strategie di Rollback Enterprise

Il piano di rientro deve essere testato in UAT prima di essere applicato in PRD.

### 5.1. Rollback via Liquibase
```bash
# Rollback dell'ultimo deploy
liquibase rollbackCount 1
```
Utilizzato per piccoli errori di logica, correzioni di tipi o DDL errati che non hanno ancora impattato i dati.

### 5.2. Rollback via Flashback Database
Utilizzato per fallimenti catastrofici, corruzione massiva dei dati o fallimento del deployment che lascia il DB in uno stato inconsistente.
```sql
-- Eseguire da SQL*Plus come SYSDBA
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
FLASHBACK DATABASE TO RESTORE POINT PRE_DEPLOY_CHG_042;
ALTER DATABASE OPEN RESETLOGS;
```

---

## 6. Validazione Post-Deployment

Dopo il messaggio di "Deploy Success", è obbligatoria una fase di verifica.
- **Sanity Check**: Verificare che l'applicazione riesca a eseguire operazioni di CRUD sulla nuova struttura.
- **Monitoraggio Performance**: Controllare i report AWR e ASH per i primi 60 minuti dopo il rilascio per intercettare regressioni.
- **Verifica Oggetti Invalidi**: Eseguire lo script `utlrp.sql` per assicurarsi che nessun oggetto dipendente sia rimasto invalido.
- **Verifica Log**: Analizzare l'Alert Log del database per messaggi di errore post-deploy.

---

## 7. Governance del Master Branch

Il branch `master` (o `main`) è la rappresentazione fedele della Produzione.
- **Protezione Branch**: Il push diretto è disabilitato. Richiede almeno 2 approvazioni (1 DBA + 1 Team Lead).
- **Tagging**: Ogni deploy concluso con successo deve essere accompagnato da un Git Tag immutabile (es. `v2026.05.14-RELEASE`).
- **History**: La cronologia dei merge deve essere pulita (squash commits raccomandato).

---

## 8. Ambienti e Flusso di Promozione

Il codice deve viaggiare attraverso la catena degli ambienti senza eccezioni:
`DEV (Sviluppo)` -> `TEST (Integrazione)` -> `UAT (User Acceptance / Performance)` -> `PRD (Produzione)`

Ogni step richiede un'approvazione automatica basata sui test e un'approvazione manuale basata sulla scorecard.

---

## 9. Gestione degli Hotfix in Produzione

In caso di emergenza (bug bloccante in produzione):
1. Creare un branch `hotfix/` dal tag di produzione corrente.
2. Risolvere il problema e testare in un ambiente di emergenza (Sandbox).
3. Merge immediato su master e deploy con priorità "Emergency" approvato dal Change Manager.
4. Retro-merge degli hotfix nei branch di sviluppo per evitare regressioni future.

---

## 10. Audit e Compliance post-deploy

A fine anno (o fine trimestre), il team di Security Audit deve poter ricostruire ogni singola modifica fatta al database.
- **Report Git**: Lista di tutti i merge sul master con autori e approvatori.
- **Liquibase DATABASECHANGELOG**: Tabella interna al database che traccia l'ordine cronologico di applicazione degli script.
- **Corrispondenza**: Ogni record in Liquibase deve corrispondere a una Pull Request in Git.

---
**Politica di Rilascio ufficiale - Governance Oracle Lab.**
