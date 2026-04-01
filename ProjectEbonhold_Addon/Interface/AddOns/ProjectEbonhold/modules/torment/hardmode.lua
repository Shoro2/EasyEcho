local addon, Addon         = ...

------------------------------------------------------------
-- HARDCORE DIFFICULTY PANEL  (UI)
--
-- All tier data is hardcoded client-side.
-- Server only stores / returns the current tier number.
-- Slider goes 1 (Normal) → 4 (max Hardcore).
------------------------------------------------------------

-- Colours
local COLOR_GOLD           = { 1.00, 0.82, 0.00 }
local COLOR_GREEN          = { 0.10, 1.00, 0.10 }
local COLOR_RED            = { 1.00, 0.20, 0.20 }
local COLOR_BLUE           = { 0.20, 0.50, 1.00 }
local COLOR_GREY           = { 0.50, 0.50, 0.50 }
local COLOR_WHITE          = { 1.00, 1.00, 1.00 }
local COLOR_ORANGE         = { 1.00, 0.55, 0.00 }

local SECTION_INSET        = 15
local SECTION_WIDTH        = 350
local PANEL_WIDTH          = 400
local PANEL_MIN_H          = 460

-- Reward icons (standard WoW texture paths)
local ICON_GOLD            = "Interface\\Icons\\INV_Misc_Coin_01"
local ICON_QUEST_XP        = "Interface\\Icons\\INV_Misc_Book_07"
local ICON_KILL_XP         = "Interface\\Icons\\Ability_DualWield"
local ICON_SOUL_ASH        = "Interface\\AddOns\\ProjectEbonhold\\assets\\inv_soulash"
local ICON_REAGENT         = "Interface\\Icons\\INV_Misc_Herb_07"
local ICON_LOOT            = "Interface\\Icons\\INV_Misc_Bag_10"

------------------------------------------------------------
-- HARDCODED TIER DATA  (1 = Normal, 2-4 = Hardcore)
------------------------------------------------------------

local TIER_DATA            = {
  [1] = {
    name       = "Normal",
    scaling    = {
      hp_multiplier    = 1.0,
      melee_multiplier = 1.0,
      spell_multiplier = 1.0,
    },
    -- Sample auras that creatures can gain (spellIds)
    auras      = {},
    rewards    = {
      gold_multiplier        = 1.0,
      extra_loot_chance      = 0,
      extra_loot_count       = 1,
      quest_xp_multiplier    = 1.0,
      creature_xp_multiplier = 1.0,
      soul_ash_multiplier    = 1.0,
      reagent_multiplier     = 1.0,
    },
    debuffs    = {},
    bonusAuras = {},
    extraLoot  = {},
  },

  [2] = {
    name       = "Hardcore I",
    scaling    = {
      hp_multiplier          = 2.7,
      melee_multiplier       = 3.5,
      spell_multiplier       = 3.5,
      aura_max               = 1,
      dungeon_boss_hp_mul    = 3.5,
      dungeon_boss_melee_mul = 2.75,
      dungeon_boss_spell_mul = 3.1,
      raid_boss_hp_mul       = 4.25,
      raid_boss_melee_mul    = 2.75,
      raid_boss_spell_mul    = 3.5,
      dungeon_add_hp_mul     = 3.5,
      dungeon_add_melee_mul  = 3.5,
      dungeon_add_spell_mul  = 2.7,
      raid_add_hp_mul        = 3.5,
      raid_add_melee_mul     = 2.75,
      raid_add_spell_mul     = 3.5,
    },
    auras      = {
      { spellId = 900905 }, -- Tier 1 Creature Empowerment
      { spellId = 900914 }, -- Tier 2 Creature Empowerment
      { spellId = 900913 }, -- Tier 2 Creature Empowerment
    },
    rewards    = {
      gold_multiplier        = 1.25,
      extra_loot_chance      = 5,
      extra_loot_count       = 1,
      quest_xp_multiplier    = 1.25,
      creature_xp_multiplier = 1.15,
      soul_ash_multiplier    = 1.25,
      reagent_multiplier     = 1.25,
      affix_chance_tier      = 1,
    },
    debuffs    = {
      { spellId = 900900 }, -- Tier 2 Debuff Players
    },
    bonusAuras = {
      { spellId = 900922 }, -- Tier 2 Bonus Aura
    },
    extraLoot  = {
      { bagType = "dungeon" },
    },
  },

  [3] = {
    name       = "Hardcore II",
    scaling    = {
      hp_multiplier          = 4.1,
      melee_multiplier       = 6.25,
      spell_multiplier       = 6.25,
      aura_max               = 3,
      dungeon_boss_hp_mul    = 4.1,
      dungeon_boss_melee_mul = 3.0,
      dungeon_boss_spell_mul = 4.0,
      raid_boss_hp_mul       = 6.25,
      raid_boss_melee_mul    = 3.0,
      raid_boss_spell_mul    = 4.0,
      dungeon_add_hp_mul     = 6.25,
      dungeon_add_melee_mul  = 3.1,
      dungeon_add_spell_mul  = 3.1,
      raid_add_hp_mul        = 4.1,
      raid_add_melee_mul     = 3.0,
      raid_add_spell_mul     = 4.0,
    },
    auras      = {
      { spellId = 900905 }, -- Tier 1 Creature Empowerment
      { spellId = 900906 }, -- Tier 2 Creature Empowerment
      { spellId = 900907 }, -- Tier 3 Possible Aura
      { spellId = 900914 }, -- Tier 2 Creature Empowerment
      { spellId = 900913 }, -- Tier 2 Creature Empowerment
    },
    rewards    = {
      gold_multiplier        = 1.5,
      extra_loot_chance      = 10,
      extra_loot_count       = 1,
      quest_xp_multiplier    = 1.5,
      creature_xp_multiplier = 1.3,
      soul_ash_multiplier    = 1.5,
      reagent_multiplier     = 1.5,
      affix_chance_tier      = 2,
    },
    debuffs    = {
      { spellId = 900900 }, -- Tier 2 Debuff Players
      { spellId = 900908 }, -- Tier 3 Debuff Players
    },
    bonusAuras = {
      { spellId = 900922 }, -- Tier 2 Bonus Aura
      { spellId = 900923 }, -- Tier 3 Bonus Aura
    },
    extraLoot  = {
      { bagType = "dungeon" },
      { bagType = "raid" },
    },
  },

  [4] = {
    name       = "Hardcore III",
    scaling    = {
      hp_multiplier          = 6.7,
      melee_multiplier       = 8.0,
      spell_multiplier       = 8.0,
      aura_max               = 4,
      dungeon_boss_hp_mul    = 8.0,
      dungeon_boss_melee_mul = 3.5,
      dungeon_boss_spell_mul = 4.5,
      raid_boss_hp_mul       = 8.25,
      raid_boss_melee_mul    = 3.5,
      raid_boss_spell_mul    = 4.5,
      dungeon_add_hp_mul     = 8.0,
      dungeon_add_melee_mul  = 8.0,
      dungeon_add_spell_mul  = 6.7,
      raid_add_hp_mul        = 8.0,
      raid_add_melee_mul     = 3.5,
      raid_add_spell_mul     = 4.5,
    },
    auras      = {
      { spellId = 900905 }, -- Tier 1 Creature Empowerment
      { spellId = 900906 }, -- Tier 2 Creature Empowerment
      { spellId = 900907 }, -- Tier 3 Possible Aura
      { spellId = 900904 }, -- Tier 3 Creature Empowerment
      { spellId = 900914 }, -- Tier 2 Creature Empowerment
      { spellId = 900913 }, -- Tier 2 Creature Empowerment
    },
    rewards    = {
      gold_multiplier        = 2.0,
      extra_loot_chance      = 15,
      extra_loot_count       = 2,
      quest_xp_multiplier    = 2.0,
      creature_xp_multiplier = 1.75,
      soul_ash_multiplier    = 2.0,
      reagent_multiplier     = 1.75,
      affix_chance_tier      = 3,
    },
    debuffs    = {
      { spellId = 900900 }, -- Tier 2 Debuff Players
      { spellId = 900908 }, -- Tier 3 Debuff Players
      { spellId = 900901 }, -- Tier 4 Debuff Players
    },
    bonusAuras = {
      { spellId = 900922 }, -- Tier 2 Bonus Aura
      { spellId = 900923 }, -- Tier 3 Bonus Aura
      { spellId = 900924 }, -- Tier 4 Bonus Aura
    },
    extraLoot  = {
      { bagType = "dungeon" },
      { bagType = "raid" },
    },
  },
}

