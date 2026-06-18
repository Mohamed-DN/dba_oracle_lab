# Guida al Patching Post‑Installazione (Oracle Database 19c Single Instance)

> [!NOTE]  
> **RIFERIMENTI UTILI**  
> - **Cheat Sheet Rapido**: [CS_OPATCH_DATAPATCH.md](../../01_operations/01_cheat_sheets/CS_OPATCH_DATAPATCH.md) (comandi rapidi di inventario e datapatch).  
> - Documentazione Oracle: “Database Release Update 19c Readme” associato alla patch scaricata.

Questa guida è un riferimento “day‑2” per la gestione degli aggiornamenti trimestrali (Release Update) del tuo database Oracle 19c in installazione **single instance**. Spiega come applicare le patch, come passare da una versione all’altra, cosa è una *Combo Patch* e come mantenere pulito il filesystem.

> [!IMPORTANT]  
> **REQUISITO MINIMO OPATCH**  
> Prima di applicare qualsiasi Release Update, verifica il **README** della patch.  
> Ad esempio, la Combo Patch di Gennaio 2026 (p38658588) richiede **OPatch 12.2.0.1.48** o superiore.  
> Puoi controllare la versione corrente con `$ORACLE_HOME/OPatch/opatch version`.

---

## 1. Che cos’è una “Combo Patch”?

Sul supporto Oracle (MOS) spesso trovi due tipi di download:
1. **Patch singole**: un file per il *Database Release Update (RU)* e un file separato per la *Oracle Java VM (OJVM) Release Update*.
2. **Combo Patch**: un unico grande ZIP che contiene **entrambe** le patch.

Estraendo lo ZIP della Combo Patch si ottengono due sottocartelle numeriche:
```
/u01/app/patch/38658588
    ├── 38629535   ← Database RU
    └── 38523609   ← OJVM RU
```
La Combo Patch è quindi un “contenitore” per semplificare il download.

---

## 2. Aggiornamento da una RU a un’altra (upgrade)

Se il tuo database è già stato patchato (es. Jan 2025) e ora vuoi passare alla Jan 2026, **non devi disinstallare manualmente la vecchia patch**.

Il comando `opatch apply` (usato per applicare le Release Update) esegue automaticamente:
1. Rileva la RU già installata.
2. Verifica che la nuova sia più recente.
3. Effettua il **rollback automatico della vecchia patch** prima di applicare la nuova.
4. Riesegue eventuali script di post‑installazione.

Tutto questo con un unico comando.  
*Ricordati comunque di fare un backup compresso della `ORACLE_HOME` prima di lanciare qualsiasi operazione di patch*.

---

## 3. Pulizia dello spazio disco

Le patch Oracle, una volta espanse, possono occupare diversi GB (spesso > 3 GB).  
Se conservi tutti i file nella directory di staging (es. `/u01/app/patch`), il disco si riempie rapidamente.

### Cosa cancellare **IN SICUREZZA** dopo un’applicazione riuscita:

```bash
# 1. Rimuovi le cartelle delle patch scompattate
rm -rf /u01/app/patch/*

# 2. Elimina i file ZIP originali (se scaricati in /tmp o altrove)
rm -f /tmp/p*.zip
rm -f /u01/app/patch/*.zip

# 3. Elimina i backup vecchi della ORACLE_HOME
#    Tieni solo l’ultimo backup funzionante.
#    Esempio: rm /u01/app/oracle/product/19.0.0/dbhome_1_backup_20250101.tar.gz
```

> [!CAUTION]  
> **NON CANCELLARE MAI** la directory `$ORACLE_HOME/.patch_storage`.  
> Contiene le informazioni necessarie per i rollback e per le applicazioni future. La sua rimozione compromette irrimediabilmente l’inventario OPatch della home.

---

## 4. Procedura di Patching con una Combo Patch (esempio)

Hai scaricato la Combo Patch `p38658588_190000_Linux-x86-64.zip` e l’ultima utility OPatch `p6880880_190000_Linux-x86-64.zip` nella directory `/tmp`.

### ⚠️ Step 0: Aggiornare OPatch (OBBLIGATORIO)

**Su un solo nodo** (l’ambiente è single instance), esegui come utente proprietario della Oracle home (es. `oracle`):

```bash
# Backup della vecchia OPatch
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.$(date +%Y%m%d)

# Estrai la nuova OPatch
unzip -q /tmp/p6880880_190000_Linux-x86-64.zip -d $ORACLE_HOME/

# Verifica versione
$ORACLE_HOME/OPatch/opatch version
```

