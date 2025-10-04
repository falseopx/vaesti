--!strict
-- Vaesti UI Single-File Library
-- Consumable via: loadstring(game:HttpGet("..."))()
-- Exports: new, SetTheme, EnableDebug
-- No globals; no per-frame loops.

local Module = {}

---------------------------------------------------------------------
-- Utility: Type Guards
---------------------------------------------------------------------
type VoidFn = () -> ()
type MaidTask = Instance | RBXScriptConnection | { Destroy: (any) -> () } | VoidFn

---------------------------------------------------------------------
-- Maid
---------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
    local self = setmetatable({}, Maid)
    self._tasks = {}
    return self
end

function Maid:Give(task: MaidTask)
    if task == nil then return task end
    table.insert(self._tasks, task)
    return task
end

function Maid:DoCleaning()
    for i = #self._tasks, 1, -1 do
        local task = self._tasks[i]
        self._tasks[i] = nil
        local t = typeof(task)
        if t == "RBXScriptConnection" then
            (task :: RBXScriptConnection):Disconnect()
        elseif t == "Instance" then
            (task :: Instance):Destroy()
        else
            if type(task) == "table" and typeof((task :: any).Destroy) == "function" then
                (task :: any):Destroy()
            elseif type(task) == "function" then
                (task :: any)()
            end
        end
    end
end

function Maid:Destroy()
    self:DoCleaning()
    table.clear(self._tasks)
end

---------------------------------------------------------------------
-- Signal
---------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._bindable = Instance.new("BindableEvent")
    self._connections = {}
    return self
end

function Signal:Connect(fn: (...any) -> ())
    return self._bindable.Event:Connect(fn)
end

function Signal:Once(fn: (...any) -> ())
    local conn
    conn = self._bindable.Event:Connect(function(...)
        if conn then conn:Disconnect() end
        fn(...)
    end)
    return conn
end

function Signal:Fire(...)
    self._bindable:Fire(...)
end

function Signal:Destroy()
    for _, c in ipairs(self._connections) do
        if c.Disconnect then c:Disconnect() end
    end
    self._bindable:Destroy()
end

---------------------------------------------------------------------
-- Internal Helpers
---------------------------------------------------------------------
local function hex(str: string): Color3
    str = str:gsub("#","")
    return Color3.fromRGB(
        tonumber(str:sub(1,2),16),
        tonumber(str:sub(3,4),16),
        tonumber(str:sub(5,6),16)
    )
end

local function merge(into: {[string]: any}, from: {[string]: any})
    for k,v in pairs(from) do
        if type(v) == "table" and type(into[k]) == "table" then
            merge(into[k], v)
        else
            into[k] = v
        end
    end
    return into
end

local function deepClone(tbl)
    local out = {}
    for k,v in pairs(tbl) do
        if type(v) == "table" then
            out[k] = deepClone(v)
        else
            out[k] = v
        end
    end
    return out
end

local function create(className: string, props: {[string]: any}?): Instance
    local inst = Instance.new(className)
    if props then
        for k,v in pairs(props) do
            if k == "Parent" then continue end
            inst[k] = v
        end
        if props.Parent then
            inst.Parent = props.Parent
        end
    end
    return inst
end

