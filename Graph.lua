local ADDON_NAME, WarbandAccountant = ...

--[[
Warband Accountant -- Graph
Private time-series graph widget, built on the native Line API. Lives in the
addon's own namespace instead of the shared global library registry, so no
other addon can see, use, or replace it.

    local Graph = WarbandAccountant.Graph
    local graph = Graph:Create(parent, {
        style      = "step",          -- "line" (default) or "step"
        yUnit      = 10000,           -- divide raw values by this for the axis (copper -> gold)
        lineColor  = { 1, 0.82, 0, 1 },
        yFormatter = function(v) return Graph.Abbreviate(v) .. "g" end,
        onTooltip  = function(tooltip, point, prevPoint, isLast) ... end,
    })
    graph:SetPoint("TOPLEFT", 0, 0)
    graph:SetSize(600, 300)
    graph:SetData({ {x = timestamp, y = value}, ... }, "Not enough data")

    -- Optional third argument adds a view window and overlays:
    graph:SetData(points, "Not enough data", {
        xMin = time() - 7 * 86400,                 -- force the left edge
        xMax = time(),                             -- force the right edge
        refLine    = { y = goalCopper, label = "Goal" },          -- dashed horizontal line
        projection = { x1 = now, y1 = balance, x2 = eta, y2 = goalCopper },  -- dashed trend line
        extraLines = { { x1 =, y1 =, x2 =, y2 =, color = {...} } },        -- more dashed lines
        vLine      = { x = deadline, label = "Ends", color = {...} },     -- dashed vertical marker
    })

Points must be sorted by x (oldest first). Any extra fields on a point are
passed through untouched to onTooltip, so you can attach whatever context
you want to show on hover.

Features: time-proportional X axis with "nice" time ticks, nice-number Y
ticks, line or step rendering, gradient fill under the curve, hover
crosshair with nearest-point tooltip, per-pixel downsampling for large
datasets, and pooled regions so redraws never leak frames or textures.
]]

local lib = {}
WarbandAccountant.Graph = lib

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs
local log10, format = math.log10, string.format
local tinsert, tremove = table.insert, table.remove

local WHITE  = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local HOUR, DAY = 3600, 86400
local TIME_STEPS = {
    300, 600, 900, 1800,
    HOUR, 2 * HOUR, 3 * HOUR, 6 * HOUR, 12 * HOUR,
    DAY, 2 * DAY, 7 * DAY, 14 * DAY, 30 * DAY, 60 * DAY, 90 * DAY, 180 * DAY, 365 * DAY,
}

local DEFAULTS = {
    style           = "line",
    lineColor       = { 0.25, 0.85, 0.55, 1 },
    lineThickness   = 2,
    fill            = true,
    fillAlpha       = 0.35,
    background      = { 0.05, 0.05, 0.05, 0.55 },
    gridColor       = { 1, 1, 1, 0.08 },
    axisColor       = { 1, 1, 1, 0.25 },
    textColor       = { 0.65, 0.65, 0.65 },
    crosshairColor  = { 1, 1, 1, 0.35 },
    refLineColor    = { 1, 1, 1, 0.55 },
    projectionColor = { 1, 1, 1, 0.45 },
    padding         = { left = 72, right = 16, top = 16, bottom = 28 },
    yTicks          = 4,
    yUnit           = 1,
    minXLabelSpacing = 90,
    extendToNow     = false,
    showLastPoint   = true,
    emptyText       = "Not enough data",
    yFormatter      = nil,   -- function(valueInUnits) -> string
    xFormatter      = nil,   -- function(timestamp, tickStep, span) -> string
    onTooltip       = nil,   -- function(tooltip, point, prevPoint, isLast)
}

-- -- Helpers ------------------------------------------------------------------

local function CleanNumber(s)
    -- "262.50" -> "262.5", "100.00" -> "100"
    s = s:gsub("(%..-)0+$", "%1")
    return (s:gsub("%.$", ""))
end

-- Compact number formatter: 1234 -> "1.23k", 2500000 -> "2.5M"
function lib.Abbreviate(v)
    local a = abs(v)
    local sign = v < 0 and "-" or ""
    if a >= 1e9 then return sign .. CleanNumber(format("%.2f", a / 1e9)) .. "B" end
    if a >= 1e6 then return sign .. CleanNumber(format("%.2f", a / 1e6)) .. "M" end
    if a >= 1e3 then return sign .. CleanNumber(format("%.2f", a / 1e3)) .. "k" end
    return sign .. CleanNumber(format("%.2f", a))
