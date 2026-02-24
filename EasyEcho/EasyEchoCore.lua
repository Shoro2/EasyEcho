-- EasyEchoCore.lua
-- Split-out core/constants/state/settings for EasyEcho
-- Generated: 2026-02-15 21:38:32

EasyEcho = EasyEcho or {}
EasyEcho.Constants = EasyEcho.Constants or {}
EasyEcho.State = EasyEcho.State or {}
EasyEcho.Engine = EasyEcho.Engine or {}
EasyEcho.Hooks = EasyEcho.Hooks or {}

local C = EasyEcho.Constants
local S = EasyEcho.State

-- =========================================================
-- CONFIGURATION
-- =========================================================
C.MAX_REROLLS_PER_CHOICE = 10
C.MIN_LEVEL_FOR_REROLL   = 11
C.DELAY_TIME             = 0.5

-- ONE-TIME PERKS (taken only once)
EasyEcho.ONE_TIME_ONLY_LIST = {
    "Immolation Aura::Any",
    "Corrosive Breath::Any",
    "Stonefist Barrage::Any",
    "Ember Spark::Any",
    "Arcane Bombardment::Any",
    "Open Wounds::Any",
    "Scorched Path::Any",
}

-- Default priority list (active profile gets a copy)
EasyEcho.DEFAULT_PRIO = {
    -- --- TIER 1 ---
    "Rend the Weak::Rare",
    "Double Strike::Uncommon",
    "Chill of the Bone Wyrm::Epic",
    "Chaotic Convergence::Rare",
    "Chronoboost::Epic",
    "Quickening Aura::Epic",
    "Edict of the Four::Epic",
    "Unbalancing Strike::Epic",
    "Battle Momentum::Uncommon",
    "Precision Strike::Epic",
    "Perfect Timing::Epic",
    "Storm Conductor::Epic",
    "Glass Canon::Rare",
    "Unbroken Focus::Rare",
    "Focused Assault::Rare",
    "Harbringer of Doom::Epic",
    "Second Edge::Epic",
	"Backstabber's Edge::Epic",
    "Echoing Afflictions::Epic",
    "Polarity Shift::Epic",
    "Quick Hands::Rare",
    "Agility Boost::Rare",
    "Brutal Might::Rare",
    "Keen Aim::Rare",
    "Expertise Drills::Rare",
    "Crushing Force::Rare",
    "Mind Expansion::Rare",
    "Quick Hands::Uncommon",
    "Agility Boost::Uncommon",
    "Brutal Might::Uncommon",
    "Keen Aim::Uncommon",
    "Scorching Wounds::Rare",
    "Reap the Weak::Rare",
    "Expertise Drills::Uncommon",
    "Crushing Force::Uncommon",
    "Mind Expansion::Uncommon",
    "Rend the Weak::Uncommon",
    "Quick Hands::Common",
    "Agility Boost::Common",
    "Brutal Might::Common",
    "Rend the Weak::Common",
    "Keen Aim::Common",
    "Expertise Drills::Common",
    "Reap the Weak::Any",
    "Crushing Force::Any",
    "Scorching Wounds::Any",
	"Mythic Potency::Any",
    "Swift Step::Any",
    "Immolation Aura::Any",
    "Corrosive Breath::Any",
    "Stonefist Barrage::Any",
    "Ember Spark::Any",
    "Arcane Bombardment::Any",
    "Open Wounds::Any",
    "Scorched Path::Any",
    "Armor Penetration::Any",
    "Strength Training::Any"
}

-- Exposed for Config UI (kept as table reference to active profile list)
EasyEcho_PrioList = EasyEcho_PrioList or {}

-- Running flag (UI uses this)
EasyEcho_IsRunning = false

-- Quality names as used by ProjectEbonhold
EasyEcho.QUALITY_NAMES = {[0] = "Common", [1] = "Uncommon", [2] = "Rare", [3] = "Epic"}

-- One-time perk map (lowercase spell name -> true)
EasyEcho.ONE_TIME_MAP = EasyEcho.ONE_TIME_MAP or {}
do
    -- clear
    for k in pairs(EasyEcho.ONE_TIME_MAP) do EasyEcho.ONE_TIME_MAP[k] = nil end
    for _, rawEntry in ipairs(EasyEcho.ONE_TIME_ONLY_LIST) do
        local name = rawEntry:match("^(.-)::") or rawEntry
        if name then EasyEcho.ONE_TIME_MAP[string.lower(name)] = true end
    end
end

-- =========================================================
-- STATE (frames + runtime variables)
-- =========================================================
S.currentRerolls   = 0
S.lastChoicesRef   = nil
S.isProcessing     = false
S.isAutoStopped    = false
S.lastLoggedPick   = -1
S.pendingDeathReset = false