local function applyCorner(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function applyStroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

---------------------------------------------------------------------
-- Themes / Tokens
---------------------------------------------------------------------
local Themes = {
    dark = {
        name = "dark",
        radii = { xs = 6, sm = 10, md = 14, lg = 20 },
        spacing = { 4, 6, 8, 12, 16, 24, 32 },
        colors = {
            bg = hex("#14161b"),
            surface = hex("#191c21"),
            surfaceAlt = hex("#1f232a"),
            stroke = hex("#2a2f38"),
            text = hex("#e7e9ee"),
            textMuted = hex("#9aa3af"),
            accent = hex("#a46aff"),
            focus = hex("#d6d9e0"),
        },
        tween = {
            hover = { time = 0.12, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.Out },
            active = { time = 0.18, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.Out },
        }
    },
    mature = {
        name = "mature",
        radii = { xs = 6, sm = 10, md = 14, lg = 20 },
        spacing = { 4, 6, 8, 12, 16, 24, 32 },
        colors = {
            bg = hex("#14161b"),
            surface = hex("#191c21"),
            surfaceAlt = hex("#1f232a"),
            stroke = hex("#2a2f38"),
            text = hex("#e7e9ee"),
            textMuted = hex("#9aa3af"),
            accent = hex("#a46aff"), -- could differentiate if desired
            focus = hex("#d6d9e0"),
        },
        tween = {
            hover = { time = 0.12, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.Out },
            active = { time = 0.18, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.Out },
        }
    }
}

local CurrentTheme = deepClone(Themes.dark)

function Module.SetTheme(nameOrOverrides: any, overrides: {[string]: any}?): {[string]: any}
    local base
    if type(nameOrOverrides) == "string" then
        base = Themes[nameOrOverrides]
        if not base then
            base = Themes.dark
        end
        CurrentTheme = deepClone(base)
        if overrides then
            merge(CurrentTheme, overrides)
        end
    elseif type(nameOrOverrides) == "table" then
        merge(CurrentTheme, nameOrOverrides)
    end
    return CurrentTheme
end

---------------------------------------------------------------------
-- Tween Convenience (not heavily used yet)
---------------------------------------------------------------------
local function tween(inst: Instance, info: TweenInfo, props: {[string]: any})
    local TweenService = game:GetService("TweenService")
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

---------------------------------------------------------------------
-- UI Object
---------------------------------------------------------------------
export type UIInstance = {
    _screen: ScreenGui,
    _window: Frame,
    _tabBar: Frame,
    _sidebar: Frame,
    _content: Frame,
    _pageArea: ScrollingFrame,
    _sticker: Frame,
    _maid: any,
    _signals: {[string]: any},
    _theme: {[string]: any},
    _sections: {[string]: any},
    _activeSectionId: string?,
    _activeTabs: {[string]: string},
    _tabButtons: {[string]: any},
    _sidebarButtons: {[string]: TextButton},
    setLayerAndLayout: (self: UIInstance) -> (),
    EnableDebug: (self: UIInstance, on: boolean) -> (),
    CreateSection: (self: UIInstance, sectionId: string, def: {tabs: {{id: string, label: string}}?, defaultTab: string?}?) -> (),
    CreatePage: (self: UIInstance, a: string, b: string?) -> Frame,
    _rebuildTabBarForSection: (self: UIInstance, sectionId: string) -> (),
    SetActiveSection: (self: UIInstance, sectionId: string) -> (),
    SetActiveTab: (self: UIInstance, tabId: string) -> (),
    Destroy: (self: UIInstance) -> (),
}

local UI = {}
UI.__index = UI

---------------------------------------------------------------------
-- Layout Application
---------------------------------------------------------------------
function UI:setLayerAndLayout()
    -- TabBar
    self._tabBar.Size = UDim2.new(1, 0, 0, 48)
    self._tabBar.Position = UDim2.new(0, 0, 0, 0)

    -- Sidebar
    self._sidebar.Size = UDim2.new(0, 240, 1, -48)
    self._sidebar.Position = UDim2.new(0, 0, 0, 48)

    -- Content
    self._content.Size = UDim2.new(1, -240, 1, -48)
    self._content.Position = UDim2.new(0, 240, 0, 48)

    -- PageArea fills Content
    self._pageArea.Size = UDim2.new(1, 0, 1, 0)
    self._pageArea.Position = UDim2.new(0, 0, 0, 0)
end

---------------------------------------------------------------------
-- Debug Tinting
---------------------------------------------------------------------
-- Instance method version of EnableDebug (replaces previous module-level function)
function UI:EnableDebug(on: boolean)
    if not self or not self._content then return end
    local layers: {GuiObject} = { self._sidebar, self._content, self._tabBar, self._pageArea, self._sticker }

    local function storeOriginalColor(inst: GuiObject)
        if not inst:GetAttribute("_origColor") then
            inst:SetAttribute("_origColor", inst.BackgroundColor3:ToHex())
        end
    end

    local function restoreOriginalColor(inst: GuiObject)
        local hexVal = inst:GetAttribute("_origColor")
        if hexVal then
            inst.BackgroundColor3 = hex("#" .. hexVal)
        end
    end

    if on then
        for _, layer in ipairs(layers) do storeOriginalColor(layer) end
        self._sidebar.BackgroundColor3 = Color3.fromRGB(120, 60, 170)
        self._content.BackgroundColor3 = Color3.fromRGB(40, 170, 90)
        self._tabBar.BackgroundColor3  = Color3.fromRGB(220, 140, 40)
        self._pageArea.BackgroundColor3= Color3.fromRGB(30, 90, 200)
        self._sticker.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    else
        for _, layer in ipairs(layers) do restoreOriginalColor(layer) end
    end
end

---------------------------------------------------------------------
-- Sections / Tabs / Pages API
---------------------------------------------------------------------
function UI:CreateSection(sectionId: string, def: {tabs: {{id: string, label: string}}?, defaultTab: string?}?)
    self._sections = self._sections or {}
    if self._sections[sectionId] then return end

    local container = create("Frame", {
        Name = "Section_" .. sectionId,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self._pageArea,
        Visible = false,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, self._theme.spacing[3])
    list.Parent = container

    self._sections[sectionId] = {
        tabs = (def and def.tabs) or {},
        pages = {},
        defaultTab = def and def.defaultTab or nil,
        container = container,
    }

    -- Sidebar button (simple list item)
    self._sidebarButtons = self._sidebarButtons or {}
    local btn = create("TextButton", {
        Name = "SectionButton_" .. sectionId,
        Text = sectionId,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextColor3 = self._theme.colors.textMuted,
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 28),
        Parent = self._sidebar,
    })
    btn.MouseButton1Click:Connect(function()
        if self._sections[sectionId] then
            self:SetActiveSection(sectionId)
        end
    end)
    self._sidebarButtons[sectionId] = btn
end

function UI:CreatePage(a: string, b: string?): Frame
    -- Overload: if only one arg treat as ("settings", a)
    local sectionId, tabId
    if b == nil then
        sectionId = "settings"
        tabId = a
    else
        sectionId = a
        tabId = b
    end
    self._sections = self._sections or {}
    local sec = self._sections[sectionId]
    if not sec then error("Section does not exist: " .. sectionId) end
    if sec.pages[tabId] then return sec.pages[tabId] end

    local page = create("Frame", {
        Name = "Page_" .. tabId,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = sec.container,
    })
    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, self._theme.spacing[3])
    list.Parent = page

    sec.pages[tabId] = page
    return page
