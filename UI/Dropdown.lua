--[[
    Pelt - dropdown
    A picker that opens a scrolling list, split into groups. Sound pickers
    get a play button beside the picker and on every row, so you can hear a
    sound before you pick it.
]]

local _, P = ...
local UI = P.UI

local ROW_H, VISIBLE, MENU_W = 22, 12, 236
local menu, catcher

local function PlayButton(parent, size, framed)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    if framed then
        UI:Surface(b, { radius = 6, color = "surface2", border = "border" })
        b.hover = UI:Fill(b, 6, { 1, 1, 1, 0.06 }, "HIGHLIGHT")
        b.hover:SetAllPoints()
    end
    b.icon = b:CreateTexture(nil, "OVERLAY")
    b.icon:SetTexture(UI.tex.play)
    b.icon:SetSize(math.floor(size * 0.55), math.floor(size * 0.55))
    b.icon:SetPoint("CENTER", 1, 0)
    b.icon:SetVertexColor(UI:Color("textDim"))
    b:SetScript("OnEnter", function(self) self.icon:SetVertexColor(UI:Color("text")) end)
    b:SetScript("OnLeave", function(self) self.icon:SetVertexColor(UI:Color("textDim")) end)
    return b
end

-- The play icon lights up and fades back.
local function Flash(b)
    local r1, g1, b1 = UI:Color("accent")
    local r2, g2, b2 = UI:Color("textDim")
    UI:Tween(b, 0.7, function(e)
        b.icon:SetVertexColor(r1 + (r2 - r1) * e, g1 + (g2 - g1) * e, b1 + (b2 - b1) * e)
    end, nil, UI.EaseInOut)
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------

