# 34 - TCPS, Wallet e Certificati Oracle Net

<!-- READY_SCRIPTS_START -->
## Guide collegate

- [Listener Services DBA](../../02_core_dba/01_administration_and_security/GUIDA_LISTENER_SERVICES_DBA.md)
- [TDE Wallet Runbook](./RUNBOOK_27_TDE_WALLET_KEYSTORE_RUNBOOK.md)
- [Checkmk Oracle Enterprise](../../02_core_dba/06_monitoring_systems/GUIDA_SETUP_CHECKMK_ORACLE_ENTERPRISE.md)
<!-- READY_SCRIPTS_END -->

## Casi frequenti

- Connessioni TCPS falliscono dopo rotazione certificato.
- Wallet client/server non trovato o non aperto.
- Certificato scaduto o chain CA incompleta.
- Listener ascolta TCP ma non TCPS.
- Applicazione usa `SSL_SERVER_DN_MATCH` e DN non combacia.
- Monitoring agent non si connette via wallet.

## Separare wallet TDE da wallet TCPS

TDE wallet protegge dati e backup cifrati. TCPS wallet protegge canale di rete/certificati. Non mischiare path e responsabilita.

Esempio:

```text
TDE wallet:  /u01/app/oracle/admin/DBUNIQUENAME/wallet/tde
TCPS wallet: /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps
Client wallet: /etc/oracle/wallets/app1
```

## Precheck server

```bash
echo $ORACLE_HOME
echo $TNS_ADMIN
ls -l $TNS_ADMIN
lsnrctl status LISTENER
lsnrctl services LISTENER
```

File da controllare:

```bash
grep -n "TCPS\\|WALLET\\|SSL" $TNS_ADMIN/listener.ora $TNS_ADMIN/sqlnet.ora $TNS_ADMIN/tnsnames.ora
```

Wallet:

```bash
orapki wallet display -wallet /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps
orapki wallet display -wallet /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps -summary
```

## Listener TCPS esempio

`listener.ora`:

```text
WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps)
    )
  )

LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = dbhost01)(PORT = 1521))
      (ADDRESS = (PROTOCOL = TCPS)(HOST = dbhost01)(PORT = 2484))
    )
  )
```

`sqlnet.ora` server:

```text
WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps)
    )
  )

SSL_CLIENT_AUTHENTICATION = FALSE
SSL_VERSION = 1.2
```

In RAC, gestire listener con Grid e validare configurazione su tutti i nodi.

## TNS client TCPS

`tnsnames.ora`:

```text
APPDB_TCPS =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCPS)(HOST = scan-prod.example.com)(PORT = 2484))
    (CONNECT_DATA =
      (SERVICE_NAME = APPDB_RW)
    )
    (SECURITY =
      (SSL_SERVER_DN_MATCH = YES)
      (SSL_SERVER_CERT_DN = "CN=scan-prod.example.com,OU=DBA,O=Example,L=Milano,C=IT")
    )
  )
```

`sqlnet.ora` client:

```text
WALLET_LOCATION =
  (SOURCE =
    (METHOD = FILE)
    (METHOD_DATA =
      (DIRECTORY = /etc/oracle/wallets/app1)
    )
  )

SSL_SERVER_DN_MATCH = YES
SSL_VERSION = 1.2
```

## Creare wallet TCPS

Server:

```bash
mkdir -p /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps
orapki wallet create -wallet /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps -auto_login
orapki wallet add -wallet /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps \
  -dn "CN=scan-prod.example.com,OU=DBA,O=Example,L=Milano,C=IT" \
  -keysize 2048 -self_signed -validity 365
orapki wallet display -wallet /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps
```

Produzione: preferire certificati firmati da CA interna/enterprise, non self-signed.

## Importare CA/certificati

```bash
orapki wallet add -wallet /etc/oracle/wallets/app1 \
  -trusted_cert -cert /tmp/root_ca.pem

orapki wallet add -wallet /etc/oracle/wallets/app1 \
  -trusted_cert -cert /tmp/intermediate_ca.pem

orapki wallet display -wallet /etc/oracle/wallets/app1
```

Se il client usa DN match, recupera DN reale:

```bash
orapki wallet display -wallet /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps -summary
```

## Test connessione

```bash
tnsping APPDB_TCPS
sqlplus app_user@APPDB_TCPS
```

Trace client temporaneo:

```text
TRACE_LEVEL_CLIENT = SUPPORT
TRACE_DIRECTORY_CLIENT = /tmp/sqlnet_trace
DIAG_ADR_ENABLED = OFF
```

Rimuovere trace dopo test per evitare crescita filesystem.

## Rotazione certificato

1. Verifica scadenza e DN corrente.
2. Crea nuovo wallet in path staging.
3. Importa CA chain completa.
4. Aggiorna listener/sqlnet su un nodo o finestra controllata.
5. Riavvia listener se necessario.
6. Test TCP e TCPS.
7. Aggiorna client wallet/app configuration.
8. Mantieni rollback wallet precedente.

Backup:

```bash
tar -czf /backup/wallet_tcps_$(date +%Y%m%d_%H%M).tgz \
  /u01/app/oracle/admin/DBUNIQUENAME/wallet/tcps
```

## Errori comuni

| Errore | Causa probabile | Controllo |
|---|---|---|
| `ORA-29024` | certificate validation failure | CA chain, scadenza, hostname/DN |
| `ORA-28860` | SSL/TLS fatal error | protocol/cipher/wallet |
| `ORA-28759` | failure to open file | path wallet o permessi |
| `TNS-12560` su TCPS | listener/protocol mismatch | `lsnrctl status` |
| `ORA-12514` | service non registrato su listener TCPS | `lsnrctl services` |

## Evidence ticket

```text
Target:
Wallet path server:
Wallet path client:
DN certificato:
CA chain:
Scadenza:
listener/sqlnet modificati:
Test TCP:
Test TCPS:
Rollback:
```
