-- Secure loading of Fluent UI
local Fluent, SaveManager, InterfaceManager

local function loadRemoteModule(url, label)
    if type(loadstring) ~= "function" then
        return nil, "loadstring is not available"
    end

    local fetchOk, source = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not fetchOk or type(source) ~= "string" or source == "" then
        return nil, "download failed: " .. tostring(source)
    end

    local chunk, compileErr = loadstring(source)
    if type(chunk) ~= "function" then
        return nil, "compile failed: " .. tostring(compileErr)
    end

    local runOk, result = pcall(chunk)
    if not runOk then
        return nil, "runtime failed: " .. tostring(result)
    end

    if result == nil then
        return nil, label .. " returned nil"
    end

    return result
end

local success, err = pcall(function()
    Fluent, err = loadRemoteModule("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua", "Fluent")
    if not Fluent then error(err) end

    SaveManager, err = loadRemoteModule("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua", "SaveManager")
    if not SaveManager then error(err) end

    InterfaceManager, err = loadRemoteModule("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua", "InterfaceManager")
    if not InterfaceManager then error(err) end
end)

if not success or not Fluent then
    warn("[Mango Hub] Failed to load Fluent UI: " .. tostring(err))
    return
end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- ============================================================
-- Fluent UI Setup (Larger Window)
-- ============================================================
local Window = Fluent:CreateWindow({
    Title = "Mango Hub",
    SubTitle = "Ban or Be Banned",
    TabWidth = 180,  -- Increased tab width
    Size = UDim2.fromOffset(500, 300),  -- Larger window size
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "dollar-sign" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

-- ============================================================
-- Global Variables
-- ============================================================
local isActive = false
local loopConn = nil
local spinAngle = 0
local hue = 0
local SPIN_SPEED = 10
local moneyParts = {}

-- ============================================================
-- UI Elements (Larger and More Spaced)
-- ============================================================
-- Main Toggle
local InfiniteMoneyToggle = Tabs.Main:AddToggle("InfiniteMoneyToggle", {
    Title = "Enable Infinite Money",
    Description = "Makes coins spin around you for easy collection. Keep it subtle to avoid detection.",
    Default = false
})

-- Spin Speed Slider
local SpinSpeedSlider = Tabs.Main:AddSlider("SpinSpeedSlider", {
    Title = "Spin Speed",
    Description = "Adjust how fast the coins spin around you (Lower = More Stealthy)",
    Default = 10,
    Min = 1,
    Max = 50,
    Rounding = 1,
    Callback = function(Value)
        SPIN_SPEED = Value
    end
})

-- Collection Range Slider
local RangeSlider = Tabs.Main:AddSlider("RangeSlider", {
    Title = "Collection Range",
    Description = "How far coins will be pulled towards you (in studs)",
    Default = 15,
    Min = 5,
    Max = 30,
    Rounding = 1,
    Callback = function(Value)
        COLLECT_RANGE = Value
    end
})

-- ============================================================
-- Main Functions
-- ============================================================
local COLLECT_RANGE = 15

local function getTorso()
    character = player.Character or player.CharacterAdded:Wait()
    if not character then return nil end
    return character:FindFirstChild("Torso") or
           character:FindFirstChild("UpperTorso") or
           character:FindFirstChild("HumanoidRootPart")
end

local function getMoneyParts()
    local results = {}
    local decoration = workspace:FindFirstChild("Decoration")
    if decoration then
        for _, child in ipairs(decoration:GetChildren()) do
            if child:IsA("BasePart") then
                local hasScript = child:FindFirstChildOfClass("Script")
                local hasTouch = child:FindFirstChildOfClass("TouchTransmitter") or
                                child:FindFirstChild("TouchInterest")
                if hasScript and hasTouch then
                    table.insert(results, child)
                end
            end
        end
    end
    return results
end

local function preparePart(part)
    if not part or not part:IsA("BasePart") then return end
    part.Anchored = true
    part.CanCollide = false
end

-- ============================================================
-- Main Loop
-- ============================================================
local function startLoop()
    if loopConn then
        loopConn:Disconnect()
        loopConn = nil
    end

    moneyParts = getMoneyParts()
    if #moneyParts == 0 then
        Fluent:Notify({
            Title = "Warning",
            Content = "No coins found in the Decoration folder. The script may not work in this game.",
            Duration = 5
        })
        return
    end

    for _, p in ipairs(moneyParts) do
        preparePart(p)
    end

    loopConn = RunService.Heartbeat:Connect(function(dt)
        if not isActive then return end

        local torso = getTorso()
        if not torso then return end

        -- Check if any parts are missing
        local anyMissing = false
        for _, p in ipairs(moneyParts) do
            if not p or not p.Parent then
                anyMissing = true
                break
            end
        end

        if anyMissing then
            moneyParts = getMoneyParts()
            for _, p in ipairs(moneyParts) do
                preparePart(p)
            end
            if #moneyParts == 0 then return end
        end

        hue = (hue + dt * 0.08) % 1
        spinAngle = (spinAngle + dt * SPIN_SPEED) % (2 * math.pi)

        for _, p in ipairs(moneyParts) do
            pcall(function()
                p.Color = Color3.fromHSV(hue, 1, 1)
                p.CFrame = CFrame.new(torso.Position) *
                         CFrame.Angles(spinAngle, spinAngle * 1.3, spinAngle * 0.7)
            end)
        end
    end)
end

local function stopLoop()
    if loopConn then
        loopConn:Disconnect()
        loopConn = nil
    end
end

-- ============================================================
-- Event Handling
-- ============================================================
InfiniteMoneyToggle:OnChanged(function(state)
    isActive = state
    if state then
        startLoop()
        Fluent:Notify({
            Title = "Infinite Money",
            Content = "Activated! Coins are now spinning around you. Keep it subtle to avoid detection.",
            Duration = 5
        })
    else
        stopLoop()
        Fluent:Notify({
            Title = "Infinite Money",
            Content = "Deactivated. Coins will return to normal.",
            Duration = 3
        })
    end
end)

SpinSpeedSlider:OnChanged(function(Value)
    SPIN_SPEED = Value
end)

RangeSlider:OnChanged(function(Value)
    COLLECT_RANGE = Value
end)

-- Character management
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    newChar:WaitForChild("HumanoidRootPart")
    if isActive then
        task.wait(0.5)
        startLoop()
    end
end)

-- ============================================================
-- Save and Load Configurations
-- ============================================================
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

-- Load autoload config
SaveManager:LoadAutoloadConfig()

print("[Mango Hub] Infinite Money loaded successfully!")
