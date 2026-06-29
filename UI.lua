local ADDON_NAME, WarbandAccountant = ...
local UI = {}
WarbandAccountant.UI = UI

-- -- Constants -----------------------------------------------------------------
local NAV_W         = 150
local WIN_W         = 1100
local WIN_H         = 660
local CONTENT_X     = NAV_W + 12
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
local function FormatGoldShort(copper)
    if not copper then return "0g" end
    local abs = math.abs(copper)
    local sign = copper < 0 and "-" or ""
    if abs >= 10000 then
        return string.format("%s%.1fg", sign, abs / 10000)
    elseif abs >= 100 then
        return string.format("%s%.1fs", sign, abs / 100)
    else
        return string.format("%s%dc", sign, abs)
    end
end

local function FormatTimestamp(ts)
    if not ts then return "" end
    local d = date("*t", ts)
    return string.format("%02d/%02d %02d:%02d", d.month, d.day, d.hour, d.min)
end

local function MakeLabel(parent, text, fontObj, x, y, w, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObj or "GameFontNormal")
    if x and y then fs:SetPoint("TOPLEFT", x, y) end
    if w then fs:SetWidth(w) end
    if color then fs:SetTextColor(color.r, color.g, color.b) end
    if text then fs:SetText(text) end
    return fs
end

local function MakeSeparator(parent, yOff)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, yOff)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOff)
    return sep
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
    elseif tabKey == "changelog" then
        UI:RefreshChangelog()
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

local function BuildOverviewTab(panel)
    local cw    = CONTENT_W
    local cardW = math.floor((cw - 40) / 4)
    local cardH = 85
    local cardY = -10

    overviewCards.warband = CreateStatCard(panel, "Warband Bank",      10,               cardY, cardW, cardH)
    overviewCards.total   = CreateStatCard(panel, "Total Gold",        10 + cardW + 10,  cardY, cardW, cardH)
    overviewCards.weekly  = CreateStatCard(panel, "This Week",         10 + (cardW+10)*2, cardY, cardW, cardH)
    overviewCards.session = CreateStatCard(panel, "Session",           10 + (cardW+10)*3, cardY, cardW, cardH)

    -- Guild bank line
    local guildLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    guildLabel:SetPoint("TOPLEFT", 10, cardY - cardH - 10)
    guildLabel:SetText("Guild Bank:")
    guildLabel:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    overviewGuildText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    overviewGuildText:SetPoint("LEFT", guildLabel, "RIGHT", 10, 0)
    overviewGuildText:SetText("--")

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
    Hdr("Character",   col.name)
    Hdr("Realm",       col.realm)
    Hdr("Current",     col.current)
    Hdr("Target",      col.target)
    Hdr("+/- Target",  col.diff)

    MakeSeparator(panel, hdrY - 16)
    overviewCharScroll, overviewCharContent = CreateScrollArea(panel, 0, hdrY - 24, CONTENT_W, scrollH)
    panel._overviewCol = col
end