### Step 1: Estrazione della Combo Patch

```bash
mkdir -p /u01/app/patch
cd /u01/app/patch
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip

# Individua i due ID
ls -l /u01/app/patch/38658588/
# Output d'esempio:
# drwxr-xr-x 38629535  ← Database RU
# drwxr-xr-x 38523609  ← OJVM RU
```

### Step 2: Pre‑requisiti prima dell’applicazione

1. **Esegui un backup dell’ORACLE_HOME** (tar, cp, snapshot, ecc.)  
2. **Ferma il listener e il database:**

   ```bash
   # Ferma il listener (se in esecuzione dalla stessa Oracle Home)
   lsnrctl stop

   # Ferma il database (modalità immediate o normal)
   sqlplus / as sysdba
   SQL> shutdown immediate;
   SQL> exit;
   ```

3. **Assicurati che nessun processo stia ancora usando la home** (verifica con `fuser $ORACLE_HOME/bin/oracle`).

### Step 3: Applicazione del Database Release Update (RU)

```bash
cd /u01/app/patch/38658588/38629535
$ORACLE_HOME/OPatch/opatch apply
```

Rispondere **y** quando richiesto. OPatch eseguirà tutte le operazioni (incluso eventuale rollback di una RU precedente) e potrà richiedere di eseguire uno script come `root` se la patch contiene componenti che lo necessitano (es. `oracle.rdbms.rsf.ic`).  
Se richiesto, esegui il comando come `root` e poi premi `Invio` per proseguire.

### Step 4: Applicazione della OJVM Release Update

```bash
cd /u01/app/patch/38658588/38523609
$ORACLE_HOME/OPatch/opatch apply
```

Anche qui, rispondere **y** alle richieste.  
Se viene chiesto di eseguire uno script come `root`, fallo immediatamente.

### Step 5: Avvio del database e Datapatch

```bash
# Avvia il listener
lsnrctl start

# Avvia il database in modalità upgrade (se richiesto da datapatch) o normalmente
sqlplus / as sysdba
SQL> startup;
SQL> exit;

# Esegui datapatch per aggiornare il dizionario dati
$ORACLE_HOME/OPatch/datapatch -verbose
```

> [!TIP]  
> `datapatch` si connette automaticamente come SYSDBA a tutti i PDB (se presenti) e applica le modifiche SQL necessarie.  
> Al termine, verifica che tutti gli script abbiano stato `SUCCESS`.

---

## 5. Rollback (situazione d’emergenza)

Se una patch crea problemi e vuoi rimuoverla, non serve riscaricare il file originale.  
OPatch conserva tutte le informazioni nella directory nascosta `.patch_storage`.

**Rimuovere la Database RU:**
```bash
$ORACLE_HOME/OPatch/opatch rollback -id 38629535
```

**Rimuovere la OJVM RU:**
```bash
$ORACLE_HOME/OPatch/opatch rollback -id 38523609
```

Dopo il rollback, riavvia il database ed esegui di nuovo `datapatch` per riallineare il dizionario dati.

---

## 6. Verifica post‑patching

### Livello Sistema Operativo (inventario OPatch)
```bash
$ORACLE_HOME/OPatch/opatch lspatches
```
Dovresti vedere elencate entrambe le patch applicate.

### Livello Database (dizionario dati)
```sql
SELECT patch_id, action, status, action_time, description
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;
```
*Lo stato `SUCCESS` per entrambe le patch è l’unico risultato accettabile.*

---

## Riepilogo dei comandi principali

| Operazione                          | Comando eseguito come `oracle`              |
|-------------------------------------|---------------------------------------------|
| Backup OPatch                       | `mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch.bak` |
| Aggiornare OPatch                   | `unzip p6880880*.zip -d $ORACLE_HOME/`      |
| Applicare Database RU               | `cd <dir_RU>; opatch apply`                |
| Applicare OJVM RU                   | `cd <dir_OJVM>; opatch apply`              |
| Aggiornare catalogo                 | `datapatch -verbose`                        |
| Verificare patch                    | `opatch lspatches`                          |
| Rollback                            | `opatch rollback -id <ID_patch>`            |

Con questa procedura il tuo database single instance rimane aggiornato in modo sicuro, pulito e perfettamente documentato.
