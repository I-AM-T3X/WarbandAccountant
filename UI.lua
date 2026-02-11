local ADDON_NAME, WarbandAccountant = ...
local Core = WarbandAccountant.Core

local UI = {}
WarbandAccountant.UI = UI

local mainFrame = nil
local minimapLDB = nil

local hasLibDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local hasLDB = LibStub and LibStub("LibDataBroker-1.1", true)

local function FormatGoldShort(copper)
    if not copper then return "0g" end
    local absCopper = math.abs(copper)
    if absCopper >= 10000 then
        return string.format("%.1fg", copper / 10000)
    elseif absCopper >= 100 then
        return string.format("%.1fs", copper / 100)
    else
        return string.format("%dc", copper)
    end
end

local function FormatTimestamp(timestamp)
    if not timestamp then return "" end
    local dateTable = date("*t", timestamp)
    return string.format("%02d/%02d %02d:%02d", dateTable.month, dateTable.day, dateTable.hour, dateTable.min)
end

local function SetupTooltip(tooltip)
    local Data = WarbandAccountant.Data
    tooltip:AddLine("Warband Accountant", 1, 0.8, 0)
    tooltip:AddLine(" ")
    
    local currentChar = Data:GetCharacterData()
    if currentChar then
        local currentGold = GetMoney()
        local target = currentChar.targetGold or 0
        local sessionChange = Data:GetSessionChange()
        local diff = currentGold - target
        
        tooltip:AddLine("Current Character:", 0.8, 0.8, 0.8)
        tooltip:AddDoubleLine("  " .. currentChar.name, WarbandAccountant.FormatGold(currentGold), 1, 1, 1, 1, 1, 1)
        
        if currentChar.paused then
            tooltip:AddLine("  |cFFFF0000PAUSED|r", 1, 0, 0)
        end
        
        if currentChar.charType then
            local typeLabel = currentChar.charType == "mainAlt" and "Main Alt" or currentChar.charType:gsub("^%l", string.upper)
            tooltip:AddLine("  Type: |cFF00FF00" .. typeLabel .. "|r", 0.8, 0.8, 0.8)
        end
        
        if sessionChange ~= 0 then
            local color = sessionChange > 0 and "|cFF00FF00" or "|cFFFF0000"
            local sign = sessionChange > 0 and "+" or ""
            tooltip:AddDoubleLine("  This Session:", color .. sign .. WarbandAccountant.FormatGold(sessionChange) .. "|r", 0.7, 0.7, 0.7, 1, 1, 1)
        end
        
        tooltip:AddDoubleLine("  Target:", WarbandAccountant.FormatGold(target), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
        
        if diff > 0 then
            tooltip:AddDoubleLine("  Excess:", WarbandAccountant.FormatGold(diff), 0, 1, 0, 0, 1, 0)
        elseif diff < 0 then
            tooltip:AddDoubleLine("  Deficit:", WarbandAccountant.FormatGold(math.abs(diff)), 1, 0, 0, 1, 0, 0)
        end
        tooltip:AddLine(" ")
    end
    
    local warbandGold = Core:GetWarbandGold()
    tooltip:AddDoubleLine("Warband Bank:", WarbandAccountant.FormatGold(warbandGold), 0.8, 0.8, 0, 1, 1, 0)
    
    local totalDeposited, totalWithdrawn = Data:GetTotalLedgerStats()
    local totalMade = totalDeposited - totalWithdrawn
    if totalMade ~= 0 or totalDeposited > 0 or totalWithdrawn > 0 then
        local madeColor, madePrefix
        if totalMade > 0 then
            madeColor = "|cFF00FF00"
            madePrefix = "+"
        elseif totalMade < 0 then
            madeColor = "|cFFFF0000"
            madePrefix = ""
        else
            madeColor = "|cFFFFFFFF"
            madePrefix = ""
        end
        tooltip:AddDoubleLine("Total Made:", madeColor .. madePrefix .. WarbandAccountant.FormatGold(totalMade) .. "|r", 0.8, 0.8, 0.8, 1, 1, 1)
    end
    
    local totalSession = Data:GetTotalSessionChange()
    if totalSession ~= 0 then
        local color = totalSession > 0 and "|cFF00FF00" or "|cFFFF0000"
        local sign = totalSession > 0 and "+" or ""
        tooltip:AddDoubleLine("Total Session:", color .. sign .. WarbandAccountant.FormatGold(totalSession) .. "|r", 0.8, 0.8, 0.8, 1, 1, 1)
    end
    
    tooltip:AddLine(" ")
    
    local characters = Data:GetAllCharacters()
    local totalTracked = 0
    local charList = {}
    
    for id, charData in pairs(characters) do
        if charData.currentGold then
            totalTracked = totalTracked + charData.currentGold
            local session = Data:GetSessionChange(id)
            table.insert(charList, {
                name = charData.name, 
                gold = charData.currentGold, 
                class = charData.class, 
                realm = charData.realm, 
                session = session,
                paused = charData.paused,
                charType = charData.charType
            })
        end
    end
    
    table.sort(charList, function(a, b) return a.gold > b.gold end)
    
    tooltip:AddLine("Warband Characters:", 0.8, 0.8, 0.8)
    
    for i, char in ipairs(charList) do
        if i <= 10 then
            local color = RAID_CLASS_COLORS[char.class] or {r=1, g=1, b=1}
            local sessionIndicator = ""
            if char.session > 0 then sessionIndicator = " |cFF00FF00↑|r" elseif char.session < 0 then sessionIndicator = " |cFFFF0000↓|r" end
            local pausedIndicator = char.paused and " |cFFFF0000[P]|r" or ""
            local typeIndicator = char.charType and string.format(" |cFF00FF00[%s]|r", char.charType == "mainAlt" and "MA" or char.charType:sub(1,1):upper()) or ""
            
            tooltip:AddDoubleLine("  " .. char.name .. pausedIndicator .. typeIndicator .. sessionIndicator .. (char.realm ~= GetRealmName() and " (*)" or ""), FormatGoldShort(char.gold), color.r, color.g, color.b, 1, 1, 1)
        end
    end
    
    if #charList > 10 then tooltip:AddLine("  ... and " .. (#charList - 10) .. " more", 0.5, 0.5, 0.5) end
    
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Total Tracked:", WarbandAccountant.FormatGold(totalTracked), 0.6, 0.8, 1, 0.6, 0.8, 1)
    tooltip:AddLine(" ")
    tooltip:AddLine("Right-Click: Settings", 0.5, 0.5, 0.5)
    tooltip:AddLine("Type /wba to open window", 0.5, 0.5, 0.5)
end

function UI:Init()
    if not hasLDB or not hasLibDBIcon then
        print("|cFFFF0000Warband Accountant:|r LibDBIcon not found. Minimap button disabled.")
        return
    end
    
    local LDB = LibStub("LibDataBroker-1.1")
    local libDBIcon = LibStub("LibDBIcon-1.0")
    local Data = WarbandAccountant.Data
    
    minimapLDB = LDB:NewDataObject("WarbandAccountant", {
        type = "launcher",
        text = "Warband Accountant",
        icon = "Interface\\AddOns\\WarbandAccountant\\Textures\\minimap",
        OnClick = function(self, button)
            if button == "RightButton" then 
				WarbandAccountant.Settings:OpenSettings() 
			end
			-- Left-click disabled - use /wba toggle to open the window
        end,
        OnTooltipShow = function(tooltip) SetupTooltip(tooltip) end,
    })
    
    libDBIcon:Register("WarbandAccountant", minimapLDB, Data:GetSettings())
end

function UI:ToggleMinimapButton()
    if not hasLibDBIcon then return end
    local libDBIcon = LibStub("LibDBIcon-1.0")
    local Data = WarbandAccountant.Data
    local settings = Data:GetSettings()
    if settings.hide then libDBIcon:Hide("WarbandAccountant") else libDBIcon:Show("WarbandAccountant") end
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

local function CreateTab(parent, text, id)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(115, 36)
    
    tab.left = tab:CreateTexture(nil, "BACKGROUND")
    tab.left:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    tab.left:SetSize(20, 36)
    tab.left:SetPoint("BOTTOMLEFT", 0, -4)
    tab.left:SetTexCoord(0, 0.15625, 0, 1.0)
    
    tab.right = tab:CreateTexture(nil, "BACKGROUND")
    tab.right:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    tab.right:SetSize(20, 36)
    tab.right:SetPoint("BOTTOMRIGHT", 0, -4)
    tab.right:SetTexCoord(0.84375, 1.0, 0, 1.0)
    
    tab.middle = tab:CreateTexture(nil, "BACKGROUND")
    tab.middle:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab")
    tab.middle:SetPoint("BOTTOMLEFT", tab.left, "BOTTOMRIGHT", 0, 0)
    tab.middle:SetPoint("TOPRIGHT", tab.right, "TOPLEFT", 0, 0)
    tab.middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    
    tab.highlight = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.highlight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
    tab.highlight:SetPoint("TOPLEFT", 8, -8)
    tab.highlight:SetPoint("BOTTOMRIGHT", -8, 8)
    tab.highlight:SetBlendMode("ADD")
    
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.text:SetPoint("CENTER", 0, -6)
    tab.text:SetText(text)
    
    function tab:SetActive(isActive)
        if isActive then
            tab.left:SetVertexColor(1.0, 0.9, 0.6)
            tab.middle:SetVertexColor(1.0, 0.9, 0.6)
            tab.right:SetVertexColor(1.0, 0.9, 0.6)
            
            tab.text:SetFontObject("GameFontHighlight")
            tab.text:SetTextColor(1, 0.82, 0)
            tab.text:SetAlpha(1)
            
            tab:EnableMouse(false)
        else
            tab.left:SetVertexColor(0.7, 0.7, 0.7)
            tab.middle:SetVertexColor(0.7, 0.7, 0.7)
            tab.right:SetVertexColor(0.7, 0.7, 0.7)
            
            tab.text:SetFontObject("GameFontNormal")
            tab.text:SetTextColor(0.6, 0.6, 0.6)
            tab.text:SetAlpha(0.8)
            
            tab:EnableMouse(true)
        end
    end
    
    tab:SetScript("OnClick", function(self)
        for _, t in ipairs(parent.tabs or {}) do
            t:SetActive(false)
        end
        self:SetActive(true)
        parent.selectedTab = id
        
        parent.targetsContent:Hide()
        parent.ledgerContent:Hide()
        if parent.settingsContent then parent.settingsContent:Hide() end
        
        if id == 1 then
            parent.targetsContent:Show()
            UI:UpdateTargets()
        elseif id == 2 then
            parent.ledgerContent:Show()
            UI:UpdateLedger()
        elseif id == 3 then
            parent.settingsContent:Show()
        end
    end)
    
    return tab
end

local function CreateMainWindow()
    local f = CreateFrame("Frame", "WarbandAccountantMainFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(950, 480)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then 
            self:Hide()
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    tinsert(UISpecialFrames, f:GetName())
    
    f.TitleBg:SetHeight(25)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -6)
    f.title:SetText("Warband Accountant")
    
    local targetsContent = CreateFrame("Frame", nil, f)
    targetsContent:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -35)
    targetsContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 15)
    f.targetsContent = targetsContent
    
    local ledgerContent = CreateFrame("Frame", nil, f)
    ledgerContent:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -35)
    ledgerContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 15)
    ledgerContent:Hide()
    f.ledgerContent = ledgerContent
    
    local settingsContent = CreateFrame("Frame", nil, f)
    settingsContent:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -35)
    settingsContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 15)
    settingsContent:Hide()
    f.settingsContent = settingsContent
    
    SetupTargetsContent(targetsContent, f)
    SetupLedgerContent(ledgerContent, f)
    SetupSettingsContent(settingsContent, f)
    
    f.targetsTab = CreateTab(f, "Targets", 1)
    f.ledgerTab = CreateTab(f, "Ledger", 2)
    f.settingsTab = CreateTab(f, "Settings", 3)
    
    f.tabs = {f.targetsTab, f.ledgerTab, f.settingsTab}
    
    f.targetsTab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 4)
    f.ledgerTab:SetPoint("LEFT", f.targetsTab, "RIGHT", -8, 0)
    f.settingsTab:SetPoint("LEFT", f.ledgerTab, "RIGHT", -8, 0)
    
    f.targetsTab:SetActive(true)
    f.ledgerTab:SetActive(false)
    f.settingsTab:SetActive(false)
    
    mainFrame = f
    return f
