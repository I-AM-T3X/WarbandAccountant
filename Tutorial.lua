local ADDON_NAME, WarbandAccountant = ...

-- ===============================================================================
-- TUTORIAL (Blizzard-style HelpTip callouts, first-run only for new installs)
--
-- Only reaches into WarbandAccountant.UI's public accessors
-- (GetMainFrame / GetNavButtonFrame / GetActiveTab / EnsureWindowOpen /
-- SwitchTab) rather than any of UI.lua's private locals, so this file can be
-- edited independently of the window/tab implementation.
-- ===============================================================================

local UI = WarbandAccountant.UI

local TUTORIAL_SYSTEM = "WBA_Tutorial"

local TUTORIAL_STEPS = {
    { tab = "overview", text = "Welcome to Warband Accountant! This is your Overview: Warband Bank balance, gold in bags, and weekly income at a glance." },
    { tab = "targets",  text = "Head here now and set a gold target for this character. Anything above target auto-deposits to the Warband Bank; a shortfall auto-withdraws to top you up." },
    { tab = "ledger",   text = "Every automatic and manual transfer is logged here, so you can always see where your gold went." },
    { tab = "token",    text = "Track the WoW Token price over time right from this window. It's empty right now since there's no history yet -- it fills in as prices get checked over time, or you can import history from the old standalone Token Price Display addon if you used it." },
    { tab = "settings", text = "Automation, category defaults, and more live here. You can replay this tour anytime with /wba tutorial." },
}

local function ShowTutorialStep(index)
    local step = TUTORIAL_STEPS[index]
    if not step then return end

    local target = UI:GetNavButtonFrame(step.tab)
    if not target then
        -- Skip a step whose nav button doesn't exist or is hidden (e.g. Guild Banks)
        ShowTutorialStep(index + 1)
        return
    end

    UI:SwitchTab(step.tab)

    HelpTip:Show(UI:GetMainFrame(), {
        text = step.text,
        buttonStyle = HelpTip.ButtonStyle.GotIt,
        targetPoint = HelpTip.Point.RightEdgeCenter,
        system = TUTORIAL_SYSTEM,
        onAcknowledgeCallback = function()
            ShowTutorialStep(index + 1)
        end,
    }, target)
end

-- Manually (re)plays the tour from the start. Safe to call anytime,
-- whether the window is open, closed, or on a different tab.
function UI:StartTutorial()
    UI:EnsureWindowOpen()
    if UI:GetActiveTab() ~= "overview" then
        UI:SwitchTab("overview")
    end
    HelpTip:HideAllSystem(TUTORIAL_SYSTEM)
    ShowTutorialStep(1)
end

-- Called once at login. Only actually starts the tour for accounts that
-- have never seen it (see Data:Init() for how that's determined).
function UI:CheckAndShowTutorial()
    local Data = WarbandAccountant.Data
    if Data:HasSeenTutorial() then return end
    Data:SetTutorialSeen(true)

    C_Timer.After(0.6, function()
        UI:StartTutorial()
    end)
end

-- Called by UI.lua's main window OnHide handler so a closed window doesn't
-- leave an orphaned callout on screen mid-tour.
function UI:HideTutorialTips()
    HelpTip:HideAllSystem(TUTORIAL_SYSTEM)
end
