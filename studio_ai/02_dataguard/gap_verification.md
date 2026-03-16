# Check GAP Data Guard

> **Purpose**: Check if there are gaps between the primary and the standby (archivelogs not yet received or not yet applied).

---

## Verification Query

```sql
-- 1. Verifica GAP (eseguire sullo STANDBY)
SELECT * FROM v$archive_gap;

-- Se restituisce righe, ci sono gap da risolvere!

-- 2. Ultimo log applicato sullo STANDBY
SELECT THREAD#, MAX(SEQUENCE#) "LAST_APPLIED" 
FROM v$archived_log 
WHERE APPLIED = 'YES' 
GROUP BY THREAD#;

-- 3. Ultimo log generato sul PRIMARY
SELECT THREAD#, MAX(SEQUENCE#) "LAST_GENERATED" 
FROM v$archived_log 
GROUP BY THREAD#;

-- 4. Confronto diretto (eseguire sul PRIMARY per una vista globale)
SELECT a.thread#, 
       a.last_seq "LAST_GENERATED",
       b.last_seq "LAST_RECEIVED",
       a.last_seq - b.last_seq "GAP"
FROM (SELECT thread#, MAX(sequence#) last_seq FROM v$archived_log GROUP BY thread#) a,
     (SELECT thread#, MAX(sequence#) last_seq FROM v$archived_log WHERE dest_id = 2 GROUP BY thread#) b
WHERE a.thread# = b.thread#;

-- 5. Stato dei trasporti
SELECT dest_id, status, error, gap_status 
FROM v$archive_dest_status 
WHERE dest_id IN (1,2);

-- 6. Verifica del Data Guard Broker (più semplice)
-- Da shell:
-- dgmgrl sys/<password>
-- DGMGRL> show configuration;
-- DGMGRL> show database verbose 'NOME_STANDBY';
```

> [!NOTE]
> A GAP of 1-2 sequences is normal in ASYNC mode. An increasing GAP indicates a network or standby space problem.
