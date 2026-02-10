local ADDON_NAME, WarbandAccountant = ...
local Data = WarbandAccountant.Data
local Core = WarbandAccountant.Core

local UI = {}
WarbandAccountant.UI = UI

local mainFrame = nil
local minimapLDB = nil

-- Check if libraries loaded
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

-- Tooltip content setup
local function SetupTooltip(tooltip)
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
                session = session
            })
        end
    end
    
    table.sort(charList, function(a, b) return a.gold > b.gold end)
    
    tooltip:AddLine("Warband Characters:", 0.8, 0.8, 0.8)
    
    for i, char in ipairs(charList) do
        if i <= 10 then
            local color = RAID_CLASS_COLORS[char.class] or {r=1, g=1, b=1}
            local sessionIndicator = ""
            if char.session > 0 then
                sessionIndicator = " |cFF00FF00↑|r"
            elseif char.session < 0 then
                sessionIndicator = " |cFFFF0000↓|r"
            end
            
            tooltip:AddDoubleLine(
                "  " .. char.name .. sessionIndicator .. (char.realm ~= GetRealmName() and " (*)" or ""), 
                FormatGoldShort(char.gold), 
                color.r, color.g, color.b, 
                1, 1, 1
            )
        end
    end
    
    if #charList > 10 then
        tooltip:AddLine("  ... and " .. (#charList - 10) .. " more", 0.5, 0.5, 0.5)
    end
    
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("Total Tracked:", WarbandAccountant.FormatGold(totalTracked), 0.6, 0.8, 1, 0.6, 0.8, 1)
    tooltip:AddLine(" ")
    tooltip:AddLine("Left-Click: Open Window", 0.5, 0.5, 0.5)
    tooltip:AddLine("Right-Click: Settings", 0.5, 0.5, 0.5)
end

function UI:Init()
    if not hasLDB or not hasLibDBIcon then
        print("|cFFFF0000Warband Accountant:|r LibDBIcon not found. Minimap button disabled.")
        return
    end
    
    local LDB = LibStub("LibDataBroker-1.1")
    local libDBIcon = LibStub("LibDBIcon-1.0")
    
    -- Create the data object
    minimapLDB = LDB:NewDataObject("WarbandAccountant", {
        type = "launcher",
        text = "Warband Accountant",
        icon = "Interface\\AddOns\\WarbandAccountant\\Textures\\minimap",
        
        OnClick = function(self, button)
            if button == "LeftButton" then
                UI:ToggleMainWindow()
            elseif button == "RightButton" then
                WarbandAccountant.Settings:OpenSettings()
            end
        end,
        
        OnTooltipShow = function(tooltip)
            SetupTooltip(tooltip)
        end,
    })
    
    -- Register with LibDBIcon - this creates the actual button
    libDBIcon:Register("WarbandAccountant", minimapLDB, Data:GetSettings())
end

-- Toggle minimap button visibility
function UI:ToggleMinimapButton()
    if not hasLibDBIcon then return end
    
    local libDBIcon = LibStub("LibDBIcon-1.0")
    local settings = Data:GetSettings()
    
    if settings.hide then
        libDBIcon:Hide("WarbandAccountant")
    else
        libDBIcon:Show("WarbandAccountant")
    end
end

-- Force refresh tooltip if open
function UI:UpdateTooltip()
    if not hasLibDBIcon then return end
    
    local button = _G["LibDBIcon10_WarbandAccountant"]
    if button and GameTooltip:IsOwned(button) then
        GameTooltip:ClearLines()
        SetupTooltip(GameTooltip)
        GameTooltip:Show()
    end
end

-- Main Window
local function CreateMainWindow()
    local f = CreateFrame("Frame", "WarbandAccountantMainFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(680, 450)
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
    
    f.TitleBg:SetHeight(30)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -8)
    f.title:SetText("Warband Accountant - Character Targets")
    
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 25, -45)
    content:SetPoint("BOTTOMRIGHT", -25, 15)
    
    local colCharacter = 10
    local colRealm = 140
    local colTarget = 290
    local colCurrent = 480
    
    local headerY = -10
    
    local headerCharacter = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerCharacter:SetPoint("TOPLEFT", colCharacter, headerY)
    headerCharacter:SetText("Character")
    headerCharacter:SetTextColor(1, 0.82, 0)
    
    local headerRealm = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerRealm:SetPoint("TOPLEFT", colRealm, headerY)
    headerRealm:SetText("Realm")
    headerRealm:SetTextColor(1, 0.82, 0)
    
    local headerTarget = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTarget:SetPoint("TOPLEFT", colTarget, headerY)
    headerTarget:SetText("Target Gold")
    headerTarget:SetTextColor(1, 0.82, 0)
    
    local headerCurrent = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerCurrent:SetPoint("TOPLEFT", colCurrent, headerY)
    headerCurrent:SetText("Current")
    headerCurrent:SetTextColor(1, 0.82, 0)
    
    local separator = content:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.25, 0.25, 0.25, 0.8)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -32)
    separator:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -32)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -26, 0)
    
    local scrollContent = CreateFrame("Frame")
    scrollContent:SetWidth(630)
    scrollFrame:SetScrollChild(scrollContent)
    
    f.scrollContent = scrollContent
    f.scrollFrame = scrollFrame
    f.rows = {}
    
    f.colPos = {
        character = colCharacter,
        realm = colRealm,
        target = colTarget,
        current = colCurrent
    }
    
    return f
