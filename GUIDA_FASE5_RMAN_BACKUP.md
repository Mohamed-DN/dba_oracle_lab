# FASE 5: Strategia RMAN Backup su Tutti i Database

> Il backup è la tua ultima linea di difesa. Non importa quanto siano sofisticate le tue soluzioni di HA (RAC, Data Guard, GoldenGate): se un errore umano cancella una tabella, solo un backup RMAN può salvarti.

### Cos'è RMAN?

RMAN (Recovery Manager) è lo strumento nativo di Oracle per effettuare backup e ripristini del database. Non è un semplice "copia file": RMAN parla direttamente con il kernel del database, conosce quali blocchi sono usati, quali sono cambiati, e può comprimere, validare e ripristinare intelligentemente.

**Perché NON usare `cp` o `tar` per backuppare un database Oracle?** Perché mentre copi i file, il database continua a scrivere. I file copiati sarebbero internamente inconsistenti (blocchi scritti a metà). RMAN invece coordina tutto con il database per garantire consistenza.

### Concetti fondamentali RMAN

| Termine | Significato | Analogia |
|---------|------------|----------|
| **Backupset** | Formato proprietario RMAN che contiene solo i blocchi usati (non quelli vuoti). È più compatto di una copia file. | Come un file ZIP che salta le pagine bianche |
| **Image Copy** | Copia identica 1:1 del datafile. Più grande ma il restore è istantaneo (basta uno `switch`). | Come un clone esatto del disco |
| **Level 0** | Backup FULL: copia TUTTI i blocchi usati nel database. È la "base" da cui partono gli incrementali. | La foto completa dell'album |
| **Level 1** | Backup INCREMENTALE: copia SOLO i blocchi cambiati dal Level 0 (o dal Level 1 precedente). Velocissimo con BCT. | Solo le foto nuove aggiunte dopo l'ultima volta |
| **Level 1 Cumulative** | Copia TUTTI i blocchi cambiati dal Level 0 (non dal Level 1 precedente). Il restore è più veloce perché ti basta il Level 0 + l'ultimo Cumulative. | Tutte le foto nuove dalla foto completa, non dall'ultimo aggiornamento |
| **Archivelog** | Copia dei redo log "archiviati" (già pieni). Servono per il Point-In-Time Recovery. | Il diario giornaliero delle modifiche |
| **FRA** | Fast Recovery Area: disco ASM (+FRA o +RECO) dove Oracle salva backup, archivelog, flashback log. | Il magazzino dei backup |
| **Retention Policy** | Regola che dice ad RMAN quanto a lungo tenere i backup. Quelli fuori finestra diventano "obsoleti" e possono essere cancellati. | La data di scadenza dei backup |
| **Channel** | Un "lavoratore" RMAN. Ogni channel legge/scrive in parallelo. 2 channel = 2 letture contemporanee = backup 2x più veloce. | Una corsia autostradale: più corsie = più traffico contemporaneo |
| **Tag** | Un'etichetta leggibile che appiccichiamo al backup (es. `FULL_WEEKLY`). Serve per trovarlo poi facilmente con `LIST BACKUP`. | Il post-it sul backup |
| **Crosscheck** | RMAN verifica che i file di backup esistano ancora fisicamente sul disco. Se qualcuno li ha cancellati dal sistema operativo, RMAN li marca come EXPIRED. | Inventario del magazzino |

---

## 5.0 Ingresso da Fase 4 (gate operativo)

Prima di impostare la strategia RMAN, il sistema deve essere stabile. Se il Data Guard non funziona, i backup sullo standby falliranno. Se la FRA è piena, RMAN non ha dove scrivere e il database si blocca.

```bash
# Data Guard — verifica che la configurazione sia operativa
# Questo comando si connette al Broker tramite il TNS alias "RACDB"
# e chiede lo stato globale della configurazione.
# DEVI vedere "SUCCESS" — se vedi WARNING o ERROR, torna alla Fase 4.
dgmgrl sys/<password>@RACDB "show configuration;"
```

```sql
-- Spazio FRA (Fast Recovery Area) — eseguilo sia sul primario che sullo standby
-- La FRA è il disco condiviso ASM dove vengono salvati:
--   - i backup RMAN
--   - gli archivelog (copie dei redo log pieni)
--   - i flashback log (se usi Flashback Database)
-- Se la FRA raggiunge il 100%, il database si FERMA perché non può più archiviare.
-- La query sotto ti mostra quanto spazio hai e quanto ne stai usando.
sqlplus / as sysdba
SELECT name,
       ROUND(space_limit/1024/1024/1024, 2) AS limit_gb,
       ROUND(space_used/1024/1024/1024, 2)  AS used_gb,
       ROUND(space_used/space_limit*100, 1)  AS pct_used
FROM v$recovery_file_dest;
```

Check minimi prima di procedere:

- DGMGRL mostra `SUCCESS`
- FRA usata meno dell'80% (se è sopra, i backup futuri falliranno)

Se hai già creato gli script RMAN in test precedenti, non ricrearli: validali e aggiorna solo retention/schedule.

---

## 5.1 La Strategia di Backup

### Backup su TUTTI e 3 i Database

```
                         ┌──────────────────────┐
                         │   RAC PRIMARY         │
                         │   (RACDB)             │
                         │   → Archivelog backup │───→ 🗄️ +FRA
                         │   → Level 1 leggero   │     (ogni 2h + giornaliero)
                         └──────────┬─────────────┘
                                    │ Redo Shipping
                                    ▼
                         ┌──────────────────────┐
                         │   RAC STANDBY (ADG)   │
                         │   (RACDB_STBY)        │
                         │   → BACKUP PRINCIPALE │───→ 🗄️ +FRA
                         │   Level 0 + Level 1   │     (full + incr + arch)
                         └──────────┬─────────────┘
                                    │ GoldenGate
                                    ▼
                         ┌──────────────────────┐
                         │   TARGET DB           │
                         │   (dbtarget)          │
                         │   → Backup separato   │───→ 🗄️ Disco locale
                         └──────────────────────┘
```

> **Perché il backup PRINCIPALE sullo standby?** Il backup Level 0 (full) è un'operazione estremamente pesante: RMAN deve leggere fisicamente OGNI blocco del database (su un DB da 50 GB, legge tutti i 50 GB dal disco). Questo genera un carico enorme di I/O e CPU. Sullo standby, queste risorse non servono ai client perché nessun utente ci lavora sopra (a meno di Active Data Guard). Ecco perché il consiglio MAA è: **fai i backup pesanti sullo standby**, così il primario resta libero di servire le applicazioni.
>
> Il backup fatto sullo standby è **identico** a quello fatto sul primario perché il database standby è una copia fisica bit-per-bit del primario (grazie al Redo Apply di Data Guard).
>
> **Perché backup ANCHE sul primario?** Per sicurezza aggiuntiva. Immagina questo scenario:
> - Lo standby è in manutenzione (spento per patching)
> - Un DBA cancella per sbaglio 10 tabelle sul primario
> - Senza backup dal primario, hai perso dati!
>
> Un Level 1 leggero sul primario (che grazie al BCT dura pochi minuti) + il backup degli archivelog ogni 2 ore ti garantiscono un RPO (Recovery Point Objective — cioè quanti dati puoi perdere al massimo) di sole 2 ore.

---

### ⚠️ Regola d'Oro RAC: Su quale nodo eseguire i comandi?

In un cluster RAC a 2 nodi, questa è la domanda più frequente. Ecco la regola definitiva:

| Operazione | Dove eseguirla | Perché |
|------------|---------------|--------|
| `CONFIGURE ...` RMAN | **1 solo nodo** (qualsiasi) | Le impostazioni RMAN vengono salvate nel **Control File**, che è condiviso in ASM. Entrambi i nodi lo leggono automaticamente. |
| `ALTER SYSTEM SET ... SID='*'` | **1 solo nodo** (qualsiasi) | Con `SID='*'` il parametro viene scritto nello **SPFILE condiviso** e si propaga a tutte le istanze al prossimo riavvio (o subito con `SCOPE=BOTH`). |
| `ALTER DATABASE ENABLE BCT` | **1 solo nodo** (qualsiasi) | Il file BCT viene creato su ASM (disco condiviso). Entrambe le istanze lo usano. |
| Script backup (`rman_full_backup.sh`) | **1 solo nodo** (il nodo 1 del cluster) | RMAN si connette al database tramite l'istanza locale, ma il backup è del database intero (tutti i datafile condivisi). Non serve farlo su 2 nodi! |
| Crontab backup | **1 solo nodo** (il nodo 1 del cluster) | Se metti il cron su entrambi i nodi, avrai 2 backup identici che partono alla stessa ora — spreco di risorse e possibili conflitti. |
| Script di creazione (`cat > /home/oracle/scripts/...`) | **1 solo nodo** (gli script stanno nel filesystem locale) | Il filesystem `/home/oracle` è **locale** a ogni nodo. Se vuoi gli script anche sul nodo 2 (come fallback), copiali con `scp`. |
| Health check SQL con `GV$` | **1 solo nodo** (qualsiasi) | Le viste `GV$` (Global V$) mostrano i dati di **tutte le istanze** del cluster da un unico punto. |
| Health check SQL con `V$` | Mostra **solo il nodo locale** | Se usi `V$` senza la G, vedi solo l'istanza su cui sei connesso. |

