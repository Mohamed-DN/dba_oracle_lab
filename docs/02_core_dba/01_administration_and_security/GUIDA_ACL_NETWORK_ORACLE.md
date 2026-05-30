# Guida ACL Network Oracle 19c — Capirle e Gestirle

## Obiettivo

Capire come funzionano le ACL di rete Oracle (Network ACL) e configurarle in modo sicuro per consentire accessi in uscita (HTTP/SMTP/TCP) solo agli utenti/schemi autorizzati.

## Teoria

In Oracle 11g+ l'accesso di rete da PL/SQL (es. `UTL_HTTP`, `UTL_SMTP`, `UTL_TCP`) è negato di default.
Le ACL definiscono:

- **Chi** può uscire (utente/schema)
- **Verso dove** (host, wildcard, range porte)
- **Con quali privilegi** (`connect`, `resolve`)

Errori tipici quando manca ACL:

- `ORA-24247: network access denied by access control list (ACL)`
- `ORA-29273` con errore di rete sottostante

## Procedura Operativa

### 1) Verifica ACL attuali

```sql
sqlplus / as sysdba

SELECT host, lower_port, upper_port, acl
FROM dba_network_acls
ORDER BY host, lower_port;

SELECT acl, principal, privilege, is_grant
FROM dba_network_acl_privileges
ORDER BY acl, principal, privilege;
```

### 2) Concedi accesso ad host specifico (best practice)

```sql
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host       => 'api.internal.local',
    lower_port => 443,
    upper_port => 443,
    ace        => xs$ace_type(
      privilege_list => xs$name_list('connect','resolve'),
      principal_name => 'APP_SCHEMA',
      principal_type => xs_acl.ptype_db
    )
  );
END;
/
```

### 3) Esempio test con UTL_HTTP

```sql
CONN app_schema

DECLARE
  l_req  UTL_HTTP.req;
  l_resp UTL_HTTP.resp;
BEGIN
  l_req  := UTL_HTTP.begin_request('https://api.internal.local/health');
  l_resp := UTL_HTTP.get_response(l_req);
  UTL_HTTP.end_response(l_resp);
END;
/
```

### 4) Revoca ACL non più necessaria

```sql
BEGIN
  DBMS_NETWORK_ACL_ADMIN.REMOVE_HOST_ACE(
    host       => 'api.internal.local',
    lower_port => 443,
    upper_port => 443,
    ace        => xs$ace_type(
      privilege_list => xs$name_list('connect','resolve'),
      principal_name => 'APP_SCHEMA',
      principal_type => xs_acl.ptype_db
    )
  );
END;
/
```

## Esempio

Caso reale: integrazione applicativa che invia webhook HTTPS.

1. L'app usa package PL/SQL con `UTL_HTTP`.
2. Senza ACL: errore `ORA-24247`.
3. Con ACL puntuale su host+porta 443: chiamata riuscita.
4. Nessun permesso generico su wildcard non necessarie.

## Validazione Finale

```sql
SELECT host, lower_port, upper_port, acl
FROM dba_network_acls
WHERE host = 'api.internal.local';
```

```sql
SELECT acl, principal, privilege, is_grant
FROM dba_network_acl_privileges
WHERE principal = 'APP_SCHEMA';
```

Atteso:

- ACL presente su host/porta corretti
- privilegio `connect`/`resolve` assegnato solo al principal richiesto
- test `UTL_HTTP` senza errori ACL

## Troubleshooting Rapido

- **ORA-24247**: ACL mancante o principal errato.
- **ORA-29273 + timeout**: ACL ok ma rete/firewall/DNS non ok.
- **ORA-06512 su package custom**: controlla schema di esecuzione effettivo (definer/invoker rights).

## Hardening consigliato

- Evita wildcard host (`*`) se non indispensabili.
- Limita porte (es. solo 443).
- Gestisci ACL via script versionati + change ticket.
