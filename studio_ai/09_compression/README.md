#09 — Data Compression (HCC /DBMS_REDEFINITION)

> Procedures for online data compression with near-zero downtime using DBMS_REDEFINITION.

---

## Why Compress?

In Enterprise databases with hundreds of GB tables, compression:
- **Reduces disk space** (50-80% savings with HCC)
- **Improves read performance** (less I/O)
- **Reduces storage costs** (fewer LUNs to purchase)

Oracle offers several levels of compression:
| Livello | Tipo |Relationship|CPU impact|
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
--1. Verify that the table is redefinable
EXEC DBMS_REDEFINITION.CAN_REDEF_TABLE('SCHEMA', 'TABELLA');

--2. Create the interim (compressed) table
CREATE TABLE SCHEMA.TABELLA_INTERIM
  COMPRESS FOR OLTP
  AS SELECT * FROM SCHEMA.TABELLA WHERE 1=2;

--3. Start the redefinition
EXEC DBMS_REDEFINITION.START_REDEF_TABLE('SCHEMA', 'TABELLA', 'TABELLA_INTERIM');

--4. Synchronize data (repeat periodically if table is large)
EXEC DBMS_REDEFINITION.SYNC_INTERIM_TABLE('SCHEMA', 'TABELLA', 'TABELLA_INTERIM');

--5. Complete the redefinition (atomic switch — milliseconds of lock)
EXEC DBMS_REDEFINITION.FINISH_REDEF_TABLE('SCHEMA', 'TABELLA', 'TABELLA_INTERIM');

-- 6. Pulizia
DROP TABLE SCHEMA.TABELLA_INTERIM;

--7. Check
SELECT table_name, compression, compress_for FROM dba_tables WHERE table_name = 'TABELLA';
```

---

## File Contents
- `Get_DDL_RENAME_OBJECT.sql` — Generate DDL to rename objects during redefinition
- `STEP_COMPRESS_DBMS_REDEFINITION.txt` — Complete step-by-step procedure

---

## 🔗 Link
This technique is useful for periodic maintenance DBA activities.
