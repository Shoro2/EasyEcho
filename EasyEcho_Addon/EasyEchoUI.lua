-- =========================================================
-- EASYECHO UI (English Version & Fixed Alignment)
-- =========================================================
EasyEcho_UI = {}

local historyFrame = nil
local historyScrollFrame = nil
local historyContent = nil
local scrollBar = nil
local fontStringPool = {}
local historyRowPool = {}  -- pool of row frames for history (SELECT entries get icon/tooltip/context menu)

local echoesFrame = nil
local echoesContent = nil
local echoesScrollBar = nil
local echoesRowPool = {}       -- pool of row frames for DB view
local echoesSortMode = "rarity"
local echoesSearchText = ""
local echoesSortDropDown = nil
local echoesCountLabel = nil   -- "X echoes discovered" header label
local echoesClassFilter = "All" -- class filter for DB view

local grantedFrame = nil
local grantedContent = nil
local grantedScrollBar = nil
local grantedRowPool = {}      -- pool of row frames for granted echoes view
local grantedSortMode = "rarity"
local grantedSearchText = ""
local grantedSortDropDown = nil

local MAX_REROLLS_UI = 10 

-- STATS LABELS
local statRend = nil
local statDouble = nil
local statEpicsPrio = nil  
local statEpicsOther = nil 
local statRares = nil
local statRerollsLeft = nil
local trackDDOne = nil   -- quality dropdown for tracked spell 1
local trackDDTwo = nil   -- quality dropdown for tracked spell 2
local trackedSpell1Box = nil
local trackedSpell2Box = nil

local liveUsedRerolls = 0
local liveTotalRerolls = 10

local historyStartStopBtn = nil
local miniStartStopBtn = nil

local function UpdateButtonAppearance(btn)
    if not btn then return end

    if EasyEcho_IsRunning then
        btn:SetText("Stop")
    else
        btn:SetText("Start")
    end
end

function EasyEcho_UI.UpdateStartStopButton()
    UpdateButtonAppearance(historyStartStopBtn)
    UpdateButtonAppearance(miniStartStopBtn)
end

local miniShowUiBtn = nil

local function CreateMiniStartStopButton()
    if miniStartStopBtn then
        return
    end

    local btn = CreateFrame("Button", "EasyEchoMiniStartStop", UIParent, "UIPanelButtonTemplate")
    btn:SetSize(62, 20)
    btn:SetPoint("TOP", UIParent, "TOP", -35, -2)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", btn.StartMoving)
    btn:SetScript("OnDragStop", btn.StopMovingOrSizing)
    btn:SetScript("OnClick", function()
        EasyEcho_ToggleRunning()
    end)

    miniStartStopBtn = btn
    UpdateButtonAppearance(btn)

    local showBtn = CreateFrame("Button", "EasyEchoMiniShowUI", UIParent, "UIPanelButtonTemplate")
    showBtn:SetSize(62, 20)
    showBtn:SetPoint("LEFT", btn, "RIGHT", 4, 0)
    showBtn:SetText("Show UI")
    showBtn:SetScript("OnClick", function()
        if EasyEcho_UI and EasyEcho_UI.ShowMainWindow then
            EasyEcho_UI.ShowMainWindow()
        elseif EasyEcho_UI and EasyEcho_UI.Toggle then
            EasyEcho_UI.Toggle()
        end
    end)
    miniShowUiBtn = showBtn
end


local QUALITY_NAMES = {
    [0] = "Common",
    [1] = "Uncommon",
    [2] = "Rare",
    [3] = "Epic",
    [4] = "Legendary"
}

local QUALITY_COLORS = {
    [0] = "ffffffff",
    [1] = "ff1eff00",
    [2] = "ff0070dd",
    [3] = "ffa335ee",
    [4] = "ffff8000"
}

