# GoldenGate in Ambienti Critici Bancari - Sicurezza, Rete e Governance

> Questa guida adatta GoldenGate a contesti enterprise regolati: banche, assicurazioni, pagamenti, pubblica amministrazione critica, sistemi finanziari e ambienti dove source e target **non sono liberamente aperti tra loro**. Il lab puo' essere semplice; la produzione no.

---

## 1. Principio base

In un ambiente bancario non si parte da "apri la porta e replica". Si parte da:

```text
Dati critici + rete segmentata + change governance + audit + rollback
```

GoldenGate deve rispettare:

- principio del minimo privilegio;
- flussi firewall espliciti;
- cifratura in transito e dove richiesto a riposo;
- credenziali in wallet/credential store;
- separazione dei ruoli DBA, security, network, middleware;
- logging e audit integrati con SIEM;
- procedure approvate da change/CAB;
- rollback testato.

---

## 2. Regola: non sempre source e target possono parlarsi

In banca e' normale avere zone separate:

```text
[PROD DB ZONE]       [INTEGRATION / DMZ]       [TARGET / ANALYTICS / CLOUD ZONE]
     |                        |                              |
     |  flussi stretti        |  broker/hub controllato      |  flussi stretti
     v                        v                              v
Source DB  --->  GoldenGate Source/Hub  --->  GoldenGate Target  --->  Target DB
```

Pattern vietati o da evitare:

- `any -> any` tra source e target;
- porte database aperte tra tutte le subnet;
- password nei parameter file;
- trail su filesystem non monitorato;
- utenti `DBA` per GoldenGate in produzione;
- connessioni HTTP non cifrate fuori dal lab;
- gestione manuale non tracciata.

---

## 3. Flussi di rete minimi

### 3.1 Microservices 19c standard push path

```text
OGG Source Host                         OGG Target Host                         Target DB
===============                         ===============                         =========
Distribution Server  -- WSS 9014 ---->  Receiver Server
Extract              -- TCP 1521 ---->  Source DB listener
Replicat             -- TCP 1521 ---->  Oracle target
Replicat             -- TCP 5432 ---->  PostgreSQL target
Admin                -- HTTPS 9011/9012/9013/9014 --> solo da subnet amministrativa
```

Firewall matrix minima:

| Da | A | Porta | Direzione | Note |
| --- | --- | --- | --- | --- |
| OGG source | Source DB SCAN/listener | 1521/1522 | source -> DB | Extract login/capture metadata |
| OGG source Distribution | OGG target Receiver | 9014 | source -> target | solo se policy consente push |
| OGG target | Target Oracle DB | 1521/1522 | target OGG -> target DB | Replicat apply |
| OGG target | PostgreSQL target | 5432 | target OGG -> target DB | replica eterogenea |
| Admin subnet | Service/Admin/Distribution/Receiver | 9011-9014 o reverse proxy 443 | admin -> OGG | gestione controllata |
| Monitoring subnet | OGG/OS endpoints | porte monitor approvate | monitoring -> OGG | metriche/log |

### 3.2 Classic 19c

```text
Pump source  -- TCP 7809/7810-7820 -->  Manager/Collector target
```

Aprire solo:

- `MGRPORT` target;
- range `DYNAMICPORTLIST` target;
- porte DB locali necessarie a Extract/Replicat.

---

## 4. Quando il source non puo' aprire connessioni verso il target

Caso tipico:

```text
Source in zona meno trusted o rete legacy
Target in zona piu trusted / cloud / DMZ protetta
Policy: il source NON puo' iniziare sessioni verso target
```

Soluzione Microservices: **Target-Initiated Distribution Path**.

```text
MODELLO PUSH STANDARD
Source Distribution  ------------------>  Target Receiver
          connessione iniziata dal source

MODELLO TARGET-INITIATED / PULL
Source Distribution  <------------------  Target Receiver
          connessione iniziata dal target
```

Perche' e' utile:

- rispetta policy dove il target/trusted zone puo' aprire verso source, ma non viceversa;
- riduce superfici esposte nel target;
- utile per DMZ, cloud-to-on-prem, on-prem-to-cloud con firewall rigidi;
- il path e' definito lato Receiver/target e tira i trail dal Distribution Server.

Da ricordare:

- in 19c e MA e' una funzionalita specifica dei Distribution Path;
- va progettata con security/network team;
- non sostituisce TLS/WSS/mTLS;
- non cancellare trail source finche' il checkpoint del path non e' sicuro.

---

## 5. Reverse proxy e porta unica

In produzione spesso non si vogliono esporre quattro porte MA (`9011-9014`) a utenti/admin.

Oracle documenta il reverse proxy NGINX per GoldenGate Microservices:

```text
Admin/browser/API  -- HTTPS 443 -->  NGINX reverse proxy  -->  Service/Admin/Distribution/Receiver
```

Vantaggi:

