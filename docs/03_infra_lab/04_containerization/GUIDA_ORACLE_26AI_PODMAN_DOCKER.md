# Enterprise Containerization: Oracle 26ai su Podman/Docker

L'utilizzo di container per i database relazionali Oracle richiede un setup attento. A differenza di un applicativo web *stateless*, un database Enterprise deve gestire memoria condivisa del Kernel (SGA), permessi asincroni su file system e sicurezza profonda del demone container.

Questa guida illustra lo standard aziendale per il deployment rapido di Oracle AI Database 26ai Free tramite Docker Compose o Podman Compose.

---

## 1. Sicurezza e Architettura: Podman vs Docker
In contesti Enterprise (Red Hat, Oracle Linux), il demone Docker in esecuzione come root rappresenta un rischio di sicurezza enorme (privilege escalation).
Lo standard di settore è **Podman**, che esegue i container in modalità **rootless**.
L'immagine ufficiale Oracle 26ai è certificata per girare *rootless*, garantendo l'isolamento completo dei processi.

---

## 2. Il Problema dei Volumi e SELinux ("Permission Denied")
Uno degli errori più comuni e bloccanti montando volumi host in un container DB su macchine Enterprise Linux è il famigerato `Permission Denied` in fase di startup.
Questo accade perché **SELinux** blocca l'accesso del container alla directory host, anche se i permessi `chmod` sembrano corretti.

**La Soluzione**: Applicare il contesto SELinux al volume.
Nel `docker-compose.yml`, è tassativo aggiungere il suffisso `:Z` (condivisione privata) o `:z` (condivisione tra più container) al mapping del volume.

---

## 3. Ottimizzazione della Memoria (Kernel shm_size)
Oracle Database utilizza estensivamente la memoria condivisa (System Global Area - SGA). I container Docker/Podman allocano di default solo **64MB** alla partizione `/dev/shm`.
Se l'SGA di Oracle supera questo limite, l'istanza va in crash (ORA-00845: MEMORY_TARGET not supported on this system).
È obbligatorio impostare `shm_size` (es. `2gb`) nel file compose.

---

## 4. Runbook: Deployment con Docker Compose

Crea una directory operativa e salva il seguente file `docker-compose.yml`:

```yaml
version: '3.8'

services:
  oracle26ai:
    image: container-registry.oracle.com/database/free:latest
    container_name: oracle26ai_ent_dev
    # Tuning Kernel per la System Global Area (SGA)
    shm_size: '2gb'
    environment:
      - ORACLE_PWD=SuperSecureEnterprisePassword123!
      - ORACLE_SID=FREE
      - ENABLE_ARCHIVELOG=true # Abilita archivelog in startup per simulazioni di recovery
    ports:
      - "1521:1521"
      - "5500:5500" # Enterprise Manager Express
    volumes:
      # Il suffisso :Z è OBBLIGATORIO per risolvere i conflitti SELinux su OEL/RHEL
      - /u01/docker_data/oracle_26ai/oradata:/opt/oracle/oradata:Z
      # Cartella di bootstrap automatico
      - /u01/docker_data/oracle_26ai/scripts/startup:/opt/oracle/scripts/startup:Z
      - /u01/docker_data/oracle_26ai/scripts/setup:/opt/oracle/scripts/setup:Z
    restart: unless-stopped
    healthcheck:
      # Verifica lo stato reale del database chiamando PMON
      test: ["CMD-SHELL", "ps -ef | grep pmon | grep -v grep || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
```

---

## 5. Bootstrap Automatico (Entrypoint Scripts)
In CI/CD, spesso serve un database già popolato con schemi specifici senza interazione manuale.
L'immagine Oracle supporta l'esecuzione automatica di script al primissimo avvio.
Qualsiasi script (`.sql`, `.sh`) inserito nella directory host `/u01/docker_data/oracle_26ai/scripts/startup` verrà eseguito **dopo** la creazione del DB.

**Esempio di script `/u01/docker_data/oracle_26ai/scripts/startup/01_app_schema.sql`:**
```sql
ALTER SESSION SET CONTAINER=FREEPDB1;
CREATE USER core_app IDENTIFIED BY "CoreApp_PWD_2026";
GRANT CONNECT, RESOURCE, DBA TO core_app;
-- Utilizzo della nuova feature 26ai: Duality View
CREATE JSON RELATIONAL DUALITY VIEW utente_view AS ...
```

---

## 6. Procedura Operativa (Start, Stop & Recovery)

1. **Inizializzazione**:
   ```bash
   mkdir -p /u01/docker_data/oracle_26ai/{oradata,scripts/startup,scripts/setup}
   podman-compose up -d
   ```
2. **Controllo dei Log di Init**:
   L'inizializzazione al primo boot può richiedere dai 5 ai 15 minuti.
   ```bash
   podman logs -f oracle26ai_ent_dev
   # Attendere il messaggio: "DATABASE IS READY TO USE"
   ```
3. **Troubleshooting Crash all'avvio**:
   Se il container esce subito (Exited 1), verifica i permessi della cartella `oradata`. L'utente dentro il container (`oracle`, UID 54321) deve poter scrivere nel volume host. Se il mapping `:Z` non fosse sufficiente:
   ```bash
   sudo chown -R 54321:54321 /u01/docker_data/oracle_26ai/oradata
   ```
