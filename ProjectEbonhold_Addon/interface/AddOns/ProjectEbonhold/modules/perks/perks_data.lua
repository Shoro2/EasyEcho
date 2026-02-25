-- Perk Database
-- This file contains all available perks in the game
-- Auto-generated from world.perks table
-- Last updated: 2026-02-23

local addonName, addon = ...

ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.PerkDatabase = {
    -- Structure:
    -- [spellId] = {
    --     maxStack = number,      -- Maximum stack count for this perk
    --     classMask = number,     -- Class restriction bitmask (1535 = all classes, 0 = none)
    --     minLevel = number,      -- Minimum level requirement
    --     quality = number,       -- 0=Common, 1=Uncommon, 2=Rare, 3=Epic, 4=Legendary
    --     groupId = number|nil,   -- Perk group ID (for mutually exclusive perks)
    --     requiredSpell = number, -- Required spell ID (0 = none)
    --     comment = string|nil    -- Developer comment/description
    -- }
    
    [200000] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 0, groupId = 97, requiredSpell = 0, comment = "Strength Training" },
    [200001] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 2, requiredSpell = 0, comment = "Agility Boost" },
    [200002] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 0, groupId = 56, requiredSpell = 0, comment = "Mind Expansion" },
    [200003] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 0, groupId = 88, requiredSpell = 0, comment = "Spiritual Fortitude" },
    [200004] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 52, requiredSpell = 0, comment = "Iron Constitution" },
    [200005] = { maxStack = 80, classMask = 1535, minLevel = 20, quality = 0, groupId = 16, requiredSpell = 0, comment = "Cavalry Instincts" },
    [200006] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 0, groupId = 54, requiredSpell = 0, comment = "Mana Regeneration" },
    [200007] = { maxStack = 80, classMask = 3, minLevel = 1, quality = 0, groupId = 72, requiredSpell = 0, comment = "Reinforced Shielding" },
    [200008] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 58, requiredSpell = 0, comment = "Mystic Potency" },
    [200009] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 13, requiredSpell = 0, comment = "Brutal Might" },
    [200010] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 26, requiredSpell = 0, comment = "Earthen Stability" },
    [200013] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 30, requiredSpell = 0, comment = "Ember Spark" },
    [200016] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 107, requiredSpell = 0, comment = "Warm-Blooded" },
    [200017] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 47, requiredSpell = 0, comment = "Hardened Skin" },
    [200018] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 46, requiredSpell = 0, comment = "Hardened Resolve" },
    [200019] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 101, requiredSpell = 0, comment = "Swift Step" },
    [200029] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 50, requiredSpell = 0, comment = "Immolation Aura - Common" },
    [200031] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 89, requiredSpell = 0, comment = "Spiteful Thorns - Common" },
    [200036] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 31, requiredSpell = 9, comment = "Ember Ward - Common" },
    [200037] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 42, requiredSpell = 9, comment = "Frost Ward - Common" },
    [200038] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 105, requiredSpell = 9, comment = "Verdant Ward - Common" },
    [200039] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 5, requiredSpell = 9, comment = "Arcane Ward - Common" },
    [200040] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 83, requiredSpell = 9, comment = "Shadow Ward - Common" },
    [200042] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 44, requiredSpell = 0, comment = "Rend the Weak" },
    [200300] = { maxStack = 80, classMask = 1, minLevel = 1, quality = 0, groupId = 74, requiredSpell = 0, comment = "Rite of Quickening" },
    [200301] = { maxStack = 80, classMask = 256, minLevel = 1, quality = 0, groupId = 27, requiredSpell = 0, comment = "Echoes of Celerity" },
    [200302] = { maxStack = 80, classMask = 64, minLevel = 1, quality = 0, groupId = 37, requiredSpell = 0, comment = "Flow of Battle" },
    [200303] = { maxStack = 80, classMask = 8, minLevel = 1, quality = 0, groupId = 67, requiredSpell = 0, comment = "Pulse of Renewal" },
    [200304] = { maxStack = 80, classMask = 16, minLevel = 1, quality = 0, groupId = 57, requiredSpell = 0, comment = "Momentum Chant" },
    [200305] = { maxStack = 80, classMask = 2, minLevel = 1, quality = 0, groupId = 1, requiredSpell = 0, comment = "Accelerated Spirit" },
    [200306] = { maxStack = 80, classMask = 128, minLevel = 1, quality = 0, groupId = 102, requiredSpell = 0, comment = "Tempo Weave" },
    [200307] = { maxStack = 80, classMask = 4, minLevel = 1, quality = 0, groupId = 73, requiredSpell = 0, comment = "Rhythm of Power" },
    [200308] = { maxStack = 80, classMask = 1024, minLevel = 1, quality = 0, groupId = 60, requiredSpell = 0, comment = "Nature Quickness" },
    [200309] = { maxStack = 80, classMask = 32, minLevel = 1, quality = 0, groupId = 20, requiredSpell = 0, comment = "Cyclebreaker’s Sigil " },
    [200414] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 0, groupId = 39, requiredSpell = 0, comment = "Forged in Combat" },
    [200421] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 61, requiredSpell = 0, comment = "Open Wounds - Common" },
    [200427] = { maxStack = 80, classMask = 1067, minLevel = 1, quality = 0, groupId = 71, requiredSpell = 0, comment = "Reactive Retaliation - Common" },
    [200429] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 53, requiredSpell = 0, comment = "Keen Aim" },
    [200430] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 19, requiredSpell = 0, comment = "Crushing Force" },
    [200431] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 69, requiredSpell = 0, comment = "Quick Hands" },
    [200432] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 0, groupId = 6, requiredSpell = 0, comment = "Armor Penetration" },
    [200433] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 0, groupId = 34, requiredSpell = 0, comment = "Expertise Drills" },
    [200434] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 0, groupId = 55, requiredSpell = 0, comment = "Mana Reservoir" },
    [200435] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 84, requiredSpell = 0, comment = "Sharpened Edge" },
    [200441] = { maxStack = 80, classMask = 1432, minLevel = 1, quality = 0, groupId = 78, requiredSpell = 0, comment = "Safeguarded Gear" },
    [200442] = { maxStack = 20, classMask = 1494, minLevel = 1, quality = 0, groupId = 91, requiredSpell = 0, comment = "Steady Channeling" },
    [200541] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 108, requiredSpell = 9, comment = "Beast Bane - Common" },
    [200542] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 109, requiredSpell = 9, comment = "Dragonkin Bane - Common" },
    [200543] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 110, requiredSpell = 9, comment = "Demon Bane - Common" },
    [200544] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 111, requiredSpell = 9, comment = "Elemental Bane - Common" },
    [200545] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 112, requiredSpell = 9, comment = "Giant Bane - Common" },
    [200546] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 113, requiredSpell = 9, comment = "Undead Bane - Common" },
    [200547] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 114, requiredSpell = 9, comment = "Mechanical Bane - Common" },
    [200548] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 115, requiredSpell = 9, comment = "Beast Slayer - Common" },
    [200549] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 116, requiredSpell = 9, comment = "Dragon Slayer - Common" },
    [200550] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 117, requiredSpell = 9, comment = "Demon Slayer - Common" },
    [200551] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 118, requiredSpell = 9, comment = "Elemental Slayer - Common" },
    [200552] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 119, requiredSpell = 9, comment = "Giant Slayer - Common" },
    [200553] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 120, requiredSpell = 9, comment = "Undead Slayer - Common" },
    [200554] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 0, groupId = 121, requiredSpell = 9, comment = "Machine Slayer - Common" },
    [200648] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 139, requiredSpell = 0, comment = "Stonefist Barrage - Common" },
    [200653] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 140, requiredSpell = 0, comment = "Arcane Bombardment - Common" },
    [200657] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 141, requiredSpell = 0, comment = "Corrosive Breath - Common" },
    [200661] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 142, requiredSpell = 0, comment = "Spiteful Shard - Common" },
    [200665] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 143, requiredSpell = 0, comment = "Scorched Path - Common" },
    [200669] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 0, groupId = 144, requiredSpell = 0, comment = "Warded Aegis - Common" },
    [200699] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 0, groupId = 162, requiredSpell = 0, comment = "Scorching Wounds - Common" },
    [200703] = { maxStack = 80, classMask = 1488, minLevel = 1, quality = 0, groupId = 163, requiredSpell = 0, comment = "Reap the Weak - Common" },
    [200020] = { maxStack = 1, classMask = 1131, minLevel = 1, quality = 1, groupId = 8, requiredSpell = 0, comment = "Battle Momentum" },
    [200022] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 1, groupId = 25, requiredSpell = 300022, comment = "Earthen Snap - Uncommon" },
    [200025] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 1, groupId = 40, requiredSpell = 300025, comment = "Frost Bite - Uncommon" },
    [200027] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 1, groupId = 63, requiredSpell = 0, comment = "Pain Drive" },
    [200033] = { maxStack = 1, classMask = 1106, minLevel = 1, quality = 1, groupId = 68, requiredSpell = 0, comment = "Purifying Touch" },
    [200035] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 12, requiredSpell = 0, comment = "Bolstered Vitality" },
    [200041] = { maxStack = 15, classMask = 1535, minLevel = 1, quality = 1, groupId = 33, requiredSpell = 0, comment = "Enhanced Recovery" },
    [200046] = { maxStack = 80, classMask = 1106, minLevel = 1, quality = 1, groupId = 48, requiredSpell = 0, comment = "Healing Echo" },
    [200048] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 15, requiredSpell = 0, comment = "Burning Touch" },
    [200310] = { maxStack = 1, classMask = 1, minLevel = 1, quality = 1, groupId = 3, requiredSpell = 0, comment = "Anger Management" },
    [200313] = { maxStack = 1, classMask = 32, minLevel = 1, quality = 1, groupId = 22, requiredSpell = 0, comment = "Dirge" },
    [200314] = { maxStack = 80, classMask = 1032, minLevel = 1, quality = 1, groupId = 106, requiredSpell = 0, comment = "Vitality" },
    [200400] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 93, requiredSpell = 0, comment = "Steel Brand" },
    [200402] = { maxStack = 80, classMask = 18, minLevel = 1, quality = 1, groupId = 49, requiredSpell = 0, comment = "Holy Brand" },
    [200404] = { maxStack = 80, classMask = 452, minLevel = 1, quality = 1, groupId = 35, requiredSpell = 0, comment = "Fire Brand" },
    [200406] = { maxStack = 80, classMask = 1100, minLevel = 1, quality = 1, groupId = 59, requiredSpell = 0, comment = "Nature Brand" },
    [200408] = { maxStack = 80, classMask = 224, minLevel = 1, quality = 1, groupId = 41, requiredSpell = 0, comment = "Frost Brand" },
    [200410] = { maxStack = 80, classMask = 272, minLevel = 1, quality = 1, groupId = 82, requiredSpell = 0, comment = "Shadow Brand" },
    [200412] = { maxStack = 80, classMask = 1152, minLevel = 1, quality = 1, groupId = 4, requiredSpell = 0, comment = "Arcane Brand" },
    [200416] = { maxStack = 10, classMask = 4, minLevel = 1, quality = 1, groupId = 24, requiredSpell = 0, comment = "Double Tap" },
    [200418] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 1, groupId = 21, requiredSpell = 0, comment = "Desperate Escape" },
    [200423] = { maxStack = 1, classMask = 4, minLevel = 1, quality = 1, groupId = 11, requiredSpell = 0, comment = "Bola Shot" },
    [200436] = { maxStack = 15, classMask = 1535, minLevel = 1, quality = 1, groupId = 86, requiredSpell = 300436, comment = "Shielded Steps - Uncommon" },
    [200437] = { maxStack = 5, classMask = 1490, minLevel = 1, quality = 1, groupId = 90, requiredSpell = 300437, comment = "Steady Casting - Uncommon" },
    [200438] = { maxStack = 10, classMask = 1535, minLevel = 1, quality = 1, groupId = 98, requiredSpell = 300438, comment = "Subtle Presence - Uncommon" },
    [200439] = { maxStack = 80, classMask = 1059, minLevel = 1, quality = 1, groupId = 66, requiredSpell = 300439, comment = "Provoking Presence - Uncommon" },
    [200440] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 1, groupId = 29, requiredSpell = 0, comment = "Efficient Casting" },
    [200451] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 1, groupId = 97, requiredSpell = 0, comment = "Strength Training" },
    [200452] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 2, requiredSpell = 0, comment = "Agility Boost" },
    [200453] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 1, groupId = 56, requiredSpell = 0, comment = "Mind Expansion" },
    [200454] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 1, groupId = 88, requiredSpell = 0, comment = "Spiritual Fortitude" },
    [200455] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 52, requiredSpell = 0, comment = "Iron Constitution" },
    [200456] = { maxStack = 80, classMask = 1535, minLevel = 20, quality = 1, groupId = 16, requiredSpell = 0, comment = "Cavalry Instincts" },
    [200457] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 1, groupId = 54, requiredSpell = 0, comment = "Mana Regeneration" },
    [200458] = { maxStack = 80, classMask = 3, minLevel = 1, quality = 1, groupId = 72, requiredSpell = 0, comment = "Reinforced Shielding" },
    [200459] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 58, requiredSpell = 0, comment = "Mystic Potency" },
    [200460] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 13, requiredSpell = 0, comment = "Brutal Might" },
    [200461] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 26, requiredSpell = 0, comment = "Earthen Stability" },
    [200462] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 30, requiredSpell = 0, comment = "Ember Spark" },
    [200463] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 107, requiredSpell = 0, comment = "Warm-Blooded" },
    [200464] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 47, requiredSpell = 0, comment = "Hardened Skin" },
    [200465] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 46, requiredSpell = 0, comment = "Hardened Resolve" },
    [200466] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 101, requiredSpell = 0, comment = "Swift Step" },
    [200467] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 31, requiredSpell = 9, comment = "Ember Ward - Uncommon" },
    [200468] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 42, requiredSpell = 9, comment = "Frost Ward - Uncommon" },
    [200469] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 105, requiredSpell = 9, comment = "Verdant Ward - Uncommon" },
    [200470] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 5, requiredSpell = 9, comment = "Arcane Ward - Uncommon" },
    [200471] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 83, requiredSpell = 9, comment = "Shadow Ward - Uncommon" },
    [200479] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 1, groupId = 39, requiredSpell = 0, comment = "Forged in Combat" },
    [200480] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 53, requiredSpell = 0, comment = "Keen Aim" },
    [200481] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 19, requiredSpell = 0, comment = "Crushing Force" },
    [200482] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 69, requiredSpell = 0, comment = "Quick Hands" },
    [200483] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 1, groupId = 6, requiredSpell = 0, comment = "Armor Penetration" },
    [200484] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 1, groupId = 34, requiredSpell = 0, comment = "Expertise Drills" },
    [200485] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 1, groupId = 55, requiredSpell = 0, comment = "Mana Reservoir" },
    [200486] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 84, requiredSpell = 0, comment = "Sharpened Edge" },
    [200490] = { maxStack = 80, classMask = 1432, minLevel = 1, quality = 1, groupId = 78, requiredSpell = 0, comment = "Safeguarded Gear - Uncommon" },
    [200491] = { maxStack = 20, classMask = 1494, minLevel = 1, quality = 1, groupId = 91, requiredSpell = 0, comment = "Steady Channeling - Uncommon" },
    [200530] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 50, requiredSpell = 0, comment = "Immolation Aura - Uncommon" },
    [200531] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 89, requiredSpell = 0, comment = "Spiteful Thorns - Uncommon" },
    [200532] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 44, requiredSpell = 0, comment = "Rend the Weak - Uncommon" },
    [200533] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 61, requiredSpell = 0, comment = "Open Wounds - Uncommon" },
    [200534] = { maxStack = 80, classMask = 1067, minLevel = 1, quality = 1, groupId = 71, requiredSpell = 0, comment = "Reactive Retaliation - Uncommon" },
    [200555] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 108, requiredSpell = 9, comment = "Beast Bane - Uncommon" },
    [200556] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 109, requiredSpell = 9, comment = "Dragonkin Bane - Uncommon" },
    [200557] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 110, requiredSpell = 9, comment = "Demon Bane - Uncommon" },
    [200558] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 111, requiredSpell = 9, comment = "Elemental Bane - Uncommon" },
    [200559] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 112, requiredSpell = 9, comment = "Giant Bane - Uncommon" },
    [200560] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 113, requiredSpell = 9, comment = "Undead Bane - Uncommon" },
    [200561] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 114, requiredSpell = 9, comment = "Mechanical Bane - Uncommon" },
    [200562] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 115, requiredSpell = 9, comment = "Beast Slayer - Uncommon" },
    [200563] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 116, requiredSpell = 9, comment = "Dragon Slayer - Uncommon" },
    [200564] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 117, requiredSpell = 9, comment = "Demon Slayer - Uncommon" },
    [200565] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 118, requiredSpell = 9, comment = "Elemental Slayer - Uncommon" },
    [200566] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 119, requiredSpell = 9, comment = "Giant Slayer - Uncommon" },
    [200567] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 120, requiredSpell = 9, comment = "Undead Slayer - Uncommon" },
    [200568] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 1, groupId = 121, requiredSpell = 9, comment = "Machine Slayer - Uncommon" },
    [200649] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 139, requiredSpell = 0, comment = "Stonefist Barrage - Uncommon" },
    [200654] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 140, requiredSpell = 0, comment = "Arcane Bombardment - Uncommon" },
    [200658] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 141, requiredSpell = 0, comment = "Corrosive Breath - Uncommon" },
    [200662] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 142, requiredSpell = 0, comment = "Spiteful Shard - Uncommon" },
    [200666] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 143, requiredSpell = 0, comment = "Scorched Path - Uncommon" },
    [200670] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 1, groupId = 144, requiredSpell = 0, comment = "Warded Aegis - Uncommon" },
    [200672] = { maxStack = 10, classMask = 1131, minLevel = 1, quality = 1, groupId = 145, requiredSpell = 0, comment = "Double Strike - Uncommon" },
    [200700] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 1, groupId = 162, requiredSpell = 0, comment = "Scorching Wounds - Uncommon" },
    [200704] = { maxStack = 80, classMask = 1488, minLevel = 1, quality = 1, groupId = 163, requiredSpell = 0, comment = "Reap the Weak - Uncommon" },
    [200050] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 38, requiredSpell = 0, comment = "Focused Assault" },
    [200052] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 87, requiredSpell = 0, comment = "Spell Harmony" },
    [200063] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 17, requiredSpell = 0, comment = "Chaotic Convergence" },
    [200200] = { maxStack = 1, classMask = 1106, minLevel = 1, quality = 2, groupId = 23, requiredSpell = 0, comment = "Divine Resonance" },
    [200205] = { maxStack = 1, classMask = 448, minLevel = 1, quality = 2, groupId = 80, requiredSpell = 0, comment = "Scorched Sky" },
    [200209] = { maxStack = 1, classMask = 224, minLevel = 1, quality = 2, groupId = 85, requiredSpell = 0, comment = "Shattered Sky" },
    [200213] = { maxStack = 1, classMask = 1152, minLevel = 1, quality = 2, groupId = 75, requiredSpell = 0, comment = "Riven Sky" },
    [200216] = { maxStack = 1, classMask = 1088, minLevel = 1, quality = 2, groupId = 96, requiredSpell = 0, comment = "Stormtorn Sky" },
    [200220] = { maxStack = 1, classMask = 18, minLevel = 1, quality = 2, groupId = 79, requiredSpell = 0, comment = "Sanctified Sky" },
    [200224] = { maxStack = 1, classMask = 272, minLevel = 1, quality = 2, groupId = 9, requiredSpell = 0, comment = "Blighted Sky" },
    [200227] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 77, requiredSpell = 0, comment = "Ruthless Exploiter" },
    [200248] = { maxStack = 5, classMask = 1535, minLevel = 1, quality = 2, groupId = 62, requiredSpell = 0, comment = "Opening Split" },
    [200425] = { maxStack = 1, classMask = 1131, minLevel = 1, quality = 2, groupId = 100, requiredSpell = 0, comment = "Sweeping Blows" },
    [200443] = { maxStack = 5, classMask = 1535, minLevel = 1, quality = 2, groupId = 43, requiredSpell = 0, comment = "Frostguard Carapace" },
    [200446] = { maxStack = 10, classMask = 1535, minLevel = 1, quality = 2, groupId = 94, requiredSpell = 300446, comment = "Stoneskin Threads - Rare" },
    [200447] = { maxStack = 5, classMask = 1535, minLevel = 1, quality = 2, groupId = 99, requiredSpell = 300447, comment = "Sundered Will - Rare" },
    [200448] = { maxStack = 5, classMask = 1535, minLevel = 1, quality = 2, groupId = 92, requiredSpell = 300448, comment = "Steady Grip - Rare" },
    [200449] = { maxStack = 5, classMask = 1535, minLevel = 1, quality = 2, groupId = 76, requiredSpell = 300449, comment = "Rootbreaker - Rare" },
    [200450] = { maxStack = 5, classMask = 1535, minLevel = 1, quality = 2, groupId = 51, requiredSpell = 300450, comment = "Insulated Soul - Rare" },
    [200492] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 2, groupId = 97, requiredSpell = 0, comment = "Strength Training - Rare" },
    [200493] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 2, requiredSpell = 0, comment = "Agility Boost - Rare" },
    [200494] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 2, groupId = 56, requiredSpell = 0, comment = "Mind Expansion - Rare" },
    [200495] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 2, groupId = 88, requiredSpell = 0, comment = "Spiritual Fortitude - Rare" },
    [200496] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 52, requiredSpell = 0, comment = "Iron Constitution - Rare" },
    [200497] = { maxStack = 80, classMask = 1535, minLevel = 20, quality = 2, groupId = 16, requiredSpell = 0, comment = "Cavalry Instincts - Rare" },
    [200498] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 2, groupId = 54, requiredSpell = 0, comment = "Mana Regeneration - Rare" },
    [200499] = { maxStack = 80, classMask = 3, minLevel = 1, quality = 2, groupId = 72, requiredSpell = 0, comment = "Reinforced Shielding - Rare" },
    [200500] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 58, requiredSpell = 0, comment = "Mystic Potency - Rare" },
    [200501] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 13, requiredSpell = 0, comment = "Brutal Might - Rare" },
    [200502] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 26, requiredSpell = 0, comment = "Earthen Stability - Rare" },
    [200503] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 30, requiredSpell = 0, comment = "Ember Spark - Rare" },
    [200504] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 107, requiredSpell = 0, comment = "Warm-Blooded - Rare" },
    [200505] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 47, requiredSpell = 0, comment = "Hardened Skin - Rare" },
    [200506] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 46, requiredSpell = 0, comment = "Hardened Resolve - Rare" },
    [200507] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 101, requiredSpell = 0, comment = "Swift Step - Rare" },
    [200508] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 31, requiredSpell = 300508, comment = "Ember Ward - Rare" },
    [200509] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 42, requiredSpell = 300509, comment = "Frost Ward - Rare" },
    [200510] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 105, requiredSpell = 300510, comment = "Verdant Ward - Rare" },
    [200511] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 5, requiredSpell = 300511, comment = "Arcane Ward - Rare" },
    [200512] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 83, requiredSpell = 300512, comment = "Shadow Ward - Rare" },
    [200520] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 2, groupId = 39, requiredSpell = 0, comment = "Forged in Combat - Rare" },
    [200521] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 53, requiredSpell = 0, comment = "Keen Aim - Rare" },
    [200522] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 19, requiredSpell = 0, comment = "Crushing Force - Rare" },
    [200523] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 69, requiredSpell = 0, comment = "Quick Hands - Rare" },
    [200524] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 2, groupId = 6, requiredSpell = 0, comment = "Armor Penetration - Rare" },
    [200525] = { maxStack = 80, classMask = 1131, minLevel = 1, quality = 2, groupId = 34, requiredSpell = 0, comment = "Expertise Drills - Rare" },
    [200526] = { maxStack = 80, classMask = 1494, minLevel = 1, quality = 2, groupId = 55, requiredSpell = 0, comment = "Mana Reservoir - Rare" },
    [200527] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 84, requiredSpell = 0, comment = "Sharpened Edge - Rare" },
    [200528] = { maxStack = 80, classMask = 1432, minLevel = 1, quality = 2, groupId = 78, requiredSpell = 0, comment = "Safeguarded Gear - Rare" },
    [200529] = { maxStack = 20, classMask = 1494, minLevel = 1, quality = 2, groupId = 91, requiredSpell = 0, comment = "Steady Channeling - Rare" },
    [200536] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 50, requiredSpell = 0, comment = "Immolation Aura - Rare" },
    [200537] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 89, requiredSpell = 0, comment = "Spiteful Thorns - Rare" },
    [200538] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 44, requiredSpell = 0, comment = "Rend the Weak - Rare" },
    [200539] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 61, requiredSpell = 0, comment = "Open Wounds - Rare" },
    [200540] = { maxStack = 80, classMask = 1067, minLevel = 1, quality = 2, groupId = 71, requiredSpell = 0, comment = "Reactive Retaliation - Rare" },
    [200569] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 108, requiredSpell = 300569, comment = "Beast Bane - Rare" },
    [200570] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 109, requiredSpell = 300570, comment = "Dragonkin Bane - Rare" },
    [200571] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 110, requiredSpell = 300571, comment = "Demon Bane - Rare" },
    [200572] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 111, requiredSpell = 300572, comment = "Elemental Bane - Rare" },
    [200573] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 112, requiredSpell = 300573, comment = "Giant Bane - Rare" },
    [200574] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 113, requiredSpell = 300574, comment = "Undead Bane - Rare" },
    [200575] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 114, requiredSpell = 300575, comment = "Mechanical Bane - Rare" },
    [200576] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 115, requiredSpell = 300576, comment = "Beast Slayer - Rare" },
    [200577] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 116, requiredSpell = 300577, comment = "Dragon Slayer - Rare" },
    [200578] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 117, requiredSpell = 300578, comment = "Demon Slayer - Rare" },
    [200579] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 118, requiredSpell = 300579, comment = "Elemental Slayer - Rare" },
    [200580] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 119, requiredSpell = 300580, comment = "Giant Slayer - Rare" },
    [200581] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 120, requiredSpell = 300581, comment = "Undead Slayer - Rare" },
    [200582] = { maxStack = 80, classMask = 1135, minLevel = 1, quality = 2, groupId = 121, requiredSpell = 300582, comment = "Machine Slayer - Rare" },
    [200650] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 139, requiredSpell = 0, comment = "Stonefist Barrage - Rare" },
    [200655] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 140, requiredSpell = 0, comment = "Arcane Bombardment - Rare" },
    [200659] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 141, requiredSpell = 0, comment = "Corrosive Breath - Rare" },
    [200663] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 142, requiredSpell = 0, comment = "Spiteful Shard - Rare" },
    [200667] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 143, requiredSpell = 0, comment = "Scorched Path - Rare" },
    [200671] = { maxStack = 80, classMask = 1535, minLevel = 1, quality = 2, groupId = 144, requiredSpell = 0, comment = "Warded Aegis - Rare" },
    [200674] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 146, requiredSpell = 0, comment = "Glass Canon - Rare" },
    [200675] = { maxStack = 1, classMask = 1024, minLevel = 1, quality = 2, groupId = 147, requiredSpell = 0, comment = "Arcane Rupture - Rare" },
    [200676] = { maxStack = 1, classMask = 308, minLevel = 1, quality = 2, groupId = 148, requiredSpell = 0, comment = "Shadow Malice - Rare" },
    [200677] = { maxStack = 1, classMask = 18, minLevel = 1, quality = 2, groupId = 149, requiredSpell = 0, comment = "Holy Revelation - Rare" },
    [200678] = { maxStack = 1, classMask = 452, minLevel = 1, quality = 2, groupId = 150, requiredSpell = 0, comment = "Burning Cataclysm - Rare" },
    [200679] = { maxStack = 1, classMask = 160, minLevel = 1, quality = 2, groupId = 151, requiredSpell = 0, comment = "Killing Chill - Rare" },
    [200680] = { maxStack = 1, classMask = 1036, minLevel = 1, quality = 2, groupId = 152, requiredSpell = 0, comment = "Nature’s Reprisal - Rare" },
    [200681] = { maxStack = 1, classMask = 1032, minLevel = 1, quality = 2, groupId = 153, requiredSpell = 0, comment = "Blood Frenzy - Rare" },
    [200682] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 154, requiredSpell = 0, comment = "Grim Resolve - Rare" },
    [200684] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 155, requiredSpell = 0, comment = "Unbroken Focus - Rare" },
    [200686] = { maxStack = 1, classMask = 4, minLevel = 1, quality = 2, groupId = 156, requiredSpell = 0, comment = "Rapid Recalibration - Rare" },
    [200687] = { maxStack = 1, classMask = 1131, minLevel = 1, quality = 2, groupId = 157, requiredSpell = 0, comment = "Relentless Rhythm - Rare" },
    [200688] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 158, requiredSpell = 0, comment = "Rolling Momentum - Rare" },
    [200690] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 2, groupId = 159, requiredSpell = 300690, comment = "Reaper’s Reprieve - Rare" },
    [200701] = { maxStack = 80, classMask = 1490, minLevel = 1, quality = 2, groupId = 162, requiredSpell = 0, comment = "Scorching Wounds - Rare" },
    [200705] = { maxStack = 80, classMask = 1488, minLevel = 1, quality = 2, groupId = 163, requiredSpell = 0, comment = "Reap the Weak - Rare" },
    [200044] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 65, requiredSpell = 0, comment = "Precision Strike" },
    [200202] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 36, requiredSpell = 0, comment = "First Strike" },
    [200228] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 18, requiredSpell = 0, comment = "Chronoboost" },
    [200230] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 45, requiredSpell = 0, comment = "Harbringer of Doom" },
    [200231] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 7, requiredSpell = 0, comment = "Backstabber’s Edge" },
    [200232] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 95, requiredSpell = 0, comment = "Storm Conductor" },
    [200234] = { maxStack = 1, classMask = 1131, minLevel = 1, quality = 3, groupId = 81, requiredSpell = 0, comment = "Second Edge" },
    [200236] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 70, requiredSpell = 0, comment = "Quickening Aura" },
    [200237] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 103, requiredSpell = 0, comment = "Temporal Flow" },
    [200238] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 32, requiredSpell = 0, comment = "Energy Overflow" },
    [200240] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 64, requiredSpell = 0, comment = "Perfect Timing" },
    [200243] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 14, requiredSpell = 0, comment = "Burning Flames" },
    [200246] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 10, requiredSpell = 0, comment = "Blood Mirror" },
    [200259] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 104, requiredSpell = 0, comment = "Twin Casting" },
    [200270] = { maxStack = 1, classMask = 1405, minLevel = 1, quality = 3, groupId = 28, requiredSpell = 0, comment = "Echoing Afflictions" },
    [200583] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 122, requiredSpell = 300583, comment = "Crypt Lord’s Swarm - Epic" },
    [200585] = { maxStack = 1, classMask = 1100, minLevel = 1, quality = 3, groupId = 123, requiredSpell = 300585, comment = "Widow’s Venom - Epic" },
    [200589] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 124, requiredSpell = 300589, comment = "Broodmother’s Webbing - Epic" },
    [200592] = { maxStack = 1, classMask = 276, minLevel = 1, quality = 3, groupId = 125, requiredSpell = 300592, comment = "Curse of the Plaguebringer - Epic" },
    [200595] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 126, requiredSpell = 300595, comment = "The Unclean’s Fever - Epic" },
    [200597] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 127, requiredSpell = 300597, comment = "The Sporelord’s Gift - Epic" },
    [200599] = { maxStack = 1, classMask = 1127, minLevel = 1, quality = 3, groupId = 128, requiredSpell = 300599, comment = "Drillmaster’s Rebuke - Epic" },
    [200601] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 129, requiredSpell = 300601, comment = "The Harvester’s Tithe - Epic" },
    [200606] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 130, requiredSpell = 300606, comment = "Edict of the Four - Epic" },
    [200613] = { maxStack = 1, classMask = 1127, minLevel = 1, quality = 3, groupId = 131, requiredSpell = 300613, comment = "Stitched Fury - Epic" },
    [200615] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 132, requiredSpell = 300615, comment = "Mutagenic Fumes - Epic" },
    [200619] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 133, requiredSpell = 300619, comment = "Ravenous Bellow - Epic" },
    [200621] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 134, requiredSpell = 300621, comment = "Polarity Shift - Epic" },
    [200627] = { maxStack = 1, classMask = 224, minLevel = 1, quality = 3, groupId = 135, requiredSpell = 300627, comment = "Chill of the Bone Wyrm - Epic" },
    [200632] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 136, requiredSpell = 300632, comment = "Call of the Lich King - Epic" },
    [200635] = { maxStack = 1, classMask = 672, minLevel = 1, quality = 3, groupId = 137, requiredSpell = 300635, comment = "Cinders of the Sanctum - Epic" },
    [200639] = { maxStack = 1, classMask = 1152, minLevel = 1, quality = 3, groupId = 138, requiredSpell = 300639, comment = "Storm of the Spellweaver - Epic" },
    [200693] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 160, requiredSpell = 300693, comment = "Reaper’s Verdict - Epic" },
    [200695] = { maxStack = 1, classMask = 1535, minLevel = 1, quality = 3, groupId = 161, requiredSpell = 300695, comment = "Reaper’s Doom - Epic" },
}

