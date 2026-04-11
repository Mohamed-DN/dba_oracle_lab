# 04 — Lock e Sessioni Bloccate

> ⏱️ Tempo: 5-15 minuti | 📅 Frequenza: Su incidente | 👤 Chi: DBA on-call
> **Scenario tipico**: "L'applicazione è bloccata! Gli utenti non riescono a lavorare!"

---

## Step 1: Identifica il Problema (30 secondi)

```sql
sqlplus / as sysdba

-- Ci sono sessioni in attesa di lock?
SELECT COUNT(*) AS blocked_sessions
FROM gv$session
WHERE blocking_session IS NOT NULL;

-- Se 0 → il problema NON è un lock, vai a procedura 05 o 07
```

## Step 2: Chi Blocca Chi? (la query d'oro)

```sql
-- Catena completa dei blocchi in RAC
SELECT
    -- BLOCKER
    s1.inst_id                        AS blk_inst,
    s1.sid                            AS blk_sid,
    s1.serial#                        AS blk_serial,
    s1.username                       AS blk_user,
    s1.program                        AS blk_program,
    s1.sql_id                         AS blk_sql_id,
    s1.event                          AS blk_event,
    s1.last_call_et                   AS blk_seconds,
    s1.status                         AS blk_status,
    -- WAITER
    s2.inst_id                        AS wait_inst,
    s2.sid                            AS wait_sid,
    s2.username                       AS wait_user,
    s2.event                          AS wait_event,
    s2.seconds_in_wait                AS wait_seconds
FROM gv$session s1
JOIN gv$session s2
    ON s1.sid = s2.blocking_session
   AND s1.inst_id = s2.blocking_instance
WHERE s2.blocking_session IS NOT NULL
ORDER BY s1.inst_id, s1.sid;
```

> **Leggi così**: La sessione `blk_sid` su istanza `blk_inst` sta BLOCCANDO la sessione `wait_sid`.
> Se `blk_status = INACTIVE` → l'utente ha fatto una modifica e NON ha fatto COMMIT.

## Step 3: Dettaglio del Blocker

```sql
-- Cosa sta facendo il blocker? (SQL in corso o ultimo eseguito)
SELECT s.sid, s.serial#, s.username, s.program,
       s.status, s.event, s.last_call_et,
       sq.sql_text
FROM gv$session s
LEFT JOIN gv$sql sq ON s.sql_id = sq.sql_id AND s.inst_id = sq.inst_id
WHERE s.sid = &blocker_sid
  AND s.inst_id = &blocker_inst;
```

```sql
-- Quali oggetti sono lockati?
SELECT lo.inst_id, lo.session_id AS sid,
       lo.oracle_username, do.owner, do.object_name, do.object_type,
       DECODE(lo.locked_mode,
           0,'None', 1,'Null', 2,'Row-S',
           3,'Row-X', 4,'Share', 5,'S/Row-X', 6,'Exclusive') AS lock_mode
FROM gv$locked_object lo
JOIN dba_objects do ON lo.object_id = do.object_id
WHERE lo.session_id = &blocker_sid;
```

## Step 4: Decidere l'Azione

### Opzione A: Contatta l'Utente
Se conosci l'utente blocante (es. da `program` o `username`):
- Chiedigli di fare **COMMIT** o **ROLLBACK**
- È la soluzione migliore perché preserva i dati

### Opzione B: Kill della Sessione

```sql
-- ⚠️ ATTENZIONE: la transazione del blocker verrà rollbackata!
-- Verifica prima con il team applicativo

-- Kill (singola istanza)
ALTER SYSTEM KILL SESSION '&sid,&serial#' IMMEDIATE;

-- Kill (RAC — specifica istanza)
ALTER SYSTEM KILL SESSION '&sid,&serial#,@&inst_id' IMMEDIATE;
```

```sql
-- Se il KILL non funziona (sessione "marked for kill"):
-- Trova il PID del processo OS
SELECT p.spid AS os_pid, s.sid, s.serial#
FROM gv$session s
JOIN gv$process p ON s.paddr = p.addr AND s.inst_id = p.inst_id
WHERE s.sid = &sid AND s.inst_id = &inst_id;
```

```bash
# Kill a livello OS (ultimo resort!)
# ⚠️ SOLO dopo aver verificato il PID!
kill -9 <os_pid>
```

## Step 5: Verifica Post-Kill

```sql
-- Controlla che il lock sia rilasciato
SELECT COUNT(*) AS still_blocked
FROM gv$session
WHERE blocking_session IS NOT NULL;

-- Verifica che la sessione bloccante non sia più presente
SELECT sid, serial#, status FROM gv$session WHERE sid = &old_blocker_sid;
```

---

## 📝 Template di Documentazione

```
DATA: ___________
TICKET: ___________
BLOCKER: SID=___ SERIAL=___ INST=___ USER=___________
WAITER(S): SID=___ USER=___________
OGGETTO LOCKATO: ___________
AZIONE: [ ] Contattato utente  [ ] Kill sessione
ESITO: [ ] Risolto  [ ] Escalato
DURATA BLOCCO: ___ minuti
```

---

## ✅ Check di Conferma

| Controllo | Atteso |
|---|---|
| Sessioni bloccate | 0 |
| Lock residui | Nessuno |
| Applicazione | Funzionante |
