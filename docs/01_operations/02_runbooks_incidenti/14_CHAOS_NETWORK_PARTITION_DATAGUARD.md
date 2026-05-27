# 14 — Chaos Engineering: Network Partition su Data Guard

## Obiettivi

Simulare scenari di instabilità di rete (latenza e perdita pacchetti) tra i nodi Primary e Standby per testare la resilienza della configurazione Data Guard e la capacità di riallineamento automatico.

## Procedura Operativa

### Esempio di Simulazione

Su nodo primary (test lab):

```bash
# aggiunge latenza artificiale 250ms + jitter 50ms
sudo tc qdisc add dev eth0 root netem delay 250ms 50ms

# opzionale: perdita pacchetti 5%
sudo tc qdisc change dev eth0 root netem delay 250ms 50ms loss 5%
```

Su standby, osserva:

```sql
SELECT name, value, unit FROM v$dataguard_stats
WHERE name IN ('transport lag','apply lag');
```

Ripristino rete:

```bash
sudo tc qdisc del dev eth0 root
```

## Validazione Finale

Pass criteria:

- [ ] broker resta `SUCCESS` o `WARNING` non critico
- [ ] `apply lag` torna sotto soglia target entro 15 minuti dal rollback
- [ ] nessun gap permanente dopo ripristino rete

Fail criteria:

- broker in `ERROR` persistente
- apply fermo > 15 minuti post-ripristino

## Troubleshooting

- **tc command non disponibile**: installare `iproute-tc`.
- **lag non rientra**: verificare MRP, archive shipping e rete host-only.
- **errore broker**: usare `show database verbose` e correggere connect identifier/listener.
