local addonName, addon = ...






local UITexts = ProjectEbonhold.UITexts


local playerRunFrame = nil
local empowermentFrame = nil
local currentData = {}
local isCollapsed = false
local isEmpowermentCollapsed = false
local intensityButton = nil


local qualityInfo =
{
    [0] = { name = "Common", color = { 1, 1, 1 }, border = 0 },
    [1] = { name = "Uncommon", color = { 0.1, 1.0, 0.1 }, border = 1 },
    [2] = { name = "Rare", color = { 0.0, 0.4, 1.0 }, border = 2 },
    [3] = { name = "Epic", color = { 0.6, 0.2, 1.0 }, border = 3 },
    [4] = { name = "Legendary", color = { 1.0, 0.5, 0.0 }, border = 4 }
}

WatchFrame:SetScript("OnUpdate", function(self)
    if ProjectEbonhold_IsClosing then return end
    if not UIParent:IsShown() then return end
    WatchFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -420)
end)

local function CreatePlayerRunFrame()
    if playerRunFrame then return playerRunFrame end

    playerRunFrame = CreateFrame("Frame", "ProjectEbonholdPlayerRunFrame",
        UIParent)
    playerRunFrame:SetSize(250, 150)
    playerRunFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -90, -200)
    playerRunFrame:SetFrameStrata("MEDIUM")
    playerRunFrame:SetMovable(true)
    playerRunFrame:EnableMouse(true)
    playerRunFrame:SetClampedToScreen(true)
    playerRunFrame:RegisterForDrag("LeftButton")
    playerRunFrame:SetScript("OnDragStart", playerRunFrame.StartMoving)
    playerRunFrame:SetScript("OnDragStop", playerRunFrame.StopMovingOrSizing)

    local headerFrame = CreateFrame("Frame", nil, playerRunFrame)
    headerFrame:SetSize(220, 70)
    headerFrame:SetPoint("TOP", playerRunFrame, "TOP", 0, 0)

    local headerTexture = headerFrame:CreateTexture(nil, "BACKGROUND")
    headerTexture:SetTexture(
        "Interface\\AddOns\\ProjectEbonhold\\assets\\texture_ui")
    headerTexture:SetTexCoord(0.023438, 0.960938, 0.015625, 0.304688)
    headerTexture:SetAllPoints(headerFrame)


    local soulAshIcon = headerFrame:CreateTexture(nil, "OVERLAY")
    soulAshIcon:SetSize(16, 16)
    soulAshIcon:SetTexture("Interface\\Icons\\inv_soulash")
    soulAshIcon:SetPoint("CENTER", headerFrame, "CENTER", -90, -15)
    playerRunFrame.soulAshIcon = soulAshIcon


    local soulPointsText = headerFrame:CreateFontString(nil, "OVERLAY",
        "GameFontNormal")
    soulPointsText:SetPoint("LEFT", soulAshIcon, "RIGHT", 8, 0)
    soulPointsText:SetText("0")
    playerRunFrame.soulPointsText = soulPointsText


    local multiplierText = headerFrame:CreateFontString(nil, "OVERLAY",
        "GameFontNormal")
    multiplierText:SetPoint("LEFT", headerFrame, "LEFT", 110, -15)
    multiplierText:SetText("|cff00ff00+0%|r")
    playerRunFrame.multiplierText = multiplierText


    local spHitbox = CreateFrame("Button", nil, headerFrame)
    spHitbox:SetPoint("LEFT", soulAshIcon, "LEFT", -5, 0)
    spHitbox:SetPoint("RIGHT", soulPointsText, "RIGHT", 5, 0)
    spHitbox:SetHeight(30)
    spHitbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local sp = playerRunFrame.currentSoulPoints or 0
        GameTooltip:SetText(UITexts.tooltips.soulPoints.title(sp), 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(UITexts.tooltips.soulPoints.line, nil, nil, nil,
            true)
        GameTooltip:Show()
    end)
    spHitbox:SetScript("OnLeave", function(self) GameTooltip:Hide() end)


    local multiplierHitbox = CreateFrame("Button", nil, headerFrame)
    multiplierHitbox:SetPoint("LEFT", multiplierText, "LEFT", -5, 0)
    multiplierHitbox:SetPoint("RIGHT", multiplierText, "RIGHT", 5, 0)
    multiplierHitbox:SetHeight(30)
    multiplierHitbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local multiplier = playerRunFrame.currentMultiplier or 0
        GameTooltip:SetText(UITexts.tooltips.multiplier.title(multiplier), 0, 1,
            0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(UITexts.tooltips.multiplier.line, nil, nil, nil,
            true)
        GameTooltip:Show()
    end)
    multiplierHitbox:SetScript("OnLeave", function(self) GameTooltip:Hide() end)


    local reaperIcon = headerFrame:CreateTexture(nil, "OVERLAY")
    reaperIcon:SetSize(24, 24)
    reaperIcon:SetTexture(
        "Interface\\AddOns\\ProjectEbonhold\\assets\\texture_ui")
    reaperIcon:SetTexCoord(0.121094, 0.214844, 0.898438, 0.996094)
    reaperIcon:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -10, -10)
    playerRunFrame.reaperIcon = reaperIcon


    local reaperHitbox = CreateFrame("Button", nil, headerFrame)
    reaperHitbox:SetPoint("CENTER", reaperIcon, "CENTER", 0, 0)
    reaperHitbox:SetSize(25, 25)
    reaperHitbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local data = _G["EbonholdIntensityData"] or {}
        local areaName = data.areaNameReaper or "0"
        GameTooltip:SetText(UITexts.tooltips.reaper.title, 1, 0.5, 0.5)
        GameTooltip:AddLine(" ")

        if areaName ~= "0" then
            GameTooltip:AddLine(UITexts.tooltips.reaper.spawned(areaName), 1, 1,
                1, true)
        else
            GameTooltip:AddLine(UITexts.tooltips.reaper.notSpawned, 0.7, 0.7,
                0.7, true)
        end

        GameTooltip:Show()
    end)
    reaperHitbox:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    playerRunFrame.reaperHitbox = reaperHitbox


    local hearthIcon = headerFrame:CreateTexture(nil, "OVERLAY")
    hearthIcon:SetSize(22, 24)
    hearthIcon:SetTexture(
        "Interface\\AddOns\\ProjectEbonhold\\assets\\texture_ui")
    hearthIcon:SetTexCoord(0.316406, 0.398438, 0.898438, 0.988281)
    hearthIcon:SetPoint("TOPRIGHT", reaperIcon, "TOPLEFT", -5, 0)
    playerRunFrame.hearthIcon = hearthIcon


    local hearthHitbox = CreateFrame("Button", nil, headerFrame)
    hearthHitbox:SetPoint("CENTER", hearthIcon, "CENTER", 0, 0)
    hearthHitbox:SetSize(25, 25)
    hearthHitbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local data = playerRunFrame.currentData or {}
        local playerLevel = UnitLevel("player")

        GameTooltip:SetText(UITexts.tooltips.survival.title, 1, 1, 0.5)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(UITexts.tooltips.survival.playerRezs ..
            (data.countCanAcceptedRezs or 0), 1, 1, 1)
        GameTooltip:AddLine(UITexts.tooltips.survival.freeRezs ..
            (data.countCanSelfRezs or 0), 1, 1, 1)
        GameTooltip:AddLine(UITexts.tooltips.survival.classRezs ..
            (data.countCanClassRezs or 0), 1, 1, 1)
        GameTooltip:AddLine(UITexts.tooltips.survival.cheatDeath ..
            (data.countCanAvoidFatalAttacks or 0), 1, 1, 1)
        GameTooltip:AddLine(UITexts.tooltips.survival.nextRezCost ..
            (math.max(playerLevel, data.costNextReset or 0)) ..
            UITexts.tooltips.survival.nextCost, 1, 1, 1)
        GameTooltip:Show()
    end)
    hearthHitbox:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
    playerRunFrame.hearthHitbox = hearthHitbox


    local intensityFrame = CreateFrame("Frame", nil, playerRunFrame)
    intensityFrame:SetSize(220, 50)
    intensityFrame:SetPoint("TOP", headerFrame, "BOTTOM", 0, 0)


    local intensityFill = intensityFrame:CreateTexture(nil, "BACKGROUND")
    intensityFill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    intensityFill:SetPoint("LEFT", intensityFrame, "LEFT", 20, -8)
    intensityFill:SetHeight(18)
    intensityFill:SetVertexColor(0.8, 0.1, 0.1, 0.8)
    playerRunFrame.intensityFill = intensityFill


    local intensityBg = intensityFrame:CreateTexture(nil, "BORDER")
    intensityBg:SetTexture(
        "Interface\\AddOns\\ProjectEbonhold\\assets\\texture_ui")
    intensityBg:SetTexCoord(0.019531, 0.964844, 0.312500, 0.515625)
    intensityBg:SetAllPoints(intensityFrame)


    local intensityIndicator = intensityFrame:CreateTexture(nil, "OVERLAY")
    intensityIndicator:SetTexture(
        "Interface\\AddOns\\ProjectEbonhold\\assets\\texture_ui")
    intensityIndicator:SetTexCoord(0.023438, 0.109375, 0.890625, 0.992188)
    intensityIndicator:SetSize(25, 30)
    intensityIndicator:SetPoint("LEFT", intensityFrame, "LEFT", 10, 0)
    playerRunFrame.intensityIndicator = intensityIndicator

    -- Circle with intensity level
    local intensityLevelCircle = CreateFrame("Frame", nil, intensityFrame)
    intensityLevelCircle:SetSize(20, 20)
    intensityLevelCircle:SetPoint("CENTER", intensityIndicator, "CENTER", 0, 10)
    intensityLevelCircle:SetFrameLevel(intensityFrame:GetFrameLevel() + 2)

    local circleBg = intensityLevelCircle:CreateTexture(nil, "BACKGROUND")
    circleBg:SetAllPoints()
    circleBg:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\roundborder")
    circleBg:SetVertexColor(0.1, 0.1, 0.1, 0.9)

    local levelText = intensityLevelCircle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("CENTER", intensityLevelCircle, "CENTER", 0, 0)
    levelText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    levelText:SetTextColor(1, 0.2, 0.2)
    levelText:SetText("0")

    playerRunFrame.intensityLevelCircle = intensityLevelCircle
    playerRunFrame.intensityLevelText = levelText


    local intensityFillFlash = intensityFrame:CreateTexture(nil, "OVERLAY")
    intensityFillFlash:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    intensityFillFlash:SetPoint("LEFT", intensityFrame, "LEFT", 20, -8)
    intensityFillFlash:SetHeight(18)
    intensityFillFlash:SetVertexColor(1, 0.5, 0.5, 1)
    intensityFillFlash:SetBlendMode("ADD")
    intensityFillFlash:SetAlpha(0)
    playerRunFrame.intensityFillFlash = intensityFillFlash


    local ag = intensityFillFlash:CreateAnimationGroup()
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetChange(0.8)
    a1:SetDuration(0.1)
    a1:SetOrder(1)
    a1:SetSmoothing("OUT")

    local a2 = ag:CreateAnimation("Alpha")
    a2:SetChange(-0.8)
    a2:SetDuration(0.3)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    playerRunFrame.intensityFillFlashAnim = ag
    playerRunFrame.intensityFrame = intensityFrame


    intensityFrame:EnableMouse(true)
    intensityFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")


        local intensityData = _G["EbonholdIntensityData"] or {}
        local intensity = intensityData.intensity or 0

        GameTooltip:SetText(UITexts.tooltips.intensity.title(intensity), 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(UITexts.tooltips.intensity.description1, nil, nil,
            nil, true)
        GameTooltip:AddLine(UITexts.tooltips.intensity.description2, nil, nil,
            nil, true)
        GameTooltip:AddLine(UITexts.tooltips.intensity.description3, nil, nil,
            nil, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(UITexts.tooltips.intensity.warning, 1, 0, 0, true)
        GameTooltip:Show()
    end)

    intensityFrame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- Intensity level icons (negative effects)
    local intensityEffects = ProjectEbonhold.IntensityEffects or {}
    local iconSize = 32
    local iconSpacing = 8
    local totalIconsWidth = (iconSize * 5) + (iconSpacing * 4)
    local startX = (220 - totalIconsWidth) / 2
    
    playerRunFrame.intensityIcons = {}
    
    for i = 1, 5 do
        local effectData = intensityEffects[i]
        local iconFrame = CreateFrame("Button", nil, playerRunFrame)
        iconFrame:SetSize(iconSize, iconSize)
        iconFrame:SetPoint("TOPLEFT", intensityFrame, "BOTTOMLEFT", startX + ((i - 1) * (iconSize + iconSpacing)), -8)
        
        -- Border frame
        local borderFrame = CreateFrame("Frame", nil, iconFrame)
        borderFrame:SetAllPoints()
        borderFrame:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 6,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        borderFrame:SetBackdropBorderColor(1, 0, 0, 1)
        
        -- Icon texture
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize - 4, iconSize - 4)
        icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        if effectData and effectData.icon then
            icon:SetTexture(effectData.icon)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        else
            icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
        iconFrame.icon = icon
        
        -- Fire glow effect (hidden by default)
        local glow = iconFrame:CreateTexture(nil, "OVERLAY")
        glow:SetSize(iconSize * 1.5, iconSize * 1.5)
        glow:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        glow:SetTexture("Interface\\Cooldown\\star4")
        glow:SetVertexColor(1, 0.3, 0, 1)
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0)
        iconFrame.glow = glow
        
        -- Glow animation
        local glowAnim = glow:CreateAnimationGroup()
        local a1 = glowAnim:CreateAnimation("Alpha")
        a1:SetChange(0.8)
        a1:SetDuration(0.3)
        a1:SetOrder(1)
        a1:SetSmoothing("OUT")
        
        local a2 = glowAnim:CreateAnimation("Alpha")
        a2:SetChange(-0.8)
        a2:SetDuration(0.5)
        a2:SetOrder(2)
        a2:SetSmoothing("IN")
        iconFrame.glowAnim = glowAnim
        
        -- Start desaturated (disabled)
        icon:SetDesaturated(true)
        iconFrame.level = i
        iconFrame.effectData = effectData
        iconFrame.wasActive = false
        
        -- Tooltip
        iconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local isActive = self.icon and not self.icon:IsDesaturated()
            
            if self.effectData then
                if isActive then
                    GameTooltip:SetText(self.effectData.name, 1, 0.2, 0.2)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(self.effectData.description, 1, 1, 1, true)
                else
                    GameTooltip:SetText(self.effectData.name, 0.5, 0.5, 0.5)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(self.effectData.description, 0.6, 0.6, 0.6, true)
                end
            else
                GameTooltip:SetText("Intensity " .. self.level, 1, 0.2, 0.2)
            end
            GameTooltip:Show()
        end)
        iconFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        table.insert(playerRunFrame.intensityIcons, iconFrame)
    end

    local empowermentHeader = CreateFrame("Button", nil, playerRunFrame)
    empowermentHeader:SetSize(230, 50)
    empowermentHeader:SetPoint("TOP", intensityFrame, "BOTTOM", 0, -48)

    local empowermentTexture =
        empowermentHeader:CreateTexture(nil, "BACKGROUND")
    empowermentTexture:SetTexture(
        "Interface\\AddOns\\ProjectEbonhold\\assets\\texture_ui")
    empowermentTexture:SetTexCoord(0.019531, 0.964844, 0.519531, 0.695312)
    empowermentTexture:SetAllPoints(empowermentHeader)
    empowermentHeader.texture = empowermentTexture

    local empowermentText = empowermentHeader:CreateFontString(nil, "OVERLAY",
        "GameFontNormal")
    empowermentText:SetPoint("CENTER", empowermentHeader, "CENTER", 0, 0)
    empowermentText:SetText("Echoes")
    playerRunFrame.empowermentText = empowermentText

    empowermentHeader:SetScript("OnClick",
        function() ToggleEmpowermentPanel() end)
    playerRunFrame.empowermentHeader = empowermentHeader

    playerRunFrame:Show()

    return playerRunFrame
