--[[
  Zenith Settings UI Library
  Version: 0.1.0
  MIT License
  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  Usage:
    local Library = loadstring(game:HttpGet("https://my.cdn/roblox/ui-lib.lua"))()
    local ui = Library.new({ title = "Untitled UI" })
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "0.1.0"

local DefaultTheme = {
  bg = Color3.fromHex("#0F1115"),
  panel = Color3.fromHex("#141720"),
  card = Color3.fromHex("#191C24"),
  stroke = Color3.fromHex("#232734"),
  text = Color3.fromHex("#E5E7EB"),
  textMuted = Color3.fromHex("#9AA4B2"),
  accent = Color3.fromHex("#A46AFB"),
  radius = 12,
  spacing = 8,
  shadowTransparency = 0.75,
  focusOutline = Color3.fromHex("#A46AFB"),
}

local Library = {}
Library.__index = Library
Library.Version = VERSION

--// Utilities ---------------------------------------------------------------

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local result = {}
  for k, v in pairs(value) do
    result[k] = deepCopy(v)
  end
  return result
end

local function mergeTables(base, overrides)
  local result = deepCopy(base)
  if type(overrides) ~= "table" then
    return result
  end
  for k, v in pairs(overrides) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = mergeTables(result[k], v)
    else
      result[k] = deepCopy(v)
    end
  end
  return result
end

local function colorToHex(color)
  local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
  local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
  local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
  return string.format("#%02X%02X%02X", r, g, b)
end

local function hexToColor(hex)
  if type(hex) ~= "string" then
    return nil
  end
  if not hex:match("^#?%x%x%x%x%x%x$") then
    return nil
  end
  if hex:sub(1, 1) ~= "#" then
    hex = "#" .. hex
  end
  local success, color = pcall(Color3.fromHex, hex)
  if success then
    return color
  end
  return nil
end

local function create(instanceType, properties, children)
  local instance = Instance.new(instanceType)
  if properties then
    for property, value in pairs(properties) do
      instance[property] = value
    end
  end
  if children then
    for _, child in ipairs(children) do
      child.Parent = instance
    end
  end
  return instance
end

local function createPadding(target, padding)
  padding = padding or 0
  local uiPadding = Instance.new("UIPadding")
  uiPadding.PaddingTop = UDim.new(0, padding)
  uiPadding.PaddingBottom = UDim.new(0, padding)
  uiPadding.PaddingLeft = UDim.new(0, padding)
  uiPadding.PaddingRight = UDim.new(0, padding)
  uiPadding.Parent = target
  return uiPadding
end

local function applyCornerRadius(instance, radius)
  local corner = Instance.new("UICorner")
  corner.CornerRadius = UDim.new(0, radius)
  corner.Parent = instance
  return corner
end

local function applyStroke(instance, color, thickness, transparency)
  local stroke = Instance.new("UIStroke")
  stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
  stroke.Thickness = thickness or 1
  stroke.LineJoinMode = Enum.LineJoinMode.Round
  stroke.Color = color
  stroke.Transparency = transparency or 0
  stroke.Parent = instance
  return stroke
end

local function clamp01(value)
  if value < 0 then
    return 0
  elseif value > 1 then
    return 1
  end
  return value
end

local function round(num, bracket)
  bracket = bracket or 1
  return math.floor(num / bracket + 0.5) * bracket
end

local function safeParent()
  local player = Players.LocalPlayer
  if player then
    local gui = player:FindFirstChildOfClass("PlayerGui")
    if not gui then
      gui = Instance.new("PlayerGui")
      gui.Name = "ZenithPlayerGui"
      gui.ResetOnSpawn = false
      gui.Parent = player
    end
    return gui
  end
  local ok, coreGui = pcall(function()
    return game:GetService("CoreGui")
  end)
  if ok then
    return coreGui
  end
  return workspace
end

--// Maid -------------------------------------------------------------------

local Maid = {}
Maid.__index = Maid

function Maid.new()
  return setmetatable({ _tasks = {} }, Maid)
end

function Maid:GiveTask(task)
  if not task then
    return nil
  end
  local tasks = self._tasks
  tasks[#tasks + 1] = task
  return task
end

function Maid:DoCleaning()
  local tasks = self._tasks
  for index = #tasks, 1, -1 do
    local task = tasks[index]
    tasks[index] = nil
    local taskType = typeof(task)
    if taskType == "RBXScriptConnection" then
      task:Disconnect()
    elseif taskType == "function" then
      task()
    elseif taskType == "Instance" then
      task:Destroy()
    elseif type(task) == "table" and task.Destroy then
      task:Destroy()
    elseif type(task) == "table" and task.Disconnect then
      task:Disconnect()
    end
  end
end

function Maid:Destroy()
  self:DoCleaning()
  setmetatable(self, nil)
end

--// Signal -----------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new()
  return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(callback)
  assert(typeof(callback) == "function", "Signal callback must be a function")
  local connection = { Connected = true }
  self._handlers[connection] = callback
  function connection:Disconnect()
    if not self.Connected then
      return
    end
    self.Connected = false
    self._handlers[self] = nil
  end
  return connection
end

function Signal:Once(callback)
  local connection
  connection = self:Connect(function(...)
    connection:Disconnect()
    callback(...)
  end)
  return connection
end

function Signal:Fire(...)
  for connection, handler in pairs(self._handlers) do
    if connection.Connected then
      task.spawn(handler, ...)
    end
  end
end

function Signal:Destroy()
  for connection in pairs(self._handlers) do
    connection.Connected = false
    connection.Disconnect = nil
  end
  table.clear(self._handlers)
end

--// Virtual List -----------------------------------------------------------

local VirtualList = {}
VirtualList.__index = VirtualList

function VirtualList.new(scrollingFrame, itemHeight, render)
  local self = setmetatable({}, VirtualList)
  self.Frame = scrollingFrame
  self.ItemHeight = itemHeight
  self.Render = render
  self.Items = {}
  self.Pool = {}
  self._maid = Maid.new()
  self._maid:GiveTask(scrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    self:_refresh(false)
  end))
  self._maid:GiveTask(scrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    self:_refresh(true)
  end))
  return self
end

function VirtualList:SetItems(items)
  self.Items = items or {}
  self:_refresh(true)
end

function VirtualList:Invalidate()
  self:_refresh(true)
end

function VirtualList:_refresh(force)
  local frame = self.Frame
  local itemHeight = self.ItemHeight
  local items = self.Items
  frame.CanvasSize = UDim2.new(0, 0, 0, #items * itemHeight)
  local viewportHeight = frame.AbsoluteSize.Y
  if viewportHeight == 0 then
    return
  end
  local startIndex = math.max(1, math.floor(frame.CanvasPosition.Y / itemHeight) + 1)
  local visibleCount = math.ceil(viewportHeight / itemHeight) + 2
  for _, pooled in ipairs(self.Pool) do
    pooled.Visible = false
  end
  local poolNeeds = visibleCount
  while #self.Pool < poolNeeds do
    local slot = Instance.new("Frame")
    slot.Name = "VirtualItem"
    slot.BackgroundTransparency = 1
    slot.Size = UDim2.new(1, 0, 0, itemHeight)
    slot.Parent = frame
    self.Pool[#self.Pool + 1] = slot
  end
  local poolIndex = 1
  for offset = 0, visibleCount do
    local itemIndex = startIndex + offset
    local data = items[itemIndex]
    if data then
      local holder = self.Pool[poolIndex]
      poolIndex = poolIndex + 1
      holder.Visible = true
      holder.Position = UDim2.new(0, 0, 0, (itemIndex - 1) * itemHeight)
      holder.LayoutOrder = itemIndex
      self.Render(holder, data, itemIndex, force)
    end
  end
end

function VirtualList:Destroy()
  self._maid:DoCleaning()
  for _, slot in ipairs(self.Pool) do
    if slot.SignalMaid then
      slot.SignalMaid:DoCleaning()
    end
    slot:Destroy()
  end
  table.clear(self.Pool)
  table.clear(self.Items)
end
--// Focus Styling ----------------------------------------------------------

local function applyFocusStyling(target, theme, maid)
  if not target then
    return nil
  end
  target.Selectable = true
  local stroke = applyStroke(target, theme.focusOutline, 1, 1)
  stroke.Transparency = 1
  local function tweenTo(value)
    TweenService:Create(stroke, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { Transparency = value }):Play()
  end
  if target.SelectionGained then
    maid:GiveTask(target.SelectionGained:Connect(function()
      tweenTo(0.1)
    end))
  end
  if target.SelectionLost then
    maid:GiveTask(target.SelectionLost:Connect(function()
      tweenTo(1)
    end))
  end
  if target:IsA("TextBox") then
    maid:GiveTask(target.Focused:Connect(function()
      tweenTo(0.1)
    end))
    maid:GiveTask(target.FocusLost:Connect(function()
      tweenTo(1)
    end))
  end
  if target.MouseEnter then
    maid:GiveTask(target.MouseEnter:Connect(function()
      tweenTo(0.4)
    end))
  end
  if target.MouseLeave then
    maid:GiveTask(target.MouseLeave:Connect(function()
      if GuiService.SelectedObject ~= target then
        tweenTo(1)
      end
    end))
  end
  return stroke
end

--// Tooltip Controller -----------------------------------------------------

local TooltipController = {}
TooltipController.__index = TooltipController

function TooltipController.new(parent, theme)
  local self = setmetatable({}, TooltipController)
  self.Theme = theme
  self.Frame = create("Frame", {
    Name = "ZenithTooltip",
    BackgroundColor3 = theme.card,
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Size = UDim2.fromOffset(200, 32),
    Visible = false,
    ZIndex = 1000,
  })
  applyCornerRadius(self.Frame, 8)
  self.Stroke = applyStroke(self.Frame, theme.stroke, 1, 0.6)
  createPadding(self.Frame, 8)
  self.Label = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextColor3 = theme.text,
    Text = "",
    AutomaticSize = Enum.AutomaticSize.XY,
    Size = UDim2.new(1, 0, 1, 0),
  })
  self.Label.Parent = self.Frame
  local sizeConstraint = Instance.new("UISizeConstraint")
  sizeConstraint.MaxSize = Vector2.new(320, 200)
  sizeConstraint.Parent = self.Frame
  self.Frame.Parent = parent
  return self
end

function TooltipController:Show(text, position)
  self.Label.Text = text
  self.Frame.Position = position
  self.Frame.Visible = true
  self.Frame.Size = UDim2.new(0, self.Label.AbsoluteSize.X + 16, 0, self.Label.AbsoluteSize.Y + 12)
end

function TooltipController:Hide()
  self.Frame.Visible = false
end

function TooltipController:SetTheme(theme)
  self.Theme = theme
  self.Frame.BackgroundColor3 = theme.card
  if self.Stroke then
    self.Stroke.Color = theme.stroke
  end
  self.Label.TextColor3 = theme.text
end

function TooltipController:Destroy()
  if self.Frame then
    self.Frame:Destroy()
    self.Frame = nil
  end
end

--// Toast Controller -------------------------------------------------------

local ToastController = {}
ToastController.__index = ToastController

function ToastController.new(parent, theme)
  local self = setmetatable({}, ToastController)
  self.Theme = theme
  self.Container = create("Frame", {
    Name = "ZenithToastContainer",
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -32, 0, 32),
    Size = UDim2.new(0, 320, 1, -64),
    ZIndex = 999,
  })
  local layout = Instance.new("UIListLayout")
  layout.Padding = UDim.new(0, 12)
  layout.FillDirection = Enum.FillDirection.Vertical
  layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
  layout.VerticalAlignment = Enum.VerticalAlignment.Top
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = self.Container
  self.Container.Parent = parent
  return self
