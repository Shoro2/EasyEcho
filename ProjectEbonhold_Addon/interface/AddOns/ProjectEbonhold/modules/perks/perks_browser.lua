-- Perk Browser UI
-- Simple interface to browse all available perks with search and filtering

local addonName, addon = ...

ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.PerkBrowser = {}

-- Store echo data for chat linking
ProjectEbonhold.EchoLinks = ProjectEbonhold.EchoLinks or {}

-- Register custom echo hyperlink handler and chat filter
local function SetupEchoLinkHandler()
    -- Hook the hyperlink click handler for echo links
    local oldSetHyperlink = ItemRefTooltip.SetHyperlink
    ItemRefTooltip.SetHyperlink = function(self, link, ...)
        if link and link:match("^echo:") then
            local spellId = link:match("^echo:(%d+)")
            if spellId then
                spellId = tonumber(spellId)
                if spellId then
                    ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
                    ItemRefTooltip:SetHyperlink("spell:" .. spellId)
                    ItemRefTooltip:Show()
                    return
                end
            end
        end
        return oldSetHyperlink(self, link, ...)
    end
    
    -- Quality color codes
    local qualityColorCodes = {
        [0] = "ffffff",  -- Common
        [1] = "19ff19",  -- Uncommon
        [2] = "4db3ff",  -- Rare
        [3] = "cc66ff",  -- Epic
        [4] = "ff8000"   -- Legendary
    }
    
    -- Chat message filter to convert echo markers to hyperlinks
    local function EchoLinkFilter(self, event, msg, ...)
        if msg and msg:find("{echo:") then
            -- Replace {echo:spellId:quality} with colored hyperlink
            msg = msg:gsub("{echo:(%d+):(%d+)}", function(spellId, quality)
                spellId = tonumber(spellId)
                quality = tonumber(quality) or 0
                local spellName = GetSpellInfo(spellId)
                if spellName then
                    local colorCode = qualityColorCodes[quality] or "ffffff"
                    return "|cff" .. colorCode .. "|Hecho:" .. spellId .. "|h[" .. spellName .. "]|h|r"
                end
                return "{echo:" .. spellId .. ":" .. quality .. "}"
            end)
            return false, msg, ...
        end
        return false
    end
    
    -- Register filter for all chat types
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", EchoLinkFilter)
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", EchoLinkFilter)
end

SetupEchoLinkHandler()

local browserFrame = nil
local searchBox = nil
local perkButtons = {}
local currentFilter = -1 -- -1 = All, 0-3 = Quality levels
local currentSearchText = ""
local showOnlyPlayerClass = false
local scrollFrame = nil
local scrollChild = nil

local PERKS_PER_ROW = 6
local PERK_BUTTON_SIZE = 51
local PERK_BUTTON_SPACING = 16
local PERK_NAME_HEIGHT = 24  -- Height for 2 lines of text

-- Quality colors matching the perk system
local qualityColors = {
    [0] = { r = 1.0, g = 1.0, b = 1.0 },    -- Common (White)
    [1] = { r = 0.1, g = 1.0, b = 0.1 },    -- Uncommon (Green)
    [2] = { r = 0.3, g = 0.7, b = 1.0 },    -- Rare (Bright Blue)
    [3] = { r = 0.8, g = 0.4, b = 1.0 },    -- Epic (Bright Purple)
    [4] = { r = 1.0, g = 0.5, b = 0.0 }     -- Legendary (Orange)
}

-- Get player's class mask
local function GetPlayerClassMask()
    local classToMask = {
        ["WARRIOR"] = 1,
        ["PALADIN"] = 2,
        ["HUNTER"] = 4,
        ["ROGUE"] = 8,
        ["PRIEST"] = 16,
        ["DEATHKNIGHT"] = 32,
        ["SHAMAN"] = 64,
        ["MAGE"] = 128,
        ["WARLOCK"] = 256,
        ["DRUID"] = 1024
    }
    
    local _, class = UnitClass("player")
    return classToMask[class] or 0
 end

