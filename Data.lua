local ADDON_NAME, WarbandAccountant = ...

local Data = {}
WarbandAccountant.Data = Data

local DEFAULT_TARGET = 1000000
local CURRENT_DB_VERSION = 1
local CURRENT_ADDON_VERSION = "2.0.0"

-- Weekly reset day by region (1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday)
-- WoW resets happen at specific times; we key off the weekday and treat the reset as midnight UTC that day.
local REGION_RESET_DAYS = {
    ["US"]  = 3, -- Tuesday
    ["EU"]  = 4, -- Wednesday
    ["KR"]  = 5, -- Thursday
    ["TW"]  = 5, -- Thursday
    ["CN"]  = 5, -- Thursday
}
-- Default fallback if region unknown
local DEFAULT_RESET_DAY = 3

local db = nil
local sessionData = {}

local function GetCharacterFullName()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

function Data:Init()
    if not WarbandAccountantDB then
        WarbandAccountantDB = {}
    end
    
    db = WarbandAccountantDB
    db.version = db.version or CURRENT_DB_VERSION
    
    db.global = db.global or {}
    db.global.autoDeposit = db.global.autoDeposit ~= false
    db.global.autoWithdraw = db.global.autoWithdraw ~= false
    db.global.confirmTransfers = db.global.confirmTransfers or false
    db.global.sortMode = db.global.sortMode or "arrow"
    
    db.global.totalDeposited = db.global.totalDeposited or 0
    db.global.totalWithdrawn = db.global.totalWithdrawn or 0
    -- Persist last known warband balance across sessions
    db.global.lastKnownWarbandBalance = db.global.lastKnownWarbandBalance or 0
    
    db.global.mainDefault       = db.global.mainDefault       or (100 * 10000)
    db.global.mainAltDefault    = db.global.mainAltDefault    or (100 * 10000)
    db.global.altDefault        = db.global.altDefault        or (100 * 10000)
    db.global.crafterDefault    = db.global.crafterDefault    or (50  * 10000)
    db.global.auctioneerDefault = db.global.auctioneerDefault or (500 * 10000)
    db.global.bankAltDefault    = db.global.bankAltDefault    or (200 * 10000)

    -- Category display names (user-renameable)
    db.global.categoryNames = db.global.categoryNames or {}
    db.global.categoryNames.main       = db.global.categoryNames.main       or "Main"
    db.global.categoryNames.mainAlt    = db.global.categoryNames.mainAlt    or "Main Alt"
    db.global.categoryNames.alt        = db.global.categoryNames.alt        or "Alt"
    db.global.categoryNames.crafter    = db.global.categoryNames.crafter    or "Crafter"
    db.global.categoryNames.auctioneer = db.global.categoryNames.auctioneer or "Auctioneer"
    db.global.categoryNames.bankAlt    = db.global.categoryNames.bankAlt    or "Bank Alt"
    
    if db.global.minimapAngle then
        db.global.minimapPos = db.global.minimapAngle
        db.global.minimapAngle = nil
    end
    
    db.global.minimapPos = db.global.minimapPos or 195
    db.global.hide = db.global.hide or false
    db.global.lastSeenVersion = db.global.lastSeenVersion or "0.0.0"
    
    db.characters = db.characters or {}
    db.ledger = db.ledger or {}
    
    db.guildLedger = db.guildLedger or {}
    db.guildSettings = db.guildSettings or {
        lastScan = 0,
        totalGuildDeposited = 0,
        totalGuildWithdrawn = 0
    }
    
    db.guildMasterCache = db.guildMasterCache or {}
    db.guildBankData = db.guildBankData or {}
    
    local charCount = 0
    for _ in pairs(db.characters) do charCount = charCount + 1 end
    
    local charID = GetCharacterFullName()
    if not db.characters[charID] then
        charCount = charCount + 1
        db.characters[charID] = {
            name = UnitName("player"),
            realm = GetRealmName(),
            class = select(2, UnitClass("player")),
            targetGold = DEFAULT_TARGET,
            enabled = true,
            paused = false,
            added = time(),
            sortOrder = charCount,
        }
    end
    
    local order = 1
    for id, data in pairs(db.characters) do
        if not data.sortOrder then
            data.sortOrder = order
            order = order + 1
        end
    end
    
    self:InitSessionData(charID)
    self:UpdateCharacterCache()
end

function Data:InitSessionData(charID)
    charID = charID or GetCharacterFullName()
    if not sessionData[charID] then
        local currentMoney = GetMoney()
        sessionData[charID] = {
            startGold = currentMoney,
            lastGold = currentMoney
        }
    end
end

