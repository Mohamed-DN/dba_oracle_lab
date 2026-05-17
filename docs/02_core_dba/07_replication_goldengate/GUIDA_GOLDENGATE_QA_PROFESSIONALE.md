# Oracle GoldenGate - Q&A Tecnico Professionale

> Domande e risposte operative per consolidare i concetti GoldenGate 19c e sapere discutere anche 26ai. Non e' una guida "da colloquio" nel titolo, ma una raccolta di risposte tecniche da DBA GoldenGate.

---

## 1. Fondamenti

### 1. Che differenza c'e' tra Data Guard e GoldenGate?

Data Guard replica un database intero a livello fisico o SQL Apply per HA/DR. GoldenGate replica cambiamenti logici selezionati, anche tra database diversi, per migrazione, integrazione, reporting o active-active. Data Guard protegge il database; GoldenGate muove dati e transazioni.

### 2. Cos'e' CDC?

Change Data Capture e' la cattura delle modifiche committed da redo/transaction log senza interrogare continuamente le tabelle applicative. GoldenGate legge redo/archivelog e produce trail file.

### 3. Cosa sono i trail file?

File sequenziali GoldenGate che contengono record di cambiamento. Servono a disaccoppiare capture e apply, garantire restart, spedire dati in rete e fare troubleshooting.

### 4. Cosa sono i checkpoint?

Punti di avanzamento persistenti di Extract/Replicat. Permettono ripartenza senza perdere transazioni o riapplicare dati gia processati.

### 5. GoldenGate e' sincrono?

Normalmente e' asincrono. Il source committa indipendentemente dal target. Il ritardo si misura come lag Extract/Replicat.

---

## 2. Architettura

### 6. Differenza tra Classic e Microservices?

Classic usa Manager, `ggsci`, Data Pump e Collector. Microservices usa Service Manager, Administration Server, Distribution Server, Receiver Server, Web UI, Admin Client e REST API. I concetti di Extract/trail/Replicat restano, cambia il control plane.

### 7. Che ruolo ha Manager in Classic?

Gestisce processi, porte, Collector, eventi, autostart/autorestart e purge dei trail con checkpoint.

### 8. Che ruolo ha Service Manager in MA?

E' il watchdog dei deployment locali: start/stop servizi, inventory e gestione centralizzata.

### 9. Cosa sostituisce Data Pump in MA?

Il Distribution Server e i Distribution Path. In Classic il Pump e' un Extract secondario; in MA e' un servizio.

### 10. Che ruolo ha Receiver Server?

Riceve trail remoti dal Distribution Server e li scrive sul target.

---

## 3. Extract

### 11. Classic Extract vs Integrated Extract?

Classic Extract legge redo con meccanismi tradizionali GoldenGate. Integrated Extract usa servizi database/LogMiner server ed e' lo standard consigliato per Oracle 19c.

### 12. Perche' Integrated Extract e' preferibile su Oracle 19c?

Perche' usa API DB supportate, gestisce meglio tipi dati moderni e si integra con RAC/CDB. Richiede `ENABLE_GOLDENGATE_REPLICATION` e privilegi corretti.

### 13. Cosa succede se Extract si ferma?

Il source continua a generare redo. Se gli archivelog necessari restano disponibili, Extract riparte dal checkpoint. Se vengono cancellati, serve restore degli archivelog o re-instanziazione.

### 14. Come controlli lag Extract?

`LAG EXTRACT`, `INFO EXTRACT DETAIL`, report Extract, statistiche DB, redo generation e availability degli archive log.

### 15. Cos'e' `REGISTER EXTRACT`?

Registra un Integrated Extract nel database per usare i servizi di integrated capture.

---

## 4. Replicat

### 16. Classic, Coordinated, Integrated e Parallel Replicat?

Classic applica in modo tradizionale. Coordinated usa piu thread coordinati. Integrated Replicat si integra con apply engine Oracle. Parallel Replicat massimizza throughput gestendo dipendenze. La scelta dipende da volume, target e consistenza richiesta.

### 17. Perche' Replicat puo' andare in abend?

Constraint violate, duplicati, mapping errato, colonne mancanti, datatype non compatibili, permessi insufficienti, target lento o trail corrotto.

### 18. Cosa fai davanti a ORA-00001 su Replicat?

Non usare subito `HANDLECOLLISIONS`. Verifica initial load, start SCN, duplicati reali, sequenze e mapping. `HANDLECOLLISIONS` e' temporaneo durante stabilizzazione, va rimosso.

### 19. Cosa fai davanti a ORA-02291?

FK parent mancante: controlla ordine di apply, mapping, dati non replicati, transazioni parziali o tabella parent esclusa.