-- Filter perks based on quality, search text, and optionally class
local function FilterPerks()
    local filtered = {}
    local playerClassMask = GetPlayerClassMask()
    
    for spellId, data in pairs(ProjectEbonhold.PerkDatabase) do
        local matchesQuality = (currentFilter == -1) or (data.quality == currentFilter)
        
        local matchesSearch = true
        if currentSearchText ~= "" then
            local spellName = GetSpellInfo(spellId)
            if spellName then
                matchesSearch = string.find(string.lower(spellName), string.lower(currentSearchText)) ~= nil
            else
                matchesSearch = false
            end
            
            -- Also search in comment if name doesn't match
            if not matchesSearch and data.comment then
                matchesSearch = string.find(string.lower(data.comment), string.lower(currentSearchText)) ~= nil
            end
        end
        
        local matchesClass = true
        if showOnlyPlayerClass then
            matchesClass = ProjectEbonhold.IsPerkAvailableForClass(spellId, playerClassMask)
        end
        
        if matchesQuality and matchesSearch and matchesClass then
            table.insert(filtered, {
                spellId = spellId,
                data = data
            })
        end
    end
    
    -- Sort by quality (descending) then by spell name
    table.sort(filtered, function(a, b)
        if a.data.quality ~= b.data.quality then
            return a.data.quality > b.data.quality
        end
        local nameA = GetSpellInfo(a.spellId) or ""
        local nameB = GetSpellInfo(b.spellId) or ""
        return nameA < nameB
    end)
    
    return filtered
end

