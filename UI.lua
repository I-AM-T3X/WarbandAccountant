local ADDON_NAME, WarbandAccountant = ...
local UI = {}
WarbandAccountant.UI = UI

-- -- Constants -----------------------------------------------------------------
local NAV_W         = 150
local WIN_W         = 1100
local WIN_H         = 660
local CONTENT_W     = WIN_W - NAV_W - 28
local CONTENT_H     = WIN_H - 54
local NAV_BTN_H     = 40
local ROW_H         = 28

local COLOR_GOLD    = { r=1,    g=0.82, b=0    }
local COLOR_GREEN   = { r=0.2,  g=1,    b=0.2  }
local COLOR_RED     = { r=1,    g=0.3,  b=0.3  }
local COLOR_GREY    = { r=0.6,  g=0.6,  b=0.6  }
local COLOR_WHITE   = { r=1,    g=1,    b=1    }


-- -- State ---------------------------------------------------------------------
local mainFrame        = nil
local activeTab        = "overview"
local ledgerCharFilter = nil
local minimapLDB       = nil

local hasLibDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local hasLDB       = LibStub and LibStub("LibDataBroker-1.1", true)

-- -- Utility -------------------------------------------------------------------
local function FormatTimestamp(ts)
    if not ts then return "" end
    local d = date("*t", ts)
    return string.format("%02d/%02d %02d:%02d", d.month, d.day, d.hour, d.min)
end

local function MakeSeparator(parent, yOff)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0,  yOff)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, yOff)
    return sep
end

-- -- Row pooling -----------------------------------------------------------
-- Shared by every tab with a repeating row list (Overview, Targets, Ledger,
-- Token History), so refreshing a tab reuses existing row frames instead of
-- creating a fresh set every time and leaving the old ones orphaned/hidden
-- forever. pool[i] holds row i's frame across refreshes; createFunc(parent)
-- is only called the first time slot i is needed.
local function GetPooledRow(pool, index, parent, createFunc)
    local row = pool[index]
    if not row then
        row = createFunc(parent)
        pool[index] = row
    end
    row:Show()
    return row
end

-- Hides any pooled rows beyond what this refresh actually used, without
-- destroying them -- they stay in the pool for the next refresh.
local function HideExtraPooledRows(pool, fromIndex)
    for i = fromIndex, #pool do
        if pool[i] then pool[i]:Hide() end
    end
end

-- -- Nav button builder --------------------------------------------------------
local navButtons = {}

local function CreateNavButton(parent, label, tabKey, yPoint, anchorTo, anchorSide)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(NAV_W, NAV_BTN_H)
    if anchorTo then
        btn:SetPoint(anchorSide or "TOP", anchorTo, "BOTTOM", 0, 0)
    else
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yPoint or 0)
    end

    -- Active accent bar
    local accent = btn:CreateTexture(nil, "ARTWORK")
    accent:SetWidth(3)
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", 0, 0)
    accent:SetColorTexture(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 1)
    accent:Hide()
    btn.accent = accent

    -- Background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)
    btn.bg = bg

    -- Highlight
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    -- Label
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", 18, 0)
    fs:SetText(label)
    fs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
    btn.label = fs

    function btn:SetActive(isActive)
        if isActive then
            self.accent:Show()
            self.bg:SetColorTexture(0.12, 0.10, 0.04, 0.9)
            self.label:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
            self.label:SetFontObject("GameFontHighlight")
        else
            self.accent:Hide()
            self.bg:SetColorTexture(0, 0, 0, 0)
            self.label:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
            self.label:SetFontObject("GameFontNormal")
        end
    end

    btn:SetScript("OnClick", function()
        UI:SwitchTab(tabKey)
    end)

    navButtons[tabKey] = btn
    return btn
end

-- -- Tab switching -------------------------------------------------------------
function UI:SwitchTab(tabKey)
    activeTab = tabKey
    for key, btn in pairs(navButtons) do
        btn:SetActive(key == tabKey)
    end
    for key, panel in pairs(mainFrame.panels) do
        if key == tabKey then
            panel:Show()
        else
            panel:Hide()
        end
    end
    -- Refresh content on switch
    if tabKey == "overview" then
        UI:RefreshOverview()
    elseif tabKey == "targets" then
        UI:RefreshTargets()
    elseif tabKey == "ledger" then
        UI:RefreshLedger()
    elseif tabKey == "goldhistory" then
        UI:ResetGraphRange("goldhistory")
        UI:RefreshGoldHistory()
    elseif tabKey == "goals" then
        UI:RefreshGoals()
    elseif tabKey == "token" then
        UI:ResetGraphRange("token")
        UI:RefreshToken()
    elseif tabKey == "tokenhistory" then
        UI:RefreshTokenHistory()
    elseif tabKey == "changelog" then
        UI:RefreshChangelog()
    elseif tabKey == "guilds" then
        UI:RefreshGuilds()
    end
end

-- -- Stat Card -----------------------------------------------------------------
local function CreateStatCard(parent, title, x, y, w, h)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetSize(w or 200, h or 90)
    card:SetPoint("TOPLEFT", x, y)
    card:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left=3, right=3, top=3, bottom=3 }
    })
    card:SetBackdropColor(0.08, 0.07, 0.04, 0.95)
    card:SetBackdropBorderColor(0.35, 0.30, 0.15, 0.8)

    local titleFs = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleFs:SetPoint("TOPLEFT", 10, -8)
    titleFs:SetText(title)
    titleFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local valueFs = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueFs:SetPoint("BOTTOM", 0, 10)
    valueFs:SetPoint("LEFT",   8, 0)
    valueFs:SetPoint("RIGHT", -8, 0)
    valueFs:SetJustifyH("CENTER")
    valueFs:SetWordWrap(false)
    valueFs:SetText("--")
    card.value = valueFs

    return card
end

-- -- Scrollable content helper -------------------------------------------------
local function CreateScrollArea(parent, x, y, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    sf:SetSize(w - 24, h)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(w - 24)
    sf:SetScrollChild(sc)

    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxScroll = math.max(0, sc:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - delta * 60)))
    end)

    return sf, sc
end

-- ===============================================================================
-- OVERVIEW TAB
-- ===============================================================================
local overviewCards = {}
local overviewCharScroll, overviewCharContent
local overviewGuildText
local overviewAccountTotalText
local overviewRowPool = {}

local function BuildOverviewTab(panel)
    local L = WarbandAccountant.L
    local cw    = CONTENT_W
    local cardW = math.floor((cw - 10*3) / 4)
    local cardH = 85
    local cardY = -10

    overviewCards.warband = CreateStatCard(panel, L.OVERVIEW_CARD_WARBAND, 6,                cardY, cardW, cardH)
    overviewCards.total   = CreateStatCard(panel, L.OVERVIEW_CARD_BAGS,    6 + (cardW+10),   cardY, cardW, cardH)
    overviewCards.weekly  = CreateStatCard(panel, L.OVERVIEW_CARD_WEEK,    6 + (cardW+10)*2, cardY, cardW, cardH)
    overviewCards.token   = CreateStatCard(panel, L.OVERVIEW_CARD_TOKEN,   6 + (cardW+10)*3, cardY, cardW, cardH)

    -- Token affordability: how many tokens the Warband Bank (spare gold) buys
    local tokenSub = overviewCards.token:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tokenSub:SetPoint("TOP", 0, -28)
    tokenSub:SetPoint("LEFT", 8, 0)
    tokenSub:SetPoint("RIGHT", -8, 0)
    tokenSub:SetJustifyH("CENTER")
    tokenSub:SetWordWrap(false)
    overviewCards.token.sub = tokenSub
    overviewCards.token:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(L.TOKEN_AFFORD_TOOLTIP_TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(L.TOKEN_AFFORD_TOOLTIP_BODY, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    overviewCards.token:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Guild bank line
    local guildLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildLabel:SetPoint("TOPLEFT", 10, cardY - cardH - 10)
    guildLabel:SetText(L.OVERVIEW_GUILD_LABEL)
    guildLabel:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    overviewGuildText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    overviewGuildText:SetPoint("LEFT", guildLabel, "RIGHT", 10, 0)
    overviewGuildText:SetText("--")

    -- Account Total line (Warband Bank + every character's current gold),
    -- aligned under the WoW Token card, same row as Guild Bank. The value
    -- is anchored to the panel's right edge with a fixed margin so it can
    -- never run past the window regardless of how wide the number gets;
    -- the label sits to its left instead of the value growing rightward
    -- unbounded from the label.
    local acctLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    acctLabel:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    overviewAccountTotalText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    overviewAccountTotalText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, cardY - cardH - 10)
    overviewAccountTotalText:SetJustifyH("RIGHT")
    overviewAccountTotalText:SetText("--")

    acctLabel:SetPoint("RIGHT", overviewAccountTotalText, "LEFT", -10, 0)
    acctLabel:SetText(L.OVERVIEW_ACCOUNT_TOTAL_LABEL)

    -- Character list header
    local col = { name=10, realm=180, current=340, target=490, diff=640 }
    local scrollH = CONTENT_H - cardH - 80
    local hdrY = cardY - cardH - 44

    local function Hdr(txt, x)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", x, hdrY)
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        return fs
    end
    Hdr(L.COL_CHARACTER, col.name)
    Hdr(L.COL_REALM,     col.realm)
    Hdr(L.COL_CURRENT,   col.current)
    Hdr(L.COL_TARGET,    col.target)
    Hdr(L.OVERVIEW_COL_DIFF, col.diff)

    MakeSeparator(panel, hdrY - 16)
    overviewCharScroll, overviewCharContent = CreateScrollArea(panel, 0, hdrY - 24, CONTENT_W, scrollH)
    panel._overviewCol = col
end

function UI:RefreshOverview()
    if not mainFrame or not mainFrame.panels.overview then return end
    local Data = WarbandAccountant.Data
    local L = WarbandAccountant.L

    -- Stat cards
    local warbandGold = WarbandAccountant.Core:GetWarbandGold()
    overviewCards.warband.value:SetText(WarbandAccountant.FormatGold(warbandGold))
    overviewCards.warband.value:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

    local totalGold = Data:GetTotalTrackedGold()
    overviewCards.total.value:SetText(WarbandAccountant.FormatGold(totalGold))
    overviewCards.total.value:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)

    overviewAccountTotalText:SetText(WarbandAccountant.FormatGold(warbandGold + totalGold))

    local weekly = Data:GetWeeklyIncome()
    local wc = weekly >= 0 and COLOR_GREEN or COLOR_RED
    local ws = weekly >= 0 and "+" or ""
    overviewCards.weekly.value:SetText(ws .. WarbandAccountant.FormatGold(weekly))
    overviewCards.weekly.value:SetTextColor(wc.r, wc.g, wc.b)

    -- Token price
    local tokenPrice = WarbandAccountant.Token and WarbandAccountant.Token:GetCurrentPrice()
    if tokenPrice then
        overviewCards.token.value:SetText(WarbandAccountant.Token.FormatGold(tokenPrice))
        overviewCards.token.value:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
    else
        overviewCards.token.value:SetText(L.OVERVIEW_LOADING)
        overviewCards.token.value:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
    end

    -- Token affordability (spare gold = Warband Bank only)
    local Goals = WarbandAccountant.Goals
    local count, secsToNext = nil, nil
    if Goals then count, secsToNext = Goals:GetTokenAffordability() end
    if count then
        local txt = string.format(L.TOKEN_AFFORD_COUNT, count)
        local short = Goals:FormatETAShort(secsToNext)
        if short then
            txt = txt .. "   |cFF999999" .. string.format(L.TOKEN_AFFORD_NEXT, short) .. "|r"
        end
        overviewCards.token.sub:SetText(txt)
    else
        overviewCards.token.sub:SetText("")
    end

    -- Guild bank
    local guildGold, guildName = WarbandAccountant.Core:GetGuildBankGold()
    if guildName then
        overviewGuildText:SetText("|cFF00FF00" .. guildName .. "|r  " .. WarbandAccountant.FormatGold(guildGold or 0))
    else
        overviewGuildText:SetText("|cFF666666" .. L.OVERVIEW_GUILD_NONE .. "|r")
    end

    -- Character rows
    local col = mainFrame.panels.overview._overviewCol
    local currentRealm = GetRealmName()

    local function CreateOverviewRow(parent)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(CONTENT_W - 30, ROW_H)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameFs:SetPoint("LEFT", col.name, 0)
        row.nameFs:SetWidth(160)
        row.nameFs:SetJustifyH("LEFT")

        row.realmFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.realmFs:SetPoint("LEFT", col.realm, 0)
        row.realmFs:SetWidth(150)
        row.realmFs:SetJustifyH("LEFT")

        row.curFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.curFs:SetPoint("LEFT", col.current, 0)
        row.curFs:SetWidth(140)
        row.curFs:SetJustifyH("LEFT")

        row.tgtFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.tgtFs:SetPoint("LEFT", col.target, 0)
        row.tgtFs:SetWidth(140)
        row.tgtFs:SetJustifyH("LEFT")

        row.diffFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.diffFs:SetPoint("LEFT", col.diff, 0)
        row.diffFs:SetWidth(140)
        row.diffFs:SetJustifyH("LEFT")

        return row
    end

    local characters = Data:GetAllCharacters()
    local charList = {}
    for id, d in pairs(characters) do
        table.insert(charList, { id=id, name=d.name, realm=d.realm, class=d.class,
            current=d.currentGold or 0, target=d.targetGold or 0,
            paused=d.paused, charType=d.charType, sortOrder=d.sortOrder or 0 })
    end
    table.sort(charList, function(a,b) return a.sortOrder < b.sortOrder end)

    local yOff = 0
    for i, c in ipairs(charList) do
        local row = GetPooledRow(overviewRowPool, i, overviewCharContent, CreateOverviewRow)
        row:SetPoint("TOPLEFT", 0, yOff)

        if i % 2 == 0 then
            row.bg:SetColorTexture(0.15, 0.14, 0.10, 0.4)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        local clr = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class] or COLOR_WHITE
        local nameStr = c.name
        if c.paused then nameStr = nameStr .. " |cFFFF4444" .. L.PAUSED_TAG .. "|r" end
        row.nameFs:SetText(nameStr)
        row.nameFs:SetTextColor(clr.r, clr.g, clr.b)

        row.realmFs:SetText(c.realm .. (c.realm ~= currentRealm and L.OTHER_REALM_SUFFIX or ""))
        row.realmFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        row.curFs:SetText(WarbandAccountant.FormatGold(c.current))
        if c.current < c.target then
            row.curFs:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        elseif c.current > c.target then
            row.curFs:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        else
            row.curFs:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
        end

        row.tgtFs:SetText(WarbandAccountant.FormatGold(c.target))
        row.tgtFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local diff = c.current - c.target
        local diffSign = diff >= 0 and "+" or ""
        row.diffFs:SetText(diffSign .. WarbandAccountant.FormatGold(diff))
        if diff > 0 then row.diffFs:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        elseif diff < 0 then row.diffFs:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        else row.diffFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b) end

        yOff = yOff - ROW_H
    end
    HideExtraPooledRows(overviewRowPool, #charList + 1)
    overviewCharContent:SetHeight(math.max(300, math.abs(yOff)))
end

-- ===============================================================================
-- TARGETS TAB
-- ===============================================================================
local targetsScrollContent
local targetRowPool = {}

local function BuildTargetsTab(panel)
    local L = WarbandAccountant.L
    local col = {
        reorder   = 8,
        character = 52,
        realm     = 192,
        main      = 308,
        target    = 458,
        current   = 598,
        paused    = 738,
        delete    = 800,
    }
    panel._col = col

    -- Header row on panel, separator below it, scroll frame starts after
    local function Hdr(txt, x, w)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -10)
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        if w then fs:SetWidth(w) end
        return fs
    end
    Hdr(L.COL_CHARACTER, col.character)
    Hdr(L.COL_REALM,     col.realm)
    Hdr(L.COL_TYPE,      col.main)
    Hdr(L.COL_TARGET,    col.target)
    Hdr(L.COL_CURRENT,   col.current)
    Hdr(L.COL_PAUSE,     col.paused)
    Hdr(L.COL_DELETE,    col.delete)

    MakeSeparator(panel, -28)

    local sf, sc = CreateScrollArea(panel, 0, -36, CONTENT_W, CONTENT_H - 36)
    targetsScrollContent = sc
    panel._targetsScroll = sf
