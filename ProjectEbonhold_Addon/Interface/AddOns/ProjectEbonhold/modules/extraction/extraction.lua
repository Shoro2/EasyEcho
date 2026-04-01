local addonName, addon = ...

ExtractionUI = ExtractionUI or {}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------


local function FormatCopperSmall(copperAmount)
    if not copperAmount or copperAmount == 0 then return GetCoinTextureString(0, 10) end
    return GetCoinTextureString(copperAmount, 10)
end

-- Returns true if the item link has a random property suffix (affix / corruption)
local function HasRandomProperty(link)
    if not link then return false end
    -- Full link: |cff...|Hitem:id:enchant:gem1:gem2:gem3:gem4:suffixId:uniqueId:level:...|h[Name]|h|r
    -- strsplit(":") field 1 = "|cff...|Hitem", field 2 = id, ..., field 8 = suffixId
    local randomProp = select(8, strsplit(":", link))
    if randomProp then
        randomProp = tonumber(randomProp)
        if randomProp and randomProp ~= 0 then
            return true
        end
    end
    return false
end

-- Hidden tooltip for scanning equipped item affix text
local scanTooltip = CreateFrame("GameTooltip", "EbonholdAffixScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Scan all equipped items and return a table { [spellId] = count }
local function CountEquippedAffixes(learnedAffixes)
    local counts = {}
    if not learnedAffixes or #learnedAffixes == 0 then return counts end

    -- Build lowercase name -> spellId lookup
    local nameToId = {}
    for _, affix in ipairs(learnedAffixes) do
        if affix.name then
            nameToId[affix.name:lower()] = affix.id
        end
        counts[affix.id] = 0
    end

    -- Equipment slots 1..19
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link and HasRandomProperty(link) then
            scanTooltip:ClearLines()
            scanTooltip:SetInventoryItem("player", slot)
            local foundInSlot = {} -- only count each affix once per item
            for j = 1, scanTooltip:NumLines() do
                local lineObj = _G["EbonholdAffixScanTooltipTextLeft" .. j]
                if lineObj then
                    local text = lineObj:GetText()
                    if text then
                        local lower = text:lower()
                        for name, id in pairs(nameToId) do
                            if not foundInSlot[id] then
                                local startPos, endPos = lower:find(name, 1, true)
                                if startPos then
                                    local before = startPos > 1 and lower:sub(startPos - 1, startPos - 1) or ""
                                    local after = lower:sub(endPos + 1, endPos + 1)
                                    if (before == "" or not before:match("%w")) and (after == "" or not after:match("%w")) then
                                        counts[id] = (counts[id] or 0) + 1
                                        foundInSlot[id] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return counts
end

------------------------------------------------------------
-- Confirmation dialog
------------------------------------------------------------

StaticPopupDialogs["EBONHOLD_CONFIRM_EXTRACTION"]  = {
    text = "This will destroy the item and extract its affix.\n\nContinue?",
    button1 = "Confirm",
    button2 = "Cancel",
    OnAccept = function()
        if ExtractionUI.pendingBag and ExtractionUI.pendingSlot then
            ExtractionService.RequestExtraction(ExtractionUI.pendingBag, ExtractionUI.pendingSlot)
        end
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["EBONHOLD_CONFIRM_APPLY_AFFIX"] = {
    text = "Apply the selected affix to this item?\n\nContinue?",
    button1 = "Confirm",
    button2 = "Cancel",
    OnAccept = function()
        if ExtractionUI.pendingBag and ExtractionUI.pendingSlot and ExtractionUI.selectedAffixId then
            ExtractionService.RequestApplyAffix(ExtractionUI.selectedAffixId, ExtractionUI.pendingBag,
                ExtractionUI.pendingSlot)
        end
    end,
    timeout = 0,
    whileDead = false,
    hideOnEscape = true,
    preferredIndex = 3,
}

------------------------------------------------------------
-- Main Frame
------------------------------------------------------------

local FRAME_WIDTH                                  = 300
local FRAME_HEIGHT                                 = 300
local SLOT_SIZE                                    = 42
local TITLE_BAR_HEIGHT                             = 24
local BOTTOM_BAR_HEIGHT                            = 30

local isInExtractionGossip                         = false

local frame                                        = CreateFrame("Frame", "EbonholdExtractionFrame", UIParent)
frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
frame:SetPoint("CENTER")
frame:SetFrameStrata("HIGH")
frame:SetToplevel(true)
frame:SetFrameLevel(100)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

-- ESC to close
table.insert(UISpecialFrames, "EbonholdExtractionFrame")

------------------------------------------------------------
-- Background & border
------------------------------------------------------------

frame.bgBlack = frame:CreateTexture(nil, "BACKGROUND")
frame.bgBlack:SetTexture(0, 0, 0, 1)
frame.bgBlack:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
frame.bgBlack:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)

frame.bgForge = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
frame.bgForge:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\obliterumforge")
frame.bgForge:SetTexCoord(0.000000, 0.632812, 0.000000, 0.628906)
frame.bgForge:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -(56 + TITLE_BAR_HEIGHT))
frame.bgForge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 56 + BOTTOM_BAR_HEIGHT)

