# Guida Storage Oracle: LUN, PV, VG, LV, udev, ASM, ASMLib, AFD e Grid

## Obiettivo

Chiarire lo stack storage che un DBA Oracle vede in produzione: dalla LUN SAN fino al diskgroup ASM. La guida serve per decidere cosa usare, cosa evitare, cosa e legacy/deprecato e quali controlli fare prima di creare o estendere storage Oracle.

## Mappa mentale

```text
Storage array / SAN / vSAN
  -> LUN
    -> multipath device (/dev/mapper/<WWID>)
      -> udev rule oppure ASMLib label
        -> ASM disk
          -> ASM diskgroup (+DATA, +FRA, +OCR)
            -> Oracle files: datafile, controlfile, redo, archivelog, backup piece
```

Con LVM:

```text
Disk/LUN
  -> PV
    -> VG
      -> LV
        -> filesystem oppure, in casi particolari, device esposto ad ASM
```

In RAC la regola critica e semplice: tutti i nodi devono vedere gli stessi dischi condivisi con nomi, permessi e path coerenti.

## Glossario essenziale

| Termine | Significato | Esempio |
|---|---|---|
| Physical disk | Disco fisico o virtuale locale | `/dev/sdb` |
| LUN | Disco logico presentato da SAN/storage array | LUN 2 TB presentata a tutti i nodi RAC |
| Path | Una strada host -> storage verso la stessa LUN | `/dev/sdb`, `/dev/sdc` |
| Multipath device | Device unico che rappresenta piu path verso la stessa LUN | `/dev/mapper/3600...` |
| PV | Physical Volume LVM: disco/partizione inizializzato con `pvcreate` | `/dev/mapper/3600...` |
| VG | Volume Group LVM: pool composto da uno o piu PV | `vg_oracle` |
| LV | Logical Volume LVM: volume logico creato dentro un VG | `/dev/vg_oracle/lv_u01` |
| udev | Regole Linux per nomi e permessi persistenti | `/etc/udev/rules.d/99-oracle-asm.rules` |
| ASM disk | Device riconosciuto da Oracle ASM | `/dev/oracleasm/disks/DATA01`, `/dev/mapper/DATA01` |
| ASM diskgroup | Pool ASM che contiene file Oracle | `+DATA`, `+FRA`, `+OCR` |
| Grid Infrastructure | Software Oracle che gestisce Clusterware, ASM, listener cluster, OCR/voting | `$GRID_HOME` |
| ASMLib | Libreria Oracle Linux per discovery, label e permessi ASM | `oracleasm createdisk DATA01 ...` |
| ASMFD/AFD | ASM Filter Driver | `AFD:DATA01` |
| ACFS | Cluster filesystem Oracle sopra ADVM/ASM | mount ACFS per file non database |

## Cosa usare oggi

| Scenario | Scelta consigliata | Note |
|---|---|---|
| Oracle RAC 19c su Linux moderno | Multipath + ASMLib v3 oppure multipath + udev | Preferire standard aziendale certificato e uguale su tutti i nodi |
| Oracle Linux 8/9 con kernel recente | ASMLib v3 se disponibile/certificato | Oracle indica migrazione da ASMFD ad ASMLib per kernel 5.14+ |
| Ambienti legacy gia stabili con udev | Mantenere udev se documentato e testato | Evitare migrazioni senza beneficio operativo |
| Nuova installazione con ASMFD su Linux 19c | Evitare come nuova scelta | ASMFD e deprecato in 19c su Linux/Solaris |
| Filesystem OS, Oracle Home, dump, script | LVM + XFS/ext4 | ASM non e per Oracle Home o dump generici, salvo ACFS dove previsto |
| Datafile/redo/controlfile/FRA | ASM diskgroup | Standard migliore per RAC e HA |
| Storage array enterprise con RAID | ASM external redundancy | Mirroring demandato allo storage |
| Storage senza RAID o extended cluster | ASM normal/high redundancy con failure group corretti | Non improvvisare: serve design HA |

## LUN e multipath

