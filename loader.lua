-- ============================================================
--  Levis Hub Loader
--  Author  : Nam Nguyen
--  GitHub  : https://github.com/Ic0u/levishub
-- ============================================================

-- ── Anti Double-Execution Guard ──────────────────────────────
if _G.LevisHubLoaded then return end
_G.LevisHubLoaded = true

-- ── Services ──────────────────────────────────────────────────
local TweenService  = game:GetService("TweenService")
local Players       = game:GetService("Players")
local HttpService   = game:GetService("HttpService")

-- ── Config ────────────────────────────────────────────────────
local BASE_URL        = "https://raw.githubusercontent.com/Ic0u/levishub/main/"

-- ── External Game Registry (fetched from GitHub) ──────────────
local DEFAULT_GAMES = {
    ["2377868063"]  = "Strucid",
    ["286090429"]   = "Arsenal",
    ["13772394625"] = "Blade Ball",
}

local function fetchGameRegistry()
    local ok, raw = pcall(game.HttpGet, game, BASE_URL .. "games.json")
    if ok and raw and raw ~= "" then
        local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
        if decodeOk and type(decoded) == "table" then
            return decoded
        end
    end
    return DEFAULT_GAMES
end

local SupportedGames    = fetchGameRegistry()
local currentPlaceId    = tostring(game.PlaceId)
local detectedGameName  = SupportedGames[currentPlaceId]
local isSupported       = (detectedGameName ~= nil)
local finalDisplayText  = detectedGameName or "Unsupported"

-- ── Safe Script Loader ────────────────────────────────────────
local function safeLoad(url)
    local getOk, source = pcall(game.HttpGet, game, url)
    if not getOk or not source or source == "" then
        return false
    end
    local fn, err = loadstring(source)
    if not fn then
        return false
    end
    local runOk, runErr = pcall(fn)
    if not runOk then
        return false
    end
    return true
end

-- ── GUI Undetection ───────────────────────────────────────────
local function getProtectedParent()
    if syn and syn.protect_gui then
        return nil, true
    elseif gethui then
        return gethui()
    else
        local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
        if ok and coreGui then return coreGui end
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function applyGuiProtection(gui)
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
        gui.Parent = game:GetService("CoreGui")
    else
        gui.Parent = getProtectedParent()
    end
end

-- ── Build GUI ─────────────────────────────────────────────────
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("LevisHubGui") then
    playerGui.LevisHubGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "LevisHubGui"
screenGui.ResetOnSpawn   = false
screenGui.DisplayOrder   = 99999
screenGui.IgnoreGuiInset = true

applyGuiProtection(screenGui)

-- Main container
local mainBox = Instance.new("Frame")
mainBox.Name                = "MainBox"
mainBox.AnchorPoint         = Vector2.new(0.5, 0.5)
mainBox.Position            = UDim2.new(0.5, 0, 0.5, 0)
mainBox.Size                = UDim2.new(0, 0, 0, 0)
mainBox.BackgroundColor3    = Color3.fromRGB(28, 28, 28)
mainBox.BackgroundTransparency = 0
mainBox.BorderSizePixel     = 0
mainBox.ClipsDescendants    = true
mainBox.Parent              = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 6)
uiCorner.Parent       = mainBox

-- Title
local titleText = Instance.new("TextLabel")
titleText.Name               = "TitleText"
titleText.AnchorPoint        = Vector2.new(0.5, 0.5)
titleText.Position           = UDim2.new(0.5, 0, 0.5, 0)
titleText.Size               = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.RichText           = true
titleText.Text               = '<font color="#1ab273">levis\'s</font> <font color="#ffffff">hub</font>'
titleText.TextSize           = 28
titleText.Font               = Enum.Font.GothamMedium
titleText.TextXAlignment     = Enum.TextXAlignment.Center
titleText.TextTransparency   = 1
titleText.Parent             = mainBox

-- Divider
local dividerLine = Instance.new("Frame")
dividerLine.Name                = "DividerLine"
dividerLine.Position            = UDim2.new(0, 0, 0, 24)
dividerLine.Size                = UDim2.new(0, 0, 0, 1)
dividerLine.BackgroundColor3    = Color3.fromRGB(26, 178, 115)
dividerLine.BackgroundTransparency = 1
dividerLine.BorderSizePixel     = 0
dividerLine.Parent              = mainBox

-- Status text
local statusText = Instance.new("TextLabel")
statusText.Name                = "StatusText"
statusText.Size                = UDim2.new(1, 0, 0, 16)
statusText.Position            = UDim2.new(0, 0, 0, 38)
statusText.BackgroundTransparency = 1
statusText.Text                = ""
statusText.TextColor3          = Color3.fromRGB(255, 255, 255)
statusText.TextSize            = 13
statusText.Font                = Enum.Font.GothamMedium
statusText.TextXAlignment      = Enum.TextXAlignment.Center
statusText.TextTransparency    = 1
statusText.Parent              = mainBox

-- ── Status Updater ────────────────────────────────────────────
local function updateStatus(newText, waitTime)
    TweenService:Create(statusText,
        TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { TextTransparency = 1, Position = UDim2.new(0, 0, 0, 30) }
    ):Play()
    task.wait(0.3)
    statusText.Text     = newText
    statusText.Position = UDim2.new(0, 0, 0, 46)
    TweenService:Create(statusText,
        TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { TextTransparency = 0, Position = UDim2.new(0, 0, 0, 38) }
    ):Play()
    task.wait(waitTime or 0.8)
end

-- ── Animation Sequence ────────────────────────────────────────
task.spawn(function()
    task.wait(0.5)

    -- 1. Box expand
    TweenService:Create(mainBox,
        TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 260, 0, 75) }
    ):Play()
    task.wait(0.6)

    -- 2. Fade in title
    TweenService:Create(titleText,
        TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { TextTransparency = 0 }
    ):Play()
    task.wait(0.4)

    -- 3. Title slide to top-left, divider expands
    TweenService:Create(titleText,
        TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
        { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 2, 0, 2), Size = UDim2.new(0, 78, 0, 20), TextSize = 15 }
    ):Play()
    TweenService:Create(dividerLine,
        TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
        { Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0 }
    ):Play()
    task.wait(0.7)

    -- 4. Status messages
    updateStatus("UI made by Marcus", 1.2)
    updateStatus("Getting Ready...", 0.3)
    updateStatus("Checking Whitelist...", 0.8)
    updateStatus("Authenticated Success!", 0.5)
    updateStatus("happy exploiting <3", 1.0)
    updateStatus(finalDisplayText, 1.5)

    -- 5. Close animation
    TweenService:Create(statusText,
        TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { TextTransparency = 1 }
    ):Play()
    TweenService:Create(dividerLine,
        TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut),
        { Size = UDim2.new(0, 0, 0, 1) }
    ):Play()
    task.wait(0.6)
    TweenService:Create(titleText,
        TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { TextTransparency = 1 }
    ):Play()
    TweenService:Create(mainBox,
        TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut),
        { Size = UDim2.new(0, 0, 0, 0) }
    ):Play()
    task.wait(0.5)
    screenGui:Destroy()

    -- 6. Load the appropriate script
    if isSupported then
        safeLoad(BASE_URL .. "games/" .. currentPlaceId .. ".lua")
    else
        safeLoad(BASE_URL .. "scripts/Universal.lua")
    end
end)
