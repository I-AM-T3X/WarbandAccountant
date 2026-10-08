local ADDON_NAME, WarbandAccountant = ...

-- -- Warband Accountant -- Localization System -----------------------------------
--
-- Every user-facing string lives in a keyed table per locale, populated by
-- Locale/<code>.lua files (which must load before this file). This file
-- builds the live lookup table WarbandAccountant.L by starting from enUS
-- (the base -- every key must exist there) and overlaying the selected
-- locale's translations on top, so a partially-translated locale never
-- shows a blank/nil string for a key nobody's translated yet.
--
-- TO ADD A NEW LANGUAGE:
--   1. Copy Locale/enUS.lua to Locale/<code>.lua (e.g. Locale/zhCN.lua)
--   2. Translate the values (leave the keys alone)
--   3. Add the file to WarbandAccountant.toc, ABOVE this file (Locale.lua)
--   4. Add a line to SUPPORTED_LOCALES below so it shows up in the
--      Settings language dropdown
-- ---------------------------------------------------------------------------------

WarbandAccountant.L = WarbandAccountant.L or {}

-- Locales with a real (even if partial) translation file. Shown in the
-- Settings language dropdown, in this order.
WarbandAccountant.SUPPORTED_LOCALES = {
    { code = "enUS", name = "English" },
    { code = "zhCN", name = "简体中文" },
}

-- Rebuilds WarbandAccountant.L for the given locale code. Safe to call
-- repeatedly (e.g. when the player changes the Settings dropdown).
function WarbandAccountant:ApplyLocale(code)
    local base   = self.LocaleData and self.LocaleData["enUS"] or {}
    local chosen = self.LocaleData and self.LocaleData[code] or {}

    wipe(self.L)
    for k, v in pairs(base) do self.L[k] = v end
    for k, v in pairs(chosen) do self.L[k] = v end

    self.activeLocale = code
end

-- Best-guess default using the client's own locale, applied immediately at
-- load time (before SavedVariables exist). Data:Init() re-applies the
-- player's saved choice once the DB is available, which overrides this if
-- they'd previously picked something different from their client locale.
WarbandAccountant:ApplyLocale(GetLocale())