end

function ToastController:_toastColor(kind)
  if kind == "success" then
    return Color3.fromHex("#4ADE80")
  elseif kind == "warn" or kind == "warning" then
    return Color3.fromHex("#F97316")
  elseif kind == "error" then
    return Color3.fromHex("#F87171")
  end
  return self.Theme.accent
end

function ToastController:Show(message, kind, opts)
  opts = opts or {}
  local toast = create("Frame", {
    Name = "Toast",
    BackgroundColor3 = self.Theme.card,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Transparency = 1,
    AnchorPoint = Vector2.new(1, 0),
  })
  applyCornerRadius(toast, 10)
  local pad = createPadding(toast, 12)
  pad.Parent = toast
  local accentStrip = create("Frame", {
    BackgroundTransparency = 0,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 4, 1, 0),
    BackgroundColor3 = self:_toastColor(kind),
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 0, 0, 0),
  })
  applyCornerRadius(accentStrip, 8)
  accentStrip.Parent = toast
  local label = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 14,
    TextColor3 = self.Theme.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    TextWrapped = true,
    Text = message,
    Size = UDim2.new(1, -16, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Position = UDim2.new(0, 12, 0, 0),
  })
  label.Parent = toast
  toast.Parent = self.Container
  toast.Transparency = 1
  local tweenIn = TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 0 })
  tweenIn:Play()
  task.spawn(function()
    tweenIn.Completed:Wait()
    toast.Transparency = 0
  end)
  local lifetime = opts.duration or 3
  task.delay(lifetime, function()
    if toast.Parent then
      local tweenOut = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Transparency = 1 })
      tweenOut:Play()
      tweenOut.Completed:Wait()
      toast:Destroy()
    end
  end)
  return toast
end

function ToastController:SetTheme(theme)
  self.Theme = theme
end

function ToastController:Destroy()
  if self.Container then
    self.Container:Destroy()
    self.Container = nil
  end
end

--// Library Constructor ----------------------------------------------------

