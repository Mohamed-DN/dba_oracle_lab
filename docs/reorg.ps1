$ErrorActionPreference = "Stop"

Set-Location "c:\DBA\dba_oracle_lab\docs"

# Create macro directories
New-Item -ItemType Directory -Force -Path "01_operations"
New-Item -ItemType Directory -Force -Path "02_core_dba"
New-Item -ItemType Directory -Force -Path "03_infra_lab"
New-Item -ItemType Directory -Force -Path "04_governance_learning"

# --- 1. OPERATIONS ---
git mv "00_cheat_sheet" "01_operations\01_cheat_sheets"
git mv "11_runbook_operativi" "01_operations\02_runbooks_incidenti"
git mv "12_scripts_sql_pronti" "01_operations\03_scripts_pronti"
git mv "13_libreria_completa_script" "01_operations\04_libreria_script_completa"

# --- 2. CORE DBA GUIDES ---
# 01_administration_and_security
New-Item -ItemType Directory -Force -Path "02_core_dba\01_administration_and_security"
git mv 04_administration\* "02_core_dba\01_administration_and_security\"
git mv 18_setup_ldap\* "02_core_dba\01_administration_and_security\"
Remove-Item -Recurse -Force 04_administration
Remove-Item -Recurse -Force 18_setup_ldap

# 02_backup_and_recovery
New-Item -ItemType Directory -Force -Path "02_core_dba\02_backup_and_recovery"
git mv 03_backup_recovery\* "02_core_dba\02_backup_and_recovery\"
git mv 15_rman_comandi\* "02_core_dba\02_backup_and_recovery\"
Remove-Item -Recurse -Force 03_backup_recovery
Remove-Item -Recurse -Force 15_rman_comandi

# 03_performance_and_diagnostics
New-Item -ItemType Directory -Force -Path "02_core_dba\03_performance_and_diagnostics"
git mv 05_performance\* "02_core_dba\03_performance_and_diagnostics\"
git mv 17_adrci_trace\* "02_core_dba\03_performance_and_diagnostics\"
Remove-Item -Recurse -Force 05_performance
Remove-Item -Recurse -Force 17_adrci_trace

# others
git mv "02_high_availability" "02_core_dba\04_high_availability_and_rac"
git mv "06_patching_upgrade" "02_core_dba\05_patching_and_upgrades"

# 06_monitoring_systems
New-Item -ItemType Directory -Force -Path "02_core_dba\06_monitoring_systems"
git mv 08_monitoring\* "02_core_dba\06_monitoring_systems\"
git mv 19_setup_checkmk\* "02_core_dba\06_monitoring_systems\"
Remove-Item -Recurse -Force 08_monitoring
Remove-Item -Recurse -Force 19_setup_checkmk

# 07_replication_goldengate
git mv "07_replication" "02_core_dba\07_replication_goldengate"


# --- 3. INFRA LAB & SETUP ---
git mv "16_proxmox_track" "03_infra_lab\01_proxmox_hardware"
git mv "01_lab_setup" "03_infra_lab\02_oracle_installation_asm"
git mv "09_cloud_oci" "03_infra_lab\03_cloud_oci"


# --- 4. GOVERNANCE & LEARNING ---
git mv "00_fondamenti" "04_governance_learning\01_fondamenti_teorici"
git mv "14_enterprise_governance" "04_governance_learning\02_enterprise_standards"

# 03_esami_e_carriera
New-Item -ItemType Directory -Force -Path "04_governance_learning\03_esami_e_carriera"
git mv 10_esami_carriera\* "04_governance_learning\03_esami_e_carriera\"
git mv 00_lab_percorso\* "04_governance_learning\03_esami_e_carriera\"
Remove-Item -Recurse -Force 10_esami_carriera
Remove-Item -Recurse -Force 00_lab_percorso

Write-Output "File movement completed."
