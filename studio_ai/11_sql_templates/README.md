# 11 — SQL Templates (DDL/DML Standard)

> Standardized SQL templates for the most common operations in the Enterprise environment.
> Ogni template include header, spool, error handling, e rollback.

---

## Template Disponibili

### DDL (Data Definition Language)

| Template | What He Does |
|---|---|
| `00X_Form_create_table.sql` | Creation of table with all options |
| `00X_Form_alter_table.sql` | Modify table structure (ADD/MODIFY/DROP column) |
| `00X_Form_drop_table.sql` | Drop table with verification |
| `00X_Form_create_index.sql` | Index creation (B-tree, bitmap, function-based) |
| `00X_Form_alter_index.sql` | Rebuild/modifica indice |
| `00X_Form_create_view.sql` | View creation |
| `00X_Form_primary_key.sql` | Added primary key |
| `00X_Form_foreign_key.sql` | Added foreign key |

### DML (Data Manipulation Language)

| Template | What He Does |
|---|---|
| `00X_Form_dml.sql` | Standard INSERT/UPDATE/DELETE with COMMIT |
| `00X_Form_loop_commit.sql` | Loop with COMMIT every N rows (for large tables) |
| `Form_loop_rowid.sql` | Loop per ROWID range (performance) |

### Programmatic

| Template | What He Does |
|---|---|
| `00X_Form_procedure.sql` | Creation of stored procedures |
| `00X_Form_package.sql` | Package creation (spec + body) |
| `00X_Form_trigger.sql` | Trigger creation |
| `00X_Form_sequence.sql` | Sequence creation |
| `00X_Form_sinonimi.sql` | Creation of synonyms |

### Permessi

| Template | What He Does |
|---|---|
| `00X_Form_assign_grant.sql` | Assegnazione GRANT su oggetti |

---

## Why use Template?

In a company with dozens of DBAs and hundreds of developers, templates ensure:
1. **Consistency**: All scripts have the same format
2. **Traceability**: Header with author, date, ticket, and description
3. **Sicurezza**: Include spool e rollback automatico in caso di errore
4. **Compliance**: Facilita l'audit e la review del codice