end


local function CreateEmpowermentFrame()
    if empowermentFrame then return empowermentFrame end


    empowermentFrame = CreateFrame("Frame", "ProjectEbonholdEmpowermentFrame",
        UIParent)
    empowermentFrame:SetSize(240, 500)

    empowermentFrame:SetPoint("RIGHT", playerRunFrame.empowermentHeader, "LEFT",
        -10, -20)
    empowermentFrame:SetFrameStrata("DIALOG")
    empowermentFrame:SetMovable(true)
    empowermentFrame:EnableMouse(true)
    empowermentFrame:SetClampedToScreen(true)
    empowermentFrame:RegisterForDrag("LeftButton")
    empowermentFrame:SetScript("OnDragStart", empowermentFrame.StartMoving)
    empowermentFrame:SetScript("OnDragStop", empowermentFrame.StopMovingOrSizing)


    empowermentFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    empowermentFrame:SetBackdropColor(0, 0, 0, 0.9)


    local titleFrame = CreateFrame("Frame", nil, empowermentFrame)
    titleFrame:SetSize(210, 20)
    titleFrame:SetPoint("TOP", empowermentFrame, "TOP", 0, -15)

    local title = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", titleFrame, "CENTER", 0, 0)
    title:SetText("Echoes")
    empowermentFrame.title = title


    local gridContainer = CreateFrame("Frame", nil, empowermentFrame)
    gridContainer:SetSize(210, 350)
    gridContainer:SetPoint("TOP", titleFrame, "BOTTOM", 0, -10)
    empowermentFrame.gridContainer = gridContainer
    empowermentFrame.perkIcons = {}


    isEmpowermentCollapsed = true
    empowermentFrame:Hide()

    return empowermentFrame
