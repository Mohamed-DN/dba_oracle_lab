# Guida OCI: Target Database per GoldenGate e Migrazione dal Lab Locale

> Questa guida spiega come costruire un target Oracle su Oracle Cloud Infrastructure (OCI) in modo coerente con il lab locale. Il focus non e solo creare una VM, ma scegliere un target e un modello di rete che siano davvero compatibili con GoldenGate e con il tuo RAC 19c locale.

---

## 1. Decisione Iniziale: Quale Target Cloud Vuoi Davvero

Prima di creare risorse OCI, devi scegliere il percorso corretto.

### Percorso A - Validazione gratuita e leggera

- OCI Always Free Compute
- Oracle AI Database Free sul target
- eventuale GoldenGate Free sul target

Quando usarlo:

- per imparare OCI;
- per testare listener, TNS, rete, initial load, schema replication in mini-lab;
- per un ambiente di prova separato e piccolo.

Limiti forti:

- GoldenGate Free e limitato a database Oracle <= 20 GB;
- interagisce solo con altre istanze GoldenGate Free;
- non include entitlement ADG o downstream capture.

Conclusione:

- questo percorso non e quello giusto per una replica formalmente supportata dal tuo RAC 19c + Data Guard locale verso cloud se sul source usi GoldenGate Core/licensed.

### Percorso B - Migrazione locale -> OCI coerente col lab enterprise

- OCI Compute come target Oracle
- DB target Oracle installato su compute
- GoldenGate Core/licensed o equivalente supportato su source e target

Quando usarlo:

- per la vera migrazione dal lab locale 19c verso cloud;
- per un flusso credibile da DBA enterprise.

Questo e il percorso che considero `corretto` per il tuo lab principale.

---

## 2. Stato delle Offering Verificate

Verifica fatta il `15 marzo 2026` su fonti Oracle ufficiali.

### OCI Always Free Compute

Oracle documenta per `VM.Standard.A1.Flex` Always Free:

- fino a `4 OCPU` Ampere A1;
- fino a `24 GB` RAM totale;
- fino a `200 GB` di block volume totale Always Free.

### Oracle AI Database Free

Oracle documenta che il pacchetto attuale disponibile e `Oracle AI Database Free 26ai`, installabile su Linux x86-64 e Arm.

Punti pratici:

- su ARM il database usa `SID FREE`;
- crea `FREE` e `FREEPDB1`;
- listener su `1521`;
- installazione RPM supportata.

### GoldenGate Free

Oracle documenta che GoldenGate Free:

- e pensato per database Oracle <= `20 GB`;
- puo interagire solo con altre istanze GoldenGate Free;
- non include entitlement `Active Data Guard`;
- non supporta downstream capture.

Questo punto da solo impone disciplina architetturale.

---

## 3. Architettura Raccomandata per il Repo

Per il tuo repo consiglio di separare nettamente due casi.

### Caso 1 - Lab principale

- `source`: RAC 19c locale
- `Data Guard`: DR locale
- `GoldenGate capture`: sul primary, non sullo standby
- `target`: OCI Compute Oracle DB
- `rete`: pubblico ristretto o VPN

### Caso 2 - Lab free-only separato

- `source`: Oracle AI Database Free locale o piccolo single instance
- `target`: Oracle AI Database Free su OCI
- `GoldenGate Free`: su entrambi i lati

Questo secondo caso e utile per imparare la UX di GoldenGate Free, ma non deve confondersi con il lab RAC 19c principale.

---

## 4. Rete: Prima Decidi il Modello

Segui prima [GUIDA_RETE_LAB_OCI_GOLDENGATE.md](./GUIDA_RETE_LAB_OCI_GOLDENGATE.md).

Per il target OCI puoi scegliere:

1. `IP pubblico ristretto` al tuo IP di casa: piu rapido.
2. `Site-to-Site VPN`: piu corretto e piu vicino a un ambiente reale.
3. `Overlay VPN`: opzionale da laboratorio.

Se non hai ancora deciso il modello di rete, non andare oltre con GoldenGate.

---

## 5. Build del Target OCI Compute

### 5.1 Creazione istanza

Nel portale OCI:

1. `Compute` -> `Instances` -> `Create instance`
2. `Shape`: `VM.Standard.A1.Flex`
3. imposta, se disponibile in quota Always Free:
   - `4 OCPU`
   - `24 GB RAM`
4. immagine consigliata:
   - `Oracle Linux 8` se vuoi il percorso piu lineare con Database Free RPM su Arm
5. assegna public IP solo se usi il modello pubblico ristretto
6. metti l'istanza in una subnet con NSG dedicato

### 5.2 Porte minime

Apri solo quelle coerenti col modello scelto:

- `22/tcp` SSH
- `1521/tcp` listener DB
- `7809/tcp` se usi GG classic/core manager
- `9011-9014/tcp` solo se usi microservices

Sorgente raccomandata:

- il tuo `IP pubblico /32`
- oppure la subnet privata locale via VPN

---

## 6. Bootstrap del Sistema Operativo

Esempio iniziale come `root`:

```bash
sudo -s

dnf -y update
hostnamectl set-hostname dbtarget

dnf -y install oraclelinux-developer-release-el8
firewall-cmd --reload
```

Swap raccomandato se fai lab su VM free piccola:

```bash
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
```

---

