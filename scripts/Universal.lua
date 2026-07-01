-- ============================================================
--  Levis Hub - Universal UI Test
--  Runs on unsupported games and documents the UI library.
-- ============================================================

local UILIB_URL = "https://raw.githubusercontent.com/Ic0u/levishub/main/libraries/UILibrary.lua"
local Library = loadstring(game:HttpGet(UILIB_URL, true))()

local Window = Library:CreateWindow("Levis Hub")
local Folder = Window:AddFolder("Elements")
local Runtime = Window:AddFolder("Runtime")
local ThemeManager = Window:AddFolder("Theme Manager")
local Configuration = Window:AddFolder("Configuration")

Window:AddLabel({ text = "Universal UI test" })
Window:AddDivider()

local statusLabel = Window:AddLabel({ text = "Status: ready" })
Window:AddLabel({ text = "RightShift toggles the UI" })

Window:AddButton({
    text = "Button",
    flag = "demo_button",
    callback = function()
        statusLabel:Set("Status: button pressed")
        print("[Levis Hub] Button pressed")
    end
})

local demoToggle = Window:AddToggle({
    text = "Toggle",
    flag = "demo_toggle",
    state = false,
    callback = function(enabled)
        statusLabel:Set("Status: toggle " .. (enabled and "on" or "off"))
        print("[Levis Hub] Toggle:", enabled)
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

local themeColor = ThemeManager:AddColor({
    text = "Accent",
    flag = "theme_accent",
    color = Library:GetTheme().Accent,
    callback = function(color)
        Library:SetTheme({ Accent = color })
        statusLabel:Set("Status: theme updated")
    end
})

ThemeManager:AddList({
    text = "Font",
    flag = "ui_font",
    value = "Gotham",
    values = {
        "Gotham",
        "GothamBold",
        "SourceSans",
        "SourceSansBold",
        "Arial",
        "ArialBold",
        "Code",
        "SciFi",
        "Fantasy",
        "Arcade",
        "Cartoon",
        "Ubuntu"
    },
    callback = function(fontName)
        if Library:SetFont(fontName) then
            statusLabel:Set("Status: font set to " .. fontName)
        else
            statusLabel:Set("Status: invalid font")
        end
    end
})

ThemeManager:AddButton({
    text = "Save Theme",
    callback = function()
        local ok, result = Library:SaveTheme()
        statusLabel:Set(ok and "Status: theme saved" or ("Status: " .. result))
    end
})

ThemeManager:AddButton({
    text = "Load Theme",
    callback = function()
        local ok, result = Library:LoadTheme()
        if ok then
            themeColor:SetColor(Library:GetTheme().Accent)
        end
        statusLabel:Set(ok and "Status: theme loaded" or ("Status: " .. result))
    end
})

ThemeManager:AddButton({
    text = "Reset Theme",
    callback = function()
        Library:ResetTheme()
        themeColor:SetColor(Library:GetTheme().Accent)
        statusLabel:Set("Status: theme reset")
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

Configuration:AddButton({
    text = "Save Config",
    callback = function()
        local ok, result = Library:SaveConfig("default")
        statusLabel:Set(ok and "Status: config saved" or ("Status: " .. result))
    end
})

Configuration:AddButton({
    text = "Load Config",
    callback = function()
        local ok, result = Library:LoadConfig("default")
        if ok then
            themeColor:SetColor(Library:GetTheme().Accent)
        end
        statusLabel:Set(ok and "Status: config loaded" or ("Status: " .. result))
    end
})

Configuration:AddButton({
    text = "Unload UI",
    callback = function()
        Library:Unload()
    end
})

Library:Init()
