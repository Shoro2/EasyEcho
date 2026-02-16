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
local echoesRowPool = {}       -- pool of row frames (icon + text + hover)
local echoesSortMode = "rarity"
local echoesSearchText = ""
local echoesSortDropDown = nil
local echoesCountLabel = nil   -- "X echoes discovered" header label

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

    -- Backfill spellId and icon for older entries
    if not EasyEchoEchoDB[key].spellId then
        EasyEchoEchoDB[key].spellId = spellId
    end
    if not EasyEchoEchoDB[key].icon or EasyEchoEchoDB[key].icon == "" then
        EasyEchoEchoDB[key].icon = icon or ""
    end

    -- Update tooltip if it was empty before
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

-- Helper: get the highest quality tier index from an echo's qualities table
local function GetHighestQuality(qualities)
    if not qualities then return 0 end
    local best = 0
    for qName, v in pairs(qualities) do
        if v then
            for idx, name in pairs(QUALITY_NAMES) do
                if name == qName and idx > best then best = idx end
            end
        end
    end
    return best
end

-- Helper: build quality badges string like "E R U"
local function BuildQualityBadges(qualities)
    if not qualities then return "" end
    local order = { { 4, "L" }, { 3, "E" }, { 2, "R" }, { 1, "U" }, { 0, "C" } }
    local parts = {}
    for _, pair in ipairs(order) do
        local qIdx, letter = pair[1], pair[2]
        local qName = QUALITY_NAMES[qIdx]
        if qName and qualities[qName] then
            table.insert(parts, "|c" .. (QUALITY_COLORS[qIdx] or "ffffffff") .. letter .. "|r")
        end
    end
    return table.concat(parts, " ")
end

local function GetEchoDBSorted()
    if not EasyEchoEchoDB then return {} end

    local entries = {}
    local searchLower = string.lower(echoesSearchText or "")

    for key, data in pairs(EasyEchoEchoDB) do
        if type(data) == "table" and data.name then
            local match = (searchLower == "" or string.lower(data.name):find(searchLower, 1, true))
            if match then
                local hq = GetHighestQuality(data.qualities)
                table.insert(entries, {
                    key = key,
                    name = data.name,
                    icon = data.icon or "",
                    spellId = data.spellId,
                    tooltip = data.tooltip or "",
                    class = data.class or "UNKNOWN",
                    qualities = data.qualities,
                    highestQuality = hq,
                    firstSeen = data.firstSeen or 0,
                    lastSeen = data.lastSeen or 0,
                    prioRank = GetPrioRank(data.name, hq)
                })
            end
        end
    end

    table.sort(entries, function(a, b)
        if echoesSortMode == "name" then
            return string.lower(a.name) < string.lower(b.name)
        elseif echoesSortMode == "lastseen" then
            if a.lastSeen ~= b.lastSeen then
                return a.lastSeen > b.lastSeen
            end
            return string.lower(a.name) < string.lower(b.name)
        elseif echoesSortMode == "prio" then
            if a.prioRank ~= b.prioRank then
                return a.prioRank < b.prioRank
            end
            if a.highestQuality ~= b.highestQuality then
                return a.highestQuality > b.highestQuality
            end
            return string.lower(a.name) < string.lower(b.name)
        else -- rarity (default)
            if a.highestQuality ~= b.highestQuality then
                return a.highestQuality > b.highestQuality
            end
            return string.lower(a.name) < string.lower(b.name)
        end
    end)

    return entries
end

-- Acquire or create a row frame for the echo list
local ROW_HEIGHT = 26
local ROW_ICON_SIZE = 22

local function AcquireEchoRow(parent, index)
    if echoesRowPool[index] then return echoesRowPool[index] end

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

    -- Quality badges
    local badges = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badges:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    badges:SetWidth(80)
    badges:SetJustifyH("LEFT")
    row.badges = badges

    -- Class label
    local classText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classText:SetPoint("LEFT", badges, "RIGHT", 4, 0)
    classText:SetWidth(70)
    classText:SetJustifyH("LEFT")
    classText:SetTextColor(0.6, 0.6, 0.6)
    row.classText = classText

    -- Highlight texture
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)

    row:SetScript("OnEnter", function(self)
        if not self.echoData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        local data = self.echoData
        local hq = GetHighestQuality(data.qualities)
        local hColor = QUALITY_COLORS[hq] or "ffffffff"
        GameTooltip:AddLine("|c" .. hColor .. data.name .. "|r")

        -- Quality tiers line
        local qLine = BuildQualityBadges(data.qualities)
        if qLine ~= "" then
            GameTooltip:AddLine("Qualities: " .. qLine, 1, 1, 1)
        end

        -- Class
        if data.class and data.class ~= "UNKNOWN" then
            GameTooltip:AddLine("Discovered as: " .. data.class, 0.5, 0.5, 0.5)
        end

        -- Timestamps
        if data.firstSeen then
            GameTooltip:AddLine("First seen: " .. date("%m/%d/%y %H:%M", data.firstSeen), 0.5, 0.5, 0.5)
        end
        if data.lastSeen then
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

    echoesRowPool[index] = row
    return row
end

local function CreateEchoesFrame()
    if echoesFrame then return end

    local FRAME_W = 560
    local FRAME_H = 520

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
    hdrQual:SetText("|cffbbbbbbQualities|r")

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

    -- Ingest granted/locked perks into the persistent echo database
    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.RequestGrantedPerks then
        ProjectEbonhold.PerkService.RequestGrantedPerks()
    end

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
        local row = AcquireEchoRow(echoesContent, 1)
        row:SetPoint("TOPLEFT", 0, 0)
        row:SetWidth(contentWidth)
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.nameText:SetText("|cff888888No echoes discovered yet.|r")
        row.badges:SetText("")
        row.classText:SetText("")
        row.echoData = nil
        row:Show()
        yOffset = ROW_HEIGHT
    else
        for i, entry in ipairs(entries) do
            local row = AcquireEchoRow(echoesContent, i)
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

            -- Name colored by highest quality
            local hColor = QUALITY_COLORS[entry.highestQuality] or "ffffffff"
            row.nameText:SetText("|c" .. hColor .. entry.name .. "|r")

            -- Quality badges
            row.badges:SetText(BuildQualityBadges(entry.qualities))

            -- Class
            local classDisplay = entry.class or ""
            if classDisplay == "UNKNOWN" then classDisplay = "" end
            if classDisplay ~= "" then
                classDisplay = classDisplay:sub(1, 1) .. classDisplay:sub(2):lower()
            end
            row.classText:SetText(classDisplay)

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
    elseif msg == "echoes" or msg == "db" then
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