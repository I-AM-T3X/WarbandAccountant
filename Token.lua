local ADDON_NAME, WarbandAccountant = ...

local Token = {}
WarbandAccountant.Token = Token

-- Main frame and locals
local frame = CreateFrame("Frame", "WBATokenPriceFrame", UIParent, "BackdropTemplate")
local labelText, priceText, priceIndicator
local updateTicker
local lastAlertTime = 0

local MIN_TIME_BETWEEN_RECORDS = 240 -- 4 minutes minimum between data points
local ALERT_COOLDOWN = 240 -- 4 minutes between chat alerts

local FREQUENCY_OPTIONS = {
    { text = "5 minutes",  value = 300  },
    { text = "10 minutes", value = 600  },
    { text = "20 minutes", value = 1200 },
    { text = "40 minutes", value = 2400 },
    { text = "60 minutes", value = 3600 },
}
Token.FREQUENCY_OPTIONS = FREQUENCY_OPTIONS

local DEFAULTS = {
    frameColor = {1, 1, 1, 1},
    textColor = {1, 0.82, 0, 1},
    iconSize = 30,
    displayType = "text",
    showArrow = true,
    alertEnabled = false,
    alertLowThreshold = nil,
    alertHighThreshold = nil,
    updateInterval = 300,
    showFloatingFrame = true,
}
Token.DEFAULTS = DEFAULTS

-- Utility: Format copper value using the shared Warband Accountant formatter
-- (gold/silver/copper, color-coded) so Token Price values look consistent
-- with the rest of the addon's stat cards and tooltips.
local function FormatGold(number)
    if not number then return "N/A" end
    return WarbandAccountant.FormatGold(number)
end
Token.FormatGold = FormatGold


-- Initialize saved variables
local function InitSettings()
    TokenPriceDisplayDB = TokenPriceDisplayDB or {}
    TokenPriceDisplaySettings = TokenPriceDisplaySettings or {}
    TokenPriceHistoryDB = TokenPriceHistoryDB or {}

    if not TokenPriceHistoryDB.prices then
        TokenPriceHistoryDB.prices = {}
    end

    for k, v in pairs(DEFAULTS) do
        if TokenPriceDisplaySettings[k] == nil then
            TokenPriceDisplaySettings[k] = v
        end
    end

    if type(TokenPriceDisplaySettings.frameColor) ~= "table" then
        TokenPriceDisplaySettings.frameColor = DEFAULTS.frameColor
    end
    if type(TokenPriceDisplaySettings.textColor) ~= "table" then
        TokenPriceDisplaySettings.textColor = DEFAULTS.textColor
    end
    if not TokenPriceDisplaySettings.updateInterval then
        TokenPriceDisplaySettings.updateInterval = DEFAULTS.updateInterval
    end
end

function Token:GetSettings()
    return TokenPriceDisplaySettings
end

function Token:GetHistory()
    return TokenPriceHistoryDB and TokenPriceHistoryDB.prices or {}
end

function Token:GetCurrentPrice()
    return C_WowTokenPublic.GetCurrentMarketPrice()
end

