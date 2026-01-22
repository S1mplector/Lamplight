#!/usr/bin/env bash
# CLI: standalone menu using clean modules

# Load settings if available
_menu_init() {
  if declare -F _load_settings >/dev/null 2>&1; then
    _load_settings
  fi
}

main_menu() {
  trap 'tput cnorm' EXIT INT TERM
  init_dir
  _menu_init
  
  # Show large ASCII clock only on the main menu
  SHOW_BIG_CLOCK=${LAMPLIGHT_SHOW_CLOCK:-1}
  local time=0
  
  while true; do
    clear
    local title_y title_x heart_y heart_x info_y
    read -r title_y title_x heart_y heart_x info_y < <(_draw_static_header)

    # Leave space for 5-row big clock (rows start at info_y)
    local menu_y=$((info_y + 7))
    tput cup "$menu_y" 0
    
    # Main menu with better organization
    echo -e "  ${WHITE}Journal${NC}"
    echo -e "    ${YELLOW}1${NC}) New entry          ${YELLOW}Q${NC}) Quick entry"
    echo -e "    ${YELLOW}2${NC}) List entries       ${YELLOW}3${NC}) Search/filter"
    echo -e "    ${YELLOW}4${NC}) Manage entries     ${YELLOW}5${NC}) Mood stats"
    echo
    echo -e "  ${WHITE}Notebooks${NC}"
    echo -e "    ${YELLOW}6${NC}) Switch notebook    ${YELLOW}7${NC}) Create notebook"
    echo -e "    ${YELLOW}8${NC}) Delete notebook"
    echo
    echo -e "  ${WHITE}Data${NC}"
    echo -e "    ${YELLOW}E${NC}) Export notebook    ${YELLOW}I${NC}) Import entries"
    echo -e "    ${YELLOW}B${NC}) Backup all         ${YELLOW}R${NC}) Restore backup"
    echo
    echo -e "  ${WHITE}Other${NC}"
    echo -e "    ${YELLOW}S${NC}) Settings           ${YELLOW}H${NC}) Help"
    echo -e "    ${YELLOW}0${NC}) Exit"

    # Calculate prompt position dynamically
    local menu_lines=14
    local prompt_y=$((menu_y + menu_lines + 1))
    tput cup "$prompt_y" 0
    echo -n "Select: "

    local choice=""
    local _old_stty
    _old_stty=$(stty -g)
    stty -echo -icanon
    while true; do
      _animate_header_frame "$title_y" "$title_x" "$heart_y" "$heart_x" "$info_y" "$time"
      if read -rsn1 -t 0 choice; then
        break
      fi
      sleep 0.1
      (( time++ ))
    done
    stty "$_old_stty"
    echo

    case "$choice" in
      # Journal
      1) usecase_new_entry ;;
      q|Q) 
        if declare -F usecase_quick_entry >/dev/null 2>&1; then
          usecase_quick_entry
        else
          usecase_new_entry
        fi
        ;;
      2)
        clear
        _draw_static_header > /dev/null
        tput cup 5 0
        usecase_list_entries_enhanced
        ;;
      3) usecase_search_entries ;;
      4) usecase_manage_entries ;;
      5) usecase_mood_stats_enhanced ;;
      
      # Notebooks
      6) usecase_switch_notebook ;;
      7) usecase_create_notebook ;;
      8) usecase_delete_notebook ;;
      
      # Data
      e|E)
        if declare -F usecase_export_notebook >/dev/null 2>&1; then
          usecase_export_notebook
        else
          echo "Export not available."; sleep 1
        fi
        ;;
      i|I)
        if declare -F usecase_import_notebook >/dev/null 2>&1; then
          usecase_import_notebook
        else
          echo "Import not available."; sleep 1
        fi
        ;;
      b|B)
        if declare -F usecase_backup_all >/dev/null 2>&1; then
          usecase_backup_all
        else
          echo "Backup not available."; sleep 1
        fi
        ;;
      r|R)
        if declare -F usecase_restore_backup >/dev/null 2>&1; then
          usecase_restore_backup
        else
          echo "Restore not available."; sleep 1
        fi
        ;;
      
      # Other
      s|S)
        if declare -F usecase_settings >/dev/null 2>&1; then
          usecase_settings
        else
          echo "Settings not available."; sleep 1
        fi
        ;;
      h|H)
        if declare -F usecase_help >/dev/null 2>&1; then
          usecase_help
        else
          _show_basic_help
        fi
        ;;
      0) break ;;
      *) ;; # Ignore invalid input silently
    esac
  done
  unset SHOW_BIG_CLOCK
}

