-- EasyEcho.lua
-- Main entrypoint (split version).
-- Requires: EasyEchoCore.lua, EasyEchoEngine.lua, EasyEchoHooks.lua
-- Generated: 2026-02-15 21:38:32

EasyEcho = EasyEcho or {}
local S = EasyEcho.State

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if not EasyEchoLogDB then EasyEchoLogDB = {} end
        if not EasyEchoHistoryDB then EasyEchoHistoryDB = {} end
        if not EasyEchoSettings then EasyEchoSettings = {} end
        if not EasyEchoEchoDB then EasyEchoEchoDB = {} end

        if EasyEcho.InitializeSettings then EasyEcho.InitializeSettings() end
        if not EasyEchoSettings.CurrentPickCount then EasyEchoSettings.CurrentPickCount = 2 end

        -- Restore character-specific profile (silent, no chat message)
        if EasyEchoSettings.CharacterProfiles then
            local charKey = (UnitName("player") or "") .. "-" .. (GetRealmName() or "")
            local charProfile = EasyEchoSettings.CharacterProfiles[charKey]
            if charProfile and EasyEchoSettings.Profiles and EasyEchoSettings.Profiles[charProfile] then
                EasyEcho_SwitchProfile(charProfile, true)
            end
        end

        if EasyEcho_UI and EasyEcho_UI.Init then EasyEcho_UI.Init() end
        if EasyEcho.SyncRerollStatus then EasyEcho.SyncRerollStatus() end

        if EasyEcho.Hooks and EasyEcho.Hooks.TryHookStartButtons then
            EasyEcho.Hooks.TryHookStartButtons(UIParent)
        end

        if EasyEcho.Engine and EasyEcho.Engine.TryRequestChoiceNow then
            EasyEcho.Engine.TryRequestChoiceNow()
        end

        -- If ProjectEbonhold exposes PerkUI.Show(), hook it so we pick right when it opens.
        if ProjectEbonhold and ProjectEbonhold.PerkUI and hooksecurefunc then
            hooksecurefunc(ProjectEbonhold.PerkUI, "Show", function()
                if not EasyEcho_IsRunning then return end
                if S.isAutoStopped or S.isProcessing then return end
                if EasyEcho.Engine and EasyEcho.Engine.StartPicker then
                    EasyEcho.Engine.StartPicker()
                end
            end)
        end
        return
    end

    if event == "PLAYER_DEAD" then
        -- Auto-reset log immediately on death if the setting is enabled
        if EasyEchoSettings and EasyEchoSettings.AutoResetLogOnDeath then
            if EasyEcho.Hooks and EasyEcho.Hooks.ResetRunState then
                EasyEcho.Hooks.ResetRunState("Player died. Log automatically reset.")
            end
            return
        end
        S.pendingDeathReset = true
        S.acceptDeathWatcher.timer = 0
        S.acceptDeathWatcher.timeout = 0
        if EasyEcho.Hooks and EasyEcho.Hooks.TryHookAcceptDeathButtons then
            EasyEcho.Hooks.TryHookAcceptDeathButtons(UIParent)
        end
        S.acceptDeathWatcher:Show()
        return
    end

    if event == "PLAYER_LEVEL_UP" then
        if EasyEcho_UI and EasyEcho_UI.UpdateEchoListUI and EasyEchoGrantedEchoesFrame and EasyEchoGrantedEchoesFrame:IsShown() then
            EasyEcho_UI.UpdateEchoListUI()
        end
        if EasyEcho.Engine and EasyEcho.Engine.CheckAutoStopAtMaxLevel then
            EasyEcho.Engine.CheckAutoStopAtMaxLevel()
        end
        -- Auto-open summary screen when reaching level 80
        if EasyEchoSettings and EasyEchoSettings.AutoOpenSummaryAt80 then
            local lvl = UnitLevel("player") or 1
            if lvl >= 80 and EasyEcho_UI and EasyEcho_UI.ShowMainWindow then
                EasyEcho_UI.ShowMainWindow()
            end
        end
        -- Send echo summary to party chat at levels 60, 70, 80
        if not EasyEchoSettings or EasyEchoSettings.SendPartyChatSummary ~= false then
            local lvl = UnitLevel("player") or 1
            if (lvl == 60 or lvl == 70 or lvl == 80) and EasyEcho_UI and EasyEcho_UI.GetGrantedSummary then
                local cPrio, cEpic, cRare, _, cUncommon, cCommon = EasyEcho_UI.GetGrantedSummary()
                local cTotal = cEpic + cRare + cUncommon + cCommon
                local msg = string.format("[EasyEcho] Lvl %d Summary: %d Echoes (%d Epic, %d Rare, %d Uncommon, %d Common | %d Prio)",
                    lvl, cTotal, cEpic, cRare, cUncommon, cCommon, cPrio)
                if GetNumPartyMembers and GetNumPartyMembers() > 0 then
                    SendChatMessage(msg, "PARTY")
                else
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00" .. msg .. "|r")
                    end
                end
            end
        end
        return
    end

    if event == "PLAYER_ALIVE" then
        if S.pendingDeathReset and (UnitLevel("player") or 1) <= 1 then
            S.pendingDeathReset = false
            if EasyEcho.Hooks and EasyEcho.Hooks.ResetRunState then
                EasyEcho.Hooks.ResetRunState("New run detected after death. Data has been reset.")
            end
        else
            S.pendingDeathReset = false
            S.acceptDeathWatcher:Hide()
        end

        if EasyEcho.SyncRerollStatus then EasyEcho.SyncRerollStatus() end
        if EasyEcho.Hooks and EasyEcho.Hooks.TryHookStartButtons then
            EasyEcho.Hooks.TryHookStartButtons(UIParent)
        end

        if (UnitLevel("player") or 1) < 80 then
            S.isAutoStopped = false
        else
            if EasyEcho.Engine and EasyEcho.Engine.CheckAutoStopAtMaxLevel then
                EasyEcho.Engine.CheckAutoStopAtMaxLevel()
            end
        end
        return
    end
end)
