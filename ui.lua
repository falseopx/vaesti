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
        radii = { xs = 6, sm = 10, md = 14, lg = 18 },
        spacing = { 4, 6, 8, 12, 16, 24, 32 },
        colors = {
            bg = hex("#16181c"),
            surface = hex("#1a1d22"),
            surfaceAlt = hex("#20242b"),
            stroke = hex("#2a2f39"),
            text = hex("#e8ebf2"),
            textMuted = hex("#a3abb6"),
            accent = hex("#a46aff"),
            focus = hex("#d4d9e1"),
        },
        tween = {
            hover = { time = 0.12, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.Out },
            active = { time = 0.18, style = Enum.EasingStyle.Quad, direction = Enum.EasingDirection.Out },
        }
    },
    mature = {
        name = "mature",
        radii = { xs = 6, sm = 10, md = 14, lg = 18 },
        spacing = { 4, 6, 8, 12, 16, 24, 32 },
        colors = {
            bg = hex("#16181c"),
            surface = hex("#1a1d22"),
            surfaceAlt = hex("#20242b"),
            stroke = hex("#2a2f39"),
            text = hex("#e8ebf2"),
            textMuted = hex("#a3abb6"),
            accent = hex("#a46aff"), -- keep purple
            focus = hex("#d4d9e1"),
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
    _sidebarRows: {[string]: {Row: GuiButton, Label: TextLabel, Accent: Frame}},
    setLayerAndLayout: (self: UIInstance) -> (),
    EnableDebug: (self: UIInstance, on: boolean) -> (),
    CreateSection: (self: UIInstance, sectionId: string, def: {tabs: {{id: string, label: string}}?, defaultTab: string?}?) -> (),
    CreatePage: (self: UIInstance, a: string, b: string?) -> Frame,
    _rebuildTabBarForSection: (self: UIInstance, sectionId: string) -> (),
    SetActiveSection: (self: UIInstance, sectionId: string) -> (),
    SetActiveTab: (self: UIInstance, tabId: string) -> (),
    Card: (self: UIInstance, parent: Instance, spec: {title: string, description: string?}) -> Frame,
    Toggle: (self: UIInstance, parent: Instance, args: {label: string, value: boolean?, onChanged: (boolean)->()?}) -> Frame,
    ColorSwatch: (self: UIInstance, parent: Instance, args: {label: string, value: Color3?, onChanged: (Color3)->()?}) -> Frame,
    SetTheme: (self: UIInstance, overrides: {[string]: any}) -> (),
    _updateSidebarVisuals: (self: UIInstance) -> (),
    _syncShadow: (self: UIInstance) -> (),
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

    -- Sidebar row styled (chip-like)
    self._sidebarButtons = self._sidebarButtons or {}
    self._sidebarRows = self._sidebarRows or {}
    local t = self._theme
    local row = Instance.new("TextButton")
    row.Name = "SectionButton_" .. sectionId
    row.Text = sectionId
    row.Font = Enum.Font.Gotham
    row.TextSize = 14
    row.TextColor3 = t.colors.textMuted
    row.AutoButtonColor = false
    row.BackgroundColor3 = t.colors.surface
    row.BackgroundTransparency = 0
    row.BorderSizePixel = 0
    row.Size = UDim2.new(1, -8, 0, 32)
    row.Position = UDim2.new(0,4,0,0)
    row.Parent = self._sidebar
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, t.radii.xs); corner.Parent = row
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0,12); pad.PaddingRight = UDim.new(0,12); pad.Parent = row
    local accentBar = Instance.new("Frame")
    accentBar.Name = "Accent"
    accentBar.BackgroundColor3 = t.colors.accent
    accentBar.BorderSizePixel = 0
    accentBar.Size = UDim2.new(0,2,1,0)
    accentBar.Position = UDim2.new(0,0,0,0)
    accentBar.Visible = false
    accentBar.Parent = row
    self:_applyFocusRing(row)
    local TweenService = game:GetService("TweenService")
    local hoverInfo = TweenInfo.new(t.tween.hover.time, t.tween.hover.style, t.tween.hover.direction)
    row.MouseEnter:Connect(function()
        if self._activeSectionId ~= sectionId then
            TweenService:Create(row, hoverInfo, { BackgroundColor3 = t.colors.surfaceAlt }):Play()
        end
    end)
    row.MouseLeave:Connect(function()
        if self._activeSectionId ~= sectionId then
            TweenService:Create(row, hoverInfo, { BackgroundColor3 = t.colors.surface }):Play()
        end
    end)
    row.MouseButton1Click:Connect(function()
        if self._sections[sectionId] then
            self:SetActiveSection(sectionId)
            self:_updateSidebarVisuals()
        end
    end)
    self._sidebarButtons[sectionId] = row
    self._sidebarRows[sectionId] = { Row = row, Label = row, Accent = accentBar }
    self:_updateSidebarVisuals()
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
    self._tabButtons = self._tabButtons or {}
    for k in pairs(self._tabButtons) do self._tabButtons[k] = nil end
    -- Remove all except Title and Divider
    for _, ch in ipairs(self._tabBar:GetChildren()) do
        if not ((ch:IsA("TextLabel") and ch.Name == "Title") or (ch:IsA("Frame") and ch.Name == "Divider")) then
            ch:Destroy()
        end
    end
    local theme = self._theme
    local sec = self._sections[sectionId]
    if not sec then return end
    local divider = self._tabBar:FindFirstChild("Divider")
    if not divider then
        divider = Instance.new("Frame")
        divider.Name = "Divider"
        divider.BackgroundColor3 = theme.colors.stroke
        divider.BackgroundTransparency = 0.5
        divider.BorderSizePixel = 0
        divider.AnchorPoint = Vector2.new(0,1)
        divider.Position = UDim2.new(0,0,1,0)
        divider.Size = UDim2.new(1,0,0,1)
        divider.Parent = self._tabBar
    end
    local title = self._tabBar:FindFirstChild("Title")
    if title and title:IsA("TextLabel") then
        title.Position = UDim2.new(0,12,0,8)
        title.Size = UDim2.new(0,120,0,28)
        title.TextColor3 = theme.colors.textMuted
    end
    local chipRow = Instance.new("Frame")
    chipRow.Name = "ChipRow"
    chipRow.BackgroundTransparency = 1
    chipRow.AutomaticSize = Enum.AutomaticSize.Y
    chipRow.Size = UDim2.new(1,-152,0,36) -- accounts for title + padding
    chipRow.Position = UDim2.new(0,140,0,6)
    chipRow.Parent = self._tabBar
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.Padding = UDim.new(0,8)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = chipRow
    local TextService = game:GetService("TextService")
    local TweenService = game:GetService("TweenService")
    local hoverInfo = TweenInfo.new(theme.tween.hover.time, theme.tween.hover.style, theme.tween.hover.direction)
    local function hoverColor()
        return theme.colors.surfaceAlt:lerp(theme.colors.text, 0.08)
    end
    for _, spec in ipairs(sec.tabs) do
        local id = tostring(spec.id)
        local labelText = spec.label or spec.id
        local width = math.max(96, TextService:GetTextSize(labelText, 14, Enum.Font.GothamMedium, Vector2.new(1000,32)).X + 16)
        local chip = Instance.new("TextButton")
        chip.Name = "Chip_" .. id
        chip.Text = labelText
        chip.Font = Enum.Font.GothamMedium
        chip.TextSize = 14
        chip.TextColor3 = theme.colors.textMuted
        chip.AutoButtonColor = false
        chip.BackgroundColor3 = theme.colors.surfaceAlt
        chip.BorderSizePixel = 0
        chip.Size = UDim2.new(0,width,1,0)
        chip.Parent = chipRow
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, theme.radii.sm); corner.Parent = chip
        local stroke = Instance.new("UIStroke"); stroke.Color = theme.colors.stroke; stroke.Transparency = 0.2; stroke.Thickness = 1; stroke.Parent = chip
        local underline = Instance.new("Frame")
        underline.Name = "Underline"
        underline.BackgroundColor3 = theme.colors.accent
        underline.BorderSizePixel = 0
        underline.Size = UDim2.new(1,0,0,2)
        underline.Position = UDim2.new(0,0,1,-2)
        underline.Visible = false
        underline.Parent = chip
        self:_applyFocusRing(chip)
        chip.MouseEnter:Connect(function()
            if not underline.Visible then
                TweenService:Create(chip, hoverInfo, { BackgroundColor3 = hoverColor() }):Play()
                TweenService:Create(chip, hoverInfo, { TextColor3 = theme.colors.text }):Play()
            end
        end)
        chip.MouseLeave:Connect(function()
            if not underline.Visible then
                TweenService:Create(chip, hoverInfo, { BackgroundColor3 = theme.colors.surfaceAlt }):Play()
                TweenService:Create(chip, hoverInfo, { TextColor3 = theme.colors.textMuted }):Play()
            end
        end)
        chip.MouseButton1Click:Connect(function()
            self:SetActiveTab(id)
        end)
        self._tabButtons[id] = { Label = chip, Underline = underline }
    end
