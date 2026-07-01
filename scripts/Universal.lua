-- ============================================================
--  Levis Hub — Universal Script
--  Runs on unsupported / undetected games
--  Author  : Nam Nguyen
-- ============================================================

-- ┌─────────────────────────────────────────────────────────────┐
-- │                  UI LIBRARY DOCUMENTATION                   │
-- │                                                             │
-- │  This file documents the full API of Levis Hub's UI         │
-- │  Library and serves as the universal (fallback) script      │
-- │  for games without a dedicated script.                      │
-- └─────────────────────────────────────────────────────────────┘

-- ── 1. LOADING THE LIBRARY ────────────────────────────────────
-- Load the UI library via HTTP:
local Library = loadstring(game:HttpGet("https://pastebin.com/raw/edJT9EGX", true))()

-- ── 2. TOGGLING THE UI ───────────────────────────────────────
-- After the library is initialized, call Library:Close()
-- to toggle (open/close) the UI window.
-- You can also bind this to a key (see Keybind section below).

-- ── 3. CREATING A WINDOW ─────────────────────────────────────
-- Syntax:  Library:CreateWindow(title: string) -> Window
--
-- Creates a new window tab in the UI.
--
-- Special property:
--   Window.canInit = false  →  Prevents this window from being
--                               created when Library:Init() is called.

local Window = Library:CreateWindow("Window")

-- ── 4. CREATING FOLDERS ──────────────────────────────────────
-- Syntax:  Window:AddFolder(name: string) -> Folder
--
-- Folders act as collapsible groups. They support ALL the same
-- methods as Windows (AddLabel, AddButton, AddToggle, etc.).
-- Folders can be nested infinitely.

local Folder = Window:AddFolder("Folder")

-- ── 5. UI ELEMENTS ───────────────────────────────────────────
--
-- All elements accept a table of options. Common properties:
--   • text     (string)    – Display text / label
--   • flag     (string)    – Unique key stored in Library.flags
--                            Defaults to the text value if omitted.
--   • callback (function)  – Called when the value changes
--

-- ─────────────────────────────────────────
-- 5.1  LABEL
-- ─────────────────────────────────────────
-- Syntax:  Window:AddLabel({ text })
-- A static, non-interactive text label.
--
-- Parameters:
--   text  (string)  – The label text to display.

Window:AddLabel({ text = "Label" })

-- ─────────────────────────────────────────
-- 5.2  BUTTON
-- ─────────────────────────────────────────
-- Syntax:  Window:AddButton({ text, flag, callback })
-- A clickable button that fires the callback once pressed.
--
-- Parameters:
--   text      (string)    – Button display text.
--   flag      (string)    – [Optional] Flag name. Set to true after click.
--   callback  (function)  – Called when the button is clicked.

Window:AddButton({
    text = "Button",
    flag = "button",
    callback = function()
        print("pressed")
    end
})

-- ─────────────────────────────────────────
-- 5.3  TOGGLE
-- ─────────────────────────────────────────
-- Syntax:  Window:AddToggle({ text, flag, state, callback })
-- An on/off switch that holds a boolean state.
--
-- Parameters:
--   text      (string)    – Toggle label.
--   flag      (string)    – [Optional] Flag name.
--   state     (boolean)   – Initial state (true = on, false = off).
--                           If true, the callback fires on Library:Init().
--   callback  (function)  – Receives the new state (boolean).

Window:AddToggle({
    text = "Toggle Off",
    flag = "toggle",
    state = false,
    callback = function(enabled)
        print("Toggle is now:", enabled)
    end
})

Window:AddToggle({
    text = "Toggle On",
    flag = "toggle1",
    state = true, -- fires callback immediately on init
    callback = function(enabled)
        print("Toggle is now:", enabled)
    end
})

-- ─────────────────────────────────────────
-- 5.4  DROPDOWN / LIST
-- ─────────────────────────────────────────
-- Syntax:  Window:AddList({ text, flag, value, values, callback })
-- A dropdown selector from a list of string values.
--
-- Parameters:
--   text      (string)    – Dropdown label.
--   flag      (string)    – [Optional] Flag name.
--   value     (string)    – Default selected value.
--                           If not present in `values`, it gets added.
--   values    (table)     – Array of selectable strings.
--   callback  (function)  – Receives the selected value (string).

Window:AddList({
    text = "List",
    flag = "list",
    value = "Value",
    values = { "Value1", "Value2", "Value3", "Value4" },
    callback = function(selected)
        print("Selected:", selected)
    end
})

