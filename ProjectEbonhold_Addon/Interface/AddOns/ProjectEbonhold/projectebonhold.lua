local ADDON_NAME = "ProjectEbonhold"
local PREFIX = "AAM0x9"

local addonName, addon = ...
addon.version = 26;
if not addon then addon = {} end

local CS = {
    SEND_HI                                   = 0,
    REQUEST_SHOP_DATA                         = 1,
    REQUEST_SHOP_PURCHASE                     = 2,
    REQUEST_ACCOUNT_DP                        = 3,
    REQUEST_SELL_JUNK_ITEMS                   = 4,
    REQUEST_LOADOUTS                          = 5,
    REQUEST_CREATE_LOADOUT                    = 7,
    REQUEST_LOADOUT_DELETE                    = 9,
    REQUEST_LOADOUT_SELECT                    = 10,
    REQUEST_AVOID_RESET_WITH_SOUL_POINTS      = 12,
    REQUEST_AVOID_RESET_WITH_SELF_REZ         = 13,
    REQUEST_PLAYER_RUN_DATA                   = 14,
    REQUEST_PLAYER_SOUL_POINTS_ADDITIONAL_PCT = 15,
    REQUEST_PLAYER_PERK_CHOICE                = 16,
    REQUEST_PLAYER_PERK_SELECTION             = 17,
    REQUEST_PLAYER_GRANTED_PERKS              = 18,
    REQUEST_PLAYER_ADD_ITEM_ITEM_SAVED        = 19,
    REQUEST_PLAYER_ITEMS_SAVED                = 20,
    REQUEST_INTENSITY_POINTS                  = 22,
    REQUEST_APPLY_SPECS                       = 23,
    REQUEST_CURRENT_SPEC                      = 24,
    REQUEST_RESET_TALENT_TREE                 = 25,
    REQUEST_ACCEPT_DEATH                      = 26,
    REQUEST_REROLL                            = 27,
    REQUEST_LOADOUT_UPDATE                    = 28,
    REQUEST_VERSION_CHECK                     = 29,
    REQUEST_LOCK_PERK                         = 30,
    REQUEST_UNLOCK_PERK                       = 31,
    REQUEST_ACCEPT_HIGHER_INTENSITY           = 32,
    REQUEST_SET_USING_VOID_STORAGE            = 50,
    REQUEST_RETRIEVE_VOID_STORAGE_ITEM        = 51,
    REQUEST_RETRIEVE_ITEMS_FROM_TAB           = 52,
    REQUEST_OBJECTIVES_PROPOSALS              = 200,
    REQUEST_SELECT_OBJECTIVE                  = 201,
    REQUEST_UNLOCK_PLAYER                     = 202,
    REQUEST_BANISH_PERK                       = 203,
    REQUEST_DEV_ADD_PERK_STACK                = 204,
    REQUEST_DEV_REMOVE_PERK_STACK             = 205,
    REQUEST_REROLL_OBJECTIVES                 = 206,

    REQUEST_HARDMODE_DATA                     = 300,
    REQUEST_HARDMODE_SET_DIFFICULTY           = 301,
    -- Extraction Events
    REQUEST_AFFIX_EXTRACTION                  = 310,
    REQUEST_AFFIX_EXTRACTION_INFO             = 311,
    REQUEST_AFFIX_APPLY                       = 312,
    REQUEST_LEARNED_AFFIXES                   = 313,
    REQUEST_AFFIX_APPLY_INFO                  = 314,

    REQUEST_UNLEARN_SPELL_ECHOES              = 315,

    REQUEST_ACTION_TRACKER_INFO               = 600,
    REQUEST_INSTANCE_RESET_ALL                = 601,
}

local SS = {
    SEND_ACKNOWLEDGEMENT                      = 0,
    SEND_SHOP_DATA                            = 1,
    SEND_ACCOUNT_DP                           = 2,
    SEND_LOADOUTS                             = 3,
    SEND_CREATED_LOADOUT                      = 4,
    SEND_UPDATED_LOADOUT                      = 5,

    SEND_SKILL_TREE_UPDATE_SPELL_CAST_RESULT  = 6,
    SEND_INSTANCE_ENTERED                     = 9,
    SEND_INSTANCE_ENCOUNTERS_COMPLETED        = 10,
    SEND_INSTANCE_ENCOUNTERS_HIDE             = 11,
    SEND_JUNK_SOLD                            = 12,
    SEND_PLAYER_RUN_DATA                      = 13,
    SEND_PLAYER_SOUL_POINTS_MULTIPLIER        = 14,
    SEND_PLAYER_UPDATED_COMMITTED_SOUL_POINTS = 15,
    SEND_PLAYER_PERK_CHOICE                   = 16,
    SEND_PLAYER_PERK_SELECTION_RESULT         = 17,
    SEND_PLAYER_PERK_GRANTED                  = 18,
    SEND_PLAYER_ITEMS_SAVED                   = 21,
    SEND_PLAYER_INTENSITY_POINTS              = 30,
    SEND_PLAYER_LEARNED_SPELL_ON_LEVEL_UP     = 31,
    SEND_PLAYER_SPEC_INDEX                    = 32,
    SEND_WRONG_PATCH                          = 33,
    SEND_CONTENT_VOID_STORAGE                 = 100,
    SEND_OBJECTIVES_PROPOSALS                 = 101,
    SEND_CURRENT_OBJECTIVE                    = 102,
    SEND_BANISH_REPLACEMENT_PERK              = 103,
    SEND_HARDMODE_DATA                        = 500,
    SEND_HARDMODE_SET_RESULT                  = 501,

    -- Extraction Events
    SEND_AFFIX_EXTRACTION_RESULT              = 510,
    SEND_AFFIX_EXTRACTION_INFO                = 511,
    SEND_AFFIX_APPLY_RESULT                   = 512,
    SEND_LEARNED_AFFIXES                      = 513,
    SEND_AFFIX_APPLY_INFO                     = 514,

    SEND_UNLEARN_SPELL_RESULT                 = 515,

    SEND_ACTION_TRACKER_INFO                  = 700,
    SEND_INSTANCE_RESET_RESULT                = 701,
    SEND_PLAYER_IS_BLOCKED                    = 900,
}

