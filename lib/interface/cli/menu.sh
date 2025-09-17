#!/usr/bin/env bash
# CLI shim that temporarily delegates to legacy journal.sh while we migrate.

lamplight_main() {
  local ROOT_DIR
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../../.. && pwd)"

  # Prefer the new stack if/when implemented
  if declare -F main_menu >/dev/null 2>&1; then
    # If a new main_menu exists in modules, run it
    init_dir
    main_menu
    return
  fi

  # Fallback to legacy
  if [[ -f "$ROOT_DIR/journal.sh" ]]; then
    exec "$ROOT_DIR/journal.sh"
  else
    echo "Lamplight: CLI not yet implemented and legacy journal.sh not found." >&2
    return 1
  fi
}
