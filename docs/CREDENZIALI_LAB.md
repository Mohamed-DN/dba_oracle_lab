# 🔐 Credenziali del Lab (ZDM & GoldenGate)

Visto l'elevato numero di utenze sparse tra Sistemi Operativi, Database On-Premise, Database in Cloud e Portali Web, ecco un riepilogo definitivo di tutte le password usate nel nostro Lab.

> [!WARNING]
> **Promemoria di Sicurezza:** 
> Ovviamente queste password vanno bene solo per un ambiente di test chiuso. In produzione, usa sempre password generate e conservale in un Password Manager.

---

## 1. OCI Cloud (Autonomous Database)
| Utente / Servizio | Username | Password | Note |
| :--- | :--- | :--- | :--- |
| **Admin ADB** | dmin | Sole_2482002 | L'amministratore supremo dell'Autonomous DB. |
| **GoldenGate Target ADB** | ggadmin | OggCloud_2026 | L'utente pre-installato da Oracle su ADB per ricevere i dati. |

---

## 2. On-Premise (RAC1 & ZDMNode)
| Utente / Servizio | Username | Password | Note |
| :--- | :--- | :--- | :--- |
| **GoldenGate Source DB** | c##ggadmin | GGadmin_2026 | L'utente creato da noi su ac1 per estrarre i dati. |
| **ZDM Linux User** | zdmuser | zdmuser | L'utente Linux su zdmnode. |

---

## 3. GoldenGate 23ai Hub (Bare Metal)
| Utente / Servizio | Username | Password | Note |
| :--- | :--- | :--- | :--- |
| **Service Manager Web** | oggadmin | OggAdmin_2026 | Amministratore globale di GoldenGate. |
| **User Deployment Web** | oggadmin | OggAdmin_2026 | Amministratore specifico del deployment zdm_hub. |
