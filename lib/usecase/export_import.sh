#!/usr/bin/env bash
# Use cases: export, import, and backup functionality

# Export a notebook to a single file (JSON or plain text bundle)
usecase_export_notebook() {
  init_dir
  clear
  echo -e "${CYAN}Export Notebook${NC}"
  print_line "$THIN" 70
  
  echo -e "\n${WHITE}Available Notebooks:${NC}"
  notebooks_list || { press_any; return; }
  
  echo -n "Enter notebook # to export (or 0 to cancel): "; read -r choice
  if [[ "$choice" == "0" ]]; then echo "Export cancelled."; press_any; return; fi
  
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#_LISTED_NOTEBOOKS[@]} ]]; then
    echo -e "${RED}Invalid selection.${NC}"; press_any; return
  fi
  
  local notebook_name="${_LISTED_NOTEBOOKS[$((choice-1))]}"
  local notebook_path="$JOURNAL_DIR_BASE/$notebook_name"
  
  echo -e "\n${WHITE}Export format:${NC}"
  echo -e "  ${YELLOW}1${NC}) JSON (structured, for backup/import)"
  echo -e "  ${YELLOW}2${NC}) Markdown (readable, for sharing)"
  echo -e "  ${YELLOW}3${NC}) Plain text bundle"
  echo -n "Select format: "; read -r format_choice
  
  local export_dir="${HOME}/LamplightExports"
  mkdir -p "$export_dir"
  local timestamp; timestamp=$(date +"%Y%m%d_%H%M%S")
  local export_file
  
  case "$format_choice" in
    1) # JSON export
      export_file="${export_dir}/${notebook_name}_${timestamp}.json"
      _export_to_json "$notebook_name" "$notebook_path" "$export_file"
      ;;
    2) # Markdown export
      export_file="${export_dir}/${notebook_name}_${timestamp}.md"
      _export_to_markdown "$notebook_name" "$notebook_path" "$export_file"
      ;;
    3) # Plain text bundle
      export_file="${export_dir}/${notebook_name}_${timestamp}.txt"
      _export_to_text "$notebook_name" "$notebook_path" "$export_file"
      ;;
    *)
      echo -e "${RED}Invalid format choice.${NC}"; press_any; return
      ;;
  esac
  
  if [[ -f "$export_file" ]]; then
    local size; size=$(du -h "$export_file" | cut -f1)
    echo -e "\n${GREEN}✔ Export successful!${NC}"
    echo -e "  File: ${CYAN}$export_file${NC}"
    echo -e "  Size: ${WHITE}$size${NC}"
  else
    echo -e "${RED}✖ Export failed.${NC}"
  fi
  press_any
}

