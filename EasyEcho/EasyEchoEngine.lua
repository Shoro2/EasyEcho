-- EasyEchoEngine.lua
-- Split-out choice processing / reroll / picker frame state machine
-- Generated: 2026-02-15 21:38:32

EasyEcho = EasyEcho or {}
EasyEcho.Engine = EasyEcho.Engine or {}

local C = EasyEcho.Constants
local S = EasyEcho.State
local QUALITY_NAMES = EasyEcho.QUALITY_NAMES

local function SetAutoStopped(stopped, reason)
    S.isAutoStopped = stopped and true or false
    if S.isAutoStopped then
        S.isProcessing = false
        if S.pickerFrame then
            S.pickerFrame.state = nil
            S.pickerFrame.timer = 0
            S.pickerFrame:Hide()
        end
        if reason and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[EasyEcho]|r " .. reason)
        end
    end
end

function EasyEcho.Engine.CheckAutoStopAtMaxLevel()
    local lvl = UnitLevel("player") or 1
    if lvl < 80 then return false end

    local choices = ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
    if not choices or #choices == 0 then
        SetAutoStopped(true, "Level 80 reached and no echoes are available. EasyEcho stopped automatically.")
        return true
    end
    return false
end

local function GetExactPriorityRank(name, quality)
    local specKey = string.lower(name .. "::" .. (QUALITY_NAMES[quality] or "Common"))
    local anyKey  = string.lower(name .. "::Any")
    for i, listKey in ipairs(EasyEcho_PrioList) do
        local lowKey = string.lower(listKey)
        if lowKey == specKey or lowKey == anyKey then return i end
    end
    return 99999
end

local function CheckPriority(choices)
    local bestRank, bestName, bestQual, bestIdx = 99999, nil, nil, nil
    for i, choice in ipairs(choices) do
        local name = GetSpellInfo(choice.spellId)
        if name and not EasyEcho.IsBanned(name) then
            if not (EasyEcho.ONE_TIME_MAP[string.lower(name)] and EasyEcho.PlayerAlreadyHasPerk(name)) then
                local rank = GetExactPriorityRank(name, choice.quality)
                if rank < bestRank then
                    bestRank, bestName, bestQual, bestIdx = rank, name, choice.quality, i
                end
            end
        end
    end
    if bestRank < 99999 then return bestName, bestQual, bestIdx end
    return nil, nil, nil
end

local function CheckBanned(choices)
    local allBanned = true
    local bannedNames = {}
    for _, choice in ipairs(choices) do
        local name = GetSpellInfo(choice.spellId)
        if name then
            if EasyEcho.IsBanned(name) then
                table.insert(bannedNames, name)
            else
                allBanned = false
            end
        end
    end
    return allBanned, table.concat(bannedNames, ", ")
end

local function StartPicker()
    S.currentRerolls = 0
    S.pickerFrame.state = "START_DELAY"
    S.pickerFrame.timer = 0
    EasyEcho.SyncRerollStatus()
    S.pickerFrame:Show()
end

local function HandleReroll(pickLevel, reason)
    if pickLevel < C.MIN_LEVEL_FOR_REROLL then return false end
    local usedRerolls, totalRerolls = EasyEcho.GetServerRunData()
    if S.currentRerolls >= C.MAX_REROLLS_PER_CHOICE then return false end
    if usedRerolls >= totalRerolls then return false end

    S.currentRerolls = S.currentRerolls + 1
    EasyEcho.SyncRerollStatus(usedRerolls + 1, totalRerolls)
    EasyEcho.LogDecision("REROLL", "-", nil, reason, usedRerolls + 1, totalRerolls, false)

    -- Reset so the new offers after reroll are logged in history
    S.lastLoggedPick = -1

    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.RequestReroll then
        ProjectEbonhold.PerkService.RequestReroll()
    end

    S.pickerFrame.state = "WAIT_FOR_NEW_CARDS"
    S.pickerFrame.timer = 0
    return true
end

local function SelectSpell(idx, name, quality, pickLevel, isPrio)
    S.isProcessing = true

    local choices = ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
    if not choices or not choices[idx] then
        S.isProcessing = false
        return
    end

    EasyEcho.LogDecision("SELECT", name or "Unknown", quality, isPrio and "Priority match" or "Fallback", 0, 0, isPrio)

    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.SelectPerk then
        ProjectEbonhold.PerkService.SelectPerk(choices[idx].spellId)
    end

    if EasyEchoSettings then
        EasyEchoSettings.CurrentPickCount = (EasyEchoSettings.CurrentPickCount or 2) + 1
    end

    S.pickerFrame.state = "LOCKED"
    S.pickerFrame.timer = 0
end