-- =========================================================
-- ECHO DATABASE - Persistent catalog of all discovered echoes
-- =========================================================
local scanTooltip = CreateFrame("GameTooltip", "EasyEchoScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function GetSpellTooltipText(spellId)
    if not spellId then return "" end
    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink("spell:" .. spellId)
    local lines = {}
    for i = 2, scanTooltip:NumLines() do
        local line = _G["EasyEchoScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text ~= "" then
                table.insert(lines, text)
            end
        end
    end
    return table.concat(lines, "\n")
end

function EasyEcho_RecordEcho(spellId, quality)
    if not spellId then return end
    if not EasyEchoEchoDB then EasyEchoEchoDB = {} end

    local name, _, icon = GetSpellInfo(spellId)
    if not name or name == "" then return end

    local key = string.lower(name)
    local qualityName = QUALITY_NAMES[quality] or "Common"
    local _, playerClass = UnitClass("player")

    if not EasyEchoEchoDB[key] then
        -- New echo discovered
        local tooltip = GetSpellTooltipText(spellId)
        EasyEchoEchoDB[key] = {
            name = name,
            spellId = spellId,
            icon = icon or "",
            tooltip = tooltip,
            tooltips = { [qualityName] = tooltip },
            classes = {},
            qualities = {},
            firstSeen = time(),
            lastSeen = time()
        }
    end

    -- Migrate old single-class field to classes table
    local entry = EasyEchoEchoDB[key]
    if entry.class and not entry.classes then
        entry.classes = {}
    end
    if entry.class then
        if entry.class ~= "UNKNOWN" and entry.class ~= "" then
            entry.classes[entry.class] = true
        end
        entry.class = nil
    end

    -- Record this class
    if playerClass and playerClass ~= "UNKNOWN" and playerClass ~= "" then
        if not entry.classes then entry.classes = {} end
        entry.classes[playerClass] = true
    end

    -- Record this quality if not yet seen
    if not EasyEchoEchoDB[key].qualities[qualityName] then
        EasyEchoEchoDB[key].qualities[qualityName] = true
    end
    EasyEchoEchoDB[key].lastSeen = time()

    -- Backfill spellId and icon for older entries
    if not EasyEchoEchoDB[key].spellId then
        EasyEchoEchoDB[key].spellId = spellId
    end
    if not EasyEchoEchoDB[key].icon or EasyEchoEchoDB[key].icon == "" then
        EasyEchoEchoDB[key].icon = icon or ""
    end

    -- Ensure tooltips table exists (migration from old format)
    if not EasyEchoEchoDB[key].tooltips then
        EasyEchoEchoDB[key].tooltips = {}
    end

    -- Store/update tooltip for this specific quality tier
    if not EasyEchoEchoDB[key].tooltips[qualityName] or EasyEchoEchoDB[key].tooltips[qualityName] == "" then
        local qualityTooltip = GetSpellTooltipText(spellId)
        if qualityTooltip and qualityTooltip ~= "" then
            EasyEchoEchoDB[key].tooltips[qualityName] = qualityTooltip
        end
    end

    -- Keep legacy tooltip field updated as fallback
    if not EasyEchoEchoDB[key].tooltip or EasyEchoEchoDB[key].tooltip == "" then
        EasyEchoEchoDB[key].tooltip = GetSpellTooltipText(spellId)
    end
end

local function GetTrackedSpellNames()
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if not EasyEchoSettings.TrackedSpellOne or EasyEchoSettings.TrackedSpellOne == "" then
        EasyEchoSettings.TrackedSpellOne = "Rend the Weak"
    end
    if not EasyEchoSettings.TrackedSpellTwo or EasyEchoSettings.TrackedSpellTwo == "" then
        EasyEchoSettings.TrackedSpellTwo = "Double Strike"
    end
    return EasyEchoSettings.TrackedSpellOne, EasyEchoSettings.TrackedSpellTwo
end

local TRACK_QUALITY_ANY = -1

local function GetTrackedSpellQualityOne()
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if EasyEchoSettings.TrackedSpellQualityOne == nil then
        -- migrate from old shared setting
        if EasyEchoSettings.TrackedSpellQuality ~= nil then
            EasyEchoSettings.TrackedSpellQualityOne = EasyEchoSettings.TrackedSpellQuality
        else
            EasyEchoSettings.TrackedSpellQualityOne = 2 -- default: Rare
        end
    end
    return EasyEchoSettings.TrackedSpellQualityOne
end

local function GetTrackedSpellQualityTwo()
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if EasyEchoSettings.TrackedSpellQualityTwo == nil then
        if EasyEchoSettings.TrackedSpellQuality ~= nil then
            EasyEchoSettings.TrackedSpellQualityTwo = EasyEchoSettings.TrackedSpellQuality
        else
            EasyEchoSettings.TrackedSpellQualityTwo = 2 -- default: Rare
        end
    end
    return EasyEchoSettings.TrackedSpellQualityTwo
end

local function SaveTrackedSpellQualityOne(q)
    if not EasyEchoSettings then EasyEchoSettings = {} end
    EasyEchoSettings.TrackedSpellQualityOne = q
end

local function SaveTrackedSpellQualityTwo(q)
    if not EasyEchoSettings then EasyEchoSettings = {} end
    EasyEchoSettings.TrackedSpellQualityTwo = q
end


local function SaveTrackedSpellNames(spellOne, spellTwo)
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if spellOne and spellOne ~= "" then EasyEchoSettings.TrackedSpellOne = spellOne end
    if spellTwo and spellTwo ~= "" then EasyEchoSettings.TrackedSpellTwo = spellTwo end
end

local function GetPrioRank(name, quality)
    if not name or not EasyEchoSettings or not EasyEchoSettings.PriorityList then return 99999 end
    local specKey = string.lower(name .. "::" .. (QUALITY_NAMES[quality] or "Common"))
    local anyKey = string.lower(name .. "::Any")

    for i, listKey in ipairs(EasyEchoSettings.PriorityList) do
        local low = string.lower(listKey)
        if low == specKey or low == anyKey then
            return i
        end
    end

    return 99999
end

-- Returns one entry per quality tier per echo (flat list)
local function GetEchoDBSorted()
    if not EasyEchoEchoDB then return {} end

    local entries = {}
    local searchLower = string.lower(echoesSearchText or "")
    local qualityOrder = { 4, 3, 2, 1, 0 }

    for key, data in pairs(EasyEchoEchoDB) do
        if type(data) == "table" and data.name then
            -- Search across all quality-specific tooltips and legacy tooltip
            local tooltipMatch = false
            if searchLower ~= "" then
                if data.tooltips then
                    for _, tt in pairs(data.tooltips) do
                        if tt and string.lower(tt):find(searchLower, 1, true) then
                            tooltipMatch = true
                            break
                        end
                    end
                end
                if not tooltipMatch and data.tooltip then
                    tooltipMatch = string.lower(data.tooltip):find(searchLower, 1, true) ~= nil
                end
            end
            local match = (searchLower == "" or string.lower(data.name):find(searchLower, 1, true) or tooltipMatch)

            -- Build classes set (handle migration from old single class field)
            local classesSet = data.classes or {}
            if data.class and not data.classes then
                classesSet = {}
                if data.class ~= "UNKNOWN" and data.class ~= "" then
                    classesSet[data.class] = true
                end
            end

            -- Apply class filter
            local classMatch = true
            if echoesClassFilter and echoesClassFilter ~= "All" then
                classMatch = classesSet[echoesClassFilter] == true
            end

            if match and classMatch and data.qualities then
                -- Build display string for all classes
                local classNames = {}
                for cls in pairs(classesSet) do
                    table.insert(classNames, cls:sub(1, 1) .. cls:sub(2):lower())
                end
                table.sort(classNames)
                local classDisplay
                if #classNames > 1 then
                    classDisplay = "Mehrere"
                elseif #classNames == 1 then
                    classDisplay = classNames[1]
                else
                    classDisplay = ""
                end

                for _, qIdx in ipairs(qualityOrder) do
                    local qName = QUALITY_NAMES[qIdx]
                    if qName and data.qualities[qName] then
                        -- Use quality-specific tooltip, fall back to legacy tooltip
                        local entryTooltip = (data.tooltips and data.tooltips[qName]) or data.tooltip or ""
                        table.insert(entries, {
                            key = key,
                            name = data.name,
                            icon = data.icon or "",
                            spellId = data.spellId,
                            tooltip = entryTooltip,
                            classes = classesSet,
                            classDisplay = classDisplay,
                            quality = qIdx,
                            firstSeen = data.firstSeen or 0,
                            lastSeen = data.lastSeen or 0,
                            prioRank = GetPrioRank(data.name, qIdx)
                        })
                    end
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        if echoesSortMode == "name" then
            if string.lower(a.name) ~= string.lower(b.name) then
                return string.lower(a.name) < string.lower(b.name)
            end
            return a.quality > b.quality
        elseif echoesSortMode == "lastseen" then
            if a.lastSeen ~= b.lastSeen then
                return a.lastSeen > b.lastSeen
            end
            if string.lower(a.name) ~= string.lower(b.name) then
                return string.lower(a.name) < string.lower(b.name)
            end
            return a.quality > b.quality
        elseif echoesSortMode == "prio" then
            if a.prioRank ~= b.prioRank then
                return a.prioRank < b.prioRank
            end
            if a.quality ~= b.quality then
                return a.quality > b.quality
            end
            return string.lower(a.name) < string.lower(b.name)
        else -- rarity (default)
            if a.quality ~= b.quality then
                return a.quality > b.quality
            end
            return string.lower(a.name) < string.lower(b.name)
        end
    end)

    return entries
end

-- Returns granted/locked perks for the current run, enriched with DB data
local function GetGrantedEchoesSorted()
    local granted = nil
    local locked = nil

    if ProjectEbonhold and ProjectEbonhold.PerkService then
        if ProjectEbonhold.PerkService.GetGrantedPerks then
            granted = ProjectEbonhold.PerkService.GetGrantedPerks()
        end
        if ProjectEbonhold.PerkService.GetLockedPerks then
            locked = ProjectEbonhold.PerkService.GetLockedPerks()
        end
    end

    if not granted and ProjectEbonhold and ProjectEbonhold.Perks and ProjectEbonhold.Perks.grantedPerks then
        granted = ProjectEbonhold.Perks.grantedPerks
    end
    if not locked and ProjectEbonhold and ProjectEbonhold.Perks and ProjectEbonhold.Perks.lockedPerks then
        locked = ProjectEbonhold.Perks.lockedPerks
    end

    if type(granted) ~= "table" and type(locked) ~= "table" then
        return {}
    end

    local grouped = {}
    local groupedOrder = {}

    local function AddPerk(perk)
        if type(perk) ~= "table" then return end
        local spellId = perk.spellId
        if not spellId then return end

        local name = GetSpellInfo(spellId) or ("Spell " .. tostring(spellId or "?"))
        local quality = perk.quality or 0
        local key = string.lower(name) .. "::" .. tostring(quality)

        if not grouped[key] then
            -- Look up icon and tooltip from EchoDB
            local dbKey = string.lower(name)
            local dbEntry = EasyEchoEchoDB and EasyEchoEchoDB[dbKey]
            local icon = ""
            local tooltip = ""
            if dbEntry then
                icon = dbEntry.icon or ""
                -- Use quality-specific tooltip, fall back to legacy tooltip
                local qualName = QUALITY_NAMES[quality] or "Common"
                tooltip = (dbEntry.tooltips and dbEntry.tooltips[qualName]) or dbEntry.tooltip or ""
            end
            if icon == "" then
                local _, _, spellIcon = GetSpellInfo(spellId)
                icon = spellIcon or ""
            end

            grouped[key] = {
                name = name,
                spellId = spellId,
                quality = quality,
                icon = icon,
                tooltip = tooltip,
                count = 0,
                prioRank = GetPrioRank(name, quality)
            }
            table.insert(groupedOrder, grouped[key])
        end

        local amount = tonumber(perk.stack) or 1
        if amount < 1 then amount = 1 end
        grouped[key].count = grouped[key].count + amount
    end

    local function AddFromContainer(container)
        if type(container) ~= "table" then return end
        if container[1] then
            for _, perk in ipairs(container) do
                AddPerk(perk)
            end
        else
            for _, perkList in pairs(container) do
                if type(perkList) == "table" then
                    for _, perk in ipairs(perkList) do
                        AddPerk(perk)
                    end
                end
            end
        end
    end

    AddFromContainer(granted)
    AddFromContainer(locked)

    local filtered = {}
    local searchLower = string.lower(grantedSearchText or "")
    for _, entry in ipairs(groupedOrder) do
        if searchLower == "" or string.lower(entry.name):find(searchLower, 1, true)
            or (entry.tooltip and entry.tooltip ~= "" and string.lower(entry.tooltip):find(searchLower, 1, true)) then
            table.insert(filtered, entry)
        end
    end

    table.sort(filtered, function(a, b)
        if grantedSortMode == "name" then
            if string.lower(a.name) ~= string.lower(b.name) then
                return string.lower(a.name) < string.lower(b.name)
            end
            return a.quality > b.quality
        elseif grantedSortMode == "count" then
            if a.count ~= b.count then return a.count > b.count end
            if a.quality ~= b.quality then return a.quality > b.quality end
            return string.lower(a.name) < string.lower(b.name)
        elseif grantedSortMode == "prio" then
            if a.prioRank ~= b.prioRank then return a.prioRank < b.prioRank end
            if a.quality ~= b.quality then return a.quality > b.quality end
            return string.lower(a.name) < string.lower(b.name)
        else -- rarity
            if a.quality ~= b.quality then return a.quality > b.quality end
            return string.lower(a.name) < string.lower(b.name)
        end
    end)

    return filtered
end

-- Shared row creation for both DB and granted views
local ROW_HEIGHT = 26
local ROW_ICON_SIZE = 22

-- History row dimensions
local HIST_ROW_HEIGHT = 20
local HIST_ICON_SIZE = 16

local function CreateRowFrame(parent, pool, index)
    if pool[index] then return pool[index] end

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)

    -- Icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ROW_ICON_SIZE, ROW_ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon = icon

    -- Name label
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    nameText:SetWidth(200)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    -- Quality / info column
    local qualText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qualText:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    qualText:SetWidth(80)
    qualText:SetJustifyH("LEFT")
    row.qualText = qualText

    -- Extra column (class in DB, count in granted)
    local extraText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    extraText:SetPoint("LEFT", qualText, "RIGHT", 4, 0)
    extraText:SetWidth(70)
    extraText:SetJustifyH("LEFT")
    extraText:SetTextColor(0.6, 0.6, 0.6)
    row.extraText = extraText

    -- Highlight texture
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)

    -- Tooltip (set per-row via echoData)
    row:SetScript("OnEnter", function(self)
        if not self.echoData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        local data = self.echoData
        local q = data.quality or 0
        local qColor = QUALITY_COLORS[q] or "ffffffff"
        local qName = QUALITY_NAMES[q] or "Common"
        GameTooltip:AddLine("|c" .. qColor .. data.name .. "|r")
        GameTooltip:AddLine(qName, 0.5, 0.5, 0.5)

        if data.count and data.count > 1 then
            GameTooltip:AddLine("Stacks: " .. data.count, 1, 1, 1)
        end

        -- Classes
        if data.classes then
            local names = {}
            for cls in pairs(data.classes) do
                table.insert(names, cls:sub(1, 1) .. cls:sub(2):lower())
            end
            table.sort(names)
            if #names > 0 then
                GameTooltip:AddLine("Discovered as: " .. table.concat(names, ", "), 0.5, 0.5, 0.5)
            end
        elseif data.classDisplay and data.classDisplay ~= "" then
            GameTooltip:AddLine("Discovered as: " .. data.classDisplay, 0.5, 0.5, 0.5)
        end

        -- Timestamps
        if data.firstSeen and data.firstSeen > 0 then
            GameTooltip:AddLine("First seen: " .. date("%m/%d/%y %H:%M", data.firstSeen), 0.5, 0.5, 0.5)
        end
        if data.lastSeen and data.lastSeen > 0 then
            GameTooltip:AddLine("Last seen: " .. date("%m/%d/%y %H:%M", data.lastSeen), 0.5, 0.5, 0.5)
        end

        -- Spell description
        GameTooltip:AddLine(" ")
        local desc = data.tooltip or ""
        if desc == "" and data.spellId then
            desc = GetSpellTooltipText(data.spellId)
        end
        if desc and desc ~= "" then
            GameTooltip:AddLine(desc, 1, 0.82, 0, true)
        else
            GameTooltip:AddLine("No description available.", 0.5, 0.5, 0.5)
        end

        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Right-click context menu for adding to prio/ban
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" or not self.echoData then return end
        local data = self.echoData
        local qName = QUALITY_NAMES[data.quality] or "Common"

        -- Create or reuse dropdown menu
        if not EasyEcho_UI._contextMenu then
            EasyEcho_UI._contextMenu = CreateFrame("Frame", "EasyEchoDBContextMenu", UIParent, "UIDropDownMenuTemplate")
        end

        UIDropDownMenu_Initialize(EasyEcho_UI._contextMenu, function(self, level)
            -- Add to Priority List
            local info1 = UIDropDownMenu_CreateInfo()
            info1.text = "Add to Priority List (" .. qName .. ")"
            info1.notCheckable = true
            info1.func = function()
                if EasyEchoSettings and EasyEchoSettings.PriorityList then
                    local newEntry = data.name .. "::" .. qName
                    table.insert(EasyEchoSettings.PriorityList, newEntry)
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Added '" .. newEntry .. "' to Priority List.")
                    end
                end
            end
            UIDropDownMenu_AddButton(info1, level)

            -- Add to Priority List (Any)
            local info1a = UIDropDownMenu_CreateInfo()
            info1a.text = "Add to Priority List (Any)"
            info1a.notCheckable = true
            info1a.func = function()
                if EasyEchoSettings and EasyEchoSettings.PriorityList then
                    local newEntry = data.name .. "::Any"
                    table.insert(EasyEchoSettings.PriorityList, newEntry)
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Added '" .. newEntry .. "' to Priority List.")
                    end
                end
            end
            UIDropDownMenu_AddButton(info1a, level)

            -- Add to Ban List
            local info2 = UIDropDownMenu_CreateInfo()
            info2.text = "Add to Ban List"
            info2.notCheckable = true
            info2.func = function()
                if EasyEchoSettings and EasyEchoSettings.BanList then
                    -- Check for duplicates
                    local already = false
                    for _, b in ipairs(EasyEchoSettings.BanList) do
                        if string.lower(b) == string.lower(data.name) then already = true; break end
                    end
                    if not already then
                        table.insert(EasyEchoSettings.BanList, data.name)
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Added '" .. data.name .. "' to Ban List.")
                        end
                    else
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[EasyEcho]|r '" .. data.name .. "' is already on the Ban List.")
                        end
                    end
                end
            end
            UIDropDownMenu_AddButton(info2, level)

            -- Cancel
            local info3 = UIDropDownMenu_CreateInfo()
            info3.text = "Cancel"
            info3.notCheckable = true
            info3.func = function() end
            UIDropDownMenu_AddButton(info3, level)
        end, "MENU")

        ToggleDropDownMenu(1, nil, EasyEcho_UI._contextMenu, "cursor", 0, 0)
    end)

    pool[index] = row
    return row
