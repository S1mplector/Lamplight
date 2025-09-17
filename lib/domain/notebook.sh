#!/usr/bin/env bash
# Domain: Notebook helpers (paths, listing)

notebook_list_all() {
  find "$JOURNAL_DIR_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}
