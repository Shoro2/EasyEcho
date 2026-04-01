local perkMainFrame = nil
local perkFramePool = {}
local hideButton = nil
local rerollButton = nil
local banishButton = nil
local chooseButton = nil
local perkFamilyHintFrame = nil
local ShowPerkFamilyHint
local isFading = false
local isSelecting = false
local isShowingPerkUI = false
local banishMode = false
local PERK_CARDS_GRACE_SEC = 0.1
local perkCardsGraceUntil = 0

local function IsTransparentDesign()
    return ProjectEbonholdOptionsService and ProjectEbonholdOptionsService:GetSetting("transparentDesign")
end

local function IsPerkDirectBanishEnabled()
    return ProjectEbonholdOptionsService and ProjectEbonholdOptionsService:GetSetting("perkDirectBanish")
end

local function IsPerkShowSelectCountEnabled()
    return ProjectEbonholdOptionsService and ProjectEbonholdOptionsService:GetSetting("perkShowSelectCount")
end

local function GetSelectLabel(count)
    if IsPerkShowSelectCountEnabled() and count then
        return "Select (" .. count .. ")"
    end
    return "Select"
end

EbonholdAutoShowDB = EbonholdAutoShowDB or { enabled = false }
local autoClickDeferred = CreateFrame("Frame")
autoClickDeferred:Hide()
autoClickDeferred:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    self:Hide()
    if chooseButton and chooseButton:IsShown() then
        chooseButton:Click()
    end
end)

local function GetPerkUIScale()
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    local scale = ProjectEbonholdDB.perkUIScale or 1.0
    return math.max(0.5, math.min(3.0, scale))
end

local function ApplyPerkUIScale(scale)
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    ProjectEbonholdDB.perkUIScale = scale
    if perkMainFrame then
        perkMainFrame:SetScale(scale)
    end
    if chooseButton then
        chooseButton:SetScale(scale)
    end
end

local qualityInfo = {
    [0] = { name = "Common", color = { 1, 1, 1 }, border = 0 },
    [1] = { name = "Uncommon", color = { 0.1, 1.0, 0.1 }, border = 1 },
    [2] = { name = "Rare", color = { 0.0, 0.4, 1.0 }, border = 2 },
    [3] = { name = "Epic", color = { 0.6, 0.2, 1.0 }, border = 3 },
    [4] = { name = "Legendary", color = { 1.0, 0.5, 0.0 }, border = 4 }
}

local familyIcons = {
    ["Tank"]          = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\tank",
    ["Survivability"] = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\survivability",
    ["Healer"]        = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\healer",
    ["Caster"]        = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\caster_dps",
    ["Caster DPS"]    = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\caster_dps",
    ["Melee"]         = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\melee_dps",
    ["Melee DPS"]     = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\melee_dps",
    ["Ranged"]        = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\ranged_dps",
    ["Ranged DPS"]    = "Interface\\AddOns\\ProjectEbonhold\\assets\\perk_families\\ranged_dps",
}

local texCoords = {
    { 0.062500, 0.476562, 0.070312, 0.492188 },
    { 0.468750, 0.898438, 0.054688, 0.515625 },
    { 0.117188, 0.484375, 0.484375, 0.898438 },
    { 0.484375, 0.960938, 0.460938, 0.898438 }
}

local _emptyTable = {} -- shared sentinel; never written to

local function GetRerollInfo()
    local runData = ProjectEbonhold.PlayerRunService and ProjectEbonhold.PlayerRunService.GetCurrentData() or _emptyTable
    local usedRerolls = runData.usedRerolls or 0
    local totalRerolls = runData.totalRerolls or 0
    local availableRerolls = math.max(0, totalRerolls - usedRerolls)
    return availableRerolls, totalRerolls
end

local function GetBanishInfo()
    if not ProjectEbonhold.Constants or not ProjectEbonhold.Constants.ENABLE_BANISH_SYSTEM then
        return 0
    end
    local runData = ProjectEbonhold.PlayerRunService and ProjectEbonhold.PlayerRunService.GetCurrentData() or _emptyTable
    return runData.remainingBanishes or 0
end

-- Save/restore perk UI position (used when moving via Ctrl+drag on cards)
local function SavePerkUIPosition()
    if not perkMainFrame then return end
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    local point, _, relativePoint, x, y = perkMainFrame:GetPoint(1)
    ProjectEbonholdDB.perkUIPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function RestorePerkUIPosition()
    if not perkMainFrame then return end
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    local pos = ProjectEbonholdDB.perkUIPosition
    if pos and pos.point and pos.x and pos.y then
        perkMainFrame:ClearAllPoints()
        perkMainFrame:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.x, pos.y)
    end
end

local function SaveChooseButtonPosition()
    if not chooseButton then return end
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    local point, _, relativePoint, x, y = chooseButton:GetPoint(1)
    ProjectEbonholdDB.chooseButtonPosition = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function RestoreChooseButtonPosition()
    if not chooseButton then return end
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    local pos = ProjectEbonholdDB.chooseButtonPosition
    if pos and pos.point and pos.x and pos.y then
        chooseButton:ClearAllPoints()
        chooseButton:SetPoint(pos.point, UIParent, pos.relativePoint or "CENTER", pos.x, pos.y)
    end
end

-- Hide/Reroll buttons: Ctrl+drag to move, snap to card edges only (never behind cards). Position persisted.
-- Allowed snap: edges with 8px gap; vertical centering when snapping to LEFT/RIGHT.
local SNAP_GAP = 8
local SNAP_THRESHOLD = 25
local SNAP_THRESHOLD_SIDE = 40 -- larger for LEFT/RIGHT so vertically-centered placement snaps easily
local CARD_EDGES = {
    [1] = { "TOP", "LEFT", "BOTTOM" },
    [2] = { "TOP", "BOTTOM" },
    [3] = { "TOP", "RIGHT", "BOTTOM" },
}

local function GetCardFrameByIndex(cardIndex)
    if not cardIndex or cardIndex < 1 or cardIndex > 3 then return nil end
    for _, f in ipairs(perkFramePool) do
        if f.inUse and f.perkIndex == cardIndex - 1 then return f end
    end
    return nil
end

local function SaveHideButtonPosition()
    if not hideButton then return end
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    if hideButton._lastSnapCardIndex then
        local point, _, relativePoint, x, y = hideButton:GetPoint(1)
        ProjectEbonholdDB.hideButtonPosition = { point = point, relativePoint = relativePoint, x = x, y = y, cardIndex =
        hideButton._lastSnapCardIndex }
    else
        -- Store as offset from UIParent center; button stays parented to perkMainFrame
        local ux, uy = UIParent:GetCenter()
        local bx, by = hideButton:GetCenter()
        if ux and uy and bx and by then
            local scale = perkMainFrame:GetEffectiveScale()
            ProjectEbonholdDB.hideButtonPosition = { useUIParent = true, offsetX = bx - ux, offsetY = by - uy, scale =
            scale }
        end
    end
end

local function RestoreHideButtonPosition()
    if not hideButton or not perkMainFrame then return end
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    local pos = ProjectEbonholdDB.hideButtonPosition
    hideButton:ClearAllPoints()
    if pos and pos.useUIParent and pos.offsetX ~= nil and pos.offsetY ~= nil then
        -- Keep parented to perkMainFrame but anchor to UIParent; adjust offset for current scale
        hideButton:SetParent(perkMainFrame)
        local savedScale = pos.scale or 1.0
        local currentScale = perkMainFrame:GetEffectiveScale()
        local ratio = savedScale / currentScale
        hideButton:SetPoint("CENTER", UIParent, "CENTER", pos.offsetX * ratio, pos.offsetY * ratio)
        hideButton._lastSnapCardIndex = nil
        return
    end
    if pos and pos.point and pos.x ~= nil and pos.y ~= nil then
        if pos.cardIndex and GetCardFrameByIndex(pos.cardIndex) then
            hideButton:SetParent(perkMainFrame)
            local cardFrame = GetCardFrameByIndex(pos.cardIndex)
            local anchor = cardFrame.backdropFrame or cardFrame
            hideButton:SetPoint(pos.point, anchor, pos.relativePoint or "CENTER", pos.x, pos.y)
            hideButton._lastSnapCardIndex = pos.cardIndex
            return
        end
    end
    hideButton:SetParent(perkMainFrame)
    local mid = GetCardFrameByIndex(2)
    local anchor = mid and (mid.backdropFrame or mid) or perkMainFrame
    hideButton:SetPoint("TOP", anchor, "BOTTOM", 0, -SNAP_GAP)
    hideButton._lastSnapCardIndex = nil
