# 🔐 GUIDA TDE in Profondità (Oracle 19c)

> Guida operativa completa su **Transparent Data Encryption (TDE)** per ambienti single-instance, RAC e CDB/PDB.
> Focus: keystore, master key lifecycle, cifratura tablespace/colonne, backup e controlli operativi.

---

## Obiettivo

Configurare e gestire TDE in modo production-grade, con procedure ripetibili e verificabili:

- protezione dati-at-rest (datafile, tempfile, backup);
- gestione sicura delle chiavi (keystore e master key);
- integrazione con ambienti multitenant (CDB/PDB);
- baseline operativa per RAC/Data Guard.

---

## Teoria (fondamentale)

### Cos’è TDE

TDE cifra i dati a riposo e li decifra in modo trasparente per utenti/app autorizzati.

### Componenti chiave

- **Keystore (wallet/external keystore)**: contiene le chiavi master.
- **TDE Master Encryption Key**: chiave radice che protegge le chiavi dei dati.
- **Data Encryption Keys**: usate per cifrare tablespace/colonne.

### Modalità multitenant

- **United mode**: keystore gestito dal CDB root, più semplice da operare.
- **Isolated mode**: keystore separato per PDB, più isolamento ma più complessità.

---

## Procedura operativa

> Esegui come utente con privilegi `ADMINISTER KEY MANAGEMENT` (tipicamente SYSKM/SYS).

### 1) Configurazione preliminare keystore

1. Imposta `WALLET_ROOT` (SPFILE/PFILE) e riavvia istanza.
2. Imposta `TDE_CONFIGURATION` (es. `FILE`, `OKV`, `OKV|FILE`).
3. Verifica:

```sql
SHOW PARAMETER wallet_root;
SHOW PARAMETER tde_configuration;
```

### 2) Creazione e apertura keystore software (FILE)

```sql
-- Crea keystore nella directory WALLET_ROOT/tde
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE IDENTIFIED BY "<WALLET_PASSWORD>";

-- Apri keystore
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "<WALLET_PASSWORD>";
```

### 3) Creazione master key TDE (con backup)

```sql
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "<WALLET_PASSWORD>" WITH BACKUP;
```

In CDB/PDB usa `CONTAINER=ALL` quando richiesto dalla policy operativa:

```sql
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "<WALLET_PASSWORD>" WITH BACKUP CONTAINER=ALL;
```

### 4) Cifratura tablespace (raccomandata)

```sql
CREATE TABLESPACE app_tde_ts
  DATAFILE '+DATA' SIZE 2G
  ENCRYPTION USING 'AES256'
  DEFAULT STORAGE(ENCRYPT);
```

Per tablespace esistente:

```sql
ALTER TABLESPACE users ENCRYPTION ONLINE USING 'AES256' ENCRYPT;
```

### 5) Cifratura colonna (uso mirato)

```sql
CREATE TABLE clienti_secure (
  id           NUMBER PRIMARY KEY,
  nome         VARCHAR2(100),
  cf           VARCHAR2(16) ENCRYPT USING 'AES256' NO SALT,
  carta_credito VARCHAR2(32) ENCRYPT
);
```

### 6) Operatività RAC/Data Guard

- Keystore deve essere disponibile in modo coerente su tutti i nodi.
- Backup keystore obbligatorio prima/ dopo rotazione chiavi.
- In Data Guard, mantenere sincronizzazione key material prima di switch/failover.

---

## Esempio end-to-end minimo (lab)

```sql
-- 1) Verifica stato wallet
SELECT wrl_type, wrl_parameter, status, wallet_type, keystore_mode
FROM   v$encryption_wallet;

-- 2) Crea tablespace cifrato
CREATE TABLESPACE tde_demo_ts
  DATAFILE '+DATA' SIZE 512M
  ENCRYPTION USING 'AES256'
  DEFAULT STORAGE(ENCRYPT);

-- 3) Crea tabella nel TS cifrato
CREATE TABLE demo_tde (
  id NUMBER PRIMARY KEY,
  payload VARCHAR2(200)
) TABLESPACE tde_demo_ts;
```

---

## Validazione finale

Verifiche consigliate:

```sql
-- Stato wallet/keystore
SELECT status, wallet_type, keystore_mode FROM v$encryption_wallet;

-- Tablespace cifrati
SELECT tablespace_name, encrypted
FROM   dba_tablespaces
ORDER  BY tablespace_name;

-- Chiavi e metadata cifratura
SELECT con_id, key_id, tag, creation_time
FROM   v$encryption_keys
ORDER  BY creation_time DESC;
```

Checklist finale:

- [ ] keystore aperto in tutte le istanze richieste;
- [ ] almeno una master key presente con backup;
- [ ] tablespace sensibili cifrati;
- [ ] procedura backup keystore documentata e testata.

---

## Troubleshooting rapido

### Wallet chiuso / non trovato

- verifica `WALLET_ROOT` e `TDE_CONFIGURATION`;
- verifica permessi filesystem e path `.../tde`;
- apri keystore con `ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN ...`.

### Errore su key management privilege

- garantisci `ADMINISTER KEY MANAGEMENT` o `SYSKM`;
- usa account/password file corretti in ambienti cluster.

### Cifratura tablespace fallita

- verifica stato wallet (`OPEN`);
- verifica spazio e parametri ASM/datafile;
- riesegui in finestra di maintenance se impatta workload.

---

## Riferimenti ufficiali Oracle

- Oracle Database Advanced Security Guide 19c — *Introduction to Transparent Data Encryption*  
  https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/introduction-to-transparent-data-encryption.html
- Oracle Database Advanced Security Guide 19c — *Configuring Transparent Data Encryption*  
  https://docs.oracle.com/en/database/oracle/oracle-database/19/asoag/configuring-transparent-data-encryption.html
- Oracle Multitenant Guide 19c — amministrazione PDB (contesto operativo CDB/PDB)  
  https://docs.oracle.com/en/database/oracle/oracle-database/19/multi/administering-pdbs-with-sql-plus.html
