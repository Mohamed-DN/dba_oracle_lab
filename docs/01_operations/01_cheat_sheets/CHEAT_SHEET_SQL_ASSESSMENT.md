# Cheat Sheet SQL Assessment DBA

> Query rapide per assessment iniziale di un database Oracle: servizio/PDB, dimensione allocata, trend crescita e sizing utile per migrazioni, GoldenGate, RMAN e capacity planning.

---

## 1. Identificare PDB da SERVICE_NAME

Utile quando hai una stringa di connessione o un alias TNS e devi capire quale PDB sta servendo.

```sql
SELECT pdb AS pluggable_database,
       name AS service_name,
       network_name
FROM   cdb_services
WHERE  UPPER(name) LIKE UPPER('%&SERVICE_NAME%');
```

Vista completa servizi/PDB:

```sql
SELECT pdb AS pluggable_database,
       name AS service_name,
       network_name
FROM   cdb_services
ORDER  BY pdb, name;
```

---

## 2. Dimensione database allocata

```sql
SELECT
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM dba_data_files), 2) AS datafiles_gb,
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM dba_temp_files), 2) AS tempfiles_gb,
    ROUND((SELECT SUM(bytes)/1024/1024/1024 FROM v$log), 2) AS redo_logs_gb,
    ROUND(
        (SELECT SUM(bytes)/1024/1024/1024 FROM dba_data_files) +
        (SELECT SUM(bytes)/1024/1024/1024 FROM dba_temp_files) +
        (SELECT SUM(bytes)/1024/1024/1024 FROM v$log)
    , 2) AS total_allocated_gb
FROM dual;
```

Uso pratico:

- stima spazio export/import;
- stima spazio target;
- capacity planning;
- dimensionamento backup e restore;
- assessment migrazione.

---

## 3. Trend crescita tablespace da AWR

Richiede AWR/licenza Diagnostics Pack dove applicabile.

```sql
WITH snap_sizes AS (
    SELECT
        s.snap_id,
        TO_CHAR(s.begin_interval_time, 'YYYY-MM') AS mese,
        SUM(h.tablespace_size * t.block_size) AS allocato_bytes,
        SUM(h.tablespace_usedsize * t.block_size) AS usato_bytes
    FROM dba_hist_tbspc_space_usage h
    JOIN dba_hist_snapshot s ON h.snap_id = s.snap_id
    JOIN v$tablespace vt ON h.tablespace_id = vt.ts#
    JOIN dba_tablespaces t ON vt.name = t.tablespace_name
    WHERE s.begin_interval_time >= ADD_MONTHS(SYSDATE, -12)
    GROUP BY s.snap_id, TO_CHAR(s.begin_interval_time, 'YYYY-MM')
)
SELECT
    mese,
    ROUND(MAX(allocato_bytes) / 1024/1024/1024, 2) AS max_allocato_gb,
    ROUND(MAX(usato_bytes) / 1024/1024/1024, 2) AS max_usato_gb,
    ROUND(
      ROUND(MAX(usato_bytes) / 1024/1024/1024, 2) -
      LAG(ROUND(MAX(usato_bytes) / 1024/1024/1024, 2)) OVER (ORDER BY mese)
    , 2) AS delta_usato_vs_mese_prec_gb
FROM snap_sizes
GROUP BY mese
ORDER BY mese;
```

Uso pratico:

- stimare crescita mensile;
- prevedere saturazione storage;
- dimensionare target cloud;
- impostare soglie Enterprise Manager;
- stimare FRA, backup e finestre manutenzione.

---

## 4. Redo rate per GoldenGate/RMAN/Data Guard

```sql
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS ora,
       ROUND(SUM(blocks * block_size)/1024/1024/1024,2) redo_gb
FROM   v$archived_log
WHERE  first_time > SYSDATE - 7
GROUP  BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER  BY ora;
```

Regola pratica:

```text
FRA minima per outage = redo_picco_ora * ore_outage * 1.5
Trail GoldenGate minimo = change_volume_picco * ore_outage_target * 1.5
```

---

## 5. Checklist assessment rapido

- [ ] PDB/service identificato.
- [ ] Dimensione allocata e usata raccolta.
- [ ] Trend crescita ultimi 12 mesi raccolto.
- [ ] Redo rate medio e picco calcolati.
- [ ] FRA e backup retention verificati.
- [ ] Oggetti senza PK identificati se serve GoldenGate.
- [ ] Tablespace/temp/redo dimensionati sul target.
- [ ] Vincoli licensing AWR/Diagnostics Pack rispettati.
