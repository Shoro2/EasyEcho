-- =========================================================
-- EASYECHO UI (English Version & Fixed Alignment)
-- =========================================================
EasyEcho_UI = {}

local historyFrame = nil
local historyScrollFrame = nil
local historyContent = nil
local scrollBar = nil
local fontStringPool = {} 

local echoesFrame = nil
local echoesContent = nil
local echoesScrollBar = nil
local echoesFontPool = {}
local echoesSortMode = "rarity"
local echoesSearchText = ""
local echoesSortDropDown = nil

local MAX_REROLLS_UI = 10 

-- STATS LABELS
local statRend = nil
local statDouble = nil
local statEpicsPrio = nil  
local statEpicsOther = nil 
local statRares = nil
local statRerollsLeft = nil
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

    local name = GetSpellInfo(spellId)
    if not name or name == "" then return end

    local key = string.lower(name)
    local qualityName = QUALITY_NAMES[quality] or "Common"
    local _, playerClass = UnitClass("player")

    if not EasyEchoEchoDB[key] then
        -- New echo discovered
        local tooltip = GetSpellTooltipText(spellId)
        EasyEchoEchoDB[key] = {
            name = name,
            tooltip = tooltip,
            class = playerClass or "UNKNOWN",
            qualities = {},
            firstSeen = time(),
            lastSeen = time()
        }
    end

    -- Record this quality if not yet seen
    if not EasyEchoEchoDB[key].qualities[qualityName] then
        EasyEchoEchoDB[key].qualities[qualityName] = true
    end
    EasyEchoEchoDB[key].lastSeen = time()

    -- Update tooltip if it was empty before
    if (not EasyEchoEchoDB[key].tooltip or EasyEchoEchoDB[key].tooltip == "") then
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

local function GetTrackedSpellQuality()
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if EasyEchoSettings.TrackedSpellQuality == nil then
        EasyEchoSettings.TrackedSpellQuality = 2 -- default: Rare
    end
    return EasyEchoSettings.TrackedSpellQuality
end

