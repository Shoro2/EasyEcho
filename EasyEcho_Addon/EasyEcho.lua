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
-- START / STOP STATE
-- =========================================================
EasyEcho_IsRunning = false

function EasyEcho_Start()
    EasyEcho_IsRunning = true
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Bot |cff00ff00STARTED|r – auto-selecting perks.")
    if EasyEcho_UI and EasyEcho_UI.UpdateStartStopButton then
        EasyEcho_UI.UpdateStartStopButton()
    end
end

function EasyEcho_Stop()
    EasyEcho_IsRunning = false
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Bot |cffff4444STOPPED|r – manual mode.")
    if EasyEcho_UI and EasyEcho_UI.UpdateStartStopButton then
        EasyEcho_UI.UpdateStartStopButton()
    end
end

function EasyEcho_ToggleRunning()
    if EasyEcho_IsRunning then
        EasyEcho_Stop()
    else
        EasyEcho_Start()
    end
end

-- =========================================================
-- SYSTEM
-- =========================================================
local currentRerolls = 0 
local lastChoicesRef = nil 
local isProcessing = false 
local isAutoStopped = false
local lastLoggedLevel = -1 -- Muss außerhalb der Funktion stehen, um sich den Level zu merken
local pendingDeathReset = false
local acceptDeathWatcher = CreateFrame("Frame")
acceptDeathWatcher:Hide()
acceptDeathWatcher.timer = 0
acceptDeathWatcher.timeout = 0
local hookedAcceptDeathButtons = {}
local hookedStartButtons = {}
local showUiButtonsByStart = {}
local startButtonWatcher = CreateFrame("Frame")
startButtonWatcher:Hide()
startButtonWatcher.timer = 0
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

local function SyncRerollStatus(overrideUsed, overrideTotal)
    if not EasyEcho_UI or not EasyEcho_UI.UpdateRerollStatus then return end

    if overrideUsed ~= nil and overrideTotal ~= nil then
        EasyEcho_UI.UpdateRerollStatus(overrideUsed, overrideTotal)
        return
    end

    local usedRerolls, totalRerolls = GetServerRunData()
    EasyEcho_UI.UpdateRerollStatus(usedRerolls, totalRerolls)
end

local function SetAutoStopped(stopped, reason)
    isAutoStopped = stopped and true or false

    if isAutoStopped then
        isProcessing = false
        if pickerFrame then
            pickerFrame.state = nil
            pickerFrame.timer = 0
            pickerFrame:Hide()
        end
        if reason and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[EasyEcho]|r " .. reason)
        end
    end
end

local function CheckAutoStopAtMaxLevel()
    local lvl = UnitLevel("player") or 1
    if lvl < 80 then return false end

    local choices = ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
    if not choices or #choices == 0 then
        SetAutoStopped(true, "Level 80 reached and no echoes are available. EasyEcho stopped automatically.")
        return true
    end

    return false
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
    SyncRerollStatus(usedRerolls + 1, totalRerolls)
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
    if isAutoStopped or isProcessing then return end
    
    local pickLevel = EasyEchoSettings.CurrentPickCount
    local choices = ProjectEbonhold.PerkService.GetCurrentChoice()
    if not choices then
        CheckAutoStopAtMaxLevel()
        return
    end
    SyncRerollStatus()

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

    -- 3. Kein Match in der Prio-Liste -> aktiv rerollen, falls möglich
    if HandleReroll(pickLevel, "No priority match") then
        return
    end

    -- 4. FALLBACK 2: Kein Treffer im Profil & kein Reroll möglich -> Links wählen
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
        elseif (UnitLevel("player") or 1) >= 80 and not cur then
            CheckAutoStopAtMaxLevel()
        end
    end

    local name = frame.GetName and frame:GetName() or ""
    name = string.lower(name or "")
    if name:find("accept", 1, true) and name:find("death", 1, true) then
        return true
    end

    return false
