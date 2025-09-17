#!/usr/bin/env bash
# CLI: standalone menu using clean modules

main_menu() {
  trap 'tput cnorm' EXIT INT TERM
  init_dir
  local time=0
  while true; do
    clear
    local title_y title_x heart_y heart_x info_y
    read -r title_y title_x heart_y heart_x info_y < <(_draw_static_header)

    local menu_y=$((info_y + 2))
    tput cup "$menu_y" 0
    echo -e "  ${YELLOW}1${NC}) New entry"
    echo -e "  ${YELLOW}2${NC}) List entries"
    echo -e "  ${YELLOW}3${NC}) Manage entries"
    echo -e "  ${YELLOW}4${NC}) Mood stats"
    echo -e "  ${YELLOW}5${NC}) Switch notebook"
    echo -e "  ${YELLOW}6${NC}) Create notebook"
    echo -e "  ${YELLOW}7${NC}) Delete notebook"
    echo -e "  ${YELLOW}0${NC}) Exit"

    # Calculate prompt position dynamically: number of menu lines (8) + some spacing
    local menu_lines=8
    local prompt_y=$((menu_y + menu_lines + 1))
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
      1) usecase_new_entry ;;
      2)
        clear
        _draw_static_header > /dev/null
        tput cup 5 0
        usecase_list_entries
        echo
        press_any
        ;;
      3) usecase_manage_entries ;;
      4) usecase_mood_stats ;;
      5) usecase_switch_notebook ;;
      6) usecase_create_notebook ;;
      7) usecase_delete_notebook ;;
      0) break ;;
      *) echo "Invalid choice"; sleep 1 ;;
    esac
  done
}

lamplight_main() {
  main_menu
}