end


function ToggleEmpowermentPanel()
    if not empowermentFrame then CreateEmpowermentFrame() end

    isEmpowermentCollapsed = not isEmpowermentCollapsed

    if isEmpowermentCollapsed then
        empowermentFrame:Hide()

        if playerRunFrame.empowermentHeader then
            playerRunFrame.empowermentHeader.texture:SetTexCoord(0.019531,
                0.964844,
                0.519531,
                0.695312)
        end
    else
        empowermentFrame:Show()

        if playerRunFrame.empowermentHeader then
            playerRunFrame.empowermentHeader.texture:SetTexCoord(0.015625,
                0.964844,
                0.703125,
                0.882812)
        end
    end
end

local perkSelectorFrame = nil
local function ShowPerkSelectorForLocking(perksData, slotIndex)
    if perkSelectorFrame and perkSelectorFrame:IsShown() then
        return
    end


    local availablePerks = {}
    local uniquePerks = {}

    for spellName, instances in pairs(perksData or {}) do
        for _, instance in ipairs(instances) do
            local uniqueKey = instance.spellId .. "_" .. instance.quality


            if not uniquePerks[uniqueKey] then
                uniquePerks[uniqueKey] = true
                table.insert(availablePerks, {
                    spellName = spellName,
                    spellId = instance.spellId,
                    quality = instance.quality

                })
            end
        end
    end

    if #availablePerks == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFF0000You don't have any echoes to lock!|r")
        return
    end


    table.sort(availablePerks, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.spellName < b.spellName
    end)


    if perkSelectorFrame then
        local children = { perkSelectorFrame:GetChildren() }
        for _, child in ipairs(children) do
            child:Hide()
            child:SetParent(nil)
        end
        perkSelectorFrame:Hide()
        perkSelectorFrame:SetParent(nil)
        perkSelectorFrame = nil
    end


    perkSelectorFrame = CreateFrame("Frame", nil, UIParent)
    local selectorFrame = perkSelectorFrame
    selectorFrame:SetSize(300, 400)
    selectorFrame:SetPoint("CENTER")
    selectorFrame:SetFrameStrata("DIALOG")
    selectorFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    selectorFrame:SetBackdropColor(0, 0, 0, 1)
    selectorFrame:EnableMouse(true)
    selectorFrame:SetMovable(true)
    selectorFrame:RegisterForDrag("LeftButton")
    selectorFrame:SetScript("OnDragStart", selectorFrame.StartMoving)
    selectorFrame:SetScript("OnDragStop", selectorFrame.StopMovingOrSizing)

    selectorFrame.title = selectorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    selectorFrame.title:SetPoint("TOP", selectorFrame, "TOP", 0, -20)
    selectorFrame.title:SetText("Select Echo to Make Permanent")


    local closeButton = CreateFrame("Button", nil, selectorFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", selectorFrame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        selectorFrame:Hide()
    end)


    local uniqueName = "PerkSelectorScrollFrame" .. math.random(1, 999999)
    local scrollFrame = CreateFrame("ScrollFrame", uniqueName, selectorFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", selectorFrame, "TOPLEFT", 10, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", selectorFrame, "BOTTOMRIGHT", -30, 10)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(260, math.max(#availablePerks * 40, 1))
    scrollFrame:SetScrollChild(scrollChild)


    scrollFrame:SetVerticalScroll(0)
    scrollFrame:UpdateScrollChildRect()


    for i, perkInfo in ipairs(availablePerks) do
        local btn = CreateFrame("Button", nil, scrollChild)
        btn:SetSize(260, 36)
        btn:SetPoint("TOP", scrollChild, "TOP", 0, -(i - 1) * 40)


        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(0.1, 0.1, 0.1, 0.5)


        local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetTexture(0.3, 0.3, 0.3, 0.5)


        local qualityData = qualityInfo[perkInfo.quality] or qualityInfo[0]
        local qualityBg = btn:CreateTexture(nil, "BORDER")
        qualityBg:SetSize(36, 36)
        qualityBg:SetPoint("LEFT", btn, "LEFT", 2, 0)
        qualityBg:SetTexture(
            "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_quality_" ..
            qualityData.border)


        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(25, 25)
        icon:SetPoint("CENTER", qualityBg, "CENTER", 0, 0)
        local spellName, _, spellIcon = GetSpellInfo(perkInfo.spellId)
        if spellIcon then
            SetPortraitToTexture(icon, spellIcon)
        end


        local qualityBorder = btn:CreateTexture(nil, "OVERLAY")
        qualityBorder:SetSize(110, 110)
        qualityBorder:SetPoint("CENTER", qualityBg, "CENTER", 0, 1)
        qualityBorder:SetTexture(
            "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_border_quality_" ..
            qualityData.border)


        local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", qualityBg, "RIGHT", 8, 0)
        nameText:SetText(perkInfo.spellName)
        nameText:SetTextColor(unpack(qualityData.color))

        btn:SetScript("OnClick", function()
            if perkInfo.spellId and ProjectEbonhold.PerkService.LockPerk(perkInfo.spellId, 1) then
                selectorFrame:Hide()

                C_Timer.After(0.5, function()
                    if ProjectEbonhold.PerkService.RequestGrantedPerks then
                        ProjectEbonhold.PerkService.RequestGrantedPerks()
                    end
                end)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(perkInfo.spellId)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
end


local function UpdateEmpowermentDisplay(perksData)
    if not empowermentFrame then CreateEmpowermentFrame() end


    if empowermentFrame.permanentSlots then
        for _, slot in ipairs(empowermentFrame.permanentSlots) do
            slot:Hide()
            slot:SetParent(nil)
        end
    end
    empowermentFrame.permanentSlots = {}


    for _, iconFrame in ipairs(empowermentFrame.perkIcons) do
        iconFrame:Hide()
        iconFrame:SetParent(nil)
    end
    empowermentFrame.perkIcons = {}


    local perkCount = 0
    local totalEchoes = 0
    local perkList = {}
    for spellName, instances in pairs(perksData or {}) do
        perkCount = perkCount + 1


        local groupTotalStacks = 0
        local highestQuality = 0
        local primarySpellId = nil

        for _, instance in ipairs(instances) do
            groupTotalStacks = groupTotalStacks + (instance.stack or 1)
            if instance.quality > highestQuality then
                highestQuality = instance.quality
                primarySpellId = instance.spellId
            end
        end

        totalEchoes = totalEchoes + groupTotalStacks
        table.insert(perkList, {
            spellName = spellName,
            spellId = primarySpellId or instances[1].spellId,
            instances = instances,
            totalStacks = groupTotalStacks,
            quality = highestQuality
        })
    end


    if empowermentFrame.title then
        empowermentFrame.title:SetText("Echoes")
    end


    if playerRunFrame and playerRunFrame.empowermentText then
        playerRunFrame.empowermentText:SetText("Echoes")
    end
    empowermentFrame.gridContainer:Show()

    table.sort(perkList, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return a.spellId < b.spellId
    end)

    local lockedPerks = ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetLockedPerks() or {}
    local maxSlots = ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetMaximumPermanentEchoes() or 0

    local permanentSlotsStartY = 12
    if maxSlots > 0 then
        local slotSize = 64
        local slotSpacing = 12
        local totalWidth = (maxSlots * slotSize) + ((maxSlots - 1) * slotSpacing)
        local startX = (200 - totalWidth) / 2

        for i = 1, maxSlots do
            local xOffset = startX + ((i - 1) * (slotSize + slotSpacing))


            local slotFrame = CreateFrame("Button", nil, empowermentFrame.gridContainer)
            slotFrame:SetSize(slotSize, slotSize)
            slotFrame:SetPoint("TOPLEFT", empowermentFrame.gridContainer, "TOPLEFT", xOffset, permanentSlotsStartY)


            local bg = slotFrame:CreateTexture(nil, "BACKGROUND")
            bg:SetSize(slotSize * 1.3, slotSize * 1.3)
            bg:SetPoint("CENTER", slotFrame, "CENTER", 0, -1)
            bg:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\perm_background_texture")


            local rotatingTex = slotFrame:CreateTexture(nil, "ARTWORK")
            rotatingTex:SetSize(slotSize * 1.2, slotSize * 1.2)
            rotatingTex:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
            rotatingTex:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\rotating_perm_texture")
            rotatingTex:SetBlendMode("ADD")


            local animGroup = rotatingTex:CreateAnimationGroup()
            local rotation = animGroup:CreateAnimation("Rotation")
            rotation:SetDegrees(-360)
            rotation:SetDuration(6)
            animGroup:SetLooping("REPEAT")
            animGroup:Play()

            slotFrame.rotatingTex = rotatingTex
            slotFrame.slotIndex = i


            local slotPerk = nil
            local slotIndex = 1
            for spellId, perkData in pairs(lockedPerks) do
                if slotIndex == i then
                    slotPerk = perkData
                    break
                end
                slotIndex = slotIndex + 1
            end


            if slotPerk then
                local qualityBg = slotFrame:CreateTexture(nil, "BORDER")
                qualityBg:SetSize(slotSize * 1.15, slotSize * 1.15)
                qualityBg:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
                local qualityData = qualityInfo[slotPerk.quality or 0] or qualityInfo[0]
                qualityBg:SetTexture(
                    "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_quality_" ..
                    qualityData.border)

                local icon = slotFrame:CreateTexture(nil, "ARTWORK")
                icon:SetSize(slotSize * 0.38, slotSize * 0.38)
                icon:SetPoint("CENTER", slotFrame, "CENTER", 0, 0)
                local spellName, _, spellIcon = GetSpellInfo(slotPerk.spellId)
                if spellIcon then
                    SetPortraitToTexture(icon, spellIcon)
                else
                    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
                slotFrame.icon = icon
                slotFrame.lockedPerkId = slotPerk.spellId


                local qualityBorder = slotFrame:CreateTexture(nil, "OVERLAY", nil, 7)
                qualityBorder:SetSize(slotSize * 1.45, slotSize * 1.45)
                qualityBorder:SetPoint("CENTER", slotFrame, "CENTER", 0, 2)
                qualityBorder:SetTexture(
                    "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_border_quality_" ..
                    qualityData.border)
            end


            slotFrame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if self.lockedPerkId and lockedPerks[i] then
                    local lockedPerkData = lockedPerks[i]
                    local qualityData = qualityInfo[lockedPerkData and lockedPerkData.quality or 0] or qualityInfo[0]
                    local spellName = GetSpellInfo(self.lockedPerkId)
                    GameTooltip:ClearLines()

                    GameTooltip:AddLine(spellName or ("Spell " .. self.lockedPerkId), qualityData.color[1],
                        qualityData.color[2], qualityData.color[3])

                    GameTooltip:AddLine(qualityData.name, 0.5, 0.5, 0.5)
                    GameTooltip:AddLine(" ")

                    local description = utils.GetSpellDescription(self.lockedPerkId, 500,
                        lockedPerkData and lockedPerkData.stack or 1)
                    GameTooltip:AddLine(description, 1, 0.82, 0, true)
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("|cffFFD700Right-click to unlock|r", 1, 1, 0.5, true)
                else
                    GameTooltip:SetText("Permanent Echo Slot", 1, 0.82, 0)
                    GameTooltip:AddLine(
                        "Click to select an Echo to carry into your next run at maximum of stack 1. This echo is in addition to all the Echoes you’ll unlock during that run.",
                        1, 1,
                        1, true)
                end
                GameTooltip:Show()
            end)
            slotFrame:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)


            slotFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            slotFrame:SetScript("OnClick", function(self, button)
                if button == "RightButton" and self.lockedPerkId then
                    StaticPopupDialogs["UNLOCK_PERK_CONFIRM"] = {
                        text = "Unlock this echo from the permanent slot?",
                        button1 = "Yes",
                        button2 = "No",
                        OnAccept = function()
                            if ProjectEbonhold.PerkService.UnlockPerk(self.lockedPerkId) then
                                C_Timer.After(0.5, function()
                                    if ProjectEbonhold.PerkService.RequestGrantedPerks then
                                        ProjectEbonhold.PerkService.RequestGrantedPerks()
                                    end
                                end)
                            end
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                    }
                    StaticPopup_Show("UNLOCK_PERK_CONFIRM")
                elseif button == "LeftButton" and not self.lockedPerkId then
                    ShowPerkSelectorForLocking(perksData, self.slotIndex)
                end
            end)

            table.insert(empowermentFrame.permanentSlots, slotFrame)
        end


        permanentSlotsStartY = permanentSlotsStartY - slotSize
    end


    local iconSize = 32
    local iconSpacing = 8
    local columns = 5
    local startX = 10
    local startY = permanentSlotsStartY

    for i, perkData in ipairs(perkList) do
        if i > 80 then break end

        local row = math.floor((i - 1) / columns)
        local col = (i - 1) % columns
        local xOffset = startX + (col * (iconSize + iconSpacing))
        local yOffset = startY - (row * (iconSize + iconSpacing))


        local iconFrame = CreateFrame("Button", nil,
            empowermentFrame.gridContainer)
        iconFrame:SetSize(iconSize, iconSize)
        iconFrame:SetPoint("TOPLEFT", empowermentFrame.gridContainer, "TOPLEFT",
            xOffset, yOffset)


        local iconBase = iconFrame:CreateTexture(nil, "BACKGROUND")
        iconBase:SetSize(iconSize * 1.2, iconSize * 1.2)
        iconBase:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        local qualityData = qualityInfo[perkData.quality] or qualityInfo[0]
        iconBase:SetTexture(
            "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_quality_" ..
            qualityData.border)


        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize * 0.8, iconSize * 0.8)
        icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
        local spellName, _, spellIcon = GetSpellInfo(perkData.spellId)
        if spellIcon then
            SetPortraitToTexture(icon, spellIcon)
        else
            icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end


        local border = iconFrame:CreateTexture(nil, "OVERLAY")
        border:SetSize(110, 110)
        border:SetPoint("CENTER", iconFrame, "CENTER", 0, 2)
        border:SetTexture(
            "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_border_quality_" ..
            qualityData.border)


        if perkData.totalStacks and perkData.totalStacks > 1 then
            local stackBadge = iconFrame:CreateTexture(nil, "OVERLAY", nil, 2)
            stackBadge:SetSize(24, 24)
            stackBadge:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMLEFT", -6, -6)
            stackBadge:SetTexture(
                "Interface\\AddOns\\ProjectEbonhold\\assets\\background_count")


            local stackText = iconFrame:CreateFontString(nil, "OVERLAY",
                "GameFontNormalSmall",
                3)
            stackText:SetPoint("CENTER", stackBadge, "CENTER", 0, 0)
            stackText:SetText(perkData.totalStacks)
            stackText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            stackText:SetTextColor(1, 1, 1)
        end


        iconFrame:EnableMouse(true)
        iconFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()


            local qualityData = qualityInfo[perkData.quality] or qualityInfo[0]
            GameTooltip:AddLine(perkData.spellName or ("Spell " .. perkData.spellId), qualityData.color[1],
                qualityData.color[2],
                qualityData.color[3])


            GameTooltip:AddLine(qualityData.name, 0.5, 0.5, 0.5)

            GameTooltip:AddLine(" ")


            local description
            if #perkData.instances > 1 then
                local spellInstances = {}
                for _, inst in ipairs(perkData.instances) do
                    table.insert(spellInstances, {
                        spellId = inst.spellId,
                        stacks = inst.stack
                    })
                end
                description = utils.GetStackedSpellDescription(spellInstances, 500)
            else
                local inst = perkData.instances[1]
                description = utils.GetSpellDescription(inst.spellId, 500, inst.stack)
            end

            GameTooltip:AddLine(description, 1, 0.82, 0, true)

            GameTooltip:Show()
        end)
        iconFrame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

        table.insert(empowermentFrame.perkIcons, iconFrame)
    end
