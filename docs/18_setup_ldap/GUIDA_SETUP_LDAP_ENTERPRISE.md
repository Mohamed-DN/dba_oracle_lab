# Guida Setup LDAP per Oracle Database — Enterprise

> Guida completa per configurare l'autenticazione centralizzata degli utenti
> Oracle Database tramite LDAP. Copre Enterprise User Security (EUS),
> Centrally Managed Users (CMU) per Active Directory, Oracle Internet Directory (OID),
> Oracle Unified Directory (OUD) e OpenLDAP.
>
> **Target audience**: DBA Oracle e Identity/Security team.

---

## PARTE I — CONCETTI E ARCHITETTURA

---

## 1. Panoramica e Metodi di Integrazione

Oracle Database supporta 3 metodi principali di integrazione LDAP:

| Metodo | Directory | Licenza | Versione Min | Complessita |
|---|---|---|---|---|
| **Enterprise User Security (EUS)** | OID, OUD | Identity Management | 10g+ | Alta |
| **Centrally Managed Users (CMU)** | Microsoft Active Directory | Nessuna aggiuntiva | 18c+ | Media |
| **LDAP Authentication (Custom)** | OpenLDAP, 389DS, qualsiasi | Nessuna | 12c+ | Media |

### 1.1 Decision Tree

```
Quale directory usi?
│
├── Microsoft Active Directory
│   └── Versione DB >= 18c?
│       ├── SI --> CMU (piu semplice, nessuna licenza extra)
│       └── NO --> EUS con OID/OUD come proxy
│
├── Oracle Internet Directory (OID) / Oracle Unified Directory (OUD)
│   └── EUS (metodo nativo Oracle)
│
└── OpenLDAP / 389DS / altro
    └── Custom LDAP auth tramite password verifier
```

### 1.2 Architettura EUS

```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│  Client App  │────►│ Oracle DB     │────►│ LDAP Server  │
│  (sqlplus,   │     │ (EUS config)  │     │ (OID/OUD/AD) │
│   app server)│     │               │     │              │
└──────────────┘     │ ldap.ora      │     │ Utenti       │
                     │ sqlnet.ora    │     │ Gruppi       │
                     │ wallet        │     │ Oracle       │
                     └───────────────┘     │ Context      │
                                           └──────────────┘
```

### 1.3 Architettura CMU (Active Directory)

```
┌──────────────┐     ┌───────────────┐     ┌──────────────┐
│  Client App  │────►│ Oracle DB     │────►│ Active       │
│              │     │ (CMU config)  │     │ Directory    │
└──────────────┘     │               │     │              │
                     │ dsi.ora       │     │ Users/Groups │
                     │ wallet (AD    │     │ OracleDB     │
                     │  password)    │     │ Schema ext.  │
                     └───────────────┘     └──────────────┘
```

---

## PARTE II — ENTERPRISE USER SECURITY (EUS)

---

## 2. Setup EUS con OID/OUD

### 2.1 Prerequisiti

1. Oracle Internet Directory (OID) o Oracle Unified Directory (OUD) installato e funzionante
2. Oracle Database 19c con patch corrente
3. Network raggiungibilita DB ↔ LDAP server (porta 389/636)
4. Oracle Wallet Manager o `orapki` disponibile

### 2.2 Step 1: Configurare ldap.ora

Sul database server, crea o modifica `$ORACLE_HOME/network/admin/ldap.ora`:

```
# ============================================
# ldap.ora — Configurazione Directory Server
# ============================================
DIRECTORY_SERVERS = (oid.company.com:389:636)
DEFAULT_ADMIN_CONTEXT = "dc=company,dc=com"
DIRECTORY_SERVER_TYPE = OID
```

Per OUD:
```
DIRECTORY_SERVERS = (oud.company.com:1389:1636)
DEFAULT_ADMIN_CONTEXT = "dc=company,dc=com"
DIRECTORY_SERVER_TYPE = OID  # OUD usa lo stesso tipo
```

### 2.3 Step 2: Registrare il Database con la Directory

```bash
# Opzione A: Usa DBCA (grafico)
dbca -silent -configureDatabase \
  -sourceDB PROD \
  -registerWithDirService true \
  -dirServiceUserName "cn=orcladmin" \
  -dirServicePassword "ldap_password" \
  -walletPassword "wallet_password"

# Opzione B: Usa NetCA
netca /responsefile /home/oracle/netca_ldap.rsp
```

### 2.4 Step 3: Creare lo Schema Enterprise nel Database

```sql
-- Crea un shared schema per gli utenti LDAP
CREATE USER eus_enterprise_schema IDENTIFIED GLOBALLY;
GRANT CREATE SESSION TO eus_enterprise_schema;
GRANT SELECT ANY TABLE TO eus_enterprise_schema;
-- Aggiungi i grant necessari per l'applicazione
```

### 2.5 Step 4: Creare Utenti nella Directory LDAP

