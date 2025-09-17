#!/usr/bin/env bash
# Use case: create a new entry (standalone)

usecase_new_entry() {
  init_dir
  clear
  echo -n "Mood (e.g. happy, sad, 1–10): "; read -r mood
  echo -n "Title (optional): "; read -r title

  local ts file_path header tmpfile
  ts=$(date +"${DATE_FMT}")
  header=$(entry_header_create "$mood" "$title")
  tmpfile=$(mktemp "/tmp/lamplight_new_${USER}_XXXXXX")
  echo "$header" > "$tmpfile"

  editor_open "$tmpfile" false

  if sed '1,/^#─*$/d' "$tmpfile" | grep -q '[^[:space:]]'; then
    file_path="$ACTIVE_NOTEBOOK_PATH/$ts.txt"
    mv "$tmpfile" "$file_path"
    echo -e "${GREEN}✔ Saved:${NC} $file_path"
  else
    rm -f "$tmpfile"
    echo -e "${YELLOW}✖ Entry discarded (no content).${NC}"
  fi
  press_any
}
