# UC01 - GoldenGate per No Downtime Migrations

> Obiettivo: migrare o aggiornare un database con downtime applicativo ridotto al minimo, usando initial load + CDC + cutover controllato.

Guide correlate:

- [Migrazione GoldenGate Oracle -> Oracle](../GUIDA_MIGRAZIONE_GOLDENGATE.md)
- [Prerequisiti DB e Architettura](../GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md)
- [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md)
- [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md)

---

## 1. Quando usarlo

Usalo quando devi fare:

- upgrade Oracle, per esempio 11g/12c verso 19c;
- migrazione da filesystem ad ASM;
- migrazione single instance verso RAC;
- migrazione on-prem verso OCI o altro cloud;
- migrazione cross-platform supportata;
- consolidamento su nuovo hardware.

Non e' la scelta piu semplice se devi fare solo disaster recovery Oracle->Oracle: per quello Data Guard e' spesso piu adatto. GoldenGate serve quando vuoi replica logica, trasformazioni, migrazione eterogenea o cutover applicativo flessibile.

---

## 2. Architettura

```text
SOURCE DB                  GOLDENGATE                    TARGET DB
=========                  ==========                    =========
App attiva                 Extract                       DB nuovo
Online redo/archivelog --> Local trail --> Pump/Dist --> Remote trail --> Replicat
Initial load ------------ Data Pump/RMAN/expdp/impdp ------------------> Dati base
CDC ---------------------------------------------------------------> Delta continuo
```

---

## 3. Fasi operative

| Fase | Attivita | Output atteso |
|---|---|---|
| Assessment | oggetti, PK, datatype, LOB, volume redo, downtime ammesso | matrice compatibilita |
| Target build | install DB, patch, charset, tablespace, utenti | target pronto |
| Prerequisiti GG | logging, supplemental logging, GGADMIN, credential store | capture sicuro |
| Initial load | Data Pump/RMAN/logical export | dati iniziali caricati |
| CDC | Extract/Pump/Replicat | target in sync |
| Validation | conteggi, checksum, Veridata/query | differenze note o zero |
| Cutover | stop app, drain, sync finale, switch connection string | app su target |
| Fallback | finestra rollback o reverse replication | piano approvato |

---

## 4. Checklist tecnica

```sql
-- Source Oracle
SELECT force_logging, supplemental_log_data_min FROM v$database;
SHOW PARAMETER enable_goldengate_replication;
SELECT log_mode FROM v$database;

-- Tabelle senza PK o unique key
SELECT owner, table_name
FROM   dba_tables t
WHERE  owner NOT IN ('SYS','SYSTEM')
AND    NOT EXISTS (
  SELECT 1
  FROM   dba_constraints c
  WHERE  c.owner = t.owner
  AND    c.table_name = t.table_name
  AND    c.constraint_type IN ('P','U')
);
```

---

## 5. Regole per ambienti bancari

- Non fare cutover senza test di riconciliazione documentato.
- Non usare password in chiaro nei parameter file.
- Non aprire firewall source->target se l'architettura richiede target-initiated path.
- Non fare DDL non governato durante la finestra di migrazione.
- Non cancellare archive log necessari a Extract.
- Non promettere RPO zero: GoldenGate e' logico e asincrono nella maggior parte dei casi.

---

## 6. Cutover runbook minimo

```text
1. Congela change applicativi non essenziali.
2. Verifica Extract lag = 0 o vicino a 0.
3. Verifica Replicat lag = 0.
4. Stop applicazione o mettila read-only.
5. Forza log switch sul source.
6. Aspetta checkpoint finale.
7. Esegui query di riconciliazione.
8. Punta applicazione al target.
9. Monitora errori applicativi e Replicat.
10. Mantieni source in stato fallback per finestra concordata.
```

---

## 7. Domande tecniche

**Perche' serve initial load se ho CDC?**

Perche' CDC cattura le modifiche da un punto nel tempo. Il target deve prima avere una copia consistente dei dati base; poi GoldenGate applica i delta.

**Qual e' il rischio principale?**

Perdere allineamento tra SCN initial load e inizio capture oppure non gestire oggetti senza chiave.

**GoldenGate sostituisce Data Guard?**

No. GoldenGate fa replica logica e migrazione; Data Guard fa DR fisico Oracle. In ambienti enterprise spesso convivono.

---

## Percorso operativo da zero

Prima di implementare questo use case in laboratorio o in UAT:

1. Leggi [Prerequisiti DB e Architettura](../GUIDA_GOLDENGATE_PREREQUISITI_DB_ARCHITETTURA.md).
2. Applica [Grant e Privilegi 19c](../GUIDA_GOLDENGATE_GRANTS_PRIVILEGI_19C.md).
3. Configura [Collegamento Source e Target](../GUIDA_GOLDENGATE_COLLEGAMENTO_SOURCE_TARGET.md).
4. Valida rete e sicurezza con [Ambienti critici/bancari](../GUIDA_GOLDENGATE_AMBIENTI_CRITICI_BANCARI.md).
5. Usa [Cheat Sheet GoldenGate 19c](../CHEAT_SHEET_GOLDENGATE_19C.md) per i comandi rapidi.

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
## Approfondimento specifico UC01

Per una migrazione zero-downtime completa, documenta sempre:

- SCN o timestamp di consistenza dell'initial load;
- punto di partenza Extract coerente con l'export/import;
- lista tabelle escluse o gestite manualmente;
- grants target per Replicat prima del primo start;
- strategia sequence/identity dopo cutover;
- finestra in cui il source resta disponibile per rollback;
- criterio ufficiale di successo: lag zero, conteggi coerenti, app connessa al target.

Errore tipico: partire con Extract dopo l'initial load senza allineare SCN. Il risultato puo' essere perdita o duplicazione logica.