- endpoint unico `443`;
- TLS centralizzato;
- URL piu pulite;
- esposizione controllata dei microservizi;
- integrazione piu semplice con load balancer, WAF, proxy aziendale.

Attenzioni:

- mTLS per Distribution Path ha limitazioni quando si usa reverse proxy;
- documentare dove termina TLS;
- evitare SSL termination non approvata su reti non trusted;
- logging reverse proxy deve andare a SIEM.

---

## 6. TLS, WSS e mTLS

Standard minimo production:

| Canale | Lab | Produzione critica |
| --- | --- | --- |
| Web UI/API | HTTP possibile | HTTPS obbligatorio |
| Distribution Path | WS possibile | WSS obbligatorio |
| Inter-deployment trust | password/basic | TLS/mTLS dove supportato |
| DB connection | TCP | TCPS se policy richiede cifratura DB |
| Password | placeholder | credential store/wallet/PAM |

GoldenGate Microservices supporta HTTPS e WSS. Nelle versioni moderne, TLS 1.2/1.3 e mTLS sono parti chiave della protezione data-in-transit.

Checklist certificati:

- [ ] certificati emessi da CA aziendale o CA approvata;
- [ ] CN/SAN coerenti con FQDN usati;
- [ ] wallet protetto con permessi OS stretti;
- [ ] scadenze certificate monitorate;
- [ ] rotation testata;
- [ ] runbook per rinnovo certificati;
- [ ] test WSS Distribution Path dopo rinnovo.

---

## 7. Credential store e wallet

Regola bancaria:

```text
Nessuna password in chiaro nei param file, script, README, job scheduler o shell history.
```

Usare:

- GoldenGate credential store;
- wallet Oracle;
- secret manager aziendale se integrato;
- PAM/bastion per accessi amministrativi;
- rotazione periodica credenziali;
- account nominali per admin, account tecnico solo per processi.

Esempio accettabile:

```text
USERIDALIAS ggsrc DOMAIN OracleGoldenGate
```

Esempio non accettabile:

```text
USERID ggadmin, PASSWORD password_in_chiaro
```

---

## 8. Least privilege database

In produzione evitare grant amministrativi globali all'utente GoldenGate.
L'utente `GGADMIN` deve avere solo i privilegi necessari per capture/apply,
non privilegi DBA generici.

Preferire:

```sql
GRANT CREATE SESSION TO ggadmin;
GRANT CREATE VIEW TO ggadmin;
BEGIN
  DBMS_GOLDENGATE_AUTH.GRANT_ADMIN_PRIVILEGE(
    grantee                 => 'GGADMIN',
    privilege_type          => '*',
    grant_select_privileges => TRUE,
    do_grants               => TRUE);
END;
/
```

Poi aggiungere solo i grant operativi necessari:

```sql
-- Target Replicat, object-level
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.CUSTOMERS TO ggadmin;
GRANT SELECT, INSERT, UPDATE, DELETE ON APP.ORDERS TO ggadmin;
```

Guida completa sui privilegi: [GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md](./GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).

Separazione consigliata:

| Utente | Dove | Ruolo |
| --- | --- | --- |
| `GGADMIN_CAPTURE` | source | capture/extract |
| `GGADMIN_APPLY` | target | apply/replicat |
| admin nominale | OGG MA UI/API | gestione processi |
| utente OS `oracle`/`ogg` | host | runtime processi |

---

## 9. Trail, dati sensibili e cifratura a riposo

I trail possono contenere dati sensibili.

Controlli:

- filesystem cifrato se richiesto;
- permessi OS stretti (`700` directory, owner runtime);
- no backup trail su share non cifrate;
- retention minima necessaria;
- purge con checkpoint;
- controllo accesso a `dirdat`, `dirrpt`, discard file;
- mascheramento/log redaction dove possibile.

Ricorda: anche report e discard file possono contenere valori dati o SQL error con informazioni sensibili.

---

## 10. Architetture consigliate per banca

### 10.1 Same data center, zone separate

```text
[DB PROD ZONE]                       [APP/INTEGRATION ZONE]                 [TARGET ZONE]
Oracle RACDB -> OGG Source Host  ->  OGG Target Host / Receiver  ->          Target DB
             1521 local/strict       WSS 9014 / reverse proxy 443            1521/5432 local
```

Caratteristiche:

- Extract vicino al source;
- Replicat vicino al target;
- un solo flusso trail tra zone;
- firewall dichiarato.

### 10.2 DMZ / target-initiated

```text
[LESS TRUSTED SOURCE]                 [TRUSTED TARGET]
Distribution Server  <--- WSS pull --- Receiver Server
```

Uso:

- il target non accetta connessioni inbound dal source;
- il target apre connessione verso source secondo policy;
- utile in DMZ/cloud.

### 10.3 Hub GoldenGate

```text
Source DBs -> OGG Hub -> Targets / Kafka / Analytics / Cloud
```

Uso:

- centralizzare gestione;
- ridurre agent sui DB server;
- governare molti flussi.