frame:SetBackdrop({
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})

------------------------------------------------------------
-- Title bar
------------------------------------------------------------

frame.titleBar = frame:CreateTexture(nil, "ARTWORK")
frame.titleBar:SetTexture(0, 0, 0, 0.6)
frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
frame.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
frame.titleBar:SetHeight(TITLE_BAR_HEIGHT)

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("CENTER", frame.titleBar, "CENTER", 0, -16)
frame.title:SetText("Enchanted Anvil")

------------------------------------------------------------
-- Close button
------------------------------------------------------------

frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
frame.closeButton:SetPoint("TOPRIGHT", -2, -2)
frame.closeButton:SetScript("OnClick", function() frame:Hide() end)

------------------------------------------------------------
-- Item slot (drop target) - centered in the background area
------------------------------------------------------------

local slot = CreateFrame("Button", "EbonholdExtractionSlot", frame)
slot:SetSize(SLOT_SIZE, SLOT_SIZE)
slot:SetPoint("CENTER", frame, "CENTER", 0, 5)

slot.bg = slot:CreateTexture(nil, "BACKGROUND")
slot.bg:SetAllPoints()

slot.icon = slot:CreateTexture(nil, "ARTWORK")
slot.icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -3)
slot.icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -3, 3)
slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
slot.icon:Hide()

slot.highlight = slot:CreateTexture(nil, "HIGHLIGHT")
slot.highlight:SetAllPoints()
slot.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
slot.highlight:SetBlendMode("ADD")

-- Hint label under the slot
frame.hintText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frame.hintText:SetPoint("TOP", slot, "BOTTOM", 0, -28)
frame.hintText:SetText("|cff888888Drop an item here to extract its affixes or apply any affixes you already know.|r")
frame.hintText:SetWidth(FRAME_WIDTH - 40)
frame.hintText:SetJustifyH("CENTER")

------------------------------------------------------------
-- Bottom bar: cost on the left, extract button on the right
------------------------------------------------------------

frame.bottomBar = frame:CreateTexture(nil, "ARTWORK")
frame.bottomBar:SetTexture(0, 0, 0, 0.6)
frame.bottomBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
frame.bottomBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
frame.bottomBar:SetHeight(BOTTOM_BAR_HEIGHT)

local extractBtn = utils.CreateCustomButton(nil, frame, { width = 130, height = 34 }, "Extract", nil)
extractBtn:SetPoint("LEFT", frame.bottomBar, "LEFT", 14, 30)
extractBtn:Disable()
extractBtn:Hide()
if extractBtn.text then extractBtn.text:SetFont("Fonts\\FRIZQT__.TTF", 10) end

local applyBtn = utils.CreateCustomButton(nil, frame, { width = 130, height = 34 }, "Choose an Affix", nil)
applyBtn:SetPoint("RIGHT", frame.bottomBar, "RIGHT", -14, 30)
applyBtn:Disable()
applyBtn:Hide()
if applyBtn.text then applyBtn.text:SetFont("Fonts\\FRIZQT__.TTF", 10) end

frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.statusText:SetPoint("BOTTOM", frame.bottomBar, "BOTTOM", 0, 7)
frame.statusText:SetText("")
frame.statusText:SetWidth(FRAME_WIDTH - 30)
frame.statusText:SetJustifyH("CENTER")
frame.statusText:SetWordWrap(true)

ExtractionUI.pendingBag      = nil
ExtractionUI.pendingSlot     = nil
ExtractionUI.pendingLink     = nil
ExtractionUI.selectedAffixId = nil

local function HideSidePanel()
    if frame.sidePanel then
        frame.sidePanel:Hide()
    end
    ExtractionUI.selectedAffixId = nil
