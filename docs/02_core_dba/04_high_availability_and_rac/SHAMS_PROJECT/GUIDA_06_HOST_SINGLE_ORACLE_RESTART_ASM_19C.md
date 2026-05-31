# Allegato Host M24SHAMS: Oracle Restart, ASM e Oracle Database 19c

## Obiettivo operativo

Preparare i due host Linux che ospiteranno `M24SHAMSPEC` nel sito PE e
`M24SHAMSSEC` nel sito SE. L'allegato copre Grid Infrastructure standalone,
Oracle Restart/HAS, ASM, Database Home 19c e listener Data Guard.

La creazione database e la configurazione Data Guard sono descritte nella
[SOP Enterprise M24SHAMS](./GUIDA_01_M24SHAMS_SINGLE_NON_CDB_DATAGUARD.md).

## Ambito

| Incluso | Escluso |
| --- | --- |
| Linux, rete, DNS, NTP | Oracle RAC |
| multipath, udev, ASM | private interconnect RAC |
| Grid Infrastructure standalone/HAS | thread redo 2 |
| Oracle Database Home 19c | `srvctl add instance` |
| listener applicativo e listener DG | CRS diskgroup dedicato non necessario per HAS |
| RU alignment e raccolta evidenze | disabilitazione cieca di SELinux o firewall |

## Scheda inventario host

Compilare prima di modificare i server.

| Campo | PE primary | SE standby |
| --- | --- | --- |
| Hostname FQDN | `<PRIMARY_FQDN>` | `<STANDBY_FQDN>` |
| Distribuzione Linux | `<DISTRO_VERSION>` | `<DISTRO_VERSION>` |
| Kernel | `<KERNEL>` | `<KERNEL>` |
| vCPU / RAM | `<CPU_RAM>` | `<CPU_RAM>` |
| IP public | `<PRIMARY_PUBLIC_IP>` | `<STANDBY_PUBLIC_IP>` |
| IP Data Guard | `<PRIMARY_DG_IP>` | `<STANDBY_DG_IP>` |
| DNS forward / reverse | `<OK/KO>` | `<OK/KO>` |
| NTP / chrony | `<SOURCE>` | `<SOURCE>` |
| LUN DATA | `<WWID_LIST>` | `<WWID_LIST>` |
| LUN FRA | `<WWID_LIST>` | `<WWID_LIST>` |
| Ridondanza storage | `<EXTERNAL/NORMAL/HIGH>` | `<EXTERNAL/NORMAL/HIGH>` |
| Grid Home | `<GRID_HOME>` | `<GRID_HOME>` |
| Oracle Base Grid | `<GRID_BASE>` | `<GRID_BASE>` |
| Oracle Home DB | `<ORACLE_HOME>` | `<ORACLE_HOME>` |
| Oracle Base DB | `<ORACLE_BASE>` | `<ORACLE_BASE>` |
| Inventory | `<ORA_INVENTORY>` | `<ORA_INVENTORY>` |
| RU approvata | `<RU_APPROVATA>` | `<RU_APPROVATA>` |

## Procedura operativa

### 1. Verifica Linux

Raccogli evidenze:

```bash
hostname -f
cat /etc/os-release
uname -r
lscpu
free -h
df -hT
df -ih
timedatectl
chronyc sources -v
getenforce
```

Lo standard deve indicare una distribuzione certificata per Oracle 19c. Se
viene usato un RPM `oracle-database-preinstall-19c`, validane compatibilita' e
contenuto: non sostituisce il controllo DBA.

### 2. Utenti, gruppi e directory

Conferma gli utenti tecnici e i gruppi approvati:

```text
grid    -> oinstall, asmadmin, asmdba, asmoper
oracle  -> oinstall, dba, oper, backupdba, dgdba, kmdba, asmdba
```

Verifica:

```bash
id grid
id oracle
getent group oinstall
getent group dba
getent group asmadmin
getent group asmdba
getent group backupdba
getent group dgdba
getent group kmdba
```