-- State
local hardmodeFrame        = nil
local confirmPopup         = nil
local selectedTier         = 1
local tutorialFrame        = nil

local SLIDER_MIN           = 1
local SLIDER_MAX           = 4

-- Expose UI handle for service callbacks
ProjectEbonhold.HardmodeUI = ProjectEbonhold.HardmodeUI or {}

------------------------------------------------------------
-- TUTORIAL PERSISTENCE  (per-character)
------------------------------------------------------------

local function GetCharacterKey()
  local name  = UnitName("player")
  local realm = GetRealmName()
  return name .. "-" .. realm
end

local function HasSeenTutorial()
  if not ProjectEbonholdDB then return false end
  if not ProjectEbonholdDB.hardmodeTutorialSeen then return false end
  return ProjectEbonholdDB.hardmodeTutorialSeen[GetCharacterKey()] == true
end

local function MarkTutorialSeen()
  if not ProjectEbonholdDB then ProjectEbonholdDB = {} end
  if not ProjectEbonholdDB.hardmodeTutorialSeen then
    ProjectEbonholdDB.hardmodeTutorialSeen = {}
  end
  ProjectEbonholdDB.hardmodeTutorialSeen[GetCharacterKey()] = true
end

------------------------------------------------------------
-- TUTORIAL OVERLAY
------------------------------------------------------------

local function ShowTutorial()
  if tutorialFrame then return end
  if not hardmodeFrame then return end

  -- Dark overlay parented to the hardmode frame itself
  tutorialFrame = CreateFrame("Frame", "HardmodeTutorialOverlay", hardmodeFrame)
  tutorialFrame:SetPoint("TOP", hardmodeFrame, "TOP", 0, -40)
  tutorialFrame:SetSize(PANEL_WIDTH - 30, 370)
  tutorialFrame:SetFrameLevel(hardmodeFrame:GetFrameLevel() + 50)
  tutorialFrame:EnableMouse(true)

  local dimTex = tutorialFrame:CreateTexture(nil, "BACKGROUND")
  dimTex:SetTexture(0, 0, 0, 0.88)
  dimTex:SetAllPoints(tutorialFrame)

  -- Skull icon
  local skull = tutorialFrame:CreateTexture(nil, "OVERLAY")
  skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
  skull:SetSize(28, 28)
  skull:SetPoint("TOP", tutorialFrame, "TOP", 0, -20)

  -- Title
  local title = tutorialFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", skull, "BOTTOM", 0, -4)
  title:SetText("|cffFFD100Hardcore|r")

  -- Body text
  local body = tutorialFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  body:SetPoint("TOP", title, "BOTTOM", 0, -10)
  body:SetWidth(PANEL_WIDTH - 50)
  body:SetJustifyH("CENTER")
  body:SetWordWrap(true)
  body:SetSpacing(3)
  body:SetText(
    "The open world feels too easy? Hardcore lets you " ..
    "|cffFF4444raise the difficulty|r of every creature you encounter, " ..
    "anywhere in the world.\n\n" ..
    "Higher tiers grant |cff00FF00bonus gold, experience, soul ash, reagents|r " ..
    "and even |cff00FF00extra loot bags|r from dungeons and raids.\n\n" ..
    "Push further and your gear will start rolling " ..
    "|cffFF8800powerful predefined affixes|r. The higher the tier, " ..
    "the stronger and more frequent they become.\n\n" ..
    "|cffFF4444Be warned:|r enemies hit much harder, gain new abilities, " ..
    "and |cffFF4444death in Hardcore is permanent|r. No resurrection."
  )

  -- "Got it" button
  local gotItBtn = CreateFrame("Button", nil, tutorialFrame, "UIPanelButtonTemplate")
  gotItBtn:SetSize(140, 30)
  gotItBtn:SetPoint("BOTTOM", tutorialFrame, "BOTTOM", 0, 16)
  gotItBtn:SetText("Got it!")
  gotItBtn:SetFrameLevel(tutorialFrame:GetFrameLevel() + 10)
  gotItBtn:SetScript("OnClick", function()
    MarkTutorialSeen()
    tutorialFrame:Hide()
    tutorialFrame = nil
  end)

  tutorialFrame:Show()
