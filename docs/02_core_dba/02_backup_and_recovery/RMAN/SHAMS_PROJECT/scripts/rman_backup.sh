#!/bin/bash
set -u

DB_UNQNAME="${1:-}"
ACTION="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${SCRIPT_DIR}/cfg/rman_backup_${DB_UNQNAME}.conf"
RDIR="${SCRIPT_DIR}/rman"
LDIR="${SCRIPT_DIR}/logs"
DATE="$(date '+%Y%m%d_%H%M%S')"

usage() {
  echo "Usage: $0 <DB_UNIQUE_NAME> { full | cumulative | differential | archive }"
}

if [ -z "${DB_UNQNAME}" ] || [ -z "${ACTION}" ]; then
  usage
  exit 2
fi

case "${ACTION}" in
  full|cumulative|differential|archive) ;;
  *) usage; exit 2 ;;
esac

if [ ! -r "${CONFIG}" ]; then
  echo "ERROR: cannot read config file ${CONFIG}"
  exit 1
fi

# shellcheck disable=SC1090
. "${CONFIG}"

: "${ORACLE_HOME:?ORACLE_HOME must be set in ${CONFIG}}"
: "${ORACLE_SID:?ORACLE_SID must be set in ${CONFIG}}"
: "${ORACLE_UNQNAME:?ORACLE_UNQNAME must be set in ${CONFIG}}"
: "${BCKDIR:?BCKDIR must be set in ${CONFIG}}"
: "${BCKDIR_MOUNTPOINT:=/backup/rman}"
: "${REQUIRE_BCKDIR_MOUNT:=YES}"
: "${RMAN_CATALOG_CONNECT:?RMAN_CATALOG_CONNECT must be set in ${CONFIG}}"
: "${RMAN_TARGET_CONNECT:=/}"
: "${EXEC_DATAFILE_BACKUP_WHEN:=STANDBY}"
: "${PARALLEL_CHANNELS:=4}"
: "${SECTION_SIZE:=32G}"
: "${ARCHIVELOG_FROM_TIME:=SYSDATE - 4/24}"
: "${LOG_RETENTION_DAYS:=30}"
: "${IGNORE_RMAN_ERRORS:=RMAN-08137}"
: "${MAIL_TO:=}"

export ORACLE_HOME ORACLE_SID ORACLE_UNQNAME
export PATH="${ORACLE_HOME}/bin:${PATH}"

if [ "${REQUIRE_BCKDIR_MOUNT}" = "YES" ]; then
  if command -v mountpoint >/dev/null 2>&1; then
    if ! mountpoint -q "${BCKDIR_MOUNTPOINT}"; then
      echo "ERROR: backup mountpoint is not mounted: ${BCKDIR_MOUNTPOINT}"
      exit 1
    fi
  else
    echo "ERROR: mountpoint command not available; set REQUIRE_BCKDIR_MOUNT=NO only with approved evidence"
    exit 1
  fi
fi

mkdir -p "${LDIR}" "${BCKDIR}/pieces/database" "${BCKDIR}/pieces/archivelog" \
  "${BCKDIR}/pieces/controlfile" "${BCKDIR}/pieces/spfile" \
  "${BCKDIR}/metadata" "${BCKDIR}/reports" "${BCKDIR}/evidence"

LOGF="${LDIR}/${ACTION}_${DB_UNQNAME}.log"
if [ -f "${LOGF}" ]; then
  mv "${LOGF}" "${LOGF}.${DATE}"
fi

exec >"${LOGF}" 2>&1

LOCKDIR="/var/tmp/rman_${DB_UNQNAME}_${ACTION}.lock"
if ! mkdir "${LOCKDIR}" 2>/dev/null; then
  echo "ERROR: lock exists: ${LOCKDIR}. Another ${ACTION} job may be running."
  exit 1
fi
trap 'rm -rf "${LOCKDIR}"' EXIT

sql_value() {
  local sql_text="$1"
  sqlplus -s / as sysdba <<EOF_SQL
SET HEAD OFF FEED OFF PAGES 0 VERIFY OFF ECHO OFF
${sql_text}
EXIT;
EOF_SQL
}

DATABASE_ROLE="$(sql_value "SELECT database_role FROM v\\$database;" | sed 's/^ *//;s/ *$//')"
OPEN_MODE="$(sql_value "SELECT open_mode FROM v\\$database;" | sed 's/^ *//;s/ *$//')"
LOG_MODE="$(sql_value "SELECT log_mode FROM v\\$database;" | tr -d '[:space:]')"
ACTUAL_UNQNAME="$(sql_value "SELECT db_unique_name FROM v\\$database;" | tr -d '[:space:]')"

echo "INFO: ${DATE} starting RMAN ${ACTION} for ${DB_UNQNAME}"
echo "INFO: role=${DATABASE_ROLE} open_mode=${OPEN_MODE} log_mode=${LOG_MODE}"

if [ "${ACTUAL_UNQNAME}" != "${DB_UNQNAME}" ]; then
  echo "ERROR: expected DB_UNIQUE_NAME=${DB_UNQNAME}, found ${ACTUAL_UNQNAME}"
  exit 1