Una LUN e un disco logico presentato dallo storage. Con Fibre Channel o iSCSI la stessa LUN puo comparire piu volte sul server, una volta per ogni path. Il multipath crea un solo device logico e nasconde i path fisici.

Comandi OS:

```bash
lsblk -o NAME,TYPE,SIZE,FSTYPE,MODEL,SERIAL,WWN,MOUNTPOINT
multipath -ll
udevadm info --query=all --name=/dev/mapper/<wwid>
```

Regole pratiche:

- ASM deve scoprire il device multipath, non i singoli `/dev/sdX`.
- Non usare `/dev/dm-X` direttamente: e un nome interno, non stabile per amministrazione.
- In cluster, evitare `user_friendly_names` se non sono identici su tutti i nodi; i nomi WWID sono piu affidabili.
- Se usi alias multipath, devono essere gestiti in modo identico su tutti i nodi RAC.

## LVM: PV, VG, LV

LVM e utile per filesystem Linux e mount point OS.

Comandi:

```bash
pvs
vgs
lvs
pvdisplay
vgdisplay
lvdisplay
```

Creazione esempio:

```bash
pvcreate /dev/mapper/3600...
vgcreate vg_oracle /dev/mapper/3600...
lvcreate -n lv_u01 -L 200G vg_oracle
mkfs.xfs /dev/vg_oracle/lv_u01
mkdir -p /u01
mount /dev/vg_oracle/lv_u01 /u01
```

Per Oracle ASM, LVM e generalmente non necessario. Oracle supporta logical volume in configurazioni semplici, ma non lo raccomanda come layer standard per ASM perche duplica funzionalita gia presenti in ASM. Se proprio lo usi, il logical volume deve rappresentare una singola LUN, senza striping o mirroring LVM.

## udev per ASM

udev assegna nomi e permessi persistenti ai device Linux.

Esempio logico:

```bash
udevadm info --query=all --name=/dev/mapper/3600...
```

Esempio regola:

```text
KERNEL=="dm-*", ENV{DM_UUID}=="mpath-3600...", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="oracleasm/disks/DATA01"
```

Reload:

```bash
udevadm control --reload-rules
udevadm trigger
ls -l /dev/oracleasm/disks/
```

Pro:

- standard Linux;
- nessun layer Oracle aggiuntivo;
- chiaro per sysadmin Linux.

Contro:

- errori di regole o match possono rompere discovery;
- serve disciplina forte tra nodi RAC;
- non offre filtro anti-overwrite come ASMLib/ASMFD.

## ASMLib

ASMLib gestisce label e discovery ASM tramite comandi `oracleasm`.

Comandi:

```bash
oracleasm status
oracleasm scandisks
oracleasm listdisks
oracleasm querydisk DATA01
oracleasm createdisk DATA01 /dev/mapper/3600...
oracleasm deletedisk DATA01
oracleasm discover
```

Discovery ASM:

```sql
show parameter asm_diskstring
alter system set asm_diskstring='ORCL:*' scope=both;
```

Pro:

- label persistenti sui dischi;
- gestione semplice;
- ASMLib v3 usa interfacce moderne su kernel recenti e puo fornire I/O filtering dove supportato.

Contro:

- dipende da pacchetti/compatibilita Oracle Linux/kernel;
- su alcune piattaforme non e supportato;
- deve essere gestito coerentemente su tutti i nodi.

## ASMFD / AFD

ASMFD forniva naming persistente e filtro contro scritture non Oracle.

Comandi tipici:

```bash
asmcmd afd_state
asmcmd afd_lsdsk
asmcmd afd_dsget
asmcmd afd_label DATA01 /dev/mapper/3600... --init
asmcmd afd_unlabel DATA01
```

Stato attuale da trattare con attenzione:

- Oracle indica ASMFD come deprecato da Oracle Database 19c su Linux e Solaris.
- Su Linux con kernel 5.14+ il filtering ASMFD e disabilitato e non supportato in avanti.
- Per ambienti Linux moderni Oracle indica migrazione verso ASMLib v3 per mantenere funzionalita equivalenti.

