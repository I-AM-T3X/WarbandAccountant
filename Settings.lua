local ADDON_NAME, WarbandAccountant = ...

local SettingsModule = {}
WarbandAccountant.Settings = SettingsModule

function SettingsModule:Init()
    self:CreateBlizzardSettings()
end

function SettingsModule:CreateBlizzardSettings()
    local Data = WarbandAccountant.Data
    
    local frame = CreateFrame("Frame", "WarbandAccountantSettingsCanvas", UIParent)
    frame:SetSize(600, 450)
    frame.name = "Warband Accountant"
    
    -- Simple background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    
    -- Header
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -40)
    title:SetText("Warband Accountant")
    title:SetTextColor(1, 0.82, 0)
    
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
    subtitle:SetText("Use /wba to open the main window with Targets and Ledger tabs")
    subtitle:SetTextColor(0.6, 0.6, 0.6)
    
    local version = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    version:SetPoint("TOP", subtitle, "BOTTOM", 0, -5)
    version:SetText("Version: 1.0.1")
    version:SetTextColor(0.5, 0.5, 0.5)
    
    -- Features Section - Two Column Layout (Centered Under Features)
    local featuresHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    featuresHeader:SetPoint("TOP", version, "BOTTOM", 0, -25)
    featuresHeader:SetText("Features")
    featuresHeader:SetTextColor(1, 0.82, 0)
    
    local leftCol = {
        "Per-character gold targets",
        "Auto deposit & withdraw",
        "Transaction ledger",
        "Session gold tracking"
    }
    
    local rightCol = {
        "Character classifications",
        "Pause automation per char",
        "Customizable sorting",
        "Minimap gold summary"
    }
    
    local lineHeight = 22
    
    for i, text in ipairs(leftCol) do
        local item = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        item:SetPoint("TOP", featuresHeader, "BOTTOM", -110, -((i-1)*lineHeight) - 15)
        item:SetWidth(180)
        item:SetJustifyH("CENTER")
        item:SetText(text)
        item:SetTextColor(0.8, 0.8, 0.8)
    end
    
    for i, text in ipairs(rightCol) do
        local item = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        item:SetPoint("TOP", featuresHeader, "BOTTOM", 110, -((i-1)*lineHeight) - 15)
        item:SetWidth(180)
        item:SetJustifyH("CENTER")
        item:SetText(text)
        item:SetTextColor(0.8, 0.8, 0.8)
    end
    
    -- BIG RED BUTTON
    local openBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    openBtn:SetPoint("TOP", featuresHeader, "BOTTOM", 0, -130)
    openBtn:SetSize(200, 50)
    openBtn:SetNormalFontObject("GameFontNormalLarge")
    openBtn:SetHighlightFontObject("GameFontHighlightLarge")
    openBtn:SetText("Open Options")
    
    -- Style it red
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
    
    -- Minimap checkbox - BELOW THE BUTTON
    local checkbox = CreateFrame("CheckButton", nil, frame, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOP", openBtn, "BOTTOM", 0, -25)
    
    local settings = Data:GetSettings()
    checkbox:SetChecked(not settings.hide)
    
    checkbox.Text:SetText("Show minimap button")
    checkbox.Text:SetFontObject("GameFontHighlight")
    
    checkbox:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        settings.hide = not show
        if WarbandAccountant.UI.ToggleMinimapButton then
            WarbandAccountant.UI:ToggleMinimapButton()
        end
    end)
    
    -- Reset Statistics Button (small, bottom right)
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetPoint("BOTTOMRIGHT", -20, 20)
    resetBtn:SetSize(120, 22)
    resetBtn:SetText("Reset Statistics")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("WARBANDACCOUNTANT_RESET_TOTALS")
    end)
    
    StaticPopupDialogs["WARBANDACCOUNTANT_RESET_TOTALS"] = {
        text = "Reset all-time deposit/withdrawal statistics?\n\nThis will clear your total deposited, total withdrawn, and all ledger history. This cannot be undone.",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() 
            Data:ResetLedgerTotals()
            print("|cFF00FF00Warband Accountant:|r Statistics reset")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    
    -- Footer
    local infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("BOTTOM", 0, 15)
    infoText:SetText("Configure automatic gold management for your Warband")
    infoText:SetTextColor(0.5, 0.5, 0.5)
    
    -- Register
    local category = Settings.RegisterCanvasLayoutCategory(frame, "Warband Accountant")
    Settings.RegisterAddOnCategory(category)
    
    self.category = category
    self.canvasFrame = frame
end

SLASH_WARBANDACCOUNTANT1 = "/warbandaccountant"
SLASH_WARBANDACCOUNTANT2 = "/wba"

SlashCmdList["WARBANDACCOUNTANT"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "" or msg == "help" then
        print("|cFF00FF00Warband Accountant|r Commands:")
        print("  /wba help - Show this help")
        print("  /wba config - Open settings")
        print("  /wba toggle - Toggle main window")
        print("  /wba process - Force process transfers")
    elseif msg == "config" then
        SettingsModule:OpenSettings()
    elseif msg == "toggle" then
        WarbandAccountant.UI:ToggleMainWindow()
    elseif msg == "process" then
        WarbandAccountant.Core:ForceProcess()
    else
        print("|cFFFF0000Warband Accountant:|r Unknown command. Type /wba help")
    end
end

function SettingsModule:OpenSettings()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end