-- ============================================================
--  Levis Hub - Universal UI Test
--  Runs on unsupported games and documents the UI library.
-- ============================================================

local UILIB_URL = "https://raw.githubusercontent.com/Ic0u/levishub/main/libraries/UILibrary.lua"
local Library = loadstring(game:HttpGet(UILIB_URL, true))()

local Window = Library:CreateWindow("Levis Hub")
local Folder = Window:AddFolder("Elements")
local Runtime = Window:AddFolder("Runtime")
local Cursor = Window:AddFolder("Cursor")
local ThemeManager = Window:AddFolder("Theme Manager")
local Configuration = Window:AddFolder("Configuration")

Window:AddLabel({ text = "Universal UI test" })
Window:AddDivider()

local statusLabel = Window:AddLabel({ text = "Status: ready" })
Window:AddLabel({ text = "RightShift toggles the UI" })

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

local demoToggle = Window:AddToggle({
    text = "Toggle",
    flag = "demo_toggle",
    state = false,
    callback = function(enabled)
        statusLabel:Set("Status: toggle " .. (enabled and "on" or "off"))
        print("[Levis Hub] Toggle:", enabled)
    end
})

Window:AddButton({
    text = "Button",
    flag = "demo_button",
    callback = function()
        statusLabel:Set("Status: button pressed")
        print("[Levis Hub] Button pressed")
    end
})

local demoList = Folder:AddList({
    text = "List",
    flag = "demo_list",
    value = "Default",
    values = { "Default", "Fast", "Clean" },
    callback = function(value)
        print("[Levis Hub] List:", value)
    end
})

local demoBox = Folder:AddBox({
    text = "Box",
    flag = "demo_box",
    value = "Levis",
    callback = function(value, enterPressed)
        print("[Levis Hub] Box:", value, enterPressed)
    end
})

