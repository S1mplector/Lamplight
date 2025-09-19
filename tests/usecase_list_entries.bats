#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")"/.. && pwd)"
  source "$ROOT_DIR/lib/config.sh"
  source "$ROOT_DIR/lib/infrastructure/ui_tui.sh"
  source "$ROOT_DIR/lib/usecase/list_entries.sh"

  # Use an isolated temp journal directory
  TMP_JOURNAL_DIR=$(mktemp -d)
  JOURNAL_DIR_BASE="$TMP_JOURNAL_DIR"
  ACTIVE_NOTEBOOK_CONFIG_FILE="$TMP_JOURNAL_DIR/.active_notebook_test"
  DEFAULT_NOTEBOOK_NAME="TestDefault"
  # Colors off for predictable output
  NC=""; YELLOW=""; GREEN=""; CYAN=""; RED=""; MAGENTA=""
  THIN='-'
}

teardown() {
  rm -rf "$TMP_JOURNAL_DIR"
}

@test "list_entries says no entries when empty" {
  init_dir
  run bash -c 'usecase_list_entries'
  # expect non-zero due to no entries
  [ "$status" -ne 0 ]
  [[ "$output" == *"No journal entries in notebook"* ]]
}

@test "list_entries shows one entry with mood and title" {
  init_dir
  ts="2020-01-01_000000"
  mkdir -p "$ACTIVE_NOTEBOOK_PATH"
  cat > "$ACTIVE_NOTEBOOK_PATH/$ts.txt" <<EOF
# Date: 2020-01-01 00:00:00
# Mood: 7
# Title: My Title
#────────────────────────────────────────
Body
EOF
  run bash -c 'usecase_list_entries'
  [ "$status" -eq 0 ]
  [[ "$output" == *"My Title"* ]]
  [[ "$output" == *"7"* ]]
}
