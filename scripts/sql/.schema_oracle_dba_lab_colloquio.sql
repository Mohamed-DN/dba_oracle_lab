--------------------------------------------------------------------------------
-- Schema Oracle DBA Lab - Colloquio
-- Scopo:
--   creare un piccolo schema applicativo per testare:
--   - SQL tuning
--   - piani di esecuzione
--   - statistiche optimizer
--   - lock e sessioni bloccate
--   - consumo TEMP/UNDO
--   - backup/recovery RMAN su oggetti applicativi
--
-- Uso consigliato:
--   1. Crea un utente dedicato, per esempio DBA_LAB.
--   2. Connettiti come DBA_LAB.
--   3. Esegui questo script.
--
-- Esempio come SYS/SYSTEM:
--
--   CREATE USER dba_lab IDENTIFIED BY "Lab_Oracle_2026"
--     DEFAULT TABLESPACE users
--     TEMPORARY TABLESPACE temp
--     QUOTA UNLIMITED ON users;
--
--   GRANT create session, create table, create view, create sequence,
--         create procedure, create job TO dba_lab;
--
--   CONNECT dba_lab/"Lab_Oracle_2026"
--   @.schema_oracle_dba_lab_colloquio.sql
--------------------------------------------------------------------------------

SET ECHO ON
SET FEEDBACK ON
SET TIMING ON
SET SERVEROUTPUT ON

--------------------------------------------------------------------------------
-- Cleanup oggetti. Ignora gli errori se gli oggetti non esistono.
--------------------------------------------------------------------------------

BEGIN
  FOR r IN (
    SELECT object_name, object_type
    FROM user_objects
    WHERE object_name IN (
      'LAB_ORDER_ITEMS',
      'LAB_PAYMENTS',
      'LAB_ORDERS',
      'LAB_CUSTOMERS',
      'LAB_PRODUCTS',
      'LAB_AUDIT_LOG',
      'LAB_BATCH_EVENTS',
      'LAB_LOAD_RUNS',
      'LAB_SEQ_CUSTOMERS',
      'LAB_SEQ_PRODUCTS',
      'LAB_SEQ_ORDERS',
      'LAB_SEQ_PAYMENTS',
      'LAB_SEQ_AUDIT',
      'VW_LAB_ORDER_DAILY'
    )
  ) LOOP
    BEGIN
      IF r.object_type = 'TABLE' THEN
        EXECUTE IMMEDIATE 'DROP TABLE ' || r.object_name || ' CASCADE CONSTRAINTS PURGE';
      ELSIF r.object_type = 'SEQUENCE' THEN
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || r.object_name;
      ELSIF r.object_type = 'VIEW' THEN
        EXECUTE IMMEDIATE 'DROP VIEW ' || r.object_name;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  END LOOP;
END;
/

--------------------------------------------------------------------------------
-- Sequenze
--------------------------------------------------------------------------------

CREATE SEQUENCE lab_seq_customers START WITH 1 CACHE 100;
CREATE SEQUENCE lab_seq_products  START WITH 1 CACHE 100;
CREATE SEQUENCE lab_seq_orders    START WITH 1 CACHE 500;
CREATE SEQUENCE lab_seq_payments  START WITH 1 CACHE 500;
CREATE SEQUENCE lab_seq_audit     START WITH 1 CACHE 500;

--------------------------------------------------------------------------------
-- Tabelle anagrafiche
--------------------------------------------------------------------------------

CREATE TABLE lab_customers (
  customer_id     NUMBER        NOT NULL,
  customer_code   VARCHAR2(30)  NOT NULL,
  full_name       VARCHAR2(120) NOT NULL,
  email           VARCHAR2(180) NOT NULL,
  region          VARCHAR2(20)  NOT NULL,
  customer_type   VARCHAR2(20)  NOT NULL,
  status          VARCHAR2(20)  NOT NULL,
  created_at      DATE          NOT NULL,
  last_login_at   DATE,
  risk_score      NUMBER(5,2),
  CONSTRAINT pk_lab_customers PRIMARY KEY (customer_id),
  CONSTRAINT uk_lab_customers_code UNIQUE (customer_code),
  CONSTRAINT ck_lab_customers_status CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED')),
  CONSTRAINT ck_lab_customers_type CHECK (customer_type IN ('RETAIL','SMB','ENTERPRISE'))
);

