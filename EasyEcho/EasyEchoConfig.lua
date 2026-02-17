EasyEcho_Config = {}
local configFrame = nil
local scrollChild = nil
local rows = {}
local searchText = ""
local selectedQuality = "Any"
local currentView = "Prio" 

-- Suggestion System Variables
local suggestionFrame = nil
local suggestionButtons = {}
local knownSpells = {}

local function PopulateKnownSpells()
    knownSpells = {}
    local seen = {}
    if EasyEcho_PrioList then
        for _, entry in ipairs(EasyEcho_PrioList) do
            local name = entry:match("^(.-)::") or entry
            if name and not seen[name] then
                table.insert(knownSpells, name)
                seen[name] = true
            end
        end
    end
    -- Also include all echoes discovered in the DB
    if EasyEchoEchoDB then
        for _, data in pairs(EasyEchoEchoDB) do
            if type(data) == "table" and data.name and not seen[data.name] then
                table.insert(knownSpells, data.name)
                seen[data.name] = true
            end
        end
    end
    table.sort(knownSpells)
end

-- =========================================================
-- DIALOGS & SUGGESTIONS
-- =========================================================
StaticPopupDialogs["EASYECHO_CONFIRM_RESET"] = {
    text = "Do you really want to reset all priorities to the default values? Your current sorting will be lost.",
    button1 = "Yes", button2 = "No",
    OnAccept = function()
        if EasyEcho_ResetPrioToDefault then EasyEcho_ResetPrioToDefault() EasyEcho_Config.Refresh() end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function UpdateSuggestions(editBox)
    local text = editBox:GetText()
    if not suggestionFrame then return end
    if text == "" or #text < 2 then suggestionFrame:Hide() return end
    local matches = {}
    local textLower = string.lower(text)
    for _, name in ipairs(knownSpells) do
        if string.lower(name):find(textLower, 1, true) then table.insert(matches, name) end
        if #matches >= 5 then break end
    end
    if #matches > 0 then
        suggestionFrame:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 5)
        suggestionFrame:Show()
        for i, btn in ipairs(suggestionButtons) do
            if matches[i] then
                btn:SetText(matches[i])
                btn:SetScript("OnClick", function() editBox:SetText(matches[i]) suggestionFrame:Hide() end)
                btn:Show()
            else btn:Hide() end
        end
        suggestionFrame:SetHeight(#matches * 22 + 10)
    else suggestionFrame:Hide() end
end

-- =========================================================
-- MAIN LOGIC & REFRESH (Fix: SetEnabled -> Enable/Disable)
-- =========================================================
function EasyEcho_Config.Refresh()
    if not scrollChild or not EasyEchoSettings then return end
    if not EasyEchoSettings.Profiles then EasyEchoSettings.Profiles = { ["Default"] = { PriorityList = {}, BanList = {} } } end
    
    PopulateKnownSpells()
    for _, row in ipairs(rows) do row:Hide() end
    
    local list = {}
    if currentView == "Prio" then list = EasyEchoSettings.PriorityList
    elseif currentView == "Ban" then list = EasyEchoSettings.BanList
    elseif currentView == "Profiles" then 
        for name, _ in pairs(EasyEchoSettings.Profiles) do table.insert(list, name) end
        table.sort(list)
    end

    local displayCount = 0
    local searchLower = string.lower(searchText)

    for i, entry in ipairs(list) do
        if searchText == "" or string.lower(entry):find(searchLower, 1, true) then
            displayCount = displayCount + 1
            local row = rows[displayCount]
            if not row then
                row = CreateFrame("Frame", nil, scrollChild)
                row:SetSize(scrollChild:GetWidth(), 25)
                row:EnableMouse(true)
                -- Icon
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(20, 20)
                row.icon:SetPoint("LEFT", 5, 0)
                row.prio = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.prio:SetPoint("LEFT", 28, 0) row.prio:SetWidth(30)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.name:SetPoint("LEFT", 60, 0) row.name:SetWidth(220)
                row.quality = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.quality:SetPoint("LEFT", 285, 0) row.quality:SetWidth(80)
                row.up = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.up:SetSize(45, 18) row.up:SetPoint("RIGHT", -85, 0)
                row.down = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.down:SetSize(45, 18) row.down:SetPoint("RIGHT", -38, 0)
                row.del = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.del:SetSize(32, 18) row.del:SetText("X") row.del:SetPoint("RIGHT", -2, 0)
                -- Clickable priority number overlay
                row.prioBtn = CreateFrame("Button", nil, row)
                row.prioBtn:SetSize(30, 25)
                row.prioBtn:SetPoint("LEFT", 28, 0)
                local ht = row.prioBtn:CreateTexture()
                ht:SetAllPoints()
                ht:SetTexture(1, 1, 0.5, 0.15)
                row.prioBtn:SetHighlightTexture(ht)
                -- Priority inline edit box
                row.prioEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                row.prioEdit:SetSize(30, 20)
                row.prioEdit:SetPoint("LEFT", 28, 0)
                row.prioEdit:SetNumeric(true)
                row.prioEdit:SetAutoFocus(false)
                row.prioEdit:SetMaxLetters(3)
                row.prioEdit:Hide()
                -- Tooltip on hover
                row:SetScript("OnEnter", function(self)
                    if not self.tooltipData then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine(self.tooltipData.name or "")
                    if self.tooltipData.desc and self.tooltipData.desc ~= "" then
                        GameTooltip:AddLine(self.tooltipData.desc, 1, 0.82, 0, true)
                    end
                    if self.tooltipData.status then
                        GameTooltip:AddLine(self.tooltipData.status, 0.5, 0.5, 0.5)
                    end
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                rows[displayCount] = row
            end

            -- Always sync row width to current scrollChild width (adapts after resize)
            row:SetWidth(scrollChild:GetWidth())

            if currentView == "Profiles" then
                row.prio:SetText("")
                if row.prioBtn then row.prioBtn:Hide() end
                if row.prioEdit then row.prioEdit:Hide() end
                row.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
                row.name:SetText(entry == EasyEchoSettings.ActiveProfile and "|cff00ff00" .. entry .. " (Active)|r" or entry)
                row.quality:SetText("")
                row.tooltipData = { name = entry, desc = "", status = entry == EasyEchoSettings.ActiveProfile and "Active Profile" or "" }
                row.up:SetText("Load") row.up:Show()
                row.up:SetScript("OnClick", function() EasyEcho_SwitchProfile(entry) end)
                row.down:SetText("Save") row.down:Show()
                row.down:SetScript("OnClick", function()
                    EasyEchoSettings.Profiles[entry].PriorityList = { unpack(EasyEchoSettings.PriorityList) }
                    EasyEchoSettings.Profiles[entry].BanList = { unpack(EasyEchoSettings.BanList) }
                    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Profile '" .. entry .. "' saved.")
                end)
                -- FIX: Enable/Disable instead of SetEnabled
                if entry ~= "Default" then row.del:Enable() else row.del:Disable() end
            else
                local sName, sQual = entry:match("^(.-)::(.+)$")
                sName, sQual = sName or entry, sQual or "Any"
                row.prio:SetText(string.format("%02d.", i))
                row.prio:Show()
                if row.prioEdit then row.prioEdit:Hide() end
                row.name:SetText(sName)

                -- Look up icon and tooltip from EchoDB
                local dbKey = string.lower(sName)
                local dbEntry = EasyEchoEchoDB and EasyEchoEchoDB[dbKey]
                if dbEntry and dbEntry.icon and dbEntry.icon ~= "" then
                    row.icon:SetTexture(dbEntry.icon)
                elseif dbEntry and dbEntry.spellId then
                    local _, _, spIcon = GetSpellInfo(dbEntry.spellId)
                    row.icon:SetTexture(spIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
                else
                    row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
                -- Use quality-specific tooltip, fall back to legacy tooltip
                local tooltipDesc = ""
                if dbEntry then
                    tooltipDesc = (dbEntry.tooltips and dbEntry.tooltips[sQual]) or dbEntry.tooltip or ""
                end
                local tooltipStatus = currentView == "Ban" and "|cffff0000Banned|r" or ("Priority #" .. i .. " (" .. sQual .. ")")
                row.tooltipData = { name = sName, desc = tooltipDesc, status = tooltipStatus }

                row.up:SetText("Up") row.down:SetText("Down")
                if currentView == "Ban" then
                    row.quality:SetText("BANNED") row.quality:SetTextColor(1, 0, 0)
                    row.up:Hide() row.down:Hide()
                    if row.prioBtn then row.prioBtn:Hide() end
                else
                    row.quality:SetText(sQual)
                    if sQual == "Epic" then row.quality:SetTextColor(0.64, 0.21, 0.93)
                    elseif sQual == "Rare" then row.quality:SetTextColor(0, 0.44, 0.87)
                    elseif sQual == "Uncommon" then row.quality:SetTextColor(0.12, 1, 0)
                    else row.quality:SetTextColor(1, 1, 1) end
                    row.up:Show() row.down:Show()
                    if row.prioBtn then
                        row.prioBtn:Show()
                        row.prioBtn:SetScript("OnClick", function()
                            row.prio:Hide()
                            row.prioEdit:SetText(tostring(i))
                            row.prioEdit:Show()
                            row.prioEdit:SetFocus()
                        end)
                        row.prioEdit:SetScript("OnEnterPressed", function(self)
                            local newPos = tonumber(self:GetText())
                            if newPos and newPos ~= i then
                                newPos = math.max(1, math.min(newPos, #list))
                                local removed = table.remove(list, i)
                                table.insert(list, newPos, removed)
                            end
                            self:Hide()
                            row.prio:Show()
                            EasyEcho_Config.Refresh()
                        end)
                        row.prioEdit:SetScript("OnEscapePressed", function(self)
                            self:Hide()
                            row.prio:Show()
                        end)
                        row.prioEdit:SetScript("OnEditFocusLost", function(self)
                            self:Hide()
                            row.prio:Show()
                        end)
                    end
                end
                row.up:SetScript("OnClick", function() if i > 1 then table.insert(list, i-1, table.remove(list, i)) EasyEcho_Config.Refresh() end end)
                row.down:SetScript("OnClick", function() if i < #list then table.insert(list, i+1, table.remove(list, i)) EasyEcho_Config.Refresh() end end)
                row.del:Enable()
                row.del:SetScript("OnClick", function() table.remove(list, i) EasyEcho_Config.Refresh() end)
            end
            row:SetPoint("TOPLEFT", 0, -(displayCount-1)*26)
            row:Show()
        end
    end
    scrollChild:SetHeight(displayCount * 26)
    
    if EasyEchoAddPrio then
        if currentView == "Profiles" then
            EasyEchoAddPrio:Hide()
            UIDropDownMenu_DisableDropDown(EasyEchoConfigQualityDropDown)
        else
            EasyEchoAddPrio:Show()
            EasyEchoAddPrio:SetText(#list + 1)
            if currentView == "Prio" then UIDropDownMenu_EnableDropDown(EasyEchoConfigQualityDropDown)
            else UIDropDownMenu_DisableDropDown(EasyEchoConfigQualityDropDown) end
        end
    end
end

-- =========================================================
-- IO FRAME & MAIN FRAME
-- =========================================================
local function CreateIOFrame()
    local f = CreateFrame("Frame", "EasyEchoIOFrame", UIParent)
    f:SetSize(450, 400) f:SetPoint("CENTER") f:SetFrameStrata("DIALOG")
    f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving) f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}})

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", f, "TOP", 0, -15)
    f.title:SetText("Export / Import")

    -- Hint
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", 20, -32)
    f.hint:SetTextColor(0.7, 0.7, 0.7)
    f.hint:SetText("Copy text to export, or paste & click Import to replace current list.")

    local scrollFrame = CreateFrame("ScrollFrame", "EasyEchoIOScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -48)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 60)

    local eb = CreateFrame("EditBox", nil, scrollFrame)
    eb:SetMultiLine(true) eb:SetWidth(380) eb:SetFontObject("ChatFontNormal")
    scrollFrame:SetScrollChild(eb)
    f.editBox = eb

    local save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    save:SetSize(100, 25) save:SetPoint("BOTTOMLEFT", 20, 20) save:SetText("Import")
    save:SetScript("OnClick", function()
        local text = eb:GetText()
        if not text or text == "" then return end
        local target
        if currentView == "Ban" then
            target = EasyEchoSettings.BanList
        else
            target = EasyEchoSettings.PriorityList
        end
        -- Clear and repopulate
        for k = #target, 1, -1 do target[k] = nil end
        for line in text:gmatch("[^\r\n]+") do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then
                table.insert(target, trimmed)
            end
        end
        EasyEcho_Config.Refresh()
        f:Hide()
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[EasyEcho]|r Imported " .. #target .. " entries into " .. (currentView == "Ban" and "Ban List" or "Priority List") .. ".")
        end
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25) closeBtn:SetPoint("BOTTOMRIGHT", -20, 20) closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    return f
end

local function PopulateIOFrame(ioFrame)
    if not ioFrame or not ioFrame.editBox then return end
    local source
    if currentView == "Ban" then
        source = EasyEchoSettings and EasyEchoSettings.BanList or {}
        ioFrame.title:SetText("Export / Import - Ban List")
    else
        source = EasyEchoSettings and EasyEchoSettings.PriorityList or {}
        ioFrame.title:SetText("Export / Import - Priority List")
    end
    local text = table.concat(source, "\n")
    ioFrame.editBox:SetText(text)
    ioFrame.editBox:HighlightText()
    ioFrame.editBox:SetFocus()
end

function EasyEcho_Config.CreateFrame()
    local f = CreateFrame("Frame", "EasyEchoConfigFrame", UIParent)
    f:SetSize(700, 700) f:SetPoint("CENTER", 100, 0)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11, right=12, top=12, bottom=11}})
    f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving) f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local close = CreateFrame("Button", "EasyEchoConfigCloseButton", f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetFrameLevel(f:GetFrameLevel() + 10)

    local backBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    backBtn:SetSize(70, 20)
    backBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)
    backBtn:SetText("Back")
    backBtn:SetScript("OnClick", function()
        if EasyEcho_UI and EasyEcho_UI.ShowMainWindow then
            EasyEcho_UI.ShowMainWindow()
        else
            f:Hide()
        end
    end)

    -- Tabs
    local pTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    pTab:SetSize(110, 25) pTab:SetPoint("TOPLEFT", 20, -15) pTab:SetText("Priority List")
    pTab:SetScript("OnClick", function() currentView = "Prio" EasyEcho_Config.Refresh() end)
    local bTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    bTab:SetSize(110, 25) bTab:SetPoint("LEFT", pTab, "RIGHT", 5, 0) bTab:SetText("Ban List")
    bTab:SetScript("OnClick", function() currentView = "Ban" EasyEcho_Config.Refresh() end)
    local prTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    prTab:SetSize(110, 25) prTab:SetPoint("LEFT", bTab, "RIGHT", 5, 0) prTab:SetText("Profiles")
    prTab:SetScript("OnClick", function() currentView = "Profiles" EasyEcho_Config.Refresh() end)

    local searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    searchBox:SetSize(130, 20) searchBox:SetPoint("TOPLEFT", 390, -15)
    searchBox:SetScript("OnTextChanged", function(s) searchText = s:GetText() EasyEcho_Config.Refresh() end)

    local sf = CreateFrame("ScrollFrame", "EasyEchoConfigScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 20, -65) sf:SetPoint("BOTTOMRIGHT", -35, 110)
    scrollChild = CreateFrame("Frame", "EasyEchoConfigScrollChild") scrollChild:SetSize(540, 1) sf:SetScrollChild(scrollChild)

    suggestionFrame = CreateFrame("Frame", nil, f) suggestionFrame:SetSize(180, 120) suggestionFrame:SetFrameStrata("HIGH") suggestionFrame:Hide()
    suggestionFrame:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16, insets={left=4, right=4, top=4, bottom=4}})
    suggestionFrame:SetBackdropColor(0,0,0,0.9)
    for i=1, 5 do
        local b = CreateFrame("Button", nil, suggestionFrame) b:SetSize(170, 20) b:SetPoint("TOP", 0, -5 - (i-1)*22)
        b:SetNormalFontObject("GameFontHighlightSmall") suggestionButtons[i] = b
        local t = b:CreateTexture() t:SetAllPoints() t:SetTexture(1,1,1,0.1) b:SetHighlightTexture(t)
    end

    -- Add New Section
    local addName = CreateFrame("EditBox", "EasyEchoAddName", f, "InputBoxTemplate")
    addName:SetSize(180, 20) addName:SetPoint("BOTTOMLEFT", 65, 75)
    addName:SetScript("OnTextChanged", function(s) if currentView ~= "Profiles" then UpdateSuggestions(s) end end)
    local addPrio = CreateFrame("EditBox", "EasyEchoAddPrio", f, "InputBoxTemplate")
    addPrio:SetSize(30, 20) addPrio:SetPoint("BOTTOMLEFT", 25, 75) addPrio:SetNumeric(true)
    local addQualDrop = CreateFrame("Frame", "EasyEchoConfigQualityDropDown", f, "UIDropDownMenuTemplate")
    addQualDrop:SetPoint("BOTTOMLEFT", 240, 68) UIDropDownMenu_SetWidth(addQualDrop, 90)
    UIDropDownMenu_Initialize(addQualDrop, function() 
        local opts = {"Common", "Uncommon", "Rare", "Epic", "Any"}
        for _, o in ipairs(opts) do UIDropDownMenu_AddButton({text=o, value=o, func=function(s) selectedQuality=s.value UIDropDownMenu_SetText(EasyEchoConfigQualityDropDown, s.value) end}) end
    end)
    UIDropDownMenu_SetText(addQualDrop, "Any")

    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(80, 22) addBtn:SetPoint("BOTTOMRIGHT", -25, 74) addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local n = addName:GetText()
        if n == "" then return end
        if currentView == "Profiles" then
            EasyEchoSettings.Profiles[n] = { PriorityList = { unpack(EasyEchoSettings.PriorityList) }, BanList = { unpack(EasyEchoSettings.BanList) } }
        else
            local clean = n:gsub("[^%a%s']", "")
            if currentView == "Prio" then table.insert(EasyEchoSettings.PriorityList, tonumber(addPrio:GetText()) or 1, clean .. "::" .. selectedQuality)
            else table.insert(EasyEchoSettings.BanList, clean) end
        end
        addName:SetText("") EasyEcho_Config.Refresh()
    end)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 25) resetBtn:SetPoint("BOTTOMLEFT", 20, 20) resetBtn:SetText("Reset Default")
    resetBtn:SetScript("OnClick", function() StaticPopup_Show("EASYECHO_CONFIRM_RESET") end)
    local ioBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ioBtn:SetSize(110, 25) ioBtn:SetPoint("BOTTOMLEFT", 135, 20) ioBtn:SetText("Export/Import")
    ioBtn:SetScript("OnClick", function()
        local ioF = EasyEchoIOFrame or CreateIOFrame()
        ioF:Show()
        PopulateIOFrame(ioF)
    end)

    -- Resize: update scrollChild width whenever the frame is resized
    f:SetScript("OnSizeChanged", function(self)
        if scrollChild then
            scrollChild:SetWidth(self:GetWidth() - 60)
        end
    end)

    if EasyEcho_UI and EasyEcho_UI.AddResizeHandles then
        EasyEcho_UI.AddResizeHandles(f, 400, 400, function()
            EasyEcho_Config.Refresh()
        end)
    end

    f:SetScript("OnHide", function()
        if EasyEcho_UI and EasyEcho_UI.UpdateShowHideButton then EasyEcho_UI.UpdateShowHideButton() end
    end)
    configFrame = f f:Hide()
end

function EasyEcho_Config.Toggle()
    if not configFrame then EasyEcho_Config.CreateFrame() end
    if configFrame:IsShown() then
        configFrame:Hide()
        if EasyEcho_UI and EasyEcho_UI.UpdateShowHideButton then EasyEcho_UI.UpdateShowHideButton() end
    else
        if EasyEchoHistoryFrame and EasyEchoHistoryFrame:IsShown() then EasyEchoHistoryFrame:Hide() end
        if EasyEchoGrantedEchoesFrame and EasyEchoGrantedEchoesFrame:IsShown() then EasyEchoGrantedEchoesFrame:Hide() end
        if EasyEcho_UI and EasyEcho_UI.SetLastShownUI then EasyEcho_UI.SetLastShownUI("config") end
        EasyEcho_Config.Refresh()
        configFrame:Show()
        if EasyEcho_UI and EasyEcho_UI.UpdateShowHideButton then EasyEcho_UI.UpdateShowHideButton() end
    end
end
