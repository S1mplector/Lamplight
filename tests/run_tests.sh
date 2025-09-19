#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

if command -v bats >/dev/null 2>&1; then
  echo "Running Bats tests..."
  bats tests/*.bats
else
  echo "Bats not found. Running shell tests..."
  fail=0
  for t in tests/*_test.sh; do
    echo "-- $t"
    bash "$t" || fail=1
  done
  if (( fail )); then
    echo "Some shell tests failed." >&2
    exit 1
  fi
  echo "All shell tests passed."
fi
