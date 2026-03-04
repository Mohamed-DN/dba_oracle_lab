# Dal Lab alla Produzione — Guida al Sizing e Tuning

> Questa guida spiega come scalare l'architettura del lab (RAC + Data Guard + GoldenGate) verso un ambiente di produzione reale. L'architettura è la stessa, cambiano i numeri.

---

## Il Principio: Stessa Architettura, Più Risorse

```
  LAB (VirtualBox)                         PRODUZIONE (Bare Metal / VM / Cloud)
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

## 1. Hardware — Cosa Cambia

### Sizing RAM per Nodo

```
╔═══════════════════════════════╦═══════════════╦═══════════════╦═══════════════╗
║ Componente                    ║ Lab (4 GB)    ║ Small Prod    ║ Large Prod    ║
╠═══════════════════════════════╬═══════════════╬═══════════════╬═══════════════╣
║ SGA_TARGET                    ║ ~1 GB (auto)  ║ 32 GB         ║ 96-128 GB     ║
║   ├─ Buffer Cache             ║ ~600 MB       ║ 20 GB         ║ 80 GB         ║
║   ├─ Shared Pool              ║ ~200 MB       ║ 8 GB          ║ 16 GB         ║
║   ├─ Large Pool               ║ ~50 MB        ║ 2 GB          ║ 8 GB          ║
║   └─ Redo Log Buffer          ║ ~10 MB        ║ 256 MB        ║ 512 MB        ║
║ PGA_AGGREGATE_TARGET          ║ ~500 MB       ║ 8 GB          ║ 32 GB         ║
║ OS + CRS + ASM                ║ ~1.5 GB       ║ 8 GB          ║ 16 GB         ║
╠═══════════════════════════════╬═══════════════╬═══════════════╬═══════════════╣
║ RAM TOTALE PER NODO           ║ 4 GB          ║ 64 GB         ║ 256 GB        ║
╚═══════════════════════════════╩═══════════════╩═══════════════╩═══════════════╝
```

> **Regola pratica**: SGA = 60-70% della RAM totale. PGA_AGGREGATE_TARGET = 10-20%. Il resto per OS, CRS, ASM.

### CPU per Nodo

| Carico | Lab | Small Prod | Large Prod |
|---|---|---|---|
| OLTP (molte transazioni piccole) | 2 vCPU | 16 CPU | 32+ CPU |
| DSS/DWH (poche query pesanti) | 2 vCPU | 8 CPU | 16+ CPU |
| Misto | 2 vCPU | 16 CPU | 24+ CPU |

### Storage

```
╔════════════════════╦═══════════════╦═══════════════════════════════════╗
║ Disk Group         ║ Lab           ║ Produzione                        ║
╠════════════════════╬═══════════════╬═══════════════════════════════════╣
║ +CRS               ║ 5 GB          ║ 10-20 GB                          ║
║                    ║ EXTERNAL      ║ NORMAL (3 failure groups)         ║
╠════════════════════╬═══════════════╬═══════════════════════════════════╣
║ +DATA              ║ 20 GB         ║ 500 GB - 10 TB+                  ║
║                    ║ EXTERNAL      ║ NORMAL o HIGH redundancy          ║
║                    ║ 1 disco VDI   ║ 8-16+ LUN SAN/NVMe               ║
╠════════════════════╬═══════════════╬═══════════════════════════════════╣
║ +FRA               ║ 15 GB         ║ 200 GB - 5 TB+                   ║
║                    ║ EXTERNAL      ║ NORMAL redundancy                 ║
║                    ║               ║ Dimensione = 2x DATA (ideale)     ║
╠════════════════════╬═══════════════╬═══════════════════════════════════╣
║ +REDO (opzionale)  ║ non presente  ║ SSD/NVMe dedicato per redo log    ║
║                    ║               ║ Bassa latenza = COMMIT veloce     ║
╚════════════════════╩═══════════════╩═══════════════════════════════════╝
```

> **ASM Redundancy in Produzione:**
> - **EXTERNAL**: Lo storage sottostante (SAN con RAID) fa il mirroring. Oracle non duplica.
> - **NORMAL**: Oracle fa 2 copie. Protegge da 1 guasto disco. Usato per +CRS, +FRA.
> - **HIGH**: Oracle fa 3 copie. Protegge da 2 guasti. Usato per +DATA critico.

---

## 2. Rete — Cosa Cambia

```
LAB:                              PRODUZIONE:
1 GbE Bridged (pubblica)          2x 10/25 GbE bonded (pubblica + VIP + SCAN)
1 GbE Host-Only (interconnect)    2x 10/25 GbE bonded (interconnect) o
                                   InfiniBand (56-100 Gbps per Exadata)
                                   + Oracle HAIP (4 IP su bonded NICs)
