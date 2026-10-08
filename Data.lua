local ADDON_NAME, WarbandAccountant = ...

local Data = {}
WarbandAccountant.Data = Data

local DEFAULT_TARGET = 1000000
local CURRENT_DB_VERSION = 1
local CURRENT_ADDON_VERSION = "2.3.0"

local db = nil

local function GetCharacterFullName()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

function Data:Init()
    local isBrandNewInstall = (WarbandAccountantDB == nil)

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
    db.global.uiScalePercent = db.global.uiScalePercent or 100
    db.global.language = db.global.language or GetLocale()
    if db.global.thousandsSeparator == nil then
        db.global.thousandsSeparator = ","
    end
    if WarbandAccountant.ApplyLocale then
        WarbandAccountant:ApplyLocale(db.global.language)
    end

    -- Only true brand-new installs get the automatic first-run tutorial.
    -- Anyone updating from an earlier version already has WarbandAccountantDB,
    -- so they're marked as having seen it (they can still replay with /wba tutorial).
    if db.global.tutorialSeen == nil then
        db.global.tutorialSeen = not isBrandNewInstall
    end
    
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
    db.accountTotalHistory = db.accountTotalHistory or {}
    
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
    
end

function Data:UpdateCharacterGold()
    local charID = GetCharacterFullName()
    if not db or not db.characters or not db.characters[charID] then return end
    
    local currentGold = GetMoney()
    db.characters[charID].currentGold = currentGold
    db.characters[charID].lastUpdate = time()

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
    
    if #db.ledger > 5000 then
        for i = 5001, #db.ledger do
            db.ledger[i] = nil
        end
    end
    
    local amt = entry.amount or 0
    if entry.type == "DEPOSIT" or entry.type == "MANUAL_DEPOSIT" then
        db.global.totalDeposited = (db.global.totalDeposited or 0) + amt
    elseif entry.type == "WITHDRAW" or entry.type == "MANUAL_WITHDRAW" then
        db.global.totalWithdrawn = (db.global.totalWithdrawn or 0) + amt
    end
    -- Let goals / the token frame's weekly line react to the new balance
    if WarbandAccountant.OnWarbandBalanceChanged then
        WarbandAccountant.OnWarbandBalanceChanged(entry.balanceAfter or 0)
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

-- Sentinel used to select "Account Total" (Warband Bank + every character's
-- current gold, snapshotted over time) as opposed to nil (Warband Bank only)
-- or a real character ID (that character's net Warband Bank contribution).
WarbandAccountant.ACCOUNT_TOTAL_KEY = "__ACCOUNT_TOTAL__"

-- Returns {timestamp, value} points, oldest first, for the Gold History
-- graph.
--
-- charID == nil: Warband Bank total over time -- built entirely from
-- existing Ledger data (each entry already records the exact balance
-- after that transaction), no separate tracking needed.
--
-- charID == WarbandAccountant.ACCOUNT_TOTAL_KEY: Warband Bank + every
-- character's current gold, over time. Unlike the other two modes this
-- can't be derived from existing data (the addon never logged historical
-- on-hand gold), so it's built from a separate periodic snapshot -- see
-- Data:RecordAccountTotalSnapshot. History only exists from whenever that
-- started running.
--
-- charID given (anything else): that character's cumulative net Warband
-- Bank contribution over time (running sum of their own deposits minus
-- withdrawals). This is NOT their personal on-hand gold -- the addon has
-- never logged that historically, only the live current value.
function Data:GetBalanceHistory(charID)
    if charID == WarbandAccountant.ACCOUNT_TOTAL_KEY then
        return self:GetAccountTotalHistory()
    end

    if not db or not db.ledger then return {} end

    local points = {}
    if not charID then
        -- db.ledger is newest-first; walk backwards for oldest-first output
        for i = #db.ledger, 1, -1 do
            local e = db.ledger[i]
            table.insert(points, { timestamp = e.timestamp, value = e.balanceAfter or 0, entry = e })
        end
    else
        local running = 0
        for i = #db.ledger, 1, -1 do
            local e = db.ledger[i]
            if e.character == charID then
                local sign = (e.type == "DEPOSIT" or e.type == "MANUAL_DEPOSIT") and 1 or -1
                running = running + sign * (e.amount or 0)
                table.insert(points, { timestamp = e.timestamp, value = running, entry = e })
            end
        end
    end
    return points