end

function UI:_rebuildTabBarForSection(sectionId: string)
    -- Remove old tab buttons (keep Title label if present)
    self._tabButtons = self._tabButtons or {}
    for _, rec in pairs(self._tabButtons) do
        if rec.Button and rec.Button.Destroy then rec.Button:Destroy() end
    end
    self._tabButtons = {}

    local sec = self._sections[sectionId]
    if not sec then return end
    local theme = self._theme
    local TextService = game:GetService("TextService")
    local xOffset = 120 -- leave space for title left side
    local padding = 8
    for _, tab in ipairs(sec.tabs) do
        local label = tab.label or tab.id
        local textSize = TextService:GetTextSize(label, 14, Enum.Font.GothamMedium, Vector2.new(1000, 32))
        local btnWidth = textSize.X + 24
        local button = create("TextButton", {
            Name = "Tab_" .. tab.id,
            Text = label,
            Font = Enum.Font.GothamMedium,
            TextSize = 14,
            TextColor3 = theme.colors.textMuted,
            AutoButtonColor = false,
            BackgroundTransparency = 0.9,
            BackgroundColor3 = theme.colors.surfaceAlt,
            Size = UDim2.new(0, btnWidth, 0, 32),
            Position = UDim2.new(0, xOffset, 0, 8),
            Parent = self._tabBar,
        })
        applyCorner(button, self._theme.radii.sm)
        local underline = create("Frame", {
            Name = "Underline",
            BackgroundColor3 = theme.colors.accent,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 2),
            Position = UDim2.new(0, 0, 1, -2),
            Visible = false,
            Parent = button,
        })
        self._tabButtons[tab.id] = { Button = button, Underline = underline }
        button.MouseButton1Click:Connect(function()
            self:SetActiveTab(tab.id)
        end)
        xOffset += btnWidth + padding
    end
