# Changelog — Oracle DBA Enterprise Lab

Tutte le modifiche significative a questo progetto saranno documentate in questo file.

## [Unreleased]

### Added

- **Fase 4B Observer FSFO**: guida operativa per Observer dedicato, wallet SEPS,
  attivazione graduale e backup Observer opzionale.
- **Dossier Colloquio Oracle DBA Produzione**: 260 domande tecniche, 15 drill
  Severity 1, piano di ripasso e mock interview.
- **SOP Enterprise M24SHAMS Staging Data Guard**: documentazione specifica per
  single instance non-CDB 19c su Oracle Restart, allegato host, run sheet e
  artifact DOCX/PDF per il change operativo.

### Changed

- **Data Guard FSFO**: consolidati setup, rollback e drill nella nuova fase core.
- **RMAN Recover Table**: resa visibile la procedura di recupero tabella nei
  riferimenti rapidi e corretta la sintassi didattica.
- **FRA e Data Guard**: rafforzati i guardrail operativi per `ORA-00257`
  quando lo standby e' in lag o irraggiungibile.
- **Bonifica documentale**: riscritti i cataloghi RMAN/Data Guard e SQL tuning
  come playbook leggibili; rimossi boilerplate nel dossier, link locali
  malformati, artefatti encoding ed esempi con password in command line.
- **CI documentale**: rimosso il job Markdown lint cosmetico; restano link
  check, conformita' didattica, ShellCheck, sicurezza e governance.
- **Indici README**: riallineata la mappa root con le directory operative,
  i 36 runbook disponibili e il percorso opzionale di containerizzazione.

## [2.0.0] - 2026-05-14
### Added
- **Governance Framework**: Introdotta la directory `docs/04_governance_learning/02_enterprise_standards/` con MAA Scorecard, SRE Framework e GitOps Policy.
- **26ai Readiness**: Creata la guida massiva `GUIDA_UPGRADE_19C_TO_26AI.md` e la guida alla containerizzazione Podman/Docker per Oracle 26ai.
- **Advanced Monitoring**: Espansa la guida CheckMK con monitoraggio AI Vector Search, automazione Ansible e integrazione Grafana.
- **GoldenGate MA**: Nuova guida all'architettura a Microservizi (MA) su OCI e on-prem.
- **Incident Management**: Creato il `TROUBLESHOOTING_DECISION_TREE.md` come KEDB professionale.
- **Security Baseline**: Definito il `PRODUCTION_PROFILE.md` per l'hardening dei database di produzione.

### Changed
- **Repository Restructure**: Riorganizzazione completa in 4 aree (Operations, Core DBA, Infra Lab, Governance) per allineamento agli standard ITIL.
- **Link Integrity**: Ripristinati e validati oltre 200 collegamenti ipertestuali tra le guide.
- **Ansible Standard**: Ridenominazione dei playbook per eliminare prefissi numerici e adottare nomi descrittivi enterprise.
- **Terraform Evolution**: Aggiornato il README di infrastruttura IaC con focus su GitOps e OCI Vault.

### Removed
- **Redundancy**: Eliminati vecchi file di guida duplicati e script di generazione temporanei.

## [1.5.0] - 2026-04-27
### Added
- Oracle Enterprise Manager 24ai installation guide.
- Fast-Start Failover (FSFO) with Observer implementation.

## [1.0.0] - 2026-02-17
### Added
- Base RAC + Data Guard laboratory with Vagrant.
- RMAN basic backup strategies.
- OPatch mandatory update policy.

---
**Formato basato su [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).**
