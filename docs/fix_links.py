import os

os.chdir(r"c:\DBA\dba_oracle_lab\docs")

folder_map = {
    "00_cheat_sheet": "01_operations/01_cheat_sheets",
    "11_runbook_operativi": "01_operations/02_runbooks_incidenti",
    "12_scripts_sql_pronti": "01_operations/03_scripts_pronti",
    "13_libreria_completa_script": "01_operations/04_libreria_script_completa",
    "04_administration": "02_core_dba/01_administration_and_security",
    "18_setup_ldap": "02_core_dba/01_administration_and_security",
    "03_backup_recovery": "02_core_dba/02_backup_and_recovery",
    "15_rman_comandi": "02_core_dba/02_backup_and_recovery",
    "05_performance": "02_core_dba/03_performance_and_diagnostics",
    "17_adrci_trace": "02_core_dba/03_performance_and_diagnostics",
    "02_high_availability": "02_core_dba/04_high_availability_and_rac",
    "06_patching_upgrade": "02_core_dba/05_patching_and_upgrades",
    "08_monitoring": "02_core_dba/06_monitoring_systems",
    "19_setup_checkmk": "02_core_dba/06_monitoring_systems",
    "07_replication": "02_core_dba/07_replication_goldengate",
    "16_proxmox_track": "03_infra_lab/01_proxmox_hardware",
    "01_lab_setup": "03_infra_lab/02_oracle_installation_asm",
    "09_cloud_oci": "03_infra_lab/03_cloud_oci",
    "00_fondamenti": "04_governance_learning/01_fondamenti_teorici",
    "14_enterprise_governance": "04_governance_learning/02_enterprise_standards",
    "10_esami_carriera": "04_governance_learning/03_esami_e_carriera",
    "00_lab_percorso": "04_governance_learning/03_esami_e_carriera"
}

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    new_content = content
    # Replace relative links: ../<old_dir> -> ../../<new_dir>
    for old, new in folder_map.items():
        new_content = new_content.replace(f"../{old}/", f"../../{new}/")
        new_content = new_content.replace(f"../{old}", f"../../{new}")
        
    # Replace root links: ./<old_dir> -> ./<new_dir> or <old_dir>/ -> <new_dir>/
    if filepath == "README.md":
        for old, new in folder_map.items():
            new_content = new_content.replace(f"./{old}/", f"./{new}/")
            new_content = new_content.replace(f"/{old}/", f"/{new}/")
            new_content = new_content.replace(f"{old}/", f"{new}/")
            new_content = new_content.replace(f"]({old})", f"]({new})")

    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated links in {filepath}")

for root, dirs, files in os.walk("."):
    for file in files:
        if file.endswith(".md"):
            process_file(os.path.join(root, file))

print("Link fixing complete.")