end

local function CreateEchoesFrame()
    if echoesFrame then return end

    local FRAME_W = 560
    local FRAME_H = 520

    local f = CreateFrame("Frame", "EasyEchoEchoDBFrame", UIParent)
    f:SetWidth(FRAME_W)
    f:SetHeight(FRAME_H)
    f:SetPoint("CENTER", 120, 20)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("Echo Database")

    -- Discovered count label
    echoesCountLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    echoesCountLabel:SetPoint("TOPLEFT", 18, -35)
    echoesCountLabel:SetTextColor(0.7, 0.7, 0.7)
    echoesCountLabel:SetText("")

    -- Search
    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("TOPLEFT", 18, -52)
    searchLabel:SetText("Search")

    local searchBox = CreateFrame("EditBox", "EasyEchoEchoesSearchBox", f, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        echoesSearchText = self:GetText() or ""
        EasyEcho_UI.UpdateEchoListUI()
    end)

    -- Sort dropdown
    local sortLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sortLabel:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    sortLabel:SetText("Sort")

    local sortDrop = CreateFrame("Frame", "EasyEchoEchoesSortDropDown", f, "UIDropDownMenuTemplate")
    sortDrop:SetPoint("LEFT", sortLabel, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(sortDrop, 110)
    UIDropDownMenu_Initialize(sortDrop, function(self, level)
        local options = {
            { text = "Rarity", value = "rarity" },
            { text = "Name", value = "name" },
            { text = "Last Seen", value = "lastseen" },
            { text = "Prio List", value = "prio" }
        }

        for _, option in ipairs(options) do
            UIDropDownMenu_AddButton({
                text = option.text,
                value = option.value,
                func = function(btn)
                    echoesSortMode = btn.value
                    UIDropDownMenu_SetText(sortDrop, option.text)
                    EasyEcho_UI.UpdateEchoListUI()
                end
            }, level)
        end
    end)
    UIDropDownMenu_SetText(sortDrop, "Rarity")
    echoesSortDropDown = sortDrop

    -- Class filter dropdown
    local classLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classLabel:SetPoint("LEFT", sortDrop, "RIGHT", 0, 2)
    classLabel:SetText("Class")

    local classDrop = CreateFrame("Frame", "EasyEchoEchoesClassDropDown", f, "UIDropDownMenuTemplate")
    classDrop:SetPoint("LEFT", classLabel, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(classDrop, 90)
    UIDropDownMenu_Initialize(classDrop, function(self, level)
        local classOptions = {
            "All", "Warrior", "Paladin", "Hunter", "Rogue", "Priest",
            "Death Knight", "Shaman", "Mage", "Warlock", "Druid"
        }
        for _, cls in ipairs(classOptions) do
            UIDropDownMenu_AddButton({
                text = cls,
                value = cls,
                func = function(btn)
                    if btn.value == "All" then
                        echoesClassFilter = "All"
                    else
                        -- Convert display name back to uppercase key
                        echoesClassFilter = string.upper(btn.value):gsub(" ", "")
                        if btn.value == "Death Knight" then echoesClassFilter = "DEATHKNIGHT" end
                    end
                    UIDropDownMenu_SetText(classDrop, cls)
                    EasyEcho_UI.UpdateEchoListUI()
                end
            }, level)
        end
    end)
    UIDropDownMenu_SetText(classDrop, "All")

    -- Column headers
    local headerY = -75
    local hdrIcon = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrIcon:SetPoint("TOPLEFT", 18, headerY)
    hdrIcon:SetWidth(ROW_ICON_SIZE + 6)
    hdrIcon:SetText("")

    local hdrName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrName:SetPoint("TOPLEFT", 18 + ROW_ICON_SIZE + 6, headerY)
    hdrName:SetWidth(200)
    hdrName:SetJustifyH("LEFT")
    hdrName:SetText("|cffbbbbbbName|r")

    local hdrQual = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrQual:SetPoint("LEFT", hdrName, "RIGHT", 4, 0)
    hdrQual:SetWidth(80)
    hdrQual:SetJustifyH("LEFT")
    hdrQual:SetText("|cffbbbbbbQuality|r")

    local hdrClass = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrClass:SetPoint("LEFT", hdrQual, "RIGHT", 4, 0)
    hdrClass:SetWidth(70)
    hdrClass:SetJustifyH("LEFT")
    hdrClass:SetText("|cffbbbbbbClass|r")

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame", "EasyEchoEchoesScrollFrame", f)
    sf:SetPoint("TOPLEFT", 15, headerY - 14)
    sf:SetPoint("BOTTOMRIGHT", -35, 20)

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(FRAME_W - 60)
    content:SetHeight(1)
    sf:SetScrollChild(content)
    echoesContent = content

    -- Scrollbar
    local sb = CreateFrame("Slider", "EasyEchoEchoesScrollBar", f, "UIPanelScrollBarTemplate")
    sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, -16)
    sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 16)
    sb:SetMinMaxValues(0, 0)
    sb:SetValueStep(1)
    sb:SetScript("OnValueChanged", function(self, value) sf:SetVerticalScroll(value) end)
    echoesScrollBar = sb

    -- Mouse wheel scrolling
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = sb:GetValue()
        local step = ROW_HEIGHT * 3
        sb:SetValue(cur - (delta * step))
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Back button
    local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    backBtn:SetSize(70, 20)
    backBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    backBtn:SetText("Back")
    backBtn:SetScript("OnClick", function()
        EasyEcho_UI.ShowMainWindow()
    end)

    f:Hide()
    echoesFrame = f
