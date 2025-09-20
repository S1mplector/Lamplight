# Lamplight

Your terminal-native journal and mood tracker. Fast, minimal, and keyboard-driven.

Lamplight lets you capture daily thoughts, track mood over time, and organize entries in notebooks — all from a beautiful TUI that runs anywhere Bash runs.

![Lamplight main interface](lib/docs/images/main_interface.png)

## What you can do

- **Capture entries quickly**
  - One-key “New entry” flow with a lightweight live editor (no external editor required)
  - Auto-stamped headers: date, mood, optional title

- **Track your mood**
  - Enter free text or a numeric mood (1–10)
  - **Mood stats** summarize your distribution at a glance

- **Organize with notebooks**
  - Create, switch, and delete notebooks to separate themes/projects
  - Active notebook is remembered between sessions

- **Manage past entries**
  - List entries with date, mood, and title
  - View, edit, or delete any entry from the TUI

- **Polished terminal UI**
  - Flicker-free header with subtle animation
  - Clear keyboard hints and responsive menus

## Quick start

Requirements: Bash (macOS/Linux), a standard terminal, and basic POSIX tools.

Run the app:

```bash
bash bin/lamplight
```

Keyboard basics:

- In menus: press the number key to choose
- In editor: arrows to move, Enter for newline, Backspace to delete, Ctrl+D to save and finish

Your data lives under `~/JournalEntries/` (organized by notebook).

## Project structure

- `bin/`
  - `lamplight` — single entrypoint; loads modules and starts the app
- `lib/`
  - `config.sh` — configuration, constants, initialization
  - `domain/` — pure logic: entry formatting, notebook helpers
  - `usecase/` — orchestrations: create/list/edit entries, mood stats, notebook management
  - `infrastructure/` — IO and environment: TUI helpers, live editor
  - `interface/cli/` — CLI wiring (menus)
- `journal.sh` — legacy monolithic script (kept for compatibility during migration)

## Notes

- Lamplight remembers your currently active notebook (`~/.simjournal_active_notebook`).
- If the modular entrypoint is unavailable, the app can fall back to the legacy flow to keep things running.

## Roadmap (high-level)

- Richer search/filter over entries
- Export/import utilities
- Optional external-editor integration