local function ProcessChoices()
    if not EasyEcho_IsRunning or S.isAutoStopped or S.isProcessing then return end

    local pickLevel = EasyEchoSettings and EasyEchoSettings.CurrentPickCount or 2
    local choices = ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
    if not choices then
        EasyEcho.Engine.CheckAutoStopAtMaxLevel()
        return
    end

    EasyEcho.SyncRerollStatus()

    -- Log options only once per pick
    if S.lastLoggedPick ~= pickLevel then
        if EasyEcho_UI and EasyEcho_UI.AddOptionsToHistory then
            EasyEcho_UI.AddOptionsToHistory(choices, pickLevel)
        end
        S.lastLoggedPick = pickLevel
    end

    -- 1) Priority match
    local mSpell, mQual, mIdx = CheckPriority(choices)
    if mSpell then
        SelectSpell(mIdx, mSpell, mQual, pickLevel, true)
        return
    end

    -- 2) Auto-banish: replace individual choices from banish list using banish tokens
    local remainingBanishes = EasyEcho.GetRemainingBanishes()
    if remainingBanishes > 0 then
        for i, choice in ipairs(choices) do
            local name = GetSpellInfo(choice.spellId)
            if name and EasyEcho.IsBanished(name) then
                if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.BanishPerk then
                    ProjectEbonhold.PerkService.BanishPerk(i - 1)
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r [#" .. pickLevel .. "] Auto-banishing: " .. name)
                    end
                    EasyEcho.WriteToLog(string.format("ACTION [#%d]: BANISH -> %s (banish list, %d remaining)", pickLevel, name, remainingBanishes - 1))
                    S.pickerFrame.state = "WAIT_FOR_BANISH"
                    S.pickerFrame.timer = 0
                    return
                end
            end
        end
    end

    -- 3) All banned -> reroll (or fallback left)
    local allBanned, bannedNames = CheckBanned(choices)
    if allBanned then
        if HandleReroll(pickLevel, "All banned: " .. bannedNames) then return end
        local fName = GetSpellInfo(choices[1].spellId)
        SelectSpell(1, fName, choices[1].quality, pickLevel, false)
        return
    end

    -- 4) No priority match -> reroll if possible
    if HandleReroll(pickLevel, "No priority match") then return end

    -- 5) Final fallback: left-most non-banned, non-duplicate-one-time choice
    local fallbackIdx = nil
    for i, choice in ipairs(choices) do
        local fname = GetSpellInfo(choice.spellId)
        if fname and not EasyEcho.IsBanned(fname) then
            if not (EasyEcho.ONE_TIME_MAP[string.lower(fname)] and EasyEcho.PlayerAlreadyHasPerk(fname)) then
                fallbackIdx = i
                break
            end
        end
    end
    -- If everything is banned/skipped, pick first non-banned at least
    if not fallbackIdx then
        for i, choice in ipairs(choices) do
            local fname = GetSpellInfo(choice.spellId)
            if fname and not EasyEcho.IsBanned(fname) then
                fallbackIdx = i
                break
            end
        end
    end
    -- If everything is banned (shouldn't reach here due to step 2, but safety net)
    if not fallbackIdx then fallbackIdx = 1 end
    local finalName = GetSpellInfo(choices[fallbackIdx].spellId)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r No profile match. Picking leftmost non-banned.")
    end
    SelectSpell(fallbackIdx, finalName, choices[fallbackIdx].quality, pickLevel, false)
end

-- Public API used by hooks / main
function EasyEcho.Engine.TryRequestChoiceNow()
    if not EasyEcho_IsRunning then return end
    if S.isAutoStopped then return end
    if not ProjectEbonhold or not ProjectEbonhold.PerkService then return end

    local perkService = ProjectEbonhold.PerkService
    if not perkService.RequestChoice then return end

    perkService.RequestChoice()

    local getChoices = perkService.GetCurrentChoice
    local choices = getChoices and getChoices() or nil
    if choices and #choices > 0 and not S.isProcessing then
        StartPicker()
    end
end

function EasyEcho.Engine.StartPicker()
    if not EasyEcho_IsRunning then return end
    if S.isAutoStopped or S.isProcessing then return end
    StartPicker()
end

-- Picker frame state machine
S.pickerFrame:SetScript("OnUpdate", function(self, elapsed)
    if not EasyEcho_IsRunning then
        self.state = nil
        self.timer = 0
        self:Hide()
        return
    end

    self.timer = self.timer + elapsed

    if self.state == "START_DELAY" and self.timer > C.DELAY_TIME then
        self.state = "PROCESSING"
        ProcessChoices()
        if self.state == "PROCESSING" then
            self.state = nil
            self:Hide()
        end

    elseif self.state == "WAIT_FOR_BANISH" and self.timer > 1.5 then
        -- Banish replacement should have arrived by now; re-evaluate choices
        self.timer = 0
        S.isProcessing = false
        self.state = "START_DELAY"

    elseif self.state == "WAIT_FOR_NEW_CARDS" and self.timer > 0.05 then
        self.timer = 0
        local cur = ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
        if cur and cur ~= S.lastChoicesRef then
            S.isProcessing = false
            S.lastChoicesRef = cur
            self.state = "START_DELAY"
            self.timer = 0
        end

    elseif self.state == "LOCKED" and self.timer > 0.2 then
        self.timer = 0
        local cur = ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
        if cur and cur ~= S.lastChoicesRef then
            S.isProcessing = false
            S.lastChoicesRef = cur
            self.state = "START_DELAY"
            self.timer = 0
        elseif (UnitLevel("player") or 1) >= 80 and not cur then
            EasyEcho.Engine.CheckAutoStopAtMaxLevel()
        end
    end
end)