end

-- Rounds a raw tick interval to a "nice" 1/2/5 x 10^n value.
local function NiceStep(range, count)
    if range <= 0 then return 1 end
    local raw = range / count
    local mag = 10 ^ floor(log10(raw))
    local n = raw / mag
    local nice
    if n < 1.5 then nice = 1 elseif n < 3 then nice = 2 elseif n < 7 then nice = 5 else nice = 10 end
    return nice * mag
end

-- Seconds to add to a UTC timestamp to get local wall-clock time, so time
-- ticks land on local midnight / round hours instead of UTC ones.
local function LocalOffset(t)
    return t - time(date("!*t", t))
end

local function DefaultXFormatter(ts, step, span)
    if step >= DAY then return date("%m/%d", ts) end
    if span >= DAY then return date("%m/%d %H:%M", ts) end
    return date("%H:%M", ts)
end

local function MergeOptions(base, overrides)
    local o = {}
    for k, v in pairs(base) do o[k] = v end
    if overrides then
        for k, v in pairs(overrides) do o[k] = v end
    end
    local pad = {}
    for k, v in pairs(base.padding) do pad[k] = v end
    if overrides and overrides.padding then
        for k, v in pairs(overrides.padding) do pad[k] = v end
    end
    o.padding = pad
    return o
end

-- -- Object pools -------------------------------------------------------------
-- WoW never frees frames or regions, so everything drawn per-refresh comes
-- from a pool and goes back into it on the next redraw.

local function NewPool(createFn)
    return { active = {}, free = {}, create = createFn }
end

