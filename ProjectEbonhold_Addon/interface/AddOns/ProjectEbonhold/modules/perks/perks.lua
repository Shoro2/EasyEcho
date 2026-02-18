local perkMainFrame = nil
local perkFramePool = {}
local hideButton = nil
local rerollButton = nil
local banishButton = nil
local chooseButton = nil
local isFading = false
local isSelecting = false -- Guard against double-selection / accidental clicks
local banishMode = false -- Track whether we're in banish mode
local pendingShowTimer = nil -- Track pending deferred ShowPerkUI calls

local qualityInfo = {
    [0] = { name = "Common", color = { 1, 1, 1 }, border = 0 },
    [1] = { name = "Uncommon", color = { 0.1, 1.0, 0.1 }, border = 1 },
    [2] = { name = "Rare", color = { 0.0, 0.4, 1.0 }, border = 2 },
    [3] = { name = "Epic", color = { 0.6, 0.2, 1.0 }, border = 3 },
    [4] = { name = "Legendary", color = { 1.0, 0.5, 0.0 }, border = 4 }
}

-- Helper to read fresh reroll data (avoids stale closure captures)
local function GetRerollInfo()
    local runData = ProjectEbonhold.PlayerRunService and ProjectEbonhold.PlayerRunService.GetCurrentData() or {}
    local usedRerolls = runData.usedRerolls or 0
    local totalRerolls = runData.totalRerolls or 0
    local availableRerolls = math.max(0, totalRerolls - usedRerolls)
    return availableRerolls, totalRerolls
end

-- Helper to check if banishing is available
local function GetBanishInfo()
    -- Check if system is enabled
    if not ProjectEbonhold.Constants or not ProjectEbonhold.Constants.ENABLE_BANISH_SYSTEM then
        -- -- print("[DEBUG] GetBanishInfo: Banish system is disabled")
        return 0
    end
    
    -- -- print("[DEBUG] GetBanishInfo: ProjectEbonhold.PlayerRunService exists: " .. tostring(ProjectEbonhold.PlayerRunService ~= nil))
    
    if ProjectEbonhold.PlayerRunService then
        -- -- print("[DEBUG] GetBanishInfo: GetCurrentData function exists: " .. tostring(ProjectEbonhold.PlayerRunService.GetCurrentData ~= nil))
    end
    
    local runData = ProjectEbonhold.PlayerRunService and ProjectEbonhold.PlayerRunService.GetCurrentData() or {}
    local remainingBanishes = runData.remainingBanishes or 0
    
    -- -- print("[DEBUG] GetBanishInfo: Player run data remaining banishes: " .. tostring(remainingBanishes))
    -- -- print("[DEBUG] GetBanishInfo: runData table type: " .. type(runData))
    
    -- Also check global variable directly
    local globalRunData = _G["EbonholdPlayerRunData"] or {}
    -- -- print("[DEBUG] GetBanishInfo: Global EbonholdPlayerRunData exists: " .. tostring(_G["EbonholdPlayerRunData"] ~= nil))
    if _G["EbonholdPlayerRunData"] then
        -- -- print("[DEBUG] GetBanishInfo: Global remainingBanishes: " .. tostring(globalRunData.remainingBanishes or "nil"))
        
        -- Compare service vs global data
        if runData.remainingBanishes ~= globalRunData.remainingBanishes then
            -- -- print("[DEBUG] GetBanishInfo: DATA MISMATCH! Service: " .. tostring(runData.remainingBanishes) .. ", Global: " .. tostring(globalRunData.remainingBanishes))
        end
    end
    
    if type(runData) == "table" then
        -- -- print("[DEBUG] GetBanishInfo: runData contents:")
        for k, v in pairs(runData) do
            -- -- print("[DEBUG] GetBanishInfo: runData." .. tostring(k) .. " = " .. tostring(v) .. " (type: " .. type(v) .. ")")
        end
    end
    
    -- Use global data if service data is missing banishes info or if there's a mismatch
    -- -- print("[DEBUG] GetBanishInfo: Checking fallback conditions...")
    -- -- print("[DEBUG] GetBanishInfo: remainingBanishes == 0: " .. tostring(remainingBanishes == 0))
    -- -- print("[DEBUG] GetBanishInfo: not remainingBanishes: " .. tostring(not remainingBanishes))
    -- -- print("[DEBUG] GetBanishInfo: globalRunData.remainingBanishes: " .. tostring(globalRunData.remainingBanishes))
    -- -- print("[DEBUG] GetBanishInfo: globalRunData.remainingBanishes > 0: " .. tostring(globalRunData.remainingBanishes and globalRunData.remainingBanishes > 0))
    
    if (remainingBanishes == 0 or not remainingBanishes) and globalRunData.remainingBanishes and globalRunData.remainingBanishes > 0 then
        -- -- print("[DEBUG] GetBanishInfo: Using global data instead: " .. tostring(globalRunData.remainingBanishes))
        remainingBanishes = globalRunData.remainingBanishes
    end
    
    -- -- print("[DEBUG] GetBanishInfo: Final result: " .. tostring(remainingBanishes))
    return remainingBanishes
end