end

-- =========================================================
-- GRANTED ECHOES - Active run's echoes with DB-enriched data
-- =========================================================
local function CreateGrantedFrame()
    if grantedFrame then return end

    local FRAME_W = 560
    local FRAME_H = 480

    local f = CreateFrame("Frame", "EasyEchoGrantedEchoesFrame", UIParent)
    f:SetWidth(FRAME_W)
    f:SetHeight(FRAME_H)
    f:SetPoint("CENTER", 120, 20)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("Granted Echoes")

    -- Search
    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("TOPLEFT", 18, -40)
    searchLabel:SetText("Search")

    local searchBox = CreateFrame("EditBox", "EasyEchoGrantedSearchBox", f, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        grantedSearchText = self:GetText() or ""
        EasyEcho_UI.UpdateGrantedUI()
    end)

    -- Sort dropdown
    local sortLabel2 = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sortLabel2:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    sortLabel2:SetText("Sort")

    local sortDrop = CreateFrame("Frame", "EasyEchoGrantedSortDropDown", f, "UIDropDownMenuTemplate")
    sortDrop:SetPoint("LEFT", sortLabel2, "RIGHT", -12, -2)
    UIDropDownMenu_SetWidth(sortDrop, 110)
    UIDropDownMenu_Initialize(sortDrop, function(self, level)
        local options = {
            { text = "Rarity", value = "rarity" },
            { text = "Name", value = "name" },
            { text = "Count", value = "count" },
            { text = "Prio List", value = "prio" }
        }
        for _, option in ipairs(options) do
            UIDropDownMenu_AddButton({
                text = option.text,
                value = option.value,
                func = function(btn)
                    grantedSortMode = btn.value
                    UIDropDownMenu_SetText(sortDrop, option.text)
                    EasyEcho_UI.UpdateGrantedUI()
                end
            }, level)
        end
    end)
    UIDropDownMenu_SetText(sortDrop, "Rarity")
    grantedSortDropDown = sortDrop

    -- Column headers
    local headerY = -63
    local hdrIcon = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrIcon:SetPoint("TOPLEFT", 18, headerY)
    hdrIcon:SetWidth(ROW_ICON_SIZE + 6)
    hdrIcon:SetText("")

    local hdrName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrName:SetPoint("TOPLEFT", 18 + ROW_ICON_SIZE + 6, headerY)
    hdrName:SetWidth(200)
    hdrName:SetJustifyH("LEFT")
    hdrName:SetText("|cffbbbbbbName|r")

    local hdrQual = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrQual:SetPoint("LEFT", hdrName, "RIGHT", 4, 0)
    hdrQual:SetWidth(80)
    hdrQual:SetJustifyH("LEFT")
    hdrQual:SetText("|cffbbbbbbQuality|r")

    local hdrCount = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hdrCount:SetPoint("LEFT", hdrQual, "RIGHT", 4, 0)
    hdrCount:SetWidth(70)
    hdrCount:SetJustifyH("LEFT")
    hdrCount:SetText("|cffbbbbbbCount|r")

    -- Scroll frame
    local sf = CreateFrame("ScrollFrame", "EasyEchoGrantedScrollFrame", f)
    sf:SetPoint("TOPLEFT", 15, headerY - 14)
    sf:SetPoint("BOTTOMRIGHT", -35, 20)

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(FRAME_W - 60)
    content:SetHeight(1)
    sf:SetScrollChild(content)
    grantedContent = content

    -- Scrollbar
    local sb = CreateFrame("Slider", "EasyEchoGrantedScrollBar", f, "UIPanelScrollBarTemplate")
    sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, -16)
    sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 16)
    sb:SetMinMaxValues(0, 0)
    sb:SetValueStep(1)
    sb:SetScript("OnValueChanged", function(self, value) sf:SetVerticalScroll(value) end)
    grantedScrollBar = sb

    -- Mouse wheel
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = sb:GetValue()
        local step = ROW_HEIGHT * 3
        sb:SetValue(cur - (delta * step))
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Back button
    local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    backBtn:SetSize(70, 20)
    backBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    backBtn:SetText("Back")
    backBtn:SetScript("OnClick", function()
        EasyEcho_UI.ShowMainWindow()
    end)

    -- Auto-refresh timer while frame is visible
    f.refreshTimer = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        self.refreshTimer = (self.refreshTimer or 0) + elapsed
        if self.refreshTimer >= 2.0 then
            self.refreshTimer = 0
            EasyEcho_UI.UpdateGrantedUI()
        end
    end)

    f:Hide()
    grantedFrame = f
end