end

function UI:SetActiveSection(sectionId: string)
    if not self._sections or not self._sections[sectionId] then return end
    sectionId = tostring(sectionId)
    self._activeSectionId = sectionId
    -- Hide all sections, show target
    for id, sec in pairs(self._sections) do
        sec.container.Visible = (id == sectionId)
    end
    -- Sidebar visuals handled centrally
    self:_rebuildTabBarForSection(sectionId)
    local sec = self._sections[sectionId]
    local first = (sec.tabs[1] and sec.tabs[1].id) and tostring(sec.tabs[1].id) or nil
    local nextTab = self._activeTabs[sectionId] or sec.defaultTab or first
    if nextTab then
        self:SetActiveTab(nextTab)
    end
    self:_updateSidebarVisuals()
end

function UI:SetActiveTab(tabId: string)
    if not tabId then return end
    tabId = tostring(tabId)

    -- find current section
    local sid = self._activeSectionId or "settings"
    local sec = self._sections and self._sections[sid]
    if not sec or not sec.container then return end

    -- no-op if already active
    self._activeTabs = self._activeTabs or {}
    if self._activeTabs[sid] == tabId then return end
    self._activeTabs[sid] = tabId

    -- toggle pages inside this section only
    local targetName = "Page_" .. tabId
    for _, child in ipairs(sec.container:GetChildren()) do
        if child:IsA("GuiObject") and child.Name:match("^Page_") then
            child.Visible = (child.Name == targetName)
        end
    end

    -- update chip visuals
    for tid, comp in pairs(self._tabButtons or {}) do
        local selected = tostring(tid) == tabId
        if comp.Label then
            comp.Label.TextColor3 = selected and self._theme.colors.text or self._theme.colors.textMuted
            comp.Label.BackgroundColor3 = self._theme.colors.surfaceAlt
        end
        if comp.Underline then
            comp.Underline.Visible = selected
        end
    end

    -- reset scroll to top
    if self._pageArea and self._pageArea:IsA("ScrollingFrame") then
        self._pageArea.CanvasPosition = Vector2.new(0,0)
    end

    if self._signals and self._signals.TabSelected then
        self._signals.TabSelected:Fire(tabId)
    end
    if self._markDirty then self:_markDirty() end
    self:_updateSidebarVisuals()