end

function SetupSettingsContent(content, parent)
    local Data = WarbandAccountant.Data
    
    -- Main Title
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Settings")
    title:SetTextColor(1, 0.82, 0)
    
    -- Subtitle
    local subtitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
    subtitle:SetText("Configure default values and display preferences")
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    
    -- Section 1: Default Target Amounts
    local targetSection = CreateFrame("Frame", nil, content, "BackdropTemplate")
    targetSection:SetSize(420, 160)
    targetSection:SetPoint("TOP", subtitle, "BOTTOM", 0, -20)
    targetSection:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    targetSection:SetBackdropColor(0, 0, 0, 0.6)
    targetSection:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    
    local targetHeader = targetSection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    targetHeader:SetPoint("TOPLEFT", 15, -12)
    targetHeader:SetText("Default Target Amounts")
    targetHeader:SetTextColor(1, 0.82, 0)
    
    local targetDesc = targetSection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetDesc:SetPoint("TOPLEFT", targetHeader, "BOTTOMLEFT", 0, -3)
    targetDesc:SetText("Gold to maintain on characters based on classification")
    targetDesc:SetTextColor(0.6, 0.6, 0.6)
    
    local function CreateTargetInput(parent, labelText, charType, yOffset)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20, yOffset)
        label:SetText(labelText)
        label:SetTextColor(0.9, 0.9, 0.9)
        
        local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        editBox:SetSize(90, 22)
        editBox:SetPoint("LEFT", label, "RIGHT", 15, 0)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(true)
        editBox:SetMaxLetters(6)
        editBox:SetJustifyH("CENTER")
        editBox:SetTextInsets(0, 0, 0, 0)
        
        local currentGold = math.floor((Data:GetDefaultTarget(charType) or 0) / 10000)
        editBox:SetText(tostring(currentGold))
        
        local goldLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        goldLabel:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
        goldLabel:SetText("gold")
        goldLabel:SetTextColor(1, 0.82, 0)
        
        editBox:SetScript("OnEnterPressed", function(self)
            local goldValue = tonumber(self:GetText()) or 0
            Data:SetDefaultTarget(charType, goldValue * 10000)
            self:ClearFocus()
        end)
        
        editBox:SetScript("OnEditFocusLost", function(self)
            local goldValue = tonumber(self:GetText()) or 0
            Data:SetDefaultTarget(charType, goldValue * 10000)
        end)
        
        -- Tooltip
        editBox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Default: " .. (currentGold > 0 and currentGold or 0) .. " gold")
            GameTooltip:Show()
        end)
        editBox:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    
    CreateTargetInput(targetSection, "Main Character:", "main", -45)
    CreateTargetInput(targetSection, "Main Alt:", "mainAlt", -75)
    CreateTargetInput(targetSection, "Alt:", "alt", -105)
    
    -- Section 2: Display Options
    local displaySection = CreateFrame("Frame", nil, content, "BackdropTemplate")
    displaySection:SetSize(420, 120)
    displaySection:SetPoint("TOP", targetSection, "BOTTOM", 0, -15)
    displaySection:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    displaySection:SetBackdropColor(0, 0, 0, 0.6)
    displaySection:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    
    local displayHeader = displaySection:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    displayHeader:SetPoint("TOPLEFT", 15, -12)
    displayHeader:SetText("Display Options")
    displayHeader:SetTextColor(1, 0.82, 0)
    
    local displayDesc = displaySection:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    displayDesc:SetPoint("TOPLEFT", displayHeader, "BOTTOMLEFT", 0, -3)
    displayDesc:SetText("Customize how characters are organized in the Targets tab")
    displayDesc:SetTextColor(0.6, 0.6, 0.6)
    
    -- Sort Mode Label
    local sortLabel = displaySection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sortLabel:SetPoint("TOPLEFT", 20, -55)
    sortLabel:SetText("Sort Mode:")
    sortLabel:SetTextColor(0.9, 0.9, 0.9)
    
    local sortDropdown = CreateFrame("Frame", "WarbandAccountantSortDropdown", displaySection, "UIDropDownMenuTemplate")
    sortDropdown:SetPoint("LEFT", sortLabel, "RIGHT", 10, 0)
    UIDropDownMenu_SetWidth(sortDropdown, 150)
    
    local currentSortMode = Data:GetSortMode()
    UIDropDownMenu_SetText(sortDropdown, currentSortMode == "arrow" and "Arrow Buttons" or "Number Input")
    
    local function SortDropdown_OnClick(self, arg1)
        UIDropDownMenu_SetText(sortDropdown, arg1 == "arrow" and "Arrow Buttons" or "Number Input")
        Data:SetSortMode(arg1)
        if mainFrame and mainFrame:IsShown() and mainFrame.selectedTab == 1 then
            UI:UpdateTargets()
        end
    end
    
    UIDropDownMenu_Initialize(sortDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.func = SortDropdown_OnClick
        info.arg1 = "arrow"
        info.text = "Arrow Buttons"
        info.checked = Data:GetSortMode() == "arrow"
        info.tooltipTitle = "Arrow Buttons"
        info.tooltipText = "Use up/down arrows to move characters in the list"
        UIDropDownMenu_AddButton(info)
        
        info = UIDropDownMenu_CreateInfo()
        info.func = SortDropdown_OnClick
        info.arg1 = "number"
        info.text = "Number Input"
        info.checked = Data:GetSortMode() == "number"
        info.tooltipTitle = "Number Input"
        info.tooltipText = "Type numbers to set exact sort order (1, 2, 3...)"
        UIDropDownMenu_AddButton(info)
    end)
    
    -- Info footer note
    local infoText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOP", displaySection, "BOTTOM", 0, -15)
    infoText:SetText("Note: Default targets apply to new character classifications only.\nUse the Targets tab to assign types to individual characters.")
    infoText:SetTextColor(0.5, 0.5, 0.5, 0.8)
    infoText:SetJustifyH("CENTER")
