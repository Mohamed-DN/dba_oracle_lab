#!/bin/bash

set -euo pipefail

echo "******************************************************************************"
echo "Preflight checks for Oracle RAC/Data Guard provisioning."
echo "******************************************************************************"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: preflight_checks.sh deve essere eseguito come root."
  exit 1
fi

if [ -z "${GRID_SOFTWARE:-}" ] || [ -z "${DB_SOFTWARE:-}" ]; then
  echo "ERROR: Variabili GRID_SOFTWARE/DB_SOFTWARE non valorizzate."
  echo "       Verifica i file /vagrant_config/install_primary.env o install_standby.env."
  exit 1
fi

GRID_PATH="/vagrant/software/${GRID_SOFTWARE}"
DB_PATH="/vagrant/software/${DB_SOFTWARE}"

if [ ! -f "${GRID_PATH}" ]; then
  echo "ERROR: File mancante: ${GRID_PATH}"
  echo "       Copia LINUX.X64_193000_grid_home.zip in vagrant_rac_dataguard/software/"
  exit 1
fi

if [ ! -f "${DB_PATH}" ]; then
  echo "ERROR: File mancante: ${DB_PATH}"
  echo "       Copia LINUX.X64_193000_db_home.zip in vagrant_rac_dataguard/software/"
  exit 1
fi

mkdir -p /vagrant/shared_disks
if [ ! -w /vagrant/shared_disks ]; then
  echo "ERROR: /vagrant/shared_disks non è scrivibile."
  exit 1
fi

echo "Preflight OK:"
echo "  GRID_SOFTWARE: ${GRID_SOFTWARE}"
echo "  DB_SOFTWARE:   ${DB_SOFTWARE}"
echo "  Shared disks:  /vagrant/shared_disks"
echo "******************************************************************************"
