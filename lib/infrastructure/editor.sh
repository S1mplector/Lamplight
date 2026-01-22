#!/usr/bin/env bash
# Live editor with scroll support and enhanced UX

# Editor state variables
_EDITOR_SCROLL_OFFSET=0
_EDITOR_SHOW_LINE_NUMBERS=0

_redraw_lines() {
  local -n _lines="$1"
  local _cur_line="$2"
  local _cur_col="$3"
  local _scroll_offset="${4:-0}"
  local _show_numbers="${5:-0}"
  
  local term_height; term_height=$(tput lines)
  local term_width; term_width=$(tput cols)
  local editor_height=$((term_height - 7))
  local line_num_width=0
  
  # Calculate line number width if showing
  if [[ "$_show_numbers" == "1" ]]; then
    line_num_width=$((${#${#_lines[@]}} + 2))
  fi

  local output; output="$(tput civis)"
  
  for i in $(seq 0 $((editor_height - 1))); do
    local line_idx=$((i + _scroll_offset))
    output+="$(tput cup $((3 + i)) 0)$(tput el)"
    
    if [[ $line_idx -lt ${#_lines[@]} ]]; then
      if [[ "$_show_numbers" == "1" ]]; then
        # Show line numbers with subtle color
        output+="\e[90m$(printf "%${line_num_width}d" $((line_idx + 1)))\e[0m "
      fi
      # Truncate long lines to fit terminal
      local line_content="${_lines[$line_idx]}"
      local max_content_width=$((term_width - line_num_width - 4))
      if [[ ${#line_content} -gt $max_content_width ]]; then
        line_content="${line_content:0:$max_content_width}…"
      fi
      output+="  ${line_content}"
    fi
  done
  
  output+="$(tput cnorm)"
  
  # Position cursor relative to scroll offset
  local screen_line=$((_cur_line - _scroll_offset))
  local cursor_x=$((2 + _cur_col + (line_num_width > 0 ? line_num_width + 1 : 0)))
  output+="$(tput cup $((3 + screen_line)) $cursor_x)"
  
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
  local scroll_offset=0
  local show_line_numbers=0
  local header_text_for_display
  header_text_for_display=$(echo "$header_info" | sed 's/# //g' | sed 's/#─*/─/g')

  local term_height term_width editor_height
  term_height=$(tput lines)
  term_width=$(tput cols)
  editor_height=$((term_height - 7))

  _draw_editor_frame() {
    clear
    echo "$header_text_for_display"
    print_line "/" "$term_width"
    
    tput cup $((4 + editor_height)) 0
    print_line "/" "$term_width"
    
    # Status bar with word count and position
    local word_count=0
    for l in "${lines[@]}"; do
      local wc; wc=$(echo "$l" | wc -w)
      ((word_count += wc))
    done
    
    if [[ "$is_read_only" == "true" ]]; then
      printf " ${CYAN}READ ONLY${NC} | Line %d/%d | %d words | ${YELLOW}Q${NC} Quit | ${YELLOW}↑↓${NC} Scroll" \
        "$((cur_line + 1))" "${#lines[@]}" "$word_count"
    else
      printf " Line %d/%d Col %d | %d words | ${YELLOW}Ctrl+D${NC} Save | ${YELLOW}Ctrl+N${NC} Line#" \
        "$((cur_line + 1))" "${#lines[@]}" "$((cur_col + 1))" "$word_count"
    fi
    tput el
  }

  _draw_editor_frame

  local old_stty
  old_stty=$(stty -g)
  trap 'stty "$old_stty"; tput cnorm' EXIT 
  stty -echo -icanon

  while true; do
    # Adjust scroll offset to keep cursor visible
    if (( cur_line < scroll_offset )); then
      scroll_offset=$cur_line
    elif (( cur_line >= scroll_offset + editor_height )); then
      scroll_offset=$((cur_line - editor_height + 1))
    fi
    
    _redraw_lines lines "$cur_line" "$cur_col" "$scroll_offset" "$show_line_numbers"
    
    # Update status bar position info
    tput sc
    tput cup $((5 + editor_height)) 1
    local word_count=0
    for l in "${lines[@]}"; do
      local wc; wc=$(echo "$l" | wc -w)
      ((word_count += wc))
    done
    
    if [[ "$is_read_only" == "true" ]]; then
      printf "${CYAN}READ ONLY${NC} | Line %d/%d | %d words" \
        "$((cur_line + 1))" "${#lines[@]}" "$word_count"
    else
      printf "Line %d/%d Col %d | %d words" \
        "$((cur_line + 1))" "${#lines[@]}" "$((cur_col + 1))" "$word_count"
    fi
    tput el
    tput rc

    IFS= read -rsn1 key
    
    if [[ "$is_read_only" == "true" ]]; then
      case "$key" in
        q|Q) break ;;
        $'\e')
          read -rsn2 -t 0.01 seq
          case "$seq" in
            '[A') (( cur_line > 0 )) && (( cur_line-- )) ;;
            '[B') (( cur_line < ${#lines[@]} - 1 )) && (( cur_line++ )) ;;
            '[5~') # Page Up
              cur_line=$((cur_line - editor_height))
              (( cur_line < 0 )) && cur_line=0
              ;;
            '[6~') # Page Down
              cur_line=$((cur_line + editor_height))
              (( cur_line >= ${#lines[@]} )) && cur_line=$((${#lines[@]} - 1))
              ;;
            '[H') cur_line=0 ;; # Home
            '[F') cur_line=$((${#lines[@]} - 1)) ;; # End
          esac
          ;;
      esac
      continue
    fi

    # Ctrl+D to save and exit
    if [[ "$key" == $'\x04' ]]; then break; fi
    
    # Ctrl+N to toggle line numbers
    if [[ "$key" == $'\x0e' ]]; then
      show_line_numbers=$((1 - show_line_numbers))
      _draw_editor_frame
      continue
    fi

    case "$key" in
      $'\e')
        read -rsn2 -t 0.01 seq
        case "$seq" in
          '[A') # Up
            (( cur_line > 0 )) && (( cur_line-- ))
            ;;
          '[B') # Down
            (( cur_line < ${#lines[@]} - 1 )) && (( cur_line++ ))
            ;;
          '[C') # Right
            if (( cur_col < ${#lines[cur_line]} )); then
              (( cur_col++ ))
            elif (( cur_line < ${#lines[@]} - 1 )); then
              (( cur_line++ ))
              cur_col=0
            fi
            ;;
          '[D') # Left
            if (( cur_col > 0 )); then
              (( cur_col-- ))
            elif (( cur_line > 0 )); then
              (( cur_line-- ))
              cur_col=${#lines[cur_line]}
            fi
            ;;
          '[5~') # Page Up
            cur_line=$((cur_line - editor_height))
            (( cur_line < 0 )) && cur_line=0
            ;;
          '[6~') # Page Down
            cur_line=$((cur_line + editor_height))
            (( cur_line >= ${#lines[@]} )) && cur_line=$((${#lines[@]} - 1))
            ;;
          '[H') cur_col=0 ;; # Home - go to start of line
          '[F') cur_col=${#lines[cur_line]} ;; # End - go to end of line
        esac
        # Clamp cursor column
        local current_line_len=${#lines[cur_line]}
        (( cur_col > current_line_len )) && cur_col=$current_line_len
        ;;
      $'\x7f'|$'\b') # Backspace
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
      $'\n'|'') # Enter
        local line="${lines[cur_line]}"
        local p1="${line:0:$cur_col}"
        local p2="${line:$cur_col}"
        lines[cur_line]="$p1"
        # Insert new line
        local new_lines=()
        for ((i=0; i<=cur_line; i++)); do
          new_lines+=("${lines[i]}")
        done
        new_lines+=("$p2")
        for ((i=cur_line+1; i<${#lines[@]}; i++)); do
          new_lines+=("${lines[i]}")
        done
        lines=("${new_lines[@]}")
        ((cur_line++))
        cur_col=0
        ;;
      $'\t') # Tab - insert spaces
        local line="${lines[cur_line]}"
        lines[cur_line]="${line:0:$cur_col}    ${line:$cur_col}"
        ((cur_col += 4))
        ;;
      *) 
        if [[ -n "$key" ]] && [[ "$key" =~ [[:print:]] ]]; then
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