```

| Parametro | Lab | Produzione |
|---|---|---|
| Rete pubblica | 1 GbE shared | 2x 10 GbE bonded (LACP) |
| Interconnect | 1 GbE host-only | 2x 10/25 GbE o InfiniBand |
| Jumbo Frames | No | **Sì** (MTU 9000) — riduce overhead |
| HAIP | No | **Sì** — Oracle High Availability IP |

---

## 3. Parametri Database — Tuning Produzione

### Init Parameters Critici

```sql
-- ========= MEMORY =========
ALTER SYSTEM SET sga_target = 32G SCOPE=SPFILE SID='*';
ALTER SYSTEM SET sga_max_size = 40G SCOPE=SPFILE SID='*';
ALTER SYSTEM SET pga_aggregate_target = 8G SCOPE=SPFILE SID='*';
-- NON usare memory_target su Linux con HugePages (usa ASMM)

-- ========= UNDO =========
ALTER SYSTEM SET undo_retention = 1800 SCOPE=BOTH SID='*';  -- 30 min
-- In produzione: 1800-3600 secondi per evitare ORA-01555

-- ========= REDO =========
-- Online Redo Log: almeno 4 gruppi, 1-4 GB per gruppo
-- Log switch ogni 15-20 minuti (non troppo frequente)

-- ========= PROCESSES & SESSIONS =========
ALTER SYSTEM SET processes = 1500 SCOPE=SPFILE SID='*';
-- sessions = 1.5 * processes + 22 (calcolato automaticamente)

-- ========= PARALLELISM =========
ALTER SYSTEM SET parallel_max_servers = 64 SCOPE=BOTH SID='*';
ALTER SYSTEM SET parallel_min_servers = 4 SCOPE=BOTH SID='*';

-- ========= OPTIMIZER =========
ALTER SYSTEM SET optimizer_adaptive_plans = TRUE SCOPE=BOTH SID='*';
ALTER SYSTEM SET optimizer_adaptive_statistics = FALSE SCOPE=BOTH SID='*';
```

### HugePages (Linux — OBBLIGATORIO in Produzione!)

```bash
# Calcola le hugepages necessarie (2 MB per pagina)
# SGA = 32 GB → 32*1024/2 = 16384 hugepages

echo "vm.nr_hugepages = 16384" >> /etc/sysctl.conf
sysctl -p

# Disabilita Transparent HugePages (THP) — MOLTO IMPORTANTE!
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

> **Perché HugePages?** La memoria normale usa pagine da 4 KB. Con 32 GB di SGA, il kernel gestisce 8 milioni di pagine → lentissimo. Con HugePages (2 MB), sono solo 16.384 pagine → gestione 500x più efficiente. Bonus: le HugePages non vengono mai swappate!

---

## 4. Sicurezza — Cosa Aggiungere in Produzione

| Area | Lab (semplificato) | Produzione |
|---|---|---|
| Firewall | Disabilitato | **Abilitato** con porte 1521, 1522, 7809 aperte |
| SELinux | Disabilitato | **Permissive** o **Enforcing** con policy Oracle |
| Encryption | Nessuna | **TDE** (Transparent Data Encryption) per datafile |
| Network Encryption | Nessuna | **Native Network Encryption** o SSL/TLS |
| Audit | Minimo | **Unified Auditing** abilitato |
| Password | Semplici | Policy complessa + rotazione 90 giorni |
| SSH | Password | **Chiavi SSH** (no password auth) |

