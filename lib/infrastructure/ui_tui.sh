#!/usr/bin/env bash
# UI/TUI utilities (placeholder for migration)

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

press_any() { spinner_wait 15; }