> **In pratica:** Per tutta la Fase 5, lavori quasi esclusivamente su **un solo nodo**:
> - `rac1` per il cluster primario
> - `racstby1` per il cluster standby
>
> Non devi mai SSH-are sul nodo 2 per replicare i comandi RMAN o i CONFIGURE.

---

## 5.2 Configurazione RMAN Base (Valida per tutti i DB)

### Connessione RMAN

RMAN è un programma a linea di comando separato da SQL*Plus. Quando scrivi `rman TARGET /`, stai dicendo ad RMAN:
- **TARGET**: il database su cui vuoi operare
- **`/`**: usa l'autenticazione OS (come quando fai `sqlplus / as sysdba`)

Devi essere loggato come utente `oracle` ed avere le variabili d'ambiente (`ORACLE_HOME`, `ORACLE_SID`) impostate correttamente.

```bash
# Connessione al database locale come SYSDBA.
# RMAN usa internamente una connessione privilegiata SYSDBA.
# Non serve specificare utente/password se sei l'utente OS "oracle".
rman TARGET /

# Se vuoi connetterti a un database remoto via TNS:
rman TARGET sys/oracle@RACDB
```

### Configurazione Iniziale (esegui su ogni DB)

> **🟢 RAC: esegui i CONFIGURE su UN SOLO nodo per cluster.** I comandi CONFIGURE vengono salvati nel Control File, che è condiviso tra tutti i nodi via ASM. Se fai `CONFIGURE RETENTION POLICY...` su `rac1`, anche `rac2` lo vedrà automaticamente.

I comandi `CONFIGURE` di RMAN impostano parametri **persistenti** che vengono salvati nel Control File del database. Una volta configurati, restano attivi per tutti i backup futuri senza doverli ripetere.

```rman
-- ============================================================
-- MOSTRA CONFIGURAZIONE ATTUALE
-- ============================================================
-- Mostra TUTTI i parametri RMAN salvati nel control file.
-- Se non hai mai configurato nulla, vedrai i valori di default.
-- Ogni riga mostrerà sia il valore corrente che il default.
SHOW ALL;

-- ============================================================
-- RETENTION POLICY: per quanti giorni tenere i backup
-- ============================================================
-- Dice ad RMAN: "Devi sempre avere abbastanza backup per poter
-- ripristinare il database a qualsiasi punto negli ultimi 7 giorni."
-- I backup più vecchi di questo vengono marcati come "obsoleti"
-- e possono essere cancellati con DELETE OBSOLETE.
--
-- ATTENZIONE: questo NON cancella automaticamente i vecchi backup!
-- Li marca solo come "obsoleti". Devi usare DELETE OBSOLETE per cancellarli.
--
-- Alternativa: CONFIGURE RETENTION POLICY TO REDUNDANCY 2;
--   → Tiene sempre almeno 2 copie di backup complete.
--   La RECOVERY WINDOW è preferita perché è basata sul tempo, non sul conteggio.
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;

-- ============================================================
-- CONTROLFILE AUTOBACKUP: rete di sicurezza automatica
-- ============================================================
-- Dopo OGNI comando di backup, RMAN crea automaticamente una copia
-- del Control File e dello SPFILE. Perché è cruciale?
-- Il Control File contiene la MAPPA di tutti i backup: senza di esso,
-- RMAN non sa dove sono i backup precedenti!
-- Se perdi il Control File E non hai un autobackup, devi ricostruire
-- tutto a mano (operazione lunghissima e rischiosa).
--
-- Il formato '%F' genera un nome univoco basato su DBID e timestamp.
-- Esempio: c-1225375887-20260406-00 (c-DBID-DATA-SEQUENZA)
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '+FRA/%F';

-- ============================================================
-- PARALLELISMO E COMPRESSIONE
-- ============================================================
-- PARALLELISM 2: usa 2 canali (processi) simultanei per leggere/scrivere.
--   Con 4 CPU disponibili, 2 canali è un buon compromesso:
--   abbastanza veloce senza saturare la macchina.
-- COMPRESSED BACKUPSET: applica compressione a ogni backup.
--   Un backup da 50 GB compresso diventa ~15-20 GB (risparmi 60-70% di spazio).
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COMPRESSED BACKUPSET;

-- ============================================================
-- ALGORITMO DI COMPRESSIONE
-- ============================================================
-- Oracle offre 4 livelli di compressione:
--   BASIC  → lenta, buona compressione (gratis, inclusa in tutte le edizioni)
--   LOW    → velocissima, poca compressione (richiede ACO - Advanced Compression Option)
--   MEDIUM → bilanciata (richiede ACO)
--   HIGH   → lentissima, massima compressione (richiede ACO)
-- In laboratorio usiamo MEDIUM. In produzione senza licenza ACO, usa BASIC.
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';

-- ============================================================
-- FORMATO FILE DI BACKUP
-- ============================================================
-- Dove RMAN salverà fisicamente i file di backup.
-- '+FRA/RACDB/%U' significa:
--   +FRA    → disco ASM della Fast Recovery Area
--   RACDB   → sottodirectory per questo database
--   %U      → nome univoco generato automaticamente
--             (esempio: 0a2s3k4l_1_1)
-- Su ASM, Oracle gestisce automaticamente i file: non devi
-- preoccuparti di path, permessi o spazio su singoli dischi.
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+FRA/RACDB/%U';

-- ============================================================
-- BACKUP OPTIMIZATION
-- ============================================================
-- Se un datafile non è cambiato rispetto all'ultimo backup,
-- RMAN lo SALTA completamente. Questo è utilissimo per i tablespace
-- read-only o per i datafile che contengono dati storici non modificati.
-- Esempio pratico: hai un tablespace STORICO di 30 GB che non cambia mai.
-- Senza optimization: ogni full backup copia 30 GB inutilmente.
-- Con optimization: RMAN lo salta, risparmiando 30 GB e 10 minuti di tempo.
CONFIGURE BACKUP OPTIMIZATION ON;
```

> **Riepilogo di cosa hai appena configurato:**
> | Parametro | Valore | Effetto pratico |
> |-----------|--------|----------------|
> | Retention | 7 giorni | Puoi ripristinare il DB a qualsiasi punto della settimana scorsa |
> | Autobackup | ON | Se perdi il control file, RMAN può ritrovare i backup |
> | Parallelismo | 2 canali | Backup ~2x più veloce rispetto a 1 canale |
> | Compressione | MEDIUM | Backup ~3x più piccoli |
> | Formato | +FRA/RACDB/%U | Tutto salvato su ASM, gestione automatica |
> | Optimization | ON | Salta file non modificati = backup più veloce |

---

## 5.3 Block Change Tracking (BCT) — Accelera gli Incrementali

### Cos'è il BCT e perché è indispensabile?

Per capire il BCT, devi prima capire come funziona un backup incrementale SENZA BCT:

1. RMAN apre il datafile (es. `system01.dbf`, che contiene 500.000 blocchi)
2. Per OGNI blocco, legge l'header del blocco per trovare il suo SCN (System Change Number)
3. Se lo SCN è più recente dell'ultimo backup, il blocco viene copiato
4. Se lo SCN è più vecchio, il blocco viene saltato

**Problema**: anche per "saltare" un blocco, RMAN deve comunque LEGGERLO dal disco per controllarne l'SCN. Su un database da 100 GB, RMAN legge comunque tutti i 100 GB anche se solo 2 GB sono cambiati. Questo richiede ~30 minuti di I/O puro.

**Con il BCT attivo**, Oracle mantiene un file speciale (il "change tracking file") che funziona come un **diario delle modifiche**. Ogni volta che DBWn scrive un blocco sporco su disco, Oracle segna nel file BCT: "il blocco 12345 del datafile 3 è cambiato". Quando RMAN parte per l'incrementale:

1. RMAN legge il file BCT (pochi MB)
2. Il file BCT gli dice: "sono cambiati i blocchi 12345, 67890, 11111 del datafile 3"
3. RMAN va a leggere SOLO quei 3 blocchi, ignora tutti gli altri
4. Risultato: backup di 2 GB letti in 2 minuti invece di 100 GB in 30 minuti

### Attivazione BCT

> **🟢 RAC: esegui su UN SOLO nodo.** Il file BCT è creato su ASM (disco condiviso) e viene usato automaticamente da entrambe le istanze.