end


function ToggleCollapse()
    if not playerRunFrame then return end
end

local function CreateIntensityButton()
    if intensityButton then return intensityButton end

    intensityButton = CreateFrame("Button", "ProjectEbonholdIntensityButton", UIParent)
    intensityButton:SetSize(128, 100)
    intensityButton:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 250)
    intensityButton:SetFrameStrata("HIGH")
    intensityButton:Hide()

    -- Background avec soulswap.blp
    local soulSwapBg = intensityButton:CreateTexture(nil, "BACKGROUND")
    soulSwapBg:SetSize(156, 90)
    soulSwapBg:SetPoint("CENTER", intensityButton, "CENTER", 0, 0)
    soulSwapBg:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\soulswap")
    intensityButton.soulSwapBg = soulSwapBg

    -- Spell icon (71)
    local spellIcon = intensityButton:CreateTexture(nil, "BORDER")
    spellIcon:SetSize(28, 28)
    spellIcon:SetPoint("CENTER", intensityButton, "CENTER", 0, 0)
    local spellName, _, spellIconPath = GetSpellInfo(95078)
    if spellIconPath then
        spellIcon:SetTexture(spellIconPath)
        spellIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    intensityButton.spellIcon = spellIcon

    -- Highlight effect
    local highlight = intensityButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(128, 100)
    highlight:SetPoint("CENTER", intensityButton, "CENTER", 0, 0)
    highlight:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\soulswap")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.3)

    -- Click handler
    intensityButton:SetScript("OnClick", function(self)
        if ProjectEbonhold and ProjectEbonhold.sendToServer and ProjectEbonhold.CS then
            ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_ACCEPT_HIGHER_INTENSITY, "") -- REQUEST_ACCEPT_HIGHER_INTENSITY = 32
        end

        -- Mettre le joueur en cooldown
        local intensityData = _G["EbonholdIntensityData"]
        if intensityData then
            intensityData.onCooldown = false
        end

        self:Hide()
    end)

    -- Tooltip
    intensityButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetHyperlink('spell:95078')
        GameTooltip:Show()
    end)
    intensityButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    return intensityButton
