# EasyEcho

**EasyEcho** is a World of Warcraft addon for the **ProjectEbonhold** private server (**WotLK 3.3.5a / Interface 30300**).  
It automates perk (“Echo”) selection during progression runs by choosing from the offered perks using a **priority list** and a **ban list** (with profile support, rerolls, history, and stats).

---

## What it does

When the server offers 3 perk choices, EasyEcho will:

1. Wait a short, configurable delay so the perk UI is fully rendered.
2. Pick the best matching option from your **Priority List** (top to bottom).
3. Skip anything on your **Ban List**.
4. Respect **one-time perks** (only take them once if already granted).
5. If there is no good match, it will **reroll** (if available), otherwise fall back to the left-most option.

---

## Features

- **Auto-selection engine**
  - Priority matching supports `Spell Name::Quality` and `Spell Name::Any` wildcard
  - Ban list blocks perks by **spell name** (case-insensitive)
  - One-time perks are skipped once already acquired
  - Reroll logic with both **local** and **server** limits

- **Profiles**
  - Multiple profiles, each with its own Priority and Ban lists
  - Switch profiles from the config UI (and in code via `EasyEcho_SwitchProfile()`)

- **UI**
  - History log: OPTIONS / SELECT / REROLL entries, including pick number (“level count”)
  - Stats panel: two tracked spells (defaults: *Rend the Weak* and *Double Strike*), epic/rare counters, rerolls left
  - Echo catalog: persistent database of discovered echoes (name, tooltip, qualities, first/last seen, class), with search/sort

- **Run safety**
  - Attempts to detect “Accept Death” clicks and resets internal run state
  - Auto-stops at level 80 if the server no longer offers echoes

---

## Requirements

- WoW client **3.3.5a** (TOC: `Interface: 30300`)
- ProjectEbonhold server addon API available (EasyEcho talks to these globals):
  - `ProjectEbonhold.PerkService` (request choice, select perk, request reroll, granted perks)
  - `ProjectEbonhold.PlayerRunService` (reroll counters: used/total)

> This repo may include a **reference copy** of ProjectEbonhold modules (e.g. `perks.lua`, `perks_service.lua`, `player_run_service.lua`, etc.). On the actual server, those are usually provided by ProjectEbonhold itself.

---

## Installation

1. Copy the addon folder into your WoW client:
   - `World of Warcraft/Interface/AddOns/EasyEcho/`

2. Start WoW and enable the addon in the AddOns list.

**Load order** (from `EasyEcho.toc`):
1. `EasyEchoUI.lua`
2. `EasyEchoConfig.lua`
3. `EasyEcho.lua`

---

## In-game commands

- `/easyecho` or `/ee`  
  Toggle the main UI (history/stats)

- `/easyecho config`  
  Open the configuration UI

- `/easyecho start`  
  Start auto-selection

- `/easyecho stop`  
  Stop auto-selection (manual mode)

- `/easyecho toggle`  
  Toggle start/stop

---

## Configuration

### Priority List format

Priority entries are strings in this format:

- `Spell Name::Quality`

Supported qualities (as used by the addon):

- `Common`, `Uncommon`, `Rare`, `Epic`, `Any`

`Any` matches regardless of the offered quality.

Example:
- `Rend the Weak::Rare`
- `Double Strike::Uncommon`
- `Immolation Aura::Any`

### Ban List format

Ban entries are **spell names only** (no `::Quality`), compared case-insensitively.

Example:
- `Some Bad Perk`
- `Another Perk`

### One-time perks

Defined in `EasyEcho.lua` as `ONE_TIME_ONLY_LIST`.  
If a perk is in that list and the player already has it (checked via `ProjectEbonhold.PerkService.GetGrantedPerks()`), EasyEcho will skip it.

### Import/Export

The config UI supports copying lists in/out as plain text (line-based).  
Profiles store independent lists.

---

## How the selection works (actual code logic)

Core logic is in `EasyEcho.lua`:

- Constants:
  - `DELAY_TIME` (default **0.5s**)
  - `MIN_LEVEL_FOR_REROLL` (default **11** — note: internally this is a *pick counter*, not necessarily your real character level)
  - `MAX_REROLLS_PER_CHOICE` (default **10**)

Decision pipeline inside `ProcessChoices()`:

1. Get current choice: `ProjectEbonhold.PerkService.GetCurrentChoice()`
2. Log the offered options to history **once per pick counter**
3. Try priority match (`CheckPriority()`):
   - Skips banned perks
   - Skips one-time perks already granted
   - Uses exact rank match (`GetExactPriorityRank()`): `Name::Quality` or `Name::Any`
4. If all options are banned, attempt reroll
5. If no priority match, attempt reroll
6. If no reroll possible, pick the left-most option

Reroll availability is checked via:
- local per-choice cap (`MAX_REROLLS_PER_CHOICE`)
- server caps from `ProjectEbonhold.PlayerRunService.GetCurrentData()` (`usedRerolls`, `totalRerolls`)

---

## Saved Variables

Defined in `EasyEcho.toc`:

- `EasyEchoLogDB` — timestamped debug/decision log (capped to ~2000 entries)
- `EasyEchoHistoryDB` — history entries (OPTIONS / SELECT / REROLL)
- `EasyEchoSettings` — profiles, active profile, priority/ban lists, tracked spells, current pick counter
- `EasyEchoEchoDB` — persistent echo catalog (discovered echoes with tooltip, qualities, first/last seen, class)

---

## Repository structure (as described in `CLAUDE.md`)

Typical layout:

Typical layout:

EasyEcho/
├── EasyEcho_Addon/ # Main addon
│ ├── EasyEcho.toc
│ ├── EasyEcho.lua
│ ├── EasyEchoConfig.lua
│ └── EasyEchoUI.lua
└── ProjectEbonhold_Addon/ # Reference copy of server addon modules
└── .../modules/perks/
├── perks.lua
└── perks_service.lua


(Your repo may include additional reference modules like `player_run_service.lua`, `player_run_ui.lua`, and `deathFrame.lua`.)

---

## Development notes (no sugar-coating)

- The codebase contains **duplicated helper functions** (e.g. some hook/reset helpers exist twice). It works, but it makes maintenance harder.
- Initialization relies on SavedVariables being present/created in the right order. If you refactor, be careful to initialize `EasyEchoSettings` before calling code that expects it.

---

## License

No license file is included. If you plan to publish this repo, add a `LICENSE` (MIT / Apache-2.0 / GPL, etc.) so the legal status is unambiguous.
