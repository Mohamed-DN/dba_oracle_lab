# Reliability Framework (SLO/SLI/KPI)

## SLI principali
- **Backup Success Rate**: % job RMAN riusciti.
- **Data Guard Apply Lag**: secondi medi e p95.
- **RTO Drill Duration**: tempo medio drill DR.
- **Availability Lab Services**: uptime servizi RAC critici.

## SLO target
- Backup Success Rate >= 99% (mensile)
- DG Apply Lag p95 <= 60 secondi
- RTO drill <= 30 minuti
- Availability servizi critici >= 99.5%

## KPI operativi
- Numero incidenti P1/P2 al mese.
- MTTR medio per incidente.
- Percentuale runbook eseguiti con esito positivo.
- Percentuale drill DR completati on-schedule.

## Evidenze e review periodica
- Conservare artifact da `.github/workflows/dr-drill.yml`.
- Review mensile SLO in report operativo.
- Correggere runbook dove la validazione fallisce.
