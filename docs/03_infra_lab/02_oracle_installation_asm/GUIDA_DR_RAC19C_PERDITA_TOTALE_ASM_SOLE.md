# Oracle RAC 19c — Complete Disaster Recovery After Total ASM Storage Loss

### Hands-on Recovery Lab | Grid Infrastructure, OCR, Voting Disks, ASM, RMAN, RESETLOGS & RAC Reconstruction

> **Environment:** Personal Oracle RAC 19c laboratory on Proxmox  
> **Scenario:** Simulated total shared ASM storage loss  
> **Result:** Successful recovery of both RAC instances (`SOTERRA1` & `SOTERRA2` both `OPEN`, CDB & PDB `READ WRITE`)  
> **Database:** CDB `SOTERRA` with application PDB `TERRAPDB`  
> **Documento pubblico / GitHub-ready · Revisione 5 (estesa e verificata) · 17 ottobre 2026**  
> **Esito effettivamente verificato:** `SOTERRA1` e `SOTERRA2` entrambe `OPEN`, CDB `SOTERRA` `READ WRITE`, PDB `TERRAPDB` `READ WRITE` su entrambi i nodi; backup RMAN post-RESETLOGS validato (5/5) e copiato sull'host hypervisor con SHA-256 (8/8).  
> **Non è una ricetta da eseguire ciecamente.** Le fasi distruttive si riferiscono a un laboratorio isolato con LUN già perse e con backup disponibili.

## Sommario

