local STIFFNESS = 180
local DAMPING = 12
local DRAG_LERP_SPEED = 0.16
local DRAG_TILT_MULTIPLIER = 0.026
local MAX_DRAG_ROTATION = 18
local DEFAULT_ACCENT = Color3.fromRGB(0, 255, 111)
local library = {
    flags = {},
    windows = {},
    options = {},
    open = true,
    isAnimating = false,
    STIFFNESS = STIFFNESS,
    DAMPING = DAMPING,
    font = Enum.Font.Gotham,
    fontOverride = false,
    originalFonts = {},
    customCursorEnabled = false,
    customCursorId = "",
    theme = {
        Accent = DEFAULT_ACCENT
    },
    defaultTheme = {
        Accent = DEFAULT_ACCENT
    },
    themeObjects = {},
    liveAccentThemes = true
}

--Services
local runService = game:GetService "RunService"
local tweenService = game:GetService "TweenService"
local textService = game:GetService "TextService"
local inputService = game:GetService "UserInputService"
local httpService = game:GetService "HttpService"

--Locals
local dragging, dragStart, startPos, dragObject, dragTarget, dragLastMouseX, dragVelocityX, dragRotationVelocity, dragOriginalClips

local ROOT_FOLDER = "Levis Hub"
local THEME_FOLDER = ROOT_FOLDER .. "/Theme"
local CONFIG_FOLDER = ROOT_FOLDER .. "/Configuration"
local THEME_FILE = THEME_FOLDER .. "/theme.json"
local THEME_INDEX_FILE = THEME_FOLDER .. "/themes.txt"
local THEME_DEFAULT_FILE = THEME_FOLDER .. "/default.txt"
local CONFIG_INDEX_FILE = CONFIG_FOLDER .. "/configs.txt"
local CONFIG_AUTOLOAD_FILE = CONFIG_FOLDER .. "/autoload.txt"

local blacklistedKeys = { --add or remove keys if you find the need to
    Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Slash, Enum
    .KeyCode.Tab, Enum.KeyCode.Backspace, Enum.KeyCode.Escape
}
local whitelistedMouseinputs = { --add or remove mouse inputs if you find the need to
    Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3
}

--Functions
local function round(num, places)
    local power = 10 ^ places
    return math.round(num * power) / power
end

local function keyCheck(x, x1)
    for _, v in next, x1 do
        if v == x then
            return true
        end
    end
end

local function offsetUDim2(value, x, y)
    return UDim2.new(value.X.Scale, value.X.Offset + x, value.Y.Scale, value.Y.Offset + y)
end

local function getAccent()
    return library.theme.Accent or DEFAULT_ACCENT
end

local function updateDragTarget(dt)
    if not dragObject or not dragStart or not startPos then return end

    local mouse = inputService:GetMouseLocation()
    local delta = mouse - dragStart
    local yPos = (startPos.Y.Offset + delta.Y) < -36 and -36 or startPos.Y.Offset + delta.Y
    dragTarget = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, yPos)

    if dragLastMouseX then
        dragVelocityX = (mouse.X - dragLastMouseX) / math.max(dt or 0, 1 / 240)
    else
        dragVelocityX = 0
    end
    dragLastMouseX = mouse.X
end

local function colorToTable(color)
    return {
        r = math.floor((color.R * 255) + 0.5),
        g = math.floor((color.G * 255) + 0.5),
        b = math.floor((color.B * 255) + 0.5)
    }
end

local function tableToColor(value)
    if typeof(value) == "Color3" then
        return value
    end
    if type(value) == "table" then
        local r = tonumber(value.r or value[1])
        local g = tonumber(value.g or value[2])
        local b = tonumber(value.b or value[3])
        if r and g and b then
            if r <= 1 and g <= 1 and b <= 1 then
                return Color3.new(r, g, b)
            end
            return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
        end
    end
end

local function hasFileApi()
    return type(isfolder) == "function"
        and type(makefolder) == "function"
        and type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end

local function ensureFolder(path)
    if not hasFileApi() then
        return false, "executor file APIs unavailable"
    end
    local ok, exists = pcall(function()
        return isfolder(path)
    end)
    if not ok then
        return false, tostring(exists)
    end
    if not exists then
        local made, err = pcall(function()
            makefolder(path)
        end)
        if not made then
            return false, tostring(err)
        end
    end
    return true
end

local function safeIsFile(path)
    if not hasFileApi() then
        return false
    end
    local ok, exists = pcall(function()
        return isfile(path)
    end)
    return ok and exists == true
end

local function safeReadFile(path)
    if not hasFileApi() then
        return false, "executor file APIs unavailable"
    end
    local ok, result = pcall(function()
        return readfile(path)
    end)
    return ok, ok and result or tostring(result)
end

local function safeWriteFile(path, data)
    if not hasFileApi() then
        return false, "executor file APIs unavailable"
    end
    local ok, err = pcall(function()
        writefile(path, data)
    end)
    return ok, ok and path or tostring(err)
end

local function ensureSaveFolders()
    local ok, err = ensureFolder(ROOT_FOLDER)
    if not ok then return false, err end
    ok, err = ensureFolder(THEME_FOLDER)
    if not ok then return false, err end
    ok, err = ensureFolder(CONFIG_FOLDER)
    if not ok then return false, err end
    return true
end

local function sanitizeConfigName(name)
    name = tostring(name or "default")
    name = name:gsub("[^%w%-%_ ]", "_")
    if name == "" then
        name = "default"
    end
    if not name:match("%.json$") then
        name = name .. ".json"
    end
    return name
end

local function displaySaveName(path)
    path = tostring(path or ""):gsub("\\", "/")
    local name = path:match("([^/]+)$") or path
    return name:gsub("%.json$", "")
end

local function buildSavePath(folder, name)
    return folder .. "/" .. sanitizeConfigName(name)
end

local function readNameIndex(path)
    local values = {}
    if not safeIsFile(path) then
        return values
    end

    local ok, raw = safeReadFile(path)
    if not ok then
        return values
    end

    for line in tostring(raw or ""):gmatch("[^\r\n]+") do
        local name = displaySaveName(line:gsub("^%s+", ""):gsub("%s+$", ""))
        if name ~= "" and not table.find(values, name) then
            table.insert(values, name)
        end
    end
    table.sort(values)
    return values
end

local function writeNameIndex(path, values)
    local ok, err = ensureSaveFolders()
    if not ok then return false, err end
    table.sort(values)
    return safeWriteFile(path, table.concat(values, "\n"))
end

local function trackSaveName(path, name)
    local values = readNameIndex(path)
    name = displaySaveName(name)
    if name ~= "" and not table.find(values, name) then
        table.insert(values, name)
    end
    return writeNameIndex(path, values)
end

local function untrackSaveName(path, name)
    local values = readNameIndex(path)
    name = displaySaveName(name)
    for index, value in next, values do
        if value == name then
            table.remove(values, index)
            break
        end
    end
    return writeNameIndex(path, values)
end

local function listJsonFiles(folder, indexPath)
    if not hasFileApi() then
        return {}, "executor file APIs unavailable"
    end
    local values = indexPath and readNameIndex(indexPath) or {}

    if type(listfiles) ~= "function" then
        return values, #values == 0 and "executor listfiles API unavailable" or nil
    end
    local folderOk, folderExists = pcall(function()
        return isfolder(folder)
    end)
    if not folderOk or not folderExists then
        return values
    end

    local listed, files = pcall(function()
        return listfiles(folder)
    end)
    if not listed then
        return values, tostring(files)
    end

    for _, path in next, files do
        if tostring(path):lower():match("%.json$") then
            local name = displaySaveName(path)
            if not table.find(values, name) then
                table.insert(values, name)
            end
        end
    end
    table.sort(values)
    return values
end