## 7. Installazione Database Target: Due Opzioni

### 7.1 Opzione pratica Always Free: Oracle AI Database Free 26ai

Questa opzione e la piu semplice da costruire su ARM.

Sequenza documentata da Oracle:

```bash
sudo -s

dnf -y install oracle-ai-database-preinstall-26ai
# scarica l'RPM corretto aarch64 dal sito Oracle
# poi installa l'RPM locale
# esempio nome file ufficiale documentato:
# oracle-database-free-26ai-23.26.0-1.el8.aarch64.rpm

dnf -y install ./oracle-database-free-26ai-23.26.0-1.el8.aarch64.rpm
/etc/init.d/oracle-free-26ai configure
```

Cosa crea:

- `ORACLE_HOME` sotto `/opt/oracle/product/26ai/dbhomeFree`
- `FREE`
- `FREEPDB1`
- listener `1521`

Nota importante:

- questo target e ottimo per lab, ma non va automaticamente confuso con un target supportato per il lab RAC 19c + GG principale.

### 7.2 Opzione coerente con migrazione enterprise

Se vuoi una migrazione davvero coerente con il source RAC 19c, usa sul target OCI:

- un Oracle Database versione certificata per il tuo percorso GG;
- GoldenGate Core/licensed o servizio OCI GoldenGate, non GoldenGate Free.

Questa opzione richiede media/licensing o un percorso di evaluation non sempre disponibile nel Free Tier.

---

## 8. Configurazione Base del Target Database

### 8.1 Variabili ambiente oracle

```bash
su - oracle
cat >> ~/.bash_profile <<'EOF'
export ORACLE_BASE=/opt/oracle
export ORACLE_HOME=/opt/oracle/product/26ai/dbhomeFree
export ORACLE_SID=FREE
export PATH=$PATH:$ORACLE_HOME/bin
EOF
source ~/.bash_profile
```

### 8.2 Test listener e database

```bash
lsnrctl status
sqlplus / as sysdba
show pdbs;
```

### 8.3 Creazione utente target per lab

```sql
sqlplus / as sysdba
ALTER SESSION SET CONTAINER=FREEPDB1;

CREATE USER ggadmin IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION, RESOURCE TO ggadmin;
GRANT SELECT ANY DICTIONARY TO ggadmin;
```

Se il target fara il ruolo di Replicat Oracle:

```sql
GRANT DBA TO ggadmin;
```

Nel lab va bene. In ambienti seri si riducono i privilegi.

---

## 9. GoldenGate sul Target: Regola di Compatibilita

### Se usi GoldenGate Core/licensed nel lab principale

Il target OCI deve usare un deployment GoldenGate compatibile e supportato.

### Se usi GoldenGate Free

Ricorda i limiti Oracle ufficiali:

- solo con altri GoldenGate Free;
- no ADG entitlement;
- no downstream capture;
- workload piccolo.

Conclusione pratica:

- per migrare dal tuo RAC 19c locale a OCI con GoldenGate nel lab principale, non fare affidamento su GoldenGate Free come percorso `ufficiale` della guida base.

---

## 10. Test di Rete Prima di GoldenGate

Dai nodi locali:

```bash
ping dbtarget
nc -vz dbtarget 1521
# se usi GG classic/core
nc -vz dbtarget 7809
# se usi microservices
nc -vz dbtarget 9011
nc -vz dbtarget 9014
tnsping DBTARGET
```

Se uno di questi test fallisce, fermati li.

---

## 11. Quale Percorso Useremo nel Repo

Nel repo fisso questa regola:

1. Fase 5 base: GoldenGate supportato con capture sul primary locale.
2. Target: locale o OCI Compute.
3. OCI Free: ottimo per target DB e networking lab.
4. GoldenGate Free: trattato come variante separata e non come presupposto del lab RAC 19c principale.

---

## 12. Cosa Devi Avere Prima di Automatizzare OCI

Per creare davvero il DB nel tuo tenancy OCI servono:

- accesso al tuo account OCI;
- quota disponibile nel compartment corretto;
- scelta reale di regione/shape/subnet;
- chiavi SSH o `oci cli` configurati se vuoi automatizzare.

Senza questi prerequisiti, il repo puo spiegare il percorso corretto ma non puo sostituire il provisioning reale nel tuo tenancy.

---

## 13. Fonti Oracle Ufficiali

- OCI Always Free resources: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
- Oracle AI Database Free install guide: https://docs.oracle.com/en/database/oracle/oracle-database-free/get-started/installing-oracle-database-free.html
- GoldenGate Free overview and limitations: https://docs.oracle.com/en/middleware/goldengate/free/23/overview/index.html
- GoldenGate Free FAQ and limits: https://docs.oracle.com/en/middleware/goldengate/free/23/overview/oracle-goldengate-free-faq.html
- OCI network security groups: https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/networksecuritygroups.htm

---

## 14. Passo Successivo Corretto

Il passo corretto dopo questa guida e:

1. completare Fase 4 Broker bene;
2. fissare il modello di rete con [GUIDA_RETE_LAB_OCI_GOLDENGATE.md](./GUIDA_RETE_LAB_OCI_GOLDENGATE.md);
3. scegliere se il target cloud e solo `free validation` o `migration target` vero;
4. poi seguire Fase 5 per GoldenGate con capture sul primary.