function Data:UpdateCharacterGold()
    local charID = GetCharacterFullName()
    if not db or not db.characters or not db.characters[charID] then return end
    
    local currentGold = GetMoney()
    db.characters[charID].currentGold = currentGold
    db.characters[charID].lastUpdate = time()
    
    self:InitSessionData(charID)
    sessionData[charID].lastGold = currentGold
end

function Data:GetSessionChange(charID)
    charID = charID or GetCharacterFullName()
    if not sessionData[charID] then return 0 end
    
    local startGold = sessionData[charID].startGold or 0
    local currentGold = (db and db.characters and db.characters[charID] and db.characters[charID].currentGold) or 0
    
    return currentGold - startGold
end

function Data:GetTotalSessionChange()
    if not db or not db.characters then return 0 end
    local total = 0
    for charID, _ in pairs(db.characters) do
        total = total + self:GetSessionChange(charID)
    end
    return total
end

function Data:ResetSession(charID)
    charID = charID or GetCharacterFullName()
    if db and db.characters and db.characters[charID] then
        local current = db.characters[charID].currentGold or GetMoney()
        sessionData[charID] = {
            startGold = current,
            lastGold = current
        }
    end
end

function Data:GetCurrentCharacterID()
    return GetCharacterFullName()
end

function Data:GetCharacterData(charID)
    charID = charID or GetCharacterFullName()
    if not db or not db.characters then return nil end
    return db.characters[charID]
end

function Data:SetCharacterTarget(charID, amount)
    charID = charID or GetCharacterFullName()
    if db and db.characters and db.characters[charID] then
        db.characters[charID].targetGold = math.max(0, tonumber(amount) or 0)
    end
end

function Data:GetAllCharacters()
    if not db then return {} end
    return db.characters or {}
end

function Data:GetTotalTrackedGold()
    if not db or not db.characters then return 0 end
    local total = 0
    for _, data in pairs(db.characters) do
        if data.currentGold then
            total = total + data.currentGold
        end
    end
    return total
end

function Data:GetSettings()
    if not db then return {} end
    return db.global or {}
end

function Data:GetDB()
    return db
end

function Data:IsAutoDepositEnabled()
    if not db then return false end
    local charData = self:GetCharacterData()
    return db.global.autoDeposit and (charData and charData.enabled ~= false)
end

function Data:IsAutoWithdrawEnabled()
    if not db then return false end
    local charData = self:GetCharacterData()
    return db.global.autoWithdraw and (charData and charData.enabled ~= false)
end

function Data:IsConfirmationRequired()
    if not db or not db.global then return false end
    return db.global.confirmTransfers
end

function Data:IsCharacterPaused(charID)
    charID = charID or GetCharacterFullName()
    if not db or not db.characters then return false end
    local char = db.characters[charID]
    return char and char.paused or false
end

function Data:ToggleCharacterPause(charID)
    charID = charID or GetCharacterFullName()
    if db and db.characters and db.characters[charID] then
        db.characters[charID].paused = not db.characters[charID].paused
        return db.characters[charID].paused
    end
    return false
end

function Data:GetDefaultTarget(charType)
    if not db or not db.global then return 1000000 end
    local key = charType .. "Default"
    return db.global[key] or 1000000
end

function Data:SetDefaultTarget(charType, amount)
    if not db then return end
    amount = math.max(0, tonumber(amount) or 0)
    db.global = db.global or {}
    db.global[charType .. "Default"] = amount
end

function Data:GetCharacterType(charID)
    charID = charID or GetCharacterFullName()
    if not db or not db.characters then return nil end
    return db.characters[charID] and db.characters[charID].charType
end

function Data:SetCharacterType(charID, charType)
    charID = charID or GetCharacterFullName()
    if not db or not db.characters or not db.characters[charID] then return end
    
    local valid = { main=true, mainAlt=true, alt=true, crafter=true, auctioneer=true, bankAlt=true }
    if not valid[charType] then
        charType = nil
    end
    
    db.characters[charID].charType = charType
    
    if charType then
        local default = self:GetDefaultTarget(charType)
        if default then
            db.characters[charID].targetGold = default
        end
    end
end

function Data:GetCharacterSortOrder(charID)
    charID = charID or GetCharacterFullName()
    if not db or not db.characters then return 0 end
    return db.characters[charID] and db.characters[charID].sortOrder or 0
end

function Data:SetCharacterSortOrder(charID, order)
    charID = charID or GetCharacterFullName()
    if db and db.characters and db.characters[charID] then
        db.characters[charID].sortOrder = order
    end
end

function Data:SwapCharacterOrder(charID1, charID2)
    if not db or not db.characters then return end
    local char1 = db.characters[charID1]
    local char2 = db.characters[charID2]
    if char1 and char2 then
        local temp = char1.sortOrder
        char1.sortOrder = char2.sortOrder
        char2.sortOrder = temp
    end
