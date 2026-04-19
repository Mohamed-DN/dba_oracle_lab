#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
AUTOMATION_DIR="${ROOT_DIR}/automation"
MOCK_BIN="${ROOT_DIR}/tests/e2e/ansible/mocks/bin"
LOG_DIR="${ROOT_DIR}/tests/e2e/ansible/logs"

mkdir -p "${LOG_DIR}"

export PATH="${MOCK_BIN}:${PATH}"
export ANSIBLE_STDOUT_CALLBACK=default

common_args=(
  -i "${ROOT_DIR}/tests/e2e/ansible/inventory.ini"
  -e oracle_home="${ROOT_DIR}/tests/e2e/ansible/mocks"
  -e grid_home="${ROOT_DIR}/tests/e2e/ansible/mocks"
  -e oracle_sid=RACDB1
  -e oracle_db_name=RACDB
  -e oracle_standby_db_name=RACDB_STBY
  -e switchover_require_confirmation=true
  -e ansible_become=false
)

cd "${AUTOMATION_DIR}"

ansible-playbook "${common_args[@]}" playbooks/04_daily_health_check.yml \
  | tee "${LOG_DIR}/04_daily_health_check.log"

ansible-playbook "${common_args[@]}" playbooks/05_rman_backup.yml \
  | tee "${LOG_DIR}/05_rman_backup.log"

ansible-playbook "${common_args[@]}" -e switchover_non_interactive=true playbooks/06_dataguard_switchover.yml \
  | tee "${LOG_DIR}/06_dataguard_switchover.log"

echo "Functional E2E completed successfully"
