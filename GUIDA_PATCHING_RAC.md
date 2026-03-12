# Guida al Patching Post-Installazione (Oracle RAC 19c)

Questa guida è un riferimento "day-2" per l'amministrazione del tuo cluster RAC. Ti spiega come gestire gli aggiornamenti trimestrali (Release Update), come passare da una versione all'altra, cos'è una *Combo Patch* e come tenere pulito il filesystem per non esaurire lo spazio.

> [!IMPORTANT]
> **REQUISITO MINIMO OPATCH (Patch Gennaio 2026)**
> Se stai applicando la Combo Patch di Gennaio 2026 (p38658588) o successive, devi utilizzare **OPatch versione 12.2.0.1.48** o superiore. Le versioni precedenti (come la .47 o .43) falliranno i pre-requisiti di `opatchauto`.

---

## 1. Che cos'è una "Combo Patch"?

Spesso su Oracle Support (MOS) troverai due tipi di download per le patch trimestrali:
1. **Patch Singole**: Ad esempio, scarichi lo zip per la *Grid Infrastructure Release Update (GI RU)* e uno zip separato per la *Oracle Java VM (OJVM) Release Update*.
2. **Combo Patch**: È un singolo mega-zip (come ad es. la `p38658588` per Jan 2026) che include **entrambe** le patch al suo interno.

### Come si usa una Combo Patch?
È semplicissimo: quando scompatti lo zip della Combo Patch, verranno create due sottocartelle numeriche. Ad esempio, estraendo la `p38658588` potresti trovarti:
- `/u01/app/patch/38658588/38629535` (che è la vera GI/DB RU)
- `/u01/app/patch/38658588/38523609` (che è la vera OJVM RU)

A quel punto, usi `opatchauto` puntando alla prima cartella, e `opatch apply` puntando alla seconda cartella. La Combo Patch è solo un "contenitore" per convenienza di download.

---

## 2. Upgrade da una RU "vecchia" a una "nuova"

Se hai già patchato il tuo cluster (es. alla Jan 2025) e ora vuoi passare alla Jan 2026, **NON devi disinstallare manualmente la patch precedente**. 

Il tool `opatchauto` (che usi per applicare le Release Update) è intelligente:
1. Rileva automaticamente quale RU è installata.
2. Controlla quale RU stai cercando di installare.
3. Se la nuova è superiore, **effettua automaticamente il rollback (disinstallazione) della vecchia** prima di applicare la nuova.
4. Riavvia i servizi CRS.

Fa tutto da solo in un unico comando! (Ma tu ricordati di fare il backup compresso della ORACLE_HOME e GRID_HOME prima di lanciare il comando, come *Best Practice*).

---

## 3. Pulizia Spazio Disco (Pulire le Patch Vecchie)

Le patch Oracle sono enormi (spesso > 3 GB scompattate). Nelle nostre VM, lo spazio su `/u01` è di circa 50 GB. Se mantieni ogni singola patch estratta nella cartella `/u01/app/patch`, in due cicli di aggiornamento riempirai il disco.

### Cosa puoi cancellare IN SICUREZZA:
Una volta che una patch è stata applicata con successo (`opatchauto apply` e `datapatch` finiti), **i file estratti in `/u01/app/patch` non servono più a nulla**. L'utility `opatch` ha già copiato tutto ciò che le serve all'interno di `$ORACLE_HOME/.patch_storage` (cartella nascosta usata per il rollback).

**Procedura di pulizia (su tutti i nodi come root):**
```bash
su - root

# 1. Rimuovi le cartelle delle patch scompattate
rm -rf /u01/app/patch/*

# 2. Rimuovi i file ZIP originali scaricati (se sono rimasti in /tmp o /u01)
rm -f /tmp/p*.zip
rm -f /u01/app/patch/*.zip

# 3. Elimina i backup .tar.gz vecchi delle ORACLE_HOME 
# (Tieni solo l'ultimo precedente funzionante, cancella quelli di mesi fa)
# Esempio: rm /u01/app/grid_home_backup_20250101.tar.gz
```

> **MAI CANCELLARE la cartella `$ORACLE_HOME/.patch_storage`**. Se lo fai, distruggi la capacità di OPatch di fare rollback o applicare patch future, corrompendo irrimediabilmente la home!

---

## 4. Procedura di Patching con la Combo Patch (Esempio)

Hai scaricato la Combo Patch `p38658588_190000_Linux-x86-64.zip` in `/tmp/` su entrambi i nodi. Ecco il flusso:

### Step 1: Estrazione (Entrambi i nodi)
```bash
su - root
mkdir -p /u01/app/patch/
cd /u01/app/patch/
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip

# Trova i due ID interni:
ls -l /u01/app/patch/38658588/
# Esempio output (i numeri reali trovati):
# drwxr-xr-x 38523609  (questa è la OJVM)
# drwxr-x--- 38629535  (questa è la RU di DB/Grid)

# Assegna diritti corretti
chown -R grid:oinstall /u01/app/patch/
```

### Step 2: Applicazione alla Grid Home (`opatchauto`)
Usa l'ID della cartella della RU Grid/DB.
```bash
# Come root
cd /u01/app/patch/38658588/38629535
export GRID_HOME=/u01/app/19.0.0/grid
$GRID_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $GRID_HOME
# Ripeti su rac2
```

### Step 3: Applicazione alla DB Home (`opatchauto`)
```bash
# Come root
cd /u01/app/patch/38658588/38629535
chown -R oracle:oinstall /u01/app/patch/
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
# Ripeti su rac2
```

### Step 4: Applicazione OJVM alla DB Home (`opatch`)
```bash
# Come oracle
su - oracle
cd /u01/app/patch/38658588/38523609
$ORACLE_HOME/OPatch/opatch apply
# Rispondi 'y' quando richiesto
# Ripeti su rac2
```

### Step 5: Datapatch (Solo dopo che il DB è creato e aperto)
```bash
# Come oracle su rac1
$ORACLE_HOME/OPatch/datapatch -verbose
```

---

## 5. Come fare Rollback (Emergenza)

Se una patch applicata causa problemi gravissimi e vuoi rimuoverla, puoi tornare indietro sfruttando il repository locale di OPatch. Non serve riscaricare lo zip originale.

**Per una Release Update (Grid o DB):**
```bash
# Come root
export ORACLE_HOME=/u01/app/19.0.0/grid   # o dbhome_1
$ORACLE_HOME/OPatch/opatchauto rollback -id 38629535 -oh $ORACLE_HOME
```

**Per la patch OJVM (DB Home):**
```bash
# Come oracle
$ORACLE_HOME/OPatch/opatch rollback -id 38523609
```

---

## 6. Verifica Post-Patching

Verifica i binari (livello Sistema Operativo):
```bash
$ORACLE_HOME/OPatch/opatch lspatches
```

Verifica il Data Dictionary (livello Database):
```sql
SELECT patch_id, action, status, action_time, description
FROM dba_registry_sqlpatch
ORDER BY action_time DESC;
```
*(Lo status finale deve essere sempre `SUCCESS`).*
