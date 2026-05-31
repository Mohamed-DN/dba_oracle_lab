# Obiettivi di apprendimento + Checklist Done (Fasi 0-8)

## Fase 0 - Setup Macchine

**Obiettivi**
- Comprendere topologia lab e rete.
- Provisionare VM con risorse corrette.
- Verificare naming/IP coerenti.

**Done checklist**
- [ ] VM create secondo piano IP
- [ ] DNS operativo
- [ ] storage base pronto
- [ ] track OS registrato: OL7.9 legacy oppure OL8 raccomandato
- [ ] Observer manuali censiti: `observer1`, `observer2` opzionale

## Fase 1 - Preparazione OS

**Obiettivi**
- Configurare prerequisiti OS Oracle.
- Impostare utenti, kernel, limiti.
- Uniformare hardening base.

**Done checklist**
- [ ] prerequisiti pacchetti installati
- [ ] utenti/gruppi Oracle coerenti
- [ ] parametri kernel validati

## Fase 2 - Grid + RAC

**Obiettivi**
- Installare Grid Infrastructure.
- Configurare ASM e diskgroup.
- Creare database RAC.

**Done checklist**
- [ ] CRS online
- [ ] ASM diskgroup disponibili
- [ ] istanze DB in stato OPEN
- [ ] `RACDB` verificato come `CDB=YES`
- [ ] `RACDBPDB` aperta `READ WRITE` su entrambe le istanze

## Fase 3 - RAC Standby

**Obiettivi**
- Preparare sito standby RAC.
- Eseguire duplicate RMAN.
- Stabilire prerequisiti Data Guard.

**Done checklist**
- [ ] standby mount/read-only secondo fase
- [ ] redo/apply allineati
- [ ] listener statico valido
- [ ] PDB `RACDBPDB` replicata nel physical standby

## Fase 4 - Data Guard Broker

**Obiettivi**
- Configurare DGMGRL broker.
- Verificare apply/transport lag.
- Simulare switchover controllato.

**Done checklist**
- [ ] `show configuration` = SUCCESS
- [ ] apply lag entro soglia lab
- [ ] switchover testato e rollback eseguito

## Fase 4B - Observer Server e FSFO

**Obiettivi**
- Installare Oracle Client Administrator su un host Observer dedicato.
- Configurare wallet SEPS e FSFO in zero data loss mode.
- Validare Observer master e backup opzionale.

**Done checklist**
- [ ] `VALIDATE FAST_START FAILOVER` senza blocchi
- [ ] `SHOW FAST_START FAILOVER` = enabled in zero data loss mode
- [ ] `observer1` registrato e raggiungibile

## Fase 5 - RMAN Backup

**Obiettivi**
- Definire policy backup/recovery.
- Eseguire backup completo e archivelog.
- Validare restore test minimo.

**Done checklist**
- [ ] job backup completati
- [ ] catalogo/backuppiece verificati
- [ ] restore test con esito PASS
- [ ] deletion policy Data Guard-aware verificata
- [ ] backup durevole esterno alla sola FRA disponibile

## Fase 6 - Enterprise Monitoring

**Obiettivi**
- Integrare monitoraggio DB/OS.
- Definire soglie allarme base.
- Rendere osservabili KPI principali.

**Done checklist**
- [ ] dashboard attiva
- [ ] alert policy caricata
- [ ] metriche core raccolte

## Fase 7 - GoldenGate

**Obiettivi**
- Comprendere flusso CDC.
- Configurare MA TLS: Extract, Distribution Path WSS e Replicat.
- Validare latenza replica.

**Done checklist**
- [ ] processi GG RUNNING
- [ ] trail file aggiornati
- [ ] test DML replicati PASS

## Fase 8 - Test Verifica

**Obiettivi**
- Eseguire test end-to-end.
- Raccogliere evidenze operative.
- Valutare readiness a produzione.

**Done checklist**
- [ ] test checklist completata
- [ ] KPI minimi centrati
- [ ] evidenze archiviate in `reliability/evidence/`