-- Records current price to history database with duplicate filtering
local function RecordPriceHistory(price)
    if not price then return end

    local now = time()
    local lastEntry = TokenPriceHistoryDB.prices[#TokenPriceHistoryDB.prices]

    if lastEntry then
        -- Hard guard: never record two entries at the exact same timestamp,
        -- regardless of price (covers ADDON_LOADED / login race conditions)
        if lastEntry.timestamp == now then
            return
        end

        local timeDiff = now - lastEntry.timestamp
        local priceDiff = math.abs(lastEntry.price - price)

        if timeDiff < MIN_TIME_BETWEEN_RECORDS and priceDiff <= 100000 then
            return
        end
    end

    local entry = { timestamp = now, price = price }
    table.insert(TokenPriceHistoryDB.prices, entry)

    while #TokenPriceHistoryDB.prices > 1008 do
        table.remove(TokenPriceHistoryDB.prices, 1)
    end

    local cutoff = time() - (7 * 24 * 60 * 60)
    while #TokenPriceHistoryDB.prices > 0 and TokenPriceHistoryDB.prices[1].timestamp < cutoff do
        table.remove(TokenPriceHistoryDB.prices, 1)
    end
end

function Token:ClearHistory()
    TokenPriceHistoryDB.prices = {}
end

-- One-time import from the standalone Token Price Display addon's
-- SavedVariables, if that addon's own .lua data file is still present
-- and loaded (e.g. the addon is installed but disabled).
-- Returns: importedCount, errorMessage
function Token:ImportLegacyHistory()
    -- The standalone addon used the exact same global names, so if it's
    -- still installed and its SavedVariables.lua was loaded into memory
    -- by a prior session, the data may already be sitting in these globals.
    -- This handles the case where WarbandAccountant's own init ran first
    -- and the legacy addon's data wasn't merged in.
    if not TokenPriceHistoryDB or not TokenPriceHistoryDB.prices then
        return 0, "No legacy Token Price Display data found in this session. Make sure the old addon is enabled at the character select screen at least once before importing, then log in and try again."
    end

    local existing = TokenPriceHistoryDB.prices
    if #existing == 0 then
        return 0, "Legacy data table found but it's empty."
    end

    -- Data is already in the same table WarbandAccountant reads from
    -- (both addons share the TokenPriceHistoryDB global), so there's
    -- nothing to copy -- just confirm it's populated and re-sort/dedupe.
    table.sort(existing, function(a, b) return a.timestamp < b.timestamp end)

    local deduped = {}
    local lastTs = nil
    for _, entry in ipairs(existing) do
        if entry.timestamp ~= lastTs then
            table.insert(deduped, entry)
            lastTs = entry.timestamp
        end
    end
    TokenPriceHistoryDB.prices = deduped

    return #deduped, nil
end

-- Removes near-duplicate entries that were recorded within a few seconds
-- of each other at the same price -- a relic of the old PLAYER_LOGIN /
-- ADDON_LOADED double-recording bug. Runs once automatically on login.
function Token:CleanupDuplicateHistory()
    if not TokenPriceHistoryDB or not TokenPriceHistoryDB.prices then return 0 end
    local data = TokenPriceHistoryDB.prices
    if #data < 2 then return 0 end

    table.sort(data, function(a, b) return a.timestamp < b.timestamp end)

    local cleaned = { data[1] }
    local removed = 0
    for i = 2, #data do
        local prev = cleaned[#cleaned]
        local cur = data[i]
        local within10Sec = (cur.timestamp - prev.timestamp) <= 10
        local samePrice = cur.price == prev.price
        if within10Sec and samePrice then
            removed = removed + 1
        else
            table.insert(cleaned, cur)
        end
    end

    TokenPriceHistoryDB.prices = cleaned
    return removed
end

-- -- Standalone floating price frame -----------------------------------------
local function SaveFramePosition()
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    if point then
        TokenPriceDisplayDB.point = point
        TokenPriceDisplayDB.relativePoint = relativePoint
        TokenPriceDisplayDB.xOfs = xOfs
        TokenPriceDisplayDB.yOfs = yOfs
    end
end

local function LoadFramePosition()
    if TokenPriceDisplayDB.point then
        frame:ClearAllPoints()
        frame:SetPoint(TokenPriceDisplayDB.point, UIParent, TokenPriceDisplayDB.relativePoint, TokenPriceDisplayDB.xOfs, TokenPriceDisplayDB.yOfs)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function SetupFrame()
    frame:SetSize(180, 40)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveFramePosition()
    end)

    frame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            WarbandAccountant.UI:Toggle("token")
        end
    end)

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("WoW Token Price")
        GameTooltip:AddLine("Right-click for history", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelText:SetPoint("LEFT", frame, "LEFT", 10, 0)
    labelText:SetText("WoW Token:")

    priceText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)
    priceText:SetTextColor(1, 1, 1)

    priceIndicator = frame:CreateTexture(nil, "OVERLAY")
    priceIndicator:SetSize(16, 16)
    priceIndicator:Hide()
