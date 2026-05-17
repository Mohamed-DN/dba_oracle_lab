# GoldenGate 19c - Grant e Privilegi Production-Grade

> Obiettivo: preparare gli utenti Oracle GoldenGate per Oracle 19c, CDB/PDB, target Oracle, PostgreSQL e ambienti critici senza usare `GRANT DBA` come scorciatoia. In laboratorio `DBA` puo' far sembrare tutto piu semplice, ma in produzione bancaria e' un anti-pattern.

---

## 1. Regola principale

```text
Il ruolo DBA funziona perche' concede troppo.
DBMS_GOLDENGATE_AUTH + grant mirati funziona perche' concede cio' che serve.
```

In produzione usare sempre:

- utente dedicato GoldenGate;
- credential store o wallet, non password in chiaro;
- `DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE` per capture/apply Oracle;
- grant DML mirati sul target;
- privilegi opzionali solo se il caso li richiede;
- evidenza di change management per ogni grant.

---

## 2. Matrice decisionale rapida

| Scenario | Utente | Privilegi principali |
|---|---|---|
| Oracle 19c CDB source, capture da piu PDB | `C##GGADMIN` in `CDB$ROOT` | `CREATE SESSION`, quota, `DBMS_GOLDENGATE_AUTH(..., 'CAPTURE', container=>'ALL')` |
| Oracle 19c CDB target, apply su piu PDB | `C##GGADMIN` o utenti locali per PDB | `DBMS_GOLDENGATE_AUTH(..., 'APPLY')` + DML sugli oggetti target |
| Oracle 19c singolo PDB | `GGADMIN` locale nel PDB | `CREATE SESSION`, quota, `DBMS_GOLDENGATE_AUTH(..., container=>'CURRENT')` |
| Oracle non-CDB | `GGADMIN` locale | `CREATE SESSION`, quota, `DBMS_GOLDENGATE_AUTH` |
| Oracle -> PostgreSQL | source Oracle + target PostgreSQL | grant Oracle source + `CONNECT`, `USAGE`, DML PostgreSQL |
| PostgreSQL source | `ggadmin` PostgreSQL | `CONNECT`, `WITH REPLICATION`, superuser temporaneo per `ADD TRANDATA` se richiesto |
| DDL replication | utente GoldenGate + approvazione change | privilegi DDL mirati e testati, non `DBA` generico |
| Data Vault / redaction / VPD | utente GoldenGate + owner security | privilegi opzionali espliciti documentati |

---

## 3. Perche' non dare `DBA`

Concedere il ruolo `DBA` a `GGADMIN` copre quasi tutti gli errori di privilegio, ma crea problemi seri:

- viola least privilege;
- rende difficile auditare cosa serve davvero;
- aumenta superficie di attacco;
- permette operazioni non necessarie al processo GoldenGate;
- in banca puo' essere bloccato da security/compliance;
- rende meno ripetibile il runbook tra ambienti DEV/UAT/PROD.

Risposta corretta in colloquio:

```text
Se in laboratorio uso DBA e funziona, non significa che sia corretto.
In produzione separo capture/apply e concedo i privilegi con DBMS_GOLDENGATE_AUTH,
poi aggiungo solo i grant DML/DDL strettamente necessari al target.
```

---

## 4. Oracle 19c CDB - Common user per capture/apply

Eseguire da `CDB$ROOT` come `SYSDBA`.

```sql
SHOW CON_NAME;
-- Deve mostrare CDB$ROOT

CREATE USER c##ggadmin IDENTIFIED BY "<PASSWORD_SICURA>"
  CONTAINER=ALL
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP;

GRANT CREATE SESSION TO c##ggadmin CONTAINER=ALL;
GRANT CREATE VIEW TO c##ggadmin CONTAINER=ALL;
GRANT ALTER SYSTEM TO c##ggadmin CONTAINER=ALL;
GRANT ALTER USER TO c##ggadmin CONTAINER=ALL;

ALTER USER c##ggadmin QUOTA UNLIMITED ON USERS CONTAINER=ALL;
ALTER USER c##ggadmin SET CONTAINER_DATA=ALL CONTAINER=CURRENT;
```

Grant GoldenGate completi per lab o utente unico capture/apply:

```sql
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

Separazione piu enterprise:

```sql
-- Source: solo capture
BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'C##GGADMIN_CAPTURE',
    privilege_type          => 'CAPTURE',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'ALL');
END;
/

-- Target: solo apply
BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'C##GGADMIN_APPLY',
    privilege_type          => 'APPLY',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'ALL');
END;
/
```

Nota: Oracle documenta `CAPTURE`, `APPLY` e `*` come valori supportati per `privilege_type`.

---

## 5. Oracle 19c PDB - Utente locale

Usare questo pattern se la replica e' limitata a un solo PDB e non devi fare capture cross-PDB.

```sql
ALTER SESSION SET CONTAINER = PDB1;
SHOW CON_NAME;

