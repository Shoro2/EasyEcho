local addonName, addon = ...

ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.WorldChannelUI = {}

-- Create the popup frame
local popup = CreateFrame("Frame", "WorldChannelPopupFrame", UIParent)
popup:SetWidth(400)
popup:SetHeight(160)
popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
popup:SetFrameStrata("DIALOG")
popup:SetFrameLevel(100)
popup:Hide()

-- Background
popup.bg = popup:CreateTexture(nil, "BACKGROUND")
popup.bg:SetPoint("TOPLEFT", popup, "TOPLEFT", 11, -12)
popup.bg:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -12, 11)
popup.bg:SetTexture(0, 0, 0, 0.9)

-- Border
popup.border = CreateFrame("Frame", nil, popup)
popup.border:SetAllPoints()
popup.border:SetBackdrop({
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

-- Title
popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
popup.title:SetPoint("TOP", popup, "TOP", 0, -20)
popup.title:SetText("|cff00ff00Join World Channel|r")

-- Message
popup.message = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
popup.message:SetPoint("TOP", popup.title, "BOTTOM", 0, -20)
popup.message:SetWidth(360)
popup.message:SetJustifyH("CENTER")
popup.message:SetJustifyV("TOP")
popup.message:SetText("Would you like to join the 'world' channel to chat with the community?")

-- Accept Button
popup.acceptButton = utils.CreateSimpleCustomButton(
    popup,
    "Join Channel",
    function()
        PlaySound("igMainMenuOption")
        if ProjectEbonhold.WorldChannelService then
            ProjectEbonhold.WorldChannelService.JoinWorldChannel()
        end
        popup:Hide()
    end,
    160,
    40
)
popup.acceptButton:SetPoint("BOTTOM", popup, "BOTTOM", -85, 20)

popup.acceptButton:SetScript("OnEnter", function(self)
    PlaySound("igMainMenuOptionCheckBoxOn")
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Join the 'world' channel to chat with other players", 1, 1, 1)
    GameTooltip:Show()
end)

popup.acceptButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Decline Button
popup.declineButton = utils.CreateSimpleCustomButton(
    popup,
    "No Thanks",
    function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        if ProjectEbonhold.WorldChannelService then
            ProjectEbonhold.WorldChannelService.DeclineWorldChannel()
        end
        popup:Hide()
    end,
    160,
    40
)
popup.declineButton:SetPoint("BOTTOM", popup, "BOTTOM", 85, 20)

popup.declineButton:SetScript("OnEnter", function(self)
    PlaySound("igMainMenuOptionCheckBoxOn")
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("You can always join manually with /join world", 1, 1, 1)
    GameTooltip:Show()
end)

popup.declineButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Function to show the prompt
function ProjectEbonhold.WorldChannelUI.ShowPrompt()
    popup:Show()
    PlaySound("igQuestListOpen")
end

-- ESC key handler
tinsert(UISpecialFrames, "WorldChannelPopupFrame")
