# CLAUDE.md — EasyEcho

## Project Overview

EasyEcho is a World of Warcraft addon for **Project Ebonhold** that automates perk selection during gameplay. It chooses perks based on user-defined priority lists, manages rerolls, tracks one-time perks, supports ban lists, and provides a profile system for multiple configurations.

## Repository Structure

```
EasyEcho/
├── EasyEcho.toc          # Addon manifest (load order, saved variables, interface version)
├── EasyEcho.lua          # Core automation logic (decision engine, state machine, hooks)
├── EasyEchoConfig.lua    # Configuration UI (priority list, ban list, profile management)
├── EasyEchoUI.lua        # History display and statistics UI
├── .gitattributes        # Git line-ending normalization
└── CLAUDE.md             # This file
```

**File load order** (defined in `.toc`): `EasyEchoUI.lua` → `EasyEchoConfig.lua` → `EasyEcho.lua`

## Tech Stack

- **Language**: Lua 5.1 (WoW scripting environment)
- **Platform**: World of Warcraft client via Project Ebonhold
- **UI Framework**: WoW built-in Lua frame API (`CreateFrame`, widget scripting)
- **Game API**: `ProjectEbonhold.PerkService`, `ProjectEbonhold.PerkUI`
- **No external dependencies** — pure Lua with WoW/Ebonhold APIs

## Architecture

### Three-Module Design

| Module | File | Responsibility |
|--------|------|----------------|
| **Core** | `EasyEcho.lua` | Perk decision engine, state machine, event hooks |
| **Config** | `EasyEchoConfig.lua` | Settings UI with three tabs (Priority, Ban, Profiles) |
| **History** | `EasyEchoUI.lua` | History log display, statistics, slash commands |

### Perk Selection Algorithm

The core decision logic in `ProcessChoices()` follows this priority:

1. **Priority List match** — pick the highest-ranked perk from the user's list
2. **One-Time perk match** — pick the highest-quality one-time perk not yet learned
3. **Ban check** — if all options are banned, attempt a reroll
4. **Fallback** — select the leftmost/highest-quality available perk

### State Machine

The perk picker uses three states:
- `START_DELAY` — brief delay before processing
- `WAIT_FOR_NEW_CARDS` — waiting for perk offers to appear
- `LOCKED` — selection complete, no further action

### Event Flow

1. `PLAYER_LOGIN` event initializes settings and UI
2. `hooksecurefunc` on `ProjectEbonhold.PerkUI.Show` triggers the picker
3. `OnUpdate` frame handler drives the state machine with `DELAY_TIME = 0.5s` intervals

### Global Data Structures

```lua
EasyEchoSettings = {
    Profiles = { [name] = { PriorityList, BanList } },
    ActiveProfile = "Default",
    PriorityList = { { Name = "...", Quality = "..." }, ... },
    BanList = { { Name = "...", Quality = "..." }, ... },
    CurrentPickCount = 2
}

EasyEchoLogDB = {}       -- Event log (capped at 2000 entries)
EasyEchoHistoryDB = {}   -- Perk selection history
```

### Key Constants

- `MAX_REROLLS_PER_CHOICE = 10`
- `MIN_LEVEL_FOR_REROLL = 11`
- `DELAY_TIME = 0.5`
- Quality levels: Common, Uncommon, Rare, Epic

### Exported Global Functions

```lua
EasyEcho_SwitchProfile(profileName)
EasyEcho_ResetPrioToDefault()
EasyEcho_Config.Toggle()
EasyEcho_Config.Refresh()
EasyEcho_UI.Toggle()
EasyEcho_UI.UpdateRerollStatus(used, total)
EasyEcho_UI.AddSelectToHistory(name, quality, reason)
EasyEcho_UI.AddRerollToHistory(reason)
EasyEcho_UI.AddOptionsToHistory(options)
```

## Coding Conventions

- **Perk entries** are stored as tables with `Name` and `Quality` fields (e.g., `{ Name = "Rend the Weak", Quality = "Rare" }`)
- **String identifiers** use `"Name::Quality"` format for lookups and comparisons
- **Section comments** divide each file into logical blocks (e.g., `-- === CONFIGURATION ===`)
- **UI frames** are created lazily on first use, not at addon load time
- **Logging** uses `WriteToLog()` with timestamps; log is capped at 2000 entries
- **Saved variables** are declared in the `.toc` file and persisted by the WoW client between sessions
- **No semicolons** — standard Lua style without trailing semicolons
- **Local scope** preferred; globals used only for cross-file communication and saved variables

## Build and Testing

- **No build step** — Lua files are loaded directly by the WoW client in the order specified by the `.toc` file
- **No automated tests** — testing is done manually in-game
- **No linter or formatter** configured
- **No CI/CD pipeline**

### Slash Commands

- `/easyecho` or `/ee` — toggle the history/statistics UI

## Development Workflow

1. Edit `.lua` files directly
2. Reload the WoW client or use `/reload` in-game to pick up changes
3. Test perk selection behavior manually in-game
4. Check `EasyEchoLogDB` saved variable for debugging decision logs

## Important Notes for AI Assistants

- The `.toc` file controls load order — if adding new files, they must be listed there
- `SavedVariables` in the `.toc` must match the global variable names used in code
- The `DEFAULT_PRIO` table in `EasyEcho.lua` contains 77 default perk entries — preserve this list carefully when editing
- The `ONE_TIME_ONLY_LIST` contains perks that should only be selected once per character
- UI code relies heavily on WoW's `CreateFrame` API — standard HTML/CSS patterns do not apply
- All three files share state through global variables (`EasyEchoSettings`, `EasyEchoLogDB`, `EasyEchoHistoryDB`)
- The `hooksecurefunc` call is the primary entry point for automation — it triggers when the perk selection UI opens
