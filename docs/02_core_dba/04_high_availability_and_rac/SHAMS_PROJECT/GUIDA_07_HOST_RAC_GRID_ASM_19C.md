# SHAMS PROJECT: Host RAC Grid Infrastructure, ASM e Oracle Database 19c

## Obiettivo operativo

Preparare due cluster RAC distinti, uno in PE e uno in SE, per i blueprint `S3`
e `S4`. Ogni cluster ospita due nodi Oracle 19c, ASM, SCAN e Database Home
allineati alla stessa RU.

## Inventario cluster

| Campo | Cluster PE | Cluster SE |
| --- | --- | --- |
| Nodi | `<PE_NODE1>`, `<PE_NODE2>` | `<SE_NODE1>`, `<SE_NODE2>` |
| Public IP | `<PE_PUBLIC_IPS>` | `<SE_PUBLIC_IPS>` |
| Private interconnect | `<PE_PRIVATE_IPS>` | `<SE_PRIVATE_IPS>` |
| VIP | `<PE_VIPS>` | `<SE_VIPS>` |
| SCAN name | `<PRIMARY_SCAN>` | `<STANDBY_SCAN>` |
| SCAN IP | `<PRIMARY_SCAN_IPS>` | `<STANDBY_SCAN_IPS>` |
| DG network | `<PE_DG_IPS>` | `<SE_DG_IPS>` |
| Grid Home | `<GRID_HOME>` | `<GRID_HOME>` |
| Oracle Home | `<ORACLE_HOME>` | `<ORACLE_HOME>` |
| RU | `<RU_APPROVATA>` | `<RU_APPROVATA>` |
| ASM DATA / FRA | `+M24SHAMS_DATA`, `+M24SHAMS_FRA` | `+M24SHAMS_DATA`, `+M24SHAMS_FRA` |

## Procedura operativa

### 1. Linux, DNS e NTP

Su ogni nodo:

```bash
hostname -f
cat /etc/os-release
uname -r
timedatectl
chronyc sources -v
getent hosts <LOCAL_NODE>
getent hosts <REMOTE_NODE>
getent hosts <LOCAL_SCAN>
```

DNS deve risolvere public hostname, VIP e SCAN. Non usare `/etc/hosts` come
sostituto definitivo di SCAN DNS.

### 2. Utenti, gruppi e prerequisiti

Verifica utenti `grid` e `oracle`, gruppi OS, limits, sysctl e RPM richiesti
dalla matrice Oracle Linux certificata.

```bash
id grid
id oracle
ulimit -a
sysctl -a | egrep 'shm|sem|file-max|ip_local_port_range|aio-max-nr'
```

Non disabilitare SELinux o firewall senza change approvato.

### 3. Rete cluster

Verifica:

- public network;
- private interconnect dedicato e ridondato;
- VIP;
- SCAN;
- rete Data Guard verso il sito remoto;
- MTU coerente;
- porte listener applicativo e `1531/TCP` DG.

```bash
ping -c 10 <REMOTE_PRIVATE_NODE>
ping -c 10 <REMOTE_DG_ENDPOINT>
```

Non instradare il private interconnect tra siti.

### 4. Storage condiviso e multipath

Ogni cluster deve avere storage condiviso tra i propri nodi, ma separato
dall'altro sito.

```bash
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINT,WWN
multipath -ll
```

Conserva WWID, LUN mapping, ownership e ridondanza. Non usare `/dev/sdX` come
identificatore persistente.

### 5. Grid Infrastructure cluster

Installa Grid Infrastructure 19c come cluster RAC:

```bash
<GRID_HOME>/gridSetup.sh
```

Configura Clusterware, SCAN, ASM e listener. Esegui root script dopo review.

Verifica:

```bash
olsnodes -n
crsctl check cluster -all
crsctl stat res -t
srvctl status asm
srvctl status scan
srvctl status scan_listener
asmcmd lsdg
```

### 6. Diskgroup applicativi

| Diskgroup | Uso | Size | Ridondanza | Soglie |
| --- | --- | --- | --- | --- |
| `+M24SHAMS_DATA` | datafile, control file, spfile | `<SIZE>` | `<TYPE>` | `<WARN/CRIT>` |
| `+M24SHAMS_FRA` | FRA, archive, control file | `<SIZE>` | `<TYPE>` | `<WARN/CRIT>` |

Valida montaggio su entrambi i nodi di ciascun cluster:

```bash
asmcmd lsdg
asmcmd ls +M24SHAMS_DATA
asmcmd ls +M24SHAMS_FRA
```

### 7. Database Home e RU

Installa Database Home 19c software-only su tutti i nodi. Allinea RU Grid e DB
Home tra PE e SE.

```bash
<GRID_HOME>/OPatch/opatch lsinventory
<ORACLE_HOME>/OPatch/opatch lsinventory
```

Non avviare duplicate finche' gli inventari non sono coerenti.

### 8. Listener e endpoint Data Guard

Configura listener applicativi SCAN e listener DG dedicato su `1531/TCP`.
L'endpoint DG deve rimanere raggiungibile durante la perdita di un nodo.

```bash
srvctl config listener
srvctl status listener
srvctl status scan_listener
lsnrctl status LISTENER_DG
```

## Validazione finale

| Check | Esito |
| --- | --- |
| due nodi online per cluster | `<OK/KO>` |
| SCAN e VIP risolvibili | `<OK/KO>` |
| interconnect stabile | `<OK/KO>` |
| storage condiviso nel sito e separato tra siti | `<OK/KO>` |
| ASM montato su tutti i nodi | `<OK/KO>` |
| RU Grid e DB Home allineata | `<OK/KO>` |
| listener SCAN e DG | `<OK/KO>` |
| `crsctl stat res -t` senza risorse anomale | `<OK/KO>` |

## Rollback

Se il cluster non e' stabile:

1. non creare database;
2. conserva log installer, CVU e root script;
3. correggi DNS, rete o storage con owner competente;
4. rimuovi solo risorse introdotte dal change;
5. ripeti CVU e checklist prima del nuovo tentativo.

## Troubleshooting rapido

| Sintomo | Azione |
| --- | --- |
| SCAN non risolve | correggi DNS e SCAN record |
| nodo non entra nel cluster | controlla interconnect, VIP, orario e log Clusterware |
| ASM diskgroup non monta su nodo 2 | multipath, udev, ownership e alert ASM |
| RU diverse | allinea Grid e DB Home prima del database |
| Observer perde il sito dopo caduta nodo | valida endpoint DG ad alta disponibilita' |