S.hookedAcceptDeathButtons = S.hookedAcceptDeathButtons or {}
S.hookedStartButtons       = S.hookedStartButtons or {}

S.acceptDeathWatcher = S.acceptDeathWatcher or CreateFrame("Frame")
S.acceptDeathWatcher:Hide()
S.acceptDeathWatcher.timer = 0
S.acceptDeathWatcher.timeout = 0

S.startButtonWatcher = S.startButtonWatcher or CreateFrame("Frame")
S.startButtonWatcher:Hide()
S.startButtonWatcher.timer = 0

S.pickerFrame = S.pickerFrame or CreateFrame("Frame")
S.pickerFrame:Hide()
S.pickerFrame.timer = 0
S.pickerFrame.state = nil

-- =========================================================
-- SAVEDVAR INIT + PROFILES
-- =========================================================
function EasyEcho.InitializeSettings()
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if not EasyEchoSettings.Profiles then EasyEchoSettings.Profiles = {} end
    if not EasyEchoSettings.ActiveProfile then EasyEchoSettings.ActiveProfile = "Default" end

    local prof = EasyEchoSettings.ActiveProfile
    if not EasyEchoSettings.Profiles[prof] then
        EasyEchoSettings.Profiles[prof] = { PriorityList = {}, BanList = {}, BanishList = {} }
        for _, v in ipairs(EasyEcho.DEFAULT_PRIO) do
            table.insert(EasyEchoSettings.Profiles[prof].PriorityList, v)
        end
    end

    EasyEchoSettings.PriorityList = EasyEchoSettings.Profiles[prof].PriorityList
    EasyEchoSettings.BanList      = EasyEchoSettings.Profiles[prof].BanList or {}
    EasyEchoSettings.BanishList   = EasyEchoSettings.Profiles[prof].BanishList or {}
    EasyEcho_PrioList             = EasyEchoSettings.PriorityList

    -- General settings defaults
    if EasyEchoSettings.TickSpeed == nil then EasyEchoSettings.TickSpeed = 0.5 end
    if EasyEchoSettings.AutoResetLogOnDeath == nil then EasyEchoSettings.AutoResetLogOnDeath = false end
    if EasyEchoSettings.AutoOpenSummaryAt80 == nil then EasyEchoSettings.AutoOpenSummaryAt80 = false end
    if EasyEchoSettings.IncludeLockedEchoes == nil then EasyEchoSettings.IncludeLockedEchoes = true end
    if EasyEchoSettings.ChatSummaryAtMilestones == nil then EasyEchoSettings.ChatSummaryAtMilestones = true end

    -- Apply saved tick speed to the engine constant
    C.DELAY_TIME = EasyEchoSettings.TickSpeed
end

function EasyEcho_SwitchProfile(profileName, silent)
    if not EasyEchoSettings or not EasyEchoSettings.Profiles then return end
    if EasyEchoSettings.Profiles[profileName] then
        EasyEchoSettings.ActiveProfile = profileName
        EasyEchoSettings.PriorityList  = EasyEchoSettings.Profiles[profileName].PriorityList
        EasyEchoSettings.BanList       = EasyEchoSettings.Profiles[profileName].BanList
        EasyEchoSettings.BanishList    = EasyEchoSettings.Profiles[profileName].BanishList or {}
        EasyEcho_PrioList              = EasyEchoSettings.PriorityList

        -- Save this profile as the character's preferred profile
        if not EasyEchoSettings.CharacterProfiles then EasyEchoSettings.CharacterProfiles = {} end
        local charKey = (UnitName("player") or "") .. "-" .. (GetRealmName() or "")
        EasyEchoSettings.CharacterProfiles[charKey] = profileName

        if not silent and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Profile '" .. profileName .. "' loaded.")
        end
        if EasyEcho_Config and EasyEcho_Config.Refresh then EasyEcho_Config.Refresh() end
    end
end