end

---------------------------------------------------------------------
-- Instance Theme Setter (proxy to Module.SetTheme)
---------------------------------------------------------------------
function UI:SetTheme(overrides: {[string]: any})
    if type(overrides) ~= "table" then return end
    local updated = Module.SetTheme(overrides)
    self._theme = updated
    -- minimal live accent update for existing tab underline / toggles
    for _, comp in pairs(self._tabButtons or {}) do
        if comp.Underline then comp.Underline.BackgroundColor3 = self._theme.colors.accent end
    end
end

-- Sidebar visuals helper
function UI:_updateSidebarVisuals()
    if not self._sidebarRows then return end
    local t = self._theme
    for sid, comp in pairs(self._sidebarRows) do
        local isActive = (self._activeSectionId == tostring(sid))
        local row = comp.Row; local label = comp.Label; local acc = comp.Accent
        if row and label and acc then
            row.BackgroundColor3 = isActive and t.colors.surfaceAlt or t.colors.surface
            label.TextColor3 = isActive and t.colors.text or t.colors.textMuted
            acc.Visible = isActive
        end
    end
end

-- Shadow sync helper
function UI:_syncShadow()
    if not self._softShadowRoot or not self._window then return end
    local win = self._window
    local root = self._softShadowRoot
    root.Position = win.Position + UDim2.new(0,-20,0,-20)
    root.Size = win.Size + UDim2.new(0,40,0,40)
    local radii = self._theme.radii.lg
    local layers = { S1 = 24, S2 = 16, S3 = 8 }
    for name, offset in pairs(layers) do
        local layer = root:FindFirstChild(name) :: Frame
        if layer then
            layer.Position = UDim2.new(0, offset, 0, offset)
            layer.Size = win.Size + UDim2.new(0, offset * -2, 0, offset * -2)
        end
    end