function EasyEcho_UI.UpdateGrantedUI()
    if not grantedFrame then CreateGrantedFrame() end

    -- Ingest granted/locked perks into EchoDB
    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.RequestGrantedPerks then
        ProjectEbonhold.PerkService.RequestGrantedPerks()
    end

    local function RecordPerks(container)
        if type(container) ~= "table" then return end
        if container[1] then
            for _, perk in ipairs(container) do
                if type(perk) == "table" and perk.spellId then
                    EasyEcho_RecordEcho(perk.spellId, perk.quality or 0)
                end
            end
        else
            for _, perkList in pairs(container) do
                if type(perkList) == "table" then
                    for _, perk in ipairs(perkList) do
                        if type(perk) == "table" and perk.spellId then
                            EasyEcho_RecordEcho(perk.spellId, perk.quality or 0)
                        end
                    end
                end
            end
        end
    end

    if ProjectEbonhold and ProjectEbonhold.PerkService then
        if ProjectEbonhold.PerkService.GetGrantedPerks then RecordPerks(ProjectEbonhold.PerkService.GetGrantedPerks()) end
        if ProjectEbonhold.PerkService.GetLockedPerks then RecordPerks(ProjectEbonhold.PerkService.GetLockedPerks()) end
    end
    if ProjectEbonhold and ProjectEbonhold.Perks then
        if ProjectEbonhold.Perks.grantedPerks then RecordPerks(ProjectEbonhold.Perks.grantedPerks) end
        if ProjectEbonhold.Perks.lockedPerks then RecordPerks(ProjectEbonhold.Perks.lockedPerks) end
    end

    -- Hide all rows
    for _, row in ipairs(grantedRowPool) do row:Hide() end

    local entries = GetGrantedEchoesSorted()
    local contentWidth = grantedContent:GetWidth()
    local yOffset = 0

    if #entries == 0 then
        local row = CreateRowFrame(grantedContent, grantedRowPool, 1)
        row:SetPoint("TOPLEFT", 0, 0)
        row:SetWidth(contentWidth)
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.nameText:SetText("|cff888888No echoes granted yet.|r")
        row.qualText:SetText("")
        row.extraText:SetText("")
        row.echoData = nil
        row:Show()
        yOffset = ROW_HEIGHT
    else
        for i, entry in ipairs(entries) do
            local row = CreateRowFrame(grantedContent, grantedRowPool, i)
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetWidth(contentWidth)

            -- Icon from DB or live
            if entry.icon and entry.icon ~= "" then
                row.icon:SetTexture(entry.icon)
            elseif entry.spellId then
                local _, _, spellIcon = GetSpellInfo(entry.spellId)
                row.icon:SetTexture(spellIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            -- Name colored by quality
            local qColor = QUALITY_COLORS[entry.quality] or "ffffffff"
            row.nameText:SetText("|c" .. qColor .. entry.name .. "|r")

            -- Quality name
            local qName = QUALITY_NAMES[entry.quality] or "Common"
            row.qualText:SetText("|c" .. qColor .. qName .. "|r")

            -- Count
            local countStr = tostring(entry.count or 1)
            if (entry.count or 1) > 1 then
                countStr = "|cffbbbbbbx" .. countStr .. "|r"
            else
                countStr = "|cff888888x1|r"
            end
            row.extraText:SetText(countStr)

            -- Store data for tooltip
            row.echoData = entry

            row:Show()
            yOffset = yOffset + ROW_HEIGHT
        end
    end

    grantedContent:SetHeight(yOffset)
    local visibleH = grantedFrame:GetHeight() - 100
    local maxScroll = math.max(0, yOffset - visibleH)
    grantedScrollBar:SetMinMaxValues(0, maxScroll)
    grantedScrollBar:SetValue(0)
end

function EasyEcho_UI.ToggleGrantedEchoes()
    if not grantedFrame then CreateGrantedFrame() end
    if grantedFrame:IsShown() then
        grantedFrame:Hide()
    else
        if historyFrame and historyFrame:IsShown() then historyFrame:Hide() end
        if echoesFrame and echoesFrame:IsShown() then echoesFrame:Hide() end
        local config = _G["EasyEchoConfigFrame"]
        if config and config:IsShown() then config:Hide() end
        grantedFrame:Show()
        EasyEcho_UI.UpdateGrantedUI()
    end
end

-- =========================================================
-- History row frame: icon + text + tooltip + right-click menu
-- =========================================================
local function CreateHistoryRowFrame(parent, pool, index)
    if pool[index] then return pool[index] end

    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(HIST_ROW_HEIGHT)
    row:EnableMouse(true)

    -- Icon (shown only for SELECT entries)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(HIST_ICON_SIZE, HIST_ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon = icon

    -- Main text
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    row.text = text

    -- Highlight texture
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)
    row.highlight = highlight

    -- Tooltip (only for entries with echoData)
    row:SetScript("OnEnter", function(self)
        if not self.echoData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        local data = self.echoData
        local q = data.quality or 0
        local qColor = QUALITY_COLORS[q] or "ffffffff"
        local qName = QUALITY_NAMES[q] or "Common"
        GameTooltip:AddLine("|c" .. qColor .. data.name .. "|r")
        GameTooltip:AddLine(qName, 0.5, 0.5, 0.5)

        if data.isPrio then
            GameTooltip:AddLine("Priority Pick", 0, 1, 0)
        end

        -- Look up extended info from EchoDB
        local dbEntry = EasyEchoEchoDB and EasyEchoEchoDB[string.lower(data.name or "")]
        if dbEntry then
            if dbEntry.classes then
                local names = {}
                for cls in pairs(dbEntry.classes) do
                    table.insert(names, cls:sub(1, 1) .. cls:sub(2):lower())
                end
                table.sort(names)
                if #names > 0 then
                    GameTooltip:AddLine("Discovered as: " .. table.concat(names, ", "), 0.5, 0.5, 0.5)
                end
            end

            GameTooltip:AddLine(" ")
            local desc = (dbEntry.tooltips and dbEntry.tooltips[qName]) or dbEntry.tooltip or ""
            if desc == "" and dbEntry.spellId then
                desc = GetSpellTooltipText(dbEntry.spellId)
            end
            if desc and desc ~= "" then
                GameTooltip:AddLine(desc, 1, 0.82, 0, true)
            else
                GameTooltip:AddLine("No description available.", 0.5, 0.5, 0.5)
            end
        end

        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Right-click context menu for adding to prio/ban
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" or not self.echoData then return end
        local data = self.echoData
        local qName = QUALITY_NAMES[data.quality] or "Common"

        if not EasyEcho_UI._contextMenu then
            EasyEcho_UI._contextMenu = CreateFrame("Frame", "EasyEchoDBContextMenu", UIParent, "UIDropDownMenuTemplate")
        end

        UIDropDownMenu_Initialize(EasyEcho_UI._contextMenu, function(self, level)
            -- Add to Priority List (specific quality)
            local info1 = UIDropDownMenu_CreateInfo()
            info1.text = "Add to Priority List (" .. qName .. ")"
            info1.notCheckable = true
            info1.func = function()
                if EasyEchoSettings and EasyEchoSettings.PriorityList then
                    local newEntry = data.name .. "::" .. qName
                    table.insert(EasyEchoSettings.PriorityList, newEntry)
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Added '" .. newEntry .. "' to Priority List.")
                    end
                end
            end
            UIDropDownMenu_AddButton(info1, level)

            -- Add to Priority List (Any)
            local info1a = UIDropDownMenu_CreateInfo()
            info1a.text = "Add to Priority List (Any)"
            info1a.notCheckable = true
            info1a.func = function()
                if EasyEchoSettings and EasyEchoSettings.PriorityList then
                    local newEntry = data.name .. "::Any"
                    table.insert(EasyEchoSettings.PriorityList, newEntry)
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Added '" .. newEntry .. "' to Priority List.")
                    end
                end
            end
            UIDropDownMenu_AddButton(info1a, level)

            -- Add to Ban List
            local info2 = UIDropDownMenu_CreateInfo()
            info2.text = "Add to Ban List"
            info2.notCheckable = true
            info2.func = function()
                if EasyEchoSettings and EasyEchoSettings.BanList then
                    local already = false
                    for _, b in ipairs(EasyEchoSettings.BanList) do
                        if string.lower(b) == string.lower(data.name) then already = true; break end
                    end
                    if not already then
                        table.insert(EasyEchoSettings.BanList, data.name)
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Added '" .. data.name .. "' to Ban List.")
                        end
                    else
                        if DEFAULT_CHAT_FRAME then
                            DEFAULT_CHAT_FRAME:AddMessage("|cffffff00[EasyEcho]|r '" .. data.name .. "' is already on the Ban List.")
                        end
                    end
                end
            end
            UIDropDownMenu_AddButton(info2, level)

            -- Cancel
            local info3 = UIDropDownMenu_CreateInfo()
            info3.text = "Cancel"
            info3.notCheckable = true
            info3.func = function() end
            UIDropDownMenu_AddButton(info3, level)
        end, "MENU")

        ToggleDropDownMenu(1, nil, EasyEcho_UI._contextMenu, "cursor", 0, 0)
    end)

    pool[index] = row
    return row
end

local function CreateHistoryFrame()
    local f = CreateFrame("Frame", "EasyEchoHistoryFrame", UIParent)
    f:SetWidth(800)
    f:SetHeight(700)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -15)
    title:SetText("EasyEcho History & Stats")

    local statsBg = f:CreateTexture(nil, "BACKGROUND")
    statsBg:SetTexture(0, 0, 0, 0.3)
    statsBg:SetPoint("TOPLEFT", 15, -35)
    statsBg:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -15, -110)

    -- =========================================================
    -- HEADER LAYOUT (2 columns) + INLINE EDIT ON LABEL CLICK
    -- =========================================================
    local PAD_X   = 25
    local TOP_Y   = -45
    local ROW_H   = 20
    local COL_GAP = 35

    local innerW = f:GetWidth() - (PAD_X * 2)
    local colW   = (innerW - COL_GAP) / 2
    local leftX  = PAD_X
    local rightX = PAD_X + colW + COL_GAP

    local function CreateStatLabel(parent, x, y, width, template)
        local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        return fs
    end

        -- One shared inline editor (re-used for both labels)
    -- IMPORTANT: In 3.3.5 OnEditFocusLost is unreliable when clicking the world.
    -- We use a fullscreen click-catcher to reliably "click away" and save.
    local clickCatcher = CreateFrame("Button", nil, UIParent)
    clickCatcher:SetAllPoints(UIParent)
    clickCatcher:EnableMouse(true)
    clickCatcher:Hide()
    clickCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
    clickCatcher:SetFrameLevel(49)

    local inlineEdit = CreateFrame("EditBox", nil, UIParent, "InputBoxTemplate")
    inlineEdit:Hide()
    inlineEdit:SetAutoFocus(true)
    inlineEdit:SetHeight(18)
    inlineEdit:SetFrameStrata("FULLSCREEN_DIALOG")
    inlineEdit:SetFrameLevel(50)

    local function CommitInlineEdit(save)
        if not inlineEdit.active then return end
        inlineEdit.active = false

        local which = inlineEdit.which
        local label = inlineEdit.label
        local text  = strtrim(inlineEdit:GetText() or "")

        inlineEdit:Hide()
        inlineEdit:ClearFocus()
        clickCatcher:Hide()

        if label then label:Show() end
        if not save or text == "" then return end

        local a, b = GetTrackedSpellNames()
        if which == 1 then a = text else b = text end

        SaveTrackedSpellNames(a, b)
        EasyEcho_UI.UpdateHistoryUI()
    end

    inlineEdit:SetScript("OnEnterPressed", function() CommitInlineEdit(true) end)
    inlineEdit:SetScript("OnEscapePressed", function() CommitInlineEdit(false) end)
    inlineEdit:SetScript("OnEditFocusLost", function() CommitInlineEdit(true) end)

    clickCatcher:SetScript("OnMouseDown", function()
        -- any click anywhere -> save & close
        CommitInlineEdit(true)
    end)

    local function AttachInlineEditClick(label, which)
        -- Invisible click-catcher over the fontstring
        local btn = CreateFrame("Button", nil, f)
        btn:SetFrameLevel((f:GetFrameLevel() or 1) + 5)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")

        -- Make it at least as big as the label width/height
        btn:SetPoint("TOPLEFT", label, "TOPLEFT", -2, 2)
        btn:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 2, -2)

        btn:SetScript("OnClick", function()
            local a, b = GetTrackedSpellNames()
            local cur = (which == 1) and (a or "") or (b or "")

            inlineEdit:ClearAllPoints()
            inlineEdit:SetWidth(math.min(colW, 260))
            inlineEdit:SetPoint("LEFT", label, "LEFT", -6, 0)

            inlineEdit.which = which
            inlineEdit.label = label
            inlineEdit.active = true

            label:Hide()
            inlineEdit:SetText(cur)
            inlineEdit:Show()
            clickCatcher:Show()
            inlineEdit:SetFocus()
            inlineEdit:HighlightText()
        end)

        return btn
    end


    -- =========================================================
    -- Quality name helper
    -- =========================================================
    local function TrackQName(q)
        if q == TRACK_QUALITY_ANY then return "Any" end
        return QUALITY_NAMES[q] or "Rare"
    end

    -- =========================================================
    -- Helper: create a quality dropdown for a tracked spell
    -- =========================================================
    local function CreateTrackQualityDD(parent, name, anchor, getter, saver)
        local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", anchor, "TOPRIGHT", -18, 6)
        UIDropDownMenu_SetWidth(dd, 100)
        UIDropDownMenu_JustifyText(dd, "LEFT")

        UIDropDownMenu_Initialize(dd, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            local function add(text, val)
                info.text = text
                info.value = val
                info.checked = (getter() == val)
                info.func = function()
                    saver(val)
                    UIDropDownMenu_SetText(dd, TrackQName(val))
                    EasyEcho_UI.UpdateHistoryUI()
                end
                UIDropDownMenu_AddButton(info, level)
            end
            add("Rare", 2)
            add("Epic", 3)
            add("Uncommon", 1)
            add("Common", 0)
            if QUALITY_NAMES[4] then add("Legendary", 4) end
            add("Any", TRACK_QUALITY_ANY)
        end)

        UIDropDownMenu_SetText(dd, TrackQName(getter()))
        return dd
    end

    -- Row 1: tracked spell counters (click name to edit) + per-spell quality dropdown
    local labelW = colW - 140  -- narrower labels to fit dropdown

    statRend = CreateStatLabel(f, leftX, TOP_Y, labelW, "GameFontHighlight")
    statRend:SetText("Rend the Weak: 0")

    trackDDOne = CreateTrackQualityDD(f, "EasyEchoTrackedQualityDD1", statRend,
        GetTrackedSpellQualityOne, SaveTrackedSpellQualityOne)

    statDouble = CreateStatLabel(f, rightX, TOP_Y, labelW, "GameFontHighlight")
    statDouble:SetText("Double Strike: 0")

    trackDDTwo = CreateTrackQualityDD(f, "EasyEchoTrackedQualityDD2", statDouble,
        GetTrackedSpellQualityTwo, SaveTrackedSpellQualityTwo)

    AttachInlineEditClick(statRend, 1)
    AttachInlineEditClick(statDouble, 2)

    -- Row 2: epics (left/right)
    local epicsY = TOP_Y - (ROW_H * 1)

    statEpicsPrio = CreateStatLabel(f, leftX, epicsY, colW, "GameFontHighlight")
    statEpicsPrio:SetTextColor(0.64, 0.21, 0.93)
    statEpicsPrio:SetText("Epics (List): 0")

    statEpicsOther = CreateStatLabel(f, rightX, epicsY, colW, "GameFontHighlight")
    statEpicsOther:SetTextColor(0.8, 0.4, 1.0)
    statEpicsOther:SetText("Epics (Other): 0")

    -- Row 3: rares + rerolls (left/right)
    local miscY = TOP_Y - (ROW_H * 2)

    statRares = CreateStatLabel(f, leftX, miscY, colW, "GameFontHighlight")
    statRares:SetTextColor(0, 0.44, 0.87)
    statRares:SetText("Total Rares: 0")

    statRerollsLeft = CreateStatLabel(f, rightX, miscY, colW, "GameFontHighlight")
    statRerollsLeft:SetTextColor(1, 0.5, 0)
    statRerollsLeft:SetText("Rerolls Left: 10")



    local sf = CreateFrame("ScrollFrame", "EasyEchoScrollFrame", f)
    sf:SetPoint("TOPLEFT", 15, -135) 
    sf:SetPoint("BOTTOMRIGHT", -35, 15)
    
    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(750)
    content:SetHeight(1)
    sf:SetScrollChild(content)
    historyContent, historyScrollFrame = content, sf

    local sb = CreateFrame("Slider", "EasyEchoScrollBar", f, "UIPanelScrollBarTemplate")
    sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, -16)
    sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 16)
    sb:SetMinMaxValues(0, 0)
    sb:SetValueStep(1)
    sb:SetScript("OnValueChanged", function(self, value) sf:SetVerticalScroll(value) end)
    scrollBar = sb

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local startStopBtn = CreateFrame("Button", "EasyEchoHistoryStartStop", f, "UIPanelButtonTemplate")
    startStopBtn:SetSize(80, 22)
    startStopBtn:SetPoint("TOPLEFT", 12, -10)
    startStopBtn:SetScript("OnClick", function()
        EasyEcho_ToggleRunning()
    end)
    historyStartStopBtn = startStopBtn
    UpdateButtonAppearance(startStopBtn)

    local clearBtn = CreateFrame("Button", "EasyEchoClearBtn", f, "UIPanelButtonTemplate")
    clearBtn:SetWidth(80)
    clearBtn:SetHeight(22)
    clearBtn:SetPoint("LEFT", startStopBtn, "RIGHT", 5, 0)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
        EasyEcho_UI.ResetAllData("Everything has been reset.")
    end)
	
	local configBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	configBtn:SetSize(80, 22)
	configBtn:SetPoint("TOPRIGHT", -35, -10)
	configBtn:SetText("Config")
	configBtn:SetScript("OnClick", function()
		if EasyEcho_Config and EasyEcho_Config.Toggle then
			if historyFrame then historyFrame:Hide() end
			if echoesFrame and echoesFrame:IsShown() then echoesFrame:Hide() end
			EasyEcho_Config.Toggle()
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[EasyEcho]|r Error: Config module not loaded!")
		end
	end)

	local echoesBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	echoesBtn:SetSize(80, 22)
	echoesBtn:SetPoint("RIGHT", configBtn, "LEFT", -5, 0)
	echoesBtn:SetText("Echoes")
	echoesBtn:SetScript("OnClick", function()
		EasyEcho_UI.ToggleGrantedEchoes()
	end)

	local dbBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	dbBtn:SetSize(50, 22)
	dbBtn:SetPoint("RIGHT", echoesBtn, "LEFT", -5, 0)
	dbBtn:SetText("DB")
	dbBtn:SetScript("OnClick", function()
		EasyEcho_UI.ToggleEchoList()
	end)
    
    f:Hide()
    historyFrame = f
