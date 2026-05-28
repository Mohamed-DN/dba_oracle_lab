# 27 - TDE Wallet e Keystore: Runbook Operativo

## Casi piu frequenti

- Database non apre dopo restart per wallet chiuso.
- Restore RMAN fallisce per wallet/keystore mancante.
- Standby Data Guard non applica o non apre per key material non allineato.
- Refresh/clone non legge tablespace cifrati.
- Rotazione master key richiesta da security.
- Migrazione keystore o abilitazione auto-login.

## Regola operativa

Il wallet e parte della strategia di recovery. Un backup RMAN cifrato o datafile TDE senza keystore valido puo diventare inutilizzabile.

## Precheck

```sql
SHOW PARAMETER wallet_root
SHOW PARAMETER tde_configuration

SELECT wrl_type, wrl_parameter, status, wallet_type, keystore_mode
FROM v$encryption_wallet;

SELECT tablespace_name, encrypted
FROM dba_tablespaces
ORDER BY encrypted DESC, tablespace_name;
```

OS:

```bash
echo $ORACLE_BASE
echo $ORACLE_HOME
find $ORACLE_BASE -maxdepth 5 -type f \( -name "ewallet.p12" -o -name "cwallet.sso" \) -ls
```

## Scenario A - Wallet chiuso dopo restart

Sintomo:

```text
ORA-28365: wallet is not open
ORA-28417 / ORA-28374 durante accesso a oggetti cifrati
```

Fix manuale:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "<wallet_password>";

SELECT status, wallet_type, keystore_mode
FROM v$encryption_wallet;
```

Se CDB/PDB:

```sql
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "<wallet_password>" CONTAINER=ALL;
```

## Scenario B - Creare auto-login wallet

Usalo solo se approvato da security policy.

```sql
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE
FROM KEYSTORE IDENTIFIED BY "<wallet_password>";
```

Verifica:

```sql
SELECT status, wallet_type
FROM v$encryption_wallet;
```

## Scenario C - Backup keystore prima di change

```sql
ADMINISTER KEY MANAGEMENT BACKUP KEYSTORE
USING 'before_change_YYYYMMDD'
IDENTIFIED BY "<wallet_password>";
```

OS:

```bash
tar -czf /secure_backup/tde_wallet_$(date +%Y%m%d_%H%M).tgz <wallet_directory>
sha256sum /secure_backup/tde_wallet_*.tgz
```

## Scenario D - Rotazione master key

Precheck:

```sql
SELECT status, wallet_type FROM v$encryption_wallet;
```

Rotazione:

```sql
ADMINISTER KEY MANAGEMENT SET KEY
IDENTIFIED BY "<wallet_password>"
WITH BACKUP USING 'rotate_master_key_YYYYMMDD';
```

Validazione:

```sql
SELECT key_id, creation_time, activation_time, creator
FROM v$encryption_keys
ORDER BY creation_time DESC;
```

## Scenario E - Data Guard con TDE

Prima di duplicate/restore/switchover:

- copia sicura del wallet/keystore sullo standby;
- permessi corretti;
- wallet aperto o auto-login coerente;
- backup keystore salvato fuori host.

Verifica su primary e standby:

```sql
SELECT name, database_role, open_mode FROM v$database;
SELECT status, wallet_type, keystore_mode FROM v$encryption_wallet;
```

## Scenario F - Restore RMAN con TDE

Prima del restore:

```bash
# ripristina wallet nella directory attesa da WALLET_ROOT/TDE_CONFIGURATION
ls -l <wallet_directory>
```

Poi:

```sql
STARTUP MOUNT;
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "<wallet_password>";
```

RMAN:

```sql
RESTORE DATABASE VALIDATE;
RESTORE DATABASE;
RECOVER DATABASE;
```

## Cosa non fare

- Non ruotare master key senza backup keystore.
- Non perdere `ewallet.p12`; `cwallet.sso` da solo non basta come strategia.
- Non copiare wallet via canali non sicuri.
- Non fare restore TDE senza aver prima validato wallet e password.
- Non abilitare auto-login senza approvazione security.

## Collegamenti

- [Guida TDE in profondita](../../02_core_dba/01_administration_and_security/GUIDA_TDE_IN_PROFONDITA.md)
- [RMAN + Data Guard Recovery/DR](./22_RMAN_DATAGUARD_CASI_RECOVERY_DR.md)

## Evidence ticket

```text
DB/istanza:
Wallet path:
Wallet status prima:
Operazione richiesta:
Backup keystore:
Comandi eseguiti:
Wallet status dopo:
Validazione applicativa:
```