end

local function SaveRerollButtonPosition()
    if not rerollButton then return end
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    if rerollButton._lastSnapCardIndex then
        local point, _, relativePoint, x, y = rerollButton:GetPoint(1)
        ProjectEbonholdDB.rerollButtonPosition = { point = point, relativePoint = relativePoint, x = x, y = y, cardIndex =
        rerollButton._lastSnapCardIndex }
    else
        -- Store as offset from UIParent center; button stays parented to perkMainFrame
        local ux, uy = UIParent:GetCenter()
        local bx, by = rerollButton:GetCenter()
        if ux and uy and bx and by then
            local scale = perkMainFrame:GetEffectiveScale()
            ProjectEbonholdDB.rerollButtonPosition = { useUIParent = true, offsetX = bx - ux, offsetY = by - uy, scale =
            scale }
        end
    end
end

local function RestoreRerollButtonPosition()
    if not rerollButton or not perkMainFrame then return end
    ProjectEbonholdDB = ProjectEbonholdDB or {}
    local pos = ProjectEbonholdDB.rerollButtonPosition
    -- Discard saved snap positions that are below the current minimum default (avoids
    -- overlap after a default offset change). Card-snapped positions use point="BOTTOM".
    local MIN_SNAP_Y = SNAP_GAP + 40
    if pos and pos.point == "BOTTOM" and (pos.y or 0) < MIN_SNAP_Y then
        pos = nil
        ProjectEbonholdDB.rerollButtonPosition = nil
    end
    rerollButton:ClearAllPoints()
    if pos and pos.useUIParent and pos.offsetX ~= nil and pos.offsetY ~= nil then
        -- Keep parented to perkMainFrame but anchor to UIParent; adjust offset for current scale
        rerollButton:SetParent(perkMainFrame)
        local savedScale = pos.scale or 1.0
        local currentScale = perkMainFrame:GetEffectiveScale()
        local ratio = savedScale / currentScale
        rerollButton:SetPoint("CENTER", UIParent, "CENTER", pos.offsetX * ratio, pos.offsetY * ratio)
        rerollButton._lastSnapCardIndex = nil
        return
    end
    if pos and pos.point and pos.x ~= nil and pos.y ~= nil then
        if pos.cardIndex and GetCardFrameByIndex(pos.cardIndex) then
            rerollButton:SetParent(perkMainFrame)
            local cardFrame = GetCardFrameByIndex(pos.cardIndex)
            local anchor = cardFrame.backdropFrame or cardFrame
            rerollButton:SetPoint(pos.point, anchor, pos.relativePoint or "CENTER", pos.x, pos.y)
            rerollButton._lastSnapCardIndex = pos.cardIndex
            return
        end
    end
    rerollButton:SetParent(perkMainFrame)
    local mid = GetCardFrameByIndex(2)
    local anchor = mid and (mid.backdropFrame or mid) or perkMainFrame
    rerollButton:SetPoint("BOTTOM", anchor, "TOP", -64, SNAP_GAP + 40)
    rerollButton._lastSnapCardIndex = nil
end

-- Distance from point (px, py) to horizontal line segment (x1,y) to (x2,y)
local function distToHorizSegment(px, py, x1, x2, y)
    if px < x1 then return math.sqrt((px - x1) ^ 2 + (py - y) ^ 2) end
    if px > x2 then return math.sqrt((px - x2) ^ 2 + (py - y) ^ 2) end
    return math.abs(py - y)
end
-- Distance from point (px, py) to vertical line segment (x, y1) to (x, y2)
local function distToVertSegment(px, py, x, y1, y2)
    if py < y1 then return math.sqrt((px - x) ^ 2 + (py - y1) ^ 2) end
    if py > y2 then return math.sqrt((px - x) ^ 2 + (py - y2) ^ 2) end
    return math.abs(px - x)
end

-- True if button's rect overlaps the card's rect (button would be "behind" the card).
local function ButtonOverlapsCard(btn, cardFrame)
    if not btn or not cardFrame or not cardFrame:IsShown() then return false end
    local snapFrame = cardFrame.backdropFrame or cardFrame
    local bl, br, bb, bt = btn:GetLeft(), btn:GetRight(), btn:GetBottom(), btn:GetTop()
    local cl, cr, cb, ct = snapFrame:GetLeft(), snapFrame:GetRight(), snapFrame:GetBottom(), snapFrame:GetTop()
    if not bl or not cl then return false end
    return not (br < cl or bl > cr or bt < cb or bb > ct)
end

