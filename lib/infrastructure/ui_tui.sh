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

# Draw the static header and output coordinates for dynamic elements on stdout
_draw_static_header() {
  # Define layout variables first so they are in scope for both drawing and coordinate output
  local title_text=" ~ Lamplight ~ "
  local title_y=1
  local title_x=2
  local border top_bottom
  border=$(printf "%*s" "${#title_text}" "" | tr ' ' '-')
  top_bottom="+${border}+"

  {   # All drawing goes to stderr; stdout will only contain coordinates
    tput cup 0 0; tput ed
    # Draw the static parts of the header
    tput cup $title_y $title_x; printf "%s" "$top_bottom"
    # Middle line intentionally without side bars; animated title will draw its own pipes
    tput cup $((title_y + 1)) $title_x; printf "%*s" "${#title_text}" ""
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

# Animate the header title (heart removed)
_animate_header_frame() {
  local title_y="$1" title_x="$2" heart_y="$3" heart_x="$4" info_y="$5" time="$6"

  tput sc
  tput civis

  local title="~ Lamplight ~"
  # Orange → yellow gradient (256-color): deep orange to bright yellow and back
  local colors=(208 209 214 220 226 220 214 209)

  local title_output=""
  for i in $(seq 0 $((${#title}-1))); do
    local color_idx=$(( (i + time) % ${#colors[@]} ))
    local char_color_code=${colors[$color_idx]}
    title_output+="\e[38;5;${char_color_code}m${title:$i:1}"
  done
  tput cup "$title_y" "$title_x"; printf "|${title_output}\e[0m|"

  tput cup "$info_y" 0; tput el
  printf "${MAGENTA}Notebook: ${YELLOW}%s${NC}   ${MAGENTA}%s${NC}" "$ACTIVE_NOTEBOOK_NAME" "$(date '+%Y-%m-%d %H:%M:%S')"

  tput rc
  tput cnorm
}
