# GUIDA: Checklist Operativa DBA

> Checklist pratica per trasformare il catalogo delle attivita DBA in una routine eseguibile.
> Usala nel lab come runbook operativo, poi adattala a produzione con owner, orari e SLA reali.

## 1. Checklist giornaliera

### Apertura giornata

- verifica stato database / istanze / servizi
- verifica listener e cluster resources
- controlla alert log e ultimi errori `ORA-`
- controlla ultimi backup RMAN
- controlla `SHOW CONFIGURATION` Data Guard e lag
- controlla tablespace critici, FRA e ASM disk group
- controlla incidenti o target down in Enterprise Manager

Evidenza minima:
- screenshot EM o output stato
- note su anomalie aperte
- owner assegnato per ogni issue

## 2. Checklist giornaliera su ticket o anomalie

- identifica se il problema e availability, performance, storage, security o rete
- raccogli evidenze prima di cambiare parametri
- salva query, output e orario evento
- fai una sola modifica per volta quando possibile
- verifica subito l'effetto della correzione
- aggiorna il runbook se il caso non era documentato

## 3. Checklist settimanale

- genera o analizza AWR / ADDM
- verifica `RESTORE VALIDATE`
- controlla crescita storage e trend tablespace
- rivedi job scheduler falliti e catene lunghe
- controlla utenti scaduti/bloccati e grant eccezionali
- verifica GG lag / processi se GoldenGate e attivo
- controlla invalid objects e warning applicativi noti

## 4. Checklist mensile

- review patch level, OPatch version e backlog RU/OJVM
- review capacity planning con crescita ultimo mese
- review auditing, privilegi potenti e directory object
- test di manutenzione controllata su servizi/listener
- review soglie e notifiche Enterprise Manager
- review documentazione operativa e rollback plan

## 5. Checklist trimestrale

- esegui switchover drill
- esegui restore drill o clone di recovery
- prova failover/reinstate nel lab
- review completa sicurezza, wallet, backup wallet, utenti privilegiati
- pulizia backlog runbook e standardizzazione naming/script

## 6. Checklist pre-change

- definisci obiettivo, finestra, owner e rollback
- verifica backup recente e restore path credibile
- salva baseline: stato servizi, lag DG, patch level, top alert, parametri chiave
- verifica spazio sufficiente per patch / export / clone / recovery
- verifica impatto su RAC, Data Guard, GoldenGate, EM
- prepara query di post-check prima di iniziare

## 7. Checklist post-change

- verifica startup e stato servizi
- verifica alert log e nuovi errori
- verifica Data Guard, backup, scheduler e monitoraggio
- verifica performance di base rispetto alla baseline
- documenta cosa e cambiato davvero
- chiudi solo se hai evidenza tecnica, non per assenza di errori visibili

## 8. Checklist per incident response

- classifica il problema: crash, lag, space issue, lock, security, rete
- stabilisci subito l'impatto: utenti, servizi, RPO/RTO, rischio dati
- evita cambi multipli non tracciati
- usa viste e tool corretti prima di riavviare
- valuta se serve escalation immediata su storage, OS, network o security
- salva root cause, workaround e fix definitivo separatamente

## 9. Checklist per refresh / clone / Data Pump

- conferma sorgente, target e versione
- verifica privilegi richiesti
- verifica spazio dump o destinazione clone
- verifica mapping schema/tablespace/PDB
- valida import o clone con oggetti, invalids e statistiche
- documenta tempi reali e colli di bottiglia

## 10. Checklist per backup e recovery readiness

- backup full/incremental riusciti
- archivelog backup coerente
- controlfile e spfile protetti
- retention valida
- crosscheck e delete obsolete eseguiti secondo policy
- ultimo restore test documentato
- recovery path noto per datafile, tablespace, controlfile, spfile, PDB, table recovery

## 11. Checklist per HA/DR

- `SHOW CONFIGURATION` in `SUCCESS`
- lag trasporto/apply entro soglia
- protection mode coerente con la policy
- standby log presenti e apply attivo
- switchover readiness verificata
- observer / FSFO valutato se scenario lo richiede
- backup continuity verificata anche dopo role transition

## 12. Checklist per security

- review utenti con privilegi `ANY`, `DBA`, `EXP_FULL_DATABASE`, `IMP_FULL_DATABASE`
- review account dormienti, scaduti o non conformi
- review directory object e uso Data Pump
- review auditing e accessi amministrativi
- review wallet/TDE e backup wallet
- applica privilegio minimo con `SYSBACKUP`, `SYSDG`, `SYSKM` quando possibile

## 13. Sequenza consigliata nel tuo lab

1. usa [GUIDA_CATALOGO_ATTIVITA_DBA.md](./GUIDA_CATALOGO_ATTIVITA_DBA.md) per vedere il perimetro completo
2. esegui la checklist giornaliera per una settimana
3. fai una settimana con AWR, RMAN validate e review security
4. fai uno switchover drill
5. fai un restore test
6. chiudi con review EM + MAA

## 14. Guide del repo da tenere affiancate

- [GUIDA_ATTIVITA_DBA.md](../GUIDA_ATTIVITA_DBA.md)
- [GUIDA_COMANDI_DBA.md](../GUIDA_COMANDI_DBA.md)
- [GUIDA_RMAN_COMPLETA_19C.md](../GUIDA_RMAN_COMPLETA_19C.md)
- [GUIDA_FASE4_DATAGUARD_DGMGRL.md](../GUIDA_FASE4_DATAGUARD_DGMGRL.md)
- [GUIDA_LISTENER_SERVICES_DBA.md](../GUIDA_LISTENER_SERVICES_DBA.md)
- [GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md](../GUIDA_FASE6_ENTERPRISE_MANAGER_13C.md)
