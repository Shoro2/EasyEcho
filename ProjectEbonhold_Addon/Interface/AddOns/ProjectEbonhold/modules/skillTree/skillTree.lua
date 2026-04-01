local addon, Addon = ...


local COLOR_GRAY = { 0.45, 0.45, 0.45 }
local COLOR_GREEN = { 0.10, 1.00, 0.10 }
local COLOR_ORANGE = { 1.00, 0.70, 0.20 }


local isWaitingForValidation = false
local applyButton = nil
local isGlowEnabled = true
local COLOR_APEX = { 1.00, 0.20, 1.00 }


local DebugPrint = function() end -- skillTree_Debug.DebugPrint


local VIEW_W, VIEW_H = 900, 600



local TALENT_POINTS_TOTAL = 0
local TALENT_POINT_TOTAL_BASE = 0


local savedLoadouts = {}
local currentLoadoutName = ""


local hasUnsavedChanges = false


local lastValidatedState = {}
local revertBtn = nil




local validateBtn = nil


local nodesById = {}
local treeSearchBox = nil
local lines = {}
local neighbors = {}

local function FilterTreeNodes(searchText)
    local lowerSearch = string.lower(searchText or "")
    local isEmpty = (lowerSearch == "")
    for _, btn in pairs(nodesById) do
        if isEmpty then
            btn:SetAlpha(1.0)
        else
            local matches = false
            if btn.spells then
                for _, spellId in ipairs(btn.spells) do
                    local name = GetSpellInfo(spellId)
                    if name and string.find(string.lower(name), lowerSearch, 1, true) then
                        matches = true
                        break
                    end
                end
            end
            btn:SetAlpha(matches and 1.0 or 0.15)
        end
    end
end
local parentsOf = {}
local nodeChoices = {}
local nodeRanks = {}
local activeApexNodeId = nil


local lastNodeClickTime = 0
local NODE_CLICK_COOLDOWN = 0.1
local rapidClickCount = 0
local rapidClickResetTime = 0
local RAPID_CLICK_THRESHOLD = 5
local RAPID_CLICK_WINDOW = 2

local function HasRealChanges()
    if not lastValidatedState or not lastValidatedState.nodeRanks then
        return next(nodeRanks) ~= nil or next(nodeChoices) ~= nil
    end


    for nodeId, rank in pairs(nodeRanks) do
        if (lastValidatedState.nodeRanks[nodeId] or 0) ~= rank then
            return true
        end
    end
    for nodeId, rank in pairs(lastValidatedState.nodeRanks) do
        if (nodeRanks[nodeId] or 0) ~= rank then
            return true
        end
    end


    if lastValidatedState.nodeChoices then
        for nodeId, choice in pairs(nodeChoices) do
            if (lastValidatedState.nodeChoices[nodeId] or 0) ~= choice then
                return true
            end
        end
        for nodeId, choice in pairs(lastValidatedState.nodeChoices) do
            if (nodeChoices[nodeId] or 0) ~= choice then
                return true
            end
        end
    elseif next(nodeChoices) ~= nil then
        return true
    end

    return false
end


local function getNodeRank(nodeId) return nodeRanks[nodeId] or 0 end

local function getMaxRank(nodeId)
    local btn = nodesById[nodeId]
    if not btn or not btn.spells then return 0 end
    return #btn.spells
end


local function isNodeActive(nodeId)
    local btn = nodesById[nodeId]
    if not btn then return false end

    if btn.isMultipleChoice then
        return (nodeChoices[nodeId] or 0) ~= 0
    else
        return getNodeRank(nodeId) > 0
    end
end


local function getSpellIconSafe(spellID)
    local _, _, iconTex = GetSpellInfo(spellID)
    return iconTex or "Interface\\Icons\\INV_Misc_QuestionMark"
end


local function updateNodeIcon(btn)
    if not btn or not btn.spells or not btn.icon or not btn.id then return end

    local nodeId = btn.id
    local spellID
    if btn.isMultipleChoice then
        local selectedChoice = nodeChoices[nodeId] or 1
        spellID = btn.spells[selectedChoice]
    else
        local currentRank = getNodeRank(nodeId)
        spellID = btn.spells[math.max(1, currentRank)]
    end

    if spellID then
        btn.icon:SetTexture(getSpellIconSafe(spellID))
    end
end


local function updateAllNodeVisuals()
    for _, btn in pairs(nodesById) do
        if btn.choiceButtons then
            for _, choiceBtn in ipairs(btn.choiceButtons) do
                choiceBtn:Hide()
            end
            btn.choiceButtons = {}
        end


        updateNodeIcon(btn)
    end
end


