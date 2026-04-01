local addonName, addon = ...






local Perks = {}
if not addon.Perks then
    addon.Perks = Perks
else
    Perks = addon.Perks
end


Perks.currentChoice = nil 
Perks.grantedPerks = {} 
Perks.lockedPerks = {} 
Perks.maximumPermanentEchoes = 0 
Perks.pendingBanishIndex = nil -- Track which perk index is being banished
Perks.pendingRollsCount = nil -- Optional: if server sends "N|..." we use this; else we use level vs picksMade

local _charKey = nil
local function GetPerkPicksMadeCharKey()
    if not _charKey then
        local realm = GetNormalizedRealmName and GetNormalizedRealmName() or "Unknown"
        local name = UnitName and UnitName("player") or "Unknown"
        _charKey = realm .. "\t" .. name
    end
    return _charKey
end

local function GetPerkPicksMade()
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    ProjectEbonholdDB.perkPicksMade = ProjectEbonholdDB.perkPicksMade or {}
    ProjectEbonholdDB.perkLastLevel = ProjectEbonholdDB.perkLastLevel or {}
    local key = GetPerkPicksMadeCharKey()
    local level = UnitLevel and UnitLevel("player") or 1
    -- Restart = back to level 1, keep nothing.
    if level <= 1 then
        ProjectEbonholdDB.perkPicksMade[key] = 0
        ProjectEbonholdDB.perkLastLevel[key] = 1
        return 0
    end
    -- Level dropped (respawn at 1 then leveled to 4 without us ever seeing level 1): new run, reset picks.
    local lastLevel = ProjectEbonholdDB.perkLastLevel[key] or 0
    if level < lastLevel then
        ProjectEbonholdDB.perkPicksMade[key] = 0
    end
    ProjectEbonholdDB.perkLastLevel[key] = level
    return ProjectEbonholdDB.perkPicksMade[key] or 0
end

-- Level for "rolls left": use UnitLevel("player") so it matches the level on your character sheet.
local function GetPerkLevel()
    local live = UnitLevel and UnitLevel("player")
    if live and live > 0 then return live end
    return 1
end

local function IncrementPerkPicksMade()
    local level = UnitLevel and UnitLevel("player") or 1
    if level <= 1 then return end  -- don't count when level 1
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    ProjectEbonholdDB.perkPicksMade = ProjectEbonholdDB.perkPicksMade or {}
    local key = GetPerkPicksMadeCharKey()
    ProjectEbonholdDB.perkPicksMade[key] = GetPerkPicksMade() + 1
end

local function ResetPicksMade()
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    ProjectEbonholdDB.perkPicksMade = ProjectEbonholdDB.perkPicksMade or {}
    local key = GetPerkPicksMadeCharKey()
    ProjectEbonholdDB.perkPicksMade[key] = 0
end 

ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_PLAYER_PERK_CHOICE,
                                function(body)
    Perks.pendingReroll = nil -- new offer arrived, unblock rerolls

    if not body or body == "" then
        Perks.currentChoice = nil
        Perks.pendingRollsCount = nil
        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.Hide then
            ProjectEbonhold.PerkUI.Hide()
        end
        return
    end

    -- Optional: server can send "N|spellId,q;..." to indicate N pending rolls (including this one)
    local bodyToParse = body
    local n, rest = body:match("^(%d+)|(.+)$")
    if n and rest then
        local num = tonumber(n)
        if num and num > 0 then
            Perks.pendingRollsCount = num
            bodyToParse = rest
        end
    else
        Perks.pendingRollsCount = nil  -- no server count: use level-based so (1) doesn't stick
    end

    local choices = {}
    local count = 0
    for perkPair in string.gmatch(bodyToParse, "([^;]+)") do
        local spellIdStr, qualityStr = perkPair:match("^([^,]+),([^,]+)$")
        if spellIdStr and qualityStr then
            local spellId = tonumber(spellIdStr)
            local quality = tonumber(qualityStr)
            if spellId and spellId ~= 0 and quality then
                table.insert(choices, {spellId = spellId, quality = quality})
                count = count + 1
            end
        end
    end

    if count == 0 then
        Perks.currentChoice = nil
        return
    end

    
    Perks.currentChoice = choices
    table.remove(choices)

    if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.Show then
        ProjectEbonhold.PerkUI.Show(choices)
    else
        
        for i, choice in ipairs(choices) do
            local spellName = GetSpellInfo(choice.spellId)
            local qualityNames = {
                [0] = "Common",
                [1] = "Uncommon",
                [2] = "Rare",
                [3] = "Epic",
                [4] = "Legendary"
            }
            local qualityName = qualityNames[choice.quality] or "Unknown"
        end
    end