local demoSlider = Folder:AddSlider({
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

local demoColor = Folder:AddColor({
    text = "Color",
    flag = "demo_color",
    color = Color3.fromRGB(0, 255, 111),
    callback = function(color)
        print("[Levis Hub] Color:", color)
    end
})

local toggleBind = Folder:AddBind({
    text = "Toggle UI",
    flag = "toggle_ui",
    key = "RightShift",
    callback = function()
        Library:Close()
    end
})

local cursorId = ""

Cursor:AddBox({
    text = "Custom cursor id",
    flag = "custom_cursor_id",
    value = "",
    callback = function(value)
        cursorId = value
        if Library.customCursorEnabled then
            Library:SetCustomCursor(cursorId)
        end
    end
})

Cursor:AddToggle({
    text = "Custom cursor",
    flag = "custom_cursor",
    state = false,
    callback = function(enabled)
        if enabled then
            Library:SetCustomCursor(cursorId)
        end
        Library:SetCustomCursorEnabled(enabled)
        statusLabel:Set("Status: custom cursor " .. (enabled and "on" or "off"))
    end
})

Cursor:AddButton({
    text = "Apply cursor id",
    callback = function()
        local ok = Library:SetCustomCursor(cursorId)
        setStatus(ok, "cursor id applied", "cursor id missing")
    end
})

local themeName = "default"
local selectedTheme = "--"
local configName = "default"
local selectedConfig = "--"
local refreshThemeList = function() end
local refreshConfigList = function() end

local themeColor = ThemeManager:AddColor({
    text = "Accent",
    flag = "theme_accent",
    color = Library:GetTheme().Accent,
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

local themeFont = ThemeManager:AddList({
    text = "Font",
    flag = "ui_font",
    value = "Default",
    values = fontValues,
    callback = function(fontName)
        local ok = fontName == "Default" and Library:ResetFont() or Library:SetFont(fontName)
        setStatus(ok, "font set to " .. tostring(fontName), "invalid font")
    end
})

ThemeManager:AddBox({
    text = "Custom theme name",
    flag = "theme_name",
    value = themeName,
    callback = function(value)
        themeName = cleanName(value, "default")
    end
})

ThemeManager:AddButton({
    text = "Create theme",
    callback = function()
        local ok, result = Library:SaveTheme(themeName)
        setStatus(ok, "theme created", result)
        refreshThemeList()
    end
})

local themeDefaultLabel = ThemeManager:AddLabel({ text = "Current default theme: none" })

local themeList = ThemeManager:AddList({
    text = "Custom themes",
    flag = "theme_list",
    value = "--",
    values = { "--" },
    callback = function(value)
        selectedTheme = value
    end
})

local function updateThemeDefaultLabel()
    themeDefaultLabel:Set("Current default theme: " .. (Library:GetDefaultTheme() or "none"))
end

refreshThemeList = function()
    if not themeList.ClearValues then return end
    local themes, err = Library:GetThemeList()
    themeList:ClearValues()
    if #themes == 0 then
        themeList:AddValue("--")
        themeList:SetValue("--")
        selectedTheme = "--"
    else
        for _, name in next, themes do
            themeList:AddValue(name)
        end
        themeList:SetValue(themes[1])
        selectedTheme = themes[1]
    end
    updateThemeDefaultLabel()
    if err then
        statusLabel:Set("Status: " .. err)
    end
end

ThemeManager:AddButton({
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

ThemeManager:AddButton({
    text = "Overwrite theme",
    callback = function()
        local name = selectedName(selectedTheme, themeName, "default")
        local ok, result = Library:SaveTheme(name)
        setStatus(ok, "theme overwritten", result)
        refreshThemeList()
    end
})

ThemeManager:AddButton({
    text = "Delete theme",
    callback = function()
        local ok, result = Library:DeleteTheme(selectedName(selectedTheme, themeName, "default"))
        setStatus(ok, "theme deleted", result)
        refreshThemeList()
    end
})

ThemeManager:AddButton({
    text = "Refresh list",
    callback = function()
        refreshThemeList()
        statusLabel:Set("Status: theme list refreshed")
    end
})

ThemeManager:AddButton({
    text = "Set as default",
    callback = function()
        local ok, result = Library:SetDefaultTheme(selectedName(selectedTheme, themeName, "default"))
        setStatus(ok, "default theme set", result)
        updateThemeDefaultLabel()
    end
})

ThemeManager:AddButton({
    text = "Reset default",
    callback = function()
        local ok, result = Library:ResetDefaultTheme()
        setStatus(ok, "default theme reset", result)
        updateThemeDefaultLabel()
    end
})

ThemeManager:AddButton({
    text = "Reset theme",
    callback = function()
        Library:ResetTheme()
        themeColor:SetColor(Library:GetTheme().Accent)
        themeFont:SetValue("Default")
        statusLabel:Set("Status: theme reset")
    end
})

Runtime:AddButton({
    text = "Set Toggle On",
    callback = function()
        demoToggle:SetState(true)
    end
})

Runtime:AddButton({
    text = "Set Slider 75",
    callback = function()
        demoSlider:SetValue(75)
    end
})

Runtime:AddButton({
    text = "Set Box Text",
    callback = function()
        demoBox:SetValue("Updated", true)
    end
})

Runtime:AddButton({
    text = "Set Color Green",
    callback = function()
        demoColor:SetColor(Color3.fromRGB(0, 255, 111))
    end
})

Runtime:AddButton({
    text = "Add List Value",
    callback = function()
        if not table.find(demoList.values, "Added") then
            demoList:AddValue("Added")
        end
        demoList:SetValue("Added")
    end
})

Runtime:AddButton({
    text = "Remove List Value",
    callback = function()
        demoList:RemoveValue("Added")
    end
})

Runtime:AddButton({
    text = "Rename Window",
    callback = function()
        Window:SetTitle("Levis Hub - Testing")
    end
})

Runtime:AddButton({
    text = "Set Bind E",
    callback = function()
        toggleBind:SetKey("E")
        statusLabel:Set("Status: UI toggle bind set to E")
    end
})

Configuration:AddBox({
    text = "Config name",
    flag = "config_name",
    value = configName,
    callback = function(value)
        configName = cleanName(value, "default")
    end
})

Configuration:AddButton({
    text = "Create config",
    callback = function()
        local ok, result = Library:SaveConfig(configName)
        setStatus(ok, "config created", result)
        refreshConfigList()
    end
})

local autoloadLabel = Configuration:AddLabel({ text = "Current autoload config: none" })

local configList = Configuration:AddList({
    text = "Config list",
    flag = "config_list",
    value = "--",
    values = { "--" },
    callback = function(value)
        selectedConfig = value
    end
})

local function updateAutoloadLabel()
    autoloadLabel:Set("Current autoload config: " .. (Library:GetAutoloadConfig() or "none"))
end

refreshConfigList = function()
    if not configList.ClearValues then return end
    local configs, err = Library:GetConfigList()
    configList:ClearValues()
    if #configs == 0 then
        configList:AddValue("--")
        configList:SetValue("--")
        selectedConfig = "--"
    else
        for _, name in next, configs do
            configList:AddValue(name)
        end
        configList:SetValue(configs[1])
        selectedConfig = configs[1]
    end
    updateAutoloadLabel()
    if err then
        statusLabel:Set("Status: " .. err)
    end
end

Configuration:AddButton({
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

Configuration:AddButton({
    text = "Overwrite config",
    callback = function()
        local ok, result = Library:SaveConfig(selectedName(selectedConfig, configName, "default"))
        setStatus(ok, "config overwritten", result)
        refreshConfigList()
    end
})

Configuration:AddButton({
    text = "Delete config",
    callback = function()
        local ok, result = Library:DeleteConfig(selectedName(selectedConfig, configName, "default"))
        setStatus(ok, "config deleted", result)
        refreshConfigList()
    end
})

Configuration:AddButton({
    text = "Refresh list",
    callback = function()
        refreshConfigList()
        statusLabel:Set("Status: config list refreshed")
    end
})

Configuration:AddButton({
    text = "Set as autoload",
    callback = function()
        local ok, result = Library:SetAutoloadConfig(selectedName(selectedConfig, configName, "default"))
        setStatus(ok, "autoload config set", result)
        updateAutoloadLabel()
    end
})

Configuration:AddButton({
    text = "Reset autoload",
    callback = function()
        local ok, result = Library:ResetAutoloadConfig()
        setStatus(ok, "autoload config reset", result)
        updateAutoloadLabel()
    end
})

Configuration:AddButton({
    text = "Unload UI",
    callback = function()
        Library:Unload()
    end
})

Library:Init()
refreshThemeList()
refreshConfigList()