end

---------------------------------------------------------------------
-- Components
---------------------------------------------------------------------
function UI:_applyFocusRing(obj: GuiObject)
    local stroke = Instance.new("UIStroke")
    stroke.Name = "FocusRing"
    stroke.Color = self._theme.colors.focus
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Enabled = false
    stroke.Parent = obj
    if obj:IsA("TextButton") then
        obj.SelectionGained:Connect(function()
            stroke.Enabled = true
        end)
        obj.SelectionLost:Connect(function()
            stroke.Enabled = false
        end)
    end
end
function UI:Card(parent: Instance, spec: {title: string, description: string?}): Frame
    local t = self._theme
    local card = Instance.new("Frame")
    card.Name = "Card"
    card.BackgroundColor3 = t.colors.surface
    card.BorderSizePixel = 0
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Size = UDim2.new(1, -16, 0, 0)
    card.Parent = parent
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, t.radii.md); corner.Parent = card
    local stroke = Instance.new("UIStroke"); stroke.Color = t.colors.stroke; stroke.Thickness = 1; stroke.Transparency = 0.2; stroke.Parent = card
    local pad = Instance.new("UIPadding"); pad.PaddingTop = UDim.new(0, 16); pad.PaddingBottom = UDim.new(0, 16); pad.PaddingLeft = UDim.new(0, 16); pad.PaddingRight = UDim.new(0, 16); pad.Parent = card
    local layout = Instance.new("UIListLayout"); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 8); layout.Parent = card

    local title = Instance.new("TextLabel")
    title.Name = "Title"; title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold; title.TextSize = 18
    title.TextColor3 = t.colors.text; title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = (spec and spec.title) or "Card"; title.Size = UDim2.new(1,0,0,22); title.Parent = card

    if spec and spec.description then
        local sub = Instance.new("TextLabel")
        sub.Name = "Description"; sub.BackgroundTransparency = 1
        sub.Font = Enum.Font.Gotham; sub.TextSize = 14
        sub.TextColor3 = t.colors.textMuted; sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.TextWrapped = true; sub.Size = UDim2.new(1,0,0,18)
        sub.Text = spec.description; sub.Parent = card
    end

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.BackgroundTransparency = 1
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.Size = UDim2.new(1,0,0,0)
    local bodyLayout = Instance.new("UIListLayout"); bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder; bodyLayout.Padding = UDim.new(0, 8); bodyLayout.Parent = body
    body.Parent = card
    return body
end

function UI:Toggle(parent: Instance, args: {label: string, value: boolean?, onChanged: (boolean)->()?}): Frame
    local t = self._theme
    local row = Instance.new("Frame"); row.Name="Toggle"; row.BackgroundTransparency=1; row.Size = UDim2.new(1,0,0,28); row.Parent = parent
    local label = Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Font=Enum.Font.Gotham; label.TextSize=14; label.TextColor3=t.colors.text; label.TextXAlignment=Enum.TextXAlignment.Left; label.Text=(args and args.label) or "Toggle"; label.Size=UDim2.new(1,-72,1,0); label.Parent=row
    local val = (args and args.value) and true or false
    local btn = Instance.new("TextButton"); btn.Name="Switch"; btn.AutoButtonColor=false; btn.Text=""; btn.Size=UDim2.new(0,44,0,22); btn.Position=UDim2.new(1,-44,0.5,-11); btn.BackgroundColor3 = val and t.colors.accent or t.colors.surfaceAlt; btn.BorderSizePixel=0; btn.Parent=row
    local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=btn
    local knob = Instance.new("Frame"); knob.Name="Knob"; knob.Size=UDim2.new(0,18,0,18); knob.Position = UDim2.new(val and 1 or 0, val and -20 or 2, 0.5, -9); knob.BackgroundColor3=t.colors.text; knob.BorderSizePixel=0; knob.Parent=btn
    local ck = Instance.new("UICorner"); ck.CornerRadius=UDim.new(1,0); ck.Parent=knob
    btn.MouseButton1Click:Connect(function()
        val = not val
        btn.BackgroundColor3 = val and t.colors.accent or t.colors.surfaceAlt
        knob.Position = UDim2.new(val and 1 or 0, val and -20 or 2, 0.5, -9)
        if args and args.onChanged then args.onChanged(val) end
    end)
    return row