function Library.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Library)
  self._maid = Maid.new()
  self._theme = mergeTables(DefaultTheme, opts.theme)
  self._saveKey = opts.saveKey
  self._title = opts.title or "Zenith Dashboard"
  self._draggable = opts.draggable ~= false
  self._resizable = opts.resizable ~= false
  self._activeNavId = nil
  self._activeTab = nil
  self._pages = {}
  self._controls = {}
  self._dirtyState = false
  self._persistTimer = 0
  self._tabButtons = {}
  self._signals = {
    NavSelected = Signal.new(),
    TabSelected = Signal.new(),
    ThemeChanged = Signal.new(),
    StateChanged = Signal.new(),
  }
  self.Signals = {
    NavSelected = self._signals.NavSelected,
    TabSelected = self._signals.TabSelected,
    ThemeChanged = self._signals.ThemeChanged,
    StateChanged = self._signals.StateChanged,
  }
  self._themeBindings = {}
  self._stateBindings = {}
  self.RootGui = create("ScreenGui", {
    Name = "ZenithSettingsUI",
    DisplayOrder = 1000,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ClipToDeviceSafeArea = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  })
  self.RootGui.Parent = safeParent()
  local main = create("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 1120, 0, 640),
    BackgroundColor3 = self._theme.panel,
    BorderSizePixel = 0,
    ClipsDescendants = true,
  })
  applyCornerRadius(main, self._theme.radius + 4)
  applyStroke(main, self._theme.stroke, 1, 0.4)
  main.Parent = self.RootGui
  self.Window = main
  local shadow = create("ImageLabel", {
    Name = "DropShadow",
    BackgroundTransparency = 1,
    Image = "rbxassetid://6014261993",
    ImageColor3 = Color3.new(0, 0, 0),
    ImageTransparency = self._theme.shadowTransparency,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 12),
    Size = UDim2.new(1, 64, 1, 64),
    ZIndex = 0,
  })
  shadow.Parent = main
  self._themeBindings[shadow] = { ImageTransparency = "shadowTransparency" }
  -- Remove any stray layout that would override absolute positioning
  local existingLayout = main:FindFirstChildOfClass("UIListLayout")
  if existingLayout then existingLayout:Destroy() end

  -- Layout constants (explicit positioning; virtual list handles its own inner layouts)
  local TAB_H = 48
  local SIDEBAR_W = 240
  local sidebar = create("Frame", {
    Name = "Sidebar",
    BackgroundColor3 = self._theme.panel,
    BorderSizePixel = 0,
    Size = UDim2.new(0, SIDEBAR_W, 1, -TAB_H),
    Position = UDim2.new(0, 0, 0, TAB_H),
    ZIndex = 4,
  })
  applyStroke(sidebar, self._theme.stroke, 1, 0.3)
  applyCornerRadius(sidebar, self._theme.radius)
  sidebar.Parent = main
  self.Sidebar = sidebar
  local sidebarHeader = create("ImageLabel", {
    BackgroundTransparency = 1,
    Image = "rbxassetid://7072706226",
    Size = UDim2.new(0, 48, 0, 48),
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 16, 0, 20),
    ImageColor3 = self._theme.accent,
  })
  sidebarHeader.Parent = sidebar
  local titleLabel = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    TextSize = 18,
    Text = self._title,
    TextColor3 = self._theme.text,
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 76, 0, 22),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    Size = UDim2.new(1, -92, 0, 24),
  })
  titleLabel.Parent = sidebar
  local sidebarScroll = create("ScrollingFrame", {
    Name = "SidebarScroll",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(),
    ScrollBarThickness = 4,
    ScrollBarImageTransparency = 0.75,
    AutomaticCanvasSize = Enum.AutomaticSize.None,
    Size = UDim2.new(1, -32, 1, -120),
    Position = UDim2.new(0, 16, 0, 80),
    ClipsDescendants = true,
  })
  sidebarScroll.Parent = sidebar
  self.SidebarScroll = sidebarScroll
  local footer = create("Frame", {
    Name = "SidebarFooter",
    BackgroundColor3 = self._theme.panel,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 92),
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
  })
  applyStroke(footer, self._theme.stroke, 1, 0.4)
  footer.Parent = sidebar
  local supportButton = create("TextButton", {
    Name = "Support",
    BackgroundColor3 = self._theme.panel,
    BorderSizePixel = 0,
    Size = UDim2.new(1, -32, 0, 36),
    Position = UDim2.new(0, 16, 0, 8),
    AutoButtonColor = false,
    Text = "Support",
    Font = Enum.Font.Gotham,
    TextSize = 14,
    TextColor3 = self._theme.textMuted,
  })
  applyCornerRadius(supportButton, 10)
  supportButton.Parent = footer
  local settingsButton = supportButton:Clone()
  settingsButton.Name = "Settings"
  settingsButton.Text = "Settings"
  settingsButton.Position = UDim2.new(0, 16, 0, 50)
  settingsButton.Parent = footer
  self._themeBindings[supportButton] = { BackgroundColor3 = "panel", TextColor3 = "textMuted" }
  self._themeBindings[settingsButton] = { BackgroundColor3 = "panel", TextColor3 = "textMuted" }

  local content = create("Frame", {
    Name = "Content",
    BackgroundColor3 = self._theme.card,
    BorderSizePixel = 0,
    Position = UDim2.new(0, SIDEBAR_W, 0, TAB_H),
    Size = UDim2.new(1, -SIDEBAR_W, 1, -TAB_H),
    ZIndex = 2,
  })
  applyCornerRadius(content, self._theme.radius)
  content.Parent = main
  self.Content = content

  local tabBarHolder = create("Frame", {
    Name = "TabBar",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, TAB_H),
    Position = UDim2.new(0, SIDEBAR_W, 0, 0),
    ZIndex = 3,
  })
  tabBarHolder.Parent = main
  self.TabBarHolder = tabBarHolder

  local tabLayout = Instance.new("UIListLayout")
  tabLayout.FillDirection = Enum.FillDirection.Horizontal
  tabLayout.Padding = UDim.new(0, 12)
  tabLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
  tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
  tabLayout.Parent = tabBarHolder

  local pageArea = create("ScrollingFrame", {
    Name = "PageArea",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, SIDEBAR_W, 0, TAB_H),
    Size = UDim2.new(1, -SIDEBAR_W, 1, -TAB_H),
    ScrollingEnabled = true,
    Active = true,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 8,
    CanvasSize = UDim2.new(),
    ZIndex = 2,
  })
  pageArea.Parent = main
  self.PageArea = pageArea

  local pagePadding = createPadding(pageArea, 24)
  pagePadding.Parent = pageArea

  local pageStack = Instance.new("UIListLayout")
  pageStack.FillDirection = Enum.FillDirection.Vertical
  pageStack.Padding = UDim.new(0, 24)
  pageStack.SortOrder = Enum.SortOrder.LayoutOrder
  pageStack.Parent = pageArea
  self:_bindTheme(sidebar, { BackgroundColor3 = "panel" })
  self:_bindTheme(content, { BackgroundColor3 = "card" })
  self:_bindTheme(main, { BackgroundColor3 = "panel" })
  self:_bindTheme(titleLabel, { TextColor3 = "text" })
  self:_bindTheme(sidebarScroll, { ScrollBarImageColor3 = "stroke" })

  self.Tooltip = TooltipController.new(self.RootGui, self._theme)
  self.Toast = ToastController.new(self.RootGui, self._theme)

  if self._draggable then
    self:_makeDraggable(main)
  end
  if self._resizable then
    self:_makeResizable(main)
  end

  if opts.bindEscape ~= false then
    self:_bindEscapeToClose()
  end

  self._maid:GiveTask(RunService.Heartbeat:Connect(function(dt)
    if self._dirtyState then
      self._persistTimer = self._persistTimer + dt
      if self._persistTimer > 0.6 then
        self._persistTimer = 0
        self._dirtyState = false
        self:_persistState()
      end
    end
  end))

  self:_loadPersistedState()
  self:_applyTheme()

  if opts.autobuild ~= false then
    self:_buildAppearanceSample()
  end

  return self
end
--// Internal helpers -------------------------------------------------------

function Library:_bindTheme(instance, mapping)
  self._themeBindings[instance] = mapping
end

function Library:_applyTheme()
  for instance, mapping in pairs(self._themeBindings) do
    if instance.Parent then
      for property, token in pairs(mapping) do
        local themeValue = self._theme[token]
        if themeValue ~= nil then
          instance[property] = themeValue
        end
      end
    end
  end
  if self.Tooltip then
    self.Tooltip:SetTheme(self._theme)
  end
  if self.Toast then
    self.Toast:SetTheme(self._theme)
  end
  self._signals.ThemeChanged:Fire(self._theme)
end

function Library:_makeDraggable(frame)
  local dragging = false
  local dragStart
  local startPos
  local maid = Maid.new()
  self._maid:GiveTask(maid)
  local topHitbox = create("Frame", {
    Name = "DragHandle",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -240, 0, 48), -- exclude sidebar width
    Position = UDim2.new(0, 240, 0, 0), -- start after sidebar
    ZIndex = 2,
  })
  topHitbox.Parent = frame
  maid:GiveTask(topHitbox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      dragging = true
      dragStart = input.Position
      startPos = frame.Position
      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
          dragging = false
        end
      end)
    end
  end))
  maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
      local delta = input.Position - dragStart
      frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
  end))
end

function Library:_makeResizable(frame)
  local handle = create("Frame", {
    Name = "ResizeGrip",
    AnchorPoint = Vector2.new(1, 1),
    BackgroundTransparency = 0.9,
    BackgroundColor3 = self._theme.stroke,
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -8, 1, -8),
    ZIndex = 10,
  })
  applyCornerRadius(handle, 6)
  applyStroke(handle, self._theme.stroke, 1, 0.4)
  handle.Parent = frame
  local resizing = false
  local startInput
  local startSize
  self._maid:GiveTask(handle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      resizing = true
      startInput = input
      startSize = frame.AbsoluteSize
      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
          resizing = false
        end
      end)
    end
  end))
  self._maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
    if resizing and input == startInput then
      local delta = input.Position - startInput.Position
      local newX = math.clamp(startSize.X + delta.X, 840, 1280)
      local newY = math.clamp(startSize.Y + delta.Y, 520, 720)
      frame.Size = UDim2.new(0, newX, 0, newY)
    end
  end))
end

