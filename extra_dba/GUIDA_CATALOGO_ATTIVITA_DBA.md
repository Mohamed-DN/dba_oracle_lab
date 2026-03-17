# GUIDA: Catalogo Completo delle Attivita DBA Oracle 19c

> Questa guida raccoglie le principali attivita che un DBA Oracle svolge davvero in esercizio.
> E pensata per il tuo lab Oracle 19c con RAC, Data Guard, GoldenGate ed Enterprise Manager, ma la struttura e valida anche come modello day-2 da produzione.

## 1. Come usare questa guida

- Usa questa guida come catalogo del mestiere DBA: ti dice cosa esiste, perche si fa e dove lo provi nel repo.
- Usa [GUIDA_CHECKLIST_ATTIVITA_DBA.md](./GUIDA_CHECKLIST_ATTIVITA_DBA.md) quando ti serve la sequenza operativa per frequenza.
- Mantieni separati:
  - `lab base`: costruzione ambiente e runbook di setup;
  - `extra_dba`: attivita operative post-lab;
  - `studio_ai`: script e note reali da riuso.

## 2. Le macro-aree del lavoro DBA

| Area | Cosa fa il DBA | Frequenza tipica | Dove la fai nel repo |
|---|---|---|---|
| **Disponibilita e startup/shutdown** | Verifica istanze, servizi, listener, cluster resources, restart controllati | Giornaliera / su change | [GUIDA_COMANDI_DBA.md](../GUIDA_COMANDI_DBA.md), [GUIDA_LISTENER_SERVICES_DBA.md](../GUIDA_LISTENER_SERVICES_DBA.md) |
| **Monitoring e alerting** | Legge alert log, incidenti EM, eventi critici, job falliti, metriche host e DB | Giornaliera | [GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md](../GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md), [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md) |
| **Backup e recovery** | Definisce strategia, monitora backup, esegue validate, restore test, recovery runbook | Giornaliera / settimanale / trimestrale | [GUIDA_FASE5_RMAN_BACKUP.md](../GUIDA_FASE5_RMAN_BACKUP.md), [GUIDA_RMAN_COMPLETA_19C.md](../GUIDA_RMAN_COMPLETA_19C.md) |
| **Performance e tuning** | Analizza AWR/ADDM/ASH, top SQL, wait events, sessioni attive, statistiche | Giornaliera / settimanale / su incidente | [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md), [GUIDA_COMANDI_DBA.md](../GUIDA_COMANDI_DBA.md) |
| **Storage, ASM e capacity** | Controlla tablespace, FRA, ASM disk group, crescita dati, autoextend, soglie | Giornaliera / settimanale / mensile | [GUIDA_COMANDI_DBA.md](../GUIDA_COMANDI_DBA.md), [GUIDA_AGGIUNTA_DISCHI_ASM.md](../GUIDA_AGGIUNTA_DISCHI_ASM.md) |
| **Security e accessi** | Gestisce utenti, ruoli, privilegi, auditing, wallet, TDE, hardening | Settimanale / mensile / su richiesta | [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md), [GUIDA_CDB_PDB_UTENTI.md](../GUIDA_CDB_PDB_UTENTI.md) |
| **Scheduler e batch** | Controlla job, finestre, chains, fallimenti, credenziali e retry | Giornaliera / settimanale | [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md) |
| **HA e DR** | Gestisce RAC, Data Guard, switchover, failover, reinstate, lag, protection mode | Giornaliera / mensile / drill | [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../GUIDA_FASE4_DATAGUARD_DGMGRL.md), [GUIDA_SWITCHOVER_COMPLETO.md](../GUIDA_SWITCHOVER_COMPLETO.md), [GUIDA_FAILOVER_E_REINSTATE.md](../GUIDA_FAILOVER_E_REINSTATE.md) |
| **Network, listener e services** | Verifica SCAN, listener statici/dinamici, srvctl, TNS, service placement | Giornaliera / su incident | [GUIDA_LISTENER_SERVICES_DBA.md](../GUIDA_LISTENER_SERVICES_DBA.md) |
| **Multitenant e lifecycle PDB** | Crea, clona, apre/chiude, plug/unplug, refresh, controlla servizi PDB | Su richiesta / mensile | [GUIDA_CDB_PDB_UTENTI.md](../GUIDA_CDB_PDB_UTENTI.md) |
| **Data movement e refresh** | Esegue export/import Data Pump, refresh ambienti, clone database/PDB | Su richiesta / progetto | [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md), [GUIDA_RMAN_COMPLETA_19C.md](../GUIDA_RMAN_COMPLETA_19C.md) |
| **Patching e lifecycle software** | Applica RU/OJVM, aggiorna OPatch, esegue rollback piano, verifica post-patch | Mensile / trimestrale / change | [GUIDA_PATCHING_RAC.md](../GUIDA_PATCHING_RAC.md), [GUIDA_UPGRADE_RU_RAC.md](../GUIDA_UPGRADE_RU_RAC.md) |
| **Documentazione e change management** | Tiene runbook, backlog rischi, evidenze test, capacity trend, lesson learned | Continuo | [TESTLOG_GOLDENGATE_TEMPLATE.md](../TESTLOG_GOLDENGATE_TEMPLATE.md), [PIANO_STUDIO_GIORNALIERO.md](../PIANO_STUDIO_GIORNALIERO.md) |

