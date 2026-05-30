# Cheat Sheet Listener, TNS & Network — Enterprise Completo 🌐

> [!NOTE]
> **DOCUMENTI CORRELATI:**
> - **Guida Listener & Services**: [GUIDA_LISTENER_SERVICES_DBA.md](../../02_core_dba/01_administration_and_security/GUIDA_LISTENER_SERVICES_DBA.md)
> - **Guida Identità Oracle**: [GUIDA_IDENTITA_ORACLE_E_SERVIZI.md](../../02_core_dba/01_administration_and_security/GUIDA_IDENTITA_ORACLE_E_SERVIZI.md)
> - **Master DBA Cheat Sheet**: [CS_MASTER_DBA.md](./CS_MASTER_DBA.md)

---

## 1. LSNRCTL — Gestione Listener

### 1.1 Comandi Base
```bash
# Status del listener
lsnrctl status
lsnrctl status LISTENER
lsnrctl status LISTENER_SCAN1

# Start / Stop / Reload
lsnrctl start
lsnrctl start LISTENER_DG
lsnrctl stop
lsnrctl reload   # Ricarica listener.ora senza stop

# Servizi registrati
lsnrctl services
lsnrctl services LISTENER
```

### 1.2 Diagnostica avanzata
```bash
# Abilitare il trace (per debug connessioni)
lsnrctl set trc_level ADMIN
lsnrctl set trc_level SUPPORT   # massimo dettaglio
lsnrctl set trc_level OFF       # disabilita

# Verificare il log del listener
lsnrctl set log_status ON
lsnrctl set log_file listener.log

# Mostrare parametri correnti
lsnrctl show all
```

### 1.3 Sicurezza Listener
```bash
# Impostare password (deprecato da 12c, usare LOCAL_OS_AUTHENTICATION)
lsnrctl change_password
# Vecchia: <blank>
# Nuova: SecurePass123

# Salvare la configurazione
lsnrctl save_config

# Verificare ADMIN_RESTRICTIONS (da listener.ora)
# ADMIN_RESTRICTIONS_LISTENER = ON   -> solo OS auth può modificare
```

---

## 2. listener.ora — Configurazione Esempi

### 2.1 Listener Standard (Single Instance)
```text
LISTENER =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = dbhost01)(PORT = 1521))
    (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ORCL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = orcl1)
    )
  )

# Sicurezza
ADMIN_RESTRICTIONS_LISTENER = ON
SECURE_REGISTER_LISTENER = (IPC)

# Logging
LOGGING_LISTENER = ON
LOG_DIRECTORY_LISTENER = /u01/app/oracle/diag/tnslsnr/dbhost01/listener/trace
```

### 2.2 Static Registration (per Data Guard NOMOUNT)
```text
SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = STANDBY_DGMGRL)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = orcl1)
    )
  )
```

### 2.3 Listener Dedicato Data Guard (porta 1531)
```text
LISTENER_DG =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = dbhost01)(PORT = 1531))
  )

SID_LIST_LISTENER_DG =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ORCL_DGMGRL.domain.com)
      (ORACLE_HOME = /u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME = orcl1)
    )
  )
```

---

## 3. tnsnames.ora — Configurazione Alias

### 3.1 Connessione Standard
```text
ORCL =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = dbhost01)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL)
    )
  )
```

### 3.2 Connessione RAC (SCAN)
```text
RACDB =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = scan-rac.domain.com)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = RACDB_SVC)
    )
  )
```

### 3.3 Connessione Data Guard (con failover)
```text
ORCL_DG =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = primary-host)(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCP)(HOST = standby-host)(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL)
      (FAILOVER_MODE =
        (TYPE = SELECT)(METHOD = BASIC)(RETRIES = 30)(DELAY = 5)
      )
    )
  )
```

### 3.4 Connessione TCPS (TLS/SSL)
```text
ORCL_SECURE =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCPS)(HOST = dbhost01)(PORT = 2484))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL)
    )
    (SECURITY =
      (SSL_SERVER_CERT_DN = "cn=dbhost01,o=MyOrg,c=IT")
    )
  )
```

---

## 4. sqlnet.ora — Parametri Critici

