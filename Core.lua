local ADDON_NAME, WarbandAccountant = ...
local Data = WarbandAccountant.Data

-- Core namespace
local Core = {}
WarbandAccountant.Core = Core

-- Export FormatGold for other modules
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

-- State
local isBankOpen = false

-- Utility: Get Warband Bank gold
local function GetWarbandGold()
    return C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
end

-- Check if we can interact with warband bank
local function CanUseWarbandBank()
    return C_Bank.CanDepositMoney(Enum.BankType.Account) or 
           C_Bank.CanWithdrawMoney(Enum.BankType.Account, 1)
end

-- Execute deposit
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

-- Execute withdrawal
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

-- Main logic: Check and process transfers
function Core:ProcessTransfers(skipConfirmation)
    if not isBankOpen then return end
    
    local charData = Data:GetCharacterData()
    if not charData or not charData.enabled then return end
    
    local currentGold = GetMoney()
    local targetGold = charData.targetGold or 0
    
    if currentGold > targetGold then
        local excess = currentGold - targetGold
        if Data:IsAutoDepositEnabled() and excess > 0 then
            if Data:IsConfirmationRequired() and not skipConfirmation then
                self:ShowConfirmation("deposit", excess)
                return
            end
            ExecuteDeposit(excess)
            self:NotifyTransfer("deposited", excess)
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
            local success, err = ExecuteWithdrawal(needed)
            if success then
                self:NotifyTransfer("withdrawn", needed)
            else
                self:NotifyError(err)
            end
        end
    end
    
    -- Update data after transfer
    Data:UpdateCharacterGold()
    WarbandAccountant.UI:UpdateTooltip()
end

-- Notification
function Core:NotifyTransfer(action, amount)
    local msg = string.format("|cFF00FF00Warband Accountant:|r %s %s", 
        WarbandAccountant.FormatGold(amount), action)
    print(msg)
end

function Core:NotifyError(err)
    print(string.format("|cFFFF0000Warband Accountant Error:|r %s", err or "Unknown error"))
end

-- Confirmation dialog
function Core:ShowConfirmation(transferType, amount)
    local dialogName = "WARBANDACCOUNTANT_CONFIRM_" .. transferType:upper()
    
    if not StaticPopupDialogs[dialogName] then
        StaticPopupDialogs[dialogName] = {
            text = "Warband Accountant\n\n%1$s %2$s?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function(self, data)
                Core:ProcessTransfers(true)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    
    local actionText = transferType == "deposit" and "Deposit" or "Withdraw"
    local text = string.format("Warband Accountant\n\n%s %s %s?", 
        actionText, WarbandAccountant.FormatGold(amount), 
        transferType == "deposit" and "to Warband Bank?" or "from Warband Bank?")
    
    StaticPopup_Show(dialogName, text)
end

-- Event handling
local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("ACCOUNT_MONEY")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        Data:Init()
        WarbandAccountant.Settings:Init()
        WarbandAccountant.UI:Init()
        
        -- Initialize session data after a short delay to ensure money is loaded
        C_Timer.After(1, function()
            Data:UpdateCharacterGold()
            WarbandAccountant.UI:UpdateTooltip()
        end)
        
    elseif event == "PLAYER_MONEY" then
        Data:UpdateCharacterGold()
        if isBankOpen then
            Core:ProcessTransfers()
        end
        WarbandAccountant.UI:UpdateTooltip()
        
    elseif event == "BANKFRAME_OPENED" then
        isBankOpen = true
        C_Timer.After(0.1, function()
            Core:ProcessTransfers()
        end)
        
    elseif event == "BANKFRAME_CLOSED" then
        isBankOpen = false
        
    elseif event == "ACCOUNT_MONEY" then
        WarbandAccountant.UI:UpdateTooltip()
    end
end)

-- Public API
function Core:IsBankOpen()
    return isBankOpen
end

function Core:GetWarbandGold()
    return GetWarbandGold()
end

function Core:ForceProcess()
    Core:ProcessTransfers()
end