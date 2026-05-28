# 33 - Audit, Compliance ed Evidence Operativa

<!-- READY_SCRIPTS_START -->
## Script e guide collegati

- [tde_security scripts](../04_libreria_script_completa/tde_security/) - audit trail, session audit, audit actions.
- [13_monitor_ddl_package.sql](../03_scripts_pronti/13_monitor_ddl_package.sql) - audit DDL operativo.
- [Security Hardening](../../02_core_dba/01_administration_and_security/GUIDA_SECURITY_HARDENING.md)
- [Package Monitor DDL](../../02_core_dba/01_administration_and_security/GUIDA_PACKAGE_MONITOR_DDL.md)
<!-- READY_SCRIPTS_END -->

## Obiettivo

Standardizzare cosa raccogliere prima/dopo un intervento DBA in ambienti regolati: produzione bancaria, assicurativa, PA critica o audit ISO/SOX/GDPR.

## Regola base

Ogni intervento deve rispondere a cinque domande:

1. Chi ha autorizzato?
2. Chi ha eseguito?
3. Cosa e stato eseguito?
4. Quando e su quale target?
5. Come e stato validato o ripristinato?

## Evidence minima per ticket

```text
Ticket/change:
Ambiente:
DB/istanza/PDB:
Host:
Owner applicativo:
Richiedente:
Approvatore:
Orario inizio/fine:
Comandi eseguiti:
Output prima:
Output dopo:
Rollback disponibile:
Rischio residuo:
```

## Identita e sessione operatore

```sql
set lines 220 pages 200
select
  sys_context('USERENV','SESSION_USER') session_user,
  sys_context('USERENV','CURRENT_USER') current_user,
  sys_context('USERENV','AUTHENTICATED_IDENTITY') authenticated_identity,
  sys_context('USERENV','HOST') host,
  sys_context('USERENV','IP_ADDRESS') ip_address,
  sys_context('USERENV','CON_NAME') con_name
from dual;
```

Su Linux:

```bash
id
whoami
hostname -f
date
tty
```

## Snapshot before/after standard

Database:

```sql
select name, open_mode, database_role, force_logging from v$database;
select instance_name, status, host_name, startup_time from gv$instance;
select con_id, name, open_mode from v$pdbs order by con_id;
```

Oggetti:

```sql
select owner, object_type, status, count(*)
from dba_objects
where owner in ('APP','APP_DBA')
group by owner, object_type, status
order by owner, object_type, status;
```

Invalidi:

```sql
select owner, object_type, object_name, status
from dba_objects
where status <> 'VALID'
order by owner, object_type, object_name;
```

Privilegi utente:

```sql
select * from dba_role_privs where grantee='APPUSER' order by granted_role;
select * from dba_sys_privs where grantee='APPUSER' order by privilege;
select * from dba_tab_privs where grantee='APPUSER' order by owner, table_name, privilege;
```

## Audit trail classico

```sql
set lines 220 pages 200
col username format a25
col action_name format a30
col obj_name format a40
col timestamp format a30

select username, action_name, owner, obj_name, returncode, timestamp
from dba_audit_trail
where timestamp > sysdate - 1
order by timestamp desc;
```

Sessioni recenti:

```sql
select username, userhost, terminal, timestamp, action_name, returncode
from dba_audit_session
where timestamp > sysdate - 1
order by timestamp desc;
```

## Unified Auditing

Verifica:

```sql
select parameter, value
from v$option
where parameter = 'Unified Auditing';
```

Query:

```sql
col event_timestamp format a35
col dbusername format a25
col action_name format a30
col object_schema format a25
col object_name format a40

select event_timestamp, dbusername, action_name, object_schema, object_name,
       return_code, unified_audit_policies
from unified_audit_trail
where event_timestamp > systimestamp - interval '24' hour
order by event_timestamp desc;
```

## Audit policy di base

Esempio da adattare a policy aziendale:

```sql
create audit policy DBA_CRITICAL_ACTIONS
  actions create user, alter user, drop user,
          create role, drop role,
          grant, revoke,
          alter system,
          alter database,
          create tablespace, alter tablespace, drop tablespace;

audit policy DBA_CRITICAL_ACTIONS;
```

Controllo:

```sql
select policy_name, enabled_option, entity_name, entity_type
from audit_unified_enabled_policies
order by policy_name, entity_name;
```

## DDL monitor applicativo

Per ambienti in cui serve evidenza DDL su schema applicativo, usare il package del repo:

```sql
@../03_scripts_pronti/13_monitor_ddl_package.sql
```

Prima di attivarlo:

- validare overhead;
- decidere retention tabella log;
- escludere ambienti di deployment massivo se necessario;
- avere approvazione security/app owner.

## Retention e purge audit

Non cancellare audit trail senza retention approvata. Prima:

```sql
select count(*), min(timestamp), max(timestamp)
from dba_audit_trail;
```

Se si usa `DBMS_AUDIT_MGMT`, documentare:

```sql
select audit_trail, last_archive_ts
from dba_audit_mgmt_last_arch_ts;
```

## Evidence per incidenti security

Raccogli senza alterare stato se possibile:

```sql
select username, account_status, lock_date, expiry_date, last_login
from dba_users
order by username;

select grantee, granted_role, admin_option, default_role
from dba_role_privs
where grantee not in ('SYS','SYSTEM')
order by grantee, granted_role;

select grantee, privilege, admin_option
from dba_sys_privs
where grantee not in ('SYS','SYSTEM')
order by grantee, privilege;
```

Per sospetto accesso non autorizzato, non droppare utenti o purgare log: aprire procedura incident/security.

## Chiusura

Un ticket compliance e chiuso solo quando contiene:

- output before/after;
- comandi o script versionati;
- approvazione;
- esito tecnico;
- eventuale deviazione dalla procedura;
- owner della prevenzione.
