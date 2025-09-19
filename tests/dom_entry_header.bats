#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")"/.. && pwd)"
  source "$ROOT_DIR/lib/config.sh"
  source "$ROOT_DIR/lib/domain/entry.sh"
}

@test "entry_header_create emits date, mood, title and delimiter" {
  mood="happy"; title="Test Title"
  out=$(entry_header_create "$mood" "$title")
  [[ "$out" == *"# Date:"* ]]
  [[ "$out" == *"# Mood: happy"* ]]
  [[ "$out" == *"# Title: Test Title"* ]]
  # delimiter uses heavy line drawing with dashes
  [[ "$out" == *"#────────────────────────"* ]]
}