local function readMarker(path)
    if not safeIsFile(path) then
        return nil
    end

    local ok, raw = safeReadFile(path)
    if not ok then
        return nil
    end

    local value = tostring(raw or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return displaySaveName(value)
end

local function writeMarker(path, value)
    local ok, err = ensureSaveFolders()
    if not ok then return false, err end
    return safeWriteFile(path, displaySaveName(value))
end

local function clearMarker(path)
    if not hasFileApi() then
        return false, "executor file APIs unavailable"
    end
    if type(delfile) == "function" and safeIsFile(path) then
        local ok, err = pcall(function()
            delfile(path)
        end)
        if not ok then
            return false, tostring(err)
        end
    elseif type(writefile) == "function" then
        return safeWriteFile(path, "")
    end
    return true, path
end

local function deleteSaveFile(path)
    if not hasFileApi() then
        return false, "executor file APIs unavailable"
    end
    if not safeIsFile(path) then
        return false, "file not found"
    end
    if type(delfile) ~= "function" then
        return false, "executor delfile API unavailable"
    end
    local ok, err = pcall(function()
        delfile(path)
    end)
    return ok, ok and path or tostring(err)
end

local function normalizeCursorImage(imageId)
    imageId = tostring(imageId or ""):gsub("%s+", "")
    if imageId == "" then
        return ""
    end
    if imageId:match("^rbxassetid://") or imageId:match("^http") then
        return imageId
    end

    local digits = imageId:match("%d+")
    return digits and ("rbxassetid://" .. digits) or imageId
end

local function encodeJson(data)
    local ok, encoded = pcall(function()
        return httpService:JSONEncode(data)
    end)
    return ok and encoded or nil
end

local function decodeJson(raw)
    local ok, decoded = pcall(function()
        return httpService:JSONDecode(raw)
    end)
    return ok and decoded or nil
end

--From: https://devforum.roblox.com/t/how-to-create-a-simple-rainbow-effect-using-tweenService/221849/2
local chromaColor
local rainbowTime = 5
spawn(function()
    while wait() do
        chromaColor = Color3.fromHSV(tick() % rainbowTime / rainbowTime, 1, 1)
    end
end)

function library:Create(class, properties)
    properties = typeof(properties) == "table" and properties or {}
    local inst = Instance.new(class)
    for property, value in next, properties do
        inst[property] = value
    end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        self.originalFonts[inst] = inst.Font
        if self.fontOverride then
            inst.Font = self.font
        end
    end
    return inst
end

function library:Draw(class, properties)
    local properties = type(properties) == 'table' and properties or {};

    local object = Drawing.new(class)
    for p, v in next, properties do
        object[p] = v;
    end
    return object
end

function library:RegisterThemeObject(object, property, resolver)
    if not object or not property then return end
    if self.liveAccentThemes ~= true then return end

    local item = {
        object = object,
        property = property,
        resolver = typeof(resolver) == "function" and resolver or function(theme)
            return theme.Accent
        end
    }
    table.insert(self.themeObjects, item)

    pcall(function()
        object[property] = item.resolver(self.theme)
    end)
end

function library:ApplyTheme()
    if self.liveAccentThemes ~= true then return end

    local aliveCount = 0
    for _, item in next, self.themeObjects do
        if item.object and item.object.Parent then
            aliveCount = aliveCount + 1
            self.themeObjects[aliveCount] = item
            pcall(function()
                item.object[item.property] = item.resolver(self.theme)
            end)
        end
    end
    for index = aliveCount + 1, #self.themeObjects do
        self.themeObjects[index] = nil
    end
end

function library:SetTheme(theme)
    theme = typeof(theme) == "table" and theme or {}
    local accent = tableToColor(theme.Accent or theme.accent)
    if accent then
        self.theme.Accent = accent
    end
    local font = theme.Font or theme.font
    if font then
        if tostring(font) == "Default" then
            self:ResetFont()
        else
            self:SetFont(tostring(font))
        end
    end
    self:ApplyTheme()
end

function library:GetTheme()
    return {
        Accent = self.theme.Accent,
        Font = self.fontOverride and self.font.Name or "Default"
    }
end

function library:SetFont(font)
    if typeof(font) == "string" then
        if font == "Default" then
            return self:ResetFont()
        end
        local ok, enumFont = pcall(function()
            return Enum.Font[font]
        end)
        font = ok and enumFont or nil
    end
    if typeof(font) ~= "EnumItem" or font.EnumType ~= Enum.Font then
        return false
    end

    self.font = font
    self.fontOverride = true
    if self.base then
        for _, object in next, self.base:GetDescendants() do
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                self.originalFonts[object] = self.originalFonts[object] or object.Font
                object.Font = font
            end
        end
    end

    return true
end

function library:ResetFont()
    self.fontOverride = false
    self.font = Enum.Font.Gotham
    if self.base then
        for _, object in next, self.base:GetDescendants() do
            if (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) and self.originalFonts[object] then
                object.Font = self.originalFonts[object]
            end
        end
    end
    return true
end

function library:ResetTheme()
    self:SetTheme({
        Accent = self.defaultTheme.Accent,
        Font = "Default"
    })
end

function library:SetCustomCursor(imageId)
    self.customCursorId = normalizeCursorImage(imageId)
    if self.cursorImage then
        self.cursorImage.Image = self.customCursorId
    end
    self:SetCustomCursorEnabled(self.customCursorEnabled)
    return self.customCursorId ~= ""
end

function library:SetCustomCursorEnabled(enabled)
    self.customCursorEnabled = enabled == true
    local showCustomCursor = self.customCursorEnabled and self.customCursorId ~= ""

    if self.cursor then
        self.cursor.Visible = self.open and not showCustomCursor
    end
    if self.cursorImage then
        self.cursorImage.Visible = self.open and showCustomCursor
    end

    pcall(function()
        inputService.MouseIconEnabled = not showCustomCursor
    end)

    return true
end

function library:SaveTheme(name)
    local ok, err = ensureSaveFolders()
    if not ok then return false, err end

    local encoded = encodeJson({
        Accent = colorToTable(self.theme.Accent),
        Font = self.fontOverride and self.font.Name or "Default"
    })
    if not encoded then
        return false, "failed to encode theme"
    end

    local path = name and buildSavePath(THEME_FOLDER, name) or THEME_FILE
    local written, result = safeWriteFile(path, encoded)
    if not written then
        return false, result
    end
    trackSaveName(THEME_INDEX_FILE, name or "theme")
    return true, result
end

function library:LoadTheme(name)
    if not hasFileApi() then
        return false, "executor file APIs unavailable"
    end

    local path = name and buildSavePath(THEME_FOLDER, name) or THEME_FILE
    if not safeIsFile(path) then
        return false, "theme file not found"
    end

    local read, raw = safeReadFile(path)
    if not read then
        return false, raw
    end

    local decoded = decodeJson(raw)
    if type(decoded) ~= "table" then
        return false, "failed to decode theme"
    end

    self:SetTheme(decoded)
    return true, path
end

function library:GetThemeList()
    local ok, err = ensureSaveFolders()
    if not ok then return {}, err end
    return listJsonFiles(THEME_FOLDER, THEME_INDEX_FILE)
end

function library:DeleteTheme(name)
    local ok, err = ensureSaveFolders()
    if not ok then return false, err end

    local path = buildSavePath(THEME_FOLDER, name)
    local deleted, result = deleteSaveFile(path)
    if deleted and self:GetDefaultTheme() == displaySaveName(name) then
        self:ResetDefaultTheme()
    end
    if deleted then
        untrackSaveName(THEME_INDEX_FILE, name)
    end
    return deleted, result
end

function library:SetDefaultTheme(name)
    local ok, err = ensureSaveFolders()
    if not ok then return false, err end

    local path = buildSavePath(THEME_FOLDER, name)
    if not safeIsFile(path) then
        return false, "theme file not found"
    end
    return writeMarker(THEME_DEFAULT_FILE, name)
end

function library:GetDefaultTheme()
    return readMarker(THEME_DEFAULT_FILE)
end

function library:ResetDefaultTheme()
    return clearMarker(THEME_DEFAULT_FILE)
end

function library:LoadDefaultTheme()
    local name = self:GetDefaultTheme()
    if not name then
        return false, "default theme not set"
    end
    return self:LoadTheme(name)
end

function library:SaveConfig(name)
    local ok, err = ensureSaveFolders()
    if not ok then return false, err end

    local values = {}
    for flag, option in next, self.options do
        if option.type ~= "button" and option.skipConfig ~= true then
            local value = self.flags[flag]
            if typeof(value) == "Color3" then
                value = colorToTable(value)
            end
            values[flag] = {
                type = option.type,
                value = value
            }
        end
    end

    local encoded = encodeJson({
        flags = values,
        theme = {
            Accent = colorToTable(self.theme.Accent),
            Font = self.fontOverride and self.font.Name or "Default"
        }
    })
    if not encoded then
        return false, "failed to encode config"
    end

    local path = buildSavePath(CONFIG_FOLDER, name)
    local written, result = safeWriteFile(path, encoded)
    if not written then
        return false, result
    end
    trackSaveName(CONFIG_INDEX_FILE, name or "default")
    return true, result
end

function library:LoadConfig(name)
    if not hasFileApi() then
        return false, "executor file APIs unavailable"
    end

    local path = buildSavePath(CONFIG_FOLDER, name)
    if not safeIsFile(path) then
        return false, "config file not found"
    end

    local read, raw = safeReadFile(path)
    if not read then
        return false, raw
    end

    local decoded = decodeJson(raw)
    if type(decoded) ~= "table" then
        return false, "failed to decode config"
    end

    if type(decoded.theme) == "table" then
        self:SetTheme(decoded.theme)
    end

    local flags = type(decoded.flags) == "table" and decoded.flags or {}
    for flag, payload in next, flags do
        local option = self.options[flag]
        local value = type(payload) == "table" and payload.value or payload
        if option and option.skipConfig ~= true then
            if option.type == "toggle" and option.SetState then
                option:SetState(value == true)
            elseif option.type == "slider" and option.SetValue then
                option:SetValue(tonumber(value) or option.value)
            elseif option.type == "list" and option.SetValue then
                option:SetValue(tostring(value or ""))
            elseif option.type == "box" and option.SetValue then
                option:SetValue(tostring(value or ""), true)
            elseif option.type == "bind" and option.SetKey then
                option:SetKey(tostring(value or option.key))
            elseif option.type == "color" and option.SetColor then
                local color = tableToColor(value)
                if color then
                    option:SetColor(color)
                end
            end
        end
    end

    return true, path
end

function library:GetConfigList()
    local ok, err = ensureSaveFolders()
    if not ok then return {}, err end
    return listJsonFiles(CONFIG_FOLDER, CONFIG_INDEX_FILE)
end

function library:DeleteConfig(name)
    local ok, err = ensureSaveFolders()
    if not ok then return false, err end

    local path = buildSavePath(CONFIG_FOLDER, name)
    local deleted, result = deleteSaveFile(path)
    if deleted and self:GetAutoloadConfig() == displaySaveName(name) then
        self:ResetAutoloadConfig()
    end
    if deleted then
        untrackSaveName(CONFIG_INDEX_FILE, name)
    end
    return deleted, result
end

function library:SetAutoloadConfig(name)
    local ok, err = ensureSaveFolders()
    if not ok then return false, err end

    local path = buildSavePath(CONFIG_FOLDER, name)
    if not safeIsFile(path) then
        return false, "config file not found"
    end
    return writeMarker(CONFIG_AUTOLOAD_FILE, name)
end

function library:GetAutoloadConfig()
    return readMarker(CONFIG_AUTOLOAD_FILE)
end

function library:ResetAutoloadConfig()
    return clearMarker(CONFIG_AUTOLOAD_FILE)
end

function library:LoadAutoloadConfig()
    local name = self:GetAutoloadConfig()
    if not name then
        return false, "autoload config not set"
    end
    return self:LoadConfig(name)
end

local function createOptionHolder(holderTitle, parent, parentTable, subHolder)
    local size = subHolder and 34 or 40
    parentTable.main = library:Create("ImageButton", {
        LayoutOrder = subHolder and parentTable.position or 0,
        Position = parentTable.windowPosition or UDim2.new(0, 20 + (250 * (parentTable.position or 0)), 0, 20),
        Size = UDim2.new(0, 230, 0, size),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(20, 20, 20),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.04,
        ClipsDescendants = true,
        Parent = parent
    })

    local round
    if not subHolder then
        round = library:Create("ImageLabel", {
            Size = UDim2.new(1, 0, 0, size),
            BackgroundTransparency = 1,
            Image = "rbxassetid://3570695787",
            ImageColor3 = parentTable.open and (subHolder and Color3.fromRGB(16, 16, 16) or Color3.fromRGB(10, 10, 10)) or
            (subHolder and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(6, 6, 6)),
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(100, 100, 100, 100),
            SliceScale = 0.04,
            Parent = parentTable.main
        })
    end

    local title = library:Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, size),
        BackgroundTransparency = subHolder and 0 or 1,
        BackgroundColor3 = subHolder and (parentTable.open and Color3.fromRGB(16, 16, 16) or Color3.fromRGB(10, 10, 10)) or
        Color3.fromRGB(10, 10, 10),
        BorderSizePixel = 0,
        Text = holderTitle,
        TextSize = subHolder and 16 or 17,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Parent = parentTable.main
    })
    parentTable.topBar = title

    local closeHolder = library:Create("Frame", {
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(-1, 0, 1, 0),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        BackgroundTransparency = 1,
        Parent = title
    })

    local close = library:Create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -size - 10, 1, -size - 10),
        Rotation = parentTable.open and 90 or 180,
        BackgroundTransparency = 1,
        Image = "rbxassetid://4918373417",
        ImageColor3 = parentTable.open and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(30, 30, 30),
        ScaleType = Enum.ScaleType.Fit,
        Parent = closeHolder
    })

    parentTable.content = library:Create("Frame", {
        Position = UDim2.new(0, 0, 0, size),
        Size = UDim2.new(1, 0, 1, -size),
        BackgroundTransparency = 1,
        Parent = parentTable.main
    })

    local layout = library:Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parentTable.content
    })

    layout.Changed:connect(function()
        parentTable.content.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
        parentTable.main.Size = #parentTable.options > 0 and parentTable.open and
        UDim2.new(0, 230, 0, layout.AbsoluteContentSize.Y + size) or UDim2.new(0, 230, 0, size)
    end)

    if not subHolder then
        library:Create("UIPadding", {
            Parent = parentTable.content
        })

        title.InputBegan:connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragObject = parentTable.main
                dragging = true
                dragStart = inputService:GetMouseLocation()
                startPos = dragObject.Position
                dragTarget = startPos
                dragLastMouseX = dragStart.X
                dragVelocityX = 0
                dragRotationVelocity = 0
                dragOriginalClips = dragObject.ClipsDescendants
                dragObject.ClipsDescendants = false
            end
        end)
        title.InputEnded:connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end

    closeHolder.InputBegan:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            parentTable.open = not parentTable.open
            tweenService:Create(close, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Rotation = parentTable.open and 90 or 180, ImageColor3 = parentTable.open and
                Color3.fromRGB(50, 50, 50) or Color3.fromRGB(30, 30, 30) }):Play()
            if subHolder then
                tweenService:Create(title, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundColor3 = parentTable.open and Color3.fromRGB(16, 16, 16) or Color3.fromRGB(10, 10, 10) })
                    :Play()
            else
                tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = parentTable.open and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(6, 6, 6) }):Play()
            end
            parentTable.main:TweenSize(
            #parentTable.options > 0 and parentTable.open and UDim2.new(0, 230, 0, layout.AbsoluteContentSize.Y + size) or
            UDim2.new(0, 230, 0, size), "Out", "Quad", 0.2, true)
        end
    end)

    function parentTable:SetTitle(newTitle)
        title.Text = tostring(newTitle)
    end

    return parentTable