CREATE TABLE lab_products (
  product_id      NUMBER        NOT NULL,
  sku             VARCHAR2(40)  NOT NULL,
  product_name    VARCHAR2(120) NOT NULL,
  category        VARCHAR2(40)  NOT NULL,
  unit_price      NUMBER(12,2)  NOT NULL,
  active_flag     CHAR(1)       NOT NULL,
  created_at      DATE          NOT NULL,
  CONSTRAINT pk_lab_products PRIMARY KEY (product_id),
  CONSTRAINT uk_lab_products_sku UNIQUE (sku),
  CONSTRAINT ck_lab_products_active CHECK (active_flag IN ('Y','N'))
);

--------------------------------------------------------------------------------
-- Tabelle transazionali
--------------------------------------------------------------------------------

CREATE TABLE lab_orders (
  order_id        NUMBER        NOT NULL,
  customer_id     NUMBER        NOT NULL,
  order_code      VARCHAR2(40)  NOT NULL,
  order_date      DATE          NOT NULL,
  status          VARCHAR2(20)  NOT NULL,
  channel         VARCHAR2(20)  NOT NULL,
  total_amount    NUMBER(14,2)  NOT NULL,
  notes           VARCHAR2(4000),
  created_at      DATE          NOT NULL,
  updated_at      DATE,
  CONSTRAINT pk_lab_orders PRIMARY KEY (order_id),
  CONSTRAINT uk_lab_orders_code UNIQUE (order_code),
  CONSTRAINT fk_lab_orders_customer FOREIGN KEY (customer_id)
    REFERENCES lab_customers(customer_id),
  CONSTRAINT ck_lab_orders_status CHECK (status IN ('NEW','PAID','SHIPPED','CANCELLED','FAILED')),
  CONSTRAINT ck_lab_orders_channel CHECK (channel IN ('WEB','MOBILE','BATCH','PARTNER'))
);

CREATE TABLE lab_order_items (
  order_item_id   NUMBER        NOT NULL,
  order_id        NUMBER        NOT NULL,
  product_id      NUMBER        NOT NULL,
  quantity        NUMBER        NOT NULL,
  unit_price      NUMBER(12,2)  NOT NULL,
  discount_pct    NUMBER(5,2)   DEFAULT 0 NOT NULL,
  line_amount     NUMBER(14,2)  NOT NULL,
  CONSTRAINT pk_lab_order_items PRIMARY KEY (order_item_id),
  CONSTRAINT fk_lab_items_order FOREIGN KEY (order_id)
    REFERENCES lab_orders(order_id),
  CONSTRAINT fk_lab_items_product FOREIGN KEY (product_id)
    REFERENCES lab_products(product_id)
);

CREATE TABLE lab_payments (
  payment_id      NUMBER        NOT NULL,
  order_id        NUMBER        NOT NULL,
  payment_date    DATE          NOT NULL,
  method          VARCHAR2(20)  NOT NULL,
  status          VARCHAR2(20)  NOT NULL,
  amount          NUMBER(14,2)  NOT NULL,
  gateway_code    VARCHAR2(40),
  CONSTRAINT pk_lab_payments PRIMARY KEY (payment_id),
  CONSTRAINT fk_lab_payments_order FOREIGN KEY (order_id)
    REFERENCES lab_orders(order_id),
  CONSTRAINT ck_lab_payments_method CHECK (method IN ('CARD','WIRE','PAYPAL','SEPA')),
  CONSTRAINT ck_lab_payments_status CHECK (status IN ('AUTHORIZED','CAPTURED','FAILED','REFUNDED'))
);

--------------------------------------------------------------------------------
-- Tabelle utili per simulare incidenti
--------------------------------------------------------------------------------

CREATE TABLE lab_audit_log (
  audit_id        NUMBER        NOT NULL,
  event_time      DATE          NOT NULL,
  username        VARCHAR2(60)  NOT NULL,
  module_name     VARCHAR2(80)  NOT NULL,
  action_name     VARCHAR2(80)  NOT NULL,
  entity_name     VARCHAR2(80),
  entity_id       NUMBER,
  payload         CLOB,
  CONSTRAINT pk_lab_audit_log PRIMARY KEY (audit_id)
);