end

local function ClearSlot()
    ExtractionUI.pendingBag      = nil
    ExtractionUI.pendingSlot     = nil
    ExtractionUI.pendingLink     = nil
    ExtractionUI.selectedAffixId = nil

    slot.icon:Hide()
    frame.hintText:SetText("|cff888888Drop an item here to extract its affixes or apply any affixes you already know.|r")
    extractBtn:SetText("Extract")
    extractBtn:Disable()
    extractBtn:Hide()
    applyBtn:SetText("Choose an Affix")
    applyBtn:Disable()
    applyBtn:Hide()
    HideSidePanel()
end

local function UpdateButtonVisibility()
    if not ExtractionUI.pendingLink then
        extractBtn:Hide()
        applyBtn:Hide()
        return
    end

    local hasAffix = HasRandomProperty(ExtractionUI.pendingLink)

    -- Check item level for apply eligibility
    local _, _, _, itemLevel = GetItemInfo(ExtractionUI.pendingLink)
    local canApply = itemLevel and itemLevel >= 200

    -- Extract: only when item has affix
    if hasAffix then
        extractBtn:Show()
        extractBtn:Enable()
    else
        extractBtn:Hide()
    end

    -- Apply: only when item level >= 200
    if canApply then
        applyBtn:Show()
        applyBtn:Enable()
    else
        applyBtn:Hide()
    end

    -- Re-center if only one button visible
    extractBtn:ClearAllPoints()
    applyBtn:ClearAllPoints()
    if hasAffix and canApply then
        extractBtn:SetPoint("RIGHT", frame.bottomBar, "CENTER", -5, 30)
        applyBtn:SetPoint("LEFT", frame.bottomBar, "CENTER", 5, 30)
    elseif hasAffix then
        extractBtn:SetPoint("CENTER", frame.bottomBar, "CENTER", 0, 30)
    elseif canApply then
        applyBtn:SetPoint("CENTER", frame.bottomBar, "CENTER", 0, 30)
    end
end

local function UpdateCostDisplay()
    local extractCost = ExtractionService.currentCost
    local extractCoinStr = extractCost and FormatCopperSmall(extractCost) or ""

    -- Update Extract button text with extraction cost
    if ExtractionUI.pendingLink and HasRandomProperty(ExtractionUI.pendingLink) then
        extractBtn:SetText("Extract  " .. extractCoinStr)
    else
        extractBtn:SetText("Extract")
    end

    -- Update Apply button text: if affix selected, show "Apply Affix" + per-affix cost
    local itemHasAffix = HasRandomProperty(ExtractionUI.pendingLink)
    if ExtractionUI.selectedAffixId then
        local applyCost = ExtractionService.applyCost
        local applyCoinStr = applyCost and FormatCopperSmall(applyCost) or ""
        local label = itemHasAffix and "Change Affix  " or "Apply Affix  "
        applyBtn:SetText(label .. applyCoinStr)
    else
        applyBtn:SetText(itemHasAffix and "Change the Affix" or "Choose an Affix")
    end

    UpdateButtonVisibility()
end

local function SetSlotItem(bag, slotIdx, link, texture)
    ExtractionUI.pendingBag  = bag
    ExtractionUI.pendingSlot = slotIdx
    ExtractionUI.pendingLink = link

    slot.icon:SetTexture(texture)
    slot.icon:Show()

    local itemName = GetItemInfo(link)
    frame.hintText:SetText(link or itemName or "")
    frame.statusText:SetText("")

    ExtractionService.RequestExtractionInfo(bag, slotIdx)
    UpdateCostDisplay()
end

------------------------------------------------------------
-- Slot click / drop handling
------------------------------------------------------------

slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")

