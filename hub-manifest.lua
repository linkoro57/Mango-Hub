local HubManifest = {}

HubManifest.games = {
    {
        key = "ban-or-be-banned",
        title = "Ban or Be Banned",
        aliases = { "ban or be banned" },
        source = "ban-or-be-banned.lua",
        placeIds = {},
        signatures = {
            workspace = { "Decoration" },
        },
    },
    {
        key = "be-a-lucky-block",
        title = "Be a Lucky Block",
        aliases = { "be a lucky block" },
        source = "be-a-lucky-block.lua",
        placeIds = {},
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
        placeIds = {},
        signatures = {},
    },
    {
        key = "jump-brainrot",
        title = "Jump Brainrot",
        aliases = { "jump brainrot" },
        source = "jump-brainrot.lua",
        placeIds = {},
        signatures = {
            replicatedStorage = { "Events", "Remotes", "Modules" },
        },
    },
    {
        key = "sell-lemons",
        title = "Sell Lemons",
        aliases = { "sell lemons" },
        source = "sell-lemons.lua",
        placeIds = {},
        signatures = {},
    },
}

local function containsPlaceId(entry, placeId)
    for _, candidate in ipairs(entry.placeIds or {}) do
        if candidate == placeId then
            return true
        end
    end
    return false
end

local function normalizeName(value)
    return tostring(value or "")
        :lower()
        :gsub("[%p%c]", " ")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
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

function HubManifest.matchScore(entry, context)
    context = context or {}
    local score = 0
    local checks = 0
    local signatures = entry.signatures or {}

    local workspaceFound, workspaceTotal = countChildren(context.workspace, signatures.workspace)
    score = score + workspaceFound
    checks = checks + workspaceTotal

    local replicatedFound, replicatedTotal = countChildren(context.replicatedStorage, signatures.replicatedStorage)
    score = score + replicatedFound
    checks = checks + replicatedTotal

    if checks == 0 then
        return 0
    end

    return score / checks
end

function HubManifest.findByKey(key)
    for _, entry in ipairs(HubManifest.games) do
        if entry.key == key then
            return entry
        end
    end
    return nil
end

function HubManifest.findByPlaceId(placeId)
    for _, entry in ipairs(HubManifest.games) do
        if containsPlaceId(entry, placeId) then
            return entry
        end
    end
    return nil
end

function HubManifest.findByName(name)
    local normalized = normalizeName(name)
    if normalized == "" then
        return nil
    end

    for _, entry in ipairs(HubManifest.games) do
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

function HubManifest.detect(context)
    context = context or {}

    local byPlaceId = HubManifest.findByPlaceId(context.placeId)
    if byPlaceId then
        return byPlaceId, "placeId"
    end

    local byName = HubManifest.findByName(context.experienceName)
    if byName then
        return byName, "experienceName"
    end

    local bestEntry
    local bestScore = 0
    for _, entry in ipairs(HubManifest.games) do
        local score = HubManifest.matchScore(entry, context)
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

return HubManifest
