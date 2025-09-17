#!/usr/bin/env bash
# Use cases: notebook management (list, switch, create, delete)

notebooks_list() {
  mapfile -t _LISTED_NOTEBOOKS < <(notebook_list_all)
  if [[ ${#_LISTED_NOTEBOOKS[@]} -eq 0 ]]; then
    echo "No notebooks found."; return 1
  fi
  local idx=0
  for nb_name in "${_LISTED_NOTEBOOKS[@]}"; do
    ((idx++))
    if [[ "$nb_name" == "$ACTIVE_NOTEBOOK_NAME" ]]; then
      printf "  ${GREEN}%d) %s (Active)${NC}\n" "$idx" "$nb_name"
    else
      printf "  %d) %s\n" "$idx" "$nb_name"
    fi
  done
  return 0
}

usecase_switch_notebook() {
  init_dir
  echo -e "\n${CYAN}Available Notebooks:${NC}"
  notebooks_list || { press_any; return; }
  if [[ ${#_LISTED_NOTEBOOKS[@]} -le 1 && "${_LISTED_NOTEBOOKS[0]}" == "$ACTIVE_NOTEBOOK_NAME" ]]; then
    echo -e "\nOnly the current notebook ('$ACTIVE_NOTEBOOK_NAME') exists."; press_any; return
  fi
  echo -n "Enter number to switch (or 0 to cancel): "; read -r choice
  if [[ "$choice" -eq 0 ]]; then echo "Switch cancelled."; press_any; return; fi
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#_LISTED_NOTEBOOKS[@]} ]]; then
    echo "Invalid selection."; press_any; return
  fi
  local selected_notebook_name="${_LISTED_NOTEBOOKS[$((choice-1))]}"
  if [[ "$selected_notebook_name" == "$ACTIVE_NOTEBOOK_NAME" ]]; then
    echo "Notebook '$selected_notebook_name' is already active."
  else
    ACTIVE_NOTEBOOK_NAME="$selected_notebook_name"
    ACTIVE_NOTEBOOK_PATH="$JOURNAL_DIR_BASE/$ACTIVE_NOTEBOOK_NAME"
    echo "$ACTIVE_NOTEBOOK_NAME" > "$ACTIVE_NOTEBOOK_CONFIG_FILE"
    echo -e "${GREEN}Switched to notebook: $ACTIVE_NOTEBOOK_NAME${NC}"
  fi
  press_any
}

usecase_create_notebook() {
  init_dir
  echo -e "\n${CYAN}Create New Notebook${NC}"
  echo -n "Enter name for the new notebook: "; read -r new_notebook_name
  if [[ -z "$new_notebook_name" ]]; then echo -e "${RED}Notebook name cannot be empty.${NC}"; press_any; return; fi
  if [[ -d "$JOURNAL_DIR_BASE/$new_notebook_name" ]]; then echo -e "${YELLOW}Notebook named '$new_notebook_name' already exists.${NC}"; press_any; return; fi
  if mkdir "$JOURNAL_DIR_BASE/$new_notebook_name"; then
    echo -e "${GREEN}Notebook '$new_notebook_name' created successfully.${NC}"
    echo -n "Switch to '$new_notebook_name' now? (y/N): "; read -r switch_choice
    if [[ "$switch_choice" =~ ^[Yy]$ ]]; then
      ACTIVE_NOTEBOOK_NAME="$new_notebook_name"
      ACTIVE_NOTEBOOK_PATH="$JOURNAL_DIR_BASE/$ACTIVE_NOTEBOOK_NAME"
      echo "$ACTIVE_NOTEBOOK_NAME" > "$ACTIVE_NOTEBOOK_CONFIG_FILE"
      echo -e "${GREEN}Switched to notebook: $ACTIVE_NOTEBOOK_NAME${NC}"
    fi
  else
    echo -e "${RED}Failed to create notebook '$new_notebook_name'.${NC}"
  fi
  press_any
}

usecase_delete_notebook() {
  init_dir
  echo -e "\n${CYAN}Available Notebooks:${NC}"
  notebooks_list || { press_any; return; }
  if [[ ${#_LISTED_NOTEBOOKS[@]} -eq 1 ]]; then echo -e "\n${YELLOW}Cannot delete the only existing notebook.${NC}"; press_any; return; fi
  echo -n "Enter number of notebook to delete (or 0 to cancel): "; read -r choice
  if [[ "$choice" -eq 0 ]]; then echo "Deletion cancelled."; press_any; return; fi
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#_LISTED_NOTEBOOKS[@]} ]]; then echo "Invalid selection."; press_any; return; fi
  local notebook_to_delete="${_LISTED_NOTEBOOKS[$((choice-1))]}"
  echo -ne "\n${RED}Permanently delete notebook '${YELLOW}$notebook_to_delete${RED}' and all its entries?${NC} (y/N): "
  read -r confirm_delete
  if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
    local notebook_path_to_delete="$JOURNAL_DIR_BASE/$notebook_to_delete"
    if rm -rf "$notebook_path_to_delete"; then
      echo -e "${GREEN}✔ Notebook '$notebook_to_delete' was deleted.${NC}"
      if [[ "$notebook_to_delete" == "$ACTIVE_NOTEBOOK_NAME" ]]; then
        echo "The active notebook was deleted. Re-initializing..."
        init_dir
        echo -e "${GREEN}Switched to new active notebook: $ACTIVE_NOTEBOOK_NAME${NC}"
      fi
    else
      echo -e "${RED}✖ Failed to delete notebook directory.${NC}"
    fi
  else
    echo "Deletion cancelled."
  fi
  press_any
}
