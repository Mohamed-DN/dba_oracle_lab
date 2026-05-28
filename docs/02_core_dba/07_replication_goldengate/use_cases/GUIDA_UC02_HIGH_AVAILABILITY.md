# UC02 - GoldenGate per High Availability

> Obiettivo: usare GoldenGate per resilienza logica, live standby applicativo o active-active controllato. Non confonderlo con Data Guard fisico.

Guide correlate:

- [GoldenGate 19c Completa](../GUIDA_GOLDENGATE_19C_COMPLETA.md)
- [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md)
- [Q&A Tecnico GoldenGate](../GUIDA_GOLDENGATE_QA_PROFESSIONALE.md)

Fonti Oracle utili:

- Active-active GoldenGate 19c: https://docs.oracle.com/en/middleware/goldengate/core/19.1/admin/configuring-oracle-goldengate-active-active-high-availability.html
- Active-active vs active-passive 26ai: https://docs.oracle.com/en/database/goldengate/core/26/ggsol/active-active-vs-active-passive.html

---

## 1. Pattern HA supportati

```text
Pattern A - Active-passive logico
SITE A primary write  ----CDC----> SITE B standby logico
App scrive solo su A. B e' pronto per takeover applicativo.

Pattern B - Active-active controllato
SITE A read/write <----CDC----> SITE B read/write
Entrambi scrivono, ma serve conflict management.
```

---

## 2. Quando ha senso

- Applicazione deve continuare su target logico con schema compatibile ma non identico.
- Serve replica tra versioni Oracle diverse.
- Serve replica tra Oracle e database non Oracle.
- Serve active-active applicativo con partizionamento logico delle scritture.
- Serve HA per specifici schemi, non per tutto il database.

Se vuoi proteggere tutto il database Oracle con massimo allineamento fisico, Data Guard resta la prima scelta.

---

## 3. Rischi active-active

| Rischio | Spiegazione | Mitigazione |
| --- | --- | --- |
| Update/update conflict | stessa riga modificata su due siti | CDR, ownership dati, routing applicativo |
| Insert collision | stessa PK generata su entrambi i siti | sequence range, GUID, identity disegnata bene |
| Delete/update conflict | un sito cancella, l'altro aggiorna | regole CDR e design funzionale |
| Loop replication | una modifica replicata torna indietro | loop detection, tag, parametri corretti |
| DDL drift | schema diverso tra siti | change governance e deploy coordinato |

---

## 4. Checklist HA enterprise

```text
[ ] Definire se active-passive o active-active.
[ ] Definire RTO/RPO realistici.
[ ] Definire ownership delle scritture.
[ ] Definire gestione sequence/identity.
[ ] Definire CDR se active-active.
[ ] Definire test split-brain applicativo.
[ ] Definire procedura takeover/fallback.
[ ] Integrare monitoring lag nel sistema NOC/SIEM.
[ ] Eseguire riconciliazione dati periodica.
```

---

## 5. Disegno consigliato per banca

```text
          +--------------------+              +--------------------+
          | DC1 / Zone A       |              | DC2 / Zone B       |
          | Oracle RAC         |              | Oracle RAC/Target  |
          | OGG Extract        |              | OGG Replicat       |
          +---------+----------+              +----------+---------+
                    | TLS/WSS, porte approvate, audit      ^
                    +---------------------------------------+
```

Regole:

- niente comunicazioni non documentate;
- TLS obbligatorio su tratte inter-zone;
- wallet e credential store protetti;
- trail cifrati o filesystem cifrato secondo policy;
- alert immediato su lag e abend.

---

## 6. Domande tecniche

**Active-active e' sempre meglio?**

No. E' piu complesso. Se l'applicazione non e' progettata per scrivere su due siti, active-active crea conflitti e rischio dati.

**Che differenza c'e' con Data Guard?**

Data Guard replica fisicamente redo Oracle e protegge tutto il database. GoldenGate replica logicamente subset di dati e puo' fare eterogeneo, trasformazioni e active-active applicativo.

**Cosa guardi in produzione?**

Lag, abend, checkpoint, trail retention, archive retention, errori discard, conflitti CDR, stato rete e validazione dati.

---

## Percorso operativo da zero

Prima di implementare questo use case in laboratorio o in UAT:

1. Leggi [Prerequisiti DB e Architettura](../GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md).
2. Applica [Grant e Privilegi 19c](../GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).
3. Configura [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md).
4. Valida rete e sicurezza con [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md).
5. Esegui il [Runbook End-to-End 19c](../GUIDA_GOLDENGATE_RUNBOOK_END_TO_END_19C.md).
6. Usa [Cheat Sheet GoldenGate 19c](../GUIDA_GOLDENGATE_19C_CHEAT_SHEET.md) per i comandi rapidi.

Grant minimi da non saltare:

```text
Oracle source: CREATE SESSION + DBMS_GOLDENGATE_AUTH privilege_type CAPTURE o *
Oracle target: DBMS_GOLDENGATE_AUTH privilege_type APPLY o * + grant DML sulle tabelle target
PostgreSQL target: CONNECT + USAGE schema + SELECT/INSERT/UPDATE/DELETE sulle tabelle
PostgreSQL source: CONNECT + WITH REPLICATION + eventuale admin temporaneo per TRANDATA
```

Criterio di avanzamento:

```text
[ ] DBLOGIN funziona con USERIDALIAS.
[ ] Supplemental logging e' attivo sugli oggetti replicati.
[ ] Extract/Replicat partono senza ORA-01031.
[ ] Lag e checkpoint sono monitorati.
[ ] Esiste rollback o re-sync plan.
[ ] I dati sensibili sono autorizzati e protetti.
```
## Approfondimento specifico UC02

Per HA logica non basta configurare due Replicat. Devi definire il modello di scrittura:

- active-passive: solo un sito scrive, l'altro riceve;
- active-active partizionato: ogni sito possiede un sottoinsieme di dati;
- active-active completo: richiede CDR, test conflitti e disegno applicativo.

Prima di proporre active-active in banca, prepara una matrice conflitti:

| Conflitto | Decisione richiesta |
| --- | --- |
| insert stessa PK | range sequence, GUID o ownership sito |
| update stessa riga | last writer wins, timestamp, regola funzionale |
| delete/update | delete vince o update viene scartato |
| DDL non allineato | freeze DDL o deploy coordinato |

Senza questa matrice, active-active e' un rischio dati, non una soluzione HA.
