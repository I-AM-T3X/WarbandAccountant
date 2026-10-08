local ADDON_NAME, WarbandAccountant = ...

--[[
Warband Accountant -- Goals
Shared "spare gold" math used by Token Affordability and the Savings Goal.

Spare gold = the Warband Bank balance only. Gold on characters is their
working capital (their targets), so it never counts here.

Earning rate = how fast the Warband Bank has grown over the last 28 days
(or however much history exists, minimum 1 day). Both the "next token"
estimate and the goal's finish estimate use it.
]]

local Goals = {}
WarbandAccountant.Goals = Goals

local DAY = 86400
local WEEK = 7 * DAY
local RATE_WINDOW   = 28 * DAY
local RATE_MIN_SPAN = DAY

local function GetDB()
    local Data = WarbandAccountant.Data
    return Data and Data:GetDB()
end

-- -- Spare gold + earning rate ------------------------------------------------

function Goals:GetSpareGold()
    local Core = WarbandAccountant.Core
    return (Core and Core:GetWarbandGold()) or 0
end

-- Copper per second the Warband Bank has grown recently, or nil when there
-- isn't at least a day of history to judge by.
function Goals:GetIncomeRate(balanceNow)
    local history = WarbandAccountant.Data:GetBalanceHistory(nil)  -- oldest first
    if #history == 0 then return nil end

    local now = time()
    local span = math.min(RATE_WINDOW, now - history[1].timestamp)
    if span < RATE_MIN_SPAN then return nil end

    local startTS = now - span
    local startBalance = history[1].value
    for i = #history, 1, -1 do
        if history[i].timestamp <= startTS then
            startBalance = history[i].value
            break
        end
    end

    balanceNow = balanceNow or self:GetSpareGold()
    return (balanceNow - startBalance) / span
end

-- Seconds until the Warband Bank reaches `amount` at the current earning
-- rate. 0 if already there, nil if the bank isn't growing (or no history).
function Goals:GetSecondsToAmount(amount, balance)
    balance = balance or self:GetSpareGold()
    local remaining = amount - balance
    if remaining <= 0 then return 0 end
    local rate = self:GetIncomeRate(balance)
    if not rate or rate <= 0 then return nil end
    return remaining / rate
end

-- Days or weeks for the savings goal estimate (a Settings choice; the
-- Overview token card always uses days). Kept outside the goal itself so
-- the choice survives clearing and setting new goals.
function Goals:GetETAUnit()
    local db = GetDB()
    return (db and db.global and db.global.goalETAUnit == "weeks") and "weeks" or "days"
end

function Goals:SetETAUnit(unit)
    local db = GetDB()
    if not db then return end
    db.global = db.global or {}
    db.global.goalETAUnit = (unit == "weeks") and "weeks" or "days"
    self:NotifyChanged()
end

-- Long form for the Goals tab: "About 12 days to go" / "About 2 weeks to go"
function Goals:FormatETA(seconds)
    local L = WarbandAccountant.L
    if not seconds then return L.ETA_OFF_TRACK end
    if self:GetETAUnit() == "weeks" then
        -- Under a week gets its own wording. Weeks round to the NEAREST week
        -- (days round up): rounding up would turn 8 days into "2 weeks" and
        -- make "About 1 week" almost impossible to ever show.
        if seconds < WEEK then return L.ETA_LESS_THAN_WEEK end
        local weeks = math.max(1, math.floor(seconds / WEEK + 0.5))
        if weeks == 1 then return L.ETA_ONE_WEEK end
        return string.format(L.ETA_WEEKS, weeks)
    end
    if seconds < DAY then return L.ETA_LESS_THAN_DAY end
    local days = math.ceil(seconds / DAY)
    if days == 1 then return L.ETA_ONE_DAY end
    return string.format(L.ETA_DAYS, days)
end

-- Short form for small spaces: "~12 days"
function Goals:FormatETAShort(seconds)
    local L = WarbandAccountant.L
    if not seconds then return nil end
    if seconds < DAY then return L.ETA_SHORT_LESS_THAN_DAY end
    local days = math.ceil(seconds / DAY)
    if days == 1 then return L.ETA_SHORT_ONE_DAY end
    return string.format(L.ETA_SHORT_DAYS, days)
end

-- -- Token affordability ------------------------------------------------------

