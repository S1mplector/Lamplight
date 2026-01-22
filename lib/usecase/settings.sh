#!/usr/bin/env bash
# Use cases: settings and help system

SETTINGS_FILE="${HOME}/.lamplight_settings"

# Load settings from file
_load_settings() {
  if [[ -f "$SETTINGS_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SETTINGS_FILE"
  fi
  # Defaults
  : "${LAMPLIGHT_SHOW_CLOCK:=1}"
  : "${LAMPLIGHT_DATE_FORMAT:=%Y-%m-%d %H:%M:%S}"
  : "${LAMPLIGHT_DEFAULT_MOOD_TYPE:=numeric}"
  : "${LAMPLIGHT_CONFIRM_DELETE:=1}"
  : "${LAMPLIGHT_AUTO_SAVE_INTERVAL:=0}"
  : "${LAMPLIGHT_THEME:=warm}"
}

# Save settings to file
_save_settings() {
  cat > "$SETTINGS_FILE" <<EOF
# Lamplight Settings
LAMPLIGHT_SHOW_CLOCK=$LAMPLIGHT_SHOW_CLOCK
LAMPLIGHT_DATE_FORMAT="$LAMPLIGHT_DATE_FORMAT"
LAMPLIGHT_DEFAULT_MOOD_TYPE="$LAMPLIGHT_DEFAULT_MOOD_TYPE"
LAMPLIGHT_CONFIRM_DELETE=$LAMPLIGHT_CONFIRM_DELETE
LAMPLIGHT_AUTO_SAVE_INTERVAL=$LAMPLIGHT_AUTO_SAVE_INTERVAL
LAMPLIGHT_THEME="$LAMPLIGHT_THEME"
EOF
}

usecase_settings() {
  _load_settings
  
  while true; do
    clear
    echo -e "${CYAN}⚙ Settings${NC}"
    print_line "$THIN" 60
    
    local clock_status="ON"
    [[ "$LAMPLIGHT_SHOW_CLOCK" == "0" ]] && clock_status="OFF"
    
    local confirm_status="ON"
    [[ "$LAMPLIGHT_CONFIRM_DELETE" == "0" ]] && confirm_status="OFF"
    
    echo -e "\n${WHITE}Display${NC}"
    echo -e "  ${YELLOW}1${NC}) Big ASCII clock: ${GREEN}$clock_status${NC}"
    echo -e "  ${YELLOW}2${NC}) Theme: ${GREEN}$LAMPLIGHT_THEME${NC}"
    
    echo -e "\n${WHITE}Behavior${NC}"
    echo -e "  ${YELLOW}3${NC}) Default mood type: ${GREEN}$LAMPLIGHT_DEFAULT_MOOD_TYPE${NC}"
    echo -e "  ${YELLOW}4${NC}) Confirm before delete: ${GREEN}$confirm_status${NC}"
    echo -e "  ${YELLOW}5${NC}) Date format: ${GREEN}$LAMPLIGHT_DATE_FORMAT${NC}"
    
    echo -e "\n${WHITE}Data${NC}"
    echo -e "  ${YELLOW}6${NC}) Journal directory: ${CYAN}$JOURNAL_DIR_BASE${NC}"
    echo -e "  ${YELLOW}7${NC}) View statistics"
    
    echo -e "\n  ${YELLOW}0${NC}) Back to main menu"
    
    echo -n "Select option: "; read -rsn1 choice
    echo
    
    case "$choice" in
      1)
        if [[ "$LAMPLIGHT_SHOW_CLOCK" == "1" ]]; then
          LAMPLIGHT_SHOW_CLOCK=0
          SHOW_BIG_CLOCK=0
        else
          LAMPLIGHT_SHOW_CLOCK=1
          SHOW_BIG_CLOCK=1
        fi
        _save_settings
        ;;
      2)
        echo -e "\n${WHITE}Select theme:${NC}"
        echo -e "  ${YELLOW}1${NC}) warm (orange/yellow)"
        echo -e "  ${YELLOW}2${NC}) cool (blue/cyan)"
        echo -e "  ${YELLOW}3${NC}) forest (green)"
        echo -e "  ${YELLOW}4${NC}) twilight (purple/pink)"
        echo -n "Select: "; read -r theme_choice
        case "$theme_choice" in
          1) LAMPLIGHT_THEME="warm" ;;
          2) LAMPLIGHT_THEME="cool" ;;
          3) LAMPLIGHT_THEME="forest" ;;
          4) LAMPLIGHT_THEME="twilight" ;;
        esac
        _apply_theme
        _save_settings
        ;;
      3)
        echo -e "\n${WHITE}Default mood input:${NC}"
        echo -e "  ${YELLOW}1${NC}) numeric (1-10 scale)"
        echo -e "  ${YELLOW}2${NC}) text (happy, sad, etc.)"
        echo -n "Select: "; read -r mood_choice
        case "$mood_choice" in
          1) LAMPLIGHT_DEFAULT_MOOD_TYPE="numeric" ;;
          2) LAMPLIGHT_DEFAULT_MOOD_TYPE="text" ;;
        esac
        _save_settings
        ;;
      4)
        if [[ "$LAMPLIGHT_CONFIRM_DELETE" == "1" ]]; then
          LAMPLIGHT_CONFIRM_DELETE=0
        else
          LAMPLIGHT_CONFIRM_DELETE=1
        fi
        _save_settings
        ;;
      5)
        echo -e "\n${WHITE}Date format presets:${NC}"
        echo -e "  ${YELLOW}1${NC}) %Y-%m-%d %H:%M:%S (2024-01-15 14:30:00)"
        echo -e "  ${YELLOW}2${NC}) %d/%m/%Y %H:%M (15/01/2024 14:30)"
        echo -e "  ${YELLOW}3${NC}) %B %d, %Y (January 15, 2024)"
        echo -e "  ${YELLOW}4${NC}) Custom"
        echo -n "Select: "; read -r fmt_choice
        case "$fmt_choice" in
          1) LAMPLIGHT_DATE_FORMAT="%Y-%m-%d %H:%M:%S" ;;
          2) LAMPLIGHT_DATE_FORMAT="%d/%m/%Y %H:%M" ;;
          3) LAMPLIGHT_DATE_FORMAT="%B %d, %Y" ;;
          4)
            echo -n "Enter custom format: "; read -r custom_fmt
            [[ -n "$custom_fmt" ]] && LAMPLIGHT_DATE_FORMAT="$custom_fmt"
            ;;
        esac
        _save_settings
        ;;
      6)
        echo -e "\n${WHITE}Current journal directory:${NC} $JOURNAL_DIR_BASE"
        echo -e "${YELLOW}Note:${NC} Changing this requires manual data migration."
        press_any
        ;;
      7)
        _show_statistics
        ;;
      0|q|Q)
        return
        ;;
    esac
  done
}