end

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function Fmt(v, decimals)
  decimals = decimals or 1
  return string.format("%." .. decimals .. "f", v)
end
-- Convert a multiplier (e.g. 1.5) to a percentage string (e.g. "+50%")
local function Pct(multiplier)
  local pct = math.floor((multiplier - 1) * 100 + 0.5)
  if pct >= 0 then return "+" .. pct .. "%" end
  return pct .. "%"
end
local function ColorText(text, r, g, b)
  return string.format("|cff%02x%02x%02x%s|r",
    math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), text)
end

local function GetTierColor(tier)
  if tier <= 1 then return 1, 1, 1 end
  local progress = (tier - 1) / (SLIDER_MAX - 1)
  return 1.0, 1.0 - progress * 0.8, 1.0 - progress * 0.8
end

--- Build a display-data table for a given tier from the hardcoded table
local function GetTierDisplayData(tier)
  return TIER_DATA[tier] or TIER_DATA[1]
end

--- Returns true when the player is allowed to change difficulty
local function CanApply()
  local playerLevel = UnitLevel("player")
  -- Disallow changing difficulty in combat
  if UnitAffectingCombat and UnitAffectingCombat("player") then
    return false
  end
  return playerLevel <= 10 or IsResting()
end

------------------------------------------------------------
-- SECTION BUILDER: bordered sub-panel inside the scroll
------------------------------------------------------------

local function CreateSection(parent, title, yOffset, width)
  local w = width or SECTION_WIDTH
  local section = CreateFrame("Frame", nil, parent)
  section:SetSize(w, 10)
  section:SetPoint("TOP", parent, "TOP", 0, yOffset)

  local header = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOP", section, "TOP", 0, -2)
  header:SetText(ColorText(title, COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3]))
  section.header = header

  section.contentTop = -18
  section.sectionWidth = w
  section.lines = {}
  section.iconRows = {}

  return section
end

local function AddLine(section, text, yOff)
  local y = yOff or (section.contentTop - (#section.lines * 16))
  local line = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  line:SetPoint("TOP", section, "TOP", 0, y)
  line:SetWidth(SECTION_WIDTH - 24)
  line:SetJustifyH("CENTER")
  line:SetWordWrap(true)
  line:SetText(text)
  table.insert(section.lines, line)
  return line
end

local function FinaliseSection(section, bottomPadding)
  bottomPadding = bottomPadding or 4
  local lowest = section.contentTop
  for _, line in ipairs(section.lines) do
    local _, _, _, _, y = line:GetPoint(1)
    if y then
      local h = line:GetStringHeight() or 14
      local bottom = y - h
      if bottom < lowest then lowest = bottom end
    end
  end
  for _, row in ipairs(section.iconRows) do
    local _, _, _, _, y = row:GetPoint(1)
    if y then
      local h = row:GetHeight() or 20
      local bottom = y - h
      if bottom < lowest then lowest = bottom end
    end
  end
  local totalH = math.abs(lowest) + bottomPadding
  section:SetHeight(totalH)
  return totalH
end

------------------------------------------------------------
-- ICON ROW
------------------------------------------------------------

local TOOLTIP_SCALE = 0.85

local function AddIconRow(section, icon, text, yOff, tooltipTitle, tooltipBody)
  local row = CreateFrame("Frame", nil, section)
  row:SetSize(SECTION_WIDTH - 24, 18)
  row:SetPoint("TOPLEFT", section, "TOPLEFT", 12, yOff)

  local tex = row:CreateTexture(nil, "ARTWORK")
  tex:SetTexture(icon)
  tex:SetSize(14, 14)
  tex:SetPoint("LEFT", row, "LEFT", 0, 0)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("LEFT", tex, "RIGHT", 6, 0)
  label:SetWidth(SECTION_WIDTH - 60)
  label:SetJustifyH("LEFT")
  label:SetText(text)

  if tooltipTitle then
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      GameTooltip:SetScale(TOOLTIP_SCALE)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipTitle, 1, 0.82, 0)
      if tooltipBody then
        GameTooltip:AddLine(tooltipBody, 1, 1, 1, true)
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
      GameTooltip:SetScale(1); GameTooltip:Hide()
    end)
  end

  table.insert(section.iconRows, row)
  return row
end

-- --------------------------------------------------------
-- Horizontal icon strip helper
--   items = { { icon, tooltipTitle, tooltipBody }, ... }
--   Returns the strip frame (caller must store/cleanup)
-- --------------------------------------------------------
local HSTRIP_ICON   = 26
local HSTRIP_GAP    = 4
local HSTRIP_BORDER = 4 -- extra px for border frame around icon

