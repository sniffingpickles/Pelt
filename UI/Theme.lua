--[[
    Pelt - theme
    Palette, fonts, rounded surfaces, shadows, glows and a small tween
    engine shared by the reminder card and the settings window.
]]

local _, P = ...

local UI = {}
P.UI = UI

local MEDIA = "Interface\\AddOns\\Pelt\\Media\\"
UI.tex = {
    white = "Interface\\Buttons\\WHITE8X8",
    bar = MEDIA .. "Bar",
    circle = MEDIA .. "Circle",
    ring = MEDIA .. "Ring",
    pill = MEDIA .. "Pill",
    round6 = MEDIA .. "Round6",
    round6Border = MEDIA .. "Round6Border",
    round12 = MEDIA .. "Round12",
    round12Border = MEDIA .. "Round12Border",
    shadow = MEDIA .. "Shadow",
    glow = MEDIA .. "Glow",
    check = MEDIA .. "Check",
    close = MEDIA .. "Close",
    chevron = MEDIA .. "Chevron",
    logo = MEDIA .. "Logo",
    glyph = MEDIA .. "PeltGlyph",
}

---------------------------------------------------------------------------
-- Palette
---------------------------------------------------------------------------

UI.palette = {
    bg          = { 0.047, 0.043, 0.039, 0.95 },
    surface     = { 0.082, 0.078, 0.071, 0.98 },
    surface2    = { 0.118, 0.110, 0.102, 1 },
    surface3    = { 0.161, 0.153, 0.141, 1 },
    track       = { 0.035, 0.031, 0.027, 0.9 },
    border      = { 0.200, 0.188, 0.176, 1 },
    edge        = { 1, 1, 1, 0.07 },
    text        = { 0.945, 0.933, 0.914, 1 },
    textDim     = { 0.639, 0.616, 0.584, 1 },
    textMute    = { 0.447, 0.427, 0.400, 1 },
    good        = { 0.365, 0.851, 0.525, 1 },
    warn        = { 1.000, 0.737, 0.282, 1 },
    danger      = { 0.969, 0.380, 0.357, 1 },
    skinning    = { 0.910, 0.635, 0.227, 1 },
    herbalism   = { 0.471, 0.827, 0.384, 1 },
    mining      = { 0.851, 0.596, 0.447, 1 },
    engineering = { 0.373, 0.737, 0.957, 1 },
}
UI.palette.accent = UI.palette.skinning
local PAL = UI.palette

-- Palette key or an {r, g, b, a} table.
function UI:Color(name)
    local c = type(name) == "table" and name or PAL[name] or PAL.text
    return c[1], c[2], c[3], c[4] or 1
end

function UI:Hex(name)
    local r, g, b = self:Color(name)
    return ("ff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

function UI:Colorize(name, text)
    return "|c" .. self:Hex(name) .. text .. "|r"
end

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------

-- EllesmereUI and SharedMedia packs register these; the game font otherwise.
local PREFERRED = { "Expressway", "Poppins", "FiraSans Medium", "Fira Sans Medium", "Barlow Condensed", "PT Sans Narrow" }
local LATIN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true }

local fontPath
function UI:FontPath()
    if fontPath then return fontPath end
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm and LATIN[GetLocale()] then
        for _, name in ipairs(PREFERRED) do
            if lsm:IsValid("font", name) then
                fontPath = lsm:Fetch("font", name)
                return fontPath
            end
        end
    end
    return STANDARD_TEXT_FONT
end

local fontStrings = setmetatable({}, { __mode = "k" })

local function ApplyFont(fs, spec)
    if not fs:SetFont(UI:FontPath(), spec.size, spec.flags or "") then
        fs:SetFont(STANDARD_TEXT_FONT, spec.size, spec.flags or "")
    end
    fs:SetShadowColor(0, 0, 0, spec.flags and 0.5 or 0.9)
    fs:SetShadowOffset(1, -1)
end

-- opts: size, flags, color, justify, wrap, layer
function UI:Text(parent, opts)
    opts = opts or {}
    local fs = parent:CreateFontString(nil, opts.layer or "OVERLAY")
    local spec = { size = opts.size or 12, flags = opts.flags }
    fontStrings[fs] = spec
    ApplyFont(fs, spec)
    fs:SetTextColor(self:Color(opts.color or "text"))
    fs:SetJustifyH(opts.justify or "LEFT")
    fs:SetWordWrap(opts.wrap == true)
    return fs
end

function UI:RefreshFonts()
    fontPath = nil
    for fs, spec in pairs(fontStrings) do ApplyFont(fs, spec) end
end

-- SharedMedia fonts can register after our text was drawn.
P:Listen("READY", function()
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not (lsm and lsm.RegisterCallback) then
        UI:RefreshFonts()
        return
    end
    lsm.RegisterCallback(UI, "LibSharedMedia_Registered", function(_, kind)
        if kind == "font" then C_Timer.After(0.2, function() UI:RefreshFonts() end) end
    end)
    UI:RefreshFonts()
end)

---------------------------------------------------------------------------
-- Surfaces
---------------------------------------------------------------------------

local probe = UIParent:CreateTexture()
UI.canSlice = probe.SetTextureSliceMargins ~= nil
probe:Hide()

local SLICE = {
    [6] = { fill = "round6", border = "round6Border", margin = 8 },
    [12] = { fill = "round12", border = "round12Border", margin = 14 },
    pill = { fill = "pill", margin = 8 },
}

