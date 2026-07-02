-- ============================================================
--  Levis Hub - Universal UI Test
--  Clean manager demo with separate windows.
-- ============================================================

local UILIB_URL = "https://raw.githubusercontent.com/Ic0u/levishub/main/libraries/UILibrary.lua"
local Library = loadstring(game:HttpGet(UILIB_URL, true))()

local MainWindow = Library:CreateWindow("Levis Hub", UDim2.new(0, 20, 0, 20))
local ThemeEditor = Library:CreateWindow("Theme Editor", UDim2.new(0, 270, 0, 20))
local ThemeVisuals = Library:CreateWindow("Theme Visuals", UDim2.new(0, 520, 0, 20))
local ThemeControls = Library:CreateWindow("Theme Controls", UDim2.new(0, 770, 0, 20))
local ThemeFiles = Library:CreateWindow("Theme Files", UDim2.new(0, 1020, 0, 20))
local ConfigEditor = Library:CreateWindow("Config Editor", UDim2.new(0, 270, 0, 500))
local ConfigFiles = Library:CreateWindow("Config Files", UDim2.new(0, 520, 0, 500))
local CursorWindow = Library:CreateWindow("Cursor", UDim2.new(0, 20, 0, 360))

local statusLabel = MainWindow:AddLabel({ text = "Status: ready" })
MainWindow:AddDivider()
MainWindow:AddLabel({ text = "RightShift toggles the UI" })

local function cleanName(value, fallback)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" or value == "--" then
        return fallback or "default"
    end
    return value
end

local function selectedName(selected, typed, fallback)
    selected = cleanName(selected, "")
    if selected ~= "" then
        return selected
    end
    return cleanName(typed, fallback)
end

local function setStatus(ok, success, failure)
    statusLabel:Set(ok and ("Status: " .. success) or ("Status: " .. tostring(failure)))
end

local function selectPreferred(list, values, preferred)
    preferred = cleanName(preferred, "")
    if preferred ~= "" and table.find(values, preferred) then
        list:SetValue(preferred)
        return preferred
    end
    if values[1] then
        list:SetValue(values[1])
        return values[1]
    end
    list:SetValue("--")
    return "--"
end

local refreshThemeList = function() end
local refreshConfigList = function() end
local syncThemeControls = function() end

local function pathFlag(path)
    return "theme_" .. tostring(path):gsub("[^%w]+", "_"):lower()
end

local function readPath(root, path, fallback)
    local current = root
    for key in tostring(path or ""):gmatch("[^%.]+") do
        if type(current) ~= "table" or current[key] == nil then
            return fallback
        end
        current = current[key]
    end
    return current == nil and fallback or current
end

