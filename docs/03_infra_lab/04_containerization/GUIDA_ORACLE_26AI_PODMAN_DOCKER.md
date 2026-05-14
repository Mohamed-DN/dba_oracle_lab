# Oracle AI Database 26ai Free: Containerization Setup (Docker / Podman)

Oltre all'architettura Enterprise su VM (Vagrant/Proxmox) per scenari di RAC e Data Guard, i DBA moderni necessitano di istanze effimere e leggere per testare feature, fare unit test sulle procedure PL/SQL, o provare le nuove funzionalità legate all'intelligenza artificiale (AI Vector Search, Agentic AI) senza il peso di un OS completo.

Oracle rilascia la versione **Free Edition** del proprio database 26ai direttamente sul [Container Registry](https://container-registry.oracle.com/). Questa guida spiega come lanciare Oracle 26ai in pochi secondi.

---

## 1. Prerequisiti
- **Motore Container**: Docker Desktop, Podman, o Rancher Desktop installati.
- **Risorse**: Minimo 2GB di RAM allocati al motore container (4GB raccomandati per sfruttare le funzioni AI).
- **Spazio**: Circa 5-8GB di spazio disco per l'immagine e i volumi.

> [!TIP]
> Su sistemi Enterprise Linux (RHEL, Oracle Linux) è fortemente raccomandato l'uso di **Podman** in modalità "rootless" per motivi di sicurezza, mentre su Windows/Mac si può usare Docker Desktop.

---

## 2. Metodo Veloce: CLI (Command Line)

Se hai solo bisogno di un database "usa e getta" per un test rapido al volo, puoi lanciare un singolo comando:

```bash
docker run -d --name oracle-26ai \
  -p 1521:1521 \
  -e ORACLE_PWD=SysPassword123! \
  container-registry.oracle.com/database/free:latest
```

> [!WARNING]
> Senza l'utilizzo di Volumi, se distruggi il container (`docker rm`), **perderai tutti i dati**. Per la persistenza, usa il metodo con Docker Compose descritto di seguito.

Per controllare i log e capire quando il database è pronto all'uso:
```bash
docker logs -f oracle-26ai
```
*(Attendi il messaggio "DATABASE IS READY TO USE")*

---

## 3. Metodo Consigliato: Docker Compose (Persistenza Dati)

Per avere un ambiente riproducibile e che mantenga i dati anche al riavvio, crea una cartella di lavoro sul tuo PC e crea al suo interno questo file `docker-compose.yml`:

```yaml
version: '3.8'

services:
  oracle26ai:
    image: container-registry.oracle.com/database/free:latest
    container_name: oracle26ai_dev
    environment:
      - ORACLE_PWD=SysPassword123!
    ports:
      - "1521:1521"
    volumes:
      - oradata:/opt/oracle/oradata
    restart: unless-stopped

volumes:
  oradata:
    driver: local
```

Avvia il container in background:
```bash
docker compose up -d
```

---

## 4. Connessione al Database

Una volta che il container è in stato *healthy*, puoi connetterti dal tuo host (usando DBeaver, SQL Developer, o SQLcl).

### Parametri di Connessione:
- **Hostname**: `localhost`
- **Port**: `1521`
- **Service Name**: `FREEPDB1`
- **Utente DBA**: `SYS` (connesso as SYSDBA) o `SYSTEM`
- **Utente App**: `PDBADMIN`
- **Password**: Quella impostata in `ORACLE_PWD` (`SysPassword123!`)

### Connessione diretta da terminale (tramite shell del container)
Se non hai tool installati sul tuo PC, puoi usare `sqlplus` o `sqlcl` direttamente da dentro il container:

```bash
docker exec -it oracle26ai_dev sqlplus sys/SysPassword123!@FREEPDB1 as sysdba
```

---

## 5. Esplorare le Novità di 26ai (Quick Test)

Una volta dentro `sqlplus`, puoi verificare di essere davvero sulla 26ai:

```sql
SELECT * FROM v$version;
```

E provare a creare una tabella con un Vector Type per sperimentare con l'**AI Vector Search** nativa, senza dover configurare cluster complessi!