## 3. Attivita complete per dominio operativo

### 3.1 Disponibilita e continuita operativa

Un DBA deve sapere sempre:
- se il database e disponibile;
- se i servizi sono online;
- se il cluster e sano;
- se ci sono restart non attesi o errori `ORA-` recenti.

Attivita tipiche:
- verifica stato database e istanze;
- verifica `srvctl status database`, `srvctl status service`, `crsctl stat res -t`;
- verifica listener e servizi registrati;
- controllo alert log e `adrci`;
- restart controllato per manutenzione o troubleshooting.

Output minimo da conservare:
- stato `OPEN_MODE`, `DATABASE_ROLE`, servizi online;
- ultimi errori alert log;
- evidenza che il restart non ha lasciato risorse in stato intermedio.

## 3.2 Monitoring, alerting e osservabilita

Questa area copre il lavoro day-2 piu frequente:
- controllare incidenti ed eventi;
- riconoscere subito saturazione CPU, memoria, I/O, FRA, tablespace;
- accorgersi di job falliti, lag DG o target down.

Attivita tipiche:
- review dashboard EM;
- review alert log e trace rilevanti;
- controllo metriche host e database;
- verifica che collection e job di monitoraggio siano sani;
- tuning soglie e notifiche.

Nel tuo repo:
- [GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md](../GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md)
- [GUIDA_COMANDI_DBA.md](../GUIDA_COMANDI_DBA.md)

## 3.3 Backup, restore test e recovery readiness

Questa e una responsabilita primaria del DBA. Oracle lo esplicita: il backup administrator deve definire, implementare e gestire la strategia di backup e recovery.

Attivita tipiche:
- verifica esito backup RMAN;
- controllo retention, crosscheck, delete obsolete;
- `RESTORE VALIDATE` e prove di recovery;
- controllo backup controlfile, spfile, archivelog;
- test restore su host alternativo o drill controllato.

Segnali di maturita:
- backup presenti non basta;
- serve prova periodica di restore;
- RPO/RTO devono essere esplicitati e verificati.

Nel tuo repo:
- [GUIDA_FASE5_RMAN_BACKUP.md](../GUIDA_FASE5_RMAN_BACKUP.md)
- [GUIDA_RMAN_COMPLETA_19C.md](../GUIDA_RMAN_COMPLETA_19C.md)

## 3.4 Performance e tuning

Il DBA non "ottimizza tutto sempre": deve prima capire dove il database perde tempo.

Attivita tipiche:
- review AWR;
- review ADDM;
- analisi ASH per incidenti brevi;
- top SQL per elapsed time, CPU, I/O;
- wait events e sessioni attive;
- verifica statistiche, piani SQL, regressioni post-change.

In RAC serve anche guardare:
- sessioni cross-instance;
- carico per istanza;
- eventuali squilibri di servizi o contention GCS/GES.

Nel tuo repo:
- [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md)
- [GUIDA_COMANDI_DBA.md](../GUIDA_COMANDI_DBA.md)
- [TOP_100_SCRIPT_DBA.md](../TOP_100_SCRIPT_DBA.md)

## 3.5 Storage, tablespace, ASM e capacity planning

