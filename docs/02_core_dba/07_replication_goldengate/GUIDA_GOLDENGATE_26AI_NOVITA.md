# Oracle GoldenGate 26ai - Novita e Differenze rispetto a 19c

> GoldenGate 19c resta la base pratica del lab e degli ambienti enterprise esistenti. GoldenGate 26ai va studiato come evoluzione moderna: piu Microservices, piu automazione, piu sorgenti/target, funzionalita AI e percorsi di upgrade da 19c/21c.

---

## 1. Posizionamento

| Versione | Come studiarla | Perche' conta |
| --- | --- | --- |
| GoldenGate 19c | Core operativo | Molto diffusa in produzione, base per Classic e MA |
| GoldenGate 21c | Ponte evolutivo | Presente in alcune installazioni MA |
| GoldenGate 26ai | Evoluzione moderna | nuove feature, AI service, compatibilita estese, upgrade path |

Per un DBA GoldenGate devi saper dire:

- 19c e' ancora importantissima;
- 26ai non cancella i concetti base: Extract, trail, Replicat, checkpoint restano fondamentali;
- 26ai spinge su Microservices, REST/API e operativita moderna.

---

## 2. Cosa cambia concettualmente

GoldenGate 26ai e' orientato a:

- Microservices-first;
- gestione via UI e API;
- automazione enterprise;
- integrazione con scenari analytics e data streaming;
- supporto piu ampio a tecnologie eterogenee;
- AI service embedded.

Non cambia la logica base:

```text
Source change -> Capture -> Trail / Stream -> Route -> Apply / Delivery
```

Cambia il modo in cui lo governi e quali target/source puoi integrare.

---

## 3. Novita 26ai da conoscere

### 3.1 AI Service embedded

GoldenGate 26ai introduce servizi AI integrati per scenari in cui i flussi dati possono essere arricchiti o integrati con modelli AI.

Da sapere:

- non serve per una replica Oracle->Oracle classica;
- e' importante in architetture moderne real-time analytics;
- va trattato come funzionalita nuova da valutare, non come prerequisito.

### 3.2 UI e automazione migliorate

26ai continua la direzione Microservices:

- web UI piu moderna;
- REST API centrali;
- deployment gestiti in modo piu standard;
- migliore automazione day-2.

### 3.3 Nuove compatibilita source/target

Dalle release notes 26ai emergono nuove compatibilita e ampliamenti, tra cui:

- EDB Postgres Advanced Server;
- YugabyteDB / YugabyteDB Anywhere;
- integrazioni analytics e distributed applications;
- scenari Data Streams.

Nota: verifica sempre certificazioni aggiornate prima di promettere supporto in produzione.

### 3.4 Automatic Schema Evolution preview

Alcune funzionalita possono essere preview/evaluation. Non vanno vendute come standard production senza controllo documentazione e supporto Oracle.

Regola professionale:

- feature GA: valutabile per produzione se certificata;
- feature preview: solo laboratorio/POC, non baseline production.

---

## 4. Differenze operative 19c vs 26ai

| Area | 19c | 26ai |
| --- | --- | --- |
| Base installata | molto diffusa | nuova generazione |
| Classic | ancora rilevante | conversione verso MA da pianificare |
| Microservices | maturo | direzione principale |
| REST/API | disponibile | piu centrale |
| AI | non core | AI service embedded |
| Heterogeneous | supporto ampio ma da verificare | supporto ampliato |
| Upgrade | origine comune | target evolutivo |

---

## 5. Cosa dire in una discussione tecnica

Risposta sintetica:

> In un ambiente enterprise io tratterei GoldenGate 19c come baseline operativa, perche' e' ancora molto presente e stabile. Studiare 26ai e' importante per capire la direzione Oracle: Microservices, API, UI moderna, AI service e nuove certificazioni eterogenee. Per upgrade valuterei prima certificazioni source/target, backup dei deployment, compatibilita dei parameter file e un piano di rollback.

Risposta piu tecnica:

> I concetti CDC restano gli stessi: Extract cattura, trail conserva checkpointable changes, Replicat applica. La differenza e' nel control plane: Classic usa Manager/GGSCI, 19c MA usa Service Manager/Admin/Distribution/Receiver, 26ai rafforza MA e aggiunge nuove capacita. Quindi per un upgrade non basta installare binari: bisogna validare deployment, wallet, credenziali, trail, parametri, certificazioni e runbook.

---

## 6. Quando valutare 26ai

Valutalo se:

- stai facendo nuova architettura Microservices;
- vuoi standard API-first;
- devi integrare nuovi source/target certificati solo su 26ai;
- vuoi allinearti alla nuova long-term direction Oracle;
- devi preparare upgrade tecnologico.

Rimani su 19c se:

- ambiente stabile e supportato;
- dipendenze legacy Classic;
- nessuna esigenza nuova;
- team non ancora pronto al cambio operativo;
- certificazioni applicative non completate.

---

## 7. Checklist valutazione 26ai

- [ ] Source e target certificati per 26ai.
- [ ] OS certificato.
- [ ] Tipo architettura: MA o Classic.
- [ ] Se Classic: percorso conversione a MA definito.
- [ ] Feature usate in 19c ancora supportate.
- [ ] Parameter file controllati.
- [ ] Credential store/wallet esportati.
- [ ] TLS/certificati validi.
- [ ] Trail e checkpoint protetti.
- [ ] Piano rollback documentato.
- [ ] Test in clone/lab prima della produzione.

---

## 8. Fonti ufficiali

- Oracle GoldenGate 26ai Docs: https://docs.oracle.com/en/database/goldengate/core/26/index.html
- What is new 26ai: https://docs.oracle.com/en/database/goldengate/core/26/coredoc/why-upgrade-ogg.html
- Release Notes 26ai: https://docs.oracle.com/en/database/goldengate/core/26/release-notes/new-features.html
- Certifications: https://www.oracle.com/integration/goldengate/certifications/