-- When button is behind/overlapping a card, snap it to the nearest outside edge (so it's never behind).
local function ForceSnapToNearestOutside(button, saveFunc, pairOffsetX)
    pairOffsetX = pairOffsetX or 0
    if not button or not perkMainFrame or not perkMainFrame:IsShown() then return end
    local bcX, bcY = button:GetCenter()
    if not bcX or not bcY then return end
    local gap = SNAP_GAP
    local bestDist, bestFrame, bestCardIndex, bestPoint, bestRel, bestX, bestY = math.huge, nil, nil, nil, nil, 0, 0
    for cardIndex = 1, 3 do
        local frame = GetCardFrameByIndex(cardIndex)
        if frame and frame:IsShown() then
            local snapFrame = frame.backdropFrame or frame
            local l, r, b, t = snapFrame:GetLeft(), snapFrame:GetRight(), snapFrame:GetBottom(), snapFrame:GetTop()
            if l and t then
                local cx = (l + r) / 2
                local cy = (b + t) / 2
                for _, edge in ipairs(CARD_EDGES[cardIndex]) do
                    local d, pt, rel, ox, oy
                    if edge == "TOP" then
                        d = distToHorizSegment(bcX, bcY, l, r, t + gap)
                        pt, rel, ox, oy = "BOTTOM", "TOP", pairOffsetX, gap
                    elseif edge == "BOTTOM" then
                        d = distToHorizSegment(bcX, bcY, l, r, b - gap)
                        pt, rel, ox, oy = "TOP", "BOTTOM", pairOffsetX, -gap
                    elseif edge == "LEFT" then
                        d = distToVertSegment(bcX, bcY, l - gap, b, t)
                        pt, rel, ox, oy = "RIGHT", "LEFT", -gap, 0
                    else
                        d = distToVertSegment(bcX, bcY, r + gap, b, t)
                        pt, rel, ox, oy = "LEFT", "RIGHT", gap, 0
                    end
                    if d < bestDist then
                        bestDist, bestFrame, bestCardIndex, bestPoint, bestRel, bestX, bestY = d, snapFrame, cardIndex,
                            pt, rel, ox, oy
                    end
                end
            end
        end
    end
    if bestFrame then
        button:ClearAllPoints()
        button:SetParent(perkMainFrame)
        button:SetPoint(bestPoint, bestFrame, bestRel, bestX, bestY)
        button._lastSnapCardIndex = bestCardIndex
    end
    if saveFunc then saveFunc() end
end

-- Snap button to nearest allowed card edge (8px gap); use larger threshold for LEFT/RIGHT for easier vertical-center snap.
local function SnapButtonToCardFrame(button, saveFunc, pairOffsetX)
    pairOffsetX = pairOffsetX or 0
    if not button or not perkMainFrame or not perkMainFrame:IsShown() then return end
    local bcX, bcY = button:GetCenter()
    if not bcX or not bcY then return end
    local gap = SNAP_GAP
    local bestDist, bestFrame, bestCardIndex, bestPoint, bestRel, bestX, bestY = math.huge, nil, nil, nil, nil, 0, 0
    for cardIndex = 1, 3 do
        local frame = GetCardFrameByIndex(cardIndex)
        if frame and frame:IsShown() then
            local snapFrame = frame.backdropFrame or frame
            local l, r, b, t = snapFrame:GetLeft(), snapFrame:GetRight(), snapFrame:GetBottom(), snapFrame:GetTop()
            if l and t then
                local cx = (l + r) / 2
                local cy = (b + t) / 2
                for _, edge in ipairs(CARD_EDGES[cardIndex]) do
                    local d, pt, rel, ox, oy
                    local thresh = (edge == "LEFT" or edge == "RIGHT") and SNAP_THRESHOLD_SIDE or SNAP_THRESHOLD
                    if edge == "TOP" then
                        d = distToHorizSegment(bcX, bcY, l, r, t + gap)
                        pt, rel, ox, oy = "BOTTOM", "TOP", pairOffsetX, gap
                    elseif edge == "BOTTOM" then
                        d = distToHorizSegment(bcX, bcY, l, r, b - gap)
                        pt, rel, ox, oy = "TOP", "BOTTOM", pairOffsetX, -gap
                    elseif edge == "LEFT" then
                        d = distToVertSegment(bcX, bcY, l - gap, b, t)
                        pt, rel, ox, oy = "RIGHT", "LEFT", -gap, 0
                    else
                        d = distToVertSegment(bcX, bcY, r + gap, b, t)
                        pt, rel, ox, oy = "LEFT", "RIGHT", gap, 0
                    end
                    if d < bestDist and d <= thresh then
                        bestDist, bestFrame, bestCardIndex, bestPoint, bestRel, bestX, bestY = d, snapFrame, cardIndex,
                            pt, rel, ox, oy
                    end
                end
            end
        end
    end
    if bestFrame and bestDist <= SNAP_THRESHOLD_SIDE then
        button:ClearAllPoints()
        button:SetParent(perkMainFrame)
        button:SetPoint(bestPoint, bestFrame, bestRel, bestX, bestY)
        button._lastSnapCardIndex = bestCardIndex
    else
        button._lastSnapCardIndex = nil
    end
    if saveFunc then saveFunc() end
end

local function ApplyRankGlows()
    for _, f in ipairs(perkFramePool) do
        if f.inUse and f.backdropFrame and f.backdropFrame.SetBackdropBorderColor then
            f.backdropFrame:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end
end
local function _FUGAZI_WAS_HERE_deprecated() end
local _lastBanishRem = nil
local function UpdateBanishButtons()
    if not IsPerkDirectBanishEnabled() then
        for _, frame in ipairs(perkFramePool) do
            if frame.inUse and frame.banishCardButton then
                frame.banishCardButton:Hide()
                frame.banishCardButton:EnableMouse(false)
            end
        end
        return
    end
    local rem = GetBanishInfo()
    local mouseFocus = GetMouseFocus()
    local remChanged = (rem ~= _lastBanishRem)
    _lastBanishRem = rem
    local banishLabel = remChanged and ("Banish (" .. rem .. ")") or nil
    for _, frame in ipairs(perkFramePool) do
        if frame.inUse and frame.banishCardButton then
            local btn = frame.banishCardButton
            if rem > 0 then
                btn:EnableMouse(true)
                btn:Enable()
                if btn.SetBackdropColor and mouseFocus ~= btn then
                    btn:SetBackdropColor(0.32, 0.1, 0.1, 0.95)
                    btn:SetBackdropBorderColor(0, 0, 0, 1)
                end
                if btn.text and banishLabel then
                    btn.text:SetText(banishLabel)
                    btn.text:SetTextColor(1, 0.45, 0.4)
                end
            else
                btn:Disable()
                if btn.SetBackdropColor and mouseFocus ~= btn then
                    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
                    btn:SetBackdropBorderColor(0, 0, 0, 1)
                end
                if btn.text and banishLabel then
                    btn.text:SetText("Banish (0)")
                    btn.text:SetTextColor(0.5, 0.5, 0.5)
                end
            end
        end
    end
end

local FadeFrame, CancelFade
do
    local fadingFrames = {}
    local fadeFrame = CreateFrame("Frame")
    fadeFrame:Hide()

    function CancelFade(frame)
        if frame and fadingFrames[frame] then
            fadingFrames[frame] = nil
        end
    end

    fadeFrame:SetScript("OnUpdate", function(self, elapsed)
        if not UIParent:IsShown() then return end
        elapsed = math.min(elapsed, 0.1)
        local hasFades = false
        for frame, fadeInfo in pairs(fadingFrames) do
            hasFades = true
            fadeInfo.timer = fadeInfo.timer + elapsed

            if fadeInfo.timer < 0 then
                frame:SetAlpha(fadeInfo.startAlpha)
            elseif fadeInfo.timer >= fadeInfo.duration then
                frame:SetAlpha(fadeInfo.endAlpha)
                if fadeInfo.finishedFunc then
                    fadeInfo.finishedFunc(frame)
                end
                fadingFrames[frame] = nil
            else
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
            fadingFrames[frame] = {
                duration = duration,
                startAlpha = startAlpha,
                endAlpha = endAlpha,
                timer = -delay,
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
local MAX_PERK_FRAME_POOL = 6

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

    if #perkFramePool >= MAX_PERK_FRAME_POOL then
        return nil
    end

    local index = #perkFramePool + 1
    local frame = CreateFrame("Frame", "PerkChoice" .. index, parent)
    frame:SetSize(200, 400)

    -- Original texture (hidden when transparent); visual backdrop is on a separate frame
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\background_one_perk")
    bg:SetTexCoord(0.226562, 0.746094, 0.009766, 0.958984)
    frame.bg = bg

    -- Backdrop frame: only this controls how tall the dark rectangle looks. Frame was 400 so content doesn't overlap.
    local backdropHeight = 320 -- change this to crop the visible backdrop (e.g. 320 = shorter, 360 = taller)
    local backdropFrame = CreateFrame("Frame", nil, frame)
    backdropFrame:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    backdropFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
    backdropFrame:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    backdropFrame:SetHeight(backdropHeight)
    backdropFrame:SetFrameLevel(frame:GetFrameLevel() - 1)
    frame.backdropFrame = backdropFrame

    if IsTransparentDesign() then
        bg:Hide()
        if backdropFrame.SetBackdrop then
            backdropFrame:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true,
                tileSize = 16,
                edgeSize = 4,
                insets = { left = 4, right = 4, top = 4, bottom = 4 }
            })
            backdropFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            backdropFrame:SetBackdropBorderColor(0, 0, 0, 1)
        end
        -- Shrink hit area to match visible backdrop so the invisible top doesn't block Reroll/Hide/checkbox
        local frameHeight = 400
        frame:SetHitRectInsets(0, 0, frameHeight - backdropHeight, 0)
    else
        backdropFrame:Hide()
    end


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

    -- ElvUI-style fonts: Friz for titles, Arial Narrow for body
    local nameText = topPerkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 14)
    nameText:SetPoint("TOP", frame, "TOP", -5, -100)
    nameText:SetWidth(170)
    nameText:SetJustifyH("CENTER")
    frame.nameText = nameText

    -- Owned counter: "xN" centered in the gap between title and icon
    local ownedFrame = CreateFrame("Frame", nil, topPerkFrame)
    ownedFrame:SetSize(50, 24)
    ownedFrame:SetPoint("BOTTOM", iconFrame, "TOP", 0, 18)
    frame.ownedCountFrame = ownedFrame
    local ownedCountText = ownedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ownedCountText:SetPoint("CENTER", ownedFrame, "CENTER", 0, 0)
    ownedCountText:SetFont("Fonts\\FRIZQT__.TTF", 16)
    ownedCountText:SetTextColor(0.9, 0.85, 0.5)
    frame.ownedCountText = ownedCountText

    local descText = topPerkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetFont("Fonts\\ARIALN.TTF", 12)
    descText:SetPoint("TOP", topPerkFrame, "CENTER", 0, 20)
    descText:SetWidth(140)
    descText:SetHeight(90)
    descText:SetJustifyH("CENTER")
    descText:SetJustifyV("TOP")
    frame.descText = descText

    local familyIconSlots = {}
    for i = 1, 5 do
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetSize(20, 20)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        tex:Hide()
        familyIconSlots[i] = tex
    end
    frame.familyIconSlots = familyIconSlots

    local selectButton = utils.CreateSimpleCustomButton(frame, "Select", nil, 130, 32)
    selectButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 70)
    frame.selectButton = selectButton

    local banishCardButton = utils.CreateSimpleCustomButton(frame, "Banish", nil, 130, 32)
    banishCardButton:SetPoint("TOP", selectButton, "BOTTOM", 0, -8)
    banishCardButton:SetAlpha(0)
    banishCardButton:Hide()

    if not banishCardButton.text then
        banishCardButton.text = banishCardButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        banishCardButton.text:SetPoint("CENTER", banishCardButton, "CENTER", 0, 0)
        banishCardButton.text:SetText("Banish")
        banishCardButton.text:SetTextColor(1, 0.4, 0.35)
    end

    frame.banishCardButton = banishCardButton

    if IsTransparentDesign() then
        local function skinCardButton(btn)
            if not btn then return end
            local function hideTex(t) if t then
                    t:Hide()
                    t:SetTexture(nil)
                end end
            hideTex(btn:GetNormalTexture())
            hideTex(btn:GetPushedTexture())
            hideTex(btn:GetHighlightTexture())
            hideTex(btn:GetDisabledTexture())
            if btn.SetBackdrop then
                btn:SetBackdrop({
                    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                    tile = true,
                    tileSize = 16,
                    edgeSize = 2,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                if btn.text then btn.text:SetFontObject("GameFontNormalSmall") end
            end
        end
        skinCardButton(selectButton)
        skinCardButton(banishCardButton)

        selectButton:SetBackdropColor(0.08, 0.28, 0.1, 0.95)
        selectButton:SetBackdropBorderColor(0, 0, 0, 1)
        selectButton:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.15, 0.5, 0.2, 1)
            self:SetBackdropColor(0.18, 0.42, 0.2, 0.98)
        end)
        selectButton:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0, 0, 0, 1)
            self:SetBackdropColor(0.08, 0.28, 0.1, 0.95)
        end)

        -- Banish: red only on hover when enabled; black border always
        banishCardButton:SetScript("OnEnter", function(self)
            if self:IsEnabled() and self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0, 0, 0, 1)
                self:SetBackdropColor(0.48, 0.16, 0.14, 0.98)
            end
        end)
        banishCardButton:SetScript("OnLeave", function(self)
            if self.SetBackdropBorderColor then
                local rem = GetBanishInfo()
                if rem > 0 then
                    self:SetBackdropBorderColor(0, 0, 0, 1)
                    self:SetBackdropColor(0.32, 0.1, 0.1, 0.95)
                else
                    self:SetBackdropBorderColor(0, 0, 0, 1)
                    self:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
                end
            end
        end)
    end

    -- Ctrl+drag from any of the 3 cards moves the whole perk UI (avoids accidental reroll)
    -- Shift+right-click on card inserts echo spell link into chat
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and IsShiftKeyDown() and self._spellId then
            local link = GetSpellLink(self._spellId)
            if not link or link == "" then
                local name = GetSpellInfo(self._spellId) or ("Spell " .. self._spellId)
                link = ("|cff71d5ff|Hspell:%d|h[%s]|h|r"):format(self._spellId, name)
            end
            local edit = ChatEdit_ChooseBoxForSend()
            if not edit:HasFocus() then
                ChatEdit_ActivateChat(edit)
            end
            ChatEdit_InsertLink(link)
            return
        end
        if button == "LeftButton" and IsControlKeyDown() and perkMainFrame then
            perkMainFrame._perkUIDragging = true
            perkMainFrame:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and perkMainFrame and perkMainFrame._perkUIDragging then
            perkMainFrame._perkUIDragging = nil
            perkMainFrame:StopMovingOrSizing()
            SavePerkUIPosition()
        end
    end)

    -- These four handlers are registered ONCE per frame (here in AcquirePerkFrame, not in
    -- UpdatePerkFrame). They read dynamic data from frame properties (_spellId, _perkIndex,
    -- _qualityData, _stacks, _maxStacks) which UpdatePerkFrame sets on each reuse.
    -- This prevents 4 new closures × 3 cards × 79 ShowPerkUI calls per level-up from
    -- accumulating as upvalue garbage in the 3.3.5 Lua runtime.

    selectButton:SetScript("OnClick", function()
        if GetTime() < perkCardsGraceUntil then return end
        if isSelecting then return end
        isSelecting = true
        for _, f in ipairs(perkFramePool) do
            if f.inUse then
                f.selectButton:EnableMouse(false)
                f:EnableMouse(false)
                if f.banishCardButton then f.banishCardButton:EnableMouse(false) end
            end
        end
        local success
        if banishMode then
            success = ProjectEbonhold.PerkService.BanishPerk(frame._perkIndex)
        else
            success = ProjectEbonhold.PerkService.SelectPerk(frame._spellId)
        end
        if not success then
            isSelecting = false
            for _, f in ipairs(perkFramePool) do
                if f.inUse then
                    f.selectButton:EnableMouse(true)
                    f:EnableMouse(true)
                    if f.banishCardButton then f.banishCardButton:EnableMouse(true) end
                end
            end
        end
    end)

    banishCardButton:SetScript("OnClick", function()
        if GetTime() < perkCardsGraceUntil then return end
        if isSelecting then return end
        isSelecting = true
        for _, f in ipairs(perkFramePool) do
            if f.inUse then
                f.selectButton:EnableMouse(false)
                f:EnableMouse(false)
                if f.banishCardButton then f.banishCardButton:EnableMouse(false) end
            end
        end
        local success = ProjectEbonhold.PerkService.BanishPerk(frame._perkIndex)
        isSelecting = false
        for _, f in ipairs(perkFramePool) do
            if f.inUse then
                f.selectButton:EnableMouse(true)
                f:EnableMouse(true)
                if f.banishCardButton then f.banishCardButton:EnableMouse(true) end
            end
        end
        if success then
            frame.banishCardButton:Hide()
            UpdateBanishButtons()
        else
            UpdateBanishButtons()
        end
    end)

    frame:SetScript("OnEnter", function(self)
        local qd = self._qualityData or qualityInfo[0]
        GameTooltip:SetOwner(self.iconFrame, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local sName = GetSpellInfo(self._spellId or 0)
        GameTooltip:AddLine(sName or ("Spell " .. tostring(self._spellId)), qd.color[1], qd.color[2], qd.color[3])
        GameTooltip:AddLine(qd.name, 0.5, 0.5, 0.5)
        local perkDb = ProjectEbonhold.PerkDatabase and ProjectEbonhold.PerkDatabase[self._spellId]
        if perkDb and perkDb.families and #perkDb.families > 0 then
            GameTooltip:AddLine(table.concat(perkDb.families, ", "), 0.4, 0.8, 1)
        end
        local st = self._stacks or 1
        local ms = self._maxStacks or 1
        if st > 1 then
            GameTooltip:AddLine("Stacks: " .. st .. "/" .. ms, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        local description = utils.GetSpellDescription(self._spellId, 500, st)
        GameTooltip:AddLine(description, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    frame.inUse = true
    table.insert(perkFramePool, frame)
    return frame
end

-- Phase 0..1 -> (x, y) on card rectangle (top -> right -> bottom -> left)
local function phaseToXY(p)
    local x, y
    if p < 0.25 then
        x = -100 + (p / 0.25) * 200
        y = 160
    elseif p < 0.5 then
        x = 100
        y = 160 - ((p - 0.25) / 0.25) * 320
    elseif p < 0.75 then
        x = 100 - ((p - 0.5) / 0.25) * 200
        y = -160
    else
        x = -100
        y = -160 + ((p - 0.75) / 0.25) * 320
    end
    return x, y
end

local function wrapPhase(z)
    local w = z % 1
    if w < 0 then w = w + 1 end
    return w
end

local function UpdatePerkFrame(frame, perkData, perkIndex)
    if not frame or not perkData then return end

    local spellId = perkData.spellId
    local quality = perkData.quality
    local stacks = perkData.stack or 1
    local maxStacks = perkData.maxStack or 1
    local qualityData = qualityInfo[quality] or qualityInfo[0]

    frame.perkIndex = perkIndex
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
    if frame.backdropFrame and frame.backdropFrame.SetBackdropColor then
        frame.backdropFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    end
    local description = utils.GetSpellDescription(spellId, 120)
    frame.descText:SetText(description)

    if frame.familyIconSlots then
        local ICON_SIZE = 20
        local ICON_SPACING = 4
        local perkDb = ProjectEbonhold.PerkDatabase and ProjectEbonhold.PerkDatabase[spellId]
        local familiesToShow = {}
        if perkDb and perkDb.families then
            for _, familyName in ipairs(perkDb.families) do
                if familyIcons[familyName] then
                    table.insert(familiesToShow, familyName)
                end
            end
        end
        local n = #familiesToShow
        local totalWidth = n * ICON_SIZE + math.max(0, n - 1) * ICON_SPACING
        local startX = -(totalWidth / 2) + (ICON_SIZE / 2)
        for i, slot in ipairs(frame.familyIconSlots) do
            if i <= n then
                local xOffset = startX + (i - 1) * (ICON_SIZE + ICON_SPACING)
                slot:ClearAllPoints()
                slot:SetPoint("TOP", frame, "TOP", xOffset, -60)
                slot:SetTexture(familyIcons[familiesToShow[i]])
                slot:Show()
            else
                slot:Hide()
            end
        end
    end

    -- Show how many of this echo you already have (text only, below main icon)
    local granted = (ProjectEbonhold and ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetGrantedPerks) and
    ProjectEbonhold.PerkService.GetGrantedPerks() or {}
    local count = 0
    if spellName and granted[spellName] then count = #granted[spellName] end
    if count == 0 and spellId and granted then
        for name, arr in pairs(granted) do
            if arr and #arr > 0 and arr[1].spellId == spellId then
                count = #arr
                break
            end
        end
    end
    frame._ownedCount = count
    frame._spellId = spellId
    if frame.ownedCountFrame and frame.ownedCountText then
        if count >= 1 then
            frame.ownedCountText:SetText("x" .. tostring(count))
            frame.ownedCountFrame:Show()
        else
            frame.ownedCountFrame:Hide()
        end
    end

    local rollsCount = (ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetPendingRollsCount and ProjectEbonhold.PerkService.GetPendingRollsCount()) or
    0
    frame.selectButton.text:SetText(GetSelectLabel(rollsCount))
    frame.selectButton.text:SetTextColor(1, 1, 1)

    -- Dynamic data stored as frame properties; handlers registered once in AcquirePerkFrame read these.
    frame._spellId = spellId
    frame._perkIndex = perkIndex
    frame._qualityData = qualityData
    frame._stacks = stacks
    frame._maxStacks = maxStacks

    do
        local rem = GetBanishInfo()
        if frame.banishCardButton.text then
            frame.banishCardButton.text:SetText("Banish (" .. rem .. ")")
            frame.banishCardButton.text:SetTextColor(rem > 0 and 1 or 0.5, rem > 0 and 0.45 or 0.5,
                rem > 0 and 0.4 or 0.5)
        end
        if frame.banishCardButton.SetBackdropColor then
            if rem > 0 then
                frame.banishCardButton:SetBackdropColor(0.32, 0.1, 0.1, 0.95)
                frame.banishCardButton:SetBackdropBorderColor(0, 0, 0, 1)
            else
                frame.banishCardButton:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
                frame.banishCardButton:SetBackdropBorderColor(0, 0, 0, 1)
            end
        end
    end

    frame:EnableMouse(true)
    frame:Show()
    frame.iconFrame:Show()
    frame.icon:Show()
    frame.iconBase:Show()
    frame.border:Show()
    frame.nameText:Show()
    frame.descText:Show()
    frame.selectButton:Show()
end

local function InitializePerkUI()
    if perkMainFrame then return end

    perkMainFrame = CreateFrame("Frame", "ProjectEbonholdPerkFrame", UIParent)
    perkMainFrame:SetFrameStrata("DIALOG")
    perkMainFrame:SetFrameLevel(100)
    perkMainFrame:SetSize(800, 280)
    perkMainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    perkMainFrame:SetMovable(true)
    perkMainFrame:SetClampedToScreen(true)
    perkMainFrame:SetScale(GetPerkUIScale())
    perkMainFrame:Hide()

    RestorePerkUIPosition()

    perkMainFrame:SetScript("OnMouseUp", function(self, button)
        if self._perkUIDragging and button == "LeftButton" then
            self._perkUIDragging = nil
            self:StopMovingOrSizing()
            SavePerkUIPosition()
        end
    end)

    -- Fallback: if mouse is released over a child frame, OnMouseUp on perkMainFrame
    -- never fires in 3.3.5 (no event bubbling). Poll for button release in OnUpdate
    -- so the frame doesn't stay stuck to the mouse.
    perkMainFrame:SetScript("OnUpdate", function(self, elapsed)
        if not self:IsShown() then return end

        -- Release drag if left button is no longer held (catches mouse-up over child frames)
        if self._perkUIDragging and not IsMouseButtonDown("LeftButton") then
            self._perkUIDragging = nil
            self:StopMovingOrSizing()
            SavePerkUIPosition()
        end

        self.banishPollElapsed = (self.banishPollElapsed or 0) + elapsed
        if self.banishPollElapsed >= 0.2 then
            self.banishPollElapsed = 0
            UpdateBanishButtons()
            local n = (ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetPendingRollsCount and ProjectEbonhold.PerkService.GetPendingRollsCount()) or
            0
            if n ~= self._lastPendingRolls then
                self._lastPendingRolls = n
                if not banishMode then
                    local label = GetSelectLabel(n)
                    for _, f in ipairs(perkFramePool) do
                        if f.inUse and f.selectButton and f.selectButton.text then
                            f.selectButton.text:SetText(label)
                        end
                    end
                end
            end
            if not self.perksHidden and rerollButton then
                local avail = GetRerollInfo()
                if avail ~= self._lastRerollAvail then
                    self._lastRerollAvail = avail
                    if avail > 0 then
                        rerollButton.text:SetText("Reroll (" .. tostring(avail) .. ")")
                        rerollButton:Show()
                    else
                        rerollButton:Hide()
                    end
                end
            end
            if not self.perksHidden and banishButton then
                local availBanishes = GetBanishInfo()
                if availBanishes ~= self._lastBanishAvail then
                    self._lastBanishAvail = availBanishes
                    if availBanishes > 0 then
                        banishButton.text:SetText("Banish (" .. tostring(availBanishes) .. ")")
                        banishButton:Enable()
                        banishButton:Show()
                    else
                        banishButton.text:SetText("Banish")
                        banishButton:Disable()
                        if banishMode then
                            banishMode = false
                            banishButton.text:SetTextColor(1, 1, 1)
                            local nn = (ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetPendingRollsCount and ProjectEbonhold.PerkService.GetPendingRollsCount()) or
                            0
                            for _, f in ipairs(perkFramePool) do
                                if f.inUse and f:IsShown() then
                                    f.selectButton.text:SetText(GetSelectLabel(nn))
                                    f.selectButton.text:SetTextColor(1, 1, 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    perkMainFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            ProjectEbonhold.PerkUI.Hide()
        end
    end)

    rerollButton = utils.CreateSimpleCustomButton(perkMainFrame, "Reroll", nil, 120, 25)
    rerollButton:SetPoint("TOP", perkMainFrame, "TOP", -64, 90)
    -- Red hover glow (manual overlay so it never gets lost; match banish darkness)
    local rerollGlow = rerollButton:CreateTexture(nil, "OVERLAY")
    rerollGlow:SetAllPoints(rerollButton)
    rerollGlow:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    rerollGlow:SetBlendMode("ADD")
    rerollGlow:SetVertexColor(0.5, 0.14, 0.14, 0.4)
    rerollGlow:Hide()
    rerollButton._rerollGlow = rerollGlow
    if IsTransparentDesign() then
        local function hideTex(t) if t then
                t:Hide()
                t:SetTexture(nil)
            end end
        hideTex(rerollButton:GetNormalTexture())
        hideTex(rerollButton:GetPushedTexture())
        hideTex(rerollButton:GetHighlightTexture())
        hideTex(rerollButton:GetDisabledTexture())
        if rerollButton.SetBackdrop then
            rerollButton:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true,
                tileSize = 16,
                edgeSize = 2,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            rerollButton:SetBackdropColor(0.22, 0.06, 0.06, 0.95)
            rerollButton:SetBackdropBorderColor(0, 0, 0, 1)
        end
        if rerollButton.text then rerollButton.text:SetFontObject("GameFontNormalSmall") end
    end
    rerollButton:SetScript("OnEnter", function(self)
        if self:IsEnabled() and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.9, 0.2, 0.2, 1)
            self:SetBackdropColor(0.5, 0.12, 0.12, 0.98)
            if self._rerollGlow then self._rerollGlow:Show() end
        end
        local availableRerolls, totalRerolls = GetRerollInfo()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Reroll Echoes", 1, 0.82, 0)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
        "Reroll current echoes. These echoes won't appear in your next choice, but may return in future selections. Decreases the odds of drawing echoes in the families of your current selection",
            1, 1, 1, true)
        GameTooltip:AddLine(" ")
        if availableRerolls > 0 then
            GameTooltip:AddLine("Rerolls remaining: " .. availableRerolls .. "/" .. totalRerolls, 0, 1, 0)
        else
            GameTooltip:AddLine("No rerolls remaining", 1, 0, 0)
        end
        GameTooltip:Show()
    end)
    rerollButton:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0, 0, 0, 1)
            self:SetBackdropColor(0.22, 0.06, 0.06, 0.95)
            if self._rerollGlow then self._rerollGlow:Hide() end
        end
        GameTooltip:Hide()
    end)
    rerollButton:SetFrameLevel(perkMainFrame:GetFrameLevel() + 20)
    rerollButton:SetMovable(true)
    rerollButton:SetClampedToScreen(true)
    rerollButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() then
            self._rerollDragging = true
            self:StartMoving()
        end
    end)
    rerollButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._rerollDragging then
            self._rerollDragging = nil
            self:StopMovingOrSizing()
            local overlaps = false
            for ci = 1, 3 do
                local card = GetCardFrameByIndex(ci)
                if card and ButtonOverlapsCard(self, card) then
                    overlaps = true
                    break
                end
            end
            if overlaps then
                ForceSnapToNearestOutside(self, SaveRerollButtonPosition, -64)
            else
                SnapButtonToCardFrame(self, SaveRerollButtonPosition, -64)
            end
            self._justDragged = true
        end
    end)
    RestoreRerollButtonPosition()
    -- OnClick registered once here, never re-registered in ShowPerkUI.
    rerollButton:SetScript("OnClick", function()
        if rerollButton._justDragged then
            rerollButton._justDragged = nil
            return
        end
        local availableRerolls = GetRerollInfo()
        if availableRerolls <= 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000No rerolls remaining! Rerolls are restored upon death.|r")
            return
        end
        ProjectEbonhold.PerkService.RequestReroll()
    end)
    rerollButton:Hide()

    -- Standalone Banish toggle button (sits right of reroll)
    banishButton = utils.CreateSimpleCustomButton(perkMainFrame, "Banish", nil, 120, 25)
    banishButton:SetPoint("LEFT", rerollButton, "RIGHT", 8, 0)
    if IsTransparentDesign() then
        local function hideTex2(t) if t then
                t:Hide()
                t:SetTexture(nil)
            end end
        hideTex2(banishButton:GetNormalTexture())
        hideTex2(banishButton:GetPushedTexture())
        hideTex2(banishButton:GetHighlightTexture())
        hideTex2(banishButton:GetDisabledTexture())
        if banishButton.SetBackdrop then
            banishButton:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true,
                tileSize = 16,
                edgeSize = 2,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            banishButton:SetBackdropColor(0.22, 0.06, 0.06, 0.95)
            banishButton:SetBackdropBorderColor(0, 0, 0, 1)
        end
        if banishButton.text then banishButton.text:SetFontObject("GameFontNormalSmall") end
    end
    banishButton:SetFrameLevel(perkMainFrame:GetFrameLevel() + 20)
    banishButton:SetScript("OnClick", function()
        banishMode = not banishMode
        if banishMode then
            if banishButton.text then banishButton.text:SetTextColor(1, 0.3, 0.3) end
        else
            if banishButton.text then banishButton.text:SetTextColor(1, 1, 1) end
        end
        for _, frame in ipairs(perkFramePool) do
            if frame.inUse and frame:IsShown() then
                if banishMode then
                    frame.selectButton.text:SetText("Banish")
                    frame.selectButton.text:SetTextColor(1, 0.3, 0.3)
                else
                    local n = (ProjectEbonhold.PerkService and ProjectEbonhold.PerkService.GetPendingRollsCount and ProjectEbonhold.PerkService.GetPendingRollsCount()) or
                    0
                    frame.selectButton.text:SetText(GetSelectLabel(n))
                    frame.selectButton.text:SetTextColor(1, 1, 1)
                end
            end
        end
    end)
    banishButton:SetScript("OnEnter", function(self)
        if self:IsEnabled() and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.9, 0.2, 0.2, 1)
            self:SetBackdropColor(0.5, 0.12, 0.12, 0.98)
        end
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
            GameTooltip:AddLine(
            "Enter banish mode. Click an echo to remove it from future selections in your current run. It banishes all qualities of the chosen echo.",
                1, 1, 1, true)
            GameTooltip:AddLine(" ")
            if freshBanishes > 0 then
                GameTooltip:AddLine("Banishes remaining: " .. freshBanishes, 0, 1, 0)
            else
                GameTooltip:AddLine("No banishes remaining", 1, 0, 0)
            end
        end
        GameTooltip:Show()
    end)
    banishButton:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0, 0, 0, 1)
            self:SetBackdropColor(0.22, 0.06, 0.06, 0.95)
        end
        GameTooltip:Hide()
    end)
    banishButton:Hide()

    hideButton = CreateFrame("Button", "PerkHideButton", perkMainFrame)
    hideButton:SetSize(200, 100)
    hideButton:SetPoint("TOP", perkMainFrame, "BOTTOM", 0, -65)
    hideButton:RegisterForClicks("LeftButtonUp")
    hideButton:Hide()

    if IsTransparentDesign() then
        hideButton:SetSize(120, 25)
        local hideButtonText = hideButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hideButtonText:SetPoint("CENTER", hideButton, "CENTER", 0, 0)
        hideButton.text = hideButtonText
        hideButtonText:SetTextColor(0.7, 0.7, 0.7)
        if hideButton.SetBackdrop then
            hideButton:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true,
                tileSize = 16,
                edgeSize = 2,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            hideButton:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            hideButton:SetBackdropBorderColor(0, 0, 0, 1)
        end
    else
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
    end
    hideButton:SetFrameLevel(perkMainFrame:GetFrameLevel() + 20)
    hideButton:SetMovable(true)
    hideButton:SetClampedToScreen(true)
    hideButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() then
            self._hideDragging = true
            self:StartMoving()
        end
    end)
    hideButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._hideDragging then
            self._hideDragging = nil
            self:StopMovingOrSizing()
            local overlaps = false
            for ci = 1, 3 do
                local card = GetCardFrameByIndex(ci)
                if card and ButtonOverlapsCard(self, card) then
                    overlaps = true
                    break
                end
            end
            if overlaps then
                ForceSnapToNearestOutside(self, SaveHideButtonPosition)
            else
                SnapButtonToCardFrame(self, SaveHideButtonPosition)
            end
            self._justDragged = true
        end
    end)
    RestoreHideButtonPosition()

    local autoShowCB = CreateFrame("CheckButton", "EbonholdAutoShowCheck", perkMainFrame, "ChatConfigCheckButtonTemplate")
    -- Positioned on right card bottom in ShowPerkUI when cards exist
    _G[autoShowCB:GetName() .. 'Text']:SetText("Auto Show Echoes")
    autoShowCB:SetChecked(EbonholdAutoShowDB.enabled)
    autoShowCB:SetScript("OnClick", function(self) EbonholdAutoShowDB.enabled = self:GetChecked() end)
    autoShowCB:Hide()

    chooseButton = CreateFrame("Button", "PerkChooseButton", UIParent)
    chooseButton:SetPoint("TOP", perkMainFrame, "BOTTOM", 0, -50)
    chooseButton:SetFrameStrata("DIALOG")
    chooseButton:SetFrameLevel(perkMainFrame:GetFrameLevel() + 10)
    chooseButton:EnableMouse(true)
    chooseButton:RegisterForClicks("LeftButtonUp")
    chooseButton:SetMovable(true)
    chooseButton:SetClampedToScreen(true)

    if IsTransparentDesign() then
        chooseButton:SetSize(140, 25)

        local chooseButtonText = chooseButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        chooseButtonText:SetPoint("CENTER", chooseButton, "CENTER", 0, 0)
        chooseButtonText:SetText("Select an Echo")
        chooseButtonText:SetTextColor(0.9, 0.9, 0.9)
        chooseButton.text = chooseButtonText

        if chooseButton.SetBackdrop then
            chooseButton:SetBackdrop({
                bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                tile = true,
                tileSize = 16,
                edgeSize = 2,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            chooseButton:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            chooseButton:SetBackdropBorderColor(0, 0, 0, 1)
        end

        chooseButton:SetScript("OnEnter", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.4, 0.7, 1.0, 1)
            end
            chooseButtonText:SetTextColor(1, 1, 1)
        end)
        chooseButton:SetScript("OnLeave", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0, 0, 0, 1)
            end
            chooseButtonText:SetTextColor(0.9, 0.9, 0.9)
        end)
    else
        chooseButton:SetSize(250, 120)

        local chooseButtonTexture = chooseButton:CreateTexture(nil, "BACKGROUND")
        chooseButtonTexture:SetAllPoints(chooseButton)
        chooseButtonTexture:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\button_hide_perk")
        chooseButtonTexture:SetTexCoord(0, 1, 0.30, 0.80)

        local chooseButtonText = chooseButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        chooseButtonText:SetPoint("CENTER", chooseButton, "CENTER", 0, 10)
        chooseButtonText:SetText("Select an Echo")
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
            elapsed = math.min(elapsed, 0.1)
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
    end

    chooseButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsControlKeyDown() then
            self._chooseButtonDragging = true
            self:StartMoving()
        end
    end)
    chooseButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self._chooseButtonDragging then
            self._chooseButtonDragging = nil
            self:StopMovingOrSizing()
            SaveChooseButtonPosition()
            self._justDragged = true
        end
    end)

    RestoreChooseButtonPosition()
    chooseButton:Hide()

    chooseButton:SetScript("OnClick", function()
        if chooseButton._justDragged then
            chooseButton._justDragged = nil
            return
        end
        local activePerks = {}
        for _, frame in ipairs(perkFramePool) do
            if frame.inUse then table.insert(activePerks, frame) end
        end

        for _, frame in ipairs(activePerks) do
            frame:SetAlpha(1)
            frame:Show()
            frame:EnableMouse(true)
            frame.selectButton:EnableMouse(true)
            if frame.banishCardButton and IsPerkDirectBanishEnabled() then
                local rem = GetBanishInfo()
                if rem > 0 then
                    frame.banishCardButton:Show()
                    frame.banishCardButton:SetAlpha(1)
                    frame.banishCardButton:EnableMouse(true)
                    frame.banishCardButton:Enable()
                    if frame.banishCardButton.text then
                        frame.banishCardButton.text:SetText("Banish (" .. rem .. ")")
                        frame.banishCardButton.text:SetTextColor(1, 0.45, 0.4)
                    end
                else
                    frame.banishCardButton:Show()
                    frame.banishCardButton:SetAlpha(1)
                    frame.banishCardButton:Disable()
                    if frame.banishCardButton.text then
                        frame.banishCardButton.text:SetText("Banish (0)")
                        frame.banishCardButton.text:SetTextColor(0.5, 0.5, 0.5)
                    end
                end
            end
        end

        ApplyRankGlows()
        if GetRerollInfo() > 0 then rerollButton:Show() else rerollButton:Hide() end
        local bAvail = GetBanishInfo()
        if bAvail > 0 then banishButton:Show() else banishButton:Hide() end

        perkMainFrame.perksHidden = false
        hideButton.text:SetText("Hide")
        hideButton.text:SetTextColor(0.7, 0.7, 0.7)
        if _G.EbonholdAutoShowCheck then _G.EbonholdAutoShowCheck:Show() end

        chooseButton:Hide()

        ShowPerkFamilyHint()

        perkCardsGraceUntil = GetTime() + PERK_CARDS_GRACE_SEC
        FadeFrame(hideButton, 0.3, 0, 1, 0)
    end)

    hideButton:SetScript("OnClick", function()
        if hideButton._justDragged then
            hideButton._justDragged = nil
            return
        end
        perkMainFrame.perksHidden = not perkMainFrame.perksHidden

        local activePerks = {}
        for _, frame in ipairs(perkFramePool) do
            if frame.inUse then table.insert(activePerks, frame) end
        end

        if perkMainFrame.perksHidden then
            for _, frame in ipairs(activePerks) do
                frame:EnableMouse(false)
                frame.selectButton:EnableMouse(false)
                if frame.banishCardButton then frame.banishCardButton:EnableMouse(false) end
                frame:SetScript("OnUpdate", nil)
                frame:SetAlpha(0)
                frame:Hide()
            end
            hideButton.text:SetText("Show")
            hideButton.text:SetTextColor(0.7, 0.7, 0.7)
            if _G.EbonholdAutoShowCheck then _G.EbonholdAutoShowCheck:Hide() end
            rerollButton:Hide()
            banishButton:Hide()
            if perkFamilyHintFrame and perkFamilyHintFrame:IsShown() then
                perkMainFrame._hintWasShown = true
                perkFamilyHintFrame:Hide()
            else
                perkMainFrame._hintWasShown = false
            end
        else
            for _, frame in ipairs(activePerks) do
                frame:SetAlpha(1)
                frame:Show()
                frame:EnableMouse(true)
                frame.selectButton:EnableMouse(true)
                if frame.banishCardButton and IsPerkDirectBanishEnabled() then
                    local rem = GetBanishInfo()
                    if rem > 0 then
                        frame.banishCardButton:Show()
                        frame.banishCardButton:SetAlpha(1)
                        frame.banishCardButton:EnableMouse(true)
                        frame.banishCardButton:Enable()
                        if frame.banishCardButton.text then
                            frame.banishCardButton.text:SetText("Banish (" .. rem .. ")")
                            frame.banishCardButton.text:SetTextColor(1, 0.3, 0.3)
                        end
                    else
                        frame.banishCardButton:Show()
                        frame.banishCardButton:SetAlpha(1)
                        frame.banishCardButton:Disable()
                        if frame.banishCardButton.text then
                            frame.banishCardButton.text:SetText("Banish (0)")
                            frame.banishCardButton.text:SetTextColor(0.5, 0.5, 0.5)
                        end
                    end
                end
            end

            if GetRerollInfo() > 0 then rerollButton:Show() else rerollButton:Hide() end
            local bAvail2 = GetBanishInfo()
            if bAvail2 > 0 then banishButton:Show() else banishButton:Hide() end
            hideButton.text:SetText("Hide")
            hideButton.text:SetTextColor(0.7, 0.7, 0.7)
            if _G.EbonholdAutoShowCheck then _G.EbonholdAutoShowCheck:Show() end
            perkCardsGraceUntil = GetTime() + PERK_CARDS_GRACE_SEC
            if perkMainFrame._hintWasShown and perkFamilyHintFrame then
                perkFamilyHintFrame:Show()
                perkMainFrame._hintWasShown = false
            end
        end
    end)

    hideButton:SetScript("OnEnter", function() hideButton.text:SetTextColor(0.7, 0.7, 0.7) end)
    hideButton:SetScript("OnLeave", function() hideButton.text:SetTextColor(1, 1, 1) end)