end

function UI:RefreshTargets()
    if not mainFrame or not targetsScrollContent then return end
    local Data  = WarbandAccountant.Data
    local L     = WarbandAccountant.L
    local panel = mainFrame.panels.targets
    local col = panel._col

    StaticPopupDialogs["WARBANDACCOUNTANT_DELETE_CHARACTER"] = {
        text = L.CONFIRM_DELETE_CHAR_TEXT,
        button1 = L.TARGETS_DELETE_BUTTON, button2 = L.CONFIRM_CANCEL,
        OnAccept = function(self, charID)
            local D = WarbandAccountant.Data
            local ok, result = D:DeleteCharacter(charID)
            if ok then
                print("|cFF00FF00Warband Accountant:|r " .. L.CHAR_DELETED_MSG .. result)
                UI:RefreshTargets()
                UI:UpdateTooltip()
            else
                print("|cFFFF0000Warband Accountant:|r " .. (result or L.CHAR_DELETE_FAILED_MSG))
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    local function CreateTargetRow(parent)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(CONTENT_W - 44, 40)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        -- Reorder: both variants exist always, toggled per refresh by sort mode
        row.orderEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.orderEdit:SetSize(36, 22)
        row.orderEdit:SetPoint("LEFT", col.reorder, 0)
        row.orderEdit:SetAutoFocus(false)
        row.orderEdit:SetNumeric(true)
        row.orderEdit:SetMaxLetters(3)
        row.orderEdit:SetJustifyH("CENTER")

        row.upBtn = CreateFrame("Button", nil, row)
        row.upBtn:SetSize(16, 16)
        row.upBtn:SetPoint("LEFT", col.reorder, 4)
        local upTex = row.upBtn:CreateTexture(nil, "ARTWORK")
        upTex:SetAllPoints()
        upTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
        upTex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        row.upBtn:SetNormalTexture(upTex)
        row.upBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

        row.downBtn = CreateFrame("Button", nil, row)
        row.downBtn:SetSize(16, 16)
        row.downBtn:SetPoint("TOP", row.upBtn, "BOTTOM", 0, 2)
        local downTex = row.downBtn:CreateTexture(nil, "ARTWORK")
        downTex:SetAllPoints()
        downTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
        downTex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        row.downBtn:SetNormalTexture(downTex)
        row.downBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

        row.nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.nameFs:SetPoint("LEFT", col.character, 0)
        row.nameFs:SetWidth(130)
        row.nameFs:SetJustifyH("LEFT")

        row.realmFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.realmFs:SetPoint("LEFT", col.realm, 0)
        row.realmFs:SetWidth(100)
        row.realmFs:SetJustifyH("LEFT")

        -- Unnamed dropdown -- a named "WBATypeDD_i" frame here would
        -- register a new global every refresh and never get cleaned up
        row.typeDD = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
        row.typeDD:SetPoint("LEFT", col.main - 16, 0)
        UIDropDownMenu_SetWidth(row.typeDD, 120)

        row.tgtEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.tgtEdit:SetSize(90, 22)
        row.tgtEdit:SetPoint("LEFT", col.target, 0)
        row.tgtEdit:SetAutoFocus(false)
        row.tgtEdit:SetNumeric(true)
        row.tgtEdit:SetMaxLetters(7)
        row.tgtEdit:SetJustifyH("RIGHT")
        row.tgtEdit:SetTextInsets(2, 6, 0, 0)

        row.gLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.gLabel:SetPoint("LEFT", row.tgtEdit, "RIGHT", 4, 0)
        row.gLabel:SetText(L.GOLD_SUFFIX)
        row.gLabel:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

        row.curFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.curFs:SetPoint("LEFT", col.current, 0)
        row.curFs:SetWidth(130)
        row.curFs:SetJustifyH("LEFT")

        row.pauseCb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.pauseCb:SetSize(24, 24)
        row.pauseCb:SetPoint("LEFT", col.paused, 0)
        row.pauseCb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.TARGETS_PAUSE_TOOLTIP_TITLE)
            GameTooltip:AddLine(L.TARGETS_PAUSE_TOOLTIP_DESC, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row.pauseCb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row.delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.delBtn:SetSize(50, 22)
        row.delBtn:SetPoint("LEFT", col.delete, 0)
        row.delBtn:SetText(L.TARGETS_DELETE_BUTTON)
        local regs = {row.delBtn:GetRegions()}
        for _, reg in ipairs(regs) do
            if reg:GetObjectType() == "Texture" then
                reg:SetVertexColor(0.8, 0.1, 0.1, 1)
            end
        end
        row.delBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.TARGETS_DELETE_TOOLTIP_TITLE)
            GameTooltip:AddLine(L.TARGETS_DELETE_TOOLTIP_DESC, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row.delBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        return row
    end

    local characters = Data:GetAllCharacters()
    local charList = {}
    for id, d in pairs(characters) do
        table.insert(charList, { id=id, name=d.name, realm=d.realm, class=d.class,
            currentGold=d.currentGold or 0, targetGold=d.targetGold or 0,
            paused=d.paused, charType=d.charType, sortOrder=d.sortOrder or 0 })
    end
    table.sort(charList, function(a,b) return a.sortOrder < b.sortOrder end)

    local currentCharID = Data:GetCurrentCharacterID()
    local sortMode = Data:GetSortMode()
    local yOff = 0

    for i, char in ipairs(charList) do
        local row = GetPooledRow(targetRowPool, i, targetsScrollContent, CreateTargetRow)
        row:SetPoint("TOPLEFT", 0, yOff)

        if i % 2 == 0 then
            row.bg:SetColorTexture(0.15, 0.14, 0.10, 0.4)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        -- Reorder controls
        if sortMode == "number" then
            row.orderEdit:Show()
            row.upBtn:Hide()
            row.downBtn:Hide()
            row.orderEdit:SetText(tostring(i))
            row.orderEdit:SetScript("OnEnterPressed", function(self)
                local newPos = tonumber(self:GetText())
                if newPos and newPos >= 1 and newPos <= #charList and newPos ~= i then
                    local moved = table.remove(charList, i)
                    table.insert(charList, newPos, moved)
                    for idx, ch in ipairs(charList) do
                        Data:SetCharacterSortOrder(ch.id, idx)
                    end
                    UI:RefreshTargets()
                else
                    self:SetText(tostring(i))
                    self:ClearFocus()
                end
            end)
            row.orderEdit:SetScript("OnEditFocusLost", function(self)
                self:SetText(tostring(i))
            end)
        else
            row.orderEdit:Hide()
            row.upBtn:Show()
            row.downBtn:Show()
            row.upBtn:Enable()
            row.downBtn:Enable()
            if i > 1 then
                row.upBtn:SetScript("OnClick", function()
                    Data:SwapCharacterOrder(char.id, charList[i-1].id)
                    UI:RefreshTargets()
                end)
            else
                row.upBtn:Disable()
            end
            if i < #charList then
                row.downBtn:SetScript("OnClick", function()
                    Data:SwapCharacterOrder(char.id, charList[i+1].id)
                    UI:RefreshTargets()
                end)
            else
                row.downBtn:Disable()
            end
        end

        -- Name / realm
        local clr = RAID_CLASS_COLORS and RAID_CLASS_COLORS[char.class] or COLOR_WHITE
        row.nameFs:SetText(char.name)
        row.nameFs:SetTextColor(clr.r, clr.g, clr.b)
        row.realmFs:SetText(char.realm)
        row.realmFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        -- Character type dropdown
        local currentType = Data:GetCharacterType(char.id)
        local displayName = currentType and Data:GetCategoryName(currentType) or "(None)"
        UIDropDownMenu_SetText(row.typeDD, displayName)
        UIDropDownMenu_Initialize(row.typeDD, function()
            local info = UIDropDownMenu_CreateInfo()
            info.text    = "(None)"
            info.arg1    = nil
            info.checked = (currentType == nil)
            info.func    = function()
                Data:SetCharacterType(char.id, nil)
                UIDropDownMenu_SetText(row.typeDD, "(None)")
                UI:UpdateTooltip()
            end
            UIDropDownMenu_AddButton(info)
            for _, key in ipairs(Data:GetAllCategoryKeys()) do
                info = UIDropDownMenu_CreateInfo()
                info.text    = Data:GetCategoryName(key)
                info.arg1    = key
                info.checked = (currentType == key)
                info.func    = function(btn, arg1)
                    Data:SetCharacterType(char.id, arg1)
                    UIDropDownMenu_SetText(row.typeDD, btn:GetText())
                    UI:RefreshTargets()
                    UI:UpdateTooltip()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        -- Target editbox
        row.tgtEdit:SetText(tostring(math.floor(char.targetGold / 10000)))
        local function SaveTarget(self)
            Data:SetCharacterTarget(char.id, (tonumber(self:GetText()) or 0) * 10000)
            UI:RefreshTargets()
        end
        row.tgtEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveTarget(self) end)
        row.tgtEdit:SetScript("OnEditFocusLost", SaveTarget)

        -- Current gold
        row.curFs:SetText(WarbandAccountant.FormatGold(char.currentGold))
        if char.currentGold < char.targetGold then
            row.curFs:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        elseif char.currentGold > char.targetGold then
            row.curFs:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        else
            row.curFs:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
        end

        -- Pause checkbox
        row.pauseCb:SetChecked(char.paused)
        row.pauseCb:SetScript("OnClick", function(self)
            local d = Data:GetCharacterData(char.id)
            if d then d.paused = self:GetChecked() end
            UI:UpdateTooltip()
        end)

        -- Delete button (not for current char)
        if char.id ~= currentCharID then
            row.delBtn:Show()
            row.delBtn:SetScript("OnClick", function()
                StaticPopup_Show("WARBANDACCOUNTANT_DELETE_CHARACTER", char.name, nil, char.id)
            end)
        else
            row.delBtn:Hide()
        end

        yOff = yOff - 40
    end
    HideExtraPooledRows(targetRowPool, #charList + 1)
    targetsScrollContent:SetHeight(math.max(300, math.abs(yOff)))
end

-- ===============================================================================
-- LEDGER TAB
-- ===============================================================================
local ledgerScrollContent
local ledgerRowPool = {}
local ledgerEmptyText
local ledgerStatsText
local ledgerFilterDropdown

local function BuildLedgerTab(panel)
    local L = WarbandAccountant.L
    local col = { time=10, char=105, type=240, amount=360, balance=520, note=690 }
    panel._col = col

    -- Row 1: Filter label + dropdown anchored top-right
    ledgerFilterDropdown = CreateFrame("Frame", "WBALedgerFilterDD", panel, "UIDropDownMenuTemplate")
    ledgerFilterDropdown:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 8, -4)
    UIDropDownMenu_SetWidth(ledgerFilterDropdown, 160)
    UIDropDownMenu_SetText(ledgerFilterDropdown, L.LEDGER_FILTER_ALL)

    local filterLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterLbl:SetPoint("RIGHT", ledgerFilterDropdown, "LEFT", 16, 1)
    filterLbl:SetText(L.LEDGER_FILTER_LABEL)
    filterLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    -- Stats text: its own full-width row below the filter, so a longer
    -- translation wrapping to a second line never collides with the
    -- filter dropdown or the column headers below it.
    ledgerStatsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ledgerStatsText:SetPoint("TOPLEFT", 10, -32)
    ledgerStatsText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -32)
    ledgerStatsText:SetJustifyH("LEFT")

    local function InitFilter()
        UIDropDownMenu_Initialize(ledgerFilterDropdown, function()
            local info = UIDropDownMenu_CreateInfo()
            info.text    = L.LEDGER_FILTER_ALL
            info.checked = (ledgerCharFilter == nil)
            info.func    = function()
                ledgerCharFilter = nil
                UIDropDownMenu_SetText(ledgerFilterDropdown, L.LEDGER_FILTER_ALL)
                UI:RefreshLedger()
            end
            UIDropDownMenu_AddButton(info)

            local Data = WarbandAccountant.Data
            local chars = {}
            for id, d in pairs(Data:GetAllCharacters()) do
                table.insert(chars, { id=id, name=d.name, realm=d.realm })
            end
            table.sort(chars, function(a,b) return a.name < b.name end)
            for _, c in ipairs(chars) do
                local disp = c.name .. (c.realm ~= GetRealmName() and L.OTHER_REALM_SUFFIX or "")
                info = UIDropDownMenu_CreateInfo()
                info.text    = disp
                info.arg1    = c.id
                info.checked = (ledgerCharFilter == c.id)
                info.func    = function(btn, arg1)
                    ledgerCharFilter = arg1
                    UIDropDownMenu_SetText(ledgerFilterDropdown, btn:GetText())
                    UI:RefreshLedger()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    ledgerFilterDropdown:SetScript("OnShow", InitFilter)
    InitFilter()

    -- Header row on panel at fixed y, separator, then scroll
    local function Hdr(txt, x)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -92)
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        return fs
    end
    Hdr(L.COL_TIME,         col.time)
    Hdr(L.COL_CHARACTER,    col.char)
    Hdr(L.COL_TYPE,         col.type)
    Hdr(L.COL_AMOUNT,       col.amount)
    Hdr(L.COL_WARBAND_BANK, col.balance)
    Hdr(L.COL_NOTE,         col.note)

    MakeSeparator(panel, -108)

    local lsf, lsc = CreateScrollArea(panel, 0, -116, CONTENT_W + 4, CONTENT_H - 120)
    ledgerScrollContent = lsc

    ledgerEmptyText = ledgerScrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ledgerEmptyText:SetPoint("CENTER", 0, 0)
    ledgerEmptyText:SetJustifyH("CENTER")
    ledgerEmptyText:Hide()
end