end)



ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_PLAYER_PERK_SELECTION_RESULT,
                                function(body)
    -- -- print("[DEBUG] Received SEND_PLAYER_PERK_SELECTION_RESULT with body: " .. tostring(body))
    Perks.pendingSelectSpellId = nil -- selection resolved, unblock picks
    -- Selection succeeded
    if body == "1" then
        -- -- print("[DEBUG] Perk selection succeeded")
        Perks.currentChoice = nil
        IncrementPerkPicksMade()

        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.Hide then
            ProjectEbonhold.PerkUI.Hide()
        end
        
        Perks.RequestChoice()
        
        Perks.RequestGrantedPerks()
    elseif body == "0" then
        -- -- print("[DEBUG] Perk selection failed server-side")
        -- Selection failed server-side, re-enable interaction so player can try again
        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.ResetSelection then
            ProjectEbonhold.PerkUI.ResetSelection()
        end
    end
end)




ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_PLAYER_PERK_GRANTED,
                                function(body)
    
    Perks.grantedPerks = {}
    Perks.lockedPerks = {}

    if not body or body == "" then
        if ProjectEbonhold and ProjectEbonhold.PlayerRunUI and ProjectEbonhold.PlayerRunUI.UpdateGrantedPerks then
            ProjectEbonhold.PlayerRunUI.UpdateGrantedPerks()
        end
        return
    end

    
    local parts = {}
    for part in string.gmatch(body, "([^;]+)") do
        table.insert(parts, part)
    end

    if #parts == 0 then
        if ProjectEbonhold and ProjectEbonhold.PlayerRunUI and ProjectEbonhold.PlayerRunUI.UpdateGrantedPerks then
            ProjectEbonhold.PlayerRunUI.UpdateGrantedPerks()
        end
        return
    end

    
    local maxSlotsStr = parts[1]
    local serverMaxSlots = tonumber(maxSlotsStr)
    
    if serverMaxSlots and serverMaxSlots > 0 then
        Perks.maximumPermanentEchoes = serverMaxSlots
    end
    

    
    local perkCount = 0
    for i = 2, #parts do
        local perkData = parts[i]
        
        
        local spellIdStr, stackStr, maxStackStr, qualityStr, lockedStr = perkData:match(
                                                                  "^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$")

        if not spellIdStr then
            
            spellIdStr, stackStr, maxStackStr = perkData:match(
                                                    "^([^,]+),([^,]+),([^,]+)$")
            qualityStr = nil
            lockedStr = nil
        end

        if spellIdStr and stackStr and maxStackStr then
            local spellId = tonumber(spellIdStr)
            local stack = tonumber(stackStr)
            local maxStack = tonumber(maxStackStr)
            local quality = qualityStr and tonumber(qualityStr) or 0 
            local isLocked = lockedStr and tonumber(lockedStr) == 1 or false

            if spellId and stack and maxStack then
                if isLocked then
                    
                    table.insert(Perks.lockedPerks, {
                        spellId = spellId,
                        stack = stack, 
                        maxStack = maxStack,
                        quality = quality
                    })
                    perkCount = perkCount + 1
                else
                    
                    local spellName = GetSpellInfo(spellId)
                    if spellName then
                        if not Perks.grantedPerks[spellName] then
                            Perks.grantedPerks[spellName] = {}
                        end
                        for i = 1, stack do
                            table.insert(Perks.grantedPerks[spellName], {
                                spellId = spellId,
                                stack = 1, 
                                maxStack = maxStack,
                                quality = quality
                            })
                            perkCount = perkCount + 1
                        end
                    end
                end
            end
        end
    end

    if perkCount == 0 then end
    
    if ProjectEbonhold and ProjectEbonhold.PlayerRunUI and
        ProjectEbonhold.PlayerRunUI.UpdateGrantedPerks then
        ProjectEbonhold.PlayerRunUI.UpdateGrantedPerks()
    end
end)


