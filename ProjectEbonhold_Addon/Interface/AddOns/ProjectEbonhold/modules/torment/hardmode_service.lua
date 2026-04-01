local addonName, addon = ...

------------------------------------------------------------

local HardmodeService = {}
ProjectEbonhold.HardmodeService = HardmodeService

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local currentDifficulty = 1   -- 1 = Normal, 2-4 = Hardmode tiers
ProjectEbonhold.currentHardmodeTier = currentDifficulty

------------------------------------------------------------
-- REWARDS TABLE
------------------------------------------------------------

-- Indexed by difficulty tier (1 = Normal, 2-5 = Hardmode tiers)
local HARDMODE_REWARDS = {
  -- [difficulty] = { context_type, gold_multiplier, extra_loot_chance, extra_loot_count, quest_xp_multiplier, creature_xp_multiplier, soul_ash_multiplier, reagent_multiplier }
  [1] = { context_type = 0, gold_multiplier = 1,    extra_loot_chance = 0,  extra_loot_count = 1, quest_xp_multiplier = 1,    creature_xp_multiplier = 1,    soul_ash_multiplier = 1,    reagent_multiplier = 1    },
  [2] = { context_type = 0, gold_multiplier = 1.25, extra_loot_chance = 5,  extra_loot_count = 1, quest_xp_multiplier = 1.25, creature_xp_multiplier = 1.15, soul_ash_multiplier = 1.25, reagent_multiplier = 1.25 },
  [3] = { context_type = 0, gold_multiplier = 1.5,  extra_loot_chance = 10, extra_loot_count = 1, quest_xp_multiplier = 1.5,  creature_xp_multiplier = 1.3,  soul_ash_multiplier = 1.5,  reagent_multiplier = 1.5  },
  [4] = { context_type = 0, gold_multiplier = 2,    extra_loot_chance = 15, extra_loot_count = 2, quest_xp_multiplier = 2,    creature_xp_multiplier = 1.75, soul_ash_multiplier = 2,    reagent_multiplier = 1.75 },
}
HardmodeService.HARDMODE_REWARDS = HARDMODE_REWARDS

------------------------------------------------------------
-- ACCESSORS
------------------------------------------------------------

function HardmodeService.GetCurrentDifficulty()
  return currentDifficulty
end

function HardmodeService.IsHardmodeActive()
  return currentDifficulty > 1
end

--- Returns the reward multipliers for the given difficulty tier (defaults to current)
function HardmodeService.GetRewardsForDifficulty(tier)
  tier = tier or currentDifficulty
  return HARDMODE_REWARDS[tier] or HARDMODE_REWARDS[1]
end

------------------------------------------------------------
-- CLIENT → SERVER
------------------------------------------------------------

--- Ask the server what tier the player is on
function HardmodeService.RequestHardmodeData()
  ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_HARDMODE_DATA, "")
end

--- Tell the server to change difficulty (1 = Normal)
function HardmodeService.SetDifficulty(tier)
  tier = math.max(1, math.min(tier, 4))
  ProjectEbonhold.sendToServer(
    ProjectEbonhold.CS.REQUEST_HARDMODE_SET_DIFFICULTY,
    tostring(tier)
  )
end

------------------------------------------------------------
-- SERVER → CLIENT
------------------------------------------------------------

--- Server sends back the current tier (just a number)
ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_HARDMODE_DATA,
  function(body)
    if not body or body == "" then return end
    currentDifficulty = tonumber(body) or 1
    ProjectEbonhold.currentHardmodeTier = currentDifficulty

    -- Notify UI
    if ProjectEbonhold.HardmodeUI and ProjectEbonhold.HardmodeUI.Refresh then
      ProjectEbonhold.HardmodeUI.Refresh()
    end
    -- Refresh intensity icons (6th icon depends on hardmode)
    if ProjectEbonhold.PlayerRunUI and ProjectEbonhold.PlayerRunUI.UpdateIntensity then
      local intensityData = _G["EbonholdIntensityData"] or { intensity = 0 }
      ProjectEbonhold.PlayerRunUI.UpdateIntensity(intensityData)
    end
    -- Refresh death frame buttons so revive options reflect new difficulty
    if UnitIsDead("player") and UpdateDeathFrameButtons then
      UpdateDeathFrameButtons()
    end
  end
)

--- Result of a set-difficulty request: "OK,<tier>" or "FAIL,<reason>"
ProjectEbonhold.onEventReceived(ProjectEbonhold.SS.SEND_HARDMODE_SET_RESULT,
  function(body)
    if not body or body == "" then return end

    local status, payload = body:match("^(%a+),(.+)$")
    if status == "OK" then
      local newTier = tonumber(payload) or 1
      currentDifficulty = newTier
      ProjectEbonhold.currentHardmodeTier = newTier

      if newTier == 1 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF00[Hardmode] Returned to Normal difficulty.|r")
      else
        DEFAULT_CHAT_FRAME:AddMessage(
          "|cff00FF00[Hardmode] Difficulty set to Tier " .. newTier .. ".|r"
        )
      end
    else
      DEFAULT_CHAT_FRAME:AddMessage(
        "|cffFF0000[Hardmode] Failed to change difficulty: " .. tostring(payload) .. "|r"
      )
    end

    -- Notify UI
    if ProjectEbonhold.HardmodeUI and ProjectEbonhold.HardmodeUI.Refresh then
      ProjectEbonhold.HardmodeUI.Refresh()
    end
    -- Refresh intensity icons (6th icon depends on hardmode)
    if ProjectEbonhold.PlayerRunUI and ProjectEbonhold.PlayerRunUI.UpdateIntensity then
      local intensityData = _G["EbonholdIntensityData"] or { intensity = 0 }
      ProjectEbonhold.PlayerRunUI.UpdateIntensity(intensityData)
    end
    -- Refresh death frame buttons so revive options reflect new difficulty
    if UnitIsDead("player") and UpdateDeathFrameButtons then
      UpdateDeathFrameButtons()
    end
  end
)

------------------------------------------------------------
-- AUTO-REQUEST ON LOGIN
------------------------------------------------------------

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:SetScript("OnEvent", function(self, event)
  HardmodeService.RequestHardmodeData()
end)