CREATE TABLE lab_batch_events (
  event_id        NUMBER        GENERATED BY DEFAULT AS IDENTITY,
  batch_name      VARCHAR2(80)  NOT NULL,
  event_time      DATE          NOT NULL,
  severity        VARCHAR2(20)  NOT NULL,
  message_text    VARCHAR2(1000),
  CONSTRAINT pk_lab_batch_events PRIMARY KEY (event_id),
  CONSTRAINT ck_lab_batch_severity CHECK (severity IN ('INFO','WARN','ERROR','FATAL'))
);

CREATE TABLE lab_load_runs (
  run_id          NUMBER        GENERATED BY DEFAULT AS IDENTITY,
  run_name        VARCHAR2(80)  NOT NULL,
  started_at      DATE          NOT NULL,
  ended_at        DATE,
  status          VARCHAR2(20)  NOT NULL,
  rows_loaded     NUMBER,
  error_message   VARCHAR2(1000),
  CONSTRAINT pk_lab_load_runs PRIMARY KEY (run_id)
);

--------------------------------------------------------------------------------
-- Indici.
-- Alcuni indici sono volutamente assenti per generare casi di tuning.
--------------------------------------------------------------------------------

CREATE INDEX ix_lab_customers_region ON lab_customers(region);
CREATE INDEX ix_lab_customers_type_status ON lab_customers(customer_type, status);
CREATE INDEX ix_lab_products_category ON lab_products(category);
CREATE INDEX ix_lab_orders_order_date ON lab_orders(order_date);
CREATE INDEX ix_lab_orders_status ON lab_orders(status);
CREATE INDEX ix_lab_items_product ON lab_order_items(product_id);
CREATE INDEX ix_lab_payments_status_date ON lab_payments(status, payment_date);

-- Volutamente NON creati:
--   ix_lab_orders_customer_id
--   ix_lab_order_items_order_id
-- Servono per testare join lenti e suggerimenti del SQL Tuning Advisor.

--------------------------------------------------------------------------------
-- Caricamento dati
--------------------------------------------------------------------------------

DECLARE
  l_customer_id   NUMBER;
  l_product_id    NUMBER;
  l_order_id      NUMBER;
  l_order_total   NUMBER;
  l_price         NUMBER;
  l_qty           NUMBER;
  l_region        VARCHAR2(20);
  l_status        VARCHAR2(20);
  l_channel       VARCHAR2(20);
  l_category      VARCHAR2(40);
