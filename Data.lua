local ADDON_NAME, WarbandAccountant = ...

local Data = {}
WarbandAccountant.Data = Data

local DEFAULT_TARGET = 1000000
local CURRENT_DB_VERSION = 1

local db = nil
local sessionData = {} -- Volatile - resets on login

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
    
    -- LibDBIcon settings compatibility
    -- Migrate from old minimapAngle to new minimapPos if needed
    if db.global.minimapAngle then
        db.global.minimapPos = db.global.minimapAngle
        db.global.minimapAngle = nil
    end
    
    db.global.minimapPos = db.global.minimapPos or 195
    db.global.hide = db.global.hide or false
    
    db.characters = db.characters or {}
    
    local charID = GetCharacterFullName()
    if not db.characters[charID] then
        db.characters[charID] = {
            name = UnitName("player"),
            realm = GetRealmName(),
            class = select(2, UnitClass("player")),
            targetGold = DEFAULT_TARGET,
            enabled = true,
            added = time(),
        }
    end
    
    -- Initialize session data for this character
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
    if not db.characters[charID] then return end
    
    local currentGold = GetMoney()
    db.characters[charID].currentGold = currentGold
    db.characters[charID].lastUpdate = time()
    
    -- Update session tracking
    self:InitSessionData(charID)
    sessionData[charID].lastGold = currentGold
end

function Data:GetSessionChange(charID)
    charID = charID or GetCharacterFullName()
    if not sessionData[charID] then return 0 end
    
    local startGold = sessionData[charID].startGold or 0
    local currentGold = db.characters[charID] and db.characters[charID].currentGold or 0
    
    return currentGold - startGold
end

function Data:GetTotalSessionChange()
    local total = 0
    for charID, _ in pairs(db.characters) do
        total = total + self:GetSessionChange(charID)
    end
    return total
end

function Data:ResetSession(charID)
    charID = charID or GetCharacterFullName()
    if db.characters[charID] then
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
    return db.characters[charID]
end

function Data:SetCharacterTarget(charID, amount)
    charID = charID or GetCharacterFullName()
    if db.characters[charID] then
        db.characters[charID].targetGold = math.max(0, tonumber(amount) or 0)
    end
end

function Data:GetAllCharacters()
    return db.characters
end

function Data:GetTotalTrackedGold()
    local total = 0
    for _, data in pairs(db.characters) do
        if data.currentGold then
            total = total + data.currentGold
        end
    end
    return total
end

function Data:GetSettings()
    return db.global
end

function Data:GetDB()
    return db
end

function Data:IsAutoDepositEnabled()
    local charData = self:GetCharacterData()
    return db.global.autoDeposit and (charData and charData.enabled ~= false)
end

function Data:IsAutoWithdrawEnabled()
    local charData = self:GetCharacterData()
    return db.global.autoWithdraw and (charData and charData.enabled ~= false)
end

function Data:IsConfirmationRequired()
    return db.global.confirmTransfers
end

function Data:UpdateCharacterCache()
    local cache = {}
    for id, data in pairs(db.characters) do
        cache[id] = {
            name = data.name,
            realm = data.realm,
            class = data.class,
            currentGold = data.currentGold or 0,
            targetGold = data.targetGold or DEFAULT_TARGET,
            enabled = data.enabled ~= false,
            added = data.added or 0
        }
    end
    return cache
end

function Data:GetCachedCharacters()
    return self:UpdateCharacterCache()
end