end

function UI:SetActiveSection(sectionId: string)
    if not self._sections or not self._sections[sectionId] then return end
    self._activeSectionId = sectionId
    -- Hide all sections, show target
    for id, sec in pairs(self._sections) do
        sec.container.Visible = (id == sectionId)
    end
    -- Sidebar highlight
    if self._sidebarButtons then
        for id, btn in pairs(self._sidebarButtons) do
            if id == sectionId then
                btn.TextColor3 = self._theme.colors.accent
            else
                btn.TextColor3 = self._theme.colors.textMuted
            end
        end
    end
    self:_rebuildTabBarForSection(sectionId)
    local sec = self._sections[sectionId]
    local first = (sec.tabs[1] and sec.tabs[1].id) and tostring(sec.tabs[1].id) or nil
    local nextTab = self._activeTabs[sectionId] or sec.defaultTab or first
    if nextTab then
        self:SetActiveTab(nextTab)
    end
end

function UI:SetActiveTab(tabId: string)
    local sectionId = self._activeSectionId or "settings"
    local sec = self._sections and self._sections[sectionId]
    if not sec then return end
    -- Toggle pages
    for id, page in pairs(sec.pages) do
        page.Visible = (id == tabId)
    end
    -- Update tab button visuals
    if self._tabButtons then
        for id, rec in pairs(self._tabButtons) do
            if rec.Button then
                if id == tabId then
                    rec.Button.TextColor3 = self._theme.colors.text
                    rec.Underline.Visible = true
                else
                    rec.Button.TextColor3 = self._theme.colors.textMuted
                    rec.Underline.Visible = false
                end
            end
        end
    end
    self._activeTabs = self._activeTabs or {}
    self._activeTabs[sectionId] = tabId
    if self._pageArea and self._pageArea:IsA("ScrollingFrame") then
        self._pageArea.CanvasPosition = Vector2.new(0, 0)
    end
end

---------------------------------------------------------------------
-- Constructor
---------------------------------------------------------------------
type NewOptions = {
    Parent: Instance?,
    Name: string?,
    Title: string?,
    Theme: string | {[string]: any}?,
    WindowSize: UDim2?,
    WindowPosition: UDim2?,
}