end

local function ForceResetPerkUI()
    isFading = false
    isSelecting = false
    isShowingPerkUI = false

    -- FIX: cancel any pending deferred auto-click so a stale click can't fire
    -- into a freshly-reset UI after ForceResetPerkUI is called mid-show.
    autoClickDeferred:SetScript("OnUpdate", nil)
    autoClickDeferred:Hide()

    if perkMainFrame then
        CancelFade(perkMainFrame)
        perkMainFrame:SetAlpha(0)
        perkMainFrame:Hide()
        perkMainFrame.banishPollElapsed = 0
    end

    for _, f in ipairs(perkFramePool) do
        CancelFade(f)
        if f.selectButton then CancelFade(f.selectButton) end
        if f.banishCardButton then CancelFade(f.banishCardButton) end
        f:SetScript("OnUpdate", nil)
        f:Hide()
        f:SetAlpha(1)
        f:EnableMouse(true)
        f.inUse = false
    end

    if chooseButton then CancelFade(chooseButton) end
    if hideButton then
        CancelFade(hideButton)
        hideButton._justDragged = nil
        hideButton._hideDragging = nil
    end
    if rerollButton then
        CancelFade(rerollButton)
        rerollButton:Hide()
        rerollButton:SetAlpha(1)
        rerollButton._justDragged = nil
        rerollButton._rerollDragging = nil
    end
    if banishButton then
        CancelFade(banishButton)
        banishButton:Hide()
        banishButton:SetAlpha(1)
    end
    banishMode = false
    if perkFamilyHintFrame then perkFamilyHintFrame:Hide() end