Sul Primario (RACDB) — come `oracle` su `rac1`:

```sql
sqlplus / as sysdba

-- Crea il file di change tracking su ASM.
-- Il file è piccolo (circa 1/30000 della dimensione del database).
-- Per un DB da 50 GB, il file BCT sarà circa 1.7 MB.
-- DEVE stare su disco condiviso in RAC perché entrambe le istanze
-- devono poter scrivere le modifiche.
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/RACDB/bct_racdb.dbf';

-- Verifica che sia attivo e vedi la dimensione del file
SELECT filename, status, ROUND(bytes/1024/1024, 2) AS size_mb
FROM v$block_change_tracking;
-- Output atteso: status = ENABLED, size_mb = ~1-5 MB
```

Sullo Standby (RACDB_STBY) — **FORTEMENTE CONSIGLIATO** dato che è da qui che facciamo i backup pesanti:

```sql
sqlplus / as sysdba

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+DATA/RACDB_STBY/bct_racdb_stby.dbf';
```

Sul Target (dbtarget) — se lo hai configurato:

```sql
sqlplus / as sysdba

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '/u01/app/oracle/oradata/dbtarget/bct_dbtarget.dbf';
```

> **Confronto pratico BCT ON vs OFF (database 50 GB, 2 GB modificati al giorno):**
>
> | Metrica | Senza BCT | Con BCT |
> |---------|-----------|--------|
> | Dati letti | 50 GB (tutto il DB) | 2 GB (solo modificati) |
> | Tempo incrementale | ~25 minuti | ~2 minuti |
> | I/O sul disco | Altissimo (satura ASM) | Minimo |
> | Impatto sulle prestazioni | Significativo | Quasi nullo |

---

## 5.4 Script di Backup — RAC Standby (Backup Principale)

> **🟢 RAC: esegui tutto su UN SOLO nodo (`racstby1`).** Gli script vengono creati nel filesystem locale di `racstby1`. RMAN si connette all'istanza locale ma backuppa il database completo (tutti i datafile condivisi su ASM). Non serve ripetere nulla su `racstby2`.
>
> Se vuoi una copia degli script anche su `racstby2` per sicurezza (es. se `racstby1` va giù), copia con: `scp /home/oracle/scripts/*.sh oracle@racstby2:/home/oracle/scripts/`

Questo è il backup **più importante** della tua infrastruttura. Viene eseguito sullo standby perché:
- Non impatta le prestazioni del primario (dove lavorano gli utenti)
- Il database standby è una copia fisica identica, quindi il backup è valido per entrambi
- In caso di disaster recovery, puoi usare questi backup per ricostruire da zero

### Backup Level 0 (Full) — Domenica

```bash
cat > /home/oracle/scripts/rman_full_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_full_backup.sh — Backup Full (Level 0) dallo Standby
# Eseguire SOLO sullo Standby (RACDB_STBY)
#
# COSA FA QUESTO SCRIPT:
# 1. Si connette ad RMAN come SYSDBA
# 2. Apre 2 canali paralleli verso il disco
# 3. Copia TUTTI i blocchi del database (Level 0 = base completa)
# 4. Backuppa gli archivelog e li cancella per liberare spazio
# 5. Crea copie di sicurezza del Control File e dello SPFILE
# 6. Cancella i backup obsoleti (> 7 giorni) e quelli corrotti

source /home/oracle/.db_env
# ^^^ carica le variabili: ORACLE_HOME, ORACLE_SID, LD_LIBRARY_PATH
# Senza questo, RMAN non trova il binario e non si connette al DB.

export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"
# ^^^ formato data leggibile nei log RMAN (altrimenti mostra formato interno Oracle)

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_full_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR
# ^^^ crea la cartella dei log se non esiste, e genera un nome file
#     univoco basato su data e ora (es: rman_full_20260406_020000.log)

rman TARGET / LOG=$LOG_FILE <<EOF
# ^^^ rman TARGET / = connessione locale al database come SYSDBA
# ^^^ LOG=$LOG_FILE = RMAN scrive tutto l'output anche nel file di log
# ^^^ <<EOF = heredoc bash: tutto il contenuto fino a EOF viene passato come input

RUN {
    # RUN { } = blocco transazionale RMAN.
    # Tutti i comandi dentro RUN vengono eseguiti come un'unità.
    # Se uno fallisce, gli altri si fermano.

    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;
    # ^^^ Apre 2 "lavoratori" paralleli.
    #     ch1 leggerà i datafile dispari, ch2 quelli pari (più o meno).
    #     Risultato: backup ~2x più veloce rispetto a 1 solo canale.
    #     Con ALLOCATE esplicito dentro RUN, hai più controllo
    #     rispetto al CONFIGURE DEVICE TYPE DISK PARALLELISM.

    -- Backup Full Database (Level 0)
    BACKUP AS COMPRESSED BACKUPSET
    -- ^^^ AS COMPRESSED BACKUPSET: crea un file proprietario RMAN
    --     contenente solo i blocchi usati, compressi con l'algoritmo MEDIUM.
    --     Un DB da 50 GB diventa ~15-20 GB nel backup.
        INCREMENTAL LEVEL 0
    -- ^^^ LEVEL 0 = copia TUTTI i blocchi usati nel database.
    --     Questo è il "punto zero" per gli incrementali della settimana.
    --     DEVE girare almeno una volta prima di poter fare Level 1.
        DATABASE
    -- ^^^ Backuppa TUTTO il database: tutti i tablespace, tutti i datafile,
    --     inclusi SYSTEM, SYSAUX, UNDO, TEMP, e tutti i PDB.
        TAG 'FULL_WEEKLY'
    -- ^^^ TAG = etichetta leggibile. Quando fai LIST BACKUP, vedrai
    --     questa etichetta e saprai subito che backup è.
        PLUS ARCHIVELOG
    -- ^^^ Backuppa anche gli archivelog PRIMA e DOPO il backup del database.
    --     Perché prima E dopo? Perché durante il backup, il database
    --     continua a generare redo. RMAN deve catturare anche i redo
    --     generati durante il backup stesso per garantire consistenza.
            TAG 'ARCH_WITH_FULL'
            DELETE INPUT;
    -- ^^^ DELETE INPUT: dopo aver backuppato gli archivelog, CANCELLALI
    --     dal disco. Questo è FONDAMENTALE per liberare spazio nella FRA.
    --     Senza questo, la FRA si riempie e il database si ferma.

    -- Backup del Controlfile e SPFILE
    BACKUP CURRENT CONTROLFILE TAG 'CTL_WEEKLY';
    -- ^^^ Il Control File è la "mappa" del database: contiene l'elenco
    --     di TUTTI i datafile, i redo log, e la storia di tutti i backup.
    --     Perderlo = dover ricostruire tutto a mano.
    BACKUP SPFILE TAG 'SPFILE_WEEKLY';
    -- ^^^ Lo SPFILE contiene TUTTI i parametri del database.
    --     Senza di esso, dovresti ricordarti a memoria ogni singolo parametro.

    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
    -- ^^^ Chiude i canali allocati. Libera le risorse.
}

-- Rimuovi i backup obsoleti secondo la retention policy
DELETE NOPROMPT OBSOLETE;
-- ^^^ Oracle controlla tutti i backup registrati nel control file.
--     Quelli che cadono fuori dalla finestra di 7 giorni vengono cancellati.
--     NOPROMPT = non chiedere conferma (necessario in script automatici).

-- Crosscheck per rimuovere riferimenti a backup cancellati manualmente
CROSSCHECK BACKUP;
-- ^^^ RMAN va a verificare fisicamente che ogni file di backup esista sul disco.
--     Se qualcuno ha cancellato un file da ASM o dal filesystem a mano,
--     RMAN lo marca come EXPIRED ("non disponibile").
CROSSCHECK ARCHIVELOG ALL;
-- ^^^ Stessa cosa ma per gli archivelog.

DELETE NOPROMPT EXPIRED BACKUP;
-- ^^^ Cancella dal catalogo RMAN i riferimenti a backup che non esistono più.
DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
-- ^^^ Idem per archivelog fantasma.
EOF

# Controlla se RMAN ha avuto errori
if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    # ^^^ Cerca la stringa "RMAN-" nel log (indica un errore RMAN).
    #     grep -v "RMAN-08138" esclude il messaggio informativo
    #     "channel %s not allocated" che è innocuo.
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
    # Qui puoi aggiungere una notifica email
else
    echo "Backup Full completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_full_backup.sh
```

> **Riepilogo del flusso Level 0:**
> 1. RMAN si connette al database standby
> 2. Apre 2 canali paralleli (due processi che leggono contemporaneamente)
> 3. Legge OGNI blocco di OGNI datafile (ecco perché è lento: legge tutto!)
> 4. Comprime i blocchi e li scrive nel backupset su +FRA
> 5. Backuppa anche gli archivelog e li cancella dalla FRA
> 6. Fa pulizia: cancella backup vecchi e verifica che tutto sia integro

