# From Lab to Production — Guide to Sizing and Tuning

> This guide explains how to scale the lab architecture (RAC + Data Guard + GoldenGate) to a real production environment. The architecture is the same, the numbers change.

---

## The Principle: Same Architecture, More Resources

```
  LAB (VirtualBox) PRODUCTION (Bare Metal / VM / Cloud)
  ═════════════════                        ═══════════════════════════════════════

  ┌────────────────┐                       ┌────────────────────────────────┐
  │ rac1    rac2   │                       │ racprod1         racprod2     │
  │ 4GB     4GB    │    ───────────►       │ 64-256 GB        64-256 GB    │
  │ 2 vCPU  2 vCPU │                       │ 16-32 CPU        16-32 CPU    │
  │ VDI disks      │                       │ SAN/NAS/Exadata storage       │
  │ 1 GbE          │                       │ 10-25 GbE intercon.           │
  └────────────────┘                       └────────────────────────────────┘

  ASM: EXTERNAL redundancy                ASM: NORMAL o HIGH redundancy
  SGA: ~1 GB (auto)                        SGA: 32-128 GB (ASMM)
  PGA: ~500 MB                             PGA: 8-32 GB
  UNDO: 500 MB                             UNDO: 10-50 GB
  TEMP: 500 MB                             TEMP: 5-30 GB
```

---

## 1. Hardware — What's Changing

### Sizing RAM per Node

```
╔═══════════════════════════════╦═══════════════╦═══════════════╦═══════════════╗
║ Component ║ Lab (4 GB) ║ Small Prod ║ Large Prod ║
╠═══════════════════════════════╬═══════════════╬═══════════════╬═══════════════╣
║ SGA_TARGET                    ║ ~1 GB (auto)  ║ 32 GB         ║ 96-128 GB     ║
║   ├─ Buffer Cache             ║ ~600 MB       ║ 20 GB         ║ 80 GB         ║
║   ├─ Shared Pool              ║ ~200 MB       ║ 8 GB          ║ 16 GB         ║
║   ├─ Large Pool               ║ ~50 MB        ║ 2 GB          ║ 8 GB          ║
║   └─ Redo Log Buffer          ║ ~10 MB        ║ 256 MB        ║ 512 MB        ║
║ PGA_AGGREGATE_TARGET          ║ ~500 MB       ║ 8 GB          ║ 32 GB         ║
║ OS + CRS + ASM                ║ ~1.5 GB       ║ 8 GB          ║ 16 GB         ║
╠═══════════════════════════════╬═══════════════╬═══════════════╬═══════════════╣
║ TOTAL RAM PER NODE ║ 4 GB ║ 64 GB ║ 256 GB ║
╚═══════════════════════════════╩═══════════════╩═══════════════╩═══════════════╝
```

> **Rule of thumb**: SGA = 60-70% of total RAM. PGA_AGGREGATE_TARGET = 10-20%. Il resto per OS, CRS, ASM.

### CPU per Node

| Load | Lab |Small Prod| Large Prod |
|---|---|---|---|
|OLTP (many small transactions)| 2 vCPU | 16 CPU | 32+ CPU |
| DSS/DWH (poche query pesanti) | 2 vCPU | 8 CPU | 16+ CPU |
| Misto | 2 vCPU | 16 CPU | 24+ CPU |

### Storage

```
╔════════════════════╦═══════════════╦═══════════════════════════════════╗
║ Disk Group ║ Lab ║ Production ║
╠════════════════════╬═══════════════╬═══════════════════════════════════╣
║ +CRS               ║ 5 GB          ║ 10-20 GB                          ║
║                    ║ EXTERNAL      ║ NORMAL (3 failure groups)         ║
╠════════════════════╬═══════════════╬═══════════════════════════════════╣
║ +DATA              ║ 20 GB         ║ 500 GB - 10 TB+                  ║
║                    ║ EXTERNAL      ║ NORMAL o HIGH redundancy          ║
║ ║ 1 VDI disk ║ 8-16+ SAN/NVMe LUN ║
╠════════════════════╬═══════════════╬═══════════════════════════════════╣
║ +FRA               ║ 15 GB         ║ 200 GB - 5 TB+                   ║
║                    ║ EXTERNAL      ║ NORMAL redundancy                 ║
║ ║ ║ Size = 2x DATA (ideal) ║
╠════════════════════╬═══════════════╬═══════════════════════════════════╣
║ +REDO (optional) ║ not present ║ Dedicated SSD/NVMe for redo log ║
║ ║ ║ Low latency = fast COMMIT ║
╚════════════════════╩═══════════════╩═══════════════════════════════════╝
```