local function Slice(tex, margin)
    tex:SetTextureSliceMargins(margin, margin, margin, margin)
    if tex.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
        tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
end
UI.Slice = Slice

-- A filled shape on its own texture: radius 6 | 12 | "pill" | nil (square).
function UI:Fill(parent, radius, color, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    local spec = radius and self.canSlice and SLICE[radius]
    if spec then
        t:SetTexture(self.tex[spec.fill])
        Slice(t, spec.margin)
    else
        t:SetTexture(self.tex.white)
    end
    t:SetVertexColor(self:Color(color or "surface"))
    return t
end

-- Background, 1px rounded edge and optional shadow on `frame`.
-- opts: radius (6 | 12), color, border (color or false), shadow
function UI:Surface(frame, opts)
    opts = opts or {}
    local s = {}
    local spec = self.canSlice and SLICE[opts.radius or 6]
    s.bg = self:Fill(frame, opts.radius or 6, opts.color or "surface", "BACKGROUND", -7)
    s.bg:SetAllPoints()
    if opts.border ~= false then
        s.ring = frame:CreateTexture(nil, "BORDER", nil, 6)
        s.ring:SetAllPoints()
        if spec then
            s.ring:SetTexture(self.tex[spec.border])
            Slice(s.ring, spec.margin)
        else
            s.ring:SetColorTexture(1, 1, 1, 1)
            s.ring:SetPoint("TOPLEFT", -1, 1)
            s.ring:SetPoint("BOTTOMRIGHT", 1, -1)
            s.ring:SetDrawLayer("BACKGROUND", -8)
        end
        s.ring:SetVertexColor(self:Color(opts.border or "edge"))
    end
    if opts.shadow then self:Shadow(frame) end
    frame.__peltSurface = s
    return s
end

function UI:SetSurface(frame, bg, border)
    local s = frame.__peltSurface
    if not s then return end
    if bg then s.bg:SetVertexColor(self:Color(bg)) end
    if border and s.ring then s.ring:SetVertexColor(self:Color(border)) end
end

function UI:Shadow(frame, spread)
    spread = spread or 12
    local sh = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    if self.canSlice then
        sh:SetTexture(self.tex.shadow)
        Slice(sh, 22)
    else
        sh:SetColorTexture(0, 0, 0, 0.35)
        spread = 2
    end
    sh:SetPoint("TOPLEFT", -spread, spread)
    sh:SetPoint("BOTTOMRIGHT", spread, -spread)
    sh:SetVertexColor(0, 0, 0, 0.8)
    return sh
end

-- Soft coloured halo behind a frame; fade it with SetAlpha.
function UI:Glow(frame, color)
    local g = CreateFrame("Frame", nil, frame)
    g:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    g:SetPoint("TOPLEFT", -16, 16)
    g:SetPoint("BOTTOMRIGHT", 16, -16)
    local t = g:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    if self.canSlice then
        t:SetTexture(self.tex.glow)
        Slice(t, 24)
    else
        t:SetColorTexture(1, 1, 1, 0.12)
    end
    t:SetBlendMode("ADD")
    t:SetVertexColor(self:Color(color or "accent"))
    g.tex = t
    g:SetAlpha(0)
    return g
end

-- Round, cropped icon with a coloured ring.
function UI:Icon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 2, -2)
    f.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if f.CreateMaskTexture then
        local mask = f:CreateMaskTexture()
        mask:SetTexture(self.tex.circle, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(f.icon)
        f.icon:AddMaskTexture(mask)
    end
    f.back = f:CreateTexture(nil, "BACKGROUND")
    f.back:SetTexture(self.tex.circle)
    f.back:SetAllPoints()
    f.back:SetVertexColor(self:Color("track"))
    f.ring = f:CreateTexture(nil, "OVERLAY")
    f.ring:SetTexture(self.tex.ring)
    f.ring:SetAllPoints()
    return f
end

---------------------------------------------------------------------------
-- Tweens
---------------------------------------------------------------------------

function UI.EaseOut(p) return 1 - (1 - p) ^ 3 end
function UI.EaseInOut(p) return p < 0.5 and 4 * p ^ 3 or 1 - (-2 * p + 2) ^ 3 / 2 end

local tweens = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, dt)
    local finished
    for key, tw in pairs(tweens) do
        tw.t = tw.t + dt
        local p = math.min(1, tw.t / tw.dur)
        tw.fn(tw.ease(p), p)
        if p >= 1 then
            tweens[key] = nil
            finished = finished or {}
            finished[#finished + 1] = tw.done
        end
    end
    if finished then
        for _, done in ipairs(finished) do done() end
    end
    if not next(tweens) then driver:Hide() end
end)

-- Runs fn(eased, raw) every frame for `dur` seconds. A new tween with the
-- same key replaces the old one.
function UI:Tween(key, dur, fn, done, ease)
    tweens[key] = { t = 0, dur = math.max(dur, 0.001), fn = fn, done = done or function() end, ease = ease or UI.EaseOut }
    driver:Show()
end

function UI:StopTween(key)
    tweens[key] = nil
end

function UI:FadeTo(frame, alpha, dur, done)
    local from = frame:GetAlpha()
    self:Tween(frame, dur or 0.2, function(e) frame:SetAlpha(from + (alpha - from) * e) end, done)
end
