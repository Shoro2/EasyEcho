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

local liveUsedRerolls = 0
local liveTotalRerolls = 10

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

    if ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetGrantedPerks then
        granted = ProjectEbonhold.PerkService.GetGrantedPerks()
    end

    if not granted and ProjectEbonhold and ProjectEbonhold.Perks and ProjectEbonhold.Perks.grantedPerks then
        granted = ProjectEbonhold.Perks.grantedPerks
    end

    if type(granted) ~= "table" then
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

        grouped[key].count = grouped[key].count + 1
    end

    if granted[1] then
        for _, perk in ipairs(granted) do
            AddPerk(perk)
        end
    else
        for _, perkList in pairs(granted) do
            if type(perkList) == "table" then
                for _, perk in ipairs(perkList) do
                    AddPerk(perk)
                end
            end
        end
    end

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
    f:SetWidth(700)
    f:SetHeight(620)
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
    statsBg:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -15, -125)

    -- Helper to create aligned labels
    local function CreateStatLabel(parent, x, y, width)
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT") -- FIXED: Explicit left justification
        return fs
    end

    -- Left Column
    statRend = CreateStatLabel(f, 25, -45, 250)
    statRend:SetText("Rend (Rare): 0")
    
    statEpicsPrio = CreateStatLabel(f, 25, -65, 250)
    statEpicsPrio:SetTextColor(0.64, 0.21, 0.93)
    statEpicsPrio:SetText("Epics (List): 0")

    statRares = CreateStatLabel(f, 25, -85, 250) -- FIXED: Consistent 25 offset
    statRares:SetTextColor(0, 0.44, 0.87)
    statRares:SetText("Total Rares: 0")

    -- Right Column
    statDouble = CreateStatLabel(f, 300, -45, 250)
    statDouble:SetText("Double Strike: 0")

    statEpicsOther = CreateStatLabel(f, 300, -65, 250)
    statEpicsOther:SetTextColor(0.8, 0.4, 1.0)
    statEpicsOther:SetText("Epics (Other): 0")

    statRerollsLeft = CreateStatLabel(f, 300, -85, 250)
    statRerollsLeft:SetTextColor(1, 0.5, 0)
    statRerollsLeft:SetText("Rerolls Left: 10")

    local sf = CreateFrame("ScrollFrame", "EasyEchoScrollFrame", f)
    sf:SetPoint("TOPLEFT", 15, -135) 
    sf:SetPoint("BOTTOMRIGHT", -35, 15)
    
    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(650)
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

    local clearBtn = CreateFrame("Button", "EasyEchoClearBtn", f, "UIPanelButtonTemplate")
    clearBtn:SetWidth(80)
    clearBtn:SetHeight(22)
    clearBtn:SetPoint("TOPLEFT", 12, -10)
    clearBtn:SetText("Clear All")
    clearBtn:SetScript("OnClick", function()
        EasyEcho_UI.ResetAllData("Everything has been reset.")
    end)
	
	-- Suche diesen Block in der Funktion CreateHistoryFrame() innerhalb der EasyEchoUI.lua
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
    local cRend, cDouble, cEpicsPrio, cEpicsOther, cRares = 0, 0, 0, 0, 0
    if not EasyEchoHistoryDB then return 0,0,0,0,0 end
    
    for _, entry in ipairs(EasyEchoHistoryDB) do
        if entry.type == "SELECT" then
            if entry.quality == 3 then
                if entry.isPrio then cEpicsPrio = cEpicsPrio + 1 else cEpicsOther = cEpicsOther + 1 end
            end
            if entry.quality == 2 then cRares = cRares + 1 end
            if entry.name then
                local n = string.lower(entry.name)
                if n:find("rend the weak") and entry.quality == 2 then cRend = cRend + 1 end
                if n:find("double strike") then cDouble = cDouble + 1 end
            end
        end
    end
    return cRend, cDouble, cEpicsPrio, cEpicsOther, cRares
end

function EasyEcho_UI.UpdateHistoryUI()
    if not historyFrame then CreateHistoryFrame() end
    local cntRend, cntDouble, cntEpicsPrio, cntEpicsOther, cntRares = CalculateStats()
    
    statRend:SetText("Rend (Rare): " .. cntRend)
    statDouble:SetText("Double Strike: " .. cntDouble)
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
        text:SetWidth(660)
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
        -- Open Config window independently
        if EasyEcho_Config and EasyEcho_Config.Toggle then
            EasyEcho_Config.Toggle()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[EasyEcho]|r Error: Config module not loaded!")
        end
    else
        -- Default: Toggle History window
        EasyEcho_UI.Toggle()
    end
end