end

function EasyEcho_UI.UpdateRerollStatus(used, total)
    liveUsedRerolls = used or 0
    liveTotalRerolls = total or 10
    if statRerollsLeft then
        statRerollsLeft:SetText("Rerolls Left: " .. math.max(0, liveTotalRerolls - liveUsedRerolls))
    end
end

local function CalculateStats()
    local cOne, cTwo, cEpicsPrio, cEpicsOther, cRares = 0, 0, 0, 0, 0

    local trackedOne, trackedTwo = GetTrackedSpellNames()
    local tOneLower = string.lower(trackedOne or "")
    local tTwoLower = string.lower(trackedTwo or "")
    local trackQOne = GetTrackedSpellQualityOne()
    local trackQTwo = GetTrackedSpellQualityTwo()

    -- Try authoritative server data first (GetGrantedPerks / GetLockedPerks)
    local granted, locked = nil, nil
    if ProjectEbonhold and ProjectEbonhold.PerkService then
        if ProjectEbonhold.PerkService.GetGrantedPerks then
            granted = ProjectEbonhold.PerkService.GetGrantedPerks()
        end
        if ProjectEbonhold.PerkService.GetLockedPerks then
            locked = ProjectEbonhold.PerkService.GetLockedPerks()
        end
    end
    if not granted and ProjectEbonhold and ProjectEbonhold.Perks and ProjectEbonhold.Perks.grantedPerks then
        granted = ProjectEbonhold.Perks.grantedPerks
    end
    if not locked and ProjectEbonhold and ProjectEbonhold.Perks and ProjectEbonhold.Perks.lockedPerks then
        locked = ProjectEbonhold.Perks.lockedPerks
    end

    local hasAPI = (type(granted) == "table" or type(locked) == "table")

    if hasAPI then
        local function ProcessPerk(perk)
            if type(perk) ~= "table" or not perk.spellId then return end
            local name = GetSpellInfo(perk.spellId)
            if not name then return end
            local quality = perk.quality or 0
            local amount = tonumber(perk.stack) or 1
            if amount < 1 then amount = 1 end

            if quality == 3 then
                local isPrio = GetPrioRank(name, quality) < 99999
                if isPrio then cEpicsPrio = cEpicsPrio + amount else cEpicsOther = cEpicsOther + amount end
            end
            if quality == 2 then cRares = cRares + amount end

            local nLower = string.lower(name)
            if tOneLower ~= "" and nLower:find(tOneLower, 1, true) then
                if trackQOne == TRACK_QUALITY_ANY or quality == trackQOne then
                    cOne = cOne + amount
                end
            end
            if tTwoLower ~= "" and nLower:find(tTwoLower, 1, true) then
                if trackQTwo == TRACK_QUALITY_ANY or quality == trackQTwo then
                    cTwo = cTwo + amount
                end
            end
        end

        local function ProcessContainer(container)
            if type(container) ~= "table" then return end
            if container[1] then
                for _, perk in ipairs(container) do ProcessPerk(perk) end
            else
                for _, perkList in pairs(container) do
                    if type(perkList) == "table" then
                        for _, perk in ipairs(perkList) do ProcessPerk(perk) end
                    end
                end
            end
        end

        ProcessContainer(granted)
        ProcessContainer(locked)
    else
        -- Fallback: count from history log when API is unavailable
        if not EasyEchoHistoryDB then return 0,0,0,0,0 end

        for _, entry in ipairs(EasyEchoHistoryDB) do
            if entry.type == "SELECT" then
                if entry.quality == 3 then
                    if entry.isPrio then cEpicsPrio = cEpicsPrio + 1 else cEpicsOther = cEpicsOther + 1 end
                end
                if entry.quality == 2 then cRares = cRares + 1 end

                if entry.name then
                    local n = string.lower(entry.name)
                    if tOneLower ~= "" and n:find(tOneLower, 1, true) then
                        if trackQOne == TRACK_QUALITY_ANY or entry.quality == trackQOne then
                            cOne = cOne + 1
                        end
                    end
                    if tTwoLower ~= "" and n:find(tTwoLower, 1, true) then
                        if trackQTwo == TRACK_QUALITY_ANY or entry.quality == trackQTwo then
                            cTwo = cTwo + 1
                        end
                    end
                end
            end
        end
    end

    return cOne, cTwo, cEpicsPrio, cEpicsOther, cRares
