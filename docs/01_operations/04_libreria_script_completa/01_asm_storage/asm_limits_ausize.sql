-- Analisi Limiti Fisici ASM basati su AU_SIZE, Compatibilità e Ridondanza
-- Utilizza questa query per il Capacity Planning proattivo.

set lines 222 pages 1000
col diskgroup_name for a15
col compatible_rdbms for a10
col max_file_size for a15
col USAGE_ALERT for a15
DEFINE ALERT_PERC=80

SELECT
    dg.name AS diskgroup_name,       
    dg.type AS redundancy_type,      
    dg.database_compatibility AS compatible_rdbms,     
    dg.allocation_unit_size / 1024 / 1024 AS au_size_mb,           
    ROUND(dg.total_mb / 1024) AS total_gb,
    ROUND(dg.free_mb / 1024)  AS free_gb,
    ROUND((1 - dg.free_mb / dg.total_mb) * 100, 2) AS pct_used,             
    COUNT(d.disk_number) AS num_disks,            
    CASE
        WHEN dg.compat_num >= 12.1 THEN
            CASE dg.allocation_unit_size
                WHEN 1048576 THEN 4   
                WHEN 2097152 THEN 8   
                WHEN 4194304 THEN 16  
                WHEN 8388608 THEN 32  
                ELSE 2
            END
        ELSE 2 
    END AS max_pb_per_disk,
    ROUND(
        COUNT(d.disk_number) *
        (CASE WHEN dg.compat_num >= 12.1 THEN CASE
dg.allocation_unit_size WHEN 1048576 THEN 4 WHEN 2097152 THEN 8 WHEN
4194304 THEN 16 WHEN 8388608 THEN 32 ELSE 2 END ELSE 2 END)
    , 2) AS max_pb_per_dg,
    CASE
        WHEN dg.compat_num >= 12.1 THEN
            (CASE dg.allocation_unit_size WHEN 1048576 THEN 4 WHEN
2097152 THEN 8 WHEN 4194304 THEN 16 WHEN 8388608 THEN 32 ELSE 2 END) *
1024
        WHEN dg.compat_num >= 11.1 THEN 128
        WHEN dg.compat_num <= 10.1 THEN
            CASE dg.allocation_unit_size
                WHEN 1048576 THEN CASE UPPER(dg.type) WHEN 'EXTERN'
THEN 64 WHEN 'NORMAL' THEN 22 WHEN 'HIGH' THEN 15 END
                WHEN 4194304 THEN CASE UPPER(dg.type) WHEN 'EXTERN'
THEN 256 WHEN 'NORMAL' THEN 128 WHEN 'HIGH' THEN 84 END
            END
    END AS max_tb_supported,
    CASE
        WHEN dg.compat_num >= 11.1 THEN 128
        WHEN dg.compat_num <= 10.1 THEN
            CASE dg.allocation_unit_size
                WHEN 1048576 THEN CASE UPPER(dg.type) WHEN 'EXTERN'
THEN 16  WHEN 'NORMAL' THEN 5.8 WHEN 'HIGH' THEN 3.9 END
                WHEN 4194304 THEN CASE UPPER(dg.type) WHEN 'EXTERN'
THEN 64  WHEN 'NORMAL' THEN 32  WHEN 'HIGH' THEN 21  END
                WHEN 8388608 THEN CASE UPPER(dg.type) WHEN 'EXTERN'
THEN 128 WHEN 'NORMAL' THEN 64  WHEN 'HIGH' THEN 42  END
            END
    END AS max_tb_bf_limit,
    ROUND((4194303 * (SELECT TO_NUMBER(value) FROM v$parameter WHERE
name = 'db_block_size')) / POWER(1024, 3)) AS max_gb_df_sf_base_bs,
    ROUND(LEAST(
        (4194303 * (SELECT value FROM v$parameter WHERE name =
'db_block_size') * 65534 / POWER(1024, 4)),
        (CASE WHEN dg.compat_num >= 12.1 THEN (CASE
dg.allocation_unit_size WHEN 1048576 THEN 4 WHEN 2097152 THEN 8 WHEN
4194304 THEN 16 WHEN 8388608 THEN 32 ELSE 2 END) * 1024 WHEN
dg.compat_num >= 11.1 THEN 128 WHEN dg.compat_num <= 10.1 THEN CASE
dg.allocation_unit_size WHEN 1048576 THEN CASE UPPER(dg.type) WHEN
'EXTERN' THEN 64 WHEN 'NORMAL' THEN 22 WHEN 'HIGH' THEN 15 END WHEN
4194304 THEN CASE UPPER(dg.type) WHEN 'EXTERN' THEN 256 WHEN 'NORMAL'
THEN 128 WHEN 'HIGH' THEN 84 END END END)
    )) AS max_tb_ts_sf_limit,
    CASE
        WHEN (1 - dg.free_mb / dg.total_mb) * 100 >= &ALERT_PERC THEN
'^' || '&ALERT_PERC' || '%' 
        ELSE 'OK' 
    END AS "Alert^ALERT_PERC"
FROM (
    SELECT
        group_number,
        name,
        type,
        allocation_unit_size,
        total_mb,
        free_mb,
        database_compatibility,
        CAST(REGEXP_SUBSTR(database_compatibility, '^\d+\.\d+') AS
NUMBER) AS compat_num
    FROM v$asm_diskgroup
) dg
JOIN v$asm_disk d ON dg.group_number = d.group_number
GROUP BY
    dg.name, dg.type, dg.database_compatibility, dg.allocation_unit_size,
    dg.total_mb, dg.free_mb, dg.compat_num
ORDER BY pct_used DESC;
