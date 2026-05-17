# Oracle GoldenGate 19c - Replica Oracle verso PostgreSQL

> Guida per capire e progettare una replica/migrazione eterogenea Oracle -> PostgreSQL con GoldenGate. Non e' identica a Oracle -> Oracle: qui il lavoro DBA include datatype mapping, initial load coerente, gestione chiavi, differenze SQL e test applicativi.

---

## 1. Architettura logica

```text
Oracle 19c Source                         GoldenGate                           PostgreSQL Target
====================================      =================================     ============================

Redo / Archive Log
      |
      v
Integrated Extract -> Local Trail -> Distribution/Pump -> Remote Trail -> Replicat for PostgreSQL -> Tables
```

Obiettivo:

- catturare DML da Oracle;
- trasformare/mappare oggetti verso PostgreSQL;
- applicare sul target mantenendo ordine e consistenza transazionale dove supportato.

---

## 2. Casi d'uso

| Scenario | Descrizione |
| --- | --- |
| Migrazione | Spostare schema Oracle verso PostgreSQL con downtime ridotto |
| Reporting | Alimentare un target PostgreSQL per query/report |
| Modernizzazione | Preparare applicazione a uscire da Oracle |
| Coesistenza | Tenere due piattaforme sincronizzate temporaneamente |

Non e' ideale per:

- replica cieca di tutto il database;
- DDL complesso non testato;
- tabelle senza chiavi;
- carichi con datatype Oracle non mappabili facilmente.

---

## 3. Pre-check Oracle source

```sql
ALTER SYSTEM SET enable_goldengate_replication=TRUE SCOPE=BOTH SID='*';
ALTER DATABASE FORCE LOGGING;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

GoldenGate:

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
ADD SCHEMATRANDATA APP
INFO SCHEMATRANDATA APP
```

Tabelle senza PK:

```sql
SELECT owner, table_name
FROM   dba_tables t
WHERE  owner = 'APP'
AND    NOT EXISTS (
  SELECT 1
  FROM   dba_constraints c
  WHERE  c.owner = t.owner
  AND    c.table_name = t.table_name
  AND    c.constraint_type = 'P'
);
```

Correggere prima di replicare update/delete.

---

## 4. Pre-check PostgreSQL target

Controlli:

- schema creato;
- tabelle con PK coerenti;
- encoding compatibile (`UTF8` consigliato);
- timezone coerente;
- utente Replicat con privilegi INSERT/UPDATE/DELETE;
- connessione ODBC/libpq configurata secondo prodotto/versione GoldenGate usata;
- indici e constraint creati in modo controllato.

Esempio concettuale PostgreSQL:

```sql
CREATE USER ggadmin WITH PASSWORD '<PASSWORD_SICURA>';
GRANT CONNECT ON DATABASE appdb TO ggadmin;
\c appdb
CREATE SCHEMA app AUTHORIZATION ggadmin;
GRANT USAGE ON SCHEMA app TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO ggadmin;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ggadmin;
```

Se PostgreSQL e' source, non target, servono anche privilegi di replication slot:

```sql
ALTER USER ggadmin WITH REPLICATION;
```

Per abilitare `ADD TRANDATA` su PostgreSQL puo' servire un utente `SUPERUSER` o admin managed-cloud. In produzione concederlo solo temporaneamente e revocarlo subito dopo:

```sql
ALTER USER ggadmin WITH SUPERUSER;
-- configurazione TRANDATA
ALTER USER ggadmin WITH NOSUPERUSER;
```

