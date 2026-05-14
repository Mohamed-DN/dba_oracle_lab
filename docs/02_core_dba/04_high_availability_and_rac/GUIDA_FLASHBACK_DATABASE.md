# Guida Flashback Database — Oracle 19c RAC

> Il Flashback Database è la "macchina del tempo" di Oracle: riporta l'INTERO database a un punto nel passato in pochi minuti, senza bisogno di restore da backup. È il tool più potente per annullare errori logici gravi.

---

## 1. Teoria: Cos'è il Flashback Database

### 1.1 Il Problema che Risolve

```
SCENARIO: Alle 10:00 un DBA junior esegue per errore:
  DELETE FROM HR.EMPLOYEES;   -- senza WHERE!
  COMMIT;
  -- 500.000 righe cancellate. Panico.

SOLUZIONI POSSIBILI:
  1. RMAN PITR → Restore da backup + apply archivelog fino alle 09:59
     Tempo: 2-4 ore (restore + recover + open resetlogs)
     Rischio: PERDI tutte le modifiche dopo le 09:59 in TUTTE le tabelle

  2. Flashback Table → FLASHBACK TABLE HR.EMPLOYEES TO TIMESTAMP ...
     Tempo: minuti
     Rischio: Funziona SOLO se la tabella non è stata droppata con PURGE
     e se UNDO è ancora disponibile

  3. Flashback Database → FLASHBACK DATABASE TO TIMESTAMP ...
     Tempo: 5-15 minuti (dipende dal volume di cambiamenti)
     Rischio: Riporta TUTTO il database indietro. Poi puoi estrarre
     i dati persi e fare OPEN RESETLOGS.
     È il compromesso migliore: veloce come un flashback,
     completo come un restore.
```

### 1.2 Come Funziona Internamente

```
  FLASHBACK DATABASE usa i "Flashback Logs"
  ═══════════════════════════════════════════

  Quando Flashback Database è attivo, Oracle salva copie dei blocchi
  PRIMA che vengano modificati in file speciali chiamati "Flashback Logs".
  Questi file risiedono nella Fast Recovery Area (FRA).

  ┌──────────────────────────────────────────────────────────┐
  │ Datafile (SYSTEM01.DBF, USERS01.DBF, ecc.)               │
  │                                                           │
  │  Prima di modificare un blocco:                           │
  │  ┌────────┐                    ┌──────────────────────┐   │
  │  │Blocco  │──"copia prima"────►│ Flashback Log        │   │
  │  │vecchio │                    │ (nella FRA)           │   │
  │  └───┬────┘                    │ fb_log_1.flb         │   │
  │      │                         │ fb_log_2.flb         │   │
  │      ▼                         │ ...                   │   │
  │  ┌────────┐                    └──────────────────────┘   │
  │  │Blocco  │                                               │
  │  │nuovo   │  (la modifica viene scritta nel datafile)      │
  │  │(DML)   │                                               │
  │  └────────┘                                               │
  └──────────────────────────────────────────────────────────┘

  Quando fai FLASHBACK DATABASE TO TIMESTAMP X:
  1. Oracle trova tutti i blocchi modificati DOPO il timestamp X
  2. Li sovrascrive con le copie "prima" salvate nei Flashback Logs
  3. Poi applica gli archivelog per essere consistente al punto X
  4. Il database è tornato indietro nel tempo!
```

### 1.3 Flashback Database vs Altre Tecnologie

| Tecnologia | Cosa riporta indietro | Velocità | Prerequisito |
|-----------|----------------------|----------|-------------|
| Flashback Query | Una singola query (`AS OF TIMESTAMP`) | Istantanea | UNDO retention |
| Flashback Table | Una singola tabella | Minuti | UNDO retention + ROW MOVEMENT |
| Flashback Drop | Tabella nel Recyclebin | Istantanea | Recyclebin ON |
| Flashback Database | L'INTERO database | 5-15 min | Flashback Logs (FRA) |
| RMAN PITR | L'INTERO database | 1-4 ore | Backup + Archivelog |

---

## 2. Attivazione del Flashback Database

### 2.1 Prerequisiti

