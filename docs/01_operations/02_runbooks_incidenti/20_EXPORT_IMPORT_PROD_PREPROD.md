# Procedura Export/Import da Database di Produzione a Pre-Produzione

Questa procedura descrive i passaggi completi per eseguire un export da un database di Produzione (Prod) e un import in un database di Pre-Produzione (Preprod).

## 1. Creare tutti i ruoli mancanti in Preprod
Prima di importare gli schemi, assicurarsi che tutti i ruoli custom necessari esistano nell'ambiente di destinazione.

Generare lo script dei ruoli in **Produzione** utilizzando lo script di sicurezza (vedi in fondo) o eseguire manualmente:
```sql
SELECT 'CREATE ROLE ' || role || ';' 
FROM dba_roles 
WHERE oracle_maintained = 'N';
```
Eseguire l'output in **Pre-Produzione**.

## 2. Creare tutte le Tablespace in Preprod
Verificare le tablespace necessarie per gli schemi da importare e crearle in Pre-Produzione.

Generare le DDL delle tablespace in **Produzione**:
```sql
SELECT dbms_metadata.get_ddl('TABLESPACE', tablespace_name) 
FROM dba_tablespaces 
WHERE tablespace_name NOT IN ('SYSTEM', 'SYSAUX', 'UNDOTBS1', 'TEMP');
```
Ricordarsi di adattare i percorsi dei datafiles prima di eseguire in Preprod.

## 3. Export degli Schemi (Produzione)
Eseguire l'export tramite Oracle Data Pump (`expdp`). In caso di database di grandi dimensioni, utilizzare i parametri `PARALLEL` e `COMPRESSION`.

Esempio di comando per export di più schemi:
```bash
expdp system/password@PROD_DB directory=DATA_PUMP_DIR \
      schemas=SCHEMA1,SCHEMA2 \
      dumpfile=exp_prod_%U.dmp \
      logfile=exp_prod.log \
      parallel=4 \
      compression=ALL
```

## 4. Spostare i file di Export
Spostare i file di dump generati dal server di Produzione al server di Pre-Produzione. Si può usare `scp -3` (attraverso un nodo intermedio) o `rsync`.

**Esempio con rsync:**
```bash
rsync -avz --progress /u01/app/oracle/admin/PROD_DB/dpdump/exp_prod_*.dmp oracle@preprod_server:/u01/app/oracle/admin/PREPROD_DB/dpdump/
```

## 5. Import degli Schemi (Pre-Produzione)
Eseguire l'import utilizzando `impdp`. 

> [!WARNING]  
> **Nota Archivelog:** In caso la dimensione dell'import sia gigante, gli archivelog si genereranno molto velocemente. Valutare di:
> - Modificare il crontab dei backup degli archivelog per eseguirlo più frequentemente durante l'import.
> - Aumentare lo spazio della FRA (Flash Recovery Area).
> - Se possibile e accettabile, mettere temporaneamente il DB o gli schemi/tabelle in NOLOGGING.

Esempio di comando per l'import:
```bash
impdp system/password@PREPROD_DB directory=DATA_PUMP_DIR \
      dumpfile=exp_prod_%U.dmp \
      logfile=imp_preprod.log \
      parallel=4 \
      table_exists_action=REPLACE
```

## 6. Controllare gli errori dell'Import
Al termine dell'import, verificare il file di log (`imp_preprod.log`) per identificare eventuali errori critici.
```bash
grep -i "ORA-" imp_preprod.log
```

## 7. Fare la Recompile degli Oggetti Invalidi
Effettuare una ricompilazione totale degli oggetti invalidi nel database di Pre-Produzione.
Eseguire come `SYSDBA`:
```sql
@?/rdbms/admin/utlrp.sql
```

## 8. Leggere gli Errori Rimasti (Oggetti ancora Invalidi)
Dopo la ricompilazione, controllare quali oggetti sono rimasti in stato `INVALID`:
```sql
SELECT owner, object_type, object_name, status
FROM dba_objects
WHERE status = 'INVALID'
ORDER BY owner, object_type;
```

## 9. Dare le Grant di Sistema e Ruoli Mancanti
Ripristinare le grant specifiche che potrebbero essersi perse o che non sono state importate completamente.
In questo esempio, si estraggono i ruoli concessi agli utenti `DWH` e `DBA_OP`:
```sql
SELECT 'GRANT "' || granted_role || '" TO "' || grantee || '"' ||
       CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION;' ELSE ';' END AS script_grant
FROM dba_role_privs
WHERE grantee IN ('DWH', 'DBA_OP')
ORDER BY grantee, granted_role;
```

