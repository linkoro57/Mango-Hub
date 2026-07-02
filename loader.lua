local RAW_BASE_URL = "https://raw.githubusercontent.com/linkoro57/Mango-Hub/main/"
local UI_SOURCE = "mango-ui.lua"

local games = {
    {
        key = "ban-or-be-banned",
        title = "Ban or Be Banned",
        aliases = { "ban or be banned", "ban or get banned" },
        source = "ban-or-be-banned.lua",
        placeIds = { 96017656548489 },
        signatures = {
            workspace = { "Decoration" },
        },
    },
    {
        key = "be-a-lucky-block",
        title = "Be a Lucky Block",
        aliases = { "be a lucky block" },
        source = "be-a-lucky-block.lua",
        placeIds = { 124473577469410 },
        signatures = {
            workspace = { "CollectZones", "RunningModels", "Plots" },
            replicatedStorage = { "BrainrotModels" },
        },
    },
    {
        key = "flex-your-fps-and-your-ping",
        title = "Flex Your FPS and Your Ping",
        aliases = { "flex your fps and your ping" },
        source = "flex-your-fps-and-your-ping.lua",
        placeIds = { 18667984660 },
        signatures = {},
    },
    {
        key = "jump-brainrot",
        title = "Jump Brainrot",
        aliases = { "jump brainrot", "brainrot jumping" },
        source = "jump-brainrot.lua",
        placeIds = { 88829149289682 },
        signatures = {
            replicatedStorage = { "Events", "Remotes", "Modules" },
        },
    },
    {
        key = "sell-lemons",
        title = "Sell Lemons",
        aliases = { "sell lemons" },
        source = "sell-lemons.lua",
        placeIds = { 79268393072444 },
        signatures = {},
    },
}

local function normalizeName(value)
    return tostring(value or "")
        :lower()
        :gsub("[%p%c]", " ")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local function containsPlaceId(entry, placeId)
    for _, candidate in ipairs(entry.placeIds or {}) do
        if candidate == placeId then
            return true
        end
    end
    return false
end

local function findByPlaceId(placeId)
    for _, entry in ipairs(games) do
        if containsPlaceId(entry, placeId) then
            return entry
        end
    end
    return nil
end

local function findByName(name)
    local normalized = normalizeName(name)
    if normalized == "" then
        return nil
    end

    for _, entry in ipairs(games) do
        if normalizeName(entry.title) == normalized then
            return entry
        end

        for _, alias in ipairs(entry.aliases or {}) do
            if normalizeName(alias) == normalized then
                return entry
            end
        end
    end

    return nil
end

local function countChildren(parent, names)
    if not parent or type(names) ~= "table" then
        return 0, 0
    end

    local total = #names
    local found = 0
    for _, name in ipairs(names) do
        if parent:FindFirstChild(name) then
            found = found + 1
        end
    end
    return found, total
end

local function matchScore(entry)
    local signatures = entry.signatures or {}
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local workspaceFound, workspaceTotal = countChildren(workspace, signatures.workspace)
    local replicatedFound, replicatedTotal = countChildren(replicatedStorage, signatures.replicatedStorage)
    local total = workspaceTotal + replicatedTotal

    if total == 0 then
        return 0
    end

    return (workspaceFound + replicatedFound) / total
end

local function getExperienceName()
    local ok, productInfo = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)

    if ok and type(productInfo) == "table" then
        return productInfo.Name
    end

    local gameName = rawget(game, "Name") or game.Name
    if type(gameName) == "string" and gameName ~= "" then
        return gameName
    end

    return nil
end

local function detectGame()
    local byPlaceId = findByPlaceId(game.PlaceId)
    if byPlaceId then
        return byPlaceId, "placeId"
    end

    local gameId = rawget(game, "GameId") or game.GameId
    if type(gameId) == "number" and gameId ~= 0 and gameId ~= game.PlaceId then
        local byGameId = findByPlaceId(gameId)
        if byGameId then
            return byGameId, "gameId"
        end
    end

    local byName = findByName(getExperienceName())
    if byName then
        return byName, "experienceName"
    end

    local bestEntry
    local bestScore = 0
    for _, entry in ipairs(games) do
        local score = matchScore(entry)
        if score > bestScore then
            bestEntry = entry
            bestScore = score
        end
    end

    if bestEntry and bestScore >= 0.67 then
        return bestEntry, "signature"
    end

    return nil, "none"
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

    if type(requestImpl) == "function" then
        local requestOk, response = pcall(requestImpl, {
            Url = url,
            Method = "GET",
        })

        if requestOk and type(response) == "table" then
            local body = response.Body or response.body
            if type(body) == "string" and body ~= "" then
                return true, body
            end
        end
    end

    return false, result