end

ShowPerkFamilyHint = function()
    if ProjectEbonholdDB and ProjectEbonholdDB.perkFamilyHintDismissed then return end

    if not perkFamilyHintFrame then
        perkFamilyHintFrame = CreateFrame("Frame", "PerkFamilyHintFrame", UIParent, "GlowBoxTemplate")
        perkFamilyHintFrame:SetSize(260, 110)
        perkFamilyHintFrame:SetFrameStrata("DIALOG")
        perkFamilyHintFrame:SetFrameLevel(200)
        perkFamilyHintFrame:EnableMouse(true)

        local closeBtn = CreateFrame("Button", nil, perkFamilyHintFrame, "UIPanelCloseButton")
        closeBtn:SetSize(26, 26)
        closeBtn:SetPoint("TOPRIGHT", perkFamilyHintFrame, "TOPRIGHT", -4, -4)
        closeBtn:SetFrameLevel(201)
        closeBtn:SetScript("OnClick", function()
            if ProjectEbonholdDB then ProjectEbonholdDB.perkFamilyHintDismissed = true end
            perkFamilyHintFrame:Hide()
        end)

        local hintText = perkFamilyHintFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
        hintText:SetJustifyV("TOP")
        hintText:SetSize(210, 0)
        hintText:SetPoint("TOPLEFT", perkFamilyHintFrame, "TOPLEFT", 18, -36)
        hintText:SetText("Picking an echo from a family boosts chances of more from that same family.")
        perkFamilyHintFrame.hintText = hintText
    end

    -- Anchor to upper-left of the leftmost perk card
    local card1 = GetCardFrameByIndex(1)
    if card1 then
        local anchor = card1.backdropFrame or card1
        perkFamilyHintFrame:ClearAllPoints()
        perkFamilyHintFrame:SetPoint("BOTTOMRIGHT", anchor, "TOPLEFT", 40, 10)
    else
        perkFamilyHintFrame:ClearAllPoints()
        perkFamilyHintFrame:SetPoint("CENTER", UIParent, "CENTER", -320, 160)
    end

    perkFamilyHintFrame:Show()