end

local function AdjustFrameSize()
    if TokenPriceDisplaySettings.displayType == "icon" then
        local iconWidth = TokenPriceDisplaySettings.iconSize
        local textWidth = priceText:GetStringWidth()
        local width = 5 + iconWidth + 5 + textWidth + 10
        frame:SetWidth(width)
        frame:SetHeight(math.max(30, TokenPriceDisplaySettings.iconSize + 4))
    else
        local padding = 20
        local width = padding

        if labelText:IsShown() then
            width = width + labelText:GetStringWidth() + 5
        end

        width = width + priceText:GetStringWidth()

        if TokenPriceDisplaySettings.showArrow and priceIndicator:IsShown() then
            width = width + 5 + 16
        end

        frame:SetHeight(30)
        frame:SetWidth(math.max(120, width))
    end
end

local function ApplySettings()
    frame:SetBackdropBorderColor(unpack(TokenPriceDisplaySettings.frameColor))
    labelText:SetTextColor(unpack(TokenPriceDisplaySettings.textColor))

    if TokenPriceDisplaySettings.displayType == "icon" then
        labelText:Hide()
        priceIndicator:ClearAllPoints()
        priceIndicator:SetPoint("LEFT", frame, "LEFT", 5, 0)
        priceIndicator:SetTexture("Interface\\Icons\\wow_token01")
        priceIndicator:SetSize(TokenPriceDisplaySettings.iconSize, TokenPriceDisplaySettings.iconSize)
        priceIndicator:Show()

        priceText:ClearAllPoints()
        priceText:SetPoint("LEFT", priceIndicator, "RIGHT", 5, 0)
    else
        labelText:Show()
        priceText:ClearAllPoints()
        priceText:SetPoint("LEFT", labelText, "RIGHT", 5, 0)

        priceIndicator:ClearAllPoints()
        priceIndicator:SetPoint("LEFT", priceText, "RIGHT", 5, 0)
    end

    if not TokenPriceDisplaySettings.showArrow then
        priceIndicator:Hide()
    end

    if TokenPriceDisplaySettings.showFloatingFrame == false then
        frame:Hide()
    else
        frame:Show()
    end

    AdjustFrameSize()
end
Token.ApplySettings = ApplySettings

function Token:ShowColorPicker(colorType)
    local settings = TokenPriceDisplaySettings
    local color = colorType == "frame" and settings.frameColor or settings.textColor
    local r, g, b, a = unpack(color)
    local originalColor = {r, g, b, a}

    local function OnColorChanged()
        local newR, newG, newB = ColorPickerFrame:GetColorRGB()
        local newA = ColorPickerFrame:GetColorAlpha()

        if colorType == "frame" then
            settings.frameColor = {newR, newG, newB, newA}
        else
            settings.textColor = {newR, newG, newB, newA}
        end
        ApplySettings()
    end

    local function OnCancel()
        if colorType == "frame" then
            settings.frameColor = originalColor
        else
            settings.textColor = originalColor
        end
        ApplySettings()
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        swatchFunc = OnColorChanged,
        opacityFunc = OnColorChanged,
        cancelFunc = OnCancel,
        hasOpacity = true,
        opacity = a,
        r = r, g = g, b = b,
    })
end

function Token:ResetToDefaultColors()
    TokenPriceDisplaySettings.frameColor = {unpack(DEFAULTS.frameColor)}
    TokenPriceDisplaySettings.textColor = {unpack(DEFAULTS.textColor)}
    ApplySettings()
end