function Library:_bindEscapeToClose()
  local actionName = "ZenithUIClose"
  ContextActionService:BindActionAtPriority(actionName, function(_, state)
    if state == Enum.UserInputState.Begin then
      self.RootGui.Enabled = false
      task.delay(0.1, function()
        self.RootGui.Enabled = true
      end)
    end
    return Enum.ContextActionResult.Pass
  end, false, 2000, Enum.KeyCode.Escape)
  self._maid:GiveTask(function()
    ContextActionService:UnbindAction(actionName)
  end)
end

function Library:_markDirty()
  self._dirtyState = true
  self._signals.StateChanged:Fire(self:GetState())
end

function Library:_persistState()
  if not self._saveKey then
    return
  end
  if typeof(writefile) ~= "function" then
    return
  end
  local data = self:GetState()
  local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
  if ok and encoded then
    pcall(writefile, self._saveKey, encoded)
  end
end

function Library:_loadPersistedState()
  if not self._saveKey then
    return
  end
  if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
    return
  end
  local ok, exists = pcall(isfile, self._saveKey)
  if not ok or not exists then
    return
  end
  local okRead, raw = pcall(readfile, self._saveKey)
  if not okRead or not raw then
    return
  end
  local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
  if okDecode and type(decoded) == "table" then
    task.delay(0, function()
      self:ApplyState(decoded)
    end)
  end
end

function Library:_registerControl(id, getter, setter)
  if not id then
    return
  end
  self._controls[id] = { get = getter, set = setter }
end

function Library:GetState()
  local snapshot = {}
  for id, controller in pairs(self._controls) do
    local ok, value = pcall(controller.get)
    if ok then
      snapshot[id] = value
    end
  end
  if self._activeTab then
    snapshot._activeTab = self._activeTab
  end
  if self._activeNavId then
    snapshot._activeNav = self._activeNavId
  end
  return snapshot
end

function Library:ApplyState(state)
  if type(state) ~= "table" then
    return
  end
  for id, value in pairs(state) do
    if id ~= "_activeTab" and id ~= "_activeNav" then
      local controller = self._controls[id]
      if controller and controller.set then
        pcall(controller.set, value)
      end
    end
  end
  if state._activeTab then
    self:SetActiveTab(state._activeTab)
  end
  if state._activeNav then
    self:_setActiveNav(state._activeNav, true)
  end
end
--// Sidebar ----------------------------------------------------------------

-- Helper to safely retrieve sidebar cell UI parts without indexing nil
local function getCellParts(holder)
  local button = holder:FindFirstChild("Button")
  if not button then return end
  local icon = button:FindFirstChild("Icon")
  local label = button:FindFirstChild("Label")
  local indicator = button:FindFirstChild("Indicator")
  if icon and label and indicator then
    return button, icon, label, indicator
  end
end

function Library:CreateSidebar(items, opts)
  opts = opts or {}
  self._sidebarItems = items or {}
  if not self._sidebarVirtualizer then
    -- before creating the VirtualList in CreateSidebar, ensure the side table exists
    self._sidebarCellMaids = self._sidebarCellMaids or setmetatable({}, { __mode = "k" })

    self._sidebarVirtualizer = VirtualList.new(self.SidebarScroll, 44, function(holder, item, _, force)
    -- first-time build for this recycled slot
    if not holder:GetAttribute("built") then
        holder:SetAttribute("built", true)
        holder.BackgroundTransparency = 1

        local newButton = create("TextButton", {
          Name = "Button",
          BackgroundTransparency = 1,
          BorderSizePixel = 0,
          Size = UDim2.new(1, 0, 1, 0),
          AutoButtonColor = false,
          Text = "",
        }); newButton.Parent = holder

        local newIcon = create("TextLabel", {
          Name = "Icon",
          BackgroundTransparency = 1,
          Font = Enum.Font.GothamSemibold,
          TextSize = 16,
          TextColor3 = self._theme.textMuted,
          Text = "-",
          Size = UDim2.new(0, 32, 0, 32),
          Position = UDim2.new(0, 8, 0.5, -16),
        }); newIcon.Parent = newButton

        local newLabel = create("TextLabel", {
          Name = "Label",
          BackgroundTransparency = 1,
          Font = Enum.Font.Gotham,
          TextSize = 14,
          TextXAlignment = Enum.TextXAlignment.Left,
          TextYAlignment = Enum.TextYAlignment.Center,
          Text = "Item",
          TextColor3 = self._theme.text,
          Size = UDim2.new(1, -48, 1, 0),
          Position = UDim2.new(0, 48, 0, 0),
        }); newLabel.Parent = newButton

        local newIndicator = create("Frame", {
          Name = "Indicator",
          BackgroundColor3 = self._theme.accent,
          Size = UDim2.new(0, 3, 0, 24),
          Position = UDim2.new(0, 2, 0.5, -12),
          Visible = false,
        }); applyCornerRadius(newIndicator, 4); newIndicator.Parent = newButton

        -- Immediately re-fetch after build to avoid stale locals / race
        local button = holder:FindFirstChild("Button")
        if not button then return end
        local icon = button:FindFirstChild("Icon")
        local label = button:FindFirstChild("Label")
        local indicator = button:FindFirstChild("Indicator")
        if not (icon and label and indicator) then return end
    end

    -- Guarded lookup (children live under the Button, not directly under holder)
    local button, icon, label, indicator = getCellParts(holder)
    if not button then
        return -- defer until next virtualization pass
    end

    -- per-holder maid from weak table
    local cellMaid = self._sidebarCellMaids[holder]
    if not cellMaid then
        cellMaid = Maid.new()
        self._sidebarCellMaids[holder] = cellMaid
    else
        cellMaid:DoCleaning()
    end

    -- render/update
    local isGroup = item.group == true
    label.Text = item.label or item.id or ("Item " .. tostring(item))
    label.TextSize = isGroup and 12 or 14
    label.Font = isGroup and Enum.Font.GothamSemibold or Enum.Font.Gotham
    icon.Text = item.icon or (isGroup and "" or "-")

    if isGroup then
        icon.Visible, button.Active, button.Selectable, indicator.Visible = false, false, false, false
        label.TextColor3 = self._theme.textMuted
    else
        icon.Visible = true
        button.Active, button.Selectable = true, true
        local selected = (self._activeNavId == item.id)
        label.TextColor3 = selected and self._theme.text or self._theme.text
        icon.TextColor3  = selected and self._theme.accent or self._theme.textMuted
        indicator.Visible = selected

        if force then
        applyFocusStyling(button, self._theme, self._maid)
        end

    cellMaid:GiveTask(button.MouseButton1Click:Connect(function()
    self:_setActiveNav(item.id)
    local page = self.PageArea and self.PageArea:FindFirstChild("Page_" .. tostring(item.id))
    if page then
      self:SetActiveTab(item.id)
    end
    end))
        cellMaid:GiveTask(button.MouseEnter:Connect(function()
        TweenService:Create(icon, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = self._theme.text }):Play()
        end))
        cellMaid:GiveTask(button.MouseLeave:Connect(function()
        if self._activeNavId ~= item.id then
            TweenService:Create(icon, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextColor3 = self._theme.textMuted }):Play()
        end
        end))
    end
    end)
  end
  self._sidebarVirtualizer:SetItems(self._sidebarItems)
  if opts.defaultId then
    self:_setActiveNav(opts.defaultId, true)
  elseif not self._activeNavId then
    for _, nav in ipairs(self._sidebarItems) do
      if not nav.group then
        self:_setActiveNav(nav.id or nav.label, true)
        break
      end
    end
  end
  return self.SidebarScroll
end

function Library:_setActiveNav(id, silent)
  if not id then
    return
  end
  if self._activeNavId == id then
    return
  end
  self._activeNavId = id
  if self._sidebarVirtualizer then
    self._sidebarVirtualizer:Invalidate()
  end
  if not silent then
    self._signals.NavSelected:Fire(id)
    self:_markDirty()
  end
end

--// Tab Bar ----------------------------------------------------------------