BEGIN
  DBMS_RANDOM.SEED(20260528);

  FOR i IN 1 .. 1000 LOOP
    l_customer_id := lab_seq_customers.NEXTVAL;

    -- Distribuzione skewed: molte righe NORTH, poche SOUTH.
    l_region :=
      CASE
        WHEN MOD(i, 20) = 0 THEN 'SOUTH'
        WHEN MOD(i, 10) = 0 THEN 'ISLANDS'
        WHEN MOD(i, 5) = 0 THEN 'CENTER'
        ELSE 'NORTH'
      END;

    INSERT INTO lab_customers (
      customer_id, customer_code, full_name, email, region,
      customer_type, status, created_at, last_login_at, risk_score
    ) VALUES (
      l_customer_id,
      'CUST-' || TO_CHAR(l_customer_id, 'FM000000'),
      'Customer ' || l_customer_id,
      'customer' || l_customer_id || '@example.local',
      l_region,
      CASE
        WHEN MOD(i, 25) = 0 THEN 'ENTERPRISE'
        WHEN MOD(i, 4) = 0 THEN 'SMB'
        ELSE 'RETAIL'
      END,
      CASE
        WHEN MOD(i, 50) = 0 THEN 'SUSPENDED'
        WHEN MOD(i, 200) = 0 THEN 'CLOSED'
        ELSE 'ACTIVE'
      END,
      TRUNC(SYSDATE) - DBMS_RANDOM.VALUE(30, 1200),
      TRUNC(SYSDATE) - DBMS_RANDOM.VALUE(0, 120),
      ROUND(DBMS_RANDOM.VALUE(1, 99), 2)
    );
  END LOOP;

  FOR i IN 1 .. 500 LOOP
    l_product_id := lab_seq_products.NEXTVAL;
    l_category :=
      CASE MOD(i, 8)
        WHEN 0 THEN 'DATABASE'
        WHEN 1 THEN 'MIDDLEWARE'
        WHEN 2 THEN 'SECURITY'
        WHEN 3 THEN 'STORAGE'
        WHEN 4 THEN 'CLOUD'
        WHEN 5 THEN 'MONITORING'
        WHEN 6 THEN 'SUPPORT'
        ELSE 'TRAINING'
      END;

    INSERT INTO lab_products (
      product_id, sku, product_name, category, unit_price, active_flag, created_at
    ) VALUES (
      l_product_id,
      'SKU-' || TO_CHAR(l_product_id, 'FM000000'),
      l_category || ' Service ' || l_product_id,
      l_category,
      ROUND(DBMS_RANDOM.VALUE(10, 5000), 2),
      CASE WHEN MOD(i, 40) = 0 THEN 'N' ELSE 'Y' END,
      TRUNC(SYSDATE) - DBMS_RANDOM.VALUE(10, 1000)
    );
  END LOOP;

  FOR i IN 1 .. 50000 LOOP
    l_order_id := lab_seq_orders.NEXTVAL;
    l_order_total := 0;

    l_status :=
      CASE
        WHEN MOD(i, 100) = 0 THEN 'FAILED'
        WHEN MOD(i, 30) = 0 THEN 'CANCELLED'
        WHEN MOD(i, 5) = 0 THEN 'SHIPPED'
        WHEN MOD(i, 2) = 0 THEN 'PAID'
        ELSE 'NEW'
      END;

    l_channel :=
      CASE MOD(i, 4)
        WHEN 0 THEN 'WEB'
        WHEN 1 THEN 'MOBILE'
        WHEN 2 THEN 'BATCH'
        ELSE 'PARTNER'
      END;

    INSERT INTO lab_orders (
      order_id, customer_id, order_code, order_date, status, channel,
      total_amount, notes, created_at, updated_at
    ) VALUES (
      l_order_id,
      TRUNC(DBMS_RANDOM.VALUE(1, 1001)),
      'ORD-' || TO_CHAR(l_order_id, 'FM0000000000'),
      TRUNC(SYSDATE) - TRUNC(DBMS_RANDOM.VALUE(0, 730)),
      l_status,
      l_channel,
      0,
      CASE WHEN MOD(i, 1000) = 0 THEN RPAD('large note ', 3000, 'x') END,
      SYSDATE - DBMS_RANDOM.VALUE(0, 730),
      SYSDATE - DBMS_RANDOM.VALUE(0, 30)
    );

    FOR j IN 1 .. 3 LOOP
      l_product_id := TRUNC(DBMS_RANDOM.VALUE(1, 501));

      SELECT unit_price
      INTO l_price
      FROM lab_products
      WHERE product_id = l_product_id;

      l_qty := TRUNC(DBMS_RANDOM.VALUE(1, 6));
      l_order_total := l_order_total + (l_price * l_qty);

      INSERT INTO lab_order_items (
        order_item_id, order_id, product_id, quantity,
        unit_price, discount_pct, line_amount
      ) VALUES (
        (l_order_id * 10) + j,
        l_order_id,
        l_product_id,
        l_qty,
        l_price,
        CASE WHEN MOD(i, 20) = 0 THEN 10 ELSE 0 END,
        ROUND(l_price * l_qty * CASE WHEN MOD(i, 20) = 0 THEN 0.90 ELSE 1 END, 2)
      );
    END LOOP;

    UPDATE lab_orders
    SET total_amount = ROUND(l_order_total, 2)
    WHERE order_id = l_order_id;

    IF l_status IN ('PAID','SHIPPED') THEN
      INSERT INTO lab_payments (
        payment_id, order_id, payment_date, method, status, amount, gateway_code
      ) VALUES (
        lab_seq_payments.NEXTVAL,
        l_order_id,
        SYSDATE - DBMS_RANDOM.VALUE(0, 730),
        CASE MOD(i, 4)
          WHEN 0 THEN 'CARD'
          WHEN 1 THEN 'WIRE'
          WHEN 2 THEN 'PAYPAL'
          ELSE 'SEPA'
        END,
        'CAPTURED',
        ROUND(l_order_total, 2),
        'GW-' || TO_CHAR(MOD(i, 100), 'FM000')
      );
    ELSIF l_status = 'FAILED' THEN
      INSERT INTO lab_payments (
        payment_id, order_id, payment_date, method, status, amount, gateway_code
      ) VALUES (
        lab_seq_payments.NEXTVAL,
        l_order_id,
        SYSDATE - DBMS_RANDOM.VALUE(0, 730),
        'CARD',
        'FAILED',
        ROUND(l_order_total, 2),
        'GW-ERR'
      );
    END IF;

    IF MOD(i, 1000) = 0 THEN
      COMMIT;
    END IF;
  END LOOP;

  FOR i IN 1 .. 20000 LOOP
    INSERT INTO lab_audit_log (
      audit_id, event_time, username, module_name, action_name,
      entity_name, entity_id, payload
    ) VALUES (
      lab_seq_audit.NEXTVAL,
      SYSDATE - DBMS_RANDOM.VALUE(0, 90),
      'APP_USER_' || MOD(i, 50),
      CASE MOD(i, 5)
        WHEN 0 THEN 'ORDER_API'
        WHEN 1 THEN 'PAYMENT_JOB'
        WHEN 2 THEN 'CUSTOMER_UI'
        WHEN 3 THEN 'BATCH_LOAD'
        ELSE 'REPORTING'
      END,
      CASE MOD(i, 4)
        WHEN 0 THEN 'INSERT'
        WHEN 1 THEN 'UPDATE'
        WHEN 2 THEN 'LOGIN'
        ELSE 'READ'
      END,
      CASE MOD(i, 3)
        WHEN 0 THEN 'LAB_ORDERS'
        WHEN 1 THEN 'LAB_CUSTOMERS'
        ELSE 'LAB_PAYMENTS'
      END,
      MOD(i, 50000) + 1,
      RPAD('payload for audit event ' || i, 500, 'x')
    );

    IF MOD(i, 1000) = 0 THEN
      COMMIT;
    END IF;
  END LOOP;

  INSERT INTO lab_load_runs(run_name, started_at, ended_at, status, rows_loaded)
  VALUES ('initial_load', SYSDATE - 1/24, SYSDATE, 'COMPLETED',
          1000 + 500 + 50000 + 150000 + 20000);

  COMMIT;
