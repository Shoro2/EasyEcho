local ADDON_NAME = "ProjectEbonhold"
local OPTIONS_TITLE = "Project Ebonhold"

local OptionsPanel = {}
local optionsFrame


local function CreateOptionsFrame()
    local frame = CreateFrame("Frame", "ProjectEbonholdOptionsPanel", UIParent)
    frame.name = OPTIONS_TITLE

    -- ── Fixed header (title / subtitle / version) stays on the outer frame ──
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(OPTIONS_TITLE)

    local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure your character progression settings")

    local version = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPRIGHT", -16, -16)
    version:SetText("Version 1.0")

    -- ── Reset button anchored to the bottom of the outer frame ──────────────
    local resetButton = CreateFrame("Button", "ProjectEbonholdResetButton", frame, "UIPanelButtonTemplate")
    resetButton:SetPoint("BOTTOMLEFT", 16, 16)
    resetButton:SetSize(150, 25)
    resetButton:SetText("Reset to Defaults")
    resetButton:SetScript("OnClick", function()
        StaticPopupDialogs["PROJECTEBONHOLD_RESET_SETTINGS"] = {
            text = "Are you sure you want to reset all settings to their default values?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                ProjectEbonholdOptionsService:ResetToDefaults()
                OptionsPanel:RefreshSettings()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("PROJECTEBONHOLD_RESET_SETTINGS")
    end)

    -- ── ScrollFrame fills the space between header and Reset button ──────────
    local scrollFrame = CreateFrame("ScrollFrame", "ProjectEbonholdOptionsScrollFrame", frame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",  4,  -56)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 46)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 580)
    scrollChild:SetHeight(1)   -- will be updated once all content is laid out
    scrollFrame:SetScrollChild(scrollChild)

    -- Mouse-wheel forwarding: child frames eat mouse events, so we forward
    -- wheel scrolls from both scrollChild and every interactive widget back
    -- to the scroll frame's built-in handler.
    local function ForwardMouseWheel(self, delta)
        ScrollFrameTemplate_OnMouseWheel(scrollFrame, delta)
    end
    scrollChild:EnableMouseWheel(true)
    scrollChild:SetScript("OnMouseWheel", ForwardMouseWheel)

    -- Helper: call on every CheckButton / Slider / Button parented to scrollChild
    local function HookWheelForward(widget)
        widget:EnableMouseWheel(true)
        widget:SetScript("OnMouseWheel", ForwardMouseWheel)
    end

    -- Adjust scrollChild width when the scroll frame is resized
    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    -- All content is now parented to scrollChild
    local p = scrollChild
    local CONTENT_WIDTH = 580  -- effective width for RIGHT anchors
    local yOffset = -10

    -- ── Section: Automatic Restoration ──────────────────────────────────────
    local autoHeader = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    autoHeader:SetPoint("TOPLEFT", 12, yOffset)
    autoHeader:SetText("Automatic Restoration")
    yOffset = yOffset - 30

    local autoSpellsCheckbox = CreateFrame("CheckButton", "ProjectEbonholdAutoSpellsCheckbox", p,
        "InterfaceOptionsCheckButtonTemplate")
    autoSpellsCheckbox:SetPoint("TOPLEFT", 16, yOffset)
    _G[autoSpellsCheckbox:GetName() .. "Text"]:SetText("Auto-place spells from previous run")
    autoSpellsCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() == 1
        ProjectEbonholdOptionsService:SetSetting("autoPlaceSpells", checked)
        ProjectEbonholdOptionsService:SendToServer()
    end)
    frame.autoSpellsCheckbox = autoSpellsCheckbox
    HookWheelForward(autoSpellsCheckbox)

    local autoSpellsDesc = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    autoSpellsDesc:SetPoint("TOPLEFT", autoSpellsCheckbox, "BOTTOMLEFT", 25, -5)
    autoSpellsDesc:SetWidth(CONTENT_WIDTH - 60)
    autoSpellsDesc:SetJustifyH("LEFT")
    autoSpellsDesc:SetTextColor(0.9, 0.9, 0.9)
    autoSpellsDesc:SetText(
        "Automatically restores all spell and ability placements\non your action bars exactly as they were in your\nprevious run.")
    yOffset = yOffset - 60

    local floatingTextCheckbox = CreateFrame("CheckButton", "ProjectEbonholdFloatingTextCheckbox", p,
        "InterfaceOptionsCheckButtonTemplate")
    floatingTextCheckbox:SetPoint("TOPLEFT", 16, yOffset)
    _G[floatingTextCheckbox:GetName() .. "Text"]:SetText("Show floating text for Intensity and Soul Ashes")
    floatingTextCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() == 1
        ProjectEbonholdOptionsService:SetSetting("showFloatingText", checked)
    end)
    frame.floatingTextCheckbox = floatingTextCheckbox
    HookWheelForward(floatingTextCheckbox)

    local floatingTextDesc = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    floatingTextDesc:SetPoint("TOPLEFT", floatingTextCheckbox, "BOTTOMLEFT", 25, -5)
    floatingTextDesc:SetWidth(CONTENT_WIDTH - 60)
    floatingTextDesc:SetJustifyH("LEFT")
    floatingTextDesc:SetTextColor(0.9, 0.9, 0.9)
    floatingTextDesc:SetText(
        "Displays floating text animations when you gain or lose\nIntensity and Soul Ashes during your run.")
    yOffset = yOffset - 60

    local hideLevelUpCheckbox = CreateFrame("CheckButton", "ProjectEbonholdHideLevelUpCheckbox", p,
        "InterfaceOptionsCheckButtonTemplate")
    hideLevelUpCheckbox:SetPoint("TOPLEFT", 16, yOffset)
    _G[hideLevelUpCheckbox:GetName() .. "Text"]:SetText("Hide level up notifications")
    hideLevelUpCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() == 1
        ProjectEbonholdOptionsService:SetSetting("hideLevelUpFrame", checked)
    end)
    frame.hideLevelUpCheckbox = hideLevelUpCheckbox
    HookWheelForward(hideLevelUpCheckbox)

    local hideLevelUpDesc = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hideLevelUpDesc:SetPoint("TOPLEFT", hideLevelUpCheckbox, "BOTTOMLEFT", 25, -5)
    hideLevelUpDesc:SetWidth(CONTENT_WIDTH - 60)
    hideLevelUpDesc:SetJustifyH("LEFT")
    hideLevelUpDesc:SetTextColor(0.9, 0.9, 0.9)
    hideLevelUpDesc:SetText(
        "Hides the level up frame and spell unlock notifications\nwhen you gain a level.")
    yOffset = yOffset - 60

    -- ── Section: Perk Selection UI ───────────────────────────────────────────
    local perkUIHeader = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    perkUIHeader:SetPoint("TOPLEFT", 12, yOffset)
    perkUIHeader:SetText("Perk Selection UI")
    yOffset = yOffset - 28

    local function AddPerkCheckbox(name, label, desc, settingKey)
        local cb = CreateFrame("CheckButton", "ProjectEbonhold" .. name .. "Checkbox", p,
            "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, yOffset)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnClick", function(self)
            ProjectEbonholdOptionsService:SetSetting(settingKey, self:GetChecked() == 1)
        end)
        frame[name .. "Checkbox"] = cb
        HookWheelForward(cb)

        local d = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        d:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 25, -3)
        d:SetWidth(CONTENT_WIDTH - 60)
        d:SetJustifyH("LEFT")
        d:SetTextColor(0.9, 0.9, 0.9)
        d:SetText(desc)
        yOffset = yOffset - 46
        return cb
    end

    frame.noPerkFadeCheckbox       = AddPerkCheckbox("NoPerkFade", "Disable echo/banish fade animations",
        "Removes fade in and fade out transitions from echo choices and the banish animation.", "noPerkFadeAnimations")

    frame.noRerollConfirmCheckbox  = AddPerkCheckbox("NoRerollConfirm", "Remove Reroll confirmation prompt",
        "Reroll fires immediately without showing a confirmation dialog.", "noRerollConfirm")

    frame.rerollAutoRepopCheckbox  = AddPerkCheckbox("RerollAutoRepop", "Reroll auto-repopulates choices",
        "After a reroll, new echo choices appear automatically without pressing 'Choose an Echo' again.", "rerollAutoRepopulate")

    frame.echoesLevelUpCheckbox    = AddPerkCheckbox("EchoesLevelUp", "Keep echoes visible when leveling up",
        "New choices from a level-up replace the current ones in-place instead of hiding them.", "echoesVisibleOnLevelUp")

    frame.autoShowEchoesCheckbox   = AddPerkCheckbox("AutoShowEchoes", "Auto-show echo choices",
        "Echo choices appear immediately without needing to click 'Choose an Echo'.", "autoShowEchoes")

    frame.perkDirectBanishCheckbox = AddPerkCheckbox("PerkDirectBanish", "Show per-echo Banish button",
        "Adds a one-click Banish button beneath the Select button on each echo choice frame.", "perkDirectBanish")

    frame.perkShowSelectCountCheckbox = AddPerkCheckbox("PerkShowSelectCount", "Show count on Select button",
        "Displays the remaining rolls count in parentheses on each Select button.", "perkShowSelectCount")

    -- Scale slider
    local scaleLabel = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 16, yOffset)
    scaleLabel:SetText("Perk UI Scale: 100%")
    frame.perkUIScaleLabel = scaleLabel
    yOffset = yOffset - 20

    local scaleSlider = CreateFrame("Slider", "ProjectEbonholdPerkUIScaleSlider", p, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", 16, yOffset)
    scaleSlider:SetWidth(220)
    scaleSlider:SetMinMaxValues(50, 200)
    scaleSlider:SetValueStep(5)
    scaleSlider:SetValue(100)
    _G["ProjectEbonholdPerkUIScaleSliderLow"]:SetText("50%")
    _G["ProjectEbonholdPerkUIScaleSliderHigh"]:SetText("200%")
    _G["ProjectEbonholdPerkUIScaleSliderText"]:SetText("")
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 5 + 0.5) * 5
        scaleLabel:SetText("Perk UI Scale: " .. value .. "%")
        local scale = value / 100
        ProjectEbonholdOptionsService:SetSetting("perkUIScale", scale)
        -- Apply live so the user can see the change immediately
        ProjectEbonholdDB = ProjectEbonholdDB or {}
        ProjectEbonholdDB.perkUIScale = scale
        if ProjectEbonhold and ProjectEbonhold.PerkUI and ProjectEbonhold.PerkUI.ApplyScale then
            ProjectEbonhold.PerkUI.ApplyScale(scale)
        end
    end)
    HookWheelForward(scaleSlider)
    frame.perkUIScaleSlider = scaleSlider

    local scaleDesc = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    scaleDesc:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -8)
    scaleDesc:SetWidth(CONTENT_WIDTH - 60)
    scaleDesc:SetJustifyH("LEFT")
    scaleDesc:SetTextColor(0.9, 0.9, 0.9)
    scaleDesc:SetText("Scales the echo selection frame. Adjustable in Interface > Addons > Project Ebonhold.")
    yOffset = yOffset - 55

    -- ── Section: Visual ──────────────────────────────────────────────────────
    local visualHeader = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    visualHeader:SetPoint("TOPLEFT", 12, yOffset)
    visualHeader:SetText("Visual")
    yOffset = yOffset - 28

    frame.TransparentDesignCheckbox = AddPerkCheckbox("TransparentDesign", "Transparent design",
        "Replaces textured backgrounds with a clean, semi-transparent dark overlay on the player run frame, echoes panel, and perk selection cards. Requires /reload to take effect.",
        "transparentDesign")

    -- Set scrollChild height to fit all content
    scrollChild:SetHeight(math.abs(yOffset) + 20)

    frame.refresh = function()
        OptionsPanel:RefreshSettings()
    end

    return frame
