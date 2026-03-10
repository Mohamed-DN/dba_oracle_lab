# 04 — User Management (Gestione Utenti)

> Procedure per la creazione e gestione degli utenti Oracle in ambiente Enterprise.
> Include prototipi per utenti nominali, applicativi, DBA operativi, e integrazione con ServiceNow.

---

## Tipologie di Utenti in un Ambiente Enterprise

| Tipo | Descrizione | Esempio |
|---|---|---|
| **Nominale** | Utente personale del DBA/sviluppatore | `MROSSI` |
| **DBA Operativo** | Account DBA con ruoli elevati | `DBA_OP` |
| **Applicativo** | Account usato dalle applicazioni | `APP_PAYMENTS` |
| **Profilo 0** | Account di servizio con tracking automatico | `SVC_BATCH` |

---

## File Contenuti

### Prototipi per Creazione Utenti
- `Prototipo_CreateUser_Nominale_v1.4.txt` — Template per utenti nominali (ultima versione)
- `Prototipo_CreateUser_DBA_OP_v1.3.txt` — Template per DBA operativi
- `Prototipo_CreateUser_DB_APPLICATIVA_v1.3.txt` — Template per utenti applicativi
- `Prototipo_CreateUser_DBA_v1.1.txt` — Template per utenti DBA

### Gestione Password e Profili
- `Verify Function PWD.txt` — Funzione di verifica complessità password
- `GeneraPass_Random_da_Bash.txt` — Script bash per generare password random sicure

### Profilo 0 (Tracking Automatico)
- `PROFILO_0_create_table.sql` — Tabella di tracciamento utenze
- `PROFILO_0_create_procedure.sql` — Procedura di purge automatica
- `PROFILO_0_crea_script_USER.sql` — Script di creazione utente Profilo 0

### Integrazione ServiceNow
- `Creazione_utenze_tutti_i_case.sql` — Tutti i casi di creazione utenze via ticket
- `creazione_utenza_sv.sql` — Creazione utenza da ServiceNow
- `droppare_utenza.sql` — Drop utenza completa

### Package User Remote
- `pkg_user_remote_v1.8.sql` — Package per gestione utenti remoti (produzione)

---

## 🔗 Collegamento
Vedi anche: [GUIDE_CDB_PDB_USERS.md](../../GUIDE_CDB_PDB_USERS.md)