end

function SetupTargetsContent(content, parent)
    local colReorder = 15
    local colCharacter = 58
    local colRealm = 190
    local colMain = 295
    local colMainAlt = 340
    local colAlt = 385
    local colTarget = 480
    local colCurrent = 610
    local colPaused = 745
    
    local headerY = -10
    
    local headerCharacter = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerCharacter:SetPoint("TOPLEFT", colCharacter, headerY)
    headerCharacter:SetText("Character")
    headerCharacter:SetTextColor(1, 0.82, 0)
    
    local headerRealm = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerRealm:SetPoint("TOPLEFT", colRealm, headerY)
    headerRealm:SetText("Realm")
    headerRealm:SetTextColor(1, 0.82, 0)
    
    local headerMain = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerMain:SetPoint("TOPLEFT", colMain, headerY)
    headerMain:SetText("Main")
    headerMain:SetTextColor(1, 0.82, 0)
    
    local headerMainAlt = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerMainAlt:SetPoint("TOPLEFT", colMainAlt, headerY)
    headerMainAlt:SetText("M.Alt")
    headerMainAlt:SetTextColor(1, 0.82, 0)
    
    local headerAlt = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerAlt:SetPoint("TOPLEFT", colAlt, headerY)
    headerAlt:SetText("Alt")
    headerAlt:SetTextColor(1, 0.82, 0)
    
    local headerTarget = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTarget:SetPoint("TOPLEFT", colTarget, headerY)
    headerTarget:SetText("Target")
    headerTarget:SetTextColor(1, 0.82, 0)
    
    local headerCurrent = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerCurrent:SetPoint("TOPLEFT", colCurrent, headerY)
    headerCurrent:SetText("Current")
    headerCurrent:SetTextColor(1, 0.82, 0)
    
    local headerPaused = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerPaused:SetPoint("TOPLEFT", colPaused, headerY)
    headerPaused:SetText("Pause")
    headerPaused:SetTextColor(1, 0.82, 0)
    
    local separator = content:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.25, 0.25, 0.25, 0.8)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -32)
    separator:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -32)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -26, 0)
    
    local scrollContent = CreateFrame("Frame")
    scrollContent:SetWidth(900)
    scrollFrame:SetScrollChild(scrollContent)
    
    parent.targetsScrollContent = scrollContent
    parent.targetsScrollFrame = scrollFrame
    parent.targetRows = {}
    
    parent.targetsColPos = {
        reorder = colReorder,
        character = colCharacter,
        realm = colRealm,
        main = colMain,
        mainAlt = colMainAlt,
        alt = colAlt,
        target = colTarget,
        current = colCurrent,
        paused = colPaused
    }
