# Oracle GoldenGate 19c - Classic Architecture e GGSCI

> Guida operativa per GoldenGate Classic Architecture. Anche se Microservices e' lo standard moderno, Classic e `ggsci` sono ancora molto presenti in ambienti enterprise esistenti e sono fondamentali per troubleshooting e colloqui tecnici.

---

## 1. Architettura Classic

```text
SOURCE HOST                                                   TARGET HOST
========================================================      ======================================

Oracle Redo/Archive
      |
      v
+----------------+       +-------------+      TCP       +-------------+       +----------------+
| Extract EXT1   | ----> | Local Trail | -------------> | Remote Trail| ----> | Replicat REP1  |
| Integrated     |       | ./dirdat/ea |                | ./dirdat/rt |       | Integrated     |
+----------------+       +-------------+                +-------------+       +----------------+
                              ^                                ^
                              |                                |
                         +---------+                      +---------+
                         | Manager |                      | Manager |
                         +---------+                      +---------+

Optional:
Extract EXT1 -> Local Trail -> Data Pump PUMP1 -> Collector/Manager -> Remote Trail -> Replicat
```

Componenti:

| Componente | Processo | Ruolo |
| --- | --- | --- |
| Manager | `mgr` | Processo padre, porte, purge, gestione processi |
| Extract | `extract` | Cattura dal redo/source |
| Data Pump | `extract` secondario | Spedisce trail al target |
| Collector | avviato dal Manager target | Riceve trail remoti |
| Replicat | `replicat` | Applica sul target |
| GGSCI | `ggsci` | CLI di amministrazione Classic |

---

## 2. Directory Classic

Dopo `CREATE SUBDIRS`:

| Directory | Uso |
| --- | --- |
| `dirprm` | parameter file |
| `dirdat` | trail file |
| `dirrpt` | report file |
| `dirchk` | checkpoint |
| `dirpcs` | process status |
| `dirsql` | script SQL |
| `dirdef` | definition file |
| `dircrd` | credential store |

Setup:

```bash
export OGG_HOME=/u01/app/oracle/product/ogg19c_classic
export PATH=$OGG_HOME:$PATH
cd $OGG_HOME
./ggsci
```

```text
GGSCI> CREATE SUBDIRS
GGSCI> INFO ALL
```

---

## 3. Manager

Parameter file `dirprm/mgr.prm`:

```text
PORT 7809
DYNAMICPORTLIST 7810-7820
AUTOSTART ER *
AUTORESTART ER *, RETRIES 5, WAITMINUTES 2, RESETMINUTES 60
PURGEOLDEXTRACTS ./dirdat/*, USECHECKPOINTS, MINKEEPDAYS 3
LAGREPORTMINUTES 5
LAGINFOMINUTES 10
LAGCRITICALMINUTES 30
```

Comandi:

```text
GGSCI> START MANAGER
GGSCI> INFO MANAGER
GGSCI> SEND MANAGER STATUS
GGSCI> STOP MANAGER
```

Note:

- `PURGEOLDEXTRACTS` deve usare `USECHECKPOINTS`.
- Non cancellare trail manualmente.
- `AUTORESTART` aiuta ma non sostituisce monitoring.

---

## 4. Credential store Classic

```text
GGSCI> ADD CREDENTIALSTORE
GGSCI> ALTER CREDENTIALSTORE ADD USER c##ggadmin@RACDB PASSWORD <PASSWORD_DB> ALIAS ggsrc DOMAIN OracleGoldenGate
GGSCI> ALTER CREDENTIALSTORE ADD USER ggadmin@DBTARGET PASSWORD <PASSWORD_DB> ALIAS ggtgt DOMAIN OracleGoldenGate
GGSCI> INFO CREDENTIALSTORE
```

Uso nei param file:

```text
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
```

Non usare:

```text
USERID ggadmin, PASSWORD password_in_chiaro
```

---

## 5. Integrated Extract Classic

Login DB e register:

```text
GGSCI> DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
GGSCI> REGISTER EXTRACT ext_rac DATABASE
```

Crea Extract:

```text
GGSCI> ADD EXTRACT ext_rac, INTEGRATED TRANLOG, BEGIN NOW
GGSCI> ADD EXTTRAIL ./dirdat/ea, EXTRACT ext_rac, MEGABYTES 200
```

Parameter file `dirprm/ext_rac.prm`:

```text
EXTRACT ext_rac
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
EXTTRAIL ./dirdat/ea
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT
REPORTCOUNT EVERY 5 MINUTES, RATE
WARNLONGTRANS 1H, CHECKINTERVAL 10M
TABLE HR.*;
TABLE APP.*;
```

Start/verifica:

```text
GGSCI> START EXTRACT ext_rac
GGSCI> INFO EXTRACT ext_rac, DETAIL
GGSCI> LAG EXTRACT ext_rac
GGSCI> SEND EXTRACT ext_rac, STATUS
GGSCI> VIEW REPORT ext_rac
```

---

## 6. Data Pump Classic

Data Pump e' un Extract che legge local trail e spedisce remote trail.

```text
GGSCI> ADD EXTRACT pump_rac, EXTTRAILSOURCE ./dirdat/ea
GGSCI> ADD RMTTRAIL ./dirdat/rt, EXTRACT pump_rac, MEGABYTES 200
```

Parameter file `dirprm/pump_rac.prm`:

```text
EXTRACT pump_rac
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
RMTHOST dbtarget.localdomain, MGRPORT 7809
RMTTRAIL ./dirdat/rt
PASSTHRU
TABLE HR.*;
TABLE APP.*;
```

Start/verifica:

```text
GGSCI> START EXTRACT pump_rac
GGSCI> INFO EXTRACT pump_rac, DETAIL
GGSCI> LAG EXTRACT pump_rac
GGSCI> VIEW REPORT pump_rac
```

Se `pump_rac` fallisce:

- Manager target non attivo;
- porta 7809 bloccata;
- filesystem target pieno;
- path remote trail errato.

---

## 7. Integrated Replicat Classic

Prima di creare Replicat, assicurati che l'utente target abbia sia i privilegi GoldenGate (`DBMS_GOLDENGATE_AUTH` con `APPLY` o `*`) sia i grant DML sulle tabelle target. Dettaglio completo: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

Checkpoint table:

```text
GGSCI> DBLOGIN USERIDALIAS ggtgt DOMAIN OracleGoldenGate
GGSCI> ADD CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
```

Crea Replicat:

```text
GGSCI> ADD REPLICAT rep_tgt, INTEGRATED, EXTTRAIL ./dirdat/rt, CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
```

Parameter file `dirprm/rep_tgt.prm`:

```text
REPLICAT rep_tgt
USERIDALIAS ggtgt DOMAIN OracleGoldenGate
ASSUMETARGETDEFS
DISCARDFILE ./dirrpt/rep_tgt.dsc, APPEND, MEGABYTES 500
REPORTCOUNT EVERY 5 MINUTES, RATE
BATCHSQL
MAP HR.*, TARGET HR.*;
MAP APP.*, TARGET APP.*;
```

Start:

```text
GGSCI> START REPLICAT rep_tgt
GGSCI> INFO REPLICAT rep_tgt, DETAIL
GGSCI> LAG REPLICAT rep_tgt
GGSCI> STATS REPLICAT rep_tgt, TOTAL
```

---

## 8. Initial load in Classic

Pattern SCN:

```sql
SELECT current_scn FROM v$database;
```

Export source:

```bash
expdp system/<PASSWORD> schemas=HR,APP directory=DATA_PUMP_DIR dumpfile=ogg_init_%U.dmp logfile=ogg_init_exp.log flashback_scn=123456789 parallel=4
```

Import target:

```bash
impdp system/<PASSWORD> schemas=HR,APP directory=DATA_PUMP_DIR dumpfile=ogg_init_%U.dmp logfile=ogg_init_imp.log parallel=4
```

Start Replicat da SCN:

```text
GGSCI> START REPLICAT rep_tgt, AFTERCSN 123456789
```

---

## 9. Comandi GGSCI essenziali

Processi:

