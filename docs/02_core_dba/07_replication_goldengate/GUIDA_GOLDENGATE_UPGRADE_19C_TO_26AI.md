# Oracle GoldenGate - Upgrade e Migrazione da 19c a 26ai

> Guida per pianificare un upgrade GoldenGate 19c -> 26ai. Il principio e' semplice: prima proteggi configurazione e dati di replica, poi aggiorni software/deployment, poi validi end-to-end. Non trattare GoldenGate come un semplice pacchetto da sostituire.

---

## 1. Regole chiave

- Per **Microservices Architecture**, Oracle documenta upgrade diretto da 19c o 21c MA a 26ai.
- Per **Classic Architecture**, devi pianificare conversione/modernizzazione verso Microservices 26ai.
- Non mischiare comandi Classic e MA nello stesso runbook.
- Prima dell'upgrade, devi poter tornare indietro.
- Non fare upgrade senza certificazioni source/target/OS.

---

## 2. Mappa decisionale

```text
Se installazione attuale = GoldenGate 19c Microservices
    -> backup completo deployment
    -> install 26ai home
    -> upgrade deployment MA
    -> validazione processi

Se installazione attuale = GoldenGate 19c Classic
    -> stabilizza Classic
    -> backup OGG_HOME/dirprm/dirdat/dirchk/wallet
    -> valuta conversione a MA
    -> poi upgrade/modernizzazione verso 26ai

Se installazione attuale < 19c Classic
    -> prima upgrade a Classic 19c/21c supportato
    -> poi conversione MA/26ai
```

---

## 3. Pre-check certificazioni

Controlla:

- versione GoldenGate sorgente;
- versione DB source e target;
- OS;
- architettura CPU;
- database character set;
- source/target eterogenei;
- uso di Classic o MA;
- funzionalita speciali: DDL replication, CDR, parallel Replicat, Kafka/PostgreSQL, TDE.

Tabella:

| Check | Comando / Fonte |
| --- | --- |
| Versione OGG | `ggsci VERSION` oppure `adminclient -version` |
| DB version | `SELECT * FROM v$version;` |
| Parametri GG | parameter file / Admin Server |
| Certificazioni | Oracle GoldenGate Certifications |
| Trail backlog | `INFO ALL`, filesystem `dirdat` |
| Archive/FRA | `v$recovery_file_dest`, `v$archived_log` |

---

## 4. Backup obbligatorio

### 4.1 Microservices

Backup minimo:

```bash
export TS=$(date +%Y%m%d_%H%M)
mkdir -p /u01/app/oracle/ogg_backup/$TS

tar czf /u01/app/oracle/ogg_backup/$TS/ogg_home_19c.tgz /u01/app/oracle/product/ogg19c_ma

tar czf /u01/app/oracle/ogg_backup/$TS/ogg_deployments.tgz /u01/app/oracle/ogg_deployments

tar czf /u01/app/oracle/ogg_backup/$TS/ogg_var.tgz /u01/app/oracle/ogg_var
```

Salva anche:

- deployment wallet;
- credential store;
- TLS certificates;
- parameter files;
- trail file attivi;
- response file installazione;
- porte e firewall.

### 4.2 Classic

```bash
export TS=$(date +%Y%m%d_%H%M)
mkdir -p /u01/app/oracle/ogg_backup/$TS
cd $OGG_HOME

tar czf /u01/app/oracle/ogg_backup/$TS/classic_ogg_home.tgz .
tar czf /u01/app/oracle/ogg_backup/$TS/classic_params.tgz dirprm GLOBALS
tar czf /u01/app/oracle/ogg_backup/$TS/classic_checkpoints.tgz dirchk
tar czf /u01/app/oracle/ogg_backup/$TS/classic_wallets.tgz dircrd 2>/dev/null || true
```

Non basta salvare `dirprm`: senza checkpoint e trail potresti non poter ripartire dallo stesso punto.

---

## 5. Export stato operativo

Classic:

```text
GGSCI> INFO ALL
GGSCI> INFO EXTRACT *, DETAIL
GGSCI> INFO REPLICAT *, DETAIL
GGSCI> SEND EXTRACT ext_rac, STATUS
GGSCI> SEND REPLICAT rep_tgt, STATUS
GGSCI> LAG EXTRACT ext_rac
GGSCI> LAG REPLICAT rep_tgt
```

Microservices:

```text
Admin Client> INFO EXTRACT *
Admin Client> INFO REPLICAT *
Admin Client> INFO DISTPATH *
Admin Client> LAG EXTRACT ext_rac
Admin Client> LAG REPLICAT rep_tgt
```

OS:

```bash
df -h
find $OGG_HOME -maxdepth 2 -type f -name "*.prm" -print
find /u01/app/oracle/ogg_deployments -type f -name "*.rpt" -mtime -2 -print
```

DB:

```sql
SELECT name, database_role, open_mode FROM v$database;
SELECT force_logging, supplemental_log_data_min FROM v$database;
SELECT name, value FROM v$parameter WHERE name='enable_goldengate_replication';
```

---

## 6. Stop controllato

Obiettivo: fermare senza perdere checkpoint.

Classic:

```text
GGSCI> STOP EXTRACT pump_rac
GGSCI> STOP EXTRACT ext_rac
GGSCI> STOP REPLICAT rep_tgt
GGSCI> INFO ALL
```

Microservices:

```text
Admin Client> STOP DISTPATH path_rac_tgt
Admin Client> STOP EXTRACT ext_rac
Admin Client> STOP REPLICAT rep_tgt
Admin Client> INFO EXTRACT *
Admin Client> INFO REPLICAT *
```