end

function SetupLedgerContent(content, parent)
    local Data = WarbandAccountant.Data
    
    local summaryText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summaryText:SetPoint("TOPLEFT", 10, -10)
    summaryText:SetText("Transaction History")
    summaryText:SetTextColor(1, 0.82, 0)
    
    local clearBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("TOPRIGHT", -10, -8)
    clearBtn:SetText("Clear History")
    clearBtn:SetScript("OnClick", function() StaticPopup_Show("WARBANDACCOUNTANT_CLEAR_LEDGER") end)
    
    StaticPopupDialogs["WARBANDACCOUNTANT_CLEAR_LEDGER"] = {
        text = "Clear all ledger history?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function() Data:ClearLedger(); UI:UpdateLedger() end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    
    local statsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsText:SetPoint("TOPLEFT", summaryText, "BOTTOMLEFT", 0, -10)
    parent.ledgerStatsText = statsText
    
    local separator = content:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.25, 0.25, 0.25, 0.8)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -50)
    separator:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -50)
    
    local colTime = 10
    local colChar = 100
    local colType = 200
    local colAmount = 300
    local colBalance = 420
    
    local hTime = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hTime:SetPoint("TOPLEFT", colTime, -60)
    hTime:SetText("Time")
    hTime:SetTextColor(0.8, 0.8, 0.8)
    
    local hChar = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hChar:SetPoint("TOPLEFT", colChar, -60)
    hChar:SetText("Character")
    hChar:SetTextColor(0.8, 0.8, 0.8)
    
    local hType = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hType:SetPoint("TOPLEFT", colType, -60)
    hType:SetText("Type")
    hType:SetTextColor(0.8, 0.8, 0.8)
    
    local hAmount = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hAmount:SetPoint("TOPLEFT", colAmount, -60)
    hAmount:SetText("Amount")
    hAmount:SetTextColor(0.8, 0.8, 0.8)
    
    local hBalance = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hBalance:SetPoint("TOPLEFT", colBalance, -60)
    hBalance:SetText("Warband Bank")
    hBalance:SetTextColor(0.8, 0.8, 0.8)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -26, 0)
    
    local scrollContent = CreateFrame("Frame")
    scrollContent:SetWidth(650)
    scrollFrame:SetScrollChild(scrollContent)
    
    parent.ledgerScrollContent = scrollContent
    parent.ledgerScrollFrame = scrollFrame
    parent.ledgerRows = {}
