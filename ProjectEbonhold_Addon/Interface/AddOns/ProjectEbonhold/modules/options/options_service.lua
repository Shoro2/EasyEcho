


local OptionsService = {}


local defaultSettings = {
    autoEquipItems = true,
    autoLearnTalents = true,
    autoPlaceSpells = true,
    showFloatingText = true,
    hideLevelUpFrame = false,
    -- Perk Selection UI options
    noPerkFadeAnimations = false,
    noRerollConfirm = false,
    rerollAutoRepopulate = false,
    echoesVisibleOnLevelUp = false,
    autoShowEchoes = false,
    perkDirectBanish = false,
    perkShowSelectCount = false,
    perkUIScale = 1.0,
    transparentDesign = false,
}

function OptionsService:Initialize()
    if not ProjectEbonholdDB then
        ProjectEbonholdDB = {}
    end
    
    if not ProjectEbonholdDB.settings then
        ProjectEbonholdDB.settings = {}
        for k, v in pairs(defaultSettings) do
            ProjectEbonholdDB.settings[k] = v
        end
    else
        
        for k, v in pairs(defaultSettings) do
            if ProjectEbonholdDB.settings[k] == nil then
                ProjectEbonholdDB.settings[k] = v
            end
        end
    end
    
    return ProjectEbonholdDB.settings
end


function OptionsService:GetSetting(key)
    if not ProjectEbonholdDB or not ProjectEbonholdDB.settings then
        return defaultSettings[key]
    end
    return ProjectEbonholdDB.settings[key]
end


function OptionsService:SetSetting(key, value)
    if not ProjectEbonholdDB or not ProjectEbonholdDB.settings then
        self:Initialize()
    end
    ProjectEbonholdDB.settings[key] = value
end


function OptionsService:ResetToDefaults()
    ProjectEbonholdDB.settings = {}
    for k, v in pairs(defaultSettings) do
        ProjectEbonholdDB.settings[k] = v
    end
end


function OptionsService:GetSettingsForServer()
    local settings = ProjectEbonholdDB.settings or defaultSettings
    
    
    local data = {}
    table.insert(data, "autoEquipItems:" .. (settings.autoEquipItems and "1" or "0"))
    table.insert(data, "autoLearnTalents:" .. (settings.autoLearnTalents and "1" or "0"))
    table.insert(data, "autoPlaceSpells:" .. (settings.autoPlaceSpells and "1" or "0"))
    
    return table.concat(data, ",")
end


function OptionsService:SendToServer()
    if not ProjectEbonhold or not ProjectEbonhold.sendToServer or not ProjectEbonhold.CS then
        return
    end
    
    local data = self:GetSettingsForServer()
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_ADDON_PREFERENCE, data)
end


function OptionsService:ApplySettingsFromServer(data)
    if not data or data == "" then return end
    
    
    for setting in string.gmatch(data, "[^,]+") do
        local key, value = string.match(setting, "([^:]+):([^:]+)")
        if key and value then
            if key == "autoEquipItems" or key == "autoLearnTalents" or key == "autoPlaceSpells" then
                self:SetSetting(key, value == "1")
            end
        end
    end
end


_G.ProjectEbonholdOptionsService = OptionsService