function UI.new(opts: NewOptions?): UIInstance
    opts = opts or {}
    local maid = Maid.new()
    local signals = {
        Closed = Signal.new(),
    }
    maid:Give(function() signals.Closed:Destroy() end)

    local theme
    if opts.Theme then
        if type(opts.Theme) == "string" then
            theme = deepClone(Themes[opts.Theme] or Themes.dark)
        else
            theme = deepClone(CurrentTheme)
            merge(theme, opts.Theme)
        end
    else
        theme = deepClone(CurrentTheme)
    end

    local screen = create("ScreenGui", {
        Name = opts.Name or "VaestiUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = opts.Parent or game:GetService("CoreGui"),
    })

    maid:Give(screen)

    -- Window (floating root)
    local window = create("Frame", {
        Name = "Window",
        BackgroundColor3 = theme.colors.bg,
        BorderSizePixel = 0,
        Size = opts.WindowSize or UDim2.new(0, 900, 0, 560),
        Position = opts.WindowPosition or UDim2.new(0.5, -450, 0.5, -280),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Parent = screen,
    })
    applyCorner(window, theme.radii.lg)
    applyStroke(window, theme.colors.stroke, 1, 0.2)

    -- Sticker (decor/branding / handle)
    local sticker = create("Frame", {
        Name = "Sticker",
        BackgroundColor3 = theme.colors.surfaceAlt,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 48, 0, 48),
        Position = UDim2.new(0, -8, 0, -8),
        Parent = window,
        ZIndex = 0,
        Active = false,
    })
    applyCorner(sticker, theme.radii.sm)
    applyStroke(sticker, theme.colors.stroke, 1, 0.4)

    -- TabBar (top)
    local tabBar = create("Frame", {
        Name = "TabBar",
        BackgroundColor3 = theme.colors.surfaceAlt,
        BorderSizePixel = 0,
        Parent = window,
        ZIndex = 3,
    })
    applyStroke(tabBar, theme.colors.stroke, 1, 0.25)

    -- Sidebar (left)
    local sidebar = create("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = theme.colors.surface,
        BorderSizePixel = 0,
        Parent = window,
        ZIndex = 4,
    })
    applyStroke(sidebar, theme.colors.stroke, 1, 0.3)

    -- Content (right main)
    local content = create("Frame", {
        Name = "Content",
        BackgroundColor3 = theme.colors.surface,
        BorderSizePixel = 0,
        Parent = window,
        ZIndex = 2,
    })
    applyStroke(content, theme.colors.stroke, 1, 0.3)

    -- PageArea (scrolling)
    local pageArea = create("ScrollingFrame", {
        Name = "PageArea",
        BackgroundColor3 = theme.colors.surface,
        BorderSizePixel = 0,
        Parent = content,
        ScrollBarThickness = 8,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0,0,0,0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Active = true,
        ZIndex = 2,
    })
    applyCorner(pageArea, theme.radii.sm)
    applyStroke(pageArea, theme.colors.stroke, 1, 0.15)

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, theme.spacing[3]) -- e.g. 8
    layout.Parent = pageArea

    -- Title label inside TabBar (simple)
    local title = create("TextLabel", {
        Name = "Title",
        Text = opts.Title or "Vaesti UI",
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = theme.colors.text,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = tabBar,
        ZIndex = 3,
    })

    -- Build object
    local self: UIInstance = setmetatable({
        _screen = screen,
        _window = window,
        _tabBar = tabBar,
        _sidebar = sidebar,
        _content = content,
        _pageArea = pageArea,
        _sticker = sticker,
        _maid = maid,
        _signals = signals,
        _theme = theme,
        _sections = {},
        _activeSectionId = nil,
        _activeTabs = {},
        _tabButtons = {},
        _sidebarButtons = {},
    }, UI)

    self:setLayerAndLayout()

    -- Demo autobuild (initial section and pages)
    self:CreateSection("settings", {
        tabs = {
            { id = "account", label = "Account" },
            { id = "appearance", label = "Appearance" },
            { id = "billing", label = "Billing" },
        },
        defaultTab = "appearance",
    })
    local pageAccount = self:CreatePage("settings", "account")
    local pageAppearance = self:CreatePage("settings", "appearance")
    local pageBilling = self:CreatePage("settings", "billing")
    self._demoPages = { account = pageAccount, appearance = pageAppearance, billing = pageBilling }
    self:SetActiveSection("settings")

    -- Cleanup handle
    function self:Destroy()
        self._maid:Destroy()
    end

    return self
end

---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
function Module.new(opts: NewOptions?): UIInstance
    return UI.new(opts)
end

-- Optional compatibility: allow Module.EnableDebug(ui, true)
function Module.EnableDebug(selfOrUi, on: boolean)
    if type(selfOrUi) == "table" and selfOrUi.EnableDebug then
        return selfOrUi:EnableDebug(on)
    end
end

-- Re-export helpers if desired (not required but convenient)
Module.Maid = Maid
Module.Signal = Signal
Module.create = create
Module.applyCorner = applyCorner
Module.applyStroke = applyStroke
Module._currentTheme = CurrentTheme

return Module