local function Acquire(pool)
    local obj = tremove(pool.free) or pool.create()
    pool.active[#pool.active + 1] = obj
    obj:Show()
    return obj
end

local function ReleaseAll(pool)
    for i = #pool.active, 1, -1 do
        local obj = pool.active[i]
        obj:Hide()
        pool.free[#pool.free + 1] = obj
        pool.active[i] = nil
    end
end

-- -- Graph mixin --------------------------------------------------------------

local GraphMixin = {}

function lib:Create(parent, opts)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    for k, v in pairs(GraphMixin) do f[k] = v end
    f:Init(opts)
    return f
end

function GraphMixin:Init(opts)
    self.opts = MergeOptions(DEFAULTS, opts)

    self:SetBackdrop({ bgFile = WHITE })
    self:SetBackdropColor(unpack(self.opts.background))

    local graph = self
    self.linePool  = NewPool(function() return graph:CreateLine(nil, "ARTWORK", nil, 2) end)
    self.fillPool  = NewPool(function()
        local t = graph:CreateTexture(nil, "BORDER")
        t:SetTexture(WHITE)
        return t
    end)
    self.gridPool  = NewPool(function()
        local t = graph:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetTexture(WHITE)
        return t
    end)
    self.labelPool = NewPool(function()
        return graph:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end)

    self.emptyLabel = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.emptyLabel:SetPoint("CENTER")
    self.emptyLabel:Hide()

    -- Persistent "latest value" marker
    self.lastDotBorder = self:CreateTexture(nil, "OVERLAY", nil, 1)
    self.lastDotBorder:SetTexture(CIRCLE)
    self.lastDotBorder:SetSize(12, 12)
    self.lastDot = self:CreateTexture(nil, "OVERLAY", nil, 2)
    self.lastDot:SetTexture(CIRCLE)
    self.lastDot:SetSize(8, 8)

    -- Hover crosshair + highlighted point
    self.crosshair = self:CreateTexture(nil, "OVERLAY", nil, 0)
    self.crosshair:SetTexture(WHITE)
    self.crosshair:SetWidth(1)

    -- Mouse-motion-only overlay so the parent window can still be dragged
    -- from the graph area.
    local overlay = CreateFrame("Frame", nil, self)
    overlay.graph = self
    if overlay.SetMouseMotionEnabled and overlay.SetMouseClickEnabled then
        overlay:SetMouseMotionEnabled(true)
        overlay:SetMouseClickEnabled(false)
    else
        overlay:EnableMouse(true)
    end
    overlay:SetScript("OnEnter", function(o) o:SetScript("OnUpdate", o.graph.OnOverlayUpdate) end)
    overlay:SetScript("OnLeave", function(o)
        o:SetScript("OnUpdate", nil)
        o.graph:HideHover()
    end)
    self.overlay = overlay

    self.hoverDotBorder = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    self.hoverDotBorder:SetTexture(CIRCLE)
    self.hoverDotBorder:SetSize(14, 14)
    self.hoverDot = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    self.hoverDot:SetTexture(CIRCLE)
    self.hoverDot:SetSize(9, 9)

    self:ApplyColors()
    self:HideHover()
    self.lastDot:Hide()
    self.lastDotBorder:Hide()

    self:SetScript("OnHide", function(s) s:HideHover() end)
    self:SetScript("OnSizeChanged", function(s)
        if s.data then s:Redraw() end
    end)
end

function GraphMixin:ApplyColors()
    local o = self.opts
    local c = o.lineColor
    self.lastDot:SetVertexColor(c[1], c[2], c[3], 1)
    self.lastDotBorder:SetVertexColor(0, 0, 0, 0.8)
    self.hoverDot:SetVertexColor(c[1], c[2], c[3], 1)
    self.hoverDotBorder:SetVertexColor(1, 1, 1, 0.9)
    self.crosshair:SetVertexColor(unpack(o.crosshairColor))
    self.emptyLabel:SetTextColor(unpack(o.textColor))
end

-- Changes options after creation (e.g. switching between step and line).
function GraphMixin:SetOptions(opts)
    local merged = self.opts
    for k, v in pairs(opts) do
        if k == "padding" then
            for pk, pv in pairs(v) do merged.padding[pk] = pv end
        else
            merged[k] = v
        end
    end
    self:SetBackdropColor(unpack(merged.background))
    self:ApplyColors()
    if self.data then self:Redraw() end
end

-- points: { {x = timestamp, y = value, ...}, ... } sorted oldest-first.
-- emptyText (optional) replaces the default message shown when there are
-- fewer than two points.
-- view (optional): { xMin, xMax, refLine = {y, label, color}, projection = {x1, y1, x2, y2, color} }
-- Y values in refLine/projection use the same raw units as the points.
function GraphMixin:SetData(points, emptyText, view)
    self.data = points or {}
    self.emptyMessage = emptyText
    self.view = view
    self:Redraw()
end

function GraphMixin:Clear()
    self.data = nil
    self:Release()
    self.emptyLabel:Hide()
end

function GraphMixin:Release()
    ReleaseAll(self.linePool)
    ReleaseAll(self.fillPool)
    ReleaseAll(self.gridPool)
    ReleaseAll(self.labelPool)
    self.lastDot:Hide()
    self.lastDotBorder:Hide()
    self.screen = nil
    self:HideHover()
end

-- -- Drawing primitives -------------------------------------------------------

function GraphMixin:DrawLine(x1, y1, x2, y2, color, thickness)
    local o = self.opts
    local c = color or o.lineColor
    local line = Acquire(self.linePool)
    line:SetThickness(thickness or o.lineThickness)
    line:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    line:SetStartPoint("BOTTOMLEFT", self, x1, y1)
    line:SetEndPoint("BOTTOMLEFT", self, x2, y2)
end

-- Dashed line made of short pooled Line segments.
function GraphMixin:DrawDashed(x1, y1, x2, y2, color, thickness)
    local DASH, GAP = 6, 4
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local ux, uy = dx / len, dy / len
    local d = 0
    local guard = 0
    while d < len and guard < 400 do
        local e = min(d + DASH, len)
        self:DrawLine(x1 + ux * d, y1 + uy * d, x1 + ux * e, y1 + uy * e, color, thickness or 1.5)
        d = e + GAP
        guard = guard + 1
    end
end

-- Vertical fill strip from the baseline up to `top`. Alpha scales with the
-- strip's height so the whole fill reads as one smooth gradient rather than
-- each strip fading independently.
function GraphMixin:DrawFill(x, w, top)
    local o = self.opts
    local h = top - self.drawB
    if h <= 0.5 or w <= 0 then return end
    local c = o.lineColor
    local t = Acquire(self.fillPool)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, self.drawB)
    t:SetSize(w, h)
    local topAlpha = o.fillAlpha * (h / self.drawH)
    if t.SetGradient and CreateColor then
        t:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], topAlpha))
    else
        t:SetVertexColor(c[1], c[2], c[3], topAlpha * 0.5)
    end
end