end

local function UpdatePlayerRunData(data)
    if not playerRunFrame then CreatePlayerRunFrame() end


    playerRunFrame.currentData = data


    if playerRunFrame.soulPointsText and data.soulPoints ~= nil then
        playerRunFrame.currentSoulPoints = data.soulPoints
        playerRunFrame.soulPointsText:SetText(
            string.format("|cffffffff%d|r", data.soulPoints))
    end


    if playerRunFrame.multiplierText and data.soulPointsMultiplier ~= nil then
        playerRunFrame.currentMultiplier = data.soulPointsMultiplier
        playerRunFrame.multiplierText:SetText(string.format(
            "|cff00ff00+%.0f%%|r",
            data.soulPointsMultiplier * 100))
    end

    if playerRunFrame.intensityIndicator then
        local intensityData = _G["EbonholdIntensityData"] or {}
        local intensity = intensityData.intensity or 0
        playerRunFrame.currentIntensity = intensity
        local maxIntensity = ProjectEbonhold.Constants.MAX_INTENSITY


        intensity = math.min(intensity, maxIntensity)
        local progress = math.min(math.max(intensity / maxIntensity, 0), 1)


        local barWidth = 180
        local indicatorWidth = 25
        local startOffset = 20
        local xPos = startOffset + (barWidth * progress) - (indicatorWidth / 2)

        if playerRunFrame.intensityFill then
            playerRunFrame.intensityFill:SetWidth(
                math.max(barWidth * progress, 1))
        end

        playerRunFrame.intensityIndicator:SetPoint("LEFT",
            playerRunFrame.intensityFrame,
            "LEFT", xPos, 0)
    end