END;
/

--------------------------------------------------------------------------------
-- Vista di reporting
--------------------------------------------------------------------------------

CREATE OR REPLACE VIEW vw_lab_order_daily AS
SELECT
  TRUNC(o.order_date) AS order_day,
  c.region,
  o.status,
  COUNT(*) AS orders_count,
  SUM(o.total_amount) AS total_amount
FROM lab_orders o
JOIN lab_customers c ON c.customer_id = o.customer_id
GROUP BY TRUNC(o.order_date), c.region, o.status;

--------------------------------------------------------------------------------
-- Statistiche optimizer
--------------------------------------------------------------------------------

BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(
    ownname          => USER,
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    method_opt       => 'FOR ALL COLUMNS SIZE AUTO',
    cascade          => TRUE,
    degree           => 2
  );
END;
/

--------------------------------------------------------------------------------
-- Report finale
--------------------------------------------------------------------------------

PROMPT
PROMPT Oggetti creati:

COLUMN table_name FORMAT A24
SELECT table_name, num_rows, blocks, last_analyzed
FROM user_tables
WHERE table_name LIKE 'LAB_%'
ORDER BY table_name;

PROMPT
PROMPT Indici creati:

COLUMN index_name FORMAT A32
COLUMN table_name FORMAT A24
SELECT index_name, table_name, status
FROM user_indexes
WHERE table_name LIKE 'LAB_%'
ORDER BY table_name, index_name;

--------------------------------------------------------------------------------
-- Query di test colloquio
--------------------------------------------------------------------------------

PROMPT
PROMPT Test 1 - Top query reporting con join e aggregazione.
PROMPT Usa DBMS_XPLAN.DISPLAY_CURSOR dopo averla eseguita.

SELECT c.region, p.category, COUNT(*) orders_count, SUM(oi.line_amount) total_amount
FROM lab_orders o
JOIN lab_customers c ON c.customer_id = o.customer_id
JOIN lab_order_items oi ON oi.order_id = o.order_id
JOIN lab_products p ON p.product_id = oi.product_id
WHERE o.order_date >= TRUNC(SYSDATE) - 180
  AND o.status IN ('PAID','SHIPPED')
GROUP BY c.region, p.category
ORDER BY total_amount DESC;

