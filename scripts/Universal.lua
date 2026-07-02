-- ============================================================
--  Levis Hub - Universal UI Test
--  Minimal demo plus one compact UI Settings manager.
-- ============================================================

local UILIB_URL = "https://raw.githubusercontent.com/Ic0u/levishub/main/libraries/UILibrary.lua"
local DISCORD_INVITE = "https://discord.gg/levishub"
local Library = loadstring(game:HttpGet(UILIB_URL, true))()

local MainWindow = Library:CreateWindow("Levis Hub", UDim2.new(0, 20, 0, 20))
local SettingsWindow = Library:CreateWindow("UI Settings", UDim2.new(0, 270, 0, 20))

local statusLabel = MainWindow:AddLabel({ text = "Status: ready" })
MainWindow:AddDivider()

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

local function copyToClipboard(text)
    if type(setclipboard) == "function" then
        local ok, err = pcall(function()
            setclipboard(text)
        end)
        return ok, ok and text or tostring(err)
    end

    if type(toclipboard) == "function" then
        local ok, err = pcall(function()
            toclipboard(text)
        end)
        return ok, ok and text or tostring(err)
    end

    return false, "clipboard API unavailable"
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

local function applyAccentColor(color)
    Library:SetTheme({
        Accent = color,
        TopBar = {
            Line = {
                SecondColor = color
            }
        },
        Toggle = {
            OnColor = color
        },
        Button = {
            Color = {
                SecondColor = color
            }
        },
        Slider = {
            Color2 = color
        }
    })
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

MainWindow:AddButton({
    text = "Notify",
    callback = function()
        Library:Notify({
            Title = "Levis Hub",
            Text = "Notification system ready",
            Duration = 4
        })
    end
})

local refreshThemeList = function() end
local refreshConfigList = function() end
local syncThemeControls = function() end

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

local function addThemeColor(folder, text, path)
    local control = folder:AddColor({
        text = text,
        flag = pathFlag(path),
        color = themeValue(path, Color3.fromRGB(255, 255, 255)),
        skipConfig = true,
        callback = function(color)
            if syncingTheme then return end
            setThemePath(path, color)
            themeStatus("theme color updated")
        end
    })
    table.insert(themeColorControls, { path = path, control = control })
    return control
end

local function addThemeToggle(folder, text, path)
    local control = folder:AddToggle({
        text = text,
        flag = pathFlag(path),
        state = themeValue(path, false) == true,
        skipConfig = true,
        callback = function(enabled)
            if syncingTheme then return end
            setThemePath(path, enabled)
            themeStatus("theme toggle updated")
        end
    })
    table.insert(themeToggleControls, { path = path, control = control })
    return control
end

local function addThemeBox(folder, text, path, fallback)
    local control = folder:AddBox({
        text = text,
        flag = pathFlag(path),
        value = tostring(themeValue(path, fallback or "")),
        skipConfig = true,
        callback = function(value)
            if syncingTheme then return end
            setThemePath(path, tostring(value or ""))
            themeStatus("theme value updated")
        end
    })
    table.insert(themeBoxControls, { path = path, control = control, fallback = fallback or "" })
    return control
end

local ThemeFolder = SettingsWindow:AddFolder("Themes")
local ConfigFolder = SettingsWindow:AddFolder("Configs")

local function currentDpiScaleText()
    return tostring(math.floor((Library:GetDPIScale() * 100) + 0.5)) .. "%"
end

local notificationSideList = SettingsWindow:AddList({
    text = "Notification Side",
    flag = "notification_side",
    value = Library:GetNotificationSide(),
    values = { "Right", "Left" },
    skipConfig = true,
    callback = function(value)
        Library:SetNotificationSide(value)
        statusLabel:Set("Status: notifications on " .. tostring(value):lower())
    end
})

local dpiScaleList = SettingsWindow:AddList({
    text = "DPI Scale",
    flag = "dpi_scale",
    value = currentDpiScaleText(),
    values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    skipConfig = true,
    callback = function(value)
        Library:SetDPIScale(value)
        statusLabel:Set("Status: dpi scale " .. tostring(value))
    end
})

