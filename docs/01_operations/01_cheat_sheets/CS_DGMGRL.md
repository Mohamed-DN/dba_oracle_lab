# Cheat Sheet DGMGRL — Enterprise Completo 🛡️

> [!NOTE]
> **DOCUMENTI DATA GUARD CORRELATI:**
> - **Guida Lab (Fase 4)**: [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4_DATAGUARD_DGMGRL.md)
> - **Observer FSFO (Fase 4B)**: [GUIDA_FASE4B_FSFO_OBSERVER.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4B_FSFO_OBSERVER.md)
> - **Switchover Completo**: [GUIDA_SWITCHOVER_COMPLETO.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_SWITCHOVER_COMPLETO.md)
> - **Failover & Reinstate**: [GUIDA_FAILOVER_E_REINSTATE.md](../../02_core_dba/04_high_availability_and_rac/GUIDA_FAILOVER_E_REINSTATE.md)
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md)

---

## 1. Connessione e Status Iniziale

```bash
# Connessione al broker
dgmgrl sys/password@PRIMARY
dgmgrl /

# Connessione in read-only (per check senza rischi)
dgmgrl -logfile /tmp/dgmgrl.log sys/pass@PRIMARY
```

### Status globale
```dgmgrl
-- Status rapido della configurazione
SHOW CONFIGURATION;

-- Status verbose (include TRANSPORT LAG, APPLY LAG, errori)
SHOW CONFIGURATION VERBOSE;

-- Lag attuale in tempo reale
SHOW CONFIGURATION LAG;
```

### Status database
```dgmgrl
-- Stato del primary
SHOW DATABASE 'PRIMARY_DB';
SHOW DATABASE VERBOSE 'PRIMARY_DB';

-- Stato dello standby
SHOW DATABASE 'STANDBY_DB';
SHOW DATABASE VERBOSE 'STANDBY_DB';

-- Tutti i membri
SHOW DATABASE 'PRIMARY_DB' 'StatusReport';
SHOW DATABASE 'STANDBY_DB' 'StatusReport';
```

---

## 2. Creazione e Gestione Configurazione

### 2.1 Creare la configurazione da zero
```dgmgrl
-- Crea configurazione (eseguire dal primary)
CREATE CONFIGURATION 'DG_CONFIG' AS
  PRIMARY DATABASE IS 'PRIMARY_DB'
  CONNECT IDENTIFIER IS PRIMARY;

-- Aggiungi standby
ADD DATABASE 'STANDBY_DB' AS
  CONNECT IDENTIFIER IS STANDBY
  MAINTAINED AS PHYSICAL;

-- Abilita
ENABLE CONFIGURATION;
```

### 2.2 Aggiungere/Rimuovere membri
```dgmgrl
-- Aggiungere un secondo standby
ADD DATABASE 'STANDBY2_DB' AS
  CONNECT IDENTIFIER IS STANDBY2
  MAINTAINED AS PHYSICAL;

-- Aggiungere un Far Sync
ADD FAR_SYNC 'FARSYNC1' AS
  CONNECT IDENTIFIER IS FARSYNC1;

-- Rimuovere un membro
REMOVE DATABASE 'STANDBY2_DB';
REMOVE FAR_SYNC 'FARSYNC1';

-- Rimuovere l'intera configurazione (ATTENZIONE!)
REMOVE CONFIGURATION;
```

### 2.3 Abilitare/Disabilitare
```dgmgrl
ENABLE CONFIGURATION;
DISABLE CONFIGURATION;

ENABLE DATABASE 'STANDBY_DB';
DISABLE DATABASE 'STANDBY_DB';
```

---

## 3. Switchover (Planned — Zero Data Loss)

### 3.1 Pre-check prima dello switchover
```dgmgrl
-- Valida la configurazione
VALIDATE DATABASE 'PRIMARY_DB';
VALIDATE DATABASE 'STANDBY_DB';

-- Verifica che lo switchover sia possibile
SHOW DATABASE 'STANDBY_DB' 'SwitchoverStatus';
-- Deve mostrare: "TO PRIMARY" o "NOT ALLOWED"
```