### Backup Level 1 (Incrementale) — Tutti i giorni

```bash
cat > /home/oracle/scripts/rman_incr_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_incr_backup.sh — Backup Incrementale (Level 1) dallo Standby

source /home/oracle/.db_env
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_incr_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;

    -- Backup Incrementale Level 1
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1
        DATABASE
        TAG 'INCR_DAILY'
        PLUS ARCHIVELOG
            TAG 'ARCH_WITH_INCR'
            DELETE INPUT;

    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}

-- Pulizia
DELETE NOPROMPT OBSOLETE;
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;
EOF

if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
else
    echo "Backup Incrementale completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_incr_backup.sh
```

> **Perché Level 1 e non Level 0 ogni giorno?** Un Level 0 copia TUTTI i blocchi. Un Level 1 copia SOLO i blocchi cambiati dal Level 0 (o dal Level 1 precedente). Su un DB da 50 GB dove ogni giorno cambiano 2 GB di dati, il Level 1 è 25x più veloce e usa 25x meno spazio.

### Backup Archivelog — Ogni 2 ore

```bash
cat > /home/oracle/scripts/rman_arch_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_arch_backup.sh — Backup Archivelog

source /home/oracle/.db_env

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_arch_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    TAG 'ARCH_HOURLY'
    DELETE INPUT;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_arch_backup.sh
```

> **Perché ogni 2 ore?** Gli archivelog si accumulano nella FRA. Se non li backuppi e cancelli regolarmente, la FRA si riempie e il database si ferma (non può più scrivere redo). `NOT BACKED UP 1 TIMES` assicura che vengano backuppati almeno una volta prima di essere cancellati.

---

## 5.5 Script di Backup — Target (dbtarget)

Il target GoldenGate ha una strategia più semplice perché può sempre essere ricreato ricarcando i dati dal primario.

```bash
cat > /home/oracle/scripts/rman_target_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_target_backup.sh — Backup per il DB Target GoldenGate

source /home/oracle/.db_env

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_target_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 3 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u01/backup/dbtarget/%F';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/u01/backup/dbtarget/%U';

RUN {
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1 CUMULATIVE
        DATABASE
        TAG 'TARGET_DAILY'
        PLUS ARCHIVELOG
            TAG 'TARGET_ARCH'
            DELETE INPUT;

    BACKUP CURRENT CONTROLFILE TAG 'TARGET_CTL';
}

DELETE NOPROMPT OBSOLETE;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_target_backup.sh
```

> **Perché `CUMULATIVE`?** Un Level 1 Cumulative include TUTTE le modifiche dal Level 0, non solo quelle dal Level 1 precedente. Il restore è più veloce perché servono solo il Level 0 + l'ultimo Level 1 Cumulative (non tutti i Level 1 intermedi).

```bash
# Crea la directory di backup sul Target
mkdir -p /u01/backup/dbtarget
chown oracle:oinstall /u01/backup/dbtarget
```

---

## 5.5b Script di Backup — RAC PRIMARIO (RACDB)

> **🟢 RAC: esegui tutto su UN SOLO nodo (`rac1`).** Stessa logica dello standby: gli script e il cron vanno configurati solo su `rac1`. Non ripetere su `rac2`.

Anche il primario ha il suo backup — leggero ma essenziale come rete di sicurezza.

```bash
cat > /home/oracle/scripts/rman_primary_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_primary_backup.sh — Backup dal Primario
# Level 1 incrementale + archivelog
# PIÙ LEGGERO di quello sullo standby

source /home/oracle/.db_env
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_primary_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;

    -- Solo Level 1 (NON Level 0 full per non sovraccaricare)
    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 1
        DATABASE
        TAG 'PRIMARY_INCR_DAILY'
        PLUS ARCHIVELOG
            TAG 'PRIMARY_ARCH'
            DELETE INPUT;

    -- Backup Controlfile + SPFILE
    BACKUP CURRENT CONTROLFILE TAG 'PRIMARY_CTL';
    BACKUP SPFILE TAG 'PRIMARY_SPFILE';

    RELEASE CHANNEL ch1;
}

DELETE NOPROMPT OBSOLETE;
EOF

if grep -i "RMAN-" $LOG_FILE | grep -v "RMAN-08138" > /dev/null; then
    echo "ERRORE RMAN rilevato! Controlla il log: $LOG_FILE"
else
    echo "Backup Primario completato con successo."
fi
SCRIPT

chmod +x /home/oracle/scripts/rman_primary_backup.sh
```

> **Perché solo Level 1 sul primario?** Il Level 0 (full) è pesante e lo fa già lo standby la domenica. Il primario fa solo il Level 1, che è leggero e veloce grazie al BCT. Se lo standby crasha, hai comunque un backup recente dal primario.

### 5.5c Backup Archivelog sul Primario (Sicurezza Extra)
Questo script è fondamentale per liberare spazio nella FRA del primario ogni 2 ore.

```bash
cat > /home/oracle/scripts/rman_arch_backup.sh <<'SCRIPT'
#!/bin/bash
# rman_arch_backup.sh — Backup Archivelog (Primario)
source /home/oracle/.db_env

LOG_DIR=/home/oracle/scripts/logs
LOG_FILE=$LOG_DIR/rman_arch_$(date +%Y%m%d_%H%M%S).log
mkdir -p $LOG_DIR

rman TARGET / LOG=$LOG_FILE <<EOF
BACKUP AS COMPRESSED BACKUPSET
    ARCHIVELOG ALL NOT BACKED UP 1 TIMES
    TAG 'PRIMARY_ARCH_HOURLY'
    DELETE INPUT;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_arch_backup.sh
```

---

## 5.6 Schedulazione con Cron

Il **cron** è lo scheduler di Linux: esegue comandi/script automaticamente a orari prefissati. Ogni utente ha il suo crontab (tabella dei job). Noi lo usiamo per automatizzare completamente i backup senza intervento umano.

> **🟢 RAC: configura il crontab su UN SOLO nodo per cluster.**
> - Primario: crontab solo su `rac1` (NON su `rac2`)
> - Standby: crontab solo su `racstby1` (NON su `racstby2`)
> - Target: crontab su `dbtarget`
>
> Se metti il cron su entrambi i nodi dello stesso cluster, partiranno DUE backup identici alla stessa ora. Questo causa conflitti di lock RMAN e doppio consumo di spazio e I/O. **Non farlo mai.**

### Sintassi Cron (mini guida)

```
Minuto  Ora  Giorno  Mese  GiornoSettimana  Comando
  0      2    *       *         0            /script.sh
  |      |    |       |         |
  |      |    |       |         +-- 0=Domenica, 1=Lunedì, ..., 6=Sabato
  |      |    |       +------------ 1-12 (mese dell'anno)
  |      |    +-------------------- 1-31 (giorno del mese)
  |      +------------------------- 0-23 (ora)
  +-------------------------------- 0-59 (minuto)
  *  = ogni valore possibile
  */2 = ogni 2 (es. ore 0, 2, 4, 6, ...)
  1-6 = da 1 a 6
```

```bash
# Apri l'editor cron come utente oracle (su OGNI macchina)
crontab -e
```

### Sul Primario (rac1):

```cron
# === BACKUP INCREMENTALE GIORNALIERO ===
# Ogni giorno alle 04:00 (sfalsato dallo standby che gira alle 02:00)
# Perché alle 04:00? Per non sovrapporre I/O con il backup dello standby.
# Lo script rman_primary_backup.sh fa un Level 1 + archivelog + controlfile.
0 4 * * * /home/oracle/scripts/rman_primary_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# === BACKUP ARCHIVELOG OGNI 2 ORE ===
# Svuota gli archivelog accumulati nella FRA del primario.
# Perché ogni 2 ore? Il primario genera continuamente redo log.
# Senza questo job, la FRA si riempie e il DB si blocca.
# Il >> appende al log (non lo sovrascrive).
# Il 2>&1 redirige anche gli errori stderr nello stesso file.
0 */2 * * * /home/oracle/scripts/rman_arch_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

### Sullo Standby (racstby1):

```cron
# === BACKUP FULL SETTIMANALE (DOMENICA) ===
# Il backup più pesante: Level 0 = copia tutto il database.
# Gira di domenica alle 02:00 di notte quando nessuno lavora.
# Questo è il "punto zero" per tutti gli incrementali della settimana.
0 2 * * 0 /home/oracle/scripts/rman_full_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# === BACKUP INCREMENTALE (LUN-SAB) ===
# Dal lunedì al sabato alle 02:00: copia SOLO i blocchi cambiati
# rispetto al backup precedente (Level 1 differenziale).
# Grazie al BCT, questo backup dura pochi minuti.
0 2 * * 1-6 /home/oracle/scripts/rman_incr_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1