### 20. Quando usare checkpoint table?

Per Replicat e' best practice, soprattutto su target database, per rendere checkpoint persistenti e gestibili.

---

## 5. Supplemental Logging

### 21. Perche' serve supplemental logging?

Redo normale puo' non contenere tutte le colonne necessarie per identificare la riga target. Supplemental logging aggiunge chiavi e colonne utili alla replica logica.

### 22. Minimal supplemental logging basta?

No, e' prerequisito base. Devi aggiungere `ADD SCHEMATRANDATA` o `ADD TRANDATA` sugli oggetti replicati.

### 23. Differenza tra `ADD TRANDATA` e `ADD SCHEMATRANDATA`?

`ADD TRANDATA` abilita logging su una tabella. `ADD SCHEMATRANDATA` lo abilita a livello schema e copre anche tabelle future.

### 24. Quando usare `ALLCOLS`?

Active-active, conflict detection, chiavi diverse tra source/target o quando vuoi massima capacita di confronto. Costa piu redo.

### 25. Cosa fare con tabelle senza PK?

Aggiungere PK/unique key se possibile. In alternativa definire `KEYCOLS`, ma devi garantire unicita reale. Evitare replica di tabelle senza chiave stabile.

---

## 6. Sicurezza

### 26. Perche' non usare `DBA` a GGADMIN?

Perche' viola least privilege. `GRANT DBA` spesso fa funzionare il lab perche' concede tutto, ma non e' una risposta accettabile in produzione critica. In produzione si usano privilegi specifici tramite `DBMS_GOLDENGATE_AUTH`, grant DML mirati sul target e credential store. Vedi [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

### 27. A cosa serve `DBMS_GOLDENGATE_AUTH`?

Concede i privilegi necessari per amministrare capture/apply GoldenGate e registra l'utente nelle viste di privilegi GoldenGate.

### 27b. Se senza `DBA` ricevo `ORA-01031`, cosa controllo?

Controllo container (`CDB$ROOT` vs PDB), `container=>'ALL'`, `CREATE SESSION`, quota tablespace, grant DML sul target, privilegi DDL se sto replicando DDL, e se `DBLOGIN` usa davvero l'alias dell'utente corretto. Non risolvo concedendo `DBA` permanente.

### 28. Common user o local user in CDB?

Common user `C##GGADMIN` se devi catturare/applicare su piu PDB o gestire CDB-level. Local user `GGADMIN` se lavori in un singolo PDB.

### 29. Dove salvare password?

Nel credential store/wallet, non nei parameter file.

### 30. TLS in Microservices e' obbligatorio?

In produzione e' best practice. In lab puoi usare HTTP per semplicita, ma devi sapere spiegare che non e' accettabile come standard enterprise.

---

## 7. FRA, redo e retention

### 31. Perche' GoldenGate puo' riempire la FRA indirettamente?

Se Extract e' fermo, gli archivelog necessari devono restare disponibili. Aumenta retention e consumo FRA. Se FRA si riempie, il DB puo' bloccarsi.

### 32. Cosa fai se FRA e' al 95% e Extract e' fermo?

Non cancelli a caso. Verifichi checkpoint Extract, archivelog richiesti, backup RMAN, spazio estendibile, restore strategy. Se puoi, fai ripartire Extract. Se mancano log, valuti restore o resync.

### 33. Come dimensioni archive retention?

Redo per ora × ore di outage tollerate × safety factor, piu RMAN/Data Guard/flashback. Misurare da `v$archived_log`.

### 34. Cosa significa archive log missing per Extract?

Extract non puo' avanzare dal checkpoint. Potresti dover ripristinare archivelog o re-instanziare target.

---

## 8. Migrazione e cutover

### 35. Come fai una migrazione zero-downtime?

1. Abiliti GoldenGate e supplemental logging.
2. Avvii Extract da SCN noto.
3. Fai initial load consistente con Data Pump/FLASHBACK_SCN.
4. Avvii Replicat da AFTERCSN.
5. Aspetti lag zero.
6. Fermi app source.
7. Verifichi consistenza.
8. Sposti traffico al target.

### 36. Cos'e' `AFTERCSN`?

Punto di start Replicat: applica solo transazioni successive a un SCN, evitando duplicazioni rispetto all'initial load.

### 37. Perche' initial load e SCN sono critici?

Se SCN non e' coerente, puoi avere dati mancanti o duplicati.

### 38. Quando usare Data Pump con `FLASHBACK_SCN`?

Quando vuoi esportare una vista consistente del source mentre le applicazioni continuano a scrivere.

---

## 9. Oracle -> PostgreSQL

### 39. Oracle -> PostgreSQL e' uguale a Oracle -> Oracle?

