local ADDON_NAME, WarbandAccountant = ...

-- -- Warband Accountant -- English (US) ------------------------------------------
--
-- This is the BASE locale. Every key used anywhere in the addon must exist
-- here, since ApplyLocale() (in Locale.lua) falls back to this table for any
-- key missing from a partial translation. Other locale files only need to
-- override the keys they've actually translated.
-- -------------------------------------------------------------------------------

WarbandAccountant.LocaleData = WarbandAccountant.LocaleData or {}

WarbandAccountant.LocaleData["enUS"] = {
    -- Settings tab: section headers
    SETTINGS_SECTION_AUTOMATION   = "Automation",
    SETTINGS_SECTION_DISPLAY      = "Display",
    SETTINGS_SECTION_CATEGORIES   = "Category Names & Default Targets",
    SETTINGS_SECTION_GUILDBANK    = "Guild Bank",
    SETTINGS_SECTION_TOKEN        = "Token Price",
    SETTINGS_SECTION_LANGUAGE     = "Language",
    SETTINGS_SECTION_DANGER       = "Danger Zone",

    -- Automation
    SETTINGS_AUTO_DEPOSIT     = "Auto-deposit excess gold to Warband Bank",
    SETTINGS_AUTO_WITHDRAW    = "Auto-withdraw gold deficit from Warband Bank",
    SETTINGS_CONFIRM_TRANSFER = "Require confirmation before transfers",
    SETTINGS_AUTOMATION_DESC  = "Transfers happen automatically whenever you open your Warband Bank. Set each character's gold target on the Targets tab.",

    -- Display
    SETTINGS_SORT_MODE      = "Sort Mode:",
    SETTINGS_SORT_ARROW     = "Arrow Buttons",
    SETTINGS_SORT_NUMBER    = "Number Input",
    SETTINGS_MINIMAP_BUTTON = "Minimap Button:",
    SETTINGS_YES            = "Yes",
    SETTINGS_NO             = "No",
    SETTINGS_UI_SCALE       = "UI Scale:",
    SETTINGS_THOUSANDS_LABEL  = "Thousands Separator:",
    SETTINGS_THOUSANDS_NONE   = "None",
    SETTINGS_THOUSANDS_COMMA  = "Comma",
    SETTINGS_THOUSANDS_PERIOD = "Period",
    SETTINGS_SHOW_STARTUP_MSG = "Changelog on Update:",

    -- Language
    SETTINGS_LANGUAGE_LABEL = "Language:",
    SETTINGS_LANGUAGE_DESC  = "Some languages may only be partially translated. Missing text falls back to English. Looking for volunteers to help localize the addon -- see the Support tab if you'd like to help!",
    SETTINGS_RELOAD_TITLE   = "Reload UI to apply the new language?",
    SETTINGS_RELOAD_ACCEPT  = "Reload Now",
    SETTINGS_RELOAD_CANCEL  = "Later",

    -- Category Names & Default Targets
    SETTINGS_CATEGORIES_HDR_NAME   = "Display Name",
    SETTINGS_CATEGORIES_HDR_TARGET = "Default Target",
    SETTINGS_CATEGORIES_NOTE       = "Name changes update immediately in dropdowns. Target applies when assigning a type.",
    GOLD_SUFFIX                    = "g",

    -- Guild Bank
    SETTINGS_HOMEGUILD_LABEL   = "Track Guild Bank For:",
    SETTINGS_HOMEGUILD_CURRENT = "Current Character's Guild",
    SETTINGS_HOMEGUILD_DESC    = "Only guilds a GM character has synced show up here. Alts elsewhere will display this guild's bank instead of their own.",

    -- Token Price
    SETTINGS_TOKEN_FREQ        = "Update Frequency:",
    SETTINGS_TOKEN_MINUTES_FORMAT = "%d minutes",
    SETTINGS_TOKEN_FLOATING    = "Floating Frame:",
    TOKEN_TOOLTIP_TITLE       = "WoW Token Price",
    TOKEN_TOOLTIP_HISTORY     = "Right-click for history",
    TOKEN_FLOATING_LABEL      = "WoW Token:",
    SETTINGS_TOKEN_ICON        = "Show token icon instead of label",
    SETTINGS_TOKEN_ARROW       = "Show price change arrow",
    SETTINGS_TOKEN_ALERTS      = "Enable price alerts (4 min cooldown)",
    SETTINGS_TOKEN_THRESHOLDS  = "Thresholds (gold):",
    SETTINGS_TOKEN_LOW         = "Low:",
    SETTINGS_TOKEN_HIGH        = "High:",
    SETTINGS_TOKEN_IMPORT      = "Import Legacy Token Data",
    SETTINGS_TOKEN_IMPORT_DESC = "Pulls history from the old standalone Token Price Display addon, if installed.",
    TOKEN_IMPORT_ERR_NOT_FOUND = "No legacy Token Price Display data found in this session. Make sure the old addon is enabled at the character select screen at least once before importing, then log in and try again.",
    TOKEN_IMPORT_ERR_EMPTY     = "Legacy data table found but it's empty.",
    TOKEN_ALERT_LOW  = "|cffff0000[Token Alert]: WoW Token price is %s! (Below threshold: %s)|r",
    TOKEN_ALERT_HIGH = "|cff00ff00[Token Alert]: WoW Token price is %s! (Above threshold: %s)|r",

    -- Danger Zone
    SETTINGS_DANGER_RESET_STATS   = "Reset All Statistics",
    SETTINGS_DANGER_RESET_STATS_DESC  = "Clears all-time totals and ledger history.",
    SETTINGS_DANGER_CLEAR_LEDGER  = "Clear Ledger History",
    SETTINGS_DANGER_CLEAR_LEDGER_DESC = "Removes all transaction history from the Ledger tab.",
    SETTINGS_DANGER_CLEAR_TOKEN   = "Clear Token History",
    SETTINGS_DANGER_CLEAR_TOKEN_DESC  = "Removes all stored Token price data points.",
    SETTINGS_DANGER_RESET_POS     = "Reset Window Position",

    -- Shared column headers (used on Overview, Targets, etc.)
    COL_CHARACTER = "Character",
    COL_REALM     = "Realm",
    COL_CURRENT   = "Current",
    COL_TARGET    = "Target",
    COL_TYPE      = "Type",
    COL_PAUSE     = "Pause",
    COL_DELETE    = "Delete",

    -- Overview tab
    OVERVIEW_CARD_WARBAND    = "Warband Bank",
    OVERVIEW_CARD_BAGS       = "Gold in Bags",
    OVERVIEW_CARD_WEEK       = "This Week",
    OVERVIEW_CARD_TOKEN      = "WoW Token",
    OVERVIEW_GUILD_LABEL     = "Guild Bank:",
    OVERVIEW_ACCOUNT_TOTAL_LABEL = "Account Total:",
    OVERVIEW_GUILD_NONE      = "None tracked",
    OVERVIEW_LOADING         = "Loading...",
    OVERVIEW_COL_DIFF        = "+/- Target",
    OTHER_REALM_SUFFIX       = " (*)",
    PAUSED_TAG               = "[P]",

    -- Targets tab
    TARGETS_PAUSE_TOOLTIP_TITLE  = "Pause Automation",
    TARGETS_PAUSE_TOOLTIP_DESC   = "Skip auto-deposit/withdraw for this character",
    TARGETS_DELETE_BUTTON        = "Delete",
    TARGETS_DELETE_TOOLTIP_TITLE = "Delete Character",
    TARGETS_DELETE_TOOLTIP_DESC  = "Remove from tracking |cFFFF0000(cannot be undone)|r",

    -- Ledger tab
    LEDGER_FILTER_ALL       = "All Characters",
    LEDGER_FILTER_LABEL     = "Filter:",
    COL_TIME                = "Time",
    COL_AMOUNT               = "Amount",
    COL_WARBAND_BANK          = "Warband Bank",
    COL_NOTE                = "Note",
    LEDGER_EMPTY_FILTERED   = "No transactions for this character.",
    LEDGER_EMPTY_ALL        = "No transactions yet.\nOpen your Warband Bank to record transfers.",
    LEDGER_UNKNOWN_CHAR     = "Unknown",
    LEDGER_TYPE_DEPOSIT     = "Deposit",
    LEDGER_TYPE_WITHDRAW    = "Withdraw",
    LEDGER_STATS_FORMAT     = "Dep: |cFF33FF33%s|r   Wdr: |cFFFF4444%s|r   Net: %s%s%s|r   Week: %s%s%s|r",

    -- Token Graph tab
    TOKEN_GRAPH_TITLE      = "WoW Token Price Graph",
    TOKEN_LOADING_STATS    = "Loading statistics...",
    TOKEN_NOT_ENOUGH_DATA  = "Not enough data yet...\nCheck back after a few price updates!",
    TOKEN_NO_HISTORY       = "No historical data available",
    TOKEN_STATS_FORMAT     = "High: %s%s|r | Low: %s%s|r | Points: %d",
    TOKEN_CURRENT_PREFIX   = "Current: ",
    TOKEN_CURRENT_PRICE_TOOLTIP = "Current Price",

    -- Token History tab
    COL_PRICE                = "Price",
    COL_CHANGE                = "Change",
    TOKENHIST_TOTAL_FORMAT   = "Total Entries: %d / 1008 (most recent first)",
    TOKENHIST_EMPTY          = "No price history yet.",
    TOKENHIST_NO_CHANGE      = "No change",

    -- Changelog tab
    CHANGELOG_VERSION_PREFIX = "Version ",
    CHANGELOG_TAG_NEW        = "New",
    CHANGELOG_TAG_FIX        = "Fix",
    CHANGELOG_TAG_IMPROVE    = "Improve",

    -- Guild Banks tab
    GUILDS_TITLE          = "Guild Banks",
    GUILDS_SUBTITLE       = "Every guild bank a character on this account has synced as Guild Master.",
    GUILDS_TOTAL_CARD     = "Total Across All Guilds",
    COL_GUILD             = "Guild",
    COL_GOLD              = "Gold",
    COL_LAST_SYNCED       = "Last Synced",
    GUILDS_HOME_TAG       = "(Home)",

    -- Support tab
    SUPPORT_TITLE          = "Support & Feedback",
    SUPPORT_SUBTITLE       = "Questions, bugs, or feature ideas -- reach out through either of these.",
    SUPPORT_DISCORD_DESC   = "Join the community, ask questions, get help.",
    SUPPORT_GITHUB_DESC    = "Report a bug or request a feature.",
    SUPPORT_COPY_HINT      = "Click, then Ctrl+C",
    SUPPORTERS_TITLE       = "Supporters",
    SUPPORTERS_THANKS      = "Thank you to everyone who supports this project!",
    SUPPORTERS_EMPTY       = "No supporters yet -- be the first!",

    -- Nav sidebar labels
    NAV_OVERVIEW     = "Overview",
    NAV_TARGETS      = "Targets",
    NAV_LEDGER       = "Ledger",
    NAV_TOKEN        = "Token Graph",
    NAV_TOKENHISTORY = "Token History",
    NAV_GUILDS       = "Guild Banks",
    NAV_SETTINGS     = "Settings",
    NAV_CHANGELOG    = "Changelog",
    NAV_SUPPORT      = "Support",
    NAV_GOLDHISTORY  = "Gold History",

    -- Minimap tooltip
    TOOLTIP_CLICK_OPEN = "Click: Open ",

    -- Gold History tab
    GOLDHIST_TITLE           = "Gold History",
    GOLDHIST_FILTER_WARBAND  = "Warband Bank Total",
    GOLDHIST_FILTER_ACCOUNT  = "Account Total",
    GOLDHIST_ACCOUNT_NOTE    = "(Warband Bank + all characters' current gold; history only goes back to when this started tracking)",
    GOLDHIST_NOT_ENOUGH_DATA = "Not enough data yet...\nCheck back after a few more transactions!",
    GOLDHIST_NOT_ENOUGH_ACCOUNT = "Not enough data yet...\nAccount Total snapshots build up over time -- check back later!",
    GOLDHIST_NO_HISTORY      = "No history available",
    GOLDHIST_STATS_FORMAT    = "High: %s%s|r | Low: %s%s|r | Points: %d",
    GOLDHIST_CURRENT_PREFIX  = "Current: ",
    GOLDHIST_CURRENT_TOOLTIP = "Current",
    GOLDHIST_CHAR_NET_NOTE   = "(net Warband Bank contribution, not on-hand gold)",

    -- Confirmation popups
    CONFIRM_CLEAR_TOKEN_TEXT  = "Clear all Token price history?\n\n|cFFFF0000This cannot be undone.|r",
    CONFIRM_RESET_STATS_TEXT  = "Reset all-time deposit/withdrawal statistics?\n\n|cFFFF0000This cannot be undone.|r",
    CONFIRM_CLEAR_LEDGER_TEXT = "Clear all Warband ledger history?\n\n|cFFFF0000This cannot be undone.|r",
    CONFIRM_DELETE_CHAR_TEXT  = "Delete %s from Warband Accountant?\n\n|cFFFF0000This cannot be undone!|r",
    STATS_RESET_MSG        = "Statistics reset.",
    CONFIRM_CANCEL          = "Cancel",
    CHAR_DELETED_MSG        = "Deleted: ",
    CHAR_DELETE_FAILED_MSG  = "Could not delete",

    -- Chat print messages
    MSG_PREFIX_GOLD    = "|cFFFFD700Warband Accountant:|r ",
    MSG_PREFIX_GREEN   = "|cFF00FF00Warband Accountant:|r ",
    MSG_PREFIX_RED     = "|cFFFF0000Warband Accountant:|r ",
    MSG_CATEGORY_UPDATED     = "Updated %s target to %s for %d character%s: %s",
    MSG_PLURAL_S              = "s",
    MSG_CATEGORY_SET_DEFAULT = "%s default target set to %s (no characters currently assigned).",
    MSG_TOKEN_IMPORT_COUNT   = "Imported/verified %d price history entries.",
    MSG_WINDOW_POS_RESET     = "Window position reset.",
    MSG_NO_LIBDBICON         = "LibDBIcon not found. Minimap button disabled.",

    -- Blizzard Interface Options stub panel
    STUB_SUBTITLE   = "All settings are inside the addon window.",
    STUB_OPEN_BTN   = "Open Warband Accountant",
    STUB_NOTE       = "Or type: /wba",

    -- Slash command messages
    SLASH_HELP_HEADER      = "Warband Accountant Commands:",
    SLASH_DELETE_SUCCESS    = "Deleted: ",
    SLASH_DELETE_FAILED     = "Could not delete",
    SLASH_DELETE_USAGE       = "Usage: /wba delete CharacterName",
    SLASH_UNKNOWN_COMMAND   = "Unknown command. Type /wba help",
    SLASH_HELP_TOGGLE     = "  /wba               - Toggle main window",
    SLASH_HELP_TARGETS    = "  /wba targets       - Open Targets tab",
    SLASH_HELP_LEDGER     = "  /wba ledger        - Open Ledger tab",
    SLASH_HELP_TOKEN      = "  /wba token         - Open Token History tab",
    SLASH_HELP_SETTINGS   = "  /wba settings      - Open Settings tab",
    SLASH_HELP_CHANGELOG  = "  /wba changelog     - Open Changelog tab",
    SLASH_HELP_SUPPORT    = "  /wba support       - Open Support tab (Discord/GitHub)",
    SLASH_HELP_TUTORIAL   = "  /wba tutorial      - Replay the first-run tutorial",
    SLASH_HELP_PROCESS    = "  /wba process       - Force process transfers",
    SLASH_HELP_WEEKLY     = "  /wba weekly        - Debug weekly income info",
    SLASH_HELP_DEBUGINFO  = "  /wba debuginfo     - Show region/realm/time diagnostics (for bug reports)",
    SLASH_HELP_DELETE     = "  /wba delete <name> - Delete a character",
    SLASH_HELP_RESETGM    = "  /wba resetgm       - Reset Guild Master cache",
    SLASH_HELP_CLEARGUILD = "  /wba clearguild    - Clear guild bank data",

    -- Tutorial tour
    TUTORIAL_STEP_OVERVIEW = "Welcome to Warband Accountant! This is your Overview: Warband Bank balance, gold in bags, and weekly income at a glance.",
    TUTORIAL_STEP_TARGETS  = "Head here now and set a gold target for this character. Anything above target auto-deposits to the Warband Bank; a shortfall auto-withdraws to top you up.",
    TUTORIAL_STEP_LEDGER   = "Every automatic and manual transfer is logged here, so you can always see where your gold went.",
    TUTORIAL_STEP_TOKEN    = "Track the WoW Token price over time right from this window. It's empty right now since there's no history yet -- it fills in as prices get checked over time, or you can import history from the old standalone Token Price Display addon if you used it.",
    TUTORIAL_STEP_SETTINGS = "Automation, category defaults, and more live here. You can replay this tour anytime with /wba tutorial.",

    -- Core transfer notifications/confirmations
    CORE_ACTION_SKIPPED_PAUSED = "skipped (paused)",
    CORE_ACTION_DEPOSITED      = "deposited",
    CORE_ACTION_WITHDRAWN      = "withdrawn",
    CORE_UNKNOWN_ERROR         = "Unknown error",
    CORE_ERROR_PREFIX          = "|cFFFF0000Warband Accountant Error:|r %s",
    CORE_CONFIRM_DEPOSIT_ACTION  = "Deposit",
    CORE_CONFIRM_WITHDRAW_ACTION = "Withdraw",
    CORE_CONFIRM_TO_BANK    = "to Warband Bank?",
    CORE_CONFIRM_FROM_BANK  = "from Warband Bank?",
    CORE_NOTE_AUTO_DEPOSIT  = "Auto-deposit excess",
    CORE_NOTE_AUTO_WITHDRAW = "Auto-withdraw deficit",
    CORE_NOTE_MANUAL_DEPOSIT  = "Manual deposit",
    CORE_NOTE_MANUAL_WITHDRAW = "Manual withdrawal",

    -- Startup chat message
    MSG_STARTUP_LOCALIZATION = "Looking for volunteers to help localize the addon into other languages -- see the Support tab if you'd like to help!",
    MSG_STARTUP_SUPPORT      = "Found a bug or have feedback? Visit the Support tab for the Discord and GitHub links.",

    -- Graph time ranges
    RANGE_LABEL   = "Range:",
    RANGE_24H     = "24 Hours",
    RANGE_3D      = "3 Days",
    RANGE_7D      = "7 Days",
    RANGE_30D     = "30 Days",
    RANGE_ALL     = "All",
    RANGE_NO_DATA = "No data in this time range yet.",

    -- Savings goal (Goals tab)
    NAV_GOALS              = "Goals",
    GOALS_TITLE            = "Savings Goal",
    GOALS_NONE             = "No savings goal set yet. You can set one in Settings.",
    GOALS_TOKEN_SUFFIX     = " (WoW Token)",
    GOALS_WAITING_PRICE    = "Waiting for the WoW Token price...",
    GOALS_MET              = "Goal met!",
    GOALS_GRAPH_LINE_LABEL = "Goal:",
    GOALS_GRAPH_NOT_ENOUGH = "Not enough Warband Bank history to graph yet.",
    GOALS_GRAPH_NOTE       = "Last 30 days of your Warband Bank. Green: your goal. Gold: your current pace. Blue: the pace you need. Red: your end date.",
    GOAL_MET_CHAT          = "Goal Met - Gratz on hitting your goal!",
    GOALS_GRAPH_DEADLINE_LABEL = "Ends",

    -- End date + pace
    GOAL_DATE_FORMAT     = "%b %d, %Y",
    GOAL_DEADLINE        = "Ends %s (%s)",
    GOAL_DEADLINE_PASSED = "Deadline passed (%s)",
    GOAL_LAST_DAY        = "last day",
    GOAL_ONE_DAY_LEFT    = "1 day left",
    GOAL_DAYS_LEFT       = "%d days left",
    GOAL_PER_DAY         = "%s per day",
    GOAL_PER_WEEK        = "%s per week",
    GOAL_NEED            = "Need %s to make it.",
    GOAL_ON_PACE         = "You're on pace.",
    GOAL_BEHIND_PACE     = "Behind pace, about %s short.",

    -- Finish estimates
    ETA_OFF_TRACK           = "Not on track yet (your Warband Bank isn't growing)",
    ETA_LESS_THAN_DAY       = "Less than a day to go",
    ETA_ONE_DAY             = "About 1 day to go",
    ETA_DAYS                = "About %d days to go",
    ETA_LESS_THAN_WEEK      = "Less than a week to go",
    ETA_ONE_WEEK            = "About 1 week to go",
    ETA_WEEKS               = "About %d weeks to go",
    ETA_SHORT_LESS_THAN_DAY = "<1 day",
    ETA_SHORT_ONE_DAY       = "~1 day",
    ETA_SHORT_DAYS          = "~%d days",

    -- Savings goal (Settings)
    SETTINGS_SECTION_GOAL      = "Savings Goal",
    SETTINGS_GOAL_NAME         = "Goal Name:",
    SETTINGS_GOAL_AMOUNT       = "Amount:",
    SETTINGS_GOAL_USE_TOKEN    = "Use WoW Token price",
    SETTINGS_GOAL_CLEAR        = "Clear Goal",
    SETTINGS_GOAL_ETA_UNIT     = "Show estimate in:",
    SETTINGS_GOAL_END_DATE     = "End Date:",
    SETTINGS_GOAL_DATE_ORDER   = "MDY",   -- dropdown order; e.g. "YMD" for year-first locales
    SETTINGS_GOAL_DATE_M       = "M",
    SETTINGS_GOAL_DATE_D       = "D",
    SETTINGS_GOAL_DATE_Y       = "Y",
    SETTINGS_GOAL_DATE_CLEAR   = "Clear",
    SETTINGS_GOAL_ETA_DAYS     = "Days",
    SETTINGS_GOAL_ETA_WEEKS    = "Weeks",
    SETTINGS_GOAL_DEFAULT_NAME = "My Goal",
    SETTINGS_GOAL_DESC         = "Progress counts your Warband Bank balance. Set an amount to start a goal, or clear the amount to remove it. Add an optional end date to see the pace you need. The Goals tab appears while a goal is set, and you'll get a chat message when you reach it.",

    -- Token affordability (Overview card)
    TOKEN_AFFORD_COUNT         = "Buys %d",
    TOKEN_AFFORD_NEXT          = "Next: %s",
    TOKEN_AFFORD_TOOLTIP_TITLE = "Token Affordability",
    TOKEN_AFFORD_TOOLTIP_BODY  = "How many WoW Tokens your spare gold (your Warband Bank) can buy right now, and roughly how long until you can afford the next one at your recent earning pace. Gold on your characters doesn't count, since that's their working capital.",

    -- Floating token frame
    SETTINGS_TOKEN_WEEKLY = "Show weekly income on floating frame",
    TOKEN_FLOATING_WEEKLY = "Weekly Profit:",

    -- Tutorial
    TUTORIAL_STEP_GOALS = "Set a savings goal in Settings and track it here. The green dashed line is your goal, and the gold dashed line shows where your Warband Bank is headed at your current pace.",
}
