# Contribuire a Oracle DBA Enterprise Lab

Grazie per l'interesse nel contribuire a questo progetto! Siamo impegnati a mantenere questo repository come lo standard d'eccellenza per la documentazione e l'automazione Oracle DBA.

## 🤝 Codice di Condotta
Partecipando a questo progetto, accetti di mantenere un comportamento professionale, collaborativo e orientato alla risoluzione dei problemi.

## 🛠️ Come Contribuire

### 1. Segnalazione di Bug o Errori Tecnici
Se trovi un errore in una guida o un bug in uno script Ansible/Terraform:
- Apri una **Issue** descrivendo il problema.
- Includi la versione di Oracle, l'OS e il log dell'errore (es. ORA-xxxxx).

### 2. Proposta di Nuove Guide o Script
- Crea un **Fork** del repository.
- Aggiungi il tuo contributo seguendo lo standard documentale esistente (Papyri Tecnici / MOP).
- Assicurati che i link siano validati (puoi usare lo script `check_links.py` se disponibile).
- Invia una **Pull Request**.

### 3. Standard di Documentazione
Tutti i documenti devono:
- Essere in formato Markdown.
- Includere una sezione di troubleshooting se applicabile.
- Usare percorsi relativi per i link interni.
- Seguire la gerarchia definita nel `README.md` principale.

## 🏗️ Workflow di Sviluppo
1. `git checkout -b feat/nuova-funzionalita`
2. Apporta le modifiche.
3. Verifica la sintassi SQL e l'idempotenza degli script Ansible.
4. `git commit -m "feat: aggiunta guida alla migrazione verso 23ai"`
5. `git push origin feat/nuova-funzionalita`

## ⚖️ Licenza
Contribuendo, accetti che il tuo codice e la tua documentazione siano rilasciati sotto la licenza **MIT** presente in questo repository.

---
**Build the future of Oracle DBA Operations together.**
