local addonName, addon = ...






local specDropdown = nil
local resetButton = nil
local selectedSpecIndex = nil


SpecCustomNames = SpecCustomNames or {}


local function GetSpecName(specIndex)
    if SpecCustomNames[specIndex] and SpecCustomNames[specIndex] ~= "" then
        return SpecCustomNames[specIndex]
    end
    local defaultNames = { "Primary", "Secondary", "Third", "Fourth", "Fifth" }
    return defaultNames[specIndex] .. " Specialization"
end


local function EditSpecName(specIndex)
    local defaultNames = { "Primary", "Secondary", "Third", "Fourth", "Fifth" }
    local currentName = SpecCustomNames[specIndex] or ""

    StaticPopupDialogs["EDIT_SPEC_NAME"] = {
        text = "Edit name for " .. defaultNames[specIndex] .. " Specialization:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(self)
            self.editBox:SetText(currentName)
            self.editBox:SetFocus()
        end,
        OnAccept = function(self)
            local newName = self.editBox:GetText()
            if newName and newName ~= "" then
                SpecCustomNames[specIndex] = newName
                print("|cff00FF00Spec name updated to: " .. newName .. "|r")
            else
                SpecCustomNames[specIndex] = nil
            end

            
            if specDropdown and selectedSpecIndex == specIndex then
                UIDropDownMenu_SetText(specDropdown, GetSpecName(specIndex))
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local newName = self:GetText()
            if newName and newName ~= "" then
                SpecCustomNames[specIndex] = newName
                print("|cff00FF00Spec name updated to: " .. newName .. "|r")
            else
                SpecCustomNames[specIndex] = nil
            end

            if specDropdown and selectedSpecIndex == specIndex then
                UIDropDownMenu_SetText(specDropdown, GetSpecName(specIndex))
            end
            self:GetParent():Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
        preferredIndex = 3
    }
    StaticPopup_Show("EDIT_SPEC_NAME")
end

local function CreateSpecDropdown()
    if specDropdown then return specDropdown end

    local dropdown = CreateFrame("Frame", "SpecDropdownFrame", PlayerTalentFrame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOP", PlayerTalentFrame, "TOP", -38, -40)
    UIDropDownMenu_SetWidth(dropdown, 140)

    
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        if level == 1 then
            for i = 1, 5 do
                local info = UIDropDownMenu_CreateInfo()
                local specName = GetSpecName(i)
                info.text = specName
                info.checked = (selectedSpecIndex == i)
                info.hasArrow = true
                info.value = i
                info.func = function()
                    selectedSpecIndex = i
                    if ProjectEbonhold and ProjectEbonhold.SpecService and ProjectEbonhold.SpecService.ApplySpec then
                        ProjectEbonhold.SpecService.ApplySpec(i)
                        UIDropDownMenu_SetText(dropdown, specName)
                        print("|cff00FF00Switching to " .. specName .. "...|r")
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end
        elseif level == 2 then
            local specIndex = UIDROPDOWNMENU_MENU_VALUE
            local info = UIDropDownMenu_CreateInfo()
            info.text = "|cffFFD700Edit Name|r"
            info.notCheckable = true
            info.func = function()
                EditSpecName(specIndex)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    
    if selectedSpecIndex then
        UIDropDownMenu_SetText(dropdown, GetSpecName(selectedSpecIndex))
    else
        UIDropDownMenu_SetText(dropdown, "Select Specialization")
    end

    specDropdown = dropdown
    return dropdown
end

local function CreateResetButton()
    if resetButton then return resetButton end

    local button = CreateFrame("Button", "ResetTalentsButton", PlayerTalentFrame, "UIPanelButtonTemplate")
    button:SetSize(100, 22)
    button:SetPoint("TOPRIGHT", PlayerTalentFrame, "TOPRIGHT", -40, -40)
    button:SetText("Reset Talents")

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Reset Talents", 1, 1, 1)
        GameTooltip:AddLine("Resets all talent points for the selected specialization.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffFFD700This will refund all spent talent points, allowing you to redistribute them.|r", 1,
            1, 0, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function()
        
        if not selectedSpecIndex then
            print("|cffFF0000Please select a specialization first|r")
            return
        end
        local selectedSpec = GetSpecName(selectedSpecIndex)
        StaticPopupDialogs["RESET_TALENTS_CONFIRM"] = {
            text = "Are you sure you want to reset all your talents?\n\n|cffFFD700Current Spec: " .. selectedSpec .. "|r",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                if ProjectEbonhold and ProjectEbonhold.SpecService and ProjectEbonhold.SpecService.ResetTalents then
                    ProjectEbonhold.SpecService.ResetTalents(selectedSpecIndex)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3
        }
        StaticPopup_Show("RESET_TALENTS_CONFIRM")
    end)

    resetButton = button
    return button
end


local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == "Blizzard_TalentUI" or PlayerTalentFrame then
        if PlayerTalentFrame then
            PlayerTalentFrame:HookScript("OnShow", function()
                CreateSpecDropdown()
                CreateResetButton()
                
                if selectedSpecIndex and specDropdown then
                    UIDropDownMenu_SetText(specDropdown, GetSpecName(selectedSpecIndex))
                end
            end)
            self:UnregisterEvent("ADDON_LOADED")
        end
    end
end)


local function UpdateSelectedSpec(specIndex)
    if not specIndex or specIndex < 1 or specIndex > 5 then
        print("|cffFF0000Invalid spec index received from server|r")
        return
    end

    selectedSpecIndex = specIndex

    
    if specDropdown then
        UIDropDownMenu_SetText(specDropdown, GetSpecName(specIndex))
        
    end
end


ProjectEbonhold = ProjectEbonhold or {}
ProjectEbonhold.Spec = ProjectEbonhold.Spec or {}
ProjectEbonhold.Spec.UpdateSelectedSpec = UpdateSelectedSpec
