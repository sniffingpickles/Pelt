--[[
    Pelt - widgets
    Buttons, switches, sliders and profession tiles for the settings window.
]]

local _, P = ...
local UI = P.UI

local function Hover(frame, on)
    if frame.hover then frame.hover:SetShown(on) end
end

-- kind: "primary" | "secondary" | "ghost"
function UI:Button(parent, label, kind, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 110, h or 28)
    local primary = kind == "primary"
    UI:Surface(b, { radius = 6, color = primary and "accent" or (kind == "ghost" and { 0, 0, 0, 0 } or "surface2"),
        border = primary and false or "border" })
    b.hover = UI:Fill(b, 6, { 1, 1, 1, 0.06 }, "HIGHLIGHT")
    b.hover:SetAllPoints()
    b.text = UI:Text(b, { size = 12, justify = "CENTER", color = primary and { 0.09, 0.06, 0.03, 1 } or "text" })
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 0, -1) end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
    return b
end

-- Section title with a hairline under it.
function UI:Header(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(26)
    f.text = UI:Text(f, { size = 10, color = "textMute" })
    f.text:SetPoint("BOTTOMLEFT", 0, 8)
    f.text:SetText(text:upper())
    f.line = UI:Fill(f, nil, { 1, 1, 1, 0.06 }, "ARTWORK")
    f.line:SetPoint("BOTTOMLEFT")
    f.line:SetPoint("BOTTOMRIGHT")
    f.line:SetHeight(1)
    return f
end

---------------------------------------------------------------------------
-- Rows: label on the left, control on the right
---------------------------------------------------------------------------

local function Row(parent, label, desc, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height or 34)
    row.hover = UI:Fill(row, 6, { 1, 1, 1, 0.03 }, "BACKGROUND")
    row.hover:SetPoint("TOPLEFT", -8, 0)
    row.hover:SetPoint("BOTTOMRIGHT", 8, 0)
    row.hover:Hide()
    row.label = UI:Text(row, { size = 12 })
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetText(label)
    row.desc = desc
    row:SetScript("OnEnter", function(self)
        Hover(self, true)
        if self.desc then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label, 1, 1, 1)
            GameTooltip:AddLine(self.desc, 0.75, 0.73, 0.70, true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        Hover(self, false)
        GameTooltip:Hide()
    end)
    return row
end
UI.Row = Row

-- Pill switch. get() -> bool, set(bool).
function UI:Switch(parent, label, desc, get, set)
    local row = Row(parent, label, desc)
    local track = CreateFrame("Frame", nil, row)
    track:SetSize(32, 16)
    track:SetPoint("RIGHT", 0, 0)
    track.bg = UI:Fill(track, "pill", "surface3", "ARTWORK")
    track.bg:SetAllPoints()
    track.knob = track:CreateTexture(nil, "OVERLAY")
    track.knob:SetTexture(UI.tex.circle)
    track.knob:SetSize(12, 12)
    row.track = track

    function row:Update(animate)
        local on = get() == true
        local from = self.pos or (on and 1 or 0)
        local to = on and 1 or 0
        local function paint(x)
            self.pos = x
            track.knob:ClearAllPoints()
            track.knob:SetPoint("LEFT", 2 + 16 * x, 0)
            local r1, g1, b1 = UI:Color("surface3")
            local r2, g2, b2 = UI:Color("accent")
            track.bg:SetVertexColor(r1 + (r2 - r1) * x, g1 + (g2 - g1) * x, b1 + (b2 - b1) * x)
            track.knob:SetVertexColor(1, 1, 1, 0.75 + 0.25 * x)
        end
        if animate then
            UI:Tween(track, 0.16, function(e) paint(from + (to - from) * e) end)
        else
            paint(to)
        end
    end
    row:SetScript("OnClick", function(self)
        set(not get())
        self:Update(true)
    end)
    row:Update()
    return row
end

-- Slider with the value printed on the right. fmt(value) -> text.
function UI:Slider(parent, label, desc, min, max, step, get, set, fmt)
    local row = Row(parent, label, desc, 46)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", 0, -6)
    row.value = UI:Text(row, { size = 12, color = "accent", justify = "RIGHT" })
    row.value:SetPoint("TOPRIGHT", 0, -6)

    local s = CreateFrame("Slider", nil, row)
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(16)
    s:SetPoint("BOTTOMLEFT", 0, 4)
    s:SetPoint("BOTTOMRIGHT", 0, 4)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:SetThumbTexture(UI.tex.circle)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(14, 14)
    thumb:SetVertexColor(1, 1, 1)
    s.track = UI:Fill(s, "pill", "surface3", "BACKGROUND")
    s.track:SetPoint("LEFT")
    s.track:SetPoint("RIGHT")
    s.track:SetHeight(4)
    s.fill = UI:Fill(s, nil, "accent", "BORDER")
    s.fill:SetPoint("LEFT", s.track, "LEFT")
    s.fill:SetHeight(4)
    row.slider = s

    local function Paint(v)
        row.value:SetText(fmt and fmt(v) or tostring(v))
        local width = s:GetWidth()
        s.fill:SetWidth(math.max(1, (width - 14) * (v - min) / (max - min) + 7))
    end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        Paint(v)
        if v ~= get() then set(v) end
    end)
    s:SetScript("OnSizeChanged", function() Paint(get()) end)
    function row:Update()
        s:SetValue(get())
        Paint(get())
    end
    row:Update()
    return row
end

-- Profession tile: icon, name, your skill, and a check when it's on.
function UI:ProfTile(parent, key, get, set)
    local info = P.Profs.info[key]
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(140, 46)
    UI:Surface(t, { radius = 6, color = "surface2", border = "border" })
    t.hover = UI:Fill(t, 6, { 1, 1, 1, 0.04 }, "HIGHLIGHT")
    t.hover:SetAllPoints()
    t.icon = UI:Icon(t, 28)
    t.icon:SetPoint("LEFT", 9, 0)
    t.icon.icon:SetTexture(info.icon)
    t.icon.ring:SetVertexColor(UI:Color(info.color))
    t.name = UI:Text(t, { size = 12 })
    t.name:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 8, -1)
    t.sub = UI:Text(t, { size = 10, color = "textMute" })
    t.sub:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 8, 1)
    t.check = t:CreateTexture(nil, "OVERLAY")
    t.check:SetTexture(UI.tex.check)
    t.check:SetSize(14, 14)
    t.check:SetPoint("TOPRIGHT", -6, -6)

    function t:Update()
        local on = get()
        local has = P.Profs:Has(key)
        self.name:SetText(P.Profs:Name(key))
        local rank, max = P.Profs:Rank(key), P.Profs:Max(key)
        if not has then
            self.sub:SetText("Not learned")
        elseif rank and max then
            self.sub:SetText(("%d / %d"):format(rank, max))
        else
            self.sub:SetText("Learned")
        end
        self.check:SetShown(on)
        self.check:SetVertexColor(UI:Color(info.color))
        local r, g, b = UI:Color(info.color)
        UI:SetSurface(self, nil, on and { r, g, b, 0.55 } or "border")
        self.icon:SetAlpha(on and has and 1 or 0.45)
        self.name:SetTextColor(UI:Color(on and "text" or "textDim"))
    end
    t:SetScript("OnClick", function(self)
        set(not get())
        self:Update()
    end)
    t:Update()
    return t
end