function Library:CreateTabBar(tabs)
  for _, button in pairs(self._tabButtons) do
    if button.Maid then
      button.Maid:DoCleaning()
    end
    if button.Instance then
      button.Instance:Destroy()
    end
  end
  table.clear(self._tabButtons)
  for index, info in ipairs(tabs) do
    local tab = create("TextButton", {
      Name = "Tab" .. (info.id or index),
      BackgroundTransparency = 1,
      Size = UDim2.new(0, 0, 1, -12),
      AutomaticSize = Enum.AutomaticSize.X,
      AutoButtonColor = false,
      Text = "",
      LayoutOrder = index,
    })
    tab.Parent = self.TabBarHolder
    local label = create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.GothamSemibold,
      TextSize = 14,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Center,
      Text = info.label,
      TextColor3 = self._theme.textMuted,
      AutomaticSize = Enum.AutomaticSize.X,
      Size = UDim2.new(0, 0, 1, 0),
    })
    label.Parent = tab
    local underline = create("Frame", {
      BackgroundColor3 = self._theme.accent,
      Size = UDim2.new(1, 0, 0, 2),
      AnchorPoint = Vector2.new(0, 1),
      Position = UDim2.new(0, 0, 1, 0),
      Visible = false,
    })
    underline.Parent = tab
    local maid = Maid.new()
    applyFocusStyling(tab, self._theme, maid)
    maid:GiveTask(tab.MouseButton1Click:Connect(function()
      self:SetActiveTab(info.id)
    end))
    self._tabButtons[info.id] = {
      Instance = tab,
      Label = label,
      Underline = underline,
      Maid = maid,
    }
  end
  return self.TabBarHolder
end

function Library:SetActiveTab(id)
  if not id then return end
  id = tostring(id)
  if self._activeTab == id then return end
  self._activeTab = id
  for tabId, comp in pairs(self._tabButtons) do
    local selected = tostring(tabId) == id
    if comp.Label     then comp.Label.TextColor3 = selected and self._theme.text or self._theme.textMuted end
    if comp.Underline then comp.Underline.Visible = selected end
  end
  local targetName = "Page_" .. id
  for _, child in ipairs(self.PageArea:GetChildren()) do
    if child:IsA("GuiObject") and child.Name:match("^Page_") then
      child.Visible = (child.Name == targetName)
    end
  end
  if self.PageArea:IsA("ScrollingFrame") then
    self.PageArea.CanvasPosition = Vector2.new(0,0)
  end
  self._signals.TabSelected:Fire(id)
  self:_markDirty()
end
--// Page & Layout Helpers --------------------------------------------------

function Library:CreatePage(id)
    id = tostring(id)
    local page = create("Frame", {
        Name = "Page_" .. id,
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Visible = false,
        LayoutOrder = (#self._pages) + 1,
    })
    page.Parent = self.PageArea

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 16)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    self._pages[id] = page

    if not self._activeTab then
        self:SetActiveTab(id)
    end
    return page
end

function Library:Stack(parent, opts)
  assert(parent, "Stack parent is required")
  opts = opts or {}
  local frame = create("Frame", {
    BackgroundTransparency = 1,
    Size = opts.size or UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
  })
  local layout = Instance.new("UIListLayout")
  layout.FillDirection = Enum.FillDirection.Vertical
  layout.Padding = UDim.new(0, opts.padding or self._theme.spacing)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = frame
  frame.Parent = parent
  return frame
end

function Library:Grid(parent, opts)
  assert(parent, "Grid parent is required")
  opts = opts or {}
  local frame = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, opts.rowHeight or 140),
  })
  local layout = Instance.new("UIGridLayout")
  layout.CellSize = UDim2.new(0, opts.cellWidth or 260, 0, opts.rowHeight or 140)
  layout.CellPadding = UDim2.new(0, opts.padding or self._theme.spacing, 0, opts.padding or self._theme.spacing)
  layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
  layout.VerticalAlignment = Enum.VerticalAlignment.Top
  layout.Parent = frame
  frame.Parent = parent
  return frame
end

function Library:Spacer(parent, size)
  assert(parent, "Spacer parent is required")
  local spacer = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, size or 16),
  })
  spacer.Parent = parent
  return spacer
end

function Library:Divider(parent)
  assert(parent, "Divider parent is required")
  local divider = create("Frame", {
    BackgroundColor3 = self._theme.stroke,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 1),
  })
  divider.Parent = parent
  return divider
end

function Library:Card(parent, spec)
  assert(parent, "Card parent is required")
  spec = spec or {}
  local card = create("Frame", {
    Name = spec.title or "Card",
    BackgroundColor3 = self._theme.card,
    BorderSizePixel = 0,
    AutomaticSize = Enum.AutomaticSize.Y,
    Size = UDim2.new(1, 0, 0, 0),
    ClipsDescendants = true,
  })
  applyCornerRadius(card, 14)
  applyStroke(card, self._theme.stroke, 1, 0.6)
  card.Parent = parent
  createPadding(card, 20)
  local layout = Instance.new("UIListLayout")
  layout.FillDirection = Enum.FillDirection.Vertical
  layout.Padding = UDim.new(0, 12)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = card
  if spec.title then
    local title = create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.GothamSemibold,
      TextSize = 16,
      TextColor3 = self._theme.text,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Center,
      Text = spec.title,
      Size = UDim2.new(1, 0, 0, 20),
    })
    title.Parent = card
  end
  if spec.description then
    local description = create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.Gotham,
      TextSize = 13,
      TextColor3 = self._theme.textMuted,
      TextWrapped = true,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Top,
      Text = spec.description,
      AutomaticSize = Enum.AutomaticSize.Y,
      Size = UDim2.new(1, 0, 0, 0),
    })
    description.Parent = card
  end
  return card
end
--// Inputs -----------------------------------------------------------------

function Library:Toggle(parent, spec)
  assert(parent, "Toggle parent is required")
  spec = spec or {}
  local wrapper = create("Frame", {
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    Size = UDim2.new(1, 0, 0, 0),
  })
  wrapper.Parent = parent
  local layout = Instance.new("UIListLayout")
  layout.FillDirection = Enum.FillDirection.Horizontal
  layout.VerticalAlignment = Enum.VerticalAlignment.Center
  layout.Padding = UDim.new(0, 12)
  layout.Parent = wrapper
  local textContainer = create("Frame", {
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    Size = UDim2.new(1, -60, 0, 0),
  })
  textContainer.Parent = wrapper
  local textLayout = Instance.new("UIListLayout")
  textLayout.FillDirection = Enum.FillDirection.Vertical
  textLayout.SortOrder = Enum.SortOrder.LayoutOrder
  textLayout.Padding = UDim.new(0, 6)
  textLayout.Parent = textContainer
  local label = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
    TextColor3 = self._theme.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    Text = spec.label or "Toggle",
    Size = UDim2.new(1, 0, 0, 20),
  })
  label.Parent = textContainer
  if spec.description then
    local desc = create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.Gotham,
      TextSize = 12,
      TextColor3 = self._theme.textMuted,
      TextWrapped = true,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Top,
      AutomaticSize = Enum.AutomaticSize.Y,
      Size = UDim2.new(1, 0, 0, 0),
      Text = spec.description,
    })
    desc.Parent = textContainer
  end
  local toggleButton = create("TextButton", {
    BackgroundColor3 = self._theme.stroke,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 48, 0, 24),
    AutoButtonColor = false,
    Text = "",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0.5, 0),
  })
  applyCornerRadius(toggleButton, 12)
  toggleButton.Parent = wrapper
  local knob = create("Frame", {
    BackgroundColor3 = Color3.new(0.8, 0.82, 0.88),
    Size = UDim2.new(0, 20, 0, 20),
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 4, 0.5, 0),
    BorderSizePixel = 0,
  })
  applyCornerRadius(knob, 10)
  knob.Parent = toggleButton
  local value = spec.value == true
  local function setVisual(newValue)
    value = newValue
    TweenService:Create(toggleButton, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
      BackgroundColor3 = newValue and self._theme.accent or self._theme.stroke,
    }):Play()
    TweenService:Create(knob, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
      Position = newValue and UDim2.new(1, -24, 0.5, 0) or UDim2.new(0, 4, 0.5, 0),
      BackgroundColor3 = newValue and Color3.fromRGB(245, 246, 252) or Color3.fromRGB(180, 184, 196),
    }):Play()
  end
  setVisual(value)
  toggleButton.MouseButton1Click:Connect(function()
    value = not value
    setVisual(value)
    if spec.onChanged then
      spec.onChanged(value)
    end
    self:_markDirty()
  end)
  applyFocusStyling(toggleButton, self._theme, self._maid)
  if spec.tooltip then
    self:_bindTooltip(toggleButton, spec.tooltip)
  end
  if spec.id then
    self:_registerControl(spec.id, function()
      return value
    end, function(newValue)
      setVisual(newValue and true or false)
    end)
  end
  return toggleButton
