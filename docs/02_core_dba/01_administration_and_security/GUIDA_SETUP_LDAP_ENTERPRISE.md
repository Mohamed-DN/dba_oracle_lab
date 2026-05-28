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
|
+-- Microsoft Active Directory
|   +-- Versione DB >= 18c?
|       +-- SI --> CMU (piu semplice, nessuna licenza extra)
|       +-- NO --> EUS con OID/OUD come proxy
|
+-- Oracle Internet Directory (OID) / Oracle Unified Directory (OUD)
|   +-- EUS (metodo nativo Oracle)
|
+-- OpenLDAP / 389DS / altro
    +-- Custom LDAP auth tramite password verifier
```

### 1.2 Architettura EUS

```
+--------------+     +---------------+     +--------------+
|  Client App  |----&gt;| Oracle DB     |----&gt;| LDAP Server  |
|  (sqlplus,   |     | (EUS config)  |     | (OID/OUD/AD) |
|   app server)|     |               |     |              |
+--------------+     | ldap.ora      |     | Utenti       |
                     | sqlnet.ora    |     | Gruppi       |
                     | wallet        |     | Oracle       |
                     +---------------+     | Context      |
                                           +--------------+
```

### 1.3 Architettura CMU (Active Directory)

```
+--------------+     +---------------+     +--------------+
|  Client App  |----&gt;| Oracle DB     |----&gt;| Active       |
|              |     | (CMU config)  |     | Directory    |
+--------------+     |               |     |              |
                     | dsi.ora       |     | Users/Groups |
                     | wallet (AD    |     | OracleDB     |
                     |  password)    |     | Schema ext.  |
                     +---------------+     +--------------+
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



---

## PARTE V — DETTAGLI AVANZATI E PROCEDURE COMPLETE

---

## 7. Comandi EUSM Completi (Enterprise User Security Manager)

### 7.1 Prerequisiti EUSM

```bash
# EUSM richiede un wallet con le credenziali LDAP
# Crea il wallet prima di usare eusm

# 1. Crea il wallet
mkstore -wrl /u01/app/oracle/admin/PROD/wallet -create <<EOF
wallet_password
wallet_password
EOF

# 2. Aggiungi le credenziali
mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createEntry oracle.security.client.username "cn=orcladmin"
mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createEntry oracle.security.client.password "ldap_admin_pwd"

# 3. Verifica
mkstore -wrl /u01/app/oracle/admin/PROD/wallet -listEntries
```

### 7.2 Comandi EUSM per Gestione Dominio

```bash
# Crea un dominio
eusm createDomain domain_name=OracleDefaultDomain \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"

# Lista domini
eusm listDomains \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"

# Aggiungi database al dominio
eusm addDatabase domain_name=OracleDefaultDomain \
  database_name=PROD \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"

# Lista database nel dominio
eusm listDatabases domain_name=OracleDefaultDomain \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"
```

### 7.3 Comandi EUSM per Mapping Utenti

```bash
# Mapping diretto: utente LDAP -> schema DB
eusm createMapping domain_name=OracleDefaultDomain \
  map_type=ENTRY \
  map_dn="cn=mario.rossi,ou=People,dc=company,dc=com" \
  schema=APP_SCHEMA \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"

# Mapping per subtree: tutto il subtree -> schema
eusm createMapping domain_name=OracleDefaultDomain \
  map_type=SUBTREE \
  map_dn="ou=Developers,ou=Groups,dc=company,dc=com" \
  schema=DEV_SHARED_SCHEMA \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"

# Lista mapping
eusm listMappings domain_name=OracleDefaultDomain \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"

# Rimuovi mapping
eusm removeMapping domain_name=OracleDefaultDomain \
  map_type=ENTRY \
  map_dn="cn=mario.rossi,ou=People,dc=company,dc=com" \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"
```

### 7.4 Global Roles