# === BACKUP ARCHIVELOG OGNI 2 ORE ===
# Anche sullo standby si accumulano archivelog (ricevuti dal primario).
# Li backuppiamo e cancelliamo ogni 2 ore per tenere la FRA pulita.
0 */2 * * * /home/oracle/scripts/rman_arch_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

### Sul Target (dbtarget):

```cron
# Backup Daily — Ogni giorno alle 03:00
0 3 * * * /home/oracle/scripts/rman_target_backup.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

---

## 5.7 Verifica dei Backup

Dopo aver eseguito i backup, è fondamentale verificare che siano validi. Un backup corrotto è peggio di nessun backup: ti dà un falso senso di sicurezza.

> **🟢 RAC: puoi eseguire tutti i comandi di verifica da UN SOLO nodo qualsiasi.** RMAN legge le informazioni dal Control File condiviso, quindi da `rac1` o `rac2` vedi gli stessi identici risultati.

### Comandi di verifica (con spiegazione dettagliata)

```rman
-- Connettiti ad RMAN
rman TARGET /

-- ============================================================
-- LIST BACKUP SUMMARY
-- ============================================================
-- Mostra un riepilogo di TUTTI i backup registrati nel control file.
-- Colonne importanti nell'output:
--   Key  = numero identificativo del backup
--   TY   = tipo: B=Backupset, P=Proxy (nastro)
--   LV   = livello: F=Full/Level0, 1=Level1, A=Archivelog
--   S    = status: A=Available, X=Expired, U=Unavailable
--   Compressed = YES/NO (se hai usato compressione)
--   Tag  = l'etichetta che gli hai dato
--
-- COSA GUARDARE: tutti i backup devono avere S=A (Available).
-- Se vedi S=X (Expired), quel backup non esiste piu' fisicamente.
LIST BACKUP SUMMARY;

-- ============================================================
-- LIST BACKUP OF DATABASE COMPLETED AFTER 'SYSDATE-1'
-- ============================================================
-- Mostra SOLO i backup del database completati nelle ultime 24 ore.
-- Se questo non restituisce risultati, significa che:
--   1. Non hai ancora eseguito nessun backup (normale se stai iniziando)
--   2. Il cron notturno non ha girato
--   3. Il backup ha fallito
-- SYSDATE-1 = ieri. Puoi cambiare il numero: SYSDATE-7 = ultimi 7 giorni.
LIST BACKUP OF DATABASE COMPLETED AFTER 'SYSDATE-1';

-- ============================================================
-- LIST BACKUP OF ARCHIVELOG ALL
-- ============================================================
-- Mostra tutti i backup degli archivelog mai fatti.
-- Se non restituisce nulla, NON hai mai backuppato gli archivelog.
-- Questo e' PERICOLOSO: la FRA si riempira' e il DB si fermera'.
LIST BACKUP OF ARCHIVELOG ALL;

-- ============================================================
-- BACKUP VALIDATE DATABASE
-- ============================================================
-- ATTENZIONE: il comando corretto e' BACKUP VALIDATE, NON "VALIDATE BACKUP"!
-- Questo comando simula un backup completo: legge OGNI blocco di OGNI 
-- datafile e ne verifica l'integrita' (checksum), ma NON crea
-- fisicamente il file di backup. E' perfetto per un test non distruttivo.
-- Se trova blocchi corrotti, li segnala con il messaggio:
--   "block corruption found" + numero datafile + numero blocco.
BACKUP VALIDATE DATABASE;

-- ============================================================
-- REPORT NEED BACKUP
-- ============================================================
-- Mostra quali datafile NON soddisfano la retention policy.
-- La colonna "Days" indica quanti giorni sono passati dall'ultimo
-- backup valido di quel file. Se vedi numeri enormi (es. 2546),
-- significa che quel file non e' mai stato backuppato correttamente.
-- In pratica: tutti i file che appaiono in questa lista DEVONO
-- essere backuppati urgentemente con almeno un Level 0.
REPORT NEED BACKUP;

-- ============================================================
-- REPORT UNRECOVERABLE DATABASE
-- ============================================================
-- Mostra i datafile che contengono operazioni NOLOGGING
-- (es. INSERT /*+ APPEND */ senza FORCE LOGGING).
-- Questi blocchi non possono essere recuperati dagli archivelog
-- perche' il redo non e' stato generato.
-- Se questo report e' vuoto = tutto OK, sei al sicuro.
-- Se mostra dei file = devi fare un backup FULL di quei file.
REPORT UNRECOVERABLE DATABASE;
```

> [!WARNING]
> **Il comando `VALIDATE BACKUP;` (senza la parola DATABASE) NON esiste in RMAN!**
> Se lo provi, riceverai l'errore: `RMAN-01009: syntax error: found ";": expecting one of: "controlfile"`.
> Il comando corretto è: `BACKUP VALIDATE DATABASE;` (legge tutto ma NON scrive nulla).

### Come leggere l'output di LIST BACKUP SUMMARY

```
Key     TY LV S Device Type Completion Time      #Pieces #Copies Compressed Tag
------- -- -- - ----------- -------------------- ------- ------- ---------- ---
1       B  F  A DISK        13-MAR-2026 04:38:26 1       1       NO         TAG20260313T043826
```

| Colonna | Valore | Significato |
|---------|--------|-------------|
| Key | 1 | Numero identificativo del backup (sequenziale) |
| TY | B | Tipo: **B**ackupset (formato proprietario RMAN) |
| LV | F | Livello: **F**ull (Level 0 o backup non incrementale) |
| S | A | Status: **A**vailable (il file esiste ed è utilizzabile) |
| #Pieces | 1 | Numero di file generati da questo backup |
| Compressed | NO | Il backup NON è compresso (spreco di spazio!) |
| Tag | TAG2026... | Etichetta auto-generata (non personalizzata) |

### Script di Report Automatico

```bash
cat > /home/oracle/scripts/rman_report.sh <<'SCRIPT'
#!/bin/bash
source /home/oracle/.db_env

echo "=== RMAN BACKUP REPORT === $(date)"
echo ""

rman TARGET / <<EOF
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
CROSSCHECK BACKUP;
EOF
SCRIPT

chmod +x /home/oracle/scripts/rman_report.sh
```

---

## 5.8 Test Pratici di Backup e Recovery (FONDAMENTALE!)

> **Un backup mai testato è un backup che non esiste.** In produzione, i DBA che non testano i restore regolarmente vengono licenziati dopo il primo disastro. Testa SEMPRE.

> **🟢 RAC: tutti i test si eseguono da UN SOLO nodo (`rac1`).** Il database è uno solo condiviso su ASM: che tu sia su `rac1` o `rac2` non fa differenza.

### Passo 0: Esecuzione Immediata del Backup (senza aspettare il cron)

Prima di testare il ripristino, devi avere un backup fresco. Lancia gli script a mano:

```bash
# === Sul PRIMARIO (rac1) come utente oracle ===

# 1. Lancia subito la configurazione RMAN base (se non l'hai ancora fatta)
rman TARGET / <<EOF
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '+FRA/%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 2 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE COMPRESSION ALGORITHM 'MEDIUM';
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '+FRA/RACDB/%U';
CONFIGURE BACKUP OPTIMIZATION ON;
EOF
# ^^^ Questi 7 comandi vengono salvati nel Control File.
#     Eseguili una volta sola, restano permanenti.

# 2. Lancia un backup FULL Level 0 immediato
#    (è la BASE da cui partono tutti gli incrementali futuri)
rman TARGET / <<EOF
RUN {
    ALLOCATE CHANNEL ch1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL ch2 DEVICE TYPE DISK;

    BACKUP AS COMPRESSED BACKUPSET
        INCREMENTAL LEVEL 0
        DATABASE
        TAG 'MANUAL_FULL_TEST'
        PLUS ARCHIVELOG
            TAG 'MANUAL_ARCH_TEST'
            DELETE INPUT;

    BACKUP CURRENT CONTROLFILE TAG 'MANUAL_CTL';
    BACKUP SPFILE TAG 'MANUAL_SPFILE';

    RELEASE CHANNEL ch1;
    RELEASE CHANNEL ch2;
}
EOF
# ^^^ Questo backup richiede 10-30 minuti a seconda della dimensione del DB.
#     Alla fine vedrai: "backup set complete, elapsed time: ..."

