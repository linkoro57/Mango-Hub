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

local success, err = pcall(function()
    local factory = rawget(_G, "__MangoHubUIFactory")
    if not factory then
        factory, err = loadRemoteModule("https://raw.githubusercontent.com/linkoro57/Mango-Hub/main/mango-ui.lua", "MangoUI")
    end
    if not factory then error(err) end

    Fluent = factory.Fluent
    SaveManager = factory.SaveManager
    InterfaceManager = factory.InterfaceManager
end)

if not success or not Fluent then
    warn("[Mango Hub] Failed to load Mango UI: " .. tostring(err))
    return
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local Window = Fluent:CreateWindow({
    Title = "Mango Hub",
    SubTitle = "Flex Your FPS and Your Ping",
    TabWidth = 160,
    Size = UDim2.fromOffset(540, 420),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Spoof = Window:AddTab({ Title = "Spoof", Icon = "activity" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local state = {
    fpsEnabled = false,
    fpsValue = 240,
    fpsFluctuating = false,
    memoryEnabled = false,
    memoryValue = 512,
    memoryFluctuating = false,
    resolutionEnabled = false,
    resolutionWidth = 1920,
    resolutionHeight = 1080,
    resolutionFluctuating = false,
    graphicsEnabled = false,
    graphicsQuality = 10
}

local rng = Random.new()
local originalTexts = {}

local function asNumber(value, fallback)
    local number = tonumber(value)
    if not number then
        return fallback
    end
    return number
end

local function clampInteger(value, minValue, maxValue)
    return math.clamp(math.floor(value + 0.5), minValue, maxValue)
end

local function getFluctuated(baseValue, spread, minValue, maxValue)
    return clampInteger(baseValue + rng:NextInteger(-spread, spread), minValue, maxValue)
end

local function getSpoofValues()
    local fps = state.fpsValue
    local memory = state.memoryValue
    local width = state.resolutionWidth
    local height = state.resolutionHeight

    if state.fpsFluctuating then
        fps = getFluctuated(fps, 8, 1, 9999)
    end

    if state.memoryFluctuating then
        memory = getFluctuated(memory, 48, 1, 999999)
    end

    if state.resolutionFluctuating then
        width = getFluctuated(width, 16, 100, 99999)
        height = getFluctuated(height, 9, 100, 99999)
    end

    return fps, memory, width, height, state.graphicsQuality
end

local function safeText(object)
    local ok, text = pcall(function()
        return object.Text
    end)
    if ok and type(text) == "string" then
        return text
    end
    return nil
end

local function setText(object, text)
    pcall(function()
        object.Text = text
    end)
end

local function shouldSpoofText(text)
    local lower = text:lower()
    return lower:find("fps", 1, true)
        or lower:find("memory", 1, true)
        or lower:find("mem", 1, true)
        or lower:find("resolution", 1, true)
        or lower:find("screen", 1, true)
        or lower:find("graphic", 1, true)
        or lower:find("quality", 1, true)
end

local function spoofedText(originalText)
    local lower = originalText:lower()
    local fps, memory, width, height, quality = getSpoofValues()

    if state.fpsEnabled and lower:find("fps", 1, true) then
        return string.format("FPS: %d", fps)
    end

    if state.memoryEnabled and (lower:find("memory", 1, true) or lower:find("mem", 1, true)) then
        return string.format("Memory: %d MB", memory)
    end

    if state.resolutionEnabled and (lower:find("resolution", 1, true) or lower:find("screen", 1, true)) then
        return string.format("Screen Resolution: %dx%d", width, height)
    end

    if state.graphicsEnabled and (lower:find("graphic", 1, true) or lower:find("quality", 1, true)) then
        return string.format("Graphic Quality: %d", quality)
    end

    return nil
end

local function scanContainer(container)
    if not container then
        return
    end

    for _, object in ipairs(container:GetDescendants()) do
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            local text = safeText(object)
            if text and (originalTexts[object] or shouldSpoofText(text)) then
                originalTexts[object] = originalTexts[object] or text
                local replacement = spoofedText(originalTexts[object])
                if replacement then
                    setText(object, replacement)
                else
                    setText(object, originalTexts[object])
                end
            end
        end
    end
end

local function applyGraphicQuality()
    if not state.graphicsEnabled then
        return
    end

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel["Level" .. tostring(state.graphicsQuality)]
    end)

    pcall(function()
        UserSettings().GameSettings.SavedQualityLevel = Enum.SavedQualitySetting["QualityLevel" .. tostring(state.graphicsQuality)]
    end)
end

local function applySpoofs()
    scanContainer(LocalPlayer:FindFirstChild("PlayerGui"))

    pcall(function()
        scanContainer(CoreGui)
    end)

    applyGraphicQuality()
end

task.spawn(function()
    while true do
        applySpoofs()
        task.wait(0.35)
    end
end)

Tabs.Spoof:AddParagraph({
    Title = "How it works",
    Content = "Changes matching FPS, memory, resolution, and graphics quality text locally. Fluctuating adds small random movement to the displayed value."
})

Tabs.Spoof:AddSection("FPS")
Tabs.Spoof:AddToggle("FpsSpoofToggle", {
    Title = "Enable FPS Spoof",
    Default = false
}):OnChanged(function(value)
    state.fpsEnabled = value
end)

Tabs.Spoof:AddInput("FpsSpoofValue", {
    Title = "FPS Value",
    Default = "240",
    Placeholder = "240",
    Numeric = true,
    Finished = false,
    Callback = function(value)
        state.fpsValue = clampInteger(asNumber(value, 240), 1, 9999)
    end
})

Tabs.Spoof:AddToggle("FpsFluctuatingToggle", {
    Title = "Enable Fluctuating",
    Default = false
}):OnChanged(function(value)
    state.fpsFluctuating = value
end)

Tabs.Spoof:AddSection("Memory")
Tabs.Spoof:AddToggle("MemorySpoofToggle", {
    Title = "Enable Memory Spoof",
    Default = false
}):OnChanged(function(value)
    state.memoryEnabled = value
end)

Tabs.Spoof:AddInput("MemorySpoofValue", {
    Title = "Memory Value (MB)",
    Default = "512",
    Placeholder = "512",
    Numeric = true,
    Finished = false,
    Callback = function(value)
        state.memoryValue = clampInteger(asNumber(value, 512), 1, 999999)
    end
})

Tabs.Spoof:AddToggle("MemoryFluctuatingToggle", {
    Title = "Enable Fluctuating",
    Default = false
}):OnChanged(function(value)
    state.memoryFluctuating = value
end)

Tabs.Spoof:AddSection("Screen Resolution")
Tabs.Spoof:AddToggle("ResolutionSpoofToggle", {
    Title = "Enable Screen Resolution Spoof",
    Default = false
}):OnChanged(function(value)
    state.resolutionEnabled = value
end)

Tabs.Spoof:AddInput("ResolutionWidthValue", {
    Title = "Width",
    Default = "1920",
    Placeholder = "1920",
    Numeric = true,
    Finished = false,
    Callback = function(value)
        state.resolutionWidth = clampInteger(asNumber(value, 1920), 100, 99999)
    end
})

Tabs.Spoof:AddInput("ResolutionHeightValue", {
    Title = "Height",
    Default = "1080",
    Placeholder = "1080",
    Numeric = true,
    Finished = false,
    Callback = function(value)
        state.resolutionHeight = clampInteger(asNumber(value, 1080), 100, 99999)
    end
})

Tabs.Spoof:AddToggle("ResolutionFluctuatingToggle", {
    Title = "Enable Fluctuating",
    Default = false
}):OnChanged(function(value)
    state.resolutionFluctuating = value
end)

Tabs.Spoof:AddSection("Graphic Quality")
Tabs.Spoof:AddToggle("GraphicQualitySpoofToggle", {
    Title = "Enable Graphic Quality Spoof",
    Default = false
}):OnChanged(function(value)
    state.graphicsEnabled = value
    applyGraphicQuality()
end)

Tabs.Spoof:AddSlider("GraphicQualityValue", {
    Title = "Graphic Quality",
    Default = 10,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(value)
        state.graphicsQuality = clampInteger(value, 1, 10)
        applyGraphicQuality()
    end
})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("MangoHub")
SaveManager:SetFolder("MangoHub/flex-fps-ping")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