```bash
# Crea un Enterprise Role (global role nel directory)
eusm createRole enterprise_role=GLOBAL_DBA_ROLE \
  domain_name=OracleDefaultDomain \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"

# Assegna global role a un database role
eusm addGlobalRole enterprise_role=GLOBAL_DBA_ROLE \
  domain_name=OracleDefaultDomain \
  database_name=PROD \
  global_role=DBA \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"

# Grant enterprise role a un utente LDAP
eusm grantRole enterprise_role=GLOBAL_DBA_ROLE \
  domain_name=OracleDefaultDomain \
  user_dn="cn=mario.rossi,ou=People,dc=company,dc=com" \
  realm_dn="dc=company,dc=com" \
  ldap_host=oid.company.com ldap_port=389 \
  ldap_user_dn="cn=orcladmin" ldap_user_password="pwd"
```

---

## 8. CMU: Password Filter e Schema Extension per Active Directory

### 8.1 Installare il Password Filter Oracle su AD Domain Controller

Il Password Filter e OBBLIGATORIO se vuoi usare l'autenticazione con password.
Senza di esso, solo Kerberos authentication funziona.

```powershell
# SUL DOMAIN CONTROLLER AD (Windows Server)

# 1. Copia opwdintg.exe dal media Oracle Database
# Si trova in: $ORACLE_HOME/bin/opwdintg.exe (sulla macchina Oracle)
# Copialo sul Domain Controller

# 2. Esegui come Amministratore
opwdintg.exe

# Menu:
# 1. Install Oracle Password Filter
# 2. Extend AD Schema for Oracle CMU
# 3. Exit

# Scegli 1: Installa il Password Filter
# Scegli 2: Estendi lo schema AD (aggiunge attributi Oracle)

# 3. RIAVVIA il Domain Controller (obbligatorio!)
# Il Password Filter si attiva solo dopo il reboot.
```

### 8.2 Verificare l'installazione del Password Filter

```powershell
# Verifica che il filter sia registrato nel registry
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "Notification Packages"
# Deve contenere: "opwdintg"

# Verifica i gruppi Oracle creati in AD
Get-ADGroup -Filter 'Name -like "ORA_VFR*"'
# Deve mostrare: ORA_VFR_11G, ORA_VFR_12C, ORA_VFR_MD5
```

### 8.3 Aggiungere Utenti AD ai Gruppi Oracle Verifier

```powershell
# L'utente DEVE essere nel gruppo verifier corretto
# Per Oracle 19c, usa ORA_VFR_12C
Add-ADGroupMember -Identity "ORA_VFR_12C" -Members "mario.rossi"

# Dopo aver aggiunto al gruppo, l'utente DEVE cambiare password
# per generare il password verifier Oracle
Set-ADAccountPassword -Identity "mario.rossi" -Reset -NewPassword (ConvertTo-SecureString "NewP@ss2026!" -AsPlainText -Force)
```

### 8.4 Configurare il Wallet per CMU con orapki

```bash
# 1. Esporta il certificato CA di Active Directory
# Sul Domain Controller: certutil -ca.cert ad_ca.cer
# Copia ad_ca.cer sul server Oracle

# 2. Crea il wallet Oracle
orapki wallet create -wallet /u01/app/oracle/admin/PROD/wallet \
  -pwd WalletPassword -auto_login

# 3. Importa il certificato CA di AD
orapki wallet add -wallet /u01/app/oracle/admin/PROD/wallet \
  -trusted_cert -cert /tmp/ad_ca.cer -pwd WalletPassword

# 4. Aggiungi le credenziali del service account AD
mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createEntry ORACLE.SECURITY.DN \
  "CN=svc_oracle_cmu,OU=ServiceAccounts,DC=company,DC=com"

mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createEntry ORACLE.SECURITY.PASSWORD "ServiceAccountPwd"

mkstore -wrl /u01/app/oracle/admin/PROD/wallet \
  -createEntry ORACLE.SECURITY.USERNAME "svc_oracle_cmu@company.com"

# 5. Verifica contenuto wallet
mkstore -wrl /u01/app/oracle/admin/PROD/wallet -listEntries
orapki wallet display -wallet /u01/app/oracle/admin/PROD/wallet
```