local function writePath(root, path, value)
    local current = root
    local keys = {}
    for key in tostring(path or ""):gmatch("[^%.]+") do
        table.insert(keys, key)
    end
    for index = 1, #keys - 1 do
        current[keys[index]] = current[keys[index]] or {}
        current = current[keys[index]]
    end
    current[keys[#keys]] = value
end

local function setThemePath(path, value)
    local patch = {}
    writePath(patch, path, value)
    Library:SetTheme(patch)
end

MainWindow:AddToggle({
    text = "Toggle",
    flag = "demo_toggle",
    state = false,
    callback = function(enabled)
        statusLabel:Set("Status: toggle " .. (enabled and "on" or "off"))
    end
})

MainWindow:AddSlider({
    text = "Slider",
    flag = "demo_slider",
    value = 50,
    min = 0,
    max = 100,
    float = 1,
    callback = function(value)
        print("[Levis Hub] Slider:", value)
    end
})

MainWindow:AddList({
    text = "Mode",
    flag = "demo_mode",
    value = "Default",
    values = { "Default", "Fast", "Clean" },
    callback = function(value)
        print("[Levis Hub] Mode:", value)
    end
})

MainWindow:AddBox({
    text = "Text",
    flag = "demo_text",
    value = "Levis",
    callback = function(value)
        print("[Levis Hub] Text:", value)
    end
})

MainWindow:AddColor({
    text = "Color",
    flag = "demo_color",
    color = Color3.fromRGB(0, 255, 111),
    callback = function(color)
        print("[Levis Hub] Color:", color)
    end
})

MainWindow:AddBind({
    text = "Toggle UI",
    flag = "toggle_ui",
    key = "RightShift",
    callback = function()
        Library:Close()
    end
})

MainWindow:AddButton({
    text = "Unload UI",
    callback = function()
        Library:Unload()
    end
})

local cursorId = ""

CursorWindow:AddBox({
    text = "Cursor id",
    flag = "custom_cursor_id",
    value = "",
    skipConfig = true,
    callback = function(value)
        cursorId = value
        if Library.customCursorEnabled then
            Library:SetCustomCursor(cursorId)
        end
    end
})

CursorWindow:AddToggle({
    text = "Custom cursor",
    flag = "custom_cursor",
    state = false,
    skipConfig = true,
    callback = function(enabled)
        if enabled then
            Library:SetCustomCursor(cursorId)
        end
        Library:SetCustomCursorEnabled(enabled)
        statusLabel:Set("Status: custom cursor " .. (enabled and "on" or "off"))
    end
})

CursorWindow:AddButton({
    text = "Apply cursor id",
    callback = function()
        local ok = Library:SetCustomCursor(cursorId)
        setStatus(ok, "cursor id applied", "cursor id missing")
    end
})

local themeName = "default"
local themeCreator = ""
local selectedTheme = "--"
local syncingTheme = false
local themeColorControls = {}
local themeToggleControls = {}
local themeBoxControls = {}

local function themeValue(path, fallback)
    return readPath(Library:GetTheme(), path, fallback)
end

local function themeStatus(message)
    if not syncingTheme then
        statusLabel:Set("Status: " .. message)
    end
end

local function addThemeColor(window, text, path)
    local control = window:AddColor({
        text = text,
        flag = pathFlag(path),
        color = themeValue(path, Color3.fromRGB(255, 255, 255)),
        skipConfig = true,
        callback = function(color)
            setThemePath(path, color)
            themeStatus("theme color updated")
        end
    })
    table.insert(themeColorControls, { path = path, control = control })
    return control
end

local function addThemeToggle(window, text, path)
    local control = window:AddToggle({
        text = text,
        flag = pathFlag(path),
        state = themeValue(path, false) == true,
        skipConfig = true,
        callback = function(enabled)
            setThemePath(path, enabled)
            themeStatus("theme toggle updated")
        end
    })
    table.insert(themeToggleControls, { path = path, control = control })
    return control
end

local function addThemeBox(window, text, path, fallback)
    local control = window:AddBox({
        text = text,
        flag = pathFlag(path),
        value = tostring(themeValue(path, fallback or "")),
        skipConfig = true,
        callback = function(value)
            setThemePath(path, tostring(value or ""))
            themeStatus("theme value updated")
        end
    })
    table.insert(themeBoxControls, { path = path, control = control, fallback = fallback or "" })
    return control
end

local themeColor = ThemeEditor:AddColor({
    text = "Accent",
    flag = "theme_accent",
    color = Library:GetTheme().Accent,
    skipConfig = true,
    callback = function(color)
        Library:SetTheme({ Accent = color })
        themeStatus("theme accent stored")
    end
})

local fontValues = {
    "Default",
    "Legacy",
    "Arial",
    "ArialBold",
    "SourceSans",
    "SourceSansLight",
    "SourceSansItalic",
    "SourceSansSemibold",
    "SourceSansBold",
    "Gotham",
    "GothamMedium",
    "GothamBold",
    "GothamBlack",
    "BuilderSans",
    "BuilderSansMedium",
    "BuilderSansBold",
    "BuilderSansExtraBold",
    "Arimo",
    "ArimoBold",
    "Code",
    "Roboto",
    "RobotoCondensed",
    "RobotoMono",
    "Ubuntu",
    "Bodoni",
    "Garamond",
    "Cartoon",
    "Arcade",
    "Fantasy",
    "Antique",
    "Highway",
    "SciFi",
    "AmaticSC",
    "Bangers",
    "Creepster",
    "DenkOne",
    "Fondamento",
    "FredokaOne",
    "GrenzeGotisch",
    "IndieFlower",
    "JosefinSans",
    "Jura",
    "Kalam",
    "LuckiestGuy",
    "Merriweather",
    "Michroma",
    "Nunito",
    "Oswald",
    "PatrickHand",
    "PermanentMarker",
    "Sarpanch",
    "SpecialElite",
    "TitilliumWeb"
}

local themeFont = ThemeEditor:AddList({
    text = "Font",
    flag = "ui_font",
    value = "Default",
    values = fontValues,
    skipConfig = true,
    callback = function(fontName)
        local ok = fontName == "Default" and Library:ResetFont() or Library:SetFont(fontName)
        if not syncingTheme then
            setStatus(ok, "font set to " .. tostring(fontName), "invalid font")
        end
    end
})

local themeNameBox = ThemeEditor:AddBox({
    text = "Theme name",
    flag = "theme_name",
    value = themeName,
    skipConfig = true,
    callback = function(value)
        themeName = cleanName(value, "default")
        Library:SetThemeInfo({ Name = themeName, Creator = themeCreator })
    end
})

local themeCreatorBox = ThemeEditor:AddBox({
    text = "Theme creator",
    flag = "theme_creator",
    value = themeCreator,
    skipConfig = true,
    callback = function(value)
        themeCreator = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        Library:SetThemeInfo({ Name = themeName, Creator = themeCreator })
    end
})

ThemeEditor:AddButton({
    text = "Create theme",
    callback = function()
        local ok, result = Library:SaveTheme(themeName, { Name = themeName, Creator = themeCreator })
        setStatus(ok, "theme created", result)
        refreshThemeList(themeName)
    end
})

ThemeEditor:AddButton({
    text = "Reset theme",
    callback = function()
        Library:ResetTheme()
        syncThemeControls()
        statusLabel:Set("Status: theme reset")
    end
})

ThemeVisuals:AddLabel({ text = "TopBar" })
addThemeToggle(ThemeVisuals, "Topbar gradient", "TopBar.Line.Gradient")
addThemeColor(ThemeVisuals, "Topbar main", "TopBar.Line.MainColor")
addThemeColor(ThemeVisuals, "Topbar second", "TopBar.Line.SecondColor")
addThemeColor(ThemeVisuals, "Topbar text", "TopBar.TextColor")
addThemeColor(ThemeVisuals, "Topbar open icon", "TopBar.OnOffColor.On")
addThemeColor(ThemeVisuals, "Topbar closed icon", "TopBar.OnOffColor.Off")
ThemeVisuals:AddDivider()
ThemeVisuals:AddLabel({ text = "Button" })
addThemeToggle(ThemeVisuals, "Button gradient", "Button.Color.Gradient")
addThemeColor(ThemeVisuals, "Button text", "Button.TextColor")
addThemeColor(ThemeVisuals, "Button main", "Button.Color.MainColor")
addThemeColor(ThemeVisuals, "Button second", "Button.Color.SecondColor")
addThemeColor(ThemeVisuals, "Button hover", "Button.Color.HoverColor")

ThemeControls:AddLabel({ text = "Text / Folder" })
addThemeColor(ThemeControls, "Text color", "Text.Color")
addThemeColor(ThemeControls, "Folder text", "Folder.TextColor")
addThemeColor(ThemeControls, "Folder open icon", "Folder.OnOff.On")
addThemeColor(ThemeControls, "Folder closed icon", "Folder.OnOff.Off")
addThemeBox(ThemeControls, "Folder icon id", "Folder.OnOff.Icon", "rbxassetid://4918373417")
ThemeControls:AddDivider()
ThemeControls:AddLabel({ text = "Toggle" })
addThemeBox(ThemeControls, "Toggle icon id", "Toggle.Icon", "rbxassetid://4919148038")
addThemeColor(ThemeControls, "Toggle stroke", "Toggle.StrokeColor")
addThemeColor(ThemeControls, "Toggle on", "Toggle.OnColor")
addThemeColor(ThemeControls, "Toggle off", "Toggle.OffColor")
addThemeColor(ThemeControls, "Toggle hover", "Toggle.HoverColor")
ThemeControls:AddDivider()
ThemeControls:AddLabel({ text = "Inputs" })
addThemeColor(ThemeControls, "Textbox main", "TextBox.MainColor")
addThemeColor(ThemeControls, "Slider background", "Slider.BackgroundColor")
addThemeColor(ThemeControls, "Slider fill", "Slider.Color2")
addThemeColor(ThemeControls, "Divider", "Divider.Color")

syncThemeControls = function()
    syncingTheme = true

    local theme = Library:GetTheme()
    local info = type(theme.Theme) == "table" and theme.Theme or {}
    themeName = cleanName(info.Name, themeName)
    themeCreator = tostring(info.Creator or "")

    themeNameBox:SetValue(themeName, true)
    themeCreatorBox:SetValue(themeCreator, true)
    themeColor:SetColor(theme.Accent)
    themeFont:SetValue(theme.Font or "Default")

    for _, item in next, themeColorControls do
        local color = readPath(theme, item.path)
        if typeof(color) == "Color3" then
            item.control:SetColor(color)
        end
    end

    for _, item in next, themeToggleControls do
        item.control:SetState(readPath(theme, item.path, false) == true)
    end

    for _, item in next, themeBoxControls do
        item.control:SetValue(tostring(readPath(theme, item.path, item.fallback)), true)
    end

    syncingTheme = false
end

local themeDefaultLabel = ThemeFiles:AddLabel({ text = "Default theme: none" })

local themeList = ThemeFiles:AddList({
    text = "Themes",
    flag = "theme_list",
    value = "--",
    values = { "--" },
    skipConfig = true,
    callback = function(value)
        selectedTheme = value
    end
})

local function updateThemeDefaultLabel()
    themeDefaultLabel:Set("Default theme: " .. (Library:GetDefaultTheme() or "none"))
end

refreshThemeList = function(preferred)
    if not themeList.ClearValues then return end

    local themes, err = Library:GetThemeList()
    themeList:ClearValues()

    if #themes == 0 then
        themeList:AddValue("--")
        selectedTheme = selectPreferred(themeList, {}, nil)
    else
        for _, name in next, themes do
            themeList:AddValue(name)
        end
        selectedTheme = selectPreferred(themeList, themes, preferred or selectedTheme)
    end

    updateThemeDefaultLabel()
    if err then
        statusLabel:Set("Status: " .. err)
    end
end

ThemeFiles:AddButton({
    text = "Load theme",
    callback = function()
        local name = selectedName(selectedTheme, themeName, "default")
        local ok, result = Library:LoadTheme(name)
        if ok then
            syncThemeControls()
        end
        setStatus(ok, "theme loaded", result)
    end
})

ThemeFiles:AddButton({
    text = "Overwrite theme",
    callback = function()
        local name = selectedName(selectedTheme, themeName, "default")
        local ok, result = Library:SaveTheme(name, { Name = themeName, Creator = themeCreator })
        setStatus(ok, "theme overwritten", result)
        refreshThemeList(name)
    end
})

ThemeFiles:AddButton({
    text = "Delete theme",
    callback = function()
        local name = selectedName(selectedTheme, themeName, "default")
        local ok, result = Library:DeleteTheme(name)
        setStatus(ok, "theme deleted", result)
        refreshThemeList()
    end
})

ThemeFiles:AddButton({
    text = "Refresh list",
    callback = function()
        refreshThemeList(selectedTheme)
        statusLabel:Set("Status: theme list refreshed")
    end
})

ThemeFiles:AddButton({
    text = "Set as default",
    callback = function()
        local ok, result = Library:SetDefaultTheme(selectedName(selectedTheme, themeName, "default"))
        setStatus(ok, "default theme set", result)
        updateThemeDefaultLabel()
    end
})

ThemeFiles:AddButton({
    text = "Reset default",
    callback = function()
        local ok, result = Library:ResetDefaultTheme()
        setStatus(ok, "default theme reset", result)
        updateThemeDefaultLabel()
    end
})

local configName = "default"
local selectedConfig = "--"

ConfigEditor:AddBox({
    text = "Config name",
    flag = "config_name",
    value = configName,
    skipConfig = true,
    callback = function(value)
        configName = cleanName(value, "default")
    end
})

ConfigEditor:AddButton({
    text = "Create config",
    callback = function()
        local ok, result = Library:SaveConfig(configName)
        setStatus(ok, "config created", result)
        refreshConfigList(configName)
    end
})

local autoloadLabel = ConfigFiles:AddLabel({ text = "Autoload config: none" })

local configList = ConfigFiles:AddList({
    text = "Configs",
    flag = "config_list",
    value = "--",
    values = { "--" },
    skipConfig = true,
    callback = function(value)
        selectedConfig = value
    end
})

local function updateAutoloadLabel()
    autoloadLabel:Set("Autoload config: " .. (Library:GetAutoloadConfig() or "none"))
end

refreshConfigList = function(preferred)
    if not configList.ClearValues then return end

    local configs, err = Library:GetConfigList()
    configList:ClearValues()

    if #configs == 0 then
        configList:AddValue("--")
        selectedConfig = selectPreferred(configList, {}, nil)
    else
        for _, name in next, configs do
            configList:AddValue(name)
        end
        selectedConfig = selectPreferred(configList, configs, preferred or selectedConfig)
    end

    updateAutoloadLabel()
    if err then
        statusLabel:Set("Status: " .. err)
    end
end

ConfigFiles:AddButton({
    text = "Load config",
    callback = function()
        local ok, result = Library:LoadConfig(selectedName(selectedConfig, configName, "default"))
        if ok then
            syncThemeControls()
            updateAutoloadLabel()
        end
        setStatus(ok, "config loaded", result)
    end
})

ConfigFiles:AddButton({
    text = "Overwrite config",
    callback = function()
        local name = selectedName(selectedConfig, configName, "default")
        local ok, result = Library:SaveConfig(name)
        setStatus(ok, "config overwritten", result)
        refreshConfigList(name)
    end
})

ConfigFiles:AddButton({
    text = "Delete config",
    callback = function()
        local name = selectedName(selectedConfig, configName, "default")
        local ok, result = Library:DeleteConfig(name)
        setStatus(ok, "config deleted", result)
        refreshConfigList()
    end
})

ConfigFiles:AddButton({
    text = "Refresh list",
    callback = function()
        refreshConfigList(selectedConfig)
        statusLabel:Set("Status: config list refreshed")
    end
})

ConfigFiles:AddButton({
    text = "Set as autoload",
    callback = function()
        local ok, result = Library:SetAutoloadConfig(selectedName(selectedConfig, configName, "default"))
        setStatus(ok, "autoload config set", result)
        updateAutoloadLabel()
    end
})

ConfigFiles:AddButton({
    text = "Reset autoload",
    callback = function()
        local ok, result = Library:ResetAutoloadConfig()
        setStatus(ok, "autoload config reset", result)
        updateAutoloadLabel()
    end
})

Library:Init()
refreshThemeList()
refreshConfigList()

delay(0.35, function()
    syncThemeControls()
    refreshThemeList(selectedTheme)
    refreshConfigList(selectedConfig)
end)
