ProjectEbonhold = ProjectEbonhold or {}

ProjectEbonhold.ActionTypes = {
    INSTANCE_RESET = 1,
}

ProjectEbonhold.InstanceResetConfig = {
    BASE_COST = 50000,
    COST_MULTIPLIER = 2,
}

ProjectEbonhold.Constants = {
    MAX_INTENSITY = 475,
    MAX_SOUL_ASHES = 89701360,
    -- Intensity Levels
    INTENSITY_LEVEL_1 = 75,
    INTENSITY_LEVEL_2 = 200,
    INTENSITY_LEVEL_3 = 275,
    INTENSITY_LEVEL_4 = 400,
    INTENSITY_LEVEL_5 = 475,
    ENABLE_BANISH_SYSTEM = true,
    -- Transmog
    TRANSMOG_DEBUG_ENABLED = false,
    OUTFIT_DEBUG_ENABLED = false,
}

ProjectEbonhold.IntensityEffects = {
    {
        name = "Intensity I",
        icon = "Interface\\Icons\\spell_nzinsanity_chasedbyshadows",
        description =
        "Soul Ash gain increased by 20%.\n\nThe darkness grows restless. Corrupted creatures surge, their blows infused with shadow energy. These twisted beings are stronger and more resilient and are dealing shadow damage on hit.",
    },
    {
        name = "Intensity II",
        icon = "Interface\\Icons\\spell_shadow_twistedfaith",
        description =
            "Soul Ash gain increased by 30%.\n\nThe Lich King's gaze falls upon you. Periodically, a searing shadow mark scorches the ground beneath your feet, " ..
            "dealing 5% of your maximum health as damage after 3 seconds, and then detonates and dealing shadow damage and those struck suffer increased shadow damage taken.",
    },
    {
        name = "Intensity III",
        icon = "Interface\\Icons\\achievement_boss_lichking",
        description =
        "Soul Ash gain increased by 40%.\n\nThe shadow marks grow more volatile. Up to 3 more can now scorch the ground simultaneously at random location, and their dark energy seeps into nearby creatures, healing them.",
    },
    {
        name = "Intensity IV",
        icon = "Interface\\Icons\\spell_shadow_unstableaffliction_3",
        description =
        "Soul Ash gain increased by 50%.\n\nThe Lich King unleashes periodically his Champions",
    },
    {
        name = "Intensity V",
        icon = "Interface\\Icons\\spell_shadow_deathscream",
        description =
        "If you survive for 10 minutes, the Lich King will send the Reaper after you.",
    }
}

ProjectEbonhold.SoulAshesMilestones = {
    { soulAshes = 1000000, spellID = 101259 },
    { soulAshes = 2000000, spellID = 101260 },
    { soulAshes = 25000000, spellID = 101261 }
}

ProjectEbonhold.UITexts = {
    tooltips = {
        soulPoints = {
            title = function(sp) return "Soul Ashes: " .. sp end,
            line = "When you die, your Soul Ashes will be added to your Skill Tree."
        },
        multiplier = {
            title = function(mult)
                return "Soul Ash Multiplier: +" ..
                    string.format("%.0f", mult * 100) .. "%"
            end,
            line =
            "This is your Soul Ash gain multiplier. You can increase it by completing achievements and reaching higher Intensity levels."
        },
        reaper = {
            title = "The Reaper",
            spawned = function(areaName)
                return "The Reaper is in |cffFF4500" .. areaName .. "|r"
            end,
            notSpawned = "The Reaper is not spawned"
        },
        survival = {
            title = "Survival Stats",

            playerRezs = "Player-Granted Resurrections (Max Allowed): ",
            freeRezs = "Free Self-Resurrections (No Soul Ash Cost): ",
            classRezs = "Class-Based Resurrections (Reincarnate, Soulstone): ",
            cheatDeath = "Cheat Death Charges: ",
            nextRezCost = "Cost of Next Resurrection: ",
            nextCost = " Soul Ash"
        },
        intensity = {
            title = function(intensity)
                return "Intensity: " .. intensity
            end,
            description1 =
            "Defeating enemies more quickly raises your intensity faster, while killing grey enemies grants no intensity. Your intensity gradually decays while you are out of combat. Below are the effects of each intensity threshold. ",
            warning =
            "Warning: Staying alive at Intensity Level 5 for 10 minutes will unleash the Wrath of the Lich King!"
        }
    },
    ui = {
        echoes = function(count) return "Echoes (" .. count .. ")" end,
        stack = function(current, max)
            return "Stack: " .. current .. "/" .. max
        end
    }
}