end

function Library:_bindTooltip(instance, text)
  self._maid:GiveTask(instance.MouseEnter:Connect(function()
    local mouse = UserInputService:GetMouseLocation()
    self.Tooltip:Show(text, UDim2.new(0, mouse.X + 12, 0, mouse.Y + 12))
  end))
  self._maid:GiveTask(instance.MouseLeave:Connect(function()
    self.Tooltip:Hide()
  end))
end

function Library:Dropdown(parent, spec)
  assert(parent, "Dropdown parent is required")
  spec = spec or {}
  local options = spec.options or {}
  local wrapper = create("Frame", {
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    Size = UDim2.new(1, 0, 0, 0),
  })
  wrapper.Parent = parent
  local label = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
    TextColor3 = self._theme.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    Text = spec.label or "Dropdown",
    Size = UDim2.new(1, 0, 0, 24),
  })
  label.Parent = wrapper
  if spec.description then
    local desc = create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.Gotham,
      TextSize = 12,
      TextColor3 = self._theme.textMuted,
      TextWrapped = true,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Top,
      AutomaticSize = Enum.AutomaticSize.Y,
      Size = UDim2.new(1, 0, 0, 0),
      Text = spec.description,
    })
    desc.Parent = wrapper
  end
  local button = create("TextButton", {
    BackgroundColor3 = self._theme.panel,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Text = "",
    Size = UDim2.new(0, 220, 0, 36),
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 0, 0, 48),
  })
  applyCornerRadius(button, 10)
  applyStroke(button, self._theme.stroke, 1, 0.5)
  button.Parent = wrapper
  local valueLabel = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = self._theme.text,
    Text = "Select",
    Size = UDim2.new(1, -32, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
  })
  valueLabel.Parent = button
  local arrow = create("ImageLabel", {
    BackgroundTransparency = 1,
    Image = "rbxassetid://7072706613",
    ImageColor3 = self._theme.textMuted,
    Size = UDim2.new(0, 16, 0, 16),
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
  })
  arrow.Parent = button
  local currentValue = spec.value or (options[1] and (options[1].id or options[1]))
  local function findOption(id)
    for _, option in ipairs(options) do
      if (option.id or option) == id then
        return option
      end
    end
  end
  local function displayValue(id)
    local option = findOption(id)
    if option then
      valueLabel.Text = option.label or option.text or tostring(option.name or option.id or option)
      currentValue = option.id or option
    end
  end
  displayValue(currentValue)
  local overlay = nil
  local function closeOverlay()
    if overlay then
      overlay:Destroy()
      overlay = nil
    end
  end
  button.MouseButton1Click:Connect(function()
    closeOverlay()
    overlay = create("Frame", {
      BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 1, 0),
      Parent = self.RootGui,
      ZIndex = 900,
    })
    local list = create("Frame", {
      BackgroundColor3 = self._theme.panel,
      BorderSizePixel = 0,
      AutomaticSize = Enum.AutomaticSize.Y,
      Size = UDim2.fromOffset(220, 0),
      Position = UDim2.new(0, button.AbsolutePosition.X, 0, button.AbsolutePosition.Y + 40),
      AnchorPoint = Vector2.new(0, 0),
    })
    applyCornerRadius(list, 12)
    applyStroke(list, self._theme.stroke, 1, 0.4)
    list.Parent = overlay
    local layout = Instance.new("UIListLayout")
    layout.Parent = list
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    for index, option in ipairs(options) do
      local optionButton = create("TextButton", {
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 32),
        Text = "",
        LayoutOrder = index,
      })
      optionButton.Parent = list
      local optionLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 13,
        TextColor3 = self._theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = option.label or option.text or tostring(option.name or option.id or option),
        Size = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
      })
      optionLabel.Parent = optionButton
      optionButton.MouseButton1Click:Connect(function()
        currentValue = option.id or option
        displayValue(currentValue)
        if spec.onChanged then
          spec.onChanged(currentValue)
        end
        self:_markDirty()
        closeOverlay()
      end)
    end
    overlay.InputBegan:Connect(function(input)
      if input.UserInputType == Enum.UserInputType.MouseButton1 then
        closeOverlay()
      end
    end)
  end)
  if spec.tooltip then
    self:_bindTooltip(button, spec.tooltip)
  end
  if spec.id then
    self:_registerControl(spec.id, function()
      return currentValue
    end, function(value)
      displayValue(value)
    end)
  end
  return button
end

function Library:RadioGroup(parent, spec)
  assert(parent, "RadioGroup parent is required")
  spec = spec or {}
  local wrapper = self:Stack(parent, { padding = 12 })
  local header = create("Frame", {
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    Size = UDim2.new(1, 0, 0, 0),
  })
  header.Parent = wrapper
  local headerLayout = Instance.new("UIListLayout")
  headerLayout.FillDirection = Enum.FillDirection.Vertical
  headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
  headerLayout.Parent = header
  if spec.label then
    create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.GothamSemibold,
      TextSize = 14,
      TextColor3 = self._theme.text,
      TextXAlignment = Enum.TextXAlignment.Left,
      Text = spec.label,
      Size = UDim2.new(1, 0, 0, 20),
    }).Parent = header
  end
  if spec.description then
    create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.Gotham,
      TextSize = 12,
      TextColor3 = self._theme.textMuted,
      TextWrapped = true,
      TextXAlignment = Enum.TextXAlignment.Left,
      Text = spec.description,
      AutomaticSize = Enum.AutomaticSize.Y,
      Size = UDim2.new(1, 0, 0, 0),
    }).Parent = header
  end
  local grid = self:Grid(wrapper, {
    cellWidth = spec.cellWidth or 200,
    rowHeight = spec.rowHeight or 120,
    padding = spec.padding or 12,
  })
  local selected = spec.value or (spec.options and spec.options[1] and (spec.options[1].id or spec.options[1]))
  local cards = {}
  local function updateAll()
    for id, entry in pairs(cards) do
      local active = (selected == id)
      entry.Indicator.Visible = active
      TweenService:Create(entry.Card, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = active and self._theme.card or self._theme.panel,
      }):Play()
    end
  end
  local options = spec.options or {}
  local function renderOption(option)
    local optionId = option.id or option
    local card = create("TextButton", {
      Name = "Radio_" .. tostring(optionId),
      BackgroundColor3 = self._theme.panel,
      BorderSizePixel = 0,
      AutoButtonColor = false,
      Text = "",
    })
    applyCornerRadius(card, 12)
    applyStroke(card, self._theme.stroke, 1, 0.6)
    card.Parent = grid
    local icon = create("ImageLabel", {
      BackgroundTransparency = 1,
      Image = option.preview or "rbxassetid://7072710185",
      ImageColor3 = self._theme.text,
      AnchorPoint = Vector2.new(0.5, 0),
      Size = UDim2.new(0, 64, 0, 40),
      Position = UDim2.new(0.5, 0, 0, 16),
    })
    icon.Parent = card
    local title = create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.GothamSemibold,
      TextSize = 14,
      TextColor3 = self._theme.text,
      TextXAlignment = Enum.TextXAlignment.Center,
      Text = option.label or option.name,
      Size = UDim2.new(1, -24, 0, 20),
      Position = UDim2.new(0, 12, 0, 64),
    })
    title.Parent = card
    if option.description then
      local desc = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = self._theme.textMuted,
        TextWrapped = true,
        Text = option.description,
        Size = UDim2.new(1, -24, 0, 32),
        Position = UDim2.new(0, 12, 0, 86),
      })
      desc.Parent = card
    end
    local indicator = create("Frame", {
      BackgroundColor3 = self._theme.accent,
      BorderSizePixel = 0,
      Size = UDim2.new(0, 20, 0, 20),
      AnchorPoint = Vector2.new(1, 0),
      Position = UDim2.new(1, -12, 0, 12),
      Visible = false,
    })
    applyCornerRadius(indicator, 10)
    indicator.Parent = card
    cards[optionId] = { Card = card, Indicator = indicator }
    card.MouseButton1Click:Connect(function()
      selected = optionId
      updateAll()
      if spec.onChanged then
        spec.onChanged(selected)
      end
      self:_markDirty()
    end)
  end
  for _, option in ipairs(options) do
    renderOption(option)
  end
  updateAll()
  if spec.id then
    self:_registerControl(spec.id, function()
      return selected
    end, function(value)
      selected = value
      updateAll()
    end)
  end
  return wrapper