-- ─────────────────────────────────────────
-- 5.5  TEXTBOX
-- ─────────────────────────────────────────
-- Syntax:  Window:AddBox({ text, flag, value, callback })
-- A text input field.
--
-- Parameters:
--   text      (string)    – Textbox label.
--   flag      (string)    – [Optional] Flag name.
--   value     (string)    – Default text content.
--   callback  (function)  – Receives the entered text (string).

Window:AddBox({
    text = "Box",
    flag = "box",
    value = "Value",
    callback = function(input)
        print("Input:", input)
    end
})

-- ─────────────────────────────────────────
-- 5.6  SLIDER
-- ─────────────────────────────────────────
-- Syntax:  Window:AddSlider({ text, flag, value, min, max, float, callback })
-- A draggable slider for numeric values.
--
-- Parameters:
--   text      (string)    – Slider label.
--   flag      (string)    – [Optional] Flag name.
--   value     (number)    – Initial value.
--   min       (number)    – Minimum value.
--   max       (number)    – Maximum value.
--   float     (number)    – [Optional] Step increment (e.g. 0.3).
--                           Omit for integer-only steps.
--   callback  (function)  – Receives the current value (number).

Window:AddSlider({
    text = "Slider (Float)",
    flag = "slider",
    value = 100,
    min = 20,
    max = 200,
    float = 0.3,
    callback = function(val)
        print("Slider:", val)
    end
})

Window:AddSlider({
    text = "Slider (Negative)",
    flag = "slider1",
    value = 0,
    min = -50,
    max = 100,
    callback = function(val)
        print("Slider:", val)
    end
})

-- ─────────────────────────────────────────
-- 5.7  KEYBIND
-- ─────────────────────────────────────────
-- Syntax:  Window:AddBind({ text, flag, key, hold, callback })
-- Binds a keyboard/mouse key to a callback.
--
-- Parameters:
--   text      (string)    – Keybind label.
--   flag      (string)    – [Optional] Flag name.
--   key       (string|Enum) – The key to bind. Accepts:
--                             • String name:  "E", "MouseButton1", "RightShift"
--                             • Enum value:   Enum.KeyCode.E
--                             •               Enum.UserInputType.MouseButton1
--   hold      (boolean)   – [Optional] If true, the callback receives:
--                             • false when the key is pressed (holding)
--                             • true  when the key is released (let go)
--   callback  (function)  – For press mode: fires on key press (no args).
--                           For hold mode: receives a boolean (see above).

-- Press mode
Window:AddBind({
    text = "Bind (Press)",
    flag = "bind",
    key = "MouseButton1",
    callback = function()
        print("pressed")
    end
})

-- Hold mode
Window:AddBind({
    text = "Bind (Hold)",
    flag = "bind_hold",
    hold = true,
    key = "E",
    callback = function(released)
        if released then
            print("let go")
        else
            print("holding")
        end
    end
})

-- Toggle UI keybind example:
-- Window:AddBind({ text = "Toggle UI", key = "RightShift", callback = function() Library:Close() end })

-- ─────────────────────────────────────────
-- 5.8  COLOR PICKER
-- ─────────────────────────────────────────
-- Syntax:  Window:AddColor({ text, flag, color, callback })
-- A color picker with a visual preview.
--
-- Parameters:
--   text      (string)    – Color picker label.
--   flag      (string)    – [Optional] Flag name.
--   color     (Color3|table) – Initial color. Accepts:
--                              • Color3.fromRGB(r, g, b)
--                              • { r, g, b }  (values 0–1, like Color3.new)
--                                Useful for JSON-encoded saved configs.
--   callback  (function)  – Receives the selected Color3 value.

Window:AddColor({
    text = "Color (RGB)",
    flag = "color",
    color = Color3.fromRGB(255, 65, 65),
    callback = function(col)
        print("Color:", col)
    end
})

Window:AddColor({
    text = "Color (Table)",
    flag = "color_table",
    color = { 1, 0.2, 0.2 }, -- equivalent to Color3.new(1, 0.2, 0.2)
    callback = function(col)
        print("Color:", col)
    end
})

-- ─────────────────────────────────────────
-- 5.9  DIVIDER
-- ─────────────────────────────────────────
-- Syntax:  Window:AddDivider()
-- Adds a horizontal separator line between elements.
-- Purely visual — no parameters or callbacks.

Window:AddDivider()

-- ── 6. INITIALIZING THE LIBRARY ──────────────────────────────
-- After all windows, folders, and elements are defined,
-- call Library:Init() to build and display the UI.
-- Toggles with state = true will fire their callbacks here.

Library:Init()

