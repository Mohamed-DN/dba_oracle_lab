# Automazione Completa: RAC Primario + RAC Standby + Data Guard
> Basato sui repository ufficiali `oraclebase/vagrant`, riadattato per simulare interamente le **Fasi da 0 a 4** del tuo piano di studi.

Questo modulo Vagrant ti permette di alzare l'intera infrastruttura del lab con soli pochi comandi, automatizzando ore di noiose configurazioni manuali (installazione Grid, DBCA, cloni, Standby Redo Logs, RMAN Duplicate e Broker).

## ⚠️ Requisiti Hardware (ATTENZIONE)
Avrai 5 VM accese in contemporanea:
- `dnsnode` (1 GB)
- `rac1` (8 GB)
- `rac2` (8 GB)
- `racstby1` (8 GB)
- `racstby2` (8 GB)

**Totale RAM richiesta: 33 GB Fisici sul tuo Host**. Se non hai almeno 64 GB di RAM sul tuo computer, la macchina esploderà o andrà in Swap pesantissimo rallentando tutto. In tal caso, dovrai editare il file `config/vagrant.yml` per abbassare la `mem_size` a `4096` (a discapito della lentezza dell'installer Oracle).

## Preparazione Software (MANUALE)
Prima di lanciare qualsiasi comando, devi scaricare i binari originali Oracle e inserirli nella cartella `/software`.
1. Crea la cartella `software` qui nella root: `mkdir software`
2. Mettici dentro i due zip di Oracle 19c per Linux:
   - `LINUX.X64_193000_grid_home.zip`
   - `LINUX.X64_193000_db_home.zip`

*(Nota: L'ISO di Oracle Linux viene scaricata in automatico da Vagrant Cloud tramite il box base di ol7)*

## Istruzioni di Avvio (L'Ordine è TASSATIVO)
L'architettura RAC dipende strettamente dal DNS, e il Nodo 2 dipende dal Nodo 1. Apri 5 terminali diversi e lancia in quest'ordine:

### 1. Il Cuore (DNS)
```bash
cd dns
vagrant up
```
*(Attendi fine installazione)*

### 2. RAC Primario (Produzione)
```bash
cd rac1
vagrant up
```
*(Attendi 40-50 minuti. Installerà Grid e configurerà `RACDB` mettendo il DB in ARCHIVELOG e creando gli SRLs)*

```bash
cd rac2
vagrant up
```
*(Attendi 30 minuti. Si aggancia al cluster e avvia l'istanza 2).*

### 3. RAC Standby (Protezione)
```bash
cd racstby1
vagrant up
```
*(Attendi 40 minuti. Installerà Grid, poi lancerà un `RMAN DUPLICATE FOR STANDBY FROM ACTIVE DATABASE` per copiare fisicamente `RACDB` via rete sul sito di Standby)*

```bash
cd racstby2
vagrant up
```
*(Attendi 30 minuti. Si aggancia allo Standby Cluster)*

### 4. Attivazione del Broker (DGMGRL)
A differenza del resto, l'attivazione del Broker DEVE essere attivata quando tutte e 5 le macchine sono 100% operative e si vedono sulla rete.
Da una sessione SSH verso `rac1`:
```bash
sh /vagrant_scripts/configure_broker.sh
```

## Come distruggere il Laboratorio
Quando hai finito l'esperimento:
```bash
cd racstby2 && vagrant destroy -f
cd racstby1 && vagrant destroy -f
cd rac2 && vagrant destroy -f
cd rac1 && vagrant destroy -f
cd dns && vagrant destroy -f
```
Per rimuovere fisicamente anche i pesanti dischi ASM condivisi generati in `/shared_disks`:
```bash
rm -rf ../shared_disks/*
```
