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
        if name and not EasyEcho.IsBanned(name) and not EasyEcho.IsBanished(name) then
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
        local ok = ProjectEbonhold.PerkService.RequestReroll()
        if ok == false then
            S.pickerFrame.state = "START_DELAY"
            S.pickerFrame.timer = 0
            EasyEcho.WriteToLog("REROLL blocked: reroll already in flight, retrying")
            return true
        end
    end

    -- Snapshot current choices so WAIT_FOR_NEW_CARDS can detect when they change
    local curChoices = ProjectEbonhold and ProjectEbonhold.PerkService
        and ProjectEbonhold.PerkService.GetCurrentChoice
        and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
    if curChoices then
        S.lastChoicesRef = curChoices
    end
    S.waitForNewCardsStart = GetTime()

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
        local ok = ProjectEbonhold.PerkService.SelectPerk(choices[idx].spellId)
        if ok == false then
            S.isProcessing = false
            S.pickerFrame.state = "START_DELAY"
            S.pickerFrame.timer = 0
            EasyEcho.WriteToLog("SELECT blocked: pick already in flight, retrying")
            return
        end
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

    local remainingBanishes = EasyEcho.GetRemainingBanishes()

    -- 1) Priority match first: if an echo from the priority list is available, select it
    --    immediately without wasting any banish tokens
    local mSpell, mQual, mIdx = CheckPriority(choices)
    if mSpell then
        SelectSpell(mIdx, mSpell, mQual, pickLevel, true)
        return
    end

    -- 2) No priority match: banish commons so all choices become uncommon+
    --    but skip commons that are on the priority list (they should be selectable)
    if remainingBanishes > 0 then
        for i, choice in ipairs(choices) do
            local name = GetSpellInfo(choice.spellId)
            if name and (choice.quality or 0) == 0 then
                -- Don't banish commons that the user has on their priority list
                if GetExactPriorityRank(name, choice.quality) >= 99999 then
                    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.BanishPerk then
                        local ok = ProjectEbonhold.PerkService.BanishPerk(i - 1)
                        if ok == false then
                            S.pickerFrame.state = "START_DELAY"
                            S.pickerFrame.timer = 0
                            EasyEcho.WriteToLog("BANISH blocked: banish already in flight, retrying")
                            return
                        end
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r [#" .. pickLevel .. "] Auto-banishing common: " .. name)
                        end
                        EasyEcho.WriteToLog(string.format("ACTION [#%d]: BANISH -> %s (common quality, %d remaining)", pickLevel, name, remainingBanishes - 1))
                        S.pickerFrame.state = "WAIT_FOR_BANISH"
                        S.pickerFrame.timer = 0
                        return
                    end
                else
                    EasyEcho.WriteToLog(string.format("SKIP BANISH [#%d]: %s is common but on priority list, keeping", pickLevel, name))
                end
            end
        end
    end

    -- 3) Auto-banish: replace individual choices from banish list using banish tokens
    if remainingBanishes > 0 then
        for i, choice in ipairs(choices) do
            local name = GetSpellInfo(choice.spellId)
            if name and EasyEcho.IsBanished(name) then
                if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.BanishPerk then
                    local ok = ProjectEbonhold.PerkService.BanishPerk(i - 1)
                    if ok == false then
                        S.pickerFrame.state = "START_DELAY"
                        S.pickerFrame.timer = 0
                        EasyEcho.WriteToLog("BANISH blocked: banish already in flight, retrying")
                        return
                    end
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

    -- 4) Check if all choices are unusable (banned / banished / one-time already owned)
    local allUnusable = true
    local allBanned = true
    local unusableReasons = {}
    for _, choice in ipairs(choices) do
        local name = GetSpellInfo(choice.spellId)
        if name then
            local isBanned = EasyEcho.IsBanned(name)
            local isBanished = EasyEcho.IsBanished(name)
            local isOneTimeOwned = EasyEcho.ONE_TIME_MAP[string.lower(name)] and EasyEcho.PlayerAlreadyHasPerk(name)
            if not isBanned then allBanned = false end
            if not isBanned and not isBanished and not isOneTimeOwned then
                allUnusable = false
            else
                table.insert(unusableReasons, name)
            end
        end
    end

    if allUnusable then
        -- Try banishing a banned card if tokens available
        if allBanned and remainingBanishes > 0 then
            local name = GetSpellInfo(choices[1].spellId)
            if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.BanishPerk then
                local ok = ProjectEbonhold.PerkService.BanishPerk(0)
                if ok == false then
                    S.pickerFrame.state = "START_DELAY"
                    S.pickerFrame.timer = 0
                    EasyEcho.WriteToLog("BANISH blocked: banish already in flight, retrying")
                    return
                end
                if DEFAULT_CHAT_FRAME then
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r [#" .. pickLevel .. "] Auto-banishing banned card: " .. (name or "Unknown"))
                end
                EasyEcho.WriteToLog(string.format("ACTION [#%d]: BANISH -> %s (all banned, %d remaining)", pickLevel, name or "Unknown", remainingBanishes - 1))
                S.pickerFrame.state = "WAIT_FOR_BANISH"
                S.pickerFrame.timer = 0
                return
            end
        end
        -- All unusable -> reroll
        local reason = "All unusable: " .. table.concat(unusableReasons, ", ")
        if HandleReroll(pickLevel, reason) then return end
        -- No rerolls left -> wait (never pick a banned/banished/already-owned echo)
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[EasyEcho]|r All choices unusable and no reroll/banish available. Waiting.")
        end
        EasyEcho.WriteToLog(string.format("SKIP [#%d]: All choices unusable, no reroll/banish available", pickLevel))
        S.pickerFrame.state = "START_DELAY"
        S.pickerFrame.timer = 0
        return
    end

    -- 5) No priority match -> reroll only if all banishes gone and level >= 11
    if remainingBanishes <= 0 then
        if HandleReroll(pickLevel, "No priority match") then return end
    end

    -- 6) Family-priority fallback: pick best echo by family priority order, preferring higher quality
    local familyList = EasyEcho_FamilyPrio
    if familyList and #familyList > 0 and ProjectEbonhold and ProjectEbonhold.PerkDatabase then
        local bestFamilyRank, bestQuality, bestFamilyIdx, bestFamilyName = 99999, -1, nil, nil
        for i, choice in ipairs(choices) do
            local fname = GetSpellInfo(choice.spellId)
            if fname and not EasyEcho.IsBanned(fname) and not EasyEcho.IsBanished(fname) then
                if not (EasyEcho.ONE_TIME_MAP[string.lower(fname)] and EasyEcho.PlayerAlreadyHasPerk(fname)) then
                    local perkData = ProjectEbonhold.PerkDatabase and ProjectEbonhold.PerkDatabase[choice.spellId]
                    local families = perkData and perkData.families
                    -- Echoes without families (or empty families table) are treated as "No Family"
                    if not families or #families == 0 then
                        families = { "No Family" }
                    end
                    for _, family in ipairs(families) do
                        local rank = 99999
                        for fi, fn in ipairs(familyList) do
                            if string.lower(fn) == string.lower(family) then rank = fi; break end
                        end
                        if rank < bestFamilyRank or (rank == bestFamilyRank and (choice.quality or 0) > bestQuality) then
                            bestFamilyRank = rank
                            bestQuality = choice.quality or 0
                            bestFamilyIdx = i
                            bestFamilyName = fname
                        end
                    end
                end
            end
        end
        if bestFamilyIdx then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r No prio match. Family fallback: " .. (bestFamilyName or "Unknown"))
            end
            SelectSpell(bestFamilyIdx, bestFamilyName, choices[bestFamilyIdx].quality, pickLevel, false)
            return
        end
    end

    -- 7) Final fallback: left-most usable (non-banned, non-banished, non-duplicate-one-time) choice
    --    Step 4 already ensures we only reach here if at least one choice IS usable.
    local fallbackIdx = nil
    local fallbackName = nil
    for i, choice in ipairs(choices) do
        local fname = GetSpellInfo(choice.spellId)
        if fname and not EasyEcho.IsBanned(fname) and not EasyEcho.IsBanished(fname) then
            if not (EasyEcho.ONE_TIME_MAP[string.lower(fname)] and EasyEcho.PlayerAlreadyHasPerk(fname)) then
                fallbackIdx = i
                fallbackName = fname
                break
            end
        end
    end
    if not fallbackIdx then
        -- Shouldn't reach here (step 4 catches all-unusable), but safety net
        S.pickerFrame.state = "START_DELAY"
        S.pickerFrame.timer = 0
        return
    end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r No profile match. Picking fallback: " .. (fallbackName or "Unknown"))
    end
    SelectSpell(fallbackIdx, fallbackName, choices[fallbackIdx].quality, pickLevel, false)
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
            S.waitForNewCardsStart = nil
            self.state = "START_DELAY"
            self.timer = 0
        elseif S.waitForNewCardsStart and (GetTime() - S.waitForNewCardsStart) > 3 then
            S.isProcessing = false
            S.waitForNewCardsStart = nil
            self.state = "START_DELAY"
            self.timer = 0
            EasyEcho.WriteToLog("WAIT_FOR_NEW_CARDS timeout: cur=" .. tostring(cur ~= nil) .. " sameRef=" .. tostring(cur == S.lastChoicesRef))
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