Un DBA deve evitare due incidenti classici:
- tablespace piena;
- FRA/ASM saturi.

Attivita tipiche:
- monitor tablespace e autoextend;
- monitor FRA usage;
- monitor ASM disk group usage e rebalance;
- previsione crescita dati;
- aggiunta datafile o dischi prima che la soglia critica sia raggiunta.

Output minimo:
- trend crescita per settimana/mese;
- top consumers;
- soglie operative condivise.

Nel tuo repo:
- [GUIDA_COMANDI_DBA.md](../GUIDA_COMANDI_DBA.md)
- [GUIDA_AGGIUNTA_DISCHI_ASM.md](../GUIDA_AGGIUNTA_DISCHI_ASM.md)

## 3.6 Security, account lifecycle e auditing

Questa area non e solo creare utenti.

Attivita tipiche:
- creare/modificare utenti e ruoli;
- review privilegi e grant eccessivi;
- controllo account scaduti, bloccati, orfani;
- gestione wallet/TDE;
- review auditing e accessi amministrativi;
- applicare least privilege usando `SYSBACKUP`, `SYSDG`, `SYSKM` quando possibile al posto di `SYSDBA`.

Controlli chiave:
- privilegio `ANY` assegnato solo se giustificato;
- directory object e Data Pump roles sotto controllo;
- audit e evidenze accessibili.

Nel tuo repo:
- [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md)
- [GUIDA_CDB_PDB_UTENTI.md](../GUIDA_CDB_PDB_UTENTI.md)

## 3.7 Scheduler, batch e manutenzione automatica

Molti incidenti arrivano da job che smettono di girare o girano troppo.

Attivita tipiche:
- review `DBA_SCHEDULER_JOBS`, `DBA_SCHEDULER_JOB_RUN_DETAILS`, job failures;
- verifica finestre di manutenzione;
- review chains, programs, credentials;
- controllo job bloccati, in loop o troppo lenti;
- purging log scheduler quando necessario.

Nel tuo repo:
- [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md)

## 3.8 HA/DR: RAC, Data Guard, switchover, failover

In ambienti come il tuo, il DBA deve sapere:
- se RAC e sano;
- se Data Guard spedisce e applica redo senza gap;
- quale protection mode e attivo;
- se switchover/failover sono pronti.

Attivita tipiche:
- review `SHOW CONFIGURATION` in DGMGRL;
- monitor transport/apply lag;
- review `Protection Mode` e `LogXptMode`;
- test switchover pianificato;
- drill di failover e reinstate nel lab;
- verifica che backup e monitoraggio continuino dopo role transition.

Nel tuo repo:
- [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../GUIDA_FASE4_DATAGUARD_DGMGRL.md)
- [GUIDA_SWITCHOVER_COMPLETO.md](../GUIDA_SWITCHOVER_COMPLETO.md)
- [GUIDA_FAILOVER_E_REINSTATE.md](../GUIDA_FAILOVER_E_REINSTATE.md)

## 3.9 Listener, SCAN, services e connettivita

Questa area copre tutti i problemi tipo:
- `ORA-12514`
- `TNS:no listener`
- servizi non registrati
- failover service placement incoerente

Attivita tipiche:
- verifica `lsnrctl status`;
- verifica `srvctl config service` e `srvctl status service`;
- controllo SCAN e risoluzione DNS;
- review listener statici per Data Guard / RMAN;
- relocate di servizi per manutenzione o bilanciamento.

Nel tuo repo:
- [GUIDA_LISTENER_SERVICES_DBA.md](../GUIDA_LISTENER_SERVICES_DBA.md)

## 3.10 Multitenant: CDB/PDB lifecycle

In 19c questa area e parte integrante del lavoro DBA.

Attivita tipiche:
- aprire/chiudere PDB;
- creare o clonare PDB;
- plug/unplug;
- verificare utenti comuni e locali;
- gestire servizi PDB;
- controllare stato e monitoraggio per singola PDB.

Nel tuo repo:
- [GUIDA_CDB_PDB_UTENTI.md](../GUIDA_CDB_PDB_UTENTI.md)

## 3.11 Data movement: Data Pump, clone, refresh

Questa area copre richieste operative e di progetto:
- refresh ambienti di test;
- export schema o full;
- import con remap;
- clone con RMAN;
- duplicate for standby o clone.