Se e' una migrazione zero downtime, potresti non fermare subito tutti i processi: devi seguire il runbook Oracle/MA specifico. In lab, fermare tutto e' piu semplice.

---

## 7. Upgrade Microservices 19c -> 26ai

Flusso concettuale:

1. Installa nuovo `OGG_HOME` 26ai separato.
2. Non sovrascrivere home 19c.
3. Esegui upgrade deployment secondo documentazione Oracle.
4. Valida Service Manager e servizi.
5. Avvia processi uno per volta.
6. Controlla lag e apply.

Esempio layout:

```bash
/u01/app/oracle/product/ogg19c_ma
/u01/app/oracle/product/ogg26ai_ma
/u01/app/oracle/ogg_deployments/SourceDeploy
/u01/app/oracle/ogg_deployments/TargetDeploy
```

Verifiche post-upgrade:

```bash
/u01/app/oracle/product/ogg26ai_ma/bin/adminclient -version
```

```text
CONNECT http://host:9012 DEPLOYMENT SourceDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
INFO EXTRACT *
INFO DISTPATH *
```

Target:

```text
CONNECT http://target:9012 DEPLOYMENT TargetDeploy AS oggadmin PASSWORD <PASSWORD_DEPLOYMENT>
INFO REPLICAT *
LAG REPLICAT rep_tgt
```

---

## 8. Classic 19c -> 26ai

Classic non va trattato come upgrade diretto equivalente a MA. Strategia professionale:

1. Stabilizza Classic 19c.
2. Documenta tutti i processi `ggsci`.
3. Esporta param file e checkpoint.
4. Disegna architettura equivalente MA.
5. Crea deployment MA.
6. Ricrea credential store.
7. Ricrea Extract/Distribution/Receiver/Replicat.
8. Testa su copia/lab.
9. Esegui cutover controllato.

Mappatura concettuale:

| Classic | Microservices / 26ai |
| --- | --- |
| Manager | Service Manager |
| GGSCI | Admin Client / Web UI / REST |
| Extract | Extract gestito da Admin Server |
| Data Pump | Distribution Path |
| Collector | Receiver Server |
| Replicat | Replicat gestito da Admin Server |
| `dirprm/*.prm` | config deployment / param file MA |

---

## 9. Rollback plan

Rollback minimo:

- fermare processi 26ai;
- ripristinare home/deployment 19c;
- ripristinare wallet/credential store;
- ripristinare param file;
- ripartire da checkpoint precedente;
- verificare trail disponibili;
- verificare source/target consistency.

Runbook rollback Microservices:

```bash
# fermare servizi 26ai secondo setup systemd/Service Manager
# ripristinare backup deployment 19c
# ripristinare OGG_HOME 19c se necessario
```

Poi:

```text
Admin Client 19c> INFO EXTRACT *
Admin Client 19c> START EXTRACT ext_rac
Admin Client 19c> START DISTPATH path_rac_tgt
Admin Client 19c> START REPLICAT rep_tgt
```

Rollback Classic:

```text
GGSCI> INFO ALL
GGSCI> START MANAGER
GGSCI> START EXTRACT ext_rac
GGSCI> START EXTRACT pump_rac
GGSCI> START REPLICAT rep_tgt
```

Se i trail sono stati modificati/cancellati, il rollback potrebbe richiedere re-instanziazione.

---

## 10. Validazione post-upgrade

### 10.1 Test tecnico

Source:

```sql
INSERT INTO hr.ogg_test(id, descrizione, data_creazione)
VALUES (1001, 'test post upgrade', SYSDATE);
COMMIT;

UPDATE hr.ogg_test
SET descrizione = 'test update post upgrade'
WHERE id = 1001;
COMMIT;

DELETE FROM hr.ogg_test WHERE id = 1001;
COMMIT;
```

Target:

```sql
SELECT * FROM hr.ogg_test WHERE id = 1001;
```

### 10.2 Test lag

```text
LAG EXTRACT ext_rac
LAG REPLICAT rep_tgt
STATS EXTRACT ext_rac, TOTAL
STATS REPLICAT rep_tgt, TOTAL
```

### 10.3 Test restart

- stop/start Extract;
- stop/start Distribution Path o Pump;
- stop/start Replicat;
- verificare nessun duplicato e nessuna perdita.

---

## 11. Checklist produzione

- [ ] Certificazioni controllate.
- [ ] Backup OGG_HOME.
- [ ] Backup deployment.
- [ ] Backup wallet/credential store.
- [ ] Backup param file.
- [ ] Trail e checkpoint protetti.
- [ ] Stato processi esportato.
- [ ] FRA/archive sufficienti.
- [ ] Piano stop/start approvato.
- [ ] Piano rollback testato.
- [ ] Test in ambiente non-prod completato.
- [ ] Monitoring aggiornato.
- [ ] Documentazione operativa aggiornata.

---

## 12. Fonti ufficiali

- Oracle GoldenGate 26ai Upgrade: https://docs.oracle.com/en/database/goldengate/core/26/coredoc/upgrade-ma.html
- Oracle GoldenGate 26ai Docs: https://docs.oracle.com/en/database/goldengate/core/26/index.html
- Oracle GoldenGate 26ai Release Notes: https://docs.oracle.com/en/database/goldengate/core/26/release-notes/new-features.html
- Oracle GoldenGate Certifications: https://www.oracle.com/integration/goldengate/certifications/