-- Handle banish replacement perk response
ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_BANISH_REPLACEMENT_PERK,
                                function(body)
    -- -- print("[DEBUG] Received SEND_BANISH_REPLACEMENT_PERK with body: " .. tostring(body))
    
    -- Check if we have a pending banish
    if not Perks.pendingBanishIndex then
        -- -- print("[DEBUG] No pending banish index stored")
        return
    end
    
    local perkIndex = Perks.pendingBanishIndex
    Perks.pendingBanishIndex = nil -- Clear pending banish
    
    if not body or body == "" then
        -- Banish failed - server sent empty response
        -- -- print("[DEBUG] Banish failed - empty response from server")
        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.ResetSelection then
            ProjectEbonhold.PerkUI.ResetSelection()
        end
        return
    end
    
    -- Parse the replacement perk data: "new_spell_id,new_quality"
    local newSpellId, newQuality
    local commaPos = string.find(body, ",")
    if commaPos then
        newSpellId = tonumber(string.sub(body, 1, commaPos - 1))
        newQuality = tonumber(string.sub(body, commaPos + 1))
    else
        -- Fallback for old format (just spell ID)
        newSpellId = tonumber(body)
        newQuality = 0
    end
    
    -- -- print("[DEBUG] Banish response - newSpellId: " .. tostring(newSpellId) .. " for perkIndex: " .. tostring(perkIndex))
    
    if not newSpellId then
        -- -- print("[DEBUG] Invalid banish response - could not parse spell ID")
        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.ResetSelection then
            ProjectEbonhold.PerkUI.ResetSelection()
        end
        return
    end
    
    if newSpellId == 0 then
        -- Banish failed (server returned 0)
        -- -- print("[DEBUG] Banish failed - server returned spellId 0")
        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.ResetSelection then
            ProjectEbonhold.PerkUI.ResetSelection()
        end
        return
    end
    
    -- Banish succeeded - update the perk choice at the specified index
    -- -- print("[DEBUG] Banish succeeded - updating perk choice at index " .. tostring(perkIndex + 1))
    if Perks.currentChoice and Perks.currentChoice[perkIndex + 1] then
        local oldSpellId = Perks.currentChoice[perkIndex + 1].spellId
        local oldQuality = Perks.currentChoice[perkIndex + 1].quality
        
        Perks.currentChoice[perkIndex + 1].spellId = newSpellId
        Perks.currentChoice[perkIndex + 1].quality = newQuality or 0
        
        -- -- print("[DEBUG] Replaced spell " .. tostring(oldSpellId) .. " with " .. tostring(newSpellId))
        
        -- Use animated single perk update instead of full refresh
        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.UpdateSinglePerk then
            -- -- print("[DEBUG] Using UpdateSinglePerk for animated replacement")
            ProjectEbonhold.PerkUI.UpdateSinglePerk(perkIndex, Perks.currentChoice[perkIndex + 1])
        elseif ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.Show then
            -- Fallback to full refresh if UpdateSinglePerk not available
            -- -- print("[DEBUG] Falling back to full UI refresh")
            ProjectEbonhold.PerkUI.Show(Perks.currentChoice)
        end
        
        -- Re-enable interaction after animation
        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.ResetSelection then
            ProjectEbonhold.PerkUI.ResetSelection()
        end
    else
        -- -- print("[DEBUG] Could not find current choice at index " .. tostring(perkIndex + 1))
        if ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.ResetSelection then
            ProjectEbonhold.PerkUI.ResetSelection()
        end
    end
end)


function Perks.RequestChoice()
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_PLAYER_PERK_CHOICE,
                                 "")
end


function Perks.SelectPerk(spellId)
    -- -- print("[DEBUG] Perks.SelectPerk called with spellId: " .. tostring(spellId))
    if Perks.pendingSelectSpellId then return false end -- pick already in flight
    if not spellId or spellId == 0 then 
        -- -- print("[DEBUG] SelectPerk: Invalid spellId")
        return false 
    end

    -- Check if we have current choices
    if not Perks.currentChoice then 
        -- -- print("[DEBUG] SelectPerk: No current choices available")
        return false 
    end

    local found = false
    for _, choice in ipairs(Perks.currentChoice) do
        if choice.spellId == spellId then
            found = true
            break
        end
    end

    if not found then 
        -- -- print("[DEBUG] SelectPerk: SpellId not found in current choices")
        return false 
    end
    
    -- -- print("[DEBUG] SelectPerk: Sending to server - REQUEST_PLAYER_PERK_SELECTION with spellId: " .. tostring(spellId))
    Perks.pendingSelectSpellId = spellId
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_PLAYER_PERK_SELECTION, tostring(spellId))
    return true