function UI:RefreshLedger()
    if not mainFrame or not ledgerScrollContent then return end
    local Data = WarbandAccountant.Data
    local L = WarbandAccountant.L

    -- Stats
    local dep, wdr = Data:GetTotalLedgerStats()
    local made = dep - wdr
    local madeCol  = made >= 0 and "|cFF33FF33" or "|cFFFF4444"
    local madeSign = made >= 0 and "+" or ""
    local wIncome  = Data:GetWeeklyIncome()
    local wCol     = wIncome >= 0 and "|cFF33FF33" or "|cFFFF4444"
    local wSign    = wIncome >= 0 and "+" or ""
    ledgerStatsText:SetText(string.format(
        L.LEDGER_STATS_FORMAT,
        WarbandAccountant.FormatGold(dep), WarbandAccountant.FormatGold(wdr),
        madeCol, madeSign, WarbandAccountant.FormatGold(made),
        wCol, wSign, WarbandAccountant.FormatGold(wIncome)))

    -- Entries
    local allEntries = Data:GetLedgerEntries(5000)
    local entries = {}
    for _, e in ipairs(allEntries) do
        if ledgerCharFilter == nil or e.character == ledgerCharFilter then
            table.insert(entries, e)
            if #entries >= 200 then break end
        end
    end

    local panel = mainFrame.panels.ledger
    -- Recompute dynamic columns
    local col = panel._col

    if #entries == 0 then
        HideExtraPooledRows(ledgerRowPool, 1)
        ledgerEmptyText:SetText(ledgerCharFilter and L.LEDGER_EMPTY_FILTERED or L.LEDGER_EMPTY_ALL)
        ledgerEmptyText:Show()
        ledgerScrollContent:SetHeight(300)
        return
    end
    ledgerEmptyText:Hide()

    local function CreateLedgerRow(parent)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(CONTENT_W - 20, 24)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.timeFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.timeFs:SetPoint("LEFT", col.time, 0)
        row.timeFs:SetJustifyH("LEFT")
        row.timeFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        row.charFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.charFs:SetPoint("LEFT", col.char, 0)
        row.charFs:SetWidth(140)
        row.charFs:SetJustifyH("LEFT")

        row.typeFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.typeFs:SetPoint("LEFT", col.type, 0)
        row.typeFs:SetJustifyH("LEFT")

        row.amtFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.amtFs:SetPoint("LEFT", col.amount, 0)
        row.amtFs:SetJustifyH("LEFT")

        row.balFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.balFs:SetPoint("LEFT", col.balance, 0)
        row.balFs:SetJustifyH("LEFT")
        row.balFs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

        row.noteFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.noteFs:SetPoint("LEFT", col.note, 0)
        row.noteFs:SetWidth(165)
        row.noteFs:SetJustifyH("LEFT")
        row.noteFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        return row
    end

    local yOff = 0
    for i, e in ipairs(entries) do
        local row = GetPooledRow(ledgerRowPool, i, ledgerScrollContent, CreateLedgerRow)
        row:SetPoint("TOPLEFT", 0, yOff)

        if i % 2 == 0 then
            row.bg:SetColorTexture(0.15, 0.14, 0.10, 0.35)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        row.timeFs:SetText(FormatTimestamp(e.timestamp))

        row.charFs:SetText(e.characterName or L.LEDGER_UNKNOWN_CHAR)

        local isDeposit = (e.type == "DEPOSIT" or e.type == "MANUAL_DEPOSIT")
        row.typeFs:SetText(isDeposit and L.LEDGER_TYPE_DEPOSIT or L.LEDGER_TYPE_WITHDRAW)
        row.typeFs:SetTextColor(isDeposit and 0.2 or 1, isDeposit and 1 or 0.2, 0.2)

        row.amtFs:SetText(WarbandAccountant.FormatGold(e.amount))
        row.balFs:SetText(WarbandAccountant.FormatGold(e.balanceAfter))

        if e.note and e.note ~= "" then
            row.noteFs:SetText(e.note)
            row.noteFs:Show()
        else
            row.noteFs:Hide()
        end

        yOff = yOff - 24
    end
    HideExtraPooledRows(ledgerRowPool, #entries + 1)
    ledgerScrollContent:SetHeight(math.max(300, math.abs(yOff)))
end

-- ===============================================================================
-- SETTINGS TAB
-- ===============================================================================
local function BuildSettingsTab(outerPanel)
    local Data = WarbandAccountant.Data
    local L = WarbandAccountant.L

    -- Wrap all settings content in a scroll frame so it never overflows the window
    local sf, panel = CreateScrollArea(outerPanel, 0, -4, CONTENT_W, CONTENT_H - 8)
    panel:SetHeight(1)  -- grown at the end based on actual content
    local cw = CONTENT_W - 24

    local y  = -15

    -- Helper: section box
    local function Section(title, sx, sy, sw, sh)
        local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        box:SetSize(sw, sh)
        box:SetPoint("TOPLEFT", sx, sy)
        box:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=12,
            insets={ left=3, right=3, top=3, bottom=3 }
        })
        box:SetBackdropColor(0.06, 0.05, 0.03, 0.95)
        box:SetBackdropBorderColor(0.35, 0.30, 0.15, 0.7)
        local hdr = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdr:SetPoint("TOPLEFT", 10, -8)
        hdr:SetText(title)
        hdr:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        return box
    end

    -- Helper: checkbox
    local function MakeCB(parent, label, x, y2, getter, setter)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", x, y2)
        cb:SetChecked(getter())
        cb.Text:SetText(label)
        cb.Text:SetFontObject("GameFontHighlightSmall")
        cb:SetScript("OnClick", function(self) setter(self:GetChecked()) end)
        return cb
    end

    local settings = Data:GetSettings()
    -- Two equal columns whose combined span exactly matches the full-width
    -- sections below (10 .. cw-10), rather than eyeballing a gap and letting
    -- rounding push the right column's right edge past the others.
    local colGap = 15
    local totalW = cw - 20
    local halfW  = math.floor((totalW - colGap) / 2)
    local dispX  = 10 + halfW + colGap
    local dispW  = totalW - halfW - colGap

    -- -- Automation box ------------------------------------------------------
    local autoGuildBoxH = 170
    local autoBox = Section(L.SETTINGS_SECTION_AUTOMATION, 10, y, halfW, autoGuildBoxH)

    MakeCB(autoBox, L.SETTINGS_AUTO_DEPOSIT, 10, -28,
        function() return settings.autoDeposit ~= false end,
        function(v) settings.autoDeposit = v end)
    MakeCB(autoBox, L.SETTINGS_AUTO_WITHDRAW, 10, -52,
        function() return settings.autoWithdraw ~= false end,
        function(v) settings.autoWithdraw = v end)
    MakeCB(autoBox, L.SETTINGS_CONFIRM_TRANSFER, 10, -76,
        function() return settings.confirmTransfers or false end,
        function(v) settings.confirmTransfers = v end)

    local autoDesc = autoBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoDesc:SetPoint("TOPLEFT", 10, -104)
    autoDesc:SetWidth(halfW - 20)
    autoDesc:SetJustifyH("LEFT")
    autoDesc:SetText(L.SETTINGS_AUTOMATION_DESC)
    autoDesc:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    -- -- Guild Bank box (paired with Automation -- both are short) ----------
    local guildBox = Section(L.SETTINGS_SECTION_GUILDBANK, dispX, y, dispW, autoGuildBoxH)

    local homeLbl = guildBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    homeLbl:SetPoint("TOPLEFT", 12, -30)
    homeLbl:SetText(L.SETTINGS_HOMEGUILD_LABEL)
    homeLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local homeDD = CreateFrame("Frame", "WBAHomeGuildDD", guildBox, "UIDropDownMenuTemplate")
    homeDD:SetPoint("LEFT", homeLbl, "RIGHT", 0, -2)
    UIDropDownMenu_SetWidth(homeDD, 190)

    local function HomeGuildDisplayText()
        return Data:GetHomeGuild() or L.SETTINGS_HOMEGUILD_CURRENT
    end
    UIDropDownMenu_SetText(homeDD, HomeGuildDisplayText())

    UIDropDownMenu_Initialize(homeDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = L.SETTINGS_HOMEGUILD_CURRENT
        info.checked = (Data:GetHomeGuild() == nil)
        info.func = function(btn)
            Data:SetHomeGuild(nil)
            UIDropDownMenu_SetText(homeDD, L.SETTINGS_HOMEGUILD_CURRENT)
            if activeTab == "overview" then UI:RefreshOverview() end
        end
        UIDropDownMenu_AddButton(info)

        for _, name in ipairs(Data:GetKnownGuildNames()) do
            info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.arg1 = name
            info.checked = (Data:GetHomeGuild() == name)
            info.func = function(btn, arg1)
                Data:SetHomeGuild(arg1)
                UIDropDownMenu_SetText(homeDD, arg1)
                if activeTab == "overview" then UI:RefreshOverview() end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local homeDesc = guildBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    homeDesc:SetPoint("TOPLEFT", 12, -56)
    homeDesc:SetWidth(dispW - 24)
    homeDesc:SetJustifyH("LEFT")
    homeDesc:SetText(L.SETTINGS_HOMEGUILD_DESC)
    homeDesc:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    -- -- Category Names + Default Targets (now below Display) ---------------
    local dispY = y - autoGuildBoxH
    local dispBoxH = 130
    local tgtY   = dispY - dispBoxH - 12
    local colW   = math.floor((cw - 40) / 2)
    local rowH   = 28
    local numRows = 3
    local tgtBoxH = 46 + (numRows * rowH) + 24  -- header + rows + note
    local tgtBox = Section(L.SETTINGS_SECTION_CATEGORIES, 10, tgtY, cw - 20, tgtBoxH)

    local function TgtHdr(txt, x)
        local fs = tgtBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, -30)
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
    end
    TgtHdr(L.SETTINGS_CATEGORIES_HDR_NAME,  14)
    TgtHdr(L.SETTINGS_CATEGORIES_HDR_TARGET, 154)
    TgtHdr(L.SETTINGS_CATEGORIES_HDR_NAME,  14  + colW)
    TgtHdr(L.SETTINGS_CATEGORIES_HDR_TARGET, 154 + colW)

    local keys = Data:GetAllCategoryKeys()

    local function MakeCategoryRow(parent, key, col, rowIdx)
        local bx = col == 0 and 10 or (10 + colW)
        local by = -50 - (rowIdx * rowH)

        local nameEB = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        nameEB:SetSize(130, 22)
        nameEB:SetPoint("TOPLEFT", bx, by)
        nameEB:SetAutoFocus(false)
        nameEB:SetMaxLetters(20)
        nameEB:SetText(Data:GetCategoryName(key))
        nameEB:SetTextInsets(4, 4, 0, 0)
        local function SaveName(self)
            local v = self:GetText()
            if v == "" then v = key; self:SetText(v) end
            Data:SetCategoryName(key, v)
        end
        nameEB:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveName(self) end)
        nameEB:SetScript("OnEditFocusLost", SaveName)

        local goldEB = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        goldEB:SetSize(80, 22)
        goldEB:SetPoint("LEFT", nameEB, "RIGHT", 8, 0)
        goldEB:SetAutoFocus(false)
        goldEB:SetNumeric(true)
        goldEB:SetMaxLetters(7)
        goldEB:SetJustifyH("RIGHT")
        goldEB:SetTextInsets(2, 6, 0, 0)
        goldEB:SetText(tostring(math.floor((Data:GetDefaultTarget(key) or 0) / 10000)))
        local gLbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        gLbl:SetPoint("LEFT", goldEB, "RIGHT", 2, 0)
        gLbl:SetText(L.GOLD_SUFFIX)
        gLbl:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        local goldSaved = false
        local function SaveGold(self)
            if goldSaved then goldSaved = false; return end
            local newTarget = (tonumber(self:GetText()) or 0) * 10000
            Data:SetDefaultTarget(key, newTarget)
            -- Update all characters currently assigned to this category
            local chars = Data:GetAllCharacters()
            local updated = {}
            for charID, charData in pairs(chars) do
                if charData.charType == key then
                    Data:SetCharacterTarget(charID, newTarget)
                    table.insert(updated, charData.name or charID)
                end
            end
            if activeTab == "targets" then UI:RefreshTargets() end
            if activeTab == "overview" then UI:RefreshOverview() end
            local catName = Data:GetCategoryName(key)
            if #updated > 0 then
                table.sort(updated)
                print(L.MSG_PREFIX_GOLD .. string.format(L.MSG_CATEGORY_UPDATED,
                    catName,
                    WarbandAccountant.FormatGold(newTarget),
                    #updated,
                    #updated == 1 and "" or L.MSG_PLURAL_S,
                    table.concat(updated, ", ")))
            else
                print(L.MSG_PREFIX_GOLD .. string.format(L.MSG_CATEGORY_SET_DEFAULT,
                    catName,
                    WarbandAccountant.FormatGold(newTarget)))
            end
        end
        goldEB:SetScript("OnEnterPressed", function(self) goldSaved = true; self:ClearFocus(); SaveGold(self) end)
        goldEB:SetScript("OnEditFocusLost", SaveGold)
    end

    for idx, key in ipairs(keys) do
        MakeCategoryRow(tgtBox, key, (idx - 1) % 2, math.floor((idx - 1) / 2))
    end

    local noteFs = tgtBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteFs:SetPoint("BOTTOMLEFT", 10, 6)
    noteFs:SetText(L.SETTINGS_CATEGORIES_NOTE)
    noteFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
    noteFs:SetWidth(cw - 40)

    -- -- Display box (own full-width row now, since it needs more room
    -- -- than Automation and Guild Bank ever will) ---------------------------
    local dispBox = Section(L.SETTINGS_SECTION_DISPLAY, 10, dispY, cw - 20, dispBoxH)
    local dispColW = math.floor((cw - 20 - 24) / 3)
    local dispCol1, dispCol2, dispCol3 = 12, 12 + dispColW, 12 + dispColW * 2

    -- Sort Mode row (col 1, row 1)
    local sortLbl = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sortLbl:SetPoint("TOPLEFT", dispCol1, -30)
    sortLbl:SetText(L.SETTINGS_SORT_MODE)
    sortLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local sortDD = CreateFrame("Frame", "WBASortDD", dispBox, "UIDropDownMenuTemplate")
    sortDD:SetPoint("LEFT", sortLbl, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(sortDD, 120)
    local curSort = Data:GetSortMode()
    UIDropDownMenu_SetText(sortDD, curSort == "arrow" and L.SETTINGS_SORT_ARROW or L.SETTINGS_SORT_NUMBER)
    UIDropDownMenu_Initialize(sortDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.func = function(btn, arg1)
            UIDropDownMenu_SetText(sortDD, btn:GetText())
            Data:SetSortMode(arg1)
            if activeTab == "targets" then UI:RefreshTargets() end
        end
        info.text = L.SETTINGS_SORT_ARROW; info.arg1 = "arrow"; info.checked = Data:GetSortMode() == "arrow"
        UIDropDownMenu_AddButton(info)
        info = UIDropDownMenu_CreateInfo()
        info.func = function(btn, arg1)
            UIDropDownMenu_SetText(sortDD, btn:GetText())
            Data:SetSortMode(arg1)
            if activeTab == "targets" then UI:RefreshTargets() end
        end
        info.text = L.SETTINGS_SORT_NUMBER; info.arg1 = "number"; info.checked = Data:GetSortMode() == "number"
        UIDropDownMenu_AddButton(info)
    end)

    -- Minimap show/hide dropdown (col 2, row 1)
    local mmLbl = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mmLbl:SetPoint("TOPLEFT", dispCol2, -30)
    mmLbl:SetText(L.SETTINGS_MINIMAP_BUTTON)
    mmLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local mmDD = CreateFrame("Frame", "WBAMinimapDD", dispBox, "UIDropDownMenuTemplate")
    mmDD:SetPoint("LEFT", mmLbl, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(mmDD, 70)
    UIDropDownMenu_SetText(mmDD, settings.hide and L.SETTINGS_NO or L.SETTINGS_YES)
    UIDropDownMenu_Initialize(mmDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = L.SETTINGS_YES; info.arg1 = false
        info.checked = not settings.hide
        info.func = function(btn, arg1)
            settings.hide = arg1
            UIDropDownMenu_SetText(mmDD, L.SETTINGS_YES)
            UI:ToggleMinimapButton()
        end
        UIDropDownMenu_AddButton(info)
        info = UIDropDownMenu_CreateInfo()
        info.text = L.SETTINGS_NO; info.arg1 = true
        info.checked = settings.hide
        info.func = function(btn, arg1)
            settings.hide = arg1
            UIDropDownMenu_SetText(mmDD, L.SETTINGS_NO)
            UI:ToggleMinimapButton()
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- UI Scale row (col 3, row 1)
    local scaleLbl = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleLbl:SetPoint("TOPLEFT", dispCol3, -30)
    scaleLbl:SetText(L.SETTINGS_UI_SCALE)
    scaleLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local scaleDD = CreateFrame("Frame", "WBAScaleDD", dispBox, "UIDropDownMenuTemplate")
    scaleDD:SetPoint("LEFT", scaleLbl, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(scaleDD, 90)
    UIDropDownMenu_SetText(scaleDD, Data:GetUIScale() .. "%")
    UIDropDownMenu_Initialize(scaleDD, function()
        for pct = 50, 300, 10 do
            local info = UIDropDownMenu_CreateInfo()
            info.text = pct .. "%"
            info.arg1 = pct
            info.checked = (Data:GetUIScale() == pct)
            info.func = function(btn, arg1)
                Data:SetUIScale(arg1)
                UIDropDownMenu_SetText(scaleDD, arg1 .. "%")
                if mainFrame then
                    mainFrame:SetScale(arg1 / 100)
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Language row (col 1, row 2)
    local langLbl = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    langLbl:SetPoint("TOPLEFT", dispCol1, -76)
    langLbl:SetText(L.SETTINGS_LANGUAGE_LABEL)
    langLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local function LocaleDisplayName(code)
        for _, entry in ipairs(WarbandAccountant.SUPPORTED_LOCALES) do
            if entry.code == code then return entry.name end
        end
        return code
    end

    local langDD = CreateFrame("Frame", "WBALanguageDD", dispBox, "UIDropDownMenuTemplate")
    langDD:SetPoint("LEFT", langLbl, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(langDD, 100)
    UIDropDownMenu_SetText(langDD, LocaleDisplayName(Data:GetLanguage()))
    UIDropDownMenu_Initialize(langDD, function()
        for _, entry in ipairs(WarbandAccountant.SUPPORTED_LOCALES) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.name
            info.arg1 = entry.code
            info.checked = (Data:GetLanguage() == entry.code)
            info.func = function(btn, arg1)
                if arg1 == Data:GetLanguage() then return end
                Data:SetLanguage(arg1)
                UIDropDownMenu_SetText(langDD, btn:GetText())
                StaticPopup_Show("WARBANDACCOUNTANT_RELOAD_UI")
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local langHelpIcon = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    langHelpIcon:SetPoint("LEFT", langDD, "RIGHT", 4, 2)
    langHelpIcon:SetText("|cFF888888(?)|r")
    local langHelpHitbox = CreateFrame("Frame", nil, dispBox)
    langHelpHitbox:SetAllPoints(langHelpIcon)
    langHelpHitbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.SETTINGS_LANGUAGE_DESC, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    langHelpHitbox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Thousands Separator row (col 2, row 2)
    local sepLbl = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sepLbl:SetPoint("TOPLEFT", dispCol2, -76)
    sepLbl:SetText(L.SETTINGS_THOUSANDS_LABEL)
    sepLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local SEP_OPTIONS = {
        { value = "",  label = L.SETTINGS_THOUSANDS_NONE },
        { value = ",", label = L.SETTINGS_THOUSANDS_COMMA },
        { value = ".", label = L.SETTINGS_THOUSANDS_PERIOD },
    }
    local function SepDisplayLabel(val)
        for _, opt in ipairs(SEP_OPTIONS) do
            if opt.value == val then return opt.label end
        end
        return L.SETTINGS_THOUSANDS_NONE
    end

    local sepDD = CreateFrame("Frame", "WBASepDD", dispBox, "UIDropDownMenuTemplate")
    sepDD:SetPoint("LEFT", sepLbl, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(sepDD, 80)
    UIDropDownMenu_SetText(sepDD, SepDisplayLabel(Data:GetThousandsSeparator()))
    UIDropDownMenu_Initialize(sepDD, function()
        for _, opt in ipairs(SEP_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.arg1 = opt.value
            info.checked = (Data:GetThousandsSeparator() == opt.value)
            info.func = function(btn, arg1)
                Data:SetThousandsSeparator(arg1)
                UIDropDownMenu_SetText(sepDD, btn:GetText())
                if activeTab == "overview" then UI:RefreshOverview() end
                if activeTab == "targets" then UI:RefreshTargets() end
                if activeTab == "ledger" then UI:RefreshLedger() end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Show changelog on update (col 3, row 2 -- the one empty grid cell)
    local changelogLbl = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    changelogLbl:SetPoint("TOPLEFT", dispCol3, -76)
    changelogLbl:SetText(L.SETTINGS_SHOW_STARTUP_MSG)
    changelogLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local changelogDD = CreateFrame("Frame", "WBAChangelogDD", dispBox, "UIDropDownMenuTemplate")
    changelogDD:SetPoint("LEFT", changelogLbl, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(changelogDD, 70)
    UIDropDownMenu_SetText(changelogDD, Data:GetShowUpdateChangelog() and L.SETTINGS_YES or L.SETTINGS_NO)
    UIDropDownMenu_Initialize(changelogDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = L.SETTINGS_YES; info.arg1 = true
        info.checked = Data:GetShowUpdateChangelog()
        info.func = function(btn, arg1)
            Data:SetShowUpdateChangelog(arg1)
            UIDropDownMenu_SetText(changelogDD, L.SETTINGS_YES)
        end
        UIDropDownMenu_AddButton(info)
        info = UIDropDownMenu_CreateInfo()
        info.text = L.SETTINGS_NO; info.arg1 = false
        info.checked = not Data:GetShowUpdateChangelog()
        info.func = function(btn, arg1)
            Data:SetShowUpdateChangelog(arg1)
            UIDropDownMenu_SetText(changelogDD, L.SETTINGS_NO)
        end
        UIDropDownMenu_AddButton(info)
    end)

    StaticPopupDialogs["WARBANDACCOUNTANT_RELOAD_UI"] = {
        text = L.SETTINGS_RELOAD_TITLE,
        button1 = L.SETTINGS_RELOAD_ACCEPT,
        button2 = L.SETTINGS_RELOAD_CANCEL,
        OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    -- -- Savings Goal | Token Price (two-column row, same widths as the top row)
    local Token = WarbandAccountant.Token
    local Goals = WarbandAccountant.Goals
    local tokenSettings = Token and Token:GetSettings()
    local tokenY = tgtY - tgtBoxH - 12
    local tokenBoxH = 340
    local goalBox  = Section(L.SETTINGS_SECTION_GOAL,  10,   tokenY, halfW, tokenBoxH)
    local tokenBox = Section(L.SETTINGS_SECTION_TOKEN, dispX, tokenY, dispW, tokenBoxH)

    -- -- Savings Goal box ------------------------------------------------------
    do
        local function Label(text, yOff)
            local fs = goalBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", 12, yOff)
            fs:SetText(text)
            fs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
            return fs
        end
        local FIELD_X = 120

        Label(L.SETTINGS_GOAL_NAME, -36)
        local nameEB = CreateFrame("EditBox", nil, goalBox, "InputBoxTemplate")
        nameEB:SetSize(200, 22)
        nameEB:SetPoint("TOPLEFT", FIELD_X, -30)
        nameEB:SetAutoFocus(false)
        nameEB:SetMaxLetters(30)

        Label(L.SETTINGS_GOAL_AMOUNT, -68)
        local amountEB = CreateFrame("EditBox", nil, goalBox, "InputBoxTemplate")
        amountEB:SetSize(110, 22)
        amountEB:SetPoint("TOPLEFT", FIELD_X, -62)
        amountEB:SetAutoFocus(false)
        amountEB:SetNumeric(true)
        amountEB:SetMaxLetters(8)
        amountEB:SetJustifyH("RIGHT")
        amountEB:SetTextInsets(2, 6, 0, 0)

        local gLbl = goalBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        gLbl:SetPoint("LEFT", amountEB, "RIGHT", 4, 0)
        gLbl:SetText(L.GOLD_SUFFIX)
        gLbl:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

        local tokenCB
        local RefreshDateDDs   -- defined with the end date row below
        local function CurrentName()
            local v = nameEB:GetText()
            if not v or v == "" then v = L.SETTINGS_GOAL_DEFAULT_NAME end
            return v
        end

        -- Pull the stored goal back into the fields
        local function LoadFields()
            local goal = Goals and Goals:GetGoal()
            nameEB:SetText(goal and goal.name or "")
            if goal and goal.useToken then
                local price = Goals:GetGoalAmount(goal)
                amountEB:SetText(price and tostring(math.floor(price / 10000)) or "")
                amountEB:Disable()
            else
                amountEB:SetText((goal and goal.amount and goal.amount > 0) and tostring(math.floor(goal.amount / 10000)) or "")
                amountEB:Enable()
            end
            if tokenCB then tokenCB:SetChecked(goal and goal.useToken or false) end
            if RefreshDateDDs then RefreshDateDDs() end
        end

        local function SaveName(self)
            if not Goals or not Goals:GetGoal() then return end  -- the amount creates the goal
            Goals:UpdateGoal({ name = CurrentName() })
            nameEB:SetText(CurrentName())
        end
        nameEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nameEB:SetScript("OnEditFocusLost", SaveName)

        local function SaveAmount(self)
            if not Goals then return end
            local goal = Goals:GetGoal()
            if goal and goal.useToken then return end
            local n = tonumber(amountEB:GetText())
            if n and n > 0 then
                Goals:UpdateGoal({ name = CurrentName(), amount = n * 10000, useToken = false })
                nameEB:SetText(CurrentName())
            elseif goal then
                -- Clearing the amount turns the goal off
                Goals:ClearGoal()
                LoadFields()
            end
        end
        amountEB:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        amountEB:SetScript("OnEditFocusLost", SaveAmount)

        tokenCB = MakeCB(goalBox, L.SETTINGS_GOAL_USE_TOKEN, 10, -96,
            function()
                local goal = Goals and Goals:GetGoal()
                return goal and goal.useToken or false
            end,
            function(v)
                if not Goals then return end
                if v then
                    Goals:UpdateGoal({ name = CurrentName(), useToken = true })
                else
                    local n = tonumber(amountEB:GetText())
                    if n and n > 0 then
                        Goals:UpdateGoal({ useToken = false, amount = n * 10000 })
                    else
                        Goals:ClearGoal()
                    end
                end
                LoadFields()
            end)

        -- Days / Weeks for the finish estimate
        Label(L.SETTINGS_GOAL_ETA_UNIT, -136)
        local unitDD = CreateFrame("Frame", "WBAGoalETAUnitDD", goalBox, "UIDropDownMenuTemplate")
        unitDD:SetPoint("TOPLEFT", FIELD_X - 18, -128)
        UIDropDownMenu_SetWidth(unitDD, 90)
        local function UnitText(u) return u == "weeks" and L.SETTINGS_GOAL_ETA_WEEKS or L.SETTINGS_GOAL_ETA_DAYS end
        UIDropDownMenu_SetText(unitDD, UnitText(Goals and Goals:GetETAUnit() or "days"))
        UIDropDownMenu_Initialize(unitDD, function()
            for _, u in ipairs({ "days", "weeks" }) do
                local info = UIDropDownMenu_CreateInfo()
                info.text    = UnitText(u)
                info.arg1    = u
                info.checked = Goals and Goals:GetETAUnit() == u
                info.func    = function(_, arg1)
                    if Goals then Goals:SetETAUnit(arg1) end
                    UIDropDownMenu_SetText(unitDD, UnitText(arg1))
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        -- End date: three dropdowns in locale order (M/D/Y for enUS), each
        -- showing its letter until a value is picked. Needs a goal first.
        Label(L.SETTINGS_GOAL_END_DATE, -172)
        local dateDDs = {}
        local function GoalDateParts()
            local goal = Goals and Goals:GetGoal()
            if goal and goal.endDate then
                local t = date("*t", goal.endDate)
                return t.year, t.month, t.day
            end
        end
        local function PickDatePart(part, value)
            if not Goals or not Goals:GetGoal() then return end
            local y, m, d = GoalDateParts()
            if not y then
                -- First pick fills the other two from today
                local t = date("*t", time())
                y, m, d = t.year, t.month, t.day
            end
            if part == "Y" then y = value elseif part == "M" then m = value else d = value end
            d = math.min(d, Goals:DaysInMonth(y, m))   -- e.g. Mar 31 -> Feb 28
            Goals:SetEndDate(Goals:MakeEndOfDay(y, m, d))
            RefreshDateDDs()
        end
        RefreshDateDDs = function()
            local hasGoal = Goals and Goals:GetGoal() ~= nil
            local y, m, d = GoalDateParts()
            local values = { Y = y, M = m, D = d }
            for part, dd in pairs(dateDDs) do
                UIDropDownMenu_SetText(dd, values[part] and tostring(values[part]) or L["SETTINGS_GOAL_DATE_" .. part])
                if hasGoal then UIDropDownMenu_EnableDropDown(dd) else UIDropDownMenu_DisableDropDown(dd) end
            end
        end

        local order = L.SETTINGS_GOAL_DATE_ORDER or "MDY"
        local dx = FIELD_X - 18
        for i = 1, #order do
            local part = order:sub(i, i)
            local dd = CreateFrame("Frame", "WBAGoalDate" .. part .. "DD", goalBox, "UIDropDownMenuTemplate")
            dd:SetPoint("TOPLEFT", dx, -164)
            UIDropDownMenu_SetWidth(dd, part == "Y" and 56 or 40)
            UIDropDownMenu_Initialize(dd, function()
                local now = date("*t", time())
                local y, m, d = GoalDateParts()
                local current = ({ Y = y, M = m, D = d })[part]
                local first, last
                if part == "M" then
                    first, last = 1, 12
                elseif part == "D" then
                    first, last = 1, Goals and Goals:DaysInMonth(y or now.year, m or now.month) or 31
                else
                    first, last = math.min(now.year, y or now.year), now.year + 5
                end
                for v = first, last do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text    = tostring(v)
                    info.arg1    = v
                    info.checked = (current == v)
                    info.func    = function(_, arg1) PickDatePart(part, arg1) end
                    UIDropDownMenu_AddButton(info)
                end
            end)
            dateDDs[part] = dd
            dx = dx + (part == "Y" and 86 or 70)
        end

        local clearDateBtn = CreateFrame("Button", nil, goalBox, "UIPanelButtonTemplate")
        clearDateBtn:SetSize(56, 22)
        clearDateBtn:SetPoint("TOPLEFT", dx + 4, -166)
        clearDateBtn:SetText(L.SETTINGS_GOAL_DATE_CLEAR)
        clearDateBtn:SetScript("OnClick", function()
            if Goals then Goals:SetEndDate(nil) end
            RefreshDateDDs()
        end)

        local clearBtn = CreateFrame("Button", nil, goalBox, "UIPanelButtonTemplate")
        clearBtn:SetSize(120, 22)
        clearBtn:SetPoint("TOPLEFT", 12, -206)
        clearBtn:SetText(L.SETTINGS_GOAL_CLEAR)
        clearBtn:SetScript("OnClick", function()
            if Goals then Goals:ClearGoal() end
            LoadFields()
        end)

        local desc = goalBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", 12, -242)
        desc:SetWidth(halfW - 24)
        desc:SetJustifyH("LEFT")
        desc:SetText(L.SETTINGS_GOAL_DESC)
        desc:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        -- Token price may load after the panel is built; refresh on show
        goalBox:SetScript("OnShow", LoadFields)
        LoadFields()
    end

    -- -- Token Price box (stacked to fit the half-width column) -----------------
    if Token and tokenSettings then
        -- Update Frequency
        local freqLbl = tokenBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        freqLbl:SetPoint("TOPLEFT", 12, -36)
        freqLbl:SetText(L.SETTINGS_TOKEN_FREQ)
        freqLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local freqDD = CreateFrame("Frame", "WBATokenFreqDD", tokenBox, "UIDropDownMenuTemplate")
        freqDD:SetPoint("LEFT", freqLbl, "RIGHT", 0, -2)
        UIDropDownMenu_SetWidth(freqDD, 110)
        local function FreqText(v)
            for _, opt in ipairs(Token.FREQUENCY_OPTIONS) do
                if opt.value == v then return string.format(L.SETTINGS_TOKEN_MINUTES_FORMAT, opt.minutes) end
            end
            return string.format(L.SETTINGS_TOKEN_MINUTES_FORMAT, 5)
        end
        UIDropDownMenu_SetText(freqDD, FreqText(tokenSettings.updateInterval))
        UIDropDownMenu_Initialize(freqDD, function()
            for _, opt in ipairs(Token.FREQUENCY_OPTIONS) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = string.format(L.SETTINGS_TOKEN_MINUTES_FORMAT, opt.minutes)
                info.arg1 = opt.value
                info.checked = (tokenSettings.updateInterval == opt.value)
                info.func = function(btn, arg1)
                    tokenSettings.updateInterval = arg1
                    UIDropDownMenu_SetText(freqDD, btn:GetText())
                    Token:RestartTicker()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        -- Floating Frame
        local showLbl = tokenBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        showLbl:SetPoint("TOPLEFT", 12, -68)
        showLbl:SetText(L.SETTINGS_TOKEN_FLOATING)
        showLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local showDD = CreateFrame("Frame", "WBATokenShowDD", tokenBox, "UIDropDownMenuTemplate")
        showDD:SetPoint("LEFT", showLbl, "RIGHT", 0, -2)
        UIDropDownMenu_SetWidth(showDD, 70)
        UIDropDownMenu_SetText(showDD, tokenSettings.showFloatingFrame ~= false and L.SETTINGS_YES or L.SETTINGS_NO)
        UIDropDownMenu_Initialize(showDD, function()
            local info = UIDropDownMenu_CreateInfo()
            info.text = L.SETTINGS_YES; info.arg1 = true
            info.checked = tokenSettings.showFloatingFrame ~= false
            info.func = function(btn, arg1)
                Token:SetShowFloatingFrame(arg1)
                UIDropDownMenu_SetText(showDD, L.SETTINGS_YES)
            end
            UIDropDownMenu_AddButton(info)
            info = UIDropDownMenu_CreateInfo()
            info.text = L.SETTINGS_NO; info.arg1 = false
            info.checked = tokenSettings.showFloatingFrame == false
            info.func = function(btn, arg1)
                Token:SetShowFloatingFrame(arg1)
                UIDropDownMenu_SetText(showDD, L.SETTINGS_NO)
            end
            UIDropDownMenu_AddButton(info)
        end)

        -- Display checkboxes, one per row
        MakeCB(tokenBox, L.SETTINGS_TOKEN_ICON, 10, -96,
            function() return tokenSettings.displayType == "icon" end,
            function(v)
                tokenSettings.displayType = v and "icon" or "text"
                Token.ApplySettings()
            end)
        MakeCB(tokenBox, L.SETTINGS_TOKEN_ARROW, 10, -120,
            function() return tokenSettings.showArrow end,
            function(v)
                tokenSettings.showArrow = v
                Token.ApplySettings()
            end)
        MakeCB(tokenBox, L.SETTINGS_TOKEN_WEEKLY, 10, -144,
            function() return tokenSettings.showWeeklyIncome == true end,
            function(v)
                tokenSettings.showWeeklyIncome = v and true or false
                Token:UpdateWeeklyLine()
            end)

        -- Alerts
        MakeCB(tokenBox, L.SETTINGS_TOKEN_ALERTS, 10, -168,
            function() return tokenSettings.alertEnabled end,
            function(v) tokenSettings.alertEnabled = v end)

        local alertLbl = tokenBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        alertLbl:SetPoint("TOPLEFT", 34, -198)
        alertLbl:SetText(L.SETTINGS_TOKEN_THRESHOLDS)
        alertLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local lowLbl = tokenBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lowLbl:SetPoint("TOPLEFT", 34, -224)
        lowLbl:SetText(L.SETTINGS_TOKEN_LOW)
        lowLbl:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)

        local lowEB = CreateFrame("EditBox", nil, tokenBox, "InputBoxTemplate")
        lowEB:SetSize(80, 22)
        lowEB:SetPoint("LEFT", lowLbl, "RIGHT", 8, 0)
        lowEB:SetAutoFocus(false)
        lowEB:SetNumeric(true)
        lowEB:SetText(tokenSettings.alertLowThreshold and tostring(tokenSettings.alertLowThreshold) or "")
        local function SaveLow(self)
            local n = tonumber(self:GetText())
            tokenSettings.alertLowThreshold = (n and n >= 0) and n or nil
        end
        lowEB:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveLow(self) end)
        lowEB:SetScript("OnEditFocusLost", SaveLow)

        local highLbl = tokenBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        highLbl:SetPoint("LEFT", lowEB, "RIGHT", 20, 0)
        highLbl:SetText(L.SETTINGS_TOKEN_HIGH)
        highLbl:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)

        local highEB = CreateFrame("EditBox", nil, tokenBox, "InputBoxTemplate")
        highEB:SetSize(80, 22)
        highEB:SetPoint("LEFT", highLbl, "RIGHT", 8, 0)
        highEB:SetAutoFocus(false)
        highEB:SetNumeric(true)
        highEB:SetText(tokenSettings.alertHighThreshold and tostring(tokenSettings.alertHighThreshold) or "")
        local function SaveHigh(self)
            local n = tonumber(self:GetText())
            tokenSettings.alertHighThreshold = (n and n >= 0) and n or nil
        end
        highEB:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveHigh(self) end)
        highEB:SetScript("OnEditFocusLost", SaveHigh)

        -- Import legacy data, description underneath
        local importBtn = CreateFrame("Button", nil, tokenBox, "UIPanelButtonTemplate")
        importBtn:SetSize(190, 22)
        importBtn:SetPoint("TOPLEFT", 10, -254)
        importBtn:SetText(L.SETTINGS_TOKEN_IMPORT)
        importBtn:SetScript("OnClick", function()
            local count, err = Token:ImportLegacyHistory()
            if err and count == 0 then
                print(L.MSG_PREFIX_RED .. err)
            else
                print(L.MSG_PREFIX_GREEN .. string.format(L.MSG_TOKEN_IMPORT_COUNT, count))
                if activeTab == "token" then UI:RefreshToken() end
            end
        end)

        local importDesc = tokenBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        importDesc:SetPoint("TOPLEFT", importBtn, "BOTTOMLEFT", 2, -6)
        importDesc:SetWidth(dispW - 24)
        importDesc:SetJustifyH("LEFT")
        importDesc:SetText(L.SETTINGS_TOKEN_IMPORT_DESC)
        importDesc:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
    end

    -- -- Danger Zone ----------------------------------------------------------
    local resetY   = tokenY - tokenBoxH - 12
    local resetBox = Section(L.SETTINGS_SECTION_DANGER, 10, resetY, cw - 20, 184)

    local function DangerBtn(label, x, yOff, onClick)
        local btn = CreateFrame("Button", nil, resetBox, "UIPanelButtonTemplate")
        btn:SetSize(160, 26)
        btn:SetPoint("TOPLEFT", x, yOff)
        btn:SetText(label)
        local regs = {btn:GetRegions()}
        for _, reg in ipairs(regs) do
            if reg:GetObjectType() == "Texture" then reg:SetVertexColor(0.7, 0.1, 0.1) end
        end
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local function DangerDesc(parent, anchor, txt)
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
        fs:SetWidth(cw - 220)
        fs:SetJustifyH("LEFT")
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
        return fs
    end

    local resetBtn = DangerBtn(L.SETTINGS_DANGER_RESET_STATS, 10, -28, function()
        StaticPopup_Show("WARBANDACCOUNTANT_RESET_TOTALS")
    end)
    DangerDesc(resetBox, resetBtn, L.SETTINGS_DANGER_RESET_STATS_DESC)

    local clearBtn = DangerBtn(L.SETTINGS_DANGER_CLEAR_LEDGER, 10, -62, function()
        StaticPopup_Show("WARBANDACCOUNTANT_CLEAR_LEDGER")
    end)
    DangerDesc(resetBox, clearBtn, L.SETTINGS_DANGER_CLEAR_LEDGER_DESC)

    local clearTokenBtn = DangerBtn(L.SETTINGS_DANGER_CLEAR_TOKEN, 10, -96, function()
        StaticPopup_Show("WARBANDACCOUNTANT_CLEAR_TOKEN_HISTORY")
    end)
    DangerDesc(resetBox, clearTokenBtn, L.SETTINGS_DANGER_CLEAR_TOKEN_DESC)

    local resetPosBtn = DangerBtn(L.SETTINGS_DANGER_RESET_POS, 10, -130, function()
        if mainFrame then
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("CENTER")
            local db = Data:GetDB()
            if db then db.framePositions = nil end
        end
        print(L.MSG_PREFIX_GREEN .. L.MSG_WINDOW_POS_RESET)
    end)

    StaticPopupDialogs["WARBANDACCOUNTANT_CLEAR_TOKEN_HISTORY"] = {
        text = L.CONFIRM_CLEAR_TOKEN_TEXT,
        button1 = L.SETTINGS_YES, button2 = L.SETTINGS_NO,
        OnAccept = function()
            local Token = WarbandAccountant.Token
            if Token then Token:ClearHistory() end
            if activeTab == "token" then UI:RefreshToken() end
            if activeTab == "tokenhistory" then UI:RefreshTokenHistory() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs["WARBANDACCOUNTANT_RESET_TOTALS"] = {
        text = L.CONFIRM_RESET_STATS_TEXT,
        button1 = L.SETTINGS_YES, button2 = L.SETTINGS_NO,
        OnAccept = function()
            Data:ResetLedgerTotals()
            print("|cFF00FF00Warband Accountant:|r " .. L.STATS_RESET_MSG)
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs["WARBANDACCOUNTANT_CLEAR_LEDGER"] = {
        text = L.CONFIRM_CLEAR_LEDGER_TEXT,
        button1 = L.SETTINGS_YES, button2 = L.SETTINGS_NO,
        OnAccept = function()
            Data:ClearLedger()
            UI:RefreshLedger()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    -- Grow the scroll content to fit everything (resetY is negative, resetBox height is 150)
    panel:SetHeight(math.abs(resetY) + 150 + 20)
end

-- ===============================================================================
-- SHARED GRAPH HELPERS (both graph tabs render through Graph.lua)
-- ===============================================================================
local Graph = WarbandAccountant.Graph

-- Y-axis labels: abbreviated gold ("262.5k") with a gold-colored "g"
local function GoldAxisLabel(goldValue)
    return Graph.Abbreviate(goldValue) .. "|cFFFFD700g|r"
end

-- Adds a colored "+1,234g" / "-1,234g" change line to a tooltip
local function AddChangeLine(tt, diff)
    local FormatGold = WarbandAccountant.FormatGold
    if diff > 0 then
        tt:AddLine("|cFF33FF33+|r" .. FormatGold(diff))
    elseif diff < 0 then
        tt:AddLine("|cFFFF4444-|r" .. FormatGold(-diff))
    end
end

-- Builds the header label + graph + stats line layout shared by both tabs.
local function CreateGraphLayout(panel, titleText, graphOpts)
    local topLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    topLabel:SetPoint("TOPLEFT", 10, -8)
    topLabel:SetText(titleText)
    topLabel:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, -32)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -32)

    local graph = Graph:Create(panel, graphOpts)
    graph:SetPoint("TOPLEFT", -10, -42)
    graph:SetSize(CONTENT_W - 10, CONTENT_H - 150)

    local statsFrame = CreateFrame("Frame", nil, panel)
    statsFrame:SetPoint("TOP", graph, "BOTTOM", 0, -12)
    statsFrame:SetSize(460, 30)

    local statsText = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("CENTER", statsFrame, "CENTER", 0, 0)

    return topLabel, graph, statsText, statsFrame
end

-- -- Time range dropdown (shared by the graph tabs) ----------------------------
-- Ranges are never remembered: each tab snaps back to its default whenever
-- it's opened (see UI:SwitchTab).
local RANGE_SECONDS = { ["24h"] = 86400, ["3d"] = 3 * 86400, ["7d"] = 7 * 86400, ["30d"] = 30 * 86400 }
local RANGE_LOCALE_KEY = { ["24h"] = "RANGE_24H", ["3d"] = "RANGE_3D", ["7d"] = "RANGE_7D", ["30d"] = "RANGE_30D", all = "RANGE_ALL" }

local function RangeText(key)
    return WarbandAccountant.L[RANGE_LOCALE_KEY[key]]
end

local function CreateRangeDropdown(panel, frameName, options, onPick)
    local L = WarbandAccountant.L
    local dd = CreateFrame("Frame", frameName, panel, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, 90)

    local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lbl:SetPoint("RIGHT", dd, "LEFT", 16, 1)
    lbl:SetText(L.RANGE_LABEL)
    lbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
    dd.label = lbl

    function dd:SetRange(key)
        self.current = key
        UIDropDownMenu_SetText(self, RangeText(key))
    end

    UIDropDownMenu_Initialize(dd, function()
        for _, key in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text    = RangeText(key)
            info.arg1    = key
            info.checked = (dd.current == key)
            info.func    = function(_, arg1)
                dd:SetRange(arg1)
                onPick(arg1)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    return dd
end

-- Trims oldest-first points to a range. Balance (step) graphs get a
-- carried-over point at the range start holding the balance it had then,
-- so the line starts at the left edge; price (line) graphs get an
-- interpolated one. Returns points, rangeStart (nil for "all"), and how
-- many real points fell inside the range.
local function FilterToRange(points, rangeKey, isStep)
    local seconds = RANGE_SECONDS[rangeKey]
    if not seconds then return points, nil, #points end

    local now = time()
    local startTS = now - seconds
    local out, before = {}, nil
    for _, p in ipairs(points) do
        if p.x < startTS then before = p else out[#out + 1] = p end
    end
    local realCount = #out

    if before then
        local y = before.y
        if not isStep and out[1] and out[1].x > before.x then
            local f = (startTS - before.x) / (out[1].x - before.x)
            y = before.y + (out[1].y - before.y) * f
        end
        table.insert(out, 1, { x = startTS, y = y, carried = true })
    end
    -- A balance with a single known value still draws as a flat line to now
    if isStep and #out == 1 then
        out[2] = { x = now, y = out[1].y, carried = true }
    end
    return out, startTS, realCount
end

-- ===============================================================================
-- GOLD HISTORY TAB (balance-over-time graph, derived entirely from the
-- existing Ledger data -- no separate tracking needed)
-- ===============================================================================
local goldHistGraph, goldHistStatsText, goldHistCurrentLabel
local goldHistFilterDropdown, goldHistCharFilter  -- nil = Warband Bank total
local goldHistNoteText
local goldHistRangeDD
local goldHistRange = "all"
local GOLDHIST_DEFAULT_RANGE = "all"

local function BuildGoldHistoryTab(panel)
    local L = WarbandAccountant.L

    local topLabel, graph, statsText, statsFrame = CreateGraphLayout(panel, L.GOLDHIST_TITLE, {
        -- A bank balance holds flat between transactions and then jumps,
        -- so a step line is the honest way to draw it.
        style       = "step",
        extendToNow = true,
        yUnit       = 10000,
        lineColor   = { 1, 0.82, 0, 1 },
        yFormatter  = GoldAxisLabel,
        onTooltip   = function(tt, point, prev, isLast)
            local FormatGold = WarbandAccountant.FormatGold
            tt:AddLine(date("%m/%d %H:%M", point.x), 0.8, 0.8, 0.8)
            tt:AddLine(FormatGold(point.y))
            if prev then AddChangeLine(tt, point.y - prev.y) end
            local e = point.entry
            if e and e.characterName then
                local who = e.characterName
                if e.note and e.note ~= "" then who = who .. ": " .. e.note end
                tt:AddLine(who, 0.6, 0.6, 0.6)
            end
            if isLast then tt:AddLine(L.GOLDHIST_CURRENT_TOOLTIP, 0, 1, 0) end
        end,
    })
    goldHistGraph = graph
    goldHistStatsText = statsText

    goldHistCurrentLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldHistCurrentLabel:SetPoint("LEFT", topLabel, "RIGHT", 20, 0)
    goldHistCurrentLabel:SetTextColor(0.2, 0.8, 0.5)
    goldHistCurrentLabel:SetJustifyH("LEFT")

    -- Character filter, top-right (same pattern as the Ledger tab)
    goldHistFilterDropdown = CreateFrame("Frame", "WBAGoldHistFilterDD", panel, "UIDropDownMenuTemplate")
    goldHistFilterDropdown:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 8, -2)
    UIDropDownMenu_SetWidth(goldHistFilterDropdown, 170)
    UIDropDownMenu_SetText(goldHistFilterDropdown, L.GOLDHIST_FILTER_WARBAND)

    local filterLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterLbl:SetPoint("RIGHT", goldHistFilterDropdown, "LEFT", 16, 1)
    filterLbl:SetText(L.LEDGER_FILTER_LABEL)
    filterLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    -- Time range, just left of the character filter
    goldHistRangeDD = CreateRangeDropdown(panel, "WBAGoldHistRangeDD", { "24h", "7d", "30d", "all" }, function(key)
        goldHistRange = key
        UI:RefreshGoldHistory()
    end)
    goldHistRangeDD:SetPoint("RIGHT", filterLbl, "LEFT", -4, -1)
    goldHistRangeDD:SetRange(GOLDHIST_DEFAULT_RANGE)

    local function InitGoldHistFilter()
        UIDropDownMenu_Initialize(goldHistFilterDropdown, function()
            local info = UIDropDownMenu_CreateInfo()
            info.text    = L.GOLDHIST_FILTER_WARBAND
            info.checked = (goldHistCharFilter == nil)
            info.func    = function()
                goldHistCharFilter = nil
                UIDropDownMenu_SetText(goldHistFilterDropdown, L.GOLDHIST_FILTER_WARBAND)
                UI:RefreshGoldHistory()
            end
            UIDropDownMenu_AddButton(info)

            local ACCOUNT_TOTAL_KEY = WarbandAccountant.ACCOUNT_TOTAL_KEY
            info = UIDropDownMenu_CreateInfo()
            info.text    = L.GOLDHIST_FILTER_ACCOUNT
            info.checked = (goldHistCharFilter == ACCOUNT_TOTAL_KEY)
            info.func    = function()
                goldHistCharFilter = ACCOUNT_TOTAL_KEY
                UIDropDownMenu_SetText(goldHistFilterDropdown, L.GOLDHIST_FILTER_ACCOUNT)
                UI:RefreshGoldHistory()
            end
            UIDropDownMenu_AddButton(info)

            local Data = WarbandAccountant.Data
            local chars = {}
            for id, d in pairs(Data:GetAllCharacters()) do
                table.insert(chars, { id=id, name=d.name, realm=d.realm })
            end
            table.sort(chars, function(a,b) return a.name < b.name end)
            for _, c in ipairs(chars) do
                local disp = c.name .. (c.realm ~= GetRealmName() and L.OTHER_REALM_SUFFIX or "")
                info = UIDropDownMenu_CreateInfo()
                info.text    = disp
                info.arg1    = c.id
                info.checked = (goldHistCharFilter == c.id)
                info.func    = function(btn, arg1)
                    goldHistCharFilter = arg1
                    UIDropDownMenu_SetText(goldHistFilterDropdown, btn:GetText())
                    UI:RefreshGoldHistory()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
    end
    goldHistFilterDropdown:SetScript("OnShow", InitGoldHistFilter)
    InitGoldHistFilter()

    goldHistNoteText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    goldHistNoteText:SetPoint("TOP", statsFrame, "BOTTOM", 0, -4)
    goldHistNoteText:SetTextColor(0.5, 0.5, 0.5)
end

function UI:RefreshGoldHistory()
    if not goldHistGraph then return end
    local Data = WarbandAccountant.Data
    local L = WarbandAccountant.L
    local FormatGold = WarbandAccountant.FormatGold

    local ACCOUNT_TOTAL_KEY = WarbandAccountant.ACCOUNT_TOTAL_KEY
    if goldHistCharFilter == ACCOUNT_TOTAL_KEY then
        goldHistNoteText:SetText(L.GOLDHIST_ACCOUNT_NOTE)
    elseif goldHistCharFilter then
        goldHistNoteText:SetText(L.GOLDHIST_CHAR_NET_NOTE)
    else
        goldHistNoteText:SetText("")
    end

    local emptyMsg = (goldHistCharFilter == ACCOUNT_TOTAL_KEY) and L.GOLDHIST_NOT_ENOUGH_ACCOUNT or L.GOLDHIST_NOT_ENOUGH_DATA
    local history = Data:GetBalanceHistory(goldHistCharFilter)

    if #history < 2 then
        goldHistStatsText:SetText(L.GOLDHIST_NO_HISTORY)
        goldHistCurrentLabel:SetText("")
        goldHistGraph:SetData(nil, emptyMsg)
        return
    end

    local all = {}
    for i, e in ipairs(history) do
        all[i] = { x = e.timestamp, y = e.value, entry = e.entry }
    end
    local points, rangeStart, realCount = FilterToRange(all, goldHistRange, true)
    goldHistCurrentLabel:SetText(L.GOLDHIST_CURRENT_PREFIX .. FormatGold(all[#all].y))

    if #points < 2 then
        goldHistStatsText:SetText(L.RANGE_NO_DATA)
        goldHistGraph:SetData(nil, L.RANGE_NO_DATA)
        return
    end

    -- High/low follow the selected range
    local minVal, maxVal = math.huge, -math.huge
    for _, p in ipairs(points) do
        if p.y < minVal then minVal = p.y end
        if p.y > maxVal then maxVal = p.y end
    end

    goldHistStatsText:SetText(string.format(L.GOLDHIST_STATS_FORMAT,
        "|cff00ff00", FormatGold(maxVal),
        "|cffff0000", FormatGold(minVal),
        realCount))

    goldHistGraph:SetData(points, emptyMsg, rangeStart and { xMin = rangeStart } or nil)
end

-- ===============================================================================
-- TOKEN GRAPH TAB
-- ===============================================================================
local tokenGraph, tokenStatsText, tokenCurrentLabel
local tokenRangeDD
local tokenRange = "7d"
local TOKEN_DEFAULT_RANGE = "7d"

local function BuildTokenTab(panel)
    local L = WarbandAccountant.L

    local topLabel, graph, statsText = CreateGraphLayout(panel, L.TOKEN_GRAPH_TITLE, {
        style      = "line",
        yUnit      = 10000,
        lineColor  = { 0.25, 0.85, 0.55, 1 },
        yFormatter = GoldAxisLabel,
        onTooltip  = function(tt, point, prev, isLast)
            local FormatGold = WarbandAccountant.FormatGold
            tt:AddLine(date("%m/%d %H:%M", point.x), 0.8, 0.8, 0.8)
            tt:AddLine(FormatGold(point.y))
            if prev then AddChangeLine(tt, point.y - prev.y) end
            if isLast then tt:AddLine(L.TOKEN_CURRENT_PRICE_TOOLTIP, 0, 1, 0) end
        end,
    })
    tokenGraph = graph
    tokenStatsText = statsText
    tokenStatsText:SetText(L.TOKEN_LOADING_STATS)

    -- Current price sits beside the title (same layout as Gold History),
    -- leaving the top-right for the range filter.
    tokenCurrentLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tokenCurrentLabel:SetPoint("LEFT", topLabel, "RIGHT", 20, 0)
    tokenCurrentLabel:SetTextColor(0.2, 0.8, 0.5)
    tokenCurrentLabel:SetJustifyH("LEFT")

    tokenRangeDD = CreateRangeDropdown(panel, "WBATokenRangeDD", { "24h", "3d", "7d" }, function(key)
        tokenRange = key
        UI:RefreshToken()
    end)
    tokenRangeDD:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 8, -2)
    tokenRangeDD:SetRange(TOKEN_DEFAULT_RANGE)
end

function UI:RefreshToken()
    if not tokenGraph then return end
    local Token = WarbandAccountant.Token
    local L = WarbandAccountant.L
    local FormatGold = Token.FormatGold

    local history = Token:GetHistory()
    if #history < 2 then
        tokenStatsText:SetText(L.TOKEN_NO_HISTORY)
        tokenCurrentLabel:SetText("")
        tokenGraph:SetData(nil, L.TOKEN_NOT_ENOUGH_DATA)
        return
    end

    local all = {}
    for i, e in ipairs(history) do
        all[i] = { x = e.timestamp, y = e.price }
    end
    local points, rangeStart, realCount = FilterToRange(all, tokenRange, false)
    tokenCurrentLabel:SetText(L.TOKEN_CURRENT_PREFIX .. FormatGold(all[#all].y))

    if #points < 2 then
        tokenStatsText:SetText(L.RANGE_NO_DATA)
        tokenGraph:SetData(nil, L.RANGE_NO_DATA)
        return
    end

    local minPrice, maxPrice = math.huge, -math.huge
    for _, p in ipairs(points) do
        if p.y < minPrice then minPrice = p.y end
        if p.y > maxPrice then maxPrice = p.y end
    end

    tokenStatsText:SetText(string.format(L.TOKEN_STATS_FORMAT,
        "|cff00ff00", FormatGold(maxPrice),
        "|cffff0000", FormatGold(minPrice),
        realCount))

    tokenGraph:SetData(points, L.TOKEN_NOT_ENOUGH_DATA, rangeStart and { xMin = rangeStart } or nil)
end

-- Snaps a graph tab's range back to its default (called whenever the tab opens)
function UI:ResetGraphRange(tabKey)
    if tabKey == "goldhistory" and goldHistRangeDD then
        goldHistRange = GOLDHIST_DEFAULT_RANGE
        goldHistRangeDD:SetRange(GOLDHIST_DEFAULT_RANGE)
    elseif tabKey == "token" and tokenRangeDD then
        tokenRange = TOKEN_DEFAULT_RANGE
        tokenRangeDD:SetRange(TOKEN_DEFAULT_RANGE)
    end
end

-- ===============================================================================
-- GOALS TAB (savings goal card + Warband Bank graph with goal line)
-- ===============================================================================
local goalsCard, goalsGraph
local GOALS_PROJECTION_CAP = 30 * 86400   -- don't project further than 30 days ahead

local function BuildGoalsTab(panel)
    local L = WarbandAccountant.L

    local topLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    topLabel:SetPoint("TOPLEFT", 10, -8)
    topLabel:SetText(L.GOALS_TITLE)
    topLabel:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, -32)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -32)

    -- Goal card
    local card = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    card:SetPoint("TOPLEFT", 6, -42)
    card:SetSize(CONTENT_W - 16, 122)
    card:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left=3, right=3, top=3, bottom=3 }
    })
    card:SetBackdropColor(0.08, 0.07, 0.04, 0.95)
    card:SetBackdropBorderColor(0.35, 0.30, 0.15, 0.8)

    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    card.name:SetPoint("TOPLEFT", 14, -12)
    card.name:SetJustifyH("LEFT")

    card.amount = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.amount:SetPoint("TOPRIGHT", -14, -14)
    card.amount:SetJustifyH("RIGHT")

    local bar = CreateFrame("StatusBar", nil, card)
    bar:SetPoint("TOPLEFT", 14, -40)
    bar:SetPoint("TOPRIGHT", -14, -40)
    bar:SetHeight(18)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.5)
    -- Thin gold outline so the bar's full length is visible against the card
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.8)
    bar.border = border

    bar.pct = border:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.pct:SetPoint("CENTER", bar, "CENTER")
    card.bar = bar

    card.eta = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.eta:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -10)
    card.eta:SetJustifyH("LEFT")

    -- End date + required pace (only when the goal has an end date)
    card.deadline = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.deadline:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -10)
    card.deadline:SetJustifyH("RIGHT")

    card.pace = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.pace:SetPoint("TOPLEFT", card.eta, "BOTTOMLEFT", 0, -8)
    card.pace:SetJustifyH("LEFT")

    card.empty = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.empty:SetPoint("CENTER")
    card.empty:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
    goalsCard = card

    -- Warband Bank graph with the goal line + projection
    goalsGraph = Graph:Create(panel, {
        style           = "step",
        extendToNow     = true,
        yUnit           = 10000,
        lineColor       = { 1, 0.82, 0, 1 },
        refLineColor    = { 0.2, 1, 0.4, 0.85 },
        projectionColor = { 1, 0.82, 0, 0.6 },
        yFormatter      = GoldAxisLabel,
        onTooltip       = function(tt, point, prev, isLast)
            local FormatGold = WarbandAccountant.FormatGold
            tt:AddLine(date("%m/%d %H:%M", point.x), 0.8, 0.8, 0.8)
            tt:AddLine(FormatGold(point.y))
            if prev then AddChangeLine(tt, point.y - prev.y) end
            if isLast then tt:AddLine(L.GOLDHIST_CURRENT_TOOLTIP, 0, 1, 0) end
        end,
    })
    goalsGraph:SetPoint("TOPLEFT", -10, -174)
    goalsGraph:SetSize(CONTENT_W - 10, CONTENT_H - 174 - 34)

    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOP", goalsGraph, "BOTTOM", 0, -8)
    note:SetTextColor(0.5, 0.5, 0.5)
    note:SetText(L.GOALS_GRAPH_NOTE)
end

function UI:RefreshGoals()
    if not goalsCard then return end
    local L = WarbandAccountant.L
    local Data = WarbandAccountant.Data
    local Goals = WarbandAccountant.Goals
    local FormatGold = WarbandAccountant.FormatGold
    local card = goalsCard

    local goal = Goals:GetGoal()
    local balance = Goals:GetSpareGold()
    local amount = goal and Goals:GetGoalAmount(goal)

    -- -- Card --
    card.deadline:SetText("")
    card.pace:SetText("")
    if not goal then
        card.name:Hide(); card.amount:Hide(); card.bar:Hide(); card.eta:Hide()
        card.empty:SetText(L.GOALS_NONE)
        card.empty:Show()
    else
        card.empty:Hide()
        card.name:Show(); card.amount:Show(); card.bar:Show(); card.eta:Show()
        card.name:SetText((goal.name or "") .. (goal.useToken and L.GOALS_TOKEN_SUFFIX or ""))

        if not amount then
            -- Token goal before the price has loaded
            card.amount:SetText("")
            card.bar:SetValue(0)
            card.bar.pct:SetText("")
            card.bar:SetStatusBarColor(1, 0.82, 0)
            card.eta:SetText(L.GOALS_WAITING_PRICE)
            card.eta:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
        else
            local pct = math.max(0, math.min(1, balance / amount))
            card.amount:SetText(FormatGold(balance) .. "  /  " .. FormatGold(amount))
            card.bar:SetValue(pct)
            card.bar.pct:SetText(string.format("%d%%", math.floor(pct * 100)))
            if balance >= amount then
                card.bar:SetStatusBarColor(0.2, 0.9, 0.3)
                card.eta:SetText(L.GOALS_MET)
                card.eta:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
            else
                card.bar:SetStatusBarColor(1, 0.82, 0)
                local secs = Goals:GetSecondsToAmount(amount, balance)
                card.eta:SetText(Goals:FormatETA(secs))
                if secs then
                    card.eta:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
                else
                    card.eta:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
                end
            end
        end

        -- End date line + pace check
        if goal.endDate then
            local dateStr = date(L.GOAL_DATE_FORMAT, goal.endDate)
            local met = amount and balance >= amount
            if goal.endDate <= time() and not met then
                card.deadline:SetText(string.format(L.GOAL_DEADLINE_PASSED, dateStr))
                card.deadline:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
            else
                card.deadline:SetText(string.format(L.GOAL_DEADLINE, dateStr, Goals:FormatTimeLeft(goal.endDate)))
                card.deadline:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
            end

            local required = Goals:GetRequiredRate(goal, amount, balance)
            if required then
                local txt = string.format(L.GOAL_NEED, Goals:FormatPerPeriod(required))
                local rate = Goals:GetIncomeRate(balance)
                if rate and rate >= required then
                    txt = txt .. "  |cFF33FF33" .. L.GOAL_ON_PACE .. "|r"
                else
                    local short = required - math.max(rate or 0, 0)
                    txt = txt .. "  |cFFFF4444" .. string.format(L.GOAL_BEHIND_PACE, Goals:FormatPerPeriod(short)) .. "|r"
                end
                card.pace:SetText(txt)
            end
        end
    end

    -- -- Graph: last 30 days of the Warband Bank --
    local all = {}
    for i, e in ipairs(Data:GetBalanceHistory(nil)) do
        all[i] = { x = e.timestamp, y = e.value }
    end
    local points, rangeStart = FilterToRange(all, "30d", true)

    local view = { xMin = rangeStart }
    if amount then
        view.refLine = { y = amount, label = L.GOALS_GRAPH_LINE_LABEL .. " " .. GoldAxisLabel(amount / 10000) }
        if balance < amount then
            local rate = Goals:GetIncomeRate(balance)
            if rate and rate > 0 then
                local now = time()
                local secs = (amount - balance) / rate
                local x2, y2 = now + secs, amount
                if secs > GOALS_PROJECTION_CAP then
                    x2 = now + GOALS_PROJECTION_CAP
                    y2 = balance + rate * GOALS_PROJECTION_CAP
                end
                view.projection = { x1 = now, y1 = balance, x2 = x2, y2 = y2 }
            end
        end
    end

    -- End date: dashed red marker + dashed blue "required pace" line from
    -- today to the goal at the deadline (both clipped to the same 30-day
    -- look-ahead as the projection, so history doesn't get squashed).
    if goal and goal.endDate and amount then
        local now = time()
        local horizon = now + GOALS_PROJECTION_CAP
        if goal.endDate <= horizon and goal.endDate >= (rangeStart or 0) then
            view.vLine = { x = goal.endDate, label = L.GOALS_GRAPH_DEADLINE_LABEL, color = { 1, 0.4, 0.4, 0.8 } }
        end
        local required = Goals:GetRequiredRate(goal, amount, balance)
        if required then
            local x2, y2 = goal.endDate, amount
            if x2 > horizon then
                x2 = horizon
                y2 = balance + required * GOALS_PROJECTION_CAP
            end
            view.extraLines = { { x1 = now, y1 = balance, x2 = x2, y2 = y2, color = { 0.4, 0.7, 1, 0.8 } } }
        end
    end
    goalsGraph:SetData(points, L.GOALS_GRAPH_NOT_ENOUGH, view)
end

-- The Goals nav button only shows while a goal is set. It sits mid-list
-- (between Ledger and Gold History), so Gold History re-anchors to close
-- the gap when it's hidden.
function UI:UpdateGoalsNavVisibility()
    local btnGoals, btnGoldHist, btnLedger = navButtons.goals, navButtons.goldhistory, navButtons.ledger
    if not mainFrame or not btnGoals or not btnGoldHist or not btnLedger then return end
    local hasGoal = WarbandAccountant.Goals and WarbandAccountant.Goals:GetGoal() ~= nil
    btnGoldHist:ClearAllPoints()
    if hasGoal then
        btnGoals:Show()
        btnGoldHist:SetPoint("TOP", btnGoals, "BOTTOM", 0, 0)
    else
        btnGoals:Hide()
        btnGoldHist:SetPoint("TOP", btnLedger, "BOTTOM", 0, 0)
        if activeTab == "goals" then
            UI:SwitchTab("overview")
        end
    end
end

-- Called by Goals whenever the goal or the Warband Bank changes
function UI:OnGoalsChanged()
    UI:UpdateGoalsNavVisibility()
    if not mainFrame or not mainFrame:IsShown() then return end
    if activeTab == "goals" then
        UI:RefreshGoals()
    elseif activeTab == "overview" then
        UI:RefreshOverview()
    end
end

-- ===============================================================================
-- TOKEN HISTORY TAB (ledger-style list of all stored price entries)
-- ===============================================================================
local tokenHistScrollContent
local tokenHistRowPool = {}
local tokenHistStatsText
local tokenHistEmptyText

local function BuildTokenHistoryTab(panel)
    local L = WarbandAccountant.L
    local col = { time=10, price=200, change=420 }
    panel._col = col

    tokenHistStatsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tokenHistStatsText:SetPoint("TOPLEFT", 10, -8)
    tokenHistStatsText:SetWidth(CONTENT_W - 30)
    tokenHistStatsText:SetJustifyH("LEFT")

    local hdrY = -32
    local function Hdr(txt, x)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, hdrY)
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        return fs
    end
    Hdr(L.COL_TIME,   col.time)
    Hdr(L.COL_PRICE,  col.price)
    Hdr(L.COL_CHANGE, col.change)

    MakeSeparator(panel, hdrY - 14)
    local sf, sc = CreateScrollArea(panel, 0, hdrY - 22, CONTENT_W, CONTENT_H - 60)
    tokenHistScrollContent = sc

    tokenHistEmptyText = tokenHistScrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tokenHistEmptyText:SetPoint("CENTER", 0, 0)
    tokenHistEmptyText:Hide()
end

function UI:RefreshTokenHistory()
    if not tokenHistScrollContent then return end
    local Token = WarbandAccountant.Token
    local L = WarbandAccountant.L
    local FormatGold = Token.FormatGold
    local FormatTime = function(ts) return date("%m/%d %H:%M", ts) end

    local data = Token:GetHistory()
    tokenHistStatsText:SetText(string.format(L.TOKENHIST_TOTAL_FORMAT, #data))

    if #data == 0 then
        HideExtraPooledRows(tokenHistRowPool, 1)
        tokenHistEmptyText:SetText(L.TOKENHIST_EMPTY)
        tokenHistEmptyText:Show()
        tokenHistScrollContent:SetHeight(300)
        return
    end
    tokenHistEmptyText:Hide()

    local panel = mainFrame.panels.tokenhistory
    local col = panel._col

    local function CreateTokenHistRow(parent)
        local row = CreateFrame("Frame", nil, parent)
        row:SetSize(CONTENT_W - 30, 24)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.timeFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.timeFs:SetPoint("LEFT", col.time, 0)
        row.timeFs:SetJustifyH("LEFT")
        row.timeFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        row.priceFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.priceFs:SetPoint("LEFT", col.price, 0)
        row.priceFs:SetJustifyH("LEFT")

        row.changeFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.changeFs:SetPoint("LEFT", col.change, 0)
        row.changeFs:SetJustifyH("LEFT")

        return row
    end

    -- Show most recent first
    local yOff = 0
    for i = #data, 1, -1 do
        local entry = data[i]
        local prevEntry = data[i - 1]
        local rowIdx = #data - i + 1

        local row = GetPooledRow(tokenHistRowPool, rowIdx, tokenHistScrollContent, CreateTokenHistRow)
        row:SetPoint("TOPLEFT", 0, yOff)

        if rowIdx % 2 == 0 then
            row.bg:SetColorTexture(0.15, 0.14, 0.10, 0.35)
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end

        row.timeFs:SetText(FormatTime(entry.timestamp))
        row.priceFs:SetText(FormatGold(entry.price))

        if prevEntry then
            local diff = entry.price - prevEntry.price
            if diff > 0 then
                row.changeFs:SetText("|cFF33FF33+" .. FormatGold(diff) .. "|r")
            elseif diff < 0 then
                row.changeFs:SetText("|cFFFF4444-" .. FormatGold(-diff) .. "|r")
            else
                row.changeFs:SetText("|cFF888888" .. L.TOKENHIST_NO_CHANGE .. "|r")
            end
        else
            row.changeFs:SetText("|cFF888888--|r")
        end

        yOff = yOff - 24
    end
    HideExtraPooledRows(tokenHistRowPool, #data + 1)
    tokenHistScrollContent:SetHeight(math.max(300, math.abs(yOff)))
end

-- ===============================================================================
-- CHANGELOG TAB
-- ===============================================================================
local changelogScrollContent

local function BuildChangelogTab(panel)
    local sf, sc = CreateScrollArea(panel, 0, -10, CONTENT_W, CONTENT_H - 20)
    changelogScrollContent = sc
end

function UI:RefreshChangelog()
    if not changelogScrollContent then return end
    local L = WarbandAccountant.L

    if changelogScrollContent._rows then
        for _, w in ipairs(changelogScrollContent._rows) do w:Hide() end
    end
    changelogScrollContent._rows = {}

    local VERSIONS  = WarbandAccountant.ChangelogVersions or {}
    local CHANGELOG = WarbandAccountant.Changelog or {}
    local PAD       = 14
    local cw        = CONTENT_W - 50
    local yOff      = -PAD

    local function AddText(fontObj, txt, x, color, wOverride)
        local fs = changelogScrollContent:CreateFontString(nil, "OVERLAY", fontObj)
        fs:SetPoint("TOPLEFT", x, yOff)
        fs:SetWidth(wOverride or (cw - x))
        fs:SetJustifyH("LEFT")
        fs:SetText(txt)
        if color then fs:SetTextColor(color.r, color.g, color.b) end
        table.insert(changelogScrollContent._rows, fs)
        return fs
    end

    for vi, version in ipairs(VERSIONS) do
        local entries = CHANGELOG[version]
        if entries then
            local vh = AddText("GameFontNormalLarge", L.CHANGELOG_VERSION_PREFIX .. version, PAD, COLOR_GOLD)
            yOff = yOff - 22

            local uline = changelogScrollContent:CreateTexture(nil, "ARTWORK")
            uline:SetColorTexture(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.25)
            uline:SetHeight(1)
            uline:SetPoint("TOPLEFT", PAD, yOff)
            uline:SetWidth(cw - PAD)
            table.insert(changelogScrollContent._rows, uline)
            yOff = yOff - 8

            for _, entry in ipairs(entries) do
                if entry.tag then
                    local tagColor, tagLabel
                    if entry.tag == "New"     then tagColor = "|cFF44FF88"; tagLabel = L.CHANGELOG_TAG_NEW
                    elseif entry.tag == "Fix" then tagColor = "|cFFFF9944"; tagLabel = L.CHANGELOG_TAG_FIX
                    else                           tagColor = "|cFF00CCFF"; tagLabel = L.CHANGELOG_TAG_IMPROVE end
                    local fs = AddText("GameFontHighlight",
                        tagColor .. "[" .. tagLabel .. "]|r " .. entry.text, PAD)
                    yOff = yOff - 20
                else
                    local fs = AddText("GameFontHighlightSmall", entry.text, PAD + 16, COLOR_GREY)
                    yOff = yOff - math.max(16, fs:GetStringHeight() + 2)
                end
                yOff = yOff - 4
            end

            if vi < #VERSIONS then yOff = yOff - 12 end
        end
    end

    changelogScrollContent:SetHeight(math.max(400, math.abs(yOff) + PAD))
end

-- ===============================================================================
-- GUILDS TAB (only shown when 2+ guild banks are being tracked)
-- ===============================================================================
local guildsTotalCard
local guildsScroll, guildsContent

local function BuildGuildsTab(panel)
    local L = WarbandAccountant.L
    local titleFs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFs:SetPoint("TOPLEFT", 6, -6)
    titleFs:SetText(L.GUILDS_TITLE)
    titleFs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

    local subFs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -4)
    subFs:SetText(L.GUILDS_SUBTITLE)
    subFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    guildsTotalCard = CreateStatCard(panel, L.GUILDS_TOTAL_CARD, 6, -56, 260, 85)

    local col = { name = 10, gold = 270, realm = 450, updated = 610 }
    local hdrY = -156

    local function Hdr(txt, x)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", x, hdrY)
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        return fs
    end
    Hdr(L.COL_GUILD,        col.name)
    Hdr(L.COL_GOLD,         col.gold)
    Hdr(L.COL_REALM,        col.realm)
    Hdr(L.COL_LAST_SYNCED,  col.updated)

    MakeSeparator(panel, hdrY - 16)

    local scrollH = CONTENT_H - 156 - 40
    guildsScroll, guildsContent = CreateScrollArea(panel, 0, hdrY - 24, CONTENT_W, scrollH)
    panel._guildsCol = col
end

function UI:RefreshGuilds()
    if not mainFrame or not mainFrame.panels.guilds then return end
    local Data = WarbandAccountant.Data
    local L = WarbandAccountant.L

    local total = Data:GetTotalGuildBankGold()
    guildsTotalCard.value:SetText(WarbandAccountant.FormatGold(total))
    guildsTotalCard.value:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

    local col = mainFrame.panels.guilds._guildsCol
    if guildsContent._rows then
        for _, r in ipairs(guildsContent._rows) do r:Hide() end
    end
    guildsContent._rows = {}

    local guilds     = Data:GetAllGuildBankData()
    local homeGuild  = Data:GetHomeGuild()

    if homeGuild then
        table.sort(guilds, function(a, b)
            if a.name == homeGuild and b.name ~= homeGuild then return true end
            if b.name == homeGuild and a.name ~= homeGuild then return false end
            return a.name < b.name
        end)
    end

    local yOff = 0
    for i, g in ipairs(guilds) do
        local row = CreateFrame("Frame", nil, guildsContent)
        row:SetSize(CONTENT_W - 30, ROW_H)
        row:SetPoint("TOPLEFT", 0, yOff)

        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.14, 0.10, 0.4)
        end

        local isHome = (g.name == homeGuild)
        local nameStr = g.name .. (isHome and ("  |cFF00FF00" .. L.GUILDS_HOME_TAG .. "|r") or "")
        local nameClr = isHome and COLOR_GOLD or COLOR_WHITE

        local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetPoint("LEFT", col.name, 0)
        nameFs:SetWidth(250)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText(nameStr)
        nameFs:SetTextColor(nameClr.r, nameClr.g, nameClr.b)

        local goldFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        goldFs:SetPoint("LEFT", col.gold, 0)
        goldFs:SetWidth(170)
        goldFs:SetJustifyH("LEFT")
        goldFs:SetText(WarbandAccountant.FormatGold(g.gold))

        local realmFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        realmFs:SetPoint("LEFT", col.realm, 0)
        realmFs:SetWidth(150)
        realmFs:SetJustifyH("LEFT")
        realmFs:SetText(g.realm or "?")
        realmFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local updFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        updFs:SetPoint("LEFT", col.updated, 0)
        updFs:SetWidth(140)
        updFs:SetJustifyH("LEFT")
        updFs:SetText(g.lastUpdate and FormatTimestamp(g.lastUpdate) or "--")
        updFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        table.insert(guildsContent._rows, row)
        yOff = yOff - ROW_H
    end
    guildsContent:SetHeight(math.max(300, math.abs(yOff)))
end

-- Shows/hides the "Guilds" nav entry based on how many guild banks are
-- currently tracked. Only worth its own tab once there's more than one
-- to compare -- a single guild is already visible on the Overview tab.
function UI:UpdateGuildNavVisibility()
    if not mainFrame or not navButtons.guilds then return end
    local count = #WarbandAccountant.Data:GetKnownGuildNames()
    if count >= 2 then
        navButtons.guilds:Show()
    else
        navButtons.guilds:Hide()
        if activeTab == "guilds" then
            UI:SwitchTab("overview")
        end
    end
end

-- ===============================================================================
-- SUPPORT TAB
-- ===============================================================================
local function BuildSupportTab(panel)
    local L = WarbandAccountant.L
    local titleFs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFs:SetPoint("TOPLEFT", 6, -6)
    titleFs:SetText(L.SUPPORT_TITLE)
    titleFs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

    local subFs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subFs:SetPoint("TOPLEFT", titleFs, "BOTTOMLEFT", 0, -4)
    subFs:SetText(L.SUPPORT_SUBTITLE)
    subFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local textX = 300 -- fixed so both rows' description/URL line up regardless of logo width

    local function LinkRow(desc, url, yOff, iconTexture, iconWidth, iconHeight)
        local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        box:SetSize(CONTENT_W - 20, 78)
        box:SetPoint("TOPLEFT", 6, yOff)
        box:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=12,
            insets={ left=3, right=3, top=3, bottom=3 }
        })
        box:SetBackdropColor(0.06, 0.05, 0.03, 0.95)
        box:SetBackdropBorderColor(0.35, 0.30, 0.15, 0.7)

        local icon = box:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconWidth, iconHeight)
        icon:SetPoint("LEFT", 20, 0)
        icon:SetTexture(iconTexture)

        local descFs = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        descFs:SetPoint("TOPLEFT", textX, -12)
        descFs:SetWidth(CONTENT_W - 40 - textX)
        descFs:SetJustifyH("LEFT")
        descFs:SetText(desc)
        descFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local eb = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
        eb:SetSize(CONTENT_W - 60 - textX - 130, 22)
        eb:SetPoint("TOPLEFT", textX + 4, -50)
        eb:SetAutoFocus(false)
        eb:SetText(url)
        eb:SetCursorPosition(0)
        eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        eb:SetScript("OnTextChanged", function(self, isUserInput)
            -- isUserInput is only true for real typing/pasting/deleting, not
            -- for the SetText call below, so this can't loop -- it just snaps
            -- straight back to the real URL the instant someone edits it.
            if isUserInput then
                self:SetText(url)
                self:SetCursorPosition(0)
                self:HighlightText()
            end
        end)

        local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("LEFT", eb, "RIGHT", 8, 0)
        hint:SetText(L.SUPPORT_COPY_HINT)

        return box
    end

    LinkRow(L.SUPPORT_DISCORD_DESC,
        "https://discord.gg/TDtKmmKGbU", -46,
        "Interface\\AddOns\\WarbandAccountant\\Textures\\discord", 265, 40)
    LinkRow(L.SUPPORT_GITHUB_DESC,
        "https://github.com/I-AM-T3X/WarbandAccountant/issues", -136,
        "Interface\\AddOns\\WarbandAccountant\\Textures\\github", 175, 40)

    -- -- Supporters -------------------------------------------------------------
    local supHeaderFs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    supHeaderFs:SetPoint("TOPLEFT", 6, -230)
    supHeaderFs:SetText(L.SUPPORTERS_TITLE)
    supHeaderFs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

    local supDescFs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    supDescFs:SetPoint("TOPLEFT", supHeaderFs, "BOTTOMLEFT", 0, -4)
    supDescFs:SetText(L.SUPPORTERS_THANKS)
    supDescFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local supBoxY = -270
    local supBoxW = CONTENT_W - 20
    local supBoxH = CONTENT_H - math.abs(supBoxY) - 10 -- fill the rest of the panel
    local supBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    supBox:SetSize(supBoxW, supBoxH)
    supBox:SetPoint("TOPLEFT", 6, supBoxY)
    supBox:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={ left=3, right=3, top=3, bottom=3 }
    })
    supBox:SetBackdropColor(0.06, 0.05, 0.03, 0.95)
    supBox:SetBackdropBorderColor(0.35, 0.30, 0.15, 0.7)

    local supporters = WarbandAccountant.Supporters or {}

    if #supporters == 0 then
        local emptyFs = supBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        emptyFs:SetPoint("TOPLEFT", 12, -12)
        emptyFs:SetText(L.SUPPORTERS_EMPTY)
        emptyFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
    else
        local names = {}
        for _, n in ipairs(supporters) do table.insert(names, n) end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)

        local sSf, sSc = CreateScrollArea(supBox, 6, -8, supBoxW - 12, supBoxH - 16)

        local COLS = 5
        local rowH = 22
        local colW = math.floor((supBoxW - 12 - 24) / COLS)

        for i, name in ipairs(names) do
            local col = (i - 1) % COLS
            local row = math.floor((i - 1) / COLS)
            local nameFs = sSc:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameFs:SetPoint("TOPLEFT", col * colW + 4, -(row * rowH) - 4)
            nameFs:SetWidth(colW - 8)
            nameFs:SetJustifyH("LEFT")
            nameFs:SetText(name)
            nameFs:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
        end

        local numRows = math.ceil(#names / COLS)
        sSc:SetHeight(math.max(supBoxH - 16, numRows * rowH + 8))
    end
end

-- ===============================================================================
-- MAIN WINDOW
-- ===============================================================================
local function CreateMainWindow()
    local L = WarbandAccountant.L
    local f = CreateFrame("Frame", "WarbandAccountantMainFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIN_W, WIN_H)

    local Data = WarbandAccountant.Data
    local db   = Data:GetDB()
    f:SetScale((Data:GetUIScale() or 100) / 100)
    db.framePositions = db.framePositions or {}
    if db.framePositions.main and db.framePositions.main.point then
        f:SetPoint(db.framePositions.main.point, db.framePositions.main.x, db.framePositions.main.y)
    else
        f:SetPoint("CENTER")
    end


    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        db.framePositions.main = { point=point, x=x, y=y }
    end)


    f:SetFrameStrata("HIGH")
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide(); self:SetPropagateKeyboardInput(false)
        else self:SetPropagateKeyboardInput(true) end
    end)
    tinsert(UISpecialFrames, f:GetName())

    f.TitleBg:SetHeight(25)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", f.TitleBg, "TOP", 0, -6)
    title:SetText("Warband Accountant")

    -- -- Nav panel ------------------------------------------------------------
    local nav = CreateFrame("Frame", nil, f, "BackdropTemplate")
    nav:SetSize(NAV_W, WIN_H - 36)
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -30)
    nav:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=10,
        insets={ left=2, right=2, top=2, bottom=2 }
    })
    nav:SetBackdropColor(0.06, 0.05, 0.03, 0.98)
    nav:SetBackdropBorderColor(0.35, 0.30, 0.15, 0.6)

    -- Top nav buttons
    local btnOverview  = CreateNavButton(nav, "  " .. L.NAV_OVERVIEW,  "overview",  -8)
    local btnTargets   = CreateNavButton(nav, "  " .. L.NAV_TARGETS,   "targets",   nil, btnOverview)
    local btnLedger    = CreateNavButton(nav, "  " .. L.NAV_LEDGER,    "ledger",       nil, btnTargets)
    local btnGoals     = CreateNavButton(nav, "  " .. L.NAV_GOALS,     "goals",        nil, btnLedger)
    local btnGoldHist  = CreateNavButton(nav, "  " .. L.NAV_GOLDHISTORY, "goldhistory", nil, btnGoals)
    local btnToken     = CreateNavButton(nav, "  " .. L.NAV_TOKEN,     "token",        nil, btnGoldHist)
    local btnTokenHist = CreateNavButton(nav, "  " .. L.NAV_TOKENHISTORY, "tokenhistory", nil, btnToken)
    local btnGuilds    = CreateNavButton(nav, "  " .. L.NAV_GUILDS,    "guilds",       nil, btnTokenHist)

    -- Bottom nav buttons (anchored from the bottom up)
    local btnSupport = CreateFrame("Button", nil, nav)
    btnSupport:SetSize(NAV_W, NAV_BTN_H)
    btnSupport:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 0, 4)

    local btnChangelog = CreateFrame("Button", nil, nav)
    btnChangelog:SetSize(NAV_W, NAV_BTN_H)
    btnChangelog:SetPoint("BOTTOM", btnSupport, "TOP", 0, 0)

    local btnSettings  = CreateFrame("Button", nil, nav)
    btnSettings:SetSize(NAV_W, NAV_BTN_H)
    btnSettings:SetPoint("BOTTOM", btnChangelog, "TOP", 0, 0)

    -- Separator between top and bottom groups
    local navSep = nav:CreateTexture(nil, "ARTWORK")
    navSep:SetColorTexture(0.3, 0.27, 0.12, 0.5)
    navSep:SetHeight(1)
    navSep:SetPoint("BOTTOMLEFT", btnSettings, "TOPLEFT",  0, 0)
    navSep:SetPoint("BOTTOMRIGHT", btnSettings, "TOPRIGHT", 0, 0)

    -- Style bottom buttons same as top
    local function StyleBottomBtn(btn, label, tabKey)
        local accent = btn:CreateTexture(nil, "ARTWORK")
        accent:SetWidth(3)
        accent:SetPoint("TOPLEFT", 0, 0)
        accent:SetPoint("BOTTOMLEFT", 0, 0)
        accent:SetColorTexture(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 1)
        accent:Hide()
        btn.accent = accent

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)
        btn.bg = bg

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.06)

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", 18, 0)
        fs:SetText(label)
        fs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
        btn.label = fs

        function btn:SetActive(isActive)
            if isActive then
                self.accent:Show()
                self.bg:SetColorTexture(0.12, 0.10, 0.04, 0.9)
                self.label:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
                self.label:SetFontObject("GameFontHighlight")
            else
                self.accent:Hide()
                self.bg:SetColorTexture(0, 0, 0, 0)
                self.label:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
                self.label:SetFontObject("GameFontNormal")
            end
        end

        btn:SetScript("OnClick", function() UI:SwitchTab(tabKey) end)
        navButtons[tabKey] = btn
    end

    StyleBottomBtn(btnSettings,  "  " .. L.NAV_SETTINGS,  "settings")
    StyleBottomBtn(btnChangelog, "  " .. L.NAV_CHANGELOG, "changelog")
    StyleBottomBtn(btnSupport,   "  " .. L.NAV_SUPPORT,   "support")

    -- -- Content panels -------------------------------------------------------
    local function MakePanel()
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT",     f, "TOPLEFT",     NAV_W + 10, -32)
        p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6,          6)
        p:Hide()
        return p
    end

    f.panels = {
        overview     = MakePanel(),
        targets      = MakePanel(),
        ledger       = MakePanel(),
        goldhistory  = MakePanel(),
        goals        = MakePanel(),
        token        = MakePanel(),
        tokenhistory = MakePanel(),
        guilds       = MakePanel(),
        settings     = MakePanel(),
        changelog    = MakePanel(),
        support      = MakePanel(),
    }

    BuildOverviewTab(f.panels.overview)
    BuildTargetsTab(f.panels.targets)
    BuildLedgerTab(f.panels.ledger)
    BuildGoldHistoryTab(f.panels.goldhistory)
    BuildGoalsTab(f.panels.goals)
    BuildTokenTab(f.panels.token)
    BuildTokenHistoryTab(f.panels.tokenhistory)
    BuildGuildsTab(f.panels.guilds)
    BuildSettingsTab(f.panels.settings)
    BuildChangelogTab(f.panels.changelog)
    BuildSupportTab(f.panels.support)

    mainFrame = f

    f:HookScript("OnHide", function()
        if UI.HideTutorialTips then
            UI:HideTutorialTips()
        end
    end)

    UI:UpdateGuildNavVisibility()
    UI:UpdateGoalsNavVisibility()

    -- Default to overview
    UI:SwitchTab("overview")

    return f