### 8.5 Parametri Database per CMU

```sql
-- Abilita CMU con autenticazione password
ALTER SYSTEM SET LDAP_DIRECTORY_ACCESS = 'PASSWORD' SCOPE=BOTH;

-- Per consentire SYSDBA via AD (opzionale, valuta rischi)
ALTER SYSTEM SET LDAP_DIRECTORY_SYSAUTH = 'YES' SCOPE=SPFILE;

-- Rimuovi prefisso OS (necessario per CMU)
ALTER SYSTEM SET OS_AUTHENT_PREFIX = '' SCOPE=SPFILE;

-- Verifica
SHOW PARAMETER ldap_directory_access;
SHOW PARAMETER ldap_directory_sysauth;
SHOW PARAMETER os_authent_prefix;
```

---

## 9. Test e Validazione LDAP/CMU

### 9.1 Test Connettivita LDAP

```bash
# Test con ldapsearch (pacchetto openldap-clients)
# Per OID
ldapsearch -h oid.company.com -p 389 \
  -D "cn=orcladmin" -w "pwd" \
  -b "dc=company,dc=com" "(uid=mario.rossi)"

# Per AD
ldapsearch -h ad.company.com -p 389 \
  -D "svc_oracle_cmu@company.com" -w "pwd" \
  -b "dc=company,dc=com" "(sAMAccountName=mario.rossi)"

# Test SSL
ldapsearch -h ad.company.com -p 636 -ZZ \
  -D "svc_oracle_cmu@company.com" -w "pwd" \
  -b "dc=company,dc=com" "(sAMAccountName=mario.rossi)"

# Test con telnet (verifica porta aperta)
telnet oid.company.com 389
telnet ad.company.com 636
```

### 9.2 Test Autenticazione DB

```bash
# Connessione con utente LDAP/AD
sqlplus mario.rossi/ldap_password@PROD

# Una volta connesso, verifica identita
SELECT USER FROM dual;
SELECT SYS_CONTEXT('USERENV','ENTERPRISE_IDENTITY') AS enterprise_dn FROM dual;
SELECT SYS_CONTEXT('USERENV','AUTHENTICATED_IDENTITY') AS auth_id FROM dual;
SELECT SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') AS auth_method FROM dual;
SELECT SYS_CONTEXT('USERENV','CURRENT_SCHEMA') AS schema FROM dual;
SELECT SYS_CONTEXT('USERENV','SESSION_USER') AS session_user FROM dual;
SELECT SYS_CONTEXT('USERENV','PROXY_USER') AS proxy FROM dual;
```

### 9.3 Debug con Trace Avanzato

```sql
-- Abilita trace dettagliato per connessioni LDAP
ALTER SYSTEM SET events '28033 trace name context forever, level 9' SCOPE=MEMORY;

-- Tenta la connessione LDAP problematica
-- ...

-- Disabilita trace
ALTER SYSTEM SET events '28033 trace name context off' SCOPE=MEMORY;

-- Trova il trace file
SELECT value FROM v$diag_info WHERE name = 'Diag Trace';
-- grep -i "ldap\|kzld\|eus\|cmu\|bind\|search" $DIAG_TRACE/*.trc | tail -50
```

---

## 10. Troubleshooting Completo LDAP/EUS/CMU