function UI:RefreshOverview()
    if not mainFrame or not mainFrame.panels.overview then return end
    local Data = WarbandAccountant.Data

    -- Stat cards
    local warbandGold = WarbandAccountant.Core:GetWarbandGold()
    overviewCards.warband.value:SetText(WarbandAccountant.FormatGold(warbandGold))
    overviewCards.warband.value:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

    local totalGold = Data:GetTotalTrackedGold()
    overviewCards.total.value:SetText(WarbandAccountant.FormatGold(totalGold))
    overviewCards.total.value:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)

    local weekly = Data:GetWeeklyIncome()
    local wc = weekly >= 0 and COLOR_GREEN or COLOR_RED
    local ws = weekly >= 0 and "+" or ""
    overviewCards.weekly.value:SetText(ws .. WarbandAccountant.FormatGold(weekly))
    overviewCards.weekly.value:SetTextColor(wc.r, wc.g, wc.b)

    local session = Data:GetTotalSessionChange()
    local sc2 = session >= 0 and COLOR_GREEN or COLOR_RED
    local ss = session >= 0 and "+" or ""
    overviewCards.session.value:SetText(ss .. WarbandAccountant.FormatGold(session))
    overviewCards.session.value:SetTextColor(sc2.r, sc2.g, sc2.b)

    -- Guild bank
    local guildGold, guildName = WarbandAccountant.Core:GetGuildBankGold()
    if guildGold and guildGold > 0 then
        overviewGuildText:SetText("|cFF00FF00" .. (guildName or "?") .. "|r  " .. WarbandAccountant.FormatGold(guildGold))
    else
        overviewGuildText:SetText("|cFF666666None tracked|r")
    end

    -- Character rows
    local col = mainFrame.panels.overview._overviewCol
    if overviewCharContent._rows then
        for _, r in ipairs(overviewCharContent._rows) do r:Hide() end
    end
    overviewCharContent._rows = {}

    local characters = Data:GetAllCharacters()
    local charList = {}
    local currentRealm = GetRealmName()
    for id, d in pairs(characters) do
        table.insert(charList, { id=id, name=d.name, realm=d.realm, class=d.class,
            current=d.currentGold or 0, target=d.targetGold or 0,
            paused=d.paused, charType=d.charType, sortOrder=d.sortOrder or 0 })
    end
    table.sort(charList, function(a,b) return a.sortOrder < b.sortOrder end)

    local yOff = 0
    for i, c in ipairs(charList) do
        local row = CreateFrame("Frame", nil, overviewCharContent)
        row:SetSize(CONTENT_W - 30, ROW_H)
        row:SetPoint("TOPLEFT", 0, yOff)

        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.14, 0.10, 0.4)
        end

        local clr = RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class] or COLOR_WHITE
        local nameStr = c.name
        if c.paused then nameStr = nameStr .. " |cFFFF4444[P]|r" end

        local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetPoint("LEFT", col.name, 0)
        nameFs:SetWidth(160)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText(nameStr)
        nameFs:SetTextColor(clr.r, clr.g, clr.b)

        local realmFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        realmFs:SetPoint("LEFT", col.realm, 0)
        realmFs:SetWidth(150)
        realmFs:SetJustifyH("LEFT")
        realmFs:SetText(c.realm .. (c.realm ~= currentRealm and " (*)" or ""))
        realmFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local curFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        curFs:SetPoint("LEFT", col.current, 0)
        curFs:SetWidth(140)
        curFs:SetJustifyH("LEFT")
        curFs:SetText(WarbandAccountant.FormatGold(c.current))
        if c.current < c.target then
            curFs:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        elseif c.current > c.target then
            curFs:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        else
            curFs:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
        end

        local tgtFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tgtFs:SetPoint("LEFT", col.target, 0)
        tgtFs:SetWidth(140)
        tgtFs:SetJustifyH("LEFT")
        tgtFs:SetText(WarbandAccountant.FormatGold(c.target))
        tgtFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local diff = c.current - c.target
        local diffFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        diffFs:SetPoint("LEFT", col.diff, 0)
        diffFs:SetWidth(140)
        diffFs:SetJustifyH("LEFT")
        local diffSign = diff >= 0 and "+" or ""
        diffFs:SetText(diffSign .. WarbandAccountant.FormatGold(diff))
        if diff > 0 then diffFs:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        elseif diff < 0 then diffFs:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        else diffFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b) end

        table.insert(overviewCharContent._rows, row)
        yOff = yOff - ROW_H
    end
    overviewCharContent:SetHeight(math.max(300, math.abs(yOff)))
end

-- ===============================================================================
-- TARGETS TAB
-- ===============================================================================
local targetsScrollContent
local targetRows = {}

local function BuildTargetsTab(panel)
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
    Hdr("Character", col.character)
    Hdr("Realm",     col.realm)
    Hdr("Type",      col.main)
    Hdr("Target",    col.target)
    Hdr("Current",   col.current)
    Hdr("Pause",     col.paused)
    Hdr("Delete",    col.delete)

    MakeSeparator(panel, -28)

    local sf, sc = CreateScrollArea(panel, 0, -36, CONTENT_W, CONTENT_H - 36)
    targetsScrollContent = sc
    panel._targetsScroll = sf
end

