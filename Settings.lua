local ADDON_NAME, WarbandAccountant = ...

local SettingsModule = {}
WarbandAccountant.Settings = SettingsModule

function SettingsModule:Init()
    self:RegisterBlizzardStub()
end

-- Minimal Blizzard addon settings entry -- just points to /wba
function SettingsModule:RegisterBlizzardStub()
    local frame = CreateFrame("Frame", "WarbandAccountantSettingsStub", UIParent)
    frame:SetSize(400, 200)
    frame.name = "Warband Accountant"

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -40)
    title:SetText("Warband Accountant")
    title:SetTextColor(1, 0.82, 0)

    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -10)
    sub:SetText("All settings are inside the addon window.")
    sub:SetTextColor(0.6, 0.6, 0.6)

    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(180, 40)
    btn:SetPoint("TOP", sub, "BOTTOM", 0, -20)
    btn:SetText("Open Warband Accountant")
    btn:SetScript("OnClick", function()
        WarbandAccountant.UI:Toggle("settings")
    end)

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOP", btn, "BOTTOM", 0, -15)
    note:SetText("Or type: /wba")
    note:SetTextColor(0.5, 0.5, 0.5)

    local category = Settings.RegisterCanvasLayoutCategory(frame, "Warband Accountant")
    Settings.RegisterAddOnCategory(category)
    self.category = category
end

function SettingsModule:OpenSettings()
    WarbandAccountant.UI:Toggle("settings")
end

-- -- Slash Commands ------------------------------------------------------------
SLASH_WARBANDACCOUNTANT1 = "/warbandaccountant"
SLASH_WARBANDACCOUNTANT2 = "/wba"

SlashCmdList["WARBANDACCOUNTANT"] = function(msg)
    msg = msg:lower():trim()

    if msg == "" then
        WarbandAccountant.UI:Toggle("overview")
    elseif msg == "help" then
        print("|cFF00FF00Warband Accountant|r Commands:")
        print("  /wba               - Toggle main window")
        print("  /wba targets       - Open Targets tab")
        print("  /wba ledger        - Open Ledger tab")
        print("  /wba settings      - Open Settings tab")
        print("  /wba changelog     - Open Changelog tab")
        print("  /wba process       - Force process transfers")
        print("  /wba weekly        - Debug weekly income info")
        print("  /wba delete <name> - Delete a character")
        print("  /wba resetgm       - Reset Guild Master cache")
        print("  /wba clearguild    - Clear guild bank data")
    elseif msg == "targets" then
        WarbandAccountant.UI:Toggle("targets")
    elseif msg == "ledger" then
        WarbandAccountant.UI:Toggle("ledger")
    elseif msg == "settings" or msg == "config" then
        WarbandAccountant.UI:Toggle("settings")
    elseif msg == "changelog" then
        WarbandAccountant.UI:Toggle("changelog")
    elseif msg == "toggle" then
        WarbandAccountant.UI:Toggle("overview")
    elseif msg == "process" then
        WarbandAccountant.Core:ForceProcess()
    elseif msg == "weekly" then
        local Data = WarbandAccountant.Data
        local income  = Data:GetWeeklyIncome()
        local resetTS = Data:GetWeeklyResetTimestamp()
        local now     = time()
        print("|cFFFFD700WarbandAccountant Weekly:|r")
        print("  Reset: " .. date("!%Y-%m-%d %H:%M:%S", resetTS) .. " UTC (" .. tostring(math.floor((now - resetTS) / 3600)) .. "h ago)")
        print("  Weekly Income: " .. WarbandAccountant.FormatGold(income))
    elseif msg == "resetgm" then
        WarbandAccountant.Data:ResetGuildMasterCache()
        print("|cFF00FF00Warband Accountant:|r Guild Master cache cleared.")
    elseif msg == "clearguild" then
        WarbandAccountant.Data:ClearGuildBankData()
        print("|cFF00FF00Warband Accountant:|r Guild bank data cleared.")
    elseif msg:match("^delete ") then
        local charName = msg:match("^delete (.+)$")
        if charName then
            local charID = charName .. "-" .. GetRealmName()
            local ok, result = WarbandAccountant.Data:DeleteCharacter(charID)
            if ok then
                print("|cFF00FF00Warband Accountant:|r Deleted: " .. result)
                WarbandAccountant.UI:RefreshTargets()
            else
                print("|cFFFF0000Warband Accountant:|r " .. (result or "Could not delete"))
            end
        else
            print("|cFFFF0000Warband Accountant:|r Usage: /wba delete CharacterName")
        end
    else
        print("|cFFFF0000Warband Accountant:|r Unknown command. Type /wba help")
    end
end