local function getNodeCost(btn, rank)
    if not btn or not btn.soulPointsCosts then return 0 end
    local costs = btn.soulPointsCosts
    return costs[rank] or costs[#costs] or 0
end


local function addCostToTooltip(tooltip, label, cost, canAfford)
    local costColor = canAfford and "|cff00FF00" or "|cffFF0000"
    local soulIcon = "|TInterface\\AddOns\\ProjectEbonhold\\assets\\inv_soulash:16|t"
    tooltip:AddLine(costColor .. label .. soulIcon .. " " .. cost .. " Soul Ashes|r", 1, 1, 1)
end


local function resetAllNodeRanks()
    for nodeId, _ in pairs(nodesById) do
        nodeRanks[nodeId] = 0
    end
end


local getConnectedNodes, isStartingNode



local function hasPrerequisites(nodeId)
    if isStartingNode(nodeId) then
        return true
    end


    local parents = parentsOf[nodeId]
    if not parents or #parents == 0 then
        return false
    end

    for _, parentId in ipairs(parents) do
        local parentBtn = nodesById[parentId]
        local parentRank = getNodeRank(parentId)
        local parentMaxRank = getMaxRank(parentId)


        if not parentBtn or not isNodeActive(parentId) or parentRank < parentMaxRank then
            return false
        end
    end

    return true
end


local function GetRemainingTalentPoints()
    return TALENT_POINTS_TOTAL
end


local function HasAnyTalents()
    for nodeId, rank in pairs(nodeRanks) do if rank > 0 then return true end end
    for nodeId, choice in pairs(nodeChoices) do
        if choice > 0 then return true end
    end
    return false
end


local function CopyCurrentBuildToLoadout(loadout)
    loadout.nodeRanks = {}
    loadout.nodeChoices = {}


    for nodeId, rank in pairs(nodeRanks) do
        if rank > 0 then loadout.nodeRanks[nodeId] = rank end
    end


    for nodeId, choice in pairs(nodeChoices) do
        if choice ~= 0 then loadout.nodeChoices[nodeId] = choice end
    end


    loadout.spendablePoints = TALENT_POINTS_TOTAL
end


local function UpdateGlowEffect()
    if validateBtn and validateBtn.glowTexture and hasUnsavedChanges and
        isGlowEnabled then
        local remainingPoints = GetRemainingTalentPoints()

        if remainingPoints >= 0 then
            validateBtn.glowTimer = validateBtn.glowTimer + 0.05
            local alpha = (math.sin(validateBtn.glowTimer * 1.5) + 1) * 0.4
            validateBtn.glowTexture:SetAlpha(alpha)
        else
            validateBtn.glowTexture:SetAlpha(0)
        end
    elseif validateBtn and validateBtn.glowTexture then
        validateBtn.glowTexture:SetAlpha(0)
    end
end


local function MarkUnsavedChanges()
    if not HasRealChanges() then
        hasUnsavedChanges = false
        if validateBtn then
            validateBtn:Disable()
            validateBtn:GetFontString():SetTextColor(0.5, 0.5, 0.5)
            if validateBtn.glowTexture then
                validateBtn.glowTexture:SetAlpha(0)
            end
        end
        DebugPrint("No real changes detected - Apply Changes disabled")
        return
    end

    hasUnsavedChanges = true

    DebugPrint("MarkUnsavedChanges called")
    DebugPrint("validateBtn exists: %s", tostring(validateBtn ~= nil))


    local remainingPoints = GetRemainingTalentPoints()



    if validateBtn then
        if not hasUnsavedChanges then
            validateBtn:Disable()
            validateBtn:GetFontString():SetTextColor(0.5, 0.5, 0.5)
            if validateBtn.glowTexture then
                validateBtn.glowTexture:SetAlpha(0)
            end
            DebugPrint("validateBtn disabled - no unsaved changes")
        else
            if remainingPoints < 0 then
                validateBtn:Disable()
                validateBtn:GetFontString():SetTextColor(0.5, 0.5, 0.5)
                if validateBtn.glowTexture then
                    validateBtn.glowTexture:SetAlpha(0)
                end
                DebugPrint("validateBtn disabled - overspent by %d",
                    -remainingPoints)
            else
                validateBtn:Enable()
                validateBtn:GetFontString():SetTextColor(1, 1, 1)
                if validateBtn.glowTexture then
                    validateBtn.glowTimer = 0
                end
                DebugPrint("Enabled validateBtn (build affordable)")
            end
        end
    else
        DebugPrint("Could not enable validateBtn - element missing")
    end


    if revertBtn and lastValidatedState and lastValidatedState.nodeRanks then
        revertBtn:Enable()

        if revertBtn.icon then
            revertBtn.icon:SetDesaturated(false)
            revertBtn.icon:SetAlpha(1.0)
        end
        DebugPrint("Enabled revertBtn")
    end

    DebugPrint("Marked as needing validation")
end


local function MarkAsValidated()
    hasUnsavedChanges = false


    if validateBtn then
        validateBtn:Disable()
        validateBtn:GetFontString():SetTextColor(0.5, 0.5, 0.5)

        if validateBtn.glowTexture then
            validateBtn.glowTexture:SetAlpha(0)
        end
    end


    if revertBtn then
        revertBtn:Disable()

        if revertBtn.icon then
            revertBtn.icon:SetDesaturated(true)
            revertBtn.icon:SetAlpha(0.5)
        end
    end


    lastValidatedState = {
        nodeRanks = {},
        nodeChoices = {},
        class = currentClass
    }


    for nodeId, rank in pairs(nodeRanks) do
        lastValidatedState.nodeRanks[nodeId] = rank
    end


    for nodeId, choice in pairs(nodeChoices) do
        lastValidatedState.nodeChoices[nodeId] = choice
    end

    DebugPrint("Validated state saved with %d node ranks and %d choices",
        table.getn(lastValidatedState.nodeRanks or {}),
        table.getn(lastValidatedState.nodeChoices or {}))
end


local function RevertToValidatedState()
    if not lastValidatedState or not lastValidatedState.nodeRanks then
        DebugPrint("|cffFF0000No validated state to revert to!|r")
        return false
    end


    if lastValidatedState.class and lastValidatedState.class ~= currentClass then
        DebugPrint(
            "|cffFFFF00Warning: Validated state is for a different class!|r")
    end


    nodeRanks = {}
    resetAllNodeRanks()
    for nodeId, rank in pairs(lastValidatedState.nodeRanks) do
        nodeRanks[nodeId] = rank
    end


    nodeChoices = {}
    for nodeId, choice in pairs(lastValidatedState.nodeChoices) do
        nodeChoices[nodeId] = choice
    end


    for _, btn in pairs(nodesById) do
        local nodeId = btn.id


        updateNodeIcon(btn)


        if btn.isMultipleChoice then
            local selectedChoice = nodeChoices[nodeId]
            if selectedChoice and selectedChoice ~= 0 then
                btn.selectedSpell = selectedChoice
            else
                btn.selectedSpell = nil
            end
        end
    end


    MarkAsValidated()


    refreshAccessibility()

    DebugPrint("|cff00FF00Reverted to last validated state!|r")
    return true
end


local TreeNodes = {}
local Links = {}
currentClass = "Mage"


local function DetectPlayerClass()
    local _, playerClass = UnitClass("player")


    local classMapping = {
        ["WARRIOR"] = "Warrior",
        ["PALADIN"] = "Paladin",
        ["HUNTER"] = "Hunter",
        ["ROGUE"] = "Rogue",
        ["PRIEST"] = "Priest",
        ["DEATHKNIGHT"] = "Death Knight",
        ["SHAMAN"] = "Shaman",
        ["MAGE"] = "Mage",
        ["WARLOCK"] = "Warlock",
        ["DRUID"] = "Druid"
    }
    local detectedClass = classMapping[playerClass] or "Mage"
    DebugPrint("Player class detected: %s (API: %s)", detectedClass,
        playerClass or "unknown")
    return detectedClass
end


nodeChoices = {}
nodeRanks = {}



function getConnectedNodes(nodeId)
    return neighbors[nodeId] or {}
end

function isStartingNode(nodeId)
    local btn = nodesById[nodeId]
    if btn then return btn.isStart == true end


    for _, node in ipairs(TreeNodes) do
        if node.id == nodeId then return node.isStart == true end
    end

    return false
end

local NextRankTooltip = nil
local CurrentRankTooltip = nil
local InfoTooltip = nil


local function SendCreateLoadoutToServer(name, nodeRanks)
    if not ProjectEbonhold or not ProjectEbonhold.sendToServer then
        DebugPrint(
            "|cffFF0000Cannot send create loadout request: ProjectEbonhold not available|r")
        return false
    end


    local nodeParts = {}
    for nodeId, rank in pairs(nodeRanks) do
        if rank > 0 then table.insert(nodeParts, nodeId .. ":" .. rank) end
    end


    local spendablePoints = TALENT_POINTS_TOTAL

    local nodesString = table.concat(nodeParts, ",")

    local dataString = name .. "," .. spendablePoints .. "," .. nodesString

    DebugPrint("|cff00FF00Sending CREATE_LOADOUT request to server...|r")
    DebugPrint("|cffFFFF00Name: " .. name .. ", Available Points: " ..
        spendablePoints .. ", Nodes: " .. #nodeParts .. "|r")

    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_CREATE_LOADOUT,
        dataString)
    return true
end


local function saveCurrentLoadout(name)
    local loadout = {
        nodeRanks = {},
        nodeChoices = {},
        id = 0,
        spendablePoints = 0,
        class = currentClass
    }


    CopyCurrentBuildToLoadout(loadout)

    savedLoadouts[name] = loadout
    currentLoadoutName = name


    SendCreateLoadoutToServer(name, loadout.nodeRanks)

    DebugPrint("|cff00FF00Loadout saved locally: " .. name .. " (" ..
        TALENT_POINTS_TOTAL .. " Soul Points available)|r")
end

local function loadLoadout(name, forceReload)
    if currentLoadoutName == name and not forceReload then
        DebugPrint("|cffFFFF00Loadout already loaded: " .. name .. "|r")
        return
    end

    local loadout = savedLoadouts[name]
    if not loadout then
        DebugPrint("|cffFF0000Loadout not found: " .. name .. "|r")
        return
    end

    DebugPrint("|cff00FF00Loading loadout: " .. name .. "...|r")


    nodeRanks = {}
    nodeChoices = {}


    resetAllNodeRanks()
    for nodeId, _ in pairs(nodesById) do
        nodeChoices[nodeId] = 0
    end


    if loadout.nodeRanks then
        for id, rank in pairs(loadout.nodeRanks) do nodeRanks[id] = rank end
    end


    if loadout.nodeChoices then
        for id, choice in pairs(loadout.nodeChoices) do
            nodeChoices[id] = choice
        end
    end


    updateAllNodeVisuals()

    currentLoadoutName = name
    refreshAccessibility()
    DebugPrint("|cff00FF00Loadout loaded: " .. name .. " (nodes applied)|r")
end

local function clearCurrentBuild()
    resetAllNodeRanks()


    nodeChoices = {}


    activeApexNodeId = nil


    updateAllNodeVisuals()

    currentLoadoutName = ""
    refreshAccessibility()
    MarkUnsavedChanges()
    DebugPrint("|cff00FF00All talents cleared!|r")
end

local function getLoadoutsList()
    local list = {}
    for name, _ in pairs(savedLoadouts) do table.insert(list, name) end
    table.sort(list)
    return list
end


local function CreateLoadoutPackage()
    local loadoutId = 0
    local loadoutName = currentLoadoutName or "Unnamed"

    if currentLoadoutName and currentLoadoutName ~= "" and
        savedLoadouts[currentLoadoutName] then
        loadoutId = savedLoadouts[currentLoadoutName].id or 0
    end

    local package = { id = loadoutId, name = loadoutName, nodeRanks = {} }


    DebugPrint("=== Creating Loadout Package ===")
    local totalNodes = 0
    for nodeId, rank in pairs(nodeRanks) do
        DebugPrint("Node %d: rank = %d", nodeId, rank)
        if rank > 0 then
            package.nodeRanks[nodeId] = rank
            totalNodes = totalNodes + 1
        end
    end
    DebugPrint("Total nodes with rank > 0: %d", totalNodes)

    return package
end


local function SendLoadoutToServer(loadoutData)
    DebugPrint("=== SENDING LOADOUT TO SERVER ===")
    DebugPrint("Loadout ID: %s, Name: %s", tostring(loadoutData.id),
        loadoutData.name)

    local nodeCount = 0
    for _ in pairs(loadoutData.nodeRanks) do nodeCount = nodeCount + 1 end
    DebugPrint("Total Nodes: %d", nodeCount)


    if ProjectEbonhold and ProjectEbonhold.SendLoadoutToServer then
        return ProjectEbonhold.SendLoadoutToServer(loadoutData)
    end

    return false
end




local function ExportLoadoutToCode()
    local buffer = {}


    local activeNodes = {}
    for nodeId, rank in pairs(nodeRanks) do
        if rank > 0 then
            table.insert(activeNodes, { id = nodeId, rank = rank })
        end
    end


    for nodeId, choice in pairs(nodeChoices) do
        if choice > 0 then
            local found = false
            for _, node in ipairs(activeNodes) do
                if node.id == nodeId then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(activeNodes, { id = nodeId, rank = 1 })
            end
        end
    end


    table.sort(activeNodes, function(a, b) return a.id < b.id end)


    for _, byte in ipairs(utils.EncodeVarInt(#activeNodes)) do
        table.insert(buffer, byte)
    end


    for _, node in ipairs(activeNodes) do
        for _, byte in ipairs(utils.EncodeVarInt(node.id)) do
            table.insert(buffer, byte)
        end

        table.insert(buffer, node.rank)
    end

    return utils.Base64Encode(buffer)
end


local function ImportLoadoutFromCode(encodedData)
    local buffer = utils.Base64Decode(encodedData)
    if not buffer or #buffer == 0 then return nil, "Invalid Base64 data" end

    local pos = 1


    local nodeCount
    nodeCount, pos = utils.DecodeVarInt(buffer, pos)
    if not nodeCount then return nil, "Failed to decode node count" end


    local nodes = {}
    for i = 1, nodeCount do
        local nodeId
        nodeId, pos = utils.DecodeVarInt(buffer, pos)
        if not nodeId then return nil, "Failed to decode node ID" end

        if pos > #buffer then
            return nil, "Missing rank for node " .. nodeId
        end
        local rank = buffer[pos]
        pos = pos + 1

        table.insert(nodes, { id = nodeId, rank = rank })
    end

    return nodes
end


local function ApplyImportedLoadout(nodes)
    if not nodes then return false end


    local totalPointsRequired = 0
    for _, node in ipairs(nodes) do
        local btn = nodesById[node.id]
        if btn then
            if btn.isMultipleChoice then
                totalPointsRequired = totalPointsRequired + 1
            else
                totalPointsRequired = totalPointsRequired + node.rank
            end
        end
    end


    if totalPointsRequired > TALENT_POINTS_TOTAL then
        return false,
            "You tried to import a build without enough Soul Points (Required: " ..
            totalPointsRequired .. ", Available: " .. TALENT_POINTS_TOTAL ..
            ")"
    end


    clearCurrentBuild()


    for _, node in ipairs(nodes) do
        local btn = nodesById[node.id]
        if btn then
            if btn.isMultipleChoice then
                nodeChoices[node.id] = 1
                nodeRanks[node.id] = 1
                btn.selectedSpell = 1
                updateNodeIcon(btn)
            else
                nodeRanks[node.id] = node.rank
            end
        end
    end


    updateAllNodeVisuals()
    refreshAccessibility()
    MarkUnsavedChanges()

    return true
end


function ValidateAndSendLoadout()
    DebugPrint("Validating current loadout...")


    if not HasAnyTalents() then
        DebugPrint("|cffFF0000Validation failed: No talents selected|r")
        return false
    end


    if currentLoadoutName and savedLoadouts[currentLoadoutName] then
        local loadout = savedLoadouts[currentLoadoutName]
        CopyCurrentBuildToLoadout(loadout)
        DebugPrint("|cff00FF00Saved current state to loadout: " ..
            currentLoadoutName .. "|r")
    end


    local loadoutData = CreateLoadoutPackage()


    if SendLoadoutToServer(loadoutData) then
        DebugPrint("|cffFFFF00Loadout sent to server...|r")
        return true
    else
        DebugPrint("|cffFF0000Failed to send loadout to server|r")
        return false
    end
end

function OnApplyChangesResult(spellId, success)
    isWaitingForValidation = false

    if success then
        MarkAsValidated()
        DebugPrint("|cff00FF00Skill tree changes applied successfully!|r")
        -- DEFAULT_CHAT_FRAME:AddMessage(
        --     "|cff00FF00[ProjectEbonhold] Skill tree changes applied successfully!|r")

        if applyButton then
            applyButton:SetText("Apply Changes")


            isGlowEnabled = false
            if applyButton.glowTexture then
                applyButton.glowTexture:SetAlpha(0)
            end
        end
    else
        DebugPrint("|cffFF0000Skill tree validation failed!|r")

        if spellId then
            -- DEFAULT_CHAT_FRAME:AddMessage(
            --     "|cffFF0000[ProjectEbonhold] Skill tree validation failed for spell " ..
            --     spellId .. "!|r")
        else
            -- DEFAULT_CHAT_FRAME:AddMessage(
            --     "|cffFF0000[ProjectEbonhold] Skill tree validation failed or timed out!|r")
        end


        RevertToValidatedState()
        hasUnsavedChanges = false

        -- DEFAULT_CHAT_FRAME:AddMessage(
        --     "|cffFFFF00[ProjectEbonhold] Changes reverted to last validated state.|r")
    end
end

local function LoadClassData(className)
    local treeData = TalentDatabase[0]

    if not treeData then
        DebugPrint(
            "|cffFF0000Error: Default tree 0 not found in TalentDatabase!|r")
        return false
    end

    currentClass = className or DetectPlayerClass()
    DebugPrint("Loading default soul tree 0 for class: %s", currentClass)


    TreeNodes = {}
    Links = {}

    for i, node in ipairs(treeData.nodes) do
        TreeNodes[i] = {}
        for key, value in pairs(node) do TreeNodes[i][key] = value end
    end

    for i, link in ipairs(treeData.links) do Links[i] = { link[1], link[2] } end


    nodeRanks = {}
    for _, node in ipairs(TreeNodes) do
        nodeRanks[node.id] = 0
    end

    return true
end


LoadClassData()


function Addon.ApplyLoadoutsFromServer(parsedData)
    if not parsedData then
        DebugPrint("|cffFF0000Invalid loadout data received from server|r")
        return false
    end


    TALENT_POINTS_TOTAL = parsedData.spendableSoulPoints or 0
    TALENT_POINT_TOTAL_BASE = parsedData.totalCommitedSoulPoints or 0


    if skillTreeFrame and skillTreeFrame.progressBar and skillTreeFrame.progressBar.UpdateProgressBar then
        skillTreeFrame.progressBar.UpdateProgressBar()
    end


    savedLoadouts = {}


    for _, loadout in ipairs(parsedData.loadouts) do
        savedLoadouts[loadout.name] = {
            nodeRanks = loadout.nodeRanks,
            nodeChoices = {},
            class = currentClass,
            spendablePoints = loadout.spendablePoints,
            id = loadout.id
        }
    end


    local selectedLoadout = nil
    if parsedData.selectedLoadoutId then
        for _, loadout in ipairs(parsedData.loadouts) do
            if loadout.id == parsedData.selectedLoadoutId then
                selectedLoadout = loadout
                break
            end
        end
    end


    if not selectedLoadout then
        for _, loadout in ipairs(parsedData.loadouts) do
            if loadout.id == 0 then
                selectedLoadout = loadout
                DebugPrint("|cffFFD700Loading default loadout 0 (tree 0)|r")
                break
            end
        end
    end


    if selectedLoadout then
        resetAllNodeRanks()
        nodeChoices = {}


        for nodeId, rank in pairs(selectedLoadout.nodeRanks) do
            nodeRanks[nodeId] = rank
        end

        currentLoadoutName = selectedLoadout.name


        updateAllNodeVisuals()
    else
        resetAllNodeRanks()
        nodeChoices = {}
        currentLoadoutName = ""
    end


    MarkAsValidated()
    refreshAccessibility()



    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(self, elapsed)
        self:SetScript("OnUpdate", nil)
        RefreshLoadoutDropdown()
    end)

    DebugPrint("|cff00FF00Loadouts received from server!|r")
    DebugPrint("|cffFFFF00Total spendable points: " .. TALENT_POINTS_TOTAL ..
        "|r")
    DebugPrint("|cffFFFF00Loaded " .. #parsedData.loadouts .. " loadout(s)|r")
    if selectedLoadout then
        DebugPrint("|cff00FF00Selected loadout: " .. selectedLoadout.name ..
            "|r")
    end

    return true
end

function RefreshLoadoutDropdown()
    if not loadoutDropdown then
        DebugPrint(
            "|cffFFFF00RefreshLoadoutDropdown: dropdown not initialized yet, will update on creation|r")
        return
    end

    DebugPrint("|cff00FF00Refreshing loadout dropdown...|r")
    DebugPrint("|cffFFFF00Current loadout name: " ..
        (currentLoadoutName or "nil") .. "|r")


    if currentLoadoutName and currentLoadoutName ~= "" then
        UIDropDownMenu_SetText(loadoutDropdown, currentLoadoutName)
        DebugPrint("|cff00FF00Dropdown text set to: " .. currentLoadoutName ..
            "|r")
    else
        UIDropDownMenu_SetText(loadoutDropdown, "Select Build")
        DebugPrint("|cffFFFF00Dropdown text set to: Select Build|r")
    end
end

function Addon.ApplyLoadoutFromServer(loadoutData)
    DebugPrint(
        "|cffFFFF00Warning: Using deprecated ApplyLoadoutFromServer function|r")
    return false
end

local function CheckInitialState()
    local hasAnyTalents = false
    for nodeId, rank in pairs(nodeRanks) do
        if rank > 0 then
            hasAnyTalents = true
            break
        end
    end

    if hasAnyTalents then
        MarkUnsavedChanges()
    else
        MarkAsValidated()
    end
end




local skillTreeFrame = CreateFrame("Frame", "skillTreeFrame", UIParent)
skillTreeFrame:SetSize(VIEW_W, VIEW_H)
skillTreeFrame:SetPoint("CENTER", 0, 50)
skillTreeFrame:SetFrameStrata("FULLSCREEN_DIALOG", true)


local glowUpdateTimer = 0
local GLOW_UPDATE_INTERVAL = 0.05
skillTreeFrame:SetScript("OnUpdate",
    function(self, elapsed)
        if ProjectEbonhold_IsClosing then return end
        if not UIParent:IsShown() then return end
        elapsed = math.min(elapsed, 0.1) -- Cap elapsed to prevent freeze after alt-tab
        glowUpdateTimer = glowUpdateTimer + elapsed
        if glowUpdateTimer >= GLOW_UPDATE_INTERVAL then
            UpdateGlowEffect()
            glowUpdateTimer = 0
        end
    end)


local bgTexture = skillTreeFrame:CreateTexture(nil, "BACKGROUND")
bgTexture:SetTexture(
    "Interface\\AddOns\\ProjectEbonhold\\assets\\UI-Background-Rock")
bgTexture:SetPoint("TOPLEFT", skillTreeFrame, "TOPLEFT", 8, -8)
bgTexture:SetPoint("BOTTOMRIGHT", skillTreeFrame, "BOTTOMRIGHT", -8, 8)
bgTexture:SetHorizTile(true)
bgTexture:SetVertTile(true)
skillTreeFrame:SetBackdrop({
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})


skillTreeFrame:SetScript("OnHide", function()
    if treeSearchBox then
        treeSearchBox:SetText("")
        treeSearchBox:ClearFocus()
        FilterTreeNodes("")
    end
end)


table.insert(UISpecialFrames, "skillTreeFrame")

local closeBtn =
    CreateFrame("Button", nil, skillTreeFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", skillTreeFrame, "TOPRIGHT", -5, -5)
closeBtn:SetFrameLevel(skillTreeFrame:GetFrameLevel() + 10)


NextRankTooltip = CreateFrame("GameTooltip", "skillTreeNextRankTooltip", nil,
    "GameTooltipTemplate")
NextRankTooltip:SetOwner(skillTreeFrame, "ANCHOR_NONE")


CurrentRankTooltip = CreateFrame("GameTooltip", "skillTreeCurrentRankTooltip",
    nil, "GameTooltipTemplate")
CurrentRankTooltip:SetOwner(skillTreeFrame, "ANCHOR_NONE")


InfoTooltip = CreateFrame("GameTooltip", "skillTreeInfoTooltip", nil,
    "GameTooltipTemplate")
InfoTooltip:SetOwner(skillTreeFrame, "ANCHOR_NONE")
skillTreeFrame:EnableMouse(true)
skillTreeFrame:Hide()


loadoutDropdown = nil


local function CreateBottomBar()
    local bottomBar = CreateFrame("Frame", "skillTreeBottomBar", skillTreeFrame)
    bottomBar:SetPoint("BOTTOMLEFT", skillTreeFrame, "BOTTOMLEFT", 8, 5)
    bottomBar:SetPoint("BOTTOMRIGHT", skillTreeFrame, "BOTTOMRIGHT", -8, 5)
    bottomBar:SetHeight(35)
    bottomBar:SetFrameLevel(skillTreeFrame:GetFrameLevel() + 10)


    local bottomBarWidth = bottomBar:GetWidth() or (VIEW_W - 16)
    local textureWidth = 126 * 0.664062
    local numTextures = math.ceil(bottomBarWidth / textureWidth)


    local adjustedTextureWidth = bottomBarWidth / numTextures


    for i = 1, numTextures do
        local tex = bottomBar:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\texture_bottom")
        tex:SetTexCoord(0.000000, 0.664062, 0.000000, 0.242188)
        tex:SetSize(adjustedTextureWidth, 40)
        tex:SetPoint("LEFT", bottomBar, "LEFT", (i - 1) * adjustedTextureWidth, 0)
    end


    local soulIcon = bottomBar:CreateTexture(nil, "OVERLAY")
    soulIcon:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\inv_soulash")
    soulIcon:SetSize(16, 16)
    soulIcon:SetPoint("LEFT", bottomBar, "LEFT", 10, 0)

    local pointsText = bottomBar:CreateFontString(nil, "OVERLAY",
        "GameFontNormal")
    pointsText:SetPoint("LEFT", soulIcon, "RIGHT", 5, 0)
    pointsText:SetText("|cffFFD700Soul Points: |r|cffFFFFFF" ..
        GetRemainingTalentPoints() .. "|r")
    skillTreeFrame.pointsText = pointsText


    local dropdown = CreateFrame("Frame", "skillTreeLoadoutDropdown", bottomBar,
        "UIDropDownMenuTemplate")
    dropdown:SetPoint("LEFT", pointsText, "RIGHT", 20, -2)
    UIDropDownMenu_SetWidth(dropdown, 150)
    dropdown:Hide()


    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()


        info.text = "|cff00FF00+ New Build...|r"
        info.func = function()
            StaticPopupDialogs["SKILLTREE_NEW_BUILD"] = {
                text = "Enter build name:",
                button1 = "Create",
                button2 = "Cancel",
                hasEditBox = true,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                OnAccept = function(self)
                    local name = self.editBox:GetText()
                    if name and name ~= "" then
                        saveCurrentLoadout(name)
                        UIDropDownMenu_SetText(dropdown, name)
                    end
                end,
                EditBoxOnEnterPressed = function(self)
                    local name = self:GetText()
                    if name and name ~= "" then
                        saveCurrentLoadout(name)
                        UIDropDownMenu_SetText(dropdown, name)
                    end
                    self:GetParent():Hide()
                end,
                EditBoxOnEscapePressed = function(self)
                    self:GetParent():Hide()
                end
            }
            StaticPopup_Show("SKILLTREE_NEW_BUILD")
        end
        UIDropDownMenu_AddButton(info)


        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.disabled = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)


        local loadouts = getLoadoutsList()
        if #loadouts > 0 then
            for _, name in ipairs(loadouts) do
                info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.func = function()
                    loadLoadout(name, true)
                    UIDropDownMenu_SetText(dropdown, name)
                end
                info.checked = (currentLoadoutName == name)
                UIDropDownMenu_AddButton(info)
            end
        else
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cff888888No saved builds|r"
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end
    end)


    if currentLoadoutName and currentLoadoutName ~= "" then
        UIDropDownMenu_SetText(dropdown, currentLoadoutName)
        DebugPrint("|cff00FF00Dropdown initialized with loadout: " ..
            currentLoadoutName .. "|r")
    else
        UIDropDownMenu_SetText(dropdown, "Select Build")
    end

    loadoutDropdown = dropdown


    applyButton = CreateFrame("Button", "skillTreeApplyButton", bottomBar,
        "UIPanelButtonTemplate2")
    applyButton:SetSize(130, 22)
    applyButton:SetPoint("LEFT", pointsText, "RIGHT", 22, 2)
    applyButton:SetText("Apply Changes")
    applyButton:SetScript("OnClick", function() ValidateAndSendLoadout() end)
    applyButton:Disable()
    applyButton:GetFontString():SetTextColor(0.5, 0.5, 0.5)


    applyButton.glowTexture = applyButton:CreateTexture(nil, "OVERLAY")
    applyButton.glowTexture:SetTexture(
        "Interface\\Buttons\\UI-Panel-Button-Glow")
    applyButton.glowTexture:SetPoint("CENTER", applyButton, "CENTER", 25, -10)
    applyButton.glowTexture:SetSize(200, 50)
    applyButton.glowTexture:SetAlpha(0)
    applyButton.glowTexture:SetBlendMode("ADD")
    applyButton.glowTexture:SetVertexColor(1, 1, 0.5)


    applyButton.glowTimer = 0
    applyButton.glowDirection = 1



    validateBtn = applyButton


    local progressBarWidth = 550
    local progressBarHeight = 42
    local progressFrame = CreateFrame("Frame", nil, skillTreeFrame)
    progressFrame:SetSize(progressBarWidth, progressBarHeight)
    progressFrame:SetPoint("TOP", skillTreeFrame, "TOP", 0, -15)
    progressFrame:SetFrameLevel(skillTreeFrame:GetFrameLevel() + 15)


    local milestoneData = ProjectEbonhold.SoulAshesMilestones or {}


    local milestones = {}
    local milestoneSpellIDs = {}
    for i, data in ipairs(milestoneData) do
        if type(data) == "table" then
            -- Format: { soulAshes = 1000000, spellID = 101260 }
            milestones[i] = data.soulAshes
            milestoneSpellIDs[i] = data.spellID
        elseif type(data) == "number" then
            -- Format simple: 1000000
            milestones[i] = data
            -- Pas de spellID pour le format simple
        end
    end


    local barTexWidth = 512 * (0.978516 - 0.015625)
    local barTexHeight = 512 * (0.113281 - 0.031250)


    local barBg = progressFrame:CreateTexture(nil, "BACKGROUND")
    barBg:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\progression_bar")
    barBg:SetTexCoord(0.015625, 0.978516, 0.031250, 0.113281)
    barBg:SetSize(progressBarWidth, barTexHeight)
    barBg:SetPoint("CENTER", progressFrame, "CENTER", 0, 0)


    local fillBar = progressFrame:CreateTexture(nil, "ARTWORK")
    fillBar:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\progression_bar")
    fillBar:SetTexCoord(0.021484, 0.435547, 0.201172, 0.230469)
    fillBar:SetPoint("LEFT", progressFrame, "LEFT", 16, 2)
    fillBar:SetHeight(barTexHeight - 25)
    progressFrame.fillBar = fillBar


    local progressText = progressFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    progressText:SetPoint("CENTER", progressFrame, "CENTER", 0, 0)
    progressText:SetTextColor(1, 1, 1)
    progressFrame.progressText = progressText


    local iconSize = 28
    local spellButton = CreateFrame("Button", nil, progressFrame)
    spellButton:SetSize(iconSize, iconSize)
    spellButton:SetPoint("LEFT", progressFrame, "RIGHT", -40, 0)


    local spellIcon = spellButton:CreateTexture(nil, "BACKGROUND")
    spellIcon:SetAllPoints(spellButton)
    progressFrame.spellIcon = spellIcon


    local lightTexture = spellButton:CreateTexture(nil, "ARTWORK")
    lightTexture:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\progression_bar")
    lightTexture:SetTexCoord(0.023438, 0.210938, 0.283203, 0.478516)
    lightTexture:SetSize(iconSize + 32, iconSize + 32)
    lightTexture:SetPoint("CENTER", spellButton, "CENTER", 0, 0)
    lightTexture:SetBlendMode("ADD")


    local borderRound = spellButton:CreateTexture(nil, "OVERLAY")
    borderRound:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\progression_bar")
    borderRound:SetTexCoord(0.214844, 0.322266, 0.314453, 0.427734)
    borderRound:SetSize(iconSize + 16, iconSize + 16)
    borderRound:SetPoint("CENTER", spellButton, "CENTER", 0, 0)


    local animGroup = lightTexture:CreateAnimationGroup()
    local rotation = animGroup:CreateAnimation("Rotation")
    rotation:SetDegrees(360)
    rotation:SetDuration(8)
    animGroup:SetLooping("REPEAT")
    animGroup:Play()


    progressFrame.currentSpellID = 71


    spellButton:SetScript("OnEnter", function(self)
        -- print(progressFrame.currentSpellID);
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink('spell:' .. progressFrame.currentSpellID)
        GameTooltip:Show()
    end)

    spellButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)


    local function UpdateProgressBar()
        local currentTotal = TALENT_POINT_TOTAL_BASE
        local currentMilestoneIndex = 0
        local previousMilestone = 0
        local nextMilestone = milestones[1] or ProjectEbonhold.Constants.MAX_SOUL_ASHES
        local hasReachedLastMilestone = false

        -- print("|cff00ff00[ProgressBar Debug]|r Total Soul Ashes:", currentTotal)
        -- print("|cff00ff00[ProgressBar Debug]|r Milestones count:", #milestones)
        -- print("|cff00ff00[ProgressBar Debug]|r First milestone:", milestones[1])

        for i, milestone in ipairs(milestones) do
            if currentTotal >= milestone then
                currentMilestoneIndex = i
                previousMilestone = milestone
                if milestones[i + 1] then
                    nextMilestone = milestones[i + 1]
                else
                    -- Dernier milestone atteint, progresser vers le maximum
                    nextMilestone = ProjectEbonhold.Constants.MAX_SOUL_ASHES
                    hasReachedLastMilestone = true
                end
            else
                -- On a trouvé le prochain milestone, on s'arrête
                break
            end
        end

        -- print("|cff00ff00[ProgressBar Debug]|r Previous:", previousMilestone, "Next:", nextMilestone, "Last reached:",
        --    hasReachedLastMilestone)




        local spellIDIndex = currentMilestoneIndex + 1
        if spellIDIndex > #milestoneSpellIDs then
            spellIDIndex = #milestoneSpellIDs
        end
        local currentSpellID = milestoneSpellIDs[spellIDIndex] or 71
        progressFrame.currentSpellID = currentSpellID


        if hasReachedLastMilestone then
            spellButton:Hide()
        else
            spellButton:Show()
            local _, _, iconTexture = GetSpellInfo(currentSpellID)
            spellIcon:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        end


        local milestoneProgress = 0
        if hasReachedLastMilestone then
            -- Après le dernier milestone, afficher la progression totale vers le cap maximum
            milestoneProgress = currentTotal / ProjectEbonhold.Constants.MAX_SOUL_ASHES
        elseif nextMilestone > previousMilestone then
            -- Entre deux milestones, afficher la progression entre eux
            milestoneProgress = (currentTotal - previousMilestone) / (nextMilestone - previousMilestone)
        end

        -- print("|cff00ff00[ProgressBar Debug]|r Progress:", milestoneProgress)


        local fillWidth = (progressBarWidth - 30) * math.min(milestoneProgress, 1)

        -- print("|cff00ff00[ProgressBar Debug]|r FillWidth calculated:", fillWidth)


        if fillWidth > 0 then
            fillBar:SetWidth(fillWidth)
            fillBar:Show()
        else
            fillBar:Hide()
        end


        progressText:SetText(currentTotal .. "/" .. nextMilestone)


        progressFrame.currentMilestoneIndex = currentMilestoneIndex
        progressFrame.nextMilestone = nextMilestone
        progressFrame.currentTotal = currentTotal
        progressFrame.previousMilestone = previousMilestone
    end
    progressFrame.UpdateProgressBar = UpdateProgressBar


    progressFrame:EnableMouse(true)
    progressFrame:SetScript("OnEnter", function(self)
        local maxSoulAshes = ProjectEbonhold.Constants.MAX_SOUL_ASHES
        local currentTotal = self.currentTotal or TALENT_POINT_TOTAL_BASE
        local nextMilestone = self.nextMilestone or maxSoulAshes
        local previousMilestone = self.previousMilestone or 0
        local currentMilestoneIndex = self.currentMilestoneIndex or 0

        InfoTooltip:SetOwner(self, "ANCHOR_TOP")
        InfoTooltip:SetText("Soul Ashes Progression", 1, 0.82, 0)


        -- Afficher la progression du milestone seulement si on n'a pas atteint le dernier
        if currentMilestoneIndex < #milestones then
            InfoTooltip:AddLine("Earn Soul Ashes to advance toward your next milestone.", 0.9, 0.9, 0.9, true)
            InfoTooltip:AddLine(" ", 1, 1, 1)

            InfoTooltip:AddLine(
                "Current Milestone: " .. currentTotal .. " / " .. nextMilestone,
                1, 1, 1
            )
            InfoTooltip:AddLine(" ", 1, 1, 1)
        else
            InfoTooltip:AddLine("All milestones completed! Progress toward the maximum cap.", 0, 1, 0, true)
            InfoTooltip:AddLine(" ", 1, 1, 1)
        end


        InfoTooltip:AddLine(
            "Soul Ashes have an maximum cap (" .. currentTotal .. " / " .. maxSoulAshes ..
            "). Once the cap is reached, you will no longer be able to commit Soul Ashes in your Skill Tree.",
            0.7, 0.7, 0.7, true
        )

        InfoTooltip:Show()
    end)

    progressFrame:SetScript("OnLeave", function(self)
        InfoTooltip:Hide()
    end)


    UpdateProgressBar()


    skillTreeFrame.progressBar = progressFrame


    local castMonitorFrame = CreateFrame("Frame")
    castMonitorFrame:RegisterEvent("UNIT_SPELLCAST_START")
    castMonitorFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    castMonitorFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    castMonitorFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    castMonitorFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    castMonitorFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

    castMonitorFrame:SetScript("OnEvent", function(self, event, unit)
        if unit ~= "player" or not applyButton then return end

        local isCasting = UnitCastingInfo("player") or UnitChannelInfo("player")

        if isCasting then
            applyButton:Disable()
            applyButton:GetFontString():SetTextColor(0.5, 0.5, 0.5)
        else
            if hasUnsavedChanges and HasRealChanges() then
                local remainingPoints = GetRemainingTalentPoints()
                if remainingPoints >= 0 then
                    applyButton:Enable()
                    applyButton:GetFontString():SetTextColor(1, 1, 1)
                end
            end
        end
    end)


    local applyBtnTooltipFrame = CreateFrame("Frame", nil, applyButton)
    applyBtnTooltipFrame:SetAllPoints(applyButton)
    applyBtnTooltipFrame:SetFrameLevel(applyButton:GetFrameLevel() + 1)
    applyBtnTooltipFrame:EnableMouse(true)


    applyBtnTooltipFrame:SetScript("OnEnter", function(self)
        local remainingPoints = GetRemainingTalentPoints()
        InfoTooltip:SetOwner(self, "ANCHOR_TOP")

        if remainingPoints < 0 then
            InfoTooltip:SetText("Apply Changes", 1, 1, 1)
            InfoTooltip:AddLine(
                "You don't have enough Soul Points to apply this build", 1, 0.3,
                0.3, true)
            InfoTooltip:AddLine("Overspent by: " .. math.abs(remainingPoints),
                0.8, 0.8, 0.8)
        else
            if hasUnsavedChanges then
                InfoTooltip:SetText("Apply Changes", 1, 1, 1)
                InfoTooltip:AddLine("Send your soul build to the server", 0.8,
                    0.8, 0.8, true)
                InfoTooltip:AddLine(
                    "Remaining Soul Points: " .. remainingPoints, 0.8, 0.8, 0.8)
            else
                InfoTooltip:SetText("Apply Changes", 0.5, 0.5, 0.5)
                InfoTooltip:AddLine("No changes to apply", 0.6, 0.6, 0.6, true)
            end
        end

        InfoTooltip:Show()
    end)

    applyBtnTooltipFrame:SetScript("OnLeave",
        function(self) InfoTooltip:Hide() end)


    applyBtnTooltipFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and applyButton:IsEnabled() then
            applyButton:Click()
        end
    end)


    local exportBtn = CreateFrame("Button", "skillTreeExportButton", bottomBar,
        "UIPanelButtonTemplate")
    exportBtn:SetSize(80, 25)
    exportBtn:SetPoint("LEFT", applyButton, "RIGHT", 5, 0)
    exportBtn:SetText("Export")
    exportBtn:Hide()
    exportBtn:SetScript("OnClick", function()
        if not HasAnyTalents() then
            StaticPopupDialogs["SKILLTREE_EXPORT_EMPTY"] = {
                text = "No talents selected to export!",
                button1 = "OK",
                timeout = 0,
                whileDead = true,
                hideOnEscape = true
            }
            StaticPopup_Show("SKILLTREE_EXPORT_EMPTY")
            return
        end


        local exportCode = ExportLoadoutToCode()


        StaticPopupDialogs["SKILLTREE_EXPORT_CODE"] = {
            text = "Build Export Code:\n\n|cffFFD700Copy the code below:|r",
            button1 = "Close",
            hasEditBox = true,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            editBoxWidth = 350,
            OnShow = function(self)
                self.editBox:SetText(exportCode)
                self.editBox:HighlightText()
                self.editBox:SetFocus()
            end,
            EditBoxOnEnterPressed = function(self)
                self:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end
        }
        StaticPopup_Show("SKILLTREE_EXPORT_CODE")
    end)


    local importBtn = CreateFrame("Button", "skillTreeImportButton", bottomBar,
        "UIPanelButtonTemplate")
    importBtn:SetSize(80, 25)
    importBtn:SetPoint("LEFT", exportBtn, "RIGHT", 5, 0)
    importBtn:SetText("Import")
    importBtn:Hide()
    importBtn:SetScript("OnClick", function()
        StaticPopupDialogs["SKILLTREE_IMPORT_CODE"] = {
            text = "Import Build Code:\n\n|cffFFD700Paste your build code below:|r",
            button1 = "Import",
            button2 = "Cancel",
            hasEditBox = true,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            editBoxWidth = 350,
            OnAccept = function(self)
                local code = self.editBox:GetText()
                if code and code ~= "" then
                    local nodes, error = ImportLoadoutFromCode(code)
                    if nodes then
                        local success, applyError = ApplyImportedLoadout(nodes)
                        if success then
                            DebugPrint(
                                "|cff00FF00Build imported successfully! (" ..
                                #nodes .. " talents)|r")
                        else
                            StaticPopupDialogs["SKILLTREE_IMPORT_ERROR"] = {
                                text = "Import failed:\n\n|cffFF0000" ..
                                    (applyError or "Failed to apply build") ..
                                    "|r",
                                button1 = "OK",
                                timeout = 0,
                                whileDead = true,
                                hideOnEscape = true
                            }
                            StaticPopup_Show("SKILLTREE_IMPORT_ERROR")
                        end
                    else
                        StaticPopupDialogs["SKILLTREE_IMPORT_ERROR"] = {
                            text = "Import failed:\n\n|cffFF0000" ..
                                (error or "Unknown error") .. "|r",
                            button1 = "OK",
                            timeout = 0,
                            whileDead = true,
                            hideOnEscape = true
                        }
                        StaticPopup_Show("SKILLTREE_IMPORT_ERROR")
                    end
                end
            end,
            EditBoxOnEnterPressed = function(self)
                local code = self:GetText()
                if code and code ~= "" then
                    local nodes, error = ImportLoadoutFromCode(code)
                    if nodes then
                        local success, applyError = ApplyImportedLoadout(nodes)
                        if success then
                            DebugPrint(
                                "|cff00FF00Build imported successfully! (" ..
                                #nodes .. " talents)|r")
                        else
                            StaticPopupDialogs["SKILLTREE_IMPORT_ERROR"] = {
                                text = "Import failed:\n\n|cffFF0000" ..
                                    (applyError or "Failed to apply build") ..
                                    "|r",
                                button1 = "OK",
                                timeout = 0,
                                whileDead = true,
                                hideOnEscape = true
                            }
                            StaticPopup_Show("SKILLTREE_IMPORT_ERROR")
                        end
                    else
                        StaticPopupDialogs["SKILLTREE_IMPORT_ERROR"] = {
                            text = "Import failed:\n\n|cffFF0000" ..
                                (error or "Unknown error") .. "|r",
                            button1 = "OK",
                            timeout = 0,
                            whileDead = true,
                            hideOnEscape = true
                        }
                        StaticPopup_Show("SKILLTREE_IMPORT_ERROR")
                    end
                end
                self:GetParent():Hide()
            end,
            EditBoxOnEscapePressed = function(self)
                self:GetParent():Hide()
            end
        }
        StaticPopup_Show("SKILLTREE_IMPORT_CODE")
    end)


    local revertBtn = CreateFrame("Button", nil, bottomBar)
    revertBtn:SetSize(25, 25)
    revertBtn:SetPoint("RIGHT", bottomBar, "RIGHT", -10, 0)
    revertBtn:SetScript("OnClick", function() RevertToValidatedState() end)


    local revertIcon = revertBtn:CreateTexture(nil, "ARTWORK")
    revertIcon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    revertIcon:SetSize(20, 20)
    revertIcon:SetPoint("CENTER", revertBtn, "CENTER", 0, 0)

    revertBtn:Disable()
    revertIcon:SetDesaturated(true)
    revertIcon:SetAlpha(0.5)


    revertBtn.icon = revertIcon


    revertBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Revert Changes", 1, 1, 1)
        GameTooltip:AddLine("Undo all changes since last validation", 0.8, 0.8,
            0.8, true)
        GameTooltip:Show()
    end)
    revertBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)


    _G.revertBtn = revertBtn


    local levelRestrictionFrame = CreateFrame("Frame", nil, bottomBar)
    levelRestrictionFrame:SetPoint("TOPLEFT", bottomBar, "TOPLEFT", 0, 0)
    levelRestrictionFrame:SetPoint("BOTTOMRIGHT", bottomBar, "BOTTOMRIGHT", 0, 0)
    levelRestrictionFrame:SetFrameLevel(bottomBar:GetFrameLevel() + 20)
    levelRestrictionFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    levelRestrictionFrame:SetBackdropColor(0, 0, 0, 1)
    levelRestrictionFrame:EnableMouse(true)
    levelRestrictionFrame:Hide()

    local levelRestrictionText = levelRestrictionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    levelRestrictionText:SetPoint("CENTER", levelRestrictionFrame, "CENTER", 0, 0)
    levelRestrictionText:SetText("|cffFF0000You cannot modify your skill tree while in combat|r")


    local function UpdateCombatRestriction()
        local inCombat = UnitAffectingCombat("player")

        if inCombat then
            levelRestrictionFrame:Show()
        else
            levelRestrictionFrame:Hide()
        end
    end


    local combatCheckFrame = CreateFrame("Frame")
    combatCheckFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatCheckFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatCheckFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    combatCheckFrame:SetScript("OnEvent", function(self, event)
        UpdateCombatRestriction()
    end)


    bottomBar.levelRestrictionFrame = levelRestrictionFrame
    bottomBar.updateCombatRestriction = UpdateCombatRestriction

    -- Search box on the right side of the bottom bar (before the revert button)
    if not treeSearchBox then
        local treeSearchLabel = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        treeSearchLabel:SetPoint("RIGHT", revertBtn, "LEFT", -155, 0)
        treeSearchLabel:SetText("Search:")

        treeSearchBox = CreateFrame("EditBox", "skillTreeSearchBox", bottomBar, "InputBoxTemplate")
        treeSearchBox:SetSize(140, 22)
        treeSearchBox:SetPoint("LEFT", treeSearchLabel, "RIGHT", 8, 0)
        treeSearchBox:SetAutoFocus(false)
        treeSearchBox:SetMaxLetters(50)
        treeSearchBox:SetFrameLevel(bottomBar:GetFrameLevel() + 5)
        treeSearchBox:SetScript("OnTextChanged", function(self)
            FilterTreeNodes(self:GetText())
        end)
        treeSearchBox:SetScript("OnEscapePressed", function(self)
            self:SetText("")
            self:ClearFocus()
            FilterTreeNodes("")
        end)
    end

    hasUnsavedChanges = false
end


local Scroll = CreateFrame("ScrollFrame", "skillTreeScroll", skillTreeFrame)
Scroll:SetPoint("TOPLEFT", 10, -15)
Scroll:SetPoint("BOTTOMRIGHT", -10, 50)
Scroll:EnableMouse(true)
Scroll:EnableMouseWheel(true)


local Canvas = CreateFrame("Frame", "skillTreeCanvas", Scroll)
Scroll:SetScrollChild(Canvas)


local zoomLevel = 1.0
local MIN_ZOOM = 0.5
local MAX_ZOOM = 2.0
local ZOOM_STEP = 0.1


local ComputeLayout


local function ApplyZoom(scale)
    zoomLevel = math.max(MIN_ZOOM, math.min(MAX_ZOOM, scale))
    Canvas:SetScale(zoomLevel)


    ComputeLayout()


    if not skillTreeFrame.zoomText then
        skillTreeFrame.zoomText = skillTreeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        skillTreeFrame.zoomText:SetPoint("TOP", skillTreeFrame, "TOP", 0, -10)
    end
    skillTreeFrame.zoomText:SetText(string.format("Zoom: %d%%", zoomLevel * 100))


    local currentTime = GetTime()
    skillTreeFrame.zoomTimestamp = currentTime
    C_Timer.After(1, function()
        if skillTreeFrame.zoomText and skillTreeFrame.zoomTimestamp == currentTime then
            skillTreeFrame.zoomText:SetText("")
        end
    end)
end


Scroll:SetScript("OnMouseWheel", function(self, delta)
    local newZoom = zoomLevel + (delta * ZOOM_STEP)
    ApplyZoom(newZoom)
end)




ComputeLayout = function()
    local NODE_SIZE = 1

    local minX, maxX, minY, maxY
    for _, n in ipairs(TreeNodes) do
        if not minX or n.x < minX then minX = n.x end
        if not maxX or n.x > maxX then maxX = n.x end
        if not minY or n.y < minY then minY = n.y end
        if not maxY or n.y > maxY then maxY = n.y end
    end

    local margin = 300
    local SPACING_SCALE = 0.8
    local scaledWidth = (maxX - minX) * SPACING_SCALE
    local scaledHeight = (maxY - minY) * SPACING_SCALE
    local baseCanvasW = scaledWidth + NODE_SIZE + margin * 2
    local baseCanvasH = scaledHeight + NODE_SIZE + margin * 2

    -- Compensate canvas size for zoom level to ensure scrolling works when zoomed out
    -- When zoomed out (zoomLevel < 1), we need a larger canvas to maintain scroll range
    local zoomCompensation = 1 / zoomLevel
    local canvasW = baseCanvasW * zoomCompensation
    local canvasH = baseCanvasH * zoomCompensation
    Canvas:SetSize(canvasW, canvasH)

    for _, n in ipairs(TreeNodes) do
        n._ox = margin + (n.x - minX) * SPACING_SCALE
        n._oy = -(margin + (maxY - n.y) * SPACING_SCALE)
    end

    Scroll:SetHorizontalScroll(Scroll:GetHorizontalScrollRange() / 2)
    Scroll:SetVerticalScroll(Scroll:GetVerticalScrollRange() / 2)
end

local function applyNodeVisual(btn)
    if btn.isApex then
        if not btn.apexBorderTexture then
            btn.apexBorderTexture = btn:CreateTexture(nil, "OVERLAY")
            btn.apexBorderTexture:SetTexture(
                "Interface\\Buttons\\UI-ActionButton-Border")
            btn.apexBorderTexture:SetBlendMode("ADD")
            btn.apexBorderTexture:SetPoint("TOPLEFT", btn, "TOPLEFT", -16, 16)
            btn.apexBorderTexture:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",
                16, -16)
            btn.apexBorderTexture:SetVertexColor(1.0, 0.2, 1.0, 0.8)
        end


        btn.apexBorderTexture:Show()
        btn.borderFrame:SetBackdropBorderColor(unpack(COLOR_APEX))
    end

    if btn.state == "active" then
        local currentRank = nodeRanks[btn.id] or 0
        local maxRank = #btn.spells or 0

        if currentRank >= maxRank then
            btn.borderFrame:SetBackdropBorderColor(unpack(COLOR_ORANGE))
        else
            btn.borderFrame:SetBackdropBorderColor(unpack(COLOR_GREEN))
        end
        btn.icon:SetDesaturated(false)
        btn.icon:SetAlpha(1.0)
    elseif btn.state == "ready" then
        btn.borderFrame:SetBackdropBorderColor(unpack(COLOR_GREEN))
        btn.icon:SetDesaturated(false)
        btn.icon:SetAlpha(1.0)
    elseif btn.state == "nopoints" then
        btn.borderFrame:SetBackdropBorderColor(1.0, 0.82, 0.0, 1.0)
        btn.icon:SetDesaturated(true)
        btn.icon:SetAlpha(0.85)
    else
        btn.borderFrame:SetBackdropBorderColor(unpack(COLOR_GRAY))
        btn.icon:SetDesaturated(true)
        btn.icon:SetAlpha(0.7)
    end


    if not btn.rankText then
        btn.rankText = btn:CreateFontString(nil, "OVERLAY",
            "GameFontNormalSmall")
        btn.rankText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

        local fontName, fontSize = btn.rankText:GetFont()
        btn.rankText:SetFont(fontName, 9, "OUTLINE")
    end

    local currentRank = nodeRanks[btn.id] or 0


    if btn.state == "locked" then
        btn.rankText:Hide()
    else
        btn.rankText:Show()


        if btn.isMultipleChoice then
            if nodeChoices[btn.id] and nodeChoices[btn.id] ~= 0 then
                btn.rankText:SetText("✓")
                btn.rankText:SetTextColor(unpack(COLOR_ORANGE))
            else
                btn.rankText:SetText("")
            end
        else
            local maxRank = #btn.spells or 0
            btn.rankText:SetText(currentRank .. "/" .. maxRank)

            if currentRank > 0 then
                if currentRank >= maxRank then
                    btn.rankText:SetTextColor(unpack(COLOR_ORANGE))
                else
                    btn.rankText:SetTextColor(unpack(COLOR_GREEN))
                end
            elseif btn.state == "nopoints" then
                btn.rankText:SetTextColor(1.0, 0.82, 0.0, 1.0)
            else
                btn.rankText:SetTextColor(unpack(COLOR_GREEN))
            end
        end
    end
