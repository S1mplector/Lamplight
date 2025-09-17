#!/usr/bin/env bash
# Live editor (placeholder for migration)

# In migration, we will move _redraw_lines and _live_editor here and expose
# a stable function like: editor_open FILE [read_only]

_redraw_lines() {
  local -n _lines="$1"
  local _cur_line="$2"
  local _cur_col="$3"
  
  local term_height; term_height=$(tput lines)
  local editor_height=$((term_height - 6)) 

  local output; output="$(tput civis)"
  for i in $(seq 0 $((editor_height - 1))); do
      output+="$(tput cup $((3 + i)) 0)$(tput el)"
      if [[ -v "_lines[i]" ]]; then
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
              read -rsn2 -t 0.01 seq
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
              read -rsn2 -t 0.01 seq
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