-- Animation Helper (3.3.5 Compatible)
local FadeFrame, CancelFade
do
    local fadingFrames = {}
    local fadeFrame = CreateFrame("Frame")
    fadeFrame:Hide()

    -- Cancel any pending fade for a frame
    function CancelFade(frame)
        if frame and fadingFrames[frame] then
            fadingFrames[frame] = nil
        end
    end

    fadeFrame:SetScript("OnUpdate", function(self, elapsed)
        if ProjectEbonhold_IsClosing then self:Hide() return end
        if not UIParent:IsShown() then return end
        elapsed = math.min(elapsed, 0.1) -- Cap elapsed to prevent freeze after alt-tab
        local hasFades = false
        for frame, fadeInfo in pairs(fadingFrames) do
            hasFades = true
            fadeInfo.timer = fadeInfo.timer + elapsed
            
            -- Check if still in delay period
            if fadeInfo.timer < 0 then
                -- Still in delay, keep alpha at start
                frame:SetAlpha(fadeInfo.startAlpha)
            elseif fadeInfo.timer >= fadeInfo.duration then
                -- Animation complete
                frame:SetAlpha(fadeInfo.endAlpha)
                if fadeInfo.finishedFunc then
                    fadeInfo.finishedFunc(frame)
                end
                fadingFrames[frame] = nil
            else
                -- Animating
                local progress = fadeInfo.timer / fadeInfo.duration
                local alpha = fadeInfo.startAlpha + (fadeInfo.endAlpha - fadeInfo.startAlpha) * progress
                frame:SetAlpha(alpha)
            end
        end
        if not hasFades then
            self:Hide()
        end
    end)

    function FadeFrame(frame, duration, startAlpha, endAlpha, delay, onFinished)
        if not frame then return end
        if delay and delay > 0 then
            -- Simple delay handling using a conceptual timer in the update loop would be better than closures
            -- But for 3.3.5 simple compatibility without C_Timer, we can just start it with negative timer
            fadingFrames[frame] = {
                duration = duration,
                startAlpha = startAlpha,
                endAlpha = endAlpha,
                timer = -delay, -- Negative timer acts as delay
                finishedFunc = onFinished
            }
        else
            fadingFrames[frame] = {
                duration = duration,
                startAlpha = startAlpha,
                endAlpha = endAlpha,
                timer = 0,
                finishedFunc = onFinished
            }
            frame:SetAlpha(startAlpha)
        end
        frame:Show()
        fadeFrame:Show()
    end
end

-- Frame Pool Management
local function AcquirePerkFrame(parent)
    for _, frame in ipairs(perkFramePool) do
        if not frame.inUse then
            frame:SetParent(parent)
            frame:SetAlpha(1)
            frame:ClearAllPoints()
            frame.inUse = true
            return frame
        end
    end

    -- Create new if none available
    local index = #perkFramePool + 1
    local frame = CreateFrame("Frame", "PerkChoice" .. index, parent)
    frame:SetSize(200, 400)

    -- Static Visuals
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\background_one_perk")
    bg:SetTexCoord(0.226562, 0.746094, 0.009766, 0.958984)

    local topPerkFrame = CreateFrame("Frame", nil, frame)
    topPerkFrame:SetSize(200, 200)
    topPerkFrame:SetPoint("TOP", frame, "TOP", -5, -140)

    local iconFrame = CreateFrame("Frame", nil, topPerkFrame)
    iconFrame:SetSize(26, 26)
    iconFrame:SetPoint("TOP", topPerkFrame, "TOP", 0, -20)
    frame.iconFrame = iconFrame

    local iconBase = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBase:SetSize(124, 124)
    iconBase:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    frame.iconBase = iconBase

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, -3)
    icon:SetSize(26, 26)
    frame.icon = icon

    local border = iconFrame:CreateTexture(nil, "OVERLAY")
    border:SetSize(124, 124)
    border:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    frame.border = border

    local nameText = topPerkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetFont("Fonts\\MORPHEUS.TTF", 14)
    nameText:SetPoint("TOP", frame, "TOP", -5, -100)
    nameText:SetWidth(170)
    nameText:SetJustifyH("CENTER")
    frame.nameText = nameText

    local descText = topPerkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOP", topPerkFrame, "CENTER", 0, 20)
    descText:SetWidth(140)
    descText:SetHeight(90)
    descText:SetJustifyH("CENTER")
    descText:SetJustifyV("TOP")
    frame.descText = descText

    local selectButton = utils.CreateSimpleCustomButton(frame, "Select", nil, 130, 32)
    selectButton:SetPoint("BOTTOM", topPerkFrame, "CENTER", 4, -80)
    frame.selectButton = selectButton

    frame.inUse = true
    table.insert(perkFramePool, frame)
    return frame
end