end

-- Current Account Total: Warband Bank gold + every tracked character's
-- current on-hand gold. A live number, always available with no history
-- needed.
function Data:GetAccountTotal()
    local warband = (WarbandAccountant.Core and WarbandAccountant.Core:GetWarbandGold()) or 0
    return warband + self:GetTotalTrackedGold()
end

-- Periodic snapshot store for the Account Total history graph. Capped like
-- the Ledger; a fresh install naturally has a short history that builds up
-- over time, since this can't be derived retroactively from existing data.
local ACCOUNT_TOTAL_HISTORY_CAP = 3000

function Data:RecordAccountTotalSnapshot()
    if not db then return end
    db.accountTotalHistory = db.accountTotalHistory or {}
    table.insert(db.accountTotalHistory, 1, {
        timestamp = time(),
        value = self:GetAccountTotal(),
    })
    if #db.accountTotalHistory > ACCOUNT_TOTAL_HISTORY_CAP then
        for i = ACCOUNT_TOTAL_HISTORY_CAP + 1, #db.accountTotalHistory do
            db.accountTotalHistory[i] = nil
        end
    end
end

function Data:GetAccountTotalHistory()
    if not db or not db.accountTotalHistory then return {} end
    local points = {}
    -- newest-first in storage; walk backwards for oldest-first output
    for i = #db.accountTotalHistory, 1, -1 do
        local e = db.accountTotalHistory[i]
        table.insert(points, { timestamp = e.timestamp, value = e.value or 0 })
    end
    return points
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
    if not db then return end
    db.guildBankData = db.guildBankData or {}
    if guildName then
        db.guildBankData[guildName] = nil
        if db.global and db.global.homeGuild == guildName then
            db.global.homeGuild = nil
        end
    else
        db.guildBankData = {}
        if db.global then
            db.global.homeGuild = nil
        end
    end
end

-- The "home guild" is a user-chosen guild bank to always display on the
-- Overview tab, regardless of which guild the current character is in.
-- Falls back to the current character's own guild when unset (see
-- Core:GetPersonalGuildBankGold).
function Data:GetHomeGuild()
    if not db or not db.global then return nil end
    return db.global.homeGuild
end

function Data:SetHomeGuild(guildName)
    if not db then return end
    db.global = db.global or {}
    db.global.homeGuild = guildName
end

-- Returns a sorted list of every guild name we have cached bank data for
-- (i.e. every guild a character has synced as Guild Master at some point).
function Data:GetKnownGuildNames()
    if not db or not db.guildBankData then return {} end
    local names = {}
    for name, _ in pairs(db.guildBankData) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Returns { {name, gold, realm, lastUpdate}, ... } for every guild bank
