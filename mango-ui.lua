local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local MangoUI = {}
MangoUI.Options = {}

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

local colors = {
    accent = Color3.fromRGB(255, 187, 92),
    accent2 = Color3.fromRGB(255, 137, 78),
    accentSoft = Color3.fromRGB(255, 214, 153),
    accentText = Color3.fromRGB(30, 20, 12),
    bg = Color3.fromRGB(14, 17, 22),
    bg2 = Color3.fromRGB(22, 28, 36),
    bg3 = Color3.fromRGB(34, 42, 53),
    bg4 = Color3.fromRGB(47, 57, 69),
    panel = Color3.fromRGB(26, 32, 42),
    panel2 = Color3.fromRGB(92, 101, 117),
    text = Color3.fromRGB(245, 247, 250),
    sub = Color3.fromRGB(150, 160, 172),
    off = Color3.fromRGB(74, 82, 95),
    ok = Color3.fromRGB(108, 224, 150),
    danger = Color3.fromRGB(255, 124, 124),
    shadow = Color3.fromRGB(5, 7, 10),
}

local tweenFast = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenSoft = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenSpring = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function desktopWindowPosition(xOffset, viewportY, windowHeight)
    return UDim2.new(0, xOffset, 0, math.floor((viewportY - windowHeight) / 2))
end

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

local function corner(object, radius)
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, radius or 8)
    uiCorner.Parent = object
    return uiCorner
end

local function pad(object, top, bottom, left, right)
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, top or 0)
    padding.PaddingBottom = UDim.new(0, bottom or 0)
    padding.PaddingLeft = UDim.new(0, left or 0)
    padding.PaddingRight = UDim.new(0, right or 0)
    padding.Parent = object
    return padding
end

local function stroke(object, transparency)
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = Color3.fromRGB(255, 255, 255)
    uiStroke.Transparency = transparency or 0.88
    uiStroke.Thickness = 1.25
    uiStroke.Parent = object
    return uiStroke
end

local function safeSet(object, property, value)
    pcall(function()
        object[property] = value
    end)
end

local function gradient(object, colorA, colorB, rotation)
    local uiGradient = Instance.new("UIGradient")
    uiGradient.Color = ColorSequence.new(colorA, colorB)
    uiGradient.Rotation = rotation or 90
    uiGradient.Parent = object
    return uiGradient
end

local function shadow(object, transparency)
    local dropShadow = Instance.new("ImageLabel")
    dropShadow.Name = "Shadow"
    dropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    dropShadow.Position = UDim2.new(0.5, 0, 0.5, 8)
    dropShadow.Size = UDim2.new(1, 38, 1, 42)
    dropShadow.BackgroundTransparency = 1
    dropShadow.Image = "rbxassetid://1316045217"
    dropShadow.ImageColor3 = colors.shadow
    dropShadow.ImageTransparency = transparency or 0.72
    dropShadow.ScaleType = Enum.ScaleType.Slice
    dropShadow.SliceCenter = Rect.new(10, 10, 118, 118)
    dropShadow.ZIndex = math.max((object.ZIndex or 1) - 1, 0)
    dropShadow.Parent = object
    return dropShadow
end

local function tween(object, info, props)
    local ok, anim = pcall(function()
        return TweenService:Create(object, info, props)
    end)
    if ok and anim then
        anim:Play()
    else
        for key, value in pairs(props) do
            safeSet(object, key, value)
        end
    end
    return anim
end

local function bindHover(button, enterProps, leaveProps)
    if not button then
        return
    end
    button.MouseEnter:Connect(function()
        tween(button, tweenFast, enterProps)
    end)
    button.MouseLeave:Connect(function()
        tween(button, tweenFast, leaveProps)
    end)
end

local function toMultiMap(defaultValue)
    local result = {}
    if type(defaultValue) == "table" then
        local count = 0
        for key, value in pairs(defaultValue) do
            count = count + 1
            if type(key) == "number" then
                result[tostring(value)] = true
            else
                result[tostring(key)] = value == true
            end
        end
        if count == 0 then
            return {}
        end
    end
    return result
end

local function shallowCopy(list)
    local out = {}
    for i, value in ipairs(list or {}) do
        out[i] = value
    end
    return out
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, innerValue in pairs(value) do
        out[deepCopy(key)] = deepCopy(innerValue)
    end
    return out
end

local function selectedSummary(valueMap)
    local selected = {}
    for key, enabled in pairs(valueMap or {}) do
        if enabled then
            table.insert(selected, tostring(key))
        end
    end
    table.sort(selected)
    if #selected == 0 then
        return "None"
    end
    return table.concat(selected, ", ")
end

local function simpleSignal()
    local signal = { _handlers = {} }
    function signal:Connect(handler)
        table.insert(self._handlers, handler)
        return {
            Disconnect = function()
                for i, fn in ipairs(signal._handlers) do
                    if fn == handler then
                        table.remove(signal._handlers, i)
                        break
                    end
                end
            end
        }
    end
    function signal:Fire(...)
        for _, handler in ipairs(self._handlers) do
            task.spawn(handler, ...)
        end
    end
    return signal
end

local function makeOption(id, initialValue)
    local changed = simpleSignal()
    local option = {
        Id = id,
        Value = initialValue,
    }
    function option:OnChanged(handler)
        return changed:Connect(handler)
    end
    function option:_emit()
        changed:Fire(self.Value)
    end
    MangoUI.Options[id] = option
    return option
end

local function getReloadStore()
    local store = rawget(_G, "__MangoHubReloadConfigs")
    if type(store) ~= "table" then
        store = {}
        _G.__MangoHubReloadConfigs = store
    end
    return store
end

local function getReloadCallback()
    local callback = rawget(_G, "__MangoHubReloadCallback")
    if type(callback) == "function" then
        return callback
    end
    return nil
end