end

local function createLabel(option, parent)
    local main = library:Create("TextLabel", {
        LayoutOrder = option.position,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = " " .. option.text,
        TextSize = 17,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent.content
    })

    function option:Set(value)
        self.text = tostring(value)
        main.Text = " " .. self.text
    end

    setmetatable(option, {
        __newindex = function(t, i, v)
            if i == "Text" then
                main.Text = " " .. tostring(v)
            end
        end
    })
end

function createToggle(option, parent)
    local main = library:Create("TextLabel", {
        LayoutOrder = option.position,
        Size = UDim2.new(1, 0, 0, 31),
        BackgroundTransparency = 1,
        Text = " " .. option.text,
        TextSize = 17,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent.content
    })

    local tickboxOutline = library:Create("ImageLabel", {
        Position = UDim2.new(1, -6, 0, 4),
        Size = UDim2.new(-1, 10, 1, -10),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = option.state and getAccent() or Color3.fromRGB(100, 100, 100),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = main
    })

    local tickboxInner = library:Create("ImageLabel", {
        Position = UDim2.new(0, 2, 0, 2),
        Size = UDim2.new(1, -4, 1, -4),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = option.state and getAccent() or Color3.fromRGB(20, 20, 20),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = tickboxOutline
    })

    local checkmarkHolder = library:Create("Frame", {
        Position = UDim2.new(0, 4, 0, 4),
        Size = option.state and UDim2.new(1, -8, 1, -8) or UDim2.new(0, 0, 1, -8),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = tickboxOutline
    })

    local checkmark = library:Create("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        BackgroundTransparency = 1,
        Image = "rbxassetid://4919148038",
        ImageColor3 = Color3.fromRGB(20, 20, 20),
        Parent = checkmarkHolder
    })

    local inContact
    library:RegisterThemeObject(tickboxOutline, "ImageColor3", function(theme)
        return option.state and theme.Accent or Color3.fromRGB(100, 100, 100)
    end)
    library:RegisterThemeObject(tickboxInner, "ImageColor3", function(theme)
        return option.state and theme.Accent or Color3.fromRGB(20, 20, 20)
    end)

    main.InputBegan:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            option:SetState(not option.state)
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            if not option.state then
                tweenService:Create(tickboxOutline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(140, 140, 140) }):Play()
            end
        end
    end)

    main.InputEnded:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            if not option.state then
                tweenService:Create(tickboxOutline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(100, 100, 100) }):Play()
            end
        end
    end)

    function option:SetState(state)
        library.flags[self.flag] = state
        self.state = state
        checkmarkHolder:TweenSize(option.state and UDim2.new(1, -8, 1, -8) or UDim2.new(0, 0, 1, -8), "Out", "Quad", 0.2,
            true)
        tweenService:Create(tickboxInner, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageColor3 = state and getAccent() or Color3.fromRGB(20, 20, 20) }):Play()
        if state then
            tweenService:Create(tickboxOutline, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = getAccent() }):Play()
        else
            if inContact then
                tweenService:Create(tickboxOutline, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(140, 140, 140) }):Play()
            else
                tweenService:Create(tickboxOutline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(100, 100, 100) }):Play()
            end
        end
        self.callback(state)
    end

    if option.state then
        delay(1, function() option.callback(true) end)
    end

    setmetatable(option, {
        __newindex = function(t, i, v)
            if i == "Text" then
                main.Text = " " .. tostring(v)
            end
        end
    })
end

function createButton(option, parent)
    local main = library:Create("TextLabel", {
        ZIndex = 2,
        LayoutOrder = option.position,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        Text = " " .. option.text,
        TextSize = 17,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Parent = parent.content
    })

    local round = library:Create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(1, -12, 1, -10),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(40, 40, 40),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = main
    })

    local inContact
    local clicking
    library:RegisterThemeObject(round, "ImageColor3", function(theme)
        if clicking then
            return theme.Accent
        end
        return inContact and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(40, 40, 40)
    end)

    main.InputBegan:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            library.flags[option.flag] = true
            clicking = true
            tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = getAccent() }):Play()
            option.callback()
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            tweenService:Create(round, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
        end
    end)

    main.InputEnded:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            clicking = false
            if inContact then
                tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
            else
                tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(40, 40, 40) }):Play()
            end
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = false
            if not clicking then
                tweenService:Create(round, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(40, 40, 40) }):Play()
            end
        end
    end)