local uiTransparencySlider = SettingsWindow:AddSlider({
    text = "UI Transparency (%)",
    flag = "ui_transparency",
    value = Library:GetUITransparency(),
    min = 0,
    max = 100,
    float = 1,
    skipConfig = true,
    callback = function(value)
        Library:SetUITransparency(value)
        statusLabel:Set("Status: ui transparency " .. tostring(value) .. "%")
    end
})

SettingsWindow:AddBind({
    text = "Panic Key",
    flag = "panic_key",
    key = "End",
    skipConfig = true,
    callback = function()
        Library:Destroy()
    end
})

SettingsWindow:AddBind({
    text = "UI Toggle",
    flag = "toggle_ui",
    key = "RightShift",
    skipConfig = true,
    callback = function()
        Library:Close()
    end
})

SettingsWindow:AddButton({
    text = "Save UI Layout",
    callback = function()
        local ok, result = Library:SaveGuiLayout()
        setStatus(ok, "ui layout saved", result)
    end
})

SettingsWindow:AddButton({
    text = "Load Saved UI Layout",
    callback = function()
        local ok, result = Library:LoadGuiLayout()
        setStatus(ok, "gui layout loaded", result)
    end
})

SettingsWindow:AddButton({
    text = "Reset UI Layout",
    callback = function()
        local ok, result = Library:ResetGuiLayout()
        setStatus(ok, "gui layout reset", result)
    end
})

SettingsWindow:AddButton({
    text = "Unload",
    callback = function()
        Library:Unload()
    end
})

SettingsWindow:AddButton({
    text = "Discord Invite",
    callback = function()
        local ok, result = copyToClipboard(DISCORD_INVITE)
        setStatus(ok, "discord invite copied", result)
    end
})

SettingsWindow:AddLabel({ text = "Updated v2.06.2026" })
SettingsWindow:AddLabel({ text = "Made by Marcus" })

local themeColor = ThemeFolder:AddColor({
    text = "Accent",
    flag = "theme_accent",
    color = Library:GetTheme().Accent,
    skipConfig = true,
    callback = function(color)
        if syncingTheme then return end
        applyAccentColor(color)
        themeStatus("accent updated")
        syncThemeControls()
    end
})

local function hasFont(fontName)
    local ok, enumFont = pcall(function()
        return Enum.Font[fontName]
    end)
    return ok and typeof(enumFont) == "EnumItem" and enumFont.EnumType == Enum.Font
end

local function addFontOption(values, fontName)
    if not table.find(values, fontName) then
        table.insert(values, fontName)
    end
end