```sql
-- Su rac1 come oracle
sqlplus / as sysdba

-- 1. Verificare che il database sia in ARCHIVELOG mode (obbligatorio)
SELECT log_mode FROM v$database;
-- Deve essere: ARCHIVELOG
-- Se non lo è, NON puoi attivare Flashback Database.

-- 2. Verificare che la FRA sia configurata (obbligatorio)
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;
-- Deve mostrare un path (es. +FRA) e una dimensione.
```

### 2.2 Attivazione

```sql
-- 1. Imposta la retention del Flashback Database
--    Questo dice a Oracle: "mantieni i flashback logs per almeno X minuti"
ALTER SYSTEM SET db_flashback_retention_target=1440 SCOPE=BOTH SID='*';
-- ^^^ 1440 minuti = 24 ore
--     Oracle manterrà i flashback logs per le ultime 24 ore.
--     Puoi fare FLASHBACK DATABASE fino a 24 ore fa (massimo).
--     Valori tipici:
--       Lab: 1440 (24 ore)
--       Produzione: 2880-4320 (2-3 giorni)
--     ⚠️ Più ore = più spazio FRA consumato!

-- 2. Attiva il Flashback Database
ALTER DATABASE FLASHBACK ON;
-- ^^^ Da questo momento, Oracle inizia a scrivere Flashback Logs.
--     Il processo RVWR (Recovery Writer) scrive i blocchi "prima"
--     nella FRA.
--     ⚠️ In RAC: questo comando va eseguito su UN SOLO nodo.
--     L'effetto è cluster-wide (condiviso su ASM).

-- 3. Verifica
SELECT flashback_on FROM v$database;
-- Output: YES

-- 4. Verifica lo spazio usato dai Flashback Logs
SELECT * FROM v$flashback_database_log;
-- Mostra: oldest_flashback_scn, oldest_flashback_time,
--         retention_target, flashback_size, estimated_flashback_size
```

---

## 3. Test Pratico: Flashback Database dopo un Errore

### 3.1 Preparazione

```sql
sqlplus / as sysdba

-- 1. Crea dati di test
CREATE TABLE HR.DATI_IMPORTANTI (
    id NUMBER PRIMARY KEY,
    nome VARCHAR2(100),
    valore NUMBER(15,2)
);

INSERT INTO HR.DATI_IMPORTANTI VALUES (1, 'Contratto Alpha', 150000.00);
INSERT INTO HR.DATI_IMPORTANTI VALUES (2, 'Contratto Beta', 280000.50);
INSERT INTO HR.DATI_IMPORTANTI VALUES (3, 'Contratto Gamma', 999999.99);
COMMIT;

-- 2. Crea un RESTORE POINT (punto di ripristino con nome)
CREATE RESTORE POINT PRIMA_DEL_DISASTRO GUARANTEE FLASHBACK DATABASE;
-- ^^^ Un RESTORE POINT è un "segnalibro" nel tempo.
--     GUARANTEE FLASHBACK DATABASE: Oracle garantisce che i flashback
--     logs per questo punto NON verranno mai cancellati automaticamente.
--     Devi cancellarlo tu con DROP RESTORE POINT quando non serve più.

-- 3. Verifica
SELECT name, scn, time, guarantee_flashback_database
FROM v$restore_point;
```

### 3.2 Simula il Disastro

```sql
-- ERRORE INTENZIONALE: cancella tutti i dati!
DELETE FROM HR.DATI_IMPORTANTI;
COMMIT;
-- 💀 Tutti i contratti sono spariti!

-- Verifica: la tabella è vuota
SELECT COUNT(*) FROM HR.DATI_IMPORTANTI;
-- 0 righe
```

### 3.3 Flashback Database

