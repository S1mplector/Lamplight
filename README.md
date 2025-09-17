# Lamplight

A light-weight Bash journal & mood tracker.

## Goals

- Separate concerns across configuration, domain, use cases, infrastructure (UI/editor), and interface (CLI)
- Maintain a single entrypoint: `bin/lamplight`
- Migrate functionality incrementally while keeping the app runnable

## Architecture (Clean-ish in Bash)

- `bin/`
  - `lamplight` — entrypoint; loads modules and starts the app
- `lib/`
  - `config.sh` — configuration, constants, init
  - `domain/` — pure logic: entry formatting, notebook helpers
  - `usecase/` — orchestrations: create/list/edit entries, mood stats, notebook management
  - `infrastructure/` — IO and environment: TUI helpers, editor
  - `interface/cli/` — CLI wiring (menus)

## Migration plan

1. Scaffold (this commit): repo structure, entrypoint, shims
2. Extract config/init from `journal.sh` into `lib/config.sh` and use from CLI
3. Extract TUI UI and live editor into `lib/infrastructure/`
4. Extract domain helpers (entry/notebook)
5. Extract use cases and rewire the menu in `interface/cli/menu.sh`
6. Remove legacy `journal.sh` dependence once all features are migrated

## Usage

- Run with:

```bash
bash bin/lamplight
```

- During migration, the entrypoint will fall back to `journal.sh`.
