# 08. Zero Downtime Migration (ZDM)

Questa directory contiene le guide architetturali, operative e di troubleshooting per eseguire migrazioni critiche tramite **Oracle Zero Downtime Migration (ZDM)**, in particolare verso Autonomous Database e infrastrutture cloud OCI.

## Guide Monumentali

| Guida | Descrizione | Scenario |
|---|---|---|
| [**Guida ZDM 26 Offline Logical verso ADB**](./GUIDA_ZDM_26_OFFLINE_LOGICAL_ADB.md) | La master guide su ZDM 26. Include l'analisi del comando `zdmcli`, il tuning del file `.rsp`, la bypass dei controlli SSH e la connessione post-migrazione via Wallet. | Da Oracle On-Prem a Cloud ADB tramite Object Storage |

## Roadmap e Tipologie di Migrazione (WIP)
In quest'area verranno successivamente integrate le procedure per:
- **Physical Online (Data Guard based)**
- **Logical Online (GoldenGate based)**
- **Migrazioni verso Base Database (DBaaS)**
