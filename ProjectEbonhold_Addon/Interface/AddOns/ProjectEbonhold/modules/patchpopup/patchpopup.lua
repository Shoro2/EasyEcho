


local addonName, addon = ...


local popup = CreateFrame("Frame", "PatchPopupFrame", UIParent)
popup:SetWidth(400)
popup:SetHeight(240)
popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
popup:SetFrameStrata("FULLSCREEN_DIALOG")
popup:SetFrameLevel(100)
popup:Hide()


popup.bg = popup:CreateTexture(nil, "BACKGROUND")
popup.bg:SetPoint("TOPLEFT", popup, "TOPLEFT", 11, -12)
popup.bg:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -12, 11)
popup.bg:SetTexture(0, 0, 0, 0.9)


popup.border = CreateFrame("Frame", nil, popup)
popup.border:SetAllPoints()
popup.border:SetBackdrop({
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})


popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
popup.title:SetPoint("TOP", popup, "TOP", 0, -20)
popup.title:SetText("|cffff0000Game not up to date|r")


popup.message = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popup.message:SetPoint("TOP", popup.title, "BOTTOM", 0, -20)
popup.message:SetWidth(360)
popup.message:SetJustifyH("CENTER")
popup.message:SetJustifyV("TOP")


popup.requiredVersion = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
popup.requiredVersion:SetPoint("TOP", popup.message, "BOTTOM", 0, -20)
popup.requiredVersion:SetWidth(360)


popup.instructions = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popup.instructions:SetPoint("TOP", popup.message, "BOTTOM", 0, -20)
popup.instructions:SetWidth(360)
popup.instructions:SetJustifyH("CENTER")
popup.instructions:SetText("")


popup.quitButton = utils.CreateSimpleCustomButton(
    popup,
    "Quit Game",
    function()
        PlaySound("igMainMenuQuit")
        Quit()
    end,
    180,
    50
)
popup.quitButton:SetPoint("BOTTOM", popup, "BOTTOM", 0, 20)


popup.quitButton:SetScript("OnEnter", function(self)
    PlaySound("igMainMenuOptionCheckBoxOn")
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Will exit your game", 1, 1, 1)
    GameTooltip:Show()
end)

popup.quitButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)


function popup:ShowPatchError(requiredPatch)
    self.message:SetText(
        "Your game installation is not up to date.\n\nIf you use the launcher, just restart your game with it to start the update.\n\nIf you opted for manual installation, re-download required files from the website, clear your cache and restart your game.")
    self.isPersistent = true
    self:Show()
    
    PlaySound("igQuestFailed")
end


popup:SetScript("OnHide", function(self)
    if self.isPersistent then
        C_Timer.After(0.1, function()
            if self.isPersistent then
                self:Show()
            end
        end)
    end
end)


PatchPopup = popup
