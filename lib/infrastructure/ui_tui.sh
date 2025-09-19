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
  if [[ "${SHOW_BIG_CLOCK:-0}" == "1" ]]; then
    # Left side: notebook label only
    printf "${MAGENTA}Notebook: ${YELLOW}%s${NC}" "$ACTIVE_NOTEBOOK_NAME"
    # Right side: big ASCII clock
    local cols; cols=$(tput cols)
    # Let the renderer compute exact width and center within left half; pass -2 as sentinel
    if ! _render_big_clock "$((info_y + 1))" -2; then
      # Too narrow for big clock, fall back to compact inline time
      tput cup "$info_y" 0; tput el; printf "${MAGENTA}Notebook: ${YELLOW}%s${NC}   ${MAGENTA}%s${NC}" "$ACTIVE_NOTEBOOK_NAME" "$(date '+%Y-%m-%d %H:%M:%S')"
    fi
  else
    # Fallback compact inline time
    printf "${MAGENTA}Notebook: ${YELLOW}%s${NC}   ${MAGENTA}%s${NC}" "$ACTIVE_NOTEBOOK_NAME" "$(date '+%Y-%m-%d %H:%M:%S')"
  fi

  tput rc
  tput cnorm
}

# Helper: return a glyph row for character ($1) and row index ($2: 0..4)
_clock_glyph_row() {
  local ch="$1" r="$2"
  case "$ch" in
    0)
      case $r in
        0) echo " ####  " ;;
        1) echo "#    # " ;;
        2) echo "#    # " ;;
        3) echo "#    # " ;;
        4) echo " ####  " ;;
      esac ;;
    1)
      case $r in
        0) echo "  ##   " ;;
        1) echo "   #   " ;;
        2) echo "   #   " ;;
        3) echo "   #   " ;;
        4) echo " ##### " ;;
      esac ;;
    2)
      case $r in
        0) echo " ####  " ;;
        1) echo "     # " ;;
        2) echo " ####  " ;;
        3) echo "#      " ;;
        4) echo " ##### " ;;
      esac ;;
    3)
      case $r in
        0) echo " ####  " ;;
        1) echo "     # " ;;
        2) echo "  ###  " ;;
        3) echo "     # " ;;
        4) echo " ####  " ;;
      esac ;;
    4)
      case $r in
        0) echo "   ##  " ;;
        1) echo "  # #  " ;;
        2) echo " #  #  " ;;
        3) echo "###### " ;;
        4) echo "    #  " ;;
      esac ;;
    5)
      case $r in
        0) echo " ##### " ;;
        1) echo " #     " ;;
        2) echo " ####  " ;;
        3) echo "     # " ;;
        4) echo " ####  " ;;
      esac ;;
    6)
      case $r in
        0) echo "  ###  " ;;
        1) echo " #     " ;;
        2) echo " ####  " ;;
        3) echo " #   # " ;;
        4) echo "  ###  " ;;
      esac ;;
    7)
      case $r in
        0) echo " ##### " ;;
        1) echo "     # " ;;
        2) echo "    #  " ;;
        3) echo "   #   " ;;
        4) echo "  #    " ;;
      esac ;;
    8)
      case $r in
        0) echo "  ##   " ;;
        1) echo " #  #  " ;;
        2) echo "  ##   " ;;
        3) echo " #  #  " ;;
        4) echo "  ##   " ;;
      esac ;;
    9)
      case $r in
        0) echo "  ###  " ;;
        1) echo " #   # " ;;
        2) echo "  #### " ;;
        3) echo "     # " ;;
        4) echo "  ###  " ;;
      esac ;;
    :)
      case $r in
        0) echo "   " ;;
        1) echo " # " ;;
        2) echo "   " ;;
        3) echo " # " ;;
        4) echo "   " ;;
      esac ;;
  esac
}

# Render a large ASCII-art digital clock (5 rows) at the given top-left coordinates.
# Draws the current time as HH:MM:SS using a 7-seg-inspired font.
# This is designed to be called frequently; it clears only the required region.
_render_big_clock() {
  local top_y="$1" left_x="$2"
  local time_str
  time_str=$(date '+%H:%M:%S')

  local rows=("" "" "" "" "")
  local ch
  for ((i=0; i<${#time_str}; i++)); do
    ch="${time_str:i:1}"
    for r in 0 1 2 3 4; do
      rows[$r]+="$(_clock_glyph_row "$ch" "$r")"
    done
  done

  # Determine dynamic width and position
  local width=${#rows[0]}
  local cols; cols=$(tput cols)
  if (( left_x < 0 )); then
    case $left_x in
      -1) left_x=$(( (cols - width) / 2 )) ;;
      -2)
         # Center within left half of the screen
         local half=$(( cols / 2 ))
         left_x=$(( (half - width) / 2 ))
         ;;
      -3)
         # Right align against right edge
         left_x=$(( cols - width - 1 ))
         ;;
      *) left_x=0 ;;
    esac
  fi
  (( left_x < 0 )) && left_x=0

  # If terminal is too narrow, signal failure so caller can fallback
  if (( width > cols - left_x )); then
    return 1
  fi

  # Build orange gradient palette (256-color): deep orange -> bright yellow -> back
  local colors=(208 209 214 220 226 220 214 209)

  # Batch all cursor movements and drawing into a single printf to minimize flicker
  local buffer=""
  for r in 0 1 2 3 4; do
    local y=$((top_y + r))
    local line="${rows[$r]}"
    local colored=""
    local w=${#line}
    for ((j=0; j<w; j++)); do
      local ch=${line:j:1}
      if [[ "$ch" == " " ]]; then
        colored+=" "
      else
        local color_idx=$(( j % ${#colors[@]} ))
        local code=${colors[$color_idx]}
        colored+=$'\e[38;5;'"${code}"$'m'"${ch}"
      fi
    done
    colored+=$'\e[0m'
    buffer+="$(tput cup "$y" 0)$(tput el)$(tput cup "$y" "$left_x")${colored}"
  done
  printf "%s" "$buffer"
  return 0
}
