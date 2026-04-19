#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"
CHANGELOG_FILE="${ROOT_DIR}/CHANGELOG.md"
COMPAT_FILE="${ROOT_DIR}/reliability/release/compatibility_matrix.yml"
OUT_DIR="${ROOT_DIR}/reliability/release/artifacts"

version="$(tr -d '[:space:]' < "${VERSION_FILE}")"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "${OUT_DIR}"

manifest="${OUT_DIR}/release-manifest-${version}.json"
compat_copy="${OUT_DIR}/compatibility-matrix-${version}.yml"

cp "${COMPAT_FILE}" "${compat_copy}"

cat > "${manifest}" <<EOF_JSON
{
  "version": "${version}",
  "generated_at_utc": "${ts}",
  "artifacts": {
    "changelog": "CHANGELOG.md",
    "compatibility_matrix": "reliability/release/compatibility_matrix.yml"
  },
  "release_governance": {
    "semver_source": "VERSION",
    "changelog_required_section": "Unreleased"
  }
}
EOF_JSON

sha256sum "${manifest}" "${compat_copy}" > "${OUT_DIR}/checksums-${version}.txt"

grep -q "## \[Unreleased\]" "${CHANGELOG_FILE}"
echo "Release artifacts built in ${OUT_DIR}"