local function CheckAlerts(currentGold)
    if not TokenPriceDisplaySettings.alertEnabled then return end

    local now = time()
    if now - lastAlertTime < ALERT_COOLDOWN then
        return
    end

    local low = TokenPriceDisplaySettings.alertLowThreshold
    local high = TokenPriceDisplaySettings.alertHighThreshold
    local alerted = false

    if low and currentGold <= low then
        print(string.format("|cffff0000[Token Alert]: WoW Token price is %s! (Below threshold: %s)|r",
            FormatGold(currentGold * 10000), FormatGold(low * 10000)))
        alerted = true
    end

    if high and currentGold >= high then
        print(string.format("|cff00ff00[Token Alert]: WoW Token price is %s! (Above threshold: %s)|r",
            FormatGold(currentGold * 10000), FormatGold(high * 10000)))
        alerted = true
    end

    if alerted then
        lastAlertTime = now
    end
end

local function UpdateTokenPrice()
    local price = C_WowTokenPublic.GetCurrentMarketPrice()

    if not price then
        if priceText then
            priceText:SetText("Loading...")
            priceIndicator:Hide()
            AdjustFrameSize()
        end
        return
    end

    local goldPrice = math.floor(price / 10000)
    priceText:SetText(FormatGold(price))

    RecordPriceHistory(price)

    local lastPrice = TokenPriceDisplaySettings.lastKnownPrice
    if lastPrice and TokenPriceDisplaySettings.showArrow and TokenPriceDisplaySettings.displayType ~= "icon" then
        if goldPrice > lastPrice then
            priceIndicator:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            priceIndicator:SetVertexColor(0, 1, 0)
        elseif goldPrice < lastPrice then
            priceIndicator:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            priceIndicator:SetVertexColor(1, 0, 0)
        else
            priceIndicator:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            priceIndicator:SetVertexColor(1, 1, 1)
        end
        priceIndicator:Show()
    elseif TokenPriceDisplaySettings.displayType == "icon" then
        priceIndicator:SetTexture("Interface\\Icons\\wow_token01")
        priceIndicator:SetVertexColor(1, 1, 1)
        priceIndicator:Show()
    elseif not TokenPriceDisplaySettings.showArrow then
        priceIndicator:Hide()
    end

    TokenPriceDisplaySettings.lastKnownPrice = goldPrice
    AdjustFrameSize()
    CheckAlerts(goldPrice)

    -- Notify UI to refresh Overview card / Token History tab if visible
    if WarbandAccountant.UI and WarbandAccountant.UI.OnTokenPriceUpdated then
        WarbandAccountant.UI:OnTokenPriceUpdated()
    end
end
Token.UpdateTokenPrice = UpdateTokenPrice

function Token:RestartTicker()
    if updateTicker then
        updateTicker:Cancel()
    end

    local interval = TokenPriceDisplaySettings.updateInterval or 300
    updateTicker = C_Timer.NewTicker(interval, function()
        C_WowTokenPublic.UpdateMarketPrice()
    end)
end

function Token:SetShowFloatingFrame(show)
    TokenPriceDisplaySettings.showFloatingFrame = show
    if show then frame:Show() else frame:Hide() end
end

-- -- Event handling -----------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        InitSettings()
        SetupFrame()
        LoadFramePosition()
        ApplySettings()
        C_WowTokenPublic.UpdateMarketPrice()

    elseif event == "PLAYER_LOGIN" then
        LoadFramePosition()
        ApplySettings()

        lastAlertTime = time()

        if not updateTicker then
            local interval = TokenPriceDisplaySettings.updateInterval or 300
            updateTicker = C_Timer.NewTicker(interval, function()
                C_WowTokenPublic.UpdateMarketPrice()
            end)
        end

        -- Clean up any near-duplicate entries from the old double-recording bug
        Token:CleanupDuplicateHistory()

    elseif event == "PLAYER_LOGOUT" then
        SaveFramePosition()

    elseif event == "TOKEN_MARKET_PRICE_UPDATED" then
        UpdateTokenPrice()
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("TOKEN_MARKET_PRICE_UPDATED")
