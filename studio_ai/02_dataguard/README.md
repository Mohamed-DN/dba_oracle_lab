# 02 — Data Guard Management

> Procedure operative per la gestione di Oracle Data Guard in ambiente RAC Enterprise.
> Include configurazione, Active Data Guard, verifica GAP, e recovery post-reboot.

---

## Panoramica

Data Guard è il pilastro della Disaster Recovery in Oracle. In un ambiente Enterprise come Nexi,
la configurazione tipica prevede:
- **Primary RAC** (2 nodi) → **Standby RAC** (2 nodi)
- Trasporto LOG: **LGWR ASYNC** (per performance) o **LGWR SYNC** (per zero data loss)
- **Active Data Guard** per utilizzare lo standby in modalità READ ONLY con APPLY attivo

---

## File Contenuti

### [configurazione_dataguard.md](./configurazione_dataguard.md)
Procedura step-by-step per configurare Data Guard con DGMGRL Broker.

### [active_dataguard.md](./active_dataguard.md)
Configurazione Active Data Guard: aprire lo standby in READ ONLY con real-time apply.

### [verifica_gap.md](./verifica_gap.md)
Query SQL per verificare se ci sono GAP tra primary e standby (log non applicati).

### [service_read_only.md](./service_read_only.md)
Configurazione di un servizio dedicato per connessioni READ ONLY allo standby.

### [recovery_post_reboot.md](./recovery_post_reboot.md)
Procedura di recovery quando il Data Guard si rompe dopo un reboot del server.

---

## 🔗 Collegamento
Vedi anche: [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../../GUIDE_PHASE4_DATAGUARD_DGMGRL.md)