local function SaveTrackedSpellQuality(q)
    if not EasyEchoSettings then EasyEchoSettings = {} end
    EasyEchoSettings.TrackedSpellQuality = q
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
            grouped[key] = {
                name = name,
                quality = quality,
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
    local searchLower = string.lower(echoesSearchText or "")
    for _, entry in ipairs(groupedOrder) do
        if searchLower == "" or string.lower(entry.name):find(searchLower, 1, true) then
            table.insert(filtered, entry)
        end
    end

    table.sort(filtered, function(a, b)
        if echoesSortMode == "name" then
            if string.lower(a.name) ~= string.lower(b.name) then
                return string.lower(a.name) < string.lower(b.name)
            end
            return a.quality > b.quality
        elseif echoesSortMode == "count" then
            if a.count ~= b.count then
                return a.count > b.count
            end
            if a.quality ~= b.quality then
                return a.quality > b.quality
            end
            return string.lower(a.name) < string.lower(b.name)
        elseif echoesSortMode == "prio" then
            if a.prioRank ~= b.prioRank then
                return a.prioRank < b.prioRank
            end
            if a.quality ~= b.quality then
                return a.quality > b.quality
            end
            return string.lower(a.name) < string.lower(b.name)
        else
            if a.quality ~= b.quality then
                return a.quality > b.quality
            end
            return string.lower(a.name) < string.lower(b.name)
        end
    end)

    return filtered
end

local function CreateEchoesFrame()
    if echoesFrame then return end

    local f = CreateFrame("Frame", "EasyEchoGrantedEchoesFrame", UIParent)
    f:SetWidth(520)
    f:SetHeight(460)
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

    local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    searchLabel:SetPoint("TOPLEFT", 18, -42)
    searchLabel:SetText("Search")

    local searchBox = CreateFrame("EditBox", "EasyEchoEchoesSearchBox", f, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        echoesSearchText = self:GetText() or ""
        EasyEcho_UI.UpdateEchoListUI()
    end)

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
            { text = "Count", value = "count" },
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

    local sf = CreateFrame("ScrollFrame", "EasyEchoEchoesScrollFrame", f)
    sf:SetPoint("TOPLEFT", 15, -72)
    sf:SetPoint("BOTTOMRIGHT", -35, 20)

    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(460)
    content:SetHeight(1)
    sf:SetScrollChild(content)
    echoesContent = content

    local sb = CreateFrame("Slider", "EasyEchoEchoesScrollBar", f, "UIPanelScrollBarTemplate")
    sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 4, -16)
    sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 4, 16)
    sb:SetMinMaxValues(0, 0)
    sb:SetValueStep(1)
    sb:SetScript("OnValueChanged", function(self, value) sf:SetVerticalScroll(value) end)
    echoesScrollBar = sb

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

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


    -- Row 1: tracked spell counters (click name to edit)
    statRend = CreateStatLabel(f, leftX, TOP_Y, colW, "GameFontHighlight")
    statRend:SetText("Rend the Weak: 0")

    statDouble = CreateStatLabel(f, rightX, TOP_Y, colW, "GameFontHighlight")
    statDouble:SetText("Double Strike: 0")

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
	
	    -- =========================================================
    -- Tracked spell quality dropdown (default = Rare)
    -- Applies to BOTH tracked spells
    -- =========================================================

    -- Make room to the right of "Rerolls Left"
    statRerollsLeft:SetWidth(colW - 140)

    local trackDD = CreateFrame("Frame", "EasyEchoTrackedQualityDropDown", f, "UIDropDownMenuTemplate")
    trackDD:SetPoint("TOPLEFT", statRerollsLeft, "TOPRIGHT", -18, 6)
    UIDropDownMenu_SetWidth(trackDD, 110)
    UIDropDownMenu_JustifyText(trackDD, "LEFT")

    local function TrackQName(q)
        if q == TRACK_QUALITY_ANY then return "Any" end
        return QUALITY_NAMES[q] or "Rare"
    end

    UIDropDownMenu_Initialize(trackDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo()

        local function add(text, val)
            info.text = text
            info.value = val
            info.checked = (GetTrackedSpellQuality() == val)
            info.func = function()
                SaveTrackedSpellQuality(val)
                UIDropDownMenu_SetText(trackDD, TrackQName(val))
                EasyEcho_UI.UpdateHistoryUI()
            end
            UIDropDownMenu_AddButton(info, level)
        end

        -- order: most common use first
        add("Rare", 2)
        add("Epic", 3)
        add("Uncommon", 1)
        add("Common", 0)
        if QUALITY_NAMES[4] then add("Legendary", 4) end
        add("Any", TRACK_QUALITY_ANY)
    end)

    UIDropDownMenu_SetText(trackDD, TrackQName(GetTrackedSpellQuality()))



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
    if not EasyEchoHistoryDB then return 0,0,0,0,0 end

    local trackedOne, trackedTwo = GetTrackedSpellNames()
    local tOneLower = string.lower(trackedOne or "")
    local tTwoLower = string.lower(trackedTwo or "")

    for _, entry in ipairs(EasyEchoHistoryDB) do
        if entry.type == "SELECT" then
            if entry.quality == 3 then
                if entry.isPrio then cEpicsPrio = cEpicsPrio + 1 else cEpicsOther = cEpicsOther + 1 end
            end
            if entry.quality == 2 then cRares = cRares + 1 end
            local trackQ = GetTrackedSpellQuality()

			if entry.name then
				local n = string.lower(entry.name)

				if tOneLower ~= "" and n:find(tOneLower, 1, true) then
					if trackQ == TRACK_QUALITY_ANY or entry.quality == trackQ then
						cOne = cOne + 1
					end
				end

				if tTwoLower ~= "" and n:find(tTwoLower, 1, true) then
					if trackQ == TRACK_QUALITY_ANY or entry.quality == trackQ then
						cTwo = cTwo + 1
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

    local trackQ = GetTrackedSpellQuality()
	local qName = (trackQ == TRACK_QUALITY_ANY) and "Any" or (QUALITY_NAMES[trackQ] or "Rare")

	statRend:SetText((trackedOne or "Spell 1") .. " (" .. qName .. "): " .. cntRend)
	statDouble:SetText((trackedTwo or "Spell 2") .. " (" .. qName .. "): " .. cntDouble)

    if trackedSpell1Box and trackedSpell1Box:GetText() ~= trackedOne then trackedSpell1Box:SetText(trackedOne) end
    if trackedSpell2Box and trackedSpell2Box:GetText() ~= trackedTwo then trackedSpell2Box:SetText(trackedTwo) end
    statEpicsPrio:SetText("Epics (List): " .. cntEpicsPrio)
    statEpicsOther:SetText("Epics (Other): " .. cntEpicsOther)
    statRares:SetText("Total Rares: " .. cntRares)
    statRerollsLeft:SetText("Rerolls Left: " .. math.max(0, liveTotalRerolls - liveUsedRerolls))

    for _, fs in ipairs(fontStringPool) do fs:Hide() end
    local yOffset = 0
    for i, entry in ipairs(EasyEchoHistoryDB or {}) do
        local text = fontStringPool[i] or historyContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if not fontStringPool[i] then table.insert(fontStringPool, text) end
        text:SetPoint("TOPLEFT", 0, -yOffset)
        text:SetWidth(760)
        text:SetJustifyH("LEFT")
        local line = ""
        if entry.type == "OPTIONS" then line = "|cff666666[#"..entry.level.." Offers]: "..entry.text.."|r"
        elseif entry.type == "SELECT" then line = "|cff999999[#"..entry.level.."]|r |c".. (QUALITY_COLORS[entry.quality] or "ffffffff") ..">>> "..entry.name.." ("..(QUALITY_NAMES[entry.quality] or "?")..")|r"
        elseif entry.type == "REROLL" then line = "|cff999999[#"..entry.level.."]|r |cffff0000[Reroll "..entry.countStr.."] ".. (entry.reason or "") .."|r" end
        text:SetText(line) text:Show()
        yOffset = yOffset + 14
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
end

