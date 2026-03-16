# 02 — Data Guard Management

> Operating procedures for managing Oracle Data Guard in the RAC Enterprise environment.
> Includes configuration, Active Data Guard, GAP verification, and post-reboot recovery.

---

## Panoramica

Data Guard is the cornerstone of Disaster Recovery in Oracle. In an Enterprise environment like Nexi,
the typical configuration includes:
- **Primary RAC** (2 nodes) → **Standby RAC** (2 nodes)
- Trasporto LOG: **LGWR ASYNC** (per performance) o **LGWR SYNC** (per zero data loss)
- **Active Data Guard** to use standby in READ ONLY mode with APPLY active

---

## File Contenuti

### [dataguard_configuration.md](./dataguard_configuration.md)
Step-by-step procedure to set up Data Guard with DGMGRL Broker.

### [active_dataguard.md](./active_dataguard.md)
Active Data Guard configuration: open standby in READ ONLY with real-time apply.

### [gap_verification.md](./gap_verification.md)
SQL query to check if there are GAPs between primary and standby (logs not applied).

### [service_read_only.md](./service_read_only.md)
Configuring a dedicated service for READ ONLY connections on standby.

### [recovery_post_reboot.md](./recovery_post_reboot.md)
Recovery procedure when Data Guard breaks after a server reboot.

---

## 🔗 Collegamento
See also: [GUIDE_PHASE4_DATAGUARD_DGMGRL.md](../../GUIDE_PHASE4_DATAGUARD_DGMGRL.md)