local function CreateHIconStrip(parent, items, yOff)
  local strip = CreateFrame("Frame", nil, parent)
  local cellSize = HSTRIP_ICON + HSTRIP_BORDER
  strip:SetHeight(cellSize)
  local totalW = #items * cellSize + math.max(0, #items - 1) * HSTRIP_GAP
  strip:SetWidth(totalW)
  strip:SetPoint("TOP", parent, "TOP", 0, yOff)

  for i, entry in ipairs(items) do
    -- Border frame (like perk browser)
    local borderFrame = CreateFrame("Frame", nil, strip)
    borderFrame:SetSize(cellSize, cellSize)
    borderFrame:SetPoint("LEFT", strip, "LEFT", (i - 1) * (cellSize + HSTRIP_GAP), 0)
    borderFrame:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    if entry.borderColor then
      borderFrame:SetBackdropBorderColor(entry.borderColor[1], entry.borderColor[2], entry.borderColor[3],
        entry.borderColor[4] or 1)
    else
      borderFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    -- Icon centred inside border
    local tex = borderFrame:CreateTexture(nil, "ARTWORK")
    tex:SetSize(HSTRIP_ICON, HSTRIP_ICON)
    tex:SetPoint("CENTER", borderFrame, "CENTER", 0, 0)
    tex:SetTexture(entry.icon)
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Desaturated (inactive) state
    if entry.desaturated then
      tex:SetDesaturated(true)
      tex:SetAlpha(0.45)
      borderFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.6)
    end

    -- Value text overlay (bottom line; shrink to 7 when a second line is also shown)
    if entry.value and not entry.desaturated then
      local valText = borderFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
      valText:SetPoint("BOTTOM", borderFrame, "BOTTOM", 0, 1)
      valText:SetFont(valText:GetFont(), entry.value2 and 7 or 8, "OUTLINE")
      valText:SetText(entry.value)
      valText:SetTextColor(1, 1, 1, 1)
    end
    -- Second value text overlay (stacked above the first)
    if entry.value2 and not entry.desaturated then
      local val2Text = borderFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
      val2Text:SetPoint("BOTTOM", borderFrame, "BOTTOM", 0, 10)
      val2Text:SetFont(val2Text:GetFont(), 7, "OUTLINE")
      val2Text:SetText(entry.value2)
      val2Text:SetTextColor(1, 0.85, 0.2, 1)
    end

    -- Tooltip
    borderFrame:EnableMouse(true)
    local tt = entry.tooltipTitle
    local tb = entry.tooltipBody
    local sid = entry.spellId
    borderFrame:SetScript("OnEnter", function(self)
      GameTooltip:SetScale(TOOLTIP_SCALE)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if sid then
        GameTooltip:SetHyperlink('spell:' .. sid)
      else
        GameTooltip:SetText(tt, 1, 0.82, 0)
        if tb then GameTooltip:AddLine(tb, 1, 1, 1, true) end
      end
      GameTooltip:Show()
    end)
    borderFrame:SetScript("OnLeave", function()
      GameTooltip:SetScale(1); GameTooltip:Hide()
    end)
  end

  return strip
end

------------------------------------------------------------
-- CONFIRMATION POPUP
------------------------------------------------------------

local function HidePopup()
  if confirmPopup then
    confirmPopup:Hide()
    confirmPopup.overlay:Hide()
    confirmPopup.blockFrame:Hide()
  end
end

