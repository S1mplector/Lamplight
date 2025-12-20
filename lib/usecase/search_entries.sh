#!/usr/bin/env bash
# Use case: search/filter entries across notebooks

_validate_date_input() {
  local d="$1"
  [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
}

_entry_matches_filters() {
  local entry_date="$1" mood="$2" path="$3" start_date="$4" end_date="$5" mood_exact="$6" mood_min="$7" mood_max="$8" mood_text="$9" text_query="${10}"

  if { [[ -n "$start_date" ]] || [[ -n "$end_date" ]]; } && [[ -z "$entry_date" ]]; then
    return 1
  fi
  if [[ -n "$start_date" && "$entry_date" < "$start_date" ]]; then return 1; fi
  if [[ -n "$end_date" && "$entry_date" > "$end_date" ]]; then return 1; fi

  if [[ -n "$mood_exact" ]]; then
    [[ "$mood" =~ ^[0-9]+$ ]] || return 1
    (( mood == mood_exact )) || return 1
  elif [[ -n "$mood_min" ]]; then
    [[ "$mood" =~ ^[0-9]+$ ]] || return 1
    (( mood >= mood_min && mood <= mood_max )) || return 1
  elif [[ -n "$mood_text" ]]; then
    [[ -n "$mood" ]] || return 1
    [[ "${mood,,}" == *"${mood_text,,}"* ]] || return 1
  fi

  if [[ -n "$text_query" ]]; then
    if ! grep -qi -- "$text_query" "$path"; then return 1; fi
  fi

  return 0
}

_scan_entries_with_filters() {
  local -n _results_ref="$1"
  local -a notebooks=("${!2}")
  local start_date="$3" end_date="$4" mood_exact="$5" mood_min="$6" mood_max="$7" mood_text="$8" text_query="$9"

  for nb in "${notebooks[@]}"; do
    local nb_path="$JOURNAL_DIR_BASE/$nb"
    mapfile -t files < <(ls -1 "$nb_path"/*.txt 2>/dev/null | sort -r)
    for path in "${files[@]}"; do
      [[ -f "$path" ]] || continue
      local fname entry_ts entry_date header_date mood title
      fname=$(basename "$path")
      entry_ts="${fname%.txt}"
      entry_date="${entry_ts%%_*}"

      header_date=$(grep -m1 '^# Date:' "$path" | cut -d':' -f2- | xargs)
      mood=$(grep -m1 '^# Mood:' "$path" | cut -d':' -f2- | xargs)
      title=$(grep -m1 '^# Title:' "$path" | cut -d':' -f2- | xargs)

      if ! [[ "$entry_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        entry_date=$(cut -d' ' -f1 <<< "$header_date")
      fi

      _entry_matches_filters "$entry_date" "$mood" "$path" "$start_date" "$end_date" "$mood_exact" "$mood_min" "$mood_max" "$mood_text" "$text_query" || continue

      _results_ref+=("$entry_ts"$'\t'"$nb"$'\t'"${header_date:-?}"$'\t'"${mood:-?}"$'\t'"${title:-?(no title)}"$'\t'"$path")
    done
  done
}

_render_search_results() {
  local -a rows=("${!1}")
  local -n out_paths_ref="$2"
  clear
  echo -e "${CYAN}Search results${NC}"
  print_line "$THIN" 80
  printf "${MAGENTA}%-3s  %-12s  %-19s  %-12s  %s${NC}\n" "#" "Notebook" "Date" "Mood" "Title"
  print_line "$THIN" 80

  out_paths_ref=()
  local idx=1
  while IFS=$'\t' read -r ts nb date mood title path; do
    printf "  ${YELLOW}%-3s${NC}  ${CYAN}%-12s${NC}  %-19s  %-12s  %s\n" "$idx" "$nb" "${date:-?}" "${mood:-?}" "${title:-?(no title)}"
    out_paths_ref[$idx]="$path"
    ((idx++))
  done <<< "$(printf "%s\n" "${rows[@]}")"
}

usecase_search_entries() {
  init_dir
  clear
  echo -e "${CYAN}Search / Filter Entries${NC}"
  print_line "$THIN" 70

  echo -n "Scope - search all notebooks? (y/N): "; read -r search_all
  local -a notebooks
  if [[ "$search_all" =~ ^[Yy]$ ]]; then
    mapfile -t notebooks < <(notebook_list_all)
  else
    notebooks=("$ACTIVE_NOTEBOOK_NAME")
  fi

  if [[ ${#notebooks[@]} -eq 0 ]]; then
    echo "No notebooks found."; press_any; return
  fi

  echo -n "Start date (YYYY-MM-DD, optional): "; read -r start_date
  if [[ -n "$start_date" && ! _validate_date_input "$start_date" ]]; then
    echo -e "${RED}Invalid start date format.${NC}"; press_any; return
  fi
  echo -n "End date (YYYY-MM-DD, optional): "; read -r end_date
  if [[ -n "$end_date" && ! _validate_date_input "$end_date" ]]; then
    echo -e "${RED}Invalid end date format.${NC}"; press_any; return
  fi
  if [[ -n "$start_date" && -n "$end_date" && "$end_date" < "$start_date" ]]; then
    echo -e "${YELLOW}End date is before start date; swapping values.${NC}"
    local tmp="$start_date"; start_date="$end_date"; end_date="$tmp"
  fi

  echo -n "Mood filter (number, range e.g. 3-7, or word; blank for any): "; read -r mood_filter_raw
  local mood_exact="" mood_min="" mood_max="" mood_text=""
  if [[ "$mood_filter_raw" =~ ^[0-9]+-[0-9]+$ ]]; then
    mood_min=${mood_filter_raw%-*}
    mood_max=${mood_filter_raw#*-}
    if (( mood_min > mood_max )); then
      local tmp="$mood_min"; mood_min="$mood_max"; mood_max="$tmp"
    fi
  elif [[ "$mood_filter_raw" =~ ^[0-9]+$ ]]; then
    mood_exact="$mood_filter_raw"
  elif [[ -n "$mood_filter_raw" ]]; then
    mood_text="$mood_filter_raw"
  fi

  echo -n "Text query (optional, matches title and body): "; read -r text_query

  local -a results
  _scan_entries_with_filters results notebooks[@] "$start_date" "$end_date" "$mood_exact" "$mood_min" "$mood_max" "$mood_text" "$text_query"

  if [[ ${#results[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No entries matched your filters.${NC}"
    press_any
    return
  fi

  local -a sorted_results
  mapfile -t sorted_results < <(printf "%s\n" "${results[@]}" | sort -r)

  local -a path_index
  while true; do
    _render_search_results sorted_results[@] path_index
    echo
    echo -n "Select entry # to view/edit/delete (0 to exit): "; read -r choice
    if [[ "$choice" == "0" ]]; then break; fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#sorted_results[@]} ]]; then
      echo "Invalid selection."; sleep 1; continue
    fi
    local selected_path="${path_index[$choice]}"
    local selected_label; selected_label=$(basename "$selected_path")
    echo -e "  ${YELLOW}1${NC}) View entry"
    echo -e "  ${YELLOW}2${NC}) Edit entry"
    echo -e "  ${YELLOW}3${NC}) Delete entry"
    echo -e "  ${YELLOW}0${NC}) Back"
    echo -n "Select action: "; read -r action
    case "$action" in
      1) editor_open "$selected_path" true ;;
      2) editor_open "$selected_path" false; echo -e "${GREEN}✔ Entry updated.${NC}"; press_any ;;
      3)
        echo -n "Delete '$selected_label'? (y/N): "; read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          if rm -f "$selected_path"; then
            echo -e "${GREEN}✔ Deleted.${NC}"
            unset "sorted_results[$((choice-1))]"
            sorted_results=("${sorted_results[@]}")
          else
            echo -e "${RED}✖ Failed to delete.${NC}"
          fi
        else
          echo "Deletion cancelled."
        fi
        press_any
        ;;
      0) ;;
      *) echo "Invalid action."; sleep 1 ;;
    esac

    if [[ ${#sorted_results[@]} -eq 0 ]]; then
      echo -e "${YELLOW}No more results.${NC}"
      press_any
      break
    fi
  done
}