end

local function ShowPerkUI(choices)
    if not choices or #choices == 0 then return end
    if (UnitLevel and UnitLevel("player") or 1) <= 1 then return end -- no echo choice at level 1
    if isShowingPerkUI then return end
    isShowingPerkUI = true

    local ok, err = pcall(function()
        ForceResetPerkUI()
        InitializePerkUI()

        perkMainFrame:Show()
        perkMainFrame:SetAlpha(1)

        for _, f in ipairs(perkFramePool) do
            f:Hide()
            f:SetAlpha(1)
            f.inUse = false
        end

        local perkCount = #choices
        local frameWidth = (perkCount * 180) + ((perkCount - 1) * 22) + 40
        perkMainFrame:SetWidth(frameWidth)

        local remainingBanishes = GetBanishInfo()

        for i, perkData in ipairs(choices) do
            local perkFrame = AcquirePerkFrame(perkMainFrame)
            if not perkFrame then break end
            UpdatePerkFrame(perkFrame, perkData, i - 1)

            local xOffset = ((i - 1) - ((perkCount - 1) / 2)) * 202
            perkFrame:SetPoint("CENTER", perkMainFrame, "CENTER", xOffset, 0)

            local shouldShow = EbonholdAutoShowDB.enabled
            if shouldShow then
                perkFrame:SetAlpha(1)
                perkFrame:Show()
                perkFrame:EnableMouse(true)
                perkFrame.selectButton:EnableMouse(true)
                if perkFrame.banishCardButton and IsPerkDirectBanishEnabled() then
                    local rem = GetBanishInfo()
                    if rem > 0 then
                        perkFrame.banishCardButton:Show()
                        perkFrame.banishCardButton:SetAlpha(1)
                        perkFrame.banishCardButton:EnableMouse(true)
                        perkFrame.banishCardButton:Enable()
                        if perkFrame.banishCardButton.text then
                            perkFrame.banishCardButton.text:SetText("Banish (" .. rem .. ")")
                            perkFrame.banishCardButton.text:SetTextColor(1, 0.3, 0.3)
                        end
                    else
                        perkFrame.banishCardButton:Show()
                        perkFrame.banishCardButton:SetAlpha(1)
                        perkFrame.banishCardButton:Disable()
                        if perkFrame.banishCardButton.text then
                            perkFrame.banishCardButton.text:SetText("Banish (0)")
                            perkFrame.banishCardButton.text:SetTextColor(0.5, 0.5, 0.5)
                        end
                    end
                end
                if GetRerollInfo() > 0 then rerollButton:Show() else rerollButton:Hide() end
                if GetBanishInfo() > 0 then banishButton:Show() else banishButton:Hide() end
            else
                perkFrame:SetAlpha(0)
                perkFrame:Hide()
                perkFrame:EnableMouse(false)
                perkFrame.selectButton:EnableMouse(false)
                if perkFrame.banishCardButton then
                    perkFrame.banishCardButton:Hide()
                    perkFrame.banishCardButton:SetAlpha(0)
                    perkFrame.banishCardButton:EnableMouse(false)
                end
            end
        end

        RestoreHideButtonPosition()
        RestoreRerollButtonPosition()

        -- Attach "Auto Show Echoes" to bottom of rightmost card (only shown when cards are visible)
        local autoShowCB = _G.EbonholdAutoShowCheck
        local middleCardIndex = math.min(2, perkCount)
        local middleCard = GetCardFrameByIndex(middleCardIndex)
        if autoShowCB and middleCard then
            local anchor = middleCard.backdropFrame or middleCard
            autoShowCB:ClearAllPoints()
            autoShowCB:SetParent(anchor)
            autoShowCB:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -SNAP_GAP)
        end

        local initAvail = GetRerollInfo()
        if initAvail > 0 then
            rerollButton.text:SetText("Reroll (" .. tostring(initAvail) .. ")")
            rerollButton.text:SetTextColor(1, 1, 1)
            rerollButton:Enable()
            -- Only show reroll when the 3 cards are visible (not in "Choose an Echo" state)
            if not perkMainFrame.perksHidden then
                rerollButton:Show()
            else
                rerollButton:Hide()
            end
        else
            rerollButton.text:SetText("Reroll")
            rerollButton:Disable()
            rerollButton:Hide()
        end

        UpdateBanishButtons()
        ApplyRankGlows()

        -- Banish toggle button
        banishMode = false
        local initBanish = GetBanishInfo()
        if initBanish > 0 then
            banishButton.text:SetText("Banish (" .. tostring(initBanish) .. ")")
            banishButton.text:SetTextColor(1, 1, 1)
            banishButton:Enable()
        else
            banishButton.text:SetText("Banish")
            banishButton:Disable()
        end
        banishButton:Hide()

        -- When "Choose an Echo" is shown, hide Show/Hide button (clicking Choose opens echoes)
        hideButton:Hide()
        hideButton.text:SetText("Show")
        hideButton.text:SetTextColor(0.7, 0.7, 0.7)
        perkMainFrame.perksHidden = true
        rerollButton:Hide()
        banishButton:Hide()
        if _G.EbonholdAutoShowCheck then _G.EbonholdAutoShowCheck:Hide() end

        CancelFade(chooseButton)
        chooseButton:EnableMouse(true)
        chooseButton:SetAlpha(1)
        chooseButton:Show()
    end) -- end pcall

    -- Always release the guard before doing anything else, even if pcall errored.
    isShowingPerkUI = false

    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[Ebonhold] PerkUI error: " .. tostring(err) .. "|r")
        return
    end

    if EbonholdAutoShowDB.enabled then
        autoClickDeferred:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            self:Hide()
            if chooseButton and chooseButton:IsShown() then
                chooseButton:Click()
            end
        end)
        autoClickDeferred:Show()
    end
