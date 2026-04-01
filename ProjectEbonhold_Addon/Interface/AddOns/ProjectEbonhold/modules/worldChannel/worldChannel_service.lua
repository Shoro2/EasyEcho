local addon, Addon = ...

ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.WorldChannelService = {}

-- Ensure DB is initialized
local function EnsureDBInitialized()
    if not ProjectEbonholdDB then
        ProjectEbonholdDB = {}
    end
    if not ProjectEbonholdDB.worldChannelAsked then
        ProjectEbonholdDB.worldChannelAsked = {}
    end
end

local function GetCharacterKey()
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    return playerName .. "-" .. realmName
end

local function HasAskedCharacter()
    EnsureDBInitialized()
    local key = GetCharacterKey()
    return ProjectEbonholdDB.worldChannelAsked[key] == true
end

local function MarkCharacterAsAsked()
    EnsureDBInitialized()
    local key = GetCharacterKey()
    ProjectEbonholdDB.worldChannelAsked[key] = true
end

function ProjectEbonhold.WorldChannelService.JoinWorldChannel()
    -- Execute the /join command directly
    -- print("|cff00ff00[WorldChannel]|r Joining 'world' channel...")
    
    -- Use the built-in slash command handler
    SlashCmdList["JOIN"]("world")
    
    MarkCharacterAsAsked()
    
    -- Confirm after a short delay
    -- C_Timer.After(0.5, function()
    --     print("|cff00ff00[WorldChannel]|r Joined 'world' channel! You can now chat with the community.")
    -- end)
end

function ProjectEbonhold.WorldChannelService.DeclineWorldChannel()
    MarkCharacterAsAsked()
end

local function CheckAndShowPrompt()
    local key = GetCharacterKey()
    local hasAsked = HasAskedCharacter()
    -- print("|cff00ff00[WorldChannel]|r CheckAndShowPrompt called")
    -- print("|cff00ff00[WorldChannel]|r Character: " .. key)
    -- print("|cff00ff00[WorldChannel]|r Has been asked: " .. tostring(hasAsked))
    
    if not hasAsked then
        -- print("|cff00ff00[WorldChannel]|r Attempting to show popup...")
        -- Show the popup
        if ProjectEbonhold.WorldChannelUI and ProjectEbonhold.WorldChannelUI.ShowPrompt then
            ProjectEbonhold.WorldChannelUI.ShowPrompt()
            -- print("|cff00ff00[WorldChannel]|r Popup shown!")
        -- else
            -- print("|cffff0000[WorldChannel]|r ERROR: UI not available!")
        end
    -- else
        -- print("|cff00ff00[WorldChannel]|r Character already asked, skipping popup")
    end
end
-- Event handler for WoW 3.3.5a
local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Delay slightly to ensure UI is ready, then check and show popup if needed
        C_Timer.After(2, function()
            CheckAndShowPrompt()
        end)
    end
end)
