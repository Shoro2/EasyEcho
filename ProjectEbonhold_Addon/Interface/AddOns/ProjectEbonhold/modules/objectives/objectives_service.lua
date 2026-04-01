local addonName, addon = ...

ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.ObjectivesService = {}

local Objectives = {}
Objectives.currentObjectives = {}
Objectives.activeObjective = nil

local function RequestObjectives()
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_OBJECTIVES_PROPOSALS, "")
end

local function GetObjectiveRerollCost(level)
    return level * level * 15 + level * 100
end

local function RequestRerollObjectives()
    local cost = GetObjectiveRerollCost(UnitLevel("player"))
    if GetMoney() < cost then
        print("|cFFFF0000You don't have enough gold to reroll objectives. Cost: " .. GetCoinTextureString(cost) .. "|r")
        return
    end
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_REROLL_OBJECTIVES, "")
end

function ProjectEbonhold.ObjectivesService.CanAffordReroll()
    return GetMoney() >= GetObjectiveRerollCost(UnitLevel("player"))
end

function ProjectEbonhold.ObjectivesService.GetRerollCost()
    return GetObjectiveRerollCost(UnitLevel("player"))
end

-- Quest objective types
local QUEST_OBJECTIVE_TYPE_OPEN_WORLD = 1
local QUEST_OBJECTIVE_TYPE_DUNGEON    = 2
local QUEST_OBJECTIVE_TYPE_RAID       = 3
local QUEST_OBJECTIVE_TYPE_PROFESSION = 4

-- Parse a single objective string into an objective table
-- Format: questId,title,objectives,zoneOrSort,questType,normalSoulAshes,hc1SoulAshes,hc2SoulAshes,hc3SoulAshes,normalXp,hc1Xp,hc2Xp,hc3Xp
local function ParseSingleObjective(objectiveStr)
    if not objectiveStr or objectiveStr == "" then
        return nil
    end

    local parts = {}
    for part in string.gmatch(objectiveStr, "([^,]+)") do
        table.insert(parts, part)
    end

    -- Minimum 13 fields: questId, title, objectives, zoneOrSort, questType, normalSoulAshes, hc1SoulAshes, hc2SoulAshes, hc3SoulAshes, normalXp, hc1Xp, hc2Xp, hc3Xp
    if #parts >= 13 then
        local questId          = parts[1]
        local title            = parts[2]
        local hc3Xp            = parts[#parts]
        local hc2Xp            = parts[#parts - 1]
        local hc1Xp            = parts[#parts - 2]
        local normalXp         = parts[#parts - 3]
        local hc3SoulAshes     = parts[#parts - 4]
        local hc2SoulAshes     = parts[#parts - 5]
        local hc1SoulAshes     = parts[#parts - 6]
        local normalSoulAshes  = parts[#parts - 7]
        local questType        = parts[#parts - 8]
        local zoneOrSort       = parts[#parts - 9]

        -- Middle fields (3 to #parts-10) are objectives text (may contain commas)
        local objectiveTextParts = {}
        for i = 3, #parts - 10 do
            table.insert(objectiveTextParts, parts[i])
        end
        local objectiveText = table.concat(objectiveTextParts, ",")

        return {
            questId          = tonumber(questId) or 0,
            title            = title,
            objectiveText    = objectiveText ~= "UNKNOWN_OBJECTIVE_TEXT" and objectiveText or "",
            zoneOrSort       = tonumber(zoneOrSort) or 0,
            questType        = tonumber(questType) or QUEST_OBJECTIVE_TYPE_OPEN_WORLD,
            normalSoulAshes  = tonumber(normalSoulAshes) or 0,
            hc1SoulAshes     = tonumber(hc1SoulAshes) or 0,
            hc2SoulAshes     = tonumber(hc2SoulAshes) or 0,
            hc3SoulAshes     = tonumber(hc3SoulAshes) or 0,
            normalXp         = tonumber(normalXp) or 0,
            hc1Xp            = tonumber(hc1Xp) or 0,
            hc2Xp            = tonumber(hc2Xp) or 0,
            hc3Xp            = tonumber(hc3Xp) or 0,
        }
    end

    return nil
end

-- Parse multiple objectives separated by semicolons
local function ParseObjectiveData(body)
    local objectives = {}

    if not body or body == "" then
        return objectives
    end

    for objectiveStr in string.gmatch(body, "([^;]+)") do
        local objective = ParseSingleObjective(objectiveStr)
        if objective then
            table.insert(objectives, objective)
        end
    end

    return objectives
end

ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_OBJECTIVES_PROPOSALS, function(body)
    Objectives.currentObjectives = ParseObjectiveData(body)
    -- If the objectives board is already open, refresh it with the new proposals
    if ProjectEbonhold.ObjectivesUI and ProjectEbonhold.ObjectivesUI.GetMainFrame then
        local frame = ProjectEbonhold.ObjectivesUI.GetMainFrame()
        if frame and frame:IsShown() then
            ProjectEbonhold.ObjectivesUI.DisplayObjectives(Objectives.currentObjectives)
        end
    end
end)

-- Handler for current active objective
ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_CURRENT_OBJECTIVE, function(body)
    -- If body is empty, reset active objective and hide tracker
    if not body or body == "" then
        Objectives.activeObjective = nil
        if ProjectEbonhold.ObjectivesUI and ProjectEbonhold.ObjectivesUI.UpdateTracker then
            ProjectEbonhold.ObjectivesUI.UpdateTracker(nil)
        end
        return
    end

    Objectives.activeObjective = ParseSingleObjective(body)

    -- Update the tracker UI
    if ProjectEbonhold.ObjectivesUI and ProjectEbonhold.ObjectivesUI.UpdateTracker then
        ProjectEbonhold.ObjectivesUI.UpdateTracker(Objectives.activeObjective)
    end
end)

-- Initialize on player entering world
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        RequestObjectives()
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

-- Export service functions
ProjectEbonhold.ObjectivesService.RequestObjectives = RequestObjectives
ProjectEbonhold.ObjectivesService.RequestRerollObjectives = RequestRerollObjectives
ProjectEbonhold.ObjectivesService.GetCurrentObjectives = function() return Objectives.currentObjectives end
ProjectEbonhold.ObjectivesService.GetActiveObjective = function() return Objectives.activeObjective end
