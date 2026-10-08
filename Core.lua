local ADDON_NAME, WarbandAccountant = ...

local Core = {}
WarbandAccountant.Core = Core

function WarbandAccountant.FormatGold(copper)
    local negative = copper < 0
    copper = math.abs(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remainingCopper = copper % 100
    local prefix = negative and "-" or ""

    local sep = (WarbandAccountant.Data and WarbandAccountant.Data:GetThousandsSeparator()) or ""
    local goldStr = tostring(gold)
    if sep ~= "" and gold >= 1000 then
        goldStr = goldStr:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
        if goldStr:sub(1, #sep) == sep then
            goldStr = goldStr:sub(#sep + 1)
        end
    end

    if gold > 0 then
        return string.format("%s|cFFFFD700%sg|r |cFFC7C7C7%02ds|r |cFFEDA55F%02dc|r", prefix, goldStr, silver, remainingCopper)
    elseif silver > 0 then
        return string.format("%s|cFFC7C7C7%ds|r |cFFEDA55F%02dc|r", prefix, silver, remainingCopper)
    else
        return string.format("%s|cFFEDA55F%dc|r", prefix, remainingCopper)
    end
end

local isBankOpen = false
local hasProcessedThisSession = false
local pendingAutoAmount = 0
local pendingAutoType = nil
local lastWarbandBalance = 0
local accountTotalTicker
local guildBankOpen = false

local function GetWarbandGold()
    return C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
end

local function ExecuteDeposit(amount)
    if not C_Bank.CanDepositMoney(Enum.BankType.Account) then
        return false, "Cannot deposit at this time"
    end
    
    local currentGold = GetMoney()
    if currentGold < amount then
        amount = currentGold
    end
    
    if amount <= 0 then return true end
    
    C_Bank.DepositMoney(Enum.BankType.Account, amount)
    return true
end

local function ExecuteWithdrawal(amount)
    local warbandGold = GetWarbandGold()
    if warbandGold < amount then
        amount = warbandGold
    end
    
    if amount <= 0 then 
        return false, "Warband bank has insufficient funds"
    end
    
    if not C_Bank.CanWithdrawMoney(Enum.BankType.Account, amount) then
        return false, "Cannot withdraw at this time"
    end
    
    C_Bank.WithdrawMoney(Enum.BankType.Account, amount)
    return true
end

function Core:ProcessTransfers(skipConfirmation)
    if not isBankOpen then return end
    
    if hasProcessedThisSession and not skipConfirmation then
        return
    end
    
    local Data = WarbandAccountant.Data
    local charData = Data:GetCharacterData()
    if not charData or not charData.enabled then return end
    
    if charData.paused then
        if not skipConfirmation then
            self:NotifyTransfer(WarbandAccountant.L.CORE_ACTION_SKIPPED_PAUSED, 0)
        end
        hasProcessedThisSession = true
        return
    end
    
    local currentGold = GetMoney()
    local targetGold = charData.targetGold or 0
    
    if currentGold > targetGold then
        local excess = currentGold - targetGold
        if Data:IsAutoDepositEnabled() and excess > 0 then
            if Data:IsConfirmationRequired() and not skipConfirmation then
                self:ShowConfirmation("deposit", excess)
                return
            end
            
            pendingAutoAmount = excess
            pendingAutoType = "DEPOSIT"
            lastWarbandBalance = GetWarbandGold()
            
            local success, err = ExecuteDeposit(excess)
            
            if not success then
                pendingAutoAmount = 0
                pendingAutoType = nil
                self:NotifyError(err)
            end
        end
    elseif currentGold < targetGold then
        local needed = targetGold - currentGold
        local warbandGold = GetWarbandGold()
        
        if needed > warbandGold then
            needed = warbandGold
        end
        
        if Data:IsAutoWithdrawEnabled() and needed > 0 then
            if Data:IsConfirmationRequired() and not skipConfirmation then
                self:ShowConfirmation("withdraw", needed)
                return
            end
            
            pendingAutoAmount = needed
            pendingAutoType = "WITHDRAW"
            lastWarbandBalance = GetWarbandGold()
            
            local success, err = ExecuteWithdrawal(needed)
            
            if not success then
                pendingAutoAmount = 0
                pendingAutoType = nil
                self:NotifyError(err)
            end
        end
    end
    
    Data:UpdateCharacterGold()
    WarbandAccountant.UI:UpdateTooltip()
end

function Core:NotifyTransfer(action, amount)
    if amount == 0 then
        print(string.format("|cFF00FF00Warband Accountant:|r %s", action))
    else
        print(string.format("|cFF00FF00Warband Accountant:|r %s %s", WarbandAccountant.FormatGold(amount), action))
    end
end

function Core:NotifyError(err)
    local L = WarbandAccountant.L
    print(string.format(L.CORE_ERROR_PREFIX, err or L.CORE_UNKNOWN_ERROR))
end

function Core:ShowConfirmation(transferType, amount)
    local L = WarbandAccountant.L
    local dialogName = "WARBANDACCOUNTANT_CONFIRM_" .. transferType:upper()

    if not StaticPopupDialogs[dialogName] then
        StaticPopupDialogs[dialogName] = {
            text = "%s",
            button1 = L.SETTINGS_YES,
            button2 = L.SETTINGS_NO,
            OnAccept = function()
                Core:ProcessTransfers(true)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    local actionText = transferType == "deposit" and L.CORE_CONFIRM_DEPOSIT_ACTION or L.CORE_CONFIRM_WITHDRAW_ACTION
    local dest = transferType == "deposit" and L.CORE_CONFIRM_TO_BANK or L.CORE_CONFIRM_FROM_BANK
    local text = string.format("%s %s %s", actionText, WarbandAccountant.FormatGold(amount), dest)

    StaticPopup_Show(dialogName, text)
end

-- Function to update guild bank data - separated for reuse
function Core:UpdateGuildBankData()
    local Data = WarbandAccountant.Data
    local guildName = select(1, GetGuildInfo("player"))
    
    if not guildName then return end
    
    -- Use raw API check here, not the cached IsGuildMaster()
    -- If we can access guild bank money, save it regardless of cache
    local isGM = IsGuildLeader()
    local gold = GetGuildBankMoney() or 0
    
    if isGM then
        Data:SetGuildBankData(guildName, gold)
        -- Reset the GM cache to true since we confirmed it
        if Data:GetDB() and Data:GetDB().guildMasterCache then
            Data:GetDB().guildMasterCache[Data:GetCurrentCharacterID()] = true
        end
        WarbandAccountant.UI:UpdateTooltip()
        if WarbandAccountant.UI.UpdateGuildNavVisibility then
            WarbandAccountant.UI:UpdateGuildNavVisibility()
        end
    end
end

local function recordManualTransaction(delta, currentBalance)
    local Data = WarbandAccountant.Data
    local L = WarbandAccountant.L
    if delta > 0 then
        Data:AddLedgerEntry({
            amount = delta,
            type = "MANUAL_DEPOSIT",
            balanceAfter = currentBalance,
            note = L.CORE_NOTE_MANUAL_DEPOSIT
        })
    elseif delta < 0 then
        Data:AddLedgerEntry({
            amount = math.abs(delta),
            type = "MANUAL_WITHDRAW",
            balanceAfter = currentBalance,
            note = L.CORE_NOTE_MANUAL_WITHDRAW
        })
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("ACCOUNT_MONEY")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("GUILDBANKFRAME_CLOSED")
eventFrame:RegisterEvent("GUILDBANK_UPDATE_MONEY")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        WarbandAccountant.Data:Init()
        WarbandAccountant.Settings:Init()
        if WarbandAccountant.Token and WarbandAccountant.Token.RefreshLocaleText then
            WarbandAccountant.Token:RefreshLocaleText()
        end
        if WarbandAccountant.UI then WarbandAccountant.UI:Init() else print("|cFFFF0000Warband Accountant:|r UI failed to load.") end

        local L = WarbandAccountant.L
        print(L.MSG_PREFIX_GOLD .. L.MSG_STARTUP_LOCALIZATION)
        print(L.MSG_PREFIX_GOLD .. L.MSG_STARTUP_SUPPORT)
        
        lastWarbandBalance = GetWarbandGold()
        
        C_Timer.After(1, function()
            WarbandAccountant.Data:UpdateCharacterGold()
            WarbandAccountant.UI:UpdateTooltip()
            if WarbandAccountant.Token and WarbandAccountant.Token.UpdateWeeklyLine then
                WarbandAccountant.Token:UpdateWeeklyLine()
            end
            if WarbandAccountant.Goals then
                WarbandAccountant.Goals:Check()
            end
            WarbandAccountant.Data:RecordAccountTotalSnapshot()
        end)

        -- Periodic Account Total snapshot, so the Gold History graph's
        -- Account Total view has more than one point per session. Every
        -- 15 minutes is enough resolution for a trend without growing the
        -- history too fast.
        if not accountTotalTicker then
            accountTotalTicker = C_Timer.NewTicker(900, function()
                WarbandAccountant.Data:RecordAccountTotalSnapshot()
            end)
        end
        
        -- Show update notification if needed
        C_Timer.After(3, function()
            WarbandAccountant.UI:CheckAndShowUpdateNotification()
        end)

        -- First-run tutorial for brand-new installs only
        C_Timer.After(3, function()
            WarbandAccountant.UI:CheckAndShowTutorial()
        end)
        
    elseif event == "PLAYER_MONEY" then
        WarbandAccountant.Data:UpdateCharacterGold()
        WarbandAccountant.UI:UpdateTooltip()
        
    elseif event == "BANKFRAME_OPENED" then
        isBankOpen = true
        hasProcessedThisSession = false
        lastWarbandBalance = GetWarbandGold()
        C_Timer.After(0.5, function()
            if isBankOpen then
                Core:ProcessTransfers()
            end
        end)
        
    elseif event == "BANKFRAME_CLOSED" then
        isBankOpen = false
        hasProcessedThisSession = false
        
    elseif event == "ACCOUNT_MONEY" then
        local Data = WarbandAccountant.Data
        local currentBalance = GetWarbandGold()
        local delta = currentBalance - lastWarbandBalance
        
        if pendingAutoType and pendingAutoAmount > 0 then
            local expectedDelta = (pendingAutoType == "DEPOSIT") and pendingAutoAmount or -pendingAutoAmount
            
            if math.abs(delta - expectedDelta) < 1 then
                Data:AddLedgerEntry({
                    amount = pendingAutoAmount,
                    type = pendingAutoType,
                    balanceAfter = currentBalance,
                    note = pendingAutoType == "DEPOSIT" and WarbandAccountant.L.CORE_NOTE_AUTO_DEPOSIT or WarbandAccountant.L.CORE_NOTE_AUTO_WITHDRAW
                })
                
                if pendingAutoType == "DEPOSIT" then
                    Core:NotifyTransfer(WarbandAccountant.L.CORE_ACTION_DEPOSITED, pendingAutoAmount)
                else
                    Core:NotifyTransfer(WarbandAccountant.L.CORE_ACTION_WITHDRAWN, pendingAutoAmount)
                end
                
                hasProcessedThisSession = true
                pendingAutoAmount = 0
                pendingAutoType = nil
            else
                recordManualTransaction(delta, currentBalance)
            end
        else
            if delta ~= 0 then
                recordManualTransaction(delta, currentBalance)
            end
        end
        
        lastWarbandBalance = currentBalance
        WarbandAccountant.UI:UpdateTooltip()
        
    elseif event == "GUILDBANKFRAME_OPENED" then
        guildBankOpen = true
        -- Delayed update since money data loads asynchronously from server
        C_Timer.After(1.0, function()
            if guildBankOpen then
                Core:UpdateGuildBankData()
            end
        end)
        
    elseif event == "GUILDBANKFRAME_CLOSED" then
        guildBankOpen = false
        -- Final update on close to catch withdrawals/deposits
        Core:UpdateGuildBankData()
        
    elseif event == "GUILDBANK_UPDATE_MONEY" then
        -- Update immediately when money changes
        if guildBankOpen then
            Core:UpdateGuildBankData()
        end
        
    end
end)

function Core:IsBankOpen()
    return isBankOpen
end

function Core:GetWarbandGold()
    return GetWarbandGold()
end

function Core:GetGuildBankGold()
    local Data = WarbandAccountant.Data
    local guildName = select(1, GetGuildInfo("player"))
    
    -- If we're a GM of current guild, always sync and prefer live data for it,
    -- even if a different guild is set as the home guild -- live data from
    -- the character actually standing in that guild beats a cached number.
    if guildName and Data:IsGuildMaster() then
        local gold = GetGuildBankMoney() or 0
        local existing = Data:GetGuildBankData(guildName)
        if not existing or existing.gold ~= gold then
            Data:SetGuildBankData(guildName, gold)
        end
        return gold, guildName
    end
    
    -- Otherwise fall back to cached data: home guild takes priority,
    -- then the current character's own guild.
    return self:GetPersonalGuildBankGold()
end

function Core:GetPersonalGuildBankGold()
    local Data = WarbandAccountant.Data
    local db = Data:GetDB()
    if not db or not db.guildBankData then return 0, nil end

    local currentRealm = GetRealmName()

    -- A chosen "home guild" always takes priority over the current
    -- character's own guild, so an alt sitting in a different guild
    -- than your GM still shows the guild bank you actually track.
    local homeGuild = Data:GetHomeGuild()
    if homeGuild then
        local data = Data:GetGuildBankData(homeGuild)
        if data and data.realm == currentRealm then
            return data.gold or 0, homeGuild
        end
    end

    -- No home guild set (or no data cached for it yet) -- fall back to
    -- the current character's own guild if we have cached data for it.
    local currentGuild = select(1, GetGuildInfo("player"))
    if currentGuild then
        local data = Data:GetGuildBankData(currentGuild)
        if data and data.realm == currentRealm then
            return data.gold or 0, currentGuild
        end
    end

    return 0, nil
end

function Core:ForceProcess()
    hasProcessedThisSession = false
    Core:ProcessTransfers()
end