local ADDON_NAME, WarbandAccountant = ...

-- -- Warband Accountant -- Changelog Data --------------------------------------
--
-- This is the ONLY file you need to touch when shipping a new version.
--
-- HOW TO ADD A NEW VERSION:
--   1. Add a new string to the top of VERSIONS (e.g. "1.0.6")
--   2. Add a matching key to CHANGELOG with your entries
--   3. Bump CURRENT_ADDON_VERSION in Data.lua to match
--   4. Bump the version string in WarbandAccountant.toc
--
-- ENTRY FORMAT:
--   { tag="New",     text="Short feature name" }          -- green  [New]
--   { tag="Fix",     text="What was broken/fixed" }       -- orange [Fix]
--   { tag="Improve", text="Enhancement description" }     -- cyan   [Improve]
--   { tag=nil,       text="Body / detail line" }          -- grey, indented under the above
--
-- -----------------------------------------------------------------------------

-- Ordered newest-first. Add new version strings here when releasing.
WarbandAccountant.ChangelogVersions = {
    "2.3.0",
    "2.2.0",
    "2.1.9",
    "2.1.8",
    "2.1.7",
    "2.1.6",
    "2.1.5",
    "2.1.4",
    "2.1.3",
    "2.1.2",
    "2.1.1",
    "2.1.0",
    "2.0.1",
    "2.0.0",
    "1.0.7",
    "1.0.6",
    "1.0.5",
    "1.0.4",
}

WarbandAccountant.ChangelogIcon = "Interface\\AddOns\\WarbandAccountant\\Textures\\minimap"

