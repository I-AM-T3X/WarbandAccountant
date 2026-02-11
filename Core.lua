local ADDON_NAME, WarbandAccountant = ...
-- Don't cache Data at file level - use WarbandAccountant.Data at runtime to avoid load order issues

local Core = {}
WarbandAccountant.Core = Core

function WarbandAccountant.FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remainingCopper = copper % 100
    
    if gold > 0 then
        return string.format("|cFFFFD700%dg|r |cFFC7C7C7%ds|r |cFFEDA55F%dc|r", gold, silver, remainingCopper)
    elseif silver > 0 then
        return string.format("|cFFC7C7C7%ds|r |cFFEDA55F%dc|r", silver, remainingCopper)
    else
        return string.format("|cFFEDA55F%dc|r", remainingCopper)
    end
end

local isBankOpen = false
local hasProcessedThisSession = false
local pendingAutoAmount = 0 -- Track expected auto-transaction amount
local pendingAutoType = nil -- "DEPOSIT" or "WITHDRAW"
local lastWarbandBalance = 0

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
            self:NotifyTransfer("skipped (paused)", 0)
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
            
            -- Set pending transaction BEFORE executing
            pendingAutoAmount = excess
            pendingAutoType = "DEPOSIT"
            lastWarbandBalance = GetWarbandGold() -- Store pre-transaction balance
            
            local success = ExecuteDeposit(excess)
            
            if not success then
                pendingAutoAmount = 0
                pendingAutoType = nil
            end
            -- Don't add ledger entry here - wait for ACCOUNT_MONEY to confirm it
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
            
            -- Set pending transaction BEFORE executing
            pendingAutoAmount = needed
            pendingAutoType = "WITHDRAW"
            lastWarbandBalance = GetWarbandGold() -- Store pre-transaction balance
            
            local success, err = ExecuteWithdrawal(needed)
            
            if not success then
                pendingAutoAmount = 0
                pendingAutoType = nil
                self:NotifyError(err)
            end
            -- Don't add ledger entry here - wait for ACCOUNT_MONEY to confirm it
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
    print(string.format("|cFFFF0000Warband Accountant Error:|r %s", err or "Unknown error"))
end

function Core:ShowConfirmation(transferType, amount)
    local dialogName = "WARBANDACCOUNTANT_CONFIRM_" .. transferType:upper()
    
    if not StaticPopupDialogs[dialogName] then
        StaticPopupDialogs[dialogName] = {
            text = "Warband Accountant\n\n%s %s?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                Core:ProcessTransfers(true)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    
    local actionText = transferType == "deposit" and "Deposit" or "Withdraw"
    local text = string.format("%s %s %s?", actionText, WarbandAccountant.FormatGold(amount), 
        transferType == "deposit" and "to Warband Bank?" or "from Warband Bank?")
    
    StaticPopup_Show(dialogName, text)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("ACCOUNT_MONEY")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        WarbandAccountant.Data:Init()
        WarbandAccountant.Settings:Init()
        WarbandAccountant.UI:Init()
        
        lastWarbandBalance = GetWarbandGold()
        
        C_Timer.After(1, function()
            WarbandAccountant.Data:UpdateCharacterGold()
            WarbandAccountant.UI:UpdateTooltip()
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
        
        -- Check if this matches our pending auto-transaction
        if pendingAutoType and pendingAutoAmount > 0 then
            local expectedDelta = (pendingAutoType == "DEPOSIT") and pendingAutoAmount or -pendingAutoAmount
            
            if math.abs(delta - expectedDelta) < 1 then -- Allow tiny rounding errors
                -- This is our auto-transaction completing, record it
                Data:AddLedgerEntry({
                    amount = pendingAutoAmount,
                    type = pendingAutoType,
                    balanceAfter = currentBalance,
                    note = pendingAutoType == "DEPOSIT" and "Auto-deposit excess" or "Auto-withdraw deficit"
                })
                
                if pendingAutoType == "DEPOSIT" then
                    Core:NotifyTransfer("deposited", pendingAutoAmount)
                else
                    Core:NotifyTransfer("withdrawn", pendingAutoAmount)
                end
                
                hasProcessedThisSession = true
                pendingAutoAmount = 0
                pendingAutoType = nil
            else
                -- Balance changed but not by expected amount, treat as manual
                recordManualTransaction(delta, currentBalance)
            end
        else
            -- No pending auto-transaction, this is manual
            if delta ~= 0 then
                recordManualTransaction(delta, currentBalance)
            end
        end
        
        lastWarbandBalance = currentBalance
        WarbandAccountant.UI:UpdateTooltip()
    end
end)

function recordManualTransaction(delta, currentBalance)
    local Data = WarbandAccountant.Data
    if delta > 0 then
        Data:AddLedgerEntry({
            amount = delta,
            type = "MANUAL_DEPOSIT",
            balanceAfter = currentBalance,
            note = "Manual deposit"
        })
    elseif delta < 0 then
        Data:AddLedgerEntry({
            amount = math.abs(delta),
            type = "MANUAL_WITHDRAW",
            balanceAfter = currentBalance,
            note = "Manual withdrawal"
        })
    end
end

function Core:IsBankOpen()
    return isBankOpen
end

function Core:GetWarbandGold()
    return GetWarbandGold()
end

function Core:ForceProcess()
    hasProcessedThisSession = false
    Core:ProcessTransfers()
end