end

function UI:UpdateMainWindow()
    if not mainFrame then return end
    
    local content = mainFrame.scrollContent
    local colPos = mainFrame.colPos
    local characters = Data:GetAllCharacters()
    local charList = {}
    
    for _, row in ipairs(mainFrame.rows) do
        if row then row:Hide() end
    end
    wipe(mainFrame.rows)
    
    for id, data in pairs(characters) do
        table.insert(charList, {
            id = id,
            name = data.name,
            realm = data.realm,
            class = data.class,
            currentGold = data.currentGold or 0,
            targetGold = data.targetGold or 0,
            added = data.added or 0
        })
    end
    
    table.sort(charList, function(a, b) 
        return (a.added or 0) < (b.added or 0)
    end)
    
    local rowHeight = 32
    local yOffset = -8
    
    for i, char in ipairs(charList) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(630, rowHeight)
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
        
        row:SetScript("OnEnter", function(self)
            self.highlight:Show()
        end)
        row:SetScript("OnLeave", function(self)
            self.highlight:Hide()
        end)
        
        local color = RAID_CLASS_COLORS[char.class] or {r=1, g=1, b=1}
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", colPos.character, 0)
        nameText:SetText(char.name)
        nameText:SetTextColor(color.r, color.g, color.b)
        
        local realmText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        realmText:SetPoint("LEFT", colPos.realm, 0)
        realmText:SetWidth(140)
        realmText:SetJustifyH("LEFT")
        realmText:SetText(char.realm)
        realmText:SetTextColor(0.6, 0.6, 0.6)
        
        local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        editBox:SetSize(110, 22)
        editBox:SetPoint("LEFT", colPos.target, 0)
        editBox:SetAutoFocus(false)
        editBox:SetNumeric(true)
        editBox:SetMaxLetters(7)
        editBox:SetText(tostring(math.floor(char.targetGold / 10000)))
        editBox:SetJustifyH("RIGHT")
        editBox:SetTextInsets(0, 8, 0, 0)
        
        local goldLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        goldLabel:SetPoint("LEFT", editBox, "RIGHT", 6, 0)
        goldLabel:SetText("g")
        goldLabel:SetTextColor(1, 0.82, 0)
        
        editBox:SetScript("OnEnterPressed", function(self)
            local goldValue = tonumber(self:GetText()) or 0
            Data:SetCharacterTarget(char.id, goldValue * 10000)
            self:ClearFocus()
            UI:UpdateMainWindow()
        end)
        
        editBox:SetScript("OnEditFocusLost", function(self)
            local goldValue = tonumber(self:GetText()) or 0
            Data:SetCharacterTarget(char.id, goldValue * 10000)
            UI:UpdateMainWindow()
        end)
        
        local currentText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        currentText:SetPoint("LEFT", colPos.current, 0)
        currentText:SetJustifyH("LEFT")
        currentText:SetWidth(170)
        
        local gold = math.floor(char.currentGold / 10000)
        local silver = math.floor((char.currentGold % 10000) / 100)
        local copper = char.currentGold % 100
        
        if gold > 0 then
            currentText:SetText(string.format("%d|cFF00FF00g|r %d|cFFCCCCCCs|r %d|cFFB87333c|r", gold, silver, copper))
        elseif silver > 0 then
            currentText:SetText(string.format("%d|cFFCCCCCCs|r %d|cFFB87333c|r", silver, copper))
        else
            currentText:SetText(string.format("%d|cFFB87333c|r", copper))
        end
        
        if char.currentGold < char.targetGold then
            currentText:SetTextColor(1, 0.4, 0.4)
        elseif char.currentGold > char.targetGold then
            currentText:SetTextColor(0.4, 1, 0.4)
        else
            currentText:SetTextColor(1, 1, 1)
        end
        
        table.insert(mainFrame.rows, row)
        yOffset = yOffset - rowHeight
    end
    
    content:SetHeight(math.max(350, math.abs(yOffset)))
    
    if #charList == 0 then
        local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        emptyText:SetPoint("CENTER", 0, 0)
        emptyText:SetText("No characters found.\nLog in to other characters to add them to Warband Accountant.")
        emptyText:SetJustifyH("CENTER")
    end
end

function UI:ToggleMainWindow()
    if not mainFrame then
        mainFrame = CreateMainWindow()
    end
    
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        self:UpdateMainWindow()
        mainFrame:Show()
    end
end