end

local function IsAcceptDeathButton(frame)
    if not frame or frame.GetObjectType == nil then return false end
    if frame:GetObjectType() ~= "Button" then return false end
    return FrameHasAcceptDeathText(frame)
end

local function TryHookAcceptDeathButtons(root)
    if not root or not root.GetChildren then return false end

    local found = false
    local children = {root:GetChildren()}
    for _, child in ipairs(children) do
        if IsAcceptDeathButton(child) and not hookedAcceptDeathButtons[child] then
            hookedAcceptDeathButtons[child] = true
            child:HookScript("OnClick", function()
                if pendingDeathReset then
                    pendingDeathReset = false
                    ResetRunState("Accept Death selected. Data has been reset for a new run.")
                end
            end)
            found = true
        end

        if TryHookAcceptDeathButtons(child) then
            found = true
        end
    end

    return found
end

local function TryRequestChoiceNow()
    if not ProjectEbonhold or not ProjectEbonhold.PerkService or not ProjectEbonhold.PerkService.RequestChoice then return end
    ProjectEbonhold.PerkService.RequestChoice()

    local choices = ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
    if choices and #choices > 0 and not isProcessing then
        currentRerolls, pickerFrame.state, pickerFrame.timer = 0, "START_DELAY", 0
        pickerFrame:Show()
    end
end

local function IsStartButton(frame)
    if not frame or not frame.GetObjectType or frame:GetObjectType() ~= "Button" then return false end

    local txt = ""
    if frame.GetText then
        txt = NormalizeUiText(frame:GetText())
    end

    local name = frame.GetName and NormalizeUiText(frame:GetName()) or ""

    return txt == "start" or txt:find("start", 1, true) ~= nil or name:find("start", 1, true) ~= nil
end

local function TryHookStartButtons(root)
    if not root or not root.GetChildren then return false end

    local found = false
    local children = {root:GetChildren()}
    for _, child in ipairs(children) do
        if IsStartButton(child) and not hookedStartButtons[child] then
            hookedStartButtons[child] = true
            child:HookScript("OnClick", function()
                TryRequestChoiceNow()
                startButtonWatcher.timer = 0
                startButtonWatcher:Show()
            end)
            found = true
        end

        if TryHookStartButtons(child) then
            found = true
        end
    end

    return found
end

startButtonWatcher:SetScript("OnUpdate", function(self, elapsed)
    self.timer = self.timer + elapsed
    if self.timer >= 1.0 then
        self:Hide()
        TryRequestChoiceNow()
    end
end)

acceptDeathWatcher:SetScript("OnUpdate", function(self, elapsed)
    if not pendingDeathReset then
        self:Hide()
        return
    end

    self.timer = self.timer + elapsed
    self.timeout = self.timeout + elapsed

    if self.timer >= 0.2 then
        self.timer = 0
        TryHookAcceptDeathButtons(UIParent)
    end

    if self.timeout >= 15 then
        pendingDeathReset = false
        self:Hide()
    end
end)

local function ResetRunState(reason)
    currentRerolls = 0
    isProcessing = false
    lastChoicesRef = nil
    lastLoggedLevel = -1

    if pickerFrame then
        pickerFrame.state = nil
        pickerFrame.timer = 0
        pickerFrame:Hide()
    end

    isAutoStopped = false

    if EasyEcho_UI and EasyEcho_UI.ResetAllData then
        EasyEcho_UI.ResetAllData(reason or "Run reset detected. Data has been cleared.")
    else
        EasyEchoHistoryDB, EasyEchoLogDB = {}, {}
        if EasyEchoSettings then EasyEchoSettings.CurrentPickCount = 2 end
    end
end

