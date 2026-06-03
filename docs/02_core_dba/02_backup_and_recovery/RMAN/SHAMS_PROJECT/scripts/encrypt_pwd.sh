#!/bin/bash
set -eu

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 password"
  echo "Note: base64 is encoding, not secure encryption. Prefer wallet aliases for RMAN."
  exit 2
fi

printf 'Encoded password is: '
printf '%s' "$1" | base64
