-- =========================================================
-- EASYECHO UI (English Version & Fixed Alignment)
-- =========================================================
EasyEcho_UI = {}

local historyFrame = nil
local historyScrollFrame = nil
local historyContent = nil
local scrollBar = nil
local fontStringPool = {} 

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
    [3] = "Epic"
}

local QUALITY_COLORS = {
    [0] = "ffffffff", 
    [1] = "ff1eff00", 
    [2] = "ff0070dd", 
    [3] = "ffa335ee"  
}

local function CreateHistoryFrame()
    local f = CreateFrame("Frame", "EasyEchoHistoryFrame", UIParent)
    f:SetWidth(600)
    f:SetHeight(540)
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
    content:SetWidth(550)
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
        EasyEchoHistoryDB, EasyEchoLogDB = {}, {}
        if EasyEchoSettings then EasyEchoSettings.CurrentPickCount = 2 end
        EasyEcho_UI.UpdateHistoryUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Everything has been reset.")
    end)
	
	-- Suche diesen Block in der Funktion CreateHistoryFrame() innerhalb der EasyEchoUI.lua
	local configBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	configBtn:SetSize(80, 22)
	configBtn:SetPoint("TOPRIGHT", -35, -10)
	configBtn:SetText("Config")
	configBtn:SetScript("OnClick", function()
		-- Sicherheitsabfrage für das Config-Modul
		if EasyEcho_Config and EasyEcho_Config.Toggle then
			-- Schließt das aktuelle Fenster (History), bevor die Config geöffnet wird
			if historyFrame then 
				historyFrame:Hide() 
			end
			-- Öffnet das Konfigurationsfenster
			EasyEcho_Config.Toggle()
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[EasyEcho]|r Error: Config module not loaded!")
		end
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
        text:SetWidth(560)
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
    
    -- Verhindert, dass derselbe Level mehrfach im UI auftaucht
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