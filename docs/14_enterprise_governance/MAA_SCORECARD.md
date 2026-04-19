# MAA Scorecard (Single Source of Truth)

La compliance MAA del repository è tracciata **solo** in:

- [`MAA_SCORECARD_SOURCE_OF_TRUTH.yml`](./MAA_SCORECARD_SOURCE_OF_TRUTH.yml)

## Regole operative

1. Non mantenere scorecard parallele in altri documenti.
2. Ogni controllo deve includere almeno una evidenza repository-based.
3. Gli stati ammessi sono: `implemented`, `partial`, `planned`.
4. Gli aggiornamenti alla scorecard devono passare via PR.

## Vista sintetica corrente

| Controllo | Stato |
|---|---|
| Data Guard Broker validation | partial |
| Protection parameters (`db_block_*`, `db_lost_write_protect`) | partial |
| Flashback readiness | partial |
| FSFO operationalization | planned |
| E2E evidence su PR | implemented |
| DR drills periodici con evidenze | implemented |
| Security gates | implemented |
| Release governance | implemented |