function UI:RefreshTargets()
    if not mainFrame or not targetsScrollContent then return end
    local Data  = WarbandAccountant.Data
    local panel = mainFrame.panels.targets
    local col = panel._col

    for _, r in ipairs(targetRows) do if r then r:Hide() end end
    wipe(targetRows)

    local characters = Data:GetAllCharacters()
    local charList = {}
    for id, d in pairs(characters) do
        table.insert(charList, { id=id, name=d.name, realm=d.realm, class=d.class,
            currentGold=d.currentGold or 0, targetGold=d.targetGold or 0,
            paused=d.paused, charType=d.charType, sortOrder=d.sortOrder or 0 })
    end
    table.sort(charList, function(a,b) return a.sortOrder < b.sortOrder end)

    local currentCharID = Data:GetCurrentCharacterID()
    local yOff = 0

    for i, char in ipairs(charList) do
        local row = CreateFrame("Frame", nil, targetsScrollContent)
        row:SetSize(CONTENT_W - 44, 40)
        row:SetPoint("TOPLEFT", 0, yOff)

        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.14, 0.10, 0.4)
        end

        -- Reorder: arrows or number input based on sort mode
        local sortMode = Data:GetSortMode()
        if sortMode == "number" then
            local orderEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            orderEdit:SetSize(36, 22)
            orderEdit:SetPoint("LEFT", col.reorder, 0)
            orderEdit:SetAutoFocus(false)
            orderEdit:SetNumeric(true)
            orderEdit:SetMaxLetters(3)
            orderEdit:SetJustifyH("CENTER")
            orderEdit:SetText(tostring(i))
            orderEdit:SetScript("OnEnterPressed", function(self)
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
            orderEdit:SetScript("OnEditFocusLost", function(self)
                self:SetText(tostring(i))
            end)
        else
            local upBtn = CreateFrame("Button", nil, row)
            upBtn:SetSize(16, 16)
            upBtn:SetPoint("LEFT", col.reorder, 4)
            local upTex = upBtn:CreateTexture(nil, "ARTWORK")
            upTex:SetAllPoints()
            upTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            upTex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            upBtn:SetNormalTexture(upTex)
            upBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            if i > 1 then
                upBtn:SetScript("OnClick", function()
                    Data:SwapCharacterOrder(char.id, charList[i-1].id)
                    UI:RefreshTargets()
                end)
            else upBtn:Disable() end

            local downBtn = CreateFrame("Button", nil, row)
            downBtn:SetSize(16, 16)
            downBtn:SetPoint("TOP", upBtn, "BOTTOM", 0, 2)
            local downTex = downBtn:CreateTexture(nil, "ARTWORK")
            downTex:SetAllPoints()
            downTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            downTex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            downBtn:SetNormalTexture(downTex)
            downBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            if i < #charList then
                downBtn:SetScript("OnClick", function()
                    Data:SwapCharacterOrder(char.id, charList[i+1].id)
                    UI:RefreshTargets()
                end)
            else downBtn:Disable() end
        end

        -- Name
        local clr = RAID_CLASS_COLORS and RAID_CLASS_COLORS[char.class] or COLOR_WHITE
        local nameFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameFs:SetPoint("LEFT", col.character, 0)
        nameFs:SetWidth(130)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText(char.name)
        nameFs:SetTextColor(clr.r, clr.g, clr.b)

        -- Realm
        local realmFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        realmFs:SetPoint("LEFT", col.realm, 0)
        realmFs:SetWidth(100)
        realmFs:SetJustifyH("LEFT")
        realmFs:SetText(char.realm)
        realmFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        -- Character type dropdown
        local currentType = Data:GetCharacterType(char.id)
        local typeDD = CreateFrame("Frame", "WBATypeDD_" .. i, row, "UIDropDownMenuTemplate")
        typeDD:SetPoint("LEFT", col.main - 16, 0)
        UIDropDownMenu_SetWidth(typeDD, 120)
        local displayName = currentType and Data:GetCategoryName(currentType) or "(None)"
        UIDropDownMenu_SetText(typeDD, displayName)
        UIDropDownMenu_Initialize(typeDD, function()
            local info = UIDropDownMenu_CreateInfo()
            info.text    = "(None)"
            info.arg1    = nil
            info.checked = (currentType == nil)
            info.func    = function()
                Data:SetCharacterType(char.id, nil)
                UIDropDownMenu_SetText(typeDD, "(None)")
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
                    UIDropDownMenu_SetText(typeDD, btn:GetText())
                    UI:RefreshTargets()
                    UI:UpdateTooltip()
                end
                UIDropDownMenu_AddButton(info)
            end
        end)

        -- Target editbox
        local tgtEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        tgtEdit:SetSize(90, 22)
        tgtEdit:SetPoint("LEFT", col.target, 0)
        tgtEdit:SetAutoFocus(false)
        tgtEdit:SetNumeric(true)
        tgtEdit:SetMaxLetters(7)
        tgtEdit:SetText(tostring(math.floor(char.targetGold / 10000)))
        tgtEdit:SetJustifyH("RIGHT")
        tgtEdit:SetTextInsets(2, 6, 0, 0)
        local gLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        gLabel:SetPoint("LEFT", tgtEdit, "RIGHT", 4, 0)
        gLabel:SetText("g")
        gLabel:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        local function SaveTarget(self)
            Data:SetCharacterTarget(char.id, (tonumber(self:GetText()) or 0) * 10000)
            UI:RefreshTargets()
        end
        tgtEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveTarget(self) end)
        tgtEdit:SetScript("OnEditFocusLost", SaveTarget)

        -- Current gold
        local curFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        curFs:SetPoint("LEFT", col.current, 0)
        curFs:SetWidth(130)
        curFs:SetJustifyH("LEFT")
        curFs:SetText(WarbandAccountant.FormatGold(char.currentGold))
        if char.currentGold < char.targetGold then
            curFs:SetTextColor(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b)
        elseif char.currentGold > char.targetGold then
            curFs:SetTextColor(COLOR_GREEN.r, COLOR_GREEN.g, COLOR_GREEN.b)
        else
            curFs:SetTextColor(COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b)
        end

        -- Pause checkbox
        local pauseCb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        pauseCb:SetSize(24, 24)
        pauseCb:SetPoint("LEFT", col.paused, 0)
        pauseCb:SetChecked(char.paused)
        pauseCb:SetScript("OnClick", function(self)
            local d = Data:GetCharacterData(char.id)
            if d then d.paused = self:GetChecked() end
            UI:UpdateTooltip()
        end)
        pauseCb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Pause Automation")
            GameTooltip:AddLine("Skip auto-deposit/withdraw for this character", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        pauseCb:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Delete button (not for current char)
        if char.id ~= currentCharID then
            local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            delBtn:SetSize(50, 22)
            delBtn:SetPoint("LEFT", col.delete, 0)
            delBtn:SetText("Delete")
            local regs = {delBtn:GetRegions()}
            for _, reg in ipairs(regs) do
                if reg:GetObjectType() == "Texture" then
                    reg:SetVertexColor(0.8, 0.1, 0.1, 1)
                end
            end
            delBtn:SetScript("OnClick", function()
                StaticPopup_Show("WARBANDACCOUNTANT_DELETE_CHARACTER", char.name, nil, char.id)
            end)
            delBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Delete Character")
                GameTooltip:AddLine("Remove from tracking |cFFFF0000(cannot be undone)|r", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            delBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        table.insert(targetRows, row)
        yOff = yOff - 40
    end
    targetsScrollContent:SetHeight(math.max(300, math.abs(yOff)))
end

-- ===============================================================================
-- LEDGER TAB
-- ===============================================================================
local ledgerScrollContent
local ledgerRows = {}
local ledgerStatsText
local ledgerFilterDropdown

local function BuildLedgerTab(panel)
    local col = { time=10, char=105, type=240, amount=360, balance=520, note=690 }
    panel._col = col

    -- Row 1: Filter label + dropdown anchored top-right
    ledgerFilterDropdown = CreateFrame("Frame", "WBALedgerFilterDD", panel, "UIDropDownMenuTemplate")
    ledgerFilterDropdown:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 8, -4)
    UIDropDownMenu_SetWidth(ledgerFilterDropdown, 160)
    UIDropDownMenu_SetText(ledgerFilterDropdown, "All Characters")

    local filterLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterLbl:SetPoint("RIGHT", ledgerFilterDropdown, "LEFT", 16, 1)
    filterLbl:SetText("Filter:")
    filterLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    -- Stats text
    ledgerStatsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ledgerStatsText:SetPoint("TOPLEFT", 10, -8)
    ledgerStatsText:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -220, -8)
    ledgerStatsText:SetJustifyH("LEFT")

    local function InitFilter()
        UIDropDownMenu_Initialize(ledgerFilterDropdown, function()
            local info = UIDropDownMenu_CreateInfo()
            info.text    = "All Characters"
            info.checked = (ledgerCharFilter == nil)
            info.func    = function()
                ledgerCharFilter = nil
                UIDropDownMenu_SetText(ledgerFilterDropdown, "All Characters")
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
                local disp = c.name .. (c.realm ~= GetRealmName() and " (*)" or "")
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
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -72)
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        return fs
    end
    Hdr("Time",         col.time)
    Hdr("Character",    col.char)
    Hdr("Type",         col.type)
    Hdr("Amount",       col.amount)
    Hdr("Warband Bank", col.balance)
    Hdr("Note",         col.note)

    MakeSeparator(panel, -88)

    local lsf, lsc = CreateScrollArea(panel, 0, -96, CONTENT_W + 4, CONTENT_H - 100)
    ledgerScrollContent = lsc