### 3.2 Eseguire lo switchover
```dgmgrl
-- Switchover standard
SWITCHOVER TO 'STANDBY_DB';

-- Switchover con conferma esplicita
SWITCHOVER TO 'STANDBY_DB' VERIFY;

-- Switchover con wait (attende che l'apply finisca)
SWITCHOVER TO 'STANDBY_DB' WAIT 300;
```

### 3.3 Post-switchover checks
```dgmgrl
SHOW CONFIGURATION;
SHOW DATABASE 'PRIMARY_DB';   -- ora è standby
SHOW DATABASE 'STANDBY_DB';   -- ora è primary
```

```sql
-- Da SQL*Plus sul nuovo primary
SELECT database_role, open_mode, switchover_status FROM V$DATABASE;
```

---

## 4. Failover (Unplanned — Disaster Recovery)

### 4.1 Failover manuale (quando il primary è irraggiungibile)
```dgmgrl
-- Failover: promuove lo standby a primary
FAILOVER TO 'STANDBY_DB';

-- Failover immediato (skip final apply, possibile perdita dati)
FAILOVER TO 'STANDBY_DB' IMMEDIATE;
```

### 4.2 Reinstate del vecchio primary
```dgmgrl
-- Dopo aver ripristinato il vecchio primary (ora deve diventare standby)
-- 1. Avvia il vecchio primary in MOUNT
-- 2. Dal nuovo primary:
REINSTATE DATABASE 'OLD_PRIMARY_DB';

-- Verifica
SHOW CONFIGURATION;
```

### 4.3 Fast-Start Failover (FSFO — Automatico)

Configura prima il wallet SEPS seguendo la
[Fase 4B](../../02_core_dba/04_high_availability_and_rac/GUIDA_FASE4B_FSFO_OBSERVER.md).

```dgmgrl
-- Configurare threshold (secondi prima del failover automatico)
EDIT CONFIGURATION SET PROPERTY FastStartFailoverThreshold = 30;

-- Abilitare inizialmente il monitoraggio senza promozione automatica
ENABLE FAST_START FAILOVER OBSERVE ONLY;
VALIDATE FAST_START FAILOVER;

-- Avviare l'Observer da observer1
START OBSERVER observer1 IN BACKGROUND
  CONNECT IDENTIFIER IS RACDB
  FILE IS '/home/oracle/admin/fsfo/observer1.dat'
  LOGFILE IS '/home/oracle/admin/fsfo/observer1.log';

-- Verificare stato FSFO
SHOW FAST_START FAILOVER;
SHOW OBSERVER;

-- Disabilitare
DISABLE FAST_START FAILOVER;

-- Stop Observer
STOP OBSERVER observer1;
```

---

## 5. Proprietà della Configurazione

### 5.1 Proprietà critiche
```dgmgrl
-- Protection Mode
EDIT CONFIGURATION SET PROTECTION MODE AS MAXAVAILABILITY;
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPERFORMANCE;
EDIT CONFIGURATION SET PROTECTION MODE AS MAXPROTECTION;

-- Verifica
SHOW CONFIGURATION 'ProtectionMode';

-- Transport Lag Threshold (alert se lag > soglia)
EDIT DATABASE 'STANDBY_DB' SET PROPERTY 'TransportLagThreshold' = 300;

-- Apply Lag Threshold
EDIT DATABASE 'STANDBY_DB' SET PROPERTY 'ApplyLagThreshold' = 600;

-- RedoRoutes (per topologie complesse)
EDIT DATABASE 'PRIMARY_DB' SET PROPERTY 'RedoRoutes' = '(LOCAL : STANDBY_DB ASYNC)';
```

### 5.2 Configurazione Redo Transport
```dgmgrl
-- Tipo di trasporto (ASYNC/SYNC/FASTSYNC)
EDIT DATABASE 'STANDBY_DB' SET PROPERTY 'LogXptMode' = 'ASYNC';
EDIT DATABASE 'STANDBY_DB' SET PROPERTY 'LogXptMode' = 'SYNC';
EDIT DATABASE 'STANDBY_DB' SET PROPERTY 'LogXptMode' = 'FASTSYNC';

-- Net Timeout
EDIT DATABASE 'STANDBY_DB' SET PROPERTY 'NetTimeout' = 30;

-- Delay applicazione redo (utile per protezione da errori logici)
EDIT DATABASE 'STANDBY_DB' SET PROPERTY 'DelayMins' = 30;
-- Per rimuovere il delay
EDIT DATABASE 'STANDBY_DB' SET PROPERTY 'DelayMins' = 0;
```