end


function OptionsPanel:RefreshSettings()
    if not optionsFrame then return end

    optionsFrame.autoSpellsCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("autoPlaceSpells"))
    optionsFrame.floatingTextCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("showFloatingText"))
    optionsFrame.hideLevelUpCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("hideLevelUpFrame"))

    -- Perk UI options
    optionsFrame.NoPerkFadeCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("noPerkFadeAnimations"))
    optionsFrame.NoRerollConfirmCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("noRerollConfirm"))
    optionsFrame.RerollAutoRepopCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("rerollAutoRepopulate"))
    optionsFrame.EchoesLevelUpCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("echoesVisibleOnLevelUp"))
    optionsFrame.AutoShowEchoesCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("autoShowEchoes"))
    optionsFrame.PerkDirectBanishCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("perkDirectBanish"))
    optionsFrame.PerkShowSelectCountCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("perkShowSelectCount"))
    optionsFrame.TransparentDesignCheckbox:SetChecked(ProjectEbonholdOptionsService:GetSetting("transparentDesign"))

    local scale = ProjectEbonholdOptionsService:GetSetting("perkUIScale") or 1.0
    local pct = math.floor(scale * 100 + 0.5)
    optionsFrame.perkUIScaleSlider:SetValue(pct)
    optionsFrame.perkUIScaleLabel:SetText("Perk UI Scale: " .. pct .. "%")
end

function OptionsPanel:Initialize()
    ProjectEbonholdOptionsService:Initialize()


    optionsFrame = CreateOptionsFrame()


    InterfaceOptions_AddCategory(optionsFrame)


    self:RefreshSettings()


    SLASH_PROJECTEBONHOLD1 = "/projectebonhold"
    SLASH_PROJECTEBONHOLD2 = "/peb"
    SlashCmdList["PROJECTEBONHOLD"] = function(msg)
        InterfaceOptionsFrame_OpenToCategory(optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(optionsFrame)
    end

    -- print("|cff00ff00[Project Ebonhold]|r Options loaded. Type /peb to open settings.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == ADDON_NAME then
        OptionsPanel:Initialize()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
