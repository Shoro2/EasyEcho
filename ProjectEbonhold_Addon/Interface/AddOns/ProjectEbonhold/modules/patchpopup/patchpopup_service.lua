


local addonName, addon = ...
local CS = ProjectEbonhold.CS
local SS = ProjectEbonhold.SS
local sendToServer = ProjectEbonhold.sendToServer
local onEventReceived = ProjectEbonhold.onEventReceived


local function requestPatchVersionCheck()
    sendToServer(CS.REQUEST_VERSION_CHECK, addon.version)
end


onEventReceived(SS.SEND_WRONG_PATCH, function(body)
    local requiredPatch = body or "unknown"
    if PatchPopup then
        PatchPopup:ShowPatchError(requiredPatch)
    end
end)


local function init()
    requestPatchVersionCheck()
end


local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        init()
    end
end)