-- Returns count, secondsToNext, price  (nil if the token price isn't known yet)
function Goals:GetTokenAffordability()
    local Token = WarbandAccountant.Token
    local price = Token and Token:GetCurrentPrice()
    if not price or price <= 0 then return nil end
    local spare = self:GetSpareGold()
    local count = math.max(0, math.floor(spare / price))
    local secondsToNext = self:GetSecondsToAmount((count + 1) * price, spare)
    return count, secondsToNext, price
end

-- -- Savings goal ---------------------------------------------------------------
-- Stored as db.global.savingsGoal = { name, amount, useToken, created, notified }
-- One goal at a time; nil means no goal.

function Goals:GetGoal()
    local db = GetDB()
    return db and db.global and db.global.savingsGoal
end

-- The goal's current amount in copper (live token price for token goals),
-- or nil if it can't be known yet.
function Goals:GetGoalAmount(goal)
    goal = goal or self:GetGoal()
    if not goal then return nil end
    if goal.useToken then
        local Token = WarbandAccountant.Token
        local price = Token and Token:GetCurrentPrice()
        if price and price > 0 then return price end
        return nil
    end
    if goal.amount and goal.amount > 0 then return goal.amount end
    return nil
end

-- -- End date -------------------------------------------------------------------
-- Optional goal.endDate: a timestamp for 11:59:59 PM local time on the
-- chosen day. nil = no deadline.

function Goals:MakeEndOfDay(year, month, day)
    return time({ year = year, month = month, day = day, hour = 23, min = 59, sec = 59 })
end

function Goals:DaysInMonth(year, month)
    -- day 0 of the next month = last day of this one
    return tonumber(date("%d", time({ year = year, month = month + 1, day = 0, hour = 12 })))
end

-- Sets or clears (nil) the end date. Doesn't re-arm the chat message.
function Goals:SetEndDate(ts)
    local goal = self:GetGoal()
    if not goal or goal.endDate == ts then return end
    goal.endDate = ts
    self:NotifyChanged()
end

-- Copper per second needed to reach `amount` by the deadline, or nil when
-- there's no deadline, it has passed, or the goal is already met.
function Goals:GetRequiredRate(goal, amount, balance)
    if not goal or not goal.endDate or not amount then return nil end
    local remaining = amount - balance
    local timeLeft = goal.endDate - time()
    if remaining <= 0 or timeLeft <= 0 then return nil end
    return remaining / timeLeft
end

-- "49,000g per day" / "343,000g per week", following the Days/Weeks setting.
-- Rounded up to whole gold so it never understates what's needed.
function Goals:FormatPerPeriod(ratePerSecond)
    local L = WarbandAccountant.L
    local weeks = self:GetETAUnit() == "weeks"
    local copper = ratePerSecond * (weeks and WEEK or DAY)
    local gold = math.ceil(copper / 10000) * 10000
    -- Whole gold only: the silver/copper would always read "00s 00c" here
    local str = WarbandAccountant.FormatGold(gold):gsub(" |cFFC7C7C7%d+s|r |cFFEDA55F%d+c|r$", "")
    return string.format(weeks and L.GOAL_PER_WEEK or L.GOAL_PER_DAY, str)
end

local function StartOfDay(ts)
    local t = date("*t", ts)
    return time({ year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0 })
end

-- Calendar days from today to the end date: "45 days left" for a date 45
-- days out, "1 day left" for tomorrow, "last day" on the day itself.
function Goals:FormatTimeLeft(endDate)
    local L = WarbandAccountant.L
    -- +0.5 absorbs daylight-saving hour shifts
    local days = math.floor((StartOfDay(endDate) - StartOfDay(time())) / DAY + 0.5)
    if days <= 0 then return L.GOAL_LAST_DAY end
    if days == 1 then return L.GOAL_ONE_DAY_LEFT end
    return string.format(L.GOAL_DAYS_LEFT, days)
end

-- Creates the goal if needed and applies changes. A new goal, or a changed
-- amount / token setting, re-arms the one-time "Goal Met" chat message.
function Goals:UpdateGoal(fields)
    local db = GetDB()
    if not db then return end
    db.global = db.global or {}
    local goal = db.global.savingsGoal
    local changed, rearm = false, false
    if not goal then
        goal = { name = WarbandAccountant.L.SETTINGS_GOAL_DEFAULT_NAME, amount = 0, useToken = false, created = time() }
        db.global.savingsGoal = goal
        changed, rearm = true, true
    end
    for k, v in pairs(fields) do
        if goal[k] ~= v then
            goal[k] = v
            changed = true
            -- A new target re-arms the "Goal Met" message; a rename or a
            -- new end date doesn't
            if k == "amount" or k == "useToken" then rearm = true end
        end
    end
    -- Saving with nothing actually different (e.g. clicking out of an
    -- unchanged box) changes nothing.
    if not changed then return end
    if rearm then goal.notified = false end
    self:Check()
    self:NotifyChanged()
end

function Goals:ClearGoal()
    local db = GetDB()
    if db and db.global then db.global.savingsGoal = nil end
    self:NotifyChanged()
end

-- Prints the one-time chat message when the Warband Bank reaches the goal.
function Goals:Check(balance)
    local goal = self:GetGoal()
    if not goal or goal.notified then return end
    local amount = self:GetGoalAmount(goal)
    if not amount then return end
    balance = balance or self:GetSpareGold()
    if balance >= amount then
        goal.notified = true
        local L = WarbandAccountant.L
        print(L.MSG_PREFIX_GREEN .. L.GOAL_MET_CHAT)
    end
end

function Goals:NotifyChanged()
    local UI = WarbandAccountant.UI
    if UI and UI.OnGoalsChanged then UI:OnGoalsChanged() end
end

-- -- Hooks ------------------------------------------------------------------------
-- Data:AddLedgerEntry calls this after every Warband Bank transaction, so the
-- goal check and the token frame's weekly line stay current.
function WarbandAccountant.OnWarbandBalanceChanged(balanceAfter)
    Goals:Check(balanceAfter)
    local Token = WarbandAccountant.Token
    if Token and Token.UpdateWeeklyLine then Token:UpdateWeeklyLine() end
    Goals:NotifyChanged()
end
