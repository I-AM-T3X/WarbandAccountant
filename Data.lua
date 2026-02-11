local ADDON_NAME, WarbandAccountant = ...

local Data = {}
WarbandAccountant.Data = Data

local DEFAULT_TARGET = 1000000
local CURRENT_DB_VERSION = 1

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
    
    -- NEW: Running totals for ledger (persist beyond 500 entries)
    db.global.totalDeposited = db.global.totalDeposited or 0
    db.global.totalWithdrawn = db.global.totalWithdrawn or 0
    
    db.global.mainDefault = db.global.mainDefault or (100 * 10000)
    db.global.mainAltDefault = db.global.mainAltDefault or (100 * 10000)
    db.global.altDefault = db.global.altDefault or (100 * 10000)
    
    if db.global.minimapAngle then
        db.global.minimapPos = db.global.minimapAngle
        db.global.minimapAngle = nil
    end
    
    db.global.minimapPos = db.global.minimapPos or 195
    db.global.hide = db.global.hide or false
    
    db.characters = db.characters or {}
    db.ledger = db.ledger or {}
    
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
    if charType == "main" then
        return db.global.mainDefault or 1000000
    elseif charType == "mainAlt" then
        return db.global.mainAltDefault or 1000000
    elseif charType == "alt" then
        return db.global.altDefault or 1000000
    end
    return 1000000
end

function Data:SetDefaultTarget(charType, amount)
    if not db then return end
    amount = math.max(0, tonumber(amount) or 0)
    db.global = db.global or {}
    if charType == "main" then
        db.global.mainDefault = amount
    elseif charType == "mainAlt" then
        db.global.mainAltDefault = amount
    elseif charType == "alt" then
        db.global.altDefault = amount
    end
end

function Data:GetCharacterType(charID)
    charID = charID or GetCharacterFullName()
    if not db or not db.characters then return nil end
    return db.characters[charID] and db.characters[charID].charType
end

function Data:SetCharacterType(charID, charType)
    charID = charID or GetCharacterFullName()
    if not db or not db.characters or not db.characters[charID] then return end
    
    if charType ~= "main" and charType ~= "mainAlt" and charType ~= "alt" then
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
    
    -- Add to ledger (with 500 limit for display)
    table.insert(db.ledger, 1, {
        timestamp = time(),
        character = entry.character or GetCharacterFullName(),
        characterName = entry.characterName or UnitName("player"),
        realm = entry.realm or GetRealmName(),
        amount = entry.amount or 0,
        type = entry.type,
        balanceAfter = entry.balanceAfter or 0,
        note = entry.note or ""
    })
    
    -- Keep only last 500 for display
    if #db.ledger > 500 then
        for i = 501, #db.ledger do
            db.ledger[i] = nil
        end
    end
    
    -- NEW: Update running totals (these persist forever)
    if entry.type == "DEPOSIT" or entry.type == "MANUAL_DEPOSIT" then
        db.global.totalDeposited = (db.global.totalDeposited or 0) + (entry.amount or 0)
    elseif entry.type == "WITHDRAW" or entry.type == "MANUAL_WITHDRAW" then
        db.global.totalWithdrawn = (db.global.totalWithdrawn or 0) + (entry.amount or 0)
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
    -- Use stored running totals instead of calculating from pruned array
    if not db or not db.global then return 0, 0 end
    
    return db.global.totalDeposited or 0, db.global.totalWithdrawn or 0
end

function Data:ClearLedger()
    db.ledger = {}
    -- Optionally reset totals too? Uncomment if desired:
    -- db.global.totalDeposited = 0
    -- db.global.totalWithdrawn = 0
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