end

local function createBind(option, parent)
    local binding
    local holding
    local loop
    local text = string.match(option.key, "Mouse") and string.sub(option.key, 1, 5) .. string.sub(option.key, 12, 13) or
    option.key

    local main = library:Create("TextLabel", {
        LayoutOrder = option.position,
        Size = UDim2.new(1, 0, 0, 33),
        BackgroundTransparency = 1,
        Text = " " .. option.text,
        TextSize = 17,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent.content
    })

    local round = library:Create("ImageLabel", {
        Position = UDim2.new(1, -6, 0, 4),
        Size = UDim2.new(0, -textService:GetTextSize(text, 16, Enum.Font.Gotham, Vector2.new(9e9, 9e9)).X - 16, 1, -10),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(40, 40, 40),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = main
    })

    local bindinput = library:Create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextSize = 16,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Parent = round
    })

    local inContact
    library:RegisterThemeObject(round, "ImageColor3", function(theme)
        if binding then
            return theme.Accent
        end
        return inContact and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(40, 40, 40)
    end)

    main.InputBegan:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            if not binding then
                tweenService:Create(round, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
            end
        end
    end)

    main.InputEnded:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            binding = true
            bindinput.Text = "..."
            tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = getAccent() }):Play()
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = false
            if not binding then
                tweenService:Create(round, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(40, 40, 40) }):Play()
            end
        end
    end)

    inputService.InputBegan:connect(function(input)
        if inputService:GetFocusedTextBox() then return end
        if (input.KeyCode.Name == option.key or input.UserInputType.Name == option.key) and not binding then
            if option.hold then
                loop = runService.Heartbeat:connect(function()
                    if binding then
                        option.callback(true)
                        loop:Disconnect()
                        loop = nil
                    else
                        option.callback()
                    end
                end)
            else
                option.callback()
            end
        elseif binding then
            local key
            pcall(function()
                if not keyCheck(input.KeyCode, blacklistedKeys) then
                    key = input.KeyCode
                end
            end)
            pcall(function()
                if keyCheck(input.UserInputType, whitelistedMouseinputs) and not key then
                    key = input.UserInputType
                end
            end)
            key = key or option.key
            option:SetKey(key)
        end
    end)

    inputService.InputEnded:connect(function(input)
        if input.KeyCode.Name == option.key or input.UserInputType.Name == option.key or input.UserInputType.Name == "MouseMovement" then
            if loop then
                loop:Disconnect()
                loop = nil
                option.callback(true)
            end
        end
    end)

    function option:SetKey(key)
        binding = false
        if loop then
            loop:Disconnect()
            loop = nil
        end
        self.key = key or self.key
        self.key = self.key.Name or self.key
        library.flags[self.flag] = self.key
        if string.match(self.key, "Mouse") then
            bindinput.Text = string.sub(self.key, 1, 5) .. string.sub(self.key, 12, 13)
        else
            bindinput.Text = self.key
        end
        tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageColor3 = inContact and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(40, 40, 40) }):Play()
        round.Size = UDim2.new(0,
            -textService:GetTextSize(bindinput.Text, 15, Enum.Font.Gotham, Vector2.new(9e9, 9e9)).X - 16, 1, -10)
    end
end

local function createSlider(option, parent)
    local main = library:Create("Frame", {
        LayoutOrder = option.position,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Parent = parent.content
    })

    local title = library:Create("TextLabel", {
        Position = UDim2.new(0, 0, 0, 4),
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = " " .. option.text,
        TextSize = 17,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = main
    })

    local slider = library:Create("ImageLabel", {
        Position = UDim2.new(0, 10, 0, 34),
        Size = UDim2.new(1, -20, 0, 5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(30, 30, 30),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = main
    })

    local fill = library:Create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = getAccent(),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = slider
    })

    local circle = library:Create("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new((option.value - option.min) / (option.max - option.min), 0, 0.5, 0),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(60, 60, 60),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 1,
        Parent = slider
    })

    local valueRound = library:Create("ImageLabel", {
        Position = UDim2.new(1, -6, 0, 4),
        Size = UDim2.new(0, -60, 0, 18),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(40, 40, 40),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = main
    })

    local inputvalue = library:Create("TextBox", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = option.value,
        TextColor3 = Color3.fromRGB(235, 235, 235),
        TextSize = 15,
        TextWrapped = true,
        Font = Enum.Font.Gotham,
        Parent = valueRound
    })

    if option.min >= 0 then
        fill.Size = UDim2.new((option.value - option.min) / (option.max - option.min), 0, 1, 0)
    else
        fill.Position = UDim2.new((0 - option.min) / (option.max - option.min), 0, 0, 0)
        fill.Size = UDim2.new(option.value / (option.max - option.min), 0, 1, 0)
    end

    local sliding
    local inContact
    library:RegisterThemeObject(fill, "ImageColor3", function(theme)
        return theme.Accent
    end)
    library:RegisterThemeObject(circle, "ImageColor3", function(theme)
        return sliding and theme.Accent or Color3.fromRGB(60, 60, 60)
    end)

    main.InputBegan:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            tweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = getAccent() }):Play()
            tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.new(3.5, 0, 3.5, 0), ImageColor3 = getAccent() }):Play()
            sliding = true
            option:SetValue(option.min +
            ((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X) * (option.max - option.min))
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            if not sliding then
                tweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = getAccent() }):Play()
                tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Size = UDim2.new(2.8, 0, 2.8, 0), ImageColor3 = Color3.fromRGB(100, 100, 100) }):Play()
            end
        end
    end)

    inputService.InputChanged:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and sliding then
            option:SetValue(option.min +
            ((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X) * (option.max - option.min))
        end
    end)

    main.InputEnded:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
            if inContact then
                tweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = getAccent() }):Play()
                tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Size = UDim2.new(2.8, 0, 2.8, 0), ImageColor3 = Color3.fromRGB(100, 100, 100) }):Play()
            else
                tweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = getAccent() }):Play()
                tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Size = UDim2.new(0, 0, 0, 0), ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
            end
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = false
            inputvalue:ReleaseFocus()
            if not sliding then
                tweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = getAccent() }):Play()
                tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { Size = UDim2.new(0, 0, 0, 0), ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
            end
        end
    end)

    inputvalue.FocusLost:connect(function()
        tweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.new(0, 0, 0, 0), ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
        option:SetValue(tonumber(inputvalue.Text) or option.value)
    end)

    function option:SetValue(value)
        value = round(value, option.places)
        value = math.clamp(value, self.min, self.max)

        circle:TweenPosition(UDim2.new((value - self.min) / (self.max - self.min), 0, 0.5, 0), "Out", "Quad", 0.1, true)
        if self.min >= 0 then
            fill:TweenSize(UDim2.new((value - self.min) / (self.max - self.min), 0, 1, 0), "Out", "Quad", 0.1, true)
        else
            fill:TweenPosition(UDim2.new((0 - self.min) / (self.max - self.min), 0, 0, 0), "Out", "Quad", 0.1, true)
            fill:TweenSize(UDim2.new(value / (self.max - self.min), 0, 1, 0), "Out", "Quad", 0.1, true)
        end

        library.flags[self.flag] = value
        self.value = value
        inputvalue.Text = value
        self.callback(value)
    end
end