_export_to_json() {
  local notebook_name="$1" notebook_path="$2" export_file="$3"
  
  echo "{" > "$export_file"
  echo "  \"notebook\": \"$notebook_name\"," >> "$export_file"
  echo "  \"exported\": \"$(date -Iseconds)\"," >> "$export_file"
  echo "  \"entries\": [" >> "$export_file"
  
  local first=1
  mapfile -t files < <(ls -1 "$notebook_path"/*.txt 2>/dev/null | sort)
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    
    local date mood title body
    date=$(grep -m1 '^# Date:' "$f" | cut -d':' -f2- | xargs)
    mood=$(grep -m1 '^# Mood:' "$f" | cut -d':' -f2- | xargs)
    title=$(grep -m1 '^# Title:' "$f" | cut -d':' -f2- | xargs)
    body=$(sed '1,/^#─*$/d' "$f" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' '\\' | sed 's/\\/\\n/g')
    
    [[ $first -eq 1 ]] && first=0 || echo "    ," >> "$export_file"
    
    cat >> "$export_file" <<EOF
    {
      "filename": "$(basename "$f")",
      "date": "$date",
      "mood": "$mood",
      "title": "$title",
      "body": "$body"
    }
EOF
  done
  
  echo "  ]" >> "$export_file"
  echo "}" >> "$export_file"
}

_export_to_markdown() {
  local notebook_name="$1" notebook_path="$2" export_file="$3"
  
  {
    echo "# $notebook_name"
    echo ""
    echo "_Exported from Lamplight on $(date '+%Y-%m-%d %H:%M:%S')_"
    echo ""
    echo "---"
    echo ""
    
    mapfile -t files < <(ls -1 "$notebook_path"/*.txt 2>/dev/null | sort -r)
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || continue
      
      local date mood title
      date=$(grep -m1 '^# Date:' "$f" | cut -d':' -f2- | xargs)
      mood=$(grep -m1 '^# Mood:' "$f" | cut -d':' -f2- | xargs)
      title=$(grep -m1 '^# Title:' "$f" | cut -d':' -f2- | xargs)
      
      echo "## ${title:-Untitled Entry}"
      echo ""
      echo "**Date:** $date  "
      echo "**Mood:** $mood"
      echo ""
      sed '1,/^#─*$/d' "$f"
      echo ""
      echo "---"
      echo ""
    done
  } > "$export_file"
}

_export_to_text() {
  local notebook_name="$1" notebook_path="$2" export_file="$3"
  
  {
    echo "========================================"
    echo "  LAMPLIGHT EXPORT: $notebook_name"
    echo "  Exported: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo ""
    
    mapfile -t files < <(ls -1 "$notebook_path"/*.txt 2>/dev/null | sort -r)
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || continue
      echo "----------------------------------------"
      cat "$f"
      echo ""
    done
  } > "$export_file"
}

# Import entries from a JSON export
usecase_import_notebook() {
  init_dir
  clear
  echo -e "${CYAN}Import Entries${NC}"
  print_line "$THIN" 70
  
  local import_dir="${HOME}/LamplightExports"
  
  if [[ ! -d "$import_dir" ]]; then
    echo -e "${YELLOW}No exports directory found at: $import_dir${NC}"
    echo -n "Enter path to import file: "; read -r import_file
  else
    echo -e "\n${WHITE}Available export files:${NC}"
    mapfile -t exports < <(find "$import_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort -r)
    
    if [[ ${#exports[@]} -eq 0 ]]; then
      echo -e "${YELLOW}No JSON exports found in $import_dir${NC}"
      echo -n "Enter path to import file: "; read -r import_file
    else
      local idx=1
      for f in "${exports[@]}"; do
        local fname; fname=$(basename "$f")
        local fsize; fsize=$(du -h "$f" | cut -f1)
        printf "  ${YELLOW}%d${NC}) %s (${WHITE}%s${NC})\n" "$idx" "$fname" "$fsize"
        ((idx++))
      done
      
      echo -n "Select file # (or enter path, 0 to cancel): "; read -r choice
      
      if [[ "$choice" == "0" ]]; then echo "Import cancelled."; press_any; return; fi
      
      if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#exports[@]} ]]; then
        import_file="${exports[$((choice-1))]}"
      else
        import_file="$choice"
      fi
    fi
  fi
  
  if [[ ! -f "$import_file" ]]; then
    echo -e "${RED}File not found: $import_file${NC}"; press_any; return
  fi
  
  if [[ ! "$import_file" =~ \.json$ ]]; then
    echo -e "${RED}Only JSON imports are supported.${NC}"; press_any; return
  fi
  
  # Parse notebook name from JSON
  local source_notebook
  source_notebook=$(grep -o '"notebook"[[:space:]]*:[[:space:]]*"[^"]*"' "$import_file" | head -1 | sed 's/.*:.*"\([^"]*\)".*/\1/')
  
  echo -e "\n${WHITE}Import destination:${NC}"
  echo -e "  ${YELLOW}1${NC}) Current notebook (${GREEN}$ACTIVE_NOTEBOOK_NAME${NC})"
  echo -e "  ${YELLOW}2${NC}) Original notebook (${CYAN}$source_notebook${NC})"
  echo -e "  ${YELLOW}3${NC}) New notebook"
  echo -n "Select: "; read -r dest_choice
  
  local dest_notebook dest_path
  case "$dest_choice" in
    1) dest_notebook="$ACTIVE_NOTEBOOK_NAME" ;;
    2) dest_notebook="$source_notebook" ;;
    3)
      echo -n "Enter new notebook name: "; read -r dest_notebook
      if [[ -z "$dest_notebook" ]]; then
        echo -e "${RED}Name cannot be empty.${NC}"; press_any; return
      fi
      ;;
    *) echo -e "${RED}Invalid choice.${NC}"; press_any; return ;;
  esac
  
  dest_path="$JOURNAL_DIR_BASE/$dest_notebook"
  mkdir -p "$dest_path"
  
  # Simple JSON parsing for import (works for our export format)
  local count=0
  local in_entry=0 filename="" date="" mood="" title="" body=""
  
  while IFS= read -r line; do
    if [[ "$line" =~ \"filename\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      filename="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"date\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      date="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"mood\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      mood="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"title\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      title="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ \"body\"[[:space:]]*:[[:space:]]*\"(.*)\" ]]; then
      body="${BASH_REMATCH[1]}"
      body=$(echo -e "$body" | sed 's/\\n/\n/g')
    elif [[ "$line" =~ \} ]]; then
      if [[ -n "$filename" ]]; then
        local entry_file="$dest_path/$filename"
        if [[ -f "$entry_file" ]]; then
          entry_file="${entry_file%.txt}_imported.txt"
        fi
        {
          echo "# Date: $date"
          echo "# Mood: $mood"
          echo "# Title: $title"
          echo "#────────────────────────────────────────"
          echo -e "$body"
        } > "$entry_file"
        ((count++))
        filename="" date="" mood="" title="" body=""
      fi
    fi
  done < "$import_file"
  
  echo -e "\n${GREEN}✔ Imported $count entries to notebook '$dest_notebook'${NC}"
  press_any
}