```ldif
# File: add_user.ldif
dn: cn=mario.rossi,ou=People,dc=company,dc=com
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: orclUser
objectClass: orclUserV2
cn: mario.rossi
sn: Rossi
givenName: Mario
uid: mario.rossi
userPassword: {SSHA}xxx
orclDBDistinguishedName: cn=mario.rossi,ou=People,dc=company,dc=com
```

```bash
# Aggiungi utente
ldapadd -h oid.company.com -p 389 -D "cn=orcladmin" -w pwd -f add_user.ldif
```

### 2.6 Step 5: Mapping Utente → Schema

Tramite Enterprise Manager o oidadmin:

```bash
# Mapping diretto: utente LDAP → schema DB
eusm createMapping domain_name=OracleDefaultDomain \
  map_type=ENTRY \
  map_dn="cn=mario.rossi,ou=People,dc=company,dc=com" \
  schema=EUS_ENTERPRISE_SCHEMA \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com \
  ldap_port=389 \
  ldap_user_dn="cn=orcladmin" \
  ldap_user_password="pwd"

# Mapping per gruppo: tutti gli utenti del gruppo → schema
eusm createMapping domain_name=OracleDefaultDomain \
  map_type=SUBTREE \
  map_dn="ou=DBAs,ou=Groups,dc=company,dc=com" \
  schema=DBA_ADMIN_SCHEMA \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com \
  ldap_port=389 \
  ldap_user_dn="cn=orcladmin" \
  ldap_user_password="pwd"
```

### 2.7 Step 6: Configurare SSL/TLS

```bash
# 1. Crea wallet per il database
orapki wallet create -wallet /u01/app/oracle/admin/PROD/wallet -pwd WalletPwd -auto_login

# 2. Importa il certificato CA del server LDAP
orapki wallet add -wallet /u01/app/oracle/admin/PROD/wallet \
  -trusted_cert -cert /tmp/ldap_ca.crt -pwd WalletPwd

# 3. Configura sqlnet.ora per usare SSL
```

```
# sqlnet.ora — aggiunta per EUS SSL
WALLET_LOCATION =
  (SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = /u01/app/oracle/admin/PROD/wallet)))

SQLNET.AUTHENTICATION_SERVICES = (tcps, ldap)
NAMES.DIRECTORY_PATH = (LDAP, TNSNAMES)
```

### 2.8 Test della Connessione EUS

```bash
# Connessione con utente LDAP
sqlplus mario.rossi/ldap_password@PROD

# Verifica identita nella sessione
SELECT SYS_CONTEXT('USERENV','ENTERPRISE_IDENTITY') AS enterprise_dn,
       SYS_CONTEXT('USERENV','AUTHENTICATED_IDENTITY') AS auth_identity,
       SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') AS auth_method,
       SYS_CONTEXT('USERENV','CURRENT_SCHEMA') AS current_schema
FROM dual;
```

---

## PARTE III — CENTRALLY MANAGED USERS (CMU) CON ACTIVE DIRECTORY

---

## 3. Setup CMU (Oracle 18c+)

### 3.1 Prerequisiti

1. Oracle Database 18c o superiore (19c raccomandato)
2. Microsoft Active Directory funzionante
3. Account di servizio AD con permessi di lettura
4. Patch: assicurati di avere le ultime patch di sicurezza

### 3.2 Step 1: Configurare dsi.ora

Crea il file `$ORACLE_HOME/network/admin/dsi.ora`:

```
# ============================================
# dsi.ora — Configurazione CMU per Active Directory
# ============================================
DSI_DIRECTORY_SERVERS = (ad.company.com:389:636)
DSI_DEFAULT_ADMIN_CONTEXT = "dc=company,dc=com"
DSI_DIRECTORY_SERVER_TYPE = AD
```

### 3.3 Step 2: Creare il Wallet con Credenziali AD

```bash
# Crea wallet
mkstore -wrl /u01/app/oracle/admin/PROD/wallet -create

# Aggiungi credenziali dell'account di servizio AD
mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createEntry ORACLE.SECURITY.USERNAME "svc_oracle_ad@company.com"

mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createEntry ORACLE.SECURITY.PASSWORD "AD_Service_Password"

mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createEntry ORACLE.SECURITY.DN "CN=svc_oracle_ad,OU=ServiceAccounts,DC=company,DC=com"
```

### 3.4 Step 3: Configurare sqlnet.ora

```
# sqlnet.ora — aggiunta per CMU
WALLET_LOCATION =
  (SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = /u01/app/oracle/admin/PROD/wallet)))

SQLNET.AUTHENTICATION_SERVICES = (all)
NAMES.DIRECTORY_PATH = (TNSNAMES)
```

### 3.5 Step 4: Configurare il Database

```sql
-- Abilita CMU
ALTER SYSTEM SET LDAP_DIRECTORY_ACCESS = 'PASSWORD' SCOPE=BOTH;

-- In 19c con patch recente:
ALTER SYSTEM SET OS_AUTHENT_PREFIX = '' SCOPE=SPFILE;
```