Per Oracle source usa i grant completi descritti in [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

---

## 5. Datatype mapping

| Oracle | PostgreSQL | Nota |
| --- | --- | --- |
| `NUMBER(p,0)` | `numeric(p,0)` / `bigint` | scegliere in base a range |
| `NUMBER(p,s)` | `numeric(p,s)` | attenzione precisione |
| `VARCHAR2` | `varchar` / `text` | controllare length semantics |
| `DATE` | `timestamp` | Oracle DATE include ora |
| `TIMESTAMP WITH TIME ZONE` | `timestamptz` | normalizzare timezone |
| `CLOB` | `text` | testare dimensione e performance |
| `BLOB` | `bytea` | validare supporto e performance |
| `RAW` | `bytea` | mapping binario |
| `CHAR` | `char` | padding diverso da valutare |

Regola: fai sempre test con dati reali, non solo DDL vuoto.

---

## 6. Case sensitivity e naming

Oracle spesso usa nomi uppercase non quotati. PostgreSQL normalizza a lowercase se non usi doppi apici.

Scelta raccomandata:

- target PostgreSQL lowercase;
- mapping esplicito in GoldenGate;
- evitare oggetti con nomi quotati se non necessari.

Esempio mapping:

```text
MAP APP.CUSTOMERS, TARGET app.customers;
MAP APP.ORDERS, TARGET app.orders;
```

---

## 7. Initial load

Approccio:

1. prendi SCN source;
2. export consistente Oracle;
3. converti/carica dati su PostgreSQL;
4. avvia Replicat da SCN coerente.

SCN:

```sql
SELECT current_scn FROM v$database;
```

Export Oracle:

```bash
expdp system/<PASSWORD> schemas=APP directory=DATA_PUMP_DIR dumpfile=app_%U.dmp logfile=app_exp.log flashback_scn=123456789 parallel=4
```

Per PostgreSQL potresti usare strumenti intermedi:

- Data Pump + conversione;
- ora2pg;
- script ETL;
- GoldenGate initial load se disponibile nel tuo stack;
- dump CSV controllato.

L'importante e' non perdere lo SCN di consistenza.

---

## 8. Extract Oracle

Parameter file source:

```text
EXTRACT ext_pg
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
EXTTRAIL ep
LOGALLSUPCOLS
UPDATERECORDFORMAT COMPACT
REPORTCOUNT EVERY 5 MINUTES, RATE
TABLE APP.CUSTOMERS;
TABLE APP.ORDERS;
```

Comandi:

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
REGISTER EXTRACT ext_pg DATABASE
ADD EXTRACT ext_pg, INTEGRATED TRANLOG, BEGIN NOW
ADD EXTTRAIL ep, EXTRACT ext_pg, MEGABYTES 200
START EXTRACT ext_pg
```

---

## 9. Replicat PostgreSQL

Il parameter file dipende dal tipo di GoldenGate for PostgreSQL/DAA installato, ma i concetti restano:

```text
REPLICAT rep_pg
TARGETDB pg_target USERIDALIAS ggpg DOMAIN OracleGoldenGate
DISCARDFILE ./dirrpt/rep_pg.dsc, APPEND, MEGABYTES 500
REPORTCOUNT EVERY 5 MINUTES, RATE
MAP APP.CUSTOMERS, TARGET app.customers;
MAP APP.ORDERS, TARGET app.orders;
```

Da validare nel tuo prodotto:

- sintassi esatta `TARGETDB` / connessione;
- supporto integrated/nonintegrated;
- gestione checkpoint;
- supporto truncate/DDL;
- datatype supportati.

---

## 10. Sequenze e identity

Oracle sequence e PostgreSQL sequence non sono la stessa cosa.

Strategie:

| Strategia | Quando |
| --- | --- |
| Replicare valori generati da Oracle | durante migrazione one-way |
| Riallineare sequence target al cutover | quando PostgreSQL diventa nuovo primary |
| Range separati | bidirezionale/active-active |

Al cutover:

```sql
-- PostgreSQL esempio concettuale
SELECT setval('app.customers_id_seq', (SELECT max(id) FROM app.customers));
```

---

## 11. DDL

Non dare per scontato che DDL Oracle diventi DDL PostgreSQL corretto.

Regola production:

- DDL gestito da migration tool/change process;
- GoldenGate replica DML;
- DDL solo se supportato e testato.

Esempi problematici:

- package/procedure Oracle;
- sequence;
- partitioning;
- function-based index;
- materialized view;
- datatype proprietari.

---

## 12. Test obbligatori

```sql
-- Oracle source
INSERT INTO app.customers(id, name, updated_at) VALUES (1001, 'GG TEST', SYSTIMESTAMP);
COMMIT;

UPDATE app.customers SET name='GG TEST UPDATE' WHERE id=1001;
COMMIT;

DELETE FROM app.customers WHERE id=1001;
COMMIT;
```

PostgreSQL target:

```sql
SELECT * FROM app.customers WHERE id = 1001;
```

Testare anche:

- caratteri accentati;
- stringhe lunghe;
- timestamp/timezone;
- numeri decimali;
- LOB;
- update su colonne non chiave;
- delete;
- transazioni multi-tabella.

---

## 13. Troubleshooting Oracle -> PostgreSQL

| Problema | Causa probabile |
| --- | --- |
| update/delete non applicati | PK assente o mapping chiave errato |
| errore datatype | conversione non valida |
| stringhe troncate | lunghezza target insufficiente |
| timestamp diverso | timezone/session settings |
| duplicati | SCN initial load errato |
| Replicat lento | indici/constraint/commit rate target |
| case mismatch | nomi uppercase/lowercase non coerenti |

---

## 14. Checklist cutover Oracle -> PostgreSQL

- [ ] Source Oracle in logging corretto.
- [ ] Tutte le tabelle hanno PK o chiave stabile.
- [ ] Datatype mapping validato.
- [ ] Initial load completato a SCN noto.
- [ ] Replicat partito da SCN corretto.
- [ ] Lag stabile a zero.
- [ ] Sequence target riallineate.
- [ ] Applicazione testata su PostgreSQL.
- [ ] Piano rollback pronto.
- [ ] Stop app source eseguito.
- [ ] Ultima sincronizzazione verificata.
- [ ] Connection string spostata.

---

## 15. Collegamenti utili

- Guida completa GoldenGate 19c: [GUIDA_GOLDENGATE_19C_COMPLETA.md](./GUIDA_GOLDENGATE_19C_COMPLETA.md)
- Microservices 19c: [GUIDA_GOLDENGATE_MICROSERVICES_ARCHITECTURE_19C.md](./GUIDA_GOLDENGATE_MICROSERVICES_ARCHITECTURE_19C.md)
- Migrazione esistente nel repo: [GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md](./GUIDA_MIGRAZIONE_ORACLE_POSTGRES.md)
- Oracle certifications: https://www.oracle.com/integration/goldengate/certifications/

## Obiettivo
Definire lo scopo operativo della procedura e il risultato atteso.

## Procedura operativa
Eseguire i passaggi descritti nella guida in ordine, verificando prerequisiti e output a ogni step.

## Validazione finale
Confermare che replica, integrità dati e stato processi siano allineati ai criteri attesi.

## Troubleshooting rapido
In caso di errore, verificare log Extract/Replicat, connettività, permessi e checkpoint, quindi rieseguire la validazione.
