-- =========================================================
-- CONFIGURATION
-- =========================================================
local MAX_REROLLS_PER_CHOICE = 10 
local MIN_LEVEL_FOR_REROLL = 11 
local DELAY_TIME = 0.5 

-- ONE-TIME PERKS (Taken only once)
local ONE_TIME_ONLY_LIST = {
    "Immolation Aura::Any",
    "Corrosive Breath::Any",
    "Stonefist Barrage::Any",
    "Ember Spark::Any",
    "Arcane Bombardment::Any",
    "Open Wounds::Any",
    "Scorched Path::Any",
}

local DEFAULT_PRIO = {
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

EasyEcho_PrioList = {} 

-- Ersetze die InitializePrioList Funktion in der EasyEcho.lua
local function InitializePrioList()
    -- Grundstruktur sicherstellen
    if not EasyEchoSettings.Profiles then 
        EasyEchoSettings.Profiles = {} 
    end
    if not EasyEchoSettings.ActiveProfile then 
        EasyEchoSettings.ActiveProfile = "Default" 
    end

    -- Falls das aktive Profil noch nicht existiert, erstelle es mit Defaults
    if not EasyEchoSettings.Profiles[EasyEchoSettings.ActiveProfile] then
        EasyEchoSettings.Profiles[EasyEchoSettings.ActiveProfile] = {
            PriorityList = {},
            BanList = {}
        }
        for _, v in ipairs(DEFAULT_PRIO) do
            table.insert(EasyEchoSettings.Profiles[EasyEchoSettings.ActiveProfile].PriorityList, v)
        end
    end

    -- Referenzen für den Bot setzen
    EasyEchoSettings.PriorityList = EasyEchoSettings.Profiles[EasyEchoSettings.ActiveProfile].PriorityList
    EasyEchoSettings.BanList = EasyEchoSettings.Profiles[EasyEchoSettings.ActiveProfile].BanList
    EasyEcho_PrioList = EasyEchoSettings.PriorityList
end

-- Neue Funktion zum Umschalten der Profile
function EasyEcho_SwitchProfile(profileName)
    if EasyEchoSettings.Profiles[profileName] then
        EasyEchoSettings.ActiveProfile = profileName
        EasyEchoSettings.PriorityList = EasyEchoSettings.Profiles[profileName].PriorityList
        EasyEchoSettings.BanList = EasyEchoSettings.Profiles[profileName].BanList
        EasyEcho_PrioList = EasyEchoSettings.PriorityList
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Profile '" .. profileName .. "' loaded.")
        if EasyEcho_Config and EasyEcho_Config.Refresh then EasyEcho_Config.Refresh() end
    end
end

-- =========================================================
-- SYSTEM
-- =========================================================
local currentRerolls = 0 
local lastChoicesRef = nil 
local isProcessing = false 
local lastLoggedLevel = -1 -- Muss außerhalb der Funktion stehen, um sich den Level zu merken
local pickerFrame = CreateFrame("Frame")
pickerFrame:Hide()
pickerFrame.timer = 0
pickerFrame.state = nil 

local QUALITY_NAMES = {[0] = "Common", [1] = "Uncommon", [2] = "Rare", [3] = "Epic"}

local ONE_TIME_MAP = {}
for _, rawEntry in ipairs(ONE_TIME_ONLY_LIST) do
    local name = rawEntry:match("^(.-)::") or rawEntry
    if name then ONE_TIME_MAP[string.lower(name)] = true end
end

-- =========================================================
-- HELPERS & LOGGING
-- =========================================================
local function GetServerRunData()
    if ProjectEbonhold and ProjectEbonhold.PlayerRunService then
        local data = ProjectEbonhold.PlayerRunService.GetCurrentData()
        if data then return (data.usedRerolls or 0), (data.totalRerolls or 10) end
    end
    return 0, 10
end

local function WriteToLog(msg)
    local timestamp = date("%m/%d/%y %H:%M:%S")
    local entry = string.format("[%s] %s", timestamp, msg)
    table.insert(EasyEchoLogDB, entry)
    if #EasyEchoLogDB > 2000 then table.remove(EasyEchoLogDB, 1) end
end

local function LogDecision(action, name, quality, reason, sUsed, sTotal, isPrio)
    local count = EasyEchoSettings and EasyEchoSettings.CurrentPickCount or "?"
    local qName = quality and QUALITY_NAMES[quality] or ""
    local msg = string.format("ACTION [#%d]: %s -> %s %s (%s)", count, action, name, qName, reason)
    WriteToLog(msg)
    
    if action == "SELECT" then
        -- Changed to English: "Selecting"
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r [# " .. count .. "] Selecting: " .. name .. " (" .. qName .. ")")
        if EasyEcho_UI and EasyEcho_UI.AddSelectToHistory then
            EasyEcho_UI.AddSelectToHistory(name, quality, count, isPrio)
        end
    elseif action == "REROLL" then
        if EasyEcho_UI and EasyEcho_UI.AddRerollToHistory then
            EasyEcho_UI.AddRerollToHistory(reason, count, sUsed, sTotal)
        end
    end
end

local function IsBanned(name)
    if not name or not EasyEchoSettings.BanList then return false end
    local lowerName = string.lower(name)
    for _, bannedName in ipairs(EasyEchoSettings.BanList) do
        if string.lower(bannedName) == lowerName then return true end
    end
    return false
end

-- =========================================================
-- LOGIC
-- =========================================================
local function PlayerAlreadyHasPerk(checkName)
    if not checkName or not ProjectEbonhold.PerkService.GetGrantedPerks then return false end
    local granted = ProjectEbonhold.PerkService.GetGrantedPerks()
    if not granted then return false end
    local searchLower = string.lower(checkName)
    for _, perkData in ipairs(granted) do
        local name = GetSpellInfo(perkData.spellId)
        if name and string.lower(name) == searchLower then return true end
    end
    return false
end

local function FindOneTimeMatch(choices)
    local bestMatch = nil
    local bestQuality = -1
    for _, choice in ipairs(choices) do
        local name = GetSpellInfo(choice.spellId)
        if name and not IsBanned(name) and ONE_TIME_MAP[string.lower(name)] and not PlayerAlreadyHasPerk(name) then
            if choice.quality > bestQuality then
                bestMatch, bestQuality = choice, choice.quality
            end
        end
    end
    return bestMatch
end

local function GetExactPriorityRank(name, quality)
    local specKey = string.lower(name .. "::" .. (QUALITY_NAMES[quality] or "Common"))
    local anyKey = string.lower(name .. "::Any")
    
    for i, listKey in ipairs(EasyEcho_PrioList) do
        local lowKey = string.lower(listKey)
        if lowKey == specKey or lowKey == anyKey then return i end
    end
    return 99999
end

local function ExecuteFallback(choices, reason)
    local fallbackChoice, fallbackQuality, fallbackName = nil, -1, ""
    for _, choice in ipairs(choices) do
        local name = GetSpellInfo(choice.spellId)
        -- Added IsBanned check
        if name and not IsBanned(name) and not (ONE_TIME_MAP[string.lower(name)] and PlayerAlreadyHasPerk(name)) then
            if choice.quality > fallbackQuality then
                fallbackChoice, fallbackQuality, fallbackName = choice, choice.quality, name
            end
        end
    end
    -- ... rest of the function (if no fallback found, take first available that isn't banned)
    if not fallbackChoice then 
        for _, choice in ipairs(choices) do
            local name = GetSpellInfo(choice.spellId)
            if not IsBanned(name) then
                fallbackChoice = choice
                fallbackName = name
                fallbackQuality = choice.quality
                break
            end
        end
    end
    -- ... 
end

local lastLoggedLevel = -1 -- Verhindert Log-Spam

-- =========================================================
-- MISSING CORE FUNCTIONS (were called but never defined)
-- =========================================================
local function CheckPriority(choices)
    local bestRank, bestName, bestQual, bestIdx = 99999, nil, nil, nil
    for i, choice in ipairs(choices) do
        local name = GetSpellInfo(choice.spellId)
        if name and not IsBanned(name) then
            -- Skip one-time perks the player already has
            if not (ONE_TIME_MAP[string.lower(name)] and PlayerAlreadyHasPerk(name)) then
                local rank = GetExactPriorityRank(name, choice.quality)
                if rank < bestRank then
                    bestRank, bestName, bestQual, bestIdx = rank, name, choice.quality, i
                end
            end
        end
    end
    if bestRank < 99999 then
        return bestName, bestQual, bestIdx
    end
    return nil, nil, nil
end

local function CheckBanned(choices)
    local allBanned = true
    local bannedNames = {}
    for _, choice in ipairs(choices) do
        local name = GetSpellInfo(choice.spellId)
        if name then
            if IsBanned(name) then
                table.insert(bannedNames, name)
            else
                allBanned = false
            end
        end
    end
    return allBanned, table.concat(bannedNames, ", ")
end

local function HandleReroll(pickLevel, reason)
    if pickLevel < MIN_LEVEL_FOR_REROLL then return false end
    local usedRerolls, totalRerolls = GetServerRunData()
    if currentRerolls >= MAX_REROLLS_PER_CHOICE then return false end
    if usedRerolls >= totalRerolls then return false end

    currentRerolls = currentRerolls + 1
    LogDecision("REROLL", "-", nil, reason, usedRerolls + 1, totalRerolls, false)

    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.RequestReroll then
        ProjectEbonhold.PerkService.RequestReroll()
    end

    pickerFrame.state = "WAIT_FOR_NEW_CARDS"
    pickerFrame.timer = 0
    return true
end

local function SelectSpell(idx, name, quality, pickLevel, isPrio)
    isProcessing = true

    local choices = ProjectEbonhold.PerkService.GetCurrentChoice()
    if not choices or not choices[idx] then
        isProcessing = false
        return
    end

    LogDecision("SELECT", name or "Unknown", quality, isPrio and "Priority match" or "Fallback", 0, 0, isPrio)

    ProjectEbonhold.PerkService.SelectPerk(choices[idx].spellId)

    EasyEchoSettings.CurrentPickCount = (EasyEchoSettings.CurrentPickCount or 2) + 1
    pickerFrame.state = "LOCKED"
    pickerFrame.timer = 0
end

local function ProcessChoices()
    if isProcessing then return end
    
    local pickLevel = EasyEchoSettings.CurrentPickCount
    local choices = ProjectEbonhold.PerkService.GetCurrentChoice()
    if not choices then return end

    -- LOGGING: Nur einmal pro Level in den Verlauf schreiben
    if lastLoggedLevel ~= pickLevel then
        if EasyEcho_UI then 
            EasyEcho_UI.AddOptionsToHistory(choices, pickLevel)
        end
        lastLoggedLevel = pickLevel
    end

    -- 1. Prüfe Prioritäten-Liste (Dein aktives Profil)
    local mSpell, mQual, mIdx = CheckPriority(choices)
    if mSpell then
        SelectSpell(mIdx, mSpell, mQual, pickLevel, true)
        return
    end

    -- 2. Prüfe Ban-Liste & Reroll
    local allBanned, bannedNames = CheckBanned(choices)
    if allBanned then
        if HandleReroll(pickLevel, "All banned: " .. bannedNames) then return end
        
        -- FALLBACK 1: Alles verboten & kein Reroll -> Links wählen
        local fName = GetSpellInfo(choices[1].spellId)
        SelectSpell(1, fName, choices[1].quality, pickLevel, false)
        return
    end

    -- 3. FALLBACK 2: Kein Treffer im Profil -> Links wählen
    local finalName = GetSpellInfo(choices[1].spellId)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r No profile match. Picking leftmost.")
    SelectSpell(1, finalName, choices[1].quality, pickLevel, false)
end

-- =========================================================
-- INIT & TIMER
-- =========================================================
pickerFrame:SetScript("OnUpdate", function(self, elapsed)
    self.timer = self.timer + elapsed
    if self.state == "START_DELAY" and self.timer > DELAY_TIME then
        self.state = "PROCESSING"
        ProcessChoices()
        -- If ProcessChoices didn't transition state (e.g. no choices / error), stop the loop
        if self.state == "PROCESSING" then
            self.state = nil
            self:Hide()
        end
    elseif self.state == "WAIT_FOR_NEW_CARDS" and self.timer > 0.05 then
        self.timer = 0
        local cur = ProjectEbonhold.PerkService.GetCurrentChoice()
        if cur and cur ~= lastChoicesRef then
            isProcessing, lastChoicesRef, self.state, self.timer = false, cur, "START_DELAY", 0
        end
    elseif self.state == "LOCKED" and self.timer > 0.2 then
        self.timer = 0
        local cur = ProjectEbonhold.PerkService.GetCurrentChoice()
        if cur and cur ~= lastChoicesRef then
            isProcessing, lastChoicesRef, self.state, self.timer = false, cur, "START_DELAY", 0
        end
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
	InitializePrioList()
    if not EasyEchoLogDB then EasyEchoLogDB = {} end
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if not EasyEchoSettings.CurrentPickCount then EasyEchoSettings.CurrentPickCount = 2 end
    if EasyEcho_UI then EasyEcho_UI.Init() end
    
    if ProjectEbonhold and ProjectEbonhold.PerkUI then
        hooksecurefunc(ProjectEbonhold.PerkUI, "Show", function()
            if isProcessing then return end
            currentRerolls, pickerFrame.state, pickerFrame.timer = 0, "START_DELAY", 0
            pickerFrame:Show()
        end)
    end
end)

function EasyEcho_ResetPrioToDefault()
    EasyEchoSettings.PriorityList = {}
    for _, v in ipairs(DEFAULT_PRIO) do
        table.insert(EasyEchoSettings.PriorityList, v)
    end
    EasyEcho_PrioList = EasyEchoSettings.PriorityList
    -- Changed to English: "Priorities reset to default."
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Priorities reset to default.")
end