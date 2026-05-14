# Troubleshooting Decision Tree (Centralizzato)

## Sintomo: provisioning fallisce
- Verifica preflight: binari Oracle presenti in `software/`.
- Verifica RAM/CPU host e spazio disco.
- Se errore rete/DNS: validare risoluzione host tra nodi.

## Sintomo: RAC non sale correttamente
- Esegui runbook [10_START_STOP_RAC](../../01_operations/02_runbooks_incidenti/10_START_STOP_RAC.md).
- Verifica CRS con `crsctl check crs` e `srvctl status database`.

## Sintomo: Data Guard non in SUCCESS
- Esegui runbook [03_CHECK_DATAGUARD](../../01_operations/02_runbooks_incidenti/03_CHECK_DATAGUARD.md).
- Controlla lag transport/apply e servizi broker.

## Sintomo: PDB non disponibile
- Verifica playbook `create_cdb_pdb.yml` e variabili `oracle_pdb_name`.
- Controlla `v$pdbs` da SQL*Plus come SYSDBA.

## Sintomo: backup o recovery in errore
- Esegui runbook [02_VERIFICA_BACKUP](../../01_operations/02_runbooks_incidenti/02_VERIFICA_BACKUP.md).
- Esegui test restore periodico e aggiorna evidenze DR.
