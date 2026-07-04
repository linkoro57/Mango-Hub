local Fluent, SaveManager, InterfaceManager

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
        factory, uiErr = loadRemoteModule("https://raw.githubusercontent.com/linkoro57/Mango-Hub/main/mango-ui.lua", "MangoUI")
    end
    if not factory then error(uiErr) end

    Fluent = factory.Fluent
    SaveManager = factory.SaveManager
    InterfaceManager = factory.InterfaceManager
end)

if not uiSuccess or not Fluent then
    warn("[Mango Hub] Failed to load Mango UI: " .. tostring(uiErr))
    return
end

local Window = Fluent:CreateWindow({
    Title = "Mango Hub",
    SubTitle = "Be a Lucky Block",
    TabWidth = 160,
    Size = UDim2.fromOffset(550, 430),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Misc = Window:AddTab({ Title = "Misc", Icon = "box" }),
    Upgrades = Window:AddTab({ Title = "Upgrades", Icon = "info" }),
    Farm = Window:AddTab({ Title = "Farm", Icon = "bot" }),
    Sell = Window:AddTab({ Title = "Sell", Icon = "dollar-sign" }),
    Webhook = Window:AddTab({ Title = "Webhook", Icon = "wifi" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

---
--- Sélection de la base pour l'Auto Farm
---
local selectedBase = "base1"
local BaseDropdown

local function getAvailableBases()
    local collectZones = workspace:FindFirstChild("CollectZones")
    if not collectZones then
        return {selectedBase}
    end

    local bases = {}
    for _, child in ipairs(collectZones:GetChildren()) do
        if child:IsA("BasePart") or child:IsA("Model") or child:IsA("Folder") then
            table.insert(bases, child.Name)
        end
    end

    table.sort(bases, function(a, b)
        local aNumber = tonumber(a:match("%d+"))
        local bNumber = tonumber(b:match("%d+"))
        if aNumber and bNumber and aNumber ~= bNumber then
            return aNumber < bNumber
        end
        return a < b
    end)

    if #bases == 0 then
        table.insert(bases, selectedBase)
    end

    return bases
end

local function refreshBaseDropdown()
    local bases = getAvailableBases()
    if not table.find(bases, selectedBase) then
        selectedBase = bases[1]
        pcall(function()
            BaseDropdown:SetValue(selectedBase)
        end)
    end

    pcall(function()
        if BaseDropdown and BaseDropdown.SetValues then
            BaseDropdown:SetValues(bases)
        end
    end)
end

-- Dropdown pour choisir la base
BaseDropdown = Tabs.Farm:AddDropdown("BaseDropdown", {
    Title = "Select Farming Base",
    Values = getAvailableBases(),
    Multi = false,
    Default = selectedBase,
    Callback = function(Value)
        selectedBase = Value
    end
})

task.spawn(function()
    local collectZones = workspace:WaitForChild("CollectZones")
    refreshBaseDropdown()
    collectZones.ChildAdded:Connect(function()
        task.wait(0.1)
        refreshBaseDropdown()
    end)
    collectZones.ChildRemoved:Connect(function()
        task.wait(0.1)
        refreshBaseDropdown()
    end)
end)

---
--- Auto Farm Best Brainrots (avec sélection de base)
---
local running = false
local AutoFarmToggle = Tabs.Farm:AddToggle("AutoFarmToggle", {
    Title = "Auto Farm Best Brainrots",
    Default = false
})

AutoFarmToggle:OnChanged(function(state)
    running = state
    if state then
        task.spawn(function()
            while running do
                local player = game.Players.LocalPlayer
                local character = player.Character or player.CharacterAdded:Wait()
                local root = character:WaitForChild("HumanoidRootPart")
                local humanoid = character:WaitForChild("Humanoid")
                local userId = player.UserId
                local modelsFolder = workspace:WaitForChild("RunningModels")
                local target = workspace:WaitForChild("CollectZones"):WaitForChild(selectedBase)

                -- Déplacement initial
                root.CFrame = CFrame.new(715, 39, -2122)
                task.wait(0.3)
                humanoid:MoveTo(Vector3.new(710, 39, -2122))

                -- Attendre de trouver le modèle du joueur
                local ownedModel = nil
                repeat
                    task.wait(0.3)
                    for _, obj in ipairs(modelsFolder:GetChildren()) do
                        if obj:IsA("Model") and obj:GetAttribute("OwnerId") == userId then
                            ownedModel = obj
                            break
                        end
                    end
                until ownedModel ~= nil or not running

                if not running then break end

                -- Déplacer le modèle vers la base sélectionnée
                if ownedModel.PrimaryPart then
                    ownedModel:SetPrimaryPartCFrame(target.CFrame)
                else
                    local part = ownedModel:FindFirstChildWhichIsA("BasePart")
                    if part then
                        part.CFrame = target.CFrame
                    end
                end

                task.wait(0.7)

                -- Placer le modèle légèrement en dessous de la base
                if ownedModel and ownedModel.Parent == modelsFolder then
                    if ownedModel.PrimaryPart then
                        ownedModel:SetPrimaryPartCFrame(target.CFrame * CFrame.new(0, -5, 0))
                    else
                        local part = ownedModel:FindFirstChildWhichIsA("BasePart")
                        if part then
                            part.CFrame = target.CFrame * CFrame.new(0, -5, 0)
                        end
                    end
                end

                -- Attendre que le modèle disparaisse
                repeat
                    task.wait(0.3)
                until not running or (ownedModel == nil or ownedModel.Parent ~= modelsFolder)

                if not running then break end

                -- Attendre la réapparition du personnage
                local oldCharacter = player.Character
                repeat
                    task.wait(0.2)
                until not running or (player.Character ~= oldCharacter and player.Character ~= nil)

                if not running then break end

                task.wait(0.4)
                local newChar = player.Character
                local newRoot = newChar:WaitForChild("HumanoidRootPart")
                newRoot.CFrame = CFrame.new(737, 39, -2118)
                task.wait(2.1)
            end
        end)
    end
end)
Options.AutoFarmToggle:SetValue(false)

---
--- Auto Claim Playtime Rewards
---
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local claimGift = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_knit@1.7.0")
    :WaitForChild("knit")
    :WaitForChild("Services")
    :WaitForChild("PlaytimeRewardService")
    :WaitForChild("RF")
    :WaitForChild("ClaimGift")

local autoClaiming = false
local ACPR = Tabs.Misc:AddToggle("ACPR", {
    Title = "Auto Claim Playtime Rewards",
    Default = false
})

ACPR:OnChanged(function(state)
    autoClaiming = state
    if not state then return end
    task.spawn(function()
        while autoClaiming do
            for reward = 1, 12 do
                if not autoClaiming then break end
                local success, err = pcall(function()
                    claimGift:InvokeServer(reward)
                end)
                task.wait(0.25)
            end
            task.wait(1)
        end
    end)
end)
Options.ACPR:SetValue(false)

---
--- Auto Rebirth
---
local rebirth = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_knit@1.7.0")
    :WaitForChild("knit")
    :WaitForChild("Services")
    :WaitForChild("RebirthService")
    :WaitForChild("RF")
    :WaitForChild("Rebirth")

local running = false
local AR = Tabs.Farm:AddToggle("AR", {
    Title = "Auto Rebirth",
    Default = false
})

AR:OnChanged(function(state)
    running = state
    if not state then return end
    task.spawn(function()
        while running do
            pcall(function()
                rebirth:InvokeServer()
            end)
            task.wait(1)
        end
    end)
end)
Options.AR:SetValue(false)

---
--- Auto Claim Event Pass Rewards
---
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local claim = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_knit@1.7.0")
    :WaitForChild("knit")
    :WaitForChild("Services")
    :WaitForChild("SeasonPassService")
    :WaitForChild("RF")
    :WaitForChild("ClaimPassReward")

local running = false
local ACEPR = Tabs.Misc:AddToggle("ACEPR", {
    Title = "Auto Claim Event Pass Rewards",
    Default = false
})

ACEPR:OnChanged(function(state)
    running = state
    if not state then return end
    task.spawn(function()
        while running do
            local gui = player:WaitForChild("PlayerGui")
                :WaitForChild("Windows")
                :WaitForChild("Event")
                :WaitForChild("Frame")
                :WaitForChild("Frame")
                :WaitForChild("Windows")
                :WaitForChild("Pass")
                :WaitForChild("Main")
                :WaitForChild("ScrollingFrame")
            for i = 1, 10 do
                if not running then break end
                local item = gui:FindFirstChild(tostring(i))
                if item and item:FindFirstChild("Frame") and item.Frame:FindFirstChild("Free") then
                    local free = item.Frame.Free
                    local locked = free:FindFirstChild("Locked")
                    local claimed = free:FindFirstChild("Claimed")
                    while running and locked and locked.Visible do
                        task.wait(0.2)
                    end
                    if running and claimed and claimed.Visible then
                        continue
                    end
                    if running and locked and not locked.Visible then
                        pcall(function()
                            claim:InvokeServer("Free", i)
                        end)
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end)
Options.ACEPR:SetValue(false)

---
--- Redeem All Codes
---
local redeem = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_knit@1.7.0")
    :WaitForChild("knit")
    :WaitForChild("Services")
    :WaitForChild("CodesService")
    :WaitForChild("RF")
    :WaitForChild("RedeemCode")

local codes = {
    "release",
    "DEVIL",
    "ZEUS"
}

Tabs.Misc:AddButton({
    Title = "Redeem All Codes",
    Callback = function()
        for _, code in ipairs(codes) do
            pcall(function()
                redeem:InvokeServer(code)
            end)
            task.wait(1)
        end
    end
})

---
--- Auto Buy Best Luckyblock
---
local buy = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_knit@1.7.0")
    :WaitForChild("knit")
    :WaitForChild("Services")
    :WaitForChild("SkinService")
    :WaitForChild("RF")
    :WaitForChild("BuySkin")

local skins = {
    "prestige_mogging_luckyblock",
    "mogging_luckyblock",
    "twoface_luckyblock",
    "colossus_luckyblock",
    "inferno_luckyblock",
    "divine_luckyblock",
    "spirit_luckyblock",
    "cyborg_luckyblock",
    "void_luckyblock",
    "gliched_luckyblock",
    "lava_luckyblock",
    "freezy_luckyblock",
    "fairy_luckyblock"
}

local suffix = {
    K = 1e3,
    M = 1e6,
    B = 1e9,
    T = 1e12,
    Qa = 1e15,
    Qi = 1e18,
    Sx = 1e21,
    Sp = 1e24,
    Oc = 1e27,
    No = 1e30,
    Dc = 1e33
}

local function parseCash(text)
    text = text:gsub("%\$", ""):gsub(",", ""):gsub("%s+", "")
    local num = tonumber(text:match("[%d%.]+"))
    local suf = text:match("%a+")
    if not num then return 0 end
    if suf and suffix[suf] then
        return num * suffix[suf]
    end
    return num
end

---
--- Auto Buy Best Luckyblock
---
local running = false
local ABL = Tabs.Misc:AddToggle("ABL", {
    Title = "Auto Buy Best Luckyblock",
    Default = false
})

ABL:OnChanged(function(state)
    running = state
    if not state then return end
    task.spawn(function()
        while running do
            local gui = player.PlayerGui:FindFirstChild("Windows")
            if not gui then
                task.wait(1)
                continue
            end
            local pickaxeShop = gui:FindFirstChild("PickaxeShop")
            if not pickaxeShop then
                task.wait(1)
                continue
            end
            local shopContainer = pickaxeShop:FindFirstChild("ShopContainer")
            if not shopContainer then
                task.wait(1)
                continue
            end
            local scrollingFrame = shopContainer:FindFirstChild("ScrollingFrame")
            if not scrollingFrame then
                task.wait(1)
                continue
            end
            local cash = player.leaderstats.Cash.Value
            local bestSkin = nil
            local bestPrice = 0
            for i = 1, #skins do
                local name = skins[i]
                local item = scrollingFrame:FindFirstChild(name)
                if item then
                    local main = item:FindFirstChild("Main")
                    if main then
                        local buyFolder = main:FindFirstChild("Buy")
                        if buyFolder then
                            local buyButton = buyFolder:FindFirstChild("BuyButton")
                            if buyButton and buyButton.Visible then
                                local cashLabel = buyButton:FindFirstChild("Cash")
                                if cashLabel then
                                    local price = parseCash(cashLabel.Text)
                                    if cash >= price and price > bestPrice then
                                        bestSkin = name
                                        bestPrice = price
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if bestSkin then
                pcall(function()
                    buy:InvokeServer(bestSkin)
                end)
            end
            task.wait(0.5)
        end
    end)
end)
Options.ABL:SetValue(false)

---
--- Sell Held Brainrot
---
Tabs.Misc:AddButton({
    Title = "Sell Held Brainrot",
    Callback = function()
        Window:Dialog({
            Title = "Confirm Sale",
            Content = "Are you sure you want to sell this held Brainrot?",
            Buttons = {
                {
                    Title = "Confirm",
                    Callback = function()
                        local player = game:GetService("Players").LocalPlayer
                        local character = player.Character or player.CharacterAdded:Wait()
                        local tool = character:FindFirstChildOfClass("Tool")
                        if not tool then
                            Fluent:Notify({
                                Title = "ERROR!",
                                Content = "Equip the Brainrot you want to Sell",
                                Duration = 5
                            })
                            return
                        end
                        local entityId = tool:GetAttribute("EntityId")
                        if not entityId then return end
                        local args = { entityId }
                        game:GetService("ReplicatedStorage")
                            :WaitForChild("Packages")
                            :WaitForChild("_Index")
                            :WaitForChild("sleitnick_knit@1.7.0")
                            :WaitForChild("knit")
                            :WaitForChild("Services")
                            :WaitForChild("InventoryService")
                            :WaitForChild("RF")
                            :WaitForChild("SellBrainrot")
                            :InvokeServer(unpack(args))
                        Fluent:Notify({
                            Title = "SOLD!",
                            Content = "Sold: " .. tool.Name,
                            Duration = 5
                        })
                    end
                },
                {
                    Title = "Cancel",
                    Callback = function() end
                }
            }
        })
    end
})

---
--- Pickup All Your Brainrots
---
Tabs.Misc:AddButton({
    Title = "Pickup All Your Brainrots",
    Callback = function()
        Window:Dialog({
            Title = "Confirm Pickup!",
            Content = "Pick up all Brainrots?",
            Buttons = {
                {
                    Title = "Confirm",
                    Callback = function()
                        local player = game:GetService("Players").LocalPlayer
                        local username = player.Name
                        local plotsFolder = workspace:WaitForChild("Plots")
                        local myPlot
                        for i = 1, 5 do
                            local plot = plotsFolder:FindFirstChild(tostring(i))
                            if plot and plot:FindFirstChild(tostring(i)) then
                                local inner = plot[tostring(i)]
                                for _, v in pairs(inner:GetDescendants()) do
                                    if v:IsA("BillboardGui") and string.find(v.Name, username) then
                                        myPlot = inner
                                        break
                                    end
                                end
                            end
                            if myPlot then break end
                        end
                        if not myPlot then return end
                        local containers = myPlot:FindFirstChild("Containers")
                        if not containers then return end
                        for i = 1, 30 do
                            local containerFolder = containers:FindFirstChild(tostring(i))
                            if containerFolder and containerFolder:FindFirstChild(tostring(i)) then
                                local container = containerFolder[tostring(i)]
                                local innerModel = container:FindFirstChild("InnerModel")
                                if innerModel and #innerModel:GetChildren() > 0 then
                                    local args = { tostring(i) }
                                    game:GetService("ReplicatedStorage")
                                        :WaitForChild("Packages")
                                        :WaitForChild("_Index")
                                        :WaitForChild("sleitnick_knit@1.7.0")
                                        :WaitForChild("knit")
                                        :WaitForChild("Services")
                                        :WaitForChild("ContainerService")
                                        :WaitForChild("RF")
                                        :WaitForChild("PickupBrainrot")
                                        :InvokeServer(unpack(args))
                                    task.wait(0.1)
                                end
                            end
                        end
                        Fluent:Notify({
                            Title = "Done!",
                            Content = "Picked up all Brainrots",
                            Duration = 5
                        })
                    end
                },
                {
                    Title = "Cancel",
                    Callback = function() end
                }
            }
        })
    end
})

---
--- Auto Recup Cash
---
local PlaceBest = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_knit@1.7.0")
    :WaitForChild("knit")
    :WaitForChild("Services")
    :WaitForChild("ContainerService")
    :WaitForChild("RF")
    :WaitForChild("PlaceBest")

local autoRecupEyeRunning = false
local AutoRecupEyeToggle = Tabs.Farm:AddToggle("AutoRecupEyeToggle", {
    Title = "Auto Recup Cash",
    Default = false
})

AutoRecupEyeToggle:OnChanged(function(state)
    autoRecupEyeRunning = state
    if state then
        task.spawn(function()
            while autoRecupEyeRunning do
                pcall(function()
                    PlaceBest:InvokeServer()
                end)
                task.wait(20)
            end
        end)
    end
end)
Options.AutoRecupEyeToggle:SetValue(false)

---
--- Sell Section
---
local SellBrainrot = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_knit@1.7.0")
    :WaitForChild("knit")
    :WaitForChild("Services")
    :WaitForChild("InventoryService")
    :WaitForChild("RF")
    :WaitForChild("SellBrainrot")

local Suffixes = {
    K = 1e3, M = 1e6, B = 1e9,
    T = 1e12, QA = 1e15, QI = 1e18,
    SX = 1e21, SP = 1e24, OC = 1e27, NO = 1e30,
}

local AllNames = {
    "67",
    "agarrini_lapalini",
    "angel_bisonte_giuppitere",
    "angel_job_job_sahur",
    "angela_larila",
    "angelinni_octossini",
    "angelzini_bananini",
    "ballerina_cappuccina",
    "ballerino_lololo",
    "bisonte_giuppitere_giuppitercito",
    "blueberrinni_octossini",
    "bobrito_bandito",
    "bombardino_crocodilo",
    "boneca_ambalabu",
    "brr_brr_patapim",
    "burbaloni_luliloli",
    "cacto_hipopotamo",
    "capuccino_assassino",
    "cathinni_sushinni",
    "cavallo_virtuoso",
    "chachechi",
    "chicleteira_bicicleteira",
    "chimpanzini_bananini",
    "cocofanto_elefanto",
    "devilcino_assassino",
    "devilivion",
    "devupat_kepat_prekupat",
    "diavolero_tralala",
    "ding_sahur",
    "dojonini_assassini",
    "dragoni_cannelloni",
    "ferro_sahur",
    "frigo_camello",
    "frulli_frula",
    "ganganzelli_trulala",
    "gangster_foottera",
    "glorbo_frutodrillo",
    "gorgonzilla",
    "gorillo_watermellondrillo",
    "graipus_medus",
    "i2perfectini_foxinini",
    "job_job_job_sahur",
    "karkirkur",
    "ketupat_kepat_prekupat",
    "la_vacca_saturno_saturnita",
    "las_vaquitas_saturnitas",
    "lerulerulerule",
    "lirili_larila",
    "los_crocodillitos",
    "los_tralaleritos",
    "luminous_yoni",
    "magiani_tankiani",
    "malame",
    "malamevil",
    "mateo",
    "meowl",
    "orangutini_ananassini",
    "orcalero_orcala",
    "pipi_potato",
    "pot_hotspot",
    "raccooni_watermelunni",
    "rang_ring_reng",
    "rhino_toasterino",
    "salamino_penguino",
    "spaghetti_tualetti",
    "spioniro_golubiro",
    "strawberrini_octosini",
    "strawberry_elephant",
    "svinina_bombobardino",
    "ta_ta_ta_ta_sahur",
    "te_te_te_te_sahur",
    "ti_ti_ti_sahur",
    "tigrrullini_watermellini",
    "to_to_to_sahur",
    "toc_toc_sahur",
    "torrtuginni_dragonfrutinni",
    "tracoducotulu_delapeladustuz",
    "tralalero_tralala",
    "trippi_troppi_troppa_trippa",
    "trulimero_trulicina",
    "udin_din_din_dun",
    "yoni",
}

local function ParseCashPerSec(str)
    if not str then return 0 end
    str = tostring(str)
    local numPart, suffix = str:match("%+?([%d%.]+)(%a*)%$")
    local num = tonumber(numPart) or 0
    if suffix and suffix ~= "" then
        local mult = Suffixes[suffix:upper()]
        if mult then num = num * mult end
    end
    return num
end

local function GetAllTools()
    local tools = {}
    for _, item in ipairs(Backpack:GetChildren()) do
        if item:IsA("Tool") then table.insert(tools, item) end
    end
    if Player.Character then
        for _, item in ipairs(Player.Character:GetChildren()) do
            if item:IsA("Tool") then table.insert(tools, item) end
        end
    end
    return tools
end

---
--- Auto Sell Brainrots
---
local Toggle = Tabs.Sell:AddToggle("SellToggle", {
    Title = "Auto Sell Brainrots",
    Default = false,
})

local Slider = Tabs.Sell:AddSlider("SellSlider", {
    Title = "Sell Interval (s)",
    Description = "How often it sells",
    Default = 2,
    Min = 0,
    Max = 10,
    Rounding = 0,
})

local FilterDropdown = Tabs.Sell:AddDropdown("FilterDropdown", {
    Title = "Filter What to Sell By",
    Values = {"Mutation", "Cash/s", "Name"},
    Multi = false,
    Default = "Mutation",
})

local MutationDropdown = Tabs.Sell:AddDropdown("MutationDropdown", {
    Title = "Mutations to Sell",
    Values = {"NORMAL", "CANDY", "GOLD", "DIAMOND", "VOID"},
    Multi = true,
    Default = {},
})

local NameDropdown = Tabs.Sell:AddDropdown("NameDropdown", {
    Title = "Names to Sell",
    Values = AllNames,
    Multi = true,
    Default = {},
})

local CashInput = Tabs.Sell:AddInput("CashInput", {
    Title = "Sell Below Cash/s",
    Default = "0",
    Placeholder = "e.g. 1000000",
    Numeric = true,
    Finished = false,
})

local function ShouldSell(tool)
    local filter = Options.FilterDropdown.Value
    if filter == "Mutation" then
        local mutation = tool:GetAttribute("Mutation")
        if not mutation then return false end
        return Options.MutationDropdown.Value[mutation] == true
    elseif filter == "Name" then
        local brainrotType = tool:GetAttribute("BrainrotType")
        if not brainrotType then return false end
        return Options.NameDropdown.Value[brainrotType] == true
    elseif filter == "Cash/s" then
        local cashAttr = tool:GetAttribute("CashPerSec")
        if not cashAttr then return false end
        local toolValue = ParseCashPerSec(tostring(cashAttr))
        local threshold = tonumber(Options.CashInput.Value) or 0
        return toolValue < threshold
    end
    return false
end

local function TrySell(tool)
    local entityId = tool:GetAttribute("EntityId")
    if entityId then
        SellBrainrot:InvokeServer(entityId)
    end
end

task.spawn(function()
    while true do
        local interval = Options.SellSlider.Value
        task.wait(math.max(interval, 0.1))
        if Options.SellToggle.Value then
            for _, tool in ipairs(GetAllTools()) do
                if ShouldSell(tool) then
                    TrySell(tool)
                    task.wait(0.05)
                end
            end
        end
    end
end)

---
--- Webhook Section
---
Tabs.Webhook:AddParagraph({
    Title = "How to Use",
    Content = "1. Paste your Discord webhook URL into the Webhook URL field.\n2. Enable the webhook using the toggle.\n3. Choose what to track in Track Filter — select Mutation, Name, or both.\n4. If tracking Mutations, select which mutations to watch for in the Mutations to Track dropdown.\n5. If tracking Names, select which Brainrot names to watch for in the Names to Track dropdown.\n6. Whenever you receive a new brainrot that matches your filters, a notification will be sent to your Discord webhook."
})

local WebhookToggle = Tabs.Webhook:AddToggle("WebhookToggle", {
    Title = "Enable Webhook",
    Default = false
})
Options.WebhookToggle:SetValue(false)

local enterwebhook = Tabs.Webhook:AddInput("enterwebhook", {
    Title = "Webhook URL",
    Default = "",
    Placeholder = "enter webhook url...",
    Numeric = false,
    Finished = false,
    Callback = function(Value) end
})

local sendfilter = Tabs.Webhook:AddDropdown("sendfilter", {
    Title = "Track Filter",
    Values = {"Mutation", "Name"},
    Multi = true,
    Default = {"Mutation"},
})

local selectmutationswebhook = Tabs.Webhook:AddDropdown("selectmutationswebhook", {
    Title = "Mutations to Track",
    Values = {"NORMAL", "CANDY", "GOLD", "DIAMOND", "VOID"},
    Multi = true,
    Default = {"GOLD"},
})

local excludePrefixes = {"candy_", "gold_", "diamond_", "void_"}
local brainrotModelNames = {}
local brainrotModelsFolder = game:GetService("ReplicatedStorage"):FindFirstChild("BrainrotModels")
if brainrotModelsFolder then
    for _, model in ipairs(brainrotModelsFolder:GetChildren()) do
        if model:IsA("Model") then
            local name = model.Name
            local excluded = false
            for _, prefix in ipairs(excludePrefixes) do
                if name:lower():sub(1, #prefix) == prefix then
                    excluded = true
                    break
                end
            end
            if not excluded then
                table.insert(brainrotModelNames, name)
            end
        end
    end
end

local selectnameswebhook = Tabs.Webhook:AddDropdown("selectnameswebhook", {
    Title = "Names to Track",
    Values = brainrotModelNames,
    Multi = true,
    Default = {},
})

local recentlySent = {}
local function SendWebhook(url, content)
    if not url or url == "" then return end
    pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode({
                content = "@everyone " .. content,
                allowed_mentions = { parse = {"everyone"} }
            })
        })
    end)
end

local function CheckTool(tool)
    if not Options.WebhookToggle.Value then return end
    if recentlySent[tool] then return end
    recentlySent[tool] = true
    task.delay(2, function()
        recentlySent[tool] = nil
    end)
    local webhookURL = Options.enterwebhook.Value
    local modes = Options.sendfilter.Value
    local mutations = Options.selectmutationswebhook.Value
    local selectedNames = Options.selectnameswebhook.Value
    if modes["Mutation"] then
        local toolMutation = tool:GetAttribute("Mutation")
        if toolMutation and mutations[tostring(toolMutation):upper()] then
            SendWebhook(webhookURL, string.format(
                "💎 **Mutation Match!**\nTool: `%s`\nMutation: `%s`",
                tool.Name, tostring(toolMutation)
            ))
        end
    end
    if modes["Name"] then
        local brainrotType = tool:GetAttribute("BrainrotType")
        if brainrotType then
            for name, selected in next, selectedNames do
                if selected and tostring(brainrotType):lower() == name:lower() then
                    SendWebhook(webhookURL, string.format(
                        "🔔 **Name Match!**\nTool: `%s`\nBrainrotType: `%s`",
                        tool.Name, tostring(brainrotType)
                    ))
                    break
                end
            end
        end
    end
end

local function WatchContainer(container)
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then
            CheckTool(child)
        end
    end
    container.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait()
            CheckTool(child)
        end
    end)
end

local LocalPlayer = Players.LocalPlayer
WatchContainer(LocalPlayer.Backpack)

local function OnCharacterAdded(character)
    WatchContainer(character)
end

if LocalPlayer.Character then
    OnCharacterAdded(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

---
--- Quests Section
---
Tabs.Farm:AddSection("Quests")

local questRunning = false

local function getQuestFrame(questType)
    local gui = LocalPlayer.PlayerGui
    local base = gui.Windows.Event.Frame.Frame.Windows.Quests.Frame.ScrollingFrame
    if questType == "Daily" then
        return base.DailyQuests.Frame.Frame.Frame
    else
        return base.HourlyQuests.Frame.Frame.Frame
    end
end

local function getUnclaimedQuests()
    local quests = {}
    for _, questType in ipairs({"Hourly", "Daily"}) do
        local frame = getQuestFrame(questType)
        if frame then
            for _, child in ipairs(frame:GetChildren()) do
                local claimed = child:FindFirstChild("Claimed")
                local title = child:FindFirstChild("Title")
                if claimed and title and not claimed.Visible then
                    table.insert(quests, {
                        claimed = claimed,
                        text = title.Text
                    })
                end
            end
        end
    end
    return quests
end

local function getMyPlotNumbers()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil, nil end
    for i = 1, 5 do
        for j = 1, 5 do
            local row = plots:FindFirstChild(tostring(i))
            local plot = row and row:FindFirstChild(tostring(j))
            if plot then
                for _, obj in ipairs(plot:GetChildren()) do
                    if obj:IsA("BillboardGui") and obj.Name:find(LocalPlayer.Name) then
                        return tostring(i), tostring(j)
                    end
                end
            end
        end
    end
    return nil, nil
end

local function farmLoop(claimedButton, stopCondition)
    local modelsFolder = workspace:WaitForChild("RunningModels")
    local target = workspace:WaitForChild("CollectZones"):WaitForChild(selectedBase) -- Utilise la base sélectionnée
    while questRunning and not claimedButton.Visible do
        if stopCondition and stopCondition() then break end
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local root = character:WaitForChild("HumanoidRootPart")
        local humanoid = character:WaitForChild("Humanoid")
        root.CFrame = CFrame.new(715, 39, -2122)
        task.wait(0.3)
        if not questRunning then return end
        humanoid:MoveTo(Vector3.new(709, 39, -2122))
        local ownedModel = nil
        repeat
            task.wait(0.3)
            if not questRunning then return end
            for _, obj in ipairs(modelsFolder:GetChildren()) do
                if obj:IsA("Model") and obj:GetAttribute("OwnerId") == LocalPlayer.UserId then
                    ownedModel = obj
                    break
                end
            end
        until ownedModel ~= nil or not questRunning or claimedButton.Visible
        if not questRunning or claimedButton.Visible then return end
        task.wait(0.2)
        if ownedModel.PrimaryPart then
            ownedModel:SetPrimaryPartCFrame(target.CFrame)
        else
            local part = ownedModel:FindFirstChildWhichIsA("BasePart")
            if part then part.CFrame = target.CFrame end
        end
        task.wait(0.7)
        if not questRunning then return end
        if ownedModel and ownedModel.Parent == modelsFolder then
            if ownedModel.PrimaryPart then
                ownedModel:SetPrimaryPartCFrame(target.CFrame * CFrame.new(0, -8, 0))
            else
                local part = ownedModel:FindFirstChildWhichIsA("BasePart")
                if part then part.CFrame = target.CFrame * CFrame.new(0, -8, 0) end
            end
        end
        repeat
            task.wait(0.4)
            if not questRunning then return end
        until claimedButton.Visible or (ownedModel == nil or ownedModel.Parent ~= modelsFolder)
        if not questRunning or claimedButton.Visible then return end
        local oldCharacter = LocalPlayer.Character
        repeat
            task.wait(0.3)
            if not questRunning then return end
        until claimedButton.Visible or (LocalPlayer.Character ~= oldCharacter and LocalPlayer.Character ~= nil)
        if not questRunning or claimedButton.Visible then return end
        task.wait(0.4)
    end
end

local function doGetBrainrotsQuest(claimedButton)
    farmLoop(claimedButton, nil)
end

local function doMutationQuest(claimedButton, mutation)
    local gotTool = false
    local function checkTool(tool)
        if claimedButton.Visible then return end
        local mut = tool:GetAttribute("Mutation")
        if mut and tostring(mut):upper() == mutation:upper() then
            gotTool = true
        end
    end
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local toolConn = backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then checkTool(child) end
    end)
    local charConn
    if LocalPlayer.Character then
        charConn = LocalPlayer.Character.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then checkTool(child) end
        end)
    end
    farmLoop(claimedButton, function() return gotTool end)
    toolConn:Disconnect()
    if charConn then charConn:Disconnect() end
end

local function doLevelUpQuest(claimedButton, times)
    if not questRunning then return end
    local pi, pj = getMyPlotNumbers()
    if not pi or not pj then return end
    local containers = workspace.Plots[pi][pj]:FindFirstChild("Containers")
    if not containers then return end
    local remote = game:GetService("ReplicatedStorage")
        :WaitForChild("Packages")
        :WaitForChild("_Index")
        :WaitForChild("sleitnick_knit@1.7.0")
        :WaitForChild("knit")
        :WaitForChild("Services")
        :WaitForChild("ContainerService")
        :WaitForChild("RF")
        :WaitForChild("UpgradeBrainrot")
    local done = 0
    for i = 1, 30 do
        if not questRunning or claimedButton.Visible or done >= times then break end
        local containerSlot = containers:FindFirstChild(tostring(i))
        if containerSlot then
            for j = 1, 30 do
                if not questRunning or claimedButton.Visible or done >= times then break end
                local innerSlot = containerSlot:FindFirstChild(tostring(j))
                if innerSlot then
                    local innerModelFolder = innerSlot:FindFirstChild("InnerModel")
                    local collection = innerSlot:FindFirstChild("Collection")
                    local collectionPad = collection and collection:FindFirstChild("CollectionPad")
                    if innerModelFolder and collectionPad and collectionPad.Color == Color3.fromRGB(64, 203, 0) then
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.CFrame = collectionPad.CFrame + Vector3.new(0, 3, 0)
                        end
                        task.wait(0.3)
                        if not questRunning then return end
                        for _ = 1, times do
                            if not questRunning or claimedButton.Visible or done >= times then break end
                            pcall(function()
                                remote:InvokeServer(tostring(i))
                            end)
                            done = done + 1
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end
end

local function parseQuestText(text)
    local brainrotCount = text:match("Get (%d+) Brainrots?$")
    if brainrotCount then
        return "brainrots", tonumber(brainrotCount)
    end
    local levelCount = text:match("[Ll]evel up [Bb]rainrots? (%d+) times?")
    if levelCount then
        return "levelup", tonumber(levelCount)
    end
    local count, mutation = text:match("Get (%d+) (%w+) Brainrots?")
    if count and mutation then
        local validMutations = {NORMAL=true, CANDY=true, GOLD=true, DIAMOND=true, VOID=true}
        if validMutations[mutation:upper()] then
            return "mutation", tonumber(count), mutation:upper()
        end
    end
    return "unknown"
end

local function runQuests()
    questRunning = true
    local quests = getUnclaimedQuests()
    for _, quest in ipairs(quests) do
        if not questRunning then break end
        if quest.claimed.Visible then continue end
        local questType, value, extra = parseQuestText(quest.text)
        if questType == "brainrots" then
            doGetBrainrotsQuest(quest.claimed)
        elseif questType == "levelup" then
            doLevelUpQuest(quest.claimed, value)
        elseif questType == "mutation" then
            doMutationQuest(quest.claimed, extra)
        end
        task.wait(0.5)
    end
    questRunning = false
end

local QuestToggle = Tabs.Farm:AddToggle("QuestToggle", {
    Title = "Auto Complete BP Quests",
    Default = false
})

QuestToggle:OnChanged(function(state)
    if state then
        if not questRunning then
            task.spawn(runQuests)
        end
    else
        questRunning = false
    end
end)
Options.QuestToggle:SetValue(false)

---
--- Brainrot Upgrades Section
---
Tabs.Upgrades:AddSection("Brainrot Upgrades")

local upgradeRunning = false
local upgradeLevel = 3

local LevelSlider = Tabs.Upgrades:AddSlider("UpgradeLevelSlider", {
    Title = "Max Upgrade Level",
    Default = 25,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Callback = function(Value)
        upgradeLevel = Value
    end
})

LevelSlider:OnChanged(function(Value)
    upgradeLevel = Value
end)
LevelSlider:SetValue(3)

local remote = game:GetService("ReplicatedStorage")
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("sleitnick_knit@1.7.0")
    :WaitForChild("knit")
    :WaitForChild("Services")
    :WaitForChild("ContainerService")
    :WaitForChild("RF")
    :WaitForChild("UpgradeBrainrot")

local function runUpgrades()
    local pi, pj = getMyPlotNumbers()
    if not pi or not pj then return end
    local containers = workspace.Plots[pi][pj]:FindFirstChild("Containers")
    if not containers then return end
    while upgradeRunning do
        local anyUpgraded = false
        for i = 1, 30 do
            if not upgradeRunning then return end
            local containerSlot = containers:FindFirstChild(tostring(i))
            if not containerSlot then continue end
            for j = 1, 30 do
                if not upgradeRunning then return end
                local innerSlot = containerSlot:FindFirstChild(tostring(j))
                if not innerSlot then continue end
                local innerModel = innerSlot:FindFirstChild("InnerModel")
                if not innerModel then continue end
                local brainrot = innerModel:FindFirstChildWhichIsA("Model")
                if not brainrot then continue end
                local level = brainrot:GetAttribute("BrainrotLevel")
                if not level then continue end
                if level < upgradeLevel then
                    local currentLevel = brainrot:GetAttribute("BrainrotLevel")
                    if currentLevel and currentLevel < upgradeLevel then
                        local args = { tostring(i) }
                        pcall(function()
                            remote:InvokeServer(unpack(args))
                        end)
                        anyUpgraded = true
                        task.wait(0.3)
                    end
                end
            end
        end
        if not anyUpgraded then
            task.wait(1)
        end
    end
end

local UpgradeToggle = Tabs.Upgrades:AddToggle("UpgradeToggle", {
    Title = "Auto Upgrade Brainrots",
    Default = false
})

UpgradeToggle:OnChanged(function(state)
    upgradeRunning = state
    if state then
        task.spawn(runUpgrades)
    end
end)
Options.UpgradeToggle:SetValue(false)

---
---
--- Save and Load Config
---
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder("FluentScriptHub/specific-game")
Tabs.Settings:AddSection("Credits")
Tabs.Settings:AddParagraph({
    Title = "Mango Hub Credits",
    Content = "Script by linkoro57\nUI design by Olemad"
})
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
