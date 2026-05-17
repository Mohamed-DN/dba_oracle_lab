# GoldenGate 19c - Prerequisiti DB e Architettura

> Guida rapida ma completa dei prerequisiti che devono essere chiusi prima di configurare Extract, Pump/Distribution e Replicat. Per il manuale completo vedi [GUIDA_GOLDENGATE_19C_COMPLETA.md](./GUIDA_GOLDENGATE_19C_COMPLETA.md).

---

## 1. Architettura minima

```text
Oracle Source -> Extract -> Local Trail -> Pump/Distribution -> Remote Trail -> Replicat -> Target
```

GoldenGate e' una pipeline transazionale. Se una parte non e' pronta, la replica diventa fragile:

- source logging incompleto = update/delete non ricostruibili;
- archive retention insufficiente = Extract non puo' ripartire;
- target senza chiavi = Replicat fragile;
- password in chiaro = rischio sicurezza;
- trail senza purge = filesystem pieno.

---

## 2. Parametri Oracle 19c obbligatori

```sql
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
ALTER DATABASE FORCE LOGGING;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

Verifica:

```sql
SELECT force_logging,
       supplemental_log_data_min,
       supplemental_log_data_pk,
       supplemental_log_data_ui
FROM   v$database;

SELECT inst_id, value
FROM   gv$parameter
WHERE  name = 'enable_goldengate_replication';
```

In RAC il parametro deve essere coerente su tutte le istanze.

---

## 3. Supplemental logging operativo

Da GoldenGate:

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
ADD SCHEMATRANDATA APP
INFO SCHEMATRANDATA APP
```

Per tabella singola:

```text
ADD TRANDATA APP.ORDERS
INFO TRANDATA APP.ORDERS
```

Per active-active/conflict detection:

```text
ADD TRANDATA APP.ORDERS ALLCOLS
```

Scelta:

| Caso | Scelta |
| --- | --- |
| Schema intero | `ADD SCHEMATRANDATA` |
| Tabelle selezionate | `ADD TRANDATA` |
| Active-active | `ALLCOLS` dopo valutazione redo |
| Nessuna PK | aggiungere PK o usare `KEYCOLS` con cautela |

---

## 4. Utente GGADMIN least privilege

Common user CDB:

```sql
CREATE USER c##ggadmin IDENTIFIED BY "<PASSWORD_SICURA>" CONTAINER=ALL;
GRANT CREATE SESSION TO c##ggadmin CONTAINER=ALL;
GRANT CREATE VIEW TO c##ggadmin CONTAINER=ALL;
GRANT ALTER SYSTEM TO c##ggadmin CONTAINER=ALL;
GRANT ALTER USER TO c##ggadmin CONTAINER=ALL;
ALTER USER c##ggadmin QUOTA UNLIMITED ON USERS CONTAINER=ALL;
ALTER USER c##ggadmin SET CONTAINER_DATA=ALL CONTAINER=CURRENT;

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'C##GGADMIN',
    privilege_type          => '*',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'ALL');
END;
/
```

Local PDB:

```sql
ALTER SESSION SET CONTAINER = PDB1;
CREATE USER ggadmin IDENTIFIED BY "<PASSWORD_SICURA>" DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION TO ggadmin;
GRANT CREATE VIEW TO ggadmin;

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE('GGADMIN');
END;
/
```

Importante: questi grant preparano l'utente GoldenGate, ma **Replicat deve anche poter applicare DML** sulle tabelle target. In produzione preferire grant oggetto per oggetto:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.CUSTOMERS TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.ORDERS TO ggadmin;
```

Per migrazioni estese si possono usare privilegi `ANY`, ma solo con approvazione security e piano di revoca:

```sql
GRANT SELECT ANY TABLE TO ggadmin;
GRANT INSERT ANY TABLE TO ggadmin;
GRANT UPDATE ANY TABLE TO ggadmin;
GRANT DELETE ANY TABLE TO ggadmin;
```

Dettaglio completo: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

---

## 5. FRA e archive retention

Formula base:

```text
spazio_minimo = redo_per_ora * ore_outage_extract * 1.5
```

Query redo rate:

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') ora,
       ROUND(SUM(blocks*block_size)/1024/1024/1024,2) redo_gb
FROM   v$archived_log
WHERE  first_time > SYSDATE - 7
GROUP  BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER  BY ora;
```

Query FRA:

```sql
SELECT name,
       ROUND(space_used*100/space_limit,2) pct_used
FROM   v$recovery_file_dest;
```

Regola: se Extract e' fermo, non cancellare archivelog necessari senza sapere il checkpoint.

---

## 6. Gate prima della configurazione

- [ ] Source in ARCHIVELOG.
- [ ] `enable_goldengate_replication=TRUE`.
- [ ] `FORCE LOGGING` attivo.
- [ ] Supplemental logging minimo attivo.
- [ ] `SCHEMATRANDATA` o `TRANDATA` attivo sugli oggetti.
- [ ] Tabelle con PK/unique key.
- [ ] `GGADMIN` creato e testato.
- [ ] Credential store previsto.
- [ ] FRA dimensionata.
- [ ] Trail filesystem dimensionato.
- [ ] Monitoring lag/FRA pronto.

---

## 7. Fonti ufficiali

- Preparing Database for GoldenGate: https://docs.oracle.com/en/middleware/goldengate/core/19.1/oracle-db/preparing-database-oracle-goldengate.html
- ENABLE_GOLDENGATE_REPLICATION: https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/ENABLE_GOLDENGATE_REPLICATION.html
- DBMS_GOLDENGATE_AUTH: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_GOLDENGATE_AUTH.html
- Grant e privilegi GoldenGate 19c nel lab: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md)

## Obiettivo
Definire lo scopo operativo della procedura e il risultato atteso.

## Procedura operativa
Eseguire i passaggi descritti nella guida in ordine, verificando prerequisiti e output a ogni step.

## Validazione finale
Confermare che replica, integrità dati e stato processi siano allineati ai criteri attesi.

## Troubleshooting rapido
In caso di errore, verificare log Extract/Replicat, connettività, permessi e checkpoint, quindi rieseguire la validazione.