> **ASM Redundancy in Production:**
> - **EXTERNAL**: The underlying storage (SAN with RAID) is mirrored. Oracle does not duplicate.
> - **NORMAL**: Oracle makes 2 copies. Protects against 1 disk failure. Used for +CRS, +FRA.
> - **HIGH**: Oracle makes 3 copies. Protects against 2 faults. Used for +DATA critical.

---

## 2. Network - What's Changing

```
LAB: PRODUCTION:
1 GbE Bridged (pubblica)          2x 10/25 GbE bonded (pubblica + VIP + SCAN)
1 GbE Host-Only (interconnect)    2x 10/25 GbE bonded (interconnect) o
                                   InfiniBand (56-100 Gbps per Exadata)
                                   + Oracle HAIP (4 IP su bonded NICs)
```

| Parametro | Lab | Production |
|---|---|---|
| Public network | 1 GbE shared | 2x 10 GbE bonded (LACP) |
| Interconnect | 1 GbE host-only | 2x 10/25 GbE o InfiniBand |
| Jumbo Frames | No | **Yes** (MTU 9000) — reduces overhead |
| HAIP | No | **Yes** — Oracle High Availability IP |

---

## 3. Database Parameters — Production Tuning

### Init Parameters Critici

```sql
-- ========= MEMORY =========
ALTER SYSTEM SET sga_target = 32G SCOPE=SPFILE SID='*';
ALTER SYSTEM SET sga_max_size = 40G SCOPE=SPFILE SID='*';
ALTER SYSTEM SET pga_aggregate_target = 8G SCOPE=SPFILE SID='*';
-- NON usare memory_target su Linux con HugePages (usa ASMM)

-- ========= UNDO =========
ALTER SYSTEM SET undo_retention = 1800 SCOPE=BOTH SID='*';  -- 30 min
--In production: 1800-3600 seconds to avoid ORA-01555

-- ========= REDO =========
--Online Redo Log: at least 4 groups, 1-4 GB per group
--Log switch every 15-20 minutes (not too frequent)

-- ========= PROCESSES & SESSIONS =========
ALTER SYSTEM SET processes = 1500 SCOPE=SPFILE SID='*';
--sessions = 1.5 * processes + 22 (calculated automatically)

-- ========= PARALLELISM =========
ALTER SYSTEM SET parallel_max_servers = 64 SCOPE=BOTH SID='*';
ALTER SYSTEM SET parallel_min_servers = 4 SCOPE=BOTH SID='*';

-- ========= OPTIMIZER =========
ALTER SYSTEM SET optimizer_adaptive_plans = TRUE SCOPE=BOTH SID='*';
ALTER SYSTEM SET optimizer_adaptive_statistics = FALSE SCOPE=BOTH SID='*';
```

### HugePages (Linux — MANDATORY in Production!)

