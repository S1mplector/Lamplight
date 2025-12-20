#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")"/.. && pwd)"
  source "$ROOT_DIR/lib/config.sh"
  source "$ROOT_DIR/lib/infrastructure/ui_tui.sh"
  source "$ROOT_DIR/lib/domain/notebook.sh"
  source "$ROOT_DIR/lib/usecase/search_entries.sh"

  TMP_JOURNAL_DIR=$(mktemp -d)
  JOURNAL_DIR_BASE="$TMP_JOURNAL_DIR"
  ACTIVE_NOTEBOOK_CONFIG_FILE="$TMP_JOURNAL_DIR/.active_notebook"
  DEFAULT_NOTEBOOK_NAME="TestDefault"
  NC=""; YELLOW=""; GREEN=""; CYAN=""; RED=""; MAGENTA=""
  THIN='-'
}

teardown() {
  rm -rf "$TMP_JOURNAL_DIR"
}

@test "scan filters by date range across notebooks" {
  mkdir -p "$JOURNAL_DIR_BASE/NB1" "$JOURNAL_DIR_BASE/NB2"
  cat > "$JOURNAL_DIR_BASE/NB1/2023-01-01_000000.txt" <<EOF
# Date: 2023-01-01 00:00:00
# Mood: 5
# Title: Early note
#────────────────────────────────────────
First entry.
EOF
  cat > "$JOURNAL_DIR_BASE/NB2/2023-02-01_000000.txt" <<EOF
# Date: 2023-02-01 00:00:00
# Mood: 6
# Title: Later note
#────────────────────────────────────────
Second entry.
EOF
  local -a notebooks=("NB1" "NB2")
  local -a results=()
  _scan_entries_with_filters results notebooks[@] "2023-01-15" "" "" "" "" "" ""
  [ "${#results[@]}" -eq 1 ]
  [[ "${results[0]}" == *$'\tNB2\t'* ]]
}

@test "scan filters by mood range and text query" {
  mkdir -p "$JOURNAL_DIR_BASE/NB3"
  cat > "$JOURNAL_DIR_BASE/NB3/2023-03-01_000000.txt" <<EOF
# Date: 2023-03-01 00:00:00
# Mood: 4
# Title: Low energy
#────────────────────────────────────────
Feeling tired but okay.
EOF
  cat > "$JOURNAL_DIR_BASE/NB3/2023-03-02_000000.txt" <<EOF
# Date: 2023-03-02 00:00:00
# Mood: great
# Title: Big win
#────────────────────────────────────────
Hit a milestone today.
EOF
  local -a notebooks=("NB3")
  local -a results=()
  _scan_entries_with_filters results notebooks[@] "" "" "" "3" "5" "" "tired"
  [ "${#results[@]}" -eq 1 ]
  [[ "${results[0]}" == *"Low energy"* ]]
}