end

local function NodeCenterOffsets(btn)
    local w, h = btn:GetWidth(), btn:GetHeight()
    local _, _, _, ox, oy = btn:GetPoint(1)
    return ox + w * 0.5, oy - h * 0.5
end

local function MakeAnimatedRotatingLine(x1, y1, x2, y2, thickness, duration)
    local dx, dy = x2 - x1, y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return nil end

    local targetAngleDeg = math.deg(math.atan2(dy, dx))
    local animDuration = duration or 1

    local tex = Canvas:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    tex:SetBlendMode("BLEND")
    tex:SetAlpha(0)
    tex:SetSize(dist, thickness or 2)

    local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
    tex:SetPoint("CENTER", Canvas, "TOPLEFT", cx, cy)

    local ag = tex:CreateAnimationGroup()
    local rot = ag:CreateAnimation("Rotation")
    rot:SetDegrees(targetAngleDeg)
    rot:SetDuration(animDuration)
    rot:SetOrder(1)
    rot:SetOrigin("CENTER", 0, 0)
    rot:SetEndDelay(999999) -- Keep the final rotation state indefinitely
    ag:SetLooping("NONE")

    -- Use animation's OnFinished callback instead of unreliable OnUpdate timing
    rot:SetScript("OnFinished", function()
        tex:SetAlpha(1)
    end)

    -- Fallback: ensure texture becomes visible even if callback fails
    local driver = CreateFrame("Frame")
    driver.elapsed = 0
    driver.animDuration = animDuration
    driver.tex = tex
    driver:SetScript("OnUpdate", function(self, elapsed)
        elapsed = math.min(elapsed, 0.1)
        self.elapsed = self.elapsed + elapsed
        -- Use a slightly longer timeout as safety margin
        if self.elapsed >= self.animDuration + 0.1 then
            if self.tex:GetAlpha() < 1 then
                self.tex:SetAlpha(1)
            end
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)

    ag:Play()

    return tex, { tex }, driver, ag