### 3.6 Step 5: Creare Utenti Mappati ad AD

```sql
-- Utente mappato direttamente (AD user → DB user)
CREATE USER "MARIO.ROSSI" IDENTIFIED GLOBALLY AS
  'CN=Mario Rossi,OU=Users,DC=company,DC=com';
GRANT CREATE SESSION TO "MARIO.ROSSI";
GRANT dba_read_role TO "MARIO.ROSSI";

-- Utente mappato per gruppo AD (shared schema)
CREATE USER ad_dba_group IDENTIFIED GLOBALLY AS
  'CN=OracleDBAs,OU=Groups,DC=company,DC=com';
GRANT CREATE SESSION TO ad_dba_group;
GRANT DBA TO ad_dba_group;

-- Utente esclusivo (solo AD, password solo in AD)
CREATE USER "APP_SERVICE" IDENTIFIED GLOBALLY AS
  'CN=app_service,OU=ServiceAccounts,DC=company,DC=com';
GRANT CONNECT, RESOURCE TO "APP_SERVICE";
```

### 3.7 Step 6: Test Connessione CMU

```bash
# Connessione con credenziali AD
sqlplus "mario.rossi/AD_Password@PROD"

# Verifica
SELECT SYS_CONTEXT('USERENV','AUTHENTICATED_IDENTITY') FROM dual;
SELECT SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') FROM dual;
```

---

## PARTE IV — TROUBLESHOOTING, QUERY, BEST PRACTICE

---

## 4. Troubleshooting LDAP/EUS/CMU

| Errore | Causa | Risoluzione |
|---|---|---|
| ORA-01017 | Password AD errata o account locked | Verifica in AD |
| ORA-28030 | Server encountered problems accessing LDAP | Check ldap.ora, network |
| ORA-28043 | Invalid bind credentials | Check wallet credentials |
| ORA-01045 | User lacks CREATE SESSION privilege | GRANT CREATE SESSION |
| ORA-28273 | No mapping for the user | Crea mapping con eusm o CREATE USER GLOBALLY |
| ORA-28274 | No mapping for enterprise role | Crea enterprise role mapping |
| ORA-12154 | TNS could not resolve | Fix tnsnames.ora, verifica NAMES.DIRECTORY_PATH |
| ldapsearch timeout | Firewall o LDAP server down | Check porta 389/636, telnet test |
| SSL handshake failed | Certificato non trusted | Importa CA cert nel wallet |

### 4.1 Debug con Trace

```sql
-- Abilita trace LDAP dettagliato
ALTER SYSTEM SET events 'trace[KZLD.*] disk=highest' SCOPE=MEMORY;
-- Disabilita:
ALTER SYSTEM SET events 'trace[KZLD.*] off' SCOPE=MEMORY;

-- Check trace file per errori LDAP
-- grep -i "ldap\|kzld\|eus\|cmu" $DIAG_TRACE/*.trc
```

### 4.2 Query Utili

```sql
-- Lista utenti autenticati esternamente/globalmente
SELECT username, authentication_type, external_name
FROM dba_users
WHERE authentication_type IN ('EXTERNAL','GLOBAL')
ORDER BY username;

-- Sessioni LDAP attive
SELECT username, 
       SYS_CONTEXT('USERENV','ENTERPRISE_IDENTITY') AS dn,
       SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') AS method,
       SYS_CONTEXT('USERENV','PROXY_USER') AS proxy
FROM v$session
WHERE authentication_type = 'GLOBAL';

-- Verifica configurazione directory
SHOW PARAMETER ldap_directory_access;
```

---

## 5. Best Practice Enterprise

```
[x] Usa SSL/TLS (porta 636) per tutte le comunicazioni LDAP
[x] Account di servizio AD con password complessa e non-expiring
[x] Auto-login wallet per evitare problemi di autenticazione automatica
[x] Mapping per GRUPPO (non per utente singolo) per scalabilita
[x] Shared schema con GRANT minimi (least privilege)
[x] Audit su login LDAP: AUDIT SESSION WHENEVER NOT SUCCESSFUL
[x] Monitoring: alert su ORA-28030 nel alert log
[x] Test connessione LDAP dopo ogni modifica di rete/firewall
[x] Documentare tutti i mapping in un registro centrale
[x] Piano di fallback: utenti locali DBA per emergenza (mai solo LDAP per SYSDBA)
```

---

## 6. Riferimenti

- Oracle Enterprise User Security Administrator's Guide 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbimi/
- Oracle CMU Documentation 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/integrating_mads_with_oracle_database.html
- MOS: How to Configure EUS (Doc ID 1085065.1)
- MOS: CMU with Active Directory (Doc ID 2462012.1)
- MOS: EUS Troubleshooting (Doc ID 1309734.1)

---

**Documento confidenziale ad uso interno DBA. Ultima revisione: Maggio 2026.**