# Enhanced list entries with preview
usecase_list_entries_enhanced() {
  init_dir
  mapfile -t files < <(ls -1 "$ACTIVE_NOTEBOOK_PATH" 2>/dev/null | sort -r)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No journal entries in notebook '$ACTIVE_NOTEBOOK_NAME' yet."
    press_any
    return 1
  fi

  printf "${MAGENTA}%-3s  %-19s  %-10s  %-30s  %s${NC}\n" "#" "Date" "Mood" "Title" "Preview"
  print_line "$THIN" 90

  local idx=1
  for f in "${files[@]}"; do
    local path="$ACTIVE_NOTEBOOK_PATH/$f"
    local d m t preview mood_color
    d=$(grep -m1 '^# Date:' "$path" | cut -d':' -f2- | xargs)
    m=$(grep -m1 '^# Mood:' "$path" | cut -d':' -f2- | xargs)
    t=$(grep -m1 '^# Title:' "$path" | cut -d':' -f2- | xargs)
    
    # Get preview if entry_preview function exists
    if declare -F entry_preview >/dev/null 2>&1; then
      preview=$(entry_preview "$path" 25)
    else
      preview=""
    fi
    
    # Get mood color
    if declare -F entry_mood_color >/dev/null 2>&1; then
      mood_color=$(entry_mood_color "$m")
    else
      mood_color="$GREEN"
      if [[ $m =~ ^[0-9]+$ ]]; then
        if (( m <= 3 )); then mood_color="$RED"; elif (( m <=6 )); then mood_color="$YELLOW"; fi
      fi
    fi

    printf "  ${YELLOW}%-3s${NC}  ${CYAN}%-19s${NC}  %s%-10s${NC}  %-30s  ${WHITE}%s${NC}\n" \
      "$idx" "${d:-?}" "$mood_color" "${m:-?}" "${t:-(no title)}" "$preview"
    ((idx++))
  done
  echo
  press_any
  return 0
}

# Enhanced mood stats with visualization
usecase_mood_stats_enhanced() {
  init_dir
  clear
  echo -e "${CYAN}Mood Statistics${NC} - $ACTIVE_NOTEBOOK_NAME"
  print_line "$THIN" 60
  
  local -A mood_counts
  local total=0
  local mood_sum=0
  local numeric_count=0
  
  mapfile -t files < <(ls -1 "$ACTIVE_NOTEBOOK_PATH"/*.txt 2>/dev/null)
  
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local mood
    mood=$(grep -m1 '^# Mood:' "$f" | cut -d':' -f2- | xargs)
    [[ -z "$mood" ]] && continue
    
    ((mood_counts["$mood"]++))
    ((total++))
    
    if [[ "$mood" =~ ^[0-9]+$ ]]; then
      ((mood_sum += mood))
      ((numeric_count++))
    fi
  done
  
  if [[ $total -eq 0 ]]; then
    echo -e "\n${YELLOW}No mood data found in this notebook.${NC}"
    press_any
    return
  fi
  
  echo -e "\n${WHITE}Distribution${NC} ($total entries)"
  print_line "$THIN" 40
  
  # Sort by count and display with bar chart
  while IFS= read -r line; do
    local count mood
    count=$(echo "$line" | awk '{print $1}')
    mood=$(echo "$line" | awk '{$1=""; print $0}' | xargs)
    
    local pct=$((count * 100 / total))
    local bar_len=$((pct / 2))
    local bar=$(printf '%*s' "$bar_len" | tr ' ' '█')
    
    local clr
    if declare -F entry_mood_color >/dev/null 2>&1; then
      clr=$(entry_mood_color "$mood")
    else
      clr="$CYAN"
    fi
    
    printf "  %s%-12s${NC} %s%-20s${NC} %3d%% (%d)\n" "$clr" "$mood" "$GREEN" "$bar" "$pct" "$count"
  done < <(for k in "${!mood_counts[@]}"; do echo "${mood_counts[$k]} $k"; done | sort -rn)
  
  # Show average if numeric moods exist
  if [[ $numeric_count -gt 0 ]]; then
    local avg=$((mood_sum * 10 / numeric_count))
    local avg_int=$((avg / 10))
    local avg_dec=$((avg % 10))
    echo
    echo -e "${WHITE}Average mood (numeric):${NC} ${GREEN}${avg_int}.${avg_dec}${NC} / 10"
  fi
  
  echo
  press_any
}

_show_basic_help() {
  clear
  echo -e "${CYAN}Lamplight Help${NC}"
  print_line "$THIN" 50
  echo -e "\n${WHITE}Keys:${NC} Number keys to select, 0 to go back"
  echo -e "${WHITE}Editor:${NC} Ctrl+D to save, Q to quit (read-only)"
  echo -e "${WHITE}Data:${NC} Stored in ~/JournalEntries/"
  echo
  press_any
}

lamplight_main() {
  main_menu
}