function EasyEcho_UI.UpdateEchoListUI()
    if not echoesFrame then CreateEchoesFrame() end

    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.RequestGrantedPerks then
        ProjectEbonhold.PerkService.RequestGrantedPerks()
    end

    -- Record all granted/locked perks to persistent echo database
    local function RecordGrantedPerks(container)
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
        if ProjectEbonhold.PerkService.GetGrantedPerks then
            RecordGrantedPerks(ProjectEbonhold.PerkService.GetGrantedPerks())
        end
        if ProjectEbonhold.PerkService.GetLockedPerks then
            RecordGrantedPerks(ProjectEbonhold.PerkService.GetLockedPerks())
        end
    end
    if ProjectEbonhold and ProjectEbonhold.Perks then
        if ProjectEbonhold.Perks.grantedPerks then RecordGrantedPerks(ProjectEbonhold.Perks.grantedPerks) end
        if ProjectEbonhold.Perks.lockedPerks then RecordGrantedPerks(ProjectEbonhold.Perks.lockedPerks) end
    end

    for _, fs in ipairs(echoesFontPool) do fs:Hide() end

    local entries = GetGrantedEchoesSorted()
    local yOffset = 0

    if #entries == 0 then
        local emptyText = echoesFontPool[1] or echoesContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if not echoesFontPool[1] then table.insert(echoesFontPool, emptyText) end
        emptyText:SetPoint("TOPLEFT", 0, 0)
        emptyText:SetWidth(450)
        emptyText:SetJustifyH("LEFT")
        emptyText:SetText("No echoes granted yet.")
        emptyText:Show()
        yOffset = 16
    else
        for i, entry in ipairs(entries) do
            local text = echoesFontPool[i] or echoesContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            if not echoesFontPool[i] then table.insert(echoesFontPool, text) end
            text:SetPoint("TOPLEFT", 0, -yOffset)
            text:SetWidth(450)
            text:SetJustifyH("LEFT")

            local qName = QUALITY_NAMES[entry.quality] or "Common"
            local qColor = QUALITY_COLORS[entry.quality] or "ffffffff"
            local countSuffix = ""
            if (entry.count or 1) > 1 then
                countSuffix = " |cffbbbbbbx" .. tostring(entry.count) .. "|r"
            end

            text:SetText("|c" .. qColor .. "[" .. qName .. "]|r " .. entry.name .. countSuffix)
            text:Show()
            yOffset = yOffset + 16
        end
    end

    echoesContent:SetHeight(yOffset)
    local maxScroll = math.max(0, yOffset - 360)
    echoesScrollBar:SetMinMaxValues(0, maxScroll)
    echoesScrollBar:SetValue(0)
end

function EasyEcho_UI.ShowMainWindow()
    if not historyFrame then CreateHistoryFrame() end
    if echoesFrame and echoesFrame:IsShown() then echoesFrame:Hide() end

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