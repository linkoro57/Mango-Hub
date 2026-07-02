local HubManifest = require(script.Parent:WaitForChild("hub-manifest"))

local Loader = {}

local function getExperienceName()
    local marketplaceService = game:GetService("MarketplaceService")
    local ok, productInfo = pcall(function()
        return marketplaceService:GetProductInfo(game.PlaceId)
    end)

    if ok and type(productInfo) == "table" then
        return productInfo.Name
    end

    return nil
end

local function getContext()
    return {
        placeId = game.PlaceId,
        experienceName = getExperienceName(),
        workspace = workspace,
        replicatedStorage = game:GetService("ReplicatedStorage"),
    }
end

local function resolveScript(entry)
    local folder = script.Parent:FindFirstChild("scripts") or script.Parent
    local module = folder:FindFirstChild(entry.key)
        or folder:FindFirstChild(entry.source)
        or folder:FindFirstChild(entry.title)

    if not module then
        return nil, ("script not found for %s"):format(entry.title)
    end

    return module
end

local function runScript(module)
    if module:IsA("ModuleScript") then
        local loaded = require(module)
        if type(loaded) == "function" then
            return loaded()
        end
        if type(loaded) == "table" and type(loaded.run) == "function" then
            return loaded.run()
        end
        return loaded
    end

    if module:IsA("LocalScript") then
        module.Disabled = false
        return true
    end

    return nil, ("unsupported script type %s"):format(module.ClassName)
end

function Loader.resolve()
    local entry, reason = HubManifest.detect(getContext())
    if not entry then
        return nil, reason
    end
    return entry, reason
end

function Loader.run()
    local entry, reason = Loader.resolve()
    if not entry then
        warn("[Mango Hub] Unsupported game. Add this PlaceId to hub-manifest.lua: " .. tostring(game.PlaceId))
        return false
    end

    rawset(_G, "__MangoHubReloadCallback", function()
        Loader.run()
    end)

    local module, resolveErr = resolveScript(entry)
    if not module then
        warn("[Mango Hub] " .. resolveErr)
        return false
    end

    local ok, result = xpcall(function()
        local runResult, runErr = runScript(module)
        if runResult == nil and runErr then
            error(runErr)
        end
        return runResult
    end, function(message)
        if type(debug) == "table" and type(debug.traceback) == "function" then
            return debug.traceback(tostring(message), 2)
        end
        return tostring(message)
    end)

    if not ok then
        warn(("[Mango Hub] Failed to launch %s via %s: %s"):format(entry.title, reason, tostring(result)))
        return false
    end

    return result ~= false
end

return Loader
