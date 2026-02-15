# CLAUDE.md

## Project Overview

**EasyEcho** is a World of Warcraft addon for the ProjectEbonhold private server (WoW 3.3.5 / Interface 30300). It automates perk/ability selection during character progression runs by choosing from offered perks based on user-defined priority and ban lists. It supports multiple profiles, rerolling, history tracking, and statistics.

## Repository Structure

```
EasyEcho/
├── CLAUDE.md
├── .gitattributes
├── EasyEcho_Addon/              # Main addon
│   ├── EasyEcho.toc             # WoW addon manifest (defines load order & saved variables)
│   ├── EasyEcho.lua             # Core bot logic: perk selection engine, profiles, event handling
│   ├── EasyEchoConfig.lua       # Configuration UI: priority/ban list management, profiles, import/export
│   └── EasyEchoUI.lua           # History & statistics UI: selection log, stats dashboard, slash commands
└── ProjectEbonhold_Addon/       # Reference copy of server-side addon modules
    └── interface/AddOns/ProjectEbonhold/modules/perks/
        ├── perks.lua            # Perk picker UI: frame rendering, animations, quality colors
        └── perks_service.lua    # Perk service API: server communication, event dispatching
```

### Load Order (defined in EasyEcho.toc)

1. `EasyEchoUI.lua` — UI framework and history display
2. `EasyEchoConfig.lua` — Configuration panel
3. `EasyEcho.lua` — Core logic (depends on UI being loaded first)

### Saved Variables (persisted between sessions)

- `EasyEchoLogDB` — Timestamped debug/decision log
- `EasyEchoHistoryDB` — Perk selection history entries
- `EasyEchoSettings` — User settings, priority lists, ban lists, profiles

## Tech Stack

- **Language:** Lua 5.1 (WoW embedded scripting)
- **Platform:** World of Warcraft 3.3.5 (WotLK) private server
- **Framework:** WoW Addon API (TOC-based addon system)
- **External dependencies:** ProjectEbonhold server addon (provides `ProjectEbonhold.Perks` service API)
- **Build system:** None — pure Lua source files deployed directly
- **Tests:** None
- **Linting/Formatting:** None configured
- **CI/CD:** None

## Architecture

### Core Selection Engine (`EasyEcho.lua`)

The perk selection follows this decision pipeline:

1. **Receive perk choices** from the ProjectEbonhold perk service via `SEND_PLAYER_PERK_CHOICE` event
2. **Delay processing** by 0.5s (configurable) using an `OnUpdate` timer to let the UI settle
3. **Check one-time perks** — perks that should only be taken once (e.g., "Immolation Aura"); picks the highest quality match
4. **Check priority list** — scans available choices against the ordered priority list; picks the highest-ranked match
5. **Check ban list** — if all choices are banned, attempt a reroll
6. **Fallback** — if no priority match, select the first non-banned choice; prefer epic quality

Key state flags:
- `isProcessing` — prevents concurrent processing of choices
- `pickerFrame` — reference to the ProjectEbonhold perk picker UI
- `currentRerolls` / `maxRerolls` — reroll tracking per run

### Profile System

Profiles store independent priority and ban lists. Users can create, switch, save, and load profiles. A default priority list with ~78 entries is provided.

### Event System

Initialization happens on `PLAYER_LOGIN`. The addon hooks into ProjectEbonhold's perk service callbacks to intercept perk choices before the player would manually select them.

### UI Architecture

- **History window** (`/ee` or `/easyecho`) — scrollable log of OPTIONS, SELECT, and REROLL events with color coding
- **Config window** (`/easyecho config`) — tabbed interface with Priority List, Ban List, and Profiles tabs
- **Statistics panel** — tracks specific perk counters (Rend, Double Strike, Epics, Rares, rerolls remaining)

## Code Conventions

### Naming