end

function UI:UpdateTargets()
    if not mainFrame then return end
    local Data = WarbandAccountant.Data
    local content = mainFrame.targetsScrollContent
    local colPos = mainFrame.targetsColPos
    local characters = Data:GetAllCharacters()
    local charList = {}
    local sortMode = Data:GetSortMode()
    
    for _, row in ipairs(mainFrame.targetRows or {}) do if row then row:Hide() end end
    wipe(mainFrame.targetRows or {})
    mainFrame.targetRows = mainFrame.targetRows or {}
    
    for id, data in pairs(characters) do
        table.insert(charList, {
            id = id, name = data.name, realm = data.realm, class = data.class,
            currentGold = data.currentGold or 0, targetGold = data.targetGold or 0,
            paused = data.paused, charType = data.charType, 
            sortOrder = data.sortOrder or 0, added = data.added or 0
        })
    end
    
    table.sort(charList, function(a, b) return (a.sortOrder or 0) < (b.sortOrder or 0) end)
    
    local rowHeight = 44
    local yOffset = -8
    
    for i, char in ipairs(charList) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(900, rowHeight)
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        if i % 2 == 0 then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
        end
        
        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, 0.05)
        row.highlight:Hide()
        row:SetScript("OnEnter", function(self) self.highlight:Show() end)
        row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
        
        if sortMode == "arrow" then
            -- Up arrow button
            local upBtn = CreateFrame("Button", nil, row)
            upBtn:SetSize(16, 16)
            upBtn:SetPoint("LEFT", colPos.reorder, 8)
            
            local upTex = upBtn:CreateTexture(nil, "ARTWORK")
            upTex:SetAllPoints()
            upTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            upTex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            upBtn:SetNormalTexture(upTex)
            
            local upTexPushed = upBtn:CreateTexture(nil, "ARTWORK")
            upTexPushed:SetAllPoints()
            upTexPushed:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Down")
            upTexPushed:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            upBtn:SetPushedTexture(upTexPushed)
            
            local upTexDisabled = upBtn:CreateTexture(nil, "ARTWORK")
            upTexDisabled:SetAllPoints()
            upTexDisabled:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Disabled")
            upTexDisabled:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            upBtn:SetDisabledTexture(upTexDisabled)
            
            upBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            
            if i > 1 then
                upBtn:SetScript("OnClick", function()
                    local prevChar = charList[i - 1]
                    if prevChar then
                        Data:SwapCharacterOrder(char.id, prevChar.id)
                        UI:UpdateTargets()
                    end
                end)
                upBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Move Up")
                    GameTooltip:Show()
                end)
                upBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
                upBtn:Disable()
            end
            
            -- Down arrow button
            local downBtn = CreateFrame("Button", nil, row)
            downBtn:SetSize(16, 16)
            downBtn:SetPoint("TOP", upBtn, "BOTTOM", 0, 2)
            
            local downTex = downBtn:CreateTexture(nil, "ARTWORK")
            downTex:SetAllPoints()
            downTex:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            downTex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            downBtn:SetNormalTexture(downTex)
            
            local downTexPushed = downBtn:CreateTexture(nil, "ARTWORK")
            downTexPushed:SetAllPoints()
            downTexPushed:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
            downTexPushed:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            downBtn:SetPushedTexture(downTexPushed)
            
            local downTexDisabled = downBtn:CreateTexture(nil, "ARTWORK")
            downTexDisabled:SetAllPoints()
            downTexDisabled:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
            downTexDisabled:SetTexCoord(0.25, 0.75, 0.25, 0.75)
            downBtn:SetDisabledTexture(downTexDisabled)
            
            downBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
            
            if i < #charList then
                downBtn:SetScript("OnClick", function()
                    local nextChar = charList[i + 1]
                    if nextChar then
                        Data:SwapCharacterOrder(char.id, nextChar.id)
                        UI:UpdateTargets()
                    end
                end)
                downBtn:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText("Move Down")
                    GameTooltip:Show()
                end)
                downBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
                downBtn:Disable()
            end
        else
            -- Number input mode
            local orderEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            orderEdit:SetSize(36, 22)
            orderEdit:SetPoint("LEFT", colPos.reorder, 0)
            orderEdit:SetAutoFocus(false)
            orderEdit:SetNumeric(true)
            orderEdit:SetMaxLetters(3)
            orderEdit:SetJustifyH("CENTER")
            orderEdit:SetText(tostring(i))
            
            orderEdit:SetScript("OnEnterPressed", function(self)
                local newPos = tonumber(self:GetText())
                if newPos and newPos >= 1 and newPos <= #charList and newPos ~= i then
                    local movedChar = table.remove(charList, i)
                    table.insert(charList, newPos, movedChar)
                    
                    for idx, ch in ipairs(charList) do
                        Data:SetCharacterSortOrder(ch.id, idx)
                    end
                    
                    UI:UpdateTargets()
                else
                    self:SetText(tostring(i))
                    self:ClearFocus()
                end
            end)
            
            orderEdit:SetScript("OnEditFocusLost", function(self)
                self:SetText(tostring(i))
            end)
        end
        
        local color = RAID_CLASS_COLORS[char.class] or {r=1, g=1, b=1}
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", colPos.character, 0)
        nameText:SetText(char.name)
        nameText:SetTextColor(color.r, color.g, color.b)
        
        local realmText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        realmText:SetPoint("LEFT", colPos.realm, 0)
        realmText:SetWidth(130)
        realmText:SetJustifyH("LEFT")
        realmText:SetText(char.realm)
        realmText:SetTextColor(0.6, 0.6, 0.6)
        
        local function CreateTypeCheckbox(col, typeName, isChecked)
            local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            check:SetSize(24, 24)
            check:SetPoint("LEFT", col, 0)
            check:SetChecked(isChecked)
            
            check:SetScript("OnClick", function(self)
                local isNowChecked = self:GetChecked()
                
                if isNowChecked then
                    if row.checkMain and row.checkMain ~= self then row.checkMain:SetChecked(false) end
                    if row.checkMainAlt and row.checkMainAlt ~= self then row.checkMainAlt:SetChecked(false) end
                    if row.checkAlt and row.checkAlt ~= self then row.checkAlt:SetChecked(false) end
                    
                    Data:SetCharacterType(char.id, typeName)
                    UI:UpdateTargets()
                else
                    Data:SetCharacterType(char.id, nil)
                end
                
                UI:UpdateTooltip()
            end)
            
            check:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local displayName = typeName == "mainAlt" and "Main Alt" or typeName:gsub("^%l", string.upper)
                GameTooltip:SetText(string.format("Set as %s", displayName))
                GameTooltip:AddLine(string.format("Sets target to %s default", displayName), 1, 1, 1, true)
                GameTooltip:Show()
            end)
            
            check:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            return check
        end
        
        local currentType = Data:GetCharacterType(char.id)
        
        row.checkMain = CreateTypeCheckbox(colPos.main, "main", currentType == "main")
        row.checkMainAlt = CreateTypeCheckbox(colPos.mainAlt, "mainAlt", currentType == "mainAlt")
        row.checkAlt = CreateTypeCheckbox(colPos.alt, "alt", currentType == "alt")
        
        local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        editBox:SetSize(80, 22)
        editBox:SetPoint("LEFT", colPos.target, 0)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(true)
        editBox:SetMaxLetters(7)
        editBox:SetText(tostring(math.floor(char.targetGold / 10000)))
        editBox:SetJustifyH("RIGHT")
        editBox:SetTextInsets(0, 8, 0, 0)
        
        local goldLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        goldLabel:SetPoint("LEFT", editBox, "RIGHT", 4, 0)
        goldLabel:SetText("g")
        goldLabel:SetTextColor(1, 0.82, 0)
        
        editBox:SetScript("OnEnterPressed", function(self)
            local goldValue = tonumber(self:GetText()) or 0
            Data:SetCharacterTarget(char.id, goldValue * 10000)
            self:ClearFocus()
            UI:UpdateTargets()
        end)
        editBox:SetScript("OnEditFocusLost", function(self)
            local goldValue = tonumber(self:GetText()) or 0
            Data:SetCharacterTarget(char.id, goldValue * 10000)
            UI:UpdateTargets()
        end)
        
        local currentText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        currentText:SetPoint("LEFT", colPos.current, 0)
        currentText:SetJustifyH("LEFT")
        currentText:SetWidth(140)
        
        local gold = math.floor(char.currentGold / 10000)
        local silver = math.floor((char.currentGold % 10000) / 100)
        local copper = char.currentGold % 100
        
        if gold > 0 then currentText:SetText(string.format("%d|cFF00FF00g|r %d|cFFCCCCCCs|r %d|cFFB87333c|r", gold, silver, copper))
        elseif silver > 0 then currentText:SetText(string.format("%d|cFFCCCCCCs|r %d|cFFB87333c|r", silver, copper))
        else currentText:SetText(string.format("%d|cFFB87333c|r", copper)) end
        
        if char.currentGold < char.targetGold then currentText:SetTextColor(1, 0.4, 0.4)
        elseif char.currentGold > char.targetGold then currentText:SetTextColor(0.4, 1, 0.4)
        else currentText:SetTextColor(1, 1, 1) end
        
        local pauseCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        pauseCheck:SetSize(24, 24)
        pauseCheck:SetPoint("LEFT", colPos.paused, 0)
        pauseCheck:SetChecked(char.paused)
        pauseCheck:SetScript("OnClick", function(self)
            local isPaused = self:GetChecked()
            Data:GetCharacterData(char.id).paused = isPaused
            UI:UpdateTooltip()
        end)
        pauseCheck:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Pause Automation")
            GameTooltip:AddLine("When checked, this character will not auto-deposit or withdraw", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        pauseCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)
        
        table.insert(mainFrame.targetRows, row)
        yOffset = yOffset - rowHeight
    end
    
    content:SetHeight(math.max(400, math.abs(yOffset)))
    
    if #charList == 0 then
        local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        emptyText:SetPoint("CENTER", 0, 0)
        emptyText:SetText("No characters found.\nLog in to other characters to add them.")
        emptyText:SetJustifyH("CENTER")
    end
