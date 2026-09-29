
-- ============================================================
-- SERVICES
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================================
-- OBSIDIAN UI LOAD
-- ============================================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

task.spawn(function()
    task.wait(1)
    pcall(function() Library:SetFont(Enum.Font.Gotham) end)
end)

local Window = Library:CreateWindow({
    Title = "Proximity Lock",
    Footer = "by L | discord: introvertt_l",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = true,
})

local Tabs = {
    Main = Window:AddTab("Main", "crosshair"),
    Settings = Window:AddTab("Settings", "settings"),
    Configs = Window:AddTab("Configs", "settings-2"),
}

-- ============================================================
-- CONFIGURATION
-- ============================================================
local Settings = {
    LockEnabled = false,
    ToggleKey = Enum.KeyCode.C,
    Smoothness = 0.2,
    TargetPart = "HumanoidRootPart",
    TeamCheck = false,
}

-- ============================================================
-- STATE
-- ============================================================
local state = {
    bound = false,
    toggleConn = nil,
    currentTarget = nil,
}

-- ============================================================
-- CORE: FIND NEAREST PLAYER
-- ============================================================
local function GetNearestPlayer()
    local target = nil
    local shortestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild(Settings.TargetPart)
            local hum = player.Character:FindFirstChild("Humanoid")
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

            if root and hum and hum.Health > 0 and myRoot then
                local skip = false
                if Settings.TeamCheck and player.Team == LocalPlayer.Team then
                    skip = true
                end

                if not skip then
                    local distance = (myRoot.Position - root.Position).Magnitude
                    local _, isVisible = Camera:WorldToViewportPoint(root.Position)

                    if isVisible and distance < shortestDistance then
                        target = root
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    return target
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function proximityLoop()
    if not Settings.LockEnabled then
        state.currentTarget = nil
        return
    end

    local target = GetNearestPlayer()
    state.currentTarget = target

    if target then
        local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Settings.Smoothness)
    end
end

local function startLoop()
    if state.bound then return end
    RunService:BindToRenderStep("ProximityLock", 201, proximityLoop)
    state.bound = true
end

local function stopLoop()
    if not state.bound then return end
    pcall(function() RunService:UnbindFromRenderStep("ProximityLock") end)
    state.bound = false
    state.currentTarget = nil
end

-- ============================================================
-- TOGGLE KEYBIND
-- ============================================================
local function bindToggleKey()
    if state.toggleConn then
        pcall(function() state.toggleConn:Disconnect() end)
        state.toggleConn = nil
    end

    state.toggleConn = UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Settings.ToggleKey then
            Settings.LockEnabled = not Settings.LockEnabled
            pcall(function()
                if Toggles.LockEnabled then Toggles.LockEnabled:SetValue(Settings.LockEnabled) end
            end)
            Library:Notify({
                Title = "Proximity Lock",
                Description = Settings.LockEnabled and "Enabled" or "Disabled",
                Time = 2,
            })
        end
    end)
end

-- ============================================================
-- MAIN TAB
-- ============================================================
local LockGroup = Tabs.Main:AddLeftGroupbox("Proximity Lock", "crosshair")
local InfoGroup = Tabs.Main:AddRightGroupbox("Status", "activity")

LockGroup:AddToggle("LockEnabled", {
    Text = "Enable Lock",
    Default = false,
    Tooltip = "Locks camera onto nearest visible player",
})
Toggles.LockEnabled:OnChanged(function(v)
    Settings.LockEnabled = v
end)

LockGroup:AddSlider("Smoothness", {
    Text = "Smoothness",
    Min = 0.05,
    Max = 1,
    Default = 0.2,
    Rounding = 2,
    Suffix = "x",
    Tooltip = "0.05 = very smooth, 1 = instant snap",
})
Options.Smoothness:OnChanged(function(v)
    Settings.Smoothness = tonumber(v) or 0.2
end)

LockGroup:AddDropdown("TargetPart", {
    Text = "Target Part",
    Values = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso" },
    Default = "HumanoidRootPart",
    Multi = false,
})
Options.TargetPart:OnChanged(function(v)
    Settings.TargetPart = v
end)

LockGroup:AddToggle("TeamCheck", {
    Text = "Team Check (Ignore Teammates)",
    Default = false,
})
Toggles.TeamCheck:OnChanged(function(v)
    Settings.TeamCheck = v
end)

local statusLabel = InfoGroup:AddLabel("Status: Idle")
local targetLabel = InfoGroup:AddLabel("Target: None")

task.spawn(function()
    while true do
        task.wait(0.25)
        pcall(function()
            if Settings.LockEnabled then
                statusLabel:SetText("Status: <font color=\"#00FF00\">Locked</font>")
            else
                statusLabel:SetText("Status: Idle")
            end
            if state.currentTarget and state.currentTarget.Parent then
                local name = state.currentTarget.Parent.Name
                targetLabel:SetText("Target: " .. name)
            else
                targetLabel:SetText("Target: None")
            end
        end)
    end
end)

-- ============================================================
-- SETTINGS TAB
-- ============================================================
local KeyGroup = Tabs.Settings:AddLeftGroupbox("Keybind", "settings")

KeyGroup:AddDropdown("ToggleKey", {
    Text = "Toggle Key",
    Values = { "C", "V", "F", "G", "H", "X", "Z", "Q", "E", "R", "T", "Y" },
    Default = "C",
    Multi = false,
})
Options.ToggleKey:OnChanged(function(v)
    local key = Enum.KeyCode[v]
    if key then
        Settings.ToggleKey = key
        bindToggleKey()
    end
end)

KeyGroup:AddLabel("Press keybind to toggle lock on/off")

-- ============================================================
-- THEME + SAVE MANAGERS
-- ============================================================
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("ProximityLock")
SaveManager:SetFolder("ProximityLock")

ThemeManager:SetDefaultTheme({
    FontColor       = Color3.fromRGB(225, 225, 225),
    MainColor       = Color3.fromRGB(28, 28, 28),
    AccentColor     = Color3.fromRGB(100, 100, 255),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    OutlineColor    = Color3.fromRGB(50, 50, 50),
    FontFace        = Font.fromName("Gotham", Enum.FontWeight.Medium),
})

SaveManager:BuildConfigSection(Tabs.Configs)
ThemeManager:ApplyToTab(Tabs.Configs)
ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()

-- ============================================================
-- UNLOAD
-- ============================================================
Library:OnUnload(function()
    stopLoop()
    if state.toggleConn then
        pcall(function() state.toggleConn:Disconnect() end)
        state.toggleConn = nil
    end
end)

-- ============================================================
-- INIT
-- ============================================================
startLoop()
bindToggleKey()

Library:Notify({
    Title = "Proximity Lock",
    Description = "Loaded! Press " .. Settings.ToggleKey.Name .. " to toggle",
    Time = 4,
})