local fontValues = { "Default" }
local fontCandidates = {
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
    "Inter",
    "Poppins",
    "Arimo",
    "ArimoBold",
    "Code",
    "Monospace",
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

for _, fontName in next, fontCandidates do
    if fontName == "Monospace" then
        if hasFont("RobotoMono") or hasFont("Code") then
            addFontOption(fontValues, fontName)
        end
    elseif hasFont(fontName) then
        addFontOption(fontValues, fontName)
    end
end

local themeFont = ThemeFolder:AddList({
    text = "Font",
    flag = "ui_font",
    value = "Default",
    values = fontValues,
    skipConfig = true,
    callback = function(fontName)
        if syncingTheme then return end
        local resolvedFont = fontName
        if fontName == "Monospace" then
            resolvedFont = hasFont("RobotoMono") and "RobotoMono" or "Code"
        end

        local ok = fontName == "Default" and Library:ResetFont() or Library:SetFont(resolvedFont)
        setStatus(ok, "font set to " .. tostring(fontName), "invalid font")
    end
})

local TopBarTheme = ThemeFolder:AddFolder("TopBar")
addThemeToggle(TopBarTheme, "Gradient", "TopBar.Line.Gradient")
addThemeColor(TopBarTheme, "Main", "TopBar.Line.MainColor")
addThemeColor(TopBarTheme, "Second", "TopBar.Line.SecondColor")
addThemeColor(TopBarTheme, "Text", "TopBar.TextColor")
addThemeColor(TopBarTheme, "Open icon", "TopBar.OnOffColor.On")
addThemeColor(TopBarTheme, "Closed icon", "TopBar.OnOffColor.Off")
addThemeBox(TopBarTheme, "Icon id", "TopBar.OnOffColor.Icon", "rbxassetid://4918373417")

local CursorTheme = ThemeFolder:AddFolder("Cursor")
addThemeToggle(CursorTheme, "Custom cursor", "Cursor.Enabled")
addThemeBox(CursorTheme, "Cursor id", "Cursor.Image", "")

local FolderTheme = ThemeFolder:AddFolder("Folder")
addThemeColor(FolderTheme, "Text", "Folder.TextColor")
addThemeColor(FolderTheme, "Open icon", "Folder.OnOff.On")
addThemeColor(FolderTheme, "Closed icon", "Folder.OnOff.Off")
addThemeBox(FolderTheme, "Icon id", "Folder.OnOff.Icon", "rbxassetid://4918373417")

local ButtonTheme = ThemeFolder:AddFolder("Button")
addThemeToggle(ButtonTheme, "Gradient", "Button.Color.Gradient")
addThemeColor(ButtonTheme, "Text", "Button.TextColor")
addThemeColor(ButtonTheme, "Main", "Button.Color.MainColor")
addThemeColor(ButtonTheme, "Second", "Button.Color.SecondColor")
addThemeColor(ButtonTheme, "Hover", "Button.Color.HoverColor")

local ToggleTheme = ThemeFolder:AddFolder("Toggle")
addThemeBox(ToggleTheme, "Icon id", "Toggle.Icon", "rbxassetid://4919148038")
addThemeColor(ToggleTheme, "Stroke", "Toggle.StrokeColor")
addThemeColor(ToggleTheme, "On", "Toggle.OnColor")
addThemeColor(ToggleTheme, "Off", "Toggle.OffColor")
addThemeColor(ToggleTheme, "Hover", "Toggle.HoverColor")

local TextInputTheme = ThemeFolder:AddFolder("Text / Inputs")
addThemeColor(TextInputTheme, "Text", "Text.Color")
addThemeColor(TextInputTheme, "Textbox main", "TextBox.MainColor")
addThemeColor(TextInputTheme, "Slider background", "Slider.BackgroundColor")
addThemeColor(TextInputTheme, "Slider fill", "Slider.Color2")
addThemeColor(TextInputTheme, "Divider", "Divider.Color")

local ThemeFiles = ThemeFolder:AddFolder("Custom themes")

local themeNameBox = ThemeFiles:AddBox({
    text = "Theme name",
    flag = "theme_name",
    value = themeName,
    skipConfig = true,
    callback = function(value)
        if syncingTheme then return end
        themeName = cleanName(value, "default")
        Library:SetThemeInfo({ Name = themeName, Creator = themeCreator })
    end
})

local themeCreatorBox = ThemeFiles:AddBox({
    text = "Theme creator",
    flag = "theme_creator",
    value = themeCreator,
    skipConfig = true,
    callback = function(value)
        if syncingTheme then return end
        themeCreator = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        Library:SetThemeInfo({ Name = themeName, Creator = themeCreator })
    end
})

ThemeFiles:AddButton({
    text = "Create theme",
    callback = function()
        local ok, result = Library:SaveTheme(themeName, { Name = themeName, Creator = themeCreator })
        setStatus(ok, "theme created", result)
        refreshThemeList(themeName)
    end
})

ThemeFiles:AddButton({
    text = "Reset theme",
    callback = function()
        Library:ResetTheme()
        syncThemeControls()
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

local configName = "default"
local renameConfigName = ""
local selectedConfig = "--"
local selectedConfigLabel

local function selectedConfigDisplay()
    local name = cleanName(selectedConfig, "")
    return name == "" and "None" or name
end

local function updateSelectedConfigLabel()
    if selectedConfigLabel then
        selectedConfigLabel:Set("Selected Config: " .. selectedConfigDisplay())
    end
end

ConfigFolder:AddBox({
    text = "Config name",
    flag = "config_name",
    value = configName,
    skipConfig = true,
    callback = function(value)
        configName = cleanName(value, "default")
    end
})

ConfigFolder:AddButton({
    text = "Create config",
    callback = function()
        local ok, result = Library:SaveConfig(configName)
        setStatus(ok, "config created", result)
        refreshConfigList(configName)
    end
})

local configList = ConfigFolder:AddList({
    text = "Configs",
    flag = "config_list",
    value = "--",
    values = { "--" },
    skipConfig = true,
    callback = function(value)
        selectedConfig = value
        updateSelectedConfigLabel()
    end
})

selectedConfigLabel = ConfigFolder:AddLabel({ text = "Selected Config: None" })

ConfigFolder:AddBox({
    text = "Rename config to",
    flag = "rename_config_name",
    value = renameConfigName,
    skipConfig = true,
    callback = function(value)
        renameConfigName = cleanName(value, "")
    end
})

ConfigFolder:AddButton({
    text = "Rename config",
    callback = function()
        local oldName = cleanName(selectedConfig, "")
        if oldName == "" then
            setStatus(false, nil, "select a config first")
            updateSelectedConfigLabel()
            return
        end

        local newName = cleanName(renameConfigName, "")
        if newName == "" then
            setStatus(false, nil, "enter a new config name")
            return
        end

        local ok, result = Library:RenameConfig(oldName, newName)
        setStatus(ok, "config renamed", result)
        if ok then
            configName = newName
            refreshConfigList(newName)
        else
            updateSelectedConfigLabel()
        end
    end
})

local autoloadLabel = ConfigFolder:AddLabel({ text = "Autoload config: none" })

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

    updateSelectedConfigLabel()
    updateAutoloadLabel()
    if err then
        statusLabel:Set("Status: " .. err)
    end
end

ConfigFolder:AddButton({
    text = "Load config",
    callback = function()
        local ok, result = Library:LoadConfig(selectedName(selectedConfig, configName, "default"))
        if ok then
            notificationSideList:SetValue(Library:GetNotificationSide())
            dpiScaleList:SetValue(currentDpiScaleText())
            uiTransparencySlider:SetValue(Library:GetUITransparency())
            syncThemeControls()
            updateAutoloadLabel()
        end
        setStatus(ok, "config loaded", result)
    end
})

ConfigFolder:AddButton({
    text = "Overwrite config",
    callback = function()
        local name = selectedName(selectedConfig, configName, "default")
        local ok, result = Library:SaveConfig(name)
        setStatus(ok, "config overwritten", result)
        refreshConfigList(name)
    end
})

ConfigFolder:AddButton({
    text = "Delete config",
    callback = function()
        local name = selectedName(selectedConfig, configName, "default")
        local ok, result = Library:DeleteConfig(name)
        setStatus(ok, "config deleted", result)
        refreshConfigList()
    end
})

ConfigFolder:AddButton({
    text = "Refresh list",
    callback = function()
        refreshConfigList(selectedConfig)
        statusLabel:Set("Status: config list refreshed")
    end
})

ConfigFolder:AddButton({
    text = "Set as autoload",
    callback = function()
        local ok, result = Library:SetAutoloadConfig(selectedName(selectedConfig, configName, "default"))
        setStatus(ok, "autoload config set", result)
        updateAutoloadLabel()
    end
})

ConfigFolder:AddButton({
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

delay(0.75, function()
    notificationSideList:SetValue(Library:GetNotificationSide())
    dpiScaleList:SetValue(currentDpiScaleText())
    uiTransparencySlider:SetValue(Library:GetUITransparency())
    syncThemeControls()
    refreshThemeList(selectedTheme)
    refreshConfigList(selectedConfig)
end)
