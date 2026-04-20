# 15 — Checkmk Agent TLS + SMART/RAID Troubleshooting

## Obiettivo

Eseguire onboarding e troubleshooting standard di un host Linux su Checkmk con:
- registrazione TLS (`cmk-agent-ctl`)
- update agent (`cmk-update-agent`)
- validazione SMART su dischi SAS e controlli RAID.

## Prerequisiti

- Accesso sudo sull'host target.
- Host già creato nel folder corretto in Checkmk.
- FQDN/IP del server Checkmk e `site ID`.
- Utente automation (o token) per registrazione agent.
- Pacchetti richiesti installati:

```bash
sudo apt update
sudo apt install -y smartmontools lsscsi pciutils
```

## Procedura Operativa

### 1) Connettività e risoluzione nome

```bash
getent hosts <CHECKMK_SERVER_FQDN>
ping -c 2 <CHECKMK_SERVER_FQDN>
```

Se manca DNS, aggiungere solo una riga in coda (mai sovrascrivere `/etc/hosts`):

```bash
echo "<CHECKMK_SERVER_IP> <CHECKMK_SERVER_FQDN> <CHECKMK_SERVER_ALIAS>" | sudo tee -a /etc/hosts
```

### 2) Installazione agent package

```bash
sudo dpkg -i /home/<USER>/check-mk-agent_<VERSION>_all.deb
```

### 3) Verifica certificato endpoint

```bash
openssl s_client -showcerts -connect <CHECKMK_SERVER_IP>:443 </dev/null 2>/dev/null | sed -n -e '/BEGIN CERTIFICATE/,/END CERTIFICATE/ p'
```

### 4) Registrazione TLS controller

```bash
sudo cmk-agent-ctl register \
  --server <CHECKMK_SERVER_FQDN> \
  --site <CHECKMK_SITE_ID> \
  --hostname "$(hostname -f)" \
  -U <AUTOMATION_USER> \
  -P '<AUTOMATION_SECRET>'
```

### 5) Registrazione update agent

```bash
sudo cmk-update-agent register \
  -s <CHECKMK_SERVER_FQDN> \
  -i <CHECKMK_SITE_ID> \
  -H "$(hostname -f)" \
  -p https \
  -U <AUTOMATION_USER> \
  -P '<AUTOMATION_SECRET>' \
  -v
```

### 6) Discovery e activate changes (UI)

1. Setup → Hosts → apri host target.
2. Run service discovery.
3. Accept new services.
4. Activate changes.

## Validazione Finale

```bash
sudo systemctl status cmk-agent-ctl-daemon --no-pager
sudo systemctl status cmk-update-agent.timer --no-pager
sudo cmk-update-agent -v
check_mk_agent | head -20
sudo cmk-agent-ctl status
```

Controlli minimi da confermare in Checkmk:
- Host status UP.
- Servizi agent e update timer in stato OK.
- Servizi disco/RAID/SMART scoperti e in stato OK/WARN coerente.

## Troubleshooting Rapido

### Errore registrazione TLS

- Verificare FQDN usato in `--server` e SAN del certificato.
- Verificare firewall/ACL su porta 443.
- Verificare ora/NTP del target (drift può invalidare TLS).

### Update agent non funziona

- Controllare registration status con `cmk-update-agent -v`.
- Verificare reachability HTTPS verso il site.
- Verificare credenziali automation e policy lato server.

### Nessuna metrica SMART/RAID

```bash
sudo lspci | grep -i -E "raid|sas|scsi|storage"
lsblk -o NAME,HCTL,TYPE,SIZE,MODEL,SERIAL
sudo lsscsi -v
lsmod | grep -E 'megaraid|mpt3sas|mpt2sas|aacraid|hpsa|3w_9xxx|arcmsr|isci'
sudo smartctl -a /dev/sda
```

- Se i dischi sono dietro controller, abilitare i plugin controller Checkmk (vendor/RAID) oltre a SMART diretto.
- Allineare naming host/device con seriale, HCTL e slot controller.

## Rollback

```bash
# Deregistrare update agent
sudo cmk-update-agent unregister -v || true

# Deregistrare controller agent
sudo cmk-agent-ctl deregister || true

# Rimuovere pacchetto agent (se necessario)
sudo apt remove -y check-mk-agent || true
```

In UI Checkmk:
1. Disabilitare host temporaneamente oppure spostarlo in folder di quarantine.
2. Rimuovere servizi non più validi.
3. Activate changes.