local function UpdatePerkFrame(frame, perkData, perkIndex)
    if not frame or not perkData then return end
    
    local spellId = perkData.spellId
    local quality = perkData.quality
    local stacks = perkData.stack or 1
    local maxStacks = perkData.maxStack or 1
    local qualityData = qualityInfo[quality] or qualityInfo[0]
    
    -- Store the perkIndex on the frame (0-based)
    frame.perkIndex = perkIndex

    -- -- print("[DEBUG] UpdatePerkFrame called for spellId: " .. tostring(spellId) .. ", quality: " .. tostring(quality) .. ", perkIndex: " .. tostring(perkIndex))

    -- Update Visuals
    frame.iconBase:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\perk_quality_" .. qualityData.border)
    frame.border:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\perk_border_quality_" .. qualityData.border)

    local spellName, _, spellIcon = GetSpellInfo(spellId)
    if spellIcon then
        SetPortraitToTexture(frame.icon, spellIcon)
    else
        frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    frame.nameText:SetText(spellName or ("Spell " .. spellId))
    frame.nameText:SetTextColor(unpack(qualityData.color))

    local description = utils.GetSpellDescription(spellId, 120)
    frame.descText:SetText(description)

    -- Update button text and style based on banish mode
    if banishMode then
        frame.selectButton.text:SetText("Banish")
        frame.selectButton.text:SetTextColor(1, 0.3, 0.3)  -- Red text for banish mode
    else
        frame.selectButton.text:SetText("Select")
        frame.selectButton.text:SetTextColor(1, 1, 1)  -- White text for select mode
    end

    -- Update Button Click
    frame.selectButton:SetScript("OnClick", function()
        if isSelecting then 
            return 
        end
        isSelecting = true
        -- Disable all select buttons immediately to prevent double-selection
        for _, f in ipairs(perkFramePool) do
            if f.inUse then
                f.selectButton:EnableMouse(false)
                f:EnableMouse(false)
            end
        end
        
        local success
        if banishMode then
            -- In banish mode, banish the perk instead of selecting it
            success = ProjectEbonhold.PerkService.BanishPerk(perkIndex)
        else
            -- In select mode, select the perk normally
            success = ProjectEbonhold.PerkService.SelectPerk(spellId)
        end
        
        if not success then
            -- Action failed client-side (e.g. race condition), re-enable interaction
            isSelecting = false
            for _, f in ipairs(perkFramePool) do
                if f.inUse then
                    f.selectButton:EnableMouse(true)
                    f:EnableMouse(true)
                end
            end
        end
    end)

    -- Scripts
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(frame.iconFrame, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()

        local spellName = GetSpellInfo(spellId)
        GameTooltip:AddLine(spellName or ("Spell " .. spellId), qualityData.color[1], qualityData.color[2],
            qualityData.color[3])
        GameTooltip:AddLine(qualityData.name, 0.5, 0.5, 0.5)

        if stacks > 1 then
            GameTooltip:AddLine("Stacks: " .. stacks .. "/" .. maxStacks, 1, 1, 1)
        end

        GameTooltip:AddLine(" ")
        local description = utils.GetSpellDescription(spellId, 500, stacks)
        GameTooltip:AddLine(description, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- Ensure all frame components are visible (important for updates)
    frame:Show()
    frame.iconFrame:Show()
    frame.icon:Show()
    frame.iconBase:Show()
    frame.border:Show()
    frame.nameText:Show()
    frame.descText:Show()
    frame.selectButton:Show()
    
    -- -- print("[DEBUG] UpdatePerkFrame: Complete - frame IsShown: " .. tostring(frame:IsShown()) .. ", Alpha: " .. tostring(frame:GetAlpha()))
end

-- Main Frame Initialization
local function InitializePerkUI()
    if perkMainFrame then return end

    perkMainFrame = CreateFrame("Frame", "ProjectEbonholdPerkFrame", UIParent)
    perkMainFrame:SetFrameStrata("DIALOG")
    perkMainFrame:SetFrameLevel(100)
    perkMainFrame:SetSize(800, 280) -- Default size, will adjust
    perkMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    perkMainFrame:Hide()

    perkMainFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            ProjectEbonhold.PerkUI.Hide()
        end
    end)

    -- Reroll Button
    rerollButton = utils.CreateSimpleCustomButton(perkMainFrame, "Reroll", nil, 140, 38)
    rerollButton:SetPoint("BOTTOM", perkMainFrame, "TOP", -75, 50)
    -- Scripts for reroll are context dependent, will set in Show

    -- Main Banish Button
    banishButton = utils.CreateSimpleCustomButton(perkMainFrame, "Banish", nil, 140, 38)
    banishButton:SetPoint("BOTTOM", perkMainFrame, "TOP", 75, 50)
    -- Scripts for banish will be set in Show

    -- Hide Button (The complex one with particles)
    hideButton = CreateFrame("Button", "PerkHideButton", perkMainFrame)
    hideButton:SetSize(200, 100)
    hideButton:SetPoint("TOP", perkMainFrame, "BOTTOM", 0, -50)
    hideButton:RegisterForClicks("LeftButtonUp")
    hideButton:Hide()

    local hideButtonTexture = hideButton:CreateTexture(nil, "BACKGROUND")
    hideButtonTexture:SetAllPoints(hideButton)
    hideButtonTexture:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\button_hide_perk")
    hideButtonTexture:SetTexCoord(0, 1, 0.30, 0.80)

    local glowTexture = hideButton:CreateTexture(nil, "ARTWORK")
    glowTexture:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
    glowTexture:SetBlendMode("ADD")
    glowTexture:SetPoint("CENTER", hideButton, "CENTER", 0, 0)
    glowTexture:SetSize(220, 110)
    glowTexture:SetVertexColor(0.3, 0.3, 0.3, 0.4)
    hideButton.glowTexture = glowTexture

    -- Setup Hide Button Particles once
    hideButton.flameParticles = {}
    for i = 1, 12 do
        local particle = hideButton:CreateTexture(nil, "OVERLAY")
        particle:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        particle:SetBlendMode("ADD")
        particle:SetSize(18, 18)
        particle:SetVertexColor(0.6, 0.6, 0.6, 0)
        table.insert(hideButton.flameParticles, {
            texture = particle,
            life = math.random() * 2,
            xOffset = (math.random() - 0.5) * 80,
            speed = 30 + math.random() * 20
        })
    end

    local hideButtonText = hideButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideButtonText:SetPoint("CENTER", hideButton, "CENTER", 0, 10)
    hideButton.text = hideButtonText

    hideButton:SetScript("OnUpdate", function(self, elapsed)
        if ProjectEbonhold_IsClosing then return end
        if not self:IsVisible() or not UIParent:IsShown() then return end
        elapsed = math.min(elapsed, 0.1) -- Cap elapsed to prevent freeze after alt-tab

        local time = GetTime()
        local pulse = 0.3 + 0.15 * math.sin(time * 1.5)
        glowTexture:SetAlpha(pulse)

        local textPulse = 0.7 + 0.3 * math.abs(math.sin(time * 0.8))
        hideButtonText:SetAlpha(textPulse)

        local particles = self.flameParticles
        for i = 1, #particles do
            local p = particles[i]
            p.life = p.life + elapsed
            if p.life >= 2 then
                p.life = 0
                p.xOffset = (math.random() - 0.5) * 80
                p.speed = 30 + math.random() * 20
            end
            local progress = p.life / 2
            local yOffset = -25 + progress * 80
            local wave = math.sin(p.life * 4 + i) * 15 * (1 - progress)
            local x = p.xOffset + wave
            p.texture:ClearAllPoints()
            p.texture:SetPoint("CENTER", self, "CENTER", x, yOffset)

            local alpha
            if progress < 0.2 then
                alpha = progress / 0.2
            elseif progress < 0.7 then
                alpha = 1
            else
                alpha = 1 - (progress - 0.7) / 0.3
            end
            p.texture:SetAlpha(alpha * 0.9)
            local size = 18 * (1 - progress * 0.5)
            p.texture:SetSize(size, size)
        end
    end)

    -- Choose Button
    chooseButton = CreateFrame("Button", "PerkChooseButton", perkMainFrame)
    chooseButton:SetSize(250, 120)
    chooseButton:SetPoint("TOP", perkMainFrame, "BOTTOM", 0, -50)
    chooseButton:SetFrameLevel(perkMainFrame:GetFrameLevel() + 10)
    chooseButton:EnableMouse(true)
    chooseButton:RegisterForClicks("LeftButtonUp")

    local chooseButtonTexture = chooseButton:CreateTexture(nil, "BACKGROUND")
    chooseButtonTexture:SetAllPoints(chooseButton)
    chooseButtonTexture:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\button_hide_perk")
    chooseButtonTexture:SetTexCoord(0, 1, 0.30, 0.80)

    local chooseButtonText = chooseButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chooseButtonText:SetPoint("CENTER", chooseButton, "CENTER", 0, 10)
    chooseButtonText:SetText("Choose an Echo")
    chooseButtonText:SetTextColor(1, 1, 1)
    chooseButton.text = chooseButtonText

    local chooseGlow = chooseButton:CreateTexture(nil, "ARTWORK")
    chooseGlow:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
    chooseGlow:SetBlendMode("ADD")
    chooseGlow:SetPoint("CENTER", chooseButton, "CENTER", 0, 0)
    chooseGlow:SetSize(270, 135)
    chooseGlow:SetVertexColor(0.3, 0.3, 0.3)
    chooseButton.glow = chooseGlow

    local chooseHighlight = chooseButton:CreateTexture(nil, "OVERLAY")
    chooseHighlight:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
    chooseHighlight:SetBlendMode("ADD")
    chooseHighlight:SetPoint("CENTER", chooseButton, "CENTER", 0, 0)
    chooseHighlight:SetSize(300, 150)
    chooseHighlight:SetVertexColor(1, 1, 1)
    chooseHighlight:SetAlpha(0)
    chooseButton.highlight = chooseHighlight

    -- Setup Choose Button Particles
    chooseButton.flameParticles = {}
    local texCoords = {
        { 0.062500, 0.476562, 0.070312, 0.492188 },
        { 0.468750, 0.898438, 0.054688, 0.515625 },
        { 0.117188, 0.484375, 0.484375, 0.898438 },
        { 0.484375, 0.960938, 0.460938, 0.898438 }
    }

    for i = 1, 30 do
        local particle = chooseButton:CreateTexture(nil, "OVERLAY")
        particle:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\texture_glow")
        particle:SetBlendMode("ADD")
        particle:SetSize(40, 40)
        local coordIndex = ((i - 1) % 4) + 1
        local coords = texCoords[coordIndex]
        particle:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        particle:SetVertexColor(0.85, 0.85, 0.85, 0)
        table.insert(chooseButton.flameParticles, {
            texture = particle,
            life = (i - 1) * (2 / 30) + math.random() * 0.05,
            xOffset = (math.random() - 0.5) * 140,
            speed = 30 + math.random() * 20,
            coordIndex = coordIndex
        })
    end

    chooseButton:SetScript("OnUpdate", function(self, elapsed)
        if ProjectEbonhold_IsClosing then return end
        if not self:IsVisible() or not UIParent:IsShown() then return end
        elapsed = math.min(elapsed, 0.1) -- Cap elapsed to prevent freeze after alt-tab
        local time = GetTime()
        local basePulse = 0.2 + 0.25 * math.abs(math.sin(time * 0.8))
        if self.isHovering then
            chooseGlow:SetAlpha(basePulse + 0.4)
        else
            chooseGlow:SetAlpha(basePulse)
        end

        local textPulse = 0.7 + 0.3 * math.abs(math.sin(time * 0.8))
        chooseButtonText:SetAlpha(textPulse)

        local particles = self.flameParticles
        for i = 1, #particles do
            local p = particles[i]
            p.life = p.life + elapsed
            if p.life >= 2 then
                p.life = 0
                p.xOffset = (math.random() - 0.5) * 140
                p.speed = 30 + math.random() * 20
                p.coordIndex = (p.coordIndex % 4) + 1
                local coords = texCoords[p.coordIndex]
                p.texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            end
            local progress = p.life / 2
            local yOffset = -25 + progress * 80
            local wave = math.sin(p.life * 4 + i) * 15 * (1 - progress)
            local x = p.xOffset + wave
            p.texture:ClearAllPoints()
            p.texture:SetPoint("CENTER", self, "CENTER", x, yOffset)
            local alpha
            if progress < 0.2 then
                alpha = progress / 0.2
            elseif progress < 0.7 then
                alpha = 1
            else
                alpha = 1 - (progress - 0.7) / 0.3
            end
            p.texture:SetAlpha(alpha * 1.3)
            local size = 40 * (1 - progress * 0.5)
            p.texture:SetSize(size, size)
        end
    end)

    chooseButton:SetScript("OnEnter", function(self)
        self.isHovering = true
        chooseHighlight:SetAlpha(0.6)
        chooseGlow:SetVertexColor(0.9, 0.9, 0.9)
    end)
    chooseButton:SetScript("OnLeave", function(self)
        self.isHovering = false
        chooseHighlight:SetAlpha(0)
        chooseGlow:SetVertexColor(0.3, 0.3, 0.3)
    end)

    -- Interactions between buttons
    chooseButton:SetScript("OnClick", function()
        -- Fade In Perks (but don't enable mouse yet - wait for chooseButton to fully hide)
        local activePerks = {}
        for _, frame in ipairs(perkFramePool) do
            if frame.inUse then table.insert(activePerks, frame) end
        end

        for i, frame in ipairs(activePerks) do
            FadeFrame(frame, 0.3, 0, 1, (i - 1) * 0.1)
        end

        rerollButton:Show()
        banishButton:Show()
        -- Refresh button states with latest data (may have changed since ShowPerkUI, e.g. after death)
        local availRerolls, totRerolls = GetRerollInfo()
        if availRerolls > 0 then
            rerollButton.text:SetText("Reroll (" .. tostring(availRerolls) .. ")")
            rerollButton.text:SetTextColor(1, 1, 1)
            rerollButton:Enable()
        else
            rerollButton.text:SetText("Reroll")
            rerollButton:Disable()
        end
        
        local availBanishes = GetBanishInfo()
        if availBanishes > 0 then
            banishButton.text:SetText("Banish (" .. tostring(availBanishes) .. ")")
            banishButton.text:SetTextColor(1, 1, 1)
            banishButton:Enable()
        else
            banishButton.text:SetText("Banish")
            banishButton:Disable()
        end

        -- Logic for state
        perkMainFrame.perksHidden = false
        hideButton.text:SetText("Hide")

        -- Fade Out Choose Button, then enable perk interaction
        FadeFrame(chooseButton, 0.3, 1, 0, 0, function(self)
            self:Hide()
            -- Only NOW enable mouse on perks, after chooseButton is fully hidden
            -- This prevents clicks from hitting select buttons during the crossfade
            for _, f in ipairs(perkFramePool) do
                if f.inUse and not isSelecting then
                    f:EnableMouse(true)
                    f.selectButton:EnableMouse(true)
                end
            end
        end)

        -- Fade In Hide Button
        FadeFrame(hideButton, 0.3, 0, 1, 0)
    end)

    hideButton:SetScript("OnClick", function()
        perkMainFrame.perksHidden = not perkMainFrame.perksHidden

        local activePerks = {}
        for _, frame in ipairs(perkFramePool) do
            if frame.inUse then table.insert(activePerks, frame) end
        end

        if perkMainFrame.perksHidden then
            -- HIDE PERKS - disable mouse immediately to prevent clicks during fade
            for i, frame in ipairs(activePerks) do
                frame:EnableMouse(false)
                frame.selectButton:EnableMouse(false)
                FadeFrame(frame, 0.3, frame:GetAlpha(), 0, (i - 1) * 0.1, function(self) self:Hide() end)
            end
            hideButton.text:SetText("Show")
            rerollButton:Hide()
            banishButton:Hide()
        else
            -- SHOW PERKS - re-enable mouse interaction
            -- Reset banish mode when showing perks again
            banishMode = false
            
            for i, frame in ipairs(activePerks) do
                frame:EnableMouse(true)
                frame.selectButton:EnableMouse(true)
                FadeFrame(frame, 0.3, 0, 1, (i - 1) * 0.1)
                -- Reset all buttons to select mode
                if frame.selectButton then
                    frame.selectButton.text:SetText("Select")
                    frame.selectButton.text:SetTextColor(1, 1, 1)
                end
            end
            rerollButton:Show()
            banishButton:Show()
            -- Refresh button states with latest data
            local availRerolls, totRerolls = GetRerollInfo()
            if availRerolls > 0 then
                rerollButton.text:SetText("Reroll (" .. tostring(availRerolls) .. ")")
                rerollButton.text:SetTextColor(1, 1, 1)
                rerollButton:Enable()
            else
                rerollButton.text:SetText("Reroll")
                rerollButton:Disable()
            end
            
            local availBanishes = GetBanishInfo()
            if availBanishes > 0 then
                banishButton.text:SetText("Banish (" .. tostring(availBanishes) .. ")")
                banishButton.text:SetTextColor(1, 1, 1)
                banishButton:Enable()
            else
                banishButton.text:SetText("Banish")
                banishButton:Disable()
            end
            hideButton.text:SetText("Hide")
        end
    end)

    hideButton:SetScript("OnEnter", function() hideButton.text:SetTextColor(0.7, 0.7, 0.7) end)
    hideButton:SetScript("OnLeave", function() hideButton.text:SetTextColor(1, 1, 1) end)
end

-- Immediately reset UI state without animation (used when new choices arrive during fade)
local function ForceResetPerkUI()
    isFading = false
    isSelecting = false
    banishMode = false  -- Reset banish mode
    if perkMainFrame then
        CancelFade(perkMainFrame)
        perkMainFrame:SetAlpha(1)
        perkMainFrame:Hide()
    end
    -- Cancel all pending fades on perk frames
    for _, f in ipairs(perkFramePool) do
        CancelFade(f)
        if f.selectButton then
            CancelFade(f.selectButton)
        end
        f:Hide()
        f:SetAlpha(1)
        f:EnableMouse(true)
        f.inUse = false
    end
    if chooseButton then
        CancelFade(chooseButton)
    end
    if hideButton then
        CancelFade(hideButton)
    end
    if rerollButton then
        CancelFade(rerollButton)
        rerollButton:Hide()
        rerollButton:SetAlpha(1)
    end
    if banishButton then
        CancelFade(banishButton)
        banishButton:Hide()
        banishButton:SetAlpha(1)
    end
end

-- Show Logic
local function ShowPerkUI(choices)
    if not choices or #choices == 0 then return end
    
    -- -- print("[DEBUG] ShowPerkUI called with " .. tostring(#choices) .. " choices")
    
    -- Cancel any pending deferred ShowPerkUI call to prevent stacking
    if pendingShowTimer then
        pendingShowTimer:SetScript("OnUpdate", nil)
        pendingShowTimer = nil
    end
    
    -- Always force reset to cancel any stale fades/state from previous interactions.
    -- This prevents stuck UI when ShowPerkUI is called while perks are already visible
    -- (e.g., leveling up while the selection screen is open).
    ForceResetPerkUI()

    InitializePerkUI()

    -- Reset state
    perkMainFrame:Show()
    perkMainFrame:SetAlpha(1)

    -- Release all frames
    for _, f in ipairs(perkFramePool) do
        f:Hide()
        f:SetAlpha(1)
        f.inUse = false
    end

    local perkCount = #choices
    local frameWidth = (perkCount * 180) + ((perkCount - 1) * 20) + 40
    perkMainFrame:SetWidth(frameWidth)

    -- Setup Perk Frames
    for i, perkData in ipairs(choices) do
        -- -- print("[DEBUG] ShowPerkUI: Setting up perk frame " .. tostring(i) .. " with spellId: " .. tostring(perkData.spellId))
        local perkFrame = AcquirePerkFrame(perkMainFrame)
        UpdatePerkFrame(perkFrame, perkData, i - 1)  -- Pass 0-based index

        local xOffset = ((i - 1) - ((perkCount - 1) / 2)) * 200
        perkFrame:SetPoint("CENTER", perkMainFrame, "CENTER", xOffset, 0)

        -- Start hidden (visual only, keep rendered to pre-load textures)
        perkFrame:SetAlpha(0)
        perkFrame:Show()
        perkFrame:EnableMouse(false)
        perkFrame.selectButton:EnableMouse(false)
    end

    -- Reroll Logic (read fresh data each time to avoid stale counts after death/reset)
    local initAvail, initTotal = GetRerollInfo()
    if initAvail > 0 then
        rerollButton.text:SetText("Reroll (" .. tostring(initAvail) .. ")")
        rerollButton.text:SetTextColor(1, 1, 1)
        rerollButton:Enable()
    else
        rerollButton.text:SetText("Reroll")
        rerollButton:Disable()
    end
    
    rerollButton:SetScript("OnClick", function()
        -- Read fresh reroll data on every click
        local availableRerolls, totalRerolls = GetRerollInfo()

        if availableRerolls <= 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000No rerolls remaining! Rerolls are restored upon death.|r")
            return
        end

        StaticPopupDialogs["PERK_REROLL_CONFIRM"] = {
            text = "Are you sure you want to reroll your current echoes?\n\n|cffFFD700Rerolls remaining: " ..
            availableRerolls ..
            "/" ..
            totalRerolls .. "|r\n\nThese echoes won't appear in your next choice, but may return in future selections.",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                -- Animate out
                for i, perkFrame in ipairs(perkFramePool) do
                    if perkFrame:IsShown() and perkFrame.inUse then
                        FadeFrame(perkFrame, 0.2, perkFrame:GetAlpha(), 0, (i - 1) * 0.05, function(self) self:Hide() end)
                    end
                end

                ProjectEbonhold.PerkService.RequestReroll()
                rerollButton:Hide()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        }
        StaticPopup_Show("PERK_REROLL_CONFIRM")
    end)

    rerollButton:SetScript("OnEnter", function(self)
        -- Read fresh reroll data for tooltip
        local availableRerolls, totalRerolls = GetRerollInfo()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Reroll Echoes", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
        "Reroll current echoes. These echoes won't appear in your next choice, but may return in future selections.", 1,
            1, 1, true)
        GameTooltip:AddLine(" ")
        if availableRerolls > 0 then
            GameTooltip:AddLine("Rerolls remaining: " .. availableRerolls .. "/" .. totalRerolls, 0, 1, 0)
        else
            GameTooltip:AddLine("No rerolls remaining", 1, 0, 0)
        end
        GameTooltip:Show()
    end)
    rerollButton:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- Main Banish Button Logic
    local remainingBanishes = GetBanishInfo()
    if remainingBanishes > 0 then
        banishButton.text:SetText("Banish (" .. tostring(remainingBanishes) .. ")")
        banishButton.text:SetTextColor(1, 1, 1)
        banishButton:Enable()
    else
        banishButton.text:SetText("Banish")
        banishButton:Disable()
    end
    
    banishButton:SetScript("OnClick", function()
        -- Toggle banish mode
        banishMode = not banishMode
        
        -- Update button appearance based on mode
        if banishMode then
            banishButton.text:SetTextColor(1, 0.3, 0.3)
        else
            banishButton.text:SetTextColor(1, 1, 1)
        end
        
        -- Update all perk frame buttons to reflect the new mode
        for _, frame in ipairs(perkFramePool) do
            if frame.inUse and frame:IsShown() then
                if banishMode then
                    frame.selectButton.text:SetText("Banish")
                    frame.selectButton.text:SetTextColor(1, 0.3, 0.3)
                else
                    frame.selectButton.text:SetText("Select")
                    frame.selectButton.text:SetTextColor(1, 1, 1)
                end
            end
        end
    end)
    
    banishButton:SetScript("OnEnter", function(self)
        local freshBanishes = GetBanishInfo()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        if banishMode then
            GameTooltip:AddLine("Cancel Banish Mode", 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click to exit banish mode and return to selecting echoes.", 1, 1, 1, true)
        else
            GameTooltip:AddLine("Banish Echo", 1, 0.82, 0)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Enter banish mode. Click an echo to remove it from future selections in your current run. It banishes all qualities of the chosen echo.", 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            if freshBanishes > 0 then
                GameTooltip:AddLine("Banishes remaining: " .. freshBanishes, 0, 1, 0)
            else
                GameTooltip:AddLine("No banishes remaining", 1, 0, 0)
            end
        end
        GameTooltip:Show()
    end)
    banishButton:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- Initial State
    banishMode = false  -- Reset banish mode when showing new choices
    rerollButton:Hide()
    banishButton:Hide()
    hideButton:Hide()
    hideButton.text:SetText("Show")
    perkMainFrame.perksHidden = true

    -- Cancel any pending fade on chooseButton to prevent race conditions
    -- where an ongoing fade-out would override our alpha setting
    CancelFade(chooseButton)
    chooseButton:EnableMouse(true)
    chooseButton:SetAlpha(1)
    chooseButton:Show()
end

local function HidePerkUI()
    isSelecting = false
    banishMode = false  -- Reset banish mode when hiding UI
    if perkMainFrame and perkMainFrame:IsShown() then
        isFading = true
        -- Immediately disable all perk interactions to prevent clicks during fade-out
        for _, f in ipairs(perkFramePool) do
            if f.inUse then
                f:EnableMouse(false)
                f.selectButton:EnableMouse(false)
            end
        end

        FadeFrame(perkMainFrame, 0.3, perkMainFrame:GetAlpha(), 0, 0, function()
            perkMainFrame:Hide()
            for _, f in ipairs(perkFramePool) do
                f:Hide()
                f:EnableMouse(true) -- Reset to default for recycling
            end
            isFading = false
        end)
    else
        -- Frame not shown, ensure isFading is reset in case it was stuck
        isFading = false
    end
end

ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.PerkUI = ProjectEbonhold.PerkUI or {}
ProjectEbonhold.PerkUI.Show = ShowPerkUI
ProjectEbonhold.PerkUI.Hide = HidePerkUI
ProjectEbonhold.PerkUI.ResetSelection = function()
    isSelecting = false
    for _, f in ipairs(perkFramePool) do
        if f.inUse then
            f:EnableMouse(true)
            f.selectButton:EnableMouse(true)
        end
    end
end
ProjectEbonhold.PerkUI.RefreshBanishText = function()
    -- Update main banish button state when player data is refreshed
    if perkMainFrame and banishButton and perkMainFrame:IsShown() then
        local remainingBanishes = GetBanishInfo()
        
        -- Update button state
        if remainingBanishes > 0 then
            banishButton.text:SetText("Banish (" .. tostring(remainingBanishes) .. ")")
            if not banishMode then
                banishButton.text:SetTextColor(1, 1, 1)
            else
                banishButton.text:SetTextColor(1, 0.3, 0.3)
            end
            banishButton:Enable()
        else
            banishButton.text:SetText("Banish")
            banishButton:Disable()
            -- Exit banish mode if we run out of banishes
            if banishMode then
                banishMode = false
                -- Update all perk frames back to select mode
                for _, frame in ipairs(perkFramePool) do
                    if frame.inUse and frame:IsShown() then
                        frame.selectButton.text:SetText("Select")
                        frame.selectButton.text:SetTextColor(1, 1, 1)
                    end
                end
            end
        end
    end
end
ProjectEbonhold.PerkUI.UpdateSinglePerk = function(perkIndex, newPerkData)
    -- Update a single perk frame with animation (0-based index from server)
    -- -- print("[DEBUG] UpdateSinglePerk: Updating perk at index " .. tostring(perkIndex) .. " with spellId: " .. tostring(newPerkData.spellId))
    
    if not perkMainFrame or not perkMainFrame:IsShown() then
        -- -- print("[DEBUG] UpdateSinglePerk: Main frame not shown, falling back to full refresh")
        ShowPerkUI(ProjectEbonhold.PerkService.GetCurrentChoice())
        return
    end
    
    -- Find the frame at this index (perkIndex is 0-based, Lua arrays are 1-based)
    local frameIndex = perkIndex + 1
    local targetFrame = nil
    
    for i, frame in ipairs(perkFramePool) do
        if frame.inUse and frame.perkIndex == perkIndex then
            targetFrame = frame
            break
        end
    end
    
    if not targetFrame then
        -- -- print("[DEBUG] UpdateSinglePerk: Could not find frame for index " .. tostring(perkIndex) .. ", falling back to full refresh")
        ShowPerkUI(ProjectEbonhold.PerkService.GetCurrentChoice())
        return
    end
    
    -- -- print("[DEBUG] UpdateSinglePerk: Found target frame, animating replacement")
    
    -- Disable interaction during animation
    targetFrame:EnableMouse(false)
    targetFrame.selectButton:EnableMouse(false)
    
    -- Fade out the old perk
    FadeFrame(targetFrame, 0.15, targetFrame:GetAlpha(), 0, 0, function(self)
        -- -- print("[DEBUG] UpdateSinglePerk: Fade-out complete, updating frame")
        
        -- Update the frame with new perk data
        UpdatePerkFrame(self, newPerkData, perkIndex)
        
        -- -- print("[DEBUG] UpdateSinglePerk: Frame updated, starting fade-in")
        
        -- Show frame at alpha 0, then fade to 1 using a fresh FadeFrame call
        -- We need to set alpha manually and use delay to avoid nested fade issues
        self:Show()
        self:SetAlpha(0)
        
        -- Use delay parameter to create a gap between update and fade-in
        -- This avoids the nested FadeFrame issue
        local startTime = GetTime()
        local fadeInDelay = 0.05
        local fadeInDuration = 0.2
        
        -- Simple manual fade-in using OnUpdate
        local fadeInFrame = CreateFrame("Frame")
        fadeInFrame:SetScript("OnUpdate", function(_, elapsed)
            local elapsed = GetTime() - startTime
            if elapsed < fadeInDelay then
                -- Still waiting
                self:SetAlpha(0)
            elseif elapsed < fadeInDelay + fadeInDuration then
                -- Fading in
                local progress = (elapsed - fadeInDelay) / fadeInDuration
                self:SetAlpha(progress)
            else
                -- Done
                self:SetAlpha(1)
                self:EnableMouse(true)
                self.selectButton:EnableMouse(true)
                -- -- print("[DEBUG] UpdateSinglePerk: Fade-in complete")
                fadeInFrame:SetScript("OnUpdate", nil)
            end
        end)
    end)
    
    -- Exit banish mode after successful banish
    if banishMode then
        banishMode = false
        
        -- Update banish button back to normal white color
        if banishButton then
            banishButton.text:SetTextColor(1, 1, 1)
        end
        
        -- Update all perk frames back to select mode
        for _, frame in ipairs(perkFramePool) do
            if frame.inUse and frame:IsShown() and frame.selectButton then
                frame.selectButton.text:SetText("Select")
                frame.selectButton.text:SetTextColor(1, 1, 1)
            end
        end
    end
    
    -- Update banish count display
    ProjectEbonhold.PerkUI.RefreshBanishText()
end

local function PrewarmPool()
    InitializePerkUI()
    for i = 1, 3 do
        local f = AcquirePerkFrame(perkMainFrame)
        f:Hide()
        f.inUse = false
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        PrewarmPool()
    elseif event == "PLAYER_LEVEL_UP" then
        ProjectEbonhold.PerkService.RequestChoice()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ProjectEbonhold.PerkService.RequestChoice()
    end
end)