-- we've synced, sorted alphabetically by guild name.
function Data:GetAllGuildBankData()
    if not db or not db.guildBankData then return {} end
    local list = {}
    for name, data in pairs(db.guildBankData) do
        table.insert(list, {
            name       = name,
            gold       = data.gold or 0,
            realm      = data.realm,
            lastUpdate = data.lastUpdate,
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Sum of gold across every synced guild bank, regardless of realm.
function Data:GetTotalGuildBankGold()
    if not db or not db.guildBankData then return 0 end
    local total = 0
    for _, data in pairs(db.guildBankData) do
        total = total + (data.gold or 0)
    end
    return total
end






-- -- Weekly Income Tracking ----------------------------------------------------
-- Weekly Income = Bank balance now - Bank balance at last reset.
-- Both values come from the ledger's balanceAfter field -- no live API needed.
-- The most recent entry before the reset = balance at reset.
-- The most recent entry overall = current balance.

local WEEK_SECONDS = 604800

-- Old fallback anchors, kept only in case C_DateAndTime.GetSecondsUntilWeeklyReset
-- is ever unavailable (it's been in the API since patch 9.0.1 / 2020, so this
-- should never actually trigger on a modern client).
local KNOWN_RESET = {
    ["US"] = 1781618400,  -- Tue 2026-06-16 10:00 AM EDT
    ["EU"] = 1781604000,  -- Wed 2026-06-17 08:00 AM CEST
    ["KR"] = 1781564400,  -- Thu 2026-06-18 10:00 AM KST
    ["TW"] = 1781564400,
    ["CN"] = 1781564400,
}

local function GetCurrentResetTimestamp()
    -- Server-authoritative: correct for every region automatically, no
    -- region-detection or hardcoded schedule needed. This replaced a
    -- per-region anchor table that silently fell back to the US (Tuesday)
    -- schedule whenever GetCurrentRegion() didn't resolve as expected --
    -- notably wrong for China's separately-operated client.
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local now = GetServerTime and GetServerTime() or time()
        local secondsUntilReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secondsUntilReset and secondsUntilReset >= 0 then
            return now + secondsUntilReset - WEEK_SECONDS
        end
    end

    -- Fallback (see comment above)
    local region = GetCurrentRegion and GetCurrentRegion() or nil
    local names  = { [1]="US", [2]="KR", [3]="EU", [4]="TW", [5]="CN" }
    local anchor = KNOWN_RESET[names[region] or ""] or KNOWN_RESET["US"]
    local now    = GetServerTime and GetServerTime() or time()
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

    if not balanceAtReset then
        -- No entry predates this week's reset -- e.g. a brand new install,
        -- or the ledger cap trimmed off everything older. Rather than
        -- reporting 0 (which would hide real activity), use the balance
        -- just BEFORE the oldest entry we do have as the baseline. Since
        -- every stored entry is newer than the reset in this branch, that
        -- oldest entry is itself from this week, so this correctly reflects
        -- all the income we actually know about.
        local oldest = db.ledger[#db.ledger]
        if not oldest then return 0 end
        local sign = (oldest.type == "DEPOSIT" or oldest.type == "MANUAL_DEPOSIT") and 1 or -1
        balanceAtReset = (oldest.balanceAfter or 0) - sign * (oldest.amount or 0)
    end

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

function Data:HasSeenTutorial()
    if not db or not db.global then return true end
    return db.global.tutorialSeen == true
end

function Data:SetTutorialSeen(seen)
    if not db then return end
    db.global = db.global or {}
    db.global.tutorialSeen = seen and true or false
end

-- Window scale, stored as a whole-number percent (50-300, step 10; 100 = default).
function Data:GetUIScale()
    if not db or not db.global then return 100 end
    return db.global.uiScalePercent or 100
end

function Data:SetUIScale(percent)
    if not db then return end
    db.global = db.global or {}
    db.global.uiScalePercent = percent
end

-- Player's chosen UI language (locale code, e.g. "enUS", "zhCN"). Falls back
-- to their client locale until they've picked one explicitly.
function Data:GetLanguage()
    if not db or not db.global then return GetLocale() end
    return db.global.language or GetLocale()
end

function Data:SetLanguage(code)
    if not db then return end
    db.global = db.global or {}
    db.global.language = code
    if WarbandAccountant.ApplyLocale then
        WarbandAccountant:ApplyLocale(code)
    end
end

-- Thousands separator for gold amounts: "," or "." or "" (none).
function Data:GetThousandsSeparator()
    if not db or not db.global then return "," end
    return db.global.thousandsSeparator or ","
end

function Data:SetThousandsSeparator(sep)
    if not db then return end
    db.global = db.global or {}
    db.global.thousandsSeparator = sep
end

-- Whether to auto-open the Changelog tab when a new version is detected.
function Data:GetShowUpdateChangelog()
    if not db or not db.global then return true end
    return db.global.showUpdateChangelog ~= false
end

function Data:SetShowUpdateChangelog(show)
    if not db then return end
    db.global = db.global or {}
    db.global.showUpdateChangelog = show
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
    
    
    return true, charName
end