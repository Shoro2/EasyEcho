# EasyEcho

**EasyEcho** is a World of Warcraft addon for the **ProjectEbonhold** private server (**WotLK 3.3.5a / Interface 30300**).
It automates perk ("Echo") selection during progression runs by choosing from the offered perks using a **priority list** and a **ban list** — with full profile support, reroll logic, history tracking, statistics, and a persistent echo catalog.

---

## Table of Contents

1. [What it does](#what-it-does)
2. [Features](#features)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [In-game Commands](#in-game-commands)
6. [Detailed Guide](#detailed-guide)
   - [Main Window (History / Stats / Echoes)](#main-window-history--stats--echoes)
   - [Configuration Window](#configuration-window)
7. [Configuration Reference](#configuration-reference)
8. [Selection Logic](#selection-logic)
9. [Saved Variables](#saved-variables)
10. [Repository Structure](#repository-structure)
11. [Development Notes](#development-notes)
12. [License](#license)

---

## What it does

When the server offers 3 perk choices, EasyEcho will:

1. Wait a short, configurable delay so the perk UI is fully rendered.
2. Pick the best matching option from your **Priority List** (top to bottom).
3. Skip anything on your **Ban List**.
4. Respect **one-time perks** — skip them if already granted.
5. If there is no good match, **reroll** (if available), otherwise fall back to the left-most non-banned option.

---

## Features

- **Auto-selection engine**
  - Priority matching supports `Spell Name::Quality` and `Spell Name::Any` wildcard
  - Ban list blocks perks by spell name (case-insensitive)
  - One-time perks are skipped once already acquired
  - Reroll logic with both local and server-side limits

- **Profiles**
  - Multiple profiles, each with its own Priority and Ban lists
  - Per-character profile memory — each character remembers its last-used profile
  - Switch profiles from the Config UI

- **UI**
  - History log with OPTIONS / SELECT / REROLL entries, right-click context menu, icon tooltips
  - Stats panel: two tracked spells, epic/rare counters, live reroll display, percentage calculations
  - Granted Echoes view: list of currently owned perks with quality summary popup
  - Echo catalog: persistent database of all discovered echoes, searchable and sortable
  - **All windows are resizable** via Shift+drag on corner handles
  - **UI toggle button** with last-open-window memory per character

- **Run safety**
  - Detects "Accept Death" clicks and resets internal run state
  - Auto-stops at level 80 if the server no longer offers echoes

---

## Requirements

- WoW client **3.3.5a** (TOC: `Interface: 30300`)
- ProjectEbonhold server addon API:
  - `ProjectEbonhold.PerkService` — request choice, select perk, request reroll, granted perks
  - `ProjectEbonhold.PlayerRunService` — reroll counters (used / total)

> This repo may include a **reference copy** of ProjectEbonhold modules (`perks.lua`, `perks_service.lua`, `player_run_service.lua`, etc.). On the actual server those are provided by ProjectEbonhold itself.

---

## Installation

1. Copy the addon folder into your WoW installation:
   ```
   World of Warcraft/Interface/AddOns/EasyEcho/
   ```
2. Launch WoW and enable **EasyEcho** in the AddOns list.

**Load order** (defined in `EasyEcho.toc`):

| # | File | Purpose |
|---|------|---------|
| 1 | `EasyEchoUI.lua` | All UI frame definitions and rendering |
| 2 | `EasyEchoConfig.lua` | Configuration panel (priority/ban lists, profiles) |
| 3 | `EasyEchoCore.lua` | Constants, shared state, profile management |
| 4 | `EasyEchoEngine.lua` | Selection engine and state machine |
| 5 | `EasyEchoHooks.lua` | Hooks for Start / Accept Death buttons |
| 6 | `EasyEcho_Main.lua` | Event dispatcher (PLAYER_LOGIN, PLAYER_DEAD, etc.) |

---

## In-game Commands

| Command | Effect |
|---------|--------|
| `/easyecho` or `/ee` | Toggle the main UI (History / Stats / Echoes) |
| `/easyecho config` | Open the Configuration window |
| `/easyecho start` | Start auto-selection |
| `/easyecho stop` | Stop auto-selection (manual mode) |
| `/easyecho toggle` | Toggle start / stop |

---

## Detailed Guide

EasyEcho provides two main windows, each with multiple tabs.
All windows are **movable** (drag the title bar) and **resizable** (hold **Shift** and drag any corner handle).
The addon remembers which windows were open for each character separately.

---

### Main Window (History / Stats / Echoes)

**Open with:** `/easyecho` or `/ee`

The main window has three tabs across the top:

---

#### Tab 1 — History

Displays a **scrollable log** of every perk pick during the current and past runs.

**Entry types:**

| Color | Type | Description |
|-------|------|-------------|
| Gray  | `OPTIONS` | The three choices offered by the server for pick #N |
| Green | `SELECT`  | The perk EasyEcho selected (or you selected manually) |
| Red   | `REROLL`  | A reroll was triggered; shows reason and reroll count |

**Columns per entry:**
- **Pick #** — the sequential pick counter (matches your in-run level)
- **Perk name** — the echo name
- **Quality** — Common / Uncommon / Rare / Epic
- **Timestamp** — when the event occurred

**Interactions:**
- **Right-click a SELECT entry** — opens a context menu showing the perk icon and tooltip
- **Scroll** — mouse wheel or drag the scroll bar to navigate through the full history
- History resets automatically when a new run is detected (death + fresh start)

---

#### Tab 2 — Stats

Displays **live statistics** for the current run.

**Tracked Spells (top section):**
- **Tracked Spell 1** (default: *Rend the Weak*) — shows how many times this perk was selected; includes what percentage came from priority matches vs. other reasons
- **Tracked Spell 2** (default: *Double Strike*) — same counters for the second spell

Use the **quality dropdowns** next to each spell name to filter which quality to count (or leave on *Any*).

**Quality counters:**
| Counter | Shows |
|---------|-------|
| Epics (Priority) | Epics selected because they matched your priority list |
| Epics (Other) | Epics selected as fallback or non-priority |
| Rares | Total rare-quality selections |

**Rerolls remaining:**
- Displays current rerolls used and total available (synced live from the server)
- Updates whenever a new choice is offered or a reroll occurs

**Percentages** are calculated relative to total selections and update automatically.

---

#### Tab 3 — Granted Echoes

Shows all perks **currently owned** by your character (fetched from `PerkService.GetGrantedPerks()`).

**On open:** A **summary popup** appears showing totals by quality:
- Epic count
- Rare count
- Uncommon count
- Common count

Close the popup to browse the list.

**List columns:**
| Column | Description |
|--------|-------------|
| Name | Echo name |
| Quality | Color-coded quality label |
| Classes | Which classes can receive this echo |

**Controls:**

| Control | Function |
|---------|----------|
| **Sort: Rarity** | Sort entries by quality (Epic → Common) |
| **Sort: Name** | Sort alphabetically |
| **Sort: Class** | Group entries by applicable class |
| **Search box** | Filter list by partial name match; supports autocomplete from echo database |
| **Tooltip Values checkbox** | When checked, computes and displays stat values from echo tooltips (flat / per-level / stamina) |

---

### Echo Database (within Granted Echoes / standalone view)

The **Echo Database** is a complete catalog of **all available echoes** provided by the `ProjectEbonhold.PerkDatabase` API. It includes all perk metadata (quality, class restrictions, max stack, tome requirements) without needing to discover them during gameplay.

**Header:** Shows total number of available echoes (e.g., *"300 echoes available"*).

**Columns:**

| Column | Description |
|--------|-------------|
| Name | Echo name (colored by quality) |
| Quality | Quality tier (Common, Uncommon, Rare, Epic) |
| Classes | Which classes can receive this echo (from classMask) |

**Sort modes:**
- **By Rarity** (default) — Epic first, then Rare, Uncommon, Common
- **Alphabetical** — A → Z by name
- **Max Stack** — highest stackable echoes first
- **Prio List** — priority list rank order

**Search / Filter:**
- Type in the search box to filter by name or comment
- Class filter dropdown to show only echoes available to a specific class
- Autocomplete suggestions in config pull from the PerkDatabase

---

### Configuration Window

**Open with:** `/easyecho config`

The Configuration window has three tabs:

---

#### Config Tab 1 — Priority List

Defines the **order in which EasyEcho prefers perks**. The engine scans this list top-to-bottom and picks the first match that is offered and not banned.

**Entry format:** `Spell Name::Quality`
Supported qualities: `Common`, `Uncommon`, `Rare`, `Epic`, `Any`

`Any` matches regardless of the offered quality.

**List columns:**

| Column | Description |
|--------|-------------|
| # | Priority rank (1 = highest) |
| Name | Echo name |
| Quality | The required quality for this entry to match |

**Row controls (per entry):**

| Button | Function |
|--------|----------|
| **▲ Up** | Move this entry one position higher (higher priority) |
| **▼ Down** | Move this entry one position lower (lower priority) |
| **Edit** | Open an inline edit field to change the name or quality |
| **Delete** | Remove this entry from the priority list |

**Add new entry:**
1. Type the echo name in the text field (autocomplete suggestions appear from the echo database and existing list).
2. Select a quality from the dropdown (`Common` / `Uncommon` / `Rare` / `Epic` / `Any`).
3. Click **Add** — the entry is appended to the bottom of the list.

**Other controls:**

| Control | Function |
|---------|----------|
| **Search** | Filter the displayed list to find specific entries |
| **Reset to Default** | Restores the built-in default priority list (~60 entries). Prompts for confirmation. |

---

#### Config Tab 2 — Ban List

Lists perks that EasyEcho should **never select**, regardless of priority.
Ban entries are spell names only (no `::Quality`), matched case-insensitively.

**Row controls (per entry):**

| Button | Function |
|--------|----------|
| **▲ Up** | Move entry up (order doesn't affect logic, but helps readability) |
| **▼ Down** | Move entry down |
| **Delete** | Remove from ban list |

**Add new entry:**
1. Type the echo name in the text field.
2. Click **Add**.

**Other controls:**

| Control | Function |
|---------|----------|
| **Search** | Filter the displayed ban list |

> **Note:** If all three offered perks are banned, EasyEcho will attempt a reroll. If no rerolls are available it picks the left-most option as a last resort.

---

#### Config Tab 3 — Profiles

Profiles let you maintain **independent priority and ban lists** per playstyle or character. Each character remembers which profile it last used.

**Profile list columns:**

| Column | Description |
|--------|-------------|
| Name | Profile name |
| Active | Checkmark indicates the currently active profile |

**Row controls (per profile):**

| Button | Function |
|--------|----------|
| **▲ Up** | Reorder profile in the list (cosmetic) |
| **▼ Down** | Reorder profile in the list (cosmetic) |
| **Select** | Switch to this profile (activates its priority and ban lists immediately) |
| **Delete** | Delete this profile (cannot delete the active profile) |

**Create new profile:**
1. Enter a profile name in the text field.
2. Click **Add Profile** — a new empty profile is created.
3. Click **Select** to activate it and start editing its priority/ban lists in the other tabs.

**Switching profiles:**
- Changes take effect immediately.
- The character's profile choice is saved persistently — if you log out and back in, the same profile is loaded automatically.

---

## Configuration Reference

### Priority List format

```
Spell Name::Quality
```

Examples:
```
Rend the Weak::Rare
Double Strike::Uncommon
Immolation Aura::Any
```

### Ban List format

Spell name only, no quality suffix:
```
Some Bad Perk
Another Unwanted Echo
```

### One-time perks

Defined in `EasyEchoCore.lua` as `ONE_TIME_ONLY_LIST`.
If a perk is on this list and the player already has it (checked via `PerkService.GetGrantedPerks()`), EasyEcho skips it automatically. No manual configuration needed.

Current one-time perks include: *Immolation Aura* and similar effects that would have no extra benefit when stacked.

### Import / Export

The config UI supports copying lists in and out as plain text (one entry per line).
Each profile stores its lists independently.

---

## Selection Logic

Core constants (in `EasyEchoCore.lua`):

| Constant | Default | Description |
|----------|---------|-------------|
| `DELAY_TIME` | `0.5s` | Wait after perk frame appears before evaluating |
| `MIN_LEVEL_FOR_REROLL` | `11` | Minimum pick counter before rerolls are attempted |
| `MAX_REROLLS_PER_CHOICE` | `10` | Local cap on rerolls per single choice event |

Decision pipeline inside `ProcessChoices()` (`EasyEchoEngine.lua`):

1. **Get choices** — `ProjectEbonhold.PerkService.GetCurrentChoice()`
2. **Log OPTIONS** — record offered choices in history (once per pick counter)
3. **Priority match** (`CheckPriority()`):
   - Skips banned perks
   - Skips one-time perks already granted
   - Finds the highest-priority entry matching any offered perk (`Name::Quality` or `Name::Any`)
   - If match found → select it
4. **All banned** — if every offered perk is on the ban list → attempt reroll
5. **No priority match** — no offered perk matches the priority list → attempt reroll
6. **Reroll unavailable** — pick the left-most non-banned option as final fallback

**State machine states** (picker frame `OnUpdate`):

| State | Description |
|-------|-------------|
| `START_DELAY` | Waiting for initial render delay |
| `PROCESSING` | Running the decision pipeline |
| `WAIT_FOR_NEW_CARDS` | Detecting new offers after a reroll |
| `LOCKED` | Waiting for server to confirm selection |

---

## Saved Variables

Defined in `EasyEcho.toc`:

| Variable | Description |
|----------|-------------|
| `EasyEchoLogDB` | Timestamped debug/decision log (capped at ~2000 entries) |
| `EasyEchoHistoryDB` | History entries: OPTIONS, SELECT, REROLL with full metadata |
| `EasyEchoSettings` | Profiles, active profile, priority/ban lists, tracked spells, UI state, pick counter |
| ~~`EasyEchoEchoDB`~~ | *Removed:* Echo catalog now provided by `ProjectEbonhold.PerkDatabase` API |

---

## Repository Structure

```
EasyEcho/
├── EasyEcho_Addon/                  # Main addon (deploy this folder)
│   ├── EasyEcho.toc                 # Addon manifest & load order
│   ├── EasyEcho_Main.lua            # Event handler & initialization
│   ├── EasyEchoCore.lua             # Constants, state, profiles, helpers
│   ├── EasyEchoEngine.lua           # Selection engine & state machine
│   ├── EasyEchoHooks.lua            # UI hooks for Start/Death buttons
│   ├── EasyEchoUI.lua               # All UI frames (~2,600 lines)
│   ├── EasyEchoConfig.lua           # Configuration UI (priority/ban/profiles)
│   └── CLAUDE.md                    # Developer notes
│
└── ProjectEbonhold_Addon/           # Reference copy of server addon modules
    └── interface/AddOns/ProjectEbonhold/modules/
        ├── perks/
        │   ├── perks.lua            # Server perk picker frame
        │   └── perks_service.lua    # Server API for perk communication
        └── playerRun/
            ├── player_run_service.lua
            ├── player_run_ui.lua
            └── deathFrame.lua
```

> Only the `EasyEcho_Addon/` folder needs to be copied to your WoW installation. The `ProjectEbonhold_Addon/` folder is included for reference only.

---

## Development Notes

- **Duplicated helpers** — some hook/reset helpers exist in more than one file. The code works, but maintenance requires updating both copies.
- **Initialization order** — `EasyEchoSettings` must be initialized before any code that reads profile or list data. Do not reorder `PLAYER_LOGIN` handler calls carelessly.
- **Frame pooling** — `EasyEchoUI.lua` uses reusable row frames for performance. Be careful when adding new row types.
- **SavedVariables nil-safety** — always use `EasyEchoSettings.X = EasyEchoSettings.X or default` patterns when reading settings that may not exist in older save files.

---

## License

No license file is included. If you plan to publish this repo, add a `LICENSE` file (MIT / Apache-2.0 / GPL) to make the legal status unambiguous.