local function NormalizeUiText(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return string.lower(text)
end

local function FrameHasAcceptDeathText(frame)
    if not frame then return false end

    if frame.GetText then
        local txt = NormalizeUiText(frame:GetText())
        if txt ~= "" and txt:find("accept", 1, true) and txt:find("death", 1, true) then
            return true
        end
    end

    if frame.GetRegions then
        local regions = {frame:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
                local txt = NormalizeUiText(region:GetText())
                if txt ~= "" and txt:find("accept", 1, true) and txt:find("death", 1, true) then
                    return true
                end
            end
        end
    end

    local name = frame.GetName and frame:GetName() or ""
    name = string.lower(name or "")
    if name:find("accept", 1, true) and name:find("death", 1, true) then
        return true
    end

    return false
end

local function IsAcceptDeathButton(frame)
    if not frame or frame.GetObjectType == nil then return false end
    if frame:GetObjectType() ~= "Button" then return false end
    return FrameHasAcceptDeathText(frame)
end

local function TryHookAcceptDeathButtons(root)
    if not root or not root.GetChildren then return false end

    local found = false
    local children = {root:GetChildren()}
    for _, child in ipairs(children) do
        if IsAcceptDeathButton(child) and not hookedAcceptDeathButtons[child] then
            hookedAcceptDeathButtons[child] = true
            child:HookScript("OnClick", function()
                if pendingDeathReset then
                    pendingDeathReset = false
                    ResetRunState("Accept Death selected. Data has been reset for a new run.")
                end
            end)
            found = true
        end

        if TryHookAcceptDeathButtons(child) then
            found = true
        end
    end

    return found
end

local function TryRequestChoiceNow()
    if isAutoStopped then return end
    if not ProjectEbonhold or not ProjectEbonhold.PerkService or not ProjectEbonhold.PerkService.RequestChoice then return end

    ProjectEbonhold.PerkService.RequestChoice()

    local choices = ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
    if choices and #choices > 0 and not isProcessing then
        currentRerolls, pickerFrame.state, pickerFrame.timer = 0, "START_DELAY", 0
        pickerFrame:Show()
    end
end

local function EnsureShowUiButton(startButton)
    if not startButton or showUiButtonsByStart[startButton] then return end

    local parent = startButton:GetParent() or UIParent
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(startButton:GetWidth() or 180, 24)
    btn:SetPoint("TOP", startButton, "BOTTOM", 0, -6)
    btn:SetText("Show UI")
    btn:SetScript("OnClick", function()
        if EasyEcho_UI and EasyEcho_UI.ShowMainWindow then
            EasyEcho_UI.ShowMainWindow()
        elseif EasyEcho_UI and EasyEcho_UI.Toggle then
            EasyEcho_UI.Toggle()
        end
    end)

    showUiButtonsByStart[startButton] = btn
end

local function IsStartButton(frame)
    if not frame or not frame.GetObjectType or frame:GetObjectType() ~= "Button" then return false end

    local txt = ""
    if frame.GetText then
        txt = NormalizeUiText(frame:GetText())
    end

    local name = frame.GetName and NormalizeUiText(frame:GetName()) or ""

    return txt == "start" or txt:find("start", 1, true) ~= nil or name:find("start", 1, true) ~= nil
end

local function TryHookStartButtons(root)
    if not root or not root.GetChildren then return false end

    local found = false
    local children = {root:GetChildren()}
    for _, child in ipairs(children) do
        if IsStartButton(child) then
            EnsureShowUiButton(child)

            if not hookedStartButtons[child] then
                hookedStartButtons[child] = true
                child:HookScript("OnClick", function()
                    TryRequestChoiceNow()
                    startButtonWatcher.timer = 0
                    startButtonWatcher:Show()
                end)
                found = true
            end
        end

        if TryHookStartButtons(child) then
            found = true
        end
    end

    return found
end

startButtonWatcher:SetScript("OnUpdate", function(self, elapsed)
    self.timer = self.timer + elapsed
    if self.timer >= 1.0 then
        self:Hide()
        TryRequestChoiceNow()
    end
end)

acceptDeathWatcher:SetScript("OnUpdate", function(self, elapsed)
    if not pendingDeathReset then
        self:Hide()
        return
    end

    self.timer = self.timer + elapsed
    self.timeout = self.timeout + elapsed

    if self.timer >= 0.2 then
        self.timer = 0
        TryHookAcceptDeathButtons(UIParent)
    end

    if self.timeout >= 15 then
        pendingDeathReset = false
        self:Hide()
    end
end)

local function ResetRunState(reason)
    currentRerolls = 0
    isProcessing = false
    lastChoicesRef = nil
    lastLoggedLevel = -1

    if pickerFrame then
        pickerFrame.state = nil
        pickerFrame.timer = 0
        pickerFrame:Hide()
    end

    isAutoStopped = false

    if EasyEcho_UI and EasyEcho_UI.ResetAllData then
        EasyEcho_UI.ResetAllData(reason or "Run reset detected. Data has been cleared.")
    else
        EasyEchoHistoryDB, EasyEchoLogDB = {}, {}
        if EasyEchoSettings then EasyEchoSettings.CurrentPickCount = 2 end
    end
end

local function NormalizeUiText(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return string.lower(text)
end

local function FrameHasAcceptDeathText(frame)
    if not frame then return false end

    if frame.GetText then
        local txt = NormalizeUiText(frame:GetText())
        if txt ~= "" and txt:find("accept", 1, true) and txt:find("death", 1, true) then
            return true
        end
    end

    if frame.GetRegions then
        local regions = {frame:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
                local txt = NormalizeUiText(region:GetText())
                if txt ~= "" and txt:find("accept", 1, true) and txt:find("death", 1, true) then
                    return true
                end
            end
        end
    end

    local name = frame.GetName and frame:GetName() or ""
    name = string.lower(name or "")
    if name:find("accept", 1, true) and name:find("death", 1, true) then
        return true
    end

    return false
end

local function IsAcceptDeathButton(frame)
    if not frame or frame.GetObjectType == nil then return false end
    if frame:GetObjectType() ~= "Button" then return false end
    return FrameHasAcceptDeathText(frame)
end

local function TryHookAcceptDeathButtons(root)
    if not root or not root.GetChildren then return false end

    local found = false
    local children = {root:GetChildren()}
    for _, child in ipairs(children) do
        if IsAcceptDeathButton(child) and not hookedAcceptDeathButtons[child] then
            hookedAcceptDeathButtons[child] = true
            child:HookScript("OnClick", function()
                if pendingDeathReset then
                    pendingDeathReset = false
                    ResetRunState("Accept Death selected. Data has been reset for a new run.")
                end
            end)
            found = true
        end

        if TryHookAcceptDeathButtons(child) then
            found = true
        end
    end

    return found
end

local function TryRequestChoiceNow()
    if isAutoStopped then return end
    if not ProjectEbonhold or not ProjectEbonhold.PerkService then return end

    local perkService = ProjectEbonhold.PerkService
    if not perkService.RequestChoice then return end

    perkService.RequestChoice()

    local getChoices = perkService.GetCurrentChoice
    local choices = getChoices and getChoices() or nil

    if choices and #choices > 0 and not isProcessing then
        currentRerolls, pickerFrame.state, pickerFrame.timer = 0, "START_DELAY", 0
        pickerFrame:Show()
    end
end

local function EnsureShowUiButton(startButton)
    if not startButton or showUiButtonsByStart[startButton] then return end

    local parent = startButton:GetParent() or UIParent
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(startButton:GetWidth() or 180, 24)
    btn:SetPoint("TOP", startButton, "BOTTOM", 0, -6)
    btn:SetText("Show UI")
    btn:SetScript("OnClick", function()
        if EasyEcho_UI and EasyEcho_UI.ShowMainWindow then
            EasyEcho_UI.ShowMainWindow()
        elseif EasyEcho_UI and EasyEcho_UI.Toggle then
            EasyEcho_UI.Toggle()
        end
    end)

    showUiButtonsByStart[startButton] = btn
end

local function IsStartButton(frame)
    if not frame or not frame.GetObjectType or frame:GetObjectType() ~= "Button" then return false end

    local txt = ""
    if frame.GetText then
        txt = NormalizeUiText(frame:GetText())
    end

    local name = frame.GetName and NormalizeUiText(frame:GetName()) or ""

    return txt == "start" or txt:find("start", 1, true) ~= nil or name:find("start", 1, true) ~= nil
end

local function TryHookStartButtons(root)
    if not root or not root.GetChildren then return false end

    local found = false
    local children = {root:GetChildren()}
    for _, child in ipairs(children) do
        if IsStartButton(child) then
            EnsureShowUiButton(child)

            if not hookedStartButtons[child] then
                hookedStartButtons[child] = true
                child:HookScript("OnClick", function()
                    TryRequestChoiceNow()
                    startButtonWatcher.timer = 0
                    startButtonWatcher:Show()
                end)
                found = true
            end
        end

        if TryHookStartButtons(child) then
            found = true
        end
    end

    return found
end

startButtonWatcher:SetScript("OnUpdate", function(self, elapsed)
    self.timer = self.timer + elapsed
    if self.timer >= 1.0 then
        self:Hide()
        TryRequestChoiceNow()
    end
end)

acceptDeathWatcher:SetScript("OnUpdate", function(self, elapsed)
    if not pendingDeathReset then
        self:Hide()
        return
    end

    self.timer = self.timer + elapsed
    self.timeout = self.timeout + elapsed

    if self.timer >= 0.2 then
        self.timer = 0
        TryHookAcceptDeathButtons(UIParent)
    end

    if self.timeout >= 15 then
        pendingDeathReset = false
        self:Hide()
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
	InitializePrioList()
        if not EasyEchoLogDB then EasyEchoLogDB = {} end
        if not EasyEchoSettings then EasyEchoSettings = {} end
        if not EasyEchoSettings.CurrentPickCount then EasyEchoSettings.CurrentPickCount = 2 end
        if EasyEcho_UI then EasyEcho_UI.Init() end
        SyncRerollStatus()
        TryHookStartButtons(UIParent)
        TryRequestChoiceNow()

        if ProjectEbonhold and ProjectEbonhold.PerkUI then
            hooksecurefunc(ProjectEbonhold.PerkUI, "Show", function()
                if isAutoStopped or isProcessing then return end
                currentRerolls, pickerFrame.state, pickerFrame.timer = 0, "START_DELAY", 0
                SyncRerollStatus()
                pickerFrame:Show()
            end)
        end
        return
    end

    if event == "PLAYER_DEAD" then
        pendingDeathReset = true
        acceptDeathWatcher.timer = 0
        acceptDeathWatcher.timeout = 0
        TryHookAcceptDeathButtons(UIParent)
        acceptDeathWatcher:Show()
        return
    end

    if event == "PLAYER_LEVEL_UP" then
        if EasyEcho_UI and EasyEcho_UI.UpdateEchoListUI and EasyEchoGrantedEchoesFrame and EasyEchoGrantedEchoesFrame:IsShown() then
            EasyEcho_UI.UpdateEchoListUI()
        end
        CheckAutoStopAtMaxLevel()
        return
    end

    if event == "PLAYER_ALIVE" then
        if pendingDeathReset and (UnitLevel("player") or 1) <= 1 then
            pendingDeathReset = false
            ResetRunState("New run detected after death. Data has been reset.")
        else
            pendingDeathReset = false
            acceptDeathWatcher:Hide()
        end
        SyncRerollStatus()
        TryHookStartButtons(UIParent)
        if (UnitLevel("player") or 1) < 80 then
            isAutoStopped = false
        else
            CheckAutoStopAtMaxLevel()
        end
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