CREATE USER ggadmin IDENTIFIED BY "<PASSWORD_SICURA>"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO ggadmin;
GRANT CREATE VIEW TO ggadmin;

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'GGADMIN',
    privilege_type          => '*',
    grant_select_privileges => TRUE,
    do_grants               => TRUE,
    container               => 'CURRENT');
END;
/
```

Se Extract deve leggere redo a livello CDB/root, preferire il common user nel root. L'utente locale nel PDB e' piu adatto per Replicat o casi confinati.

---

## 6. Oracle non-CDB

```sql
CREATE USER ggadmin IDENTIFIED BY "<PASSWORD_SICURA>"
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION TO ggadmin;
GRANT CREATE VIEW TO ggadmin;
GRANT ALTER SYSTEM TO ggadmin;

BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'GGADMIN',
    privilege_type          => '*',
    grant_select_privileges => TRUE,
    do_grants               => TRUE);
END;
/
```

---

## 7. Target Oracle - Grant DML per Replicat

`DBMS_GOLDENGATE_AUTH` prepara l'utente per GoldenGate, ma Replicat deve anche poter applicare DML sugli oggetti target.

### 7.1 Approccio raccomandato: object-level grants

```sql
-- Esegui come owner dello schema target o come DBA operativo approvato
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.CUSTOMERS TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.ORDERS TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.ORDER_ITEMS TO ggadmin;
```

Per molte tabelle puoi generare gli statement:

```sql
SELECT 'GRANT SELECT, INSERT, UPDATE, DELETE ON ' || owner || '.' || table_name || ' TO GGADMIN;'
FROM   dba_tables
WHERE  owner = 'APP'
ORDER  BY table_name;
```

### 7.2 Approccio esteso: ANY privileges

Da usare solo con approvazione security, per schemi ampi o migrazioni temporanee:

```sql
GRANT SELECT ANY TABLE TO ggadmin;
GRANT INSERT ANY TABLE TO ggadmin;
GRANT UPDATE ANY TABLE TO ggadmin;
GRANT DELETE ANY TABLE TO ggadmin;
```

In banca annotare sempre:

```text
motivo, durata, ambiente, owner approvatore, piano revoca
```

### 7.3 Checkpoint table

Se usi checkpoint table:

```sql
-- Da GGSCI/AdminClient dopo DBLOGIN
ADD CHECKPOINTTABLE GGADMIN.GG_CHECKPOINT
```

L'utente deve poter creare oggetti nel proprio schema o avere quota adeguata.

---

## 8. DDL replication

DDL replication richiede privilegi aggiuntivi e governance piu forte.

Regola pratica:

- in migrazione controllata, spesso si blocca DDL durante la finestra critica;
- in replica continua, DDL deve passare da change management;
- evitare di concedere `DBA` solo per far passare DDL;
- concedere privilegi DDL mirati e testare in UAT.

Esempi da valutare caso per caso:

```sql
GRANT CREATE ANY TABLE TO ggadmin;
GRANT ALTER ANY TABLE TO ggadmin;
GRANT DROP ANY TABLE TO ggadmin;
GRANT CREATE ANY INDEX TO ggadmin;
```

Non applicare questi grant senza approvazione: sono privilegi potenti.

---

## 9. Privilegi opzionali Oracle

Usare solo se il requisito li richiede.

| Caso | Azione |
|---|---|
| Virtual Private Database | valutare `EXEMPT_ACCESS_POLICY` tramite privilegi opzionali |
| Data Redaction | valutare `EXEMPT_REDACTION_POLICY` |
| Database Vault | servono ruoli/realm specifici come `DV_GOLDENGATE_ADMIN`, secondo policy security |
| TDE/classic mining | verificare accesso log/ASM/wallet secondo architettura |
| DDL su realm protetti | autorizzazioni tramite owner Database Vault |

Esempio opzionale:

```sql
BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                   => 'C##GGADMIN',
    privilege_type            => 'CAPTURE',
    grant_select_privileges   => TRUE,
    do_grants                 => TRUE,
    grant_optional_privileges => 'EXEMPT_REDACTION_POLICY',
    container                 => 'ALL');
END;
/
```

---

## 10. PostgreSQL - Source e target

Oracle consiglia un utente dedicato anche per PostgreSQL.

### 10.1 PostgreSQL target Replicat

```sql
CREATE USER ggadmin WITH PASSWORD '<PASSWORD_SICURA>';
GRANT CONNECT ON DATABASE appdb TO ggadmin;

\c appdb