function EasyEcho_ResetPrioToDefault()
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if not EasyEchoSettings.Profiles then EasyEchoSettings.Profiles = {} end
    if not EasyEchoSettings.ActiveProfile then EasyEchoSettings.ActiveProfile = "Default" end

    local prof = EasyEchoSettings.ActiveProfile
    if not EasyEchoSettings.Profiles[prof] then
        EasyEchoSettings.Profiles[prof] = { PriorityList = {}, BanList = {} }
    end

    local prio = EasyEchoSettings.Profiles[prof].PriorityList
    for i = #prio, 1, -1 do prio[i] = nil end
    for _, v in ipairs(EasyEcho.DEFAULT_PRIO) do prio[#prio + 1] = v end

    EasyEchoSettings.PriorityList = prio
    EasyEcho_PrioList = prio

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Priorities reset to default.")
    end
    if EasyEcho_Config and EasyEcho_Config.Refresh then EasyEcho_Config.Refresh() end
end

-- =========================================================
-- START / STOP
-- =========================================================
function EasyEcho_Start()
    EasyEcho_IsRunning = true
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Bot |cff00ff00STARTED|r – auto-selecting perks.")
    end
    if EasyEcho_UI and EasyEcho_UI.UpdateStartStopButton then EasyEcho_UI.UpdateStartStopButton() end
end

function EasyEcho_Stop()
    EasyEcho_IsRunning = false
    S.isProcessing = false
    if S.pickerFrame then
        S.pickerFrame.state = nil
        S.pickerFrame.timer = 0
        S.pickerFrame:Hide()
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Bot |cffff4444STOPPED|r – manual mode.")
    end
    if EasyEcho_UI and EasyEcho_UI.UpdateStartStopButton then EasyEcho_UI.UpdateStartStopButton() end
end

function EasyEcho_ToggleRunning()
    if EasyEcho_IsRunning then EasyEcho_Stop() else EasyEcho_Start() end
end

-- =========================================================
-- LOGGING + SHARED HELPERS
-- =========================================================
local function EnsureLogDB()
    if not EasyEchoLogDB then EasyEchoLogDB = {} end
end

function EasyEcho.WriteToLog(msg)
    EnsureLogDB()
    local timestamp = date("%m/%d/%y %H:%M:%S")
    local entry = string.format("[%s] %s", timestamp, msg)
    table.insert(EasyEchoLogDB, entry)
    if #EasyEchoLogDB > 2000 then table.remove(EasyEchoLogDB, 1) end
end

function EasyEcho.GetServerRunData()
    if ProjectEbonhold and ProjectEbonhold.PlayerRunService then
        local data = ProjectEbonhold.PlayerRunService.GetCurrentData()
        if data then return (data.usedRerolls or 0), (data.totalRerolls or 10) end
    end
    return 0, 10
end

function EasyEcho.SyncRerollStatus(overrideUsed, overrideTotal)
    if not EasyEcho_UI or not EasyEcho_UI.UpdateRerollStatus then return end
    if overrideUsed ~= nil and overrideTotal ~= nil then
        EasyEcho_UI.UpdateRerollStatus(overrideUsed, overrideTotal)
        return
    end
    local usedRerolls, totalRerolls = EasyEcho.GetServerRunData()
    EasyEcho_UI.UpdateRerollStatus(usedRerolls, totalRerolls)
end

function EasyEcho.LogDecision(action, name, quality, reason, sUsed, sTotal, isPrio)
    local count = EasyEchoSettings and EasyEchoSettings.CurrentPickCount or "?"
    local qName = (quality ~= nil) and (EasyEcho.QUALITY_NAMES[quality] or "") or ""
    local msg = string.format("ACTION [#%d]: %s -> %s %s (%s)", count, action, name or "-", qName, reason or "-")
    EasyEcho.WriteToLog(msg)

    if action == "SELECT" then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r [# " .. count .. "] Selecting: " .. (name or "Unknown") .. " (" .. qName .. ")")
        end
        if EasyEcho_UI and EasyEcho_UI.AddSelectToHistory then
            EasyEcho_UI.AddSelectToHistory(name, quality, count, isPrio)
        end
    elseif action == "REROLL" then
        if EasyEcho_UI and EasyEcho_UI.AddRerollToHistory then
            EasyEcho_UI.AddRerollToHistory(reason, count, sUsed, sTotal)
        end
    end
end

function EasyEcho.IsBanned(name)
    if not name or not EasyEchoSettings or not EasyEchoSettings.BanList then return false end
    local lowerName = string.lower(name)
    for _, bannedName in ipairs(EasyEchoSettings.BanList) do
        if string.lower(bannedName) == lowerName then return true end
    end
    return false
end

function EasyEcho.IsBanished(name)
    if not name or not EasyEchoSettings or not EasyEchoSettings.BanishList then return false end
    local lowerName = string.lower(name)
    for _, entry in ipairs(EasyEchoSettings.BanishList) do
        if string.lower(entry) == lowerName then return true end
    end
    return false
end

function EasyEcho.GetRemainingBanishes()
    if ProjectEbonhold and ProjectEbonhold.PlayerRunService then
        local data = ProjectEbonhold.PlayerRunService.GetCurrentData()
        if data then return data.remainingBanishes or 0 end
    end
    return 0
end

function EasyEcho.PlayerAlreadyHasPerk(checkName)
    if not checkName or not ProjectEbonhold or not ProjectEbonhold.PerkService or not ProjectEbonhold.PerkService.GetGrantedPerks then return false end
    local granted = ProjectEbonhold.PerkService.GetGrantedPerks()
    if not granted then return false end
    local searchLower = string.lower(checkName)
    for _, perkData in ipairs(granted) do
        local n = GetSpellInfo(perkData.spellId)
        if n and string.lower(n) == searchLower then return true end
    end
    return false
end
