# Percorso Oracle Linux 8 e ASMLib v3 per il Core Lab

## Obiettivo

Adattare il Core Lab RAC + Data Guard a Oracle Linux 8 senza mescolare i
pacchetti del track legacy Oracle Linux 7.9. Questa guida è un'appendice alle
Fasi 0-2: topologia, nomi host e database restano invariati.

## Assessment

Prima del build registra:

| Campo | Valore |
| --- | --- |
| Release Oracle Linux 8 | `<OL8_RELEASE>` |
| Kernel attivo | `<KERNEL_RELEASE>` |
| Oracle Database e Grid Infrastructure | `19c`, stessa RU approvata |
| Versione OPatch approvata | `<OPATCH_VERSION>` |
| Metodo discovery ASM | `ASMLib v3` |

Oracle Linux 8 è la baseline raccomandata per nuove VM del lab. Non installare
RPM EL7 su OL8 e non riutilizzare una Golden Image costruita con OL7.

## Procedura operativa

### 1. Preparare l'OS

Usa le Fasi 0 e 1 per rete, DNS, `/u01`, utenti e limiti. Su ogni nodo verifica:

```bash
cat /etc/oracle-release
uname -r
id grid
id oracle
```

Applica il pacchetto preinstall compatibile con OL8:

```bash
dnf install -y oracle-database-preinstall-19c
```

### 2. Installare ASMLib v3

Segui la documentazione Oracle Linux ASMLib e usa i repository configurati per
la release OL8 scelta:

```bash
dnf install -y oracleasm-support oracleasmlib
oracleasm configure -i
oracleasm status
```

Durante `oracleasm configure -i` imposta owner `grid`, group `asmadmin`, avvio
e scan al boot. Se un pacchetto richiesto non è disponibile per il kernel in
uso, fermati: non forzare RPM di un'altra release.

### 3. Etichettare e verificare i dischi

Dopo aver verificato con `lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS` che i device
siano quelli corretti:

```bash
oracleasm createdisk CRS1 /dev/sdc1
oracleasm createdisk CRS2 /dev/sdd1
oracleasm createdisk CRS3 /dev/sde1
oracleasm createdisk DATA /dev/sdf1
oracleasm createdisk RECO /dev/sdg1
oracleasm scandisks
oracleasm listdisks
```

Ripeti solo `scandisks` e `listdisks` sul secondo nodo dello stesso cluster.

### 4. Installare Grid Infrastructure

Nella Fase 2 seleziona il discovery path ASMLib validato dal preflight. Non
applicare workaround OL7 automaticamente: verifica prima l'errore effettivo e
la README della RU approvata.

## Validazione finale

```bash
cat /etc/oracle-release
uname -r
oracleasm status
oracleasm listdisks
ls -l /dev/oracleasm/disks
```

Prima di avviare Grid Setup conserva l'output e conferma che i nodi dello stesso
cluster vedano gli stessi dischi.

## Troubleshooting rapido

| Sintomo | Controllo | Azione |
| --- | --- | --- |
| `oracleasm` non disponibile | `dnf info oracleasm-support oracleasmlib` | Verifica repository OL8 e documentazione ASMLib |
| dischi non visibili | `lsblk`, `oracleasm status`, log kernel | Correggi mapping, ownership o scan; non riformattare device non identificati |
| RPM EL7 presente | `rpm -qa | grep -i oracleasm` | Rimuovi il mix di release e reinstalla pacchetti OL8 approvati |
| Grid Setup non vede ASM | discovery path e permessi | Verifica il path ASMLib reale prima di cambiare configurazione |

## Riferimenti

- [Oracle Linux ASMLib](https://docs.oracle.com/en/operating-systems/oracle-linux/asmlib/)
- [Checklist Linux Database 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/operating-system-checklist-for-oracle-database-installation-on-linux.html)
- [Checklist Grid Infrastructure 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwlin/operating-system-checklist-for-oracle-grid-infrastructure-and-oracle-rac.html)
