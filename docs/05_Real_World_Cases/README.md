# 🔥 Archivio Incidenti e Casi Studio (Real World Cases)

Questa directory rappresenta la **Knowledge Base operativa** derivata esclusivamente dall'esperienza "sul campo" (produzione e troubleshooting avanzato su ambienti reali dei clienti).

A differenza dei classici Runbook teorici o procedurali (che si trovano in `01_operations/02_runbooks_incidenti`), qui vengono archiviati i veri **Post-Mortem** e i **Playbook di Emergenza** scritti *dopo* aver affrontato criticità complesse, edge-case di licenza, database crash irreversibili e migrazioni di recupero non standard.

Ogni documento è strutturato con la regola del "copia-incolla": deve permettere a un sistemista di uscire da un'emergenza critica senza dover studiare, semplicemente applicando la procedura testata e blindata.

## 🌳 Alberatura e Contenuti

```text
05_Real_World_Cases/
│
├── README.md                                          <-- Questo indice
├──  08_2026_Rescue_Oracle_XE_12GB_Limit.md             <-- Recupero "a cuore aperto" di XE oltre i limiti fisici
└──  10_2026_Oracle_Standalone_ASM_UDEV_Post_Migration.md
```

---
*Note di stile per i futuri inserimenti: ogni nuovo caso studio va nominato con la nomenclatura standard:*
`[MM]_[AAAA]_[NOME_SINTETICO_INCIDENTE].md`
