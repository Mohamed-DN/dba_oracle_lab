# GUIDA: Housekeeping Automatico (ADRCI Purge) 🧹

Una delle cause più frequenti di incidenti di produzione (inclusi crash di intere istanze RAC o del Clusterware) è il riempimento dei filesystem (`/u01` o Recovery Area) a causa dell'accumulo incontrollato di log, tracce e dump generati dall'infrastruttura Oracle.

A partire da Oracle 11g, l'**Automatic Diagnostic Repository (ADR)** centralizza questi log, ma le policy di purge automatiche interne (MMON) a volte non sono sufficienti o falliscono in caso di burst di errori. 

Questa guida descrive come implementare uno script di auto-purge robusto a livello OS tramite `cron`, garantendo che l'infrastruttura si auto-mantenga pulita.

---

## 1. Lo Script Enterprise: `adrci_auto_purge.sh`

Nel repository è fornito lo script ufficiale per gestire questa operazione:  
[scripts/shell/adrci_auto_purge.sh](../../../scripts/shell/adrci_auto_purge.sh)

### Caratteristiche principali dello script:
*   **Auto-Discovery**: Trova dinamicamente tutte le `ADR Home` configurate (Database, Listener, ASM, Grid).
*   **Retention Policy Granulare**: 
    *   Trace Files: 14 giorni (20160 minuti)
    *   Incident & Core Dumps: 30 giorni (43200 minuti)
*   **Logging Interno**: Traccia tutte le attività e pulisce i suoi stessi log più vecchi di 30 giorni.

---

## 2. Deploy e Schedulazione (Crontab)

L'installazione richiede pochi secondi e va effettuata sull'utente proprietario dell'installazione Oracle (generalmente `oracle` e/o `grid`).

### Step 2.1: Posizionamento
Copia lo script nella directory standard degli script amministrativi (es. `/u01/app/oracle/admin/scripts/shell/`):
```bash
mkdir -p /u01/app/oracle/admin/scripts/shell/
cp adrci_auto_purge.sh /u01/app/oracle/admin/scripts/shell/
chmod 700 /u01/app/oracle/admin/scripts/shell/adrci_auto_purge.sh
```

### Step 2.2: Configurazione Crontab
Schedula lo script per l'esecuzione giornaliera, ad esempio alle 02:30 del mattino:
```bash
crontab -e
```
Aggiungi la seguente linea:
```text
# ====================================================================
# ORACLE HOUSEKEEPING
# ====================================================================
30 02 * * * /u01/app/oracle/admin/scripts/shell/adrci_auto_purge.sh > /dev/null 2>&1
```

> [!TIP]
> **Ambienti RAC / Grid Infrastructure**:  
> In ambienti RAC, ricorda di copiare e schedulare lo script **su tutti i nodi** del cluster. Inoltre, se il ruolo è separato, l'utente `grid` dovrà avere una copia dello script schedulata nel proprio crontab per pulire la ADR Home di ASM e Clusterware.

---

## 3. Gestione e Triage (Verifica del Purge)

Se hai un incidente di spazio (`ORA-09817` o simili), puoi lanciare lo script manualmente in qualsiasi momento:

```bash
su - oracle
/u01/app/oracle/admin/scripts/shell/adrci_auto_purge.sh
```

I log dello script verranno generati nella cartella `/u01/app/oracle/admin/scripts/logs/`. Per verificare che il purge sia andato a buon fine, analizza gli ultimi log:

```bash
tail -f /u01/app/oracle/admin/scripts/logs/adrci_auto_purge_*.log
```

### 🚨 Risoluzione Problemi Comuni
Se un alert log XML (`log.xml`) diventa troppo grande malgrado il purge:
*   **Rotazione manuale Alert Log**: ADRCI ruota l'alert log XML a 10MB di default, ma se l'istanza genera migliaia di log al secondo potrebbe esserci un bug o un listener instabile.
*   **File bloccati**: Assicurati che non ci siano processi zombie (o sessioni `tail -f`) che mantengono i vecchi trace aperti in modalità lock, impedendone la cancellazione a livello di OS.