function GraphMixin:DrawRect(x, y, w, h, color)
    local t = Acquire(self.gridPool)
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, y)
    t:SetSize(w, h)
    t:SetVertexColor(unpack(color))
    return t
end

function GraphMixin:DrawLabel(text, point, x, y, justify)
    local fs = Acquire(self.labelPool)
    fs:ClearAllPoints()
    fs:SetPoint(point, self, "BOTTOMLEFT", x, y)
    fs:SetJustifyH(justify or "CENTER")
    fs:SetText(text)
    fs:SetTextColor(unpack(self.opts.textColor))
    return fs
end

-- -- Main redraw ----------------------------------------------------------------

function GraphMixin:Redraw()
    self:Release()
    local o = self.opts
    local data = self.data

    if not data or #data < 2 then
        self.emptyLabel:SetText(self.emptyMessage or o.emptyText)
        self.emptyLabel:Show()
        self.overlay:Hide()
        return
    end
    self.emptyLabel:Hide()

    local W, H = self:GetWidth(), self:GetHeight()
    if not W or not H or W <= 0 or H <= 0 then return end

    local pad = o.padding
    local drawL, drawB = pad.left, pad.bottom
    local drawW = W - pad.left - pad.right
    local drawH = H - pad.top - pad.bottom
    if drawW <= 10 or drawH <= 10 then return end
    self.drawL, self.drawB, self.drawW, self.drawH = drawL, drawB, drawW, drawH

    local view = self.view or {}
    local ref, proj = view.refLine, view.projection
    local extras, vline = view.extraLines or {}, view.vLine

    -- X range (time)
    local xMin, xMax = data[1].x, data[#data].x
    local lastX = xMax
    -- Where the solid line/fill actually stops. "Extend to now" means to
    -- the current time, NOT to the right edge of the view: the Goals tab
    -- widens xMax for the look-ahead, and the held balance must not run
    -- flat through that future area.
    local endX = lastX
    if o.extendToNow then
        endX = max(lastX, time())
        xMax = max(xMax, endX)
    end
    if view.xMin then xMin = min(xMin, view.xMin) end
    if view.xMax then xMax = max(xMax, view.xMax) end
    if proj and proj.x2 then xMax = max(xMax, proj.x2) end
    for _, e in ipairs(extras) do if e.x2 then xMax = max(xMax, e.x2) end end
    if vline and vline.x then xMax = max(xMax, vline.x) end
    if xMax - xMin < 600 then
        local mid = (xMin + xMax) / 2
        xMin, xMax = mid - 300, mid + 300
    end
    local span = xMax - xMin

    -- Y range (in display units), snapped out to nice tick values
    local unit = o.yUnit
    local lo, hi = math.huge, -math.huge
    for i = 1, #data do
        local v = data[i].y / unit
        if v < lo then lo = v end
        if v > hi then hi = v end
    end
    -- Overlays must stay on screen too
    local function Include(raw)
        if not raw then return end
        local v = raw / unit
        if v < lo then lo = v end
        if v > hi then hi = v end
    end
    if ref then Include(ref.y) end
    if proj then Include(proj.y1); Include(proj.y2) end
    for _, e in ipairs(extras) do Include(e.y1); Include(e.y2) end
    if hi - lo < 1e-9 then
        local p = max(abs(hi) * 0.05, 1)
        lo, hi = lo - p, hi + p
    end
    local yStep = NiceStep(hi - lo, o.yTicks)
    local axisLo = floor(lo / yStep) * yStep
    local axisHi = ceil(hi / yStep) * yStep
    if axisHi - axisLo < yStep then axisHi = axisLo + yStep end

    local function XToPx(x) return drawL + (x - xMin) / span * drawW end
    local function YToPx(v) return drawB + ((v / unit) - axisLo) / (axisHi - axisLo) * drawH end

    -- Horizontal grid + Y labels
    local yFmt = o.yFormatter or lib.Abbreviate
    local v = axisLo
    local guard = 0
    while v <= axisHi + yStep * 0.001 and guard < 50 do
        local gy = drawB + (v - axisLo) / (axisHi - axisLo) * drawH
        self:DrawRect(drawL, gy, drawW, 1, (guard == 0) and o.axisColor or o.gridColor)
        self:DrawLabel(yFmt(v), "RIGHT", drawL - 6, gy, "RIGHT")
        v = v + yStep
        guard = guard + 1
    end

    -- Vertical grid + X (time) labels
    local maxLabels = max(2, floor(drawW / o.minXLabelSpacing))
    local tStep = TIME_STEPS[#TIME_STEPS]
    for _, s in ipairs(TIME_STEPS) do
        if span / s <= maxLabels then tStep = s; break end
    end
    local tz = LocalOffset(xMin)
    local t = ceil((xMin + tz) / tStep) * tStep - tz
    local xFmt = o.xFormatter or DefaultXFormatter
    guard = 0
    while t <= xMax and guard < 60 do
        local px = XToPx(t)
        self:DrawRect(px, drawB, 1, drawH, o.gridColor)
        self:DrawLabel(xFmt(t, tStep, span), "TOP", px, drawB - 4)
        t = t + tStep
        guard = guard + 1
    end

    -- Screen-space points, downsampled to at most 2 per SAMPLE_PX-wide column
    -- (more than that is invisible anyway and just costs line segments)
    local SAMPLE_PX = 2
    local screen = {}
    local isStep = (o.style == "step")
    if #data <= drawW / SAMPLE_PX then
        for i = 1, #data do
            local p = data[i]
            screen[i] = { px = XToPx(p.x), py = YToPx(p.y), point = p, index = i }
        end
    else
        local bucket
        local function Flush()
            if not bucket then return end
            local a, b = bucket.a, bucket.b
            if a.index > b.index then a, b = b, a end
            screen[#screen + 1] = a
            if b ~= a then screen[#screen + 1] = b end
        end
        for i = 1, #data do
            local p = data[i]
            local sp = { px = XToPx(p.x), py = YToPx(p.y), point = p, index = i }
            local col = floor(sp.px / SAMPLE_PX)
            if not bucket or bucket.col ~= col then
                Flush()
                bucket = { col = col, a = sp, b = sp }
            elseif isStep then
                -- keep first and last value in the column
                bucket.b = sp
            else
                -- keep min and max in the column so spikes survive
                if sp.py < bucket.a.py then bucket.a = sp end
                if sp.py > bucket.b.py then bucket.b = sp end
            end
        end
        Flush()
    end
    self.screen = screen

    local n = #screen
    local endPx = XToPx(endX)

    -- Fill under the curve
    if o.fill then
        if isStep then
            for i = 1, n do
                local x1 = screen[i].px
                local x2 = (i < n) and screen[i + 1].px or endPx
                self:DrawFill(x1, x2 - x1, screen[i].py)
            end
        else
            local STRIP = 2
            local seg = 1
            local x = floor(screen[1].px)
            local xEnd = screen[n].px
            while x < xEnd do
                local cx = x + STRIP / 2
                while seg < n - 1 and screen[seg + 1].px < cx do seg = seg + 1 end
                local a, b = screen[seg], screen[seg + 1]
                local frac = (b.px > a.px) and (cx - a.px) / (b.px - a.px) or 0
                frac = max(0, min(1, frac))
                local y = a.py + (b.py - a.py) * frac
                local w = min(STRIP, xEnd - x)
                self:DrawFill(x, w, y)
                x = x + STRIP
            end
        end
    end

    -- The line itself
    local half = o.lineThickness / 2
    for i = 1, n - 1 do
        local a, b = screen[i], screen[i + 1]
        if isStep then
            self:DrawLine(a.px, a.py, b.px, a.py)
            if abs(b.py - a.py) > 0.5 then
                local dir = (b.py > a.py) and 1 or -1
                self:DrawLine(b.px, a.py - dir * half, b.px, b.py + dir * half)
            end
        else
            self:DrawLine(a.px, a.py, b.px, b.py)
        end
    end
    if isStep and endPx > screen[n].px + 0.5 then
        self:DrawLine(screen[n].px, screen[n].py, endPx, screen[n].py)
    end

    -- Overlays: dashed goal line + dashed projection
    if ref and ref.y then
        local ry = YToPx(ref.y)
        local rc = ref.color or o.refLineColor
        self:DrawDashed(drawL, ry, drawL + drawW, ry, rc, 1.5)
        if ref.label then
            local fs = self:DrawLabel(ref.label, "BOTTOMRIGHT", drawL + drawW - 2, ry + 3, "RIGHT")
            fs:SetTextColor(rc[1], rc[2], rc[3])
        end
    end
    if proj and proj.x1 and proj.x2 then
        self:DrawDashed(XToPx(proj.x1), YToPx(proj.y1), XToPx(proj.x2), YToPx(proj.y2),
            proj.color or o.projectionColor, 1.5)
    end
    for _, e in ipairs(extras) do
        if e.x1 and e.x2 then
            self:DrawDashed(XToPx(e.x1), YToPx(e.y1), XToPx(e.x2), YToPx(e.y2),
                e.color or o.projectionColor, 1.5)
        end
    end
    if vline and vline.x then
        local vx = XToPx(vline.x)
        local vc = vline.color or o.refLineColor
        self:DrawDashed(vx, drawB, vx, drawB + drawH, vc, 1.5)
        if vline.label then
            local fs = self:DrawLabel(vline.label, "TOPRIGHT", vx - 3, drawB + drawH - 2, "RIGHT")
            fs:SetTextColor(vc[1], vc[2], vc[3])
        end
    end

    -- Latest-value marker
    if o.showLastPoint then
        local last = screen[n]
        self.lastDotBorder:ClearAllPoints()
        self.lastDotBorder:SetPoint("CENTER", self, "BOTTOMLEFT", last.px, last.py)
        self.lastDot:ClearAllPoints()
        self.lastDot:SetPoint("CENTER", self, "BOTTOMLEFT", last.px, last.py)
        self.lastDotBorder:Show()
        self.lastDot:Show()
    end

    -- Hover area covers the plot region
    self.overlay:ClearAllPoints()
    self.overlay:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", drawL, drawB)
    self.overlay:SetSize(drawW, drawH)
    self.overlay:Show()
end

-- -- Hover ------------------------------------------------------------------------

local function FindNearest(screen, x)
    local lo, hi = 1, #screen
    while hi - lo > 1 do
        local mid = floor((lo + hi) / 2)
        if screen[mid].px < x then lo = mid else hi = mid end
    end
    if abs(screen[lo].px - x) <= abs(screen[hi].px - x) then return lo end
    return hi
end

function GraphMixin.OnOverlayUpdate(overlay)
    local g = overlay.graph
    local screen = g.screen
    if not screen or #screen == 0 then return end
    local left = g:GetLeft()
    if not left then return end
    local cx = GetCursorPosition() / g:GetEffectiveScale()
    local idx = FindNearest(screen, cx - left)
    if idx ~= g.hoverIndex then
        g:ShowHover(idx)
    end
end

function GraphMixin:ShowHover(idx)
    local sp = self.screen and self.screen[idx]
    if not sp then return end
    self.hoverIndex = idx

    self.crosshair:ClearAllPoints()
    self.crosshair:SetPoint("BOTTOM", self, "BOTTOMLEFT", sp.px, self.drawB)
    self.crosshair:SetHeight(self.drawH)
    self.crosshair:Show()

    self.hoverDotBorder:ClearAllPoints()
    self.hoverDotBorder:SetPoint("CENTER", self, "BOTTOMLEFT", sp.px, sp.py)
    self.hoverDot:ClearAllPoints()
    self.hoverDot:SetPoint("CENTER", self, "BOTTOMLEFT", sp.px, sp.py)
    self.hoverDotBorder:Show()
    self.hoverDot:Show()

    local tt = GameTooltip
    tt:SetOwner(self.overlay, "ANCHOR_NONE")
    tt:ClearAllPoints()
    local onRight = sp.px < self.drawL + self.drawW / 2
    local high = sp.py > self.drawB + self.drawH * 0.6
    local anchor = (high and "TOP" or "BOTTOM") .. (onRight and "LEFT" or "RIGHT")
    tt:SetPoint(anchor, self, "BOTTOMLEFT", sp.px + (onRight and 14 or -14), sp.py + (high and -14 or 14))

    local prev = self.screen[idx - 1]
    local isLast = (idx == #self.screen)
    if self.opts.onTooltip then
        self.opts.onTooltip(tt, sp.point, prev and prev.point, isLast)
    else
        tt:AddLine(date("%m/%d %H:%M", sp.point.x))
        tt:AddLine(lib.Abbreviate(sp.point.y / self.opts.yUnit), 1, 1, 1)
    end
    tt:Show()
end

function GraphMixin:HideHover()
    self.hoverIndex = nil
    if self.crosshair then self.crosshair:Hide() end
    if self.hoverDot then self.hoverDot:Hide() end
    if self.hoverDotBorder then self.hoverDotBorder:Hide() end
    if self.overlay and GameTooltip:IsOwned(self.overlay) then
        GameTooltip:Hide()
    end
end