---

## 5. Monitoring — Cosa Aggiungere

```
LAB:                              PRODUZIONE:
Script manuali                    Oracle Enterprise Manager (OEM) 13c
crontab health check              + Cloud Control Agent su ogni nodo
alert log manuale                 + Dashboard centralizzata
                                  + Email/SMS alerting
                                  + Integration con PagerDuty/ServiceNow

Alternativa OEM:                  Grafana + Prometheus + oracle_exporter
                                  (open source, più leggero)
```

### orachk — Health Check Oracle Automatizzato

```bash
# Scarica orachk da MOS (Doc 1268927.2)
# Eseguilo mensilmente e prima/dopo ogni patching
./orachk -a
# Genera un report HTML con raccomandazioni Oracle
```

---

## 6. Checklist Produzione Finale

```
╔═══════════════════════════════════════════════════════════════╗
║              CHECKLIST GO-LIVE PRODUZIONE                     ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  HARDWARE & OS                                               ║
║  □ RAM: almeno 64 GB per nodo                                ║
║  □ CPU: almeno 16 core per nodo                              ║
║  □ Storage SAN/NVMe con multipath                            ║
║  □ NIC bonding (LACP) per public + interconnect              ║
║  □ HugePages configurate, THP disabilitate                   ║
║  □ Kernel parameters ottimizzati (shmmax, sem, aio-max)      ║
║  □ NTP/chrony sincronizzato su tutti i nodi                  ║
║                                                               ║
║  DATABASE                                                    ║
║  □ ARCHIVELOG mode attivo                                    ║
║  □ FORCE LOGGING attivo                                      ║
║  □ BCT (Block Change Tracking) abilitato                     ║
║  □ Undo retention >= 1800 secondi                            ║
║  □ Redo Log: 4+ gruppi, 1-4 GB, switch ogni 15-20 min       ║
║  □ Processes >= 1000 (basato su carico previsto)             ║
║  □ Statistiche automatiche verificate                        ║
║  □ Password policy attiva                                    ║
║                                                               ║
║  ASM                                                         ║
║  □ +CRS: NORMAL redundancy (3 failure groups)                ║
║  □ +DATA: NORMAL o HIGH redundancy                           ║
║  □ +FRA: NORMAL redundancy, dimensione >= 2x DATA           ║
║  □ Tutti i dischi stessa dimensione e performance            ║
║                                                               ║
║  HIGH AVAILABILITY                                           ║
║  □ Data Guard configurato con standby fisico                 ║
║  □ Fast-Start Failover (FSFO) opzionale con Observer         ║
║  □ FAN (Fast Application Notification) abilitato             ║
║  □ Services configurati (non usare default service!)         ║
║  □ CLB + RLB (Connection/Runtime Load Balancing)             ║
║                                                               ║
║  BACKUP & RECOVERY                                           ║
║  □ RMAN backup Level 0 settimanale + Level 1 giornaliero    ║
║  □ Archivelog backup ogni 1-2 ore                            ║
║  □ RESTORE DATABASE VALIDATE eseguito con successo           ║
║  □ Procedura di DR testata (switchover + failover)           ║
║                                                               ║
║  SICUREZZA                                                   ║
║  □ Firewall attivo con porte specifiche                      ║
║  □ TDE per encryption dei datafile                           ║
║  □ Unified Auditing abilitato                                ║
║  □ Network encryption (Native o SSL)                         ║
║                                                               ║
║  MONITORING                                                  ║
║  □ OEM o Grafana+Prometheus configurato                      ║
║  □ orachk eseguito e PASS completo                           ║
║  □ Alert email per: spazio, errori ORA-, job falliti         ║
║  □ AWR snapshot ogni 30 min (default)                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

> **Ricorda**: Il tuo lab E la produzione hanno la **stessa architettura**. La differenza è: più RAM, più CPU, più dischi, più ridondanza, più sicurezza, più monitoring. I concetti che hai imparato nel lab si applicano 1:1 in produzione.
