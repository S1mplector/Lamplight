#!/usr/bin/env bash
# Use case: mood statistics

usecase_mood_stats() {
  init_dir
  clear
  echo "Mood distribution for notebook '$ACTIVE_NOTEBOOK_NAME':"
  echo
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
  echo
  press_any
}