end

-- ===============================================================================
-- MINIMAP TOOLTIP
-- ===============================================================================
local function SetupTooltip(tooltip)
    local Data = WarbandAccountant.Data
    local L = WarbandAccountant.L
    tooltip:AddLine("Warband Accountant", 1, 0.82, 0)
    tooltip:AddLine(" ")

    local warbandGold = WarbandAccountant.Core:GetWarbandGold()
    tooltip:AddDoubleLine(L.OVERVIEW_CARD_WARBAND .. ":", WarbandAccountant.FormatGold(warbandGold), 0.8, 0.8, 0, 1, 1, 0)

    -- Only show Token price in the tooltip if the floating Token frame is hidden,
    -- since otherwise the price is already visible on screen at all times.
    local Token = WarbandAccountant.Token
    if Token then
        local tokenSettings = Token:GetSettings()
        if tokenSettings and tokenSettings.showFloatingFrame == false then
            local tokenPrice = Token:GetCurrentPrice()
            if tokenPrice then
                tooltip:AddDoubleLine(L.OVERVIEW_CARD_TOKEN .. ":", Token.FormatGold(tokenPrice), 0.8, 0.8, 0.8, 1, 1, 1)
            end
        end
    end

    local totalGold = Data:GetTotalTrackedGold()
    tooltip:AddDoubleLine(L.OVERVIEW_CARD_BAGS .. ":", WarbandAccountant.FormatGold(totalGold), 0.8, 0.8, 0.8, 1, 1, 1)

    local weekly = Data:GetWeeklyIncome()
    local wc = weekly >= 0
    tooltip:AddDoubleLine(L.OVERVIEW_CARD_WEEK .. ":",
        (wc and "|cFF33FF33+" or "|cFFFF4444") .. WarbandAccountant.FormatGold(weekly) .. "|r",
        0.8, 0.8, 0.8, 1, 1, 1)

    tooltip:AddLine(" ")
    tooltip:AddLine(L.TOOLTIP_CLICK_OPEN .. "Warband Accountant", 0.5, 0.5, 0.5)