Ripetere la ricompilazione se l'aggiunta di permessi potrebbe aver risolto le dipendenze:
```sql
@?/rdbms/admin/utlrp.sql
```

## 10. Controllo di Consistenza (Numero Oggetti e Dimensioni)
Controllare che gli schemi nei due ambienti (Prod e Preprod) abbiano lo stesso numero di oggetti e dimensioni comparabili.

**Numero di Oggetti per Schema:**
```sql
SELECT owner, object_type, count(*) 
FROM dba_objects 
WHERE owner IN ('SCHEMA1', 'SCHEMA2') 
GROUP BY owner, object_type 
ORDER BY owner, object_type;
```

**Dimensione degli Schemi:**
```sql
SELECT owner, sum(bytes)/1024/1024/1024 AS size_gb 
FROM dba_segments 
WHERE owner IN ('SCHEMA1', 'SCHEMA2') 
GROUP BY owner;
```

## 11. Controllare i DB_LINK
I Database Link non sempre vengono importati correttamente, in quanto le password sui DB Link preesistenti non possono essere estratte in chiaro. Inoltre in Pre-Produzione potrebbero puntare erroneamente ai DB di Produzione!
> **Riferimento:** Consultare la procedura dedicata: `21_GESTIONE_DB_LINK.md` per il reset e la gestione corretta post-clone.

---

## Allegato: Script Completo Export Sicurezza (export_sicurezza.sql)
Questo script può essere eseguito in Produzione per generare lo script DDL per ricreare l'intera alberatura dei ruoli, le grant di sistema e di oggetto.

```sql
SET LINESIZE 300
SET PAGESIZE 0
SET TRIMSPOOL ON
SET FEEDBACK OFF
SET VERIFY OFF

SPOOL export_sicurezza.sql

PROMPT -- ==============================================================
PROMPT -- 1. CREAZIONE DEI RUOLI CUSTOM
PROMPT -- ==============================================================
SELECT 'CREATE ROLE ' || role || ';' 
FROM dba_roles 
WHERE oracle_maintained = 'N';

PROMPT -- ==============================================================
PROMPT -- 2. GRANT DI SISTEMA ASSEGNATE AI RUOLI CUSTOM
PROMPT -- ==============================================================
SELECT 'GRANT ' || privilege || ' TO ' || grantee || 
       CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION;' ELSE ';' END 
FROM dba_sys_privs 
WHERE grantee IN (SELECT role FROM dba_roles WHERE oracle_maintained = 'N');

PROMPT -- ==============================================================
PROMPT -- 3. GRANT SUGLI OGGETTI (TABELLE/VISTE/PROC) AI RUOLI CUSTOM
PROMPT -- ==============================================================
SELECT 'GRANT ' || privilege || ' ON ' || owner || '."' || table_name || '" TO ' || grantee || 
       CASE WHEN grantable = 'YES' THEN ' WITH GRANT OPTION;' ELSE ';' END 
FROM dba_tab_privs 
WHERE grantee IN (SELECT role FROM dba_roles WHERE oracle_maintained = 'N')
ORDER BY grantee, owner, table_name;

PROMPT -- ==============================================================
PROMPT -- 4. RUOLI ASSEGNATI AD ALTRI RUOLI CUSTOM (RUOLI ANNIDATI)
PROMPT -- ==============================================================
SELECT 'GRANT ' || granted_role || ' TO ' || grantee || 
       CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION;' ELSE ';' END 
FROM dba_role_privs 
WHERE grantee IN (SELECT role FROM dba_roles WHERE oracle_maintained = 'N')
  AND granted_role IN (SELECT role FROM dba_roles WHERE oracle_maintained = 'N');

PROMPT -- ==============================================================
PROMPT -- 5. ASSEGNAZIONE DEI RUOLI AGLI UTENTI CUSTOM
PROMPT -- ==============================================================
SELECT 'GRANT ' || granted_role || ' TO ' || grantee || 
       CASE WHEN admin_option = 'YES' THEN ' WITH ADMIN OPTION;' ELSE ';' END 
FROM dba_role_privs 
WHERE grantee IN (SELECT username FROM dba_users WHERE oracle_maintained = 'N');

SPOOL OFF
SET FEEDBACK ON
```
