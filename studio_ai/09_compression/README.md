# 09 — Data Compression (HCC / DBMS_REDEFINITION)

> Procedure per la compressione online dei dati con near-zero downtime usando DBMS_REDEFINITION.

---

## Perché Comprimere?

In database Enterprise con tabelle da centinaia di GB, la compressione:
- **Riduce lo spazio su disco** (risparmio 50-80% con HCC)
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

## Procedura: Compressione Online con DBMS_REDEFINITION

Questa procedura permette di comprimere una tabella **senza downtime** (near-zero):

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
- `Get_DDL_RENAME_OBJECT.sql` — Genera DDL per rename degli oggetti durante la ridefinizione
- `STEP_COMPRESS_DBMS_REDEFINITION.txt` — Procedura step-by-step completa

---

## 🔗 Collegamento
Questa tecnica è utile per le attività DBA di manutenzione periodica.
