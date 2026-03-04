# PHASE 7: RMAN Backup Strategy

> Implement a comprehensive RMAN backup strategy for all 3 databases: Primary RAC, Standby RAC, and Target.

## Backup Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  RAC PRIMARY     │     │  RAC STANDBY     │     │  TARGET DB       │
│  (RACDB)         │     │  (RACDB_STBY)    │     │  (dbtarget)      │
│                  │     │                  │     │                  │
│  Backup: NO ❌   │     │  Backup: YES ✅  │     │  Backup: YES ✅  │
│  (offload to     │     │  Level 0 weekly  │     │  Level 0 weekly  │
│   standby)       │     │  Level 1 daily   │     │  Level 1 daily   │
└──────────────────┘     │  Archivelog 2h   │     │  Archivelog 4h   │
                         └──────────────────┘     └──────────────────┘
```

> **Why backup from standby?** Zero impact on primary performance. The standby has the exact same data thanks to redo apply.

---

## RMAN Configuration

```rman
RMAN> CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 7 DAYS;
RMAN> CONFIGURE BACKUP OPTIMIZATION ON;
RMAN> CONFIGURE CONTROLFILE AUTOBACKUP ON;
RMAN> CONFIGURE DEVICE TYPE DISK PARALLELISM 2;
RMAN> CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/backup/rman/%d_%T_%s_%p.bkp';
```

## Block Change Tracking (BCT) — Faster Incrementals

```sql
ALTER DATABASE ENABLE BLOCK CHANGE TRACKING USING FILE '+FRA/RACDB_STBY/bct.dbf';
```

> BCT tracks which blocks changed since last backup. Without it, RMAN reads the ENTIRE database to find changed blocks. With BCT, incrementals finish in minutes instead of hours.

## Backup Scripts

### Level 0 (Full - Weekly)
```rman
RUN {
  BACKUP INCREMENTAL LEVEL 0 DATABASE
    FORMAT '/backup/rman/%d_L0_%T_%s_%p.bkp'
    TAG 'WEEKLY_L0';
  BACKUP ARCHIVELOG ALL
    FORMAT '/backup/rman/%d_ARCH_%T_%s_%p.bkp'
    TAG 'ARCH_WEEKLY'
    DELETE INPUT;
  DELETE NOPROMPT OBSOLETE;
}
```

### Level 1 (Incremental - Daily)
```rman
RUN {
  BACKUP INCREMENTAL LEVEL 1 DATABASE
    FORMAT '/backup/rman/%d_L1_%T_%s_%p.bkp'
    TAG 'DAILY_L1';
  BACKUP ARCHIVELOG ALL
    FORMAT '/backup/rman/%d_ARCH_%T_%s_%p.bkp'
    TAG 'ARCH_DAILY'
    DELETE INPUT;
}
```

## Crontab Schedule

```bash
# Level 0 - Sunday 2 AM
0 2 * * 0 /home/oracle/scripts/rman_level0.sh >> /var/log/rman_l0.log 2>&1

# Level 1 - Mon-Sat 2 AM
0 2 * * 1-6 /home/oracle/scripts/rman_level1.sh >> /var/log/rman_l1.log 2>&1

# Archivelog - Every 2 hours
0 */2 * * * /home/oracle/scripts/rman_arch.sh >> /var/log/rman_arch.log 2>&1
```

## Test Restore (CRITICAL — Always test your backups!)

```rman
-- Test restore without actually restoring
RESTORE DATABASE VALIDATE;
RESTORE ARCHIVELOG ALL VALIDATE;

-- Check backup completeness
REPORT NEED BACKUP;
LIST BACKUP SUMMARY;
```

---

**🏆 LAB COMPLETE! All phases implemented successfully.**