end

local function BuildNeighborsAndParents()
    neighbors, parentsOf = {}, {}
    DebugPrint("|cff00FFFFBuilding neighbors from " .. #Links .. " links|r")
    for _, e in ipairs(Links) do
        local a, b = e[1], e[2]
        neighbors[a] = neighbors[a] or {}
        neighbors[b] = neighbors[b] or {}
        table.insert(neighbors[a], b)
        table.insert(neighbors[b], a)


        parentsOf[b] = parentsOf[b] or {}
        table.insert(parentsOf[b], a)
    end
    DebugPrint("|cff00FFFFNeighbors table built successfully|r")
end

local function displayTalentPoints()
    if skillTreeFrame.pointsText then
        skillTreeFrame.pointsText:SetText(
            "|cffFFD700Soul Ashes: |r|cffFFFFFF" .. GetRemainingTalentPoints() ..
            "|r")
    end
end

function updateTalentPoints()
    displayTalentPoints()
end

local function canAffordTalent(nodeId)
    local btn = nodesById[nodeId]
    if not btn then return false end

    local currentRank = getNodeRank(nodeId)
    local nextRank = currentRank + 1
    local nodeCost = getNodeCost(btn, nextRank)

    return GetRemainingTalentPoints() >= nodeCost
end

local function canUpgradeNode(nodeId)
    local btn = nodesById[nodeId]
    if not btn then return false end


    if not hasPrerequisites(nodeId) then
        DebugPrint("Node %d cannot be upgraded - prerequisites not met", nodeId)
        return false
    end


    if btn.isMultipleChoice then
        return (nodeChoices[nodeId] or 0) == 0 and canAffordTalent(nodeId)
    end


    local currentRank = getNodeRank(nodeId)
    local maxRank = getMaxRank(nodeId)
    return currentRank < maxRank and canAffordTalent(nodeId)
end

local function canDowngradeNode(nodeId)
    local btn = nodesById[nodeId]
    if not btn then return false end

    -- Permanent nodes that have been validated on server cannot be downgraded
    if btn.permanent and lastValidatedState and lastValidatedState.nodeRanks
        and (lastValidatedState.nodeRanks[nodeId] or 0) > 0 then
        return false
    end

    if btn.isMultipleChoice then
        local hasChoice = (nodeChoices[nodeId] or 0) ~= 0
        if not hasChoice then return false end
    else
        local currentRank = getNodeRank(nodeId)
        if currentRank <= 0 then return false end
    end

    local currentRank = getNodeRank(nodeId)
    local maxRank = getMaxRank(nodeId)
    -- Check if any child node has progress and depends on this node
    -- Since hasPrerequisites requires ALL parents to be maxed,
    -- we cannot downgrade if ANY active child has this node as a parent
    if not btn.isMultipleChoice and currentRank >= maxRank then
        for otherId, otherBtn in pairs(nodesById) do
            if otherId ~= nodeId then
                local otherHasProgress = false

                if otherBtn.isMultipleChoice then
                    otherHasProgress = (nodeChoices[otherId] or 0) ~= 0
                else
                    otherHasProgress = getNodeRank(otherId) > 0
                end

                if otherHasProgress then
                    local parents = parentsOf[otherId]
                    if parents then
                        -- Check if this node is a parent of the active child
                        for _, parentId in ipairs(parents) do
                            if parentId == nodeId then
                                -- This node is a required parent of an active child
                                -- Since ALL parents must be maxed, we cannot downgrade
                                return false
                            end
                        end
                    end
                end
            end
        end
    end

    return true
end

local function upgradeNodeRank(nodeId)
    local btn = nodesById[nodeId]
    if not btn or not canUpgradeNode(nodeId) then return false end


    if btn.isApex then
        if activeApexNodeId and activeApexNodeId ~= nodeId then
            DebugPrint(
                "|cffFF0000You can only have one APEX talent active at a time!|r")
            DebugPrint("|cffFFFF00Deactivate your current APEX talent first.|r")
            return false
        end
        activeApexNodeId = nodeId
    end


    if btn.isMultipleChoice then
        if (nodeChoices[nodeId] or 0) == 0 then
            ShowChoiceButtons(btn)
            return false
        end
        return false
    end


    local currentRank = nodeRanks[nodeId] or 0
    local nextRank = currentRank + 1
    local nodeCost = getNodeCost(btn, nextRank)

    nodeRanks[nodeId] = nextRank
    TALENT_POINTS_TOTAL = TALENT_POINTS_TOTAL - nodeCost

    DebugPrint("Node %d upgraded to rank %d (cost: %d, remaining: %d)",
        nodeId, nextRank, nodeCost, TALENT_POINTS_TOTAL)
    MarkUnsavedChanges()
    return true
end

local function downgradeNodeRank(nodeId)
    local btn = nodesById[nodeId]
    if not btn or not canDowngradeNode(nodeId) then return false end


    if btn.isApex and activeApexNodeId == nodeId then activeApexNodeId = nil end


    if btn.isMultipleChoice then
        local refund = getNodeCost(btn, 1)
        TALENT_POINTS_TOTAL = TALENT_POINTS_TOTAL + refund

        nodeChoices[nodeId] = 0
        nodeRanks[nodeId] = 0
        btn.selectedSpell = nil


        if btn.spells and #btn.spells > 0 then
            btn.icon:SetTexture(getSpellIconSafe(btn.spells[1]))
        end

        DebugPrint("Node %d choice removed (refund: %d, remaining: %d)",
            nodeId, refund, TALENT_POINTS_TOTAL)
        MarkUnsavedChanges()
        return true
    end


    local currentRank = nodeRanks[nodeId] or 0
    if currentRank > 0 then
        local refund = getNodeCost(btn, currentRank)
        TALENT_POINTS_TOTAL = TALENT_POINTS_TOTAL + refund

        nodeRanks[nodeId] = currentRank - 1

        DebugPrint("Node %d downgraded to rank %d (refund: %d, remaining: %d)",
            nodeId, currentRank - 1, refund, TALENT_POINTS_TOTAL)
    end

    MarkUnsavedChanges()
    return true
end

local function updateLinkColors()
    for _, L in ipairs(lines) do
        local a, b = L.a, L.b
        local color
        if a.state == "active" and b.state == "active" then
            color = COLOR_ORANGE
        elseif (a.state == "active" and b.state == "ready") or
            (b.state == "active" and a.state == "ready") then
            color = COLOR_GREEN
        else
            color = COLOR_GRAY
        end


        if not L.lastColor or L.lastColor ~= color then
            L.lastColor = color

            if L.tex then L.tex:SetVertexColor(unpack(color)) end
        end
    end
end




local function ShowChoiceButtons(btn)
    if not btn.spells or #btn.spells <= 1 then return end
    if #btn.choiceButtons > 0 then return end


    local numChoices = #btn.spells

    for i, spellID in ipairs(btn.spells) do
        local offsetX, offsetY = 0, 0
        if numChoices == 2 then
            offsetX = (i == 1) and -18 or 18
            offsetY = 25
        else
            local angle = (i - 1) * (2 * math.pi / numChoices) - math.pi / 2
            offsetX = 35 * math.cos(angle)
            offsetY = 35 * math.sin(angle)
        end


        local choiceBtn = CreateFrame("Button", nil, Canvas)
        choiceBtn:SetSize(30, 30)
        choiceBtn:SetPoint("CENTER", btn, "CENTER", offsetX, offsetY)
        choiceBtn:SetFrameLevel(btn:GetFrameLevel() + 10)


        choiceBtn.borderFrame = CreateFrame("Frame", nil, choiceBtn)
        choiceBtn.borderFrame:SetPoint("TOPLEFT", choiceBtn, "TOPLEFT", -3, 3)
        choiceBtn.borderFrame:SetPoint("BOTTOMRIGHT", choiceBtn, "BOTTOMRIGHT",
            3, -3)
        choiceBtn.borderFrame:SetFrameLevel(choiceBtn:GetFrameLevel())


        local spellName, _, iconTex = GetSpellInfo(spellID)
        if not spellName then
            iconTex = "Interface\\Icons\\INV_Misc_QuestionMark"
            DebugPrint("Warning: Invalid spell ID %s in talent database",
                spellID)
        end
        local icon = choiceBtn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints(choiceBtn)
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        icon:SetTexture(iconTex or "Interface\\Icons\\INV_Misc_QuestionMark")
        choiceBtn.icon = icon


        choiceBtn.borderFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })

        if btn.state == "locked" then
            choiceBtn.borderFrame:SetBackdropBorderColor(0.3, 0.3, 0.3)
            choiceBtn:SetAlpha(0.5)
            choiceBtn.icon:SetDesaturated(true)
        elseif i == btn.selectedSpell then
            choiceBtn.borderFrame:SetBackdropBorderColor(0, 1, 0)
            choiceBtn:SetAlpha(1.0)
            choiceBtn.icon:SetDesaturated(false)
        else
            choiceBtn.borderFrame:SetBackdropBorderColor(1, 1, 1)
            choiceBtn:SetAlpha(0.8)
            choiceBtn.icon:SetDesaturated(false)
        end


        choiceBtn:SetScript("OnEnter", function()
            if btn.hideFrame then
                btn.hideFrame:SetScript("OnUpdate", nil)
                btn.hideFrame.timer = nil
            end

            GameTooltip:SetOwner(choiceBtn, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink('spell:' .. spellID)

            if btn.state == "locked" then
                GameTooltip:AddLine("|cffFF0000Node is locked|r", 1, 1, 1)
            elseif i == btn.selectedSpell then
                GameTooltip:AddLine("|cff00FF00Currently Selected|r", 1, 1, 1)
            else
                GameTooltip:AddLine("|cffFFFFFFClick to select this option|r",
                    1, 1, 1)
            end
            GameTooltip:Show()
        end)
        choiceBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)


        choiceBtn:SetScript("OnClick", function()
            if btn.state ~= "locked" and canAffordTalent(btn.id) then
                local nodeCost = getNodeCost(btn, 1)
                TALENT_POINTS_TOTAL = TALENT_POINTS_TOTAL - nodeCost

                btn.selectedSpell = i
                nodeChoices[btn.id] = i
                nodeRanks[btn.id] = 1

                DebugPrint("Node %d choice %d selected (cost: %d, remaining: %d)",
                    btn.id, i, nodeCost, TALENT_POINTS_TOTAL)
                MarkUnsavedChanges()


                btn.icon:SetTexture(getSpellIconSafe(spellID))


                for j, otherBtn in ipairs(btn.choiceButtons) do
                    if btn.state == "locked" then
                        otherBtn.borderFrame:SetBackdropBorderColor(0.3, 0.3,
                            0.3)
                        otherBtn:SetAlpha(0.5)
                        otherBtn.icon:SetDesaturated(true)
                    elseif j == i then
                        otherBtn.borderFrame:SetBackdropBorderColor(0, 1, 0)
                        otherBtn:SetAlpha(1.0)
                        otherBtn.icon:SetDesaturated(false)
                    else
                        otherBtn.borderFrame:SetBackdropBorderColor(1, 1, 1)
                        otherBtn:SetAlpha(0.8)
                        otherBtn.icon:SetDesaturated(false)
                    end
                end


                refreshAccessibility()


                local spellName = GetSpellInfo(spellID)
                if not spellName then
                    spellName = "Invalid Spell (" .. spellID .. ")"
                end
                DebugPrint("|cff00FF00Choice selected: " ..
                    (spellName or "Unknown") .. "|r")


                HideChoiceButtons(btn)
            elseif btn.state == "locked" then
                DebugPrint(
                    "|cffFF0000Prerequisites not met! You cannot select this option yet.|r")
            elseif not canAffordTalent(btn.id) then
                DebugPrint("|cffFF0000Not enough Soul Points!|r")
            end
        end)

        choiceBtn.spellID = spellID
        table.insert(btn.choiceButtons, choiceBtn)
    end
