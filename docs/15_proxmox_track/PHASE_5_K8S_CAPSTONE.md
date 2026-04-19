# Fase 5 - K3s/RKE2 Capstone

## Obiettivo

Costruire cluster Kubernetes sulle VM Proxmox e distribuire app con dipendenza Oracle.

## Scelte tecniche

- Runtime: Docker o Podman con decisione esplicita (rootless/daemonless, operatività team).
- Distribuzione K8s: K3s o RKE2 in base a requisiti sicurezza e semplicità operativa.
- Topologia minima: 3 VM Linux (1 control-plane, 2 worker).

## Orchestrazione con AWX

- Job template AWX "cluster bootstrap".
- Job template AWX "app deploy" con secret/connessione DB Oracle.
- Inventory dinamico riusato dal flusso Terraform.

## Test end-to-end richiesti

- Bootstrap cluster completo da zero.
- Deploy applicazione con readiness/liveness probes attive.
- Verifica connessione applicazione -> Oracle.

## KPI capstone

- provisioning_success_rate
- bootstrap_success_rate
- mean_deploy_time_minutes

## Acceptance checklist

- [ ] Cluster K8s operativo su 3 VM.
- [ ] Applicazione deployata e raggiungibile.
- [ ] Connessione Oracle validata con test automatizzato.