end

local function ensureSharedUiFactory()
    local existing = rawget(_G, "__MangoHubUIFactory")
    if type(existing) == "table" then
        return true
    end

    local loader = getLoader()
    if type(loader) ~= "function" then
        warn("[Mango Hub] Failed to preload Mango UI: loadstring/load is not available.")
        return false
    end

    local fetchOk, source = httpGet(RAW_BASE_URL .. UI_SOURCE)
    if not fetchOk or type(source) ~= "string" or source == "" then
        warn("[Mango Hub] Failed to preload Mango UI: " .. tostring(source))
        return false
    end

    local chunk, compileErr = loader(source)
    if type(chunk) ~= "function" then
        warn("[Mango Hub] Failed to compile Mango UI: " .. tostring(compileErr))
        return false
    end

    local runOk, result = xpcall(chunk, function(message)
        if type(debug) == "table" and type(debug.traceback) == "function" then
            return debug.traceback(tostring(message), 2)
        end
        return tostring(message)
    end)

    if not runOk then
        warn("[Mango Hub] Failed to run Mango UI: " .. tostring(result))
        return false
    end

    if type(result) == "table" then
        rawset(_G, "__MangoHubUIFactory", result)
        return true
    end

    local loaded = rawget(_G, "__MangoHubUIFactory")
    if type(loaded) == "table" then
        return true
    end

    warn("[Mango Hub] Mango UI preload returned an invalid result.")
    return false
end

local function runRemote(entry)
    ensureSharedUiFactory()

    local loader = getLoader()
    if type(loader) ~= "function" then
        warn("[Mango Hub] loadstring/load is not available.")
        return false
    end

    local url = RAW_BASE_URL .. entry.source
    local fetchOk, source = httpGet(url)
    if not fetchOk or type(source) ~= "string" or source == "" then
        warn("[Mango Hub] Failed to fetch " .. entry.source .. ": " .. tostring(source))
        return false
    end

    local chunk, compileErr = loader(source)
    if type(chunk) ~= "function" then
        warn("[Mango Hub] Failed to compile " .. entry.source .. ": " .. tostring(compileErr))
        return false
    end

    local runOk, runErr = xpcall(chunk, function(message)
        if type(debug) == "table" and type(debug.traceback) == "function" then
            return debug.traceback(tostring(message), 2)
        end
        return tostring(message)
    end)

    if not runOk then
        warn("[Mango Hub] Failed to run " .. entry.source .. ": " .. tostring(runErr))
        return false
    end

    return true
end

local function runLocal(entry)
    local scriptObject = rawget(getfenv and getfenv() or _G, "script") or script
    if type(scriptObject) ~= "userdata" and type(scriptObject) ~= "table" then
        return nil
    end

    local ok, parent = pcall(function()
        return scriptObject.Parent
    end)

    if not ok then
        return nil
    end

    if not parent then
        return nil
    end

    local folder = parent:FindFirstChild("scripts") or parent
    local module = folder:FindFirstChild(entry.key)
        or folder:FindFirstChild(entry.source)
        or folder:FindFirstChild(entry.title)

    if not module then
        return nil
    end

    if module:IsA("ModuleScript") then
        local loaded = require(module)
        if type(loaded) == "function" then
            return loaded()
        end
        if type(loaded) == "table" and type(loaded.run) == "function" then
            return loaded.run()
        end
        return loaded ~= false
    end

    if module:IsA("LocalScript") then
        module.Disabled = false
        return true
    end

    return nil
end

local function run()
    local entry, reason = detectGame()
    if not entry then
        warn("[Mango Hub] Unsupported game. GameId: " .. tostring(game.GameId))
        return false
    end

    rawset(_G, "__MangoHubReloadCallback", function()
        run()
    end)

    local localResult = runLocal(entry)
    if localResult ~= nil then
        return localResult
    end

    return runRemote(entry, reason)
end

return run()