```bash
# Calculate hugepages needed (2 MB per page)
# SGA = 32 GB → 32*1024/2 = 16384 hugepages

echo "vm.nr_hugepages = 16384" >> /etc/sysctl.conf
sysctl -p

# Disabilita Transparent HugePages (THP) — MOLTO IMPORTANTE!
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

> **Why HugePages?** Normal memory uses 4KB pages. With 32GB SGA, the kernel handles 8 million pages → very slow. With HugePages (2 MB), that's just 16,384 pages → 500x more efficient handling. Bonus: HugePages are never swapped!

---

## 4. Security — What to Add in Production

| Area |Lab (simplified)| Production |
|---|---|---|
| Firewall | Disabilitato |**Enabled** with ports 1521, 1522, 7809 open|
| SELinux | Disabilitato | **Permissive** o **Enforcing** con policy Oracle |
| Encryption | Nessuna | **TDE** (Transparent Data Encryption) per datafile |
| Network Encryption | Nessuna | **Native Network Encryption** o SSL/TLS |
| Audit | Minimo | **Unified Auditing** abilitato |
| Password | Semplici | Complex policy + 90 day rotation |
| SSH | Password | **SSH keys** (no auth password) |

---

## 5. Monitoring — What to Add

```
LAB: PRODUCTION:
Script manuali                    Oracle Enterprise Manager (OEM) 13c
crontab health check + Cloud Control Agent on each node
manual alert log + centralized dashboard
                                  + Email/SMS alerting
                                  + Integration con PagerDuty/ServiceNow

Alternativa OEM:                  Grafana + Prometheus + oracle_exporter
                                  (open source, lighter)
```

### orachk — Health Check Oracle Automatizzato

```bash
# Download orachk from MOS (Doc 1268927.2)
# Run this monthly and before/after every patching
./orachk -a
# Generate an HTML report with Oracle recommendations
```

---

## 6. Final Production Checklist

```
╔═══════════════════════════════════════════════════════════════╗
║ GO-LIVE PRODUCTION CHECKLIST ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  HARDWARE & OS                                               ║
║ □ RAM: at least 64 GB per node ║
║ □ CPU: at least 16 cores per node ║
║  □ Storage SAN/NVMe con multipath                            ║
║  □ NIC bonding (LACP) per public + interconnect              ║
║ □ HugePages configured, THP disabled ║
║ □ Optimized kernel parameters (shmmax, sem, aio-max) ║
║ □ NTP/chrony synchronized on all nodes ║
║                                                               ║
║  DATABASE                                                    ║
║ □ ARCHIVELOG mode active ║
║ □ FORCE LOGGING active ║
║  □ BCT (Block Change Tracking) abilitato                     ║
║ □ Undo retention >= 1800 seconds ║
║  □ Redo Log: 4+ gruppi, 1-4 GB, switch ogni 15-20 min       ║
║ □ Processes >= 1000 (based on expected load) ║
║ □ Automatic statistics verified ║
║ □ Active password policy ║
║                                                               ║
║  ASM                                                         ║
║  □ +CRS: NORMAL redundancy (3 failure groups)                ║
║  □ +DATA: NORMAL o HIGH redundancy                           ║
║  □ +FRA: NORMAL redundancy, dimensione >= 2x DATA           ║
║ □ All disks same size and performance ║
║                                                               ║
║  HIGH AVAILABILITY                                           ║
║ □ Data Guard configured with physical standby ║
║  □ Fast-Start Failover (FSFO) opzionale con Observer         ║
║  □ FAN (Fast Application Notification) abilitato             ║
║ □ Services configured (do not use default service!) ║
║  □ CLB + RLB (Connection/Runtime Load Balancing)             ║
║                                                               ║
║  BACKUP & RECOVERY                                           ║
║ □ RMAN backup Level 0 weekly + Level 1 daily ║
║  □ Archivelog backup ogni 1-2 ore                            ║
║ □ RESTORE DATABASE VALIDATE completed successfully ║
║ □ Tested DR procedure (switchover + failover) ║
║                                                               ║
║  SICUREZZA                                                   ║
║ □ Active firewall with specific ports ║
║ □ TDE for datafile encryption ║
║  □ Unified Auditing abilitato                                ║
║  □ Network encryption (Native o SSL)                         ║
║                                                               ║
║  MONITORING                                                  ║
║ □ OEM or Grafana+Prometheus configured ║
║ □ orachk executed and PASS complete ║
║ □ Email alert for: space, ORA- errors, failed jobs ║
║  □ AWR snapshot ogni 30 min (default)                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

> **Remember**: Your lab AND production have the **same architecture**. The difference is: more RAM, more CPU, more disks, more redundancy, more security, more monitoring. The concepts you learned in the lab apply 1:1 in production.