# 3. Verifica che il backup sia stato registrato
rman TARGET / <<EOF
LIST BACKUP SUMMARY;
REPORT NEED BACKUP;
EOF
# ^^^ Ora dovresti vedere il tuo backup con Tag=MANUAL_FULL_TEST
#     e REPORT NEED BACKUP dovrebbe mostrare ZERO file (tutti backuppati).
```

> **Output atteso dopo il backup:**
> ```
> Key     TY LV S Device Type Completion Time      #Pieces #Copies Compressed Tag
> ------- -- -- - ----------- -------------------- ------- ------- ---------- ---
> 3       B  0  A DISK        07-APR-2026 06:45:02 2       1       YES        MANUAL_FULL_TEST
> 4       B  A  A DISK        07-APR-2026 06:45:15 1       1       YES        MANUAL_ARCH_TEST
> 5       B  F  A DISK        07-APR-2026 06:45:20 1       1       YES        MANUAL_CTL
> ```
> Nota che ora `LV=0` (Level 0), `Compressed=YES`, e il tag è il tuo.

---

### Test 1: Verifica Non-Distruttiva (il backup è leggibile?)

Questi comandi NON modificano il database. Verificano solo che i backup siano integri e utilizzabili.

```rman
rman TARGET /

-- ============================================================
-- RESTORE DATABASE PREVIEW
-- ============================================================
-- Fa una "prova a secco": RMAN controlla se ha tutti i pezzi
-- necessari per un restore completo (datafile + archivelog),
-- ma NON LI COPIA FISICAMENTE. È come chiedere:
-- "Se dovessi ricostruire il database da zero, avrei tutto?"
-- Se vedi "media recovery... would be applied" = tutto OK.
-- Se vedi "no backup of datafile X found" = PROBLEMA!
RESTORE DATABASE PREVIEW;

-- ============================================================
-- RESTORE DATABASE VALIDATE
-- ============================================================
-- Un passo più in profondità: RMAN legge fisicamente OGNI blocco
-- dai file di backup e verifica l'integrità dei checksum,
-- ma NON SCRIVE nulla su disco. È il test più affidabile
-- per verificare che i backup non siano corrotti.
-- Se va tutto bene, vedrai: "Finished restore at ..."
-- Se c'è un blocco corrotto, vedrai: "block corruption found"
RESTORE DATABASE VALIDATE;
```

---

### Test 2: Recupero di una Tabella Droppata (Flashback Drop)

Questo è lo scenario più comune: qualcuno ha fatto `DROP TABLE` per errore. Oracle ha una funzionalità chiamata **Recyclebin** (Cestino) che rende il recupero istantaneo senza nemmeno bisogno di RMAN.

```sql
-- === Sul PRIMARIO (rac1) come oracle ===
sqlplus / as sysdba

-- 1. Verifica che il Recyclebin sia attivo (dovrebbe esserlo di default)
SHOW PARAMETER recyclebin;
-- Output atteso: recyclebin = on

-- 2. Crea una tabella di test con dati
CREATE TABLE HR.TEST_BACKUP (
    id    NUMBER PRIMARY KEY,
    nome  VARCHAR2(50),
    data_ins DATE DEFAULT SYSDATE
);

INSERT INTO HR.TEST_BACKUP VALUES (1, 'Mario Rossi', SYSDATE);
INSERT INTO HR.TEST_BACKUP VALUES (2, 'Luigi Bianchi', SYSDATE);
INSERT INTO HR.TEST_BACKUP VALUES (3, 'Anna Verdi', SYSDATE);
COMMIT;

-- 3. Verifica che i dati ci siano
SELECT * FROM HR.TEST_BACKUP;
-- Deve mostrare 3 righe

-- 4. Annota l'SCN corrente (ci servirà dopo per il test PITR)
SELECT CURRENT_SCN FROM V$DATABASE;
-- Esempio output: 2847593 (segnatelo!)

-- 5. DROP della tabella (simula errore umano!)
DROP TABLE HR.TEST_BACKUP;

-- 6. Verifica che sia sparita
SELECT * FROM HR.TEST_BACKUP;
-- Errore: ORA-00942: table or view does not exist

-- 7. Guarda nel Recyclebin (il cestino di Oracle)
SELECT object_name, original_name, type, droptime
FROM dba_recyclebin
WHERE original_name = 'TEST_BACKUP';
-- Dovresti vedere la tabella con il suo nome "cestinato"
-- (tipo BIN$aBcDeFgHiJ...)

-- 8. RECUPERA LA TABELLA DAL CESTINO!
FLASHBACK TABLE HR.TEST_BACKUP TO BEFORE DROP;

-- 9. Verifica che i dati siano tornati
SELECT * FROM HR.TEST_BACKUP;
-- 🎉 Le 3 righe sono tornate senza bisogno di RMAN!
```

> **Quando il Flashback Drop NON funziona:**
> - Se hai fatto `DROP TABLE ... PURGE` (bypass del cestino)
> - Se il tablespace ha avuto bisogno di spazio e il Recyclebin è stato svuotato automaticamente
> - Se hai eseguito `PURGE RECYCLEBIN` manualmente
>
> In questi casi, devi usare RMAN con Point-in-Time Recovery (Test 3).

---

### Test 3: Point-In-Time Recovery di una Tabella con RMAN (PITR)

Questo è il test più realistico: la tabella è stata droppata con `PURGE`, il cestino è vuoto. L'unica salvezza è RMAN. Usiamo la funzionalità **RMAN Table Point-in-Time Recovery** (disponibile da Oracle 12c).

```sql
-- === Sul PRIMARIO (rac1) come oracle ===
sqlplus / as sysdba

-- 1. Crea una nuova tabella di test
CREATE TABLE HR.TEST_PITR (
    id    NUMBER PRIMARY KEY,
    nome  VARCHAR2(50),
    valore NUMBER(10,2)
);

INSERT INTO HR.TEST_PITR VALUES (1, 'Transazione Alpha', 1500.00);
INSERT INTO HR.TEST_PITR VALUES (2, 'Transazione Beta',  2700.50);
INSERT INTO HR.TEST_PITR VALUES (3, 'Transazione Gamma', 9999.99);
COMMIT;

-- 2. SEGNA L'ORARIO PRECISO (sarà il punto di recupero!)
SELECT TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') AS "TIMESTAMP_PRIMA_DEL_DROP"
FROM DUAL;
-- ^^^ Esempio output: 07-APR-2026 06:50:30
-- COPIATI QUESTO TIMESTAMP! È il momento in cui la tabella esisteva ancora.

-- 3. Aspetta qualche secondo, poi DROPPA CON PURGE (nessun cestino!)
DROP TABLE HR.TEST_PITR PURGE;

-- 4. Verifica: sparita davvero?
SELECT * FROM HR.TEST_PITR;
-- ORA-00942: table or view does not exist

-- 5. Verifica: il cestino è vuoto?
SELECT * FROM dba_recyclebin WHERE original_name = 'TEST_PITR';
-- no rows selected — non c'è salvezza nel cestino
```

Ora usa RMAN per recuperare la tabella viaggiando indietro nel tempo:

```bash
# === Sempre su rac1 come oracle ===

# RMAN RECOVER TABLE: recupera una tabella specifica a un punto nel tempo.
# Oracle internamente:
#   a) Crea un database ausiliario temporaneo (in /tmp o in +FRA)
#   b) Fa un restore del database a quel punto nel tempo nel DB ausiliario
#   c) Usa Data Pump per esportare SOLO la tabella dal DB ausiliario
#   d) Importa la tabella nel database di produzione
#   e) Cancella il database ausiliario

# SOSTITUISCI il timestamp con quello che hai annotato al passo 2!
rman TARGET /

RECOVER TABLE HR.TEST_PITR
    UNTIL TIME "TO_DATE('07-APR-2026 06:50:30','DD-MON-YYYY HH24:MI:SS')"
    AUXILIARY DESTINATION '/tmp/rman_pitr_aux'
    REMAP TABLE HR.TEST_PITR:HR.TEST_PITR_RECOVERED;
```

> **Spiegazione del comando:**
> - `RECOVER TABLE HR.TEST_PITR`: recupera questa specifica tabella
> - `UNTIL TIME "..."`: torna indietro al momento PRIMA del DROP
> - `AUXILIARY DESTINATION '/tmp/rman_pitr_aux'`: dove creare il DB temporaneo (serve ~2x lo spazio del tablespace)
> - `REMAP TABLE ... :HR.TEST_PITR_RECOVERED`: rinomina la tabella recuperata (per sicurezza, non sovrascrive l'originale se esistesse ancora)

```sql
-- 6. Verifica il recupero!
sqlplus / as sysdba

SELECT * FROM HR.TEST_PITR_RECOVERED;
-- 🎉 Le 3 righe sono tornate! Transazione Alpha, Beta, Gamma.

-- 7. Se sei soddisfatto, rinominala
ALTER TABLE HR.TEST_PITR_RECOVERED RENAME TO TEST_PITR;