PROMPT
PROMPT Test 2 - Predicate non sargable: TRUNC(order_date) puo impedire uso efficiente indice.

SELECT COUNT(*), SUM(total_amount)
FROM lab_orders
WHERE TRUNC(order_date) = TRUNC(SYSDATE) - 30;

PROMPT
PROMPT Variante migliore del Test 2.

SELECT COUNT(*), SUM(total_amount)
FROM lab_orders
WHERE order_date >= TRUNC(SYSDATE) - 30
  AND order_date <  TRUNC(SYSDATE) - 29;

PROMPT
PROMPT Test 3 - Join potenzialmente lento per indici FK mancanti.

SELECT o.order_id, o.order_date, o.status, SUM(oi.line_amount) total_amount
FROM lab_orders o
JOIN lab_order_items oi ON oi.order_id = o.order_id
WHERE o.customer_id = 42
GROUP BY o.order_id, o.order_date, o.status
ORDER BY o.order_date DESC;

PROMPT
PROMPT Fix possibile da testare, dopo aver misurato before/after:
PROMPT CREATE INDEX ix_lab_orders_customer_id ON lab_orders(customer_id);
PROMPT CREATE INDEX ix_lab_items_order_id ON lab_order_items(order_id);

PROMPT
PROMPT Test 4 - Skew dati: regione NORTH molto piu frequente di SOUTH.

SELECT region, COUNT(*)
FROM lab_customers
GROUP BY region
ORDER BY COUNT(*) DESC;

PROMPT
PROMPT Test 5 - Query per simulare consumo TEMP su sort/aggregazione.

SELECT module_name, action_name, COUNT(*), MAX(DBMS_LOB.GETLENGTH(payload)) max_payload_len
FROM lab_audit_log
GROUP BY module_name, action_name
ORDER BY max_payload_len DESC, COUNT(*) DESC;

PROMPT
PROMPT Test 6 - Simulazione lock manuale.
PROMPT Sessione A:
PROMPT   UPDATE lab_orders SET notes = 'LOCK TEST' WHERE order_id = 100;
PROMPT   -- non fare COMMIT
PROMPT Sessione B:
PROMPT   UPDATE lab_orders SET notes = 'WAIT TEST' WHERE order_id = 100;
PROMPT Poi usa i runbook lock/sessioni bloccate.

PROMPT
PROMPT Setup completato.
PROMPT Prossimi script utili:
PROMPT   @docs/01_operations/03_scripts_pronti/07_performance_quick.sql
PROMPT   @docs/01_operations/03_scripts_pronti/14_optimizer_stats.sql
PROMPT   @docs/01_operations/03_scripts_pronti/08_rman_backup_status.sql

--------------------------------------------------------------------------------
-- Mini runbook RMAN live per testare backup/recovery dello schema
--------------------------------------------------------------------------------

PROMPT
PROMPT RMAN LIVE TEST - comandi da lanciare fuori da SQL*Plus.
PROMPT Obiettivo: forzare un backup e vedere subito cosa esiste, cosa manca e se e' validabile.
PROMPT
PROMPT 1) Da shell, entra in RMAN:
PROMPT    rman target /
PROMPT
PROMPT 2) Fotografia configurazione corrente:
PROMPT    SHOW ALL;
PROMPT    LIST BACKUP SUMMARY;
PROMPT    REPORT SCHEMA;
PROMPT    REPORT NEED BACKUP;
PROMPT
PROMPT 3) Backup manuale veloce database + archivelog:
PROMPT    RUN {
PROMPT      SQL "ALTER SYSTEM ARCHIVE LOG CURRENT";
PROMPT      BACKUP AS COMPRESSED BACKUPSET DATABASE TAG 'DBA_LAB_MANUAL_DB';
PROMPT      BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL TAG 'DBA_LAB_MANUAL_ARCH';
PROMPT      BACKUP CURRENT CONTROLFILE TAG 'DBA_LAB_MANUAL_CTL';
PROMPT      BACKUP SPFILE TAG 'DBA_LAB_MANUAL_SPFILE';
PROMPT    }
PROMPT
PROMPT 4) Controlli immediati in RMAN:
PROMPT    LIST BACKUP TAG 'DBA_LAB_MANUAL_DB';
PROMPT    LIST BACKUP TAG 'DBA_LAB_MANUAL_ARCH';
PROMPT    LIST BACKUP OF CONTROLFILE;
PROMPT    LIST BACKUP OF SPFILE;
PROMPT    LIST ARCHIVELOG ALL;
PROMPT    RESTORE DATABASE PREVIEW SUMMARY;
PROMPT    RESTORE DATABASE VALIDATE;
PROMPT    RESTORE ARCHIVELOG ALL VALIDATE;
PROMPT
PROMPT 5) Controlli da SQL*Plus:
PROMPT    SELECT input_type, status, start_time, end_time, output_bytes_display
PROMPT    FROM v$rman_backup_job_details
PROMPT    WHERE start_time > SYSDATE - 1
PROMPT    ORDER BY start_time DESC;
PROMPT
PROMPT    SELECT file_type, percent_space_used, percent_space_reclaimable, number_of_files
PROMPT    FROM v$flash_recovery_area_usage
PROMPT    ORDER BY percent_space_used DESC;
PROMPT
PROMPT    SELECT name, space_limit/1024/1024/1024 limit_gb,
PROMPT           space_used/1024/1024/1024 used_gb,
PROMPT           space_reclaimable/1024/1024/1024 reclaimable_gb
PROMPT    FROM v$recovery_file_dest;
PROMPT
PROMPT Nota colloquio:
PROMPT    Non dire solo "backup completed". Devi dimostrare LIST BACKUP, restore validate,
PROMPT    archivelog disponibili, controlfile/SPFILE e spazio FRA.