slot:SetScript("OnReceiveDrag", function(self)
    if not CursorHasItem() then return end

    local infoType, itemId, itemLink = GetCursorInfo()
    if infoType ~= "item" then
        ClearCursor()
        return
    end

    -- Find bag/slot by scanning containers
    local foundBag, foundSlot
    for b = 0, 4 do
        for s = 1, GetContainerNumSlots(b) do
            local containerLink = GetContainerItemLink(b, s)
            if containerLink and containerLink == itemLink then
                foundBag  = b
                foundSlot = s
                break
            end
        end
        if foundBag then break end
    end

    ClearCursor()

    if not foundBag then
        frame.statusText:SetText("|cffff0000Could not locate the item in your bags.|r")
        return
    end

    -- Validate: must be equipable and at least green (uncommon) quality
    local _, _, itemQuality, itemLevel, _, _, _, _, itemEquipLoc, texture = GetItemInfo(itemLink)
    if not itemEquipLoc or itemEquipLoc == "" or itemEquipLoc == "INVTYPE_NON_EQUIP" then
        frame.statusText:SetText("|cffff0000Only equipable items can be placed here.|r")
        return
    end
    if not itemQuality or itemQuality < 2 then
        frame.statusText:SetText("|cffff0000Only items of uncommon (green) quality or higher.|r")
        return
    end
    if not itemLevel or itemLevel < 200 then
        frame.statusText:SetText("|cffff0000Only items with item level 200 or higher.|r")
        return
    end

    -- Convert Lua bag/slot to TrinityCore GetItemByPos(bag, slot) format:
    -- Backpack: bag 0 → 255, slot 1-based → absolute index (INVENTORY_SLOT_ITEM_START + slot - 1 = 22 + slot)
    -- Bags 1-4: bag N → equipped bag slot (18 + N), slot 1-based → 0-based (slot - 1)
    local serverBag, serverSlot
    if foundBag == 0 then
        serverBag  = 255
        serverSlot = 22 + foundSlot -- INVENTORY_SLOT_ITEM_START (23) + foundSlot - 1
    else
        serverBag  = 18 + foundBag  -- INVENTORY_SLOT_BAG_START (19) + foundBag - 1
        serverSlot = foundSlot - 1  -- 0-based within the bag
    end
    SetSlotItem(serverBag, serverSlot, itemLink, texture)
end)

slot:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        ClearSlot()
        return
    end

    -- LeftButton: accept drop from cursor
    if CursorHasItem() then
        self:GetScript("OnReceiveDrag")(self)
    end
end)

-- Tooltip
slot:SetScript("OnEnter", function(self)
    if ExtractionUI.pendingLink then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(ExtractionUI.pendingLink)
        GameTooltip:Show()
    else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd700Affix Extraction|r")
        GameTooltip:AddLine("Drop an item with a random property (affix) here\nto extract its corruption.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff888888Right-click to clear the slot|r", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end
end)

slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

------------------------------------------------------------
-- Extract button handler
------------------------------------------------------------

extractBtn:SetScript("OnClick", function()
    if not ExtractionUI.pendingBag or not ExtractionUI.pendingSlot then return end
    StaticPopup_Show("EBONHOLD_CONFIRM_EXTRACTION")
end)

applyBtn:SetScript("OnClick", function()
    if not ExtractionUI.pendingBag or not ExtractionUI.pendingSlot then return end
    -- Toggle side panel
    if frame.sidePanel and frame.sidePanel:IsShown() then
        HideSidePanel()
    else
        ExtractionUI.ShowSidePanel()
    end
end)

function ExtractionUI.OnCostReceived(cost)
    if not frame:IsShown() then return end
    UpdateCostDisplay()
end

function ExtractionUI.OnExtractionSuccess()
    if not frame:IsShown() then return end
    frame.statusText:SetText("|cff00ff00Affix extracted successfully!|r")
    ClearSlot()
    UpdateCostDisplay()
end

function ExtractionUI.OnExtractionFail(reason)
    if not frame:IsShown() then return end
    frame.statusText:SetText("|cffff0000" .. (reason or "Extraction failed.") .. "|r")
end

function ExtractionUI.OnApplySuccess()
    if not frame:IsShown() then return end
    frame.statusText:SetText("|cff00ff00Affix applied successfully!|r")
    HideSidePanel()
    ClearSlot()
    UpdateCostDisplay()
end

function ExtractionUI.OnApplyFail(reason)
    if not frame:IsShown() then return end
    frame.statusText:SetText("|cffff0000" .. (reason or "Apply failed.") .. "|r")
end

function ExtractionUI.OnApplyCostReceived(cost)
    if not frame:IsShown() then return end
    UpdateCostDisplay()
    -- Update confirm button with cost
    if frame.sidePanel and frame.sidePanel.confirmBtn and ExtractionUI.selectedAffixId then
        local coinStr = cost and FormatCopperSmall(cost) or ""
        frame.sidePanel.confirmBtn:SetText("Confirm  " .. coinStr)
    end
end

function ExtractionUI.OnLearnedAffixesReceived()
    if frame.sidePanel and frame.sidePanel:IsShown() then
        ExtractionUI.PopulateSidePanel()
    end
end

------------------------------------------------------------
-- OnHide cleanup
------------------------------------------------------------

frame:SetScript("OnHide", function()
    ClearSlot()
    frame.statusText:SetText("")
    HideSidePanel()
    if isInExtractionGossip then
        isInExtractionGossip = false
        if GossipFrame then
            GossipFrame:SetAlpha(1)
            GossipFrame:EnableMouse(true)
            GossipFrame:ClearAllPoints()
            GossipFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        end
        if GossipFrameCloseButton then
            GossipFrameCloseButton:Click()
        end
    end
end)

------------------------------------------------------------
-- Side panel (Affix Book)
------------------------------------------------------------

local SIDE_PANEL_WIDTH = 220
local AFFIX_ROW_HEIGHT = 28

local function CreateSidePanel()
    local panel = CreateFrame("Frame", "EbonholdAffixBookPanel", frame)
    panel:SetSize(SIDE_PANEL_WIDTH, FRAME_HEIGHT)
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", -2, 0)
    panel:SetFrameStrata("HIGH")
    panel:SetToplevel(true)
    panel:SetFrameLevel(frame:GetFrameLevel() + 1)
    panel:EnableMouse(true)
    panel:Hide()

    panel.bgTexture = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    panel.bgTexture:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\UI-Background-Rock")
    panel.bgTexture:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    panel.bgTexture:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)

    panel:SetBackdrop({
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Title
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOP", panel, "TOP", 0, -25)
    panel.title:SetText("Affix Book")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", "EbonholdAffixBookScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -(12 + TITLE_BAR_HEIGHT + 16))
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 56)
    panel.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    panel.scrollChild = scrollChild

    -- Empty text
    panel.emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.emptyText:SetPoint("CENTER", scrollChild, "CENTER", 0, -15)
    panel.emptyText:SetText("No Affixes learned.\nTo learn more, extract them\nfrom any piece of gear.")
    panel.emptyText:Hide()

    -- Confirm button at bottom of side panel
    panel.confirmBtn = utils.CreateCustomButton(nil, panel, { width = 190, height = 30 }, "Confirm Apply", function()
        if ExtractionUI.pendingBag and ExtractionUI.pendingSlot and ExtractionUI.selectedAffixId then
            StaticPopup_Show("EBONHOLD_CONFIRM_APPLY_AFFIX")
        end
    end)
    panel.confirmBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 20)
    panel.confirmBtn:Disable()
    if panel.confirmBtn.text then panel.confirmBtn.text:SetFont("Fonts\\FRIZQT__.TTF", 10) end
    panel.affixRows = {}
    return panel