end

function Data:AddLedgerEntry(entry)
    if not db then return end
    db.ledger = db.ledger or {}
    
    local ts = time()
    table.insert(db.ledger, 1, {
        timestamp     = ts,
        character     = entry.character     or GetCharacterFullName(),
        characterName = entry.characterName or UnitName("player"),
        realm         = entry.realm         or GetRealmName(),
        amount        = entry.amount        or 0,
        type          = entry.type,
        balanceAfter  = entry.balanceAfter  or 0,
        note          = entry.note          or ""
    })
    
    if #db.ledger > 1000 then
        for i = 1001, #db.ledger do
            db.ledger[i] = nil
        end
    end
    
    local amt = entry.amount or 0
    if entry.type == "DEPOSIT" or entry.type == "MANUAL_DEPOSIT" then
        db.global.totalDeposited = (db.global.totalDeposited or 0) + amt
    elseif entry.type == "WITHDRAW" or entry.type == "MANUAL_WITHDRAW" then
        db.global.totalWithdrawn = (db.global.totalWithdrawn or 0) + amt
    end
end

function Data:GetLedgerEntries(limit)
    if not db or not db.ledger then return {} end
    limit = limit or 50
    local entries = {}
    for i = 1, math.min(limit, #db.ledger) do
        table.insert(entries, db.ledger[i])
    end
    return entries
end

function Data:GetTotalLedgerStats()
    if not db or not db.global then return 0, 0 end
    return db.global.totalDeposited or 0, db.global.totalWithdrawn or 0
end

function Data:ClearLedger()
    db.ledger = {}
end

function Data:ResetLedgerTotals()
    if not db or not db.global then return end
    db.global.totalDeposited = 0
    db.global.totalWithdrawn = 0
    db.ledger = {}
end

function Data:UpdateCharacterCache()
    if not db or not db.characters then return {} end
    local cache = {}
    for id, data in pairs(db.characters) do
        cache[id] = {
            name = data.name,
            realm = data.realm,
            class = data.class,
            currentGold = data.currentGold or 0,
            targetGold = data.targetGold or DEFAULT_TARGET,
            enabled = data.enabled ~= false,
            paused = data.paused or false,
            charType = data.charType,
            sortOrder = data.sortOrder or 0,
            added = data.added or 0
        }
    end
    return cache
end

function Data:GetCachedCharacters()
    return self:UpdateCharacterCache()
end

function Data:GetSortMode()
    if not db or not db.global then return "arrow" end
    return db.global.sortMode or "arrow"
end

function Data:SetSortMode(mode)
    if not db or not db.global then return end
    db.global.sortMode = mode
end

function Data:IsGuildMaster()
    local charID = GetCharacterFullName()
    
    if not db.guildMasterCache then
        db.guildMasterCache = {}
    end
    
    if db.guildMasterCache[charID] == false then
        return false
    end
    
    if db.guildMasterCache[charID] == true then
        local isStillGM = IsGuildLeader()
        if not isStillGM then
            db.guildMasterCache[charID] = false
        end
        return isStillGM
    end
    
    local isGM = IsGuildLeader()
    db.guildMasterCache[charID] = isGM
    
    return isGM
end

function Data:ResetGuildMasterCache()
    if db then
        db.guildMasterCache = {}
    end
end

function Data:GetGuildBankData(guildName)
    if not db or not db.guildBankData then return nil end
    return db.guildBankData[guildName]
end

function Data:SetGuildBankData(guildName, goldAmount)
    if not db then return end
    db.guildBankData = db.guildBankData or {}
    db.guildBankData[guildName] = {
        gold = goldAmount,
        lastUpdate = time(),
        realm = GetRealmName()
    }
end

function Data:ClearGuildBankData(guildName)
    if not db or not db.guildBankData then return end
    if guildName then
        db.guildBankData[guildName] = nil
    else
        db.guildBankData = {}
    end
end

function Data:AddGuildLedgerEntry(entry)
    if not db or not self:IsGuildMaster() then return end
    db.guildLedger = db.guildLedger or {}
    
    table.insert(db.guildLedger, 1, {
        timestamp = time(),
        player = entry.player or "Unknown",
        amount = entry.amount or 0,
        type = entry.type,
        years = entry.years or 0,
        months = entry.months or 0,
        days = entry.days or 0,
        hours = entry.hours or 0,
        note = entry.note or ""
    })
    
    if #db.guildLedger > 500 then
        for i = 501, #db.guildLedger do
            db.guildLedger[i] = nil
        end
    end
    
    if entry.type == "deposit" then
        db.guildSettings.totalGuildDeposited = (db.guildSettings.totalGuildDeposited or 0) + (entry.amount or 0)
    elseif entry.type == "withdraw" then
        db.guildSettings.totalGuildWithdrawn = (db.guildSettings.totalGuildWithdrawn or 0) + (entry.amount or 0)
    end
    
    db.guildSettings.lastScan = time()
end

function Data:GetGuildLedgerEntries(limit)
    if not db or not db.guildLedger then return {} end
    limit = limit or 50
    local entries = {}
    for i = 1, math.min(limit, #db.guildLedger) do
        table.insert(entries, db.guildLedger[i])
    end
    return entries
end

function Data:GetGuildLedgerStats()
    if not db or not db.guildSettings then return 0, 0, 0 end
    return db.guildSettings.totalGuildDeposited or 0, 
           db.guildSettings.totalGuildWithdrawn or 0,
           db.guildSettings.lastScan or 0
end

function Data:ClearGuildLedger()
    if not self:IsGuildMaster() then return end
    db.guildLedger = {}
    db.guildSettings.totalGuildDeposited = 0
    db.guildSettings.totalGuildWithdrawn = 0
end

function Data:ShouldShowGuildBankFeatures()
    return self:IsGuildMaster()
end

-- -- Weekly Income Tracking ----------------------------------------------------
-- Weekly Income = Bank balance now - Bank balance at last reset.
-- Both values come from the ledger's balanceAfter field -- no live API needed.
-- The most recent entry before the reset = balance at reset.
-- The most recent entry overall = current balance.

local KNOWN_RESET = {
    ["US"] = 1781618400,  -- Tue 2026-06-16 10:00 AM EDT
    ["EU"] = 1781604000,  -- Wed 2026-06-17 08:00 AM CEST
    ["KR"] = 1781564400,  -- Thu 2026-06-18 10:00 AM KST
    ["TW"] = 1781564400,
    ["CN"] = 1781564400,
}
local WEEK_SECONDS = 604800

local function GetCurrentResetTimestamp()
    local region = GetCurrentRegion and GetCurrentRegion() or nil
    local names  = { [1]="US", [2]="KR", [3]="EU", [4]="TW", [5]="CN" }
    local anchor = KNOWN_RESET[names[region] or ""] or KNOWN_RESET["US"]
    local now    = time()
    while anchor + WEEK_SECONDS <= now do anchor = anchor + WEEK_SECONDS end
    while anchor > now do anchor = anchor - WEEK_SECONDS end
    return anchor
end

function Data:GetWeeklyIncome()
    if not db or not db.ledger or #db.ledger == 0 then return 0 end
    local resetTS = GetCurrentResetTimestamp()

    -- Current balance = most recent ledger entry
    local balanceNow = db.ledger[1].balanceAfter or 0

    -- Balance at reset = most recent entry whose timestamp is <= resetTS
    local balanceAtReset = nil
    for _, entry in ipairs(db.ledger) do
        if entry.timestamp and entry.timestamp <= resetTS then
            balanceAtReset = entry.balanceAfter
            break
        end
    end

    if not balanceAtReset then return 0 end
    return balanceNow - balanceAtReset
end

function Data:GetWeeklyResetTimestamp()
    return GetCurrentResetTimestamp()
end

-- -----------------------------------------------------------------------------


function Data:GetCategoryName(charType)
    if not db or not db.global or not db.global.categoryNames then return charType end
    return db.global.categoryNames[charType] or charType
end

function Data:SetCategoryName(charType, name)
    if not db or not db.global then return end
    db.global.categoryNames = db.global.categoryNames or {}
    db.global.categoryNames[charType] = name or charType
end

function Data:GetAllCategoryKeys()
    return { "main", "mainAlt", "alt", "crafter", "auctioneer", "bankAlt" }
end

function Data:GetCurrentAddonVersion()
    return CURRENT_ADDON_VERSION
end

function Data:GetLastSeenVersion()
    if not db or not db.global then return "0.0.0" end
    return db.global.lastSeenVersion or "0.0.0"
end

function Data:SetLastSeenVersion(version)
    if db and db.global then
        db.global.lastSeenVersion = version
    end
end

function Data:DeleteCharacter(charID)
    if not db or not db.characters then return false, "Database not initialized" end
    
    -- Don't allow deleting the current character
    if charID == GetCharacterFullName() then
        return false, "Cannot delete current character"
    end
    
    -- Check if character exists
    if not db.characters[charID] then
        return false, "Character not found: " .. charID
    end
    
    -- Delete the character
    local charName = db.characters[charID].name or "Unknown"
    db.characters[charID] = nil
    
    -- Clear any session data
    if sessionData[charID] then
        sessionData[charID] = nil
    end
    
    return true, charName
end