end

function HideChoiceButtons(btn)
    if btn.choiceButtons then
        for _, choiceBtn in ipairs(btn.choiceButtons) do
            choiceBtn:Hide()
            choiceBtn:SetParent(nil)
        end
    end
    btn.choiceButtons = {}
end

local function updateNodeDisplay(btn, nodeId)
    if not btn or not btn.spells then return end

    local currentRank = getNodeRank(nodeId)
    local maxRank = getMaxRank(nodeId)


    local currentSpellID
    if btn.isMultipleChoice then
        local selectedChoice = nodeChoices[nodeId] or 1
        currentSpellID = btn.spells[selectedChoice]
    elseif currentRank > 0 then
        currentSpellID = btn.spells[currentRank]
    else
        currentSpellID = btn.spells[1]
    end

    if currentSpellID then
        local _, _, iconTex = GetSpellInfo(currentSpellID)
        if not iconTex then
            iconTex = "Interface\\Icons\\INV_Misc_QuestionMark"
            DebugPrint("Warning: Invalid spell ID %s in updateNodeDisplay",
                currentSpellID)
        end
        btn.icon:SetTexture(iconTex or "Interface\\Icons\\INV_Misc_QuestionMark")
    end


    if not btn.rankText then
        btn.rankText = btn:CreateFontString(nil, "OVERLAY",
            "GameFontNormalSmall")
        btn.rankText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
        btn.rankText:SetTextColor(1, 1, 0)

        btn.rankText:SetShadowOffset(1, -1)
        btn.rankText:SetShadowColor(0, 0, 0, 1)
    end

    if btn.isMultipleChoice then
        btn.rankText:SetText(currentRank > 0 and "✓" or "")
    else
        btn.rankText:SetText(currentRank .. "/" .. maxRank)
    end