| # | Errore | Causa Dettagliata | Diagnostica | Risoluzione |
|---|---|---|---|---|
| 1 | ORA-28030 | DB non raggiunge LDAP server | `telnet host port`, check firewall | Fix rete, verifica dsi.ora/ldap.ora |
| 2 | ORA-28043 | Password wallet-to-LDAP non valida | `mkstore -listEntries` | Rigenera wallet con DBCA o mkstore |
| 3 | ORA-28273 | Nessun mapping per l'utente | `eusm listMappings` | Crea mapping con eusm o CREATE USER GLOBALLY |
| 4 | ORA-28274 | Nessun mapping per enterprise role | `eusm listRoles` | Crea enterprise role mapping |
| 5 | ORA-01017 | Password AD errata o account locked | Check in AD (Account status) | Unlock, reset password in AD |
| 6 | ORA-01045 | Utente non ha CREATE SESSION | `SELECT * FROM dba_sys_privs` | GRANT CREATE SESSION |
| 7 | ORA-28040 | Auth protocol mismatch | Check SQLNET.ALLOWED_LOGON_VERSION | Allinea versioni client/server |
| 8 | ORA-12154 | TNS alias non trovato | `tnsping`, check NAMES.DIRECTORY_PATH | Fix tnsnames.ora o ldap.ora |
| 9 | SSL handshake fail | Certificato CA non nel wallet | `orapki wallet display` | Importa CA cert |
| 10 | Timeout LDAP | Firewall, LDAP server sovraccarico | `ldapsearch` con timeout | Check firewall rules, LDAP health |
| 11 | Password verifier missing | Utente non nel gruppo ORA_VFR | Check AD group membership | Aggiungi a ORA_VFR_12C, reset pwd |
| 12 | dsi.ora not found | Path errato o TNS_ADMIN sbagliato | `echo $TNS_ADMIN`, check path | Sposta in $ORACLE_HOME/network/admin |
| 13 | wallet not found | WALLET_LOCATION errato in sqlnet.ora | Check sqlnet.ora | Fix path, verifica cwallet.sso esista |
| 14 | ORA-28300 | Schema globale non esiste | `SELECT username FROM dba_users` | Crea shared schema |

---

## 11. Audit e Compliance

```sql
-- Audit tutti i login via LDAP
AUDIT CREATE SESSION BY ACCESS;

-- Audit login falliti (critico per security)
AUDIT CREATE SESSION WHENEVER NOT SUCCESSFUL;

-- Query: login LDAP falliti nelle ultime 24h
SELECT username, os_username, userhost, terminal,
       TO_CHAR(timestamp,'DD-MON HH24:MI:SS') AS ts,
       action_name, returncode
FROM dba_audit_trail
WHERE action_name = 'LOGON'
  AND returncode != 0
  AND timestamp > SYSDATE - 1
ORDER BY timestamp DESC;

-- Unified Audit (19c+)
SELECT event_timestamp, dbusername, os_username, 
       authentication_type, client_program_name,
       return_code, unified_audit_policies
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code != 0
  AND event_timestamp > SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC;
```

---

## 12. Schema di Fallback (Emergenza)

```sql
-- SEMPRE mantenere almeno 1 utente DBA locale per emergenza
-- In caso di LDAP down, questo utente permette l'accesso

CREATE USER dba_emergency IDENTIFIED BY "EmergP@ss!" 
  PROFILE DEFAULT ACCOUNT UNLOCK;
GRANT DBA TO dba_emergency;
GRANT SYSDBA TO dba_emergency;

-- Documentare le credenziali in un vault sicuro (es. CyberArk, HashiCorp Vault)
-- NON nella documentazione in chiaro!
```

---



---

## PARTE VI — NAMING CENTRALIZZATO, KERBEROS, PROXY AUTH

---

## 14. LDAP Directory Naming (Centralizzare tnsnames.ora)

Invece di gestire tnsnames.ora su ogni client, puoi centralizzare tutto in LDAP.

### 14.1 Concetto

```
PRIMA (senza LDAP naming):
  Client 1: tnsnames.ora locale
  Client 2: tnsnames.ora locale  <-- copie da mantenere sincronizzate
  Client N: tnsnames.ora locale

DOPO (con LDAP naming):
  Client 1: ldap.ora -> LDAP Server (contiene tutti i TNS entries)
  Client 2: ldap.ora -> LDAP Server
  Client N: ldap.ora -> LDAP Server  <-- un unico punto di gestione
```

### 14.2 Configurazione sul Server LDAP