local function ShowConfirmationPopup(tier)
  if not confirmPopup then
    local blockFrame = CreateFrame("Frame", "HardmodeBlockFrame", UIParent)
    blockFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    blockFrame:SetFrameLevel(999)
    blockFrame:SetAllPoints(UIParent)
    blockFrame:EnableMouse(true)
    blockFrame:SetScript("OnMouseDown", function() end)
    blockFrame:Hide()

    confirmPopup = CreateFrame("Frame", "HardmodeConfirmPopup", UIParent)
    confirmPopup:SetSize(380, 260)
    confirmPopup:SetPoint("CENTER")
    confirmPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    confirmPopup:SetFrameLevel(1000)
    confirmPopup.blockFrame = blockFrame

    local bg = confirmPopup:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\UI-Background-Rock")
    bg:SetPoint("TOPLEFT", 8, -8)
    bg:SetPoint("BOTTOMRIGHT", -8, 8)
    bg:SetHorizTile(true)
    bg:SetVertTile(true)

    confirmPopup:SetBackdrop({
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local overlay = confirmPopup:CreateTexture(nil, "BACKGROUND")
    overlay:SetTexture(0, 0, 0, 0.85)
    overlay:SetAllPoints(UIParent)
    confirmPopup.overlay = overlay

    confirmPopup:EnableMouse(true)
    confirmPopup:SetScript("OnMouseDown", function() end)

    confirmPopup.title = confirmPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    confirmPopup.title:SetPoint("TOP", 0, -20)
    confirmPopup.title:SetDrawLayer("OVERLAY", 7)

    confirmPopup.desc = confirmPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    confirmPopup.desc:SetPoint("TOP", confirmPopup.title, "BOTTOM", 0, -12)
    confirmPopup.desc:SetWidth(340)
    confirmPopup.desc:SetJustifyH("CENTER")
    confirmPopup.desc:SetWordWrap(true)
    confirmPopup.desc:SetDrawLayer("OVERLAY", 7)

    confirmPopup.acceptBtn = CreateFrame("Button", nil, confirmPopup, "UIPanelButtonTemplate")
    confirmPopup.acceptBtn:SetSize(120, 30)
    confirmPopup.acceptBtn:SetPoint("BOTTOM", confirmPopup, "BOTTOM", -65, 20)
    confirmPopup.acceptBtn:SetText("Accept")
    confirmPopup.acceptBtn:SetFrameLevel(confirmPopup:GetFrameLevel() + 10)

    confirmPopup.cancelBtn = CreateFrame("Button", nil, confirmPopup, "UIPanelButtonTemplate")
    confirmPopup.cancelBtn:SetSize(120, 30)
    confirmPopup.cancelBtn:SetPoint("BOTTOM", confirmPopup, "BOTTOM", 65, 20)
    confirmPopup.cancelBtn:SetText("Cancel")
    confirmPopup.cancelBtn:SetFrameLevel(confirmPopup:GetFrameLevel() + 10)
    confirmPopup.cancelBtn:SetScript("OnClick", HidePopup)
  end

  local tr, tg, tb = GetTierColor(tier)
  confirmPopup.title:SetText("|cffFFD100Change Difficulty|r")

  local msg
  if tier == 1 then
    msg = "Return to |cffFFFFFFNormal|r difficulty?\nAll hardcore effects will be removed."
  else
    local tierStr = ColorText("Tier " .. tier, tr, tg, tb)
    msg = "Activate " ..
        tierStr ..
        " difficulty?\nEnemies will become significantly stronger\nand you will receive increased rewards.\n\n|cffFF4444Warning:|r Dying in Hardcore is |cffFF4444definitive|r, you cannot revive using any other method.\n\n|cffFFCC00Dungeon/Raid IDs are shared across all Hardcore and normal tiers.|r"
  end
  confirmPopup.desc:SetText(msg)

  confirmPopup.acceptBtn:SetScript("OnClick", function()
    HidePopup()
    if ProjectEbonhold.HardmodeService then
      ProjectEbonhold.HardmodeService.SetDifficulty(tier)
    end
  end)

  confirmPopup.blockFrame:Show()
  confirmPopup.overlay:Show()
  confirmPopup:Show()
end

------------------------------------------------------------
-- TIER SLIDER  (1 – 4)
------------------------------------------------------------

local function CreateTierSlider(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(220, 44)

  local slider = CreateFrame("Slider", "HardmodeTierSlider", frame, "OptionsSliderTemplate")
  slider:SetWidth(180)
  slider:SetHeight(17)
  slider:SetPoint("TOP", frame, "TOP", 0, -4)
  slider:SetMinMaxValues(SLIDER_MIN, SLIDER_MAX)
  slider:SetValueStep(1)

  _G[slider:GetName() .. "Low"]:SetText(SLIDER_MIN)
  _G[slider:GetName() .. "High"]:SetText(SLIDER_MAX)
  _G[slider:GetName() .. "Text"]:SetText("")

  frame.valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

  local function UpdateLabel(tier)
    local r, g, b = GetTierColor(tier)
    local td = TIER_DATA[tier] or TIER_DATA[1]
    if tier == 1 then
      frame.valueText:SetText("|cffFFFFFFNormal|r")
    else
      frame.valueText:SetText(ColorText(td.name, r, g, b))
    end
  end

  function frame:SetValue(tier)
    selectedTier = tier
    slider:SetValue(tier)
    UpdateLabel(tier)
  end

  function frame:GetValue()
    return selectedTier
  end

  slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value + 0.5)
    if value == selectedTier then return end
    selectedTier = value
    UpdateLabel(value)
    -- Instantly refresh info sections from hardcoded data
    if hardmodeFrame and hardmodeFrame:IsShown() and hardmodeFrame.canvas then
      BuildInfoSections(hardmodeFrame.canvas, GetTierDisplayData(value), INFO_SECTIONS_Y)
    end
    -- Enable/disable Apply based on whether selection differs from current tier
    if hardmodeFrame and hardmodeFrame.applyBtn then
      local svc = ProjectEbonhold.HardmodeService
      local curTier = svc and svc.GetCurrentDifficulty() or 1
      if not CanApply() then
        hardmodeFrame.applyBtn:Hide()
        if hardmodeFrame.applyHint then hardmodeFrame.applyHint:Show() end
      elseif value == curTier then
        if hardmodeFrame.applyHint then hardmodeFrame.applyHint:Hide() end
        hardmodeFrame.applyBtn:Show()
        hardmodeFrame.applyBtn:Disable()
      else
        if hardmodeFrame.applyHint then hardmodeFrame.applyHint:Hide() end
        hardmodeFrame.applyBtn:Show()
        hardmodeFrame.applyBtn:Enable()
      end
    end
  end)

  return frame
end

------------------------------------------------------------
-- INFO SECTIONS: built from a tier-data table
------------------------------------------------------------

local infoSectionFrames = {}

local function ClearInfoSections()
  for _, f in ipairs(infoSectionFrames) do
    if f.Hide then f:Hide() end
    if f.SetParent and f:GetObjectType() ~= "FontString" then
      f:SetParent(nil)
    end
  end
  infoSectionFrames = {}
end

-- forward-declared; assigned after definition
BuildInfoSections = nil

BuildInfoSections = function(canvas, displayData, startY)
  ClearInfoSections()

  local y = startY

  -- Tier 0: just show a centred "Normal difficulty" label
  if displayData.name == "Normal" then
    local label = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("TOP", canvas, "TOP", 0, y - 40)
    label:SetText("Normal difficulty")
    label:SetAlpha(0.75)
    table.insert(infoSectionFrames, label)
    canvas:SetHeight(math.abs(y) + 100)
    return y
  end

  --------------------------------------------------------
  -- Creature Modifiers  (single Open World row, full breakdown in tooltip)
  --------------------------------------------------------
  local s = displayData.scaling

  local ICON_HP    = "Interface\\Icons\\PetBattle_Health"
  local ICON_MELEE = "Interface\\Icons\\Ability_MeleeDamage"
  local ICON_SPELL = "Interface\\Icons\\Spell_Ice_MagicDamage"

  local dualRow = CreateFrame("Frame", nil, canvas)
  dualRow:SetSize(SECTION_WIDTH, 10) -- height set below
  dualRow:SetPoint("TOP", canvas, "TOP", 0, y)
  table.insert(infoSectionFrames, dualRow)

  local halfW = math.floor(SECTION_WIDTH / 2)

  local modTitle = dualRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  modTitle:SetPoint("TOP", dualRow, "TOP", -halfW / 2, -2)
  modTitle:SetText(ColorText("Creature Modifiers", COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3]))

  local scalingItems = {
    {
      icon         = ICON_HP,
      value        = Pct(s.hp_multiplier),
      tooltipTitle = "Health  " .. Pct(s.hp_multiplier),
      tooltipBody  = "Open World: x" .. Fmt(s.hp_multiplier)
          .. "\nDungeon Boss: x" .. Fmt(s.dungeon_boss_hp_mul)
          .. "\nRaid Boss: x" .. Fmt(s.raid_boss_hp_mul)
          .. "\nDungeon Adds: x" .. Fmt(s.dungeon_add_hp_mul)
          .. "\nRaid Adds: x" .. Fmt(s.raid_add_hp_mul),
    },
    {
      icon         = ICON_MELEE,
      value        = Pct(s.melee_multiplier),
      tooltipTitle = "Melee  " .. Pct(s.melee_multiplier),
      tooltipBody  = "Open World: x" .. Fmt(s.melee_multiplier)
          .. "\nDungeon Boss: x" .. Fmt(s.dungeon_boss_melee_mul)
          .. "\nRaid Boss: x" .. Fmt(s.raid_boss_melee_mul)
          .. "\nDungeon Adds: x" .. Fmt(s.dungeon_add_melee_mul)
          .. "\nRaid Adds: x" .. Fmt(s.raid_add_melee_mul),
    },
    {
      icon         = ICON_SPELL,
      value        = Pct(s.spell_multiplier),
      tooltipTitle = "Spell  " .. Pct(s.spell_multiplier),
      tooltipBody  = "Open World: x" .. Fmt(s.spell_multiplier)
          .. "\nDungeon Boss: x" .. Fmt(s.dungeon_boss_spell_mul)
          .. "\nRaid Boss: x" .. Fmt(s.raid_boss_spell_mul)
          .. "\nDungeon Adds: x" .. Fmt(s.dungeon_add_spell_mul)
          .. "\nRaid Adds: x" .. Fmt(s.raid_add_spell_mul),
    },
  }
  local scalingStrip = CreateHIconStrip(dualRow, scalingItems, 0)
  scalingStrip:ClearAllPoints()
  scalingStrip:SetPoint("TOP", modTitle, "BOTTOM", 0, -4)
  table.insert(infoSectionFrames, scalingStrip)

  -- === RIGHT: Creature Empowerments ===
  local auraMaxLabel = (s.aura_max and s.aura_max > 0) and ("  (Max " .. s.aura_max .. ")") or ""
  local empTitle = dualRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  empTitle:SetPoint("TOP", dualRow, "TOP", halfW / 2, -2)
  empTitle:SetText(ColorText("Creature Empowerments" .. auraMaxLabel, COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3]))

  -- Build ordered unique aura list: sorted by first unlock tier (lowest → highest)
  local orderedAuras = {}
  local seenAura = {}
  for tier = 2, SLIDER_MAX do
    for _, aura in ipairs(TIER_DATA[tier].auras or {}) do
      if not seenAura[aura.spellId] then
        seenAura[aura.spellId] = true
        table.insert(orderedAuras, { spellId = aura.spellId, unlockTier = tier })
      end
    end
  end

  local activeAuras = {}
  for _, aura in ipairs(displayData.auras or {}) do
    activeAuras[aura.spellId] = true
  end

  local auraItems = {}
  for _, aura in ipairs(orderedAuras) do
    local sid = aura.spellId
    local isActive = activeAuras[sid] or false
    local auraName, _, auraIcon = GetSpellInfo(sid)
    auraName = auraName or ("Spell " .. sid)
    auraIcon = auraIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
    table.insert(auraItems, {
      icon         = auraIcon,
      borderColor  = isActive and { 1, 0.2, 0.2, 0.8 } or nil,
      desaturated  = not isActive,
      spellId      = sid,
      tooltipTitle = auraName,
      tooltipBody  = isActive
          and ("Unlocked at Tier " .. aura.unlockTier .. ", creatures can gain this aura")
          or ("Unlocked at Tier " .. aura.unlockTier .. ", not active at this difficulty"),
    })
  end
  -- Split auras into two centred rows
  local half = math.ceil(#auraItems / 2)
  local auraItems1, auraItems2 = {}, {}
  for i, item in ipairs(auraItems) do
    if i <= half then table.insert(auraItems1, item) else table.insert(auraItems2, item) end
  end

  local auraStrip1 = CreateHIconStrip(dualRow, auraItems1, 0)
  auraStrip1:ClearAllPoints()
  auraStrip1:SetPoint("TOP", empTitle, "BOTTOM", 0, -4)
  table.insert(infoSectionFrames, auraStrip1)

  local auraStrip2 = CreateHIconStrip(dualRow, auraItems2, 0)
  auraStrip2:ClearAllPoints()
  auraStrip2:SetPoint("TOP", auraStrip1, "BOTTOM", 0, -4)
  table.insert(infoSectionFrames, auraStrip2)

  -- title(2+14) + gap(4) + row1(30) + gap(4) + row2(30) + padding(6)
  local dualRowH = 2 + 14 + 4 + (HSTRIP_ICON + HSTRIP_BORDER) + 4 + (HSTRIP_ICON + HSTRIP_BORDER) + 6
  dualRow:SetHeight(dualRowH)
  y = y - dualRowH - 6

  --------------------------------------------------------
  -- Bonuses & Curses (single section, full width)
  --------------------------------------------------------
  local maxDebuffs = TIER_DATA[4].debuffs

  local rewardSec = CreateSection(canvas, "Bonuses", y)
  table.insert(infoSectionFrames, rewardSec)

  local rw           = displayData.rewards
  local rwY          = rewardSec.contentTop

  local GREEN_BORDER = { 0.1, 1, 0.1, 0.8 }
  local GREY_BORDER  = { 0.35, 0.35, 0.35, 0.6 }

  local function RewardIcon(icon, multiplier, label)
    local active = multiplier > 1.0
    return {
      icon         = icon,
      value        = Pct(multiplier),
      borderColor  = active and GREEN_BORDER or GREY_BORDER,
      desaturated  = not active,
      tooltipTitle = label .. "  " .. Pct(multiplier),
      tooltipBody  = active
          and (label .. " increased by " .. Pct(multiplier))
          or (label .. ", no bonus at this tier"),
    }
  end

  local xpActive = rw.quest_xp_multiplier > 1.0 or rw.creature_xp_multiplier > 1.0
  local rewardItems = {
    RewardIcon(ICON_GOLD, rw.gold_multiplier, "Gold"),
    {
      icon         = "Interface\\AddOns\\ProjectEbonhold\\assets\\xp_icon",
      value        = Pct(rw.quest_xp_multiplier),
      value2       = Pct(rw.creature_xp_multiplier),
      borderColor  = xpActive and GREEN_BORDER or GREY_BORDER,
      desaturated  = not xpActive,
      tooltipTitle = "Experience",
      tooltipBody  = "Quest XP: " .. Pct(rw.quest_xp_multiplier) .. "\nKill XP:  " .. Pct(rw.creature_xp_multiplier),
    },
    RewardIcon(ICON_SOUL_ASH, rw.soul_ash_multiplier, "Soul Ash"),
    RewardIcon(ICON_REAGENT, rw.reagent_multiplier, "Reagents"),
  }
  local lootActive = rw.extra_loot_chance > 0
  table.insert(rewardItems, {
    icon         = ICON_LOOT,
    value        = lootActive and (Fmt(rw.extra_loot_chance, 0) .. "%") or "0%",
    borderColor  = lootActive and GREEN_BORDER or GREY_BORDER,
    desaturated  = not lootActive,
    tooltipTitle = "Bonus Loot  " .. (lootActive and (Fmt(rw.extra_loot_chance, 0) .. "%") or "0%"),
    tooltipBody  = lootActive
        and (Fmt(rw.extra_loot_chance, 0) .. "% chance for " .. rw.extra_loot_count .. " extra drop(s)")
        or "Bonus loot, not available at this tier",
  })

  local affixTier = rw.affix_chance_tier or 0
  local affixDescs = {
    [1] =
    "Equipment looted in the open world, dungeons and raids has a small chance to drop corrupted with a random stat modifier.\n\nExtract affixes from corrupted gear to learn them, then apply them to clean items.",
    [2] =
    "Equipment looted in the open world, dungeons and raids has an increased chance to drop corrupted.\n\nMore corruption types become available and roll chances scale higher than Tier 1.",
    [3] =
    "Equipment looted in the open world, dungeons and raids has a high chance to drop corrupted with powerful modifiers.\n\nAll corruption types are unlocked and roll at maximum probability.",
  }
  table.insert(rewardItems, {
    icon         = "Interface\\Icons\\Inv_enchant_formulasuperior_01",
    borderColor  = affixTier > 0 and GREEN_BORDER or GREY_BORDER,
    desaturated  = affixTier == 0,
    tooltipTitle = affixTier > 0 and ("Predefined Affixes : Tier " .. affixTier) or "Predefined Affixes",
    tooltipBody  = affixTier > 0
        and affixDescs[affixTier]
        or "Not active at this tier.",
  })

  -- Bonus auras in the same reward strip
  local activeBonusAuras = {}
  for _, buff in ipairs(displayData.bonusAuras or {}) do
    activeBonusAuras[buff.spellId] = true
  end
  local maxBonusAuras = TIER_DATA[4].bonusAuras or {}
  for _, buff in ipairs(maxBonusAuras) do
    local isActive = activeBonusAuras[buff.spellId] or false
    local bName, _, bIcon = GetSpellInfo(buff.spellId)
    bName = bName or buff.name or ("Spell " .. buff.spellId)
    bIcon = bIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
    table.insert(rewardItems, {
      icon         = bIcon,
      borderColor  = isActive and GREEN_BORDER or GREY_BORDER,
      desaturated  = not isActive,
      spellId      = buff.spellId,
      tooltipTitle = bName,
      tooltipBody  = isActive
          and "This bonus aura is active at this tier"
          or "This bonus aura is not active at this tier",
    })
  end

  local rewardStrip = CreateHIconStrip(rewardSec, rewardItems, rwY)
  table.insert(rewardSec.iconRows, rewardStrip)
  table.insert(infoSectionFrames, rewardStrip)
  rwY = rwY - HSTRIP_ICON - 4

  -- Curses sub-row (inside same section)
  if #maxDebuffs > 0 then
    rwY = rwY - 8 -- extra gap between reward icons and Curses
    local curseLabel = rewardSec:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    curseLabel:SetPoint("TOP", rewardSec, "TOP", 0, rwY)
    curseLabel:SetText(ColorText("Curses", COLOR_GOLD[1], COLOR_GOLD[2], COLOR_GOLD[3]))
    table.insert(rewardSec.lines, curseLabel)
    rwY = rwY - 16

    local activeDebuffs = {}
    for _, debuff in ipairs(displayData.debuffs) do
      activeDebuffs[debuff.spellId] = true
    end

    local debuffItems = {}
    for _, debuff in ipairs(maxDebuffs) do
      local isActive = activeDebuffs[debuff.spellId] or false
      local dName, _, dIcon = GetSpellInfo(debuff.spellId)
      dName = dName or debuff.name or ("Spell " .. debuff.spellId)
      dIcon = dIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
      table.insert(debuffItems, {
        icon         = dIcon,
        borderColor  = isActive and { 1, 0.2, 0.2, 0.8 } or nil,
        desaturated  = not isActive,
        spellId      = debuff.spellId,
        tooltipTitle = dName,
        tooltipBody  = isActive
            and "This curse is active at this tier"
            or "This curse is not active at this tier",
      })
    end
    local debuffStrip = CreateHIconStrip(rewardSec, debuffItems, rwY)
    table.insert(rewardSec.iconRows, debuffStrip)
    table.insert(infoSectionFrames, debuffStrip)
  end

  local rewardH = FinaliseSection(rewardSec)
  y = y - rewardH - 6

  --------------------------------------------------------
  -- Extra Loot
  --------------------------------------------------------
  local extraLoot = displayData.extraLoot or {}
  local maxExtraLoot = TIER_DATA[4].extraLoot or {}
  if #maxExtraLoot > 0 then
    local activeBags = {}
    for _, item in ipairs(extraLoot) do
      activeBags[item.bagType] = true
    end

    local lootSec = CreateSection(canvas, "Bonus Loot", y)
    table.insert(infoSectionFrames, lootSec)
    local lY = lootSec.contentTop
    local lootItems = {}
    for _, item in ipairs(maxExtraLoot) do
      local isActive = activeBags[item.bagType] or false
      if item.bagType == "dungeon" then
        table.insert(lootItems, {
          icon         = "Interface\\Icons\\garrison_bluearmor",
          borderColor  = isActive and GREEN_BORDER or GREY_BORDER,
          desaturated  = not isActive,
          tooltipTitle = "Dungeon Loot Bag",
          tooltipBody  = isActive
              and "Chance to receive a random dungeon item when killing enemies. The item's level is equal to the creature's level."
              or "Not available at this tier.",
        })
      elseif item.bagType == "raid" then
        table.insert(lootItems, {
          icon         = "Interface\\Icons\\garrison_purplearmor",
          borderColor  = isActive and GREEN_BORDER or GREY_BORDER,
          desaturated  = not isActive,
          tooltipTitle = "Raid Loot Bag",
          tooltipBody  = isActive
              and "Chance to receive a random raid item when killing enemies. The item's level is equal to the creature's level."
              or "Not available at this tier.",
        })
      end
    end
    local lootStrip = CreateHIconStrip(lootSec, lootItems, lY)
    table.insert(lootSec.iconRows, lootStrip)
    table.insert(infoSectionFrames, lootStrip)
    lY = lY - HSTRIP_ICON - 4
    local lootH = FinaliseSection(lootSec)
    y = y - lootH - 6
  end

  local contentH = math.abs(y) + 20
  canvas:SetHeight(contentH)
  return y
end

-- Y offset where info sections start (below the top bar)
INFO_SECTIONS_Y = -105

------------------------------------------------------------
-- BUILD THE MAIN PANEL
------------------------------------------------------------

local function BuildContent(canvas, currentTier)
  -- Wipe previous children
  local children = { canvas:GetChildren() }
  for _, c in ipairs(children) do
    c:Hide(); c:SetParent(nil)
  end
  local regions = { canvas:GetRegions() }
  for _, r in ipairs(regions) do
    if r and r.Hide then r:Hide() end
  end
  infoSectionFrames = {}

  --------------------------------------------------------
  -- TOP BAR
  --------------------------------------------------------
  local topBar = CreateFrame("Frame", nil, canvas)
  topBar:SetSize(SECTION_WIDTH, 70)
  topBar:SetPoint("TOP", canvas, "TOP", 0, 0)

  -- Slider – centred horizontally, 40 px below top
  local slider = CreateTierSlider(topBar)
  slider:SetPoint("TOP", topBar, "TOP", 0, -18)
  slider:SetValue(currentTier)

  -- Apply button – centred, below the slider
  local applyBtn = utils.CreateSimpleCustomButton(topBar,
    "Apply",
    function()
      local playerLevel = UnitLevel("player")
      if UnitAffectingCombat and UnitAffectingCombat("player") then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffFF0000[Hardcore] You cannot change difficulty while in combat.|r")
        return
      end
      if playerLevel > 10 and not IsResting() then
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cffFF0000[Hardcore] You must be level 10 or below, or rested (in an inn or capital city) to change difficulty.|r")
        return
      end
      local svc = ProjectEbonhold.HardmodeService
      local curTier = svc and svc.GetCurrentDifficulty() or 1
      if selectedTier ~= curTier then
        ShowConfirmationPopup(selectedTier)
      end
    end,
    120, 30)
  applyBtn:SetPoint("TOP", slider, "BOTTOM", 0, -4)

  -- Disable Apply if already at the current tier
  hardmodeFrame.applyBtn = applyBtn

  -- Hint shown when Apply is hidden (not in a rested area)
  local applyHint = topBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  applyHint:SetPoint("TOP", slider, "BOTTOM", 0, -6)
  applyHint:SetWidth(280)
  applyHint:SetJustifyH("CENTER")
  applyHint:SetWordWrap(true)
  applyHint:SetText("|cffFF6666You must be level 10, rested (inn or capital city), and not in combat to change difficulty.|r")
  hardmodeFrame.applyHint = applyHint

  if not CanApply() then
    applyBtn:Hide()
    applyHint:Show()
  else
    applyHint:Hide()
    if selectedTier == currentTier then
      applyBtn:Disable()
    end
  end
  BuildInfoSections(canvas, GetTierDisplayData(currentTier), INFO_SECTIONS_Y)
end

local function CreateHardmodeFrame()
  hardmodeFrame = CreateFrame("Frame", "HardmodeFrame", UIParent)
  hardmodeFrame:SetSize(PANEL_WIDTH, PANEL_MIN_H)
  hardmodeFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  hardmodeFrame:SetFrameStrata("HIGH")

  local bgTexture = hardmodeFrame:CreateTexture(nil, "BACKGROUND")
  bgTexture:SetTexture("Interface\\AddOns\\ProjectEbonhold\\assets\\background-torment")
  bgTexture:SetAllPoints(hardmodeFrame)
  bgTexture:SetTexCoord(0, 0.84375, 0, 0.70703125)

  hardmodeFrame:SetMovable(true)
  hardmodeFrame:EnableMouse(true)
  hardmodeFrame:RegisterForDrag("LeftButton")
  hardmodeFrame:SetScript("OnDragStart", hardmodeFrame.StartMoving)
  hardmodeFrame:SetScript("OnDragStop", hardmodeFrame.StopMovingOrSizing)

  local closeBtn = CreateFrame("Button", nil, hardmodeFrame, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", hardmodeFrame, "TOPRIGHT", -10, -10)

  -- Help "?" button (top-left)
  local helpBtn = CreateFrame("Button", nil, hardmodeFrame)
  helpBtn:SetSize(22, 22)
  helpBtn:SetPoint("TOPLEFT", hardmodeFrame, "TOPLEFT", 16, -14)
  helpBtn:SetFrameLevel(hardmodeFrame:GetFrameLevel() + 5)

  local helpText = helpBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  helpText:SetPoint("CENTER", helpBtn, "CENTER", 0, 0)
  helpText:SetText("|cffFFD100?|r")
  helpText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")

  helpBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  helpBtn:SetScript("OnClick", function()
    ShowTutorial()
  end)
  helpBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Help", 1, 0.82, 0)
    GameTooltip:AddLine("Click to view the Hardcore tutorial.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  helpBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local canvas = CreateFrame("Frame", "HardmodeCanvas", hardmodeFrame)
  canvas:SetPoint("TOPLEFT", hardmodeFrame, "TOPLEFT", 10, -42)
  canvas:SetPoint("TOPRIGHT", hardmodeFrame, "TOPRIGHT", -10, -42)
  canvas:SetHeight(800)

  hardmodeFrame.canvas = canvas
  hardmodeFrame:Hide()

  table.insert(UISpecialFrames, "HardmodeFrame")
end

function ProjectEbonhold.HardmodeUI.Refresh()
  if not hardmodeFrame then return end
  if not hardmodeFrame:IsShown() then return end

  local svc = ProjectEbonhold.HardmodeService
  local tier = svc and svc.GetCurrentDifficulty() or 1
  BuildContent(hardmodeFrame.canvas, tier)
end

function Addon.ToggleHardmodeFrame()
  if not hardmodeFrame then
    CreateHardmodeFrame()
  end

  if hardmodeFrame:IsShown() then
    hardmodeFrame:Hide()
  else
    -- Ask server for current tier
    if ProjectEbonhold.HardmodeService then
      ProjectEbonhold.HardmodeService.RequestHardmodeData()
    end
    hardmodeFrame:Show()

    local svc = ProjectEbonhold.HardmodeService
    local tier = svc and svc.GetCurrentDifficulty() or 1
    BuildContent(hardmodeFrame.canvas, tier)

    -- First-time tutorial
    if not HasSeenTutorial() then
      ShowTutorial()
    end
  end
end

Addon.ToggleTormentFrame = Addon.ToggleHardmodeFrame
print("|cffFFD100Hardcore Difficulty loaded! Type /hardmode to open.|r")
