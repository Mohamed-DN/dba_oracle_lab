# 🤖 Automazione Avanzata: Response Files & Jinja2 Templates

> **Obiettivo**: Capire come i repository Enterprise come `oravirt/ansible-oracle` usano i template Jinja2 per automatizzare al 100% l'installazione di Oracle RAC, eliminando completamente l'interfaccia grafica (OUI).
>
> Questo documento spiega i file contenuti in `automation/templates/`.

---

## 1. Il Paradigma "Silent Installation"

Normalmente, l'installazione di Oracle (Grid o RDBMS) o la creazione del database (DBCA) avvengono tramite interfaccia grafica. L'amministratore clicca, seleziona i dischi, inserisce le password e genera un DB.

In ambienti **DevOps Enterprise**, questo è inaccettabile (non è scalabile né riproducibile). Si usa la modalità *Silent Mode*:
```bash
# Esempio reale di esecuzione silenziosa
./runInstaller -silent -responseFile /tmp/grid_install.rsp -ignorePrereqFailure
```

### Cos'è un Response File (`.rsp`)?
È un file di testo in formato chiave-valore (`chiave=valore`) fornito originariamente da Oracle. L'installatore legge le risposte da questo file invece di chiederle all'utente tramite interfaccia grafica.

---

## 2. Perché Ansible usa Jinja2 (`.j2`)?

Se hai 10 cluster Oracle diversi, non vuoi scrivere a mano 10 `grid_install.rsp` diversi.
Ansible risolve il problema usando **Jinja2** (il suo motore di template). 

Nei template del nostro lab (es. `automation/templates/grid_install.rsp.j2`), troverai sintassi come questa:

```yaml
oracle.install.crs.config.clusterNodes={{ cluster_nodes | join(',') }}
oracle.install.crs.config.diskGroups={{ crs_diskgroup | default('+CRS') }}
```

Quando lanci il playbook d'installazione, Ansible **"inietta"** le variabili lette dall'inventory (es. i nomi dei 4 nodi RAC) o da `group_vars` al posto delle parentesi graffe `{{ }}` e genera al volo il file `.rsp` finale sul server di destinazione.

---

## 3. Analisi dei Template nel Lab

Nella directory `automation/templates/` abbiamo posizionato i 4 motori fondamentali dell'automazione Oracle, estratti dalle best practices di `oravirt`:

### A. `grid_install.rsp.j2`
Imposta l'installazione di **Grid Infrastructure**.
- `oracle.install.option=CRS_SWONLY`: Installa solo il software, la configurazione vera e propria del cluster avverrà lanciando `root.sh`.
- Iniettiamo esplicitamente l'`OS_PASSWORD` dal Vault di Ansible per evitare prompt interattivi quando Grid monta gli ASM disk.

### B. `db_install.rsp.j2`
Installa il **Database Software (RDBMS)**.
- `oracle.install.db.InstallEdition=EE`: Enterprise Edition.
- `CLUSTER_NODES={{ cluster_nodes | join(',') }}`: Cruciale per RAC. Dice all'installer di copiare il binario anche sul secondo/terzo/n-esimo nodo.

### C. `dbca_rac.rsp.j2`
Il **motore di creazione del Database**.
- `databaseConfigType=RAC`: Ansible passa questa flag per assicurarsi che il database sia clusterizzato.
- Le directory di archiviazione sono dinamiche: `diskGroupName={{ data_diskgroup }}` garantisce che se per il cluster A usiamo `+DATA` e per il cluster B usiamo `+FAST_DATA`, Ansible creerà il file giusto.
- Recupera le password da `{{ vault_oracle_sys_password }}` in modo sicuro.

### D. `netca_rac.rsp.j2`
Configurazione della Rete (Listener e SCAN).
- Configura i listener locali (1521).
- Genera i file `listener.ora` e `tnsnames.ora` in modo silenzioso.

---

## 4. Domande da Colloquio sull'Argomento

### Q: "Come gestisci le chiavi e password di sys nei response file quando usi Ansible?"
**Risposta**: Non inserisco mai password in chiaro nei `.rsp` o nel repository Git. I file `.rsp` sul repository in realtà sono file `.j2` jinja2. Tramite Ansible, definisco una variabile `{{ vault_oracle_sys_password }}`. Il valore reale è cifrato localmente tramite **Ansible Vault**. Durante l'esecuzione `generate_template`, Ansible decifra al volo, popola l'rsp sul nodo target, esegue l'installazione in modalità *silent*, e come ultimo step del playbook cancella immediatamente (`state: absent`) il file `dbca.rsp` per non lasciare password in chiaro sul disco.

### Q: "Cosa succede se un'installazione 'silent' fallisce? Come la debugghi senza interfaccia grafica?"
**Risposta**: Controllo immediatamente i file di log all'interno di `$ORACLE_BASE/oraInventory/logs/` e il file log specifico della sessione di installazione in `/tmp/InstallActions...log`. Negli script automatici, catturo lo *standard error* dell'output Ansible e lo stampo in caso di fallimento per avere evidenza immediata della causa.
