# 36 — Cambio DB_UNIQUE_NAME e Sanitizzazione ASM

<!-- RUNBOOK_NAV_START -->
## Casi piu frequenti da aprire prima
- Adeguare naming convention Data Guard (suffisso PEC sul primario).
- DB_UNIQUE_NAME non allineato con standard aziendali.
- OMF su ASM continua a scrivere nella vecchia directory.
- Necessita di sanare datafile/tempfile/redo log/controlfile senza ricreare il DB.

## Indice rapido
- [Casi piu frequenti da aprire prima](#casi-piu-frequenti-da-aprire-prima)
- [Obiettivi](#obiettivi)
- [Prerequisiti](#prerequisiti)
- [Rischi e Impatto](#rischi-e-impatto)
- [Procedura Operativa](#procedura-operativa)
  - [Step 0: Matrice di configurazione](#step-0-matrice-di-configurazione)
  - [Fase 1: Modifica logica del DB_UNIQUE_NAME](#fase-1-modifica-logica-del-db_unique_name)
  - [Fase 2: Generazione SPFILE sanato e directory ASM](#fase-2-generazione-spfile-sanato-e-directory-asm)
  - [Fase 3: Spostamento online dei datafile](#fase-3-spostamento-online-dei-datafile)
  - [Fase 4: Ricreazione tempfile e online redo log](#fase-4-ricreazione-tempfile-e-online-redo-log)
  - [Fase 5: Rilocazione e multiplexing controlfile](#fase-5-rilocazione-e-multiplexing-controlfile)
  - [Fase 6: Chiusura attivita e rimozione strutture orfane](#fase-6-chiusura-attivita-e-rimozione-strutture-orfane)
- [Rollback](#rollback)
- [Validazione Finale](#validazione-finale)
- [Troubleshooting / Piano di Rientro](#troubleshooting--piano-di-rientro)
- [Riferimenti](#riferimenti)
<!-- RUNBOOK_NAV_END -->

<!-- READY_SCRIPTS_START -->
## Script pronti collegati

Usali per raccogliere evidenze rapide dopo aver letto lo scenario del runbook.

- Nessuno specifico. Usa le query di verifica incluse nella procedura.
<!-- READY_SCRIPTS_END -->
> ⏱️ Tempo: 60-120 minuti | 📅 Frequenza: Change pianificato | 👤 Chi: DBA + Grid/ASM
> **Scenario tipico**: DB_UNIQUE_NAME errato, OMF su ASM sotto directory non standard.

---

## Obiettivi

Allineare il database Oracle 19c agli standard di naming aziendali, aggiornando `DB_UNIQUE_NAME` e `ORACLE_SID`, rigenerando lo `SPFILE` in ASM nella nuova directory e rilocando tutti i file fisici (datafile, tempfile, redo log, controlfile) senza ricreare il database.

## Prerequisiti

- Change approvato e finestra pianificata.
- Backup RMAN recente e verificato.
- Stato Data Guard noto (ruolo, lag, broker).
- Accesso OS come `oracle` e `grid`.
- Tool disponibili: `srvctl`, `sqlplus`, `rman`, `asmcmd`.
- Spazio sufficiente sui diskgroup ASM target.
- Piano di rollback e contatti applicativi disponibili.

## Rischi e Impatto

- Downtime breve per la fase di controllo file (`controlfile`).
- Impatto su servizi se il clusterware non viene riallineato correttamente.
- Rischio di OMF che continui a scrivere nel path vecchio se lo `SPFILE` non e' rigenerato.
- Errore ORA-65500 se il DB e' ancora registrato nel clusterware con il vecchio nome.

## Procedura Operativa

### Step 0: Matrice di configurazione

| Componente | Stato iniziale | Stato finale |
| --- | --- | --- |
| DB_NAME | W4UCIHMO | W4UCIHMO (invariato) |
| DB_UNIQUE_NAME | W4UCIHMOC | W4UCIHMOPEC |
| ORACLE_SID | W4UCIHMOC | W4HMOPEC |
| ASM (root OMF) | +W4DMUCI_DATA/W4UCIHMOC/ | +W4DMUCI_DATA/W4UCIHMOPEC/ |

> Aggiorna i valori in tabella secondo il tuo ambiente.

---

### Fase 1: Modifica logica del DB_UNIQUE_NAME

> **Motivo**: `DB_UNIQUE_NAME` e' parametro statico. Se il DB e' registrato nel Clusterware, l'alter diretto in SPFILE genera ORA-65500.

1. **Stop DB e rimozione temporanea dal clusterware**

```bash
srvctl stop database -d W4UCIHMOC
srvctl remove database -d W4UCIHMOC
```

2. **Crea PFILE locale puntando al vecchio SPFILE ASM**

```bash
echo "SPFILE='+W4DMUCI_DATA/W4UCIHMOC/PARAMETERFILE/spfile.318.1234455867'" \
  > /u01/app/oracle/product/19.26.0.0/dbs/initW4UCIHMOC.ora
```

3. **Avvio minimo e cambio parametro**

```sql
sqlplus / as sysdba
STARTUP NOMOUNT;
ALTER SYSTEM SET db_unique_name='W4UCIHMOPEC' SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
EXIT;
```

---

### Fase 2: Generazione SPFILE sanato e directory ASM

1. **Registra temporaneamente il nuovo DB_UNIQUE_NAME**

```bash
srvctl add database -d W4UCIHMOPEC \
  -oraclehome /u01/app/oracle/product/19.26.0.0 \
  -spfile '+W4DMUCI_DATA/W4UCIHMOC/PARAMETERFILE/spfile.318.1234455867'

srvctl start database -d W4UCIHMOPEC
```

2. **Allinea ORACLE_SID e crea directory ASM**

```bash
export ORACLE_SID=W4HMOPEC
asmcmd mkdir +W4DMUCI_DATA/W4UCIHMOPEC
asmcmd mkdir +W4DMUCI_DATA/W4UCIHMOPEC/PARAMETERFILE
```

3. **Crea nuovo SPFILE definitivo partendo dalla memoria**

```sql
sqlplus / as sysdba
CREATE SPFILE='+W4DMUCI_DATA/W4UCIHMOPEC/PARAMETERFILE/spfileW4UCIHMOPEC.ora'
  FROM MEMORY;
EXIT;
```

4. **Aggiorna clusterware e PFILE locale**

```bash
srvctl modify database -d W4UCIHMOPEC \
  -spfile '+W4DMUCI_DATA/W4UCIHMOPEC/PARAMETERFILE/spfileW4UCIHMOPEC.ora'

mv /u01/app/oracle/product/19.26.0.0/dbs/initW4UCIHMOC.ora \
   /u01/app/oracle/product/19.26.0.0/dbs/initW4HMOPEC.ora

echo "SPFILE='+W4DMUCI_DATA/W4UCIHMOPEC/PARAMETERFILE/spfileW4UCIHMOPEC.ora'" \
  > /u01/app/oracle/product/19.26.0.0/dbs/initW4HMOPEC.ora
```

---

### Fase 3: Spostamento online dei datafile

1. **Genera comandi di move**

```sql
SELECT 'ALTER DATABASE MOVE DATAFILE ''' || name || ''' TO ''+W4DMUCI_DATA'';'
FROM v$datafile;
```

2. **Esegui i comandi uno alla volta**

```sql
ALTER DATABASE MOVE DATAFILE '+W4DMUCI_DATA/W4UCIHMOC/DATAFILE/system.123.456' TO '+W4DMUCI_DATA';
```

---

### Fase 4: Ricreazione tempfile e online redo log

**Tempfile**

```sql
ALTER TABLESPACE temp ADD TEMPFILE '+W4DMUCI_DATA' SIZE 1024M;
ALTER DATABASE TEMPFILE '+W4DMUCI_DATA/W4UCIHMOC/TEMPFILE/temp.123.456' DROP INCLUDING DATAFILES;
```

**Online Redo Log**

```sql
ALTER DATABASE ADD LOGFILE '+W4DMUCI_DATA' SIZE 500M;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
ALTER DATABASE DROP LOGFILE GROUP <ID_VECCHIO_GRUPPO>;
```

---

### Fase 5: Rilocazione e multiplexing controlfile

> **Downtime necessario**: pianifica finestra e avvisa i servizi.

1. **Aggiorna parametro `control_files` nello SPFILE**

```sql
ALTER SYSTEM SET control_files='+W4DMUCI_DATA', '+W4DMUCI_FRA' SCOPE=SPFILE;
SHUTDOWN IMMEDIATE;
STARTUP NOMOUNT;
EXIT;
```

2. **Ripristina controlfile da RMAN e riapri il DB**

```rman
rman target /
RESTORE CONTROLFILE FROM '+W4DMUCI_DATA/W4UCIHMOC/CONTROLFILE/current.309.1234454915';
ALTER DATABASE MOUNT;
ALTER DATABASE OPEN;
```

---

### Fase 6: Chiusura attivita e rimozione strutture orfane

1. **Riavvia via clusterware**

```bash
srvctl stop database -d W4UCIHMOPEC
srvctl start database -d W4UCIHMOPEC
```

2. **Verifica che tutta la base dati usi il nuovo path**

```sql
SELECT name FROM v$datafile;
SELECT name FROM v$tempfile;
SELECT member FROM v$logfile;
SHOW PARAMETER control_files;
```

3. **Rimuovi directory ASM orfane**

```bash
asmcmd ls -l +W4DMUCI_DATA/W4UCIHMOC
asmcmd rm -r +W4DMUCI_DATA/W4UCIHMOC
```

---

## Rollback

1. Stop database e rimuovi la registrazione del nuovo nome:

```bash
srvctl stop database -d W4UCIHMOPEC
srvctl remove database -d W4UCIHMOPEC
```

2. Ripristina PFILE e SPFILE precedente:

```bash
mv /u01/app/oracle/product/19.26.0.0/dbs/initW4HMOPEC.ora \
   /u01/app/oracle/product/19.26.0.0/dbs/initW4UCIHMOC.ora
```

3. Ri-registrazione del vecchio nome e avvio:

```bash
srvctl add database -d W4UCIHMOC \
  -oraclehome /u01/app/oracle/product/19.26.0.0 \
  -spfile '+W4DMUCI_DATA/W4UCIHMOC/PARAMETERFILE/spfile.318.1234455867'

srvctl start database -d W4UCIHMOC
```

4. Ripristina i controlfile dal backup se necessario e apri il DB.

---

## Validazione Finale

```sql
SELECT name, db_unique_name FROM v$database;
SHOW PARAMETER db_unique_name;
SHOW PARAMETER spfile;
SHOW PARAMETER control_files;
```

```sql
SELECT name FROM v$datafile;
SELECT name FROM v$tempfile;
SELECT member FROM v$logfile;
```

```bash
srvctl status database -d W4UCIHMOPEC
asmcmd ls +W4DMUCI_DATA/W4UCIHMOPEC
```

**Atteso**:
- `DB_UNIQUE_NAME` allineato allo standard.
- Tutti i file fisici sotto `+W4DMUCI_DATA/W4UCIHMOPEC/`.
- Risorse clusterware online senza errori.

---

## Troubleshooting / Piano di Rientro

- **ORA-65500**: rimuovi il database dal clusterware (`srvctl remove database -d <old>`), poi ripeti l'alter.
- **SPFILE non trovato**: verifica path ASM e permessi con `asmcmd ls`.
- **Datafile move bloccato**: controlla sessioni che usano il file e riprova in finestra di carico ridotto.
- **Redo log drop fallisce**: assicurati che il gruppo sia `INACTIVE` con `ALTER SYSTEM SWITCH LOGFILE` + `CHECKPOINT`.
- **Controlfile restore fallisce**: verifica path completo e compatibilita' con il DBID.

---

## Riferimenti

- [Identita Oracle e Servizi](../../02_core_dba/01_administration_and_security/GUIDA_IDENTITA_ORACLE_E_SERVIZI.md)
- [Cheat Sheet ASMCMD](../01_cheat_sheets/CS_ASMCMD.md)
- [Cheat Sheet SRVCTL/CRSCTL](../01_cheat_sheets/CS_SRVCTL_CRSCTL.md)
- [RMAN Essentials](../01_cheat_sheets/CS_RMAN_RAPIDO.md)
