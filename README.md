# EasyEcho

World of Warcraft Addon (WotLK **3.3.5a / Interface 30300**) für den **ProjectEbonhold** Private-Server: EasyEcho automatisiert die *Echo/Perk*-Auswahl während Progression-Runs.

Statt manuell Karten/Perks zu klicken, nimmt EasyEcho die angebotenen Optionen und entscheidet anhand von:

- **Prioritätenliste** (geordnet, inkl. gewünschter Quality)
- **Ban-Liste** (niemals nehmen)
- **One-Time-Perks** (nur ein einziges Mal nehmen)
- **Reroll-Logik** (wenn nichts passt)

Dazu gibt’s UI für **History**, **Stats**, **Echo-Katalog** und eine **Config-GUI** mit Profilen.

---

## Features

- **Auto-Select Engine**
  - Matcht exakte Einträge wie `"Rend the Weak::Rare"` oder `"...::Any"`
  - Skippt gebannte Perks
  - Skippt One-Time-Perks, falls bereits vorhanden
  - Rerollt, wenn *alle Optionen gebannt* oder *kein Prio-Match* (konfig-/serverlimitiert)

- **Profile-System**
  - Mehrere Profile mit eigenen Priority/Ban-Listen
  - Load/Save pro Profil

- **UI**
  - History: `OPTIONS`, `SELECT`, `REROLL` inkl. Farbcodierung
  - Stats: Zähler (u.a. Rend/Double Strike), Epics (Prio vs. sonst), Rares, Rerolls
  - Mini-Buttons oben (draggable): **Start/Stop** + **Show UI**
  - Echo-Liste: alle *jemals gesehenen* Echos (persistenter Katalog), Suche + Sortierung

- **Run-Safety**
  - Reset der internen Daten beim Death/Run-Reset (Hook auf „Accept Death“)
  - Auto-Stop bei Level 80, wenn keine Echos mehr angeboten werden

---

## Anforderungen

- WoW Client **3.3.5a** (TOC: `Interface: 30300`)
- ProjectEbonhold Addon/Server-API verfügbar:
  - `ProjectEbonhold.PerkService` (Choice/Select/Reroll + Granted Perks)
  - `ProjectEbonhold.PlayerRunService` (Reroll-Infos: used/total)
  - optional: `ProjectEbonhold.PerkUI` (wenn vorhanden, wird `Show()` gehookt)

> Dieses Repo enthält zusätzlich **Referenzkopien** einiger ProjectEbonhold-Module (`perks.lua`, `perks_service.lua`, `player_run_service.lua`, `player_run_ui.lua`, `deathFrame.lua`). Für einen normalen Spieler ist das meist *bereits serverseitig vorhanden*.

---

## Installation

1. Ordner `EasyEcho` (mit `EasyEcho.toc` und den Lua-Dateien) nach:
   
   `World of Warcraft/Interface/AddOns/EasyEcho/`

2. WoW starten → Addons aktivieren.

**Load Order** (aus `EasyEcho.toc`):

1. `EasyEchoUI.lua`
2. `EasyEchoConfig.lua`
3. `EasyEcho.lua`

---

## In-Game Usage

### Start/Stop

- Klick auf den Mini-Button **Start/Stop** (oben im UI)
- oder per Slash Command:

Wichtig: EasyEcho **autostartet nicht** nach Reload/Restart. Start/Stop ist eine Laufzeit-Flag (`EasyEcho_IsRunning`).

- `/easyecho start` – Bot an
- `/easyecho stop` – Bot aus
- `/easyecho toggle` – Toggle

### UI / Config

- `/easyecho` oder `/ee` – History/Stats Fenster togglen
- `/easyecho config` – Config-Fenster

---

## Konfiguration

### Priority List

Einträge sind Strings im Format:

- `"Spell Name::Quality"`

Quality ist:

- `Common`, `Uncommon`, `Rare`, `Epic`, `Any`

`Any` matcht unabhängig von der angebotenen Quality.

Beispiel:

- `Rend the Weak::Rare`
- `Double Strike::Uncommon`
- `Immolation Aura::Any`

### Ban List

Einträge sind **Spell Names** (ohne `::Quality`). Wenn alle drei Optionen gebannt sind, versucht EasyEcho zu rerollen.

### One-Time-Perks

In `EasyEcho.lua` via `ONE_TIME_ONLY_LIST` hinterlegt (Format `"Name::Any"`). EasyEcho nimmt diese nur, wenn der Perk nicht bereits in den granted perks auftaucht.