end

function EasyEcho_UI.UpdateHistoryUI()
    if not historyFrame then CreateHistoryFrame() end
    local cntRend, cntDouble, cntEpicsPrio, cntEpicsOther, cntRares = CalculateStats()
    local trackedOne, trackedTwo = GetTrackedSpellNames()

    local trackQOne = GetTrackedSpellQualityOne()
    local trackQTwo = GetTrackedSpellQualityTwo()
    local qNameOne = (trackQOne == TRACK_QUALITY_ANY) and "Any" or (QUALITY_NAMES[trackQOne] or "Rare")
    local qNameTwo = (trackQTwo == TRACK_QUALITY_ANY) and "Any" or (QUALITY_NAMES[trackQTwo] or "Rare")

    statRend:SetText((trackedOne or "Spell 1") .. ": " .. cntRend)
    statDouble:SetText((trackedTwo or "Spell 2") .. ": " .. cntDouble)

    if trackDDOne then UIDropDownMenu_SetText(trackDDOne, qNameOne) end
    if trackDDTwo then UIDropDownMenu_SetText(trackDDTwo, qNameTwo) end

    if trackedSpell1Box and trackedSpell1Box:GetText() ~= trackedOne then trackedSpell1Box:SetText(trackedOne) end
    if trackedSpell2Box and trackedSpell2Box:GetText() ~= trackedTwo then trackedSpell2Box:SetText(trackedTwo) end
    statEpicsPrio:SetText("Epics (List): " .. cntEpicsPrio)
    statEpicsOther:SetText("Epics (Other): " .. cntEpicsOther)
    statRares:SetText("Total Rares: " .. cntRares)
    statRerollsLeft:SetText("Rerolls Left: " .. math.max(0, liveTotalRerolls - liveUsedRerolls))

    -- Hide old fontstring pool (legacy) and row pool (use pairs for sparse indices)
    for _, fs in pairs(fontStringPool) do fs:Hide() end
    for _, row in pairs(historyRowPool) do row:Hide() end

    local yOffset = 0
    for i, entry in ipairs(EasyEchoHistoryDB or {}) do
        if entry.type == "SELECT" then
            -- SELECT entries use row frames with icon, tooltip, and context menu
            local row = CreateHistoryRowFrame(historyContent, historyRowPool, i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetWidth(750)
            row:SetHeight(HIST_ROW_HEIGHT)

            -- Icon from EchoDB
            local dbEntry = EasyEchoEchoDB and EasyEchoEchoDB[string.lower(entry.name or "")]
            if dbEntry and dbEntry.icon and dbEntry.icon ~= "" then
                row.icon:SetTexture(dbEntry.icon)
            elseif dbEntry and dbEntry.spellId then
                local _, _, spellIcon = GetSpellInfo(dbEntry.spellId)
                row.icon:SetTexture(spellIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            row.icon:Show()

            -- Position text after icon
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)

            local qColor = QUALITY_COLORS[entry.quality] or "ffffffff"
            local qName = QUALITY_NAMES[entry.quality] or "?"
            row.text:SetText("|cff999999[#" .. entry.level .. "]|r |c" .. qColor .. ">>> " .. entry.name .. " (" .. qName .. ")|r")

            row.echoData = entry
            row.highlight:Show()
            row:Show()
            yOffset = yOffset + HIST_ROW_HEIGHT
        else
            -- OPTIONS and REROLL entries use simple font strings
            local text = fontStringPool[i] or historyContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            if not fontStringPool[i] then fontStringPool[i] = text end
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", 0, -yOffset)
            text:SetWidth(750)
            text:SetJustifyH("LEFT")
            local line = ""
            if entry.type == "OPTIONS" then
                line = "|cff666666[#" .. entry.level .. " Offers]: " .. entry.text .. "|r"
            elseif entry.type == "REROLL" then
                line = "|cff999999[#" .. entry.level .. "]|r |cffff0000[Reroll " .. entry.countStr .. "] " .. (entry.reason or "") .. "|r"
            end
            text:SetText(line)
            text:Show()
            yOffset = yOffset + 14
        end
    end
    historyContent:SetHeight(yOffset)
    local maxScroll = math.max(0, yOffset - 370)
    scrollBar:SetMinMaxValues(0, maxScroll)
    if maxScroll > 0 then scrollBar:SetValue(maxScroll) end
end

function EasyEcho_UI.AddSelectToHistory(name, quality, levelCount, isPrio)
    if not EasyEchoHistoryDB then EasyEchoHistoryDB = {} end
    table.insert(EasyEchoHistoryDB, {type="SELECT", name=name, quality=quality, level=levelCount, isPrio=isPrio, timestamp=time()})
    EasyEcho_UI.UpdateHistoryUI()

    -- Record selected echo to persistent database
    if name and ProjectEbonhold and ProjectEbonhold.PerkService then
        local choices = ProjectEbonhold.PerkService.GetCurrentChoice and ProjectEbonhold.PerkService.GetCurrentChoice() or nil
        if choices then
            for _, choice in ipairs(choices) do
                local cName = GetSpellInfo(choice.spellId)
                if cName and string.lower(cName) == string.lower(name) then
                    EasyEcho_RecordEcho(choice.spellId, quality)
                    break
                end
            end
        end
    end
end

function EasyEcho_UI.AddOptionsToHistory(choices, levelCount)
    if not EasyEchoHistoryDB then EasyEchoHistoryDB = {} end

    -- Verhindert doppelte Einträge für denselben Level im UI
    local lastEntry = EasyEchoHistoryDB[#EasyEchoHistoryDB]
    if lastEntry and lastEntry.type == "OPTIONS" and lastEntry.level == levelCount then
        return
    end

    local optString = ""
    for i, choice in ipairs(choices) do
        optString = optString .. (GetSpellInfo(choice.spellId) or "?") .. "(" .. string.sub(QUALITY_NAMES[choice.quality] or "C", 1, 1) .. ")"
        if i < #choices then optString = optString .. ", " end

        -- Record each offered echo to persistent database
        EasyEcho_RecordEcho(choice.spellId, choice.quality)
    end

    table.insert(EasyEchoHistoryDB, {type="OPTIONS", text=optString, level=levelCount, timestamp=time()})
    EasyEcho_UI.UpdateHistoryUI()
end

function EasyEcho_UI.AddRerollToHistory(reason, levelCount, used, total)
    if not EasyEchoHistoryDB then EasyEchoHistoryDB = {} end
    table.insert(EasyEchoHistoryDB, {type="REROLL", level=levelCount, reason=reason, countStr=(used or "?").."/"..(total or "?"), timestamp=time()})
    EasyEcho_UI.UpdateHistoryUI()
end

function EasyEcho_UI.ResetAllData(chatMessage)
    EasyEchoHistoryDB = {}
    EasyEchoLogDB = {}

    if EasyEchoSettings then
        EasyEchoSettings.CurrentPickCount = 2
    end

    local granted = nil
    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetGrantedPerks then
        granted = ProjectEbonhold.PerkService.GetGrantedPerks()
    end

    if type(granted) == "table" then
        table.wipe(granted)
    elseif ProjectEbonhold and ProjectEbonhold.Perks and type(ProjectEbonhold.Perks.grantedPerks) == "table" then
        table.wipe(ProjectEbonhold.Perks.grantedPerks)
    end

    if chatMessage and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r " .. chatMessage)
    end

    EasyEcho_UI.UpdateHistoryUI()
    if echoesFrame and echoesFrame:IsShown() then
        EasyEcho_UI.UpdateEchoListUI()
    end
    if grantedFrame and grantedFrame:IsShown() then
        EasyEcho_UI.UpdateGrantedUI()
    end
end

function EasyEcho_UI.UpdateEchoListUI()
    if not echoesFrame then CreateEchoesFrame() end

    -- Hide all existing rows
    for _, row in ipairs(echoesRowPool) do row:Hide() end

    local entries = GetEchoDBSorted()
    local contentWidth = echoesContent:GetWidth()
    local yOffset = 0

    -- Update count label
    local totalCount = 0
    if EasyEchoEchoDB then
        for _ in pairs(EasyEchoEchoDB) do totalCount = totalCount + 1 end
    end
    if echoesCountLabel then
        echoesCountLabel:SetText(totalCount .. " echoes discovered" .. (#entries ~= totalCount and (" (" .. #entries .. " shown)") or ""))
    end

    if #entries == 0 then
        local row = CreateRowFrame(echoesContent, echoesRowPool, 1)
        row:SetPoint("TOPLEFT", 0, 0)
        row:SetWidth(contentWidth)
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.nameText:SetText("|cff888888No echoes discovered yet.|r")
        row.qualText:SetText("")
        row.extraText:SetText("")
        row.echoData = nil
        row:Show()
        yOffset = ROW_HEIGHT
    else
        for i, entry in ipairs(entries) do
            local row = CreateRowFrame(echoesContent, echoesRowPool, i)
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetWidth(contentWidth)

            -- Icon
            if entry.icon and entry.icon ~= "" then
                row.icon:SetTexture(entry.icon)
            elseif entry.spellId then
                local _, _, spellIcon = GetSpellInfo(entry.spellId)
                row.icon:SetTexture(spellIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            else
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end

            -- Name colored by quality
            local qColor = QUALITY_COLORS[entry.quality] or "ffffffff"
            row.nameText:SetText("|c" .. qColor .. entry.name .. "|r")

            -- Quality name colored
            local qName = QUALITY_NAMES[entry.quality] or "Common"
            row.qualText:SetText("|c" .. qColor .. qName .. "|r")

            -- Classes (multiple)
            row.extraText:SetText(entry.classDisplay or "")

            -- Store data for tooltip
            row.echoData = entry

            row:Show()
            yOffset = yOffset + ROW_HEIGHT
        end
    end

    echoesContent:SetHeight(yOffset)
    local visibleH = echoesFrame:GetHeight() - 120
    local maxScroll = math.max(0, yOffset - visibleH)
    echoesScrollBar:SetMinMaxValues(0, maxScroll)
    echoesScrollBar:SetValue(0)
end

function EasyEcho_UI.ShowMainWindow()
    if not historyFrame then CreateHistoryFrame() end
    if echoesFrame and echoesFrame:IsShown() then echoesFrame:Hide() end
    if grantedFrame and grantedFrame:IsShown() then grantedFrame:Hide() end

    local config = _G["EasyEchoConfigFrame"]
    if config and config:IsShown() then
        config:Hide()
    end

    historyFrame:Show()
    EasyEcho_UI.UpdateHistoryUI()
end

function EasyEcho_UI.ToggleEchoList()
    if not echoesFrame then CreateEchoesFrame() end
    if echoesFrame:IsShown() then
        echoesFrame:Hide()
    else
        if historyFrame and historyFrame:IsShown() then historyFrame:Hide() end
        if grantedFrame and grantedFrame:IsShown() then grantedFrame:Hide() end
        local config = _G["EasyEchoConfigFrame"]
        if config and config:IsShown() then config:Hide() end
        echoesFrame:Show()
        EasyEcho_UI.UpdateEchoListUI()
    end
end

function EasyEcho_UI.Init()
    if not EasyEchoHistoryDB then EasyEchoHistoryDB = {} end
    CreateHistoryFrame()
    CreateMiniStartStopButton()
    EasyEcho_UI.UpdateHistoryUI()
end

function EasyEcho_UI.Toggle()
    if not historyFrame then CreateHistoryFrame() end
    if historyFrame:IsShown() then historyFrame:Hide() else historyFrame:Show() EasyEcho_UI.UpdateHistoryUI() end
end

-- =========================================================
-- SLASH COMMANDS (Updated for /ee config)
-- =========================================================
SLASH_EASYECHO1 = "/easyecho"
SLASH_EASYECHO2 = "/ee"

SlashCmdList["EASYECHO"] = function(msg)
    msg = string.lower(msg or "")

    if msg == "config" then
        if EasyEcho_Config and EasyEcho_Config.Toggle then
            EasyEcho_Config.Toggle()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[EasyEcho]|r Error: Config module not loaded!")
        end
    elseif msg == "echoes" then
        EasyEcho_UI.ToggleGrantedEchoes()
    elseif msg == "db" then
        EasyEcho_UI.ToggleEchoList()
    elseif msg == "start" then
        EasyEcho_Start()
    elseif msg == "stop" then
        EasyEcho_Stop()
    elseif msg == "toggle" then
        EasyEcho_ToggleRunning()
    else
        EasyEcho_UI.Toggle()
    end
end