end

-- ===============================================================================
-- PUBLIC INTERFACE
-- ===============================================================================
function UI:Init()
    local L = WarbandAccountant.L
    if not hasLDB or not hasLibDBIcon then
        print(L.MSG_PREFIX_RED .. L.MSG_NO_LIBDBICON)
        return
    end

    local LDB       = LibStub("LibDataBroker-1.1")
    local libDBIcon = LibStub("LibDBIcon-1.0")
    local Data      = WarbandAccountant.Data

    minimapLDB = LDB:NewDataObject("WarbandAccountant", {
        type = "launcher",
        text = "Warband Accountant",
        icon = "Interface\\AddOns\\WarbandAccountant\\Textures\\minimap",
        OnClick = function(self, button)
            UI:Toggle(button == "RightButton" and "settings" or "overview")
        end,
        OnTooltipShow = function(tooltip) SetupTooltip(tooltip) end,
    })

    libDBIcon:Register("WarbandAccountant", minimapLDB, Data:GetSettings())
end

function UI:Toggle(tabKey)
    local justCreated = false
    if not mainFrame then
        CreateMainWindow()
        justCreated = true
    end
    -- A brand-new window always ends up shown -- CreateMainWindow() leaves
    -- it visible and already on "overview", which would otherwise look
    -- identical to "already open on the requested tab" below and get
    -- immediately hidden again on this same call (the bug: minimap button
    -- doing nothing on the very first click, only working on the second).
    if not justCreated and mainFrame:IsShown() and activeTab == (tabKey or "overview") then
        mainFrame:Hide()
    else
        mainFrame:Show()
        UI:SwitchTab(tabKey or "overview")
    end
