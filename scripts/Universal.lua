-- ============================================================
--  Levis Hub - Universal UI Test
--  Clean manager demo with separate windows.
-- ============================================================

local UILIB_URL = "https://raw.githubusercontent.com/Ic0u/levishub/main/libraries/UILibrary.lua"
local Library = loadstring(game:HttpGet(UILIB_URL, true))()

local MainWindow = Library:CreateWindow("Levis Hub", UDim2.new(0, 20, 0, 20))
local ThemeEditor = Library:CreateWindow("Theme Editor", UDim2.new(0, 270, 0, 20))
local ThemeFiles = Library:CreateWindow("Theme Files", UDim2.new(0, 520, 0, 20))
local ConfigEditor = Library:CreateWindow("Config Editor", UDim2.new(0, 270, 0, 340))
local ConfigFiles = Library:CreateWindow("Config Files", UDim2.new(0, 520, 0, 340))
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
local selectedTheme = "--"

local themeColor = ThemeEditor:AddColor({
    text = "Accent",
    flag = "theme_accent",
    color = Library:GetTheme().Accent,
    skipConfig = true,
    callback = function(color)
        Library:SetTheme({ Accent = color })
        statusLabel:Set("Status: theme accent stored")
    end
})

local fontValues = {
    "Default",
    "Gotham",
    "GothamMedium",
    "GothamBold",
    "GothamBlack",
    "SourceSans",
    "SourceSansSemibold",
    "SourceSansBold",
    "SourceSansItalic",
    "Arial",
    "ArialBold",
    "ArialItalic",
    "ArialBoldItalic",
    "Code",
    "Roboto",
    "RobotoMono",
    "Ubuntu",
    "BuilderSans",
    "BuilderSansMedium",
    "BuilderSansBold",
    "BuilderSansExtraBold",
    "SciFi",
    "Arcade",
    "Fantasy",
    "Cartoon",
    "Bodoni",
    "Garamond",
    "Highway",
    "Legacy",
    "Antique"
}

local themeFont = ThemeEditor:AddList({
    text = "Font",
    flag = "ui_font",
    value = "Default",
    values = fontValues,
    skipConfig = true,
    callback = function(fontName)
        local ok = fontName == "Default" and Library:ResetFont() or Library:SetFont(fontName)
        setStatus(ok, "font set to " .. tostring(fontName), "invalid font")
    end
})

ThemeEditor:AddBox({
    text = "Theme name",
    flag = "theme_name",
    value = themeName,
    skipConfig = true,
    callback = function(value)
        themeName = cleanName(value, "default")
    end
})

ThemeEditor:AddButton({
    text = "Create theme",
    callback = function()
        local ok, result = Library:SaveTheme(themeName)
        setStatus(ok, "theme created", result)
        refreshThemeList(themeName)
    end
})

ThemeEditor:AddButton({
    text = "Reset theme",
    callback = function()
        Library:ResetTheme()
        themeColor:SetColor(Library:GetTheme().Accent)
        themeFont:SetValue("Default")
        statusLabel:Set("Status: theme reset")
    end
})

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
            themeColor:SetColor(Library:GetTheme().Accent)
            themeFont:SetValue(Library:GetTheme().Font or "Default")
        end
        setStatus(ok, "theme loaded", result)
    end
})

ThemeFiles:AddButton({
    text = "Overwrite theme",
    callback = function()
        local name = selectedName(selectedTheme, themeName, "default")
        local ok, result = Library:SaveTheme(name)
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
            themeColor:SetColor(Library:GetTheme().Accent)
            themeFont:SetValue(Library:GetTheme().Font or "Default")
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
    themeColor:SetColor(Library:GetTheme().Accent)
    themeFont:SetValue(Library:GetTheme().Font or "Default")
    refreshThemeList(selectedTheme)
    refreshConfigList(selectedConfig)
end)
