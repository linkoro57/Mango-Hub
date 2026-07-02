local Fluent, SaveManager, InterfaceManager

local task = type(task) == "table" and task or {}
if type(task.wait) ~= "function" then
    task.wait = wait
end
if type(task.spawn) ~= "function" then
    task.spawn = function(callback, ...)
    local args = { ... }
    return spawn(function()
        callback(unpack(args))
    end)
    end
end
if type(task.delay) ~= "function" then
    task.delay = function(delayTime, callback, ...)
    local args = { ... }
    return spawn(function()
        wait(delayTime)
        callback(unpack(args))
    end)
    end
end

local function getLoader()
    if type(loadstring) == "function" then
        return loadstring
    end
    if type(load) == "function" then
        return load
    end
    return nil
end

local function httpGet(url)
    local ok, result = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and type(result) == "string" and result ~= "" then
        return true, result
    end

    local synTable = rawget(_G, "syn")
    local fluxusTable = rawget(_G, "fluxus")
    local requestImpl = rawget(_G, "request")
        or rawget(_G, "http_request")
        or rawget(_G, "http")
        or rawget(_G, "requestfunc")
        or (type(synTable) == "table" and synTable.request)
        or (type(fluxusTable) == "table" and fluxusTable.request)

    if type(requestImpl) ~= "function" then
        return false, result
    end

    local requestOk, response = pcall(requestImpl, {
        Url = url,
        Method = "GET",
    })

    if not requestOk or type(response) ~= "table" then
        return false, response
    end

    local body = response.Body or response.body
    return type(body) == "string" and body ~= "", body or response.StatusMessage or "empty response"
end

local function loadRemoteModule(url, label)
    local loader = getLoader()
    if type(loader) ~= "function" then
        return nil, "loadstring/load is not available"
    end

    local fetchOk, source = httpGet(url)
    if not fetchOk or type(source) ~= "string" or source == "" then
        return nil, "download failed: " .. tostring(source)
    end

    local chunk, compileErr = loader(source)
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

local uiSuccess, uiErr = pcall(function()
    local factory = rawget(_G, "__MangoHubUIFactory")
    if not factory then
        factory, uiErr = loadRemoteModule("https://raw.githubusercontent.com/linkoro57/Mango_Hub/main/mango-ui", "MangoUI")
    end
    if not factory then
        error(uiErr)
    end
    Fluent = factory.Fluent
    SaveManager = factory.SaveManager
    InterfaceManager = factory.InterfaceManager
end)

if not uiSuccess or not Fluent then
    warn("[Mango Hub] Failed to load Mango UI: " .. tostring(uiErr))
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local scriptAlive = true