end

local function HidePerkUI()
    isSelecting = false

    if perkMainFrame and perkMainFrame:IsShown() then
        perkMainFrame:Hide()
        perkMainFrame.banishPollElapsed = 0

        for _, f in ipairs(perkFramePool) do
            if f.inUse then
                f:Hide()
                f:EnableMouse(true)
                if f.banishCardButton then f.banishCardButton:Hide() end
            end
        end

        if rerollButton then rerollButton:Hide() end
        if banishButton then banishButton:Hide() end
        if hideButton then hideButton:Hide() end
        if chooseButton then chooseButton:Hide() end
        if perkFamilyHintFrame then perkFamilyHintFrame:Hide() end

        isFading = false
    end
end

ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.PerkUI = ProjectEbonhold.PerkUI or {}
ProjectEbonhold.PerkUI.Show = ShowPerkUI
ProjectEbonhold.PerkUI.Hide = HidePerkUI
ProjectEbonhold.PerkUI.ApplyRankGlows = ApplyRankGlows
ProjectEbonhold.PerkUI.ApplyScale = ApplyPerkUIScale
ProjectEbonhold.PerkUI.ResetSelection = function()
    isSelecting = false
    for _, f in ipairs(perkFramePool) do
        if f.inUse then
            f:EnableMouse(true)
            f.selectButton:EnableMouse(true)
            if f.banishCardButton then f.banishCardButton:EnableMouse(true) end
        end
    end
end

local function PrewarmPool()
    InitializePerkUI()
    for i = 1, 3 do
        local f = AcquirePerkFrame(perkMainFrame)
        f:Hide()
        f.inUse = false
    end
end


local function AddScaleSliderToOptionsPanel()
    -- Scale slider is now handled inside the options scroll frame (options.lua)
end

local function RefreshBanishText()
    UpdateBanishButtons()
end
ProjectEbonhold.PerkUI.RefreshBanishText = RefreshBanishText

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        PrewarmPool()
        ApplyPerkUIScale(GetPerkUIScale())
        AddScaleSliderToOptionsPanel()
    elseif event == "PLAYER_LEVEL_UP" or event == "PLAYER_ENTERING_WORLD" then
        ProjectEbonhold.PerkService.RequestChoice()
    end
end)