end

function UI:ColorSwatch(parent: Instance, args: {label: string, value: Color3?, onChanged: (Color3)->()?}): Frame
    local t = self._theme
    local row = Instance.new("Frame"); row.Name="ColorSwatch"; row.BackgroundTransparency=1; row.Size = UDim2.new(1,0,0,28); row.Parent = parent
    local label = Instance.new("TextLabel"); label.BackgroundTransparency=1; label.Font=Enum.Font.Gotham; label.TextSize=14; label.TextColor3=t.colors.text; label.TextXAlignment=Enum.TextXAlignment.Left; label.Text=(args and args.label) or "Color"; label.Size=UDim2.new(1,-48,1,0); label.Parent=row
    local btn = Instance.new("TextButton"); btn.Name="Swatch"; btn.AutoButtonColor=false; btn.Text=""; btn.Size=UDim2.new(0,22,0,22); btn.Position=UDim2.new(1,-22,0.5,-11); btn.BackgroundColor3 = (args and args.value) or t.colors.accent; btn.BorderSizePixel=0; btn.Parent=row
    local c = Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=btn
    local presets = {
        Color3.fromRGB(164,106,255),
        Color3.fromRGB(92,190,255),
        Color3.fromRGB(255,142,94),
        Color3.fromRGB(120,220,140),
        Color3.fromRGB(255,204,0),
    }
    local i = 1
    btn.MouseButton1Click:Connect(function()
        i = (i % #presets) + 1
        local color = presets[i]
        btn.BackgroundColor3 = color
        if args and args.onChanged then args.onChanged(color) end
    end)
    return row
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
    applyStroke(window, theme.colors.stroke, 1, 0.15)
    -- Layered soft shadow root
    local softRoot = Instance.new("Frame")
    softRoot.Name = "SoftShadowRoot"
    softRoot.BackgroundTransparency = 1
    softRoot.Active = false
    softRoot.ZIndex = 0
    softRoot.Parent = screen
    local function mkLayer(name, offset, transparency)
        local f = Instance.new("Frame")
        f.Name = name
        f.BackgroundColor3 = Color3.new(0,0,0)
        f.BackgroundTransparency = transparency
        f.BorderSizePixel = 0
        f.Parent = softRoot
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, theme.radii.lg)
        c.Parent = f
        return f
    end
    mkLayer("S1", 24, 0.90)
    mkLayer("S2", 16, 0.93)
    mkLayer("S3", 8, 0.96)

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
        TextColor3 = theme.colors.textMuted,
        BackgroundTransparency = 1,
        Size = UDim2.new(0,120,1,0),
        Position = UDim2.new(0,8,0,0),
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
        _sidebarRows = {},
        _softShadowRoot = softRoot,
    }, UI)

    self:setLayerAndLayout()
    self:_syncShadow()

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

    -- Populate demo appearance page
    local p = self._demoPages and self._demoPages.appearance
    if p then
        local card1 = self:Card(p, { title = "Brand color", description = "Select or customize your brand color." })
        self:ColorSwatch(card1, { label = "Brand color", value = self._theme.colors.accent, onChanged = function(c)
            self:SetTheme({ colors = { accent = c } })
        end })
        local card2 = self:Card(p, { title = "Dashboard charts", description = "How charts are displayed." })
        self:Toggle(card2, { label = "Use simplified charts", value = false, onChanged = function(v)
            print("simplified:", v)
        end })
    end

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