-- 8. Pulizia: cancella la directory ausiliaria temporanea
-- (fallo dal terminale Linux)
```

```bash
rm -rf /tmp/rman_pitr_aux
```

> [!WARNING]
> **RECOVER TABLE richiede:**
> - Un backup FULL (Level 0) recente come base
> - Gli archivelog continui dal backup fino al timestamp di recovery
> - Spazio sufficiente nella AUXILIARY DESTINATION (~dimensione tablespace)
> - Che il database sia in ARCHIVELOG mode (che noi abbiamo attivato in Fase 3)
>
> Se non hai un backup o gli archivelog sono stati cancellati, il recovery è IMPOSSIBILE.

---

### Test 4: Recupero di un Datafile Perso (Scenario Critico)

Questo simula la perdita fisica di un datafile (disco guasto, cancellazione accidentale). **Test da fare con ESTREMA CAUTELA** — consigliato farlo prima sullo standby o su un DB di test.

```sql
-- === Preparazione: identifica un datafile NON critico ===
sqlplus / as sysdba

-- Elenca tutti i datafile con il loro tablespace
SELECT file#, name, status, ROUND(bytes/1024/1024) AS size_mb
FROM v$datafile
ORDER BY file#;
-- Cerca il file del tablespace USERS (è il meno critico).
-- Esempio: file# = 7, name = +DATA/RACDB/DATAFILE/users.260.1227759055

-- Crea un tablespace di TEST dedicato (così non rischi i dati veri)
CREATE TABLESPACE TEST_RECOVERY
    DATAFILE '+DATA' SIZE 50M
    AUTOEXTEND ON NEXT 10M MAXSIZE 200M;

-- Crea una tabella nel tablespace di test
CREATE TABLE HR.TEST_DATAFILE (
    id NUMBER, testo VARCHAR2(100)
) TABLESPACE TEST_RECOVERY;
INSERT INTO HR.TEST_DATAFILE SELECT LEVEL, 'Riga '||LEVEL FROM DUAL CONNECT BY LEVEL <= 1000;
COMMIT;

-- Segna quale file è stato creato
SELECT file#, name FROM v$datafile WHERE name LIKE '%TEST_RECOVERY%';
-- Esempio output: file# = 10, +DATA/RACDB/DATAFILE/test_recovery.289...
-- SEGNA IL NUMERO DEL FILE (es. 10)
```

```sql
-- === SIMULA LA PERDITA DEL FILE ===

-- 1. Metti il datafile offline (simula disco guasto)
ALTER DATABASE DATAFILE 10 OFFLINE;
-- ^^^ Sostituisci 10 con il tuo file#

-- 2. Ora prova ad accedere alla tabella
SELECT * FROM HR.TEST_DATAFILE;
-- ORA-00376: file 10 cannot be read at this time
-- Il database funziona ancora! Solo il tablespace TEST_RECOVERY è giù.
```

```bash
# === RECUPERO CON RMAN ===
rman TARGET /

# RMAN RESTORE + RECOVER: ripristina il datafile dal backup
# e poi applica gli archivelog per portarlo aggiornato
RUN {
    # 1. Restore: copia il datafile dal backup al disco ASM
    RESTORE DATAFILE 10;
    # ^^^ RMAN cerca nel backup più recente il file 10
    #     e lo ricopia su ASM nella posizione originale.

    # 2. Recover: applica gli archivelog per aggiornare il file
    #    dal momento del backup fino a "adesso"
    RECOVER DATAFILE 10;
    # ^^^ Senza questo, il file sarebbe "vecchio" (al momento del backup).
    #     RECOVER legge gli archivelog e applica tutte le modifiche
    #     avvenute DOPO il backup, rendendo il file consistente con il resto.
}

# 3. Torna in SQL*Plus per rimettere online il file
SQL "ALTER DATABASE DATAFILE 10 ONLINE";
```

```sql
-- 4. Verifica il recupero!
sqlplus / as sysdba
SELECT COUNT(*) FROM HR.TEST_DATAFILE;
-- 🎉 Output: 1000 righe — tutto recuperato!

-- 5. Pulizia finale (opzionale)
DROP TABLE HR.TEST_DATAFILE PURGE;
DROP TABLESPACE TEST_RECOVERY INCLUDING CONTENTS AND DATAFILES;
```

> **Perché questo test è importante?** Nella realtà, i dischi si guastano. I file vengono cancellati per errore. Un DBA deve saper ripristinare un singolo datafile **senza fermare il database**. Questo è esattamente quello che hai appena fatto: il database è rimasto aperto per gli altri utenti, solo il tablespace rotto era offline.

---

### Test 5: Validazione Integrità Completa (Dry Run)

Questo test non modifica nulla. Verifica che OGNI blocco del database e OGNI file di backup siano integri.

```rman
rman TARGET /

-- ============================================================
-- TEST A: I blocchi del database sono integri?
-- ============================================================
-- Legge fisicamente ogni blocco di ogni datafile e verifica
-- i checksum. Se un blocco è corrotto, lo segnala.
-- NON crea backup, NON modifica nulla.
BACKUP VALIDATE DATABASE;

-- ============================================================
-- TEST B: I file di backup sono leggibili?
-- ============================================================
-- Per ogni backupset registrato, RMAN apre il file e verifica
-- che sia leggibile e non corrotto.
-- Se un file è stato cancellato o corrotto, lo marca EXPIRED.
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;

-- ============================================================
-- TEST C: Avrei tutto per un restore completo?
-- ============================================================
-- Simula un restore completo: controlla che tutti i datafile
-- e archivelog necessari siano disponibili nei backup.
RESTORE DATABASE PREVIEW;
RESTORE DATABASE VALIDATE;

-- ============================================================
-- TEST D: Ci sono datafile scoperti?
-- ============================================================
REPORT NEED BACKUP;
-- Se mostra file = fai subito un backup Level 0!

-- ============================================================
-- TEST E: Ci sono operazioni NOLOGGING non protette?
-- ============================================================
REPORT UNRECOVERABLE DATABASE;
-- Se mostra file = fai subito un backup di quei datafile specifici
```

---

### Test 6: Verifica Restore da Backup dello Standby al Primario

Un backup fatto sullo standby è utilizzabile per il ripristino del primario. Questo test lo conferma.

```rman
-- Dal primario, verifica che può usare i backup dello standby
rman TARGET /

-- RESTORE ... PREVIEW mostra quali backup userebbe per il restore.
-- Se hai fatto backup dallo standby, li vedrai elencati qui.
-- Il DBID è lo stesso, quindi sono pienamente intercambiabili.
RESTORE DATABASE PREVIEW;

-- Dovresti vedere output tipo:
-- "List of Backup Sets"
-- "BS Key  Type LV ...  Tag: FULL_WEEKLY"
-- Questo prova che i backup fatti su racstby1 sono utilizzabili
-- per ripristinare il primario su rac1.
```

---

### Riepilogo Test: Cosa hai verificato

| Test | Cosa verifica | Rischio | Tempo |
|------|--------------|---------|-------|
| **Passo 0** | Il backup esiste e completa con successo | Nessuno | 10-30 min |
| **Test 1** | I file di backup sono integri e leggibili | Nessuno (dry run) | 5-15 min |
| **Test 2** | Recovery di DROP TABLE via Recyclebin | Nessuno (cestino) | 1 min |
| **Test 3** | Recovery di DROP TABLE PURGE via RMAN PITR | Basso (usa /tmp) | 10-20 min |
| **Test 4** | Recovery di datafile perso (disco guasto) | Medio (offline tablespace test) | 5-10 min |
| **Test 5** | Integrità totale database e backup | Nessuno (readonly) | 10-30 min |
| **Test 6** | Backup standby usabile per primario | Nessuno (readonly) | 2 min |

> [!IMPORTANT]
> **Best Practice Oracle MAA per i test:**
> - Esegui il Test 1 (validazione) **almeno settimanalmente**
> - Esegui il Test 3 o 4 (recovery reale) **almeno mensilmente** su un DB di test
> - Documenta SEMPRE i risultati dei test in un log con data e ora
> - Se un test fallisce, **non andare avanti** — risolvi prima il problema di backup

---

## 5.9 Schema Riassuntivo della Strategia

| Database | Tipo Backup | Frequenza | Retention | Dove |
|---|---|---|---|---|
| **RACDB (Primary)** | Level 1 Incremental | Ogni giorno 04:00 | 7 giorni | +FRA |
| **RACDB (Primary)** | Archivelog | Ogni 2 ore | — | +FRA |
| **RACDB_STBY (Standby)** | Level 0 Full | Domenica 02:00 | 7 giorni | +FRA |
| **RACDB_STBY (Standby)** | Level 1 Incr | Lun-Sab 02:00 | 7 giorni | +FRA |
| **RACDB_STBY (Standby)** | Archivelog | Ogni 2 ore | — | +FRA |
| **dbtarget (Target GG)** | Level 1 Cumulative | Ogni giorno 03:00 | 3 giorni | /u01/backup |

---

## 5.10 Statistiche, Health Check e Manutenzione Automatica

> **Perché le statistiche?** Oracle usa le statistiche degli oggetti (tabelle, indici) per calcolare il piano di esecuzione ottimale delle query. Statistiche vecchie = piani sbagliati = query lente. Sono il carburante dell'ottimizzatore.

### Raccolta Statistiche (Automatica — già attiva di default)

Oracle raccoglie automaticamente le statistiche tramite il job `GATHER_STATS_JOB` che gira nella maintenance window (di notte). Verifica che sia attivo:

```sql
-- Verifica che la raccolta automatica sia attiva
SELECT client_name, status FROM dba_autotask_client 
WHERE client_name = 'auto optimizer stats collection';
-- Deve mostrare: ENABLED

