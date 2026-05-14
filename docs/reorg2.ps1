$ErrorActionPreference = "Stop"

Set-Location "c:\DBA\dba_oracle_lab\docs"

Function Move-GitContent {
    param([string]$SourceDir, [string]$DestDir)
    if (Test-Path $SourceDir) {
        $items = Get-ChildItem -Path $SourceDir
        foreach ($item in $items) {
            $src = $item.FullName
            $dst = Join-Path -Path (Resolve-Path $DestDir).Path -ChildPath $item.Name
            git mv $src $dst
        }
        Remove-Item -Recurse -Force $SourceDir
    }
}

Move-GitContent "04_administration" "02_core_dba\01_administration_and_security\"
Move-GitContent "18_setup_ldap" "02_core_dba\01_administration_and_security\"

Move-GitContent "03_backup_recovery" "02_core_dba\02_backup_and_recovery\"
Move-GitContent "15_rman_comandi" "02_core_dba\02_backup_and_recovery\"

Move-GitContent "05_performance" "02_core_dba\03_performance_and_diagnostics\"
Move-GitContent "17_adrci_trace" "02_core_dba\03_performance_and_diagnostics\"

Move-GitContent "08_monitoring" "02_core_dba\06_monitoring_systems\"
Move-GitContent "19_setup_checkmk" "02_core_dba\06_monitoring_systems\"

Move-GitContent "10_esami_carriera" "04_governance_learning\03_esami_e_carriera\"
Move-GitContent "00_lab_percorso" "04_governance_learning\03_esami_e_carriera\"

Write-Output "Folder merge completed."