local function createList(option, parent, holder)
    local valueCount = 0

    local main = library:Create("Frame", {
        LayoutOrder = option.position,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
        Parent = parent.content
    })

    local round = library:Create("ImageLabel", {
        Position = UDim2.new(0, 6, 0, 4),
        Size = UDim2.new(1, -12, 1, -10),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(40, 40, 40),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = main
    })

    local title = library:Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -24, 0, 14),
        BackgroundTransparency = 1,
        Text = option.text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(140, 140, 140),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = main
    })

    local listvalue = library:Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 20),
        Size = UDim2.new(1, -24, 0, 24),
        BackgroundTransparency = 1,
        Text = option.value,
        TextSize = 18,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = main
    })

    library:Create("ImageLabel", {
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.new(-1, 32, 1, -32),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        Rotation = 90,
        BackgroundTransparency = 1,
        Image = "rbxassetid://4918373417",
        ImageColor3 = Color3.fromRGB(140, 140, 140),
        ScaleType = Enum.ScaleType.Fit,
        Parent = round
    })

    option.mainHolder = library:Create("ImageButton", {
        ZIndex = 3,
        Size = UDim2.new(0, 240, 0, 52),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageTransparency = 1,
        ImageColor3 = Color3.fromRGB(30, 30, 30),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Visible = false,
        Parent = library.base
    })

    local content = library:Create("ScrollingFrame", {
        ZIndex = 3,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarImageColor3 = Color3.fromRGB(),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = option.mainHolder
    })

    library:Create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        Parent = content
    })

    local layout = library:Create("UIListLayout", {
        Parent = content
    })

    layout.Changed:connect(function()
        option.mainHolder.Size = UDim2.new(0, 240, 0, (valueCount > 4 and (4 * 40) or layout.AbsoluteContentSize.Y) + 12)
        content.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end)

    local inContact
    round.InputBegan:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if library.activePopup then
                library.activePopup:Close()
            end
            local position = main.AbsolutePosition
            option.mainHolder.Position = UDim2.new(0, position.X - 5, 0, position.Y - 10)
            option.open = true
            option.mainHolder.Visible = true
            library.activePopup = option
            content.ScrollBarThickness = 6
            tweenService:Create(option.mainHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { ImageTransparency = 0, Position = UDim2.new(0, position.X - 5, 0, position.Y - 4) }):Play()
            tweenService:Create(option.mainHolder,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.1),
                { Position = UDim2.new(0, position.X - 5, 0, position.Y + 1) }):Play()
            for _, label in next, content:GetChildren() do
                if label:IsA "TextLabel" then
                    tweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
                end
            end
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            if not option.open then
                tweenService:Create(round, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
            end
        end
    end)

    round.InputEnded:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = false
            if not option.open then
                tweenService:Create(round, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(40, 40, 40) }):Play()
            end
        end
    end)

    local TAB_CONST = string.rep(' ', 4)
    function option:AddValue(value)
        valueCount = valueCount + 1
        local label = library:Create("TextLabel", {
            ZIndex = 3,
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = Color3.fromRGB(30, 30, 30),
            BorderSizePixel = 0,
            Text = TAB_CONST .. value,
            TextSize = 14,
            TextTransparency = self.open and 0 or 1,
            Font = Enum.Font.Gotham,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = content
        })

        local inContact
        local clicking
        label.InputBegan:connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                clicking = true
                tweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundColor3 = Color3.fromRGB(10, 10, 10) }):Play()
                self:SetValue(value)
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                inContact = true
                if not clicking then
                    tweenService:Create(label, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { BackgroundColor3 = Color3.fromRGB(20, 20, 20) }):Play()
                end
            end
        end)

        label.InputEnded:connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                clicking = false
                tweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundColor3 = inContact and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(30, 30, 30) }):Play()
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                inContact = false
                if not clicking then
                    tweenService:Create(label, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { BackgroundColor3 = Color3.fromRGB(30, 30, 30) }):Play()
                end
            end
        end)

        if not table.find(option.values, value) then
            table.insert(option.values, value)
        end
    end

    if not table.find(option.values, option.value) then
        option:AddValue(option.value)
    end

    for _, value in next, option.values do
        option:AddValue(tostring(value))
    end

    function option:RemoveValue(value)
        for _, label in next, content:GetChildren() do
            if label:IsA "TextLabel" and label.Text == (TAB_CONST .. value) then
                label:Destroy()
                valueCount = valueCount - 1
                break
            end
        end

        if self.value == value then
            self:SetValue("")
        end
    end

    function option:ClearValues()
        for _, label in next, content:GetChildren() do
            if label:IsA "TextLabel" then
                label:Destroy()
            end
        end
        self.values = {}
        valueCount = 0
        self:SetValue("")
    end

    function option:SetValue(value)
        library.flags[self.flag] = tostring(value)
        self.value = tostring(value)
        listvalue.Text = self.value
        self.callback(value)
    end

    function option:Close()
        library.activePopup = nil
        self.open = false
        content.ScrollBarThickness = 0
        local position = main.AbsolutePosition
        tweenService:Create(round, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageColor3 = inContact and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(40, 40, 40) }):Play()
        tweenService:Create(self.mainHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageTransparency = 1, Position = UDim2.new(0, position.X - 5, 0, position.Y - 10) }):Play()
        for _, label in next, content:GetChildren() do
            if label:IsA "TextLabel" then
                tweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            end
        end
        wait(0.3)
        --delay(0.3, function()
        if not self.open then
            self.mainHolder.Visible = false
        end
        --end)
    end

    return option
end

local function createBox(option, parent)
    local main = library:Create("Frame", {
        LayoutOrder = option.position,
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundTransparency = 1,
        Parent = parent.content
    })

    local outline = library:Create("ImageLabel", {
        Position = UDim2.new(0, 6, 0, 4),
        Size = UDim2.new(1, -12, 1, -10),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(60, 60, 60),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = main
    })

    local round = library:Create("ImageLabel", {
        Position = UDim2.new(0, 8, 0, 6),
        Size = UDim2.new(1, -16, 1, -14),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(20, 20, 20),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.01,
        Parent = main
    })

    local title = library:Create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 8),
        Size = UDim2.new(1, -24, 0, 14),
        BackgroundTransparency = 1,
        Text = option.text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(100, 100, 100),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = main
    })

    local inputvalue = library:Create("TextBox", {
        Position = UDim2.new(0, 12, 0, 20),
        Size = UDim2.new(1, -24, 0, 24),
        BackgroundTransparency = 1,
        Text = option.value,
        TextSize = 18,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Parent = main
    })

    local inContact
    local focused
    library:RegisterThemeObject(outline, "ImageColor3", function(theme)
        return focused and theme.Accent or Color3.fromRGB(60, 60, 60)
    end)

    main.InputBegan:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not focused then inputvalue:CaptureFocus() end
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            if not focused then
                tweenService:Create(outline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(100, 100, 100) }):Play()
            end
        end
    end)

    main.InputEnded:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = false
            if not focused then
                tweenService:Create(outline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
            end
        end
    end)

    inputvalue.Focused:connect(function()
        focused = true
        tweenService:Create(outline, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageColor3 = getAccent() }):Play()
    end)

    inputvalue.FocusLost:connect(function(enter)
        focused = false
        tweenService:Create(outline, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageColor3 = Color3.fromRGB(60, 60, 60) }):Play()
        option:SetValue(inputvalue.Text, enter)
    end)

    function option:SetValue(value, enter)
        library.flags[self.flag] = tostring(value)
        self.value = tostring(value)
        inputvalue.Text = self.value
        self.callback(value, enter)
    end
end

