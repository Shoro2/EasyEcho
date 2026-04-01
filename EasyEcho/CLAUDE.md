# CLAUDE.md

## Project Overview

**EasyEcho** is a World of Warcraft addon for the ProjectEbonhold private server (WoW 3.3.5a / Interface 30300). It automates perk ("echo") selection during character progression runs by choosing from offered perks based on user-defined priority and ban lists. It supports multiple profiles, rerolling, history tracking, statistics, and a complete echo catalog powered by the `ProjectEbonhold.PerkDatabase` API.

## Repository Structure

```
EasyEcho/
├── CLAUDE.md
├── .gitattributes
├── EasyEcho_Addon/              # Main addon (deploy this folder)
│   ├── EasyEcho.toc             # WoW addon manifest (defines load order & saved variables)
│   ├── EasyEchoUI.lua           # All UI frames: history, stats, granted echoes, echo database (~2,600 lines)
│   ├── EasyEchoConfig.lua       # Configuration UI: priority/ban list management, profiles, import/export
│   ├── EasyEchoCore.lua         # Constants, shared state, profile management, helpers
│   ├── EasyEchoEngine.lua       # Selection engine and picker frame state machine
│   ├── EasyEchoHooks.lua        # Hooks for Start / Accept Death buttons
│   └── EasyEcho_Main.lua        # Event dispatcher (PLAYER_LOGIN, PLAYER_DEAD, PLAYER_ALIVE, PLAYER_LEVEL_UP)
└── ProjectEbonhold_Addon/       # Reference copy of server-side addon modules
    └── interface/AddOns/ProjectEbonhold/modules/
        ├── perks/
        │   ├── perks.lua            # Perk picker UI: frame rendering, animations, quality colors
        │   ├── perks_service.lua    # Perk service API: server communication, event dispatching
        │   ├── perks_data.lua       # PerkDatabase: complete echo catalog (~480 spells with metadata)
        │   └── perks_browser.lua    # Echo browser UI with search, class filter, quality filter
        ├── playerRun/
        │   ├── player_run_service.lua
        │   ├── player_run_ui.lua
        │   └── deathFrame.lua
        ├── shop/
        │   └── shop.lua
        └── voidStorage/
            └── voidStorage_service.lua
```

### Load Order (defined in EasyEcho.toc)

| # | File | Purpose |
|---|------|---------|
| 1 | `EasyEchoUI.lua` | All UI frame definitions and rendering |
| 2 | `EasyEchoConfig.lua` | Configuration panel (priority/ban lists, profiles) |
| 3 | `EasyEchoCore.lua` | Constants, shared state, profile management |
| 4 | `EasyEchoEngine.lua` | Selection engine and state machine |
| 5 | `EasyEchoHooks.lua` | Hooks for Start / Accept Death buttons |
| 6 | `EasyEcho_Main.lua` | Event dispatcher |

`EasyEchoCore.lua` must be loaded before `EasyEchoEngine.lua` and `EasyEcho_Main.lua` — do not reorder them.

### Saved Variables (persisted between sessions)

- `EasyEchoLogDB` — Timestamped debug/decision log (capped at ~2000 entries)
- `EasyEchoHistoryDB` — Perk selection history entries (OPTIONS, SELECT, REROLL)
- `EasyEchoSettings` — User settings, priority lists, ban lists, profiles, character-specific profile memory
- ~~`EasyEchoEchoDB`~~ — *Removed:* Echo catalog now provided by `ProjectEbonhold.PerkDatabase` API

## Tech Stack

- **Language:** Lua 5.1 (WoW embedded scripting)
- **Platform:** World of Warcraft 3.3.5a (WotLK) private server
- **Framework:** WoW Addon API (TOC-based addon system)
- **External dependencies:** ProjectEbonhold server addon (provides `ProjectEbonhold.PerkService`, `ProjectEbonhold.PlayerRunService`, and `ProjectEbonhold.PerkDatabase`)
- **Build system:** None — pure Lua source files deployed directly
- **Tests:** None
- **Linting/Formatting:** None configured
- **CI/CD:** None