**Vai direttamente alle procedure commentate:** [A — convenzioni](#appendice-a--come-leggere-ed-eseguire-questo-runbook) · [B — storage/ASMLIB](#appendice-b--preparazione-e-ricostruzione-delle-lun-registro-dettagliato) · [C — Grid/OCR](#appendice-c--ricostruzione-gi-e-protezione-ocr) · [D — RMAN restore/recovery](#appendice-d--rman-sequenza-completa-inclusa-quella-mancante-nella-sintesi) · [E — SPFILE/password/RAC](#appendice-e--spfile-ociocr-password-file-e-avvio-rac) · [F — validazione SQL](#appendice-f--validazione-verifica-conclusiva-sql-commentata) · [G — errori](#appendice-g--errori-osservati-e-risposta-operativa-non-inventare-fix) · [H — test futuri](#appendice-h--runbook-per-verifiche-ancora-non-eseguite).

> **Edizione estesa:** le appendici A–H contengono procedure commentate comando per comando, precheck, errori, varianti, prove e punti di ripartenza. La sezione §6.3 è stata corretta in base al log originale: `SET NEWNAME`, `RESTORE`, `SWITCH` e successivo `RECOVER`, non restore generico sui path persi.

1. [Obiettivi, scopo e ciò che è stato dimostrato](#1-obiettivi-scopo-e-ciò-che-è-stato-dimostrato)
2. [Assessment e architettura anonimizzata](#2-assessment-e-architettura-anonimizzata)
3. [Guasto, perimetro e prove preservate](#3-guasto-perimetro-e-prove-preservate)
4. [Procedura operativa: rebuild storage/ASM](#4-procedura-operativa-rebuild-storageasm)
5. [Rebuild Grid Infrastructure, OCR e voting](#5-rebuild-grid-infrastructure-ocr-e-voting)
6. [Restore e recovery RMAN](#6-restore-e-recovery-rman)
7. [Redo, tempfile e OPEN RESETLOGS](#7-redo-tempfile-e-open-resetlogs)
8. [SPFILE RAC, password file e OCR database](#8-spfile-rac-password-file-e-ocr-database)
9. [Backup post-RESETLOGS e copia off-guest](#9-backup-post-resetlogs-e-copia-off-guest)
10. [Validazione finale: riavvio a due istanze e prove conclusive](#10-validazione-finale-riavvio-a-due-istanze-e-prove-conclusive)
11. [Troubleshooting: errori osservati, stop condition e lezioni apprese](#11-troubleshooting-errori-osservati-stop-condition-e-lezioni-apprese)
12. [Verifiche ancora da completare](#12-verifiche-ancora-da-completare)
13. [Riferimenti](#13-riferimenti)

---

## 1. Obiettivi, scopo e ciò che è stato dimostrato

Il laboratorio simula la perdita completa delle **LUN ASM condivise** di un cluster Oracle RAC a due nodi. Sui nodi sopravvivevano OS, Grid Home, Database Home e un disco **separato** contenente il backup RMAN. Non erano disponibili gli OCR/voting originali sullo storage condiviso perduto.

L'esercitazione ha dimostrato una ricostruzione in sequenza:

- preservazione di evidenze, LUN originali e backup di configurazione;
- **deconfigurazione / riconfigurazione** della Grid Home esistente, senza reinstallare i binari;
- nuove LUN e nuova ASM (`+CRS`, `+DATA`, `+FRA`), OCR e voting files;
- restore dei 13 datafile del CDB, recovery con archived redo su due thread e `OPEN RESETLOGS`;
- nuovo SPFILE e password file condivisi su ASM, più registrazione database/istanze in OCR;
- backup RMAN della nuova incarnazione, validazione di tutti e cinque i backupset e copia verificata su Proxmox;
- `srvctl start instance` su entrambi i nodi, con `cluster_database=TRUE` e due redo thread `OPEN`.

**Risultato, non ancora testato:** i meccanismi di failover applicativo, comportamento dopo reboot delle VM, backup off-site e DR dell'intero host **non** sono stati validati: v. §12.

## 2. Assessment e architettura anonimizzata

> **Gli indirizzi in questo documento sono esempi deliberatamente sostituiti.** Gli IP `192.0.2.0/24` e `198.51.100.0/24` sono reti TEST-NET riservate alla documentazione, **non** indirizzi utilizzabili nel laboratorio senza sostituirli. Anche VMID, subnet private e host hypervisor sono rappresentati come esempi.

| Componente | Valore del laboratorio / identificativo pubblico |
|---|---|
| Hypervisor | Proxmox VE, host esempio `pve-lab` |
| VM | `sole1`, `sole2` (VMID `<VMID_SOLE1>` e `<VMID_SOLE2>`) |
| OS | Oracle Linux 8 |
| Oracle GI / DB RU | Oracle 19c Release Update **19.30** |
| Grid owner / DB owner | `grid` / `oracle` |
| Grid Home | `/u01/app/19.0.0/grid` |
| Database Home | `/u01/app/oracle/product/19.0.0/dbhome_1` |
| CDB / PDB | `SOTERRA` / `TERRAPDB` |
| DBID conservato | `2483660440` |
| SID RAC | `SOTERRA1`, `SOTERRA2` |
| ASM | ASMLIB, discovery `ORCL:*` |
| OCR/voting | `+CRS`, tre ASM disk `CRS1`, `CRS2`, `CRS3` |
| Data / FRA | `+DATA` (`DATA1`), `+FRA` (`FRA1`) |
| Rete pubblica **esempio** | `sole1: 192.0.2.11`, `sole2: 192.0.2.12` |
| VIP **esempio** | `192.0.2.21`, `192.0.2.22` |
| SCAN **esempio** | `192.0.2.50–52` |
| Interconnect **esempio** | `10.77.20.11/24`, `10.77.20.12/24` |
| Management hypervisor **esempio** | `198.51.100.10` |

Non diffondere nella versione pubblica UUID dei dischi, WWN, seriali fisici, credenziali SYS, IP reali, nomi cliente o file di backup sensibili.

### Topologia logica

```text
          Client / SCAN / VIP (indirizzi di esempio)
                        │
              ┌─────────┴─────────┐
              │                   │
            sole1               sole2
         SOTERRA1             SOTERRA2
         redo thread 1        redo thread 2
         UNDOTBS1             UNDOTBS2
              │                   │
              └─────────┬─────────┘
                        │ shared ASM
                 +CRS | +DATA | +FRA
                        │
                 CDB SOTERRA
                    TERRAPDB

     Backup RMAN vecchio: disco separato, mount XFS RO
     Backup nuovo: disco guest + copia ZFS su Proxmox
```

## 3. Guasto, perimetro e prove preservate

La rimozione/scomparsa delle LUN condivise ha reso irraggiungibili i diskgroup precedenti; il cluster ha perso l'OCR/voting e non poteva montare i file del database. Il filesystem OS e le due Oracle Home erano rimasti integri. Non si è tentato di «riparare» file ASM perduti con `dd`, `wipefs` o manipolazione alla cieca.

### Preservazione eseguita nel laboratorio

- I vecchi volumi ZFS originali sono stati preservati, **non** riciclati come nuove LUN.
- È stato realizzato un checkpoint ZFS prima della Grid reconfiguration.
- Config, OLR e log GI sono stati acquisiti; il nuovo OCR è stato copiato dopo la ricostruzione su storage **non ASM** con checksum.
- Il disco da **80 GiB** con i backup pre-guasto è stato montato su `sole1` in **sola lettura** con opzioni XFS `ro,norecovery`, per non alterare il contenuto.
- I file RMAN originali sono stati verificati con checksum e quindi catalogati/validati.

Controlli inventariali esemplificativi, **read-only**:

```bash
hostname -s
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
findmnt -T /u01/app/19.0.0/grid
findmnt /mnt/sole_rman
# Il discovery ASM non deve includere dischi OS o backup.
# Sul nodo hypervisor, identificare i volumi tramite ID stabili.
```

**GATE:** mai riutilizzare una vecchia LUN recuperabile e mai assumere che un nome `/dev/sdX` sia stabile tra un boot e l'altro.

## 4. Procedura operativa: rebuild storage/ASM

### 4.1 Nuove LUN: attività storicamente eseguite

Nel laboratorio sono stati provisionati **cinque** nuovi dispositivi condivisi e create le partizioni richieste **una sola volta, su sole1**. Il comando esatto di creazione GPT non è conservato nella documentazione finale: non si inventa retroattivamente. Le nuove partizioni sono state etichettate con ASMLIB e viste da entrambi i nodi:

```text
ORCL:CRS1
ORCL:CRS2
ORCL:CRS3
ORCL:DATA1
ORCL:FRA1
```

Verifiche da ripetere su entrambi i nodi prima di usare i dischi:

```bash
/usr/sbin/oracleasm listdisks
/u01/app/19.0.0/grid/bin/asmcmd lsdg
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
```

> In un ambiente non isolato, `oracleasm createdisk`, `CREATE DISKGROUP`, `mkfs`, partitioning e/o formattazione sono **operazioni che possono sovrascrivere dati**. Eseguirle solo su identificativi storage nuovi, certificati e con procedure change approvate. I comandi di creazione riportati di seguito illustrano quanto fatto, non sostituiscono il controllo dei dispositivi.

### 4.2 Diskgroup definitivi

```sql
-- Nomi e tipi di diskgroup risultanti dal laboratorio.
-- Esempi strutturali: il piano di ridondanza deve essere certificato.
-- +CRS è stato ricostruito durante la configurazione GI sui tre dischi CRS.

CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK 'ORCL:DATA1' NAME DATA1
  ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='12.1';

CREATE DISKGROUP FRA EXTERNAL REDUNDANCY
  DISK 'ORCL:FRA1' NAME FRA1
  ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='12.1';
```

`+CRS` è stato predisposto in configurazione normale con tre dischi OCR/voting. `+DATA` e `+FRA` utilizzavano un disk ciascuno con ridondanza `EXTERNAL` (ridondanza *delegata allo storage sottostante*). I diskgroups sono stati portati `MOUNTED` su entrambe le istanze ASM.

## 5. Rebuild Grid Infrastructure, OCR e voting

### 5.1 Deconfigurazione dei due nodi — **eseguita**

> **DISTRUTTIVO A LIVELLO DI CONFIGURAZIONE CLUSTER:** rimuove la configurazione GI/OCR preesistente. Sul laboratorio lo storage originale era perso e le evidenze protette; su un cluster produttivo fermarsi finché la procedura non è approvata.

```bash
# 1. root@sole2 — nodo non-last
GH=/u01/app/19.0.0/grid
cd "$GH/crs/install"
./rootcrs.sh -deconfig -force 2>&1 | tee /root/sole2_rootcrs_deconfig_20261016.log
# Exit 0 / CLSRSC-336 osservato.

# 2. SOLO dopo exit 0 del nodo2: root@sole1 — lastnode
GH=/u01/app/19.0.0/grid
cd "$GH/crs/install"
./rootcrs.sh -deconfig -force -lastnode 2>&1 | tee /root/sole1_rootcrs_lastnode_20261016.log
# Exit 0 / CLSRSC-336 osservato.
```

Sono stati mantenuti i binari della Grid Home e Database Home già patchati. I vecchi OCR/voting non sono stati «restaurati»: l'OCR ottenuto è **nuovo**.

### 5.2 Configurazione dalle Home esistenti — **eseguita**

La configurazione GI è stata ripetuta con il flusso `gridSetup.sh` da `grid@sole1`, impostando nodi, rete, SCAN/VIP, ASM discovery e `+CRS`; quando richiesto dal wizard si sono eseguiti gli script `root.sh` in ordine `sole1` → `sole2`.

```bash
# grid@sole1, nel percorso di configurazione già predisposto
cd /u01/app/19.0.0/grid
./gridSetup.sh

# root@sole1 — solo quando richiesto dal wizard
cd /u01/app/19.0.0/grid
./root.sh 2>&1 | tee /root/sole1_rootsh_retry4_20261016.log

# root@sole2 — dopo completamento del nodo1
cd /u01/app/19.0.0/grid
./root.sh 2>&1 | tee /root/sole2_rootsh_reconfig_20261016.log
```

Nel corso del tentativo iniziale sono comparsi problemi GPnP/SCP, risolti correggendo le **sole directory di destinazione mancanti**; la procedura non va tradotta in una generica cancellazione di cartelle GPnP. Eventuali ripetizioni di `root.sh` necessitano diagnosi del log e indicazioni Oracle.

### 5.3 Verifica GI/OCR — **eseguita**

```bash
GH=/u01/app/19.0.0/grid
"$GH/bin/crsctl" check crs
"$GH/bin/crsctl" check cluster -all
"$GH/bin/olsnodes" -n -s
"$GH/bin/ocrcheck"
"$GH/bin/crsctl" query css votedisk
"$GH/bin/crsctl" stat res -t
```

**Evidenze osservate:** `sole1` e `sole2` **Active**, CRS/CSS/ASM online, OCR healthy, **3 voting disks ONLINE** sui tre dischi `CRS1–3`; diskgroups dati/FRA montati. È stato eseguito `ocrconfig -copy` del backup del **nuovo** OCR su filesystem host/guest separato, con SHA-256 confrontato.

## 6. Restore e recovery RMAN

### 6.1 Sorgente RMAN protetta e inventario

Il disco backup era separato dalle nuove LUN ASM. L'accesso era:

```bash
# La forma con UUID (non pubblicato qui) ha preservato il disco XFS.
# Eseguire SOLO se filesystem non già montato e UUID verificato.
mount -t xfs -o ro,norecovery UUID='<UUID_BACKUP_VERIFICATO>' /mnt/sole_rman
findmnt /mnt/sole_rman
```

Percorso backup originale:

```text
/mnt/sole_rman/SOTERRA_FULL_20261016/
  02550acg_2_1_1.bkp     archived logs
  03550aei_3_1_1.bkp     datafile backupset
  04550agt_4_1_1.bkp     datafile backupset
  05550ail_5_1_1.bkp     datafile backupset
  06550akn_6_1_1.bkp     archived logs finali
  07550akp_7_1_1.bkp     control file
  08550akr_8_1_1.bkp     vecchio SPFILE
```

Il vecchio SPFILE e il control file contenevano percorsi OMF riferiti allo storage distrutto; **non sono stati riutilizzati ciecamente come configurazione di avvio**.

### 6.2 Avvio temporaneo della sola prima istanza

È stato creato un **PFILE dedicato al recovery** in:

```text
/tmp/sole_soterra_restore_20261016/initSOTERRA1_recovery.ora
```

Parametri fondamentali verificati:

```ini
*.db_name='SOTERRA'
*.cluster_database=FALSE
*.control_files='+DATA/SOTERRA/control01.ctl','+FRA/SOTERRA/control02.ctl'
*.db_create_file_dest='+DATA'
*.db_recovery_file_dest='+FRA'
*.db_recovery_file_dest_size=14000M
*.enable_pluggable_database=TRUE
```

La prima istanza è stata portata a `NOMOUNT` e poi `MOUNT` dopo restore del control file:

```sql
-- SQL*Plus come oracle@sole1, prima che esista il control file ripristinato.
STARTUP NOMOUNT PFILE='/tmp/sole_soterra_restore_20261016/initSOTERRA1_recovery.ora';
```

```rman
# Comandi rappresentativi della sequenza applicata nel laboratorio.
# In RMAN la destinazione esatta deve essere già disponibile in ASM.
RESTORE CONTROLFILE FROM '/mnt/sole_rman/SOTERRA_FULL_20261016/07550akp_7_1_1.bkp';
SQL 'ALTER DATABASE MOUNT';
CATALOG START WITH '/mnt/sole_rman/SOTERRA_FULL_20261016/' NOPROMPT;
LIST BACKUP SUMMARY;
RESTORE DATABASE PREVIEW;
RESTORE DATABASE VALIDATE;
```

**Verifiche storiche:** il DBID era `2483660440`, la struttura conteneva **13 datafile**, e la validazione RMAN ha letto le tre piece dati. L'avviso `RMAN-06139` relativo a `REPORT SCHEMA` con backup control file era stato contestualizzato, senza trattarlo come errore di restore.

### 6.3 Restore + incomplete recovery — **eseguito**

```rman
RUN {
  SET UNTIL SCN 3484552;
  SET NEWNAME FOR DATABASE TO '+DATA';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
}
```

Il `RECOVER DATABASE` è stato eseguito in un passo RMAN separato con lo stesso limite SCN, dopo lo `SWITCH DATAFILE ALL` (vedi Appendice D.6).

L'SCN è specifico di **quel** set di archived log e del punto di recupero effettivamente scelto. Non usarlo su un altro database/backup: richiede `RESTORE PREVIEW`, validazione archivelog e controllo degli SCN recuperabili. I file ripristinati sono stati collocati su `+DATA`; recovery ha utilizzato i redo necessari dai **thread 1 e 2**.

## 7. Redo, tempfile e OPEN RESETLOGS

Il control file restaurato puntava a vecchi nomi redo OMF ASM inesistenti. Prima dell'apertura sono stati riallineati i member ai nuovi nomi; questi **otto** percorsi sono stati poi effettivamente verificati con `asmcmd ls -l`:

```text
Gruppo 1: +DATA/SOTERRA/redo_g01_a.log   +FRA/SOTERRA/redo_g01_b.log
Gruppo 2: +DATA/SOTERRA/redo_g02_a.log   +FRA/SOTERRA/redo_g02_b.log
Gruppo 3: +DATA/SOTERRA/redo_g03_a.log   +FRA/SOTERRA/redo_g03_b.log
Gruppo 4: +DATA/SOTERRA/redo_g04_a.log   +FRA/SOTERRA/redo_g04_b.log
```

```sql
-- SQL di esempio; eseguire ALTER DATABASE RENAME FILE soltanto
-- dopo inventario V$LOGFILE/ASM e review dei percorsi reali.
-- ALTER DATABASE RENAME FILE '<VECCHIO_REDO_MEMBER>'
--   TO '+DATA/SOTERRA/redo_g01_a.log';

-- Dopo RECOVER DATABASE completato e verifiche sui member:
ALTER DATABASE OPEN RESETLOGS;
```

**Risultato realmente osservato:** database `SOTERRA`, DBID `2483660440`, `READ WRITE`, **`RESETLOGS_CHANGE# = 3484553`**. Sono stati ricreati automaticamente i tempfile del CDB$ROOT, PDB$SEED e TERRAPDB (verificati in `V$TEMPFILE`). `TERRAPDB` è risultata `READ WRITE`.

> Una prima versione del blocco di OPEN RESETLOGS non ha raggiunto la DDL per un errore del wrapper PL/SQL (`PLS-00201` su `raise_application_error` nel contesto usato). Il problema era nello script di controllo, non una corruzione del database. La DDL è stata poi eseguita in un passo verificato.

## 8. SPFILE RAC, password file e OCR database

### 8.1 Ricostruzione SPFILE da PFILE verificato — **eseguita**

Il vecchio SPFILE è stato estratto in PFILE per consultazione, ma **non** riapplicato: vecchi path `CONTROLFILE/current.*` e `local_listener` erano incompatibili con la nuova configurazione. È stato generato un nuovo PFILE RAC partendo dal PFILE di recovery funzionante, aggiungendo parametri statici dei due nodi:

```ini
*.db_name='SOTERRA'
*.cluster_database=TRUE
*.control_files='+DATA/SOTERRA/control01.ctl','+FRA/SOTERRA/control02.ctl'
SOTERRA1.instance_number=1
SOTERRA1.thread=1
SOTERRA1.undo_tablespace='UNDOTBS1'
SOTERRA2.instance_number=2
SOTERRA2.thread=2
SOTERRA2.undo_tablespace='UNDOTBS2'
```

Oltre ai parametri base di CDB, memoria, ASM OMF, audit e FRA già verificati. Creazione ed esportazione readback:

```sql
CREATE SPFILE='+DATA/SOTERRA/spfileSOTERRA.ora'
  FROM PFILE='/tmp/sole_soterra_restore_20261016/initSOTERRA_RAC_final.ora';
CREATE PFILE='/tmp/sole_soterra_restore_20261016/initSOTERRA_spfile_readback.ora'
  FROM SPFILE='+DATA/SOTERRA/spfileSOTERRA.ora';
```

Prima del restart sono stati verificati **assenti**, su entrambi i nodi, `dbs/spfileSOTERRA{1,2}.ora`, `dbs/spfile.ora`, `dbs/initSOTERRA{1,2}.ora`; questa precauzione evita che l'istanza usi parametri locali incoerenti. Successivamente `srvctl` ha gestito lo SPFILE condiviso.

### 8.2 Registrazione database e due istanze — **eseguita**

```bash
# Esempio fedele alle opzioni utilizzate; eseguito come DB owner oracle,
# con ORACLE_HOME, ORACLE_BASE e PATH esplicitamente impostati.
DBH=/u01/app/oracle/product/19.0.0/dbhome_1
export ORACLE_HOME="$DBH" ORACLE_BASE=/u01/app/oracle
export PATH="$DBH/bin:$PATH"

srvctl add database \
  -db SOTERRA -dbname SOTERRA \
  -oraclehome "$DBH" \
  -spfile '+DATA/SOTERRA/spfileSOTERRA.ora' \
  -dbtype RAC -role PRIMARY -startoption OPEN \
  -stopoption IMMEDIATE -policy MANUAL -diskgroup 'DATA,FRA'

srvctl add instance -db SOTERRA -instance SOTERRA1 -node sole1
srvctl add instance -db SOTERRA -instance SOTERRA2 -node sole2
srvctl config database -db SOTERRA
```

La policy è stata lasciata **MANUAL** intenzionalmente durante il recovery. In un primo tentativo un controllo Bash con `grep -Fqx 'Database instances:'` si fermava a causa di spazi finali; un successivo comando `srvctl` senza ambiente Oracle completo non ha restituito l'output atteso. I controlli sono stati corretti **senza ripetere `add database` o interrompere l'istanza attiva**.

### 8.3 Password file database condiviso — **eseguito**

**Assenza originale verificata** con `V$PASSWORDFILE_INFO` e ricerca file `orapw*`. Dopo registrazione risorsa database si è creato il file in ASM; la password iniziale SYS è stata digitata al prompt interattivo, non nei comandi/log:

```bash
# Login GI owner grid, ORACLE_SID=+ASM1; NON usare --asm (file ASM).
asmcmd pwcreate --dbuniquename SOTERRA +DATA/SOTERRA/orapwSOTERRA
# Oracle richiede la password SYS al prompt.

# La sola creazione del file ASM non ha impostato la posizione in OCR.
# pwget inizialmente: "Password file location has not been set for DB instance".
# Eseguito come DB owner oracle:
srvctl modify database -db SOTERRA -pwfile '+DATA/SOTERRA/orapwSOTERRA'

# Verifica, login GI owner:
asmcmd pwget --dbuniquename SOTERRA
# +DATA/SOTERRA/orapwSOTERRA
srvctl config database -db SOTERRA
```

**Protezione:** mai `pwcreate -f` su un file esistente, mai confondere `--dbuniquename` con `--asm` (file ASM/GI), mai inserire password nella shell o in Git.

## 9. Backup post-RESETLOGS e copia off-guest

### 9.1 Nuovo backup della nuova incarnazione — **eseguito**

L'istanza temporanea (`cluster_database=FALSE`) era `READ WRITE`, in `ARCHIVELOG`, DBID intatto e `RESETLOGS_CHANGE#=3484553`. Sono stati esportati in filesystem i parametri del nuovo SPFILE ASM e creati backupset RMAN sul disco OS, **non** sul vecchio disco `ro,norecovery`:

```sql
CREATE PFILE='/u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017/initSOTERRA_RAC_ASM_backup.ora'
  FROM SPFILE='+DATA/SOTERRA/spfileSOTERRA.ora';
```

```rman
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  BACKUP AS COMPRESSED BACKUPSET DATABASE
    FORMAT '/u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017/SOTERRA_DB_%U.bkp'
    TAG 'SOTERRA_POST_RESETLOGS';
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG FROM SCN 3484553
    FORMAT '/u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017/SOTERRA_ARCH_%U.bkp'
    TAG 'SOTERRA_POST_RESETLOGS';
  BACKUP CURRENT CONTROLFILE
    FORMAT '/u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017/SOTERRA_CTL_%U.bkp'
    TAG 'SOTERRA_POST_RESETLOGS';
  RELEASE CHANNEL c1;
}
```

**Risultato:** 3 piece datafile, 1 archived log, 1 control file, totale **~1,4 GB**; RMAN ha generato anche control file autobackup nella FRA. Poiché l'istanza era stata avviata da PFILE, è stato salvato separatamente un PFILE **esportato dallo SPFILE condiviso** invece di assumere che `BACKUP SPFILE` fosse valido nello stato temporaneo.

### 9.2 Validazione RMAN — **eseguita**

```rman
LIST BACKUPSET TAG 'SOTERRA_POST_RESETLOGS';
RESTORE DATABASE VALIDATE;
VALIDATE BACKUPSET 14;  -- archived logs
VALIDATE BACKUPSET 15;  -- control file
```

Sono stati validati **5/5** backupset: `10`, `11`, `12` (13 datafile complessivi), `14` (archived log thread 1 e 2), `15` (control file). Il PDB$SEED mantiene il proprio checkpoint storico: non è un errore, dato che è PDB template in sola lettura.

### 9.3 Copia off-guest e integrità — **eseguita**

```text
Origine guest:
  /u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017/
Destinazione hypervisor (esempio host pve-lab):
  /var/lib/vz/dump/sole_dr/SOTERRA_POST_RESETLOGS_20261017/
```

Il trasferimento è stato realizzato tramite `rsync` su SSH. Il manifest SHA-256 generato sulla sorgente è stato verificato sulla destinazione:

```bash
# Esempio di validazione già eseguita sul server di destinazione:
cd /var/lib/vz/dump/sole_dr/SOTERRA_POST_RESETLOGS_20261017
sha256sum -c SHA256SUMS.from_sole1
```

**Evidenza: 8/8 file OK**, compresi i 5 `.bkp`, il PFILE e i due log RMAN. **Attenzione:** le copie VM e host condividono l'hardware; non è backup geografico o fisicamente indipendente. Il server PBS esterno risultava non raggiungibile durante il test.

## 10. Validazione finale: riavvio a due istanze e prove conclusive

### 10.1 Chiusura ordinata della temporanea e riavvio gestito — **eseguiti**

Dopo la validazione del backup e copia off-guest, su `sole1` è stato verificato:

```text
2483660440 | READ_WRITE | 3484553 | OPEN | FALSE
```

Quindi l'istanza SOTERRA1 è stata chiusa con `SHUTDOWN IMMEDIATE`, senza `SHUTDOWN ABORT`. Stato post-shutdown: entrambe le istanze non running secondo `srvctl`.

```bash
# Come oracle@sole1 con ambiente DB corretto:
srvctl start instance -db SOTERRA -instance SOTERRA1 -startoption OPEN
srvctl status database -db SOTERRA
# SOTERRA1 running; SOTERRA2 not running

# Solo dopo verifica su SOTERRA1: cluster_database=TRUE,
# v$parameter spfile ASM, CDB READ WRITE e redo thread 2 ENABLED PUBLIC:
srvctl start instance -db SOTERRA -instance SOTERRA2 -startoption OPEN
srvctl status database -db SOTERRA
```

### 10.2 Verifica RAC conclusiva — **evidenza reale**

```sql
SELECT inst_id, instance_name, host_name, status, thread#
FROM gv$instance ORDER BY inst_id;

SELECT name, dbid, open_mode, database_role
FROM v$database;

SELECT thread#, status, enabled, groups
FROM v$thread ORDER BY thread#;

SELECT inst_id, name, value
FROM gv$parameter
WHERE name IN ('cluster_database','spfile','undo_tablespace')
ORDER BY name, inst_id;

SELECT inst_id, name, open_mode
FROM gv$pdbs
WHERE name IN ('TERRAPDB','PDB$SEED')
ORDER BY inst_id, name;
```

```text
GV$INSTANCE:
  1  SOTERRA1  sole1.localdomain  OPEN   thread 1
  2  SOTERRA2  sole2.localdomain  OPEN   thread 2

V$DATABASE:
  SOTERRA  DBID 2483660440  PRIMARY  READ WRITE

V$THREAD:
  1 OPEN PUBLIC groups=2
  2 OPEN PUBLIC groups=2

GV$PARAMETER:
  cluster_database TRUE su entrambe
  spfile +DATA/SOTERRA/spfilesoterra.ora su entrambe
  SOTERRA1 undo_tablespace=UNDOTBS1
  SOTERRA2 undo_tablespace=UNDOTBS2

GV$PDBS:
  TERRAPDB READ WRITE su entrambe
  PDB$SEED READ ONLY su entrambe
```

Questo dimostra **RAC a due istanze simultaneamente operative**, non ancora una prova di accesso client tramite SCAN o failover applicativo.

## 11. Troubleshooting: errori osservati, stop condition e lezioni apprese

| Problema / evento reale | Cosa ha funzionato | Cosa evitare |
|---|---|---|
| OCR/voting persi con LUN | Nuovo Clusterware/OCR su nuovi dischi certificati | `ocrconfig -restore` da backup OCR inesistente |
| ASMLIB dopo storage replacement | Discovery coerente `ORCL:*` su entrambi i nodi | usare automaticamente `sdX` o includere disco backup |
| Riconfigurazione Grid / GPnP | Verificare i log; riparare specifica directory mancante | cancellazione generica GPnP, riavvii ripetuti ciechi |
| SPFILE originale referenziava ASM perduto | PFILE di recovery e SPFILE RAC pulito, readback | copiare l'originale senza revisione |
| Precedenza di `dbs/spfile<SID>.ora` locale | Verificati file locali assenti; `srvctl` gestisce SPFILE ASM | scrivere file locali non necessari o stale |
| Wrapper PL/SQL per OPEN RESETLOGS | Precheck separato e DDL diretta | scambiare `PLS-00201` dello script per danno del DB |
| `grep -Fqx 'Database instances:'` | Regex con spazi opzionali + environment Oracle | assumere che ogni `STOP` script sia guasto GI |
| `pwcreate` produce file ma `pwget` vuoto | `srvctl modify database -pwfile` + `pwget` | ripetere `pwcreate` / usare `-f` |
| RMAN con PFILE temporaneo | Export del PFILE da shared SPFILE ASM | presumere backup SPFILE automatico valido |
| `lsblk MOUNTPOINTS` non supportato | `lsblk ... MOUNTPOINT` | diagnosticare storage guasto per errore di colonna |
| `srvctl` vede istanza manuale come OFFLINE | shutdown ordinato, poi startup da `srvctl` | avviare la seconda mentre la prima è `cluster_database=FALSE` |

**GATE di sicurezza generale:** quando un comando di recovery fallisce, salvare stdout, stderr, log e configurazione del checkpoint; non rieseguire automaticamente comandi `add`, `create`, `deconfig`, `RESETLOGS` o `pwcreate`.

## 12. Verifiche ancora da completare

- [ ] Verificare **SCAN, listener e servizi** e connessione applicativa reale a `TERRAPDB` da client separato.
- [ ] Testare una connessione **remota** amministrativa che utilizzi il nuovo password file, con credential handling sicuro.
- [ ] Verificare l'apertura della PDB dopo reboot e la policy di startup; attualmente `srvctl config database` indicava `Management policy: MANUAL`.
- [ ] Effettuare un failover controllato e documentato, non simulare la perdita improvvisa mentre esistono scritture applicative.
- [ ] Programmare backup schedulati, export OCR dopo change, backup password file e controllo FRA/retention.
- [ ] Eseguire un restore test periodico su ambiente separato, non sul CDB recuperato.
- [ ] Copiare il backup e le evidenze su storage indipendente dall'host Proxmox; verificare con attenzione il PBS fuori servizio.
- [ ] Documentare VM CPU/RAM, Network/SCAN, gestione delle LUN condivise e test storage failure con dati verificati.

## 13. Riferimenti

**Documentazione ufficiale Oracle 19c:**

- [Unconfiguring Oracle Clusterware Without Removing Binaries](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwlin/unconfiguring-oracle-clusterware-without-removing-binaries.html)
- [Configuring Software Binaries for Oracle GI Cluster](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwlin/configuring-software-binaries-for-oracle-grid-infrastructure-for-a-cluster.html)
- [Managing OCR and Voting Files](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwadd/managing-oracle-cluster-registry-and-voting-files.html)
- [Managing ASM with ASMCMD: pwcreate/pwget/pwset](https://docs.oracle.com/en/database/oracle/oracle-database/19/ostmg/manage-asm-asmcmd.html)
- [Server Control Utility (SRVCTL)](https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/server-control-utility-reference.html)
- [Oracle RMAN Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/rcmrf/)

**Fonti dell'esercitazione:** log shell/SQL/RMAN del 16–17/10/2026 e report di laboratorio SOLE Rev.3 (checkpoint intermedio). Questo README Rev.4 aggiorna esplicitamente quel report con gli step successivi effettivamente conclusi e non attribuisce ai log comandi di partizionamento che non sono stati conservati.

> **Non applicare i comandi a QLY o a un cliente senza un runbook dedicato.** QLY differisce per proprietari software, release, UDEV, diskgroups, topologia VMware e responsabilità operative.

---

# APPENDICE A — Come leggere ed eseguire questo runbook

**Legenda di affidabilità (obbligatoria):**

- **[ESEGUITO + OUTPUT]**: il comando o la fase è presente nei log conservati o nel dialogo operativo, con output positivo.
- **[ESEGUITO + SINTESI]**: l'operazione è confermata dal report tecnico, ma non è disponibile qui l'intera trascrizione originale.
- **[ESEMPIO NON RIPETERE]**: sintassi per spiegare il risultato; va validata su installazione diversa e non è una traccia forense.
- **[NON ESEGUITO]**: controllo o test consigliato dopo il recupero, non documentato come completato.

**Formato delle procedure:** `host / utente` → prerequisito → blocco → spiegazione delle istruzioni → output atteso → errore/STOP. Un comando senza output in un documento storico non è prova di successo. Gli IP seguenti usano esclusivamente TEST-NET (RFC 5737). I comandi che consultano gli oggetti reali del laboratorio mantengono nomi database e directory, ma non credenziali, UUID e IP originali.

## A.1 Convenzioni di ambiente Oracle

```bash
# root@sole1 o root@sole2; NON eseguire come unica sessione globale
GH=/u01/app/19.0.0/grid
DBH=/u01/app/oracle/product/19.0.0/dbhome_1
NODE=$(hostname -s)
case "$NODE" in sole1) DB_SID=SOTERRA1; ASM_SID=+ASM1;;
                sole2) DB_SID=SOTERRA2; ASM_SID=+ASM2;;
                *) echo 'STOP: nodo non SOLE'; exit 1;; esac
printf 'node=%s db=%s asm=%s\n' "$NODE" "$DB_SID" "$ASM_SID"
```

**Riga per riga:** `GH` punta ai binari della Grid (proprietario `grid`); `DBH` ai binari del database (proprietario `oracle`). `hostname -s` controlla il contesto. Il `case` impedisce di indirizzare erroneamente la SID del nodo 1 al nodo 2. L'espansione delle variabili avviene solo nella shell corrente: questi valori non devono essere lanciati sul cliente QLY.

```bash
# root, esempio di esecuzione read-only tramite utente DB
runuser -u oracle -- env ORACLE_HOME="$DBH" \
  ORACLE_BASE=/u01/app/oracle ORACLE_SID="$DB_SID" \
  PATH="$DBH/bin:/usr/bin:/bin" "$DBH/bin/sqlplus" -s -L / as sysdba

# root, esempio di esecuzione ASM: digitare soltanto in presenza dei privilegi verificati
runuser -u grid -- env ORACLE_HOME="$GH" ORACLE_SID="$ASM_SID" \
  PATH="$GH/bin:/usr/bin:/bin" "$GH/bin/asmcmd" lsdg
```

**Spiegazione:** `runuser -u` cambia utente senza alterare persistentemente il login; `env` costruisce un ambiente controllato; `ORACLE_SID` seleziona l'istanza locale; `-L` fa fallire subito login SQL*Plus; `/ as sysdba` e la connessione ASM dipendono dai gruppi OS (non dal nuovo password file di database). In una shell interattiva SQL*Plus il primo esempio apre la sessione, non esegue alcuna DDL. **STOP** se i proprietari o le Home differiscono.

# APPENDICE B — Preparazione e ricostruzione delle LUN: registro dettagliato

## B.1 Fotografia Proxmox prima di qualsiasi modifica [ESEGUITO + SINTESI]

```bash
# root@pve-lab (hypervisor), sola lettura
qm config <VMID_NODO_1>            # SOSTITUIRE il VMID certificato
qm config <VMID_NODO_2>
pvesm status
zfs list -t filesystem,volume,snapshot
```

**Cosa fanno:** `qm config` mostra l'attachment SCSI/virtio delle due VM; `pvesm status` mappa storage e disponibilità; `zfs list` evidenzia zvol e snapshot da preservare. I VMID erano reali ma qui sono sostituiti per la pubblicazione; i volumi precedenti sono stati conservati come **unused**. **STOP** se uno zvol originale è ancora collegato o potrebbe contenere dati recuperabili: non riciclarlo.

## B.2 Distinguere OS, backup, ASM [ESEGUITO + SINTESI]

```bash
# root@sole1 E root@sole2; sola lettura
lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINT
for dev in /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf /dev/sdg; do
  test -b "$dev" || continue
  echo "=== $dev ==="
  udevadm info --query=property --name="$dev" |
    grep -E '^(ID_SERIAL|ID_PATH|ID_WWN)=' || true
done
```

**Riga per riga:** `lsblk` mostra la struttura OS/dati; `test -b` scarta nomi assenti; `udevadm info` recupera identificatori più affidabili di `/dev/sdX`; `grep` restringe le proprietà visibili. Nell'istantanea reale `sda` era OS, `sdg` era il disco XFS di backup. Nel riuso del runbook **NON** prendere l'assegnazione storica `sdg` come garanzia: controllare UUID e backing hypervisor.

## B.3 Etichettatura ASMLIB e creazione dischi [PARZIALE: comandi storici di scrittura non integralmente conservati]

```bash
# INVENTARIO READ-ONLY; root su entrambi
oracleasm listdisks
for d in CRS1 CRS2 CRS3 DATA1 FRA1; do
  oracleasm querydisk "$d" || echo "MISSING ASMLIB: $d"
done

# NOTA: il pattern seguente è SOLO illustrativo. Non eseguire su dischi in uso:
# oracleasm createdisk CRS1 /dev/<PARTIZIONE_NUOVA_E_CERTIFICATA>
# oracleasm createdisk CRS2 /dev/<PARTIZIONE_NUOVA_E_CERTIFICATA>
# oracleasm createdisk CRS3 /dev/<PARTIZIONE_NUOVA_E_CERTIFICATA>
# oracleasm createdisk DATA1 /dev/<PARTIZIONE_NUOVA_E_CERTIFICATA>
# oracleasm createdisk FRA1 /dev/<PARTIZIONE_NUOVA_E_CERTIFICATA>
```

**Spiegazione:** `listdisks` elenca label correnti; `querydisk` verifica una label; `createdisk` scriverebbe header ASMLIB, quindi gli esempi sono commentati. L'operazione storica di GPT/labeling è documentata come eseguita, ma non abbiamo la riga di partizionamento originale perciò non ne inventiamo una. L'esecuzione deve avvenire una volta sola sul device certificato; sull'altro nodo si effettua discovery, **non** una seconda formattazione.

## B.4 Controllo ASM prima della creazione DG [ESEGUITO + SINTESI]

```sql
-- grid@sole1, sqlplus / as sysasm, solo lettura
SET LINESIZE 200 PAGESIZE 100
SELECT path, name, header_status, mount_status, mode_status,
       total_mb, group_number FROM v$asm_disk ORDER BY path;
SELECT name, state, type, total_mb, free_mb, usable_file_mb
FROM v$asm_diskgroup ORDER BY name;
```

**Spiegazione:** `HEADER_STATUS=PROVISIONED` su `DATA1/FRA1` attestava device nuovi non assegnati; `MEMBER` su `CRS1–3` attestava assegnazione a `+CRS`. Una LUN con `MEMBER` di un DG storico diverso, o con proprietà non spiegate, è un **STOP**, non una candidata a `CREATE DISKGROUP`.

## B.5 Creazione dei DG dati [ESEGUITO + SINTESI]

```sql
-- grid@sole1, ATTENZIONE: DDL ASM. Non ripetere se DG già esiste.
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK 'ORCL:DATA1' NAME DATA1
  ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='12.1';

CREATE DISKGROUP FRA EXTERNAL REDUNDANCY
  DISK 'ORCL:FRA1' NAME FRA1
  ATTRIBUTE 'compatible.asm'='19.0', 'compatible.rdbms'='12.1';
```

**Comando per comando:** `CREATE DISKGROUP` inizializza il file system ASM logico; `EXTERNAL REDUNDANCY` non crea copie ASM aggiuntive; `DISK` seleziona un header ASMLIB certificato; `NAME` dà identificativo nel DG; `compatible.asm` / `compatible.rdbms` impostano soglie di compatibilità — sono valori reali del lab, non da imporre a un cliente. I nuovi DG furono montati anche su Sole2 tramite `srvctl start diskgroup ... -node sole2`; `asmcmd lsdg` confermò `MOUNTED`.

# APPENDICE C — Ricostruzione GI e protezione OCR

## C.1 Deconfigurazione Home esistente [ESEGUITO + OUTPUT]

```bash
# ATTENZIONE DISTRUTTIVO DI CONFIGURAZIONE; root@sole2 PER PRIMO
GH=/u01/app/19.0.0/grid
cd "$GH/crs/install" || exit 1
set -o pipefail
./rootcrs.sh -deconfig -force 2>&1 | tee /root/sole2_rootcrs_deconfig_20261016.log
printf 'rootcrs rc=%s\n' "${PIPESTATUS[0]}"

# root@sole1, solo se il primo comando è terminato con exit 0
GH=/u01/app/19.0.0/grid
cd "$GH/crs/install" || exit 1
set -o pipefail
./rootcrs.sh -deconfig -force -lastnode 2>&1 | tee /root/sole1_rootcrs_lastnode_20261016.log
printf 'rootcrs lastnode rc=%s\n' "${PIPESTATUS[0]}"
```

**Interpretazione:** `-deconfig` cancella la configurazione GI, non i binari; `-force` supera alcuni impedimenti ma non significa «sempre sicuro»; `-lastnode` è riservato all'ultimo nodo. `tee` conserva evidenze; `PIPESTATUS[0]` va catturato subito, prima di altri comandi, per distinguere errore del programma da successo di `tee`. Il log osservato terminava con **CLSRSC-336 ed exit 0** su entrambi. **Su QLY serve un change distinto e un piano di rollback**.

## C.2 GPnP: errore reale e soluzione circoscritta [ESEGUITO + SINTESI]

```bash
# root su entrambi; lettura proprietà, non aprire wallet/credenziali
GH=/u01/app/19.0.0/grid
find "$GH/gpnp" -maxdepth 6 -type d -printf '%P | %u:%g | %m\n' | sort
for rel in seed/asm profiles/peer wallets/peer wallets/pa wallets/prdr wallets/root; do
  stat -c '%n | %U:%G | %a' "$GH/gpnp/$rel" 2>/dev/null || echo "MISSING $rel"
done
```

**Spiegazione:** nell'installazione verificata una directory di destinazione mancava durante la replica GPnP e faceva fallire la propagazione di `credentials.xml`/`profile.xml`/`cwallet.sso`. La correzione ha riguardato solo la struttura assente, dopo confronto owner/group/mode da Sole1. **Non** eseguire `rm -rf` su `gpnp`, non copiare wallet vecchi, non «riparare» permessi con `chmod -R 777`.

```bash
# ESEMPIO DI INTERVENTO STORICO SUL SOLE2; solo se stesso difetto confermato
GH=/u01/app/19.0.0/grid
install -d -o grid -g oinstall -m 1750 "$GH/gpnp/wallets"
install -d -o grid -g oinstall -m 1700 "$GH/gpnp/wallets/peer"
install -d -o grid -g oinstall -m 1700 "$GH/gpnp/wallets/pa"
install -d -o grid -g oinstall -m 1750 "$GH/gpnp/wallets/prdr"
install -d -o grid -g oinstall -m 1700 "$GH/gpnp/wallets/root"
```

**Nota:** `install -d` crea la directory **se manca** e può modificarne i permessi se esiste; la sintassi riflette i permessi verificati nel laboratorio. Non è uno step generico di ogni cluster.

## C.3 Wizard GI e root scripts [ESEGUITO + OUTPUT]

```bash
# grid@sole1, nuovo bootstrap su software Home esistente
cd /u01/app/19.0.0/grid
./gridSetup.sh

# root@sole1, solo al prompt wizard e con stato GI pronto
( set -o pipefail; cd /u01/app/19.0.0/grid || exit 1
  ./root.sh 2>&1 | tee /root/sole1_rootsh_retry4_20261016.log
  exit "${PIPESTATUS[0]}" )

# root@sole2, solo dopo nodo1 exit=0 e check OCI/OCR del wizard
( set -o pipefail; cd /u01/app/19.0.0/grid || exit 1
  ./root.sh 2>&1 | tee /root/sole2_rootsh_reconfig_20261016.log
  exit "${PIPESTATUS[0]}" )
```

**Cosa attendersi:** i log reali mostravano root scripts con 19 fasi fino a `PostConfig`, esito `CLSRSC-325`/`CLSRSC-343`, exit 0. Se un `root.sh` fallisce, leggere `crsconfig` e le cause specifiche, *non* rilanciarlo 4 volte per principio (il nome storico del log contiene “retry4” perché il lab ha avuto ripartenze condizionate).

## C.4 Verifica OCR/voting e copia FUORI ASM [ESEGUITO + OUTPUT]

```bash
GH=/u01/app/19.0.0/grid
"$GH/bin/crsctl" check cluster -all       # CRS/CSS/EVM sui due nodi
"$GH/bin/olsnodes" -n -s                # membri + stato Active
"$GH/bin/crsctl" stat res -t            # risorse ONLINE/OFFLINE
"$GH/bin/ocrcheck"                     # integrità OCR
"$GH/bin/crsctl" query css votedisk     # 3 voting dischi ONLINE
"$GH/bin/ocrconfig" -manualbackup      # crea nuovo OCR backup
"$GH/bin/ocrconfig" -showbackup        # ottiene path completo reale
```

**Spiegazione comando per comando:** `crsctl check cluster -all` differisce da `check crs` locale; `olsnodes` non certifica da solo OCR; `ocrcheck` valida struttura e accessibilità del nuovo OCR; `query css votedisk` dimostra quorum; `manualbackup` genera backup di configurazione del nuovo cluster (NON riporta in vita quello perso); `showbackup` individua il file da copiare. Il risultato era un backup di circa 2,3 MiB.

```bash
# root@sole1; la path sorgente si recupera dal comando showbackup (non copiare quella di un altro cluster)
GH=/u01/app/19.0.0/grid
install -d -m 700 /root/sole_recovery_20261016
"$GH/bin/ocrconfig" -copy \
  '+CRS:/sole/OCRBACKUP/backup_20261016_103348.ocr.258.1246790029' \
  '/root/sole_recovery_20261016/OCR_SOLE_REBUILD_20261016.ocr'
sha256sum /root/sole_recovery_20261016/OCR_SOLE_REBUILD_20261016.ocr
```

**Spiegazione:** `ocrconfig -copy` trasferisce una copia di backup OCR da ASM a filesystem; `sha256sum` calcola l'impronta da confrontare dopo la copia fuori VM. Il nome specifico identifica quel checkpoint storico e non un file generico. Non pubblicare l'archivio OCR o i wallet.

# APPENDICE D — RMAN: sequenza completa, inclusa quella mancante nella sintesi

## D.1 Montaggio della sorgente separata in sola lettura [ESEGUITO + OUTPUT]

```bash
# root@sole1, SOLO dopo identificazione UUID univoca del disco backup
lsblk -o NAME,SIZE,FSTYPE,UUID,MOUNTPOINT
findmnt /mnt/sole_rman || true
# Comando storico a livello di opzioni: UUID reale omesso intenzionalmente
# mount -t xfs -o ro,norecovery UUID=<UUID_BACKUP_CERTIFICATO> /mnt/sole_rman
findmnt /mnt/sole_rman
```

**Perché `ro,norecovery`?** Un XFS in stato journal pendente può tentare una recovery del log che implicherebbe scritture. `ro,norecovery` evita il replay, privilegiando la preservazione; il filesystem deve risultare leggibile (non è garantito per ogni XFS danneggiato). Il diskgroup ASM e il mount XFS non hanno nulla in comune.

## D.2 Istanza temporanea single-instance per restore [ESEGUITO + OUTPUT]

```ini
# /tmp/sole_soterra_restore_20261016/initSOTERRA1_recovery.ora
*.db_name='SOTERRA'
*.db_unique_name='SOTERRA'
*.compatible='19.0.0'
*.db_block_size=8192
*.cluster_database=FALSE
*.enable_pluggable_database=TRUE
*.processes=320
*.sga_target=2304M
*.pga_aggregate_target=769M
*.db_create_file_dest='+DATA'
*.db_recovery_file_dest='+FRA'
*.db_recovery_file_dest_size=14000M
*.control_files='+DATA/SOTERRA/control01.ctl','+FRA/SOTERRA/control02.ctl'
*.audit_file_dest='/u01/app/oracle/admin/SOTERRA/adump'
```

**Riga per riga:** `db_name` e `db_unique_name` identificano il database da recuperare; `compatible` delimita formato file; `db_block_size` deve corrispondere al database origine; `cluster_database=FALSE` evita un secondo mount RAC durante il restore; `enable_pluggable_database` abilita CDB; i parametri SGA/PGA/processes devono rispettare RAM e workload; `db_create_file_dest` permette OMF su nuova `+DATA`; `db_recovery_file_dest` e size definiscono la FRA; `control_files` punta **solo** agli alias appena ricreati, mai agli OMF vecchi; `audit_file_dest` deve esistere ed essere scrivibile da `oracle`. Non copiare questa configurazione su un CDB diverso.

```sql
-- oracle@sole1 con ORACLE_SID=SOTERRA1; DDL di bootstrap
STARTUP NOMOUNT PFILE='/tmp/sole_soterra_restore_20261016/initSOTERRA1_recovery.ora';
-- Atteso: istanza STARTED, non OPEN.
```

**Perché NOMOUNT:** prima di ripristinare il control file non è possibile montare il database. Se compare `ORA-01078`, validare la sintassi PFILE; se compare `ORA-150xx`, verificare ASM; fermarsi e non modificare path casualmente.

## D.3 Restore control file e catalogazione backup [ESEGUITO + OUTPUT]

```rman
# oracle@sole1, target / nocatalog. DBID storico accertato; nessun backup viene riscritto.
SET DBID 2483660440;
RESTORE CONTROLFILE FROM '/mnt/sole_rman/SOTERRA_FULL_20261016/07550akp_7_1_1.bkp';
SQL 'ALTER DATABASE MOUNT';
CATALOG BACKUPPIECE '/mnt/sole_rman/SOTERRA_FULL_20261016/02550acg_2_1_1.bkp';
CATALOG BACKUPPIECE '/mnt/sole_rman/SOTERRA_FULL_20261016/03550aei_3_1_1.bkp';
CATALOG BACKUPPIECE '/mnt/sole_rman/SOTERRA_FULL_20261016/04550agt_4_1_1.bkp';
CATALOG BACKUPPIECE '/mnt/sole_rman/SOTERRA_FULL_20261016/05550ail_5_1_1.bkp';
CATALOG BACKUPPIECE '/mnt/sole_rman/SOTERRA_FULL_20261016/06550akn_6_1_1.bkp';
CATALOG BACKUPPIECE '/mnt/sole_rman/SOTERRA_FULL_20261016/07550akp_7_1_1.bkp';
CATALOG BACKUPPIECE '/mnt/sole_rman/SOTERRA_FULL_20261016/08550akr_8_1_1.bkp';
LIST BACKUP SUMMARY;
REPORT SCHEMA;
```

**Comandi:** `SET DBID` individua il database quando non è montato; `RESTORE CONTROLFILE` porta in ASM una copia del backup control file e imposta i riferimenti di mount; `ALTER DATABASE MOUNT` legge il catalogo file/redo ancora storico; ogni `CATALOG BACKUPPIECE` reintroduce un pezzo sulla controlfile repository; `LIST BACKUP SUMMARY` controlla associazioni; `REPORT SCHEMA` inventaria file, ma con backup control file può emettere `RMAN-06139`, warning atteso nel contesto documentato. **Non ignorare altri errori RMAN**.

## D.4 Scegliere SCN e validare prima di scrivere [ESEGUITO + OUTPUT]

```sql
-- oracle@sole1, con DB MOUNT
SELECT file#, name FROM v$datafile ORDER BY file#;
SELECT group#, member FROM v$logfile ORDER BY group#, member;
SELECT file#, MAX(checkpoint_change#) FROM v$backup_datafile
 WHERE file# > 0 GROUP BY file# ORDER BY file#;
SELECT thread#, sequence#, first_change#, next_change#
 FROM v$backup_redolog ORDER BY thread#, sequence#;
```

**Interpretazione:** `v$datafile` indica i 13 file di ROOT, SEED, TERRAPDB; `v$logfile` mostra otto vecchi redo member da rinominare; `v$backup_datafile` e `v$backup_redolog` aiutano a verificare che gli SCN siano coperti dai backup e dai due thread. Non selezionare un `UNTIL SCN` oltre l'ultimo archived redo completo disponibile.

```rman
RUN {
  SET UNTIL SCN 3484552;
  RESTORE DATABASE PREVIEW SUMMARY;
  RESTORE DATABASE VALIDATE;
}
RESTORE ARCHIVELOG FROM SCN 3484265 UNTIL SCN 3484552 PREVIEW;
```

**Comandi:** `SET UNTIL` impone il limite coerente con l'incarnazione e con la copertura archivelog; `PREVIEW` legge i metadati senza restore; `VALIDATE` legge e verifica i backupset; il preview degli archived log controlla che i thread indispensabili siano presenti. Gli SCN sono **evidenze specifiche** del 16/10/2026, non un modello da riutilizzare. La verifica portò a un recovery concluso con nuova `RESETLOGS_CHANGE#=3484553`.

## D.5 RESTORE effettivamente eseguito: OMF + switch [ESEGUITO + OUTPUT]

```rman
RUN {
  SET UNTIL SCN 3484552;
  SET NEWNAME FOR DATABASE TO '+DATA';
  RESTORE DATABASE;
  SWITCH DATAFILE ALL;
}
```

**Riga per riga:** `SET UNTIL` delimita la recovery incompleta; `SET NEWNAME` ordina a RMAN di ricreare **tutti i datafile** con nuovi nomi OMF nel nuovo `+DATA`; `RESTORE DATABASE` legge i set dati originali senza alterare il backup XFS; `SWITCH DATAFILE ALL` aggiorna il control file per usare i nuovi datafile ripristinati. Nei log sono stati osservati 13 `datafile switched to datafile copy`, con percorsi `+DATA/SOTERRA/...` corretti. **Non ripetere il RUN ora che il DB è operativo.**

## D.6 Recovery separato, a SCN concordato [ESEGUITO + RISULTATO]

```rman
# Rappresentazione della recovery effettiva; SET UNTIL deve restare coerente col restore.
RUN {
  SET UNTIL SCN 3484552;
  RECOVER DATABASE;
}
```

**Spiegazione:** `RECOVER DATABASE` applica redo archiviati su datafile restaurati, anche dal thread 2 precedente. Quando termina, NON significa ancora che il DB sia `OPEN`: per un recupero incompleto con backup control file serve un'apertura controllata con `RESETLOGS` (a fronte dei corretti prerequisiti). Se mancano archivelog, non forzare l'open con altri SCN; ripianificare il recovery point.

## D.7 Redo member storici → nuovi alias ASM [ESEGUITO + SINTESI]

```sql
-- Query read-only da eseguire PRIMA della rinomina; nel lab già eseguita.
SELECT group#, type, member FROM v$logfile ORDER BY group#, member;

-- Solo esempio della trasformazione ripetuta su 8 member;
-- sostituire ogni <VECCHIO_MEMBER_DA_V$LOGFILE> con il VALORE REALE.
-- ALTER DATABASE RENAME FILE '<VECCHIO_MEMBER_DA_V$LOGFILE>'
--   TO '+DATA/SOTERRA/redo_g01_a.log';
-- ALTER DATABASE RENAME FILE '<VECCHIO_MEMBER_DA_V$LOGFILE>'
--   TO '+FRA/SOTERRA/redo_g01_b.log';
```

**Perché:** in `MOUNT`, con i redo OMF originali non più presenti, Oracle non avrebbe potuto aprire `RESETLOGS`. Il DDL effettivo ha convertito gli otto member in nomi nuovi nei due DG e le nuove destinazioni furono verificate. Non creiamo finti nomi sorgente: un `ALTER DATABASE RENAME FILE` con placeholder sarebbe pericoloso.

## D.8 Apertura del database e tempfile [ESEGUITO + OUTPUT]

```sql
-- Eseguito DOPO completed recovery, file redo corretti e check di stato
ALTER DATABASE OPEN RESETLOGS;

-- Verifiche read-only successive
SELECT name, dbid, open_mode, resetlogs_change# FROM v$database;
SELECT con_id, name, open_mode FROM v$pdbs ORDER BY con_id;
SELECT con_id, file#, name, bytes FROM v$tempfile ORDER BY con_id, file#;
SELECT group#, status FROM v$log ORDER BY group#;
```

**Spiegazione:** `OPEN RESETLOGS` crea la nuova incarnazione e re-inizializza i thread redo; il DBID resta invariato. Lo script iniziale con `raise_application_error` aveva fallito per PLS-00201 senza eseguire la DDL; la DDL separata riuscì. `v$tempfile` dimostrò tre tempfile riprodotti automaticamente (root, seed, TERRAPDB). Il database era `READ WRITE`, la PDB TERRAPDB `READ WRITE`. `OPEN RESETLOGS` non va mai ripetuto su un database già aperto.

# APPENDICE E — SPFILE, OCI/OCR, password file e avvio RAC

## E.1 Vecchio SPFILE vs SPFILE nuovo [ESEGUITO + OUTPUT]

```text
Vecchio SPFILE RMAN:      08550akr_8_1_1.bkp
PFILE di ispezione:      /tmp/sole_soterra_restore_20261016/initSOTERRA_original_pre_disaster.ora
PFILE di recovery:       /tmp/sole_soterra_restore_20261016/initSOTERRA1_recovery.ora
PFILE RAC definitivo:    /tmp/sole_soterra_restore_20261016/initSOTERRA_RAC_final.ora
SPFILE ASM condiviso:    +DATA/SOTERRA/spfileSOTERRA.ora
PFILE di readback:       /tmp/sole_soterra_restore_20261016/initSOTERRA_spfile_readback.ora
```

**Perché il vecchio SPFILE non si riusa:** referenziava i vecchi OMF `CONTROLFILE/current.*` e parametri `local_listener` stale. Non è stato sovrascritto; è servito solo come riferimento. Il nuovo PFILE RAC è stato creato dal PFILE funzionante con `cluster_database=TRUE`, due SID, thread 1/2, undo dedicato per istanza. Il file completo deve essere validato in sito per RAM e ambiente, non copiato automaticamente in un altro laboratorio.

```sql
CREATE SPFILE='+DATA/SOTERRA/spfileSOTERRA.ora'
  FROM PFILE='/tmp/sole_soterra_restore_20261016/initSOTERRA_RAC_final.ora';
CREATE PFILE='/tmp/sole_soterra_restore_20261016/initSOTERRA_spfile_readback.ora'
  FROM SPFILE='+DATA/SOTERRA/spfileSOTERRA.ora';
```

**Comandi:** il primo crea un file binario ASM di parametri; il secondo lo rilegge come testo per verificare concretamente `control_files`, `cluster_database`, `instance_number`, `thread`, `undo_tablespace`. Fu eseguito **prima** del cambio modalità. Su entrambi i nodi furono verificati assenti `dbs/spfileSOTERRA?.ora`, `dbs/spfile.ora`, `dbs/initSOTERRA?.ora`: un `spfileSID.ora` locale potrebbe deviare un avvio non gestito; è la ragione per cui non furono creati pointer arbitrari.

## E.2 Registrazione OCR del database [ESEGUITO + OUTPUT]

```bash
# oracle@sole1, environment ORACLE_HOME=DBH, ORACLE_BASE=/u01/app/oracle
srvctl add database \
  -db SOTERRA -dbname SOTERRA \
  -oraclehome /u01/app/oracle/product/19.0.0/dbhome_1 \
  -spfile '+DATA/SOTERRA/spfileSOTERRA.ora' -dbtype RAC \
  -role PRIMARY -startoption OPEN -stopoption IMMEDIATE \
  -policy MANUAL -diskgroup 'DATA,FRA'

srvctl add instance -db SOTERRA -instance SOTERRA1 -node sole1
srvctl add instance -db SOTERRA -instance SOTERRA2 -node sole2
srvctl config database -db SOTERRA
```

**Flag per flag:** `-db` indica `DB_UNIQUE_NAME` della risorsa OCR; `-dbname` il `DB_NAME`; `-oraclehome` il DB software; `-spfile` il percorso effettivo ASM; `-dbtype RAC` istanze RAC, non single; `-role PRIMARY` ruolo; `-startoption OPEN` condizione all'avvio; `-stopoption IMMEDIATE` shutdown controllato; `-policy MANUAL` impedisce automatic start non richiesto durante la fase di recovery; `-diskgroup` elenca DG usati dal DB. `add instance` assegna ciascun SID al nodo amministrato. Non rieseguire `add` se la risorsa esiste: leggere prima `config`.

## E.3 Password file nuovo (solo DB) [ESEGUITO + OUTPUT]

```bash
# grid@sole1 con ORACLE_HOME GI / ORACLE_SID +ASM1:
asmcmd pwcreate --dbuniquename SOTERRA '+DATA/SOTERRA/orapwSOTERRA'
# Password SYS digitata al prompt; mai su command-line o README.
asmcmd ls -l '+DATA/SOTERRA/orapwSOTERRA'
asmcmd pwget --dbuniquename SOTERRA
# Risposta iniziale: "Password file location has not been set for DB instance"

# oracle@sole1:
srvctl modify database -db SOTERRA -pwfile '+DATA/SOTERRA/orapwSOTERRA'
srvctl config database -db SOTERRA

# grid@sole1 dopo la registrazione:
asmcmd pwget --dbuniquename SOTERRA
# Risposta verificata: +DATA/SOTERRA/orapwSOTERRA
```

**Cosa significa:** `pwcreate` genera file PASSWORD in ASM e chiede credenziale iniziale `SYS`; `ls -l` ne mostra la presenza e alias; `pwget` espone l'associazione corrente (nel nostro caso era inizialmente vuota); `srvctl modify database -pwfile` ha registrato la posizione in OCR, senza rigenerare il file; `pwget` ha quindi mostrato il path atteso anche da Sole2. **Non usare `--asm`: quello riguarda la password file dell'istanza ASM**, con semantica e precauzioni diverse. Un rerun non necessario di `pwcreate` è sbagliato; mai usare `-f`.

## E.4 Prima della transizione: controllo dual-node [ESEGUITO + OUTPUT]

```bash
# Da ciascuna VM, come root; nessuna modifica
GH=/u01/app/19.0.0/grid
DBH=/u01/app/oracle/product/19.0.0/dbhome_1
ASM_SID=$(case "$(hostname -s)" in sole1) echo +ASM1;;sole2) echo +ASM2;;esac)
for f in '+DATA/SOTERRA/spfileSOTERRA.ora' \
         '+DATA/SOTERRA/orapwSOTERRA' \
         '+DATA/SOTERRA/control01.ctl' \
         '+FRA/SOTERRA/control02.ctl'; do
  runuser -u grid -- env ORACLE_HOME="$GH" ORACLE_SID="$ASM_SID" \
    PATH="$GH/bin:/usr/bin:/bin" "$GH/bin/asmcmd" ls -l "$f" || exit 1
done
```

**Perché:** `asmcmd ls -l` sui due nodi ha restituito gli stessi oggetti ASM (gli OMF sottostanti contenevano identici identificatori), dimostrando che non erano due file locali diversi. È stato verificato anche che `audit_file_dest` era scrivibile per `oracle`, e che non esistevano SPFILE locali divergenti.

## E.5 Backup post-resetlogs [ESEGUITO + OUTPUT]

```rman
RUN {
  ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
  BACKUP AS COMPRESSED BACKUPSET DATABASE
    FORMAT '/u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017/SOTERRA_DB_%U.bkp'
    TAG 'SOTERRA_POST_RESETLOGS';
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG FROM SCN 3484553
    FORMAT '/u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017/SOTERRA_ARCH_%U.bkp'
    TAG 'SOTERRA_POST_RESETLOGS';
  BACKUP CURRENT CONTROLFILE
    FORMAT '/u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017/SOTERRA_CTL_%U.bkp'
    TAG 'SOTERRA_POST_RESETLOGS';
  RELEASE CHANNEL c1;
}
```

**Comando per comando:** `ALLOCATE CHANNEL` seleziona un flusso DISK; `COMPRESSED BACKUPSET DATABASE` crea tre backupset fisici corrispondenti a ROOT/TERRAPDB/SEED, complessivamente 13 datafile; `FORMAT` definisce nomi univoci dei piece; `TAG` aiuta a rintracciare il checkpoint; `ARCHIVE LOG CURRENT` archivia il redo; `ARCHIVELOG FROM SCN` seleziona log successivi alla nuova incarnazione (due thread inclusi); `BACKUP CURRENT CONTROLFILE` salva i metadati correnti; `RELEASE CHANNEL` libera il canale. La directory di destinazione era stata creata da root con permessi `oracle:oinstall` 0700. Il filesystem root aveva >10 GiB liberi; il backup finale occupò ~1,4 GB.

```rman
LIST BACKUPSET TAG 'SOTERRA_POST_RESETLOGS';
RESTORE DATABASE VALIDATE;
VALIDATE BACKUPSET 14;
VALIDATE BACKUPSET 15;
```

**Perché due livelli:** `RESTORE DATABASE VALIDATE` ha realmente letto i set 10/11/12 dei 13 datafile; `VALIDATE BACKUPSET 14` ha verificato il set archivelog (thread 1+2); `VALIDATE BACKUPSET 15` il controlfile. Gli esiti furono 5/5 senza errori RMAN. Le chiavi BS 10–15 sono quelle di **questa** controlfile repository, non numeri trasferibili ad altro sistema.

## E.6 Copia sul Proxmox host: script effettivo [ESEGUITO + OUTPUT]

```bash
# root@pve-lab; esempio con IP TEST-NET, sostituire sempre dopo verifica fingerprint SSH
SRC_HOST=root@192.0.2.11
SRC=/u01/app/oracle/backup/SOTERRA_POST_RESETLOGS_20261017
DEST=/var/lib/vz/dump/sole_dr/SOTERRA_POST_RESETLOGS_20261017
install -d -m 700 /var/lib/vz/dump/sole_dr
install -d -m 700 "$DEST"
rsync -avh --no-owner --no-group --no-perms --partial --info=progress2 \
  "${SRC_HOST}:${SRC}/" "${DEST}/"
ssh "$SRC_HOST" "cd '$SRC' && sha256sum -- *.bkp *.ora *.log" \
  > "$DEST/SHA256SUMS.from_sole1"
( cd "$DEST" && sha256sum -c SHA256SUMS.from_sole1 )
chmod 700 "$DEST"
find "$DEST" -maxdepth 1 -type f -exec chmod 600 {} +
```

**Spiegazione:** `install -d` crea una destinazione protetta; `rsync` trasferisce contenuti e log; `--partial` consente di riprendere un trasferimento, ma non è una garanzia di integrità; `ssh` genera il manifest sulla **sorgente**; `sha256sum -c` confronta otto file nella destinazione; `chmod` minimizza l'esposizione. Evidenza storica: 8/8 `OK`; 242 GiB ancora liberi sull'host. Questa copia **condivide** l'hardware con la VM: per DR reale serve un terzo deposito indipendente.

## E.7 Arresto ordinato e riavvio RAC [ESEGUITO + OUTPUT]

```sql
-- oracle@sole1: prima verifica DBID/READ WRITE/cluster_database=FALSE
SHUTDOWN IMMEDIATE;
-- SQL*Plus: Database closed; Database dismounted; ORACLE instance shut down.
```

```bash
# oracle@sole1, con ORACLE_HOME=DBH e ORACLE_BASE corretti
srvctl start instance -db SOTERRA -instance SOTERRA1 -startoption OPEN
srvctl status database -db SOTERRA
# SOTERRA1 online; SOTERRA2 ancora offline

# DOPO verifica del solo SOTERRA1: spfile ASM, TRUE, READ WRITE, PDB aperta
srvctl start instance -db SOTERRA -instance SOTERRA2 -startoption OPEN
srvctl status database -db SOTERRA
```

**Perché questa sequenza:** `SHUTDOWN IMMEDIATE` dismonta/chiude coerentemente il DB aperto in modalità single; `srvctl start instance` legge il nuovo SPFILE condiviso associato alla risorsa OCR; **non** si avvia contemporaneamente la seconda istanza mentre `cluster_database=FALSE`; la seconda si avvia solo dopo che `gv$instance` della prima è `OPEN` e `v$thread` 2 è `PUBLIC` con 2 gruppi. Successo osservato: due SID `OPEN`, thread 1/2 `OPEN`, due undo tablespace separate, TERRAPDB `READ WRITE` su entrambe.

# APPENDICE F — Validazione: verifica conclusiva SQL commentata

```sql
SET LINESIZE 200 PAGESIZE 100
SELECT inst_id, instance_name, host_name, status, thread#
  FROM gv$instance ORDER BY inst_id;
SELECT name, dbid, open_mode, database_role, resetlogs_change#
  FROM v$database;
SELECT thread#, status, enabled, groups FROM v$thread ORDER BY thread#;
SELECT inst_id, name, value FROM gv$parameter
 WHERE name IN ('cluster_database','spfile','undo_tablespace')
 ORDER BY name, inst_id;
SELECT inst_id, name, open_mode FROM gv$pdbs
 WHERE name IN ('TERRAPDB','PDB$SEED') ORDER BY inst_id, name;
```

| Query | Perché è importante | Risultato reale 17/10 |
|---|---|---|
| `GV$INSTANCE` | vista globale di tutte le istanze | SOTERRA1/2 `OPEN` su nodi distinti |
| `V$DATABASE` | identità, ruolo e incarnazione | SOTERRA `PRIMARY`, `READ WRITE`, DBID identico |
| `V$THREAD` | redo corrente per istanza | thread 1 e 2 `OPEN` / `PUBLIC` / 2 gruppi ciascuno |
| `GV$PARAMETER` | conferma parametro statico e SPFILE condiviso | `cluster_database=TRUE` entrambe; `SPFILE=+DATA...`; undo 1/2 |
| `GV$PDBS` | CDB PDB open-state su ciascuna istanza | TERRAPDB `READ WRITE` su entrambe, SEED `READ ONLY` |

# APPENDICE G — Troubleshooting: errori osservati e risposta operativa (non inventare fix)

| Evento | Origine | Cosa fare | Cosa evitare |
|---|---|---|---|
| Vecchio OCR irraggiungibile | LUN OCR perdute | preservare OLR, inventario e ripreparare GI | `ocrconfig -restore` senza backup OCR esterno |
| errore `CLSRSC` in InitConfig / GPnP | directory remote peer incomplete | leggere log preciso e controllare owner/mode | cancellare wallet o ricopiare vecchio GPnP |
| `RMAN-06139` su `REPORT SCHEMA` | backup controlfile non corrente | leggere schema/SCN da backup catalogati | dichiarare ripristino fallito per questo warning |
| errore script `PLS-00201` | wrapper PL/SQL prima di `OPEN RESETLOGS` | correggere script e verificare stato DB | rifare restore RMAN per errore dello script |
| `Database instances:` vuoto ma `grep -Fqx` fallisce | spazi/trailing field output | usare regex `[[:space:]]*` e stampare CFG | registrare di nuovo DB esistente |
| `srvctl config` vuoto in uno script | ambiente `oracle` incompleto | `env ORACLE_HOME`, `ORACLE_BASE`, `PATH` espliciti | attribuire a OCR corrotto senza `crsctl` |
| pwfile in ASM ma `pwget` vuoto | assenza percorso database OCR | `srvctl modify database -pwfile` e rileggere | ricreare file / forzare overwrite |
| `lsblk MOUNTPOINTS` sconosciuta | versione util-linux OL8 | `MOUNTPOINT` | parlare di guasto dischi |
| `srvctl status` offline prima di shutdown | DB avviato manualmente, non CRS-managed | shutdown poi startup via srvctl | avviare 2° RAC prima del passaggio |

# APPENDICE H — Runbook per verifiche ancora non eseguite

> **[NON ESEGUITO]** I comandi sotto sono esclusivamente di diagnosi o sono test condizionati; non vanno riportati nel report come già effettuati.

```bash
# grid@sole1 (GI home): SCAN, listener, servizi
srvctl config scan
srvctl status scan
srvctl status scan_listener
srvctl status listener

# oracle@sole1 (DB home): servizi RAC / policy
srvctl config database -db SOTERRA
srvctl status database -db SOTERRA
srvctl config service -db SOTERRA
srvctl status service -db SOTERRA
```

**Interpretazione:** `srvctl config` è impostazione persistente; `status` è runtime. L'assenza di un servizio applicativo su TERRAPDB non invalida il recupero DB, ma impedisce di dichiarare concluso il test di connettività da client. Non creare un service nuovo senza convenzioni e test di rete.

```sql
-- oracle@sole1 /as sysdba, read-only, stato redo e spazio FRA
SELECT thread#, status, enabled FROM v$thread ORDER BY thread#;
SELECT inst_id, instance_name, status FROM gv$instance ORDER BY inst_id;
SELECT inst_id, name, open_mode FROM gv$pdbs ORDER BY inst_id, name;
SELECT name, space_limit, space_used, space_reclaimable FROM v$recovery_file_dest;
SELECT file_name, format, is_asm FROM v$passwordfile_info;
SELECT username, sysdba, sysbackup, sysdg, syskm FROM v$pwfile_users;
```

**Perché:** verifica lo stato della nuova incarnazione e la metadata visibility del pwfile *dopo* avvio. Il contenuto di `V$PWFILE_USERS` è un inventario di grant speciali, non un dump di segreti. Il test del password file remoto va fatto da rete separata con credenziali conservate nel vault, non inserite nei log.

**Test di failover, reboot delle VM, policy AUTOMATIC, TDE, retention RMAN e restore su host separato:** non sono mai stati eseguiti nell'evidenza disponibile e richiedono un piano autonomo, con downtime concordato, verifiche sulla continuità dei client e rollback. Non includere un comando di spegnimento a caldo come «test innocuo».

---

**Indice comando → passo:** `qm/pvesm/zfs` B.1, `lsblk/udevadm` B.2, `oracleasm` B.3, `v$asm_*` B.4, `CREATE DISKGROUP` B.5, `rootcrs` C.1, `gpnp/install` C.2, `gridSetup/root.sh` C.3, `ocrconfig` C.4, `mount` D.1, `PFILE` D.2, `RESTORE CONTROLFILE/CATALOG` D.3, SCN/PREVIEW D.4, `SET NEWNAME/RESTORE/SWITCH` D.5, `RECOVER` D.6, `RENAME FILE` D.7, `RESETLOGS` D.8, SPFILE E.1, SRVCTL E.2, password file E.3, precheck E.4, RMAN backup/VALIDATE E.5, off-host hash E.6, avvio RAC E.7, verifica F, troubleshooting G, controlli futuri H.
