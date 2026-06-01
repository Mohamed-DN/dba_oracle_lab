#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AUTOMATION_DIR="${ROOT_DIR}/automation"
MOCK_BIN="${ROOT_DIR}/tests/e2e/ansible/mocks/bin"
LOG_DIR="${ROOT_DIR}/tests/e2e/ansible/logs"
TMP_DIR="${ROOT_DIR}/tests/e2e/ansible/tmp"
RMAN_ROOT="${TMP_DIR}/backup/rman"
SCRIPT_ROOT="${TMP_DIR}/scripts"

rm -rf "${TMP_DIR}"
mkdir -p "${LOG_DIR}" "${RMAN_ROOT}" "${SCRIPT_ROOT}"

export PATH="${MOCK_BIN}:${PATH}"
export ANSIBLE_STDOUT_CALLBACK=default
export ANSIBLE_ROLES_PATH="${AUTOMATION_DIR}/roles"

common_args=(
  -i "${ROOT_DIR}/tests/e2e/ansible/inventory.ini"
  -e oracle_home="${ROOT_DIR}/tests/e2e/ansible/mocks"
  -e grid_home="${ROOT_DIR}/tests/e2e/ansible/mocks"
  -e oracle_standby_db_name=RACDB_STBY
  -e switchover_require_confirmation=true
  -e ansible_become=false
  -e rman_repository_root="${RMAN_ROOT}"
  -e rman_require_repository_mount=false
  -e rman_repository_owner="$(id -un)"
  -e rman_repository_group="$(id -gn)"
)

cd "${AUTOMATION_DIR}"

ansible-playbook "${common_args[@]}" playbooks/daily_health_check.yml \
  | tee "${LOG_DIR}/daily_health_check.log"

ansible-playbook "${common_args[@]}" -e rman_backup_type=LEVEL0 playbooks/rman_backup.yml \
  | tee "${LOG_DIR}/rman_backup.log"

for db_unique_name in RACDB RACDB_STBY; do
  test -d "${RMAN_ROOT}/${db_unique_name}/pieces/database"
  test -d "${RMAN_ROOT}/${db_unique_name}/pieces/archivelog"
  test -f "${RMAN_ROOT}/${db_unique_name}/reports/latest_backup.status"
  test -f "${RMAN_ROOT}/${db_unique_name}/reports/latest_validate.status"
  grep -q '^STATUS=SUCCESS$' "${RMAN_ROOT}/${db_unique_name}/reports/latest_backup.status"
done

if grep -R -n 'DELETE[[:space:]]' "${AUTOMATION_DIR}/roles/oracle_rman_backup"; then
  echo "Backup role must not contain DELETE statements" >&2
  exit 1
fi

if ansible-playbook "${common_args[@]}" \
  -e rman_cleanup_min_level0_backups=3 playbooks/rman_cleanup.yml \
  >"${LOG_DIR}/rman_cleanup_blocked.log" 2>&1; then
  echo "Cleanup should fail when fewer than two recoverable chains are accepted" >&2
  exit 1
fi

ansible-playbook "${common_args[@]}" playbooks/rman_cleanup.yml \
  | tee "${LOG_DIR}/rman_cleanup.log"

for db_unique_name in RACDB RACDB_STBY; do
  test -f "${RMAN_ROOT}/${db_unique_name}/reports/latest_cleanup.status"
  grep -q '^STATUS=SUCCESS$' "${RMAN_ROOT}/${db_unique_name}/reports/latest_cleanup.status"
done

ansible-playbook "${common_args[@]}" \
  -e rman_schedule_manage_cron=false \
  -e rman_script_dir="${SCRIPT_ROOT}" \
  playbooks/rman_schedule.yml \
  | tee "${LOG_DIR}/rman_schedule.log"

test -x "${SCRIPT_ROOT}/rman_backup_job.sh"
test -x "${SCRIPT_ROOT}/rman_cleanup_job.sh"

ansible-playbook "${common_args[@]}" -e switchover_non_interactive=true playbooks/dataguard_switchover.yml \
  | tee "${LOG_DIR}/dataguard_switchover.log"

echo "Functional E2E completed successfully"
