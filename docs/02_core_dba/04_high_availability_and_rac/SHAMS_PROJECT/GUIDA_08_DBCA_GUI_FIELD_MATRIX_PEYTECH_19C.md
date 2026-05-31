# SHAMS PROJECT: Matrice Campi DBCA PEYTECH Oracle 19c

## Obiettivo operativo

Compilare DBCA senza confondere il nome condiviso del database con il nome
site-specific della configurazione Data Guard. Questa checklist deriva
dall'audit delle schermate DBCA ricevute e dalla baseline PEYTECH adattata a
Oracle 19c.

DBCA crea soltanto il primary PE. Il physical standby SE viene creato in un
secondo momento con RMAN duplicate, non con un altro wizard DBCA indipendente.

## Fonti Oracle ufficiali

- [Creazione database con DBCA](https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/installing-oracle-database-creating-database.html)
- [Naming database e SID](https://docs.oracle.com/en/database/oracle/oracle-database/19/rilin/selecting-a-database-name.html)
- [Creazione RAC con DBCA](https://docs.oracle.com/en/database/oracle/oracle-database/19/racpd/create-oracle-rac-database-dbca.html)

## Naming da usare

Per il collaudo `C`, il primary e' sul sito `PE` e lo standby sul sito `SE`.

| Oggetto | Primary PE | Standby SE |
| --- | --- | --- |
| Nome base condiviso | `M24SHAMS` | `M24SHAMS` |
| `DB_NAME` | `M24SHAMS` | `M24SHAMS` |
| `DB_UNIQUE_NAME` | `M24SHAMSPEC` | `M24SHAMSSEC` |
| Global Database Name DBCA | `M24SHAMSPEC[.<DB_DOMAIN>]` | N/A: no DBCA |
| SID DBCA single instance | `M24SHAMSPEC` | N/A: no DBCA |
| SID prefix DBCA RAC | `M24SHAMSPEC` | N/A: no DBCA |
| SID RAC risultanti | `M24SHAMSPEC1`, `M24SHAMSPEC2` | `M24SHAMSSEC1`, `M24SHAMSSEC2` |
| SID locale auxiliary single | N/A | `M24SHAMSSEC` |

La regola PEYTECH e':

```text
DB_UNIQUE_NAME = <NOME_BASE><DATACENTER><AMBIENTE>
```

Per questo change:

```text
M24SHAMS + PE + C = M24SHAMSPEC
M24SHAMS + SE + C = M24SHAMSSEC
```

Per questo standard PEYTECH il SID single inserito in DBCA e' site-specific:
`M24SHAMSPEC`. Anche il SID prefix RAC e' site-specific; DBCA aggiunge il
numero di istanza e crea `M24SHAMSPEC1` e `M24SHAMSPEC2`.

## Preflight

Prima di aprire DBCA raccogli dal database di riferimento i parametri
approvati. Non copiare valori di sizing da una schermata senza evidenza.

```sql
SELECT name, db_unique_name, log_mode
FROM v$database;

SELECT name, display_value
FROM v$parameter
WHERE name IN (
  'sga_target',
  'sga_max_size',
  'pga_aggregate_target',
  'processes',
  'sessions',
  'open_cursors',
  'db_block_size',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'log_archive_format'
)
ORDER BY name;

SELECT parameter, value
FROM nls_database_parameters
WHERE parameter IN (
  'NLS_CHARACTERSET',
  'NLS_NCHAR_CHARACTERSET',
  'NLS_LANGUAGE',
  'NLS_TERRITORY'
)
ORDER BY parameter;

SELECT DBMS_XDB_CONFIG.GETHTTPSPORT() AS em_express_https_port
FROM dual;

SELECT username, account_status
FROM dba_users
WHERE username IN ('DBSNMP', 'SYSMAN')
ORDER BY username;

SELECT group#, thread#, bytes / 1024 / 1024 AS mb, members, status
FROM v$log
ORDER BY thread#, group#;
```

Registra nel change:

- RAM host e sizing SGA/PGA approvato;
- FRA bytes disponibili sul diskgroup dedicato;
- quattro online redo log group da `4G` per thread come baseline iniziale,
  da validare sul carico;
- componenti richiesti realmente dall'applicazione;
- uso o meno di EM Express e Cloud Control;
- blueprint selezionato: `S1`, `S2`, `S3` oppure `S4`.

## Procedura operativa

### 1. Avvio corretto

Avvia DBCA dal Database Home:

```bash
export ORACLE_BASE=<ORACLE_BASE>
export ORACLE_HOME=<ORACLE_HOME>
export PATH="$ORACLE_HOME/bin:$PATH"
dbca
```

Non usare `Typical configuration`. Seleziona `Advanced configuration` per
controllare template, storage, componenti, parametri e script generati.

### 2. Matrice schermata-per-schermata

| Schermata DBCA | Scelta approvata | Verifica operativa |
| --- | --- | --- |
| Creation Mode | `Advanced configuration` | Non usare il percorso `Typical configuration`. |
| Deployment Type | Single instance per `S1`/`S2`; RAC per `S3`/`S4` | Per RAC usare configurazione admin-managed e selezionare entrambi i nodi. |
| Template | `Custom Database` | Evita template con datafile precostituiti quando serve controllo completo della creazione. |
| Database Identification, Global Database Name | `M24SHAMSPEC[.<DB_DOMAIN>]` | Contiene nome base, sito primary `PE` e ambiente collaudo `C`. |
| Database Identification, single instance SID | `M24SHAMSPEC` | Segue la convenzione site-specific PEYTECH. |
| Database Identification, RAC SID prefix | `M24SHAMSPEC` | DBCA crea `M24SHAMSPEC1` e `M24SHAMSPEC2`. |
| Container database | Disabilitato per `S1`/`S3`; abilitato per `S2`/`S4` | Per CDB creare la PDB iniziale `M24SHAMSC_APP`. |
| Storage Option | ASM con OMF su `+M24SHAMS_DATA` | Revisionare control file e redo multiplexati tra DATA e FRA. |
| Fast Recovery Option | FRA su `+M24SHAMS_FRA` con sizing approvato | Non puntare la FRA al diskgroup DATA. |
| Archiving | Abilitato | Nel popup usare automatic archiving; lasciare vuote le destinazioni locali se la destinazione prevista e' la FRA. |
| Network Configuration | Listener GI gia' approvati: applicativo `1521`, DG `1531` | Non creare un listener aggiuntivo vuoto o duplicato. |
| Database Options | Solo componenti applicativi approvati | Disabilitare OJVM, Spatial, Multimedia e OLAP se non richiesti. Oracle Text richiede conferma applicativa. |
| Memory | ASMM con SGA/PGA da sizing approvato | Non copiare automaticamente valori derivati dalla RAM host. |
| Sizing | `processes=2048`, `db_block_size=8192` salvo eccezione approvata | Verificare anche `sessions` e `open_cursors` rispetto al riferimento. |
| Character sets | `AL32UTF8`, `AL16UTF16`, `American`, `United States` | Registrare eventuali eccezioni applicative. |
| Connection mode | Dedicated server | Usare shared server solo con requisito esplicito. |
| Management Options | EM Express disabilitato salvo approvazione; Cloud Control solo con team monitoring | Confrontare con `GETHTTPSPORT()` e stato account di monitoraggio del riferimento. |
| Creation Option | `Generate database creation scripts` | Salvare in `$ORACLE_BASE/admin/$DB_NAME/scripts`, revisionare SQL e init file prima dell'esecuzione. |

### 3. All Initialization Parameters

Prima di generare gli script apri `All Initialization Parameters`, correggi i
valori e seleziona l'inclusione nello SPFILE dove applicabile.

| Parametro | Valore primary PE |
| --- | --- |
| `db_name` | `M24SHAMS` |
| `db_unique_name` | `M24SHAMSPEC` |
| `db_create_file_dest` | `+M24SHAMS_DATA` |
| `db_recovery_file_dest` | `+M24SHAMS_FRA` |
| `db_recovery_file_dest_size` | `<FRA_BYTES>` |
| `processes` | `2048`, salvo sizing approvato differente |
| `db_block_size` | `8192`, salvo requisito applicativo differente |

Il trasporto redo remoto Data Guard viene configurato dopo la preparazione
dello standby. Non inserire destinazioni remote improvvisate nel wizard.

### 4. Review degli script

DBCA deve produrre script da revisionare, non creare direttamente il database.
Conserva nel change gli script approvati e il summary DBCA.

Verifica almeno:

- `CREATE DATABASE` coerente con `M24SHAMS`;
- `DB_NAME=M24SHAMS` e `DB_UNIQUE_NAME=M24SHAMSPEC`;
- OMF e path ASM corretti;
- control file e redo multiplexati tra DATA e FRA;
- FRA su `+M24SHAMS_FRA`;
- `ARCHIVELOG` abilitato;
- componenti non richiesti assenti;
- nessuna password leggibile in file o argomenti shell.

## Errori rilevati nelle schermate ricevute

| Evidenza GUI | Correzione |
| --- | --- |
| Percorso `Typical configuration` | Usare `Advanced configuration`. |
| Template `General Purpose or Transaction Processing` | Usare `Custom Database` per il percorso controllato PEYTECH. |
| FRA inizialmente puntata al diskgroup DATA | Impostare `+M24SHAMS_FRA` e validare lo spazio reale. |
| `Enable archiving` non selezionato | Abilitare archiving e usare la FRA come destinazione locale. |
| Opzione per creare un nuovo listener selezionata senza necessità | Selezionare i listener GI esistenti `1521` e `1531`; non crearne uno duplicato. |
| OJVM, Text, Multimedia, OLAP e Spatial selezionati | Installare soltanto i componenti approvati dall'applicazione. |
| EM Express selezionato sulla porta `5500` | Disabilitarlo salvo decisione esplicita del team monitoring. |
| `Create database` selezionato nella Creation Option | Usare `Generate database creation scripts`, revisionare ed eseguire gli script approvati. |

Le schermate mostrano dove intervenire, ma i valori dell'esempio ricevuto non
sono la naming authority del progetto SHAMS. Per SHAMS si conserva la
distinzione tra Global Database Name e SID site-specific
`M24SHAMSPEC`, `db_name=M24SHAMS` e `db_unique_name=M24SHAMSPEC`.

## Validazione finale

Prima di autorizzare l'esecuzione:

```text
[ ] Advanced configuration
[ ] Custom Database
[ ] Global Database Name = M24SHAMSPEC[.<DB_DOMAIN>]
[ ] SID single = M24SHAMSPEC oppure SID prefix RAC = M24SHAMSPEC
[ ] db_name = M24SHAMS
[ ] db_unique_name = M24SHAMSPEC
[ ] FRA = +M24SHAMS_FRA
[ ] ARCHIVELOG abilitato
[ ] listener esistenti selezionati, nessun listener duplicato
[ ] componenti opzionali approvati uno per uno
[ ] Generate database creation scripts
[ ] script revisionati e allegati al change
```

Dopo l'esecuzione controllata:

```sql
SELECT name, db_unique_name, log_mode, force_logging, cdb
FROM v$database;

SELECT instance_name, status
FROM v$instance;

SHOW PARAMETER db_recovery_file_dest
SHOW PARAMETER db_recovery_file_dest_size
```

## Troubleshooting rapido

| Problema | Azione |
| --- | --- |
| Il SID single non include sito e ambiente | Impostare `M24SHAMSPEC` secondo la convenzione PEYTECH; mantenere distinto `db_name=M24SHAMS`. |
| DBCA calcola `DB_NAME` non coerente | Correggere `db_name=M24SHAMS` in `All Initialization Parameters`, includerlo nello SPFILE e verificare gli script generati. |
| FRA punta a DATA | Tornare alla schermata Fast Recovery Option e scegliere `+M24SHAMS_FRA`. |
| Il listener DG non compare | Configurare prima il listener GI `1531` nell'allegato host; non crearne uno DB Home duplicato. |
| Una option applicativa e' dubbia | Fermare il change e ottenere conferma applicativa/licenza prima della generazione script. |
| Il wizard e' gia' arrivato alla creazione diretta | Annullare, riaprire DBCA e scegliere la generazione script; non promuovere un database creato fuori dal percorso approvato. |
