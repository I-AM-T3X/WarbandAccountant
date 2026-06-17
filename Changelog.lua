local ADDON_NAME, WarbandAccountant = ...

-- ── Warband Accountant — Changelog Data ──────────────────────────────────────
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
-- ─────────────────────────────────────────────────────────────────────────────

-- Ordered newest-first. Add new version strings here when releasing.
WarbandAccountant.ChangelogVersions = {
    "1.0.7",
    "1.0.6",
    "1.0.5",
    "1.0.4",
}

WarbandAccountant.ChangelogIcon = "Interface\\AddOns\\WarbandAccountant\\Textures\\minimap"

-- Keyed by version string. Each value is a list of entry tables.
WarbandAccountant.Changelog = {

    ["1.0.7"] = {
        { tag="Fix", text="Weekly Income displaying incorrectly" },
        { tag=nil,   text="Reset timestamp calculation was using UTC date math that doesn't work correctly in WoW's Lua environment. Now uses a hardcoded known reset anchor with 7-day stepping." },
        { tag="Fix", text="Negative gold values displaying garbled output" },
        { tag=nil,   text="Lua's modulo operator on negative numbers returns unexpected results. Negative gold amounts (e.g. a weekly loss) now display correctly with a minus sign." },
    },

    ["1.0.6"] = {
        { tag="Fix", text="Weekly Income Reset Timestamp" },
        { tag=nil,   text="Fixed an issue where the weekly income counter was calculating the reset time incorrectly, causing it to show a much lower number than expected." },
        { tag=nil,   text="The reset now targets the exact server reset time per region — NA: Tuesday 9AM PDT, EU: Wednesday 8AM CEST, KR/TW: Thursday 10AM KST." },
    },

    ["1.0.5"] = {
        { tag="New",     text="Weekly Income Tracking" },
        { tag=nil,       text="Tracks net gold earned across all characters since your weekly reset." },
        { tag=nil,       text="Resets automatically per region — NA: Tuesday, EU: Wednesday, KR/TW: Thursday." },
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
        { tag="Improve", text="TOC updated for patch 12.0.7 — Midnight: Revelations." },
    },

    ["1.0.4"] = {
        { tag="New", text="Character Deletion" },
        { tag=nil,   text="Delete old or renamed characters from the Targets tab or via /wba delete CharacterName." },
    },

}