```sql
-- 1. Chiudi il database
SHUTDOWN IMMEDIATE;
-- ^^^ Il Flashback Database richiede che il DB sia in MOUNT,
--     non in OPEN. Questo è l'unico downtime.

-- 2. Monta il database
STARTUP MOUNT;

-- 3. Esegui il Flashback!
FLASHBACK DATABASE TO RESTORE POINT PRIMA_DEL_DISASTRO;
-- ^^^ Oracle:
--     a) Legge i Flashback Logs e sovrascrive i blocchi con le versioni "prima"
--     b) Applica gli archivelog fino al punto specificato
--     c) Il database è ora nello stato di PRIMA del DELETE
--     Tempo: tipicamente 2-10 minuti (dipende dal volume di cambiamenti)

-- 4. Apri il database con RESETLOGS
ALTER DATABASE OPEN RESETLOGS;
-- ^^^ RESETLOGS: crea una nuova "incarnazione" del database.
--     I redo logs ripartono da sequence 1.
--     Questo è necessario perché abbiamo cambiato la timeline del database.

-- 5. Verifica i dati!
SELECT * FROM HR.DATI_IMPORTANTI;
-- 🎉 I 3 contratti sono tornati! Alpha, Beta, Gamma!

-- 6. Pulizia
DROP RESTORE POINT PRIMA_DEL_DISASTRO;
```

---

## 4. Flashback Database con Data Guard

### 4.1 Il Caso d'Uso Più Importante: Reinstate dopo Failover

```
SCENARIO: Il Primary (RACDB) crasha irrimediabilmente.
Fai FAILOVER verso lo standby (RACDB_STBY diventa Primary).
PROBLEMA: il vecchio Primary (RACDB) non può più essere standby
          perché è "divergente" — ha una timeline diversa.

SENZA Flashback Database:
  → Devi RICOSTRUIRE lo standby da zero con RMAN DUPLICATE
  → Tempo: ore (dipende dalla dimensione del database)

CON Flashback Database:
  → Fai FLASHBACK DATABASE sul vecchio Primary al punto di divergenza
  → Poi lo converti in nuovo standby
  → Tempo: minuti!
```

### 4.2 Procedura di Reinstate

```sql
-- 1. Sul vecchio Primary (RACDB, dopo il failover, è crashato)
--    Avvialo in mount mode
STARTUP MOUNT;

-- 2. Flashback al punto di divergenza
--    (DGMGRL conosce automaticamente l'SCN di divergenza)
FLASHBACK DATABASE TO SCN <divergence_SCN>;
-- ^^^ L'SCN di divergenza si trova con:
--     SELECT standby_became_primary_scn FROM v$database; (sullo standby)

-- 3. Converti in standby fisico
ALTER DATABASE CONVERT TO PHYSICAL STANDBY;

-- 4. Riavvia
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;

-- 5. Registra nel Broker
-- Il Broker vedrà automaticamente il reinstate e riprenderà la sincronizzazione
```

Oppure, più semplicemente con DGMGRL:

```bash
dgmgrl sys/<password>@RACDB_STBY
REINSTATE DATABASE RACDB;
-- ^^^ Il Broker fa tutto automaticamente:
--     flashback, conversione a standby, avvio apply.
--     Richiede che Flashback Database sia ON su entrambi.
```

---

## 5. Best Practice Oracle MAA

> [!IMPORTANT]
> **Oracle raccomanda di attivare Flashback Database su TUTTI i database di un ambiente Data Guard (sia Primary che Standby).** Questo permette reinstate rapidi dopo switchover e failover.

- **Retention target**: almeno 60 minuti in produzione (1440 consigliato)
- **FRA sizing**: prevedi il 10-15% extra per i Flashback Logs
- **Restore Points garantiti**: usali prima di manutenzioni rischiose (patching, upgrade)
- **Monitoring**: controlla `v$flashback_database_stat` per le performance

```sql
-- Query di monitoraggio Flashback
SELECT
    begin_time,
    end_time,
    flashback_data,
    db_data,
    redo_data,
    ROUND(estimated_flashback_size/1024/1024) AS est_fb_mb
FROM v$flashback_database_stat
ORDER BY begin_time DESC
FETCH FIRST 10 ROWS ONLY;
```

---

## 6. Fonti Oracle Ufficiali

- Flashback Database Concepts: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/using-flasback-database-restore-points.html
- Flashback Database in Data Guard: https://docs.oracle.com/en/database/oracle/oracle-database/19/sbydb/using-flashback-database-after-failover.html
- Restore Points: https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/using-flasback-database-restore-points.html#GUID-4B93A6F4-4D4A-4BBB-B52D-73DF7E12F1CD
