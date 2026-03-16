# COMPLETE GUIDE: Listeners, Services and DBA Monitoring Toolkit

> **Objective**: This guide covers everything you need to manage Listeners, Services, and monitor an Oracle RAC professionally. Includes diagrams, detailed explanations and ready-to-use scripts extracted from the [oraclebase/dba](https://github.com/oraclebase/dba).
>
> ⚠️ **This guide is intended to be run in the lab AND in production.**

---

## Index

1. [How the Oracle Listener Works](#1-how-the-oracle-listener-works)
2. [RAC Listener Configuration](#2-rac-listener-configuration)
3. [Oracle Services](#3-oracle-services)
4. [SCAN Listener — Oracle's Load Balancer](#4-scan-listener)
5. [Management via lsnrctl/srvctl (Commands)](#5-management-listener-commands)
6. [DBA Monitoring Toolkit](#6-dba-monitoring-toolkit)
7. [Practical Lab Exercises](#7-practical-lab-exercises)

---

## 1. How the Oracle Listener Works

### What is the Listener?

The Listener is a **network process** that listens on a TCP port (default 1521) and directs client connections to the correct database.

```
╔══════════════════════════════════════════════════════════════════════╗
║ HOW A CONNECTION WORKS ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║   Client (SQL*Plus, App, JDBC)                                       ║
║     │                                                                ║
║ │ 1. "I want to connect to ORCL on port 1521" ║
║     ▼                                                                ║
║   ┌─────────────────────────────────┐                                ║
║ │ LISTENER (:1521) │ ║
║   │                                 │                                ║
║ │ Knows the registered services: │ ║
║   │  - ORCL                        │                                ║
║   │  - ORCL_DG (Data Guard)        │                                ║
║   │  - PDB1                        │                                ║
║   └─────────┬───────────────────────┘                                ║
║             │                                                        ║
║ │ 2. "OK, I'll send you to the right instance" ║
║             ▼                                                        ║
║   ┌─────────────────────────────────┐                                ║
║   │   Server Process (Dedicato)     │                                ║
║ │ connected to SGA/PGA │ ║
║ │ of the ORCL │ ║ instance
║   └─────────────────────────────────┘                                ║
║                                                                      ║
║ Note: The Listener does NOT transfer data after connection!        ║
║ It only does the initial "redirect", then client↔server talk ║
║ directly.                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Static vs Dynamic Listener

```
╔═══════════════════════════════════════════════════╗
║ SERVICE REGISTRATION ║
╠═══════════════════════════════════════════════════╣
║                                                    ║
║ STATIC (listener.ora) DYNAMIC (PMON) ║
║  ─────────────────────         ─────────────────   ║
║ - Defined in the file - The PMON process ║
║ listener.ora registers ║
║ - Serves BEFORE the automatically ║
║ DB is open - Works when ║
║ - Required for RMAN the DB is OPEN ║
║ DUPLICATE (NOMOUNT) - Update services║
║ - Required for Date every 60 sec ║
║ Guard standby - Preferred in prod ║
║                                                    ║
║  Quando usare quale:                               ║
║  ┌─────────────────────────────────────────────┐   ║
║ │ ALWAYS static for: │ ║
║ │ - DB in MOUNT (Data Guard standby) │ ║
║  │   - RMAN Duplicate (NOMOUNT)                │   ║
║ │ - Startup after crash │ ║
║  │                                             │   ║
║ │ ALWAYS dynamic for: │ ║
║ │ - Normal production (OPEN) │ ║
║  │   - Load balancing RAC                      │   ║
║ │ - Automatic failover │ ║
║  └─────────────────────────────────────────────┘   ║
╚═══════════════════════════════════════════════════╝
```

---

## 2. RAC Listener Configuration

### 2.1 Listener architecture in RAC

```
╔══════════════════════════════════════════════════════════════════╗
║ LISTENER ARCHITECTURE IN RAC ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║   Client App / SQL*Plus / JDBC                                   ║
║       │                                                          ║
║ │ Connection via SCAN: rac-scan:1521/ORCL ║
║       ▼                                                          ║
║   ╔═══════════════════════════════════╗                           ║
║ ║ SCAN LISTENER (3 virtual IPs) ║ ← Grid Infrastructure ║
║ ║ .105 .106 .107 ║ handles everything ║
║   ║   Porta 1521                     ║                           ║
║   ╚════════════╤══════════════════════╝                           ║
║                │  Load Balancing (round-robin                     ║
║                │  + connection load balancing)                    ║
║        ┌───────┴───────┐                                         ║
║        ▼               ▼                                         ║
║   ┌─────────┐    ┌─────────┐                                     ║
║   │ Node 1  │    │ Node 2  │                                     ║
║ │ LSNR │ │ LSNR │ ← LOCAL listener for node ║
║ │ :1521 │ │ :1521 │ (operated by CRS) ║
║   │         │    │         │                                     ║
║   │ Inst1   │    │ Inst2   │                                     ║
║   │ ORCL1   │    │ ORCL2   │                                     ║
║   └─────────┘    └─────────┘                                     ║
║                                                                  ║
║ Registered Services: ║
║ - ORCL (database service, both nodes) ║
║   - ORCL_APP(application service, node1 only) ║
║   - ORCL_REPORT (reporting service, solo nodo2)                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### 2.2 listener.ora file (RAC — managed by Grid)

In RAC, il `listener.ora` it is managed automatically by the Grid Infrastructure. It is usually found in `$GRID_HOME/network/admin/listener.ora`.

```bash
#View current listener.ora (as grid user)
cat $GRID_HOME/network/admin/listener.ora
```

Typical content generated by CRS:

```
# listener.ora for RAC Node 1 (generated by CRS)
LISTENER=
  (DESCRIPTION_LIST=
    (DESCRIPTION=
      (ADDRESS=(PROTOCOL=IPC)(KEY=LISTENER))
      (ADDRESS=(PROTOCOL=TCP)(HOST=rac1-vip)(PORT=1521))
    )
  )

# STATIC recording for Data Guard / RMAN Duplicate
SID_LIST_LISTENER=
  (SID_LIST=
    (SID_DESC=
      (GLOBAL_DBNAME=ORCL)
      (ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME=ORCL1)
    )
    (SID_DESC=
      (GLOBAL_DBNAME=ORCL_DGMGRL)
      (ORACLE_HOME=/u01/app/oracle/product/19.0.0/dbhome_1)
      (SID_NAME=ORCL1)
    )
  )
```

> **Why `_DGMGRL`?** Data Guard Broker cerca automaticamente un servizio con suffisso `_DGMGRL`. Without this static entry, the broker cannot connect to the standby in MOUNT.

### 2.3 File tnsnames.ora

```
# tnsnames.ora — main connections

# Connection via SCAN (PRODUCTION — use this!)
ORCL =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac-scan)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL)
    )
  )

#DIRECT connection to node 1 (debug/maintenance)
ORCL1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = rac1-vip)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ORCL1)
    )
  )

# Connect to standby (with UR=A for NOMOUNT/MOUNT!)
ORCL_STBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = racstby1-vip)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = ORCL_STBY)
      (UR = A)
    )
  )
```

> **`(UR = A)` = "Unrestricted Access"** — Allows connection even when the DB is in NOMOUNT or MOUNT. **Required** for RMAN Duplicate and Data Guard.

---

## 3. Oracle Services (Services)

### 3.1 What is a Service?

A Service is a **logical name** that groups together database instances for a certain purpose.

```
╔══════════════════════════════════════════════════════════════════╗
║ SERVICES IN ACTION ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Service: ORCL_OLTP                                              ║
║  ├── Preferred: Nodo1, Nodo2                                     ║
║  ├── Available: (nessuno)                                        ║
║  ├── TAF Policy: BASIC (failover automatico)                     ║
║ └── Purpose: OLTP transactions, low latency ║
║                                                                  ║
║  Service: ORCL_REPORT                                            ║
║  ├── Preferred: Nodo2                                            ║
║  ├── Available: Nodo1 (se Nodo2 muore)                           ║
║  ├── TAF Policy: NONE                                            ║
║ └── Purpose: Heavy reporting, only on one node ║
║                                                                  ║
║  Service: ORCL_BATCH                                             ║
║  ├── Preferred: Nodo1                                            ║
║  ├── Available: Nodo2                                            ║
║  ├── TAF Policy: NONE                                            ║
║ └── Purpose: Nightly batch jobs ║
║                                                                  ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║ │ ADVANTAGE OF SERVICES: │ ║
║  │  - Separazione workload (OLTP vs Report vs Batch)        │    ║
║ │ - Automatic failover (if a node fails) │ ║
║ │ - Monitoring by service (AWR, wait events) │ ║
║  │  - Load balancing intelligente                           │    ║
║ │ - Resource management (Resource Manager for service) │ ║
║  └──────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════╝
```

### 3.2 Create and Manage Services (Lab)

```bash
# ═══════════════════════════════════════════════════════
#CREATE A RAC SERVICE (as oracle user)
# ═══════════════════════════════════════════════════════

# OLTP service — on both nodes
srvctl add service -db ORCL -service ORCL_OLTP \
  -preferred ORCL1,ORCL2 \
  -failovertype SELECT \
  -failovermethod BASIC \
  -failoverretry 30 \
  -failoverdelay 10

# REPORT service — preferred on node2, failover to node1
srvctl add service -db ORCL -service ORCL_REPORT \
  -preferred ORCL2 \
  -available ORCL1 \
  -failovertype SELECT \
  -failovermethod BASIC

# BATCH service — preferred on node1
srvctl add service -db ORCL -service ORCL_BATCH \
  -preferred ORCL1 \
  -available ORCL2

# ═══════════════════════════════════════════════════════
#MANAGE THE SERVICES
# ═══════════════════════════════════════════════════════

# Start a service
srvctl start service -db ORCL -service ORCL_OLTP

# Stop a service
srvctl stop service -db ORCL -service ORCL_REPORT

#Status of all services
srvctl status service -db ORCL

#Detailed configuration
srvctl config service -db ORCL -service ORCL_OLTP

# Remove a service
srvctl remove service -db ORCL -service ORCL_BATCH

# ═══════════════════════════════════════════════════════
# VERIFICARE IN SQL*PLUS
# ═══════════════════════════════════════════════════════
```

```sql
--Active services in the database
SELECT name, network_name, pdb
FROM   v$services
ORDER BY name;

--Sessions per service
SELECT service_name, COUNT(*) sessions
FROM   gv$session
WHERE  username IS NOT NULL
GROUP BY service_name
ORDER BY 2 DESC;

--Connection via a specific service
-- sqlplus user/pass@rac-scan:1521/ORCL_OLTP
```

---

## 4. SCAN Listener

### 4.1 What is SCAN?

**SCAN = Single Client Access Name**. It is a DNS hostname that resolves to 3 IPs (for high availability and load balancing).

```
╔══════════════════════════════════════════════════════════════════╗
║ HOW SCAN WORKS ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ DNS resolves "rac-scan" to: ║
║     192.168.1.105                                                ║
║     192.168.1.106                                                ║
║     192.168.1.107                                                ║
║                                                                  ║
║ Each IP is managed by a SCAN Listener (on a RAC node): ║
║                                                                  ║
║   ┌──────────┐  ┌──────────┐  ┌──────────┐                      ║
║   │ SCAN-L1  │  │ SCAN-L2  │  │ SCAN-L3  │                      ║
║   │ .105     │  │ .106     │  │ .107     │                      ║
║   │ Nodo1    │  │ Nodo2    │  │ Nodo1    │  ← CRS decide        ║
║   └────┬─────┘  └────┬─────┘  └────┬─────┘    dove metterlo     ║
║        │             │             │                             ║
║        └──────┬──────┘──────┬──────┘                             ║
║               │             │                                    ║
║          ┌────┴───┐    ┌────┴───┐                                ║
║          │ Inst 1 │    │ Inst 2 │  ← routing intelligente       ║
║          └────────┘    └────────┘                                ║
║                                                                  ║
║   VANTAGGI:                                                      ║
║ ✓ Client ALWAYS uses the same hostname (rac-scan) ║
║ ✓ If you add/remove nodes, the client does NOT change anything ║
║ ✓ Automatic load balancing between nodes ║
║ ✓ If a SCAN listener fails, CRS restarts it on another node ║
╚══════════════════════════════════════════════════════════════════╝
```

### 4.2 SCAN commands

```bash
# SCAN listener status
srvctl status scan_listener
# Output: SCAN Listener LISTENER_SCAN1 is enabled
#         SCAN Listener LISTENER_SCAN1 is running on node rac1

#SCAN configuration
srvctl config scan
srvctl config scan_listener

# Test connection via SCAN
tnsping rac-scan

# Check DNS resolution
nslookup rac-scan
# Deve restituire 3 IP!
```

---

## 5. Listener Management (Commands)

```bash
# ═══════════════════════════════════════════════════════
# COMANDI lsnrctl (Listener Control)
# ═══════════════════════════════════════════════════════

# Listener status
lsnrctl status

#Detailed status with services
lsnrctl services

# Start/Stop (solo per listener locali, NON CRS-managed!)
lsnrctl start
lsnrctl stop
lsnrctl reload    # rilegge listener.ora senza riavviare

# ═══════════════════════════════════════════════════════
# COMANDI srvctl (per RAC — usa SEMPRE questi!)
# ═══════════════════════════════════════════════════════

# Listener locale
srvctl status listener
srvctl start listener
srvctl stop listener
srvctl config listener

# SCAN Listener
srvctl status scan_listener
srvctl start scan_listener
srvctl stop scan_listener
srvctl config scan_listener

#Force re-registration (if services do not appear)
#From SQL*Plus as SYS:
ALTER SYSTEM REGISTER;

# ═══════════════════════════════════════════════════════
# TROUBLESHOOTING LISTENER
# ═══════════════════════════════════════════════════════

# 1. TNS-12541: TNS:no listener
#→ Check if the listener is active: lsnrctl status
#    → Controlla firewall: iptables -L

# 2. ORA-12514: TNS:listener does not currently know of service
# → ALTER SYSTEM REGISTER;  (force re-registration)
# → Check local_listener parameter

# 3. TNS-12535: TNS:operation timed out
#→ Check network: ping hostname
#    → Controlla /etc/hosts

# Key parameter for the listener
SHOW PARAMETER local_listener;
SHOW PARAMETER remote_listener;
--local_listener points to the VIP of the current node
--remote_listener points to the SCAN name
```

---

## 6. DBA Monitoring Toolkit

> Script professionali estratti da [oraclebase/dba](https://github.com/oraclebase/dba) (Tim Hall, oracle-base.com). These scripts are used by professional DBAs in production.

### 6.1 Sessioni RAC (Cross-Instance)

```sql
-- ═══════════════════════════════════════════════════════
-- sessions_rac.sql— Sessions on ALL RAC nodes
-- Fonte: oraclebase/dba/rac/sessions_rac.sql
-- ═══════════════════════════════════════════════════════
SET LINESIZE 500
SET PAGESIZE 1000

COLUMN username FORMAT A15
COLUMN machine FORMAT A25
COLUMN logon_time FORMAT A20

SELECT NVL(s.username, '(oracle)') AS username,
       s.inst_id,
       s.osuser,
       s.sid,
       s.serial#,
       p.spid,
       s.lockwait,
       s.status,
       s.module,
       s.machine,
       s.program,
       TO_CHAR(s.logon_Time,'DD-MON-YYYY HH24:MI:SS') AS logon_time
FROM   gv$session s,
       gv$process p
WHERE  s.paddr   = p.addr
AND    s.inst_id = p.inst_id
ORDER BY s.username, s.osuser;
```

### 6.2 Lock RAC (Chi Blocca Chi?)

```sql
-- ═══════════════════════════════════════════════════════
-- locked_objects_rac.sql — Lock su tutti i nodi
-- Fonte: oraclebase/dba/rac/locked_objects_rac.sql
-- ═══════════════════════════════════════════════════════
SET LINESIZE 500

COLUMN owner FORMAT A20
COLUMN username FORMAT A20
COLUMN object_name FORMAT A30
COLUMN locked_mode FORMAT A15

SELECT b.inst_id,
       b.session_id AS sid,
       NVL(b.oracle_username, '(oracle)') AS username,
       a.owner AS object_owner,
       a.object_name,
       Decode(b.locked_mode, 0, 'None',
1, 'Null (NULL)',
                             2, 'Row-S (SS)',
                             3, 'Row-X (SX)',
                             4, 'Share (S)',
                             5, 'S/Row-X (SSX)',
                             6, 'Exclusive (X)',
                             b.locked_mode) locked_mode,
       b.os_user_name
FROM   dba_objects a,
       gv$locked_object b
WHERE  a.object_id = b.object_id
ORDER BY 1, 2, 3, 4;
```

### 6.3 Tablespace (with View Bar!)

```sql
-- ═══════════════════════════════════════════════════════
-- free_space.sql— Space used for datafiles
-- Fonte: oraclebase/dba/monitoring/free_space.sql
-- ═══════════════════════════════════════════════════════
SET PAGESIZE 100 LINESIZE 265
COLUMN tablespace_name FORMAT A20
COLUMN file_name FORMAT A50

SELECT df.tablespace_name,
       df.file_name,
       df.size_mb,
       f.free_mb,
       df.max_size_mb,
       f.free_mb + (df.max_size_mb - df.size_mb) AS max_free_mb,
       RPAD(' '|| RPAD('X',ROUND((df.max_size_mb-(f.free_mb + (df.max_size_mb - df.size_mb)))/max_size_mb*10,0), 'X'),11,'-') AS used_pct
FROM   (SELECT file_id, file_name, tablespace_name,
               TRUNC(bytes/1024/1024) AS size_mb,
               TRUNC(GREATEST(bytes,maxbytes)/1024/1024) AS max_size_mb
        FROM   dba_data_files) df,
       (SELECT TRUNC(SUM(bytes)/1024/1024) AS free_mb, file_id
        FROM   dba_free_space GROUP BY file_id) f
WHERE  df.file_id = f.file_id (+)
ORDER BY df.tablespace_name, df.file_name;
```

### 6.4 Quick Tuning (6 Hit Ratios with Recommendations)

```sql
-- ═══════════════════════════════════════════════════════
-- tuning.sql — Performance check istantaneo
-- Fonte: oraclebase/dba/monitoring/tuning.sql
-- ═══════════════════════════════════════════════════════
--Automatically check:
-- ✓ Dictionary Cache Hit Ratio  (target: >90%)
-- ✓ Library Cache Hit Ratio     (target: >99%)
-- ✓ Buffer Cache Hit Ratio      (target: >89%)
-- ✓ Latch Hit Ratio             (target: >98%)
-- ✓ Disk Sort Ratio             (target: <5%)
-- ✓ Rollback Segment Waits      (target: <5%)
--
--Run: @tuning.sql
--It tells you WHAT's wrong and HOW to fix it!
```

### 6.5 Active Sessions

```sql
-- ═══════════════════════════════════════════════════════
-- active_sessions.sql — Solo sessioni ATTIVE
-- Fonte: oraclebase/dba/monitoring/active_sessions.sql
-- ═══════════════════════════════════════════════════════
SELECT NVL(s.username, '(oracle)') AS username,
       s.sid, s.serial#, p.spid,
       s.status, s.machine, s.program,
       s.last_call_et AS seconds_active,
       s.module, s.action,
       s.sql_id
FROM   v$session s, v$process p
WHERE  s.paddr = p.addr
AND    s.status = 'ACTIVE'
AND    s.username IS NOT NULL
ORDER BY s.last_call_et DESC;
```

### 6.6 Complete Database Info

```sql
-- ═══════════════════════════════════════════════════════
-- db_info.sql— Full database view
-- Fonte: oraclebase/dba/monitoring/db_info.sql
-- ═══════════════════════════════════════════════════════
SELECT * FROM v$database;
SELECT * FROM v$instance;
SELECT * FROM v$version;
SELECT name, value FROM v$sga;
SELECT name, status FROM v$controlfile;

SELECT name, status, enabled,
       ROUND(bytes/1024/1024) size_mb
FROM   v$datafile ORDER BY 1;

SELECT group#, member, status
FROM   v$logfile ORDER BY 1, 2;
```

### 6.7 All Useful Basic Oracle Scripts (Reference)

| Script | What He Does | Quando Usarlo |
|---|---|---|
| `@sessions_rac` | Cross-node sessions | Check giornalieri |
| `@locked_objects_rac` |Lock between nodes| Troubleshooting blocchi |
| `@active_sessions` |Active sessions| Performance check rapido |
| `@free_space` |Datafile space| Capacity planning |
| `@ts_free_space` |Tablespace space|Space alert|
| `@tuning` | 6 hit ratio | Tuning rapido |
| `@db_info` | Complete DB info |Documentation|
| `@longops` |Long operations|RMAN/import monitoring|
| `@redo_by_hour` | Redo per ora | Sizing redo log |
| `@locked_objects` | Lock (single inst) | Debug lock |
| `@top_sql` | Top SQL per risorse | Performance tuning |
| `@session_waits` | Wait events |Slowdown diagnosis|
| `@invalid_objects` |Invalid items| Post-upgrade check |
| `@hidden_parameters` | Parametri nascosti | Deep tuning |
| `@patch_registry` | Patch installate | Compliance check |

> 📥 **Download**: Clona il repo `git clone https://github.com/oraclebase/dba.git` e metti la cartella `monitoring/` in `$ORACLE_BASE/scripts/`. Then execute`@$ORACLE_BASE/scripts/monitoring/sessions_rac.sql`.

---

## 7. Practical Lab Exercises

### Exercise 1: Listener and Connection

```bash
#1. Check the status of the listener
lsnrctl status

#2. Check the registered services
lsnrctl services

#3. Check your CRS configuration
srvctl status listener
srvctl status scan_listener

#4. Test the connection via SCAN
tnsping rac-scan

#5. Connect via SCAN
sqlplus sys/<password>@rac-scan:1521/ORCL as sysdba

#6. Connect directly to node 1
sqlplus sys/<password>@rac1-vip:1521/ORCL1 as sysdba

#7. Check session and service
SELECT instance_name, host_name, status FROM v$instance;
SELECT sys_context('USERENV','SERVICE_NAME') FROM dual;
```

### Exercise 2: Creating and Testing a Service

```bash
#1. Create an OLTP Service (Both Nodes)
srvctl add service -db ORCL -service ORCL_OLTP \
  -preferred ORCL1,ORCL2

# 2. Avvialo
srvctl start service -db ORCL -service ORCL_OLTP

#3. Check
srvctl status service -db ORCL

#4. Connect VIA the service
sqlplus hr/hr@rac-scan:1521/ORCL_OLTP

#5. Check in SQL*Plus
SELECT service_name, COUNT(*)
FROM   gv$session
WHERE  service_name = 'ORCL_OLTP'
GROUP BY service_name;

#6. Move the service to a single node (maintenance)
srvctl relocate service -db ORCL -service ORCL_OLTP \
  -oldinst ORCL1 -newinst ORCL2

#7. Verify that all sessions are on node2
```

### Exercise 3: Complete Monitoring

```bash
#1. Clone Oracle Base scripts
cd $ORACLE_BASE
git clone https://github.com/oraclebase/dba.git scripts_ob

#2. From SQL*Plus, run the tuning check
sqlplus / as sysdba
@/u01/app/oracle/scripts_ob/monitoring/tuning.sql

#3. Check RAC sessions
@/u01/app/oracle/scripts_ob/rac/sessions_rac.sql

#4. Check the space
@/u01/app/oracle/scripts_ob/monitoring/free_space.sql

#5. Check the locks
@/u01/app/oracle/scripts_ob/rac/locked_objects_rac.sql
```

### Exercise 4: Simulate a Problem and Solve It

```bash
# Session 1 — Create a lock
sqlplus hr/hr@ORCL
UPDATE employees SET salary = salary * 1.1 WHERE employee_id = 100;
-- NON dare COMMIT!

# Session 2 — Search for the lock
sqlplus / as sysdba
@locked_objects_rac.sql
--You will see the Row-X (SX) lock on the EMPLOYEES object

# Session 3 — Kill the blocking session
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;

#Session 1 — You will see: ORA-00028: your session has been killed
```

---

## Appendix A: Production Listener Checklist

| # | Check | Comando | OK? |
|---|---|---|---|
| 1 | Active listener on each node | `srvctl status listener` | ☐ |
| 2 | SCAN listener active (3 IPs) | `srvctl status scan_listener` | ☐ |
| 3 | DNS risolve SCAN a 3 IP | `nslookup rac-scan` | ☐ |
| 4 | Registered services | `lsnrctl services` | ☐ |
| 5 | `local_listener`correct| `SHOW PARAMETER local_listener` | ☐ |
| 6 | `remote_listener` = SCAN | `SHOW PARAMETER remote_listener` | ☐ |
| 7 | Entry statica per DG |Check`listener.ora` | ☐ |
| 8 | `tnsping`works| `tnsping ORCL` | ☐ |
| 9 | Custom services created | `srvctl status service -db ORCL` | ☐ |
| 10 |Connection via SCAN OK| `sqlplus user/pass@rac-scan/ORCL` | ☐ |

---

> **Fonte**: Script monitoring da [github.com/oraclebase/dba](https://github.com/oraclebase/dba)(Tim Hall). Architecture from [oracle-base.com](https://oracle-base.com).