Quindi: non scegliere AFD per una nuova installazione Linux 19c/OL8+/OL9+ senza una ragione certificata e una matrice di supporto approvata.

## ASM e Grid Infrastructure

ASM e parte della Grid Infrastructure. In single instance con Oracle Restart, Grid gestisce ASM, listener e database come risorse locali. In RAC, Grid gestisce cluster, OCR, voting disk, ASM, database, istanze, listener, SCAN e servizi.

Comandi:

```bash
crsctl check crs
crsctl stat res -t
srvctl status asm
srvctl config asm
srvctl status diskgroup -g DATA
asmcmd lsdg
```

SQL ASM:

```sql
select name, state, type, total_mb, free_mb, required_mirror_free_mb, usable_file_mb
from v$asm_diskgroup
order by name;

select group_number, disk_number, name, path, header_status, mode_status, state
from v$asm_disk
order by group_number, disk_number;
```

## Ridondanza ASM

| Tipo | Cosa significa | Quando usarlo |
|---|---|---|
| External | Nessun mirroring ASM | Storage array/RAID gia protegge i dati |
| Normal | Mirroring ASM 2-way | Storage senza RAID o design host-based |
| High | Mirroring ASM 3-way | Massima protezione, costo storage alto |
| Flex | Redundancy per file group | Ambienti avanzati, design specifico |

Regole:

- Non mischiare dischi lenti e veloci nello stesso diskgroup.
- Dischi nello stesso diskgroup dovrebbero avere dimensione e prestazioni simili.
- In normal/high redundancy, definire failure group coerenti con fault domain reali.
- Per array enterprise, spesso `EXTERNAL REDUNDANCY` e la scelta corretta.

## Diskgroup consigliati

| Diskgroup | Contenuto | Note |
|---|---|---|
| `+OCR` o `+CRS` | OCR, voting file, Grid Management Repository se presente | Critico per cluster |
| `+DATA` | datafile, controlfile, online redo se policy lo prevede | I/O primario DB |
| `+FRA` o `+RECO` | archivelog, backupset, flashback log, controlfile copy | Separare da DATA se possibile |
| `+REDO` | redo dedicato | Solo se serve isolamento I/O specifico |

## Matrice decisionale

| Domanda | Risposta operativa |
|---|---|
| Nuovo RAC 19c su Linux moderno? | ASM + multipath + ASMLib v3 oppure udev certificato |
| Nuovo single node enterprise? | ASM se vuoi coerenza con RAC/RMAN/DG; filesystem per installazioni semplici |
| Posso usare LVM sotto ASM? | Solo se necessario e semplice; non usare LVM per mirroring/striping sotto ASM |
| Posso usare `/dev/sdX`? | No in produzione: nomi non persistenti |
| Posso usare `/dev/dm-X`? | No: device interno multipath |
| Posso usare `/dev/mapper/<WWID>`? | Si, se discovery e permessi sono coerenti |
| Devo usare AFD? | Non per nuove installazioni Linux 19c moderne; e deprecato |
| udev o ASMLib? | ASMLib v3 se standard Oracle Linux supportato; udev se standard Linux aziendale consolidato |

## Check prima di aggiungere una LUN ad ASM

OS:

```bash
lsblk -o NAME,TYPE,SIZE,FSTYPE,MODEL,SERIAL,WWN,MOUNTPOINT
multipath -ll
udevadm info --query=all --name=/dev/mapper/<wwid>
ls -l /dev/mapper/
```

LVM collision:

```bash
pvs
vgs
lvs
blkid
wipefs -n /dev/mapper/<wwid>
```

ASM:

```bash
asmcmd lsdg
asmcmd lsdsk -p
```

SQL:

```sql
select name, path, header_status, mode_status, state, total_mb
from v$asm_disk
order by path;
```

Regola: se `HEADER_STATUS` non e `CANDIDATE` o atteso dal change, fermati.

## Esempio udev + ASM