```text
INFO ALL
INFO EXTRACT ext_rac, DETAIL
INFO REPLICAT rep_tgt, DETAIL
STATUS EXTRACT ext_rac
STATUS REPLICAT rep_tgt
START EXTRACT ext_rac
STOP EXTRACT ext_rac
START REPLICAT rep_tgt
STOP REPLICAT rep_tgt
KILL EXTRACT ext_rac
KILL REPLICAT rep_tgt
```

Lag e statistiche:

```text
LAG EXTRACT ext_rac
LAG REPLICAT rep_tgt
STATS EXTRACT ext_rac, TOTAL
STATS REPLICAT rep_tgt, TOTAL
SEND EXTRACT ext_rac, STATUS
SEND REPLICAT rep_tgt, STATUS
```

Report:

```text
VIEW REPORT ext_rac
VIEW REPORT pump_rac
VIEW REPORT rep_tgt
VIEW GGSEVT
```

Parametri:

```text
EDIT PARAMS mgr
EDIT PARAMS ext_rac
EDIT PARAMS pump_rac
EDIT PARAMS rep_tgt
VIEW PARAMS ext_rac
```

Supplemental logging:

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
ADD SCHEMATRANDATA HR
INFO SCHEMATRANDATA HR
ADD TRANDATA HR.EMPLOYEES
INFO TRANDATA HR.EMPLOYEES
```

---

## 10. Reposition e recovery

Usare con cautela: cambia il punto da cui GoldenGate legge/applica.

Extract:

```text
ALTER EXTRACT ext_rac, SCN 123456789
ALTER EXTRACT ext_rac, BEGIN NOW
```

Replicat:

```text
ALTER REPLICAT rep_tgt, EXTSEQNO 12, EXTRBA 34567
START REPLICAT rep_tgt
```

Quando serve:

- restore archivelog impossibile;
- re-instanziazione target parziale;
- riallineamento dopo errore controllato.

Rischio:

- data loss logica;
- duplicati;
- target inconsistente.

Prima di farlo in produzione: fermare processi, salvare report, concordare SCN, documentare rollback.

---

## 11. Troubleshooting Classic

| Errore | Lettura pratica |
| --- | --- |
| `OGG-01296` | problema DB login/privilegi |
| `OGG-00446` | Extract/Replicat non riesce a proseguire |
| `OGG-01028` | problemi checkpoint/trail |
| `ORA-01291` | archive log mancante |
| `ORA-01031` | privilegi insufficienti |
| `ORA-00001` | duplicato su target, spesso initial load/start SCN errato |
| `ORA-02291` | FK violata, ordine/mapping/dati mancanti |

Metodo:

1. `INFO ALL`.
2. `VIEW REPORT processo`.
3. controlla discard file.
4. controlla alert log DB.
5. controlla spazio `dirdat` e FRA.
6. correggi root cause.
7. riparti con `START`, non con `ALTER` se non necessario.

---

## 12. Quando usare Classic oggi

Usalo per:

- ambienti gia esistenti;
- troubleshooting con team legacy;
- migrazioni dove il cliente ha standard Classic;
- esercitarti con `ggsci`, ancora molto chiesto.

Non sceglierlo come default per nuove architetture se puoi usare Microservices.

---

## 13. Fonti ufficiali

- Oracle GoldenGate GGSCI Commands: https://docs.oracle.com/en/middleware/goldengate/core/18.1/reference/oracle-goldengate-ggsci-commands.html
- Oracle GoldenGate Classic Documentation: https://docs.oracle.com/en/middleware/goldengate/core/19.1/ggcab/oracle-goldengate-classic-architecture.pdf
- Process interfaces: https://docs.oracle.com/en/middleware/goldengate/core/18.1/admin/getting-started-oracle-goldengate-process-interfaces.html

## Obiettivo
Definire lo scopo operativo della procedura e il risultato atteso.

## Procedura operativa
Eseguire i passaggi descritti nella guida in ordine, verificando prerequisiti e output a ogni step.

## Validazione finale
Confermare che replica, integrità dati e stato processi siano allineati ai criteri attesi.

## Troubleshooting rapido
In caso di errore, verificare log Extract/Replicat, connettività, permessi e checkpoint, quindi rieseguire la validazione.