local function createColorPickerWindow(option)
    option.mainHolder = library:Create("ImageButton", {
        ZIndex = 3,
        Size = UDim2.new(0, 240, 0, 180),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageTransparency = 1,
        ImageColor3 = Color3.fromRGB(30, 30, 30),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = library.base
    })

    local hue, sat, val = Color3.toHSV(option.color)
    hue, sat, val = hue == 0 and 1 or hue, sat + 0.005, val - 0.005
    local editinghue
    local editingsatval
    local currentColor = option.color
    local previousColors = { [1] = option.color }
    local originalColor = option.color
    local rainbowEnabled
    local rainbowLoop

    function option:updateVisuals(Color)
        currentColor = Color
        self.visualize2.ImageColor3 = Color
        hue, sat, val = Color3.toHSV(Color)
        hue = hue == 0 and 1 or hue
        self.satval.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        self.hueSlider.Position = UDim2.new(1 - hue, 0, 0, 0)
        self.satvalSlider.Position = UDim2.new(sat, 0, 1 - val, 0)
    end

    option.hue = library:Create("ImageLabel", {
        ZIndex = 3,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 8, 1, -8),
        Size = UDim2.new(1, -100, 0, 22),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = option.mainHolder
    })

    local Gradient = library:Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.157, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(0.323, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.488, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.817, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
        Parent = option.hue
    })

    option.hueSlider = library:Create("Frame", {
        ZIndex = 3,
        Position = UDim2.new(1 - hue, 0, 0, 0),
        Size = UDim2.new(0, 2, 1, 0),
        BackgroundTransparency = 1,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderColor3 = Color3.fromRGB(255, 255, 255),
        Parent = option.hue
    })

    option.hue.InputBegan:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            editinghue = true
            X = (option.hue.AbsolutePosition.X + option.hue.AbsoluteSize.X) - option.hue.AbsolutePosition.X
            X = (Input.Position.X - option.hue.AbsolutePosition.X) / X
            X = X < 0 and 0 or X > 0.995 and 0.995 or X
            option:updateVisuals(Color3.fromHSV(1 - X, sat, val))
        end
    end)

    inputService.InputChanged:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement and editinghue then
            X = (option.hue.AbsolutePosition.X + option.hue.AbsoluteSize.X) - option.hue.AbsolutePosition.X
            X = (Input.Position.X - option.hue.AbsolutePosition.X) / X
            X = X <= 0 and 0 or X >= 0.995 and 0.995 or X
            option:updateVisuals(Color3.fromHSV(1 - X, sat, val))
        end
    end)

    option.hue.InputEnded:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            editinghue = false
        end
    end)

    option.satval = library:Create("ImageLabel", {
        ZIndex = 3,
        Position = UDim2.new(0, 8, 0, 8),
        Size = UDim2.new(1, -100, 1, -42),
        BackgroundTransparency = 1,
        BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
        BorderSizePixel = 0,
        Image = "rbxassetid://4155801252",
        ImageTransparency = 1,
        ClipsDescendants = true,
        Parent = option.mainHolder
    })

    option.satvalSlider = library:Create("Frame", {
        ZIndex = 3,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(sat, 0, 1 - val, 0),
        Size = UDim2.new(0, 4, 0, 4),
        Rotation = 45,
        BackgroundTransparency = 1,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Parent = option.satval
    })

    option.satval.InputBegan:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            editingsatval = true
            X = (option.satval.AbsolutePosition.X + option.satval.AbsoluteSize.X) - option.satval.AbsolutePosition.X
            Y = (option.satval.AbsolutePosition.Y + option.satval.AbsoluteSize.Y) - option.satval.AbsolutePosition.Y
            X = (Input.Position.X - option.satval.AbsolutePosition.X) / X
            Y = (Input.Position.Y - option.satval.AbsolutePosition.Y) / Y
            X = X <= 0.005 and 0.005 or X >= 1 and 1 or X
            Y = Y <= 0 and 0 or Y >= 0.995 and 0.995 or Y
            option:updateVisuals(Color3.fromHSV(hue, X, 1 - Y))
        end
    end)

    inputService.InputChanged:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement and editingsatval then
            X = (option.satval.AbsolutePosition.X + option.satval.AbsoluteSize.X) - option.satval.AbsolutePosition.X
            Y = (option.satval.AbsolutePosition.Y + option.satval.AbsoluteSize.Y) - option.satval.AbsolutePosition.Y
            X = (Input.Position.X - option.satval.AbsolutePosition.X) / X
            Y = (Input.Position.Y - option.satval.AbsolutePosition.Y) / Y
            X = X <= 0.005 and 0.005 or X >= 1 and 1 or X
            Y = Y <= 0 and 0 or Y >= 0.995 and 0.995 or Y
            option:updateVisuals(Color3.fromHSV(hue, X, 1 - Y))
        end
    end)

    option.satval.InputEnded:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            editingsatval = false
        end
    end)

    option.visualize2 = library:Create("ImageLabel", {
        ZIndex = 3,
        Position = UDim2.new(1, -8, 0, 8),
        Size = UDim2.new(0, -80, 0, 80),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = currentColor,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = option.mainHolder
    })

    option.resetColor = library:Create("ImageLabel", {
        ZIndex = 3,
        Position = UDim2.new(1, -8, 0, 92),
        Size = UDim2.new(0, -80, 0, 18),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageTransparency = 1,
        ImageColor3 = Color3.fromRGB(20, 20, 20),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = option.mainHolder
    })

    option.resetText = library:Create("TextLabel", {
        ZIndex = 3,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "Reset",
        TextTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Parent = option.resetColor
    })

    option.resetColor.InputBegan:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 and not rainbowEnabled then
            previousColors = { originalColor }
            option:SetColor(originalColor)
        end
        if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
            tweenService:Create(option.resetColor, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(10, 10, 10) }):Play()
        end
    end)

    option.resetColor.InputEnded:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
            tweenService:Create(option.resetColor, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(20, 20, 20) }):Play()
        end
    end)

    option.undoColor = library:Create("ImageLabel", {
        ZIndex = 3,
        Position = UDim2.new(1, -8, 0, 112),
        Size = UDim2.new(0, -80, 0, 18),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageTransparency = 1,
        ImageColor3 = Color3.fromRGB(20, 20, 20),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = option.mainHolder
    })

    option.undoText = library:Create("TextLabel", {
        ZIndex = 3,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "Undo",
        TextTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Parent = option.undoColor
    })

    option.undoColor.InputBegan:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 and not rainbowEnabled then
            local Num = #previousColors == 1 and 0 or 1
            option:SetColor(previousColors[#previousColors - Num])
            if #previousColors ~= 1 then
                table.remove(previousColors, #previousColors)
            end
        end
        if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
            tweenService:Create(option.undoColor, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(10, 10, 10) }):Play()
        end
    end)

    option.undoColor.InputEnded:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
            tweenService:Create(option.undoColor, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(20, 20, 20) }):Play()
        end
    end)

    option.setColor = library:Create("ImageLabel", {
        ZIndex = 3,
        Position = UDim2.new(1, -8, 0, 132),
        Size = UDim2.new(0, -80, 0, 18),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageTransparency = 1,
        ImageColor3 = Color3.fromRGB(20, 20, 20),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = option.mainHolder
    })

    option.setText = library:Create("TextLabel", {
        ZIndex = 3,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "Set",
        TextTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Parent = option.setColor
    })

    option.setColor.InputBegan:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 and not rainbowEnabled then
            table.insert(previousColors, currentColor)
            option:SetColor(currentColor)
        end
        if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
            tweenService:Create(option.setColor, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(10, 10, 10) }):Play()
        end
    end)

    option.setColor.InputEnded:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
            tweenService:Create(option.setColor, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(20, 20, 20) }):Play()
        end
    end)

    option.rainbow = library:Create("ImageLabel", {
        ZIndex = 3,
        Position = UDim2.new(1, -8, 0, 152),
        Size = UDim2.new(0, -80, 0, 18),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageTransparency = 1,
        ImageColor3 = Color3.fromRGB(20, 20, 20),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = option.mainHolder
    })

    option.rainbowText = library:Create("TextLabel", {
        ZIndex = 3,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "Rainbow",
        TextTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 15,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Parent = option.rainbow
    })

    option.rainbow.InputBegan:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            rainbowEnabled = not rainbowEnabled
            if rainbowEnabled then
                rainbowLoop = runService.Heartbeat:connect(function()
                    option:SetColor(chromaColor)
                    option.rainbowText.TextColor3 = chromaColor
                end)
            else
                rainbowLoop:Disconnect()
                option:SetColor(previousColors[#previousColors])
                option.rainbowText.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
        if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
            tweenService:Create(option.rainbow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(10, 10, 10) }):Play()
        end
    end)

    option.rainbow.InputEnded:connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseMovement and not dragging then
            tweenService:Create(option.rainbow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { ImageColor3 = Color3.fromRGB(20, 20, 20) }):Play()
        end
    end)

    return option
end

local function createColor(option, parent, holder)
    option.main = library:Create("TextLabel", {
        LayoutOrder = option.position,
        Size = UDim2.new(1, 0, 0, 31),
        BackgroundTransparency = 1,
        Text = " " .. option.text,
        TextSize = 17,
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = parent.content
    })

    local colorBoxOutline = library:Create("ImageLabel", {
        Position = UDim2.new(1, -6, 0, 4),
        Size = UDim2.new(-1, 10, 1, -10),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = Color3.fromRGB(100, 100, 100),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = option.main
    })

    option.visualize = library:Create("ImageLabel", {
        Position = UDim2.new(0, 2, 0, 2),
        Size = UDim2.new(1, -4, 1, -4),
        BackgroundTransparency = 1,
        Image = "rbxassetid://3570695787",
        ImageColor3 = option.color,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(100, 100, 100, 100),
        SliceScale = 0.02,
        Parent = colorBoxOutline
    })

    local inContact
    option.main.InputBegan:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not option.mainHolder then createColorPickerWindow(option) end
            if library.activePopup then
                library.activePopup:Close()
            end
            local position = option.main.AbsolutePosition
            option.mainHolder.Position = UDim2.new(0, position.X - 5, 0, position.Y - 10)
            option.open = true
            option.mainHolder.Visible = true
            library.activePopup = option
            tweenService:Create(option.mainHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { ImageTransparency = 0, Position = UDim2.new(0, position.X - 5, 0, position.Y - 4) }):Play()
            tweenService:Create(option.mainHolder,
                TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.1),
                { Position = UDim2.new(0, position.X - 5, 0, position.Y + 1) }):Play()
            tweenService:Create(option.satval, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { BackgroundTransparency = 0 }):Play()
            for _, object in next, option.mainHolder:GetDescendants() do
                if object:IsA "TextLabel" then
                    tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { TextTransparency = 0 }):Play()
                elseif object:IsA "ImageLabel" then
                    tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { ImageTransparency = 0 }):Play()
                elseif object:IsA "Frame" then
                    tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { BackgroundTransparency = 0 }):Play()
                end
            end
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            if not option.open then
                tweenService:Create(colorBoxOutline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(140, 140, 140) }):Play()
            end
        end
    end)

    option.main.InputEnded:connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            inContact = true
            if not option.open then
                tweenService:Create(colorBoxOutline, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageColor3 = Color3.fromRGB(100, 100, 100) }):Play()
            end
        end
    end)

    function option:SetColor(newColor)
        if self.mainHolder then
            self:updateVisuals(newColor)
        end
        self.visualize.ImageColor3 = newColor
        library.flags[self.flag] = newColor
        self.color = newColor
        self.callback(newColor)
    end

    function option:Close()
        library.activePopup = nil
        self.open = false
        local position = self.main.AbsolutePosition
        tweenService:Create(self.mainHolder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { ImageTransparency = 1, Position = UDim2.new(0, position.X - 5, 0, position.Y - 10) }):Play()
        tweenService:Create(self.satval, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }):Play()
        for _, object in next, self.mainHolder:GetDescendants() do
            if object:IsA "TextLabel" then
                tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { TextTransparency = 1 }):Play()
            elseif object:IsA "ImageLabel" then
                tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { ImageTransparency = 1 }):Play()
            elseif object:IsA "Frame" then
                tweenService:Create(object, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 1 }):Play()
            end
        end
        delay(0.3, function()
            if not self.open then
                self.mainHolder.Visible = false
            end
        end)
    end
end