-- Quality names for reference
ProjectEbonhold.PerkQualityNames = {
    [0] = "Common",
    [1] = "Uncommon", 
    [2] = "Rare",
    [3] = "Epic",
    [4] = "Legendary"
}

-- Class masks for reference
-- Use bitwise operations to check: band(perk.classMask, playerClassMask) > 0
ProjectEbonhold.PerkClassMasks = {
    WARRIOR     = 0x001,  -- 1
    PALADIN     = 0x002,  -- 2
    HUNTER      = 0x004,  -- 4
    ROGUE       = 0x008,  -- 8
    PRIEST      = 0x010,  -- 16
    DEATHKNIGHT = 0x020,  -- 32
    SHAMAN      = 0x040,  -- 64
    MAGE        = 0x080,  -- 128
    WARLOCK     = 0x100,  -- 256
    DRUID       = 0x200,  -- 1024
    ALL         = 1535    -- Sum of all classes (available to all)
}

-- Helper function: Get perk data by spell ID
function ProjectEbonhold.GetPerkData(spellId)
    return ProjectEbonhold.PerkDatabase[spellId]
end

-- Helper function: Check if perk is available for player's class
function ProjectEbonhold.IsPerkAvailableForClass(spellId, playerClassMask)
    local perk = ProjectEbonhold.PerkDatabase[spellId]
    if not perk then return false end
    if perk.classMask == 0 then return false end -- 0 = not available to anyone
    if perk.classMask == 1535 then return true end -- All classes
    return bit.band(perk.classMask, playerClassMask) > 0
end

-- Helper function: Check if player meets level requirement
function ProjectEbonhold.IsPerkAvailableForLevel(spellId, playerLevel)
    local perk = ProjectEbonhold.PerkDatabase[spellId]
    if not perk then return false end
    return playerLevel >= perk.minLevel
end

-- Helper function: Get all perks of a specific quality
function ProjectEbonhold.GetPerksByQuality(quality)
    local result = {}
    for spellId, data in pairs(ProjectEbonhold.PerkDatabase) do
        if data.quality == quality then
            table.insert(result, { spellId = spellId, data = data })
        end
    end
    return result
end

-- Helper function: Get total perk count
function ProjectEbonhold.GetTotalPerkCount()
    local count = 0
    for _ in pairs(ProjectEbonhold.PerkDatabase) do
        count = count + 1
    end
    return count
end
