-- Optimized UI Library (performance + maintainability refactor)
-- Original API preserved. Added: window:SetAccent, window:Destroy, library._VERSION
-- Key changes:
--  * Removed per-frame RenderStepped polling for static accent updates
--  * Event-driven tab & sector visibility/position updates
--  * Centralized connection tracking & cleanup
--  * Theme change event (window.ThemeChanged) + registration helper
--  * Drag handling localized per-drag (no global frame polling)
--  * Dropdown / selection updates now event based instead of frame loop
--  * Reduced duplicate TextService calls & service fetches

local library = { _VERSION = "1.1.0" }

-- Service cache
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _RunService = game:GetService("RunService") -- retained for future expansion
local _TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Utility: safe connect tracking
local function track(window, signal, fn)
    local c = signal:Connect(fn)
    table.insert(window._connections, c)
    return c
end

-- Utility: tween helper (short ease)
local function shortTween(obj, goal, t)
    local ti = TweenInfo.new(t or 0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
    TweenService:Create(obj, ti, goal):Play()
end

-- Utility: rounding with decimals precision (decimals = number of decimal places)
local function roundTo(value, decimals)
    local mul = 10 ^ (decimals or 0)
    return math.floor(value * mul + 0.5) / mul
end

-- Utility: create outline triplet (main already exists)
-- (outline helper removed - original repeated patterns kept to avoid structural breakage)

-- Drag logic helper
local function enableDrag(frame, window)
    local dragging = false
    local dragStart, startPos
    track(window, frame.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    track(window, frame.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    track(window, UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function library:CreateWindow(name,accentcolor,accentcolor2,textsize,sizeX,sizeY,backimage,hidebutton)
    local window = { }
    window._connections = {}
    window._accentCallbacks = {}
    window._tabs = {}
    window._sectors = {}
    window._keybinds = {}
    window.ThemeChanged = Instance.new("BindableEvent")
    
    window.name = name or "New Window"
    window.textsize = textsize or 12
    window.accentcolor = accentcolor or Color3.fromRGB(28, 56, 139)
    window.accentcolor2 = accentcolor2 or Color3.fromRGB(16, 31, 78)
    window.size = UDim2.fromOffset(sizeX, sizeY) or UDim2.fromOffset(400, 477)
    window.backimage = backimage
    window.hidebutton = hidebutton or Enum.KeyCode.RightShift
    

    window.SelectedTab = nil

    window.Main = Instance.new("ScreenGui")
    window.Main.Name = name
    -- Parent fallback (PlayerGui first, then CoreGui if exploit environment)
    local parentGui = nil
    pcall(function() parentGui = player:FindFirstChildOfClass("PlayerGui") end)
    if parentGui then
        window.Main.Parent = parentGui
    else
        window.Main.Parent = game:GetService("CoreGui")
    end
    pcall(function()
        local _syn = rawget(getfenv(), "syn")
        if _syn and _syn.protect_gui then _syn.protect_gui(window.Main) end
    end)

    track(window, UserInputService.InputBegan, function(key, gp)
        if not gp and key.KeyCode == window.hidebutton then
            window.Main.Enabled = not window.Main.Enabled
        end
    end)

    -- legacy drag functions removed (replaced by enableDrag)

    window.Frame = Instance.new("Frame", window.Main)
    window.Frame.Name = "main"
    window.Frame.Position = UDim2.fromScale(0.5, 0.5)
    window.Frame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    window.Frame.Size = window.size
    window.Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    window.Frame.AnchorPoint = Vector2.new(0.5, 0.5)

    window.BlackOutline = Instance.new("Frame", window.Frame)
    window.BlackOutline.Name = "blackline"
    window.BlackOutline.ZIndex = 0
    window.BlackOutline.Size = window.size + UDim2.fromOffset(4, 4)
    window.BlackOutline.BorderSizePixel = 0
    window.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
    window.BlackOutline.Position = UDim2.fromOffset(-2, -2)

    window.TopBar = Instance.new("Frame", window.Frame)
    window.TopBar.Name = "top"
    window.TopBar.Size = UDim2.fromOffset(window.size.X.Offset, 20)
    window.TopBar.BorderSizePixel = 0
    window.TopBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    enableDrag(window.TopBar, window)

    window.TopGradient = Instance.new("UIGradient", window.TopBar)
    window.TopGradient.Rotation = 90
    window.TopGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(29, 29, 29)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(12, 12, 12))}

    window.NameLabel = Instance.new("TextLabel", window.TopBar)
    window.NameLabel.TextColor3 = Color3.new(1,1,1)
    window.NameLabel.Text = window.name
    window.NameLabel.TextXAlignment = Enum.TextXAlignment.Left
    window.NameLabel.Font = Enum.Font.Code
    window.NameLabel.Name = "title"
    window.NameLabel.Position = UDim2.fromOffset(6, 0)
    window.NameLabel.BackgroundTransparency = 1
    window.NameLabel.Size = UDim2.fromOffset(194, 19)
    window.NameLabel.TextSize = window.textsize

    window.Line2 = Instance.new("Frame", window.Frame)
    window.Line2.Name = "line"
    window.Line2.Position = UDim2.fromOffset(0, 20)
    window.Line2.Size = UDim2.fromOffset(window.size.X.Offset, 1)
    window.Line2.BorderSizePixel = 0
    window.Line2.BackgroundColor3 = window.accentcolor
    table.insert(window._accentCallbacks, function(p) window.Line2.BackgroundColor3 = p end)

    window.TabList = Instance.new("Frame", window.Frame)
    window.TabList.Name = "tablist"
    window.TabList.BackgroundTransparency = 1
    window.TabList.Position = UDim2.fromOffset(0, 21)
    window.TabList.Size = UDim2.fromOffset(window.size.X.Offset, 19)
    window.TopBar.Size = UDim2.fromOffset(window.TopBar.Size.X.Offset, window.TopBar.Size.Y.Offset + window.TabList.Size.Y.Offset)
    window.TabList.BorderSizePixel = 0
    window.TabList.BackgroundColor3 = Color3.new(0.09803921568, 0.09803921568, 0.09803921568)

    enableDrag(window.TabList, window)

    window.BlackLine = Instance.new("Frame", window.Frame)
    window.BlackLine.Name = "blackline"
    window.BlackLine.Size = UDim2.fromOffset(window.size.X.Offset, 1)
    window.BlackLine.BorderSizePixel = 0
    window.BlackLine.ZIndex = 9
    window.BlackLine.BackgroundColor3 = Color3.new(0, 0, 0)
    window.BlackLine.Position = UDim2.fromOffset(0, window.TabList.Position.Y.Offset) + UDim2.fromOffset(0, window.TabList.AbsoluteSize.Y - 1)

    if window.backimage then
        window.BackgroundImage = Instance.new("ImageButton", window.Frame)
        window.BackgroundImage.Name = "navigation"
        window.BackgroundImage.BackgroundTransparency = 1
        window.BackgroundImage.LayoutOrder = 10
        window.BackgroundImage.ScaleType = Enum.ScaleType.Stretch
        window.BackgroundImage.Position = window.BlackLine.Position + UDim2.fromOffset(0, 1)
        window.BackgroundImage.Size = UDim2.fromOffset(window.size.X.Offset, window.size.Y.Offset - 40)
        window.BackgroundImage.Image = window.backimage
    end

    window.Line = Instance.new("Frame", window.Frame)
    window.Line.Name = "line"
    window.Line.Position = UDim2.fromOffset(0, 0)
    window.Line.Size = UDim2.fromOffset(60, 1)
    window.Line.BorderSizePixel = 0
    window.Line.BackgroundColor3 = window.accentcolor
    table.insert(window._accentCallbacks, function(p) window.Line.BackgroundColor3 = p end)

    window.ListLayout = Instance.new("UIListLayout", window.TabList)
    window.ListLayout.FillDirection = Enum.FillDirection.Horizontal
    window.ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    window.OpenedColorPickers = { }

    function window:SetAccent(primary, secondary)
        if primary then window.accentcolor = primary end
        if secondary then window.accentcolor2 = secondary end
        for _,cb in ipairs(window._accentCallbacks) do
            local ok,err = pcall(cb, window.accentcolor, window.accentcolor2)
            if not ok then warn("[ui_library] accent callback error:", err) end
        end
        window.ThemeChanged:Fire(window.accentcolor, window.accentcolor2)
    end

    function window:Destroy()
        for _,c in ipairs(window._connections) do
            pcall(function() c:Disconnect() end)
        end
        self._connections = {}
        if self.Main then self.Main:Destroy() end
    end

    local function updateTabVisibility()
        for _,t in ipairs(window._tabs) do
            t.TabPage.Visible = (window.SelectedTab == t.TabButton)
            t.TabButton.TextColor3 = (window.SelectedTab == t.TabButton) and window.accentcolor or Color3.fromRGB(230,230,230)
        end
    end

    function window:CreateTab(name)
        local tab = { }
        tab.name = name or ""

        local textservice = game:GetService("TextService")
        local size = textservice:GetTextSize(tab.name, window.textsize, Enum.Font.Code, Vector2.new(200,300))

        tab.TabButton = Instance.new("TextButton", window.TabList)
        tab.TabButton.TextColor3 = Color3.fromRGB(230, 230, 230)
        tab.TabButton.Text = tab.name
        tab.TabButton.AutoButtonColor = false
        tab.TabButton.Font = Enum.Font.Code
        tab.TabButton.BackgroundTransparency = 1
        tab.TabButton.Size = UDim2.fromOffset(size.X + 15, 16)
        tab.TabButton.Name = tab.name
        tab.TabButton.TextSize = window.textsize

        tab.TabPage = Instance.new("ScrollingFrame", window.Frame)
        tab.TabPage.Name = tab.name:gsub(" ", "") .. "page"
        tab.TabPage.ScrollBarThickness = 0
        tab.TabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tab.TabPage.ScrollingDirection = "Y"
		tab.TabPage.Position = UDim2.new(0,0,0.0019470076076686, 39)
		tab.TabPage.Size = UDim2.fromOffset(window.size.X.Offset, window.size.Y.Offset - 39)
        tab.TabPage.BackgroundTransparency = 1

        table.insert(window._accentCallbacks, function(p)
            if window.SelectedTab == tab.TabButton then
                tab.TabButton.TextColor3 = p
            end
        end)

        local block = false
        function tab:SelectTab()
            if block then return end
            block = true
            window.SelectedTab = tab.TabButton
            shortTween(window.Line, {Size = UDim2.fromOffset(size.X + 15, 1), Position = UDim2.new(0, (tab.TabButton.AbsolutePosition.X - window.Frame.AbsolutePosition.X), 0, 0)}, 0.12)
            updateTabVisibility()
            task.delay(0.15, function() block = false end)
        end
    

        tab.TabButton.MouseButton1Down:Connect(function()
            tab:SelectTab()
        end)

        if not window.SelectedTab then
            tab:SelectTab()
        end

        tab.SectorsLeft = { }
        tab.SectorsRight = { }

        function tab:CreateSector(name,side)
            local sector = { }
            sector.name = name or ""
            sector.side = side or "left"
            
            sector.Main = Instance.new("Frame", tab.TabPage) 
            sector.Main.Name = sector.name:gsub(" ", "") .. "Sector"
            sector.Main.BorderColor3 = Color3.fromRGB(60, 60, 60)
            sector.Main.ZIndex = 2
            sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, 20)
            sector.Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

            sector.Line = Instance.new("Frame", sector.Main)
            sector.Line.Name = "line"
            sector.Line.ZIndex = 2
            sector.Line.Size = UDim2.fromOffset(sector.Main.Size.X.Offset + 2, 1)
            sector.Line.BorderSizePixel = 0
            sector.Line.Position = UDim2.fromOffset(-1, -1)
            sector.Line.BackgroundColor3 = window.accentcolor
            table.insert(window._accentCallbacks, function(p) if sector.Line.Parent then sector.Line.BackgroundColor3 = p end end)


            sector.BlackOutline = Instance.new("Frame", sector.Main)
            sector.BlackOutline.Name = "blackline"
            sector.BlackOutline.ZIndex = 1
            sector.BlackOutline.Size = sector.Main.Size + UDim2.fromOffset(4, 4)
            sector.BlackOutline.BorderSizePixel = 0
            sector.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
            sector.BlackOutline.Position = UDim2.fromOffset(-2, -2)
            sector.Main:GetPropertyChangedSignal("Size"):Connect(function()
                sector.BlackOutline.Size = sector.Main.Size + UDim2.fromOffset(4, 4)
            end)

            local size = textservice:GetTextSize(sector.name, 13, Enum.Font.Code, Vector2.new(2000, 2000))
            sector.Label = Instance.new("TextLabel", sector.Main)
            sector.Label.AnchorPoint = Vector2.new(0,0.5)
            sector.Label.Position = UDim2.fromOffset(12, -1)
            sector.Label.Size = UDim2.fromOffset(math.clamp(textservice:GetTextSize(sector.name, 13, Enum.Font.Code, Vector2.new(200,300)).X + 10, 0, sector.Main.Size.X.Offset), size.Y)
            sector.Label.BackgroundTransparency = 1
            sector.Label.BorderSizePixel = 0
            sector.Label.ZIndex = 4
            sector.Label.Text = sector.name
            sector.Label.TextColor3 = Color3.new(1,1,2552/255)
            sector.Label.TextStrokeTransparency = 1
            sector.Label.Font = Enum.Font.Code
            sector.Label.TextSize = 13

            sector.LabelBackFrame = Instance.new("Frame", sector.Label)
            sector.LabelBackFrame.Name = "labelframe"
            sector.LabelBackFrame.ZIndex = 3
            sector.LabelBackFrame.Size = UDim2.fromOffset(sector.Label.Size.X.Offset, 10)
            sector.LabelBackFrame.BorderSizePixel = 0
            sector.LabelBackFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            sector.LabelBackFrame.Position = UDim2.fromOffset(0, 5)

            sector.Items = Instance.new("Frame", sector.Main) 
            sector.Items.Name = "items"
            sector.Items.ZIndex = 2
            sector.Items.BackgroundTransparency = 1
            sector.Items.Size = UDim2.fromOffset(170, 140)
            sector.Items.AutomaticSize = Enum.AutomaticSize.Y
            sector.Items.BorderSizePixel = 0

            sector.ListLayout = Instance.new("UIListLayout", sector.Items)
            sector.ListLayout.FillDirection = Enum.FillDirection.Vertical
            sector.ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
            sector.ListLayout.Padding = UDim.new(0, 9)

            sector.ListPadding = Instance.new("UIPadding", sector.Items)
            sector.ListPadding.PaddingTop = UDim.new(0, 12)
            sector.ListPadding.PaddingLeft = UDim.new(0, 6)
            sector.ListPadding.PaddingRight = UDim.new(0, 6)

            function sector:AddButton(text, callback)
                local button = { }
                button.text = text or ""
                button.callback = callback or function() end

                button.Main = Instance.new("TextButton", sector.Items)
                button.Main.BorderSizePixel = 0
                button.Main.Text = ""
                button.Main.AutoButtonColor = false
                button.Main.Name = "button"
                button.Main.ZIndex = 4
                button.Main.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 12, 14)
                button.Main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                button.Main.MouseButton1Down:Connect(button.callback)

                button.Gradient = Instance.new("UIGradient", button.Main)
                button.Gradient.Rotation = 90
                button.Gradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(49, 49, 49)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(39, 39, 39))}

                button.Outline = Instance.new("Frame", button.Main)
                button.Outline.Name = "blackline"
                button.Outline.ZIndex = 3
                button.Outline.Size = button.Main.Size + UDim2.fromOffset(2, 2)
                button.Outline.BorderSizePixel = 0
                button.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                button.Outline.Position = UDim2.fromOffset(-1, -1)

                button.BlackOutline = Instance.new("Frame", button.Main)
                button.BlackOutline.Name = "blackline"
                button.BlackOutline.ZIndex = 2
                button.BlackOutline.Size = button.Main.Size + UDim2.fromOffset(4, 4)
                button.BlackOutline.BorderSizePixel = 0
                button.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                button.BlackOutline.Position = UDim2.fromOffset(-2, -2)

                button.Label = Instance.new("TextLabel", button.Main)
                button.Label.Name = "Label"
                button.Label.BackgroundTransparency = 1
                button.Label.Position = UDim2.new(0, -1, 0, 0)
                button.Label.ZIndex = 4
                button.Label.AutomaticSize = Enum.AutomaticSize.XY
                button.Label.Font = Enum.Font.Code
                button.Label.Text = " " .. button.text
                button.Label.TextColor3 = Color3.fromRGB(200, 200, 200)
                button.Label.TextSize = 13
                button.Label.TextStrokeTransparency = 1
                button.Label.TextXAlignment = Enum.TextXAlignment.Left
                button.Label.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        pcall(button.callback)
                    end
                end)

                button.BlackOutline.MouseEnter:Connect(function()
                    button.Outline.BackgroundColor3 = window.accentcolor
                    button.BlackOutline.BackgroundColor3 = window.accentcolor
                    button.Outline.BackgroundTransparency = 0.4
                    button.BlackOutline.BackgroundTransparency = 0.5
                end)
                button.BlackOutline.MouseLeave:Connect(function()
                    button.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    button.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                    button.Outline.BackgroundTransparency = 0
                    button.BlackOutline.BackgroundTransparency = 0
                end)
                table.insert(window._accentCallbacks, function(p)
                    if window.SelectedTab == tab.TabButton then
                        -- keep hover color dynamic only when hovered; baseline unaffected
                    end
                end)

                sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, sector.ListLayout.AbsoluteContentSize.Y + 18)
                tab.TabPage.CanvasSize = sector.Main.Size

                return button
            end

            function sector:AddLabel(text)
                local label = { }

                label.Main = Instance.new("TextLabel", sector.Items)
                label.Main.Name = "Label"
                label.Main.BackgroundTransparency = 1
                label.Main.Position = UDim2.new(0, -1, 0, 0)
                label.Main.ZIndex = 4
                label.Main.AutomaticSize = Enum.AutomaticSize.XY
                label.Main.Font = Enum.Font.Code
                label.Main.Text = text
                label.Main.TextColor3 = Color3.fromRGB(200, 200, 200)
                label.Main.TextSize = 13
                label.Main.TextStrokeTransparency = 1
                label.Main.TextXAlignment = Enum.TextXAlignment.Left

                function label:Set(value)
                    label.Main.Text = value
                end

                sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, sector.ListLayout.AbsoluteContentSize.Y + 18)
                tab.TabPage.CanvasSize = sector.Main.Size

                return label
            end
            
            function sector:AddToggle(text,default, callback)
                local toggle = { }
                toggle.text = text or ""
                toggle.default = default or false
                toggle.callback = callback or function(value) end
                
                toggle.value = toggle.default

                toggle.Main = Instance.new("TextButton", sector.Items)
                toggle.Main.Name = "toggle"
                toggle.Main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                toggle.Main.BorderColor3 = Color3.fromRGB(60, 60, 60)
                toggle.Main.BorderSizePixel = 0
                toggle.Main.Size = UDim2.fromOffset(10, 10)
                toggle.Main.AutoButtonColor = false
                toggle.Main.ZIndex = 4 
                toggle.Main.Font = Enum.Font.SourceSans
                toggle.Main.Text = ""
                toggle.Main.TextColor3 = Color3.fromRGB(0, 0, 0)
                toggle.Main.TextSize = 14

                toggle.Outline = Instance.new("Frame", toggle.Main)
                toggle.Outline.Name = "blackline"
                toggle.Outline.ZIndex = 3
                toggle.Outline.Size = toggle.Main.Size + UDim2.fromOffset(2, 2)
                toggle.Outline.BorderSizePixel = 0
                toggle.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                toggle.Outline.Position = UDim2.fromOffset(-1, -1)

                toggle.BlackOutline = Instance.new("Frame", toggle.Main)
                toggle.BlackOutline.Name = "blackline"
                toggle.BlackOutline.ZIndex = 2
                toggle.BlackOutline.Size = toggle.Main.Size + UDim2.fromOffset(4, 4)
                toggle.BlackOutline.BorderSizePixel = 0
                toggle.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                toggle.BlackOutline.Position = UDim2.fromOffset(-2, -2)
                
                toggle.Gradient = Instance.new("UIGradient", toggle.Main)
                toggle.Gradient.Rotation = (22.5 * 13)
                toggle.Gradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(30, 30, 30)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(45, 45, 45))}

                toggle.Label = Instance.new("TextLabel", toggle.Main)
                toggle.Label.Name = "Label"
                toggle.Label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                toggle.Label.BackgroundTransparency = 1
                toggle.Label.Position = UDim2.fromOffset(toggle.Main.AbsoluteSize.X + 10, -2)
                toggle.Label.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 71, toggle.BlackOutline.Size.Y.Offset)
                toggle.Label.Font = Enum.Font.Code
                toggle.Label.ZIndex = 2
                toggle.Label.Text = toggle.text
                toggle.Label.TextColor3 = Color3.fromRGB(200, 200, 200)
                toggle.Label.TextSize = 13
                toggle.Label.TextStrokeTransparency = 1
                toggle.Label.TextXAlignment = Enum.TextXAlignment.Left

                toggle.CheckedFrame = Instance.new("Frame", toggle.Main)
                toggle.CheckedFrame.ZIndex = 4
                toggle.CheckedFrame.BorderSizePixel = 0
                toggle.CheckedFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Color3.fromRGB(204, 0, 102)
                toggle.CheckedFrame.Size = toggle.Main.Size

                toggle.Gradient2 = Instance.new("UIGradient", toggle.CheckedFrame)
                toggle.Gradient2.Rotation = (22.5 * 13)
                local function updateToggleGradient()
                    toggle.Gradient2.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, window.accentcolor2), ColorSequenceKeypoint.new(1.00, window.accentcolor)})
                end
                updateToggleGradient()
                table.insert(window._accentCallbacks, function() updateToggleGradient() end)

                toggle.Items = Instance.new("Frame", toggle.Main)
                toggle.Items.Name = "\n"
                toggle.Items.ZIndex = 3
                toggle.Items.Size = UDim2.fromOffset(60, toggle.BlackOutline.AbsoluteSize.Y)
                toggle.Items.BorderSizePixel = 0
                toggle.Items.BackgroundTransparency = 1
                toggle.Items.BackgroundColor3 = Color3.new(0, 0, 0)
                toggle.Items.Position = UDim2.fromOffset(sector.Main.Size.X.Offset - 71, -2)

                toggle.ListLayout = Instance.new("UIListLayout", toggle.Items)
                toggle.ListLayout.FillDirection = Enum.FillDirection.Horizontal
                toggle.ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
                toggle.ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
                toggle.ListLayout.Padding = UDim.new(0, 6)

                toggle.ListPadding = Instance.new("UIPadding", toggle.Items)
                toggle.ListPadding.PaddingTop = UDim.new(0, 2)
                toggle.ListPadding.PaddingRight = UDim.new(0, 2)

                function toggle:Set(value) 
                    toggle.value = value
                    toggle.CheckedFrame.Visible = value
                    pcall(toggle.callback, value) 
                end
                toggle:Set(toggle.default)

                function toggle:AddKeybind(default)
                    local keybind = { }

                    keybind.default = default or "None"
                    keybind.value = keybind.default

                    local defaultKey = (typeof(keybind.default) == "EnumItem" and keybind.default.Name) or "None"
                    local text = defaultKey == "None" and "[None]" or "[" .. defaultKey .. "]"
                    local size = textservice:GetTextSize(text, 13, Enum.Font.Code, Vector2.new(2000, 2000))

                    keybind.Main = Instance.new("TextButton", toggle.Items)
                    keybind.Main.Name = "keybind"
                    keybind.Main.BackgroundTransparency = 1
                    keybind.Main.BorderSizePixel = 0
                    keybind.Main.ZIndex = 2
                    keybind.Main.Size = UDim2.fromOffset(size.X + 2, size.Y)
                    keybind.Main.Text = text
                    keybind.Main.Font = Enum.Font.Code
                    keybind.Main.TextColor3 = Color3.fromRGB(136, 136, 136)
                    keybind.Main.TextSize = 13
                    keybind.Main.TextXAlignment = Enum.TextXAlignment.Right
                    keybind.Main.MouseButton1Down:Connect(function()
                        keybind.Main.Text = "..."
                    end)

                    game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
                        if not gameProcessed then
                            if keybind.Main.Text == "..." then
                                if input.UserInputType == Enum.UserInputType.Keyboard then
                                    keybind.Main.Text = "[" .. input.KeyCode.Name .. "]"
                                    keybind.value = input.KeyCode
                                else
                                    keybind.Main.Text = "[None]"
                                    keybind.value = "None"
                                end
                            else
                                if keybind.value ~= "None" and input.KeyCode == keybind.value then
                                    toggle:Set(not toggle.CheckedFrame.Visible)
                                end
                            end
                        end
                    end)

                    return keybind
                end

                function toggle:AddColorpicker(default,callback)
                    local colorpicker = { }

                    colorpicker.callback = callback or function() end
                    colorpicker.default = default or Color3.fromRGB(255, 255, 255)
                    colorpicker.value = colorpicker.default
                    colorpicker.MainPicker = nil -- predeclare for type safety

                    colorpicker.Main = Instance.new("Frame", toggle.Items)
                    colorpicker.Main.ZIndex = 6
                    colorpicker.Main.BorderSizePixel = 0
                    colorpicker.Main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    colorpicker.Main.Size = UDim2.fromOffset(16, 10)

                    colorpicker.Gradient = Instance.new("UIGradient", colorpicker.Main)
                    colorpicker.Gradient.Rotation = 90
                    local function refreshSwatch()
                        local clr = Color3.new(math.clamp(colorpicker.value.R / 1.7, 0, 1), math.clamp(colorpicker.value.G / 1.7, 0, 1), math.clamp(colorpicker.value.B / 1.7, 0, 1))
                        colorpicker.Gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, colorpicker.value), ColorSequenceKeypoint.new(1.00, clr)})
                    end
                    refreshSwatch()

                    colorpicker.Outline = Instance.new("Frame", colorpicker.Main)
                    colorpicker.Outline.Name = "outline"
                    colorpicker.Outline.ZIndex = 5
                    colorpicker.Outline.Size = colorpicker.Main.Size + UDim2.fromOffset(2, 2)
                    colorpicker.Outline.BorderSizePixel = 0
                    colorpicker.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    colorpicker.Outline.Position = UDim2.fromOffset(-1, -1)
    
                    colorpicker.BlackOutline = Instance.new("Frame", colorpicker.Main)
                    colorpicker.BlackOutline.Name = "blackline"
                    colorpicker.BlackOutline.ZIndex = 4
                    colorpicker.BlackOutline.Size = colorpicker.Main.Size + UDim2.fromOffset(4, 4)
                    colorpicker.BlackOutline.BorderSizePixel = 0
                    colorpicker.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                    colorpicker.BlackOutline.Position = UDim2.fromOffset(-2, -2)

                    colorpicker.BlackOutline.MouseEnter:Connect(function()
                        colorpicker.Outline.BackgroundColor3 = window.accentcolor
                        colorpicker.BlackOutline.BackgroundColor3 = window.accentcolor
                        colorpicker.Outline.BackgroundTransparency = 0.4
                        colorpicker.BlackOutline.BackgroundTransparency = 0.5
                    end)
                    -- MouseLeave deferred until after MainPicker exists

                    colorpicker.MainPicker = Instance.new("Frame", colorpicker.Main)
                    colorpicker.MainPicker.Name = "picker"
                    colorpicker.BlackOutline.MouseLeave:Connect(function()
                        if not window.OpenedColorPickers[colorpicker.MainPicker] then
                            colorpicker.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                            colorpicker.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                            colorpicker.Outline.BackgroundTransparency = 0
                            colorpicker.BlackOutline.BackgroundTransparency = 0
                        end
                    end)
                    colorpicker.MainPicker.ZIndex = 100
                    colorpicker.MainPicker.Visible = false
                    window.OpenedColorPickers[colorpicker.MainPicker] = false
                    colorpicker.MainPicker.Size = UDim2.fromOffset(160, 178)
                    colorpicker.MainPicker.BorderSizePixel = 0
                    colorpicker.MainPicker.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                    colorpicker.MainPicker.Position = UDim2.fromOffset(-colorpicker.MainPicker.AbsoluteSize.X + colorpicker.Main.AbsoluteSize.X, 15)

                    colorpicker.Outline2 = Instance.new("TextButton", colorpicker.MainPicker)
                    colorpicker.Outline2.AutoButtonColor = false
                    colorpicker.Outline2.Name = "outline"
                    colorpicker.Outline2.ZIndex = 99
                    colorpicker.Outline2.Size = colorpicker.MainPicker.Size + UDim2.fromOffset(2, 2)
                    colorpicker.Outline2.BorderSizePixel = 0
                    colorpicker.Outline2.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    colorpicker.Outline2.Position = UDim2.fromOffset(-1, -1)
    
                    colorpicker.BlackOutline2 = Instance.new("Frame", colorpicker.MainPicker)
                    colorpicker.BlackOutline2.Name = "blackline"
                    colorpicker.BlackOutline2.ZIndex = 98
                    colorpicker.BlackOutline2.Size = colorpicker.MainPicker.Size + UDim2.fromOffset(4, 4)
                    colorpicker.BlackOutline2.BorderSizePixel = 0
                    colorpicker.BlackOutline2.BackgroundColor3 = Color3.new(0, 0, 0)
                    colorpicker.BlackOutline2.Position = UDim2.fromOffset(-2, -2)

                    colorpicker.hue = Instance.new("ImageLabel", colorpicker.MainPicker)
                    colorpicker.hue.ZIndex = 101
                    colorpicker.hue.Position = UDim2.new(0,5,0,5)
                    colorpicker.hue.Size = UDim2.new(0,150,0,150)
                    colorpicker.hue.Image = "rbxassetid://4155801252"
                    colorpicker.hue.ScaleType = Enum.ScaleType.Stretch
                    colorpicker.hue.BackgroundColor3 = Color3.new(1,0,0)
                    colorpicker.hue.BorderColor3 = Color3.fromRGB(0, 0, 0)

                    colorpicker.hueselectorpointer = Instance.new("ImageLabel", colorpicker.MainPicker)
                    colorpicker.hueselectorpointer.ZIndex = 101
                    colorpicker.hueselectorpointer.BackgroundTransparency = 1
                    colorpicker.hueselectorpointer.BorderSizePixel = 0
                    colorpicker.hueselectorpointer.Position = UDim2.new(0, 0, 0, 0)
                    colorpicker.hueselectorpointer.Size = UDim2.new(0, 7, 0, 7)
                    colorpicker.hueselectorpointer.Image = "rbxassetid://6885856475"

                    colorpicker.selector = Instance.new("TextLabel", colorpicker.MainPicker)
                    colorpicker.selector.ZIndex = 100
                    colorpicker.selector.Position = UDim2.new(0,5,0,163)
                    colorpicker.selector.Size = UDim2.new(0,150,0,10)
                    colorpicker.selector.BackgroundColor3 = Color3.fromRGB(255,255,255)
                    colorpicker.selector.BorderColor3 = Color3.new(0, 0, 0)
                    colorpicker.selector.Text = ""
        
                    colorpicker.gradient = Instance.new("UIGradient", colorpicker.selector)
                    colorpicker.gradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.new(1,0,0)),
                        ColorSequenceKeypoint.new(0.25,Color3.new(1,0,1)),
                        ColorSequenceKeypoint.new(0.5,Color3.new(0,1,1)),
                        ColorSequenceKeypoint.new(0.75,Color3.new(1,1,0)),
                        ColorSequenceKeypoint.new(1,Color3.new(1,0,0)),
                    })

                    colorpicker.pointer = Instance.new("Frame", colorpicker.selector)
                    colorpicker.pointer.ZIndex = 101
                    colorpicker.pointer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                    colorpicker.pointer.Position = UDim2.new(0,0,0,0)
                    colorpicker.pointer.Size = UDim2.new(0,2,0,10)
                    colorpicker.pointer.BorderColor3 = Color3.fromRGB(255, 255, 255)

                    function colorpicker:RefreshSelector()
                        local pos = math.clamp((mouse.X - colorpicker.hue.AbsolutePosition.X) / colorpicker.hue.AbsoluteSize.X, 0, 1)
                        colorpicker.color = 1 - pos
                        colorpicker.pointer:TweenPosition(UDim2.new(pos, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.05)
                        colorpicker.hue.BackgroundColor3 = Color3.fromHSV(1 - pos, 1, 1)
                    end

                    function colorpicker:RefreshHue()
                        local x = (mouse.X - colorpicker.hue.AbsolutePosition.X) / colorpicker.hue.AbsoluteSize.X
                        local y = (mouse.Y - colorpicker.hue.AbsolutePosition.Y) / colorpicker.hue.AbsoluteSize.Y
                        colorpicker.hueselectorpointer:TweenPosition(UDim2.new(math.clamp(x * colorpicker.hue.AbsoluteSize.X, 0.5, 0.945 * colorpicker.hue.AbsoluteSize.X) / colorpicker.hue.AbsoluteSize.X, 0, math.clamp(y * colorpicker.hue.AbsoluteSize.Y, 0.5, 0.855 * colorpicker.hue.AbsoluteSize.Y) / colorpicker.hue.AbsoluteSize.Y, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.05)
                        colorpicker:Set(Color3.fromHSV(colorpicker.color, math.clamp(x * colorpicker.hue.AbsoluteSize.X, 0.5, 1 * colorpicker.hue.AbsoluteSize.X) / colorpicker.hue.AbsoluteSize.X, 1 - (math.clamp(y * colorpicker.hue.AbsoluteSize.Y, 0.5, 1 * colorpicker.hue.AbsoluteSize.Y) / colorpicker.hue.AbsoluteSize.Y)))
                    end

                    function colorpicker:Set(value)
                        local color = Color3.new(math.clamp(value.r, 0, 1), math.clamp(value.g, 0, 1), math.clamp(value.b, 0, 1))
                        colorpicker.value = color
                        refreshSwatch()
                        pcall(colorpicker.callback, color)
                    end
                    colorpicker:Set(colorpicker.default)

                    local dragging_selector = false
                    local dragging_hue = false

                    colorpicker.selector.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging_selector = true
                            colorpicker:RefreshSelector()
                        end
                    end)
    
                    colorpicker.selector.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging_selector = false
                            colorpicker:RefreshSelector()
                        end
                    end)

                    colorpicker.hue.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging_hue = true
                            colorpicker:RefreshHue()
                        end
                    end)
    
                    colorpicker.hue.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            dragging_hue = false
                            colorpicker:RefreshHue()
                        end
                    end)
    
                    game:GetService("UserInputService").InputChanged:Connect(function(input)
                        if dragging_selector and input.UserInputType == Enum.UserInputType.MouseMovement then
                            colorpicker:RefreshSelector()
                        end
                        if dragging_hue and input.UserInputType == Enum.UserInputType.MouseMovement then
                            colorpicker:RefreshHue()
                        end
                    end)

                    local inputBegan = function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            for i,v in pairs(window.OpenedColorPickers) do
                                if v and i ~= colorpicker.MainPicker then
                                    i.Visible = false
                                    window.OpenedColorPickers[i] = false
                                end
                            end

                            colorpicker.MainPicker.Visible = not colorpicker.MainPicker.Visible
                            window.OpenedColorPickers[colorpicker.MainPicker] = colorpicker.MainPicker.Visible
                            if window.OpenedColorPickers[colorpicker.MainPicker] then
                                colorpicker.Outline.BackgroundColor3 = window.accentcolor
                                colorpicker.BlackOutline.BackgroundColor3 = window.accentcolor
                                colorpicker.Outline.BackgroundTransparency = 0.4
                                colorpicker.BlackOutline.BackgroundTransparency = 0.5
                            else
                                colorpicker.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                                colorpicker.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                                colorpicker.Outline.BackgroundTransparency = 0
                                colorpicker.BlackOutline.BackgroundTransparency = 0
                            end
                        end
                    end

                    colorpicker.Main.InputBegan:Connect(inputBegan)
                    colorpicker.Outline.InputBegan:Connect(inputBegan)
                    colorpicker.BlackOutline.InputBegan:Connect(inputBegan)

                    return colorpicker
                end

                toggle.Main.MouseButton1Down:Connect(function()
                    toggle:Set(not toggle.CheckedFrame.Visible)
                end)
                toggle.Label.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        toggle:Set(not toggle.CheckedFrame.Visible)
                    end
                end)

                local MouseEnter = function()
                    toggle.Outline.BackgroundColor3 = window.accentcolor
                    toggle.BlackOutline.BackgroundColor3 = window.accentcolor
                    toggle.Outline.BackgroundTransparency = 0.4
                    toggle.BlackOutline.BackgroundTransparency = 0.5
                end
                local MouseLeave = function()
                    toggle.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    toggle.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                    toggle.Outline.BackgroundTransparency = 0
                    toggle.BlackOutline.BackgroundTransparency = 0
                end

                toggle.Label.MouseEnter:Connect(MouseEnter)
                toggle.Label.MouseLeave:Connect(MouseLeave)
                toggle.BlackOutline.MouseEnter:Connect(MouseEnter)
                toggle.BlackOutline.MouseLeave:Connect(MouseLeave)

                sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, sector.ListLayout.AbsoluteContentSize.Y + 18)
                tab.TabPage.CanvasSize = sector.Main.Size

                return toggle
            end
            
            function sector:AddTextbox(text,default,callback)
                local textbox = { }
                textbox.text = text or ""
                textbox.callback = callback or function() end
                textbox.default = default

                textbox.Holder = Instance.new("Frame", sector.Items)
                textbox.Holder.Name = "holder"
                textbox.Holder.ZIndex = 4
                textbox.Holder.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 12, 14)
                textbox.Holder.BorderSizePixel = 0
                textbox.Holder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

                textbox.Gradient = Instance.new("UIGradient", textbox.Holder)
                textbox.Gradient.Rotation = 90
                textbox.Gradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(49, 49, 49)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(39, 39, 39))}

                textbox.Main = Instance.new("TextBox", textbox.Holder)
                textbox.Main.PlaceholderText = textbox.text
                textbox.Main.PlaceholderColor3 = Color3.fromRGB(190, 190, 190)
                textbox.Main.Text = ""
                textbox.Main.BackgroundTransparency = 1
                textbox.Main.Font = Enum.Font.Code
                textbox.Main.Name = "textbox"
                textbox.Main.MultiLine = false
                textbox.Main.ZIndex = 5
                textbox.Main.TextScaled = true
                textbox.Main.Size = textbox.Holder.Size
                textbox.Main.TextSize = 13
                textbox.Main.TextColor3 = Color3.fromRGB(255, 255, 255)
                textbox.Main.BorderSizePixel = 0
                textbox.Main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                textbox.Main:GetPropertyChangedSignal("Text"):Connect(function()
                    pcall(textbox.callback, textbox.Main.Text)
                end)

                textbox.Outline = Instance.new("Frame", textbox.Main)
                textbox.Outline.Name = "blackline"
                textbox.Outline.ZIndex = 3
                textbox.Outline.Size = textbox.Holder.Size + UDim2.fromOffset(2, 2)
                textbox.Outline.BorderSizePixel = 0
                textbox.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                textbox.Outline.Position = UDim2.fromOffset(-1, -1)

                textbox.BlackOutline = Instance.new("Frame", textbox.Main)
                textbox.BlackOutline.Name = "blackline"
                textbox.BlackOutline.ZIndex = 2
                textbox.BlackOutline.Size = textbox.Holder.Size + UDim2.fromOffset(4, 4)
                textbox.BlackOutline.BorderSizePixel = 0
                textbox.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                textbox.BlackOutline.Position = UDim2.fromOffset(-2, -2)

                textbox.BlackOutline.MouseEnter:Connect(function()
                    textbox.Outline.BackgroundColor3 = window.accentcolor
                    textbox.BlackOutline.BackgroundColor3 = window.accentcolor
                    textbox.Outline.BackgroundTransparency = 0.4
                    textbox.BlackOutline.BackgroundTransparency = 0.5
                end)
                textbox.BlackOutline.MouseLeave:Connect(function()
                    textbox.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    textbox.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                    textbox.Outline.BackgroundTransparency = 0
                    textbox.BlackOutline.BackgroundTransparency = 0
                end)

                function textbox:Set(text)
                    textbox.Main.Text = text
                end
                if textbox.default then 
                    textbox:Set(textbox.default)
                end

                sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, sector.ListLayout.AbsoluteContentSize.Y + 18)
                tab.TabPage.CanvasSize = sector.Main.Size

                return textbox
            end

            function sector:AddSlider(text,min,default,max,decimals,callback)
                local slider = { }
                slider.text = text or ""
                slider.callback = callback or function(value) end
                slider.min = min or 0
                slider.max = max or 100
                slider.decimals = decimals or 1
                slider.default = default or slider.min

                slider.value = slider.default
                local dragging = false

                slider.BackLabel = Instance.new("Frame", sector.Items)
                slider.BackLabel.Name = "backlabel"
                slider.BackLabel.ZIndex = 3
                slider.BackLabel.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 12, 10)
                slider.BackLabel.BorderSizePixel = 0
                slider.BackLabel.BackgroundTransparency = 1

                slider.Label = Instance.new("TextLabel", slider.BackLabel)
                slider.Label.BackgroundTransparency = 1
                slider.Label.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 12, 10)
                slider.Label.Font = Enum.Font.Code
                slider.Label.Text = slider.text .. ": " .. tostring(slider.default)
                slider.Label.TextColor3 = Color3.fromRGB(200, 200, 200)
                slider.Label.Position = UDim2.fromOffset(0, 3)
                slider.Label.TextSize = 13
                slider.Label.ZIndex = 2
                slider.Label.TextStrokeTransparency = 1
                slider.Label.TextXAlignment = Enum.TextXAlignment.Left

                slider.Main = Instance.new("TextButton", sector.Items)
                slider.Main.Name = "slider"
                slider.Main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                slider.Main.BorderSizePixel = 0
                slider.Main.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 12, 10)
                slider.Main.AutoButtonColor = false
                slider.Main.Text = ""
                slider.Main.ZIndex = 4

                slider.Outline = Instance.new("Frame", slider.Main)
                slider.Outline.Name = "blackline"
                slider.Outline.ZIndex = 3
                slider.Outline.Size = slider.Main.Size + UDim2.fromOffset(2, 2)
                slider.Outline.BorderSizePixel = 0
                slider.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                slider.Outline.Position = UDim2.fromOffset(-1, -1)

                slider.BlackOutline = Instance.new("Frame", slider.Main)
                slider.BlackOutline.Name = "blackline"
                slider.BlackOutline.ZIndex = 2
                slider.BlackOutline.Size = slider.Main.Size + UDim2.fromOffset(4, 4)
                slider.BlackOutline.BorderSizePixel = 0
                slider.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                slider.BlackOutline.Position = UDim2.fromOffset(-2, -2)

                slider.Gradient = Instance.new("UIGradient", slider.Main)
                slider.Gradient.Rotation = 90
                slider.Gradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(49, 49, 49)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(41, 41, 41))}

                slider.SlideBar = Instance.new("Frame", slider.Main)
                slider.SlideBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255) --Color3.fromRGB(204, 0, 102)
                slider.SlideBar.ZIndex = 4
                slider.SlideBar.BorderSizePixel = 0
                slider.SlideBar.Size = UDim2.fromOffset(0, slider.Main.Size.Y.Offset)

                slider.Gradient2 = Instance.new("UIGradient", slider.SlideBar)
                slider.Gradient2.Rotation = 90
                local function updateSliderGrad()
                    slider.Gradient2.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, window.accentcolor), ColorSequenceKeypoint.new(1.00, window.accentcolor2)})
                end
                updateSliderGrad()
                table.insert(window._accentCallbacks, function() updateSliderGrad() end)

                slider.BlackOutline.MouseEnter:Connect(function()
                    slider.Outline.BackgroundColor3 = window.accentcolor
                    slider.BlackOutline.BackgroundColor3 = window.accentcolor
                    slider.Outline.BackgroundTransparency = 0.4
                    slider.BlackOutline.BackgroundTransparency = 0.5
                end)
                slider.BlackOutline.MouseLeave:Connect(function()
                    slider.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    slider.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                    slider.Outline.BackgroundTransparency = 0
                    slider.BlackOutline.BackgroundTransparency = 0
                end)

                function slider:Set(value)
                    slider.value = value
                    value = roundTo(value, slider.decimals)
                    local percent = (value - slider.min) / (slider.max - slider.min)
                    percent = math.clamp(percent, 0, 1)
                    shortTween(slider.SlideBar, {Size = UDim2.fromOffset(percent * slider.Main.Size.X.Offset, slider.Main.Size.Y.Offset)}, 0.05)
                    slider.Label.Text = slider.text .. ": " .. tostring(value)
                    pcall(slider.callback, value)
                end
                slider:Set(slider.default)

                function slider:Refresh()
                    local percent = math.clamp(mouse.X - slider.SlideBar.AbsolutePosition.X, 0, slider.Main.Size.X.Offset) / slider.Main.Size.X.Offset
                    local value = slider.min + (slider.max - slider.min) * percent
                    slider:Set(value)
                end

                slider.SlideBar.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        slider:Refresh()
                    end
                end)

                slider.SlideBar.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)

                slider.Main.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        slider:Refresh()
                    end
                end)

                slider.Main.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)

                track(window, UserInputService.InputChanged, function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        slider:Refresh()
                    end
                end)

                sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, sector.ListLayout.AbsoluteContentSize.Y + 18)
                tab.TabPage.CanvasSize = sector.Main.Size

                return slider
            end

            function sector:AddColorpicker(text, default, callback)
                local colorpicker = { }

                colorpicker.text = text or ""
                colorpicker.callback = callback or function() end
                colorpicker.default = default or Color3.fromRGB(255, 255, 255)
                colorpicker.value = colorpicker.default
                colorpicker.MainPicker = nil -- predeclare

                colorpicker.Label = Instance.new("TextLabel", sector.Items)
                colorpicker.Label.BackgroundTransparency = 1
                colorpicker.Label.Size = UDim2.fromOffset(156, 10)
                colorpicker.Label.ZIndex = 2
                colorpicker.Label.Font = Enum.Font.Code
                colorpicker.Label.Text = colorpicker.text
                colorpicker.Label.TextColor3 = Color3.fromRGB(200, 200, 200)
                colorpicker.Label.TextSize = 13
                colorpicker.Label.TextStrokeTransparency = 1
                colorpicker.Label.TextXAlignment = Enum.TextXAlignment.Left

                colorpicker.Main = Instance.new("Frame", colorpicker.Label)
                colorpicker.Main.ZIndex = 6
                colorpicker.Main.BorderSizePixel = 0
                colorpicker.Main.Position = UDim2.fromOffset(sector.Main.Size.X.Offset - 29, 0)
                colorpicker.Main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                colorpicker.Main.Size = UDim2.fromOffset(16, 10)

                colorpicker.Gradient = Instance.new("UIGradient", colorpicker.Main)
                colorpicker.Gradient.Rotation = 90
                local function refreshSwatch()
                    local clr = Color3.new(math.clamp(colorpicker.value.R / 1.7, 0, 1), math.clamp(colorpicker.value.G / 1.7, 0, 1), math.clamp(colorpicker.value.B / 1.7, 0, 1))
                    colorpicker.Gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0.00, colorpicker.value), ColorSequenceKeypoint.new(1.00, clr)})
                end
                refreshSwatch()

                colorpicker.Outline = Instance.new("Frame", colorpicker.Main)
                colorpicker.Outline.Name = "outline"
                colorpicker.Outline.ZIndex = 5
                colorpicker.Outline.Size = colorpicker.Main.Size + UDim2.fromOffset(2, 2)
                colorpicker.Outline.BorderSizePixel = 0
                colorpicker.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                colorpicker.Outline.Position = UDim2.fromOffset(-1, -1)

                colorpicker.BlackOutline = Instance.new("Frame", colorpicker.Main)
                colorpicker.BlackOutline.Name = "blackline"
                colorpicker.BlackOutline.ZIndex = 4
                colorpicker.BlackOutline.Size = colorpicker.Main.Size + UDim2.fromOffset(4, 4)
                colorpicker.BlackOutline.BorderSizePixel = 0
                colorpicker.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                colorpicker.BlackOutline.Position = UDim2.fromOffset(-2, -2)

                colorpicker.BlackOutline.MouseEnter:Connect(function()
                    colorpicker.Outline.BackgroundColor3 = window.accentcolor
                    colorpicker.BlackOutline.BackgroundColor3 = window.accentcolor
                    colorpicker.Outline.BackgroundTransparency = 0.4
                    colorpicker.BlackOutline.BackgroundTransparency = 0.5
                end)
                -- leave handler added after MainPicker exists

                colorpicker.MainPicker = Instance.new("Frame", colorpicker.Main)
                colorpicker.MainPicker.Name = "picker"
                colorpicker.BlackOutline.MouseLeave:Connect(function()
                    if not window.OpenedColorPickers[colorpicker.MainPicker] then
                        colorpicker.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                        colorpicker.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                        colorpicker.Outline.BackgroundTransparency = 0
                        colorpicker.BlackOutline.BackgroundTransparency = 0
                    end
                end)
                colorpicker.MainPicker.ZIndex = 100
                colorpicker.MainPicker.Visible = false
                window.OpenedColorPickers[colorpicker.MainPicker] = false
                colorpicker.MainPicker.Size = UDim2.fromOffset(160, 178)
                colorpicker.MainPicker.BorderSizePixel = 0
                colorpicker.MainPicker.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                colorpicker.MainPicker.Position = UDim2.fromOffset(-colorpicker.MainPicker.AbsoluteSize.X + colorpicker.Main.AbsoluteSize.X, 15)

                colorpicker.Outline2 = Instance.new("TextButton", colorpicker.MainPicker)
                colorpicker.Outline2.AutoButtonColor = false
                colorpicker.Outline2.Name = "outline"
                colorpicker.Outline2.ZIndex = 99
                colorpicker.Outline2.Size = colorpicker.MainPicker.Size + UDim2.fromOffset(2, 2)
                colorpicker.Outline2.BorderSizePixel = 0
                colorpicker.Outline2.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                colorpicker.Outline2.Position = UDim2.fromOffset(-1, -1)

                colorpicker.BlackOutline2 = Instance.new("Frame", colorpicker.MainPicker)
                colorpicker.BlackOutline2.Name = "blackline"
                colorpicker.BlackOutline2.ZIndex = 98
                colorpicker.BlackOutline2.Size = colorpicker.MainPicker.Size + UDim2.fromOffset(4, 4)
                colorpicker.BlackOutline2.BorderSizePixel = 0
                colorpicker.BlackOutline2.BackgroundColor3 = Color3.new(0, 0, 0)
                colorpicker.BlackOutline2.Position = UDim2.fromOffset(-2, -2)

                colorpicker.hue = Instance.new("ImageLabel", colorpicker.MainPicker)
                colorpicker.hue.ZIndex = 101
                colorpicker.hue.Position = UDim2.new(0,5,0,5)
                colorpicker.hue.Size = UDim2.new(0,150,0,150)
                colorpicker.hue.Image = "rbxassetid://4155801252"
                colorpicker.hue.ScaleType = Enum.ScaleType.Stretch
                colorpicker.hue.BackgroundColor3 = Color3.new(1,0,0)
                colorpicker.hue.BorderColor3 = Color3.fromRGB(0, 0, 0)

                colorpicker.hueselectorpointer = Instance.new("ImageLabel", colorpicker.MainPicker)
                colorpicker.hueselectorpointer.ZIndex = 101
                colorpicker.hueselectorpointer.BackgroundTransparency = 1
                colorpicker.hueselectorpointer.BorderSizePixel = 0
                colorpicker.hueselectorpointer.Position = UDim2.new(0, 0, 0, 0)
                colorpicker.hueselectorpointer.Size = UDim2.new(0, 7, 0, 7)
                colorpicker.hueselectorpointer.Image = "rbxassetid://6885856475"

                colorpicker.selector = Instance.new("TextLabel", colorpicker.MainPicker)
                colorpicker.selector.ZIndex = 100
                colorpicker.selector.Position = UDim2.new(0,5,0,163)
                colorpicker.selector.Size = UDim2.new(0,150,0,10)
                colorpicker.selector.BackgroundColor3 = Color3.fromRGB(255,255,255)
                colorpicker.selector.BorderColor3 = Color3.new(0, 0, 0)
                colorpicker.selector.Text = ""
    
                colorpicker.gradient = Instance.new("UIGradient", colorpicker.selector)
                colorpicker.gradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(1,0,0)),
                    ColorSequenceKeypoint.new(0.25,Color3.new(1,0,1)),
                    ColorSequenceKeypoint.new(0.5,Color3.new(0,1,1)),
                    ColorSequenceKeypoint.new(0.75,Color3.new(1,1,0)),
                    ColorSequenceKeypoint.new(1,Color3.new(1,0,0)),
                })

                colorpicker.pointer = Instance.new("Frame", colorpicker.selector)
                colorpicker.pointer.ZIndex = 101
                colorpicker.pointer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                colorpicker.pointer.Position = UDim2.new(0,0,0,0)
                colorpicker.pointer.Size = UDim2.new(0,2,0,10)
                colorpicker.pointer.BorderColor3 = Color3.fromRGB(255, 255, 255)

                function colorpicker:RefreshSelector()
                    local pos = math.clamp((mouse.X - colorpicker.hue.AbsolutePosition.X) / colorpicker.hue.AbsoluteSize.X, 0, 1)
                    colorpicker.color = 1 - pos
                    colorpicker.pointer:TweenPosition(UDim2.new(pos, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.05)
                    colorpicker.hue.BackgroundColor3 = Color3.fromHSV(1 - pos, 1, 1)
                end

                function colorpicker:RefreshHue()
                    local x = (mouse.X - colorpicker.hue.AbsolutePosition.X) / colorpicker.hue.AbsoluteSize.X
                    local y = (mouse.Y - colorpicker.hue.AbsolutePosition.Y) / colorpicker.hue.AbsoluteSize.Y
                    colorpicker.hueselectorpointer:TweenPosition(UDim2.new(math.clamp(x * colorpicker.hue.AbsoluteSize.X, 0.5, 0.945 * colorpicker.hue.AbsoluteSize.X) / colorpicker.hue.AbsoluteSize.X, 0, math.clamp(y * colorpicker.hue.AbsoluteSize.Y, 0.5, 0.855 * colorpicker.hue.AbsoluteSize.Y) / colorpicker.hue.AbsoluteSize.Y, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, 0.05)
                    colorpicker:Set(Color3.fromHSV(colorpicker.color, math.clamp(x * colorpicker.hue.AbsoluteSize.X, 0.5, 1 * colorpicker.hue.AbsoluteSize.X) / colorpicker.hue.AbsoluteSize.X, 1 - (math.clamp(y * colorpicker.hue.AbsoluteSize.Y, 0.5, 1 * colorpicker.hue.AbsoluteSize.Y) / colorpicker.hue.AbsoluteSize.Y)))
                end

                function colorpicker:Set(value)
                    local color = Color3.new(math.clamp(value.r, 0, 1), math.clamp(value.g, 0, 1), math.clamp(value.b, 0, 1))
                    colorpicker.value = color
                    refreshSwatch()
                    pcall(colorpicker.callback, color)
                end
                colorpicker:Set(colorpicker.default)

                local dragging_selector = false
                local dragging_hue = false

                colorpicker.selector.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging_selector = true
                        colorpicker:RefreshSelector()
                    end
                end)

                colorpicker.selector.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging_selector = false
                        colorpicker:RefreshSelector()
                    end
                end)

                colorpicker.hue.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging_hue = true
                        colorpicker:RefreshHue()
                    end
                end)

                colorpicker.hue.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging_hue = false
                        colorpicker:RefreshHue()
                    end
                end)

                game:GetService("UserInputService").InputChanged:Connect(function(input)
                    if dragging_selector and input.UserInputType == Enum.UserInputType.MouseMovement then
                        colorpicker:RefreshSelector()
                    end
                    if dragging_hue and input.UserInputType == Enum.UserInputType.MouseMovement then
                        colorpicker:RefreshHue()
                    end
                end)

                local inputBegan = function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        for i,v in pairs(window.OpenedColorPickers) do
                            if v and i ~= colorpicker.MainPicker then
                                i.Visible = false
                                window.OpenedColorPickers[i] = false
                            end
                        end

                        colorpicker.MainPicker.Visible = not colorpicker.MainPicker.Visible
                        window.OpenedColorPickers[colorpicker.MainPicker] = colorpicker.MainPicker.Visible
                        if window.OpenedColorPickers[colorpicker.MainPicker] then
                            colorpicker.Outline.BackgroundColor3 = window.accentcolor
                            colorpicker.BlackOutline.BackgroundColor3 = window.accentcolor
                            colorpicker.Outline.BackgroundTransparency = 0.4
                            colorpicker.BlackOutline.BackgroundTransparency = 0.5
                        else
                            colorpicker.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                            colorpicker.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                            colorpicker.Outline.BackgroundTransparency = 0
                            colorpicker.BlackOutline.BackgroundTransparency = 0
                        end
                    end
                end

                colorpicker.Main.InputBegan:Connect(inputBegan)
                colorpicker.Outline.InputBegan:Connect(inputBegan)
                colorpicker.BlackOutline.InputBegan:Connect(inputBegan)

                sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, sector.ListLayout.AbsoluteContentSize.Y + 18)
                tab.TabPage.CanvasSize = sector.Main.Size

                return colorpicker
            end

            function sector:AddKeybind(text,default,newkeycallback,callback)
                local keybind = { }

                keybind.text = text or ""
                keybind.default = default or "None"
                keybind.callback = callback or function() end
                keybind.newkeycallback = newkeycallback or function(key) end

                keybind.value = keybind.default

                keybind.Main = Instance.new("TextLabel", sector.Items)
                keybind.Main.BackgroundTransparency = 1
                keybind.Main.Size = UDim2.fromOffset(156, 10)
                keybind.Main.ZIndex = 2
                keybind.Main.Font = Enum.Font.Code
                keybind.Main.Text = keybind.text
                keybind.Main.TextColor3 = Color3.fromRGB(200, 200, 200)
                keybind.Main.TextSize = 13
                keybind.Main.TextStrokeTransparency = 1
                keybind.Main.TextXAlignment = Enum.TextXAlignment.Left

                keybind.Bind = Instance.new("TextButton", keybind.Main)
                keybind.Bind.Name = "keybind"
                keybind.Bind.BackgroundTransparency = 1
                keybind.Bind.BorderColor3 = Color3.fromRGB(60, 60, 60)
                keybind.Bind.ZIndex = 2
                keybind.Bind.BorderSizePixel = 0
                keybind.Bind.Position = UDim2.fromOffset(sector.Main.Size.X.Offset - 50, 0)
                keybind.Bind.Size = UDim2.fromOffset(37, 10)
                keybind.Bind.Font = Enum.Font.Code
                keybind.Bind.Text = keybind.default == "None" and "[None]" or "[" .. keybind.default.Name .. "]"
                keybind.Bind.TextColor3 = Color3.fromRGB(136, 136, 136)
                keybind.Bind.TextSize = 14
                keybind.Bind.TextXAlignment = Enum.TextXAlignment.Right
                keybind.Bind.MouseButton1Down:Connect(function()
                    keybind.Bind.Text = "..."
                end)

                function keybind:Set(value)
                    keybind.Bind.Text = "[" .. value.Name .. "]"
                    pcall(keybind.newkeycallback, value)
                end

                game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
                    if not gameProcessed then
                        if keybind.Bind.Text == "..." then
                            if input.UserInputType == Enum.UserInputType.Keyboard then
                                keybind.Bind.Text = "[" .. input.KeyCode.Name .. "]"
                                keybind.value = input.KeyCode
                            else
                                keybind.Bind.Text = "[None]"
                                keybind.value = "None"
                            end
                            pcall(keybind.newkeycallback, keybind.value)
                        else
                            if keybind.value ~= "None" and input.KeyCode == keybind.value then
                                pcall(keybind.callback)
                            end
                        end
                    end
                end)

                sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, sector.ListLayout.AbsoluteContentSize.Y + 18)
                tab.TabPage.CanvasSize = sector.Main.Size

                return keybind
            end

            function sector:AddDropdown(text,items,default,callback)
                local dropdown = { }

                dropdown.text = text or ""
                dropdown.items = items or { }
                dropdown.default = default
                dropdown.callback = callback or function() end
                dropdown.value = dropdown.default
                dropdown.OutlineItems = nil
                dropdown.BlackOutlineItems = nil

                dropdown.BackLabel = Instance.new("Frame", sector.Items)
                dropdown.BackLabel.Name = "backlabel"
                dropdown.BackLabel.ZIndex = 3
                dropdown.BackLabel.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 12, 10)
                dropdown.BackLabel.BorderSizePixel = 0
                dropdown.BackLabel.BackgroundTransparency = 1

                dropdown.Label = Instance.new("TextLabel", dropdown.BackLabel)
                dropdown.Label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                dropdown.Label.BackgroundTransparency = 1
                dropdown.Label.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 12, 10)
                dropdown.Label.Position = UDim2.fromOffset(0, 3)
                dropdown.Label.Font = Enum.Font.Code
                dropdown.Label.Text = dropdown.text
                dropdown.Label.ZIndex = 4
                dropdown.Label.TextColor3 = Color3.fromRGB(200, 200, 200)
                dropdown.Label.TextSize = 13
                dropdown.Label.TextStrokeTransparency = 1
                dropdown.Label.TextXAlignment = Enum.TextXAlignment.Left

                dropdown.Main = Instance.new("TextButton", sector.Items)
                dropdown.Main.Name = "dropdown"
                dropdown.Main.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                dropdown.Main.BorderSizePixel = 0
                dropdown.Main.Size = UDim2.fromOffset(sector.Main.Size.X.Offset - 12, 16)
                dropdown.Main.ZIndex = 4
                dropdown.Main.AutoButtonColor = false
                dropdown.Main.Font = Enum.Font.Code
                dropdown.Main.Text = ""
                dropdown.Main.TextColor3 = Color3.fromRGB(255, 255, 255)
                dropdown.Main.TextSize = 14
                dropdown.Main.TextXAlignment = Enum.TextXAlignment.Left

                dropdown.Gradient = Instance.new("UIGradient", dropdown.Main)
                dropdown.Gradient.Rotation = 90
                dropdown.Gradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(49, 49, 49)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(39, 39, 39))}

                dropdown.SelectedLabel = Instance.new("TextLabel", dropdown.Main)
                dropdown.SelectedLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                dropdown.SelectedLabel.BackgroundTransparency = 1
                dropdown.SelectedLabel.Position = UDim2.fromOffset(5, 2)
                dropdown.SelectedLabel.Size = UDim2.fromOffset(130, 13)
                dropdown.SelectedLabel.Font = Enum.Font.Code
                dropdown.SelectedLabel.Text = dropdown.text
                dropdown.SelectedLabel.ZIndex = 5
                dropdown.SelectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                dropdown.SelectedLabel.TextSize = 13
                dropdown.SelectedLabel.TextStrokeTransparency = 1
                dropdown.SelectedLabel.TextXAlignment = Enum.TextXAlignment.Left

                dropdown.Nav = Instance.new("ImageButton", dropdown.Main)
                dropdown.Nav.Name = "navigation"
                dropdown.Nav.BackgroundTransparency = 1
                dropdown.Nav.LayoutOrder = 10
                dropdown.Nav.Position = UDim2.fromOffset(sector.Main.Size.X.Offset - 30, 3)
                dropdown.Nav.Rotation = 180
                dropdown.Nav.ZIndex = 5
                dropdown.Nav.Size = UDim2.fromOffset(13, 9)
                dropdown.Nav.Image = "rbxassetid://3926305904"
                dropdown.Nav.ImageRectOffset = Vector2.new(524, 764)
                dropdown.Nav.ImageRectSize = Vector2.new(36, 36)

                dropdown.Outline = Instance.new("Frame", dropdown.Main)
                dropdown.Outline.Name = "blackline"
                dropdown.Outline.ZIndex = 3
                dropdown.Outline.Size = dropdown.Main.Size + UDim2.fromOffset(2, 2)
                dropdown.Outline.BorderSizePixel = 0
                dropdown.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                dropdown.Outline.Position = UDim2.fromOffset(-1, -1)

                dropdown.BlackOutline = Instance.new("Frame", dropdown.Main)
                dropdown.BlackOutline.Name = "blackline"
                dropdown.BlackOutline.ZIndex = 2
                dropdown.BlackOutline.Size = dropdown.Main.Size + UDim2.fromOffset(4, 4)
                dropdown.BlackOutline.BorderSizePixel = 0
                dropdown.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                dropdown.BlackOutline.Position = UDim2.fromOffset(-2, -2)

                dropdown.ItemsFrame = Instance.new("ScrollingFrame", dropdown.Main)
                dropdown.ItemsFrame.Name = "itemsframe"
                dropdown.ItemsFrame.BorderSizePixel = 0
                dropdown.ItemsFrame.Size = UDim2.fromOffset(dropdown.Main.Size.X.Offset, math.clamp(#dropdown.items * 20, 20, 156) + 4)
                dropdown.ItemsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                dropdown.ItemsFrame.Position = UDim2.fromOffset(0, dropdown.Main.Size.Y.Offset + 8)
                dropdown.ItemsFrame.ScrollBarThickness = 0
                dropdown.ItemsFrame.ZIndex = 8
                dropdown.ItemsFrame.ScrollingDirection = "Y"
                dropdown.ItemsFrame.Visible = false

                dropdown.ListLayout = Instance.new("UIListLayout", dropdown.ItemsFrame)
                dropdown.ListLayout.FillDirection = Enum.FillDirection.Vertical
                dropdown.ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

                dropdown.ListPadding = Instance.new("UIPadding", dropdown.ItemsFrame)
                dropdown.ListPadding.PaddingTop = UDim.new(0, 2)
                dropdown.ListPadding.PaddingBottom = UDim.new(0, 2)
                dropdown.ListPadding.PaddingLeft = UDim.new(0, 2)
                dropdown.ListPadding.PaddingRight = UDim.new(0, 2)

                -- Items + refresh logic
                local dropdownItems = {}
                local function refreshItems()
                    for _,Item in ipairs(dropdownItems) do
                        local v = Item._value
                        if dropdown.value == v then
                            Item.BackgroundColor3 = Color3.fromRGB(64,64,64)
                            Item.TextColor3 = window.accentcolor
                            Item.Text = " " .. v
                        else
                            Item.BackgroundColor3 = Color3.fromRGB(40,40,40)
                            Item.TextColor3 = Color3.fromRGB(255,255,255)
                            Item.Text = v
                        end
                    end
                end
                function dropdown:Set(value)
                    dropdown.SelectedLabel.Text = value
                    dropdown.value = value
                    pcall(dropdown.callback, value)
                    refreshItems()
                end
                for _,v in ipairs(dropdown.items) do
                    local Item = Instance.new("TextButton", dropdown.ItemsFrame)
                    Item.BackgroundColor3 = Color3.fromRGB(40,40,40)
                    Item.TextColor3 = Color3.fromRGB(255,255,255)
                    Item.BorderSizePixel = 0
                    Item.Size = UDim2.fromOffset(dropdown.Main.Size.X.Offset - 4, 20)
                    Item.ZIndex = 8
                    Item.Text = v
                    Item.AutoButtonColor = false
                    Item.Font = Enum.Font.Code
                    Item.TextSize = 13
                    Item.TextXAlignment = Enum.TextXAlignment.Left
                    Item.TextStrokeTransparency = 1
                    Item._value = v
                    Item.MouseButton1Down:Connect(function()
                        dropdown:Set(v)
                        dropdown.Nav.Rotation = 180
                        dropdown.ItemsFrame.Visible = false
                        dropdown.ItemsFrame.Active = false
                        if dropdown.OutlineItems ~= nil then dropdown.OutlineItems.Visible = false end
                        if dropdown.BlackOutlineItems ~= nil then dropdown.BlackOutlineItems.Visible = false end
                        refreshItems()
                    end)
                    table.insert(dropdownItems, Item)
                end
                table.insert(window._accentCallbacks, function() refreshItems() end)
                refreshItems()

                dropdown.OutlineItems = Instance.new("Frame", dropdown.Main)
                dropdown.OutlineItems.Name = "blackline"
                dropdown.OutlineItems.ZIndex = 5
                dropdown.OutlineItems.Size = dropdown.ItemsFrame.Size + UDim2.fromOffset(2, 2)
                dropdown.OutlineItems.BorderSizePixel = 0
                dropdown.OutlineItems.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                dropdown.OutlineItems.Position = dropdown.ItemsFrame.Position + UDim2.fromOffset(-1, -1)
                dropdown.OutlineItems.Visible = false

                dropdown.BlackOutlineItems = Instance.new("Frame", dropdown.Main)
                dropdown.BlackOutlineItems.Name = "blackline"
                dropdown.BlackOutlineItems.ZIndex = 4
                dropdown.BlackOutlineItems.Size = dropdown.ItemsFrame.Size + UDim2.fromOffset(4, 4)
                dropdown.BlackOutlineItems.BorderSizePixel = 0
                dropdown.BlackOutlineItems.BackgroundColor3 = Color3.new(0, 0, 0)
                dropdown.BlackOutlineItems.Position = dropdown.ItemsFrame.Position + UDim2.fromOffset(-2, -2)
                dropdown.BlackOutlineItems.Visible = false

                dropdown.IgnoreBackButtons = Instance.new("TextButton", dropdown.ItemsFrame)
                dropdown.IgnoreBackButtons.BackgroundTransparency = 1
                dropdown.IgnoreBackButtons.BorderSizePixel = 0
                dropdown.IgnoreBackButtons.Position = UDim2.fromOffset(0, 0)
                dropdown.IgnoreBackButtons.Size = dropdown.ItemsFrame.Size
                dropdown.IgnoreBackButtons.ZIndex = 7
                dropdown.IgnoreBackButtons.Text = ""
                dropdown.IgnoreBackButtons.AutoButtonColor = false

                if dropdown.default then dropdown:Set(dropdown.default) else refreshItems() end

                local MouseButton1Down = function()
                    if dropdown.Nav.Rotation == 180 then
                        dropdown.Nav.Rotation = 0
                        dropdown.ItemsFrame.Visible = true
                        dropdown.ItemsFrame.Active = true
                        dropdown.OutlineItems.Visible = true
                        dropdown.BlackOutlineItems.Visible = true
                    else
                        dropdown.Nav.Rotation = 180
                        dropdown.ItemsFrame.Visible = false
                        dropdown.ItemsFrame.Active = false
                        dropdown.OutlineItems.Visible = false
                        dropdown.BlackOutlineItems.Visible = false
                    end
                end

                dropdown.Main.MouseButton1Down:Connect(MouseButton1Down)
                dropdown.Nav.MouseButton1Down:Connect(MouseButton1Down)

                dropdown.BlackOutline.MouseEnter:Connect(function()
                    dropdown.Outline.BackgroundColor3 = window.accentcolor
                    dropdown.BlackOutline.BackgroundColor3 = window.accentcolor
                    dropdown.Outline.BackgroundTransparency = 0.4
                    dropdown.BlackOutline.BackgroundTransparency = 0.5
                end)
                dropdown.BlackOutline.MouseLeave:Connect(function()
                    dropdown.Outline.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    dropdown.BlackOutline.BackgroundColor3 = Color3.new(0, 0, 0)
                    dropdown.Outline.BackgroundTransparency = 0
                    dropdown.BlackOutline.BackgroundTransparency = 0
                end)

                sector.Main.Size = UDim2.fromOffset(window.size.X.Offset / 2 - 17, sector.ListLayout.AbsoluteContentSize.Y + 18)
                tab.TabPage.CanvasSize = sector.Main.Size

                return dropdown
            end

            table.insert(sector.side:lower() == "left" and tab.SectorsLeft or tab.SectorsRight, sector)

            local function reposition()
                local yLeft, yRight = 12, 12
                for _,s in ipairs(tab.SectorsLeft) do
                    s.Main.Position = UDim2.new(0, 12, 0, yLeft)
                    yLeft = yLeft + s.Main.AbsoluteSize.Y + 12
                end
                for _,s in ipairs(tab.SectorsRight) do
                    s.Main.Position = UDim2.new(0, window.size.X.Offset - s.Main.AbsoluteSize.X - 12, 0, yRight)
                    yRight = yRight + s.Main.AbsoluteSize.Y + 12
                end
            end
            sector.Main:GetPropertyChangedSignal("Size"):Connect(reposition)
            reposition()

            return sector
        end

        table.insert(window._tabs, tab)
        updateTabVisibility()
        return tab
    end

    -- Initial accent broadcast
    window:SetAccent(window.accentcolor, window.accentcolor2)
    return window
end

return library