## Architecture

### Module Namespaces

| Namespace | Defined in | Purpose |
|-----------|-----------|---------|
| `EasyEcho` | all files | Root table; owns sub-namespaces |
| `EasyEcho.Constants` (`C`) | `EasyEchoCore.lua` | Tunable constants (`DELAY_TIME`, etc.) |
| `EasyEcho.State` (`S`) | `EasyEchoCore.lua` | Runtime state: frames, flags, counters |
| `EasyEcho.Engine` | `EasyEchoEngine.lua` | Selection logic and state machine functions |
| `EasyEcho.Hooks` | `EasyEchoHooks.lua` | Button-hooking logic |
| `EasyEcho_UI` | `EasyEchoUI.lua` | UI rendering and update functions |
| `EasyEcho_Config` | `EasyEchoConfig.lua` | Config panel rendering and refresh |

### Core Selection Engine (`EasyEchoEngine.lua`)

The perk selection follows this decision pipeline inside `ProcessChoices()`:

1. **Get choices** — `ProjectEbonhold.PerkService.GetCurrentChoice()`
2. **Log OPTIONS** — record offered choices in history (once per pick counter)
3. **Priority match** (`CheckPriority()`):
   - Skips banned perks (`EasyEcho.IsBanned()`)
   - Skips one-time perks already granted (`EasyEcho.ONE_TIME_MAP` + `EasyEcho.PlayerAlreadyHasPerk()`)
   - Finds highest-priority entry matching any offered perk (`Name::Quality` or `Name::Any`)
   - If match found → select it
4. **All banned** — if every offered perk is on the ban list → attempt reroll
5. **No priority match** — no offered perk matches the priority list → attempt reroll
6. **Reroll unavailable** — pick the left-most non-banned option as final fallback

**State machine states** (picker frame `OnUpdate`):

| State | Description |
|-------|-------------|
| `START_DELAY` | Waiting for initial render delay (`C.DELAY_TIME`) |
| `PROCESSING` | Running the decision pipeline |
| `WAIT_FOR_NEW_CARDS` | Detecting new offers after a reroll |
| `LOCKED` | Waiting for server to confirm selection |

Key state flags (in `EasyEcho.State`):
- `isProcessing` — prevents concurrent processing of choices
- `isAutoStopped` — set when the engine auto-halts (e.g., at level 80)
- `pendingDeathReset` — tracks whether a death reset is pending confirmation
- `currentRerolls` — reroll count for the current picker event
- `pickerFrame` — the OnUpdate frame driving the state machine

### Profile System (`EasyEchoCore.lua`)

Profiles store independent priority and ban lists. `EasyEchoSettings.CharacterProfiles` maps each character (name + realm key) to their last-used profile, restored silently on `PLAYER_LOGIN`.

Key functions:
- `EasyEcho.InitializeSettings()` — initializes SavedVars and loads the active profile
- `EasyEcho_SwitchProfile(name, silent)` — activates a profile and saves character preference
- `EasyEcho_ResetPrioToDefault()` — resets active profile's priority list to `EasyEcho.DEFAULT_PRIO`
- `EasyEcho_Start()` / `EasyEcho_Stop()` / `EasyEcho_ToggleRunning()` — bot start/stop

### Event System (`EasyEcho_Main.lua`)

Handles WoW events on a single `eventFrame`:

| Event | Action |
|-------|--------|
| `PLAYER_LOGIN` | Initialize settings, restore character profile, init UI, hook Start buttons |
| `PLAYER_DEAD` | Mark pending death reset; hook Accept Death buttons |
| `PLAYER_ALIVE` | Confirm or cancel death reset; sync reroll status |
| `PLAYER_LEVEL_UP` | Refresh echoes UI; check auto-stop at level 80 |