-- Create a perk button
local function CreatePerkButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(PERK_BUTTON_SIZE, PERK_BUTTON_SIZE + PERK_NAME_HEIGHT)
    
    -- Border frame
    local borderFrame = CreateFrame("Frame", nil, button)
    borderFrame:SetSize(PERK_BUTTON_SIZE + 6, PERK_BUTTON_SIZE + 6)
    borderFrame:SetPoint("TOP", button, "TOP", 0, -3)
    borderFrame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    borderFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    button.borderFrame = borderFrame
    
    -- Icon (centered within border)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(PERK_BUTTON_SIZE, PERK_BUTTON_SIZE)
    icon:SetPoint("CENTER", borderFrame, "CENTER", 0, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.icon = icon
    
    -- Stack text
    local stackText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stackText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    stackText:SetTextColor(1, 1, 1)
    stackText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    button.stackText = stackText
    
    -- Name text
    local nameText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("TOP", icon, "BOTTOM", 0, -2)
    nameText:SetWidth(PERK_BUTTON_SIZE + 10)
    nameText:SetHeight(PERK_NAME_HEIGHT)
    nameText:SetJustifyH("CENTER")
    nameText:SetJustifyV("TOP")
    nameText:SetWordWrap(true)
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 9)
    button.nameText = nameText
    
    -- Highlight
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetSize(PERK_BUTTON_SIZE, PERK_BUTTON_SIZE)
    highlight:SetPoint("CENTER", icon, "CENTER", 0, 0)
    
    -- Tome indicator (for perks that require a spell to be learned)
    local tomeIcon = button:CreateTexture(nil, "OVERLAY")
    tomeIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
    tomeIcon:SetSize(20, 20)
    tomeIcon:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    tomeIcon:Hide()
    button.tomeIcon = tomeIcon
    
    -- Owned indicator (checkmark for perks the player currently has)
    local ownedIcon = button:CreateTexture(nil, "OVERLAY")
    ownedIcon:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    ownedIcon:SetSize(20, 20)
    ownedIcon:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 2, 2)
    ownedIcon:SetVertexColor(0, 1, 0, 1) -- Green tint
    ownedIcon:Hide()
    button.ownedIcon = ownedIcon
    
    -- Tooltip
    button:SetScript("OnEnter", function(self)
        if self.spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            
            -- Show spell name
            local spellName = GetSpellInfo(self.spellId)
            if spellName then
                local color = qualityColors[self.perkData.quality] or qualityColors[0]
                GameTooltip:AddLine(spellName, color.r, color.g, color.b)
            end
            
            -- Show computed description using utils
            if utils and utils.GetSpellDescription then
                local description = utils.GetSpellDescription(self.spellId, 200, self.perkData.maxStack)
                GameTooltip:AddLine(description, 1, 1, 1, true)
            else
                GameTooltip:SetHyperlink("spell:" .. self.spellId)
            end
            
            if self.perkData then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Max Stack: " .. self.perkData.maxStack, 1, 1, 1)
                
                -- Show tome requirement
                if self.perkData.requiredSpell and self.perkData.requiredSpell ~= 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Requires Tome to unlock", 1, 0.82, 0)
                end
                
                -- Dev mode hint
                if utils.IsDevRealm() then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cffFF6600Left-click to add stack (DEV)|r", 1, 1, 1, true)
                end
            end
            
            GameTooltip:Show()
        end
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Click handler for Shift+Click to link in chat + Dev mode left-click to add
    button:SetScript("OnClick", function(self, mouseButton)
        -- Shift+Click to link in chat
        if IsShiftKeyDown() and self.spellId and mouseButton == "LeftButton" then
            local spellName = GetSpellInfo(self.spellId)
            if spellName and self.perkData then
                -- Find active chat edit box
                local editBox = ChatFrameEditBox
                if not editBox or not editBox:IsShown() then
                    editBox = ChatFrame1EditBox
                end
                
                if editBox and editBox:IsShown() then
                    -- Insert echo marker that will be converted to hyperlink client-side
                    local marker = "{echo:" .. self.spellId .. ":" .. self.perkData.quality .. "}"
                    editBox:Insert(marker)
                else
                    -- Open chat if not open
                    ChatFrame_OpenChat("")
                    C_Timer.After(0.1, function()
                        local eb = ChatFrame1EditBox
                        if eb then
                            local marker = "{echo:" .. self.spellId .. ":" .. self.perkData.quality .. "}"
                            eb:Insert(marker)
                        end
                    end)
                end
            end
        -- Dev mode: Left-click (without shift) to add perk stack
        elseif utils.IsDevRealm() and not IsShiftKeyDown() and mouseButton == "LeftButton" and self.spellId and self.perkData then
            if ProjectEbonhold and ProjectEbonhold.sendToServer and ProjectEbonhold.CS then
                ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_DEV_ADD_PERK_STACK, tostring(self.spellId))
            end
        end
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    return button
end

-- Update the perk grid display
local function UpdatePerkGrid()
    local filteredPerks = FilterPerks()
    
    -- Create buttons if needed
    while #perkButtons < #filteredPerks do
        table.insert(perkButtons, CreatePerkButton(scrollChild))
    end
    
    -- Update existing buttons
    for i, button in ipairs(perkButtons) do
        if i <= #filteredPerks then
            local perk = filteredPerks[i]
            local spellId = perk.spellId
            local data = perk.data
            
            button.spellId = spellId
            button.perkData = data
            
            -- Set icon
            local spellName, _, spellIcon = GetSpellInfo(spellId)
            if spellIcon then
                button.icon:SetTexture(spellIcon)
            else
                button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            
            -- Set stack text
            if data.maxStack > 1 then
                button.stackText:SetText("x" .. data.maxStack)
                button.stackText:Show()
            else
                button.stackText:Hide()
            end
            
            -- Show tome icon if required spell exists
            if data.requiredSpell and data.requiredSpell ~= 0 then
                button.tomeIcon:Show()
            else
                button.tomeIcon:Hide()
            end
            
            -- Show owned icon if player has this perk (with matching quality)
            local playerHasPerk = false
            local Perks = addon and addon.Perks
            if Perks then
                -- Check granted perks (must match both spell name and quality)
                if spellName and Perks.grantedPerks and Perks.grantedPerks[spellName] then
                    for _, instance in ipairs(Perks.grantedPerks[spellName]) do
                        if instance.quality == data.quality then
                            playerHasPerk = true
                            break
                        end
                    end
                end
                -- Check locked perks (must match both spellId and quality)
                if not playerHasPerk and Perks.lockedPerks then
                    for _, lockedPerk in ipairs(Perks.lockedPerks) do
                        if lockedPerk.spellId == spellId and lockedPerk.quality == data.quality then
                            playerHasPerk = true
                            break
                        end
                    end
                end
            end
            if playerHasPerk then
                button.ownedIcon:Show()
            else
                button.ownedIcon:Hide()
            end
            
            -- Set name with quality color
            local color = qualityColors[data.quality] or qualityColors[0]
            button.nameText:SetText(spellName or "Unknown")
            button.nameText:SetTextColor(color.r, color.g, color.b)
            
            -- Set border color based on quality
            button.borderFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
            
            -- Position button in grid
            local row = math.floor((i - 1) / PERKS_PER_ROW)
            local col = (i - 1) % PERKS_PER_ROW
            
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 
                10 + col * (PERK_BUTTON_SIZE + PERK_BUTTON_SPACING),
                -10 - row * (PERK_BUTTON_SIZE + PERK_NAME_HEIGHT + PERK_BUTTON_SPACING))
            
            button:Show()
        else
            button:Hide()
        end
    end
    
    -- Update scroll child height
    local numRows = math.ceil(#filteredPerks / PERKS_PER_ROW)
    local contentHeight = numRows * (PERK_BUTTON_SIZE + PERK_NAME_HEIGHT + PERK_BUTTON_SPACING) + 25
    scrollChild:SetHeight(math.max(contentHeight, 450))
end

-- Create the main browser frame
local function CreateBrowserFrame()
    browserFrame = CreateFrame("Frame", "PerkBrowserFrame", UIParent)
    browserFrame:SetSize(470, 600)
    browserFrame:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    browserFrame:SetFrameStrata("HIGH")
    browserFrame:EnableMouse(true)
    browserFrame:SetMovable(true)
    browserFrame:RegisterForDrag("LeftButton")
    browserFrame:SetScript("OnDragStart", browserFrame.StartMoving)
    browserFrame:SetScript("OnDragStop", browserFrame.StopMovingOrSizing)
    browserFrame:Hide()
    
    -- Background
    browserFrame:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    
    -- Background texture (matching Skill Tree)
    local bgTexture = browserFrame:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\UI-Background-Rock")
    bgTexture:SetPoint("TOPLEFT", browserFrame, "TOPLEFT", 8, -8)
    bgTexture:SetPoint("BOTTOMRIGHT", browserFrame, "BOTTOMRIGHT", -8, 8)
    bgTexture:SetHorizTile(true)
    bgTexture:SetVertTile(true)
    
    -- Title
    local title = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", browserFrame, "TOP", 0, -15)
    title:SetText("Echoes Browser")
    
    -- Dev mode indicator and instructions
    local searchBoxTopOffset = -50
    if utils.IsDevRealm() then
        local devLabel = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        devLabel:SetPoint("TOP", title, "BOTTOM", 0, -5)
        devLabel:SetText("|cffFF6600[DEV MODE]|r")
        devLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        
        -- Dev mode instructions
        local devInstructions = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        devInstructions:SetPoint("TOP", devLabel, "BOTTOM", 0, -2)
        devInstructions:SetText("|cffFF9933Left-click echoes to add stack|r")
        devInstructions:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        
        searchBoxTopOffset = -70  -- Extra space for dev mode labels
    end
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, browserFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", browserFrame, "TOPRIGHT", -5, -5)
    
    -- Search box
    searchBox = CreateFrame("EditBox", nil, browserFrame, "InputBoxTemplate")
    searchBox:SetSize(240, 30)
    searchBox:SetPoint("TOPLEFT", browserFrame, "TOPLEFT", 30, searchBoxTopOffset)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(50)
    searchBox:SetScript("OnTextChanged", function(self)
        currentSearchText = self:GetText()
        UpdatePerkGrid()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    
    local searchLabel = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", 0, 5)
    searchLabel:SetText("Search:")
    
    -- Class filter checkbox
    local classCheckbox = CreateFrame("CheckButton", nil, browserFrame, "UICheckButtonTemplate")
    classCheckbox:SetSize(24, 24)
    classCheckbox:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    classCheckbox:SetChecked(false)
    classCheckbox:SetScript("OnClick", function(self)
        showOnlyPlayerClass = self:GetChecked()
        UpdatePerkGrid()
    end)
    
    local classCheckLabel = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    classCheckLabel:SetPoint("LEFT", classCheckbox, "RIGHT", 5, 0)
    classCheckLabel:SetText("My Class Only")
    classCheckLabel:SetTextColor(1.0, 1.0, 1.0)
    
    -- Quality filter buttons
    local filterLabels = {
        [-1] = "All",
        [0] = "Common",
        [1] = "Uncommon",
        [2] = "Rare",
        [3] = "Epic"
    }
    
    local filterButtons = {}
    local filterX = 20
    local filterButtonsTopOffset = utils.IsDevRealm() and -110 or -90
    
    for quality = -1, 3 do
        local btn = CreateFrame("Button", nil, browserFrame)
        btn:SetSize(80, 25)
        btn:SetPoint("TOPLEFT", browserFrame, "TOPLEFT", filterX, filterButtonsTopOffset)
        
        local btnBg = btn:CreateTexture(nil, "BACKGROUND")
        btnBg:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        btnBg:SetTexCoord(0, 0.625, 0, 0.6875)
        btnBg:SetAllPoints()
        btn:SetNormalTexture(btnBg)
        
        local btnHighlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btnHighlight:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        btnHighlight:SetTexCoord(0, 0.625, 0, 0.6875)
        btnHighlight:SetAllPoints()
        btnHighlight:SetBlendMode("ADD")
        
        -- Create font string WITHOUT template to avoid color override
        local btnText = btn:CreateFontString(nil, "OVERLAY")
        btnText:SetFont("Fonts\\FRIZQT__.TTF", 10)
        btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btnText:SetText(filterLabels[quality])
        
        -- Apply quality colors to button text - MUST be after SetFont
        if quality == -1 then
            btnText:SetTextColor(1.0, 1.0, 1.0)  -- White for "All"
        elseif quality == 0 then
            btnText:SetTextColor(1.0, 1.0, 1.0)  -- Common (White)
        elseif quality == 1 then
            btnText:SetTextColor(0.1, 1.0, 0.1)  -- Uncommon (Green)
        elseif quality == 2 then
            btnText:SetTextColor(0.3, 0.7, 1.0)  -- Rare (Bright Blue)
        elseif quality == 3 then
            btnText:SetTextColor(0.8, 0.4, 1.0)  -- Epic (Bright Purple)
        end
        btn.text = btnText
        
        btn.quality = quality
        btn:SetScript("OnClick", function(self)
            currentFilter = self.quality
            UpdatePerkGrid()
            
            -- Update button states
            for _, b in pairs(filterButtons) do
                if b.quality == currentFilter then
                    b:SetAlpha(1.0)
                else
                    b:SetAlpha(0.6)
                end
            end
        end)
        
        filterButtons[quality] = btn
        filterX = filterX + 85
    end
    
    -- Set initial filter state
    filterButtons[-1]:SetAlpha(1.0)
    for i = 0, 3 do
        filterButtons[i]:SetAlpha(0.6)
    end
    
    -- Scroll frame
    local scrollFrameTopOffset = utils.IsDevRealm() and -145 or -125
    scrollFrame = CreateFrame("ScrollFrame", "PerkBrowserScrollFrame", browserFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", browserFrame, "TOPLEFT", 25, scrollFrameTopOffset)
    scrollFrame:SetPoint("BOTTOMRIGHT", browserFrame, "BOTTOMRIGHT", -42, 15)
    
    scrollChild = CreateFrame("Frame", "PerkBrowserScrollChild", scrollFrame)
    scrollChild:SetSize(390, 450)
    scrollFrame:SetScrollChild(scrollChild)
end

-- Show the perk browser
function ProjectEbonhold.PerkBrowser.Show()
    if not browserFrame then
        CreateBrowserFrame()
    end
    
    UpdatePerkGrid()
    browserFrame:Show()
end

-- Hide the perk browser
function ProjectEbonhold.PerkBrowser.Hide()
    if browserFrame then
        browserFrame:Hide()
    end
end

-- Toggle the perk browser
function ProjectEbonhold.PerkBrowser.Toggle()
    if browserFrame and browserFrame:IsShown() then
        ProjectEbonhold.PerkBrowser.Hide()
    else
        ProjectEbonhold.PerkBrowser.Show()
    end
end

-- Slash command
SLASH_PERKBROWSER1 = "/echoes"
SlashCmdList["PERKBROWSER"] = function()
    ProjectEbonhold.PerkBrowser.Toggle()
end
