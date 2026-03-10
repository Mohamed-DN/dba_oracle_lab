# 08 — TDE & Security (Transparent Data Encryption e Oracle Vault)

> Procedure per la crittografia dei dati e la gestione della sicurezza in Oracle Enterprise.

---

## Panoramica

**TDE** (Transparent Data Encryption) è il metodo standard Oracle per crittografare i dati a riposo (at rest).
**Oracle Vault** aggiunge controlli di accesso avanzati che impediscono anche ai DBA di accedere a dati sensibili.

In un ambiente bancario/finanziario, TDE e Vault sono **obbligatori** per la compliance PCI-DSS.

---

## File Contenuti

### TDE — Attività Operative
La cartella TDE contiene 56 file di attività reali su database specifici. I pattern comuni includono:
- Abilitazione TDE su un nuovo database/PDB
- Rotazione delle chiavi di crittografia
- Migrazione keystore da file a Oracle Key Vault
- Troubleshooting problemi post-reboot

### Oracle Vault
- `Enable_Disable_Vault_for_DELPHIX/` — Procedure per abilitare/disabilitare Vault quando serve Delphix (tool di virtualizzazione DB)

### PKG Encrypto
- `PKG_BANCOMAT_SECURE_spec.sql` — Specifica del package per crittografia applicativa
- `PKG_BANCOMAT_SECURE_body.sql` — Body del package

---

## Quick Reference: TDE

```sql
-- 1. Creare il Keystore (se non esiste)
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE '/u01/app/oracle/admin/DBNAME/wallet' IDENTIFIED BY "wallet_password";

-- 2. Aprire il Keystore
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "wallet_password" CONTAINER=ALL;

-- 3. Impostare la TDE Master Key
ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "wallet_password" WITH BACKUP CONTAINER=ALL;

-- 4. Crittografare un Tablespace
ALTER TABLESPACE USERS ENCRYPTION ONLINE USING 'AES256' ENCRYPT;

-- 5. Abilitare auto-login (per evitare di riaprire il wallet dopo ogni restart)
ADMINISTER KEY MANAGEMENT CREATE AUTO_LOGIN KEYSTORE FROM KEYSTORE '/u01/app/oracle/admin/DBNAME/wallet' IDENTIFIED BY "wallet_password";

-- Verifica
SELECT * FROM v$encryption_wallet;
SELECT tablespace_name, encrypted FROM dba_tablespaces;
```

---

## 🔗 Collegamento
Vedi anche: [GUIDE_DBA_ACTIVITIES.md](../../GUIDE_DBA_ACTIVITIES.md) (sezione Security)