Attivita tipiche:
- `expdp` / `impdp`;
- export selettivi per schema/tabella;
- import con `REMAP_SCHEMA`, `REMAP_TABLESPACE`;
- clone/duplicate per test;
- controllo compatibilita versioni e privilegi.

Nel tuo repo:
- [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md)
- [GUIDA_RMAN_COMPLETA_19C.md](../GUIDA_RMAN_COMPLETA_19C.md)

## 3.12 Patching, upgrade e software lifecycle

Questa e una delle aree piu sensibili del lavoro DBA.

Attivita tipiche:
- verifica inventario patch;
- aggiornamento OPatch;
- pre-check e backup home;
- applicazione RU/OJVM;
- review invalid objects e datapatch dove previsto;
- rollback plan;
- verifica servizi e performance post-change.

Per RAC/Data Guard il DBA deve anche:
- mantenere ordine rolling quando possibile;
- allineare grid home, db home, standby e tooling;
- documentare baseline prima e dopo.

Nel tuo repo:
- [GUIDA_PATCHING_RAC.md](../GUIDA_PATCHING_RAC.md)
- [GUIDA_UPGRADE_RU_RAC.md](../GUIDA_UPGRADE_RU_RAC.md)

## 3.13 Documentazione, evidenze e change management

Questa parte viene spesso sottovalutata, ma distingue un DBA improvvisato da uno affidabile.

Attivita tipiche:
- mantenere runbook aggiornati;
- tenere evidenze di backup test, switchover test, patching, failover drill;
- annotare parametri cambiati;
- mantenere checklist pre/post change;
- registrare rischi, rollback plan, owner e finestra.

Nel lab puoi allenarla con:
- test log GoldenGate;
- checklist RMAN;
- note di role transition e patching.

## 4. Vista per frequenza

### Giornaliero

- availability check database, listener, servizi, cluster
- alert log e incidenti EM
- job batch e scheduler failures
- backup ultimo ciclo
- DG lag / status broker
- tablespace, FRA, ASM usage
- top wait o blocchi se ci sono ticket aperti

### Settimanale

- review AWR/ADDM
- `RESTORE VALIDATE`
- review crescita storage
- review utenti e grant anomali
- review scheduler jobs e log retention
- review GG lag / errori se in uso

### Mensile

- patch review e backlog RU
- capacity planning
- audit di sicurezza e account review
- test operativo di servizi / relocate / restart controllato
- review soglie EM e incident rules

### Trimestrale

- switchover drill
- restore drill o clone su host alternativo
- failover/reinstate in lab
- review completa runbook e documentazione

## 5. Mappa rapida: cosa sai fare davvero quando questa guida e "completa"

Se padroneggi questa cartella, devi saper fare almeno questo:

1. capire in pochi minuti se il tuo ambiente e sano o no;
2. dimostrare che i backup non solo esistono ma sono ripristinabili;
3. trovare il perche di lag, lock, top SQL e crescita storage;
4. gestire utenti, privilegi e auditing senza abusare di `SYSDBA`;
5. fare switchover/failover controllati e capire l'impatto del protection mode;
6. gestire listener, services, SCAN e troubleshoot TNS;
7. fare patching con pre-check, post-check e rollback plan;
8. gestire PDB, Data Pump e refresh ambienti.

## 6. Fonti Oracle ufficiali consultate

- Oracle Database 19c Administration landing page:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/administration.html
- Oracle Database Administrator's Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/admin.pdf
- Oracle Database Backup and Recovery User's Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/
- Oracle Database Performance Tuning Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/database-performance-tuning-guide.pdf
- Oracle Data Guard Concepts and Administration 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/data-guard-concepts-and-administration.pdf
- Oracle RAC Administration and Deployment Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/
- Oracle Multitenant Administrator's Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/managing-a-multitenant-environment.html
- Oracle Data Pump Export Utility 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/sutil/oracle-data-pump-export-utility.html
- Oracle Security Guide 19c:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/keeping-your-oracle-database-secure.html
- Oracle Scheduler administration:
  https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/administering-oracle-scheduler.html
- Oracle Enterprise Manager Cloud Control Administrator's Guide 13.5:
  https://docs.oracle.com/en/enterprise-manager/cloud-control/enterprise-manager-cloud-control/13.5/emadm/index.html