Le directory devono seguire lo standard locale. Esempio:

```text
<GRID_BASE>
<GRID_HOME>
<ORACLE_BASE>
<ORACLE_HOME>
<ORA_INVENTORY>
```

Non copiare path storici PEYTECH senza confrontarli con l'inventario del server.

### 3. Kernel, limits e sicurezza host

Raccogli:

```bash
sysctl -a | egrep 'shm|sem|file-max|ip_local_port_range|aio-max-nr'
ulimit -a
grep -R "oracle\\|grid" /etc/security/limits.conf /etc/security/limits.d 2>/dev/null
firewall-cmd --state
firewall-cmd --list-all
```

Applica solo la baseline Linux approvata per la distribuzione certificata.

Non disabilitare SELinux o firewall per comodita'. Se una policy aziendale
richiede una modifica, registrala nel change e limita l'apertura alle porte
necessarie:

| Flusso | Porta | Origine / destinazione |
| --- | --- | --- |
| Listener applicativo | `<PORTA_APP>` | reti applicative autorizzate |
| Listener Data Guard | `1531/TCP` | PE Data Guard `<->` SE Data Guard |
| SSH amministrativo | `22/TCP` | bastion autorizzati |
| Monitoring | `<PORTE_MONITORING>` | sistemi autorizzati |

### 4. DNS, NTP e rete Data Guard

Verifica forward e reverse lookup:

```bash
getent hosts <PRIMARY_FQDN>
getent hosts <STANDBY_FQDN>
getent hosts <PRIMARY_DG_FQDN>
getent hosts <STANDBY_DG_FQDN>
```

Misura latenza e stabilita' della rete PE-SE:

```bash
ping -c 20 <REMOTE_DG_FQDN>
```

Per il gate `SYNC` usa anche test applicativi e metriche Oracle. Il ping non e'
una prova sufficiente del costo commit.

### 5. Storage, multipath e udev

Lo storage team deve consegnare WWID, dimensioni e ridondanza. Verifica:

```bash
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT,WWN
multipath -ll
udevadm info --query=all --name=<DEVICE>
```

Regole:

1. identificare i device con WWID stabile;
2. non usare nomi `/dev/sdX` come contratto persistente;
3. verificare ownership e permessi per ASM;
4. non presentare lo stesso LUN ai due siti salvo architettura storage
   esplicitamente progettata e approvata;
5. conservare output multipath e regole udev nell'evidence pack.

### 6. Installazione Grid Infrastructure standalone

Usa il media Oracle 19c approvato e la RU prevista dal change. Avvia il setup
come utente `grid`:

```bash
<GRID_HOME>/gridSetup.sh
```

Seleziona installazione standalone server / Oracle Restart, non cluster RAC.
Configura ASM con il diskgroup richiesto dalla baseline infrastrutturale.

Esegui gli script root solo dopo review:

```bash
<ORA_INVENTORY>/orainstRoot.sh
<GRID_HOME>/root.sh
```

Verifica:

```bash
crsctl check has
srvctl status asm
asmcmd lsdg
```

### 7. Diskgroup applicativi ASM

Crea diskgroup dedicati secondo ridondanza e capacity plan approvati:

```text
+M24SHAMS_DATA
+M24SHAMS_FRA
```

Prima della creazione registra:

| Diskgroup | Capacita' iniziale | Ridondanza | AU size | Soglia warning | Soglia critica |
| --- | --- | --- | --- | --- | --- |
| `+M24SHAMS_DATA` | `<SIZE>` | `<TYPE>` | `<AU>` | `<PERCENT>` | `<PERCENT>` |
| `+M24SHAMS_FRA` | `<SIZE>` | `<TYPE>` | `<AU>` | `<PERCENT>` | `<PERCENT>` |

Validazione:

```bash
asmcmd lsdg
asmcmd ls +M24SHAMS_DATA
asmcmd ls +M24SHAMS_FRA
```