end

function UI:RefreshLedger()
    if not mainFrame or not ledgerScrollContent then return end
    local Data = WarbandAccountant.Data

    -- Clear rows
    for _, r in ipairs(ledgerRows) do if r then r:Hide() end end
    wipe(ledgerRows)

    -- Stats
    local dep, wdr = Data:GetTotalLedgerStats()
    local made = dep - wdr
    local madeCol  = made >= 0 and "|cFF33FF33" or "|cFFFF4444"
    local madeSign = made >= 0 and "+" or ""
    local wIncome  = Data:GetWeeklyIncome()
    local wCol     = wIncome >= 0 and "|cFF33FF33" or "|cFFFF4444"
    local wSign    = wIncome >= 0 and "+" or ""
    ledgerStatsText:SetText(string.format(
        "Dep: |cFF33FF33%s|r   Wdr: |cFFFF4444%s|r   Net: %s%s%s|r   Week: %s%s%s|r",
        WarbandAccountant.FormatGold(dep), WarbandAccountant.FormatGold(wdr),
        madeCol, madeSign, WarbandAccountant.FormatGold(made),
        wCol, wSign, WarbandAccountant.FormatGold(wIncome)))

    -- Entries
    local allEntries = Data:GetLedgerEntries(500)
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
        local empty = ledgerScrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        empty:SetPoint("CENTER", 0, 0)
        empty:SetText(ledgerCharFilter and "No transactions for this character." or
            "No transactions yet.\nOpen your Warband Bank to record transfers.")
        empty:SetJustifyH("CENTER")
        ledgerScrollContent:SetHeight(300)
        return
    end

    local yOff = 0
    for i, e in ipairs(entries) do
        local row = CreateFrame("Frame", nil, ledgerScrollContent)
        row:SetSize(CONTENT_W - 20, 24)
        row:SetPoint("TOPLEFT", 0, yOff)

        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.14, 0.10, 0.35)
        end

        local timeFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timeFs:SetPoint("LEFT", col.time, 0)
        timeFs:SetJustifyH("LEFT")
        timeFs:SetText(FormatTimestamp(e.timestamp))
        timeFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

        local charFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        charFs:SetPoint("LEFT", col.char, 0)
        charFs:SetWidth(140)
        charFs:SetJustifyH("LEFT")
        charFs:SetText(e.characterName or "Unknown")

        local typeFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        typeFs:SetPoint("LEFT", col.type, 0)
        local isDeposit = (e.type == "DEPOSIT" or e.type == "MANUAL_DEPOSIT")
        typeFs:SetJustifyH("LEFT")
        typeFs:SetText(isDeposit and "Deposit" or "Withdraw")
        typeFs:SetTextColor(isDeposit and 0.2 or 1, isDeposit and 1 or 0.2, 0.2)

        local amtFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        amtFs:SetPoint("LEFT", col.amount, 0)
        amtFs:SetJustifyH("LEFT")
        amtFs:SetText(WarbandAccountant.FormatGold(e.amount))

        local balFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        balFs:SetPoint("LEFT", col.balance, 0)
        balFs:SetJustifyH("LEFT")
        balFs:SetText(WarbandAccountant.FormatGold(e.balanceAfter))
        balFs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)

        if e.note and e.note ~= "" then
            local noteFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            noteFs:SetPoint("LEFT", col.note, 0)
            noteFs:SetWidth(165)
            noteFs:SetJustifyH("LEFT")
            noteFs:SetText(e.note)
            noteFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
        end

        table.insert(ledgerRows, row)
        yOff = yOff - 24
    end
    ledgerScrollContent:SetHeight(math.max(300, math.abs(yOff)))
