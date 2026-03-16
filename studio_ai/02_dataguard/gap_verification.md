# Check GAP Data Guard

> **Purpose**: Check if there are gaps between the primary and the standby (archivelogs not yet received or not yet applied).

---

## Verification Query

```sql
--1. Check GAP (run on STANDBY)
SELECT * FROM v$archive_gap;

--If it returns rows, there are gaps to fix!

--2. Last log applied on STANDBY
SELECT THREAD#, MAX(SEQUENCE#) "LAST_APPLIED" 
FROM v$archived_log 
WHERE APPLIED = 'YES' 
GROUP BY THREAD#;

--3. Last log generated on PRIMARY
SELECT THREAD#, MAX(SEQUENCE#) "LAST_GENERATED" 
FROM v$archived_log 
GROUP BY THREAD#;

--4. Direct comparison (run on PRIMARY for a global view)
SELECT a.thread#, 
       a.last_seq "LAST_GENERATED",
       b.last_seq "LAST_RECEIVED",
       a.last_seq - b.last_seq "GAP"
FROM (SELECT thread#, MAX(sequence#) last_seq FROM v$archived_log GROUP BY thread#) a,
     (SELECT thread#, MAX(sequence#) last_seq FROM v$archived_log WHERE dest_id = 2 GROUP BY thread#) b
WHERE a.thread# = b.thread#;

--5. State of transport
SELECT dest_id, status, error, gap_status 
FROM v$archive_dest_status 
WHERE dest_id IN (1,2);

--6. Data Guard Broker Verification (easier)
-- Da shell:
-- dgmgrl sys/<password>
-- DGMGRL> show configuration;
-- DGMGRL> show database verbose 'NOME_STANDBY';
```

> [!NOTE]
> A GAP of 1-2 sequences is normal in ASYNC mode. An increasing GAP indicates a network or standby space problem.