1. Identifica WWID:

```bash
multipath -ll
udevadm info --query=all --name=/dev/mapper/3600...
```

2. Crea regola:

```text
KERNEL=="dm-*", ENV{DM_UUID}=="mpath-3600...", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="oracleasm/disks/DATA01"
```

3. Ricarica:

```bash
udevadm control --reload-rules
udevadm trigger
ls -l /dev/oracleasm/disks/DATA01
```

4. ASM:

```sql
alter diskgroup DATA add disk '/dev/oracleasm/disks/DATA01' name DATA01 rebalance power 4;
select * from v$asm_operation;
```

## Esempio ASMLib + ASM

```bash
oracleasm status
oracleasm createdisk DATA01 /dev/mapper/3600...
oracleasm scandisks
oracleasm listdisks
oracleasm querydisk DATA01
```

ASM:

```sql
alter system set asm_diskstring='ORCL:*' scope=both;
alter diskgroup DATA add disk 'ORCL:DATA01' name DATA01 rebalance power 4;
```

## Cosa evitare

- Non usare `/dev/sdX` in ASM.
- Non far scoprire ad ASM sia path singoli sia multipath dello stesso disco.
- Non usare LVM mirroring/striping sotto ASM.
- Non mettere OCR/voting su storage non supportato per Clusterware.
- Non cancellare file ASM con comandi OS.
- Non cambiare permessi dischi a mano senza persistenza.
- Non mischiare AFD e ASMLib: se ASMLib e installato e non usato per persistence, Oracle indica di deinstallarlo.
- Non creare piu partizioni dello stesso disco fisico nello stesso diskgroup.

## Troubleshooting rapido

| Sintomo | Check |
|---|---|
| Disco non visibile in ASM | `asmcmd lsdsk -p`, `show parameter asm_diskstring`, permessi udev/ASMLib |
| ORA-15031 / ORA-15032 | path errato, permessi, disk header non candidate |
| ASM vede duplicati | multipath non filtrato, ASM scopre `/dev/sdX` e `/dev/mapper/*` |
| Dopo reboot dischi spariti | udev non persistente, ASMLib non avviato, multipath non attivo |
| Rebalance lento | `v$asm_operation`, power basso, I/O storage saturo |
| Diskgroup full | controllare `usable_file_mb`, non solo `free_mb` |

## Fonti ufficiali e note

- Oracle ASM storage considerations 19c: <https://docs.oracle.com/en/database/oracle/oracle-database/19/ostmg/considerations-asm-storage.html>
- Oracle storage requirements for ASM 19c: <https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/identifying-storage-requirements-for-oracle-automatic-storage-management.html>
- Oracle Grid Infrastructure Linux install 19c, nota ASMFD deprecated: <https://docs.oracle.com/en/database/oracle/oracle-database/19/cwlin/installing-oracle-standalone-cluster.html>
- Oracle migration ASMFD to ASMLib: <https://docs.oracle.com/en/database/oracle/oracle-database/19/cwlin/migrating-from-asmfd-to-asmlib.html>
- Oracle ASMLib: <https://docs.oracle.com/en/operating-systems/oracle-linux/asmlib/asmlib-AboutASMLib.html>
- Oracle ASMLib configuration: <https://docs.oracle.com/en/operating-systems/oracle-linux/asmlib/asmlib-ConfiguringASMLib.html>
- Oracle Linux udev device management: <https://docs.oracle.com/en/operating-systems/oracle-linux/7/osmanage/osmanage-DeviceManagement.html>
- Red Hat LVM RHEL 8: <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/epub/configuring_and_managing_logical_volumes/configuring-and-managing-logical-volumes.epub>
- Red Hat DM Multipath RHEL 8: <https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/epub/configuring_device_mapper_multipath/enabling-multipathing-on-nvme-devices_configuring-device-mapper-multipath>
- Oracle Linux multipath: <https://docs.oracle.com/en/operating-systems/oracle-linux/8/stordev/stordev-UsingMultipathingforEfficientStorage.html>