_apply_theme() {
  case "$LAMPLIGHT_THEME" in
    warm)
      # Keep default warm orange/yellow
      ;;
    cool)
      CYAN=$'\e[36m'
      YELLOW=$'\e[94m'  # Bright blue
      ;;
    forest)
      CYAN=$'\e[32m'
      YELLOW=$'\e[92m'  # Bright green
      ;;
    twilight)
      CYAN=$'\e[35m'
      YELLOW=$'\e[95m'  # Bright magenta
      ;;
  esac
}

_show_statistics() {
  clear
  echo -e "${CYAN}📊 Journal Statistics${NC}"
  print_line "$THIN" 60
  
  local total_entries=0
  local total_words=0
  local total_notebooks=0
  local oldest_entry=""
  local newest_entry=""
  
  mapfile -t notebooks < <(notebook_list_all)
  total_notebooks=${#notebooks[@]}
  
  for nb in "${notebooks[@]}"; do
    local nb_path="$JOURNAL_DIR_BASE/$nb"
    mapfile -t files < <(ls -1 "$nb_path"/*.txt 2>/dev/null)
    total_entries=$((total_entries + ${#files[@]}))
    
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || continue
      local words; words=$(wc -w < "$f")
      total_words=$((total_words + words))
      
      local entry_date; entry_date=$(grep -m1 '^# Date:' "$f" | cut -d':' -f2- | xargs)
      if [[ -z "$oldest_entry" ]] || [[ "$entry_date" < "$oldest_entry" ]]; then
        oldest_entry="$entry_date"
      fi
      if [[ -z "$newest_entry" ]] || [[ "$entry_date" > "$newest_entry" ]]; then
        newest_entry="$entry_date"
      fi
    done
  done
  
  echo -e "\n${WHITE}Overview${NC}"
  echo -e "  Total notebooks:    ${GREEN}$total_notebooks${NC}"
  echo -e "  Total entries:      ${GREEN}$total_entries${NC}"
  echo -e "  Total words:        ${GREEN}$total_words${NC}"
  
  if [[ $total_entries -gt 0 ]]; then
    local avg_words=$((total_words / total_entries))
    echo -e "  Avg words/entry:    ${GREEN}$avg_words${NC}"
    echo -e "\n${WHITE}Timeline${NC}"
    echo -e "  First entry:        ${CYAN}$oldest_entry${NC}"
    echo -e "  Latest entry:       ${CYAN}$newest_entry${NC}"
  fi
  
  echo -e "\n${WHITE}Storage${NC}"
  local storage_size; storage_size=$(du -sh "$JOURNAL_DIR_BASE" 2>/dev/null | cut -f1)
  echo -e "  Data size:          ${GREEN}$storage_size${NC}"
  echo -e "  Location:           ${CYAN}$JOURNAL_DIR_BASE${NC}"
  
  echo
  press_any
}

usecase_help() {
  clear
  echo -e "${CYAN}❓ Lamplight Help${NC}"
  print_line "$THIN" 70
  
  echo -e "\n${WHITE}Quick Start${NC}"
  echo -e "  Press ${YELLOW}1${NC} to create a new journal entry"
  echo -e "  Each entry has a date, mood, optional title, and your content"
  
  echo -e "\n${WHITE}Navigation${NC}"
  echo -e "  ${YELLOW}Number keys${NC}    Select menu options"
  echo -e "  ${YELLOW}0 or Q${NC}         Go back / Exit"
  echo -e "  ${YELLOW}Arrow keys${NC}     Navigate in editor and lists"
  
  echo -e "\n${WHITE}Editor Controls${NC}"
  echo -e "  ${YELLOW}Arrow keys${NC}     Move cursor"
  echo -e "  ${YELLOW}Enter${NC}          New line"
  echo -e "  ${YELLOW}Backspace${NC}      Delete character"
  echo -e "  ${YELLOW}Ctrl+D${NC}         Save and exit"
  echo -e "  ${YELLOW}Q${NC}              Quit (in read-only mode)"
  
  echo -e "\n${WHITE}Mood Tracking${NC}"
  echo -e "  Enter moods as numbers (1-10) or words (happy, sad, etc.)"
  echo -e "  View mood statistics from the main menu"
  echo -e "  Search entries by mood range (e.g., 7-10)"
  
  echo -e "\n${WHITE}Notebooks${NC}"
  echo -e "  Organize entries into separate notebooks"
  echo -e "  Switch between notebooks to keep topics separate"
  echo -e "  Search across all notebooks or just the current one"
  
  echo -e "\n${WHITE}Data & Backup${NC}"
  echo -e "  Export notebooks to JSON, Markdown, or plain text"
  echo -e "  Create full backups of all data"
  echo -e "  Data stored in: ${CYAN}~/JournalEntries/${NC}"
  
  echo
  press_any
}

# Quick entry - minimal prompts for fast journaling
usecase_quick_entry() {
  init_dir
  clear
  
  local ts file_path header tmpfile
  ts=$(date +"${DATE_FMT}")
  
  _load_settings
  local mood_prompt="Mood (1-10): "
  [[ "$LAMPLIGHT_DEFAULT_MOOD_TYPE" == "text" ]] && mood_prompt="Mood: "
  
  echo -e "${CYAN}⚡ Quick Entry${NC}"
  print_line "$THIN" 40
  echo -n "$mood_prompt"; read -r mood
  
  header=$(entry_header_create "$mood" "")
  tmpfile=$(mktemp "/tmp/lamplight_quick_${USER}_XXXXXX")
  echo "$header" > "$tmpfile"
  
  editor_open "$tmpfile" false
  
  if sed '1,/^#─*$/d' "$tmpfile" | grep -q '[^[:space:]]'; then
    file_path="$ACTIVE_NOTEBOOK_PATH/$ts.txt"
    mv "$tmpfile" "$file_path"
    echo -e "${GREEN}✔ Saved${NC}"
  else
    rm -f "$tmpfile"
    echo -e "${YELLOW}✖ Discarded${NC}"
  fi
  sleep 0.5
}
