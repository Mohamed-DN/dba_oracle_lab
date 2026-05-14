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

---

## 1. Il Modello Dichiarativo: Database as Code

Nessun cambiamento deve essere eseguito manualmente tramite SQL*Plus o interfacce grafiche sugli ambienti controllati (TEST, UAT, PRD).

- **Sorgente della Verità**: Il repository Git.
- **Stato Desiderato**: Definito nei file SQL o XML/YAML.
- **Automazione**: Una pipeline (GitHub Actions, Jenkins) confronta lo stato attuale del DB con quello nel repository e applica solo le differenze.

---

## 2. Gestione dei Cambiamenti di Schema (Liquibase)

Utilizziamo Liquibase per tracciare ogni modifica. Ogni file è un "Changeset".

### 2.1. Regole per il Changeset
- **Idempotenza**: Lo script deve poter girare più volte senza rompere nulla.
- **Atomicità**: Un changeset = Una singola azione logica (es. aggiunta di una colonna).
- **Rollback integrato**: Ogni changeset deve avere una sezione `<rollback>` definita.

**Esempio di Changeset Buono:**
```sql
--changeset mrossi:01
CREATE TABLE ordini (id NUMBER PRIMARY KEY, data DATE);
--rollback DROP TABLE ordini;
```

---

## 3. Il Processo di Pull Request e Code Review

Ogni modifica al database deve superare un'ispezione tecnica rigorosa.

### 3.1. Checklist del Revisore (DBA)
- [ ] **Data Types**: Sono stati usati i tipi corretti? (es. `NUMBER` invece di `VARCHAR2` per ID).
- [ ] **Performance**: La nuova colonna richiede un indice? La query proposta è sargable?
- [ ] **Sintassi 26ai**: Sono state sfruttate le nuove feature (es. `BOOLEAN` type, `VECTOR` type) dove appropriato?
- [ ] **Naming Convention**: Rispetta gli standard aziendali (es. prefisso `T_` per tabelle, `V_` per viste)?

### 3.2. Analisi Automatica degli Explain Plan
La pipeline deve fallire se una nuova query causa un Full Table Scan su una tabella con più di 100.000 righe.

---

## 4. La Checklist di GO / NO-GO (Pre-Deployment)

30 minuti prima dell'inizio della finestra di manutenzione, il Release Manager deve validare il GO.

### 4.1. Criteri per il GO (Verde)
- [ ] Tutti i test di regressione in UAT sono passati.
- [ ] Il backup RMAN pre-deployment è completato e verificato.
- [ ] Il team DBA è "On-Call" e presente sul canale di comunicazione.
- [ ] È stato creato un **Guaranteed Restore Point (GRP)**.

### 4.2. Criteri per il NO-GO (Rosso)
- [ ] Esistono incidenti critici (P1) aperti sull'infrastruttura di rete o storage.
- [ ] Il backup dell'ultima notte è fallito.
- [ ] Mancano i contatti del team applicativo responsabile dei test post-deploy.

---

## 5. Strategie di Rollback Enterprise

Il piano di rientro deve essere testato in UAT prima di PRD.

### 5.1. Rollback via Liquibase
```bash
liquibase rollbackCount 1
```
Utilizzato per piccoli errori di logica o DDL errati.

### 5.2. Rollback via Flashback Database
Utilizzato per fallimenti catastrofici o corruzione massiva dei dati.
```sql
FLASHBACK DATABASE TO RESTORE POINT PRE_DEPLOY_CHG_042;
```

---

## 6. Validazione Post-Deployment

Dopo il "Deploy Success", il lavoro non è finito.
- **Sanity Check**: Verificare che l'applicazione riesca a scrivere nella nuova tabella.
- **Monitoraggio Performance**: Controllare il report AWR per i primi 30 minuti dopo il rilascio.
- **Verifica Oggetti Invalidi**: Eseguire `utlrp.sql` per assicurarsi che nessun oggetto sia rimasto invalido.

---

## 7. Governance del Master Branch

Il branch `master` (o `main`) è considerato la Produzione.
- **Protezione Branch**: Nessun push diretto. Richiede 2 approvazioni (1 DBA + 1 Team Lead).
- **Tagging**: Ogni deploy deve essere accompagnato da un Git Tag (es. `v1.2.0-PRD`).
- **Emergenze**: Gli "Hotfix" seguono lo stesso flusso ma con priorità di approvazione accelerata.

---
**Politica di Rilascio ufficiale - Governance Oracle Lab.**