end

function Library:ColorSwatch(parent, spec)
  assert(parent, "ColorSwatch parent is required")
  spec = spec or {}
  local wrapper = create("Frame", {
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    Size = UDim2.new(1, 0, 0, 0),
  })
  wrapper.Parent = parent
  local label = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
    TextColor3 = self._theme.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = spec.label or "Brand color",
    Size = UDim2.new(1, 0, 0, 20),
  })
  label.Parent = wrapper
  if spec.description then
    create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.Gotham,
      TextSize = 12,
      TextColor3 = self._theme.textMuted,
      TextWrapped = true,
      TextXAlignment = Enum.TextXAlignment.Left,
      AutomaticSize = Enum.AutomaticSize.Y,
      Size = UDim2.new(1, 0, 0, 0),
      Text = spec.description,
    }).Parent = wrapper
  end
  local swatchButton = create("TextButton", {
    BackgroundColor3 = spec.value or self._theme.accent,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 48, 0, 48),
    AutoButtonColor = false,
    Text = "",
    Position = UDim2.new(0, 0, 0, 32),
  })
  applyCornerRadius(swatchButton, 12)
  swatchButton.Parent = wrapper
  local hexBox = create("TextBox", {
    BackgroundColor3 = self._theme.panel,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 120, 0, 36),
    Position = UDim2.new(0, 64, 0, 38),
    Font = Enum.Font.Gotham,
    TextSize = 14,
    TextColor3 = self._theme.text,
    Text = colorToHex(spec.value or self._theme.accent),
    ClearTextOnFocus = false,
  })
  applyCornerRadius(hexBox, 10)
  applyStroke(hexBox, self._theme.stroke, 1, 0.4)
  hexBox.Parent = wrapper
  local currentColor = spec.value or self._theme.accent
  local function updateColor(newColor)
    currentColor = newColor
    swatchButton.BackgroundColor3 = newColor
    hexBox.Text = colorToHex(newColor)
    if spec.onChanged then
      spec.onChanged(newColor)
    end
    self:_markDirty()
  end
  swatchButton.MouseButton1Click:Connect(function()
    local randomColor = Color3.fromHSV(math.random(), 0.55, 1)
    updateColor(randomColor)
  end)
  hexBox.FocusLost:Connect(function(enterPressed)
    local parsed = hexToColor(hexBox.Text)
    if parsed then
      updateColor(parsed)
    else
      hexBox.Text = colorToHex(currentColor)
    end
  end)
  if spec.id then
    self:_registerControl(spec.id, function()
      return colorToHex(currentColor)
    end, function(value)
      local parsed = type(value) == "string" and hexToColor(value)
      if parsed then
        updateColor(parsed)
      end
    end)
  end
  return swatchButton
end

function Library:Slider(parent, spec)
  assert(parent, "Slider parent is required")
  spec = spec or {}
  local min = spec.min or 0
  local max = spec.max or 100
  local step = spec.step or 1
  local wrapper = create("Frame", {
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    Size = UDim2.new(1, 0, 0, 0),
  })
  wrapper.Parent = parent
  create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
    TextColor3 = self._theme.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = spec.label or "Slider",
    Size = UDim2.new(1, 0, 0, 20),
  }).Parent = wrapper
  local track = create("Frame", {
    BackgroundColor3 = self._theme.stroke,
    BorderSizePixel = 0,
    Size = UDim2.new(1, -160, 0, 4),
    Position = UDim2.new(0, 0, 0, 32),
  })
  applyCornerRadius(track, 2)
  track.Parent = wrapper
  local fill = create("Frame", {
    BackgroundColor3 = self._theme.accent,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 0, 1, 0),
  })
  fill.Parent = track
  local knob = create("Frame", {
    BackgroundColor3 = self._theme.accent,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 16, 0, 16),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0, 0, 0.5, 0),
  })
  applyCornerRadius(knob, 8)
  knob.Parent = track
  local valueLabel = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = self._theme.textMuted,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = tostring(spec.value or min),
    Position = UDim2.new(0, 0, 0, 48),
    Size = UDim2.new(1, 0, 0, 20),
  })
  valueLabel.Parent = wrapper
  local currentValue = math.clamp(spec.value or min, min, max)
  local function updateVisual()
    local alpha = (currentValue - min) / (max - min)
    fill.Size = UDim2.new(alpha, 0, 1, 0)
    knob.Position = UDim2.new(alpha, 0, 0.5, 0)
    valueLabel.Text = string.format("%s", spec.format and spec.format(currentValue) or tostring(currentValue))
  end
  updateVisual()
  local dragging = false
  local function setValueFromInput(x)
    local relative = clamp01((x - track.AbsolutePosition.X) / track.AbsoluteSize.X)
    local newValue = min + (max - min) * relative
    newValue = round(newValue, step)
    newValue = math.clamp(newValue, min, max)
    currentValue = newValue
    updateVisual()
    if spec.onChanged then
      spec.onChanged(currentValue)
    end
    self:_markDirty()
  end
  track.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = true
      setValueFromInput(input.Position.X)
      input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
          dragging = false
        end
      end)
    end
  end)
  UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
      setValueFromInput(input.Position.X)
    end
  end)
  if spec.id then
    self:_registerControl(spec.id, function()
      return currentValue
    end, function(value)
      currentValue = math.clamp(tonumber(value) or currentValue, min, max)
      updateVisual()
    end)
  end
  return track
end

function Library:Keybind(parent, spec)
  assert(parent, "Keybind parent is required")
  spec = spec or {}
  local wrapper = create("Frame", {
    BackgroundTransparency = 1,
    AutomaticSize = Enum.AutomaticSize.Y,
    Size = UDim2.new(1, 0, 0, 0),
  })
  wrapper.Parent = parent
  local label = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
    TextColor3 = self._theme.text,
    TextXAlignment = Enum.TextXAlignment.Left,
    Text = spec.label or "Keybind",
    Size = UDim2.new(1, 0, 0, 20),
  })
  label.Parent = wrapper
  local button = create("TextButton", {
    BackgroundColor3 = self._theme.panel,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Size = UDim2.new(0, 180, 0, 32),
    Text = "",
    Position = UDim2.new(0, 0, 0, 32),
  })
  applyCornerRadius(button, 10)
  applyStroke(button, self._theme.stroke, 1, 0.5)
  button.Parent = wrapper
  local valueLabel = create("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextColor3 = self._theme.text,
    TextXAlignment = Enum.TextXAlignment.Center,
    Text = spec.value or "None",
    Size = UDim2.new(1, 0, 1, 0),
  })
  valueLabel.Parent = button
  local capturing = false
  local currentKey = spec.value or "None"
  local captureConnection
  local function setKey(text)
    currentKey = text
    valueLabel.Text = text
    if spec.onChanged then
      spec.onChanged(currentKey)
    end
    self:_markDirty()
  end
  button.MouseButton1Click:Connect(function()
    if capturing then
      return
    end
    capturing = true
    valueLabel.Text = "Press keys..."
    if captureConnection then
      captureConnection:Disconnect()
    end
    captureConnection = UserInputService.InputBegan:Connect(function(input, gpe)
      if gpe then
        return
      end
      if input.UserInputType == Enum.UserInputType.Keyboard then
        setKey(input.KeyCode.Name)
        capturing = false
        captureConnection:Disconnect()
      end
    end)
    task.delay(4, function()
      if capturing then
        capturing = false
        if captureConnection then
          captureConnection:Disconnect()
        end
        valueLabel.Text = currentKey
      end
    end)
  end)
  if spec.id then
    self:_registerControl(spec.id, function()
      return currentKey
    end, function(value)
      setKey(value or "None")
    end)
  end
  return button