end

function UI:UpdateLedger()
    if not mainFrame or not mainFrame.ledgerScrollContent then return end
    local Data = WarbandAccountant.Data
    local content = mainFrame.ledgerScrollContent
    local entries = Data:GetLedgerEntries(100)
    
    for _, row in ipairs(mainFrame.ledgerRows or {}) do if row then row:Hide() end end
    wipe(mainFrame.ledgerRows or {})
    mainFrame.ledgerRows = mainFrame.ledgerRows or {}
    
    if mainFrame.ledgerEmptyText then
        mainFrame.ledgerEmptyText:Hide()
        mainFrame.ledgerEmptyText = nil
    end
    
    local totalDeposited, totalWithdrawn = Data:GetTotalLedgerStats()
    local totalMade = totalDeposited - totalWithdrawn
    
    local madeColor, madePrefix
    if totalMade > 0 then
        madeColor = "|cFF00FF00"
        madePrefix = "+"
    elseif totalMade < 0 then
        madeColor = "|cFFFF0000"
        madePrefix = ""
    else
        madeColor = "|cFFFFFFFF"
        madePrefix = ""
    end
    
    mainFrame.ledgerStatsText:SetText(string.format("Deposited: |cFF00FF00%s|r  |  Withdrawn: |cFFFF0000%s|r  |  Made: %s%s%s|r",
        WarbandAccountant.FormatGold(totalDeposited), 
        WarbandAccountant.FormatGold(totalWithdrawn),
        madeColor,
        madePrefix,
        WarbandAccountant.FormatGold(totalMade)))
    
    if #entries == 0 then
        local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        emptyText:SetPoint("CENTER", 0, 0)
        emptyText:SetText("No transactions recorded yet.\nOpen your Warband Bank to record transfers.")
        emptyText:SetJustifyH("CENTER")
        content:SetHeight(400)
        mainFrame.ledgerEmptyText = emptyText
        return
    end
    
    local rowHeight = 24
    local yOffset = 0
    local colTime = 10
    local colChar = 100
    local colType = 200
    local colAmount = 300
    local colBalance = 420
    
    for i, entry in ipairs(entries) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(650, rowHeight)
        row:SetPoint("TOPLEFT", 0, yOffset)
        
        if i % 2 == 0 then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
        end
        
        local timeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        timeText:SetPoint("LEFT", colTime, 0)
        timeText:SetText(FormatTimestamp(entry.timestamp))
        timeText:SetTextColor(0.7, 0.7, 0.7)
        
        local charText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        charText:SetPoint("LEFT", colChar, 0)
        charText:SetText(entry.characterName or "Unknown")
        charText:SetWidth(90)
        charText:SetJustifyH("LEFT")
        
        local typeText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        typeText:SetPoint("LEFT", colType, 0)
        if entry.type == "DEPOSIT" or entry.type == "MANUAL_DEPOSIT" then
            typeText:SetText("Deposit")
            typeText:SetTextColor(0, 1, 0)
        else
            typeText:SetText("Withdraw")
            typeText:SetTextColor(1, 0, 0)
        end
        
        local amountText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        amountText:SetPoint("LEFT", colAmount, 0)
        amountText:SetText(WarbandAccountant.FormatGold(entry.amount))
        amountText:SetJustifyH("RIGHT")
        
        local balanceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        balanceText:SetPoint("LEFT", colBalance, 0)
        balanceText:SetText(WarbandAccountant.FormatGold(entry.balanceAfter))
        balanceText:SetTextColor(1, 0.82, 0)
        balanceText:SetJustifyH("RIGHT")
        
        table.insert(mainFrame.ledgerRows, row)
        yOffset = yOffset - rowHeight
    end
    
    content:SetHeight(math.max(400, math.abs(yOffset)))
end

function UI:ToggleMainWindow()
    if not mainFrame then mainFrame = CreateMainWindow() end
    if mainFrame:IsShown() then mainFrame:Hide()
    else self:UpdateTargets(); if mainFrame.selectedTab == 2 then self:UpdateLedger() end; mainFrame:Show() end
end