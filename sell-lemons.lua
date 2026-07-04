-- Fluent UI Setup
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

local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local fireClickDetector = type(fireclickdetector) == "function" and fireclickdetector or nil
local fireProximityPrompt = type(fireproximityprompt) == "function" and fireproximityprompt or nil

local function req(path)
    local ok, module = pcall(require, path)
    return ok and module or nil
end

local Tycoon = req(RS.Modules.Tycoon.Tycoon)
local TycoonBalances = req(RS.Modules.Tycoon.Component.TycoonBalances)
local ClientTycoonBalances = req(RS.Modules.Tycoon.Component.Client.ClientTycoonBalances)
local ClientTycoonRebirth = req(RS.Modules.Tycoon.Component.Client.ClientTycoonRebirth)
local ClientTycoonAscension = req(RS.Modules.Tycoon.Component.Client.ClientTycoonAscension)
local ClientTycoonEvolution = req(RS.Modules.Tycoon.Component.Client.ClientTycoonEvolution)
local ClientTycoonIncome = req(RS.Modules.Tycoon.Component.Client.ClientTycoonIncome)
local ClientTycoonPowers = req(RS.Modules.Tycoon.Component.Client.ClientTycoonPowers)
local ClientTycoonPhoneOffers = req(RS.Modules.Tycoon.Component.Client.ClientTycoonPhoneOffers)
local Orchard = req(RS.Modules.Tycoon.Orchard.Orchard)
local OrchardPlot = req(RS.Modules.Tycoon.Orchard.Client.ClientOrchardPlot)
local OrchardFruits = req(RS.Modules.Tycoon.Orchard.Client.ClientOrchardFruits)
local RemoteSignal = req(RS.Core.RemoteSignal)
local RemoteRequest = req(RS.Core.RemoteRequest)
local Entity = req(RS.Core.Entity)
local Huge = req(RS.Modules.Huge)
local Config = req(RS.Config)

local state = {
    AutoBuy = false,
    AutoUpgradeEarners = false,
    AutoUpgradePowers = false,
    AutoWake = false,
    AutoCashDrop = false,
    AutoPhone = false,
    AutoFruit = false,
    AutoRebirth = false,
    AutoEvolve = false,
    AutoAscend = false,
    AutoOrchardHarvest = false,
    AutoOrchardSell = false,
    AutoSewerCashVine = false,
    AntiAFK = false,
    SpeedOn = false,
    SpeedVal = 16,
}
local scriptAlive = true

local cacheRoot, buyCache, earnerCache = nil, {}, {}
local fruitCache, savedCFrame = {}, nil
local powerRetryAt = {}
local purchaseRetryAt = {}
local earnerRetryAt = {}
local wakeRetryAt = {}
local sidegameRetryAt = {}
local phoneCooldown = 0
local cacheRefreshAt = 0
local statsRefreshAt = 0
local orchardRefreshAt = 0
local sewerRefreshAt = 0
local status = {
    cash = "--",
    investors = "--",
    rebirths = "--",
    evolve = "--",
    actions = "idle",
}
local orchardPlotCache = {}
local sewerPromptCache = {
    levers = {},
    cash = {},
}

local function getTycoon()
    return Tycoon and Tycoon.getLocal()
end

local function getRootPart()
    local character = LP.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function afford(price, current)
    local ok, result = pcall(function()
        return price ~= nil and price <= current
    end)
    return ok and result
end

local suffixPowers = {
    K = 3,
    M = 6,
    B = 9,
    T = 12,
    QA = 15,
    QI = 18,
    SX = 21,
    SP = 24,
    OC = 27,
    NO = 30,
    DC = 33,
}

local function parseDisplayNumber(text)
    if type(text) ~= "string" then
        return nil
    end

    local cleaned = text:upper():gsub(",", ""):gsub("%s+", "")
    if cleaned == "" or cleaned == "--" then
        return nil
    end

    for _, parserName in { "fromString", "parse", "Parse" } do
        local parser = Huge and Huge[parserName]
        if type(parser) == "function" then
            local ok, value = pcall(function()
                return parser(cleaned)
            end)
            if not ok or value == nil then
                ok, value = pcall(function()
                    return parser(Huge, cleaned)
                end)
            end
            if ok and value ~= nil then
                return value
            end
        end
    end

    local direct = tonumber(cleaned)
    if direct then
        return direct
    end

    local baseText, suffix = cleaned:match("^([%+%-]?%d*%.?%d+)([A-Z]+)$")
    local base = tonumber(baseText)
    local power = suffix and suffixPowers[suffix]
    if base and power then
        return base * (10 ^ power)
    end

    return nil