### Import/Export

Im Config-Fenster gibt’s einen **Export/Import** Dialog:

- Export: Liste aus dem Edit-Feld kopieren
- Import: Zeilenweise einfügen → „Import“

---

## Wie die Auswahl-Engine arbeitet

Grob (siehe `EasyEcho.lua`):

1. **Choice holen** (`ProjectEbonhold.PerkService.RequestChoice()`)
2. **Kurz warten** (`DELAY_TIME`, default 0.5s), damit die Perk-UI stabil ist
   - Zusätzlich wird versucht, „Start“-Buttons der ProjectEbonhold-UI zu hooken, um nach Run-Start sofort Choices anzufragen.
3. **Prio-Check**: höchster Rang in PriorityList gewinnt
4. **Ban-Check**: wenn alle gebannt → Reroll (sofern möglich)
5. **Kein Prio-Match** → Reroll (sofern möglich)
6. **Fallback**: wenn kein Reroll möglich → links nehmen (Choice Index 1)

Reroll-Guards:

- Minimum Level für Reroll: `MIN_LEVEL_FOR_REROLL` (default 11)
- Max. Rerolls pro Choice: `MAX_REROLLS_PER_CHOICE` (default 10)
- Server-Limit: `usedRerolls/totalRerolls` über `ProjectEbonhold.PlayerRunService.GetCurrentData()`

---

## Saved Variables

Aus `EasyEcho.toc`:

- `EasyEchoLogDB` – Debug-/Decision-Log (max. ~2000 Einträge)
- `EasyEchoHistoryDB` – UI-History (OPTIONS/SELECT/REROLL)
- `EasyEchoSettings` – Profile, Priority/Ban, Tracked Spells, CurrentPickCount
- `EasyEchoEchoDB` – Persistenter Echo-Katalog (Name, Tooltip, Qualities, first/last seen, Klasse)

---

## Repository / Dateien

Minimal für das Addon:

- `EasyEcho.toc` – Manifest + SavedVariables + Load Order
- `EasyEcho.lua` – Core Logic (Engine, Hooks, Rerolls, Death Reset)
- `EasyEchoUI.lua` – History/Stats/Echo-Katalog + Slash Commands
- `EasyEchoConfig.lua` – Config UI (Prio/Ban/Profiles + Import/Export)

Referenz / Server-Module (ProjectEbonhold):

- `perks_service.lua` – Service-API + Event Parsing (Choice/Select/Reroll/Granted)
- `perks.lua` – Perk Picker UI
- `player_run_service.lua` – Run-Daten (u.a. Rerolls), Intensity etc.
- `player_run_ui.lua` – Run UI (Anzeige)
- `deathFrame.lua` – Death/Accept-Death UI

---

## Entwicklung / Hinweise

- **Lua 5.1 / WoW API** (3.3.5): kein `C_Timer`, daher Timer über `OnUpdate`.
- EasyEcho nutzt bewusst globale Tables/Functions mit Prefix `EasyEcho_...` (Addon-Pattern).

### Tech-Debt (ehrlich, damit du nicht in Fallen läufst)

- `EasyEcho.lua` enthält mehrere **duplizierte Funktionsblöcke** (z.B. `TryRequestChoiceNow`, `TryHookStartButtons`, Death-Watcher-Helfer). Das ist funktional meistens okay, macht aber Debugging unnötig schwer.
- `InitializePrioList()` greift auf `EasyEchoSettings` zu. Auf „First Run“ sollte `EasyEchoSettings` vorher initialisiert werden (sonst Lua-Error möglich). In der Praxis existiert es oft schon als SavedVariable – aber sauber ist es nicht.

Wenn du aufräumen willst: Duplicate Blöcke entfernen, Initialisierung in `PLAYER_LOGIN` erst *nach* dem `EasyEchoSettings`-Setup ausführen.

---

## Contributing

PRs/Issues sind willkommen – idealerweise mit:

- Repro steps (was passiert im Run?)
- Log-Auszug (`EasyEchoLogDB`) oder Screenshot
- Info, welche ProjectEbonhold-Version/API du nutzt

---

## Lizenz

In diesem Repo ist **keine** Lizenzdatei enthalten. Wenn du das öffentlich auf GitHub hostest, entscheide dich bewusst für eine Lizenz (z.B. MIT/Apache-2.0/GPL) und füge eine `LICENSE` hinzu.