ProjectEbonhold.DeathTexts = {
    frame = {
        title = "You are dead",
        description = "Choose an option:",
        arenaTitle = "Spectator Mode",
        arenaDescription = "You can spectate the arena:",
        battlegroundTitle = "Battleground Death"
    },

    buttons = {
        acceptDeath = function(soulPointsGain)
            return "Accept Death    |cff00FF00+" .. tostring(soulPointsGain) ..
                " Soul Points|r"
        end,
        releaseSpirit = "Release Spirit",
        useSoulstone = function(text, countCanClassRezs)
            return "Resurrect with " .. text .. " " ..
                tostring(countCanClassRezs) .. " remaining"
        end,
        selfRezAvailable = function(count)
            return "Resurrect without penalty " .. tostring(count) ..
                " remaining"
        end,
        soulPointsAffordable = function(cost)
            return "Resurrect |cffEB0000-" .. cost .. "|r Soul Points"
        end,
        acceptPlayerRez = function(count)
            return "Player Resurrection (" .. tostring(count) .. " remaining)"
        end
    },

    confirmations = {
        acceptDeath = {
            title = "Confirm Accept Death",
            message = function(soulPointsGain)
                return "You will gain " .. soulPointsGain ..
                    " Soul Points that you can spend in the Skill Tree.\n\nYour equipped gear will be sent to your inventory, and you will be reset to level 1 and teleported to your starting zone.\n\nAre you sure?"
            end
        },
        selfRez = {
            title = "Confirm Self Resurrection",
            message = function(remaining)
                return
                    "Use one of your remaining self resurrections?\n\nYou will be resurrected at the nearest graveyard.\n\n(" ..
                    remaining .. " remaining)"
            end
        },
        soulPointsRez = {
            title = "Confirm Soul Points Resurrection",
            message = function(cost, remaining)
                return "Use " .. cost ..
                    " Soul Points to resurrect?\n\nYou will have " ..
                    remaining .. " Soul Points remaining and will be resurrected at the nearest graveyard."
            end
        },
        soulstone = {
            title = function(text)
                return "Confirm " .. text .. " Usage"
            end,
            message = function(text, remaining)
                return "Use your " ..
                    text .. " to resurrect?\n\nYou will be resurrected at the nearest graveyard.\n\n(" ..
                    remaining .. " class resurrections remaining)"
            end
        },
        acceptPlayerRez = {
            title = "Confirm Player Resurrection",
            message = function(remaining)
                return "Accept resurrection from another player?\n\nYou will be resurrected at your friend's location.\n\n(" ..
                    remaining .. " accepted resurrections remaining)"
            end
        }
    },


    tooltips = {
        acceptDeath = {
            title = "Accept Death",
            line1 = function(soulPointsGain)
                return "You will gain " .. soulPointsGain .. " Soul Points."
            end,
            line2 = "Soul Points can be spent in the Skill Tree to unlock powerful abilities."
        },
        selfRez = {
            title = "Self Resurrection",
            line1 = "Revive without any penalty.",
            line2 = function(remaining)
                return "You have " .. remaining .. " remaining."
            end
        },
        soulPointsRez = {
            title = "Soul Points Resurrection",
            canAfford = {
                line1 = function(cost)
                    return "Use " .. cost .. " Soul Points to resurrect."
                end,
                line2 = "This will deduct Soul Points from your current run, not from your Skill Tree.",
                line3 = function(remaining)
                    return "You will have " .. remaining ..
                        " Soul Points remaining in this run."
                end
            },
            cantAfford = {
                line1 = function(cost)
                    return "You need " .. cost .. " Soul Points to resurrect."
                end,
                line2 = function(current)
                    return "You currently have " .. current ..
                        " Soul Points in this run."
                end
            }
        },
        soulstone = {
            title = function(text) return "Use " .. text end,
            line1 = function(text)
                return "Use your " .. text .. " to resurrect."
            end,
            line2 = function(remaining)
                return "You have " .. remaining ..
                    " class resurrections remaining."
            end
        },
        acceptPlayerRez = {
            title = "Accept Player Resurrection",
            line1 = "Accept resurrection from another player.",
            line2 = function(remaining)
                return "You have " .. remaining ..
                    " accepted resurrections remaining."
            end
        }
    },


    messages = {
        notEnoughSoulPoints = "|cffFF0000Not enough Soul Points to resurrect!|r",
        arenaSpectator = function()
            return ARENA_SPECTATOR or "You are now spectating."
        end,
        confirmPrints = {
            acceptDeath = "Accept Death confirmed - Custom call to implement",
            selfRez = "Self resurrection confirmed - Custom call to implement",
            soulPointsRez = "Soul Points resurrection confirmed - Custom call to implement",
            acceptPlayerRez = "Accept Player Resurrection confirmed - Custom call to implement"
        }
    }
}
