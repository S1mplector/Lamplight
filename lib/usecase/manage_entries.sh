#!/usr/bin/env bash
# Use cases: manage past entries (view, edit, delete)

usecase_manage_entries() {
  trap 'tput cnorm' EXIT
  clear
  _draw_static_header > /dev/null
  tput cup 5 0
  usecase_list_entries || { press_any; return; }
  echo
  echo -n "Select entry # to manage (or 0 to cancel): "; read -r num

  if [[ "$num" -eq 0 ]]; then echo "Cancelled."; press_any; return; fi

  mapfile -t files < <(ls -1 "$ACTIVE_NOTEBOOK_PATH" 2>/dev/null | sort -r)
  if ! [[ $num =~ ^[0-9]+$ ]] || [[ $num -lt 1 ]] || [[ $num -gt ${#files[@]} ]]; then
    echo "Invalid selection."; press_any; return
  fi

  local idx=$((num-1))
  local entry_path="$ACTIVE_NOTEBOOK_PATH/${files[$idx]}"
  local entry_basename; entry_basename=$(basename "$entry_path")

  local time=0
  while true; do
    clear
    local title_y title_x heart_y heart_x info_y
    read -r title_y title_x heart_y heart_x info_y < <(_draw_static_header)

    local menu_y=$((info_y + 2))
    tput cup "$menu_y" 0
    echo -e "Managing Entry: ${YELLOW}$entry_basename${NC}"
    print_line "$THIN" 70
    echo -e "  ${YELLOW}1${NC}) View Entry"
    echo -e "  ${YELLOW}2${NC}) Edit Entry"
    echo -e "  ${YELLOW}3${NC}) Delete Entry"
    echo -e "  ${YELLOW}0${NC}) Back"

    local prompt_y=$((menu_y + 6))
    tput cup "$prompt_y" 0
    echo -n "Select: "

    local choice=""
    while true; do
      _animate_header_frame "$title_y" "$title_x" "$heart_y" "$heart_x" "$info_y" "$time"
      # Non-blocking read; macOS Bash 3.2 doesn't support fractional timeouts
      if read -rsn1 -t 0 key; then
        choice="$key"; break
      fi
      sleep 0.1
      (( time++ ))
    done
    # Restore terminal before processing the choice
    stty "$_old_stty"
    echo

    case "$choice" in
      1) editor_open "$entry_path" true ;;
      2) editor_open "$entry_path" false; echo -e "${GREEN}✔ Entry updated.${NC}"; press_any ;;
      3)
        echo -n "Delete '$entry_basename'? (y/N): "; read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          rm -f "$entry_path" && echo -e "${GREEN}✔ Deleted.${NC}" || echo -e "${RED}✖ Failed to delete.${NC}"
          press_any; return
        else
          echo "Deletion cancelled."; press_any
        fi
        ;;
      0) return ;;
      *) echo "Invalid choice"; sleep 1 ;;
    esac
  done
}
