# Quickstart Enterprise (10 minuti)

## Obiettivo
Arrivare a un primo esito verificabile con provisioning minimo + health check automatico.

## Prerequisiti rapidi
- Host con VirtualBox 7+, Vagrant, Ansible.
- Accesso ai binari Oracle in `vagrant_rac_dataguard/software/`.

## Percorso rapido
1. `cd vagrant_rac_dataguard/dns && vagrant up`
2. `cd ../rac1 && vagrant up`
3. `cd /home/runner/work/dba_oracle_lab/dba_oracle_lab/automation`
4. `ansible-playbook -i inventory/lab.ini playbooks/daily_health_check.yml`
5. `ansible-playbook -i inventory/lab.ini playbooks/create_cdb_pdb.yml -e pdb_create_if_missing=true -e cdb_create_if_missing=false`

## Output atteso
- Stato CRS e istanze RAC senza errori bloccanti.
- Sezione Data Guard leggibile nel report health check.
- PDB target presente/aperto oppure conferma esistenza.

## Se qualcosa fallisce
Passa al [Troubleshooting Decision Tree](./TROUBLESHOOTING_DECISION_TREE.md).
