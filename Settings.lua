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
        print("  /wba token         - Open Token History tab")
        print("  /wba settings      - Open Settings tab")
        print("  /wba changelog     - Open Changelog tab")
        print("  /wba support       - Open Support tab (Discord/GitHub)")
        print("  /wba tutorial      - Replay the first-run tutorial")
        print("  /wba process       - Force process transfers")
        print("  /wba weekly        - Debug weekly income info")
        print("  /wba debuginfo     - Show region/realm/time diagnostics (for bug reports)")
        print("  /wba delete <name> - Delete a character")
        print("  /wba resetgm       - Reset Guild Master cache")
        print("  /wba clearguild    - Clear guild bank data")
    elseif msg == "targets" then
        WarbandAccountant.UI:Toggle("targets")
    elseif msg == "ledger" then
        WarbandAccountant.UI:Toggle("ledger")
    elseif msg == "token" then
        WarbandAccountant.UI:Toggle("token")
    elseif msg == "settings" or msg == "config" then
        WarbandAccountant.UI:Toggle("settings")
    elseif msg == "changelog" then
        WarbandAccountant.UI:Toggle("changelog")
    elseif msg == "support" then
        WarbandAccountant.UI:Toggle("support")
    elseif msg == "tutorial" then
        WarbandAccountant.UI:StartTutorial()
    elseif msg == "toggle" then
        WarbandAccountant.UI:Toggle("overview")
    elseif msg == "process" then
        WarbandAccountant.Core:ForceProcess()
    elseif msg == "weekly" then
        local Data = WarbandAccountant.Data
        local income  = Data:GetWeeklyIncome()
        local resetTS = Data:GetWeeklyResetTimestamp()
        local now     = GetServerTime and GetServerTime() or time()
        print("|cFFFFD700WarbandAccountant Weekly:|r")
        print("  Reset: " .. date("!%Y-%m-%d %H:%M:%S", resetTS) .. " UTC (" .. tostring(math.floor((now - resetTS) / 3600)) .. "h ago)")
        print("  Weekly Income: " .. WarbandAccountant.FormatGold(income))
    elseif msg == "debuginfo" then
        local Data = WarbandAccountant.Data
        local region = GetCurrentRegion and GetCurrentRegion() or nil
        local regionNames = { [1]="US", [2]="KR", [3]="EU", [4]="TW", [5]="CN" }
        local locale = GetLocale and GetLocale() or "?"
        local realm = GetRealmName and GetRealmName() or "?"
        local buildVersion, buildNumber, buildDate = "?", "?", "?"
        if GetBuildInfo then
            buildVersion, buildNumber, buildDate = GetBuildInfo()
        end
        local serverTime = GetServerTime and GetServerTime() or nil
        local localTime = time()
        local secondsUntilReset = (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset)
            and C_DateAndTime.GetSecondsUntilWeeklyReset() or nil
        local resetTS = Data:GetWeeklyResetTimestamp()

        print("|cFF00FF00Warband Accountant Debug Info:|r")
        print("  Addon Version: " .. Data:GetCurrentAddonVersion())
        print("  Region: " .. (regionNames[region] or "unknown") .. " (raw=" .. tostring(region) .. ")")
        print("  Locale: " .. locale)
        print("  Realm: " .. realm)
        print("  Client Build: " .. tostring(buildVersion) .. " (" .. tostring(buildNumber) .. "), " .. tostring(buildDate))
        print("  Server Time: " .. tostring(serverTime) .. (serverTime and (" (" .. date("!%Y-%m-%d %H:%M:%S", serverTime) .. " UTC)") or " (unavailable)"))
        print("  Local Clock Time: " .. tostring(localTime) .. " (" .. date("!%Y-%m-%d %H:%M:%S", localTime) .. " UTC)")
        if serverTime then
            print("  Clock Skew (local - server): " .. tostring(localTime - serverTime) .. "s")
        end
        print("  Seconds Until Weekly Reset (raw API): " .. tostring(secondsUntilReset))
        print("  Calculated Last Reset: " .. date("!%Y-%m-%d %H:%M:%S", resetTS) .. " UTC")
        print("  Weekly Income (calculated): " .. WarbandAccountant.FormatGold(Data:GetWeeklyIncome()))
        print("|cFFFFFF00Tip:|r Copy/paste this block when reporting a bug on GitHub.")
    elseif msg == "resetgm" then
        WarbandAccountant.Data:ResetGuildMasterCache()
        print("|cFF00FF00Warband Accountant:|r Guild Master cache cleared.")
    elseif msg == "clearguild" then
        WarbandAccountant.Data:ClearGuildBankData()
        if WarbandAccountant.UI.UpdateGuildNavVisibility then
            WarbandAccountant.UI:UpdateGuildNavVisibility()
        end
        print("|cFF00FF00Warband Accountant:|r Guild bank data cleared.")
    elseif msg == "debugguild" or msg:match("^debugguild%s+%d+$") then
        local Data = WarbandAccountant.Data
        local countArg = msg:match("^debugguild%s+(%d+)$")
        local count = math.max(1, math.min(tonumber(countArg) or 2, 10))

        for i = 1, count do
            local goldAmount = math.random(1000, 999999) * 10000
            Data:SetGuildBankData("Debug Guild " .. i, goldAmount)
        end

        if WarbandAccountant.UI.UpdateGuildNavVisibility then
            WarbandAccountant.UI:UpdateGuildNavVisibility()
        end
        if WarbandAccountant.UI.RefreshGuilds then
            WarbandAccountant.UI:RefreshGuilds()
        end

        print(string.format("|cFF00FF00Warband Accountant:|r Added %d debug guild bank %s (\"Debug Guild 1\"..\"Debug Guild %d\").",
            count, count == 1 and "entry" or "entries", count))
        print("|cFFFFFF00Warband Accountant:|r Use /wba cleardebugguild to remove just these, or /wba clearguild to wipe all guild data (real and fake).")
    elseif msg == "cleardebugguild" then
        local Data = WarbandAccountant.Data
        local removed = 0
        for _, name in ipairs(Data:GetKnownGuildNames()) do
            if name:match("^Debug Guild %d+$") then
                Data:ClearGuildBankData(name)
                removed = removed + 1
            end
        end

        if WarbandAccountant.UI.UpdateGuildNavVisibility then
            WarbandAccountant.UI:UpdateGuildNavVisibility()
        end
        if WarbandAccountant.UI.RefreshGuilds then
            WarbandAccountant.UI:RefreshGuilds()
        end

        if removed > 0 then
            print(string.format("|cFF00FF00Warband Accountant:|r Removed %d debug guild bank %s. Real synced guild data untouched.",
                removed, removed == 1 and "entry" or "entries"))
        else
            print("|cFF00FF00Warband Accountant:|r No debug guild banks found.")
        end
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