Rischi:

- hub diventa componente critico;
- serve HA, backup, monitoring forte;
- capacity planning trail/CPU/rete.

### 10.4 Air-gap / rete ultra-restrittiva

Per reti isolate, verificare feature e prodotti GoldenGate specifici/certificati. Non assumere che il normale Distribution Path basti.

Principi:

- niente internet diretto;
- staging controllato;
- transfer approvato;
- integrita trail verificata;
- auditing completo;
- accettazione security formale.

---

## 11. Monitoring e SIEM

Eventi da integrare:

- Extract/Replicat ABENDED;
- lag sopra soglia;
- trail filesystem sopra soglia;
- FRA sopra soglia;
- errori login DB;
- cambio parameter file;
- start/stop processi;
- scadenza certificati;
- fallimento Distribution Path;
- errori discard file.

Soglie tipiche:

| Metrica | Warning | Critical |
| --- | --- | --- |
| Replicat lag | > 5 min | > 15 min o SLA specifico |
| Extract lag | > 5 min | > 15 min |
| FRA usage | > 80% | > 90% |
| Trail filesystem | > 75% | > 85/90% |
| Certificato TLS | < 30 giorni | < 7 giorni |

---

## 12. Change governance

Prima di una modifica GoldenGate in banca:

- [ ] change ticket approvato;
- [ ] impatto applicativo valutato;
- [ ] schema/tabelle incluse approvate dal data owner;
- [ ] firewall rule approvata da security/network;
- [ ] piano rollback scritto;
- [ ] backup config/trail/checkpoint;
- [ ] test non-prod eseguito;
- [ ] finestra operativa definita;
- [ ] monitoraggio intensivo post-change;
- [ ] evidenze archiviate.

---

## 13. Runbook di incidente critico

### 13.1 Extract fermo

1. Non cancellare archivelog.
2. Controlla report Extract.
3. Controlla FRA e archive availability.
4. Controlla DB login/privilegi.
5. Riparti solo dopo root cause.
6. Se mancano log: restore archivelog o re-instanziazione.

### 13.2 Distribution path fermo

1. Verifica Receiver/Manager target.
2. Verifica firewall/TLS/certificati.
3. Controlla trail source growth.
4. Se target-initiated: verifica Receiver path lato target.
5. Non purgare trail source prima di recupero.

### 13.3 Replicat abended

1. Leggi report e discard.
2. Identifica errore SQL.
3. Non usare `HANDLECOLLISIONS` come fix permanente.
4. Correggi dato/mapping/constraint.
5. Riparti e verifica consistency.

---

## 14. Checklist production readiness

- [ ] Architettura approvata da DBA, security, network, application owner.
- [ ] Tutti i flussi firewall documentati e minimizzati.
- [ ] Nessun `any-any`.
- [ ] HTTPS/WSS/TLS abilitati dove richiesto.
- [ ] Credential store configurato.
- [ ] Nessuna password in chiaro.
- [ ] Utenti DB least privilege.
- [ ] Trail e report protetti.
- [ ] FRA/archive retention dimensionata.
- [ ] Backup e restore config testati.
- [ ] Runbook incidenti scritto.
- [ ] Monitoring/SIEM configurato.
- [ ] Certificati monitorati.
- [ ] Rollback testato.
- [ ] Evidenze change conservate.

---

## 15. Fonti ufficiali

- GoldenGate Security Guide 19c: https://docs.oracle.com/en/middleware/goldengate/core/19.1/securing/oracle-goldengate-security.pdf
- Securing Deployments 19c: https://docs.oracle.com/en/middleware/goldengate/core/19.1/securing/securing-deployments.html
- Network / Reverse Proxy 19c: https://docs.oracle.com/en/middleware/goldengate/core/19.1/securing/network.html
- Target-Initiated Distribution Paths 19c: https://docs.oracle.com/en/middleware/goldengate/core/19.1/securing/source-initiated-and-target-initiated-distribution-paths.html
- Add Target-Initiated Distribution Path 19c: https://docs.oracle.com/en/middleware/goldengate/core/19.1/coredoc/distribute-add-target-initiated-distribution-paths.html
- Secure Data in Transit 26ai: https://docs.oracle.com/en/database/goldengate/core/26/coredoc/secure-data-transit.html
- GoldenGate Connectivity and Certifications: https://www.oracle.com/integration/goldengate/certifications/

## Obiettivo
Definire l’adozione GoldenGate in contesti bancari critici rispettando requisiti di sicurezza, continuità e governance.

## Procedura operativa
Applicare segmentazione rete, hardening host, controllo accessi, change process e runbook di escalation per ambienti regolati.

## Validazione finale
Validare audit trail, segregazione ruoli, SLA di lag/availability e conformità ai controlli operativi richiesti.

## Troubleshooting rapido
In caso di incidente, seguire flusso war-room: evidenze log, impatto transazionale, rollback controllato ed escalation compliance.