fi

if [ "${LOG_MODE}" != "ARCHIVELOG" ]; then
  echo "ERROR: database is not in ARCHIVELOG mode"
  exit 1
fi

if [ "${DATABASE_ROLE}" = "PRIMARY" ] && [ "${OPEN_MODE}" != "READ WRITE" ]; then
  echo "ERROR: primary database must be READ WRITE for this backup"
  exit 1
fi

if [ "${DATABASE_ROLE}" = "PHYSICAL STANDBY" ]; then
  case "${OPEN_MODE}" in
    MOUNTED|READ\ ONLY|READ\ ONLY\ WITH\ APPLY) ;;
    *) echo "ERROR: physical standby open mode not valid for RMAN backup: ${OPEN_MODE}"; exit 1 ;;
  esac
fi

RUN_DATAFILE_BACKUP=0
case "${EXEC_DATAFILE_BACKUP_WHEN}" in
  ALWAYS) RUN_DATAFILE_BACKUP=1 ;;
  NEVER) RUN_DATAFILE_BACKUP=0 ;;
  PRIMARY) [ "${DATABASE_ROLE}" = "PRIMARY" ] && RUN_DATAFILE_BACKUP=1 ;;
  STANDBY) [ "${DATABASE_ROLE}" = "PHYSICAL STANDBY" ] && RUN_DATAFILE_BACKUP=1 ;;
  *) echo "ERROR: EXEC_DATAFILE_BACKUP_WHEN must be ALWAYS, NEVER, PRIMARY or STANDBY"; exit 1 ;;
esac

if [ "${ACTION}" = "archive" ]; then
  INPUT_TYPE_PREDICATE="= 'ARCHIVELOG'"
else
  INPUT_TYPE_PREDICATE="<> 'ARCHIVELOG'"
fi

running_count="$(sqlplus -s / as sysdba <<EOF_SQL
SET HEAD OFF FEED OFF PAGES 0
SELECT COUNT(*)
FROM v\$rman_backup_job_details
WHERE status = 'RUNNING'
  AND input_type ${INPUT_TYPE_PREDICATE};
EXIT;
EOF_SQL
)"
running_count="$(echo "${running_count}" | tr -d '[:space:]')"
if [ "${running_count:-0}" -gt 0 ]; then
  echo "ERROR: another RMAN ${ACTION} class job is already running"
  exit 1
fi

case "${ACTION}" in
  full)
    [ "${RUN_DATAFILE_BACKUP}" -eq 0 ] && echo "INFO: datafile backup skipped by role policy" && exit 0
    [ "${DATABASE_ROLE}" = "PRIMARY" ] && CMDF="${RDIR}/bck_full_primary.rcv" || CMDF="${RDIR}/bck_full_standby.rcv"
    ;;
  cumulative)
    [ "${RUN_DATAFILE_BACKUP}" -eq 0 ] && echo "INFO: datafile backup skipped by role policy" && exit 0
    [ "${DATABASE_ROLE}" = "PRIMARY" ] && CMDF="${RDIR}/bck_incr_cumulative_primary.rcv" || CMDF="${RDIR}/bck_incr_cumulative_standby.rcv"
    ;;
  differential)
    [ "${RUN_DATAFILE_BACKUP}" -eq 0 ] && echo "INFO: datafile backup skipped by role policy" && exit 0
    [ "${DATABASE_ROLE}" = "PRIMARY" ] && CMDF="${RDIR}/bck_incr_differential_primary.rcv" || CMDF="${RDIR}/bck_incr_differential_standby.rcv"
    ;;
  archive)
    [ "${DATABASE_ROLE}" = "PRIMARY" ] && CMDF="${RDIR}/bck_archive_primary.rcv" || CMDF="${RDIR}/bck_archive_standby.rcv"
    ;;
esac

if [ ! -r "${CMDF}" ]; then
  echo "ERROR: RMAN cmdfile not found: ${CMDF}"
  exit 1
fi

rman target "${RMAN_TARGET_CONNECT}" catalog "${RMAN_CATALOG_CONNECT}" \
  cmdfile "${CMDF}" using "${BCKDIR}" "${DB_UNQNAME}" "${ARCHIVELOG_FROM_TIME}" "${PARALLEL_CHANNELS}" "${SECTION_SIZE}"

err_count="$(grep -E 'RMAN-|ORA-[0-9]{5}|^ERROR' "${LOGF}" | grep -Ev "${IGNORE_RMAN_ERRORS}" | wc -l | tr -d '[:space:]')"
if [ "${err_count}" -gt 0 ]; then
  echo "ERROR: RMAN errors found in ${LOGF}"
  if [ -n "${MAIL_TO}" ]; then
    mail -s "${DB_UNQNAME} RMAN ${ACTION} error" "${MAIL_TO}" < "${LOGF}" || true
  fi
  exit 1
fi

find "${LDIR}" -type f -name '*.log.*' -mtime "+${LOG_RETENTION_DAYS}" -delete
echo "INFO: RMAN ${ACTION} completed successfully"
