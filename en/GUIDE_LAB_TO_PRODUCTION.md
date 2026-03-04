# Lab to Production — Sizing and Tuning Guide

> How to scale the lab architecture (RAC + Data Guard + GoldenGate) to a real production environment. Same architecture, bigger numbers.

---

## Same Architecture, More Resources

```
  LAB (VirtualBox)                         PRODUCTION (Bare Metal / VM / Cloud)
  ═════════════════                        ═══════════════════════════════════════

  rac1    rac2                              racprod1         racprod2
  4GB     4GB       ───────────►            64-256 GB        64-256 GB
  2 vCPU  2 vCPU                            16-32 CPU        16-32 CPU
  VDI disks                                 SAN/NAS/Exadata storage
  1 GbE                                     10-25 GbE interconnect
```

---

## 1. Hardware Sizing

### RAM per Node

```
╔═══════════════════════════════╦═══════════════╦═══════════════╦═══════════════╗
║ Component                     ║ Lab (4 GB)    ║ Small Prod    ║ Large Prod    ║
╠═══════════════════════════════╬═══════════════╬═══════════════╬═══════════════╣
║ SGA_TARGET                    ║ ~1 GB (auto)  ║ 32 GB         ║ 96-128 GB     ║
║   ├─ Buffer Cache             ║ ~600 MB       ║ 20 GB         ║ 80 GB         ║
║   ├─ Shared Pool              ║ ~200 MB       ║ 8 GB          ║ 16 GB         ║
║   └─ Large Pool               ║ ~50 MB        ║ 2 GB          ║ 8 GB          ║
║ PGA_AGGREGATE_TARGET          ║ ~500 MB       ║ 8 GB          ║ 32 GB         ║
║ OS + CRS + ASM                ║ ~1.5 GB       ║ 8 GB          ║ 16 GB         ║
╠═══════════════════════════════╬═══════════════╬═══════════════╬═══════════════╣
║ TOTAL RAM PER NODE            ║ 4 GB          ║ 64 GB         ║ 256 GB        ║
╚═══════════════════════════════╩═══════════════╩═══════════════╩═══════════════╝
```

> **Rule of thumb**: SGA = 60-70% of total RAM. PGA = 10-20%. Rest for OS, CRS, ASM.

### Storage (ASM)

| Disk Group | Lab | Production |
|---|---|---|
| +CRS | 5 GB, EXTERNAL | 10-20 GB, **NORMAL** (3 failure groups) |
| +DATA | 20 GB, EXTERNAL | 500 GB-10 TB+, **NORMAL/HIGH** |
| +FRA | 15 GB, EXTERNAL | 200 GB-5 TB+, **NORMAL**, size = 2× DATA |
| +REDO | (none) | SSD/NVMe dedicated for redo (low latency = fast COMMIT) |

---

## 2. Key Production Parameters

```sql
ALTER SYSTEM SET sga_target = 32G SCOPE=SPFILE SID='*';
ALTER SYSTEM SET pga_aggregate_target = 8G SCOPE=SPFILE SID='*';
ALTER SYSTEM SET undo_retention = 1800 SCOPE=BOTH SID='*';  -- 30 min
ALTER SYSTEM SET processes = 1500 SCOPE=SPFILE SID='*';
```

### HugePages (Linux — MANDATORY in Production!)

```bash
# SGA = 32 GB → 32*1024/2 = 16384 hugepages (2 MB each)
echo "vm.nr_hugepages = 16384" >> /etc/sysctl.conf
sysctl -p
# Disable Transparent HugePages
echo never > /sys/kernel/mm/transparent_hugepage/enabled
```

---

## 3. Security Additions

| Area | Lab | Production |
|---|---|---|
| Firewall | Disabled | **Enabled** (ports 1521, 7809) |
| SELinux | Disabled | **Permissive/Enforcing** |
| Encryption | None | **TDE** + Native Network Encryption |
| Audit | Minimal | **Unified Auditing** |
| Passwords | Simple | Complex + 90-day rotation |

---

## 4. Production Go-Live Checklist

```
□ RAM: 64+ GB/node              □ ARCHIVELOG + FORCE LOGGING
□ CPU: 16+ cores/node           □ BCT enabled
□ NIC bonding (public+intercon) □ Undo retention >= 1800s
□ HugePages + THP disabled      □ Redo: 4+ groups, 1-4 GB each
□ ASM NORMAL/HIGH redundancy    □ Statistics auto-collection verified
□ Data Guard + FAN/CLB/RLB      □ RMAN backup tested (RESTORE VALIDATE)
□ TDE + Unified Auditing        □ orachk PASS
□ OEM or Grafana monitoring     □ DR tested (switchover + failover)
```

> **Remember**: Your lab and production have the **same architecture**. The difference is: more RAM, more CPU, more disks, more redundancy, more security, more monitoring.
