#!/usr/bin/env bash
# Use case: list entries (placeholder)

usecase_list_entries() {
  if declare -F list_entries >/dev/null 2>&1; then
    list_entries
  else
    echo "Not implemented yet" >&2
    return 1
  fi
}
