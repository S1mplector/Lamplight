#!/usr/bin/env bash
# Use case: create a new entry (placeholder delegating to legacy)

usecase_new_entry() {
  if declare -F new_entry >/dev/null 2>&1; then
    new_entry
  else
    echo "Not implemented yet" >&2
    return 1
  fi
}
