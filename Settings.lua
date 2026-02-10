local ADDON_NAME, WarbandAccountant = ...
local Data = WarbandAccountant.Data

-- Local namespace to avoid shadowing global Settings
local SettingsModule = {}
WarbandAccountant.Settings = SettingsModule

function SettingsModule:Init()
    self:CreateBlizzardSettings()
end

function SettingsModule:CreateBlizzardSettings()
    -- Create the canvas frame for Blizzard Settings UI
    local frame = CreateFrame("Frame", "WarbandAccountantSettingsCanvas", UIParent)
    frame:SetSize(600, 400)
    frame.name = "Warband Accountant" -- Required for Settings API
    
    -- Background texture (dark Blizzard style)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.95)
    
    -- Border
    local border = CreateFrame("Frame", nil, frame, "DialogBorderDarkTemplate")
    border:SetAllPoints()
    
    -- Title (Baganator-style big text)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -60)
    title:SetText("|cFF4FC3F7Warband|r |cFFFFFFFFAccountant|r")
    title:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
    
    -- Version
    local version = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    version:SetPoint("TOP", title, "BOTTOM", 0, -10)
    version:SetText("Version: 1.0.0")
    version:SetTextColor(0.7, 0.7, 0.7)
    
    -- Minimap button toggle
    local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    checkbox:SetPoint("TOP", version, "BOTTOM", 0, -40)
    checkbox.Text:SetText("Show minimap button")
    checkbox.Text:SetFontObject("GameFontHighlight")
    
    -- Set initial state
    local settings = Data:GetSettings()
    checkbox:SetChecked(not settings.hide)
    
    checkbox:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        settings.hide = not show
        if WarbandAccountant.UI.ToggleMinimapButton then
            WarbandAccountant.UI:ToggleMinimapButton()
        end
    end)
    
    -- Help text
    local helpText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    helpText:SetPoint("TOP", checkbox, "BOTTOM", 0, -20)
    helpText:SetText("Access options anytime with /wa")
    
    -- Big red button (Baganator style)
    local openBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    openBtn:SetPoint("TOP", helpText, "BOTTOM", 0, -30)
    openBtn:SetSize(200, 50)
    
    -- Make it red like Baganator's button
    openBtn:SetNormalFontObject("GameFontNormalLarge")
    openBtn:SetHighlightFontObject("GameFontHighlightLarge")
    openBtn:SetText("Open Options")
    
    -- Red button styling
    local function StyleButtonAsRed(btn)
        local regions = {btn:GetRegions()}
        for _, region in ipairs(regions) do
            if region:GetObjectType() == "Texture" then
                region:SetVertexColor(0.8, 0.1, 0.1, 1)
            end
        end
    end
    
    openBtn:SetScript("OnShow", function() StyleButtonAsRed(openBtn) end)
    
    openBtn:SetScript("OnClick", function()
        WarbandAccountant.UI:ToggleMainWindow()
    end)
    
    -- Additional info text at bottom
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("BOTTOM", 0, 20)
    infoText:SetText("Configure automatic gold management for your Warband")
    infoText:SetTextColor(0.5, 0.5, 0.5)
    
    -- Register as Canvas Layout Category (this gives us the full custom panel)
    local category = Settings.RegisterCanvasLayoutCategory(frame, "Warband Accountant")
    Settings.RegisterAddOnCategory(category)
    
    self.category = category
    self.canvasFrame = frame
end

-- Slash command
SLASH_WARBANDACCOUNTANT1 = "/warbandaccountant"
SLASH_WARBANDACCOUNTANT2 = "/wa"

SlashCmdList["WARBANDACCOUNTANT"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "" or msg == "help" then
        print("|cFF00FF00Warband Accountant|r Commands:")
        print("  /warbandaccountant help - Show this help")
        print("  /warbandaccountant config - Open settings")
        print("  /warbandaccountant toggle - Toggle main window")
        print("  /warbandaccountant process - Force process transfers")
    elseif msg == "config" then
        SettingsModule:OpenSettings()
    elseif msg == "toggle" then
        WarbandAccountant.UI:ToggleMainWindow()
    elseif msg == "process" then
        WarbandAccountant.Core:ForceProcess()
    else
        print("|cFFFF0000Warband Accountant:|r Unknown command. Type /warbandaccountant help")
    end
end

function SettingsModule:OpenSettings()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end