local function makeNotifier(gui)
    local viewport = getViewportSize()
    local isCompact = viewport.X <= 760
    local sideMargin = isCompact and 12 or 20
    local holderWidth = math.min(isCompact and (viewport.X - sideMargin * 2) or 280, 280)

    local holder = Instance.new("Frame")
    holder.Name = "Notifications"
    holder.AnchorPoint = isCompact and Vector2.new(0.5, 0) or Vector2.new(1, 0)
    holder.Position = isCompact and UDim2.new(0.5, 0, 0, 12) or UDim2.new(1, -20, 0, 20)
    holder.Size = UDim2.new(0, holderWidth, 1, isCompact and -24 or -40)
    holder.BackgroundTransparency = 1
    holder.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.Parent = holder

    return function(payload)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 64)
        card.BackgroundColor3 = colors.bg2
        card.BorderSizePixel = 0
        card.Parent = holder
        corner(card, 10)
        stroke(card, 0.4)
        pad(card, 8, 8, 10, 10)
        gradient(card, colors.bg2, colors.bg3, 90)
        card.BackgroundTransparency = 1
        card.Position = UDim2.new(0, 0, 0, -8)

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(1, 0, 0, 18)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 13
        title.TextColor3 = colors.text
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = tostring(payload.Title or "Notification")
        title.Parent = card

        local content = Instance.new("TextLabel")
        content.BackgroundTransparency = 1
        content.Position = UDim2.new(0, 0, 0, 22)
        content.Size = UDim2.new(1, 0, 1, -22)
        content.Font = Enum.Font.Gotham
        content.TextSize = 11
        content.TextWrapped = true
        content.TextYAlignment = Enum.TextYAlignment.Top
        content.TextColor3 = colors.sub
        content.TextXAlignment = Enum.TextXAlignment.Left
        content.Text = tostring(payload.Content or "")
        content.Parent = card

        tween(card, tweenSoft, {
            BackgroundTransparency = 0,
            Position = UDim2.new(0, 0, 0, 0),
        })
        local duration = tonumber(payload.Duration) or 4
        task.delay(duration, function()
            if card.Parent then
                tween(card, tweenFast, {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, -6),
                })
                task.delay(0.16, function()
                    if card.Parent then
                        card:Destroy()
                    end
                end)
            end
        end)
    end
end

