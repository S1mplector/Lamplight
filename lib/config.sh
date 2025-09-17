#!/usr/bin/env bash
# Config and constants for Lamplight

# Base directories and defaults
: "${JOURNAL_DIR_BASE:="$HOME/JournalEntries"}"
: "${DATE_FMT:="%Y-%m-%d_%H%M%S"}"
: "${ACTIVE_NOTEBOOK_NAME:=""}"
: "${ACTIVE_NOTEBOOK_PATH:=""}"
: "${ACTIVE_NOTEBOOK_CONFIG_FILE:="$HOME/.simjournal_active_notebook"}"
: "${DEFAULT_NOTEBOOK_NAME:="Default"}"

# Colours
PINK=$'\e[95m'
BOLD_PINK=$'\e[1;95m'
NC=$'\e[0m'
YELLOW=$'\e[33m'
GREEN=$'\e[32m'
CYAN=$'\e[36m'
RED=$'\e[31m'
MAGENTA=$'\e[35m'

THIN='-'
THICK='='

init_dir() {
  mkdir -p "$JOURNAL_DIR_BASE"

  local found_active_from_file=0
  if [[ -f "$ACTIVE_NOTEBOOK_CONFIG_FILE" ]]; then
    local saved_notebook_name
    saved_notebook_name=$(<"$ACTIVE_NOTEBOOK_CONFIG_FILE")
    if [[ -n "$saved_notebook_name" && -d "$JOURNAL_DIR_BASE/$saved_notebook_name" ]]; then
      ACTIVE_NOTEBOOK_NAME="$saved_notebook_name"
      found_active_from_file=1
    fi
  fi

  if (( found_active_from_file == 0 )); then
    if [[ -d "$JOURNAL_DIR_BASE/$DEFAULT_NOTEBOOK_NAME" ]]; then
      ACTIVE_NOTEBOOK_NAME="$DEFAULT_NOTEBOOK_NAME"
    else
      mapfile -t existing_notebooks < <(find "$JOURNAL_DIR_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
      if [[ ${#existing_notebooks[@]} -gt 0 ]]; then
        ACTIVE_NOTEBOOK_NAME="${existing_notebooks[0]}"
      else
        ACTIVE_NOTEBOOK_NAME="$DEFAULT_NOTEBOOK_NAME"
      fi
    fi
  fi

  ACTIVE_NOTEBOOK_PATH="$JOURNAL_DIR_BASE/$ACTIVE_NOTEBOOK_NAME"
  mkdir -p "$ACTIVE_NOTEBOOK_PATH"
  echo "$ACTIVE_NOTEBOOK_NAME" > "$ACTIVE_NOTEBOOK_CONFIG_FILE"
}