local ServerHandlers = {}
local function onEventReceived(id, fn) ServerHandlers[id] = fn end

local function sendToServer(id, body)
    local me = UnitName("player")
    local payload = tostring(id)
    if body and body ~= "" then payload = payload .. "\t" .. body end

    local MAX_PAYLOAD_SIZE = 240

    if string.len(payload) <= MAX_PAYLOAD_SIZE then
        SendAddonMessage(PREFIX, payload, "WHISPER", me)
    else
        local bodyToChunk = body or ""
        local chunks = {}
        local MAX_CHUNK_SIZE = 180

        local pos = 1

        while pos <= string.len(bodyToChunk) do
            local chunk = string.sub(bodyToChunk, pos, pos + MAX_CHUNK_SIZE - 1)
            table.insert(chunks, chunk)
            pos = pos + MAX_CHUNK_SIZE
        end

        local mid = string.format("%04X", math.random(0, 65535))
        local total = #chunks

        for idx, chunk in ipairs(chunks) do
            local chunkPayload = string.format("%s\t@%s\t%03X/%03X\t%s",
                tostring(id), mid, idx, total, chunk)
            SendAddonMessage(PREFIX, chunkPayload, "WHISPER", me)
        end
    end
end

CharacterAmmoSlot:SetScript("OnShow", function() CharacterAmmoSlot:Hide() end)
SetCVar("UberTooltips", 1)

local inflight = {}

local function now() return GetTime() end
local function cleanupExpired()
    local t = now()
    for k, v in pairs(inflight) do
        if t - (v.t0 or t) > 15 then inflight[k] = nil end
    end
end

local function dispatch(prefix, payload, dist, sender)
    if prefix ~= PREFIX then return end
    local evtStr, rest = payload:match("^(%d+)\t(.*)$")
    if not evtStr then return end -- silently dropped!
    local evt = tonumber(evtStr, 10)


    local mid, idx, tot, slice = rest:match(
        "^@([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])\t([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])/([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])\t(.*)$")
    if mid then
        local key = evt .. ":" .. mid
        local rec = inflight[key]
        if not rec then
            rec = { total = tonumber(tot, 16), got = 0, parts = {}, t0 = now() }
            inflight[key] = rec
        end
        local i = tonumber(idx, 16)
        if i >= 1 and i <= rec.total and not rec.parts[i] then
            rec.parts[i] = slice
            rec.got = rec.got + 1
        end
        if rec.got == rec.total then
            local out = table.concat(rec.parts, "", 1, rec.total)
            inflight[key] = nil
            local handler = ServerHandlers[evt]
            if handler then
                local ok, err = pcall(handler, out, dist, sender, evt)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cffff0000[ProjectEbonhold] handler error:|r " ..
                        tostring(err))
                end
            end
        end
        cleanupExpired()
        return
    end


    local handler = ServerHandlers[evt]
    if handler then
        local ok, err = pcall(handler, rest, dist, sender, evt)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffff0000[ProjectEbonhold] handler error:|r " .. tostring(err))
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEVEL_UP")

f:SetScript("OnEvent", function(_, e, ...)
    if e == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            if RegisterAddonMessagePrefix then
                RegisterAddonMessagePrefix(PREFIX)
            end
        end
    elseif e == "CHAT_MSG_ADDON" then
        local prefix, payload, dist, sender = ...

        if not payload or payload == "" then
            return
        end
        dispatch(prefix, payload, dist, sender)
    elseif e == "PLAYER_ENTERING_WORLD" then
    elseif e == "PLAYER_LEVEL_UP" then
    end
end)


ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.SS = SS
ProjectEbonhold.CS = CS
ProjectEbonhold.onEventReceived = onEventReceived
ProjectEbonhold.sendToServer = sendToServer

function TargetFrame_CheckClassification(self, forceNormalTexture)
    local texture;
    local classification = UnitClassification(self.unit);
    local intensityData = _G["EbonholdIntensityData"] or {}
    local intensityLevel = intensityData.intensity or 0

    if intensityLevel >= ProjectEbonhold.Constants.INTENSITY_LEVEL_3 then
        texture = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite"
    end

    if (classification == "worldboss" or classification == "elite") then
        texture = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite";
    elseif (classification == "rareelite") then
        texture = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare-Elite";
    elseif (classification == "rare") then
        texture = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare";
    end
    if (texture and not forceNormalTexture) then
        self.borderTexture:SetTexture(texture);
        self.haveElite = true;
        if (self.threatIndicator) then
            self.threatIndicator:SetTexCoord(0, 0.9453125, 0.181640625, 0.400390625);
            self.threatIndicator:SetWidth(242);
            self.threatIndicator:SetHeight(112);
            self.threatIndicator:SetPoint("TOPLEFT", self, "TOPLEFT", -22, 9);
        end
    else
        self.borderTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame");
        self.haveElite = nil;
        if (self.threatIndicator) then
            self.threatIndicator:SetTexCoord(0, 0.9453125, 0, 0.181640625);
            self.threatIndicator:SetWidth(242);
            self.threatIndicator:SetHeight(93);
            self.threatIndicator:SetPoint("TOPLEFT", self, "TOPLEFT", -24, 0);
        end
    end
end