```bash
# 1. Con NetCA (grafico)
netca
# Seleziona: Directory Usage Configuration
# Inserisci: host LDAP, porta, naming context
# NetCA crea ldap.ora e registra il contesto Oracle nella directory

# 2. Esportare le entries tnsnames.ora esistenti nel LDAP
# Usa Oracle Net Manager per importare tnsnames.ora nella directory
netmgr
# Directory -> Oracle Net Services -> ... -> Import tnsnames.ora
```

### 14.3 Aggiungere un TNS Entry nella Directory LDAP

```ldif
# File: add_tns_prod.ldif
dn: cn=PROD,cn=OracleContext,dc=company,dc=com
objectClass: top
objectClass: orclNetService
cn: PROD
orclNetDescString: (DESCRIPTION=
  (ADDRESS=(PROTOCOL=TCP)(HOST=dbserver01)(PORT=1521))
  (CONNECT_DATA=(SERVICE_NAME=PROD.company.com)))
```

```bash
ldapadd -h oid.company.com -p 389 \
  -D "cn=orcladmin" -w pwd -f add_tns_prod.ldif
```

### 14.4 Configurazione sui Client

```
# ldap.ora sui client
DIRECTORY_SERVERS = (oid.company.com:389:636)
DEFAULT_ADMIN_CONTEXT = "dc=company,dc=com"
DIRECTORY_SERVER_TYPE = OID

# sqlnet.ora sui client
NAMES.DIRECTORY_PATH = (LDAP, TNSNAMES, EZCONNECT)
# LDAP viene cercato PRIMA di tnsnames.ora locale
```

```bash
# Test
tnsping PROD
# Se funziona, il TNS entry e stato risolto via LDAP
```

---

## 15. Kerberos Authentication (SSO)

### 15.1 Concetto

Con Kerberos, gli utenti NON inseriscono la password Oracle.
Si autenticano con il ticket Kerberos (da Active Directory) e Oracle lo valida.

### 15.2 Prerequisiti

1. Active Directory con Kerberos attivo (standard in AD)
2. Oracle Database 19c con Advanced Security Option
3. `kinit` funzionante sui client
4. SPN (Service Principal Name) registrato per Oracle

### 15.3 Configurazione

```bash
# 1. Registra SPN per Oracle in AD
setspn -A oracle/dbserver01.company.com@COMPANY.COM svc_oracle_ad

# 2. Crea keytab per Oracle
ktpass /out oracle.keytab /mapuser svc_oracle_ad \
  /princ oracle/dbserver01.company.com@COMPANY.COM \
  /crypto All /ptype KRB5_NT_PRINCIPAL /pass ServicePwd
# Copia oracle.keytab sul server Oracle
```

```
# sqlnet.ora sul server Oracle
SQLNET.AUTHENTICATION_SERVICES = (kerberos5)
SQLNET.AUTHENTICATION_KERBEROS5_SERVICE = oracle
SQLNET.KERBEROS5_CONF = /etc/krb5.conf
SQLNET.KERBEROS5_KEYTAB = /u01/app/oracle/admin/PROD/wallet/oracle.keytab
SQLNET.KERBEROS5_CC_NAME = /tmp/krb5cc_%{uid}
```

```sql
-- Crea utente Oracle per Kerberos auth
CREATE USER "MARIO.ROSSI@COMPANY.COM" IDENTIFIED EXTERNALLY;
GRANT CREATE SESSION TO "MARIO.ROSSI@COMPANY.COM";
```

```bash
# Test dal client
kinit mario.rossi@COMPANY.COM  # inserisci password AD
sqlplus /@PROD  # connessione senza password!
```

---

## 16. Proxy Authentication

Consente a un'applicazione di connettersi con un utente "proxy" e assumere l'identita di un enterprise user.

```sql
-- Abilita proxy per uno schema
ALTER USER app_schema GRANT CONNECT THROUGH enterprise_proxy_user;

-- Connessione proxy
-- sqlplus enterprise_proxy_user[end_user]/proxy_pwd@PROD
-- La sessione opera come end_user ma si connette come proxy
```

---

## 17. Multitenant (CDB/PDB) con LDAP

### 17.1 Shared Schema in PDB