```text
# Naming resolution order
NAMES.DIRECTORY_PATH = (TNSNAMES, LDAP, EZCONNECT)

# Dead Connection Detection (timeout in minuti)
SQLNET.EXPIRE_TIME = 10

# Encryption (Native Network Encryption)
SQLNET.ENCRYPTION_SERVER = REQUIRED
SQLNET.ENCRYPTION_TYPES_SERVER = (AES256)
SQLNET.CRYPTO_CHECKSUM_SERVER = REQUIRED
SQLNET.CRYPTO_CHECKSUM_TYPES_SERVER = (SHA256)

# TDE Wallet Location
ENCRYPTION_WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /opt/oracle/admin/ORCL/wallet/tde)
    )
  )

# Timeout connessione (secondi)
SQLNET.INBOUND_CONNECT_TIMEOUT = 60
SQLNET.OUTBOUND_CONNECT_TIMEOUT = 30
SQLNET.RECV_TIMEOUT = 30
SQLNET.SEND_TIMEOUT = 30

# Logging
DIAG_ADR_ENABLED = ON
LOG_DIRECTORY_CLIENT = /u01/app/oracle/log
TRACE_LEVEL_CLIENT = OFF

# ACL (Access Control — restrict by IP)
TCP.VALIDNODE_CHECKING = YES
TCP.INVITED_NODES = (192.168.1.0/24, 10.0.0.0/8)
TCP.EXCLUDED_NODES = (192.168.1.99)

# Banner personalizzato
SQLNET.BANNER = "Authorized access only"
```

---

## 5. TNS Diagnostica

### 5.1 tnsping
```bash
# Test connettività TNS
tnsping ORCL
tnsping ORCL 5    # 5 tentativi

# Easy Connect (senza tnsnames.ora)
sqlplus user@//hostname:1521/service_name
```

### 5.2 Troubleshooting Errori Comuni

| Errore | Causa Probabile | Fix |
|---|---|---|
| ORA-12154: TNS could not resolve | Alias non in tnsnames.ora | Verificare tnsnames.ora e NAMES.DIRECTORY_PATH |
| ORA-12541: TNS no listener | Listener non avviato | `lsnrctl start` |
| ORA-12514: TNS listener no service | Servizio non registrato | Check `lsnrctl services`, static registration |
| ORA-12170: TNS connect timeout | Firewall, rete | Check porta, firewall, SQLNET.INBOUND_CONNECT_TIMEOUT |
| ORA-12537: TNS connection closed | Listener crash o timeout | Check alert log listener |
| ORA-12560: TNS protocol adapter | Nessun ORACLE_SID impostato | `export ORACLE_SID=ORCL` |
| ORA-28040: No matching auth protocol | Client troppo vecchio | `SQLNET.ALLOWED_LOGON_VERSION_SERVER` |
| ORA-12578: TNS wallet | Wallet non trovato o chiuso | Check `ENCRYPTION_WALLET_LOCATION` |

### 5.3 Trace di rete (debug avanzato)
```text
# In sqlnet.ora (temporaneo, per debug)
TRACE_LEVEL_CLIENT = 16    # max verbosity
TRACE_DIRECTORY_CLIENT = /tmp
TRACE_FILE_CLIENT = sqlnet_client.trc

# Dopo il debug, rimettere a OFF
TRACE_LEVEL_CLIENT = OFF
```

---

## 6. Quick Reference

```text
+---------------------------+----------------------------------------------+
| OPERAZIONE                | COMANDO                                      |
+---------------------------+----------------------------------------------+
| Status listener           | lsnrctl status                               |
| Start/Stop listener       | lsnrctl start / stop                         |
| Reload config             | lsnrctl reload                               |
| Servizi registrati        | lsnrctl services                             |
| Test TNS alias            | tnsping ORCL                                 |
| Easy Connect              | sqlplus user@//host:1521/svc            |
| Trace listener ON         | lsnrctl set trc_level ADMIN                  |
| Trace listener OFF        | lsnrctl set trc_level OFF                    |
| Admin restrictions        | ADMIN_RESTRICTIONS_LISTENER = ON             |
| Dead conn detection       | SQLNET.EXPIRE_TIME = 10                      |
| IP filtering              | TCP.VALIDNODE_CHECKING = YES                 |
+---------------------------+----------------------------------------------+
```