end

-- ===============================================================================
-- SETTINGS TAB
-- ===============================================================================
local function BuildSettingsTab(panel)
    local Data = WarbandAccountant.Data
    local cw = CONTENT_W
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
    local halfW = math.floor(cw / 2) - 15

    -- -- Automation box ------------------------------------------------------
    local autoBox = Section("Automation", 10, y, halfW, 130)

    MakeCB(autoBox, "Auto-deposit excess gold to Warband Bank", 10, -28,
        function() return settings.autoDeposit ~= false end,
        function(v) settings.autoDeposit = v end)
    MakeCB(autoBox, "Auto-withdraw gold deficit from Warband Bank", 10, -52,
        function() return settings.autoWithdraw ~= false end,
        function(v) settings.autoWithdraw = v end)
    MakeCB(autoBox, "Require confirmation before transfers", 10, -76,
        function() return settings.confirmTransfers or false end,
        function(v) settings.confirmTransfers = v end)

    -- -- Display box ---------------------------------------------------------
    local dispBox = Section("Display", halfW + 25, y, halfW, 130)

    -- Sort Mode row
    local sortLbl = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sortLbl:SetPoint("TOPLEFT", 12, -30)
    sortLbl:SetText("Sort Mode:")
    sortLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local sortDD = CreateFrame("Frame", "WBASortDD", dispBox, "UIDropDownMenuTemplate")
    sortDD:SetPoint("LEFT", sortLbl, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(sortDD, 130)
    local curSort = Data:GetSortMode()
    UIDropDownMenu_SetText(sortDD, curSort == "arrow" and "Arrow Buttons" or "Number Input")
    UIDropDownMenu_Initialize(sortDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.func = function(btn, arg1)
            UIDropDownMenu_SetText(sortDD, btn:GetText())
            Data:SetSortMode(arg1)
            if activeTab == "targets" then UI:RefreshTargets() end
        end
        info.text = "Arrow Buttons"; info.arg1 = "arrow"; info.checked = Data:GetSortMode() == "arrow"
        UIDropDownMenu_AddButton(info)
        info = UIDropDownMenu_CreateInfo()
        info.func = function(btn, arg1)
            UIDropDownMenu_SetText(sortDD, btn:GetText())
            Data:SetSortMode(arg1)
            if activeTab == "targets" then UI:RefreshTargets() end
        end
        info.text = "Number Input"; info.arg1 = "number"; info.checked = Data:GetSortMode() == "number"
        UIDropDownMenu_AddButton(info)
    end)

    -- Minimap show/hide dropdown
    local mmLbl = dispBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mmLbl:SetPoint("TOPLEFT", 12, -76)
    mmLbl:SetText("Show Minimap Button:")
    mmLbl:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)

    local mmDD = CreateFrame("Frame", "WBAMinimapDD", dispBox, "UIDropDownMenuTemplate")
    mmDD:SetPoint("LEFT", mmLbl, "RIGHT", 4, 0)
    UIDropDownMenu_SetWidth(mmDD, 70)
    UIDropDownMenu_SetText(mmDD, settings.hide and "No" or "Yes")
    UIDropDownMenu_Initialize(mmDD, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Yes"; info.arg1 = false
        info.checked = not settings.hide
        info.func = function(btn, arg1)
            settings.hide = arg1
            UIDropDownMenu_SetText(mmDD, "Yes")
            UI:ToggleMinimapButton()
        end
        UIDropDownMenu_AddButton(info)
        info = UIDropDownMenu_CreateInfo()
        info.text = "No"; info.arg1 = true
        info.checked = settings.hide
        info.func = function(btn, arg1)
            settings.hide = arg1
            UIDropDownMenu_SetText(mmDD, "No")
            UI:ToggleMinimapButton()
        end
        UIDropDownMenu_AddButton(info)
    end)

    -- -- Category Names + Default Targets ------------------------------------
    local tgtY   = y - 130
    local colW   = math.floor((cw - 40) / 2)
    local rowH   = 28
    local numRows = 3
    local tgtBoxH = 46 + (numRows * rowH) + 24  -- header + rows + note
    local tgtBox = Section("Category Names & Default Targets", 10, tgtY, cw - 20, tgtBoxH)

    local function TgtHdr(txt, x)
        local fs = tgtBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", x, -30)
        fs:SetText(txt)
        fs:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
    end
    TgtHdr("Display Name",  14)
    TgtHdr("Default Target", 154)
    TgtHdr("Display Name",  14  + colW)
    TgtHdr("Default Target", 154 + colW)

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
        gLbl:SetText("g")
        gLbl:SetTextColor(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b)
        local function SaveGold(self)
            Data:SetDefaultTarget(key, (tonumber(self:GetText()) or 0) * 10000)
        end
        goldEB:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveGold(self) end)
        goldEB:SetScript("OnEditFocusLost", SaveGold)
    end

    for idx, key in ipairs(keys) do
        MakeCategoryRow(tgtBox, key, (idx - 1) % 2, math.floor((idx - 1) / 2))
    end

    local noteFs = tgtBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    noteFs:SetPoint("BOTTOMLEFT", 10, 6)
    noteFs:SetText("Name changes update immediately in dropdowns. Target applies when assigning a type.")
    noteFs:SetTextColor(COLOR_GREY.r, COLOR_GREY.g, COLOR_GREY.b)
    noteFs:SetWidth(cw - 40)

    -- -- Danger Zone ----------------------------------------------------------
    local resetY   = tgtY - tgtBoxH - 12
    local resetBox = Section("Danger Zone", 10, resetY, cw - 20, 150)

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

    local resetBtn = DangerBtn("Reset All Statistics", 10, -28, function()
        StaticPopup_Show("WARBANDACCOUNTANT_RESET_TOTALS")
    end)
    DangerDesc(resetBox, resetBtn, "Clears all-time totals and ledger history.")

    local clearBtn = DangerBtn("Clear Ledger History", 10, -62, function()
        StaticPopup_Show("WARBANDACCOUNTANT_CLEAR_LEDGER")
    end)
    DangerDesc(resetBox, clearBtn, "Removes all transaction history from the Ledger tab.")

    local resetPosBtn = DangerBtn("Reset Window Position", 10, -96, function()
        if mainFrame then
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("CENTER")
            local db = Data:GetDB()
            if db then db.framePositions = nil end
        end
        print("|cFF00FF00Warband Accountant:|r Window position reset.")
    end)

    StaticPopupDialogs["WARBANDACCOUNTANT_RESET_TOTALS"] = {
        text = "Reset all-time deposit/withdrawal statistics?\n\n|cFFFF0000This cannot be undone.|r",
        button1 = "Yes", button2 = "No",
        OnAccept = function()
            Data:ResetLedgerTotals()
            print("|cFF00FF00Warband Accountant:|r Statistics reset.")
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

    StaticPopupDialogs["WARBANDACCOUNTANT_CLEAR_LEDGER"] = {
        text = "Clear all Warband ledger history?\n\n|cFFFF0000This cannot be undone.|r",
        button1 = "Yes", button2 = "No",
        OnAccept = function()
            Data:ClearLedger()
            UI:RefreshLedger()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }

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
            local vh = AddText("GameFontNormalLarge", "Version " .. version, PAD, COLOR_GOLD)
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
                    local tagColor
                    if entry.tag == "New"     then tagColor = "|cFF44FF88"
                    elseif entry.tag == "Fix" then tagColor = "|cFFFF9944"
                    else                           tagColor = "|cFF00CCFF" end
                    local fs = AddText("GameFontHighlight",
                        tagColor .. "[" .. entry.tag .. "]|r " .. entry.text, PAD)
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
-- MAIN WINDOW
-- ===============================================================================
local function CreateMainWindow()
    local f = CreateFrame("Frame", "WarbandAccountantMainFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIN_W, WIN_H)

    local Data = WarbandAccountant.Data
    local db   = Data:GetDB()
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
    local btnOverview  = CreateNavButton(nav, "  Overview",  "overview",  -8)
    local btnTargets   = CreateNavButton(nav, "  Targets",   "targets",   nil, btnOverview)
    local btnLedger    = CreateNavButton(nav, "  Ledger",    "ledger",    nil, btnTargets)

    -- Bottom nav buttons (anchored from the bottom up)
    local btnChangelog = CreateFrame("Button", nil, nav)
    btnChangelog:SetSize(NAV_W, NAV_BTN_H)
    btnChangelog:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", 0, 4)

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

    StyleBottomBtn(btnSettings,  "  Settings",  "settings")
    StyleBottomBtn(btnChangelog, "  Changelog", "changelog")

    -- -- Content panels -------------------------------------------------------
    local function MakePanel()
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT",     f, "TOPLEFT",     NAV_W + 10, -32)
        p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6,          6)
        p:Hide()
        return p
    end

    f.panels = {
        overview  = MakePanel(),
        targets   = MakePanel(),
        ledger    = MakePanel(),
        settings  = MakePanel(),
        changelog = MakePanel(),
    }

    BuildOverviewTab(f.panels.overview)
    BuildTargetsTab(f.panels.targets)
    BuildLedgerTab(f.panels.ledger)
    BuildSettingsTab(f.panels.settings)
    BuildChangelogTab(f.panels.changelog)

    mainFrame = f

    -- Default to overview
    UI:SwitchTab("overview")

    return f
end

-- ===============================================================================
-- MINIMAP TOOLTIP
-- ===============================================================================
local function SetupTooltip(tooltip)
    local Data = WarbandAccountant.Data
    tooltip:AddLine("Warband Accountant", 1, 0.82, 0)
    tooltip:AddLine(" ")

    local warbandGold = WarbandAccountant.Core:GetWarbandGold()
    tooltip:AddDoubleLine("Warband Bank:", WarbandAccountant.FormatGold(warbandGold), 0.8, 0.8, 0, 1, 1, 0)

    local totalGold = Data:GetTotalTrackedGold()
    tooltip:AddDoubleLine("Total Gold:", WarbandAccountant.FormatGold(totalGold), 0.8, 0.8, 0.8, 1, 1, 1)

    local weekly = Data:GetWeeklyIncome()
    local wc = weekly >= 0
    tooltip:AddDoubleLine("This Week:",
        (wc and "|cFF33FF33+" or "|cFFFF4444") .. WarbandAccountant.FormatGold(weekly) .. "|r",
        0.8, 0.8, 0.8, 1, 1, 1)

    local session = Data:GetTotalSessionChange()
    if session ~= 0 then
        local sc2 = session >= 0
        tooltip:AddDoubleLine("Session:",
            (sc2 and "|cFF33FF33+" or "|cFFFF4444") .. WarbandAccountant.FormatGold(session) .. "|r",
            0.8, 0.8, 0.8, 1, 1, 1)
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Click: Open Warband Accountant", 0.5, 0.5, 0.5)
end

-- ===============================================================================
-- PUBLIC INTERFACE
-- ===============================================================================
function UI:Init()
    if not hasLDB or not hasLibDBIcon then
        print("|cFFFF0000Warband Accountant:|r LibDBIcon not found. Minimap button disabled.")
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
    if not mainFrame then CreateMainWindow() end
    if mainFrame:IsShown() and activeTab == (tabKey or "overview") then
        mainFrame:Hide()
    else
        mainFrame:Show()
        UI:SwitchTab(tabKey or "overview")
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
    if mainFrame then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER")
        local db = WarbandAccountant.Data:GetDB()
        if db then db.framePositions = nil end
    end
    print("|cFF00FF00Warband Accountant:|r Window position reset.")
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
        C_Timer.After(0.5, function()
            UI:Toggle("changelog")
        end)
    end
end

-- Delete character dialog (referenced from RefreshTargets)
StaticPopupDialogs["WARBANDACCOUNTANT_DELETE_CHARACTER"] = {
    text = "Delete %s from Warband Accountant?\n\n|cFFFF0000This cannot be undone!|r",
    button1 = "Delete", button2 = "Cancel",
    OnAccept = function(self, charID)
        local Data = WarbandAccountant.Data
        local ok, result = Data:DeleteCharacter(charID)
        if ok then
            print("|cFF00FF00Warband Accountant:|r Deleted: " .. result)
            UI:RefreshTargets()
            UI:UpdateTooltip()
        else
            print("|cFFFF0000Warband Accountant:|r " .. (result or "Could not delete"))
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