end

function ExtractionUI.PopulateSidePanel()
    local panel = frame.sidePanel
    if not panel then return end

    -- Clear old rows
    for _, row in ipairs(panel.affixRows) do
        row:Hide()
    end
    panel.affixRows = {}
    ExtractionUI.selectedAffixId = nil
    panel.confirmBtn:Disable()

    local affixes = ExtractionService.learnedAffixes or {}
    local equippedCounts = CountEquippedAffixes(affixes)
    local contentHeight = math.max(#affixes * AFFIX_ROW_HEIGHT, 1)
    panel.scrollChild:SetHeight(contentHeight)

    if #affixes == 0 then
        panel.emptyText:Show()
    else
        panel.emptyText:Hide()
    end

    for i, affix in ipairs(affixes) do
        local row = CreateFrame("Button", nil, panel.scrollChild)
        row:SetSize(panel.scrollChild:GetWidth(), AFFIX_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", panel.scrollChild, "TOPLEFT", 0, -(i - 1) * AFFIX_ROW_HEIGHT)

        row.affixId = affix.id

        -- Highlight
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetTexture(1, 1, 1, 0.15)
        row.highlight:Hide()

        -- Hover highlight
        row.hoverTex = row:CreateTexture(nil, "HIGHLIGHT")
        row.hoverTex:SetAllPoints()
        row.hoverTex:SetTexture(1, 1, 1, 0.08)

        -- Icon (round via SetPortraitToTexture)
        local iconSize = AFFIX_ROW_HEIGHT - 4
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(iconSize, iconSize)
        row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        if affix.icon then
            SetPortraitToTexture(row.icon, affix.icon)
        else
            SetPortraitToTexture(row.icon, "Interface\\Icons\\INV_Misc_QuestionMark")
        end

        -- Round border overlay
        row.iconBorder = row:CreateTexture(nil, "OVERLAY")
        row.iconBorder:SetSize(iconSize + 32, iconSize + 32)
        row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
        row.iconBorder:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\roundborder")

        -- Name
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.nameText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)
        local displayName = affix.name or ("Affix " .. affix.id)
        local eqCount = equippedCounts[affix.id] or 0
        if eqCount > 0 then
            displayName = displayName .. "  |cff00ff00(x" .. eqCount .. ")|r"
        end
        row.nameText:SetText(displayName)

        -- Click to select
        row:SetScript("OnClick", function()
            -- Deselect all
            for _, r in ipairs(panel.affixRows) do
                r.highlight:Hide()
            end
            -- Select this one
            row.highlight:Show()
            ExtractionUI.selectedAffixId = affix.id
            panel.confirmBtn:Enable()
            -- Show cost from affix data directly
            local coinStr = affix.cost and FormatCopperSmall(affix.cost) or ""
            panel.confirmBtn:SetText("Confirm  " .. coinStr)
            -- Store apply cost for the main button display
            ExtractionService.applyCost = affix.cost
            UpdateCostDisplay()
        end)

        -- Tooltip
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(affix.id)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        panel.affixRows[i] = row
    end
end

function ExtractionUI.ShowSidePanel()
    if not frame.sidePanel then
        frame.sidePanel = CreateSidePanel()
    end
    ExtractionService.RequestLearnedAffixes()
    ExtractionUI.PopulateSidePanel()
    frame.sidePanel:Show()
end

------------------------------------------------------------
-- Slash command to open the UI
------------------------------------------------------------

SLASH_EXTRACTION1 = "/extraction"
SLASH_EXTRACTION2 = "/affix"
SlashCmdList["EXTRACTION"] = function()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- Expose toggle for other UI elements
function ExtractionUI.Toggle()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

------------------------------------------------------------
-- Gossip-based open/close
------------------------------------------------------------

local gossipEventFrame = CreateFrame("Frame")
gossipEventFrame:RegisterEvent("GOSSIP_SHOW")
gossipEventFrame:RegisterEvent("GOSSIP_CLOSED")
gossipEventFrame:SetScript("OnEvent", function(self, event)
    if event == "GOSSIP_SHOW" then
        -- Only process if GossipFrame is actually visible (real gossip interaction)
        if not GossipFrame or not GossipFrame:IsShown() then
            return
        end

        local npcName = GossipFrameNpcNameText and GossipFrameNpcNameText:GetText()
        if npcName == "Enchanted Anvil" then
            isInExtractionGossip = true
            if GossipFrame then
                GossipFrame:SetAlpha(0)
                GossipFrame:EnableMouse(false)
                GossipFrame:ClearAllPoints()
                GossipFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 1000, -1000)
            end
            frame:Show()
        else
            if isInExtractionGossip then
                isInExtractionGossip = false
                frame:Hide()
            end
        end
    elseif event == "GOSSIP_CLOSED" then
        local wasInExtractionGossip = isInExtractionGossip
        isInExtractionGossip = false
        if wasInExtractionGossip and GossipFrame then
            GossipFrame:SetAlpha(1)
            GossipFrame:EnableMouse(true)
            GossipFrame:ClearAllPoints()
            GossipFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        end
        if wasInExtractionGossip then
            frame:Hide()
        end
    end
end)

-- Close extraction when other UI panels open
local function CloseExtractionIfOpen()
    if frame and frame:IsShown() then
        -- Reset GossipFrame properly
        if GossipFrame then
            GossipFrame:SetAlpha(1)
            GossipFrame:EnableMouse(true)
            GossipFrame:ClearAllPoints()
            GossipFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
        end
        isInExtractionGossip = false
        if GossipFrameCloseButton then
            GossipFrameCloseButton:Click()
        end
        frame:Hide()
    end
end

local framesToWatch = {
    "CharacterFrame",
    "TalentFrame",
    "SpellBookFrame",
    "QuestLogFrame",
    "QuestLogDetailFrame",
    "FriendsFrame",
    "PVPFrame",
    "AchievementFrame",
    "GuildFrame",
    "LFGParentFrame",
    "PlayerTalentFrame",
    "LFDParentFrame",
    "WorldMapFrame",
    "GameMenuFrame",
}

for _, frameName in ipairs(framesToWatch) do
    local f = _G[frameName]
    if f then
        f:HookScript("OnShow", CloseExtractionIfOpen)
    end
end
