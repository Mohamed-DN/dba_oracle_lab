# Guida Ufficiale: Percorso Lite (Single-Node Sandbox via Vagrant)

> Percorso pensato per chi non ha 32-64 GB RAM. Obiettivo: imparare i fondamenti DBA su **1 nodo** con footprint ridotto.

## Teoria

Il lab completo RAC + Data Guard richiede 5 VM. Con hardware limitato puoi comunque coprire:

- setup OS Oracle Linux
- hardening base e utenti Oracle
- basi ASM/storage locale
- automazione Ansible e runbook operativi core
- troubleshooting SQL e monitoraggio

Questo percorso **non sostituisce** i test HA (RAC/Data Guard), ma crea un sandbox didattico ufficiale e ripetibile.

## Esempio pratico (Vagrant)

Prerequisiti minimi host:

- RAM: **12-16 GB** (consigliato 16)
- CPU: 4 vCPU
- Disco libero: 80 GB

1) Usa la topologia esistente ma alza solo i nodi necessari:

```bash
cd /home/runner/work/dba_oracle_lab/dba_oracle_lab/vagrant_rac_dataguard

# riduci RAM nel profilo locale (esempio)
cp config/vagrant.yml config/vagrant.lite.yml
sed -i 's/mem_size: 8192/mem_size: 4096/g' config/vagrant.lite.yml

# usa il profilo lite solo per dns + rac1
cp config/vagrant.lite.yml config/vagrant.yml

cd dns && vagrant up
cd ../rac1 && vagrant up
```

2) Concludi la fase sandbox:

```bash
vagrant ssh rac1
# Esegui check basilari
hostname
free -h
df -h
```

## Validazione

Checklist pass/fail:

- [ ] `dnsnode` raggiungibile via `ping`
- [ ] `rac1` up e accessibile via `vagrant ssh`
- [ ] utenti Oracle presenti (`id oracle`, `id grid`)
- [ ] rete host-only funzionante (`ip addr`, `ip route`)
- [ ] almeno 3 runbook core eseguiti in sandbox senza errori bloccanti

Criterio di superamento: **5/5 check**.

## Troubleshooting

- **VM lentissima / swap alto**: riduci VM attive, chiudi host process pesanti, assegna 4096 MB solo a `rac1`.
- **Provisioning fallisce per binari Oracle mancanti**: verifica cartella `vagrant_rac_dataguard/software/`.
- **Rete host-only assente**: ricrea adapter VirtualBox e riallinea subnet.
- **DNS non risolve hostname**: riavvia `dns` (`vagrant reload`) e valida `/etc/hosts`.

## Scope didattico coperto (lite)

- Fase 0-2 in modalità ridotta
- Fondamenti e amministrazione quotidiana
- Non include validazione HA completa (richiede lab full)