GRANT USAGE ON SCHEMA app TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO ggadmin;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ggadmin;
```

Se Replicat deve gestire truncate:

```sql
GRANT TRUNCATE ON ALL TABLES IN SCHEMA app TO ggadmin;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT TRUNCATE ON TABLES TO ggadmin;
```

### 10.2 PostgreSQL source Extract

```sql
CREATE USER ggadmin WITH PASSWORD '<PASSWORD_SICURA>';
GRANT CONNECT ON DATABASE appdb TO ggadmin;
ALTER USER ggadmin WITH REPLICATION;
```

Per alcune operazioni come abilitare table-level supplemental logging / `ADD TRANDATA`, la documentazione PostgreSQL GoldenGate indica che puo' servire `SUPERUSER`; in produzione concederlo solo temporaneamente e revocarlo subito dopo.

```sql
-- Solo finestra controllata, se richiesto dalla piattaforma
ALTER USER ggadmin WITH SUPERUSER;
-- esegui configurazione TRANDATA
ALTER USER ggadmin WITH NOSUPERUSER;
```

Su servizi managed cloud, `SUPERUSER` potrebbe non essere disponibile: usare l'admin previsto dal servizio per la fase di preparazione.

---

## 11. Credential store obbligatorio

Non mettere password nei parameter file.

```text
ADD CREDENTIALSTORE
ALTER CREDENTIALSTORE ADD USER c##ggadmin@RACDB PASSWORD <PASSWORD_DB> ALIAS ggsrc DOMAIN OracleGoldenGate
ALTER CREDENTIALSTORE ADD USER ggadmin@DBTARGET PASSWORD <PASSWORD_DB> ALIAS ggtgt DOMAIN OracleGoldenGate
INFO CREDENTIALSTORE
```

Uso nei parametri:

```text
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
```

Non usare:

```text
USERID ggadmin, PASSWORD password_in_chiaro
```

---

## 12. Verifiche post-grant

### 12.1 Oracle

```sql
SELECT username, privilege_type
FROM   dba_goldengate_privileges
WHERE  username IN ('GGADMIN','C##GGADMIN')
ORDER  BY username, privilege_type;

SELECT grantee, privilege
FROM   dba_sys_privs
WHERE  grantee IN ('GGADMIN','C##GGADMIN')
ORDER  BY grantee, privilege;

SELECT owner, table_name, privilege
FROM   dba_tab_privs
WHERE  grantee IN ('GGADMIN','C##GGADMIN')
ORDER  BY owner, table_name, privilege;
```

### 12.2 GoldenGate DBLOGIN

```text
DBLOGIN USERIDALIAS ggsrc DOMAIN OracleGoldenGate
INFO SCHEMATRANDATA APP
```

Se `DBLOGIN` fallisce:

- controlla alias credential store;
- controlla service name/TNS;
- controlla container corretto;
- controlla `CREATE SESSION`;
- controlla password scaduta o account locked.

---

## 13. ORA-01031 troubleshooting

| Punto | Controllo |
|---|---|
| Container sbagliato | `SHOW CON_NAME` prima dei grant |
| Common user mancante | usare `C##` in CDB root se serve capture CDB |
| `container=>'ALL'` mancante | rieseguire da root per common user |
| Replicat non applica DML | aggiungere grant su tabelle target |
| DDL fallisce | grant DDL mirati o blocco DDL durante migrazione |
| Integrated Extract non registra | DBLOGIN con utente privilegiato via `DBMS_GOLDENGATE_AUTH` |
| PostgreSQL slot fallisce | manca `WITH REPLICATION` |
| PostgreSQL `ADD TRANDATA` fallisce | superuser/admin temporaneo richiesto |

---

## 14. Checklist bancaria

- [ ] Niente `GRANT DBA` permanente a `GGADMIN`.
- [ ] Utente source e target separati se richiesto da segregazione duty.
- [ ] Tutti i grant hanno owner e approvazione.
- [ ] Password nel credential store, non nei file.
- [ ] Grant DML target limitati agli schemi/tabelle replicate.
- [ ] Privilegi opzionali documentati e motivati.
- [ ] Grant temporanei revocati dopo configurazione.
- [ ] Verifica `DBA_GOLDENGATE_PRIVILEGES` allegata al change.
- [ ] Test `DBLOGIN`, `ADD SCHEMATRANDATA`, `REGISTER EXTRACT`, `ADD REPLICAT` completati in UAT.
- [ ] Piano di revoca e break-glass documentato.

---

## 15. Fonti Oracle ufficiali

- Oracle GoldenGate 19c - Establishing Credentials: https://docs.oracle.com/en/middleware/goldengate/core/19.1/oracle-db/establishing-oracle-goldengate-credentials.html
- Oracle Database 19c - DBMS_GOLDENGATE_AUTH: https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_GOLDENGATE_AUTH.html
- GoldenGate 19c - Requirements for CDB/PDB: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/requirements-multitenant-container-databases.html
- GoldenGate 19c - DBLOGIN: https://docs.oracle.com/en/middleware/goldengate/core/19.1/gclir/dblogin.html
- GoldenGate for PostgreSQL - Preparing Database: https://docs.oracle.com/en/middleware/goldengate/core/21.3/gghdb/preparing-database-oracle-goldengate-postgresql.html
- GoldenGate 19c - Operating System Privileges: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/operating-system-privileges_19c.html