end

function refreshAccessibility()
    updateTalentPoints()


    for nid, btn in pairs(nodesById) do
        local hasProgress = isNodeActive(nid)

        if hasProgress then
            local currentRank = getNodeRank(nid)
            local maxRank = getMaxRank(nid)

            if currentRank >= maxRank then
                btn.state = "active"
            else
                if canAffordTalent(nid) then
                    btn.state = "ready"
                else
                    btn.state = "nopoints"
                end
            end
        elseif btn.isStart then
            if canAffordTalent(nid) then
                btn.state = "ready"
            else
                btn.state = "nopoints"
            end
        else
            local hasPrereqs = hasPrerequisites(nid)

            if hasPrereqs and canAffordTalent(nid) then
                btn.state = "ready"
            elseif hasPrereqs and not canAffordTalent(nid) then
                btn.state = "nopoints"
            else
                btn.state = "locked"
            end
        end
    end


    displayTalentPoints()


    for nid, btn in pairs(nodesById) do
        applyNodeVisual(btn)
        updateNodeDisplay(btn, nid)
    end
    updateLinkColors()
end

local function CreateNodes()
    wipe(nodesById)
    for _, n in ipairs(TreeNodes) do
        local btn = CreateFrame("Button", "skillTreeNode" .. n.id, Canvas)
        btn:SetSize(28, 28)
        btn:SetPoint("TOPLEFT", Canvas, "TOPLEFT", n._ox, n._oy)
        btn.id = n.id
        btn.isStart = n.isStart and true or false
        btn.state = btn.isStart and "ready" or "locked"


        btn.choiceButtons = {}


        btn.borderFrame = CreateFrame("Frame", nil, btn)
        btn.borderFrame:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 4)
        btn.borderFrame:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 4, -4)
        btn.borderFrame:SetFrameLevel(btn:GetFrameLevel())


        btn.spells = n.spells
        btn.isMultipleChoice = n.isMultipleChoice or false
        btn.isApex = n.isApex or false
        btn.permanent = n.permanent or false

        btn.soulPointsCosts = n.soulPointsCosts

        btn.soulPointsCost = btn.soulPointsCosts and btn.soulPointsCosts[1] or 0


        if btn.isMultipleChoice then
            btn.selectedSpell = nodeChoices[n.id] or 0
        end




        local currentSpellID
        if btn.isMultipleChoice and nodeChoices[n.id] then
            currentSpellID = btn.spells[nodeChoices[n.id]]
        elseif btn.spells then
            local currentRank = getNodeRank(n.id)
            currentSpellID = btn.spells[math.max(1, currentRank)]
        end

        if currentSpellID then
            local _, _, iconTex = GetSpellInfo(currentSpellID)
            if not iconTex then
                iconTex = "Interface\\Icons\\INV_Misc_QuestionMark"
                DebugPrint("Warning: Invalid spell ID %s in CreateNodes",
                    currentSpellID)
            end
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints(btn)
            btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            btn.icon:SetTexture(iconTex or
                "Interface\\Icons\\INV_Misc_QuestionMark")
        end
        btn.borderFrame:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        btn.borderFrame:SetBackdropBorderColor(1, 1, 1, 1)

        local function refreshNodeTooltip(node)
            if not node:IsMouseOver() then return end


            if NextRankTooltip then NextRankTooltip:Hide() end
            if CurrentRankTooltip then CurrentRankTooltip:Hide() end


            if node.spells and not node.isMultipleChoice then
                local currentRank = nodeRanks[node.id] or 0
                local maxRank = #node.spells


                if currentRank > 0 then
                    local currentSpellID = node.spells[currentRank]
                    if currentSpellID then
                        local spellName, _, spellIcon, castTime, minRange,
                        maxRange, _, _, _ = GetSpellInfo(currentSpellID)
                        if spellName then
                            CurrentRankTooltip:SetOwner(node, "ANCHOR_RIGHT")
                            CurrentRankTooltip:SetHyperlink('spell:' ..
                                currentSpellID)

                            if not node.permanent then
                                CurrentRankTooltip:AddLine(
                                    "\n|cff00FF00Rank: " .. currentRank .. "/" ..
                                    maxRank .. "|r", 1, 1, 1)

                                if currentRank < maxRank then
                                    local nextRank = currentRank + 1
                                    local soulCost = getNodeCost(node, nextRank)
                                    local canAfford = TALENT_POINTS_TOTAL >= soulCost
                                    addCostToTooltip(CurrentRankTooltip, "Next rank: ", soulCost, canAfford)
                                end
                            end

                            CurrentRankTooltip:Show()
                        end
                    end
                else
                    local firstSpellID = node.spells[1]
                    if firstSpellID then
                        local spellName, _, spellIcon, castTime, minRange,
                        maxRange, _, _, _ = GetSpellInfo(firstSpellID)
                        if spellName then
                            CurrentRankTooltip:SetOwner(node, "ANCHOR_RIGHT")
                            CurrentRankTooltip:SetHyperlink('spell:' ..
                                firstSpellID)

                            if not node.permanent then
                                CurrentRankTooltip:AddLine(
                                    "\n|cffFFFFFFRank: 0/" .. maxRank .. "|r", 1, 1, 1)
                            end

                            local soulCost = getNodeCost(node, 1)
                            local canAfford = TALENT_POINTS_TOTAL >= soulCost
                            addCostToTooltip(CurrentRankTooltip, node.permanent and "" or "First rank: ", soulCost, canAfford)

                            CurrentRankTooltip:Show()
                        end
                    end
                end

                if not node.isMultipleChoice and maxRank > 1 and currentRank > 0 then
                    local nextRank = currentRank + 1
                    if nextRank <= maxRank and NextRankTooltip then
                        local nextSpellID = node.spells[nextRank]
                        if nextSpellID then
                            local nextSpellName, _, nextSpellIcon, castTime,
                            minRange, maxRange, _, _, _ = GetSpellInfo(
                                nextSpellID)
                            if nextSpellName then
                                NextRankTooltip:SetOwner(node, "ANCHOR_NONE")
                                NextRankTooltip:SetPoint("TOPLEFT",
                                    CurrentRankTooltip,
                                    "BOTTOMLEFT", 0, -5)
                                NextRankTooltip:SetHyperlink('spell:' ..
                                    nextSpellID)
                                NextRankTooltip:AddLine(
                                    "|cffFFFFFFNext Rank " .. nextRank .. ":|r",
                                    1, 1, 1)
                                NextRankTooltip:Show()
                            end
                        end
                    end
                end


                if node.state == "active" then
                    if node.permanent and lastValidatedState and lastValidatedState.nodeRanks
                        and (lastValidatedState.nodeRanks[node.id] or 0) > 0 then
                        CurrentRankTooltip:AddLine(
                            "|cffFF0000Permanent Skill|r", 1, 1, 1, true)
                    else
                        CurrentRankTooltip:AddLine(
                            "|cffAAAAAARight-click to unlearn|r", 1, 1, 1, true)
                    end
                    CurrentRankTooltip:Show();
                elseif node.state == "ready" then
                    if node.permanent then
                        CurrentRankTooltip:AddLine(
                            "|cffFF0000Permanent Skill|r", 1, 1, 1, true)
                    end
                    CurrentRankTooltip:AddLine(
                        "|cff00FF00Left-click to learn|r", 1, 1, 1, true)
                    CurrentRankTooltip:Show();
                end
            end
        end
        btn:SetScript("OnEnter", function(self)
            if self.spells then
                if self.isMultipleChoice and #self.spells > 1 then
                    ShowChoiceButtons(self)
                else
                    local currentRank = nodeRanks[self.id] or 0
                    local maxRank = #self.spells


                    if currentRank > 0 then
                        local currentSpellID = self.spells[currentRank]
                        if currentSpellID then
                            local spellName, _, spellIcon, castTime, minRange,
                            maxRange, _, _, _ = GetSpellInfo(
                                currentSpellID)
                            if spellName then
                                CurrentRankTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                CurrentRankTooltip:SetHyperlink('spell:' ..
                                    currentSpellID)

                                if not self.permanent then
                                    CurrentRankTooltip:AddLine(
                                        "\n|cff00FF00Rank: " .. currentRank ..
                                        "/" .. maxRank .. "|r", 1, 1, 1)

                                    if maxRank > 1 and currentRank < maxRank then
                                        local nextRank = currentRank + 1
                                        local soulCost = getNodeCost(self, nextRank)
                                        local canAfford = TALENT_POINTS_TOTAL >= soulCost
                                        addCostToTooltip(CurrentRankTooltip, "Next rank: ", soulCost, canAfford)
                                    elseif maxRank == 1 then
                                        local soulCost = getNodeCost(self, 1)
                                        local canAfford = TALENT_POINTS_TOTAL >= soulCost
                                        addCostToTooltip(CurrentRankTooltip, "", soulCost, canAfford)
                                    end
                                end

                                CurrentRankTooltip:Show()
                            end
                        end
                    else
                        local firstSpellID = self.spells[1]
                        if firstSpellID then
                            local spellName, _, spellIcon, castTime, minRange,
                            maxRange, _, _, _ = GetSpellInfo(firstSpellID)
                            if spellName then
                                CurrentRankTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                CurrentRankTooltip:SetHyperlink('spell:' ..
                                    firstSpellID)

                                if not self.permanent then
                                    CurrentRankTooltip:AddLine(
                                        "\n|cffFFFFFFRank: 0/" .. maxRank .. "|r", 1,
                                        1, 1)
                                end

                                local soulCost = getNodeCost(self, 1)
                                local canAfford = TALENT_POINTS_TOTAL >= soulCost
                                if self.permanent then
                                    addCostToTooltip(CurrentRankTooltip, "", soulCost, canAfford)
                                elseif maxRank > 1 then
                                    addCostToTooltip(CurrentRankTooltip, "First rank: ", soulCost, canAfford)
                                else
                                    addCostToTooltip(CurrentRankTooltip, "", soulCost, canAfford)
                                end

                                CurrentRankTooltip:Show()
                            end
                        end
                    end




                    if not self.isMultipleChoice and maxRank > 1 and currentRank >
                        0 then
                        local nextRank = currentRank + 1
                        if nextRank <= maxRank then
                            local nextSpellID = self.spells[nextRank]
                            if nextSpellID then
                                local nextSpellName, _, nextSpellIcon, castTime,
                                minRange, maxRange, _, _, _ =
                                    GetSpellInfo(nextSpellID)
                                if nextSpellName then
                                    NextRankTooltip:SetOwner(self, "ANCHOR_NONE")
                                    NextRankTooltip:SetPoint("TOPLEFT",
                                        CurrentRankTooltip,
                                        "BOTTOMLEFT", 0, -5)
                                    NextRankTooltip:SetHyperlink('spell:' ..
                                        nextSpellID)
                                    NextRankTooltip:AddLine(
                                        "|cffFFFFFFNext Rank " .. nextRank ..
                                        ":|r", 1, 1, 1)
                                    NextRankTooltip:Show()
                                end
                            end
                        end
                    end


                    if self.state == "active" then
                        if self.permanent and lastValidatedState and lastValidatedState.nodeRanks
                            and (lastValidatedState.nodeRanks[self.id] or 0) > 0 then
                            CurrentRankTooltip:AddLine(
                                "|cffFF0000Permanent Skill|r", 1, 1, 1, true)
                        else
                            CurrentRankTooltip:AddLine(
                                "|cffAAAAAARight-click to unlearn|r", 1, 1, 1, true)
                        end
                        CurrentRankTooltip:Show();
                    elseif self.state == "ready" then
                        if self.permanent then
                            CurrentRankTooltip:AddLine(
                                "|cffFF0000Permanent Skill|r", 1, 1, 1, true)
                        end
                        CurrentRankTooltip:AddLine(
                            "|cff00FF00Left-click to learn|r", 1, 1, 1, true)
                        CurrentRankTooltip:Show();
                    end
                end

                if self.isApex then
                    CurrentRankTooltip:AddLine(
                        "|cffFFAAAAOnly one Apex Talent can be active at a time.|r",
                        1, 1, 1, true)
                    CurrentRankTooltip:Show()
                end
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self.hideFrame then
                self.hideFrame = CreateFrame("Frame")
            end

            self.hideFrame:SetScript("OnUpdate", function(frame, elapsed)
                elapsed = math.min(elapsed, 0.1) -- Cap elapsed to prevent freeze after alt-tab
                frame.timer = (frame.timer or 0) + elapsed
                if frame.timer > 0.1 then
                    frame:SetScript("OnUpdate", nil)
                    frame.timer = nil


                    local mouseOverChoice = false
                    for _, choiceBtn in ipairs(self.choiceButtons) do
                        if choiceBtn:IsMouseOver() then
                            mouseOverChoice = true
                            break
                        end
                    end

                    if not self:IsMouseOver() and not mouseOverChoice then
                        HideChoiceButtons(self)
                    end
                end
            end)


            NextRankTooltip:Hide()
            CurrentRankTooltip:Hide()
        end)




        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(self, button)
            local nodeId = self.id
            local currentTime = GetTime()


            if currentTime - lastNodeClickTime < NODE_CLICK_COOLDOWN then
                return
            end


            if currentTime - rapidClickResetTime > RAPID_CLICK_WINDOW then
                rapidClickCount = 0
                rapidClickResetTime = currentTime
            end

            rapidClickCount = rapidClickCount + 1

            if rapidClickCount > RAPID_CLICK_THRESHOLD then
                -- DEFAULT_CHAT_FRAME:AddMessage(
                --    "|cffFF0000[Skill Tree] Macro usage detected. Please click talents manually.|r")
                return
            end

            lastNodeClickTime = currentTime


            if UnitAffectingCombat("player") then
                DebugPrint("|cffFF0000You cannot modify your skill tree while in combat!|r")
                return
            end

            if button == "LeftButton" then
                if self.isMultipleChoice then
                    if #self.choiceButtons == 0 then
                        DebugPrint(
                            "|cffFFFF00Hover over this node to see available choices|r")
                    end
                    return
                end


                if canUpgradeNode(nodeId) then
                    -- If the node is permanent, show a confirmation popup before learning
                    if self.permanent then
                        local selfRef = self
                        StaticPopupDialogs["SKILLTREE_PERMANENT_CONFIRM"] = {
                            text =
                            "|cffFF4444Warning: Permanent SKill|r\n\nThis Skill is |cffFF0000permanent|r and cannot be unlearned once the changes are applied.\n\nAre you sure you want to learn it?",
                            button1 = "Yes, Learn It",
                            button2 = "Cancel",
                            timeout = 0,
                            whileDead = true,
                            hideOnEscape = true,
                            showAlert = true,
                            OnAccept = function()
                                local success = upgradeNodeRank(nodeId)
                                if success then
                                    refreshAccessibility()
                                    local currentRank = nodeRanks[nodeId] or 0
                                    local maxRank = #selfRef.spells or 0
                                    DebugPrint("|cff00FF00Permanent talent upgraded to rank " ..
                                        currentRank .. "/" .. maxRank .. "!|r")
                                    refreshNodeTooltip(selfRef)
                                end
                            end,
                        }
                        local popup = StaticPopup_Show("SKILLTREE_PERMANENT_CONFIRM")
                        if popup then
                            popup:SetFrameStrata("TOOLTIP")
                        end
                        return
                    end

                    local success = upgradeNodeRank(nodeId)
                    if success then
                        refreshAccessibility()
                        local currentRank = nodeRanks[nodeId] or 0
                        local maxRank = #self.spells or 0
                        DebugPrint("|cff00FF00Talent upgraded to rank " ..
                            currentRank .. "/" .. maxRank .. "!|r")

                        refreshNodeTooltip(self)
                    end
                else
                    local currentRank = nodeRanks[nodeId] or 0
                    local maxRank = #self.spells or 0

                    if currentRank >= maxRank then
                        DebugPrint(
                            "|cffFF0000Talent is already at maximum rank (" ..
                            maxRank .. ")!|r")
                    elseif not canAffordTalent(nodeId) then
                        DebugPrint("|cffFF0000Not enough Soul Ashes!|r")
                    elseif self.state == "locked" then
                        DebugPrint("|cffFF0000Prerequisites not met!|r")
                    end
                end
            elseif button == "RightButton" then
                if self.isMultipleChoice and #self.choiceButtons > 0 then
                    HideChoiceButtons(self)
                    return
                end


                if not self.isMultipleChoice then
                    -- Block unlearning permanent nodes that have been validated on server
                    if self.permanent and lastValidatedState and lastValidatedState.nodeRanks
                        and (lastValidatedState.nodeRanks[nodeId] or 0) > 0 then
                        DebugPrint("|cffFF0000This talent is permanent and cannot be unlearned!|r")
                        return
                    end

                    if canDowngradeNode(nodeId) then
                        local success = downgradeNodeRank(nodeId)
                        if success then
                            refreshAccessibility()
                            local currentRank = getNodeRank(nodeId)
                            local maxRank = getMaxRank(nodeId)
                            DebugPrint("|cffFFFF00Talent downgraded to rank " ..
                                currentRank .. "/" .. maxRank ..
                                ".|r")

                            refreshNodeTooltip(self)
                        end
                    else
                        local currentRank = getNodeRank(nodeId)
                        if currentRank <= 0 then
                            DebugPrint("|cffFF0000Talent is not learned yet!|r")
                        else
                            DebugPrint(
                                "|cffFF0000Cannot downgrade: Other talents depend on this one!|r")
                        end
                    end
                end
            end
        end)




        btn:SetScript("OnMouseDown", function(self, button)
            if (button == "LeftButton" and self.state == "ready") or
                (button == "RightButton" and self.state == "active") then
                return
            end


            if Scroll:GetScript("OnMouseDown") then
                Scroll:GetScript("OnMouseDown")(Scroll, button)
            end
        end)
        btn:SetScript("OnMouseUp", function(_, button)
            if Scroll:GetScript("OnMouseUp") then
                Scroll:GetScript("OnMouseUp")(Scroll, button)
            end
        end)

        nodesById[n.id] = btn
        applyNodeVisual(btn)
    end