end


function Perks.RequestGrantedPerks()
    ProjectEbonhold.sendToServer(
        ProjectEbonhold.CS.REQUEST_PLAYER_GRANTED_PERKS, "")
end


function Perks.RequestReroll()
    if Perks.pendingReroll then return false end -- reroll already in flight
    Perks.pendingReroll = true
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_REROLL, "")
    return true
end


function Perks.BanishPerk(perkIndex)
    -- -- print("[DEBUG] Perks.BanishPerk called with perkIndex: " .. tostring(perkIndex))
    if Perks.pendingBanishIndex then return false end -- banish already in flight
    if not perkIndex or perkIndex < 0 or perkIndex > 2 then 
        -- -- print("[DEBUG] BanishPerk: Invalid perkIndex")
        return false 
    end
    
    -- Check if banish system is enabled
    if not ProjectEbonhold.Constants or not ProjectEbonhold.Constants.ENABLE_BANISH_SYSTEM then
        -- -- print("[DEBUG] BanishPerk: Banish system is disabled")
        return false
    end
    
    -- Check if we have remaining banishes
    local runData = ProjectEbonhold.PlayerRunService and ProjectEbonhold.PlayerRunService.GetCurrentData() or {}
    local remainingBanishes = runData.remainingBanishes or 0
    -- -- print("[DEBUG] BanishPerk: Remaining banishes: " .. tostring(remainingBanishes))
    if remainingBanishes <= 0 then
        -- -- print("[DEBUG] BanishPerk: No remaining banishes")
        return false
    end
    
    -- Store which perk we're trying to banish
    Perks.pendingBanishIndex = perkIndex
    -- -- print("[DEBUG] BanishPerk: Stored pending banish index: " .. tostring(perkIndex))
    
    -- -- print("[DEBUG] BanishPerk: Sending to server - REQUEST_BANISH_PERK with perkIndex: " .. tostring(perkIndex))
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_BANISH_PERK, tostring(perkIndex))
    return true
end






ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.Perks = Perks 
ProjectEbonhold.PerkService = ProjectEbonhold.PerkService or {}
ProjectEbonhold.PerkService.RequestChoice = Perks.RequestChoice
ProjectEbonhold.PerkService.SelectPerk = Perks.SelectPerk
ProjectEbonhold.PerkService.RequestGrantedPerks = Perks.RequestGrantedPerks
ProjectEbonhold.PerkService.RequestReroll = Perks.RequestReroll
ProjectEbonhold.PerkService.BanishPerk = Perks.BanishPerk
ProjectEbonhold.PerkService.GetCurrentChoice = function()
    return Perks.currentChoice
end
-- Rolls left = (level - 1) - picksMade. Level = value from PLAYER_LEVEL_UP (stored) or UnitLevel.
ProjectEbonhold.PerkService.GetPendingRollsCount = function()
    local level = GetPerkLevel()
    local rollsOffered = math.min(80, math.max(0, level - 1))
    local picksMade = GetPerkPicksMade()
    -- Cap picks at (level - 1) so bad saved data never gives negative rolls
    picksMade = math.min(picksMade, rollsOffered)
    return math.max(0, rollsOffered - picksMade)
end
-- For tooltip: level, picks made (capped), rolls left
ProjectEbonhold.PerkService.GetRollsDebugInfo = function()
    local level = GetPerkLevel()
    local rollsOffered = math.min(80, math.max(0, level - 1))
    local picksMade = math.min(GetPerkPicksMade(), rollsOffered)
    local rollsLeft = math.max(0, rollsOffered - picksMade)
    return level, picksMade, rollsLeft
end
ProjectEbonhold.PerkService.ResetPicksMade = ResetPicksMade
ProjectEbonhold.PerkService.GetGrantedPerks = function()
    return Perks.grantedPerks
end
ProjectEbonhold.PerkService.GetLockedPerks = function()
    return Perks.lockedPerks
end
ProjectEbonhold.PerkService.GetMaximumPermanentEchoes = function()
    return Perks.maximumPermanentEchoes or 0
end
ProjectEbonhold.PerkService.LockPerk = function(spellId, count)
    if not spellId or spellId == 0 then return false end
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_LOCK_PERK, tostring(spellId))
    return true
end
ProjectEbonhold.PerkService.UnlockPerk = function(spellId)
    if not spellId or spellId == 0 then return false end
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_UNLOCK_PERK, tostring(spellId))
    return true
end