local function createDivider(option, parent, holder)
    option.main = library:Create('Frame', {
        LayoutOrder = option.position,
        BackgroundTransparency = 1,

        Size = UDim2.new(1, 0, 0, 6),
        Parent = parent.content,
    })

    option.divider = library:Create('Frame', {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),

        BorderSizePixel = 0,
        BorderColor3 = Color3.fromRGB(50, 50, 50),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),

        Size = UDim2.new(1, -10, 0, 2),
        Parent = option.main,
    })
end

local function loadOptions(option, holder)
    for _, newOption in next, option.options do
        if newOption.type == "label" then
            createLabel(newOption, option)
        elseif newOption.type == "toggle" then
            createToggle(newOption, option)
        elseif newOption.type == "button" then
            createButton(newOption, option)
        elseif newOption.type == "list" then
            createList(newOption, option, holder)
        elseif newOption.type == "box" then
            createBox(newOption, option)
        elseif newOption.type == "bind" then
            createBind(newOption, option)
        elseif newOption.type == "slider" then
            createSlider(newOption, option)
        elseif newOption.type == "color" then
            createColor(newOption, option, holder)
        elseif newOption.type == 'divider' then
            createDivider(newOption, option, holder)
        elseif newOption.type == "folder" then
            newOption:init()
        end
    end
end

local function getFnctions(parent)
    function parent:AddLabel(option)
        option = typeof(option) == "table" and option or {}
        option.text = tostring(option.text)
        option.type = "label"
        option.position = #self.options
        table.insert(self.options, option)

        return option
    end

    function parent:AddDivider(option)
        option = type(option) == 'table' and option or {}
        option.type = 'divider'
        option.position = #self.options
        table.insert(self.options, option)

        return option
    end

    function parent:AddToggle(option)
        option = typeof(option) == "table" and option or {}
        option.text = tostring(option.text)
        option.state = typeof(option.state) == "boolean" and option.state or false
        option.callback = typeof(option.callback) == "function" and option.callback or function() end
        option.type = "toggle"
        option.position = #self.options
        option.flag = option.flag or option.text
        library.flags[option.flag] = option.state
        library.options[option.flag] = option
        table.insert(self.options, option)

        return option
    end

    function parent:AddButton(option)
        option = typeof(option) == "table" and option or {}
        option.text = tostring(option.text)
        option.callback = typeof(option.callback) == "function" and option.callback or function() end
        option.type = "button"
        option.position = #self.options
        option.flag = option.flag or option.text
        table.insert(self.options, option)

        return option
    end

    function parent:AddBind(option)
        option = typeof(option) == "table" and option or {}
        option.text = tostring(option.text)
        option.key = (option.key and option.key.Name) or option.key or "F"
        option.hold = typeof(option.hold) == "boolean" and option.hold or false
        option.callback = typeof(option.callback) == "function" and option.callback or function() end
        option.type = "bind"
        option.position = #self.options
        option.flag = option.flag or option.text
        library.flags[option.flag] = option.key
        library.options[option.flag] = option
        table.insert(self.options, option)

        return option
    end

    function parent:AddSlider(option)
        option = typeof(option) == "table" and option or {}
        option.text = tostring(option.text)
        option.min = typeof(option.min) == "number" and option.min or 0
        option.max = typeof(option.max) == "number" and option.max or 0
        option.dual = typeof(option.dual) == "boolean" and option.dual or false
        option.value = math.clamp(typeof(option.value) == "number" and option.value or option.min, option.min, option
        .max)
        option.value2 = typeof(option.value2) == "number" and option.value2 or option.max
        option.callback = typeof(option.callback) == "function" and option.callback or function() end
        option.float = typeof(option.value) == "number" and option.float or 1
        option.type = "slider"
        option.position = #self.options
        option.flag = option.flag or option.text
        library.flags[option.flag] = option.value
        library.options[option.flag] = option
        table.insert(self.options, option)

        if type(option.float) == 'number' then
            local _ = '' .. option.float;
            local num = select(2, _:gsub('%d', function(c) return c end))

            option.places = math.max(1, num - 1)
            -- :)
        else
            option.places = 1;
        end

        return option
    end

    function parent:AddList(option)
        option = typeof(option) == "table" and option or {}
        option.text = tostring(option.text)
        option.values = typeof(option.values) == "table" and option.values or {}
        option.value = tostring(option.value or option.values[1] or "")
        option.callback = typeof(option.callback) == "function" and option.callback or function() end
        option.open = false
        option.type = "list"
        option.position = #self.options
        option.flag = option.flag or option.text
        library.flags[option.flag] = option.value
        library.options[option.flag] = option
        table.insert(self.options, option)

        return option
    end

    function parent:AddBox(option)
        option = typeof(option) == "table" and option or {}
        option.text = tostring(option.text)
        option.value = tostring(option.value or "")
        option.callback = typeof(option.callback) == "function" and option.callback or function() end
        option.type = "box"
        option.position = #self.options
        option.flag = option.flag or option.text
        library.flags[option.flag] = option.value
        library.options[option.flag] = option
        table.insert(self.options, option)

        return option
    end

    function parent:AddColor(option)
        option = typeof(option) == "table" and option or {}
        option.text = tostring(option.text)
        option.color = typeof(option.color) == "table" and
        Color3.new(tonumber(option.color[1]), tonumber(option.color[2]), tonumber(option.color[3])) or option.color or
        Color3.new(255, 255, 255)
        option.callback = typeof(option.callback) == "function" and option.callback or function() end
        option.open = false
        option.type = "color"
        option.position = #self.options
        option.flag = option.flag or option.text
        library.flags[option.flag] = option.color
        library.options[option.flag] = option
        table.insert(self.options, option)

        return option
    end

    function parent:AddFolder(title)
        local option = {}
        option.title = tostring(title)
        option.options = {}
        option.open = false
        option.type = "folder"
        option.position = #self.options
        table.insert(self.options, option)

        getFnctions(option)

        function option:init()
            createOptionHolder(self.title, parent.content, self, true)
            loadOptions(self, parent)
        end

        return option
    end
end

function library:CreateWindow(title, position)
    local window = { title = tostring(title), options = {}, open = true, canInit = true, init = false, position = #self
    .windows }
    if typeof(position) == "UDim2" then
        window.windowPosition = position
    end
    getFnctions(window)

    table.insert(library.windows, window)

    return window
end

local UIToggle
local UnlockMouse

local function collectFadeTargets(root)
    local targets = {}

    local function add(object)
        local props = {}
        local hidden = {}

        if object:IsA("GuiObject") then
            props.BackgroundTransparency = object.BackgroundTransparency
            hidden.BackgroundTransparency = 1
        end
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
            props.TextTransparency = object.TextTransparency
            hidden.TextTransparency = 1
        end
        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            props.ImageTransparency = object.ImageTransparency
            hidden.ImageTransparency = 1
        end
        if object:IsA("ScrollingFrame") then
            props.ScrollBarImageTransparency = object.ScrollBarImageTransparency
            hidden.ScrollBarImageTransparency = 1
        end

        if next(props) then
            table.insert(targets, {
                object = object,
                props = props,
                hidden = hidden
            })
        end
    end

    add(root)
    for _, object in next, root:GetDescendants() do
        add(object)
    end

    return targets
end

local function setFadeTargetsHidden(targets)
    for _, item in next, targets do
        pcall(function()
            for property, value in next, item.hidden do
                item.object[property] = value
            end
        end)
    end
end

local function tweenFadeTargets(targets, hidden, duration)
    local info = TweenInfo.new(duration or 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    for _, item in next, targets do
        pcall(function()
            tweenService:Create(item.object, info, hidden and item.hidden or item.props):Play()
        end)
    end
end

local function ensureWindowScale(window)
    if not window.main then return end
    return window.main:FindFirstChild("LevisIntroScale") or library:Create("UIScale", {
        Name = "LevisIntroScale",
        Parent = window.main
    })
end

local function playIntro(root, windows)
    local fadeTargets = collectFadeTargets(root)

    for _, item in next, fadeTargets do
        local object = item.object
        if item.props.BackgroundTransparency ~= nil then
            object.BackgroundTransparency = 1
        end
        if item.props.TextTransparency ~= nil then
            object.TextTransparency = 1
        end
        if item.props.ImageTransparency ~= nil then
            object.ImageTransparency = 1
        end
        if item.props.ScrollBarImageTransparency ~= nil then
            object.ScrollBarImageTransparency = 1
        end
    end

    for index, window in next, windows do
        if window.main then
            local position = window.main.Position
            local size = window.main.Size
            local scale = ensureWindowScale(window)
            local order = window.position or index
            local delayTime = math.min(order * 0.035, 0.18)
            local height = math.max(window.main.AbsoluteSize.Y, size.Y.Offset, 40)
            local collapsedHeight = 6
            local startOffset = math.floor((height - collapsedHeight) * 0.5)
            local originalClips = window.main.ClipsDescendants

            scale.Scale = 1
            window.main.ClipsDescendants = true
            window.main.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, collapsedHeight)
            window.main.Position = offsetUDim2(position, 0, startOffset)
            window.main.Rotation = 0

            tweenService:Create(window.main, TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delayTime), {
                Position = position,
                Size = size
            }):Play()

            delay(0.4 + delayTime, function()
                if window.main and window.main.Parent then
                    window.main.Position = position
                    window.main.Size = size
                    window.main.ClipsDescendants = originalClips
                end
            end)
        end
    end

    for _, item in next, fadeTargets do
        tweenService:Create(item.object, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), item.props):Play()
    end
