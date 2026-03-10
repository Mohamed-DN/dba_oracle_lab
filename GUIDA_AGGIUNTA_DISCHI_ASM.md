# Guida: Creazione e Aggiunta Dischi ASM (Scopo Formativo)

Questa guida illustra la procedura operativa per gestire i dischi in Oracle ASM (Automatic Storage Management). 

> [!IMPORTANT]
> **Metodo ASMLib vs Udev**
> Nel nostro laboratorio e nell'architettura di riferimento usiamo **ASMLib** (`oracleasm`). 
> Esiste anche un altro metodo ampiamente utilizzato basato su **udev rules** (configurando `/etc/udev/rules.d/` e `scsi_id`). Entrambi i metodi sono validi, ma in tutta la nostra guida faremo affidamento esclusivo su **ASMLib** per semplicità e coerenza operativa.

---

## 1. Perché aggiungere o creare dischi ASM?

In un ambiente Enterprise, la gestione dello spazio è dinamica e fondamentale:
*   **Espansione della Capacità**: Quando lo spazio libero di un Disk Group (es. `+DATA`) scende sotto una soglia di allerta (di solito 15-20%), è necessario aggiungere nuovi dischi fisici. ASM permette questa operazione a caldo, **senza alcun downtime**.
*   **Bilanciamento delle Prestazioni (Rebalance)**: ASM distribuisce nativamente i dati su tutti i dischi di un Disk Group (operazione di *striping*). Quando aggiungi un nuovo disco, ASM avvia un processo automatico di *Rebalance* che sposta blocchi di dati dai vecchi dischi al nuovo. Questo distribuisce il carico I/O e migliora le performance.
*   **Separazione Logica**: In scenari avanzati, si creano Disk Group dedicati (es. `+RECO` per i backup o FRA) per isolare l'I/O critico.

---

## 2. High Level Steps (Fasi di Alto Livello)

Sia che si stia creando un Disk Group da zero o espandendone uno, questi sono i passaggi principali:

1.  **Backend** - *Provision new disks from Storage*: Fornisci i nuovi dischi fisici o virtuali dallo storage (es. VMware, VirtualBox, SAN).
2.  **root** - *Create Disk Partitions using `fdisk`*: Crea una partizione primaria per riservare il disco ed evitare sovrascritture involontarie.
3.  **root** - *Mark Disk as ASM Disks using `oracleasm createdisk`*: Registra il disco nel driver ASMLib affinché Oracle possa riconoscerlo.
4.  **grid** - *Create new disk group using `CREATE DISKGROUP` command*: Crea (o espandi usando `ALTER`) il Disk Group dalla riga di comando o grafica ASMCA.

---

## 3. Scopo Formativo: Creare un Disk Group da zero

Di seguito un esempio SQL puro per creare un nuovo Disk Group, partendo dai dischi marcati da ASMLib. Ipotizziamo che i comandi `oracleasm createdisk DATA` e `RECO` siano già stati lanciati.

```sql
# Come utente grid (proprietario del software Grid Infrastructure)
su - grid

-- Connettiti all'istanza ASM locale (+ASM1)
sqlplus / as sysasm

-- Crea disk group DATA (Usiamo il path fisico effettivo del driver oracleasm)
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
  DISK '/dev/oracleasm/disks/DATA'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

-- Crea disk group RECO
CREATE DISKGROUP RECO EXTERNAL REDUNDANCY
  DISK '/dev/oracleasm/disks/RECO'
  ATTRIBUTE 'compatible.asm' = '19.0.0.0.0',
            'compatible.rdbms' = '19.0.0.0.0';

-- Verifica i Disk Group appena creati
SELECT name, state, type, total_mb, free_mb FROM v$asm_diskgroup;

EXIT;
```

---

## 4. Esempio Pratico: Aggiungere un Disco per Espansione

Se invece si vuole espandere un Disk Group esistente (es. abbiamo già `+DATA` e vogliamo dargli più spazio), ecco i passaggi completi partendo dall'OS:

### Fase System Administrator
1. **Backend**: Viene assegnato un nuovo disco (es. 10 GB) alla macchina virtuale. Esso diviene visibile come `/dev/sdf`.
2. **rac1 (root)**: Partizionamento:
   ```bash
   fdisk /dev/sdf
   # Premi n, p, 1, invio, invio, w
   ```
3. **rac1 (root)**: Marcatura ASMLib:
   ```bash
   oracleasm createdisk DATA_EXP1 /dev/sdf1
   ```
4. **rac2 (root)**: Scoperta del nuovo disco sull'altra sede del cluster:
   ```bash
   oracleasm scandisks
   oracleasm listdisks
   ```

### Fase DBA
1. **rac1 (grid)**: Aggiunta del disco al Disk Group via SQL:
   ```sql
   su - grid
   sqlplus / as sysasm

   -- Aggiungi il disco al Disk Group DATA con priorità di rebalance 4 (valore medio-alto)
   ALTER DISKGROUP DATA ADD DISK 'ORCL:DATA_EXP1' REBALANCE POWER 4;
   
   -- Monitora l'avanzamento dell'operazione asincrona in background
   SELECT * FROM v$asm_operation;
   
   -- Verifica la nuova dimensione al termine dell'operazione
   SELECT name, total_mb, free_mb FROM v$asm_diskgroup WHERE name = 'DATA';
   ```

> [!NOTE]
> Il nome stringa `'ORCL:DATA_EXP1'` è il prefisso standard che ASMLib usa per presentare i suoi dischi al database se `asm_diskstring` è configurato come `'ORCL:*'`, che è il default.

---

## 📚 Approfondisci

Per procedure operative reali da ambiente Enterprise (con multipath, VMAX, Pure Storage), consulta:
- [Procedura Aggiunta Dischi ASM (da Produzione)](./studio_ai/01_asm_storage/procedura_aggiunta_dischi_asm.md)
- [Deallocazione Dischi ASM](./studio_ai/01_asm_storage/deallocazione_dischi_asm.md)

*Torna alla guida principale per le attività di [Preparazione Storage e Grid](./GUIDA_FASE2_GRID_E_RAC.md).*