local Window = Fluent:CreateWindow({
    Title = "Mango Hub",
    SubTitle = "Jump Brainrot",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 430),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "zap" }),
    Shop = Window:AddTab({ Title = "Shop", Icon = "shopping-bag" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
}

local Options = Fluent.Options

Window:SetOnClose(function()
    scriptAlive = false
    for _, option in pairs(Options) do
        if type(option) == "table" and type(option.SetValue) == "function" and type(option.Value) == "boolean" then
            pcall(function()
                option:SetValue(false)
            end)
        end
    end
end)

local Events = ReplicatedStorage:WaitForChild("Events")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Variables = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Varieables")
local EnergyTable = require(Variables:WaitForChild("Energys"))
local WingsTable = require(Variables:WaitForChild("Wings"))

local state = {
    autoJump = false,
    autoReward = false,
    autoRebirth = false,
    autoBuyBestEnergy = false,
    autoEquipBestEnergy = false,
    autoBuyBestWing = false,
    autoEquipBestWing = false,
    autoDelay = 0.25,
}

local statsParagraph = Tabs.Main:AddParagraph({
    Title = "Live Stats",
    Content = "Loading..."
})

local function notify(title, content, duration)
    Fluent:Notify({
        Title = title,
        Content = content,
        Duration = duration or 4
    })
end

local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

local function getRootPart()
    return getCharacter():WaitForChild("HumanoidRootPart")
end

local function getLeaderstats()
    return player:FindFirstChild("leaderstats")
end

local function getGameData()
    local ok, data = pcall(function()
        return Remotes.GetAllData:InvokeServer()
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local function getCurrentMoney()
    local leaderstats = getLeaderstats()
    local value = leaderstats and leaderstats:FindFirstChild("Power")
    return value and value.Value or 0
end

local function isOwned(map, key)
    if type(map) ~= "table" then
        return false
    end
    local value = map[key]
    return value ~= nil and value ~= false
end

local function getBestEnergyToBuyOrEquip(data)
    local money = data and data.Money or 0
    local owned = data and data.Energys or {}
    local bestOwnedKey
    local bestOwnedIndex = -1
    local bestAffordableKey
    local bestAffordableIndex = -1

    for key, info in pairs(EnergyTable) do
        if type(info) == "table" and info.Currency == "Money" and type(info.Index) == "number" then
            if isOwned(owned, key) then
                if info.Index > bestOwnedIndex then
                    bestOwnedIndex = info.Index
                    bestOwnedKey = key
                end
            elseif type(info.Cost) == "number" and money >= info.Cost and info.Index > bestAffordableIndex then
                bestAffordableIndex = info.Index
                bestAffordableKey = key
            end
        end
    end

    return bestAffordableKey, bestOwnedKey
end

local function getBestWingToBuyOrEquip(data)
    local money = data and data.Money or 0
    local owned = data and data.Wings or {}
    local bestOwnedKey
    local bestOwnedIndex = -1
    local bestAffordableKey
    local bestAffordableIndex = -1

    for key, info in pairs(WingsTable) do
        if type(info) == "table" and info.Currency == "Money" and type(info.Index) == "number" then
            if isOwned(owned, key) then
                if info.Index > bestOwnedIndex then
                    bestOwnedIndex = info.Index
                    bestOwnedKey = key
                end
            elseif type(info.Cost) == "number" and money >= info.Cost and info.Index > bestAffordableIndex then
                bestAffordableIndex = info.Index
                bestAffordableKey = key
            end
        end
    end

    return bestAffordableKey, bestOwnedKey
end

local function fireJump()
    pcall(function()
        Remotes.Jump:FireServer()
    end)
end

local function claimReward()
    pcall(function()
        Events.Reward:FireServer()
    end)
end

local function rebirth()
    pcall(function()
        Events.Rebirth:FireServer()
    end)
end

local function buyBestEnergy()
    local data = getGameData()
    local bestAffordableKey = getBestEnergyToBuyOrEquip(data)
    if bestAffordableKey then
        pcall(function()
            Events.BuyEnergy:FireServer(bestAffordableKey)
        end)
        return bestAffordableKey
    end
    return nil
end

local function equipBestEnergy()
    local data = getGameData()
    local _, bestOwnedKey = getBestEnergyToBuyOrEquip(data)
    if bestOwnedKey then
        pcall(function()
            Events.EquipEnergy:FireServer(bestOwnedKey)
        end)
        return bestOwnedKey
    end
    return nil
end

local function buyBestWing()
    local data = getGameData()
    local bestAffordableKey = getBestWingToBuyOrEquip(data)
    if bestAffordableKey then
        pcall(function()
            Events.BuyWing:FireServer(bestAffordableKey)
        end)
        return bestAffordableKey
    end
    return nil
end

local function equipBestWing()
    local data = getGameData()
    local _, bestOwnedKey = getBestWingToBuyOrEquip(data)
    if bestOwnedKey then
        pcall(function()
            Events.EquipWing:FireServer(bestOwnedKey)
        end)
        return bestOwnedKey
    end
    return nil
end

local function updateStats()
    local leaderstats = getLeaderstats()
    local altitude = leaderstats and leaderstats:FindFirstChild("Altitude")
    local power = leaderstats and leaderstats:FindFirstChild("Power")
    local rebirths = leaderstats and leaderstats:FindFirstChild("Rebirth")
    local data = getGameData()

    statsParagraph:SetDesc(table.concat({
        "Altitude: " .. tostring(altitude and altitude.Value or "?"),
        "Power: " .. tostring(power and power.Value or "?"),
        "Rebirths: " .. tostring(rebirths and rebirths.Value or "?"),
        "Money: " .. tostring(data and data.Money or "?"),
        "Energy: " .. tostring(data and data.Energy or "none"),
        "Wing: " .. tostring(data and data.Wing or "none"),
    }, "\n"))
end

local teleports = {
    Spawn = Vector3.new(100.7, 4, -42.8),
    Forest = Vector3.new(410.1, 1028.5, -281.2),
    Frozen = Vector3.new(9281.1, 1028.5, -281.2),
    Lava = Vector3.new(5004.3, 1028.5, 21.5),
    Golden = Vector3.new(29335.5, 4.8, -18.7),
    TwilightVale = Vector3.new(13033.1, -127.3, -271.9),
    ForestChest = Vector3.new(50.2, 27.9, -173.8),
}

Tabs.Main:AddButton({
    Title = "Jump Once",
    Callback = function()
        fireJump()
    end
})

Tabs.Main:AddButton({
    Title = "Claim Reward Once",
    Callback = function()
        claimReward()
    end
})

Tabs.Main:AddButton({
    Title = "Rebirth Once",
    Callback = function()
        rebirth()
    end
})

Tabs.Main:AddSlider("ActionDelaySlider", {
    Title = "Auto Delay",
    Description = "Shared delay for auto actions.",
    Default = 25,
    Min = 5,
    Max = 100,
    Rounding = 0,
    Callback = function(value)
        state.autoDelay = value / 100
    end
})

Tabs.Main:AddToggle("AutoJumpToggle", {
    Title = "Auto Jump",
    Default = false
}):OnChanged(function(value)
    state.autoJump = value
end)

Tabs.Main:AddToggle("AutoRewardToggle", {
    Title = "Auto Reward",
    Default = false
}):OnChanged(function(value)
    state.autoReward = value
end)

Tabs.Main:AddToggle("AutoRebirthToggle", {
    Title = "Auto Rebirth",
    Default = false
}):OnChanged(function(value)
    state.autoRebirth = value
end)

Tabs.Shop:AddButton({
    Title = "Buy Best Energy",
    Callback = function()
        local bought = buyBestEnergy()
        notify("Energy", bought and ("Bought " .. bought) or "Nothing affordable.")
    end
})

Tabs.Shop:AddButton({
    Title = "Equip Best Energy",
    Callback = function()
        local equipped = equipBestEnergy()
        notify("Energy", equipped and ("Equipped " .. equipped) or "No owned energy found.")
    end
})

Tabs.Shop:AddToggle("AutoBuyBestEnergyToggle", {
    Title = "Auto Buy Best Energy",
    Default = false
}):OnChanged(function(value)
    state.autoBuyBestEnergy = value
end)

Tabs.Shop:AddToggle("AutoEquipBestEnergyToggle", {
    Title = "Auto Equip Best Energy",
    Default = false
}):OnChanged(function(value)
    state.autoEquipBestEnergy = value
end)

Tabs.Shop:AddButton({
    Title = "Buy Best Wing",
    Callback = function()
        local bought = buyBestWing()
        notify("Wings", bought and ("Bought " .. bought) or "Nothing affordable.")
    end
})

Tabs.Shop:AddButton({
    Title = "Equip Best Wing",
    Callback = function()
        local equipped = equipBestWing()
        notify("Wings", equipped and ("Equipped " .. equipped) or "No owned wing found.")
    end
})

Tabs.Shop:AddToggle("AutoBuyBestWingToggle", {
    Title = "Auto Buy Best Wing",
    Default = false
}):OnChanged(function(value)
    state.autoBuyBestWing = value
end)

Tabs.Shop:AddToggle("AutoEquipBestWingToggle", {
    Title = "Auto Equip Best Wing",
    Default = false
}):OnChanged(function(value)
    state.autoEquipBestWing = value
end)

for name, position in pairs(teleports) do
    Tabs.Teleport:AddButton({
        Title = "Teleport " .. name,
        Callback = function()
            local root = getRootPart()
            root.CFrame = CFrame.new(position)
        end
    })
end

Tabs.Settings:AddButton({
    Title = "Refresh Stats",
    Callback = function()
        updateStats()
    end
})

task.spawn(function()
    while scriptAlive do
        updateStats()

        if state.autoJump then
            fireJump()
        end
        if state.autoReward then
            claimReward()
        end
        if state.autoRebirth then
            rebirth()
        end
        if state.autoBuyBestEnergy then
            buyBestEnergy()
        end
        if state.autoEquipBestEnergy then
            equipBestEnergy()
        end
        if state.autoBuyBestWing then
            buyBestWing()
        end
        if state.autoEquipBestWing then
            equipBestWing()
        end

        task.wait(state.autoDelay)
    end
end)

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()

notify("Mango Hub", "Jump Brainrot loaded.", 4)