end

function library:Init()
    self.base = self.base or self:Create("ScreenGui")
    if (syn and syn.protect_gui) then
        syn.protect_gui(self.base)
        self.base.Parent = game:GetService "CoreGui"
    elseif type(get_hidden_gui) == 'function' then
        self.base.Parent = get_hidden_gui()
    elseif type(gethui) == 'function' then
        self.base.Parent = gethui()
    else
        self.base.Name = tostring(math.random())
        self.base.Parent = game:GetService "CoreGui"
    end


    self.cursor = self.cursor or self:Create("Frame", {
        ZIndex = 100,
        AnchorPoint = Vector2.new(0, 0),
        Size = UDim2.new(0, 5, 0, 5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Parent = self.base
    })

    self.cursorImage = self.cursorImage or self:Create("ImageLabel", {
        ZIndex = 101,
        AnchorPoint = Vector2.new(0, 0),
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundTransparency = 1,
        Image = self.customCursorId,
        Visible = false,
        Parent = self.base
    })
    self:SetCustomCursorEnabled(self.customCursorEnabled)

    for _, window in next, self.windows do
        if window.canInit and not window.init then
            window.init = true
            createOptionHolder(window.title, self.base, window)
            loadOptions(window)
        end
    end

    playIntro(self.base, self.windows)

    delay(0.15, function()
        self:LoadDefaultTheme()
        self:LoadAutoloadConfig()
    end)
end

function library:Close()
    if self.isAnimating or not self.base then return false end
    self.isAnimating = true
    self.open = not self.open

    if self.activePopup then
        self.activePopup:Close()
    end

    local duration = 0.36
    local slideDistance = 54
    local maxStagger = 0.1

    if self.open then
        self:SetCustomCursorEnabled(self.customCursorEnabled)

        local targets = self._fadeTargets or collectFadeTargets(self.base)
        setFadeTargetsHidden(targets)

        for index, window in next, self.windows do
            if window.main then
                local position = window._visiblePosition or window.main.Position
                local scale = ensureWindowScale(window)
                local order = window.position or index
                local stagger = math.min(order * 0.018, maxStagger)

                window.main.Visible = true
                window.main.Position = offsetUDim2(position, 0, -slideDistance)
                window.main.Rotation = 0
                scale.Scale = 0.985

                tweenService:Create(window.main, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, stagger), {
                    Position = position
                }):Play()
                tweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, stagger), {
                    Scale = 1
                }):Play()
            end
        end

        tweenFadeTargets(targets, false, 0.24)

        delay(duration + maxStagger, function()
            self:ApplyTheme()
            self.isAnimating = false
        end)
    else
        if self.cursor then
            self.cursor.Visible = false
        end
        if self.cursorImage then
            self.cursorImage.Visible = false
        end
        pcall(function()
            inputService.MouseIconEnabled = true
        end)

        local targets = collectFadeTargets(self.base)
        self._fadeTargets = targets

        for index, window in next, self.windows do
            if window.main then
                local scale = ensureWindowScale(window)
                local order = window.position or index
                local stagger = math.min(order * 0.014, maxStagger)

                window._visiblePosition = window.main.Position
                tweenService:Create(window.main, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, stagger), {
                    Position = offsetUDim2(window.main.Position, 0, -slideDistance)
                }):Play()
                tweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, stagger), {
                    Scale = 0.985
                }):Play()
            end
        end

        delay(0.04, function()
            tweenFadeTargets(targets, true, 0.22)
        end)

        delay(duration + maxStagger, function()
            for _, window in next, self.windows do
                if window.main and not self.open then
                    window.main.Visible = false
                end
            end
            self.isAnimating = false
        end)
    end

    return true
end

function library:Destroy()
    self.open = false
    self.isAnimating = false
    dragging = false
    dragObject = nil
    dragTarget = nil
    dragStart = nil
    startPos = nil
    dragLastMouseX = nil
    dragVelocityX = 0
    dragRotationVelocity = 0
    dragOriginalClips = nil

    if self.activePopup then
        pcall(function()
            self.activePopup:Close()
        end)
        self.activePopup = nil
    end

    if self.base then
        pcall(function()
            self.base:ClearAllChildren()
        end)
        pcall(function()
            self.base:Destroy()
        end)
    end

    self.base = nil
    self.cursor = nil
    self.cursorImage = nil
    self._fadeTargets = nil
    self.themeObjects = {}
    self.originalFonts = {}

    pcall(function()
        inputService.MouseIconEnabled = true
    end)

    for _, window in next, self.windows do
        window.main = nil
        window.content = nil
        window.init = false
    end
end

function library:Unload()
    if self.isAnimating or not self.base then return false end
    self.isAnimating = true
    self.open = false

    if self.cursor then
        self.cursor.Visible = false
    end
    if self.cursorImage then
        self.cursorImage.Visible = false
    end
    pcall(function()
        inputService.MouseIconEnabled = true
    end)

    if self.activePopup then
        pcall(function()
            self.activePopup:Close()
        end)
        self.activePopup = nil
    end

    local duration = 0.72
    local targets = collectFadeTargets(self.base)

    local flash = self:Create("Frame", {
        ZIndex = 999,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = getAccent(),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.base
    })
    tweenService:Create(flash, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.72
    }):Play()
    delay(0.08, function()
        if flash and flash.Parent then
            tweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                BackgroundTransparency = 1
            }):Play()
        end
    end)

    for index, window in next, self.windows do
        if window.main then
            local scale = ensureWindowScale(window)
            local order = window.position or index
            local direction = order % 2 == 0 and -1 or 1
            local stagger = math.min(order * 0.025, 0.14)
            local startPosition = window.main.Position

            window.main.ClipsDescendants = false
            tweenService:Create(window.main, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, stagger), {
                Position = offsetUDim2(startPosition, direction * 10, -16),
                Rotation = direction * -7
            }):Play()
            tweenService:Create(scale, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, stagger), {
                Scale = 1.08
            }):Play()
            delay(0.11 + stagger, function()
                if window.main and window.main.Parent then
                    tweenService:Create(window.main, TweenInfo.new(0.46, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                        Position = offsetUDim2(startPosition, direction * 180, 128),
                        Rotation = direction * 26
                    }):Play()
                    tweenService:Create(scale, TweenInfo.new(0.46, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                        Scale = 0.48
                    }):Play()
                end
            end)
        end
    end

    delay(0.16, function()
        tweenFadeTargets(targets, true, 0.38)
    end)

    delay(duration, function()
        self:Destroy()
    end)

    return true
end

inputService.InputBegan:connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if library.activePopup then
            if input.Position.X < library.activePopup.mainHolder.AbsolutePosition.X or input.Position.Y < library.activePopup.mainHolder.AbsolutePosition.Y then
                library.activePopup:Close()
            end
        end
        if library.activePopup then
            if input.Position.X > library.activePopup.mainHolder.AbsolutePosition.X + library.activePopup.mainHolder.AbsoluteSize.X or input.Position.Y > library.activePopup.mainHolder.AbsolutePosition.Y + library.activePopup.mainHolder.AbsoluteSize.Y then
                library.activePopup:Close()
            end
        end
    end
end)

inputService.InputEnded:connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

inputService.InputChanged:connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouse = inputService:GetMouseLocation() + Vector2.new(0, -36)
        if library.cursor then
            library.cursor.Position = UDim2.new(0, mouse.X - 2, 0, mouse.Y - 2)
        end
        if library.cursorImage then
            library.cursorImage.Position = UDim2.new(0, mouse.X - 14, 0, mouse.Y - 14)
        end
    end
end)

runService.RenderStepped:connect(function(dt)
    if not dragObject then return end

    if dragging then
        updateDragTarget(dt)
    end

    if dragTarget then
        dragObject.Position = dragObject.Position:Lerp(dragTarget, DRAG_LERP_SPEED)
    end

    local targetRotation = dragging and math.clamp((dragVelocityX or 0) * DRAG_TILT_MULTIPLIER, -MAX_DRAG_ROTATION, MAX_DRAG_ROTATION) or 0
    local stiffness = library.STIFFNESS or STIFFNESS
    local damping = library.DAMPING or DAMPING
    local displacement = dragObject.Rotation - targetRotation
    local force = (-stiffness * displacement) - (damping * (dragRotationVelocity or 0))

    dragRotationVelocity = (dragRotationVelocity or 0) + (force * dt)
    dragObject.Rotation = dragObject.Rotation + (dragRotationVelocity * dt)

    if not dragging and math.abs(dragObject.Rotation) < 0.05 and math.abs(dragRotationVelocity or 0) < 0.05 then
        dragObject.Rotation = 0
        if dragOriginalClips ~= nil then
            dragObject.ClipsDescendants = dragOriginalClips
        end
        dragObject = nil
        dragTarget = nil
        dragStart = nil
        startPos = nil
        dragLastMouseX = nil
        dragVelocityX = 0
        dragRotationVelocity = 0
        dragOriginalClips = nil
    end
end)

return library