-- Vedi quando ha girato l'ultima volta
SELECT client_name, window_name, jobs_created, jobs_started, jobs_completed
FROM dba_autotask_client_history 
WHERE client_name LIKE '%stats%' 
ORDER BY window_start_time DESC FETCH FIRST 5 ROWS ONLY;
```

### Raccolta Statistiche Manuale (per tabelle specifiche)

```sql
-- Statistiche su uno schema intero
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('HR', CASCADE => TRUE, DEGREE => 4);

-- Statistiche su una tabella specifica
EXEC DBMS_STATS.GATHER_TABLE_STATS('HR', 'EMPLOYEES', CASCADE => TRUE);

-- Statistiche su TUTTO il database (pesante — fallo solo se necessario)
EXEC DBMS_STATS.GATHER_DATABASE_STATS(DEGREE => 4);
```

> **`CASCADE => TRUE`**: Raccoglie anche le statistiche degli indici della tabella.
> **`DEGREE => 4`**: Usa 4 processi paralleli per velocizzare.

### Verifica Tabelle con Statistiche Vecchie

```sql
-- Tabelle con statistiche più vecchie di 7 giorni e > 10% righe modificate
SELECT owner, table_name, last_analyzed, num_rows, stale_stats
FROM dba_tab_statistics 
WHERE stale_stats = 'YES' 
AND owner NOT IN ('SYS','SYSTEM','DBSNMP','OUTLN')
ORDER BY num_rows DESC;
```

### Health Check Completo del Database

```sql
-- ============= HEALTH CHECK SCRIPT =============
-- Eseguilo una volta al giorno o dopo ogni intervento

-- 1. Stato dell'istanza
SELECT inst_id, instance_name, status, startup_time FROM gv$instance;

-- 2. Spazio Tablespace (> 85% = WARNING, > 95% = CRITICAL)
SELECT tablespace_name, 
       ROUND(used_percent, 1) AS "Used%",
       CASE WHEN used_percent > 95 THEN '🔴 CRITICAL'
            WHEN used_percent > 85 THEN '🟡 WARNING'
            ELSE '🟢 OK' END AS status
FROM dba_tablespace_usage_metrics
ORDER BY used_percent DESC;

-- 3. Spazio ASM
SELECT name, state, type, 
       ROUND(total_mb/1024,1) AS total_gb, 
       ROUND(free_mb/1024,1) AS free_gb,
       ROUND((1-free_mb/total_mb)*100,1) AS "Used%"
FROM v$asm_diskgroup;

-- 4. Alert log errori recenti (ORA-)
SELECT originating_timestamp, message_text 
FROM v$diag_alert_ext 
WHERE originating_timestamp > SYSDATE - 1
AND message_text LIKE '%ORA-%'
ORDER BY originating_timestamp DESC FETCH FIRST 20 ROWS ONLY;

-- 5. Sessioni attive per wait class
SELECT wait_class, COUNT(*) AS sessions
FROM gv$session WHERE status = 'ACTIVE' AND wait_class != 'Idle'
GROUP BY wait_class ORDER BY sessions DESC;

-- 6. Data Guard lag (solo sullo standby)
SELECT name, value, datum_time FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- 7. Job falliti nelle ultime 24 ore
SELECT job_name, status, actual_start_date, run_duration
FROM dba_scheduler_job_run_details
WHERE actual_start_date > SYSDATE - 1 AND status = 'FAILED';

-- 8. Invalid objects
SELECT owner, object_type, object_name FROM dba_objects 
WHERE status = 'INVALID' 
AND owner NOT IN ('SYS','SYSTEM','PUBLIC')
ORDER BY owner, object_type;

-- 9. FRA usage
SELECT * FROM v$flash_recovery_area_usage;
SELECT ROUND(space_limit/1024/1024/1024,2) AS limit_gb, 
       ROUND(space_used/1024/1024/1024,2) AS used_gb,
       ROUND(space_reclaimable/1024/1024/1024,2) AS reclaimable_gb
FROM v$recovery_file_dest;
```

### Script Health Check Automatico

```bash
cat > /home/oracle/scripts/daily_health_check.sh <<'SCRIPT'
#!/bin/bash
# daily_health_check.sh — Report giornaliero del database
source /home/oracle/.db_env

LOG=/home/oracle/scripts/logs/health_$(date +%Y%m%d).log
echo "=== DAILY HEALTH CHECK — $(date) ===" > $LOG

sqlplus -s / as sysdba >> $LOG <<SQL
SET LINESIZE 200 PAGESIZE 100

PROMPT
PROMPT === INSTANCE STATUS ===
SELECT inst_id, instance_name, status FROM gv\$instance;

PROMPT
PROMPT === TABLESPACE USAGE ===
SELECT tablespace_name, ROUND(used_percent,1) AS pct_used FROM dba_tablespace_usage_metrics WHERE used_percent > 80 ORDER BY used_percent DESC;

PROMPT
PROMPT === ASM DISKGROUP ===
SELECT name, ROUND((1-free_mb/total_mb)*100,1) AS pct_used FROM v\$asm_diskgroup;

PROMPT
PROMPT === STALE STATISTICS ===
SELECT owner, COUNT(*) AS stale_tables FROM dba_tab_statistics WHERE stale_stats='YES' AND owner NOT IN ('SYS','SYSTEM') GROUP BY owner;

PROMPT
PROMPT === RECENT ORA ERRORS ===
SELECT originating_timestamp, SUBSTR(message_text,1,120) FROM v\$diag_alert_ext WHERE originating_timestamp > SYSDATE-1 AND message_text LIKE '%ORA-%' FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT === INVALID OBJECTS ===
SELECT owner, object_type, COUNT(*) FROM dba_objects WHERE status='INVALID' AND owner NOT IN ('SYS','SYSTEM','PUBLIC') GROUP BY owner, object_type;
SQL

echo "" >> $LOG
echo "=== END HEALTH CHECK ===" >> $LOG
cat $LOG
SCRIPT

chmod +x /home/oracle/scripts/daily_health_check.sh
```

Aggiungi al cron su TUTTI i database:

```cron
# Health Check giornaliero — Ogni giorno alle 08:00
0 8 * * * /home/oracle/scripts/daily_health_check.sh >> /home/oracle/scripts/logs/cron.log 2>&1
```

---

## ✅ Checklist Fine Fase 5

```bash
# 1. BCT attivo sui DB dove esegui incrementali
sqlplus -s / as sysdba <<< "SELECT status FROM v\$block_change_tracking;"

# 2. Backup eseguito con successo
rman TARGET / <<< "LIST BACKUP SUMMARY;"

# 3. Cron configurato
crontab -l

# 4. Restore testato
rman TARGET / <<< "RESTORE DATABASE VALIDATE;"
```

---

**→ Prossimo consigliato: [FASE 6: Enterprise Manager Cloud Control](./GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md)**

---

## 🎉 Congratulazioni (Core Stack Completato)

Hai completato il core dell'architettura Oracle (HA + DR + replica + backup):

```
RAC Primary (RACDB)
    ├── Data Guard → RAC Standby (RACDB_STBY)
    │                    ├── RMAN Backup (Level 0 + Level 1)
    │                    └── GoldenGate Extract
    │                            └── → Target DB (dbtarget)
    │                                      └── RMAN Backup (Cumulative)
    └── Force Logging + Archivelog Mode
```

Hai imparato:
1. **RAC**: High Availability locale con failover automatico.
2. **Data Guard**: Disaster Recovery con standby fisico.
3. **GoldenGate**: Replica logica cross-platform verso un target indipendente.
4. **RMAN**: Backup & Recovery professionale su TUTTI i database.
5. **Statistiche & Maintenance**: Health check, statistiche dell'ottimizzatore, monitoraggio proattivo.
6. **Patching**: OPatch, opatchauto, datapatch per Grid e Database.

Passo successivo naturale: centralizzare monitoraggio e governance con Enterprise Manager (Fase 6).
