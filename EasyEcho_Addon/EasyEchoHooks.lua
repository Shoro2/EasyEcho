-- EasyEchoHooks.lua
-- Split-out UI scanning hooks (Start button / Accept Death) and run reset
-- Generated: 2026-02-15 21:38:32

EasyEcho = EasyEcho or {}
EasyEcho.Hooks = EasyEcho.Hooks or {}

local S = EasyEcho.State

local function NormalizeUiText(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return string.lower(text)
end

function EasyEcho.Hooks.ResetRunState(reason)
    S.currentRerolls = 0
    S.isProcessing = false
    S.lastChoicesRef = nil
    S.lastLoggedPick = -1

    if S.pickerFrame then
        S.pickerFrame.state = nil
        S.pickerFrame.timer = 0
        S.pickerFrame:Hide()
    end

    S.isAutoStopped = false

    if EasyEcho_UI and EasyEcho_UI.ResetAllData then
        EasyEcho_UI.ResetAllData(reason or "Run reset detected. Data has been cleared.")
    else
        EasyEchoHistoryDB = {}
        EasyEchoLogDB = {}
        if EasyEchoSettings then EasyEchoSettings.CurrentPickCount = 2 end
    end
end

local function FrameHasAcceptDeathText(frame)
    if not frame then return false end

    if frame.GetText then
        local txt = NormalizeUiText(frame:GetText())
        if txt ~= "" and txt:find("accept", 1, true) and txt:find("death", 1, true) then return true end
    end

    if frame.GetRegions then
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
                local txt = NormalizeUiText(region:GetText())
                if txt ~= "" and txt:find("accept", 1, true) and txt:find("death", 1, true) then return true end
            end
        end
    end

    local name = frame.GetName and frame:GetName() or ""
    name = string.lower(name or "")
    if name:find("accept", 1, true) and name:find("death", 1, true) then return true end

    return false
end

local function IsAcceptDeathButton(frame)
    if not frame or frame.GetObjectType == nil then return false end
    if frame:GetObjectType() ~= "Button" then return false end
    return FrameHasAcceptDeathText(frame)
end

function EasyEcho.Hooks.TryHookAcceptDeathButtons(root)
    if not root or not root.GetChildren then return false end

    local found = false
    local children = { root:GetChildren() }
    for _, child in ipairs(children) do
        if IsAcceptDeathButton(child) and not S.hookedAcceptDeathButtons[child] then
            S.hookedAcceptDeathButtons[child] = true
            child:HookScript("OnClick", function()
                if S.pendingDeathReset then
                    S.pendingDeathReset = false
                    EasyEcho.Hooks.ResetRunState("Accept Death selected. Data has been reset for a new run.")
                end
            end)
            found = true
        end

        if EasyEcho.Hooks.TryHookAcceptDeathButtons(child) then found = true end
    end

    return found
end

local function IsStartButton(frame)
    if not frame or not frame.GetObjectType or frame:GetObjectType() ~= "Button" then return false end

    local txt = ""
    if frame.GetText then txt = NormalizeUiText(frame:GetText()) end
    local name = frame.GetName and NormalizeUiText(frame:GetName()) or ""

    return txt == "start" or txt:find("start", 1, true) ~= nil or name:find("start", 1, true) ~= nil
end

function EasyEcho.Hooks.TryHookStartButtons(root)
    if not root or not root.GetChildren then return false end

    local found = false
    local children = { root:GetChildren() }
    for _, child in ipairs(children) do
        if IsStartButton(child) and not S.hookedStartButtons[child] then
            S.hookedStartButtons[child] = true
            child:HookScript("OnClick", function()
                if EasyEcho.Engine and EasyEcho.Engine.TryRequestChoiceNow then
                    EasyEcho.Engine.TryRequestChoiceNow()
                end
                S.startButtonWatcher.timer = 0
                S.startButtonWatcher:Show()
            end)
            found = true
        end

        if EasyEcho.Hooks.TryHookStartButtons(child) then found = true end
    end

    return found
end

S.startButtonWatcher:SetScript("OnUpdate", function(self, elapsed)
    if not EasyEcho_IsRunning then self:Hide(); return end
    self.timer = (self.timer or 0) + elapsed
    if self.timer >= 1.0 then
        self:Hide()
        if EasyEcho.Engine and EasyEcho.Engine.TryRequestChoiceNow then
            EasyEcho.Engine.TryRequestChoiceNow()
        end
    end
end)

S.acceptDeathWatcher:SetScript("OnUpdate", function(self, elapsed)
    if not S.pendingDeathReset then self:Hide(); return end

    self.timer = (self.timer or 0) + elapsed
    self.timeout = (self.timeout or 0) + elapsed

    if self.timer >= 0.2 then
        self.timer = 0
        EasyEcho.Hooks.TryHookAcceptDeathButtons(UIParent)
    end

    if self.timeout >= 15 then
        S.pendingDeathReset = false
        self:Hide()
    end
end)
