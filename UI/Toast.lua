--[[
    Pelt - reminder card
    One card for the newest corpse you still have to skin, with a badge for
    the rest. It slides in, shakes when you walk off, ticks green when you
    skin it and drains a thin bar toward "missed".
]]

local _, P = ...
local UI, Profs = P.UI, P.Profs

local Toast = {}
P.Toast = Toast

local W, H = 300, 68
local HOLD = { done = 1.6, missed = 2.6, gone = 0, dismissed = 0 }

local anchor, card, banner

local function Info(c)
    return Profs.info[c.prof or "skinning"]
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function BuildCard()
    anchor = CreateFrame("Button", "PeltAnchor", UIParent)
    anchor:SetSize(W, H)
    anchor:SetFrameStrata("HIGH")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:EnableMouse(false)
    anchor:RegisterForDrag("LeftButton")
    anchor:RegisterForClicks("RightButtonUp")

    anchor.outline = UI:Fill(anchor, 6, { 1, 1, 1, 0.05 }, "BACKGROUND")
    anchor.outline:SetPoint("TOPLEFT", -6, 6)
    anchor.outline:SetPoint("BOTTOMRIGHT", 6, -6)
    anchor.outline:Hide()
    anchor.hint = UI:Text(anchor, { size = 11, color = "accent", justify = "CENTER" })
    anchor.hint:SetPoint("BOTTOM", anchor, "TOP", 0, 10)
    anchor.hint:SetText("Drag to move  ·  right-click to reset  ·  /pelt move to lock")
    anchor.hint:Hide()

    card = CreateFrame("Frame", "PeltCard", anchor)
    card:SetSize(W, H)
    card:SetPoint("CENTER")
    card:SetAlpha(0)
    card:Hide()
    UI:Surface(card, { radius = 12, color = "bg", border = "edge", shadow = true })
    card.glow = UI:Glow(card)

    -- thin accent stripe on the left edge
    card.stripe = UI:Fill(card, nil, "accent", "ARTWORK")
    card.stripe:SetPoint("TOPLEFT", 0, -16)
    card.stripe:SetPoint("BOTTOMLEFT", 0, 16)
    card.stripe:SetWidth(2)

    card.icon = UI:Icon(card, 42)
    card.icon:SetPoint("LEFT", 14, 1)

    -- tick that covers the icon once it's skinned
    card.tick = CreateFrame("Frame", nil, card)
    card.tick:SetAllPoints(card.icon)
    card.tick:SetFrameLevel(card.icon:GetFrameLevel() + 2)
    card.tick.bg = card.tick:CreateTexture(nil, "ARTWORK")
    card.tick.bg:SetTexture(UI.tex.circle)
    card.tick.bg:SetAllPoints()
    card.tick.mark = card.tick:CreateTexture(nil, "OVERLAY")
    card.tick.mark:SetTexture(UI.tex.check)
    card.tick.mark:SetPoint("CENTER")
    card.tick.mark:SetSize(26, 26)
    card.tick:Hide()

    card.eyebrow = UI:Text(card, { size = 10, flags = "", color = "accent" })
    card.eyebrow:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 12, 1)

    card.title = UI:Text(card, { size = 15 })
    card.title:SetPoint("TOPLEFT", card.eyebrow, "BOTTOMLEFT", 0, -3)
    card.title:SetPoint("RIGHT", card, "RIGHT", -40, 0)

    card.meta = UI:Text(card, { size = 11, color = "textDim" })
    card.meta:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
    card.meta:SetPoint("RIGHT", card, "RIGHT", -14, 0)

    -- "+2" when more corpses are waiting
    card.badge = CreateFrame("Frame", nil, card)
    card.badge:SetSize(26, 16)
    card.badge:SetPoint("TOPRIGHT", -34, -11)
    card.badge.bg = UI:Fill(card.badge, "pill", "surface3", "ARTWORK")
    card.badge.bg:SetAllPoints()
    card.badge.text = UI:Text(card.badge, { size = 10, justify = "CENTER" })
    card.badge.text:SetPoint("CENTER", 0, 0)
    card.badge:Hide()

    -- The card lets clicks through to the world; only this button takes the mouse.
    card.close = CreateFrame("Button", nil, card)
    card.close:SetSize(20, 20)
    card.close:SetPoint("TOPRIGHT", -9, -9)
    card.close:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card.close.tex = card.close:CreateTexture(nil, "ARTWORK")
    card.close.tex:SetTexture(UI.tex.close)
    card.close.tex:SetAllPoints()
    card.close.tex:SetVertexColor(UI:Color("textMute"))
    card.close:SetScript("OnEnter", function(self)
        self.tex:SetVertexColor(UI:Color("text"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Skip this corpse")
        GameTooltip:AddLine("Pelt stops reminding you about it.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    card.close:SetScript("OnLeave", function(self)
        self.tex:SetVertexColor(UI:Color("textMute"))
        GameTooltip:Hide()
    end)
    card.close:SetScript("OnClick", function()
        if Toast.demo then
            Toast:EndDemo()
        elseif Toast.shown then
            P.Tracker:Dismiss(Toast.shown)
        end
    end)

    -- time left before the corpse counts as missed
    card.track = UI:Fill(card, nil, { 1, 1, 1, 0.06 }, "ARTWORK")
    card.track:SetPoint("BOTTOMLEFT", 14, 7)
    card.track:SetPoint("BOTTOMRIGHT", -14, 7)
    card.track:SetHeight(2)
    card.fill = card:CreateTexture(nil, "ARTWORK", nil, 1)
    card.fill:SetTexture(UI.tex.white)
    card.fill:SetPoint("TOPLEFT", card.track)
    card.fill:SetPoint("BOTTOMLEFT", card.track)
    card.fill:SetWidth(1)

    card:SetScript("OnUpdate", function() Toast:OnUpdate() end)
end

local function BuildBanner()
    banner = CreateFrame("Frame", "PeltBanner", UIParent)
    banner:SetSize(600, 90)
    banner:SetPoint("CENTER", 0, 170)
    banner:SetFrameStrata("HIGH")
    banner:Hide()
    banner.glyph = banner:CreateTexture(nil, "ARTWORK")
    banner.glyph:SetTexture(UI.tex.glyph)
    banner.glyph:SetSize(30, 30)
    banner.glyph:SetPoint("TOP")
    banner.title = UI:Text(banner, { size = 30, flags = "OUTLINE", justify = "CENTER" })
    banner.title:SetPoint("TOP", banner.glyph, "BOTTOM", 0, -6)
    banner.sub = UI:Text(banner, { size = 13, color = "textDim", justify = "CENTER" })
    banner.sub:SetPoint("TOP", banner.title, "BOTTOM", 0, -6)
end

function Toast:Layout()
    local pos = P.db.position
    anchor:ClearAllPoints()
    anchor:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3])
    anchor:SetScale(P.db.scale or 1)
    banner:SetScale(P.db.scale or 1)
end

---------------------------------------------------------------------------
-- Painting
---------------------------------------------------------------------------

local function SetAccent(colorKey)
    local r, g, b = UI:Color(colorKey)
    card.stripe:SetVertexColor(r, g, b)
    card.icon.ring:SetVertexColor(r, g, b)
    card.eyebrow:SetTextColor(r, g, b)
    card.fill:SetVertexColor(r, g, b)
    card.glow.tex:SetVertexColor(r, g, b)
end

local function SkillText(c)
    local rank = Profs:Rank(c.prof)
    if not c.need then
        return c.level and ("Level %d"):format(c.level) or ""
    end
    local need = ("%s %d"):format(Profs:Name(c.prof), c.need)
    if rank then
        local ok = rank >= c.need
        need = need .. "  ·  " .. UI:Colorize(ok and "good" or "danger", ("you %d"):format(rank))
    end
    return ("Level %d  ·  %s"):format(c.level, need)
end

local function ItemsText(items)
    if not items or #items == 0 then return nil end
    local parts = {}
    for i = 1, math.min(2, #items) do
        parts[#parts + 1] = ("%s |cff8f8a84x%d|r"):format(items[i].name, items[i].count)
    end
    return table.concat(parts, "  ·  ")
end

function Toast:PaintPending(c)
    local info = Info(c)
    SetAccent(info.color)
    card.icon.icon:SetTexture(info.icon)
    card.icon.icon:SetDesaturated(false)
    card.tick:Hide()
    card.title:SetText(c.name or "Corpse")
    card.title:SetTextColor(UI:Color("text"))
    -- "mouseover" or "softinteract" while you point at this corpse
    local pointed = not P.inCombat and P.Tracker.hover == c and P.Tracker.hoverUnit
    if P.inCombat then
        card.eyebrow:SetText("AFTER THE FIGHT")
        card.eyebrow:SetTextColor(UI:Color("textDim"))
    elseif c.casting then
        card.eyebrow:SetText(info.casting:upper())
    elseif pointed then
        card.eyebrow:SetText((pointed == "softinteract" and "In reach" or info.hover):upper())
    elseif c.nagged then
        card.eyebrow:SetText("DON'T FORGET IT")
        card.eyebrow:SetTextColor(UI:Color("warn"))
    else
        card.eyebrow:SetText(info.verb:upper())
    end
    self:SetGlow(pointed and 0.35 or 0)
    card.meta:SetText(SkillText(c))
    local extra = #P.Tracker.pending - 1
    card.badge:SetShown(extra > 0)
    card.badge.text:SetText("+" .. extra)
    card.track:Show()
    card.fill:Show()
end

function Toast:PaintResolved(c, how, items)
    local info = Info(c)
    card.badge:Hide()
    card.track:Hide()
    card.fill:Hide()
    card.icon.icon:SetTexture(info.icon)
    card.title:SetText(c.name or "Corpse")
    self:SetGlow(0)
    if how == "done" then
        SetAccent("good")
        card.tick:Show()
        card.tick.bg:SetVertexColor(UI:Color("good"))
        card.tick.mark:SetVertexColor(0.05, 0.05, 0.05)
        card.eyebrow:SetText(info.done:upper())
        card.title:SetTextColor(UI:Color("text"))
        local parts = {}
        if c.gain then
            parts[1] = UI:Colorize("good", ("%s %d  +%d"):format(Profs:Name(c.prof or "skinning"), c.rankNow, c.gain))
        end
        parts[#parts + 1] = ItemsText(items)
        if P.stats.streak >= 3 then
            parts[#parts + 1] = UI:Colorize("good", ("streak %d"):format(P.stats.streak))
        end
        card.meta:SetText(table.concat(parts, "  ·  "))
    else
        SetAccent("danger")
        card.tick:Hide()
        card.icon.icon:SetDesaturated(true)
        card.eyebrow:SetText("MISSED")
        card.title:SetTextColor(UI:Color("textDim"))
        card.meta:SetText("Left behind. Mouse over it again to bring it back.")
    end
end

---------------------------------------------------------------------------
-- Motion
---------------------------------------------------------------------------

local function Place(x, y)
    card:ClearAllPoints()
    card:SetPoint("CENTER", anchor, "CENTER", x or 0, y or 0)
end

local function Opacity()
    return P.inCombat and not Toast.resolving and 0.55 or 1
end

function Toast:SlideIn()
    card:Show()
    UI:StopTween("pelt.out")
    local from, to = card:GetAlpha(), Opacity()
    UI:Tween("pelt.in", 0.28, function(e)
        card:SetAlpha(from + (to - from) * e)
        Place(0, -14 * (1 - e))
    end)
end

function Toast:SlideOut(done)
    UI:StopTween("pelt.in")
    local from = card:GetAlpha()
    UI:Tween("pelt.out", 0.3, function(e)
        card:SetAlpha(from * (1 - e))
        Place(0, -10 * e)
    end, function()
        card:Hide()
        UI:SetSurface(card, "bg")
        UI:StopTween("pelt.glow")
        card.glow:SetAlpha(0)
        Toast.glowTo = 0
        if done then done() end
    end)
end

-- A steady halo while you point at the corpse.
function Toast:SetGlow(to)
    if self.glowTo == to then return end
    self.glowTo = to
    local from = card.glow:GetAlpha()
    UI:Tween("pelt.glow", 0.25, function(e) card.glow:SetAlpha(from + (to - from) * e) end)
end

function Toast:Shake()
    UI:Tween("pelt.shake", 0.5, function(_, p)
        Place(math.sin(p * math.pi * 7) * 7 * (1 - p), 0)
    end, nil, function(p) return p end)
    UI:Tween("pelt.glow", 1.6, function(_, p)
        card.glow:SetAlpha(math.sin(p * math.pi * 3) ^ 2 * (1 - p * 0.6))
    end, function() card.glow:SetAlpha(Toast.glowTo or 0) end, function(p) return p end)
end

function Toast:Pop()
    UI:Tween("pelt.pop", 0.35, function(_, p)
        card.tick:SetScale(0.6 + 0.4 * UI.EaseOut(p) + math.sin(p * math.pi) * 0.12)
        -- a green flash that settles back to the normal background
        local q = 1 - p
        UI:SetSurface(card, { 0.047 + 0.05 * q, 0.043 + 0.17 * q, 0.039 + 0.08 * q, 0.95 })
    end, nil, function(p) return p end)
end

function Toast:ShowBanner(c)
    if not P.db.bigText then return end
    local info = Info(c)
    banner.title:SetText(info.nag:format(c.name or "corpse"))
    banner.title:SetTextColor(UI:Color(info.color))
    banner.glyph:SetVertexColor(UI:Color(info.color))
    banner.sub:SetText("It's still on the ground behind you.")
    banner:SetAlpha(0)
    banner:Show()
    UI:Tween("pelt.banner", 2.6, function(_, p)
        local a
        if p < 0.08 then a = p / 0.08 elseif p > 0.7 then a = (1 - p) / 0.3 else a = 1 end
        banner:SetAlpha(a)
        banner.title:SetScale(1 + 0.08 * math.max(0, 1 - p / 0.12))
    end, function() banner:Hide() end, function(p) return p end)
end

---------------------------------------------------------------------------
-- What the tracker calls
---------------------------------------------------------------------------

function Toast:Push(c)
    if self.demo then self:EndDemo(true) end
    P:PlaySound(P.db.sound)
    if self.resolving then return end  -- shows once the resolution finishes
    local fresh = self.shown ~= c
    self.shown = c
    self:PaintPending(c)
    if fresh then self:SlideIn() end
end

function Toast:Nag(c)
    P:PlaySound(P.db.nagSound)
    self:ShowBanner(c)
    if self.shown == c and not self.resolving then
        self:PaintPending(c)
        self:Shake()
    end
end

function Toast:Resolve(c, how, items)
    local hold = HOLD[how] or 0
    if how == "done" then P:PlaySound(P.db.doneSound) end
    if hold == 0 then
        if self.shown == c and not self.resolving then
            self.shown = nil
            self:Refresh()
        elseif not self.resolving then
            self:Refresh()
        end
        return
    end
    self.shown = nil
    self.resolving = { c = c, how = how, items = items, untilT = GetTime() + hold }
    self:PaintResolved(c, how, items)
    if how == "done" then self:Pop() end
    if not card:IsShown() or card:GetAlpha() < 1 then self:SlideIn() end
end

-- The skill-up lands a moment after the tick: add it to the card.
function Toast:SkillUp(c)
    local r = self.resolving
    if r and r.c == c and r.how == "done" then
        self:PaintResolved(c, "done", r.items)
        r.untilT = math.max(r.untilT, GetTime() + 1.2)
    end
end

-- Show whatever should be showing now.
function Toast:Refresh()
    if self.demo or self.resolving or not card then return end
    local top = P.Tracker.pending[1]
    if top then
        local fresh = self.shown ~= top
        self.shown = top
        self:PaintPending(top)
        if fresh or not card:IsShown() then
            self:SlideIn()
        else
            UI:Tween("pelt.in", 0.2, function(e) card:SetAlpha(card:GetAlpha() + (Opacity() - card:GetAlpha()) * e) end)
        end
    elseif card:IsShown() and not self.moving then
        self.shown = nil
        self:SlideOut()
    end
end

function Toast:OnUpdate()
    if self.resolving then
        if GetTime() >= self.resolving.untilT then
            self.resolving = nil
            if P.Tracker.pending[1] then
                self:Refresh()
            else
                self:SlideOut()
            end
        end
        return
    end
    local c = self.shown
    if not c or not c.age then return end
    local cast = c.casting
    if cast then
        -- fills up with your skinning cast
        local p = cast.done and 1 or math.min(1, (GetTime() - cast.at) / cast.dur)
        card.fill:SetWidth(math.max(1, (W - 28) * p))
        return
    end
    local left = math.max(0, 1 - c.age / math.max(1, P.db.remindFor))
    card.fill:SetWidth(math.max(1, (W - 28) * left))
end

---------------------------------------------------------------------------
-- Preview and moving
---------------------------------------------------------------------------

function Toast:Demo()
    if self.resolving then self.resolving = nil end
    local c = { name = "Mottled Boar", level = 7, prof = "skinning", age = 0, moved = 0 }
    c.need = Profs.Required(c.level)
    self.demo = c
    self.shown = c
    self:PaintPending(c)
    self:SlideIn()
    P:PlaySound(P.db.sound)
    UI:Tween("pelt.demo", 7, function(_, p)
        if self.demo ~= c then return end
        if not c.casting then c.age = p * P.db.remindFor end
        if p > 0.38 and not c.nagged then
            c.nagged = true
            self:Nag(c)
        elseif p > 0.56 and not c.casting then
            c.casting = { at = GetTime(), dur = 7 * 0.15 }
            self:PaintPending(c)
        elseif p > 0.72 and not c.done then
            c.done = true
            local rank = Profs:Rank("skinning")
            if rank then c.gain, c.rankNow = 1, rank + 1 end
            P:PlaySound(P.db.doneSound)
            self:PaintResolved(c, "done", { { name = "Ruined Leather Scraps", count = 2 } })
            self:Pop()
        end
    end, function()
        if self.demo == c then self:EndDemo() end
    end, function(p) return p end)
end

function Toast:EndDemo(silent)
    UI:StopTween("pelt.demo")
    self.demo = nil
    self.shown = nil
    if silent then return end
    if self.moving then
        self:PaintPending({ name = "Mottled Boar", level = 7, prof = "skinning", need = 1 })
    else
        self:Refresh()
    end
end

function Toast:ToggleMover(on)
    if on == nil then on = not self.moving end
    self.moving = on
    anchor:EnableMouse(on)
    anchor.outline:SetShown(on)
    anchor.hint:SetShown(on)
    if on then
        self:PaintPending(self.shown or { name = "Mottled Boar", level = 7, prof = "skinning", need = 1 })
        card:SetAlpha(1)
        card:Show()
        Place(0, 0)
        P:Print("Drag the card where you want it. Type /pelt move again to lock it.")
    else
        self:Refresh()
    end
    P:Send("MOVER", on)
end

function Toast:IsMoving()
    return self.moving == true
end

P:Listen("READY", function()
    BuildCard()
    BuildBanner()
    Toast:Layout()

    anchor:SetScript("OnDragStart", function(self) self:StartMoving() end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        P.db.position = { point, math.floor(x + 0.5), math.floor(y + 0.5) }
        Toast:Layout()
    end)
    anchor:SetScript("OnClick", function(_, button)
        if button == "RightButton" then P:ResetPosition() end
    end)
end)

P:Listen("LAYOUT", function() if anchor then Toast:Layout() end end)
P:Listen("SETTINGS", function() if anchor then Toast:Layout() Toast:Refresh() end end)