### UI Architecture (`EasyEchoUI.lua`)

The main window (`/ee` or `/easyecho`) has three tabs:
- **History** — scrollable OPTIONS/SELECT/REROLL log with right-click context menu
- **Stats** — tracked spells, epic/rare counters, live reroll display
- **Granted Echoes** — list of currently owned perks with quality summary popup

**Echo Database** — complete catalog of all echoes, searchable and sortable. Data comes from `ProjectEbonhold.PerkDatabase` API (no longer self-built).

All windows are movable and resizable (Shift+drag corner handles). The addon remembers which windows were open per character.

## Code Conventions

### Naming

| Scope | Convention | Example |
|-------|-----------|---------|
| Global functions | `EasyEcho_PascalCase` | `EasyEcho_SwitchProfile()` |
| Module functions | `EasyEcho.Namespace.FunctionName` | `EasyEcho.Engine.CheckAutoStopAtMaxLevel()` |
| Local functions | `PascalCase` or `camelCase` | `CheckPriority()`, `GetExactPriorityRank()` |
| Saved variables | `EasyEchoPascalCaseDB` / `EasyEchoSettings` | `EasyEchoLogDB` |
| UI frames | `PascalCase` | `EasyEchoGrantedEchoesFrame` |
| Module namespaces | `EasyEcho_Config`, `EasyEcho_UI` | — |
| Constants table | `EasyEcho.Constants` (aliased as `C`) | `C.DELAY_TIME` |
| State table | `EasyEcho.State` (aliased as `S`) | `S.isProcessing` |

### Patterns

- **Event-driven**: All server interaction uses WoW event registration (`RegisterEvent`, `SetScript("OnEvent")`)
- **State machine**: The picker frame transitions through states (`"START_DELAY"`, `"PROCESSING"`, `"WAIT_FOR_NEW_CARDS"`, `"LOCKED"`)
- **Timer callbacks**: `OnUpdate` handlers with elapsed time accumulation for delayed actions
- **Global namespace**: Functions exposed globally with `EasyEcho_` prefix (standard WoW addon pattern)
- **SavedVars nil-safety**: Always use `X = X or default` patterns when reading settings that may not exist in older save files

### Language

Code comments are a mix of English and German. Keep new comments in English.

## Key APIs

### ProjectEbonhold Perk Service (`ProjectEbonhold.PerkService`)

```lua
ProjectEbonhold.PerkService.SelectPerk(spellId)       -- Send selection to server
ProjectEbonhold.PerkService.RequestReroll()            -- Request a reroll
ProjectEbonhold.PerkService.GetCurrentChoice()         -- Table of currently offered perk options
ProjectEbonhold.PerkService.GetGrantedPerks()          -- Table of player's acquired perks
```

### ProjectEbonhold Player Run Service (`ProjectEbonhold.PlayerRunService`)

```lua
ProjectEbonhold.PlayerRunService.GetCurrentData()      -- Returns {usedRerolls, totalRerolls, ...}
```

### WoW API Functions Used

- `CreateFrame()`, `CreateFontString()`, `CreateTexture()` — UI construction
- `GetSpellInfo(spellId)` — Retrieve spell name, icon, description
- `UnitLevel("player")` — Player level checks
- `UnitName("player")`, `GetRealmName()` — Character identity for profile keys
- `GameTooltip` — Tooltip display
- `StaticPopup_Show()` — Confirmation dialogs
- `UIParent` — Root frame for all addon UI
- `hooksecurefunc()` — Non-destructive function hooking

## In-Game Commands

| Command | Action |
|---------|--------|
| `/easyecho` or `/ee` | Toggle main window (History / Stats / Echoes) |
| `/easyecho config` | Open configuration UI |
| `/easyecho start` | Start auto-selection |
| `/easyecho stop` | Stop auto-selection (manual mode) |
| `/easyecho toggle` | Toggle start / stop |