### 8. Installazione Database Home 19c

Come utente `oracle`:

```bash
<ORACLE_HOME_INSTALL_MEDIA>/runInstaller
```

Installa software only. Non creare ancora il database. Usa stesso layout e
stessa RU sui due siti.

Verifica:

```bash
<ORACLE_HOME>/OPatch/opatch lsinventory
<ORACLE_HOME>/bin/sqlplus -v
```

Confronta gli inventari PE e SE. Risolvi ogni differenza prima del duplicate.

### 9. Listener applicativo e listener Data Guard

Configura un listener dedicato Data Guard su `1531/TCP`. Mantieni separato il
listener applicativo se previsto dallo standard aziendale.

Esempio minimo:

```text
LISTENER_DG =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = <LOCAL_DG_FQDN>)(PORT = 1531))
    )
  )
```

Registra il listener con Oracle Restart secondo la RU installata:

```bash
srvctl add listener -help
srvctl config listener
srvctl status listener
lsnrctl status LISTENER_DG
```

La sezione statica per `M24SHAMSPEC_DG` e `M24SHAMSSEC_DG` viene completata
durante la SOP database.

### 10. Logging, audit ed evidence pack

Conserva almeno:

```text
01_host_inventory/
02_dns_ntp_network/
03_multipath_udev/
04_grid_install/
05_asm/
06_db_home_inventory/
07_listener/
08_go_no_go/
```

Non salvare password, wallet password o secret in chiaro.

## Validazione finale

| Controllo | Comando | Esito |
| --- | --- | --- |
| DNS e reverse DNS | `getent hosts` | `<OK/KO>` |
| Orario sincronizzato | `timedatectl`, `chronyc sources -v` | `<OK/KO>` |
| Multipath stabile | `multipath -ll` | `<OK/KO>` |
| Oracle Restart | `crsctl check has` | `<OK/KO>` |
| ASM | `srvctl status asm`, `asmcmd lsdg` | `<OK/KO>` |
| Diskgroup applicativi | `asmcmd ls +M24SHAMS_DATA`, `asmcmd ls +M24SHAMS_FRA` | `<OK/KO>` |
| Grid RU | `<GRID_HOME>/OPatch/opatch lsinventory` | `<OK/KO>` |
| DB Home RU | `<ORACLE_HOME>/OPatch/opatch lsinventory` | `<OK/KO>` |
| Listener DG | `lsnrctl status LISTENER_DG` | `<OK/KO>` |
| Rete PE-SE | test porta `1531/TCP` e latenza | `<OK/KO>` |

Il passaggio alla SOP database e' consentito solo se tutti i controlli sono
`OK` oppure esiste una deroga firmata.

## Rollback

Se l'installazione host fallisce:

1. interrompi prima della creazione database;
2. conserva log installer, root script e inventario;
3. rimuovi solo le risorse create dal change usando gli strumenti Oracle
   previsti;
4. non cancellare LUN, multipath map o regole udev senza approvazione storage;
5. ripristina configurazioni firewall e sicurezza secondo il change;
6. ripeti assessment prima di un nuovo tentativo.

## Troubleshooting rapido

| Sintomo | Controllo | Azione |
| --- | --- | --- |
| `crsctl check has` fallisce | log Grid Infrastructure e root script | Correggi Oracle Restart prima di ASM |
| ASM non vede dischi | `multipath -ll`, udev, ownership | Coinvolgi storage; non inizializzare device incerti |
| Diskgroup non monta | alert ASM, ridondanza e quorum | Correggi storage prima del DBCA |
| RU diverse PE/SE | `opatch lsinventory` | Allinea Grid e DB Home prima del duplicate |
| Listener DG non parte | `listener.ora`, porta, firewall | Correggi bind e regole rete |
| DNS incoerente | `getent hosts`, reverse lookup | Correggi DNS; non fissare IP temporanei nel TNS definitivo |
