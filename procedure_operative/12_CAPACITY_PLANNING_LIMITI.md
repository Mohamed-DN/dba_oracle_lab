# 12 — Capacity Planning e Limiti Fisici (Hard Limits)

> ⏱️ Tempo: 10-15 minuti | 📅 Frequenza: Mensile / Su allarme spazio | 👤 Chi: DBA
> **Scenario**: Il database cresce molto. Dobbiamo sapere non solo quanto spazio abbiamo, ma **qual è il limite architetturale invalicabile** (es. limite di dimensionamento ASM basato sulla block size).

---

## Obiettivo

Assicurarsi che l'infrastruttura (ASM e Tablespace) non si scontri contro gli "Hard Lmits" fisici di Oracle. 
Ad esempio, un datafile (SMALLFILE) con database block size a 8k NON può superare i 32GB, indipendentemente dallo spazio sul disco.

## 🗂️ Gli script di riferimento

Gli script per questa procedura sono già salvati nel repository:
1. `studio_ai/01_asm_storage/asm_limits_ausize.sql`
2. `studio_ai/03_monitoring_scripts/tbs_maxsize_limits.sql`
3. `studio_ai/03_monitoring_scripts/gen_bigfile_autoextend.sql`

---

## Step 1: Controllo Limiti Teorici ASM vs Allocation Unit (AU_SIZE)

Esegui lo script:
```sql
@studio_ai/01_asm_storage/asm_limits_ausize.sql
```

### Cosa analizzare nell'output:

1. **`AU_SIZE` (Allocation Unit Size)**:
   - Se è `1MB` (default pre-11g), il diskgroup gestirà al massimo datafile o database più piccoli rispetto a 4MB o 8MB.
   - Da 12c in poi, `AU_SIZE` default è `4MB` (supporta single BIGFILE fino a 16TB).
   
2. **`MAX_GB_DF_SF_BASE_BS` (Max GB Datafile Smallfile Base Block Size)**:
   - Solitamente è 32GB se `db_block_size = 8192`. Questo significa che NESSUN Smallfile può superare i 32GB. **Non impostare il `MAXSIZE` a 64GB su questi file, Oracle fallirebbe.**

3. **`MAX_TB_BF_LIMIT` (Max TB Bigfile Limit)**:
   - Indica il limite massimo per un BIGFILE Tablespace nel diskgroup.
   
4. **Colonna `Alert^80%`**:
   - Indica direttamente i diskgroup che superano la soglia di allarme logico (spazio fisico usato su totale).

---

## Step 2: MAXSIZE rispetto allo Spazio Reale Allocato

Esegui lo script:
```sql
@studio_ai/03_monitoring_scripts/tbs_maxsize_limits.sql
```

### Come interpretarlo:
Questo report mostra 5 colonne fondamentali in GB.

| Colonna | Significato | Attenzione se... |
|---------|------------|------------------|
| `MAXSIZE` | La somma di tutti i `MAXSIZE` (o max autoextend) per il tablespace. | È troppo grande (il DB scoppierà in storage fisico prima di arrivare a questa soglia) o troppo piccolo. |
| `TOTAL PHYS ALLOC`| Spazio fisico attuale allocato sul file system/ASM. | È quasi identico al MAXSIZE. Il tablespace non può più crescere. |
| `USED` | Spazio *realmente* contenente dati. | Molto inferiore all'Allocato: hai segmenti vuoti o tabelle povery, valuta shrink. |
| `% USED` | Percentuale di utilizzo sul MAXSIZE teorico. | `> 85%`: Devi intervenire aumentando il limite. |

---

## Step 3: Gestione proattiva dei BIGFILE Tablespace

Quando un BIGFILE arriva alla saturazione, l'unica soluzione è estendere il suo MAXSIZE (poiché usa un singolo enorme datafile). 
Il generatore fornisce il comando esatto per portare il limite al **170%** del valore attuale (o a un minimo predefinito di ~10GB), escludendo in automatico i tablespace di sistema e UNDO.

Esegui:
```sql
@studio_ai/03_monitoring_scripts/gen_bigfile_autoextend.sql
```

### Esempio output (da copiare e lanciare):
```sql
alter tablespace NODO_ONLINE_LOB_2 AUTOEXTEND ON maxsize 18128219194;
```
*Lancia i comandi ottenuti solo sui tablespace che ne hanno effettivamente bisogno in base allo Step 2.*

---

## ✅ Best Practices / Check di Conferma

| Controllo | Verifica / Limit |
|---|---|
| SMALLFILE Datafiles | Nessun datafile ha `MAXSIZE > 32G` (se bs=8k). |
| BIGFILE Tablespace | I tablespace enormi (es. `RE_DATA`, LOBs) usano BIGFILE e non eccedono i limiti AU_SIZE dello Step 1. |
| Coerenza MAXSIZE / FISICO | La somma dei MAXSIZE di tutti i DB rac non supera lo storage fisico realmente installato nell'Hypervisor/Storage array. Questa si chiama `Thin Provisioning Trap`! |