## Configuration Reference

### Constants (in `EasyEchoCore.lua`)

| Constant | Default | Description |
|----------|---------|-------------|
| `C.DELAY_TIME` | `0.5s` | Wait after perk frame appears before evaluating (overridden by `EasyEchoSettings.TickSpeed`) |
| `C.MIN_LEVEL_FOR_REROLL` | `11` | Minimum pick counter before rerolls are attempted |
| `C.MAX_REROLLS_PER_CHOICE` | `10` | Local cap on rerolls per single choice event |

### Settings Keys (in `EasyEchoSettings`)

| Key | Default | Description |
|-----|---------|-------------|
| `TickSpeed` | `0.5` | Processing delay in seconds (applied to `C.DELAY_TIME` at login) |
| `AutoResetLogOnDeath` | `false` | If true, reset run data immediately on `PLAYER_DEAD` |
| `AutoOpenSummaryAt80` | `false` | If true, auto-show main window when reaching level 80 |
| `IncludeLockedEchoes` | `true` | Include class-locked echoes in echo database display |
| `CharacterProfiles` | `{}` | Map of `"Name-Realm"` → profile name |
| `ActiveProfile` | `"Default"` | Currently active profile name |
| `CurrentPickCount` | `2` | Sequential pick counter for the current run |

### Priority List Format

```
Spell Name::Quality
```

Supported qualities: `Common`, `Uncommon`, `Rare`, `Epic`, `Any`

`Any` matches regardless of offered quality.

### Ban List Format

Spell name only, no quality suffix. Matched case-insensitively.

### One-Time Perks

Defined in `EasyEchoCore.lua` as `EasyEcho.ONE_TIME_ONLY_LIST` (format: `"Spell Name::Any"`). Built into a lowercase lookup map `EasyEcho.ONE_TIME_MAP` at load time. If a perk is in this list and the player already has it, it is skipped automatically — no manual configuration needed.

## Development Workflow

### Deployment

Copy the `EasyEcho_Addon/` folder into the WoW client's `Interface/AddOns/EasyEcho/` directory. No build step is needed.

### Adding New Perks to the Default Priority List

1. Add entries to `EasyEcho.DEFAULT_PRIO` in `EasyEchoCore.lua`
2. Each entry is a string: `"Spell Name::Quality"` where quality is one of `Common`, `Uncommon`, `Rare`, `Epic`, `Any`
3. For one-time perks, also add the entry to `EasyEcho.ONE_TIME_ONLY_LIST`

### Modifying the UI

- History/stats/echoes UI: edit `EasyEchoUI.lua`
- Config panel: edit `EasyEchoConfig.lua`
- Perk picker visuals: edit `ProjectEbonhold_Addon/.../perks.lua` (server-side reference only)

### Quality Tiers

| Quality | Color |
|---------|-------|
| Common | White |
| Uncommon | Green |
| Rare | Blue |
| Epic | Purple |
| Legendary | Orange (display only, in `perks.lua`) |
| Any | Wildcard match in priority/one-time lists |

## Important Notes

- `ProjectEbonhold_Addon/` is a **reference copy** only. Changes here do not affect the server.
- `EasyEchoCore.lua` must initialize before `EasyEchoEngine.lua` and `EasyEcho_Main.lua`. Do not reorder the TOC load order.
- `C.DELAY_TIME` is set at login from `EasyEchoSettings.TickSpeed`; modifying the constant directly after login has no effect until the next session.
- The `isProcessing` flag prevents race conditions when multiple perk choice events arrive in quick succession.
- Reroll limits are fetched from the server via `EasyEcho.GetServerRunData()` which calls `ProjectEbonhold.PlayerRunService.GetCurrentData()`.
- Some hook/reset helpers exist in more than one file (noted in README). Maintenance requires updating both copies.
- `EasyEchoUI.lua` uses reusable row frames for performance. Be careful when adding new row types.
