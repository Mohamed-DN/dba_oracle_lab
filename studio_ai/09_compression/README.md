# 09 — Data Compression (HCC / DBMS_REDEFINITION)

> Procedures for online data compression with near-zero downtime using DBMS_REDEFINITION.

---

## Why Compress?

In Enterprise databases with hundreds of GB tables, compression:
- **Reduces disk space** (50-80% savings with HCC)
- **Migliora le performance di lettura** (meno I/O)
- **Riduce i costi storage** (meno LUN da acquistare)

Oracle offre diversi livelli di compressione:
| Livello | Tipo | Rapporto | Impatto CPU |
|---|---|---|---|
| Basic | `COMPRESS BASIC` | 2-3x | Basso |
| OLTP | `COMPRESS FOR OLTP` | 2-4x | Basso |
| Query High | `COMPRESS FOR QUERY HIGH` (HCC) | 6-10x | Medio |
| Archive High | `COMPRESS FOR ARCHIVE HIGH` (HCC) | 10-15x | Alto |

> [!NOTE]
> HCC (Hybrid Columnar Compression) richiede **Exadata** o **ZFS Storage Appliance**. Su storage standard, usare OLTP Compression.

---

## How to: Online Compression with DBMS_REDEFINITION

This procedure allows you to compress a table **without downtime** (near-zero):

```sql
-- 1. Verifica che la tabella sia ridefinibile
EXEC DBMS_REDEFINITION.CAN_REDEF_TABLE('SCHEMA', 'TABELLA');

-- 2. Crea la tabella interim (compressa)
CREATE TABLE SCHEMA.TABELLA_INTERIM
  COMPRESS FOR OLTP
  AS SELECT * FROM SCHEMA.TABELLA WHERE 1=2;

-- 3. Avvia la ridefinizione
EXEC DBMS_REDEFINITION.START_REDEF_TABLE('SCHEMA', 'TABELLA', 'TABELLA_INTERIM');

-- 4. Sincronizza i dati (ripetere periodicamente se la tabella è grande)
EXEC DBMS_REDEFINITION.SYNC_INTERIM_TABLE('SCHEMA', 'TABELLA', 'TABELLA_INTERIM');

-- 5. Completa la ridefinizione (switch atomico — millisecondi di lock)
EXEC DBMS_REDEFINITION.FINISH_REDEF_TABLE('SCHEMA', 'TABELLA', 'TABELLA_INTERIM');

-- 6. Pulizia
DROP TABLE SCHEMA.TABELLA_INTERIM;

-- 7. Verifica
SELECT table_name, compression, compress_for FROM dba_tables WHERE table_name = 'TABELLA';
```

---

## File Contenuti
- `Get_DDL_RENAME_OBJECT.sql` — Generate DDL to rename objects during redefinition
- `STEP_COMPRESS_DBMS_REDEFINITION.txt` — Complete step-by-step procedure

---

## 🔗 Collegamento
This technique is useful for periodic maintenance DBA activities.