end

-- -- Public accessors for other modules (e.g. Tutorial.lua) ------------------
-- Kept deliberately narrow: mainFrame/navButtons/activeTab stay private to
-- this file, other modules go through these instead of reaching in directly.

-- Ensures the main window exists and is visible. Does not change tabs.
function UI:EnsureWindowOpen()
    if not mainFrame then CreateMainWindow() end
    if not mainFrame:IsShown() then
        mainFrame:Show()
    end
end

-- Returns the main window frame, creating it first if needed. Useful as a
-- HelpTip/tooltip parent.
function UI:GetMainFrame()
    if not mainFrame then CreateMainWindow() end
    return mainFrame
end

-- Returns the nav button frame for a tab key, or nil if that tab doesn't
-- exist yet (window never opened) or is currently hidden (e.g. Guild Banks
-- before 2+ guilds are synced).
function UI:GetNavButtonFrame(tabKey)
    local btn = navButtons[tabKey]
    if not btn or not btn:IsShown() then return nil end
    return btn
end

function UI:GetActiveTab()
    return activeTab
end

function UI:OnTokenPriceUpdated()
    -- A WoW Token goal can be met by the price dropping, even with the
    -- window closed.
    if WarbandAccountant.Goals then WarbandAccountant.Goals:Check() end
    if not mainFrame or not mainFrame:IsShown() then return end
    if activeTab == "overview" then
        UI:RefreshOverview()
    elseif activeTab == "token" then
        UI:RefreshToken()
    elseif activeTab == "goals" then
        UI:RefreshGoals()
    end
