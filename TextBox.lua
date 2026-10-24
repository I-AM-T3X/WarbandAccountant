local ADDON_NAME, WarbandAccountant = ...

--[[
Warband Accountant -- Text boxes

Our own text box, so spacing is easy to reason about. It uses Blizzard's
behavior template (InputBoxScriptTemplate: Escape/Enter/Tab handling,
highlight on focus, screen reader narration) and draws the same border art
Blizzard's InputBoxTemplate uses, with one difference:

    The border sits exactly on the frame.

InputBoxTemplate draws its left edge 5px outside the frame and puts the text
right against the frame edge, so its visible box never lined up with where
you anchored it. Here, what you SetPoint is what you see, and the text
always has the same padding inside the border (TB.PAD).

    local eb = TB.Create(parent, width, height, {
        numeric  = true,        -- digits only
        maxLetters = 7,
        justify  = "RIGHT",     -- "LEFT" (default), "CENTER" or "RIGHT"
    })

To line typed text up with a label or header above it, put the box TB.PAD
pixels to the left of that header.

When disabled the box dims its border and greys its text.
]]

local TB = {}
WarbandAccountant.TextBox = TB

TB.PAD = 6            -- text padding inside the border, left and right
TB.HEIGHT = 22        -- default box height
local EDGE_W = 8      -- width of the rounded end caps

local ENABLED_RGB  = { 1, 1, 1 }
local DISABLED_RGB = { 0.5, 0.5, 0.5 }

local function SetArtAlpha(eb, a)
    eb.Left:SetAlpha(a); eb.Middle:SetAlpha(a); eb.Right:SetAlpha(a)
end

local function OnDisable(self)
    SetArtAlpha(self, 0.5)
    self:SetTextColor(DISABLED_RGB[1], DISABLED_RGB[2], DISABLED_RGB[3])
end

local function OnEnable(self)
    SetArtAlpha(self, 1)
    self:SetTextColor(ENABLED_RGB[1], ENABLED_RGB[2], ENABLED_RGB[3])
end

function TB.Create(parent, width, height, opts)
    opts = opts or {}
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxScriptTemplate")
    eb:SetSize(width or 100, height or TB.HEIGHT)
    eb:SetAutoFocus(false)
    eb:SetFontObject(opts.font or "ChatFontNormal")

    -- Border: left cap, right cap, stretched middle, all inside the frame
    local left = eb:CreateTexture(nil, "BACKGROUND")
    left:SetAtlas("common-search-border-left")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(EDGE_W)

    local right = eb:CreateTexture(nil, "BACKGROUND")
    right:SetAtlas("common-search-border-right")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(EDGE_W)

    local middle = eb:CreateTexture(nil, "BACKGROUND")
    middle:SetAtlas("common-search-border-middle")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

    eb.Left, eb.Middle, eb.Right = left, middle, right

    eb:SetTextInsets(TB.PAD, TB.PAD, 0, 0)
    eb:SetJustifyH(opts.justify or "LEFT")
    if opts.numeric then eb:SetNumeric(true) end
    if opts.maxLetters then eb:SetMaxLetters(opts.maxLetters) end

    eb:HookScript("OnDisable", OnDisable)
    eb:HookScript("OnEnable", OnEnable)
    eb.isWATextBox = true
    return eb
end
