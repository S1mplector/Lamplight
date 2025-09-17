#!/usr/bin/env bash
# Use case: list entries (standalone)

usecase_list_entries() {
  init_dir
  mapfile -t files < <(ls -1 "$ACTIVE_NOTEBOOK_PATH" 2>/dev/null | sort -r)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No journal entries in notebook '$ACTIVE_NOTEBOOK_NAME' yet."
    return 1
  fi

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