-- Keyed by version string. Each value is a list of entry tables.
WarbandAccountant.Changelog = {

    ["2.3.0"] = {
        { tag="New",     text="Savings Goals" },
        { tag=nil,       text="Set a savings goal in Settings and track it on the new Goals tab, which appears once you have a goal. You'll see your progress, an estimate of when you'll reach it based on how fast your Warband Bank has been growing, and a graph with your goal line and where you're headed. You'll also get a chat message when you hit it." },
        { tag="New",     text="WoW Token goals" },
        { tag=nil,       text="Check 'Use WoW Token price' and your goal follows the live token price automatically." },
        { tag="New",     text="Goal end dates" },
        { tag=nil,       text="Add an optional end date, perfect for limited-time items. The Goals tab shows how much you need to earn per day (or per week) to make it, tells you if you're on pace or falling behind, and marks the deadline on the graph." },
        { tag="New",     text="Show goal estimates in days or weeks" },
        { tag=nil,       text="Pick whichever reads better for you in the Savings Goal settings." },
        { tag="New",     text="Token Affordability" },
        { tag=nil,       text="The WoW Token card on the Overview now shows how many tokens your Warband Bank can buy and roughly when you'll be able to afford the next one. Gold on your characters isn't counted, since that's their working capital." },
        { tag="New",     text="Time ranges on graphs" },
        { tag=nil,       text="Gold History can now show 24 Hours, 7 Days, 30 Days, or All, and the Token Graph can show 24 Hours, 3 Days, or 7 Days. The high and low stats follow the range you pick. Each graph goes back to its default view when you open it." },
        { tag="New",     text="Weekly Profit on the floating token frame" },
        { tag=nil,       text="Optionally show this week's Warband Bank profit right under the token price. Off by default, turn it on in Settings > Token Price." },
        { tag="Improve", text="Settings layout" },
        { tag=nil,       text="Savings Goal and Token Price now sit side by side, matching the Automation and Guild Bank row." },
        { tag="Fix",     text="Token icon disappearing in icon mode" },
        { tag=nil,       text="With icon mode on and price arrows off, the token icon on the floating frame could vanish until the next price update." },
        { tag="Improve", text="Chinese translation" },
        { tag=nil,       text="All of the new features are translated into Simplified Chinese (zhCN)." },
    },

    ["2.2.0"] = {
        { tag="Improve", text="Graphs rebuilt from the ground up" },
        { tag=nil,       text="Gold History and the Token Graph now draw smooth lines instead of dotted ones, space points by actual time, use clean round-number axis labels, and shade the area under the line." },
        { tag="New",     text="Hover crosshair on graphs" },
        { tag=nil,       text="Hover anywhere on a graph to see the nearest point's time, value, and change from the previous point. Gold History also shows which character made the transaction." },
        { tag="Improve", text="Graphs show your full history" },
        { tag=nil,       text="The 100-point limit is gone. Large histories are automatically thinned to what fits on screen without losing spikes." },
        { tag="Improve", text="Gold History uses a step line" },
        { tag=nil,       text="Balances stay flat between transactions and then jump, so the graph now shows exactly that instead of drawing misleading diagonals." },
        { tag="Fix",     text="/wba delete never actually deleting anyone" },
        { tag=nil,       text="The command lowercased the whole message before reading the character name, so 'Bob' became 'bob' and never matched your actual character. Fixed -- the name now keeps its real capitalization." },
        { tag="Fix",     text="Rows piling up in memory the longer you play" },
        { tag=nil,       text="Overview, Targets, Ledger, and Token History were creating a fresh set of rows every single refresh and just hiding the old ones instead of reusing them. Rebuilt all four to reuse their rows, so refreshing no longer leaves anything behind." },
        { tag="Fix",     text="'No results' messages sometimes sticking around" },
        { tag=nil,       text="The empty-state text on Ledger and Token History was being recreated every refresh and never properly cleared." },
        { tag="Fix",     text="Ledger's character filter missing older transactions" },
        { tag=nil,       text="Filtering to a specific character only searched your most recent 500 entries even though the ledger stores up to 5,000, so a less-active character could show far fewer results than they actually have. It now searches your full history." },
        { tag="Fix",     text="Failed auto-deposits failing silently" },
        { tag=nil,       text="A failed automatic deposit now shows an error message, matching how a failed withdrawal already worked." },
        { tag="Improve", text="Assorted internal cleanup" },
        { tag=nil,       text="A few settings (like the Token update frequency options) could get stuck showing your client's default language instead of your chosen one after logging in. Also trimmed some unnecessary background work that ran on every screen refresh." },
    },

    ["2.1.9"] = {
        { tag="New", text="Account Total" },
        { tag=nil,   text="A new 'Account Total' line on the Overview tab (Warband Bank + every character's current gold, live). Also added as a filter option on the Gold History graph -- unlike Warband Bank Total and per-character views, this one starts tracking from this update forward (the addon has never logged historical on-hand gold per character), so its history builds up over time rather than appearing all at once." },
        { tag="Fix", text="Weekly Income showing +0c despite real activity on new installs" },
        { tag=nil,   text="If every ledger entry you had was newer than this week's reset (always true right after installing), the calculation had no baseline to compare against and just gave up, reporting 0 even with real deposits/withdrawals. It now derives a baseline from your earliest known entry instead, so new installs show accurate weekly income from day one." },
    },

    ["2.1.8"] = {
        { tag="New", text="Option to disable the changelog auto-popup on update" },
        { tag=nil,   text="New 'Changelog on Update' dropdown in Settings > Display. Defaults to Yes (current behavior). Set it to No and updates apply silently, no auto-opened Changelog tab." },
        { tag="Improve", text="Thousands Separator dropdown shortened" },
        { tag=nil,   text="Options now just read None/Comma/Period instead of including a full example number, so the dropdown doesn't crowd the row." },
    },

    ["2.1.7"] = {
        { tag="New", text="Gold History tab" },
        { tag=nil,   text="A balance-over-time graph, same look as the Token Graph, built entirely from your existing Ledger data. Filter by Warband Bank Total or a specific character (shows that character's net Warband Bank contribution over time, not their on-hand gold)." },
        { tag="New", text="Thousands separator for gold amounts" },
        { tag=nil,   text="New Settings > Display option: None, Comma (1,234,567), or Period (1.234.567). Defaults to comma on for everyone, including existing installs." },
        { tag="Improve", text="Ledger history cap raised from 1,000 to 5,000 entries" },
        { tag="Fix", text="Gold History Y-axis showing garbled numbers and raw color codes" },
        { tag=nil,   text="The graph's axis labels were reading raw copper values as if they were already gold, showing numbers roughly 10,000x too large. The oversized text also wrapped mid-way through a color code, showing a raw escape-code artifact instead of a properly colored number." },
        { tag="Fix", text="Gold History 'Current' label overlapping the Filter dropdown" },
    },

    ["2.1.6"] = {
        { tag="New", text="Simplified Chinese localization" },
        { tag=nil,   text="Full Simplified Chinese translation, contributed by community volunteer Justinxu666. Select it from the Language dropdown in Settings. Localization framework also supports adding more languages down the line." },
        { tag="Fix", text="Ledger stats line overlapping the filter dropdown" },
        { tag=nil,   text="A longer translated stats line could wrap to a second line and overlap the character filter dropdown above it. Stats now sit on their own row with room to wrap safely." },
        { tag="New", text="Startup chat messages" },
        { tag=nil,   text="A quick note on login pointing to the Support tab for bug reports/feedback, and a call for translation volunteers." },
        { tag="New", text="Automation explanation text" },
        { tag=nil,   text="A short note under the automation checkboxes explaining that transfers happen automatically when you open your Warband Bank, and that targets are set per-character on the Targets tab." },
    },

    ["2.1.5"] = {
        { tag="Fix", text="Weekly Income always showing 0 for some regions" },
        { tag=nil,   text="The weekly reset time was calculated from a hardcoded per-region schedule that silently fell back to the US (Tuesday) schedule whenever region detection didn't resolve correctly -- notably wrong on China's separately-operated client. Now uses the server's own reset countdown directly, which is correct for every region automatically." },
        { tag="Fix", text="Minimap button did nothing on the first click" },
        { tag=nil,   text="Opening the window for the very first time (minimap button, or /wba, before the window had ever been created) silently opened and immediately closed it in the same click. Only the second click actually showed anything. Fixed." },
        { tag="New", text="/wba debuginfo command" },
        { tag=nil,   text="Prints region, locale, realm, client build, server/local clock skew, and the weekly reset calculation -- handy to paste into a bug report." },
    },

    ["2.1.4"] = {
        { tag="New", text="Support tab" },
        { tag=nil,   text="A new tab in the side nav with links to the Discord and GitHub Issues, each with a click-to-select field for an easy copy." },
        { tag="New", text="Supporters section" },
        { tag=nil,   text="A thank-you list on the Support tab, laid out 5 names wide and scrollable as it grows." },
        { tag="New", text="UI Scale setting" },
        { tag=nil,   text="A new dropdown in Settings scales the whole window from 50% to 300% in 10% steps, for anything from a small laptop screen to a 4K monitor. Applies immediately and remembers your choice." },
    },

    ["2.1.3"] = {
        { tag="New", text="First-run tutorial" },
        { tag=nil,   text="Brand-new installs now get a short guided tour on first login: Overview, Targets, Ledger, Token Graph, and Settings, using the same tooltip style Blizzard uses for its own in-game tutorials. Existing installs don't get the tour automatically. Replay it anytime with /wba tutorial." },
    },

    ["2.1.2"] = {
        { tag="New", text="Home Guild setting" },
        { tag=nil,   text="A new dropdown in Settings lets you pick a specific guild's bank to always show on the Overview tab, regardless of which guild the logged-in character actually belongs to. Only guilds a GM character has synced appear in the list." },
        { tag=nil,   text="Previously, an alt in a different guild than your GM had no way to see that guild's bank at all -- it would just show 'None tracked'." },
        { tag="New", text="Guild Banks tab" },
        { tag=nil,   text="Once you've synced two or more guild banks (by being Guild Master on more than one character), a new Guild Banks tab appears in the side nav listing every tracked guild, its balance, its realm, when it last synced, and a running total across all of them. Your Home Guild always sorts to the top of the list." },
        { tag="Fix", text="Settings layout: Display box misaligned" },
        { tag=nil,   text="The Automation/Display column split used slightly off math, so the Display box's right edge crept a few pixels past the other section boxes below it. Both columns now line up exactly." },
    },

    ["2.1.1"] = {
        { tag="Fix", text="Confirmation popup crashing when transfers require confirmation" },
        { tag=nil,   text="The deposit/withdraw confirmation dialog had two format placeholders but only one value was passed, causing a crash. Simplified to a single placeholder and removed the double question mark from the message." },
    },

    ["2.1.0"] = {
        { tag="New",     text="Token Price Display merged in" },
        { tag=nil,       text="Warband Accountant now includes WoW Token price tracking, formerly its own standalone addon. All Token Price Display settings and history carry over automatically." },
        { tag="New",     text="Token History Tab" },
        { tag=nil,       text="A new tab in the side nav shows a clean price history line graph with session high/low stats and per-point tooltips." },
        { tag="New",     text="WoW Token stat card" },
        { tag=nil,       text="The Overview dashboard now shows the current Token price alongside Warband Bank, Total Gold, and Weekly Income." },
        { tag="New",     text="Token Price settings" },
        { tag=nil,       text="Update frequency, display style, change arrow, and price alerts are now configured from the Settings tab. The floating price frame can still be shown or hidden independently." },
        { tag="New",     text="Legacy data import" },
        { tag=nil,       text="A button in Token Price settings verifies and imports price history from the standalone Token Price Display addon if it's still installed." },
        { tag="Improve", text="Settings tab now scrolls" },
        { tag=nil,       text="The Settings tab content is wrapped in a scroll frame so it never overflows the window, regardless of how many sections are added." },
        { tag="Improve", text="Minimap tooltip shows Token price" },
        { tag=nil,       text="When the floating Token price frame is hidden, the current price appears in the minimap tooltip instead, right below Warband Bank." },
        { tag="Improve", text="Consistent gold formatting" },
        { tag=nil,       text="Token price now uses the same gold/silver/copper color-coded format as the rest of the addon, with two-digit padding for silver and copper." },
        { tag="Improve", text="Slash commands expanded: /wba token." },
        { tag="Improve", text="Category default targets now apply to all characters" },
        { tag=nil,       text="Changing a category's default gold target in Settings immediately updates all characters assigned to that category. A chat message confirms which characters were updated and to what amount." },
        { tag="Improve", text="\"Total Gold\" renamed to \"Gold in Bags\"" },
        { tag=nil,       text="The Overview stat card and minimap tooltip now use the more descriptive label \"Gold in Bags\" to clarify it represents the sum of gold held across all tracked characters." },
    },

    ["2.0.1"] = {
        { tag="Fix", text="Guild bank showing wrong guild's balance" },
        { tag=nil,   text="Personal guild bank lookup could fall back to any cached guild data on the realm instead of the character's actual guild. Now only shows data for the guild you're currently in." },
        { tag="Fix", text="Guild bank displaying 'None tracked' at 0 gold" },
        { tag=nil,   text="Overview panel treated a tracked guild bank with a zero balance the same as no data at all. Now correctly shows the guild name with 0g instead of falling back to 'None tracked'." },
    },

    ["2.0.0"] = {
        { tag="New",     text="Unified Window UI" },
        { tag=nil,       text="All panels (Overview, Targets, Ledger, Settings, Changelog) consolidated into a single window with a side navigation bar." },
        { tag="New",     text="Overview / Dashboard Tab" },
        { tag=nil,       text="At-a-glance stat cards for Warband Bank balance, Total Gold, Weekly Income, and Session change. Full character list below with current vs target comparison." },
        { tag="New",     text="Inline Changelog Tab" },
        { tag=nil,       text="Changelog is now a tab inside the main window instead of a popup." },
        { tag="Improve", text="Settings moved into the addon window -- Blizzard addon panel is now a lightweight stub." },
        { tag="Improve", text="Right-click minimap button now opens directly to Settings tab." },
        { tag="Improve", text="Slash commands expanded: /wba targets, /wba ledger, /wba settings, /wba changelog." },
    },


    ["1.0.7"] = {
        { tag="Fix", text="Weekly Income displaying incorrectly" },
        { tag=nil,   text="Reset timestamp calculation was using UTC date math that doesn't work correctly in WoW's Lua environment. Now uses a hardcoded known reset anchor with 7-day stepping." },
        { tag="Fix", text="Negative gold values displaying garbled output" },
        { tag=nil,   text="Lua's modulo operator on negative numbers returns unexpected results. Negative gold amounts (e.g. a weekly loss) now display correctly with a minus sign." },
    },

    ["1.0.6"] = {
        { tag="Fix", text="Weekly Income Reset Timestamp" },
        { tag=nil,   text="Fixed an issue where the weekly income counter was calculating the reset time incorrectly, causing it to show a much lower number than expected." },
        { tag=nil,   text="The reset now targets the exact server reset time per region -- NA: Tuesday 9AM PDT, EU: Wednesday 8AM CEST, KR/TW: Thursday 10AM KST." },
    },

    ["1.0.5"] = {
        { tag="New",     text="Weekly Income Tracking" },
        { tag=nil,       text="Tracks net gold earned across all characters since your weekly reset." },
        { tag=nil,       text="Resets automatically per region -- NA: Tuesday, EU: Wednesday, KR/TW: Thursday." },
        { tag=nil,       text="Failsafe accumulator records income even if the ledger fills up mid-week." },
        { tag="New",     text="Ledger Character Filter" },
        { tag=nil,       text="New dropdown in the Ledger lets you view one character's transactions at a time." },
        { tag="New",     text="Mail Income Tracking" },
        { tag=nil,       text="Gold received from mail (AH sales, CoD, attachments) is captured in weekly income." },
        { tag="New",     text="Ledger Note Column" },
        { tag=nil,       text="The Note field for each transaction is now its own visible column." },
        { tag="Improve", text="Ledger history expanded from 500 to 1000 entries." },
        { tag="Improve", text="Tooltip shows 'This Week' income below Total Session." },
        { tag="Improve", text="Ledger stats bar includes the weekly income figure." },
        { tag="Improve", text="TOC updated for patch 12.0.7 -- Midnight: Revelations." },
    },

    ["1.0.4"] = {
        { tag="New", text="Character Deletion" },
        { tag=nil,   text="Delete old or renamed characters from the Targets tab or via /wba delete CharacterName." },
    },

}
