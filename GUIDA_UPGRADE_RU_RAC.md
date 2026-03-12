# Guida all'Upgrade delle Release Update (RU) in Oracle RAC

Questa guida spiega come gestire il passaggio da una RU esistente (es. r19.25) a una più recente (es. r19.30) utilizzando il formato **Combo Patch** e l'automazione di **opatchauto**.

> [!WARNING]
> La Release Update di **Gennaio 2026** richiede obbligatoriamente **OPatch 12.2.0.1.48** o superiore. Assicurati di aggiornare l'utility OPatch in tutte le Home prima di iniziare l'upgrade.

---

## 1. Logica di Upgrade di Oracle 19c

In Oracle 19c, l'applicazione di una nuova Release Update (RU) sopra una preesistente segue un flusso automatizzato:

1. **Rilevamento**: `opatchauto` analizza la Home e scopre la patch RU attualmente installata.
2. **Rollback Automatico**: Se la patch che stai applicando è una nuova versione della stessa tipologia (RU), il tool esegue autonomamente il *rollback* della patch precedente.
3. **Applicazione**: Una volta rimossa la vecchia versione, viene applicata la nuova release.
4. **Gestione Cluster**: Per la Grid Infrastructure, `opatchauto` gestisce autonomamente lo stop e lo start dei servizi CRS (Oracle High Availability Services).

> **Vantaggio**: Non serve lanciare comandi di disinstallazione manuali. Un unico comando (`opatchauto apply`) gestisce l'intero ciclo di vita dell'aggiornamento.

---

## 2. Workflow con Combo Patch

Le Combo Patch (come la `p38658588`) contengono sia la **Database/Grid RU** sia la **OJVM RU**. Ecco il workflow per l'upgrade su un sistema già patchato.

### Step 1: Pulizia e Preparazione
Prima di scompattare la nuova patch, libera spazio su `/u01/app/patch` (che è la nostra area di lavoro da 50GB, dato che `/tmp` è troppo piccola nelle nostre VM).

```bash
# Come root su rac1
rm -rf /u01/app/patch/*
cd /u01/app/patch
unzip -q /tmp/p38658588_190000_Linux-x86-64.zip
chown -R grid:oinstall /u01/app/patch
```

### Step 2: Identificazione dei Sotto-Patch
La Combo Patch estrarrà due directory. Per Jan 2026:
- `38629535`: La Release Update (RU) principale.
- `38523609`: La OJVM Release Update.

### Step 3: Upgrade della Grid Home (Nodi 1 e 2)
```bash
# Come root
cd /u01/app/patch/38658588/38629535
export GRID_HOME=/u01/app/19.0.0/grid
$GRID_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $GRID_HOME
```
*`opatchauto` rileverà la versione precedente (es. Jan 2025), farà rollback e applicherà la Jan 2026.*

### Step 4: Upgrade della Database Home (Nodi 1 e 2)
```bash
# Come root
cd /u01/app/patch/38658588/38629535
export ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1
$ORACLE_HOME/OPatch/opatchauto apply /u01/app/patch/38658588/38629535 -oh $ORACLE_HOME
```

### Step 5: Upgrade OJVM (Oracle Home)
La patch OJVM si applica sopra la vecchia con `opatch apply`.

```bash
# Come oracle su rac1
su - oracle
cd /u01/app/patch/38658588/38523609
$ORACLE_HOME/OPatch/opatch apply
```

---

## 3. Post-Upgrade: Datapatch

Dopo aver aggiornato i binari su tutti i nodi, devi allineare il dizionario dati del database. Questo comando va eseguito su **UN SOLO NODO** (rac1) con il DB aperto.

```bash
# Come oracle su rac1
$ORACLE_HOME/OPatch/datapatch -verbose
```

### Verifica finale
```sql
SELECT patch_id, status, description FROM dba_registry_sqlpatch;
```
*Lo status deve essere `SUCCESS` per tutti gli ingressi più recenti.*

---

## 4. Troubleshooting: Spazio Disco

Se un upgrade fallisce con errori di "Space Check", ricordati che `opatch` mantiene i backup delle patch precedenti in `$ORACLE_HOME/.patch_storage`.

**Best Practice di Pulizia:**
Una volta che l'upgrade è terminato con successo, **CANCELLA** sempre i file estratti per non saturare la partizione `/u01`.

```bash
# Come root
rm -rf /u01/app/patch/*
```
*(NON cancellare mai la cartella nascosta `.patch_storage` dentro le Home).*
