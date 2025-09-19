#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────
#   SimJournal – lightweight Bash journal & mood tracker (v3)
#   • Stores entries under ~/JournalEntries/
#   • Features: new entry, edit/view, mood stats, notebook management
#   • Live, animated, flicker-free UI
# ------------------------------------------------------------------

# ─── Configuration ────────────────────────────────────────────────
JOURNAL_DIR_BASE="$HOME/JournalEntries"
DATE_FMT="%Y-%m-%d_%H%M%S"          # filename timestamp
ACTIVE_NOTEBOOK_NAME=""
ACTIVE_NOTEBOOK_PATH=""
ACTIVE_NOTEBOOK_CONFIG_FILE="$HOME/.simjournal_active_notebook"
DEFAULT_NOTEBOOK_NAME="Default"

# ─── Colours ─────────────────────────────────────────────────────
PINK=$'\e[95m'; BOLD_PINK=$'\e[1;95m'; NC=$'\e[0m'; YELLOW=$'\e[33m'; GREEN=$'\e[32m'; CYAN=$'\e[36m'; RED=$'\e[31m'; MAGENTA=$'\e[35m'
# Line characters
THIN='-'; THICK='='

# ─── Helpers ─────────────────────────────────────────────────────
init_dir() {
    mkdir -p "$JOURNAL_DIR_BASE" # Ensure base journal directory exists

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
        # Check if default notebook directory exists
        if [[ -d "$JOURNAL_DIR_BASE/$DEFAULT_NOTEBOOK_NAME" ]]; then
            ACTIVE_NOTEBOOK_NAME="$DEFAULT_NOTEBOOK_NAME"
        else
            # If no config and default doesn't exist, try to find any other notebook
            mapfile -t existing_notebooks < <(find "$JOURNAL_DIR_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
            if [[ ${#existing_notebooks[@]} -gt 0 ]]; then
                ACTIVE_NOTEBOOK_NAME="${existing_notebooks[0]}"
            else
                # No notebooks exist, create and use the default one
                ACTIVE_NOTEBOOK_NAME="$DEFAULT_NOTEBOOK_NAME"
            fi
        fi
    fi
    
    ACTIVE_NOTEBOOK_PATH="$JOURNAL_DIR_BASE/$ACTIVE_NOTEBOOK_NAME"
    mkdir -p "$ACTIVE_NOTEBOOK_PATH"
    echo "$ACTIVE_NOTEBOOK_NAME" > "$ACTIVE_NOTEBOOK_CONFIG_FILE"
}

press_any() { spinner_wait 15; }

print_line() { local ch="$1"; local len=${2:-60}; printf "${CYAN}%*s${NC}\n" "$len" | tr ' ' "$ch"; }

spinner_wait() {
  local loops=${1:-15}
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0
  for ((c=0; c<loops; c++)); do
    printf "\r${CYAN}%s Returning to menu...${NC}" "${frames[i]}"
    sleep 0.1
    (( i = (i + 1) % 10 ))
  done
  printf "\r\033[K"
}

_draw_static_header() {
    # Define layout variables first so they are in scope for both drawing and coordinate output
    local title_text=" ~ SimJournal ~ "
    local title_y=1
    local title_x=2
    local border top_bottom
    border=$(printf "%*s" "${#title_text}" "" | tr ' ' '-')
    top_bottom="+${border}+"

    {   # All drawing goes to stderr; stdout will only contain coordinates
        tput cup 0 0; tput ed
        # Draw the static parts of the header
        tput cup $title_y $title_x; printf "%s" "$top_bottom"
        tput cup $((title_y + 1)) $title_x; printf "|%*s|" "${#title_text}" ""
        tput cup $((title_y + 2)) $title_x; printf "%s" "$top_bottom"
    } >&2
    
    # Output: coordinates for the dynamic elements (stdout only)
    local title_print_y=$((title_y + 1))
    local title_print_x=$((title_x + 1))
    local heart_y=$((title_y + 1))
    local heart_x=$(( title_x + ${#title_text} + 3 ))
    local info_y=$((title_y + 3))
    echo "$title_print_y $title_print_x $heart_y $heart_x $info_y"
}

_animate_header_frame() {
    local title_y="$1" title_x="$2" heart_y="$3" heart_x="$4" info_y="$5" time="$6"
    
    tput sc 
    tput civis 

    local title="~ SimJournal ~"
    # A pure purple-to-pink palette with no "off" colors.
    local colors=(163 164 165 201 199 198 199 201 165 164)

    local title_output=""
    for i in $(seq 0 $((${#title}-1))); do
        local color_idx=$(( (i + time) % ${#colors[@]} ))
        local char_color_code=${colors[$color_idx]}
        title_output+="\e[38;5;${char_color_code}m${title:$i:1}"
    done
    tput cup "$title_y" "$title_x"; printf "|${title_output}\e[0m|"

    # Heart animation removed by request; no drawing at heart coordinates.

    tput cup "$info_y" 0; tput el
    printf "${MAGENTA}Notebook: ${YELLOW}%s${NC}   ${MAGENTA}%s${NC}" "$ACTIVE_NOTEBOOK_NAME" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    tput rc 
    tput cnorm
}

# ─── Live Editor ────────────────────────────────────────────────
_redraw_lines() {
    local -n _lines="$1"
    local _cur_line="$2"
    local _cur_col="$3"
    
    local term_height; term_height=$(tput lines)
    local editor_height=$((term_height - 6)) 

    local output; output="$(tput civis)"
    for i in $(seq 0 $((editor_height - 1))); do
        output+="$(tput cup $((3 + i)) 0)$(tput el)"
        # Portable array element existence check (works on Bash 3.2 on macOS)
        if [[ -n "${_lines[i]+_}" ]]; then
            output+="  ${_lines[i]}"
        fi
    done
    output+="$(tput cnorm)"
    output+="$(tput cup $((3 + _cur_line)) $((2 + _cur_col)))"
    printf "%s" "$output"
}

_live_editor() {
    local file_to_edit="$1"
    local is_read_only="$2"

    local header_info
    header_info=$(sed -n '1,/^#─*$/p' "$file_to_edit")
    mapfile -t lines < <(sed '1,/^#─*$/d' "$file_to_edit")
    if [[ ${#lines[@]} -eq 0 ]]; then
        lines=("")
    fi

    local cur_line=0
    local cur_col=0
    local header_text_for_display
    header_text_for_display=$(echo "$header_info" | sed 's/# //g' | sed 's/#─*/─/g')

    clear
    echo "$header_text_for_display"
    print_line "/" 70
    
    local term_height; term_height=$(tput lines)
    local editor_height=$((term_height - 6))
    tput cup $((4 + editor_height)) 0
    print_line "/" 70
    if [[ "$is_read_only" == "true" ]]; then
        printf " ${YELLOW}Arrow keys${NC} Move | ${YELLOW}Q${NC} to Quit"
    else
        printf " ${YELLOW}Arrow keys${NC} Move | ${YELLOW}Enter${NC} Newline | ${YELLOW}Backspace${NC} Delete | ${YELLOW}Ctrl+D${NC} Save & Finish"
    fi
    tput ed

    local old_stty
    old_stty=$(stty -g)
    trap 'stty "$old_stty"' EXIT 
    stty -echo -icanon

    while true; do
        _redraw_lines lines "$cur_line" "$cur_col"

        IFS= read -rsn1 key
        if [[ "$is_read_only" == "true" ]]; then
            if [[ "$key" == "q" ]]; then break; fi
             if [[ "$key" == $'\e' ]]; then
                # macOS Bash 3.2: use non-blocking read; no fractional timeout support
                read -rsn2 -t 0 seq
                case "$seq" in
                    '[A') (( cur_line > 0 )) && (( cur_line-- )) ;;
                    '[B') (( cur_line < ${#lines[@]} - 1 )) && (( cur_line++ )) ;;
                esac
             fi
             continue
        fi

        if [[ "$key" == $'\x04' ]]; then break; fi

        case "$key" in
            $'\e')
                # macOS Bash 3.2: use non-blocking read; no fractional timeout support
                read -rsn2 -t 0 seq
                case "$seq" in
                    '[A') (( cur_line > 0 )) && (( cur_line-- )) ;;
                    '[B') (( cur_line < ${#lines[@]} - 1 )) && (( cur_line++ )) ;;
                    '[C') (( cur_col < ${#lines[cur_line]} )) && (( cur_col++ )) ;;
                    '[D') (( cur_col > 0 )) && (( cur_col-- )) ;;
                esac
                local current_line_len=${#lines[cur_line]}
                (( cur_col > current_line_len )) && cur_col=$current_line_len
                ;;
            $'\x7f') # Backspace
                if (( cur_col > 0 )); then
                    local line="${lines[cur_line]}"
                    ((cur_col--))
                    lines[cur_line]="${line:0:$cur_col}${line:$((cur_col+1))}"
                elif (( cur_line > 0 )); then
                    local line_content="${lines[cur_line]}"
                    unset 'lines[cur_line]'; lines=("${lines[@]}")
                    ((cur_line--))
                    cur_col=${#lines[cur_line]}
                    lines[cur_line]+="$line_content"
                fi
                ;;
            $'\n') # Enter
                local line="${lines[cur_line]}"; local p1="${line:0:$cur_col}"; local p2="${line:$cur_col}"
                lines[cur_line]="$p1"
                lines=("${lines:0:$((cur_line+1))}" "$p2" "${lines:$((cur_line+1))}")
                ((cur_line++)); cur_col=0
                ;;
            *) 
                if [[ "$key" =~ [[:print:]] ]]; then
                    local line="${lines[cur_line]}"
                    lines[cur_line]="${line:0:$cur_col}$key${line:$cur_col}"
                    ((cur_col++))
                fi
                ;;
        esac
    done
    
    stty "$old_stty"; trap - EXIT

    if [[ "$is_read_only" != "true" ]]; then
        local final_content
        final_content=$(printf "%s\n" "${lines[@]}")
        echo "$header_info" > "$file_to_edit"
        echo "$final_content" >> "$file_to_edit"
    fi
    clear
}

# ─── Create a new entry ─────────────────────────────────────────
new_entry() {
    clear
    echo -n "Mood (e.g. happy, sad, 1–10): "; read -r mood
    echo -n "Title (optional): "; read -r title
    ts=$(date +"$DATE_FMT")
    local header_info
    header_info=$(cat <<-EOF
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# Mood: $mood
# Title: $title
#────────────────────────────────────────
EOF
)
    local tmpfile
    tmpfile=$(mktemp "/tmp/journal_new_${USER}_XXXXXX")
    echo "$header_info" > "$tmpfile"

    _live_editor "$tmpfile" false

    if sed '1,/^#─*$/d' "$tmpfile" | grep -q '[^[:space:]]'; then
        local file_path="$ACTIVE_NOTEBOOK_PATH/$ts.txt"
        mv "$tmpfile" "$file_path"
        echo -e "${GREEN}✔ Saved:${NC} $file_path"
    else
        rm "$tmpfile"
        echo -e "${YELLOW}✖ Entry discarded (no content).${NC}"
    fi
    press_any
}

# ─── List entries ───────────────────────────────────────────────
list_entries() {
  mapfile -t files < <(ls -1 "$ACTIVE_NOTEBOOK_PATH" 2>/dev/null | sort -r)
  [[ ${#files[@]} -eq 0 ]] && { echo "No journal entries in notebook '$ACTIVE_NOTEBOOK_NAME' yet."; return 1; }

  printf "${MAGENTA}%-3s  %-19s  %-12s  %s${NC}\n" "#" "Date" "Mood" "Title"
  print_line "$THIN" 70

  local idx=1
  for f in "${files[@]}"; do
    local path="$ACTIVE_NOTEBOOK_PATH/$f"
    local d m t mood_color
    d=$(grep -m1 '^# Date:' "$path" | cut -d':' -f2- | xargs)
    m=$(grep -m1 '^# Mood:' "$path" | cut -d':' -f2- | xargs)
    t=$(grep -m1 '^# Title:' "$path" | cut -d':' -f2- | xargs)

    mood_color="$GREEN"
    if [[ $m =~ ^[0-9]+$ ]]; then
      if (( m <= 3 )); then mood_color="$RED"; elif (( m <=6 )); then mood_color="$YELLOW"; fi
    else
      case "${m,,}" in
        happy|great|good|excited|joy*|elated*) mood_color="$GREEN" ;;
        meh|okay|fine|neutral) mood_color="$YELLOW" ;;
        sad|depress*|angry|bad|tired) mood_color="$RED" ;;
        *) mood_color="$CYAN" ;;
      esac
    fi

    printf "  ${YELLOW}%-3s${NC}  ${CYAN}%-19s${NC}  %s%-12s${NC}  %s\n" "$idx" "${d:-?}" "$mood_color" "${m:-?}" "${t:-(no title)}"
    ((idx++))
  done
  return 0
}

# ─── Past Entries Management ──────────────────────────────────
manage_past_entries() {
  trap 'tput cnorm' EXIT
  clear
  _draw_static_header > /dev/null
  tput cup 5 0
  list_entries || { press_any; return; }
  echo
  echo -n "Select entry # to manage (or 0 to cancel): "; read -r num

  if [[ "$num" -eq 0 ]]; then echo "Cancelled."; press_any; return; fi

  mapfile -t files < <(ls -1 "$ACTIVE_NOTEBOOK_PATH" | sort -r)
  if ! [[ $num =~ ^[0-9]+$ ]] || [[ $num -lt 1 ]] || [[ $num -gt ${#files[@]} ]]; then
    echo "Invalid selection."; press_any; return
  fi

  local idx=$((num-1))
  local entry_path="$ACTIVE_NOTEBOOK_PATH/${files[$idx]}"
  local entry_basename; entry_basename=$(basename "$entry_path")

  local time=0
  while true; do
    clear
    local coords; read -r title_y title_x heart_y heart_x info_y < <(_draw_static_header)
    
    local menu_y=$((info_y + 2))
    tput cup "$menu_y" 0
    echo -e "Managing Entry: ${YELLOW}$entry_basename${NC}"
    print_line "$THIN" 70
    echo -e "  ${YELLOW}1${NC}) View Entry"
    echo -e "  ${YELLOW}2${NC}) Edit Entry"
    echo -e "  ${YELLOW}3${NC}) Delete Entry"
    echo -e "  ${YELLOW}0${NC}) Back to Main Menu"
    
    local prompt_y=$((menu_y + 6))
    tput cup "$prompt_y" 0
    echo -n "Select: "

    local choice=""
    while true; do
        _animate_header_frame "$title_y" "$title_x" "$heart_y" "$heart_x" "$info_y" "$time"
        if read -rsn1 -t 0.1 key; then
            choice="$key"
            break
        fi
        (( time++ ))
    done
    echo 

    case "$choice" in
      1) _live_editor "$entry_path" true ;;
      2) _live_editor "$entry_path" false; echo -e "${GREEN}✔ Entry updated.${NC}"; press_any ;;
      3)
        echo -n "Delete '$entry_basename'? (y/N): "; read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          rm -f "$entry_path" && echo -e "${GREEN}✔ Deleted.${NC}" || echo -e "${RED}✖ Failed to delete.${NC}"
        else
          echo "Deletion cancelled."
        fi
        press_any; trap - EXIT; return
        ;;
      0) trap - EXIT; return ;;
      *) echo "Invalid choice"; sleep 1 ;;
    esac
  done
}

# ─── Mood statistics ──────────────────────────────────────────
show_moods() {
  clear
  echo "Mood distribution for notebook '$ACTIVE_NOTEBOOK_NAME':"; echo
  local line count mood clr
  while read -r count mood; do
     clr="$GREEN"
     if [[ $mood =~ ^[0-9]+$ ]]; then
        if (( mood <=3 )); then clr="$RED"; elif (( mood <=6 )); then clr="$YELLOW"; fi
     else
        case "${mood,,}" in
          happy|great|good|excited|joy*|elated*) clr="$GREEN" ;;
          meh|okay|fine|neutral) clr="$YELLOW" ;;
          sad|depress*|angry|bad|tired) clr="$RED" ;;
          *) clr="$CYAN" ;;
        esac
     fi
     printf "${clr}%-4s %s${NC}\n" "$count" "$mood"
  done < <(grep -h '^# Mood:' "$ACTIVE_NOTEBOOK_PATH"/*.txt 2>/dev/null | cut -d':' -f2- | tr -d ' ' | sort | uniq -c | sort -nr)

  if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
     echo "No mood data found in this notebook."
  fi
  echo; press_any
}

# ─── Notebook Management ──────────────────────────────────────
manage_notebooks() {
    trap 'tput cnorm' EXIT
    local time=0
    while true; do
        clear
        local coords; read -r title_y title_x heart_y heart_x info_y < <(_draw_static_header)

        local menu_y=$((info_y + 2))
        tput cup "$menu_y" 0
        echo -e "${CYAN}Notebook Settings${NC}"
        print_line "$THIN" 70
        echo -e "  ${YELLOW}1${NC}) Create New Notebook"
        echo -e "  ${YELLOW}2${NC}) Delete a Notebook"
        echo -e "  ${YELLOW}3${NC}) Switch Active Notebook"
        echo -e "  ${YELLOW}0${NC}) Back to Main Menu"
        
        local prompt_y=$((menu_y + 6))
        tput cup "$prompt_y" 0
        echo -n "Select: "

        local choice=""
        while true; do
            _animate_header_frame "$title_y" "$title_x" "$heart_y" "$heart_x" "$info_y" "$time"
            if read -rsn1 -t 0.1 key; then
                choice="$key"
                break
            fi
            (( time++ ))
        done
        echo

        case "$choice" in
            1) clear; _create_new_notebook ;;
            2) clear; _delete_notebook ;;
            3) clear; _switch_notebook ;;
            0) trap - EXIT; return ;;
            *) echo "Invalid choice"; sleep 1 ;;
        esac
    done
}

_list_notebooks() {
  echo -e "\n${CYAN}Available Notebooks:${NC}"
  mapfile -t notebooks < <(find "$JOURNAL_DIR_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  if [[ ${#notebooks[@]} -eq 0 ]]; then
    echo "No notebooks found (this shouldn't happen if init_dir worked)."
    return 1
  fi

  local idx=0
  for nb_name in "${notebooks[@]}"; do
    ((idx++))
    if [[ "$nb_name" == "$ACTIVE_NOTEBOOK_NAME" ]]; then
      printf "  ${GREEN}%d) %s (Active)${NC}\n" "$idx" "$nb_name"
    else
      printf "  %d) %s\n" "$idx" "$nb_name"
    fi
  done
  _LISTED_NOTEBOOKS=("${notebooks[@]}") 
  return 0
}

_switch_notebook() {
  _LISTED_NOTEBOOKS=() 
  _list_notebooks
  local list_status=$?

  if [[ $list_status -ne 0 ]]; then
    echo "Could not list notebooks." 
    press_any
    return
  fi

  if [[ ${#_LISTED_NOTEBOOKS[@]} -le 1 && "${_LISTED_NOTEBOOKS[0]}" == "$ACTIVE_NOTEBOOK_NAME" ]]; then
    echo -e "\nOnly the current notebook ('$ACTIVE_NOTEBOOK_NAME') exists."
    press_any
    return
  fi

  echo -n "Enter number of notebook to switch to (or 0 to cancel): "
  read -r choice

  if [[ "$choice" -eq 0 ]]; then
    echo "Switch cancelled."
    press_any
    return
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#_LISTED_NOTEBOOKS[@]} ]]; then
    echo "Invalid selection."
    press_any
    return
  fi

  local selected_notebook_name="${_LISTED_NOTEBOOKS[$((choice-1))]}"

  if [[ "$selected_notebook_name" == "$ACTIVE_NOTEBOOK_NAME" ]]; then
    echo "Notebook '$selected_notebook_name' is already active."
  else
    ACTIVE_NOTEBOOK_NAME="$selected_notebook_name"
    ACTIVE_NOTEBOOK_PATH="$JOURNAL_DIR_BASE/$ACTIVE_NOTEBOOK_NAME"
    echo "$ACTIVE_NOTEBOOK_NAME" > "$ACTIVE_NOTEBOOK_CONFIG_FILE"
    echo -e "${GREEN}Switched to notebook: $ACTIVE_NOTEBOOK_NAME${NC}"
  fi
  press_any
}

_create_new_notebook() {
  echo -e "\n${CYAN}Create New Notebook${NC}"
  echo -n "Enter name for the new notebook: "
  read -r new_notebook_name

  if [[ -z "$new_notebook_name" ]]; then
    echo -e "${RED}Notebook name cannot be empty.${NC}"
    press_any
    return
  fi

  if [[ -d "$JOURNAL_DIR_BASE/$new_notebook_name" ]]; then
    echo -e "${YELLOW}Notebook named '$new_notebook_name' already exists.${NC}"
    press_any
    return
  fi

  if mkdir "$JOURNAL_DIR_BASE/$new_notebook_name"; then
    echo -e "${GREEN}Notebook '$new_notebook_name' created successfully.${NC}"
    echo -n "Switch to '$new_notebook_name' now? (y/N): "
    read -r switch_choice
    if [[ "$switch_choice" =~ ^[Yy]$ ]]; then
      ACTIVE_NOTEBOOK_NAME="$new_notebook_name"
      ACTIVE_NOTEBOOK_PATH="$JOURNAL_DIR_BASE/$ACTIVE_NOTEBOOK_NAME"
      echo "$ACTIVE_NOTEBOOK_NAME" > "$ACTIVE_NOTEBOOK_CONFIG_FILE"
      echo -e "${GREEN}Switched to notebook: $ACTIVE_NOTEBOOK_NAME${NC}"
    fi
  else
    echo -e "${RED}Failed to create notebook '$new_notebook_name'. Check permissions or name.${NC}"
  fi
  press_any
}

_delete_notebook() {
    _LISTED_NOTEBOOKS=() 
    _list_notebooks
    local list_status=$?

    if [[ $list_status -ne 0 ]]; then
        press_any
        return
    fi
    
    if [[ ${#_LISTED_NOTEBOOKS[@]} -eq 1 ]]; then
        echo -e "\n${YELLOW}Cannot delete the only existing notebook.${NC}"
        press_any
        return
    fi

    echo -n "Enter number of notebook to delete (or 0 to cancel): "
    read -r choice

    if [[ "$choice" -eq 0 ]]; then
        echo "Deletion cancelled."
        press_any
        return
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#_LISTED_NOTEBOOKS[@]} ]]; then
        echo "Invalid selection."
        press_any
        return
    fi

    local notebook_to_delete="${_LISTED_NOTEBOOKS[$((choice-1))]}"
    
    echo -ne "\n${RED}Permanently delete notebook '${YELLOW}$notebook_to_delete${RED}' and all its entries?${NC} (y/N): "
    read -r confirm_delete

    if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
        local notebook_path_to_delete="$JOURNAL_DIR_BASE/$notebook_to_delete"
        if rm -rf "$notebook_path_to_delete"; then
            echo -e "${GREEN}✔ Notebook '$notebook_to_delete' was deleted.${NC}"
            if [[ "$notebook_to_delete" == "$ACTIVE_NOTEBOOK_NAME" ]]; then
                echo "The active notebook was deleted. Re-initializing..."
                init_dir 
                echo -e "${GREEN}Switched to new active notebook: $ACTIVE_NOTEBOOK_NAME${NC}"
            fi
        else
            echo -e "${RED}✖ Failed to delete notebook directory. Check permissions.${NC}"
        fi
    else
        echo "Deletion cancelled."
    fi
    press_any
}

# ─── Main menu ────────────────────────────────────────────────
main_menu() {
  trap 'tput cnorm' EXIT INT TERM
  local time=0
  while true; do
    clear
    local coords; read -r title_y title_x heart_y heart_x info_y < <(_draw_static_header)

    local menu_y=$((info_y + 2))
    tput cup "$menu_y" 0
    echo -e "  ${YELLOW}1${NC}) New entry"
    echo -e "  ${YELLOW}2${NC}) Past Entries"
    echo -e "  ${YELLOW}3${NC}) Mood stats"
    echo -e "  ${YELLOW}4${NC}) Switch Notebook"
    echo -e "  ${YELLOW}5${NC}) Notebook Settings"
    echo -e "  ${YELLOW}0${NC}) Exit"
    
    local prompt_y=$((menu_y + 7))
    tput cup "$prompt_y" 0
    echo -n "Select: ";
    
    local choice=""
    while true; do
        _animate_header_frame "$title_y" "$title_x" "$heart_y" "$heart_x" "$info_y" "$time"
        if read -rsn1 -t 0.1 key; then
            choice="$key"
            break
        fi
        (( time++ ))
    done
    echo

    case "$choice" in
      1) new_entry ;;
      2) manage_past_entries ;;
      3) show_moods ;;
      4) _switch_notebook ;;
      5) manage_notebooks ;;
      0) break ;;
      *) echo "Invalid choice"; sleep 1 ;;
    esac
    print_line "$THICK" 70
  done
}

# ─── Run ──────────────────────────────────────────────────────
init_dir
main_menu