end

local function getRebirthUiValues()
    local playerGui = LP and LP:FindFirstChild("PlayerGui")
    local rebirthGui = playerGui and playerGui:FindFirstChild("Rebirth")
    local investorsMenu = rebirthGui and rebirthGui:FindFirstChild("InvestorsMenu")
    local body = investorsMenu and investorsMenu:FindFirstChild("Body")
    if not body then
        return nil
    end

    local amount = body:FindFirstChild("Amount")
    local potential = body:FindFirstChild("Potential")
    local bonus = body:FindFirstChild("Bonus")

    local amountLabel = amount and amount:FindFirstChild("Quantity")
    local potentialLabel = potential and potential:FindFirstChild("Quantity")
    local bonusLabel = bonus and bonus:FindFirstChild("Quantity")
    if not (amountLabel and potentialLabel) then
        return nil
    end

    return {
        currentText = amountLabel.Text,
        potentialText = potentialLabel.Text,
        bonusText = bonusLabel and bonusLabel.Text or nil,
        current = parseDisplayNumber(amountLabel.Text),
        potential = parseDisplayNumber(potentialLabel.Text),
        bonus = bonusLabel and parseDisplayNumber(bonusLabel.Text) or nil,
    }
end

local function refreshCaches(tycoon)
    if not tycoon or not tycoon.Instance then
        return
    end

    local now = os.clock()
    if cacheRoot == tycoon.Instance and (#buyCache > 0 or #earnerCache > 0) and now < cacheRefreshAt then
        return
    end

    cacheRefreshAt = now + 4
    cacheRoot, buyCache, earnerCache = tycoon.Instance, {}, {}

    for _, instance in CollectionService:GetTagged("Tycoon.Purchase") do
        if instance:IsDescendantOf(cacheRoot) then
            table.insert(buyCache, instance)
        end
    end

    for _, instance in CollectionService:GetTagged("Tycoon.Earner") do
        if instance:IsDescendantOf(cacheRoot) then
            table.insert(earnerCache, instance)
        end
    end
end

local function isPurchaseReady(instance)
    return instance
        and instance.Parent
        and instance:GetAttribute("Shown")
        and not instance:GetAttribute("Purchased")
        and instance:GetAttribute("Enabled") ~= false
end

local function isEarnerReady(instance)
    return instance and instance.Parent and instance:GetAttribute("Enabled") ~= false
end

local function anyAutomationEnabled()
    return state.AutoBuy
        or state.AutoUpgradeEarners
        or state.AutoUpgradePowers
        or state.AutoWake
        or state.AutoCashDrop
        or state.AutoPhone
        or state.AutoFruit
        or state.AutoRebirth
        or state.AutoEvolve
        or state.AutoAscend
        or state.AutoOrchardHarvest
        or state.AutoOrchardSell
        or state.AutoSewerCashVine
end

local function anySidegameEnabled()
    return state.AutoOrchardHarvest
        or state.AutoOrchardSell
        or state.AutoSewerCashVine
end

local function getLocalOrchard(tycoon)
    if not (tycoon and Orchard and Orchard.getFromTycoon) then
        return nil
    end

    local ok, orchard = pcall(function()
        return Orchard.getFromTycoon(tycoon)
    end)
    return ok and orchard or nil
end

local function refreshOrchardPlots(tycoon)
    local orchard = getLocalOrchard(tycoon)
    if not orchard or not orchard.Instance then
        orchardPlotCache = {}
        return nil
    end

    local now = os.clock()
    if now < orchardRefreshAt and #orchardPlotCache > 0 then
        return orchard
    end

    orchardRefreshAt = now + 3
    orchardPlotCache = {}

    for _, instance in CollectionService:GetTagged("Tycoon.OrchardPlot") do
        if instance:IsDescendantOf(orchard.Instance) then
            table.insert(orchardPlotCache, instance)
        end
    end

    return orchard
end

local function refreshSewerPrompts()
    local now = os.clock()
    if now < sewerRefreshAt and (#sewerPromptCache.levers + #sewerPromptCache.cash) > 0 then
        return
    end

    sewerRefreshAt = now + 5
    sewerPromptCache = {
        levers = {},
        cash = {},
    }

    local sewer = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Sewer")
    if not sewer then
        return
    end

    for _, descendant in sewer:GetDescendants() do
        if descendant:IsA("ProximityPrompt") then
            local fullName = descendant:GetFullName()
            if descendant.Name == "PullPrompt" then
                table.insert(sewerPromptCache.levers, descendant)
            elseif fullName:find("CashVine") then
                table.insert(sewerPromptCache.cash, descendant)
            end
        end
    end
end

local function teleportToSewerLever(colorName)
    local hrp = getRootPart()
    local sewer = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Sewer")
    if not (hrp and sewer) then
        return
    end

    local leverModel = sewer:FindFirstChild("Doors" .. colorName)
    local lever = leverModel and leverModel:FindFirstChild("Lever (" .. colorName .. ")", true)
    local root = lever and lever:FindFirstChild("Root")
    if root and root:IsA("BasePart") then
        hrp.CFrame = root.CFrame + Vector3.new(0, 4, 0)
    end
end

local function triggerPrompt(prompt, cooldown)
    if not (prompt and prompt.Parent and fireProximityPrompt) then
        return false
    end
    if prompt.Enabled == false or prompt:GetAttribute("Disabled") == true then
        return false
    end

    local now = os.clock()
    if (sidegameRetryAt[prompt] or 0) > now then
        return false
    end

    local ok = pcall(function()
        fireProximityPrompt(prompt)
    end)
    sidegameRetryAt[prompt] = now + (ok and (cooldown or 0.5) or 2)
    return ok
end

local function doOrchardHarvest(tycoon)
    if not OrchardPlot then
        return
    end

    refreshOrchardPlots(tycoon)
    local readyState = OrchardPlot.States and OrchardPlot.States.FruitReady
    if not readyState then
        return
    end

    for _, instance in orchardPlotCache do
        if not state.AutoOrchardHarvest then
            return
        end

        local plot = OrchardPlot.getUnsafe and OrchardPlot.getUnsafe(instance)
        if plot and plot:GetState() == readyState then
            local key = "orchard-harvest:" .. tostring(instance:GetDebugId())
            local now = os.clock()
            if (sidegameRetryAt[key] or 0) <= now then
                local okHarvest = pcall(function()
                    plot:HarvestAsync()
                end)
                sidegameRetryAt[key] = now + (okHarvest and 0.25 or 1.5)
            end
        end
    end
end

local function doOrchardSell(tycoon)
    local orchard = getLocalOrchard(tycoon)
    if not orchard or not OrchardFruits then
        return
    end

    local fruits = orchard:GetComponent(OrchardFruits)
    if not fruits then
        return
    end

    local payload = {}
    local total = 0
    for _, entry in ipairs(fruits:GetAll()) do
        if entry.Fruit and type(entry.Count) == "number" and entry.Count > 0 then
            payload[entry.Fruit] = entry.Count
            total = total + entry.Count
        end
    end

    if total <= 0 then
        return
    end

    local now = os.clock()
    if (sidegameRetryAt.orchardSell or 0) > now then
        return
    end

    local okSell = pcall(function()
        fruits:SellFruitsAsync(payload)
    end)
    sidegameRetryAt.orchardSell = now + (okSell and 1 or 3)
end

local function doSewerPrompts(list, cooldown)
    for _, prompt in ipairs(list) do
        if triggerPrompt(prompt, cooldown) then
            task.wait(0.05)
        end
    end
end

local function updateStatusSnapshot(tycoon)
    local now = os.clock()
    if now < statsRefreshAt then
        return
    end

    statsRefreshAt = now + 0.5

    pcall(function()
        local balances = tycoon:GetComponent(ClientTycoonBalances) or tycoon:GetComponent(TycoonBalances)
        if balances then
            pcall(function()
                status.cash = Huge.formatShort(balances:GetCash())
            end)
            pcall(function()
                status.investors = Huge.formatShort(balances:GetInvestors())
            end)
        end

        local rebirth = tycoon:GetComponent(ClientTycoonRebirth)
        if rebirth then
            pcall(function()
                status.rebirths = tostring(rebirth:GetRebirths())
            end)
        end

        local evolution = tycoon:GetComponent(ClientTycoonEvolution)
        if evolution then
            pcall(function()
                status.evolve = string.format("%.0f%%", math.clamp(evolution:GetEvolutionProgress() * 100, 0, 100))
            end)
        end
    end)
end

local function doAutoBuy(tycoon)
    local balances = tycoon:GetComponent(ClientTycoonBalances) or tycoon:GetComponent(TycoonBalances)
    if not balances then
        return
    end

    local now = os.clock()
    local cash = balances:GetCash()

    for _, instance in buyCache do
        if not state.AutoBuy then
            return
        end

        if (purchaseRetryAt[instance] or 0) > now then
            continue
        end

        if isPurchaseReady(instance) then
            local entity = Entity.getUnsafe(instance)
            if entity then
                local okPrice, price = pcall(function()
                    return entity:GetPrice()
                end)

                if okPrice and price and afford(price, cash) then
                    local okPurchase = pcall(function()
                        entity:TryPurchaseAsync(false)
                    end)
                    purchaseRetryAt[instance] = okPurchase and (now + 0.15) or (now + 2)
                    if okPurchase then
                        cash = balances:GetCash()
                    end
                else
                    purchaseRetryAt[instance] = now + (okPrice and 0.35 or 1.5)
                end
            end
        else
            purchaseRetryAt[instance] = nil
        end
    end
end

local function doUpgradeEarners(tycoon)
    local balances = tycoon:GetComponent(TycoonBalances)
    if not balances then
        return
    end

    local now = os.clock()
    local cash = balances:GetCash()

    for _, instance in earnerCache do
        if not state.AutoUpgradeEarners then
            return
        end

        if (earnerRetryAt[instance] or 0) > now then
            continue
        end

        if not isEarnerReady(instance) then
            earnerRetryAt[instance] = nil
            continue
        end

        local entity = Entity.getUnsafe(instance)
        if entity then
            local okLevel, level = pcall(function()
                return entity:GetUpgradeLevel()
            end)

            if okLevel then
                local okUpgrade, _, count = pcall(function()
                    return entity:GetUpgradePrice(level, math.huge, cash)
                end)

                if okUpgrade and count and count > 0 then
                    local okApply = pcall(function()
                        entity:UpgradeAsync(count)
                    end)
                    earnerRetryAt[instance] = okApply and (now + 0.2) or (now + 2)
                    if okApply then
                        cash = balances:GetCash()
                    end
                else
                    earnerRetryAt[instance] = now + 0.6
                end
            else
                earnerRetryAt[instance] = now + 1.5
            end
        end
    end
end

local function doUpgradePowers(tycoon)
    local balances = tycoon:GetComponent(ClientTycoonBalances)
    if not balances then
        return
    end

    local powers = tycoon:GetComponent(ClientTycoonPowers)
    if not (powers and Config) then
        return
    end

    for name in pairs(Config.Powers) do
        if not state.AutoUpgradePowers then
            return
        end

        local now = os.clock()
        if (powerRetryAt[name] or 0) > now then
            continue
        end

        local okLevel, level = pcall(function()
            return powers:GetLevel(name)
        end)
        local okMax, maxLevel = pcall(function()
            return powers:GetMaxLevel(name)
        end)

        if okLevel and okMax and maxLevel and level < maxLevel then
            local okPrice, price = pcall(function()
                return powers:GetUpgradePrice(name)
            end)
            local okInvestors, investors = pcall(function()
                return balances:GetInvestors()
            end)

            if okPrice and price and okInvestors and afford(price, investors) then
                local okUpgrade = pcall(function()
                    powers:UpgradeAsync(name)
                end)
                powerRetryAt[name] = okUpgrade and (now + 0.2) or (now + 8)
            elseif okPrice and not price then
                powerRetryAt[name] = now + 4
            end
        else
            powerRetryAt[name] = nil
        end
    end
end

local function doWake(tycoon)
    local income = tycoon:GetComponent(ClientTycoonIncome)
    if not income then
        return
    end

    local now = os.clock()

    for _, instance in earnerCache do
        if not state.AutoWake then
            return
        end

        if (wakeRetryAt[instance] or 0) > now then
            continue
        end

        if not isEarnerReady(instance) then
            wakeRetryAt[instance] = nil
            continue
        end

        local entity = Entity.getUnsafe(instance)
        if entity and entity.WakeAsync and not income:IsStreamAutomatic(entity.Name) then
            local okNext, nextEarn = pcall(function()
                return entity:GetEstimatedNextEarnTime()
            end)

            if okNext and nextEarn and nextEarn > 0 then
                wakeRetryAt[instance] = now + math.min(nextEarn, 2)
            else
                local okWake = pcall(function()
                entity:WakeAsync()
                end)
                wakeRetryAt[instance] = okWake and (now + 0.35) or (now + 2)
            end
        else
            wakeRetryAt[instance] = now + 5
        end
    end
end

local function doPhone(tycoon)
    if os.clock() < phoneCooldown then
        return
    end

    local offers = tycoon:GetComponent(ClientTycoonPhoneOffers)
    if not offers then
        return
    end

    local okOffer, offer = pcall(function()
        return offers:GetCurrentOffer()
    end)

    if okOffer and type(offer) == "number" then
        pcall(function()
            offers:AcceptOffer()
        end)
        phoneCooldown = os.clock() + 1.5
    end
end

local function tryRebirth(tycoon)
    local rebirth = tycoon:GetComponent(ClientTycoonRebirth)
    if not rebirth then
        return
    end

    local uiValues = getRebirthUiValues()
    if uiValues and uiValues.current ~= nil and uiValues.potential ~= nil then
        local okReady, ready = pcall(function()
            return 0 < uiValues.current and uiValues.current <= uiValues.potential
        end)

        if okReady and ready then
            pcall(function()
                rebirth:RebirthAsync(false)
            end)
        end
        return
    end

    local balances = tycoon:GetComponent(ClientTycoonBalances) or tycoon:GetComponent(TycoonBalances)
    if not balances then
        return
    end

    local okInvestors, investors = pcall(function()
        return balances:GetInvestors()
    end)
    if not okInvestors then
        return
    end

    local okPotential, potential = pcall(function()
        return rebirth:GetPotentialInvestors()
    end)
    if not okPotential then
        return
    end

    local okReady, ready = pcall(function()
        return 0 < investors and investors <= potential
    end)

    if okReady and ready then
        pcall(function()
            rebirth:RebirthAsync(false)
        end)
    end
end

local function tryEvolve(tycoon)
    local evolution = tycoon:GetComponent(ClientTycoonEvolution)
    if not evolution then
        return
    end

    local okProgress, progress = pcall(function()
        return evolution:GetEvolutionProgress()
    end)

    if okProgress and type(progress) == "number" and progress >= 1 then
        pcall(function()
            evolution:EvolveAsync()
        end)
    end
end

local function tryAscend(tycoon)
    local ascension = tycoon:GetComponent(ClientTycoonAscension)
    if not ascension then
        return
    end

    local okDiscovered, discovered = pcall(function()
        return ascension:IsDiscovered()
    end)
    if not (okDiscovered and discovered) then
        return
    end

    local okAscension, progress = pcall(function()
        return ascension:GetAscension()
    end)

    if okAscension and type(progress) == "number" and progress >= 1 then
        pcall(function()
            ascension:AscendAsync()
        end)
    end
end

local function gatherFruit()
    fruitCache = {}
    local tycoon = getTycoon()
    local localTycoon = tycoon and tycoon.Instance
    if not localTycoon then
        return
    end

    local seen = {}

    for _, descendant in localTycoon:GetDescendants() do
        if descendant:IsA("BasePart") and descendant.Parent and descendant.Parent.Name == "Fruit" then
            local isFruitClickPart = descendant.Name == "ClickPart" or descendant.Name == "ClickFruitPart"
            local detector = isFruitClickPart and descendant:FindFirstChildOfClass("ClickDetector")

            if not detector then
                detector = descendant:FindFirstChildWhichIsA("ClickDetector", true)
            end

            if detector and not seen[detector] then
                seen[detector] = true
                table.insert(fruitCache, { part = descendant, cd = detector })
            end
        end
    end
end

do
    local okRedeem, redeem = pcall(function()
        return RemoteRequest.new("CashDropService.Redeem")
    end)
    local okSignal, newSignal = pcall(function()
        return RemoteSignal.new("CashDropService.New")
    end)

    if okRedeem and okSignal and redeem and newSignal then
        newSignal.OnClientEvent:Connect(function(id)
            if state.AutoCashDrop and id ~= nil then
                pcall(function()
                    redeem:InvokeServer(id)
                end)
            end
        end)
    end
end

do
    local virtualUser = game:GetService("VirtualUser")
    LP.Idled:Connect(function()
        if state.AntiAFK then
            pcall(function()
                virtualUser:CaptureController()
                virtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
end

RunService.Heartbeat:Connect(function()
    if not scriptAlive then
        return
    end
    if state.SpeedOn then
        local character = LP.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.WalkSpeed ~= state.SpeedVal then
            humanoid.WalkSpeed = state.SpeedVal
        end
    end
end)

task.spawn(function()
    local index = 1

    while scriptAlive do
        if state.AutoFruit then
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not savedCFrame and hrp then
                savedCFrame = hrp.CFrame
                gatherFruit()
                index = 1
            end

            if hrp and #fruitCache > 0 then
                local fruit = fruitCache[index]
                if fruit and fruit.part and fruit.part.Parent then
                    hrp.CFrame = CFrame.new(fruit.part.Position + Vector3.new(0, 4, 0))
                    task.wait(0.1)

                    local origin = hrp.Position
                    for _, candidate in fruitCache do
                        if candidate.part and candidate.part.Parent and (candidate.part.Position - origin).Magnitude <= candidate.cd.MaxActivationDistance then
                            if fireClickDetector then
                                pcall(function()
                                    fireClickDetector(candidate.cd)
                                end)
                            end
                        end
                    end
                end

                index = index + 8
                if index > #fruitCache then
                    index = 1
                end
            end

            task.wait(0.05)
        else
            if savedCFrame then
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    pcall(function()
                        hrp.CFrame = savedCFrame
                    end)
                end
                savedCFrame = nil
            end

            task.wait(0.2)
        end
    end
end)

local updateUi = function() end

local function startLogicLoop()
    task.spawn(function()
        while scriptAlive do
            local tycoon = getTycoon()
            if tycoon then
                local automationEnabled = anyAutomationEnabled()
                local actions = {}

                if automationEnabled then
                    if state.AutoBuy or state.AutoUpgradeEarners or state.AutoWake then
                        refreshCaches(tycoon)
                    end
                    if anySidegameEnabled() then
                        refreshSewerPrompts()
                        refreshOrchardPlots(tycoon)
                    end

                    pcall(function()
                        if state.AutoBuy then
                            doAutoBuy(tycoon)
                            table.insert(actions, "buy")
                        end
                        if state.AutoUpgradeEarners then
                            doUpgradeEarners(tycoon)
                            table.insert(actions, "upg")
                        end
                        if state.AutoUpgradePowers then
                            doUpgradePowers(tycoon)
                            table.insert(actions, "pow")
                        end
                        if state.AutoWake then
                            doWake(tycoon)
                            table.insert(actions, "wake")
                        end
                        if state.AutoPhone then
                            doPhone(tycoon)
                            table.insert(actions, "deal")
                        end
                        if state.AutoFruit then
                            table.insert(actions, "fruit")
                        end
                        if state.AutoRebirth then
                            tryRebirth(tycoon)
                            table.insert(actions, "rebirth")
                        end
                        if state.AutoEvolve then
                            tryEvolve(tycoon)
                            table.insert(actions, "evolve")
                        end
                        if state.AutoAscend then
                            tryAscend(tycoon)
                            table.insert(actions, "ascend")
                        end
                        if state.AutoOrchardHarvest then
                            doOrchardHarvest(tycoon)
                            table.insert(actions, "orchard")
                        end
                        if state.AutoOrchardSell then
                            doOrchardSell(tycoon)
                            table.insert(actions, "sellfruit")
                        end
                        if state.AutoSewerCashVine then
                            doSewerPrompts(sewerPromptCache.cash, 1)
                            table.insert(actions, "vine")
                        end
                    end)
                end

                updateStatusSnapshot(tycoon)
                status.actions = #actions > 0 and table.concat(actions, ", ") or "idle"
            else
                status.actions = "waiting for tycoon..."
            end

            updateUi()
            task.wait(anyAutomationEnabled() and 0.2 or 0.5)
        end
    end)
end

local function buildFluentGui()
    local Window = Fluent:CreateWindow({
        Title = "Mango Hub",
        SubTitle = "Sell Lemons",
        TabWidth = 160,
        Size = UDim2.fromOffset(560, 460),
        Acrylic = false,
        Theme = "Darker",
        MinimizeKey = Enum.KeyCode.LeftControl
    })

    Window:SetOnClose(function()
        scriptAlive = false
        for key, value in pairs(state) do
            if type(value) == "boolean" then
                state[key] = false
            end
        end
    end)

    local Tabs = {
        Farm = Window:AddTab({ Title = "Farm", Icon = "bot" }),
        Sidegame = Window:AddTab({ Title = "Sidegame", Icon = "map" }),
        Progression = Window:AddTab({ Title = "Progression", Icon = "trending-up" }),
        Utility = Window:AddTab({ Title = "Utility", Icon = "wrench" }),
        Stats = Window:AddTab({ Title = "Stats", Icon = "bar-chart-3" }),
        Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
    }

    local statsParagraph = Tabs.Stats:AddParagraph({
        Title = "Session Stats",
        Content = "Cash: --\nInvestors: --\nRebirths: --\nEvolution: --\nActions: idle"
    })

    updateUi = function()
        if statsParagraph and statsParagraph.SetDesc then
            statsParagraph:SetDesc(string.format(
                "Cash: %s\nInvestors: %s\nRebirths: %s\nEvolution: %s\nActions: %s",
                status.cash,
                status.investors,
                status.rebirths,
                status.evolve,
                status.actions
            ))
        end
    end

    Tabs.Farm:AddToggle("AutoBuyToggle", {
        Title = "Auto Buy Tiles",
        Description = "Buys affordable purchase tiles automatically.",
        Default = false
    }):OnChanged(function(value)
        state.AutoBuy = value
    end)

    Tabs.Farm:AddToggle("AutoUpgradeEarnersToggle", {
        Title = "Auto Upgrade Earners",
        Description = "Bulk upgrades cash machines when affordable.",
        Default = false
    }):OnChanged(function(value)
        state.AutoUpgradeEarners = value
    end)

    Tabs.Farm:AddToggle("AutoUpgradePowersToggle", {
        Title = "Auto Upgrade Powers",
        Description = "Spends investors on power upgrades.",
        Default = false
    }):OnChanged(function(value)
        state.AutoUpgradePowers = value
    end)

    Tabs.Farm:AddToggle("AutoFruitToggle", {
        Title = "Auto Collect Fruit",
        Description = "Teleports through lemon trees and harvests fruit.",
        Default = false
    }):OnChanged(function(value)
        state.AutoFruit = value
        if value then
            gatherFruit()
        end
    end)

    Tabs.Farm:AddToggle("AutoWakeToggle", {
        Title = "Auto Wake Earners",
        Description = "Triggers manual earners repeatedly.",
        Default = false
    }):OnChanged(function(value)
        state.AutoWake = value
    end)

    Tabs.Farm:AddToggle("AutoCashDropToggle", {
        Title = "Auto Collect Cash Drops",
        Description = "Claims cash drops as soon as they appear.",
        Default = false
    }):OnChanged(function(value)
        state.AutoCashDrop = value
    end)

    Tabs.Farm:AddToggle("AutoPhoneToggle", {
        Title = "Auto Phone Deals",
        Description = "Accepts current phone deals automatically.",
        Default = false
    }):OnChanged(function(value)
        state.AutoPhone = value
    end)

    Tabs.Sidegame:AddSection("Orchard")

    Tabs.Sidegame:AddToggle("AutoOrchardHarvestToggle", {
        Title = "Auto Harvest Orchard",
        Description = "Harvests local orchard plots when fruit is ready.",
        Default = false
    }):OnChanged(function(value)
        state.AutoOrchardHarvest = value
        if value then
            local tycoon = getTycoon()
            if tycoon then
                refreshOrchardPlots(tycoon)
            end
        end
    end)

    Tabs.Sidegame:AddToggle("AutoOrchardSellToggle", {
        Title = "Auto Sell Orchard Fruits",
        Description = "Sells all stored orchard fruits automatically.",
        Default = false
    }):OnChanged(function(value)
        state.AutoOrchardSell = value
    end)

    Tabs.Sidegame:AddButton({
        Title = "Teleport To Orchard",
        Description = "Moves you to your orchard teleport pad.",
        Callback = function()
            local tycoon = getTycoon()
            local orchard = tycoon and getLocalOrchard(tycoon)
            local hrp = getRootPart()
            local teleport = orchard and orchard.Instance and orchard.Instance:FindFirstChild("Teleport")
            if hrp and teleport and teleport:IsA("BasePart") then
                hrp.CFrame = teleport.CFrame + Vector3.new(0, 4, 0)
            end
        end
    })

    Tabs.Sidegame:AddSection("Sewer")

    Tabs.Sidegame:AddButton({
        Title = "TP Lever Blue",
        Description = "Teleports to the blue sewer lever.",
        Callback = function()
            teleportToSewerLever("Blue")
        end
    })

    Tabs.Sidegame:AddButton({
        Title = "TP Lever Green",
        Description = "Teleports to the green sewer lever.",
        Callback = function()
            teleportToSewerLever("Green")
        end
    })

    Tabs.Sidegame:AddButton({
        Title = "TP Lever Purple",
        Description = "Teleports to the purple sewer lever.",
        Callback = function()
            teleportToSewerLever("Purple")
        end
    })

    Tabs.Sidegame:AddButton({
        Title = "TP Lever Red",
        Description = "Teleports to the red sewer lever.",
        Callback = function()
            teleportToSewerLever("Red")
        end
    })

    Tabs.Sidegame:AddToggle("AutoSewerCashVineToggle", {
        Title = "Auto Cash Vine",
        Description = "Triggers the sewer cash vine prompt automatically.",
        Default = false
    }):OnChanged(function(value)
        state.AutoSewerCashVine = value
    end)

    Tabs.Progression:AddToggle("AutoRebirthToggle", {
        Title = "Auto Rebirth",
        Description = "Rebirths when the displayed rebirth gain reaches or exceeds your current investors.",
        Default = false
    }):OnChanged(function(value)
        state.AutoRebirth = value
    end)

    Tabs.Progression:AddToggle("AutoEvolveToggle", {
        Title = "Auto Evolve",
        Description = "Evolves at 100% progress.",
        Default = false
    }):OnChanged(function(value)
        state.AutoEvolve = value
    end)

    Tabs.Progression:AddToggle("AutoAscendToggle", {
        Title = "Auto Ascend",
        Description = "Ascends at 100% progress.",
        Default = false
    }):OnChanged(function(value)
        state.AutoAscend = value
    end)

    Tabs.Utility:AddToggle("AntiAfkToggle", {
        Title = "Anti-AFK",
        Description = "Prevents idle disconnects.",
        Default = false
    }):OnChanged(function(value)
        state.AntiAFK = value
    end)

    Tabs.Utility:AddToggle("SpeedToggle", {
        Title = "Enable Walk Speed",
        Description = "Applies the selected walk speed continuously.",
        Default = false
    }):OnChanged(function(value)
        state.SpeedOn = value
    end)

    Tabs.Utility:AddSlider("WalkSpeedSlider", {
        Title = "Walk Speed",
        Description = "Sets the target walk speed.",
        Default = 16,
        Min = 16,
        Max = 150,
        Rounding = 0,
        Callback = function(value)
            state.SpeedVal = math.floor(value + 0.5)
        end
    })

    Tabs.Utility:AddButton({
        Title = "Refresh Fruit Cache",
        Description = "Rescans available lemon trees and fruit click detectors.",
        Callback = function()
            gatherFruit()
            Fluent:Notify({
                Title = "Sell Lemons",
                Content = string.format("Fruit cache refreshed (%d fruit nodes found).", #fruitCache),
                Duration = 4
            })
        end
    })

    Tabs.Stats:AddButton({
        Title = "Copy Current Status",
        Description = "Shows a quick summary notification of your current stats.",
        Callback = function()
            Fluent:Notify({
                Title = "Sell Lemons Status",
                Content = string.format(
                    "Cash: %s | Investors: %s | Rebirths: %s | Evolution: %s | Actions: %s",
                    status.cash,
                    status.investors,
                    status.rebirths,
                    status.evolve,
                    status.actions
                ),
                Duration = 5
            })
        end
    })

    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("MangoHub")
    SaveManager:SetFolder("MangoHub/sell-lemons")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)

    Window:SelectTab(1)
    SaveManager:LoadAutoloadConfig()

    Fluent:Notify({
        Title = "Mango Hub",
        Content = "Sell Lemons loaded successfully.",
        Duration = 4
    })
end

local fluentOk, fluentErr = pcall(buildFluentGui)
if not fluentOk then
    warn("[Mango Hub] Failed to build shared UI: " .. tostring(fluentErr))
end

startLogicLoop()
print("[Sell Lemons Farm] loaded")