function MangoUI:CreateWindow(config)
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local guiParent = playerGui

    local old = guiParent:FindFirstChild("MangoHubGui")
    if not old and guiParent ~= playerGui then
        old = playerGui:FindFirstChild("MangoHubGui")
    end
    if old then
        old:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MangoHubGui"
    gui.ResetOnSpawn = false
    safeSet(gui, "IgnoreGuiInset", true)
    safeSet(gui, "DisplayOrder", 999)
    safeSet(gui, "ZIndexBehavior", Enum.ZIndexBehavior.Sibling)
    gui.Parent = guiParent

    local oldOverlayGui = guiParent:FindFirstChild("MangoHubDropdownOverlay")
    if oldOverlayGui then
        oldOverlayGui:Destroy()
    end

    local overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "MangoHubDropdownOverlay"
    overlayGui.ResetOnSpawn = false
    safeSet(overlayGui, "IgnoreGuiInset", true)
    safeSet(overlayGui, "DisplayOrder", 10000)
    safeSet(overlayGui, "ZIndexBehavior", Enum.ZIndexBehavior.Sibling)
    overlayGui.Parent = guiParent

    local notify = makeNotifier(gui)
    function self:Notify(payload)
        notify(payload or {})
    end

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 9999
    overlay.Parent = overlayGui

    local size = config.Size or UDim2.fromOffset(560, 460)
    local requestedWidth = size.X.Offset > 0 and size.X.Offset or 560
    local requestedHeight = size.Y.Offset > 0 and size.Y.Offset or 460
    local viewport = getViewportSize()
    local isMobile = UserInputService.TouchEnabled or viewport.X <= 820
    local horizontalMargin = isMobile and 12 or 40
    local verticalMargin = isMobile and 16 or 32
    local minWidth = math.min(320, viewport.X - horizontalMargin * 2)
    local minHeight = math.min(280, viewport.Y - verticalMargin * 2)
    local width = math.clamp(requestedWidth, minWidth, math.max(minWidth, viewport.X - horizontalMargin * 2))
    local height = math.clamp(requestedHeight, minHeight, math.max(minHeight, viewport.Y - verticalMargin * 2))
    local barHeight = isMobile and 54 or 46
    local tabsHeight = isMobile and 48 or 40
    local chromeHeight = barHeight + tabsHeight
    local buttonSize = isMobile and 34 or 28
    local controlHeight = isMobile and 34 or 28
    local touchCardHeight = isMobile and 54 or 44
    local compactText = isMobile and 12 or 11

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, width, 0, height)
    main.AnchorPoint = isMobile and Vector2.new(0.5, 0.5) or Vector2.new(0, 0)
    main.Position = isMobile and UDim2.new(0.5, 0, 0.5, 0) or desktopWindowPosition(horizontalMargin, viewport.Y, height)
    main.BackgroundColor3 = colors.bg
    main.BorderSizePixel = 0
    main.Parent = gui
    corner(main, 14)
    stroke(main, 0.4)
    gradient(main, colors.bg, colors.bg2, 90)
    main.BackgroundTransparency = 1

    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.new(1, 0, 0, barHeight)
    bar.BackgroundColor3 = colors.panel
    bar.BorderSizePixel = 0
    bar.Active = true
    bar.Parent = main
    corner(bar, 14)

    local barMask = Instance.new("Frame")
    barMask.Size = UDim2.new(1, 0, 0, 14)
    barMask.Position = UDim2.new(0, 0, 1, -14)
    barMask.BackgroundColor3 = colors.panel
    barMask.BorderSizePixel = 0
    barMask.Parent = bar

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 4, 0, 22)
    accentBar.Position = UDim2.new(0, 12, 0.5, -11)
    accentBar.BackgroundColor3 = colors.accent
    accentBar.BorderSizePixel = 0
    accentBar.Parent = bar
    corner(accentBar, 2)
    gradient(accentBar, colors.accent, colors.accent2, 90)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 24, 0, isMobile and 7 or 4)
    title.Size = UDim2.new(1, isMobile and -112 or -100, 0, 18)
    title.Font = Enum.Font.GothamBold
    title.TextSize = isMobile and 15 or 16
    title.TextColor3 = colors.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = tostring(config.Title or "Mango Hub")
    title.Parent = bar

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.new(0, 24, 0, isMobile and 25 or 22)
    subtitle.Size = UDim2.new(1, isMobile and -112 or -100, 0, 14)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = compactText
    subtitle.TextColor3 = colors.sub
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Text = tostring(config.SubTitle or "")
    subtitle.Parent = bar

    local dragHandle = Instance.new("TextButton")
    dragHandle.Name = "DragHandle"
    dragHandle.AutoButtonColor = false
    dragHandle.Text = isMobile and "Drag" or ""
    dragHandle.BackgroundTransparency = isMobile and 0.08 or 1
    dragHandle.BackgroundColor3 = colors.bg3
    dragHandle.BorderSizePixel = 0
    dragHandle.Active = true
    dragHandle.Selectable = false
    dragHandle.Font = Enum.Font.GothamBold
    dragHandle.TextSize = isMobile and 12 or 1
    dragHandle.TextColor3 = colors.sub
    dragHandle.Position = isMobile and UDim2.new(0.5, 0, 0, 4) or UDim2.new(0, 0, 0, 0)
    dragHandle.AnchorPoint = isMobile and Vector2.new(0.5, 0) or Vector2.new(0, 0)
    dragHandle.Size = isMobile and UDim2.new(0, 120, 0, 18) or UDim2.new(1, -(buttonSize * 3 + 44), 1, 0)
    dragHandle.ZIndex = 5
    dragHandle.Parent = bar
    corner(dragHandle, 9)
    if isMobile then
        stroke(dragHandle, 0.8)
    end

    local function makeBarButton(text, xOffset, color)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, buttonSize, 0, buttonSize)
        button.Position = UDim2.new(1, xOffset, 0.5, -math.floor(buttonSize / 2))
        button.BackgroundColor3 = colors.bg2
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = isMobile and 16 or 15
        button.TextColor3 = color or colors.text
        button.Text = text
        button.Parent = bar
        corner(button, 8)
        stroke(button, 0.9)
        bindHover(button,
            { BackgroundColor3 = colors.bg3 },
            { BackgroundColor3 = colors.bg2 }
        )
        return button
    end

    local closeButton = makeBarButton("X", -(isMobile and 12 + buttonSize or 36), colors.danger)
    local minButton = makeBarButton("-", -(isMobile and 18 + buttonSize * 2 or 70), colors.text)
    local reloadButton = makeBarButton("R", -(isMobile and 24 + buttonSize * 3 or 104), colors.accent)

    local tabsBar = Instance.new("ScrollingFrame")
    tabsBar.Name = "TabsBar"
    tabsBar.Position = UDim2.new(0, 0, 0, barHeight)
    tabsBar.Size = UDim2.new(1, 0, 0, tabsHeight)
    tabsBar.BackgroundColor3 = colors.bg
    tabsBar.BackgroundTransparency = 1
    tabsBar.BorderSizePixel = 0
    tabsBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabsBar.ScrollBarThickness = 0
    safeSet(tabsBar, "ScrollingDirection", Enum.ScrollingDirection.X)
    tabsBar.Parent = main
    local tabsPaddingLeft = isMobile and 10 or 12
    local tabsPaddingRight = isMobile and 10 or 12
    local tabsPaddingTop = 8
    local tabsPaddingBottom = isMobile and 8 or 6
    local tabsSpacing = 8
    local preferredTabWidth = math.max(96, config.TabWidth or 160)
    local minimumTabWidth = isMobile and 100 or 88
    pad(tabsBar, tabsPaddingTop, tabsPaddingBottom, tabsPaddingLeft, tabsPaddingRight)

    local tabsLayout = Instance.new("UIListLayout")
    tabsLayout.FillDirection = Enum.FillDirection.Horizontal
    tabsLayout.Padding = UDim.new(0, tabsSpacing)
    tabsLayout.Parent = tabsBar

    local pages = Instance.new("Frame")
    pages.Name = "Pages"
    pages.Position = UDim2.new(0, 0, 0, chromeHeight)
    pages.Size = UDim2.new(1, 0, 1, -chromeHeight)
    pages.BackgroundTransparency = 1
    pages.Parent = main

    tween(main, tweenSpring, {
        BackgroundTransparency = 0,
        Position = isMobile and UDim2.new(0.5, 0, 0.5, 0) or desktopWindowPosition(horizontalMargin + 6, viewport.Y, height),
    })
    task.delay(0.02, function()
        if main.Parent and not isMobile then
            tween(main, tweenSoft, {
                Position = desktopWindowPosition(horizontalMargin, viewport.Y, height),
            })
        end
    end)

    local window = {
        _gui = gui,
        _main = main,
        _pages = pages,
        _tabButtons = {},
        _tabs = {},
        _selectedIndex = 1,
        _closed = false,
        _onClose = type(config.OnClose) == "function" and config.OnClose or nil,
    }

    function window:SetOnClose(callback)
        self._onClose = type(callback) == "function" and callback or nil
    end

    local function relayoutTabs()
        local count = #window._tabButtons
        if count == 0 then
            tabsBar.CanvasSize = UDim2.new(0, 0, 0, 0)
            return
        end

        local usableWidth = math.max(0, main.AbsoluteSize.X - tabsPaddingLeft - tabsPaddingRight)
        local sharedWidth = math.floor((usableWidth - tabsSpacing * (count - 1)) / count)
        local buttonWidth = sharedWidth
        local totalWidth

        if sharedWidth >= minimumTabWidth then
            buttonWidth = sharedWidth
            totalWidth = usableWidth
        else
            buttonWidth = math.max(minimumTabWidth, math.min(preferredTabWidth, usableWidth))
            totalWidth = buttonWidth * count + tabsSpacing * (count - 1)
        end

        for _, tabButton in ipairs(window._tabButtons) do
            tabButton.Size = UDim2.new(0, buttonWidth, 1, -4)
        end

        tabsBar.CanvasSize = UDim2.new(0, totalWidth + tabsPaddingLeft + tabsPaddingRight, 0, 0)
    end

    local function setMinimized(minimized)
        tabsBar.Visible = not minimized
        pages.Visible = not minimized
        tween(main, tweenSoft, {
            Size = minimized and UDim2.new(0, width, 0, barHeight) or UDim2.new(0, width, 0, height)
        })
    end

    local minimized = false
    minButton.MouseButton1Click:Connect(function()
        minimized = not minimized
        setMinimized(minimized)
    end)

    closeButton.MouseButton1Click:Connect(function()
        if window._closed then
            return
        end
        window._closed = true
        if window._onClose then
            pcall(window._onClose)
        end
        gui:Destroy()
    end)

    reloadButton.MouseButton1Click:Connect(function()
        if window._closed then
            return
        end
        local saveReloadConfig = rawget(_G, "__MangoHubSaveReloadConfig")
        if type(saveReloadConfig) == "function" then
            pcall(saveReloadConfig)
        end
        window._closed = true
        if window._onClose then
            pcall(window._onClose)
        end
        gui:Destroy()

        task.spawn(function()
            local reloadCallback = getReloadCallback()
            if type(reloadCallback) ~= "function" then
                warn("[Mango Hub] Reload unavailable: no local reload callback registered.")
                return
            end

            local runOk, runErr = xpcall(reloadCallback, function(message)
                if type(debug) == "table" and type(debug.traceback) == "function" then
                    return debug.traceback(tostring(message), 2)
                end
                return tostring(message)
            end)

            if not runOk then
                warn("[Mango Hub] Reload failed: " .. tostring(runErr))
            end
        end)
    end)

    local function clampWindowPosition()
        local currentViewport = getViewportSize()
        local margin = 8

        if isMobile then
            local minVisibleX = math.min(main.AbsoluteSize.X, 96)
            local minVisibleY = math.min(main.AbsoluteSize.Y, barHeight + 12)
            local maxOffsetX = math.max(0, math.floor((currentViewport.X + main.AbsoluteSize.X) / 2) - minVisibleX)
            local maxOffsetY = math.max(0, math.floor((currentViewport.Y + main.AbsoluteSize.Y) / 2) - minVisibleY)
            local offsetX = math.clamp(main.Position.X.Offset, -maxOffsetX, maxOffsetX)
            local offsetY = math.clamp(main.Position.Y.Offset, -maxOffsetY, maxOffsetY)
            main.Position = UDim2.new(0.5, math.floor(offsetX), 0.5, math.floor(offsetY))
            return
        end

        local maxX = math.max(margin, currentViewport.X - main.AbsoluteSize.X - margin)
        local maxY = math.max(margin, currentViewport.Y - main.AbsoluteSize.Y - margin)
        local offsetX = math.clamp(main.Position.X.Offset, margin, maxX)
        local offsetY = math.clamp(main.Position.Y.Offset, margin, maxY)
        main.Position = UDim2.new(0, math.floor(offsetX), 0, math.floor(offsetY))
    end

    local dragging, dragStart, startPos, dragInput, dragInputType
    local function updateDrag(input)
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        clampWindowPosition()
    end

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            dragInput = input
            dragInputType = input.UserInputType

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    dragInput = nil
                    dragInputType = nil
                end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and dragInputType == Enum.UserInputType.MouseButton1 and input == dragInput then
            updateDrag(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if dragging and input == dragInput then
            dragging = false
            dragInput = nil
            dragInputType = nil
        end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging and dragInputType == Enum.UserInputType.Touch then
            local touches = UserInputService:GetTouches()
            local touch = touches[1]
            if touch then
                updateDrag(touch)
            else
                dragging = false
                dragInput = nil
                dragInputType = nil
            end
        end
    end)

    local currentCamera = workspace.CurrentCamera
    if currentCamera then
        currentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            clampWindowPosition()
            relayoutTabs()
        end)
    end

    local function selectTab(index)
        for i, tab in ipairs(window._tabs) do
            local selected = i == index
            tab.Page.Visible = selected
            local button = window._tabButtons[i]
            if button then
                tween(button, tweenSoft, {
                    BackgroundColor3 = selected and colors.accent or colors.bg2,
                    TextColor3 = selected and colors.accentText or colors.text,
                })
                local strokeRef = button:FindFirstChild("AccentStroke")
                if strokeRef and strokeRef:IsA("UIStroke") then
                    tween(strokeRef, tweenSoft, {
                        Transparency = selected and 0.55 or 0.9,
                    })
                end
            end
        end
        window._selectedIndex = index
    end

    function window:SelectTab(index)
        selectTab(tonumber(index) or 1)
    end

    function window:AddTab(tabConfig)
        local tab = {}
        local index = #self._tabs + 1

        local button = Instance.new("TextButton")
        button.Name = "TabButton"
        button.AutoButtonColor = false
        button.Size = UDim2.new(0, preferredTabWidth, 1, -4)
        button.BackgroundColor3 = colors.bg2
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamBold
        button.TextSize = isMobile and 13 or 12
        button.TextColor3 = colors.text
        button.Text = tostring(tabConfig.Title or ("Tab " .. index))
        button.Parent = tabsBar
        corner(button, 10)
        local buttonStroke = stroke(button, 0.9)
        buttonStroke.Name = "AccentStroke"
        button.MouseEnter:Connect(function()
            if window._selectedIndex ~= index then
                tween(button, tweenFast, {
                    BackgroundColor3 = colors.bg3,
                })
            end
        end)
        button.MouseLeave:Connect(function()
            if window._selectedIndex ~= index then
                tween(button, tweenFast, {
                    BackgroundColor3 = colors.bg2,
                })
            end
        end)

        local page = Instance.new("ScrollingFrame")
        page.Name = tostring(tabConfig.Title or ("Tab" .. index))
        page.Size = UDim2.new(1, 0, 1, 0)
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.ScrollBarThickness = 4
        page.ScrollBarImageColor3 = colors.accent
        page.ScrollBarImageTransparency = 0.25
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.Visible = false
        page.Parent = pages
        pad(page, isMobile and 8 or 6, isMobile and 12 or 12, isMobile and 10 or 12, isMobile and 10 or 8)

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        local function refreshPageCanvas()
            page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
        end
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshPageCanvas)
        refreshPageCanvas()

        local order = 0
        local function nextOrder()
            order = order + 1
            return order
        end

        local function addCard(height)
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, height)
            card.BackgroundColor3 = colors.bg2
            card.BorderSizePixel = 0
            card.LayoutOrder = nextOrder()
            card.Parent = page
            corner(card, 10)
            stroke(card, 0.9)
            gradient(card, colors.bg2, colors.panel, 90)
            return card
        end

        function tab:AddSection(text)
            local header = Instance.new("TextLabel")
            header.Size = UDim2.new(1, 0, 0, 18)
            header.BackgroundTransparency = 1
            header.Font = Enum.Font.GothamBold
            header.TextSize = isMobile and 13 or 12
            header.TextColor3 = colors.accent
            header.TextXAlignment = Enum.TextXAlignment.Left
            header.Text = tostring(text)
            header.LayoutOrder = nextOrder()
            header.Parent = page
            pad(header, 4, 0, 2, 0)
            return header
        end

        function tab:AddParagraph(paragraphConfig)
            local lineCount = 1
            local contentText = tostring(paragraphConfig.Content or "")
            for _ in string.gmatch(contentText, "\n") do
                lineCount = lineCount + 1
            end
            local cardHeight = math.max(isMobile and 92 or 76, (isMobile and 50 or 40) + lineCount * (isMobile and 18 or 16))
            local card = addCard(cardHeight)
            pad(card, 10, 10, 12, 12)

            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Size = UDim2.new(1, 0, 0, 18)
            titleLabel.Font = Enum.Font.GothamBold
            titleLabel.TextSize = isMobile and 14 or 13
            titleLabel.TextColor3 = colors.text
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.Text = tostring(paragraphConfig.Title or "Paragraph")
            titleLabel.Parent = card

            local contentLabel = Instance.new("TextLabel")
            contentLabel.BackgroundTransparency = 1
            contentLabel.Position = UDim2.new(0, 0, 0, 22)
            contentLabel.Size = UDim2.new(1, 0, 1, -22)
            contentLabel.Font = Enum.Font.Gotham
            contentLabel.TextSize = compactText
            contentLabel.TextWrapped = true
            contentLabel.TextYAlignment = Enum.TextYAlignment.Top
            contentLabel.TextColor3 = colors.sub
            contentLabel.TextXAlignment = Enum.TextXAlignment.Left
            contentLabel.Text = contentText
            contentLabel.Parent = card

            local paragraph = {}
            function paragraph:SetDesc(text)
                contentLabel.Text = tostring(text or "")
            end
            function paragraph:SetTitle(text)
                titleLabel.Text = tostring(text or "")
            end
            return paragraph
        end

        function tab:AddButton(buttonConfig)
            local card = addCard(buttonConfig.Description and (isMobile and 72 or 60) or touchCardHeight)
            pad(card, 8, 8, 12, 12)

            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 1, 0)
            button.BackgroundColor3 = colors.bg3
            button.BorderSizePixel = 0
            button.Text = ""
            button.Parent = card
            corner(button, 8)
            stroke(button, 0.92)
            gradient(button, colors.bg3, colors.bg4, 90)
            bindHover(button,
                { BackgroundColor3 = colors.bg4 },
                { BackgroundColor3 = colors.bg3 }
            )

            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Position = UDim2.new(0, 10, 0, isMobile and 10 or 8)
            titleLabel.Size = UDim2.new(1, -20, 0, 15)
            titleLabel.Font = Enum.Font.GothamBold
            titleLabel.TextSize = isMobile and 14 or 13
            titleLabel.TextColor3 = colors.text
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.Text = tostring(buttonConfig.Title or "Button")
            titleLabel.Parent = button

            local descLabel
            if buttonConfig.Description then
                descLabel = Instance.new("TextLabel")
                descLabel.BackgroundTransparency = 1
                descLabel.Position = UDim2.new(0, 10, 0, isMobile and 30 or 24)
                descLabel.Size = UDim2.new(1, -20, 0, 12)
                descLabel.Font = Enum.Font.Gotham
                descLabel.TextSize = compactText
                descLabel.TextColor3 = colors.sub
                descLabel.TextXAlignment = Enum.TextXAlignment.Left
                descLabel.Text = tostring(buttonConfig.Description)
                descLabel.Parent = button
            end

            button.MouseButton1Click:Connect(function()
                if type(buttonConfig.Callback) == "function" then
                    task.spawn(buttonConfig.Callback)
                end
            end)
            return button
        end

        function tab:AddToggle(id, toggleConfig)
            local option = makeOption(id, toggleConfig.Default == true)
            local card = addCard(toggleConfig.Description and (isMobile and 62 or 50) or touchCardHeight)
            pad(card, 8, 8, 12, 12)

            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Size = UDim2.new(1, isMobile and -74 or -62, 0, 15)
            titleLabel.Font = Enum.Font.GothamBold
            titleLabel.TextSize = isMobile and 14 or 13
            titleLabel.TextColor3 = colors.text
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.Text = tostring(toggleConfig.Title or id)
            titleLabel.Parent = card

            if toggleConfig.Description then
                local descLabel = Instance.new("TextLabel")
                descLabel.BackgroundTransparency = 1
                descLabel.Position = UDim2.new(0, 0, 0, isMobile and 24 or 20)
                descLabel.Size = UDim2.new(1, isMobile and -74 or -62, 0, 12)
                descLabel.Font = Enum.Font.Gotham
                descLabel.TextSize = compactText
                descLabel.TextColor3 = colors.sub
                descLabel.TextXAlignment = Enum.TextXAlignment.Left
                descLabel.Text = tostring(toggleConfig.Description)
                descLabel.Parent = card
            end

            local switch = Instance.new("TextButton")
            local switchWidth = isMobile and 48 or 42
            local switchHeight = isMobile and 26 or 22
            local knobSize = isMobile and 22 or 18
            switch.Size = UDim2.new(0, switchWidth, 0, switchHeight)
            switch.Position = UDim2.new(1, -switchWidth, 0.5, -math.floor(switchHeight / 2))
            switch.BackgroundColor3 = colors.off
            switch.BorderSizePixel = 0
            switch.Text = ""
            switch.Parent = card
            corner(switch, math.floor(switchHeight / 2))
            stroke(switch, 0.92)
            gradient(switch, colors.off, colors.panel2, 0)

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, knobSize, 0, knobSize)
            knob.Position = UDim2.new(0, 2, 0.5, -math.floor(knobSize / 2))
            knob.BackgroundColor3 = colors.text
            knob.BorderSizePixel = 0
            knob.Parent = switch
            corner(knob, math.floor(knobSize / 2))

            local function render()
                local on = option.Value == true
                tween(switch, tweenSoft, {
                    BackgroundColor3 = on and colors.accent or colors.off
                })
                tween(knob, tweenSoft, {
                    Position = on and UDim2.new(1, -(knobSize + 2), 0.5, -math.floor(knobSize / 2)) or UDim2.new(0, 2, 0.5, -math.floor(knobSize / 2))
                })
            end

            function option:SetValue(value)
                self.Value = value == true
                render()
                self:_emit()
            end

            switch.MouseButton1Click:Connect(function()
                option:SetValue(not option.Value)
            end)

            render()
            return option
        end

        function tab:AddSlider(id, sliderConfig)
            local initial = tonumber(sliderConfig.Default) or tonumber(sliderConfig.Min) or 0
            local option = makeOption(id, initial)
            local card = addCard(sliderConfig.Description and (isMobile and 88 or 74) or (isMobile and 70 or 58))
            pad(card, 8, 8, 12, 12)

            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Size = UDim2.new(1, -70, 0, 15)
            titleLabel.Font = Enum.Font.GothamBold
            titleLabel.TextSize = isMobile and 14 or 13
            titleLabel.TextColor3 = colors.text
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.Text = tostring(sliderConfig.Title or id)
            titleLabel.Parent = card

            local valueLabel = Instance.new("TextLabel")
            valueLabel.BackgroundTransparency = 1
            valueLabel.Position = UDim2.new(1, -60, 0, 0)
            valueLabel.Size = UDim2.new(0, 60, 0, 15)
            valueLabel.Font = Enum.Font.Gotham
            valueLabel.TextSize = isMobile and 13 or 12
            valueLabel.TextColor3 = colors.sub
            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
            valueLabel.Parent = card

            if sliderConfig.Description then
                local descLabel = Instance.new("TextLabel")
                descLabel.BackgroundTransparency = 1
                descLabel.Position = UDim2.new(0, 0, 0, isMobile and 22 or 18)
                descLabel.Size = UDim2.new(1, 0, 0, 12)
                descLabel.Font = Enum.Font.Gotham
                descLabel.TextSize = compactText
                descLabel.TextColor3 = colors.sub
                descLabel.TextXAlignment = Enum.TextXAlignment.Left
                descLabel.Text = tostring(sliderConfig.Description)
                descLabel.Parent = card
            end

            local track = Instance.new("Frame")
            local trackHeight = isMobile and 8 or 6
            local sliderKnobSize = isMobile and 18 or 14
            track.Size = UDim2.new(1, 0, 0, trackHeight)
            track.Position = UDim2.new(0, 0, 1, isMobile and -14 or -12)
            track.BackgroundColor3 = colors.bg3
            track.BorderSizePixel = 0
            track.Parent = card
            corner(track, math.floor(trackHeight / 2))
            stroke(track, 0.94)

            local fill = Instance.new("Frame")
            fill.BorderSizePixel = 0
            fill.BackgroundColor3 = colors.accent
            fill.Parent = track
            corner(fill, math.floor(trackHeight / 2))
            gradient(fill, colors.accent, colors.accent2, 0)

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, sliderKnobSize, 0, sliderKnobSize)
            knob.BackgroundColor3 = colors.text
            knob.BorderSizePixel = 0
            knob.Parent = track
            knob.ZIndex = 2
            corner(knob, math.floor(sliderKnobSize / 2))

            local minValue = tonumber(sliderConfig.Min) or 0
            local maxValue = tonumber(sliderConfig.Max) or 100
            local rounding = tonumber(sliderConfig.Rounding) or 0

            local function round(value)
                if rounding <= 0 then
                    return math.floor(value + 0.5)
                end
                local mult = 10 ^ rounding
                return math.floor(value * mult + 0.5) / mult
            end

            local function render()
                local alpha = 0
                if maxValue ~= minValue then
                    alpha = (option.Value - minValue) / (maxValue - minValue)
                end
                alpha = math.clamp(alpha, 0, 1)
                valueLabel.Text = tostring(option.Value)
                tween(fill, tweenFast, {
                    Size = UDim2.new(alpha, 0, 1, 0)
                })
                tween(knob, tweenFast, {
                    Position = UDim2.new(alpha, -math.floor(sliderKnobSize / 2), 0.5, -math.floor(sliderKnobSize / 2))
                })
            end

            function option:SetValue(value)
                local nextValue = math.clamp(tonumber(value) or initial, minValue, maxValue)
                self.Value = round(nextValue)
                render()
                self:_emit()
            end

            if type(sliderConfig.Callback) == "function" then
                option:OnChanged(sliderConfig.Callback)
            end

            local dragging = false
            local function updateFromX(x)
                local alpha = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
                option:SetValue(minValue + (maxValue - minValue) * math.clamp(alpha, 0, 1))
            end
            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateFromX(input.Position.X)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateFromX(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)

            option:SetValue(initial)
            return option
        end

        function tab:AddInput(id, inputConfig)
            local option = makeOption(id, tostring(inputConfig.Default or ""))
            local card = addCard(isMobile and 72 or 66)
            pad(card, 8, 8, 12, 12)

            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Size = UDim2.new(1, 0, 0, 15)
            titleLabel.Font = Enum.Font.GothamBold
            titleLabel.TextSize = isMobile and 14 or 13
            titleLabel.TextColor3 = colors.text
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.Text = tostring(inputConfig.Title or id)
            titleLabel.Parent = card

            local inputBox = Instance.new("TextBox")
            inputBox.Position = UDim2.new(0, 0, 0, 24)
            inputBox.Size = UDim2.new(1, 0, 0, controlHeight)
            inputBox.BackgroundColor3 = colors.bg3
            inputBox.BorderSizePixel = 0
            inputBox.Font = Enum.Font.Gotham
            inputBox.TextSize = isMobile and 13 or 12
            inputBox.TextColor3 = colors.text
            inputBox.PlaceholderColor3 = colors.sub
            inputBox.TextXAlignment = Enum.TextXAlignment.Left
            inputBox.PlaceholderText = tostring(inputConfig.Placeholder or "")
            inputBox.Text = option.Value
            inputBox.ClearTextOnFocus = false
            inputBox.Parent = card
            corner(inputBox, 8)
            pad(inputBox, 0, 0, 10, 10)
            stroke(inputBox, 0.94)
            bindHover(inputBox,
                { BackgroundColor3 = colors.bg4 },
                { BackgroundColor3 = colors.bg3 }
            )

            function option:SetValue(value)
                local nextValue = tostring(value or "")
                if inputConfig.Numeric then
                    nextValue = nextValue:gsub("[^%d%-%.]", "")
                end
                self.Value = nextValue
                inputBox.Text = nextValue
                self:_emit()
                if type(inputConfig.Callback) == "function" then
                    task.spawn(inputConfig.Callback, self.Value)
                end
            end

            local function apply()
                option:SetValue(inputBox.Text)
            end

            inputBox.FocusLost:Connect(function()
                apply()
            end)
            if inputConfig.Finished == false then
                inputBox:GetPropertyChangedSignal("Text"):Connect(function()
                    apply()
                end)
            end

            return option
        end

        function tab:AddDropdown(id, dropdownConfig)
            local values = shallowCopy(dropdownConfig.Values or {})
            local isMulti = dropdownConfig.Multi == true
            local initialValue
            if isMulti then
                initialValue = toMultiMap(dropdownConfig.Default or {})
            else
                initialValue = dropdownConfig.Default or values[1]
            end
            local option = makeOption(id, initialValue)

            local card = addCard(isMobile and 72 or 66)
            pad(card, 8, 8, 12, 12)

            local titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Size = UDim2.new(1, 0, 0, 15)
            titleLabel.Font = Enum.Font.GothamBold
            titleLabel.TextSize = isMobile and 14 or 13
            titleLabel.TextColor3 = colors.text
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.Text = tostring(dropdownConfig.Title or id)
            titleLabel.Parent = card

            local button = Instance.new("TextButton")
            button.Position = UDim2.new(0, 0, 0, 24)
            button.Size = UDim2.new(1, 0, 0, controlHeight)
            button.BackgroundColor3 = colors.bg3
            button.BorderSizePixel = 0
            button.Font = Enum.Font.Gotham
            button.TextSize = isMobile and 13 or 12
            button.TextColor3 = colors.text
            button.TextXAlignment = Enum.TextXAlignment.Left
            button.AutoButtonColor = false
            button.Parent = card
            corner(button, 8)
            pad(button, 0, 0, 10, 30)
            stroke(button, 0.94)
            gradient(button, colors.bg3, colors.bg4, 90)
            bindHover(button,
                { BackgroundColor3 = colors.bg4 },
                { BackgroundColor3 = colors.bg3 }
            )

            local caret = Instance.new("TextLabel")
            caret.BackgroundTransparency = 1
            caret.Size = UDim2.new(0, isMobile and 28 or 24, 1, 0)
            caret.Position = UDim2.new(1, isMobile and -28 or -24, 0, 0)
            caret.Font = Enum.Font.GothamBold
            caret.TextSize = isMobile and 13 or 12
            caret.TextColor3 = colors.sub
            caret.Text = "v"
            caret.Parent = button

            local popup = Instance.new("Frame")
            popup.Visible = false
            local popupHeight = math.min(isMobile and 168 or 120, math.floor(height * 0.35))
            popup.Size = UDim2.new(0, 0, 0, popupHeight)
            popup.Position = UDim2.new(0, 0, 0, 0)
            popup.BackgroundColor3 = colors.bg2
            popup.BorderSizePixel = 0
            popup.ZIndex = 10000
            popup.Parent = overlay
            corner(popup, 8)
            stroke(popup, 0.45)
            gradient(popup, colors.bg2, colors.panel, 90)

            local function positionPopup()
                local relativeX = button.AbsolutePosition.X - overlay.AbsolutePosition.X
                local relativeY = button.AbsolutePosition.Y - overlay.AbsolutePosition.Y
                local popupWidth = math.max(120, button.AbsoluteSize.X)
                local nextX = math.clamp(relativeX, 8, math.max(8, overlay.AbsoluteSize.X - popupWidth - 8))
                local downY = relativeY + button.AbsoluteSize.Y + 6
                local upY = relativeY - popupHeight - 6
                local nextY = downY

                if upY >= 8 then
                    nextY = upY
                elseif downY + popupHeight > overlay.AbsoluteSize.Y - 8 then
                    nextY = math.max(8, overlay.AbsoluteSize.Y - popupHeight - 8)
                end

                popup.Size = UDim2.new(0, popupWidth, 0, popupHeight)
                popup.Position = UDim2.new(0, math.floor(nextX), 0, math.floor(nextY))
            end

            local popupScroll = Instance.new("ScrollingFrame")
            popupScroll.Size = UDim2.new(1, 0, 1, 0)
            popupScroll.BackgroundTransparency = 1
            popupScroll.BorderSizePixel = 0
            popupScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
            popupScroll.ScrollBarThickness = isMobile and 4 or 3
            popupScroll.ScrollBarImageColor3 = colors.accent
            popupScroll.ZIndex = 10001
            popupScroll.Parent = popup
            pad(popupScroll, 6, 6, 6, 6)

            local popupLayout = Instance.new("UIListLayout")
            popupLayout.Padding = UDim.new(0, 4)
            popupLayout.Parent = popupScroll

            local function refreshPopupCanvas()
                popupScroll.CanvasSize = UDim2.new(0, 0, 0, popupLayout.AbsoluteContentSize.Y + 12)
            end
            popupLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshPopupCanvas)
            refreshPopupCanvas()

            local valueButtons = {}

            local function renderSummary()
                if isMulti then
                    button.Text = selectedSummary(option.Value)
                else
                    button.Text = tostring(option.Value or "Select...")
                end
            end

            local function refreshValueButtons()
                for _, child in ipairs(valueButtons) do
                    if child.Parent then
                        child:Destroy()
                    end
                end
                valueButtons = {}

                for _, rawValue in ipairs(values) do
                    local value = tostring(rawValue)
                    local row = Instance.new("TextButton")
                    row.Size = UDim2.new(1, 0, 0, isMobile and 34 or 26)
                    row.BackgroundColor3 = colors.bg3
                    row.BorderSizePixel = 0
                    row.Text = ""
                    row.AutoButtonColor = false
                    row.ZIndex = 10002
                    row.Parent = popupScroll
                    corner(row, 8)
                    stroke(row, 0.94)

                    local label = Instance.new("TextLabel")
                    label.BackgroundTransparency = 1
                    label.Position = UDim2.new(0, 10, 0, 0)
                    label.Size = UDim2.new(1, -20, 1, 0)
                    label.Font = Enum.Font.Gotham
                    label.TextSize = isMobile and 13 or 12
                    label.TextColor3 = colors.text
                    label.TextXAlignment = Enum.TextXAlignment.Left
                    label.Text = value
                    label.ZIndex = 10003
                    label.Parent = row

                    local function renderRow()
                        local selected = isMulti and option.Value[value] == true or option.Value == value
                        row.BackgroundColor3 = selected and colors.accent or colors.bg3
                        label.TextColor3 = selected and colors.accentText or colors.text
                    end

                    row.MouseEnter:Connect(function()
                        local selected = isMulti and option.Value[value] == true or option.Value == value
                        if not selected then
                            tween(row, tweenFast, {
                                BackgroundColor3 = colors.bg4,
                            })
                        end
                    end)
                    row.MouseLeave:Connect(function()
                        renderRow()
                    end)

                    row.MouseButton1Click:Connect(function()
                        if isMulti then
                            option.Value[value] = not option.Value[value]
                            if dropdownConfig.Callback then
                                task.spawn(dropdownConfig.Callback, option.Value)
                            end
                            option:_emit()
                            renderSummary()
                            renderRow()
                        else
                            option:SetValue(value)
                            popup.Visible = false
                        end
                    end)

                    renderRow()
                    table.insert(valueButtons, row)
                end

                refreshPopupCanvas()
            end

            function option:SetValue(value)
                if isMulti then
                    self.Value = toMultiMap(value or {})
                else
                    self.Value = value
                end
                renderSummary()
                refreshValueButtons()
                self:_emit()
                if type(dropdownConfig.Callback) == "function" then
                    task.spawn(dropdownConfig.Callback, self.Value)
                end
            end

            function option:SetValues(nextValues)
                values = shallowCopy(nextValues or {})
                refreshValueButtons()
                renderSummary()
            end

            button.MouseButton1Click:Connect(function()
                positionPopup()
                popup.Parent = nil
                popup.Parent = overlay
                popup.Visible = not popup.Visible
            end)

            option:SetValue(initialValue)
            return option
        end

        button.MouseButton1Click:Connect(function()
            selectTab(index)
        end)

        tab.Page = page
        self._tabButtons[index] = button
        self._tabs[index] = tab
        relayoutTabs()

        if index == 1 then
            selectTab(1)
        end

        return tab
    end

    clampWindowPosition()
    relayoutTabs()
    return window
