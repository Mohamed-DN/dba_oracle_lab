# Compatibilità per Area (19c / 21c / 23ai / 26c)

## Matrice visibile per area del repository

| Area | 19c | 21c | 23ai | 26c | Note |
|---|---|---|---|---|---|
| Lab setup (Fasi 0-8) | ✅ | ⚠️ | ⚠️ | ⚠️ | Target primario 19c, versioni superiori con adattamenti installer/patch |
| Playbook Ansible | ✅ | ✅ | ⚠️ | ⚠️ | Verificare moduli Oracle e prerequisiti OS/collection |
| Runbook operativi | ✅ | ✅ | ✅ | ⚠️ | Query per viste dinamiche validate fino a 23ai |
| Libreria script (~1000) | ✅ | ✅ | ✅ | ⚠️ | Alcuni script legacy richiedono review per 26c |
| Patching/Upgrade guide | ✅ | ✅ | ✅ | ✅ | Include percorsi 12c→19c e 19c→26c |
| Monitoring stack | ✅ | ✅ | ✅ | ✅ | Checkmk/Prometheus/Grafana agnostici alla versione DB |

Legenda: ✅ supporto dichiarato, ⚠️ supporto parziale/da validare in lab.