-- ── 7. READING FLAGS ─────────────────────────────────────────
-- Library.flags is a table that stores the current value/state
-- of every element that has a flag set.
--
-- Examples:
--   Library.flags["toggle"]   → boolean (true/false)
--   Library.flags["slider"]   → number
--   Library.flags["list"]     → string
--   Library.flags["box"]      → string
--   Library.flags["color"]    → Color3
--   Library.flags["bind"]     → Enum.KeyCode / Enum.UserInputType
--   Library.flags["button"]   → boolean (true after clicked)
--
-- You can also read value/state/key directly from each option object.

wait(5)
print("Toggle is currently:", Library.flags["toggle"])
print("Second toggle is currently:", Library.flags["toggle1"])

-- ── 8. LIBRARY UTILITY METHODS ───────────────────────────────
--
-- These methods can be called AFTER Library:Init()
-- for runtime control of the UI.
--

-- ─────────────────────────────────────────
-- 8.1  Library:Close()
-- ─────────────────────────────────────────
-- Toggles the UI visibility (show/hide).
-- Does NOT destroy the UI — just hides it.
-- Call again to re-show.
--
-- Example:
--   Library:Close()  -- hides UI
--   Library:Close()  -- shows UI again

-- ─────────────────────────────────────────
-- 8.2  Library:Destroy()
-- ─────────────────────────────────────────
-- Permanently destroys the entire UI and cleans up
-- all connections/events. Cannot be undone.
-- Use this when you want to fully remove the hub.
--
-- Example:
--   Library:Destroy()

-- ─────────────────────────────────────────
-- 8.3  Window/Folder:ClearAllChildren()
-- ─────────────────────────────────────────
-- Removes ALL child elements (buttons, toggles, sliders, etc.)
-- from a Window or Folder. The window/folder itself stays.
-- Useful for rebuilding a section dynamically.
--
-- Example:
--   Window:ClearAllChildren()           -- clears the window
--   Folder:ClearAllChildren()           -- clears a folder
--
-- After clearing, you can re-add new elements:
--   Window:AddLabel({ text = "Refreshed!" })

-- ── 9. PER-ELEMENT METHODS ──────────────────────────────────
--
-- Each element returned by Add___() has a :Set() method
-- to programmatically update its value at runtime.
--

-- ─────────────────────────────────────────
-- 9.1  Toggle:Set(state: boolean)
-- ─────────────────────────────────────────
-- Programmatically toggle on/off. Fires the callback.
--
-- local myToggle = Window:AddToggle({ text = "ESP", flag = "esp", state = false, callback = function(a) end })
-- myToggle:Set(true)   -- turns on
-- myToggle:Set(false)  -- turns off

-- ─────────────────────────────────────────
-- 9.2  Slider:Set(value: number)
-- ─────────────────────────────────────────
-- Programmatically change the slider value. Fires the callback.
-- Value is clamped to [min, max].
--
-- local mySlider = Window:AddSlider({ text = "Speed", flag = "speed", value = 16, min = 0, max = 100, callback = function(a) end })
-- mySlider:Set(50)

-- ─────────────────────────────────────────
-- 9.3  List:Set(value: string)
-- ─────────────────────────────────────────
-- Programmatically select a dropdown value. Fires the callback.
--
-- local myList = Window:AddList({ text = "Mode", flag = "mode", value = "A", values = {"A","B","C"}, callback = function(a) end })
-- myList:Set("B")

-- ─────────────────────────────────────────
-- 9.4  Box:Set(value: string)
-- ─────────────────────────────────────────
-- Programmatically change the textbox content. Fires the callback.
--
-- local myBox = Window:AddBox({ text = "Name", flag = "name", value = "", callback = function(a) end })
-- myBox:Set("Hello")

-- ─────────────────────────────────────────
-- 9.5  Color:Set(color: Color3)
-- ─────────────────────────────────────────
-- Programmatically change the selected color. Fires the callback.
--
-- local myColor = Window:AddColor({ text = "ESP Color", flag = "espcolor", color = Color3.fromRGB(255,0,0), callback = function(a) end })
-- myColor:Set(Color3.fromRGB(0, 255, 0))

-- ─────────────────────────────────────────
-- 9.6  Bind:Set(key: string|Enum)
-- ─────────────────────────────────────────
-- Programmatically change the keybind.
--
-- local myBind = Window:AddBind({ text = "Aimbot", flag = "aim_key", key = "E", callback = function() end })
-- myBind:Set("Q")

-- ─────────────────────────────────────────
-- 9.7  Label:Set(text: string)
-- ─────────────────────────────────────────
-- Programmatically update the label text.
--
-- local myLabel = Window:AddLabel({ text = "Status: Idle" })
-- myLabel:Set("Status: Running")