# Create a full backup of all notebooks
usecase_backup_all() {
  init_dir
  clear
  echo -e "${CYAN}Backup All Data${NC}"
  print_line "$THIN" 70
  
  local backup_dir="${HOME}/LamplightBackups"
  mkdir -p "$backup_dir"
  
  local timestamp; timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_file="${backup_dir}/lamplight_backup_${timestamp}.tar.gz"
  
  echo -e "\n${WHITE}Creating backup of all notebooks...${NC}"
  
  if tar -czf "$backup_file" -C "$JOURNAL_DIR_BASE" . 2>/dev/null; then
    local size; size=$(du -h "$backup_file" | cut -f1)
    local count; count=$(find "$JOURNAL_DIR_BASE" -type f -name "*.txt" | wc -l)
    local nb_count; nb_count=$(find "$JOURNAL_DIR_BASE" -mindepth 1 -maxdepth 1 -type d | wc -l)
    
    echo -e "\n${GREEN}✔ Backup successful!${NC}"
    echo -e "  File: ${CYAN}$backup_file${NC}"
    echo -e "  Size: ${WHITE}$size${NC}"
    echo -e "  Contains: ${WHITE}$nb_count notebooks${NC}, ${WHITE}$count entries${NC}"
  else
    echo -e "${RED}✖ Backup failed.${NC}"
  fi
  press_any
}

# Restore from a backup
usecase_restore_backup() {
  init_dir
  clear
  echo -e "${CYAN}Restore from Backup${NC}"
  print_line "$THIN" 70
  
  local backup_dir="${HOME}/LamplightBackups"
  
  if [[ ! -d "$backup_dir" ]]; then
    echo -e "${RED}No backups directory found at: $backup_dir${NC}"
    press_any; return
  fi
  
  mapfile -t backups < <(find "$backup_dir" -maxdepth 1 -name "*.tar.gz" -type f 2>/dev/null | sort -r)
  
  if [[ ${#backups[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No backups found.${NC}"
    press_any; return
  fi
  
  echo -e "\n${WHITE}Available backups:${NC}"
  local idx=1
  for f in "${backups[@]}"; do
    local fname; fname=$(basename "$f")
    local fsize; fsize=$(du -h "$f" | cut -f1)
    local fdate; fdate=$(stat -c %y "$f" 2>/dev/null | cut -d'.' -f1)
    printf "  ${YELLOW}%d${NC}) %s (${WHITE}%s${NC}) - %s\n" "$idx" "$fname" "$fsize" "$fdate"
    ((idx++))
  done
  
  echo -n "Select backup # to restore (0 to cancel): "; read -r choice
  
  if [[ "$choice" == "0" ]]; then echo "Restore cancelled."; press_any; return; fi
  
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#backups[@]} ]]; then
    echo -e "${RED}Invalid selection.${NC}"; press_any; return
  fi
  
  local backup_file="${backups[$((choice-1))]}"
  
  echo -e "\n${RED}⚠ WARNING: This will restore notebooks from the backup.${NC}"
  echo -e "${WHITE}Existing entries with the same name will be overwritten.${NC}"
  echo -n "Continue? (y/N): "; read -r confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."; press_any; return
  fi
  
  if tar -xzf "$backup_file" -C "$JOURNAL_DIR_BASE" 2>/dev/null; then
    echo -e "\n${GREEN}✔ Restore successful!${NC}"
    init_dir  # Re-initialize to pick up any changes
  else
    echo -e "${RED}✖ Restore failed.${NC}"
  fi
  press_any
}
