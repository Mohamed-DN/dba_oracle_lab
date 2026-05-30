#!/bin/bash
# ==============================================================================================
# SCRIPT        : adrci_auto_purge.sh
# DESCRIPTION   : Housekeeping automatico intelligente per ADRCI (Automatic Diagnostic Repository)
#                 Esegue il purge di Trace files, Incident Dumps, Core Dumps e Alert Logs.
# AUTHOR        : Enterprise DBA Lab
# USAGE         : ./adrci_auto_purge.sh (tipicamente schedulato via crontab)
# ==============================================================================================

# --- Configurazione Variabili d'Ambiente ---
if [ -f ~/.bash_profile ]; then
    # shellcheck source=/dev/null
    source ~/.bash_profile
fi

# Directory di Log dello script (assicurarsi che esista)
LOG_DIR="/u01/app/oracle/admin/scripts/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/adrci_auto_purge_$(date +%Y%m%d).log"

# --- Policy di Retention (in Minuti) ---
# 14 giorni = 20160 minuti
# 30 giorni = 43200 minuti
RETENTION_MINUTES_TRACE=20160
RETENTION_MINUTES_INCIDENT=43200
RETENTION_MINUTES_CDUMP=20160

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" | tee -a "${LOG_FILE}"
}

log_msg "=================================================================="
log_msg " INIZIO PURGE ADRCI"
log_msg " ORACLE_HOME = ${ORACLE_HOME}"
log_msg " ORACLE_BASE = ${ORACLE_BASE}"
log_msg "=================================================================="

# Verifica disponibilità eseguibile adrci
if [ ! -x "${ORACLE_HOME}/bin/adrci" ]; then
    log_msg "ERRORE: Eseguibile adrci non trovato in ${ORACLE_HOME}/bin!"
    exit 1
fi

# Ottenere tutti gli ADR Home disponibili
ADR_HOMES=$(${ORACLE_HOME}/bin/adrci exec="show homes" | grep -v "ADR Homes:")

if [ -z "${ADR_HOMES}" ]; then
    log_msg "ATTENZIONE: Nessun ADR Home trovato."
    exit 0
fi

for HOME in ${ADR_HOMES}; do
    log_msg ">>> Elaborazione ADR Home: ${HOME}"
    
    # Esecuzione purge per tipo
    log_msg "    [PURGE] ALERT (Purge automatico applicando policy di default ADR)..."
    ${ORACLE_HOME}/bin/adrci exec="set homepath ${HOME}; purge -type ALERT" >> "${LOG_FILE}" 2>&1
    
    log_msg "    [PURGE] TRACE (Ritenzione: ${RETENTION_MINUTES_TRACE} minuti)..."
    ${ORACLE_HOME}/bin/adrci exec="set homepath ${HOME}; purge -age ${RETENTION_MINUTES_TRACE} -type TRACE" >> "${LOG_FILE}" 2>&1
    
    log_msg "    [PURGE] INCIDENT (Ritenzione: ${RETENTION_MINUTES_INCIDENT} minuti)..."
    ${ORACLE_HOME}/bin/adrci exec="set homepath ${HOME}; purge -age ${RETENTION_MINUTES_INCIDENT} -type INCIDENT" >> "${LOG_FILE}" 2>&1
    
    log_msg "    [PURGE] CDUMP (Ritenzione: ${RETENTION_MINUTES_CDUMP} minuti)..."
    ${ORACLE_HOME}/bin/adrci exec="set homepath ${HOME}; purge -age ${RETENTION_MINUTES_CDUMP} -type CDUMP" >> "${LOG_FILE}" 2>&1
    
    log_msg "    Completato purge per: ${HOME}"
    log_msg "------------------------------------------------------------------"
done

# --- Pulizia vecchio file di log dello script ---
find "${LOG_DIR}" -name "adrci_auto_purge_*.log" -mtime +30 -exec rm {} \;
log_msg "Pulizia log script vecchi (> 30 giorni) completata."

log_msg "=================================================================="
log_msg " FINE PURGE ADRCI COMPLETATO CON SUCCESSO"
log_msg "=================================================================="

exit 0
