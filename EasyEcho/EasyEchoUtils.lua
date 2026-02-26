-- EasyEchoUtils.lua
-- Shared utilities, constants, and helpers for EasyEcho
-- Must be loaded FIRST in the TOC (before all other EasyEcho files)

EasyEcho = EasyEcho or {}

-- =========================================================
-- QUALITY TABLES (single source of truth)
-- =========================================================
EasyEcho.QUALITY_NAMES = {
    [0] = "Common",
    [1] = "Uncommon",
    [2] = "Rare",
    [3] = "Epic",
    [4] = "Legendary"
}

EasyEcho.QUALITY_COLORS = {
    [0] = "ffffffff",
    [1] = "ff1eff00",
    [2] = "ff0070dd",
    [3] = "ffa335ee",
    [4] = "ffff8000"
}

-- =========================================================
-- CASE-INSENSITIVE SEARCH
-- =========================================================
-- Returns true if `needle` is found in `haystack` (plain text, case-insensitive).
function EasyEcho.CaseFind(haystack, needle)
    if not haystack or not needle or needle == "" then return false end
    return string.lower(haystack):find(string.lower(needle), 1, true) ~= nil
end

-- =========================================================
-- PRIORITY RANK LOOKUP (shared by Engine + UI)
-- =========================================================
-- Returns the 1-based index of `name::quality` (or `name::Any`) in the
-- active priority list, or 99999 if not found.
function EasyEcho.GetPriorityRank(name, quality)
    if not name then return 99999 end
    local list = EasyEchoSettings and EasyEchoSettings.PriorityList or EasyEcho_PrioList
    if not list then return 99999 end
    local specKey = string.lower(name .. "::" .. (EasyEcho.QUALITY_NAMES[quality] or "Common"))
    local anyKey  = string.lower(name .. "::Any")
    for i, listKey in ipairs(list) do
        local low = string.lower(listKey)
        if low == specKey or low == anyKey then return i end
    end
    return 99999
end

-- =========================================================
-- BANISH LIST INITIALIZATION
-- =========================================================
function EasyEcho.EnsureBanishList()
    if not EasyEchoSettings then EasyEchoSettings = {} end
    if not EasyEchoSettings.BanishList then EasyEchoSettings.BanishList = {} end
    return EasyEchoSettings.BanishList
end

-- =========================================================
-- PROFILE LIST ASSIGNMENT
-- =========================================================
-- Copies the given profile's lists into the top-level settings references.
function EasyEcho.ApplyProfileLists(profileName)
    if not EasyEchoSettings or not EasyEchoSettings.Profiles then return end
    local profile = EasyEchoSettings.Profiles[profileName]
    if not profile then return end
    EasyEchoSettings.PriorityList = profile.PriorityList
    EasyEchoSettings.BanList      = profile.BanList or {}
    EasyEchoSettings.BanishList   = profile.BanishList or {}
    EasyEcho_PrioList             = EasyEchoSettings.PriorityList
end

-- =========================================================
-- ECHO SORT COMPARATOR (shared by DB view + Granted view)
-- =========================================================
-- Sorts a list of echo entries in-place by the given mode.
-- Each entry must have: .name, .quality, .prioRank
-- Optional fields used by specific modes: .maxStack, .count
function EasyEcho.SortEchoes(entries, sortMode)
    table.sort(entries, function(a, b)
        if sortMode == "name" then
            local aLow, bLow = string.lower(a.name), string.lower(b.name)
            if aLow ~= bLow then return aLow < bLow end
            return a.quality > b.quality
        elseif sortMode == "maxstack" then
            if (a.maxStack or 1) ~= (b.maxStack or 1) then return (a.maxStack or 1) > (b.maxStack or 1) end
            if a.quality ~= b.quality then return a.quality > b.quality end
            return string.lower(a.name) < string.lower(b.name)
        elseif sortMode == "count" then
            if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
            if a.quality ~= b.quality then return a.quality > b.quality end
            return string.lower(a.name) < string.lower(b.name)
        elseif sortMode == "prio" then
            if a.prioRank ~= b.prioRank then return a.prioRank < b.prioRank end
            if a.quality ~= b.quality then return a.quality > b.quality end
            return string.lower(a.name) < string.lower(b.name)
        else -- rarity (default)
            if a.quality ~= b.quality then return a.quality > b.quality end
            return string.lower(a.name) < string.lower(b.name)
        end
    end)
end