### 5.3 Tutte le proprietà in una volta
```dgmgrl
SHOW DATABASE 'STANDBY_DB' 'InconsistentProperties';
SHOW DATABASE 'STANDBY_DB' 'InconsistentLogXptProps';
```

---

## 6. Validate (Diagnostica Avanzata)

```dgmgrl
-- Validate completo (check redo transport, password file, logs)
VALIDATE DATABASE 'PRIMARY_DB';
VALIDATE DATABASE 'STANDBY_DB';
VALIDATE DATABASE VERBOSE 'STANDBY_DB';

-- Validate specifici
VALIDATE STATIC CONNECT IDENTIFIER FOR 'STANDBY_DB';
VALIDATE NETWORK CONFIGURATION FOR 'STANDBY_DB';
```

---

## 7. Troubleshooting Rapido

| Sintomo | Diagnostica | Fix |
|---|---|---|
| `ORA-16809` Multiple warnings | `SHOW DATABASE VERBOSE 'DB'` | Check alert log per dettagli |
| Apply Lag in crescita | `SHOW CONFIGURATION LAG` | Verifica I/O standby, redo transport |
| Transport Lag alto | `SHOW DATABASE 'DB' 'TransportLagThreshold'` | Check rete, listener, firewall |
| `DISABLED` dopo switchover | `SHOW CONFIGURATION` | `ENABLE DATABASE 'DB'` |
| `ORA-16629` db needs attention | `SHOW DATABASE 'DB' 'StatusReport'` | Spesso: gap archivelog o redo |
| Switchover non permesso | `SHOW DATABASE 'DB' 'SwitchoverStatus'` | Risolvere i prerequisiti |
| Password mismatch | `VALIDATE DATABASE 'DB'` | Copiare password file dal primary |
| `REINSTATE` fallisce | Flashback disabilitato | Ricreare lo standby da zero |

### Comandi SQL di supporto (da eseguire in SQL*Plus)
```sql
-- Lag reale
SELECT name, value, datum_time FROM V$DATAGUARD_STATS WHERE name IN ('transport lag','apply lag');

-- Sequenza applicata
SELECT thread#, max(sequence#) FROM V$ARCHIVED_LOG WHERE applied='YES' GROUP BY thread#;

-- Stato MRP (Managed Recovery Process)
SELECT process, status, thread#, sequence#, block# FROM V$MANAGED_STANDBY WHERE process LIKE 'MRP%';

-- GAP detection
SELECT * FROM V$ARCHIVE_GAP;

-- Redo transport errors
SELECT dest_id, status, error FROM V$ARCHIVE_DEST WHERE dest_id IN (1,2);
```

---

## 8. Quick Reference — Operazioni Quotidiane

```text
+---------------------------+----------------------------------------------+
| OPERAZIONE                | COMANDO                                      |
+---------------------------+----------------------------------------------+
| Check globale             | SHOW CONFIGURATION;                          |
| Check lag                 | SHOW CONFIGURATION LAG;                      |
| Check singolo DB          | SHOW DATABASE VERBOSE 'DB';                  |
| Switchover                | SWITCHOVER TO 'STANDBY';                     |
| Failover                  | FAILOVER TO 'STANDBY';                       |
| Reinstate post-failover   | REINSTATE DATABASE 'OLD_PRIMARY';            |
| Validate                  | VALIDATE DATABASE 'DB';                      |
| Start FSFO Observer       | START OBSERVER observer1 IN BACKGROUND ...;  |
| Disable standby           | DISABLE DATABASE 'DB';                       |
| Enable standby            | ENABLE DATABASE 'DB';                        |
| Cambia protection mode    | EDIT CONFIG SET PROTECTION MODE AS MAX...;   |
+---------------------------+----------------------------------------------+
```
