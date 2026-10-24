local ADDON_NAME, WarbandAccountant = ...

--[[
Warband Accountant -- Dropdowns

Blizzard's current dropdown (WowStyle1DropdownTemplate + Blizzard_Menu),
wrapped in a small API shaped like the old UIDropDownMenu calls this addon
was written with, so every call site converts one-for-one:

    UIDropDownMenu_SetWidth(dd, w)      ->  DD.SetWidth(dd, w)
    UIDropDownMenu_SetText(dd, t)       ->  DD.SetText(dd, t)
    UIDropDownMenu_Initialize(dd, fn)   ->  DD.Initialize(dd, fn)
    UIDropDownMenu_CreateInfo()         ->  DD.CreateInfo()
    UIDropDownMenu_AddButton(info)      ->  DD.AddButton(info)
    UIDropDownMenu_Enable/DisableDropDown(dd)  ->  DD.SetEnabled(dd, on)

Each dropdown is a holder frame the same size as an old UIDropDownMenu
frame (old dropdowns had ~16px of empty padding around the visible box),
with the real dropdown button inside where the old box used to sit. So
every existing SetPoint against "dd" lands exactly where it did before.

The addon's menus are all single-choice lists using info.text, .checked,
.func and .arg1, so each option becomes a radio button.
]]

local DD = {}
WarbandAccountant.Dropdown = DD

local PAD_LEFT = 16          -- where the old visible box started inside the frame
local OLD_PADDING = 50       -- old frame width = menu width + 50
local BOX_EXTRA = 18         -- old visible box width = menu width + ~18
local SCROLL_AFTER = 20      -- longer menus scroll (e.g. the 31-day picker)
local ROW_HEIGHT = 20

-- Creates a dropdown. `name` is optional (a global name for the holder).
function DD.Create(name, parent)
    local holder = CreateFrame("Frame", name, parent)
    holder:SetSize(140, 32)

    local button = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
    button:SetPoint("LEFT", holder, "LEFT", PAD_LEFT, 1)
    button:SetWidth(140 - OLD_PADDING + BOX_EXTRA)

    holder.dropdown = button
    holder.isWADropdown = true
    return holder
end

function DD.SetWidth(holder, width)
    holder:SetWidth(width + OLD_PADDING)
    holder.dropdown:SetWidth(width + BOX_EXTRA)
end

function DD.SetText(holder, text)
    holder.text = text
    holder.dropdown:OverrideText(text or "")
end

function DD.GetText(holder)
    return holder.text
end

function DD.SetEnabled(holder, on)
    holder.dropdown:SetEnabled(on and true or false)
end

function DD.CreateInfo()
    return {}
end

-- Collects options while an Initialize function runs.
local collecting

function DD.AddButton(info)
    if collecting then collecting[#collecting + 1] = info end
end

local function IsChecked(info)
    if type(info.checked) == "function" then return info.checked() and true or false end
    return info.checked and true or false
end

-- initFn builds the option list with DD.CreateInfo / DD.AddButton, exactly
-- like an old UIDropDownMenu init function. Blizzard runs the generator
-- whenever it (re)builds the menu, so the checked state is always current.
function DD.Initialize(holder, initFn)
    holder.initFn = initFn
    holder.dropdown:SetupMenu(function(owner, root)
        local items = {}
        collecting = items
        local ok, err = pcall(initFn)
        collecting = nil
        if not ok then geterrorhandler()(err) end

        if #items > SCROLL_AFTER then root:SetScrollMode(SCROLL_AFTER * ROW_HEIGHT) end

        for _, info in ipairs(items) do
            -- Old menu callbacks get (button, arg1, arg2); some read the
            -- picked option's text back with button:GetText().
            local fakeButton = { GetText = function() return info.text end }
            root:CreateRadio(info.text,
                function() return IsChecked(info) end,
                function()
                    -- single choice: this one is now the checked option
                    for _, other in ipairs(items) do
                        if type(other.checked) ~= "function" then other.checked = (other == info) end
                    end
                    if info.func then info.func(fakeButton, info.arg1, info.arg2) end
                end,
                info.arg1)
        end
    end)
end