```sql
-- Nel CDB root
ALTER SESSION SET CONTAINER = CDB$ROOT;
CREATE USER c##eus_schema IDENTIFIED GLOBALLY CONTAINER=ALL;
GRANT CREATE SESSION TO c##eus_schema CONTAINER=ALL;

-- Nella PDB specifica
ALTER SESSION SET CONTAINER = PDB_PROD;
CREATE USER pdb_eus_schema IDENTIFIED GLOBALLY;
GRANT CREATE SESSION TO pdb_eus_schema;
```

### 17.2 CMU per PDB Specifiche

```sql
-- Per limitare CMU a PDB specifiche
ALTER PLUGGABLE DATABASE PDB_PROD CLOSE;
ALTER PLUGGABLE DATABASE PDB_PROD OPEN READ WRITE;
-- Ogni PDB puo avere la propria configurazione CMU
```

---

## 18. Monitoring e Alerting per LDAP

### 18.1 Query per Monitorare Login LDAP

```sql
-- Sessioni attive autenticate via LDAP
SELECT s.sid, s.serial#, s.username, s.program, s.machine,
       s.logon_time, s.status,
       SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') AS auth_method,
       SYS_CONTEXT('USERENV','ENTERPRISE_IDENTITY') AS dn
FROM v$session s
WHERE s.type != 'BACKGROUND'
  AND s.authentication_type IN ('GLOBAL','EXTERNAL');

-- Login falliti nelle ultime 24h
SELECT event_timestamp, dbusername, os_username, 
       userhost, authentication_type, return_code,
       client_program_name
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code != 0
  AND authentication_type IN ('DIRECTORY','GLOBAL')
  AND event_timestamp > SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC;

-- Conteggio login per metodo di autenticazione
SELECT authentication_type, COUNT(*) AS sessions
FROM v$session
WHERE type != 'BACKGROUND'
GROUP BY authentication_type
ORDER BY sessions DESC;
```

### 18.2 Alert su ORA-28030 (LDAP non raggiungibile)

```bash
# In CheckMK: custom check che monitora l'alert log per ORA-28030
# /etc/check_mk/oracle_custom/ldap_health.sql
SELECT
  CASE WHEN COUNT(*) > 0 THEN 2 ELSE 0 END AS state,
  'ORA-28030 occurrences in last hour: ' || COUNT(*) AS detail
FROM v$diag_alert_ext
WHERE message_text LIKE '%ORA-28030%'
  AND originating_timestamp > SYSTIMESTAMP - INTERVAL '1' HOUR;
```

---

## 19. Riferimenti Completi

- Oracle Enterprise User Security Administrator's Guide 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbimi/
- Oracle CMU with Active Directory 19c
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/integrating_mads_with_oracle_database.html
- Oracle EUSM Command Reference
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbimi/enterprise-user-security-manager-eusm-command-reference.html
- Oracle Net Services Reference (ldap.ora, sqlnet.ora, dsi.ora)
  https://docs.oracle.com/en/database/oracle/oracle-database/19/netrf/
- Oracle Password Filter for AD (opwdintg)
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/integrating_mads_with_oracle_database.html
- Oracle Kerberos Authentication
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-kerberos-authentication.html
- Oracle Directory Naming Configuration
  https://docs.oracle.com/en/database/oracle/oracle-database/19/netag/configuring-naming-methods.html
- Oracle Proxy Authentication
  https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-privilege-and-role-authorization.html
- MOS: How to Configure EUS Step by Step (Doc ID 1085065.1)
- MOS: CMU with Active Directory Step by Step (Doc ID 2462012.1)
- MOS: EUS Troubleshooting Checklist (Doc ID 1309734.1)
- MOS: ORA-28030 Troubleshooting (Doc ID 457111.1)
- MOS: Kerberos Authentication for Oracle DB (Doc ID 340178.1)
- MOS: LDAP Directory Naming (Doc ID 169abordo.1)

---

**Documento confidenziale ad uso interno DBA. Ultima revisione: Maggio 2026.**
