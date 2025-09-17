#!/usr/bin/env bash
# Live editor (placeholder for migration)

# In migration, we will move _redraw_lines and _live_editor here and expose
# a stable function like: editor_open FILE [read_only]

editor_open() {
  local file_to_edit="$1"; local is_read_only="${2:-false}"
  # Temporary: call legacy function if available
  if declare -F _live_editor >/dev/null 2>&1; then
    _live_editor "$file_to_edit" "$is_read_only"
  else
    if [[ "$is_read_only" == "true" ]]; then
      ${PAGER:-less} "$file_to_edit"
    else
      ${EDITOR:-nano} "$file_to_edit"
    fi
  fi
}