No. E' eterogenea: datatype, DDL, sequenze, case sensitivity e funzioni SQL possono differire. Va testata tabella per tabella.

### 40. Quali sono i rischi principali?

Mapping datatype, LOB, timestamp/timezone, nomi maiuscoli/minuscoli, transazioni grandi, DDL non equivalente, vincoli e sequenze.

### 41. Come gestisci sequence Oracle su PostgreSQL?

Non aspettarti equivalenza automatica perfetta. Devi creare sequence/identity target e definire cutover evitando collisioni.

### 42. Serve PK anche per PostgreSQL target?

Si, per update/delete affidabili serve chiave stabile. Senza PK la replica e' fragile.

---

## 10. RAC e Data Guard

### 43. GoldenGate cattura da RAC?

Si, ma devi usare configurazione corretta, servizi stabili e Integrated Extract. Tutte le istanze devono avere parametri coerenti.

### 44. GoldenGate cattura dallo standby Data Guard?

Possibile in architetture specifiche, ma il pattern piu semplice e' capture dal primary. Per capture da standby serve progettazione e supporto specifico.

### 45. Cosa succede dopo switchover Data Guard?

Devi verificare ruolo DB, servizi, TNS, Extract, alias, archive availability e runbook GoldenGate. Non assumere che tutto segua automaticamente.

---

## 11. 19c e 26ai

### 46. Perche' studiare 19c se esiste 26ai?

Perche' 19c e' diffusissimo in produzione. Molti ambienti reali usano ancora Classic o MA 19c.

### 47. Cosa porta 26ai?

Microservices piu centrale, UI/API migliorate, AI service embedded, nuove compatibilita source/target e maggiore orientamento a data streaming/analytics.

### 48. Upgrade 19c -> 26ai e' sempre diretto?

Per Microservices 19c/21c Oracle documenta upgrade diretto a 26ai. Per Classic devi pianificare conversione/modernizzazione verso Microservices.

### 49. Cosa controlli prima di upgrade?

Certificazioni, backup deployment, wallet, credential store, param file, trail, checkpoint, OS, source/target compatibility, rollback.

---

## 12. Domande scenario

### 50. Replicat e' lento ma Extract e Pump sono ok. Dove guardi?

Target DB: wait event, indici, constraint, trigger, parallelismo, `BATCHSQL`, report Replicat, discard file, I/O target.

### 51. Extract e' lento. Dove guardi?

Redo rate, LogMiner, CPU source, I/O archive, FRA, transazioni lunghe, dizionario, report Extract.

### 52. Trail cresce sul source. Cosa significa?

Pump/Distribution fermo o lento, rete non disponibile, target Receiver/Manager giu, spazio target pieno.

### 53. Trail cresce sul target. Cosa significa?

Replicat fermo o lento.

### 54. Come dimostri che la replica funziona?

Test insert/update/delete su tabella con PK, verifica target, `LAG`, `STATS`, report senza errori e query di confronto.

### 55. Come eviti loop in bidirezionale?

Parametri e architettura CDR/loop detection, separazione origin, esclusione transazioni replicate, chiavi gestite e test accurati.

### 56. Come gestisci DDL?

Solo se supportato e richiesto. Devi testare DDL replication, versioni, oggetti esclusi e impatto target. In molti ambienti DDL si gestisce con change process controllato.

### 57. Cosa monitori ogni giorno?

Process status, lag, abend, report errori, trail growth, FRA usage, archive generation, spazio filesystem, heartbeat, target apply rate.

### 58. Cosa metti in un runbook GoldenGate?

Start/stop, restart after abend, archive missing, FRA full, lag alto, cutover, rollback, resync, escalation e comandi diagnostici.

### 59. Quando serve re-instanziazione?

Quando mancano log necessari, target divergente non riparabile, start SCN errato, o recovery logica troppo rischiosa.

### 60. Qual e' la risposta piu importante da dare su GoldenGate?

GoldenGate non e' solo "start extract/start replicat". E' una pipeline transazionale: source logging, capture, trail retention, routing, apply, checkpoint, monitoring e recovery devono essere progettati insieme.

## Obiettivo
Chiarire i temi chiave da presidiare in colloquio tecnico su GoldenGate (architettura, operatività, troubleshooting).

## Procedura operativa
Usare la guida in modalità sessione Q&A: ripasso per blocchi, risposta strutturata e verifica degli argomenti critici.

## Validazione finale
Verificare di saper spiegare end-to-end capture/apply, scenari di errore frequenti e procedure di recovery operative.

## Troubleshooting rapido
Se emergono lacune, tornare alle domande con incertezza, collegarle ai runbook OGG e ripetere il ripasso mirato.