--------------------------------------------------------------------------------
-- Mini runbook Flashback / Restore Point
--------------------------------------------------------------------------------

PROMPT
PROMPT FLASHBACK / RESTORE POINT LIVE TEST - comandi da usare con attenzione.
PROMPT Obiettivo: creare un punto di ritorno prima di un test o change.
PROMPT
PROMPT 1) Verifica prerequisiti da SQL*Plus come SYSDBA:
PROMPT    SELECT name, open_mode, log_mode, flashback_on FROM v$database;
PROMPT    SHOW PARAMETER db_recovery_file_dest
PROMPT    SHOW PARAMETER db_recovery_file_dest_size
PROMPT    SHOW PARAMETER db_flashback_retention_target
PROMPT
PROMPT 2) Se Flashback Database non e' attivo, in lab/change approvato:
PROMPT    SHUTDOWN IMMEDIATE;
PROMPT    STARTUP MOUNT;
PROMPT    ALTER DATABASE ARCHIVELOG;
PROMPT    ALTER DATABASE FLASHBACK ON;
PROMPT    ALTER DATABASE OPEN;
PROMPT
PROMPT 3) Crea guaranteed restore point:
PROMPT    CREATE RESTORE POINT rp_before_dba_lab_test GUARANTEE FLASHBACK DATABASE;
PROMPT
PROMPT 4) Verifica restore point e consumo:
PROMPT    SELECT name, scn, time, guarantee_flashback_database, storage_size
PROMPT    FROM v$restore_point
PROMPT    ORDER BY time DESC;
PROMPT
PROMPT 5) Flashback Query su tabella del lab:
PROMPT    SELECT COUNT(*) FROM lab_orders AS OF TIMESTAMP (SYSTIMESTAMP - INTERVAL '10' MINUTE);
PROMPT
PROMPT 6) Flashback Table, se serve e se row movement e' abilitato:
PROMPT    ALTER TABLE lab_orders ENABLE ROW MOVEMENT;
PROMPT    FLASHBACK TABLE lab_orders TO TIMESTAMP (SYSTIMESTAMP - INTERVAL '10' MINUTE);
PROMPT
PROMPT 7) Flashback Database al restore point, procedura invasiva:
PROMPT    SHUTDOWN IMMEDIATE;
PROMPT    STARTUP MOUNT;
PROMPT    FLASHBACK DATABASE TO RESTORE POINT rp_before_dba_lab_test;
PROMPT    ALTER DATABASE OPEN RESETLOGS;
PROMPT
PROMPT 8) Pulizia dopo test:
PROMPT    DROP RESTORE POINT rp_before_dba_lab_test;
PROMPT
PROMPT Nota colloquio:
PROMPT    Flashback Query/Table e' granulare. Flashback Database riporta indietro
PROMPT    tutto il database e richiede governance, downtime e validazione.