end

function Library:Button(parent, spec)
  assert(parent, "Button parent is required")
  spec = spec or {}
  local button = create("TextButton", {
    BackgroundColor3 = spec.style == "primary" and self._theme.accent or self._theme.panel,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Size = spec.size or UDim2.new(0, 140, 0, 40),
    Text = spec.text or "Button",
    Font = Enum.Font.GothamSemibold,
    TextSize = 14,
    TextColor3 = spec.style == "primary" and Color3.fromRGB(240, 242, 252) or self._theme.text,
  })
  applyCornerRadius(button, 12)
  applyStroke(button, self._theme.stroke, spec.style == "primary" and 0 or 1, spec.style == "primary" and 1 or 0.5)
  button.Parent = parent
  button.MouseButton1Click:Connect(function()
    if spec.onActivated then
      spec.onActivated()
    end
  end)
  if spec.tooltip then
    self:_bindTooltip(button, spec.tooltip)
  end
  return button
end

function Library:Notify(text, kind, opts)
  return self.Toast:Show(text, kind, opts)
end

function Library:SetTheme(theme)
  self._theme = mergeTables(DefaultTheme, theme)
  self:_applyTheme()
end

function Library:Destroy()
  self._maid:DoCleaning()
  for _, signal in pairs(self._signals) do
    signal:Destroy()
  end
  if self.Tooltip then
    self.Tooltip:Destroy()
  end
  if self.Toast then
    self.Toast:Destroy()
  end
  if self.RootGui then
    self.RootGui:Destroy()
  end
end
--// Demo Builder -----------------------------------------------------------

function Library:_buildAppearanceSample(targetPage)
  -- If a page is provided, build only the appearance sample into that page.
  if targetPage then
    local pageAppearance = targetPage
    assert(pageAppearance, "Target page missing for appearance sample build")

    local heading = create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.GothamSemibold,
      TextSize = 20,
      TextColor3 = self._theme.text,
      TextXAlignment = Enum.TextXAlignment.Left,
      Text = "Appearance",
      Size = UDim2.new(1, 0, 0, 28),
    })
    heading.Parent = pageAppearance

    local subheading = create("TextLabel", {
      BackgroundTransparency = 1,
      Font = Enum.Font.Gotham,
      TextSize = 13,
      TextColor3 = self._theme.textMuted,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextWrapped = true,
      Text = "Change how your public dashboard looks and feels.",
      AutomaticSize = Enum.AutomaticSize.Y,
      Size = UDim2.new(1, 0, 0, 0),
    })
    subheading.Parent = pageAppearance

    local brandCard = self:Card(pageAppearance, { title = "Brand color", description = "Select or customize your brand color." })
    self:ColorSwatch(brandCard, {
      id = "brandColor",
      value = self._theme.accent,
      tooltip = "Click to randomize or enter a hex value.",
      onChanged = function(color)
        self:SetTheme({ accent = color })
        self:Notify("Brand color updated to " .. colorToHex(color), "info", { duration = 2 })
      end,
    })

    local chartCard = self:Card(pageAppearance, { title = "Dashboard charts", description = "How charts are displayed." })
    self:RadioGroup(chartCard, {
      id = "chartStyle",
      label = "Chart style",
      options = {
        { id = "default", label = "Default", description = "Default company branding." },
        { id = "simplified", label = "Simplified", description = "Minimal and modern." },
        { id = "custom", label = "Custom CSS", description = "Manage styling with CSS." },
      },
      value = "default",
      onChanged = function(option)
        self:Notify("Chart style set to " .. option, "success", { duration = 2.5 })
      end,
    })

    local languageCard = self:Card(pageAppearance, { title = "Language", description = "Default language for public dashboard." })
    self:Dropdown(languageCard, {
      id = "language",
      options = {
        { id = "en-uk", label = "English (UK)" },
        { id = "en-us", label = "English (US)" },
        { id = "fr-fr", label = "Francais" },
        { id = "de-de", label = "Deutsch" },
      },
      value = "en-uk",
      onChanged = function(value)
        self:Notify("Language changed to " .. value, "info", { duration = 2 })
      end,
    })

    local cookieCard = self:Card(pageAppearance, { title = "Cookie banner", description = "Display cookie banners to visitors." })
    self:RadioGroup(cookieCard, {
      id = "cookieBanner",
      options = {
        { id = "default", label = "Default", description = "Cookie controls for visitors." },
        { id = "simplified", label = "Simplified", description = "Show a simplified banner." },
        { id = "none", label = "None", description = "Don't show any banners." },
      },
      value = "default",
      onChanged = function(value)
        self:Notify("Cookie banner set to " .. value, "success", { duration = 2 })
      end,
    })

    local footer = create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60) })
    footer.Parent = pageAppearance
    local footerLayout = Instance.new("UIListLayout")
    footerLayout.FillDirection = Enum.FillDirection.Horizontal
    footerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    footerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    footerLayout.Padding = UDim.new(0, 12)
    footerLayout.Parent = footer

    self:Button(footer, { text = "Cancel", style = "ghost", onActivated = function() self:Notify("Changes discarded", "warn") end })
    self:Button(footer, { text = "Save changes", style = "primary", onActivated = function() self:Notify("Settings saved", "success"); self:_persistState() end })
    return
  end

  -- Default behavior (auto-build full sample with nav + pages)
  local sidebarItems = {
    { id = "overview", label = "Overview", icon = "??" },
    { id = "dashboards", label = "Dashboards", icon = "??" },
    { id = "projects", label = "All projects", icon = "??" },
    { id = "analyze", label = "Analyze", icon = "??" },
    { id = "access", label = "Manage access", icon = "??" },
    { group = true, label = "Data management" },
    { id = "charts", label = "All charts", icon = "??" },
    { id = "events", label = "Explore events", icon = "??" },
    { id = "labels", label = "Visual labels", icon = "??" },
    { id = "live", label = "Live data feed", icon = "??" },
    { id = "support", label = "Support", icon = "?" },
    { id = "appearance", label = "Appearance", icon = "??" },
  }
  self:CreateSidebar(sidebarItems, { defaultId = "appearance" })
  local tabs = {
    { id = "account", label = "Account" },
    { id = "profile", label = "Profile" },
    { id = "security", label = "Security" },
    { id = "appearance", label = "Appearance" },
    { id = "notifications", label = "Notifications" },
    { id = "billing", label = "Billing" },
    { id = "integrations", label = "Integrations" },
  }
  self:CreateTabBar(tabs)
  local pageAccount    = self:CreatePage("account")
  local pageAppearance = self:CreatePage("appearance")
  local pageBilling    = self:CreatePage("billing")
  self:Card(pageAccount, { title = "Account", description = "Manage profile & credentials." })
  self:Card(pageBilling, { title = "Billing", description = "Invoices, payment methods, usage." })
  self:_buildAppearanceSample(pageAppearance) -- reuse simplified path
  self:SetActiveTab("appearance")
end

return Library

--[[
local Library = loadstring(game:HttpGet("https://my.cdn/roblox/ui-lib.lua"))()
local ui = Library.new({ title = "Untitled UI", saveKey = "untitledui.json", draggable = true })
ui:CreateSidebar({
  { id = "overview", label = "Overview" },
  { id = "dashboards", label = "Dashboards" },
  { group = true, label = "Data management" },
  { id = "allcharts", label = "All charts" },
})
ui:CreateTabBar({ { id = "account", label = "Account" }, { id = "appearance", label = "Appearance" }, { id = "billing", label = "Billing" } })
local page = ui:CreatePage("appearance")
local card = ui:Card(page, { title = "Brand color", description = "Select or customize your brand color." })
ui:ColorSwatch(card, { value = Color3.fromHex("#A46AFB"), onChanged = function(c)
  print("brand", c)
end })
ui:Button(page, { text = "Save changes", style = "primary", onActivated = function()
  ui:Notify("Saved", "success")
end })
]]







