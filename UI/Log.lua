--[[
    Pelt - log window
    /pelt log: what the tracker saw and decided lately, in a box you can
    copy from for a bug report.
]]

local _, P = ...
local UI = P.UI

local LogWindow = {}
P.LogWindow = LogWindow

local WIDTH, HEIGHT = 600, 420
local window

local function Text()
    if not P.log or #P.log == 0 then return "Nothing yet. Kill and loot something, then look again." end
    return table.concat(P.log, "\n")
end

local function Build()
    window = CreateFrame("Frame", "PeltLog", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    UI:Surface(window, { radius = 12, color = "surface", border = "edge", shadow = true })
    tinsert(UISpecialFrames, "PeltLog")

    local title = UI:Text(window, { size = 16 })
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Pelt log")
    local hint = UI:Text(window, { size = 11, color = "textDim" })
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetText("What Pelt saw and decided lately. Click the text, press Ctrl+A, then Ctrl+C to copy it.")

    local close = CreateFrame("Button", nil, window)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -14, -14)
    close.tex = close:CreateTexture(nil, "ARTWORK")
    close.tex:SetTexture(UI.tex.close)
    close.tex:SetAllPoints()
    close.tex:SetVertexColor(UI:Color("textDim"))
    close:SetScript("OnEnter", function(self) self.tex:SetVertexColor(UI:Color("text")) end)
    close:SetScript("OnLeave", function(self) self.tex:SetVertexColor(UI:Color("textDim")) end)
    close:SetScript("OnClick", function() window:Hide() end)

    local well = CreateFrame("Frame", nil, window)
    well:SetPoint("TOPLEFT", 18, -62)
    well:SetPoint("BOTTOMRIGHT", -18, 56)
    UI:Surface(well, { radius = 8, color = "bg", border = "edge" })

    local scroll = CreateFrame("ScrollFrame", nil, well)
    scroll:SetPoint("TOPLEFT", 10, -8)
    scroll:SetPoint("BOTTOMRIGHT", -10, 8)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(max, (self:GetVerticalScroll() or 0) - delta * 40)))
    end)

    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetWidth(WIDTH - 56)
    if not box:SetFont(UI:FontPath(), 11, "") then box:SetFont(STANDARD_TEXT_FONT, 11, "") end
    box:SetTextColor(UI:Color("text"))
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        window:Hide()
    end)
    -- read-only: anything typed is put back
    box:SetScript("OnTextChanged", function(self, typed)
        if typed then self:SetText(Text()) end
    end)
    scroll:SetScrollChild(box)
    window.box, window.scroll = box, scroll

    window.count = UI:Text(window, { size = 11, color = "textDim" })
    window.count:SetPoint("BOTTOMLEFT", 18, 22)

    local clear = UI:Button(window, "Clear", "ghost", 80, 28)
    clear:SetPoint("BOTTOMRIGHT", -18, 14)
    clear:SetScript("OnClick", function() P:ClearLog() end)

    window:SetScript("OnShow", function() LogWindow:Update() end)
end

function LogWindow:Update()
    if not window then return end
    window.box:SetText(Text())
    window.count:SetText(("%d lines"):format(P.log and #P.log or 0))
    -- newest at the bottom, once the box has its new height
    C_Timer.After(0, function()
        if window:IsShown() then window.scroll:SetVerticalScroll(window.scroll:GetVerticalScrollRange() or 0) end
    end)
end

function LogWindow:Toggle()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

function LogWindow:Text()
    return window and window.box:GetText()
end

P:Listen("LOG", function()
    -- leave it alone while you're selecting text in it
    if window and window:IsShown() and not window.box:HasFocus() then LogWindow:Update() end
end)
