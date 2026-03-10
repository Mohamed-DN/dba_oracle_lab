# 11 — SQL Templates (DDL/DML Standard)

> Template SQL standardizzati per le operazioni più comuni in ambiente Enterprise.
> Ogni template include header, spool, error handling, e rollback.

---

## Template Disponibili

### DDL (Data Definition Language)

| Template | Cosa Fa |
|---|---|
| `00X_Form_create_table.sql` | Creazione tabella con tutte le opzioni |
| `00X_Form_alter_table.sql` | Modifica struttura tabella (ADD/MODIFY/DROP column) |
| `00X_Form_drop_table.sql` | Drop tabella con verifica |
| `00X_Form_create_index.sql` | Creazione indice (B-tree, bitmap, function-based) |
| `00X_Form_alter_index.sql` | Rebuild/modifica indice |
| `00X_Form_create_view.sql` | Creazione vista |
| `00X_Form_primary_key.sql` | Aggiunta primary key |
| `00X_Form_foreign_key.sql` | Aggiunta foreign key |

### DML (Data Manipulation Language)

| Template | Cosa Fa |
|---|---|
| `00X_Form_dml.sql` | INSERT/UPDATE/DELETE standard con COMMIT |
| `00X_Form_loop_commit.sql` | Loop con COMMIT ogni N righe (per tabelle grandi) |
| `Form_loop_rowid.sql` | Loop per ROWID range (performance) |

### Programmatic

| Template | Cosa Fa |
|---|---|
| `00X_Form_procedure.sql` | Creazione stored procedure |
| `00X_Form_package.sql` | Creazione package (spec + body) |
| `00X_Form_trigger.sql` | Creazione trigger |
| `00X_Form_sequence.sql` | Creazione sequence |
| `00X_Form_sinonimi.sql` | Creazione sinonimi |

### Permessi

| Template | Cosa Fa |
|---|---|
| `00X_Form_assign_grant.sql` | Assegnazione GRANT su oggetti |

---

## Perché usare Template?

In un'azienda con decine di DBA e centinaia di sviluppatori, i template garantiscono:
1. **Consistenza**: Tutti gli script hanno lo stesso formato
2. **Tracciabilità**: Header con autore, data, ticket, e descrizione
3. **Sicurezza**: Include spool e rollback automatico in caso di errore
4. **Compliance**: Facilita l'audit e la review del codice
