# 14 - Chaos Engineering: Network Partition su Data Guard

## Obiettivi

Simulare in laboratorio latenza o perdita pacchetti sulla sola rete Data Guard,
verificare alerting e misurare il riallineamento dopo il rollback. Non usare
questa procedura in produzione senza change specifico.

## Procedura operativa

### 1. Preflight

Registra:

| Campo | Valore |
| --- | --- |
| Ambiente non produttivo | `<OK/KO>` |
| Host e interfaccia DG | `<HOST>` / `<DG_INTERFACE>` |
| Regola `tc` iniziale | `<NESSUNA oppure OUTPUT>` |
| Broker prima del test | `<SUCCESS/WARNING>` |
| FSFO | `<DISABLED/OBSERVE_ONLY>` |
| Lag iniziale | `<TRANSPORT>` / `<APPLY>` |
| Owner rollback | `<NOME>` |

Per un drill di solo trasporto lascia FSFO disabilitato oppure in observe-only.
La promozione automatica richiede un drill separato.

### 2. Introduci latenza

Sul nodo e sull'interfaccia approvati:

```bash
sudo tc qdisc show dev <DG_INTERFACE>
sudo tc qdisc add dev <DG_INTERFACE> root netem delay 250ms 50ms
```

Opzionale:

```bash
sudo tc qdisc change dev <DG_INTERFACE> root netem delay 250ms 50ms loss 5%
```

Osserva sullo standby:

```sql
SELECT name, value, unit
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');

SELECT process, status, thread#, sequence#
FROM v$managed_standby;
```

### 3. Rollback rete

Esegui sempre, anche se il test fallisce:

```bash
sudo tc qdisc del dev <DG_INTERFACE> root
sudo tc qdisc show dev <DG_INTERFACE>
```

### 4. Verifica riallineamento

Sullo standby:

```sql
SELECT thread#, low_sequence#, high_sequence#
FROM v$archive_gap;

SELECT name, value, unit
FROM v$dataguard_stats
WHERE name IN ('transport lag', 'apply lag');
```

## Validazione finale

Pass criteria:

- regola `tc` rimossa;
- primary rimasto disponibile;
- lag rientrato entro soglia;
- nessun gap permanente;
- Broker tornato `SUCCESS`.

Fail criteria:

- regola rete ancora attiva;
- apply fermo dopo rollback;
- gap persistente;
- role transition inattesa.

## Troubleshooting rapido

| Sintomo | Azione |
| --- | --- |
| `tc` assente | installa `iproute-tc` nel lab |
| interfaccia errata | rimuovi subito regola e ripeti assessment |
| lag non rientra | usa [Check Data Guard](./RUNBOOK_03_CHECK_DATAGUARD.md) |
| gap persistente | usa DG-062 nel runbook RMAN/Data Guard |
| FSFO scatta | ferma drill, verifica fencing e separazione test |