end

local function CreateLinks()
    for _, L in ipairs(lines) do
        if L.animGroup then
            L.animGroup:Stop()
        end

        if L.driver then
            L.driver:SetScript("OnUpdate", nil)
            L.driver:Hide()
        end

        if L.tex then L.tex:Hide() end

        if L.segments then
            for _, segment in ipairs(L.segments) do segment:Hide() end
        end
    end
    wipe(lines)

    for _, e in ipairs(Links) do
        local a, b = nodesById[e[1]], nodesById[e[2]]
        if a and b then
            local ax, ay = NodeCenterOffsets(a)
            local bx, by = NodeCenterOffsets(b)


            local mainTex, allSegments, driver, animGroup =
                MakeAnimatedRotatingLine(ax, ay, bx, by, 3)
            if mainTex then
                lines[#lines + 1] = {
                    tex = mainTex,
                    segments = allSegments,
                    driver = driver,
                    animGroup = animGroup,
                    a = a,
                    b = b
                }
            end
        end
    end
    updateLinkColors()
end




local dragging = false
local startX, startY, startH, startV

local function GetCursorScaled()
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()
    return x / s, y / s
end

Scroll:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" or button == "RightButton" then
        dragging = true
        startX, startY = GetCursorScaled()
        startH = self:GetHorizontalScroll()
        startV = self:GetVerticalScroll()
    end