end

function UI:ToggleMinimapButton()
    if not hasLibDBIcon then return end
    local libDBIcon = LibStub("LibDBIcon-1.0")
    local settings  = WarbandAccountant.Data:GetSettings()
    if settings.hide then libDBIcon:Hide("WarbandAccountant")
    else libDBIcon:Show("WarbandAccountant") end
end

function UI:UpdateTooltip()
    if not hasLibDBIcon then return end
    local button = _G["LibDBIcon10_WarbandAccountant"]
    if button and GameTooltip:IsOwned(button) then
        GameTooltip:ClearLines()
        SetupTooltip(GameTooltip)
        GameTooltip:Show()
    end
end

-- Legacy compat for WarbandAccountant.Core.lua references
function UI:ToggleMainWindow()   UI:Toggle("overview") end
function UI:ToggleLedgerWindow() UI:Toggle("ledger")   end
function UI:UpdateTargets()      UI:RefreshTargets()   end
function UI:UpdateWarbandLedger() UI:RefreshLedger()   end
function UI:RefreshTargetsTab()  UI:RefreshTargets()   end
function UI:ResetFramePositions()
    local L = WarbandAccountant.L
    if mainFrame then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER")
        local db = WarbandAccountant.Data:GetDB()
        if db then db.framePositions = nil end
    end
    print(L.MSG_PREFIX_GREEN .. L.MSG_WINDOW_POS_RESET)
end

-- Changelog popup compat -- now just opens the changelog tab
function UI:ShowChangelog()
    UI:Toggle("changelog")
end

function UI:CheckAndShowUpdateNotification()
    local Data = WarbandAccountant.Data
    local lastSeen = Data:GetLastSeenVersion()
    local current  = Data:GetCurrentAddonVersion()
    if lastSeen ~= current then
        Data:SetLastSeenVersion(current)
        -- Brand-new installs (never-before-seen sentinel) get the tutorial
        -- instead of a changelog popup for a version they never used.
        if lastSeen ~= "0.0.0" and Data:GetShowUpdateChangelog() then
            C_Timer.After(0.5, function()
                UI:Toggle("changelog")
            end)
        end
    end
end

-- Delete character dialog registration moved into RefreshTargets (see below),
-- since registering it here at file-load time would bake in whatever locale
-- guess was active before Data:Init() corrects it from the saved preference.