end

local SaveManager = {}
function SaveManager:SetLibrary(library)
    self.Library = library
end
function SaveManager:IgnoreThemeSettings() end
function SaveManager:SetIgnoreIndexes() end
function SaveManager:SetFolder(folder)
    self.Folder = tostring(folder or "default")

    rawset(_G, "__MangoHubSaveReloadConfig", function()
        local store = getReloadStore()
        local snapshot = {}
        for id, option in pairs((self.Library and self.Library.Options) or MangoUI.Options) do
            if option and option.Value ~= nil then
                snapshot[id] = deepCopy(option.Value)
            end
        end
        store[self.Folder] = snapshot
    end)
end
function SaveManager:BuildConfigSection(tab)
    if tab and tab.AddSection then
        tab:AddSection("Configs")
        tab:AddParagraph({
            Title = "Config Saving",
            Content = "This Mango GUI version keeps the same controls but does not persist Fluent configs."
        })
    end
end
function SaveManager:LoadAutoloadConfig()
    local folder = self.Folder
    if type(folder) ~= "string" or folder == "" then
        return
    end

    local store = getReloadStore()
    local snapshot = store[folder]
    if type(snapshot) ~= "table" then
        return
    end

    local options = (self.Library and self.Library.Options) or MangoUI.Options
    for id, savedValue in pairs(snapshot) do
        local option = options[id]
        if option and type(option.SetValue) == "function" then
            pcall(function()
                option:SetValue(deepCopy(savedValue))
            end)
        end
    end
end

local InterfaceManager = {}
function InterfaceManager:SetLibrary() end
function InterfaceManager:SetFolder() end
function InterfaceManager:BuildInterfaceSection(tab)
    if tab and tab.AddSection then
        tab:AddSection("Interface")
        tab:AddParagraph({
            Title = "Mango UI",
            Content = "Shared Mango Hub interface active."
        })
    end
end

local MangoHubUIFactory = {
    Fluent = MangoUI,
    SaveManager = SaveManager,
    InterfaceManager = InterfaceManager,
}

_G.__MangoHubUIFactory = MangoHubUIFactory

return MangoHubUIFactory