end)

Scroll:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" or button == "RightButton" then
        dragging = false
    end
end)

local scrollUpdateTimer = 0
local SCROLL_UPDATE_INTERVAL = 0.016
Scroll:SetScript("OnUpdate", function(self, elapsed)
    if ProjectEbonhold_IsClosing then return end
    if not dragging or not UIParent:IsShown() then return end
    elapsed = math.min(elapsed, 0.1) -- Cap elapsed to prevent freeze after alt-tab

    scrollUpdateTimer = scrollUpdateTimer + elapsed
    if scrollUpdateTimer < SCROLL_UPDATE_INTERVAL then return end
    scrollUpdateTimer = 0

    local x, y = GetCursorScaled()
    local dx, dy = x - startX, y - startY


    if math.abs(dx) < 2 and math.abs(dy) < 2 then return end

    local hMax = self:GetHorizontalScrollRange()
    local vMax = self:GetVerticalScrollRange()

    local newH = math.min(hMax, math.max(0, startH - dx))
    local newV = math.min(vMax, math.max(0, startV + dy))

    self:SetHorizontalScroll(newH)
    self:SetVerticalScroll(newV)
end)


local isTreeInitialized = false




local function InitTree()
    if isTreeInitialized then
        DebugPrint("Tree already initialized, skipping...")
        return
    end

    DebugPrint("Initializing tree...", ProjectEbonhold)


    if ProjectEbonhold and ProjectEbonhold.RequestLoadoutFromServer then
        DebugPrint("Requesting loadout from server...")
        ProjectEbonhold.RequestLoadoutFromServer()
    end

    ComputeLayout()
    BuildNeighborsAndParents()
    CreateNodes()
    CreateLinks()
    CreateBottomBar()
    refreshAccessibility()
    CheckInitialState()
    RefreshLoadoutDropdown()
    isTreeInitialized = true
    DebugPrint("Tree initialization complete")
end

skillTreeFrame:SetScript("OnShow", function()
    InitTree()

    refreshAccessibility()
    C_Timer.After(0.1, function()
        if _G.skillTreeBottomBar and _G.skillTreeBottomBar.updateLevelRestriction then
            _G.skillTreeBottomBar.updateLevelRestriction()
        end
    end)
end)


ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.SkillTree = ProjectEbonhold.SkillTree or {}
ProjectEbonhold.SkillTree.OnApplyChangesResult = OnApplyChangesResult


ProjectEbonhold.SkillTree.UpdateTotalSoulPoints =
    function(spendablePoints, committedPoints)
        TALENT_POINTS_TOTAL = spendablePoints
        TALENT_POINT_TOTAL_BASE = committedPoints

        if skillTreeFrame and skillTreeFrame.pointsText then
            skillTreeFrame.pointsText:SetText(
                "|cffFFD700Soul Ashes: |r|cffFFFFFF" .. GetRemainingTalentPoints() ..
                "|r")
        end
        if skillTreeFrame and skillTreeFrame.progressBar and skillTreeFrame.progressBar.UpdateProgressBar then
            skillTreeFrame.progressBar.UpdateProgressBar()
        end

        refreshAccessibility()
        DebugPrint(
            "|cff00FF00Soul Ashes updated - Spendable: %d, Committed: %d|r",
            TALENT_POINTS_TOTAL, TALENT_POINT_TOTAL_BASE)
    end