end


local function UpdateIntensity(intensityData)
    if not playerRunFrame then
        return
    end


    local intensity = intensityData.intensity or 0
    playerRunFrame.currentIntensity = intensity
    local maxIntensity = ProjectEbonhold.Constants.MAX_INTENSITY


    intensity = math.min(intensity, maxIntensity)
    local progress = math.min(math.max(intensity / maxIntensity, 0), 1)

    local barWidth = 180
    local indicatorWidth = 25
    local startOffset = 20
    local xPos = startOffset + (barWidth * progress) - (indicatorWidth / 2)

    if playerRunFrame.intensityFill then
        playerRunFrame.intensityFill:SetWidth(math.max(barWidth * progress, 1))


        playerRunFrame.intensityFill:SetVertexColor(0.8, 0.1, 0.1, 0.8)
    end

    if playerRunFrame.intensityFillFlash then
        playerRunFrame.intensityFillFlash:SetWidth(
            math.max(barWidth * progress, 1))
    end

    if playerRunFrame.intensityIndicator then
        playerRunFrame.intensityIndicator:SetPoint("LEFT",
            playerRunFrame.intensityFrame,
            "LEFT", xPos, 0)
    end

    -- Update intensity level circle position and text
    if playerRunFrame.intensityLevelCircle and playerRunFrame.intensityLevelText then
        playerRunFrame.intensityLevelCircle:SetPoint("CENTER", playerRunFrame.intensityIndicator, "CENTER", 0, 10)
        -- Calculate intensity tier (I-V)
        local constants = ProjectEbonhold.Constants
        local tier = ""
        if intensity >= constants.INTENSITY_LEVEL_5 then
            tier = "5"
        elseif intensity >= constants.INTENSITY_LEVEL_4 then
            tier = "4"
        elseif intensity >= constants.INTENSITY_LEVEL_3 then
            tier = "3"
        elseif intensity >= constants.INTENSITY_LEVEL_2 then
            tier = "2"
        elseif intensity >= constants.INTENSITY_LEVEL_1 then
            tier = "1"
        end

        playerRunFrame.intensityLevelText:SetText(tier)

        -- Show/hide circle based on whether we have a tier
        if tier == "" then
            playerRunFrame.intensityLevelCircle:Hide()
        else
            playerRunFrame.intensityLevelCircle:Show()
        end
    end

    -- Update intensity icons (negative effects)
    if playerRunFrame.intensityIcons then
        local constants = ProjectEbonhold.Constants
        local levels = {
            constants.INTENSITY_LEVEL_1,
            constants.INTENSITY_LEVEL_2,
            constants.INTENSITY_LEVEL_3,
            constants.INTENSITY_LEVEL_4,
            constants.INTENSITY_LEVEL_5
        }
        
        for i, iconFrame in ipairs(playerRunFrame.intensityIcons) do
            local isActive = intensity >= levels[i]
            
            if isActive then
                -- Active (color)
                iconFrame.icon:SetDesaturated(false)
                
                -- Play animation only when transitioning from inactive to active
                if not iconFrame.wasActive and iconFrame.glowAnim then
                    iconFrame.glowAnim:Play()
                end
            else
                -- Inactive (gray)
                iconFrame.icon:SetDesaturated(true)
            end
            
            iconFrame.wasActive = isActive
        end
    end


    if playerRunFrame.reaperIcon then
        local areaName = intensityData.areaNameReaper or "0"
        if areaName ~= "0" then
            playerRunFrame.reaperIcon:SetTexCoord(0.214844, 0.312500, 0.894531,
                0.996094)
        else
            playerRunFrame.reaperIcon:SetTexCoord(0.121094, 0.214844, 0.898438,
                0.996094)
        end
    end

    local oldIntensity = playerRunFrame.lastIntensity or 0
    if playerRunFrame and playerRunFrame.intensityFillFlashAnim and intensity >
        oldIntensity then
        playerRunFrame.intensityFillFlashAnim:Stop()
        playerRunFrame.intensityFillFlashAnim:Play()
    end
    playerRunFrame.lastIntensity = intensity

    -- Afficher/cacher le bouton d'intensité selon le palier
    if not intensityButton then
        CreateIntensityButton()
    end

    local threshold = ProjectEbonhold.Constants and ProjectEbonhold.Constants.INTENSITY_LEVEL_3 or 300
    local canTrigger = intensityData.onCooldown == false
    if intensity >= threshold and canTrigger then
        intensityButton:Show()
    else
        intensityButton:Hide()
    end
