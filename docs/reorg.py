import os
import subprocess
import shutil

os.chdir(r"c:\DBA\dba_oracle_lab\docs")

def run(cmd):
    #print(f"Running: {cmd}")
    subprocess.run(cmd, shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def move_contents(src_dir, dst_dir):
    if not os.path.exists(src_dir):
        return
    for item in os.listdir(src_dir):
        src_path = os.path.join(src_dir, item)
        dst_path = os.path.join(dst_dir, item)
        try:
            run(f'git mv "{src_path}" "{dst_path}"')
        except subprocess.CalledProcessError:
            print(f"Failed to move {src_path}")
    shutil.rmtree(src_dir, ignore_errors=True)

# Create macro directories
ensure_dir("01_operations")
ensure_dir("02_core_dba")
ensure_dir("03_infra_lab")
ensure_dir("04_governance_learning")

# --- 1. OPERATIONS ---
ensure_dir(r"01_operations\01_cheat_sheets")
move_contents("00_cheat_sheet", r"01_operations\01_cheat_sheets")

ensure_dir(r"01_operations\02_runbooks_incidenti")
move_contents("11_runbook_operativi", r"01_operations\02_runbooks_incidenti")

ensure_dir(r"01_operations\03_scripts_pronti")
move_contents("12_scripts_sql_pronti", r"01_operations\03_scripts_pronti")

ensure_dir(r"01_operations\04_libreria_script_completa")
move_contents("13_libreria_completa_script", r"01_operations\04_libreria_script_completa")

# --- 2. CORE DBA GUIDES ---
ensure_dir(r"02_core_dba\01_administration_and_security")
move_contents("04_administration", r"02_core_dba\01_administration_and_security")
move_contents("18_setup_ldap", r"02_core_dba\01_administration_and_security")

ensure_dir(r"02_core_dba\02_backup_and_recovery")
move_contents("03_backup_recovery", r"02_core_dba\02_backup_and_recovery")
move_contents("15_rman_comandi", r"02_core_dba\02_backup_and_recovery")

ensure_dir(r"02_core_dba\03_performance_and_diagnostics")
move_contents("05_performance", r"02_core_dba\03_performance_and_diagnostics")
move_contents("17_adrci_trace", r"02_core_dba\03_performance_and_diagnostics")

ensure_dir(r"02_core_dba\04_high_availability_and_rac")
move_contents("02_high_availability", r"02_core_dba\04_high_availability_and_rac")

ensure_dir(r"02_core_dba\05_patching_and_upgrades")
move_contents("06_patching_upgrade", r"02_core_dba\05_patching_and_upgrades")

ensure_dir(r"02_core_dba\06_monitoring_systems")
move_contents("08_monitoring", r"02_core_dba\06_monitoring_systems")
move_contents("19_setup_checkmk", r"02_core_dba\06_monitoring_systems")

ensure_dir(r"02_core_dba\07_replication_goldengate")
move_contents("07_replication", r"02_core_dba\07_replication_goldengate")

# --- 3. INFRA LAB & SETUP ---
ensure_dir(r"03_infra_lab\01_proxmox_hardware")
move_contents("16_proxmox_track", r"03_infra_lab\01_proxmox_hardware")

ensure_dir(r"03_infra_lab\02_oracle_installation_asm")
move_contents("01_lab_setup", r"03_infra_lab\02_oracle_installation_asm")

ensure_dir(r"03_infra_lab\03_cloud_oci")
move_contents("09_cloud_oci", r"03_infra_lab\03_cloud_oci")

# --- 4. GOVERNANCE & LEARNING ---
ensure_dir(r"04_governance_learning\01_fondamenti_teorici")
move_contents("00_fondamenti", r"04_governance_learning\01_fondamenti_teorici")

ensure_dir(r"04_governance_learning\02_enterprise_standards")
move_contents("14_enterprise_governance", r"04_governance_learning\02_enterprise_standards")

ensure_dir(r"04_governance_learning\03_esami_e_carriera")
move_contents("10_esami_carriera", r"04_governance_learning\03_esami_e_carriera")
move_contents("00_lab_percorso", r"04_governance_learning\03_esami_e_carriera")

print("Git MV Completed cleanly.")