-- Values in display order, with a header row where the group changes.
local function Flatten(values)
    local out, last = {}, nil
    for _, v in ipairs(values) do
        if v.group and v.group ~= last then out[#out + 1] = { header = v.group } end
        last = v.group
        out[#out + 1] = v
    end
    return out
end

local function Paint()
    local items, owner = menu.items, menu.owner
    local picked = owner.get()
    for i, row in ipairs(menu.rows) do
        local item = items[menu.offset + i]
        row.item = item
        row.hover:Hide()
        if not item then
            row:Hide()
        elseif item.header then
            row:Show()
            row:EnableMouse(false)
            row.text:ClearAllPoints()
            row.text:SetPoint("BOTTOMLEFT", 8, 4)
            row.text:SetText(item.header:upper())
            row.text:SetTextColor(UI:Color("textMute"))
            row.check:Hide()
            row.play:Hide()
            row.rule:SetShown(menu.offset + i > 1)
        else
            local on = item.key == picked
            row:Show()
            row:EnableMouse(true)
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", 24, 0)
            row.text:SetPoint("RIGHT", -28, 0)
            row.text:SetText(item.label)
            row.text:SetTextColor(UI:Color(on and "accent" or "text"))
            row.check:SetShown(on)
            row.play:SetShown(owner.preview ~= nil and item.key ~= "none")
            row.rule:Hide()
        end
    end
    local total = #items
    if total > VISIBLE then
        local track = VISIBLE * ROW_H
        local h = math.max(18, track * VISIBLE / total)
        menu.thumb:ClearAllPoints()
        menu.thumb:SetPoint("TOPRIGHT", -3, -6 - (track - h) * menu.offset / (total - VISIBLE))
        menu.thumb:SetHeight(h)
        menu.thumb:Show()
    else
        menu.thumb:Hide()
    end
end

local function Scroll(offset)
    menu.offset = math.max(0, math.min(offset, #menu.items - VISIBLE))
    Paint()
end

local function BuildMenu()
    -- clicking anywhere else closes the list
    catcher = CreateFrame("Button", "PeltMenuCatcher", UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", function() UI:CloseMenu() end)
    catcher:Hide()

    menu = CreateFrame("Frame", "PeltMenu", UIParent)
    menu:SetSize(MENU_W, VISIBLE * ROW_H + 12)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:EnableMouseWheel(true)
    menu:Hide()
    UI:Surface(menu, { radius = 6, color = "surface", border = "border", shadow = true })

    menu.rows = {}
    for i = 1, VISIBLE do
        local row = CreateFrame("Button", nil, menu)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", -8, -6 - (i - 1) * ROW_H)
        row.hover = UI:Fill(row, 6, { 1, 1, 1, 0.05 }, "BACKGROUND")
        row.hover:SetAllPoints()
        row.rule = UI:Fill(row, nil, { 1, 1, 1, 0.06 }, "ARTWORK")
        row.rule:SetPoint("TOPLEFT", 4, -2)
        row.rule:SetPoint("TOPRIGHT", -4, -2)
        row.rule:SetHeight(1)
        row.check = row:CreateTexture(nil, "ARTWORK")
        row.check:SetTexture(UI.tex.check)
        row.check:SetSize(12, 12)
        row.check:SetPoint("LEFT", 7, 0)
        row.check:SetVertexColor(UI:Color("accent"))
        row.text = UI:Text(row, { size = 11 })
        row.play = PlayButton(row, 20)
        row.play:SetPoint("RIGHT", -2, 0)
        row.play:SetScript("OnClick", function(self)
            if row.item and menu.owner.preview then
                menu.owner.preview(row.item.key)
                Flash(self)
            end
        end)
        row:SetScript("OnEnter", function(self) self.hover:Show() end)
        row:SetScript("OnLeave", function(self) self.hover:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.item and not self.item.header then menu.owner:Pick(self.item.key) end
        end)
        menu.rows[i] = row
    end

    menu.thumb = UI:Fill(menu, nil, { 1, 1, 1, 0.16 }, "OVERLAY")
    menu.thumb:SetWidth(3)
    menu:SetScript("OnMouseWheel", function(_, delta) Scroll(menu.offset - delta * 3) end)
    menu:SetScript("OnHide", function()
        catcher:Hide()
        if menu.owner then menu.owner:SetOpen(false) end
        menu.owner = nil
    end)
end

function UI:OpenMenu(owner)
    if not menu then BuildMenu() end
    if menu:IsShown() and menu.owner == owner then
        self:CloseMenu()
        return
    end
    self:CloseMenu()
    menu.owner = owner
    menu.items = Flatten(owner.values())
    local height = math.min(VISIBLE, #menu.items) * ROW_H + 12
    menu:SetHeight(height)
    -- open with the current pick in the middle
    local index = 1
    for i, item in ipairs(menu.items) do
        if item.key == owner.get() then index = i end
    end
    Scroll(index - math.ceil(VISIBLE / 2))

    local b = owner.button
    local room = (b:GetBottom() or 0) * b:GetEffectiveScale() / UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    if room > height + 12 then
        menu:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -4)
    else
        menu:SetPoint("BOTTOMRIGHT", b, "TOPRIGHT", 0, 4)
    end
    catcher:Show()
    menu:Show()
    owner:SetOpen(true)
end

function UI:CloseMenu()
    if menu and menu:IsShown() then menu:Hide() end
end

---------------------------------------------------------------------------
-- The picker
---------------------------------------------------------------------------

-- values() -> list of { key, label, group }. opts.preview(key) adds play
-- buttons; opts.width sizes the picker.
function UI:Dropdown(parent, label, desc, values, get, set, opts)
    opts = opts or {}
    local row = UI.Row(parent, label, desc)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(opts.width or 140, 24)
    b:SetPoint("RIGHT")
    UI:Surface(b, { radius = 6, color = "surface2", border = "border" })
    b.hover = UI:Fill(b, 6, { 1, 1, 1, 0.06 }, "HIGHLIGHT")
    b.hover:SetAllPoints()
    b.text = UI:Text(b, { size = 11 })
    b.text:SetPoint("LEFT", 10, 0)
    b.text:SetPoint("RIGHT", -24, 0)
    b.chev = b:CreateTexture(nil, "ARTWORK")
    b.chev:SetTexture(UI.tex.chevronDown)
    b.chev:SetSize(12, 12)
    b.chev:SetPoint("RIGHT", -7, 0)
    b.chev:SetVertexColor(UI:Color("textDim"))
    row.button, row.values, row.get, row.preview = b, values, get, opts.preview

    if opts.preview then
        row.play = PlayButton(row, 24, true)
        row.play:SetPoint("RIGHT", b, "LEFT", -6, 0)
        row.play:SetScript("OnClick", function(self)
            opts.preview(get())
            Flash(self)
        end)
    end

    function row:Pick(key)
        set(key)
        self:Update()
        UI:CloseMenu()
    end

    function row:SetOpen(open)
        UI:SetSurface(b, nil, open and "accent" or "border")
        b.chev:SetVertexColor(UI:Color(open and "accent" or "textDim"))
    end

    function row:Update()
        local key = get()
        for _, v in ipairs(values()) do
            if v.key == key then
                b.text:SetText(v.label)
                return
            end
        end
        -- saved from a sound pack that's no longer installed
        b.text:SetText(UI:Colorize("textMute", tostring(key):match(":(.+)$") or tostring(key)))
    end

    b:SetScript("OnClick", function() UI:OpenMenu(row) end)
    b:SetScript("OnEnter", function() row:GetScript("OnEnter")(row) end)
    b:SetScript("OnLeave", function() row:GetScript("OnLeave")(row) end)
    row:SetScript("OnClick", function() b:Click() end)
    row:Update()
    return row
end