| Scope | Convention | Example |
|-------|-----------|---------|
| Global functions | `EasyEcho_PascalCase` prefix | `EasyEcho_SwitchProfile()` |
| Local functions | `camelCase` or `PascalCase` | `ProcessChoices()`, `GetExactPriorityRank()` |
| Saved variables | `EasyEchoPascalCaseDB` / `EasyEchoSettings` | `EasyEchoLogDB` |
| UI frames | `PascalCase` | `CreateHistoryFrame()` |
| Module namespaces | `EasyEcho_Config`, `EasyEcho_UI` | — |
| Constants | `UPPER_SNAKE_CASE` | `MAX_REROLLS`, `MIN_LEVEL` |

### Patterns

- **Event-driven**: All server interaction uses WoW event registration (`RegisterEvent`, `SetScript("OnEvent")`)
- **State machine**: The picker frame transitions through states (`"START_DELAY"`, `"WAIT_FOR_NEW_CARDS"`, `"LOCKED"`)
- **Frame pooling**: `perks.lua` reuses UI frames from a pool for performance
- **Timer callbacks**: `OnUpdate` handlers with elapsed time accumulation for delayed actions
- **Global namespace**: Functions and tables exposed globally with `EasyEcho_` prefix (standard WoW addon pattern)

### Language

Code comments are a mix of English and German. Keep new comments in English.

## Key APIs

### ProjectEbonhold Perk Service (`ProjectEbonhold.Perks`)

```lua
ProjectEbonhold.Perks.SelectPerk(spellId)     -- Send selection to server
ProjectEbonhold.Perks.RequestChoice()          -- Request available perks
ProjectEbonhold.Perks.RequestReroll()          -- Request a reroll
ProjectEbonhold.Perks.RequestGrantedPerks()    -- Fetch player's acquired perks
ProjectEbonhold.Perks.grantedPerks             -- Table of acquired perks (keyed by spell name)
ProjectEbonhold.Perks.currentChoice            -- Table of currently offered perk options
```

### WoW API Functions Used

- `CreateFrame()`, `CreateFontString()`, `CreateTexture()` — UI construction
- `GetSpellInfo(spellId)` — Retrieve spell name, icon, description
- `GameTooltip` — Tooltip display
- `StaticPopup_Show()` — Confirmation dialogs
- `UIParent` — Root frame for all addon UI

## In-Game Commands

| Command | Action |
|---------|--------|
| `/easyecho` | Toggle history/stats window |
| `/ee` | Toggle history/stats window (alias) |
| `/easyecho config` | Open configuration UI |

## Development Workflow

### Deployment

Copy the `EasyEcho_Addon/` folder into the WoW client's `Interface/AddOns/` directory. No build step is needed.

### Adding New Perks

1. Add entries to the default priority list in `EasyEcho.lua` (the `defaultPrioList` table)
2. Each entry is `{name = "Spell Name", quality = "Quality"}` where quality is one of: `"Common"`, `"Uncommon"`, `"Rare"`, `"Epic"`, `"Any"`
3. For one-time perks, add the spell name to the `oneTimePerks` table

### Modifying the UI

- History/stats UI: edit `EasyEchoUI.lua`
- Config panel: edit `EasyEchoConfig.lua`
- Perk picker visuals: edit `ProjectEbonhold_Addon/.../perks.lua` (server-side reference)

### Quality Tiers

The perk system uses these quality tiers (matches WoW item quality naming):
- Common (white)
- Uncommon (green)
- Rare (blue)
- Epic (purple)
- Legendary (orange) — used in perks.lua display only
- Any — wildcard match in priority lists

## Important Notes

- The `ProjectEbonhold_Addon/` directory is a reference copy of the server addon modules. Changes here do not affect the server directly.
- The addon uses a 0.5s processing delay (`PROCESS_DELAY`) to ensure the perk picker UI is fully rendered before interacting with it.
- The `isProcessing` flag prevents race conditions when multiple perk choice events arrive in quick succession.
- Reroll limits are fetched from the server via `GetServerRunData()` at runtime.