end


local function RequestPlayerRunData()
    if ProjectEbonhold and ProjectEbonhold.sendToServer and ProjectEbonhold.CS then
        ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_PLAYER_RUN_DATA,
            "")
        ProjectEbonhold.sendToServer(ProjectEbonhold.CS
            .REQUEST_PLAYER_SOUL_POINTS_ADDITIONAL_PCT,
            "")
        ProjectEbonhold.sendToServer(
            ProjectEbonhold.CS.REQUEST_INTENSITY_POINTS, "")
    end
end


local function UpdateGrantedPerks(forceEmpty)
    if forceEmpty then
        UpdateEmpowermentDisplay({})
        return
    end

    if ProjectEbonhold and ProjectEbonhold.PerkService and
        ProjectEbonhold.PerkService.GetGrantedPerks then
        local perks = ProjectEbonhold.PerkService.GetGrantedPerks()
        UpdateEmpowermentDisplay(perks)
    end
end


local isInitialized = false


local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if not isInitialized then
            CreatePlayerRunFrame()
            CreateEmpowermentFrame()

            if ProjectEbonhold and ProjectEbonhold.PerkService and
                ProjectEbonhold.PerkService.RequestGrantedPerks then
                C_Timer.After(1.0, function()
                    ProjectEbonhold.PerkService.RequestGrantedPerks()
                end)
            end

            isInitialized = true
        end

        RequestPlayerRunData()
    end
end)

local function GetUIElements()
    if not playerRunFrame then return nil end

    return {
        soulPointsText = playerRunFrame.soulPointsText,

        acceptedRezsText = nil,
        selfRezsText = nil,
        classRezsText = nil,
        avoidDeathText = nil,

        empowermentText = playerRunFrame.empowermentText,
        intensityIndicator = playerRunFrame.intensityIndicator
    }
end


ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.PlayerRunUI = ProjectEbonhold.PlayerRunUI or {}
ProjectEbonhold.PlayerRunUI.UpdateData = UpdatePlayerRunData
ProjectEbonhold.PlayerRunUI.Toggle = ToggleCollapse
ProjectEbonhold.PlayerRunUI.ToggleEmpowerment = ToggleEmpowermentPanel
ProjectEbonhold.PlayerRunUI.GetUIElements = GetUIElements
ProjectEbonhold.PlayerRunUI.UpdateGrantedPerks = UpdateGrantedPerks
ProjectEbonhold.PlayerRunUI.UpdateIntensity = UpdateIntensity
