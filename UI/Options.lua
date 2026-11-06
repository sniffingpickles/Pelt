--[[
    Pelt - settings window
    /pelt, the addon compartment and the game's AddOns settings page all
    open it.
]]

local _, P = ...
local UI = P.UI

local Options = {}
P.Options = Options

local WIDTH, HEIGHT, COL = 640, 490, 288
local window
local controls = {}

local function Changed()
    P:Send("SETTINGS")
end

local function Setting(key)
    return function() return P.db[key] end, function(v) P.db[key] = v Changed() end
end

local function SoundValues()
    return P:SoundList()
end

local function Preview(key)
    P:PlaySound(key)
end

local function StatsText()
    local s = P.stats
    local function n(v) return UI:Colorize("text", tostring(v)) end
    return ("Skinned %s  ·  Missed %s  ·  Best streak %s  ·  Items %s"):format(n(s.skinned), n(s.missed), n(s.best), n(s.items))
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

-- Stacks controls down a column.
local function Column(parent, x)
    local col = { y = -78, x = x }
    function col:Add(widget, height, gap)
        widget:SetPoint("TOPLEFT", parent, "TOPLEFT", self.x, self.y)
        widget:SetWidth(COL)
        self.y = self.y - (height or widget:GetHeight()) - (gap or 0)
        if widget.Update then controls[#controls + 1] = widget end
        return widget
    end
    return col
end

local function Build()
    window = CreateFrame("Frame", "PeltOptions", UIParent)
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
    tinsert(UISpecialFrames, "PeltOptions")

    -- header
    local logo = window:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.tex.logo)
    logo:SetSize(38, 38)
    logo:SetPoint("TOPLEFT", 18, -16)
    local title = UI:Text(window, { size = 20 })
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
    title:SetText("Pelt")
    local version = UI:Text(window, { size = 11, color = "textMute" })
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    version:SetText("v" .. P.version)
    local tagline = UI:Text(window, { size = 11, color = "textDim" })
    tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    tagline:SetText("Never walk away from a corpse you could skin.")

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

    -- left column
    local left = Column(window, 18)
    left:Add(UI:Header(window, "Reminders"), 26, 2)
    local get, set = Setting("enabled")
    left:Add(UI:Switch(window, "Remind me", "Show a card when a corpse you can skin is waiting.", get, set), 34)
    get, set = Setting("onlyMine")
    left:Add(UI:Switch(window, "Only corpses I looted",
        "Leave out other people's kills, corpses your group looted and ones that dropped nothing.", get, set), 34)
    get, set = Setting("others")
    left:Add(UI:Switch(window, "Other people's kills",
        "Remind you about skinnable corpses someone else killed when you point at or target them. Passing one up doesn't count as a miss.",
        get, set), 34)
    get, set = Setting("lowSkill")
    left:Add(UI:Switch(window, "Remind when my skill is too low",
        "Also remind you about corpses you can't skin yet. The card shows the skill it needs.", get, set), 34)
    get, set = Setting("remindFor")
    left:Add(UI:Slider(window, "Count it as missed after",
        "How long a corpse stays on the card out of combat before Pelt calls it missed. Time in combat doesn't count.",
        15, 120, 5, get, set, function(v) return ("%d s"):format(v) end), 46, 6)

    left:Add(UI:Header(window, "Professions"), 26, 8)
    local tiles = CreateFrame("Frame", nil, window)
    tiles:SetHeight(100)
    for i, key in ipairs(P.Profs.order) do
        local tile = UI:ProfTile(tiles, key,
            function() return P.db.profs[key] end,
            function(v) P.db.profs[key] = v Changed() end)
        tile:SetPoint("TOPLEFT", ((i - 1) % 2) * 148, -math.floor((i - 1) / 2) * 54)
        controls[#controls + 1] = tile
    end
    left:Add(tiles, 100)

    -- right column
    local right = Column(window, WIDTH - 18 - COL)
    right:Add(UI:Header(window, "Alerts"), 26, 2)
    get, set = Setting("nag")
    right:Add(UI:Switch(window, "Nag when I walk away",
        "Shake the card and play a sound when you move off without skinning.", get, set), 34)
    get, set = Setting("bigText")
    right:Add(UI:Switch(window, "Big text with the nag", "Also flash \"Skin the ...!\" in the middle of the screen.", get, set), 34)
    local sounds = { preview = Preview }
    Options.dropdowns = {}
    get, set = Setting("sound")
    Options.dropdowns.sound = right:Add(UI:Dropdown(window, "Skinnable sound",
        "Plays when a corpse you can skin shows up.", SoundValues, get, set, sounds), 34)
    get, set = Setting("nagSound")
    Options.dropdowns.nagSound = right:Add(UI:Dropdown(window, "Walk-away sound",
        "Plays with the nag.", SoundValues, get, set, sounds), 34)
    get, set = Setting("doneSound")
    Options.dropdowns.doneSound = right:Add(UI:Dropdown(window, "Skinned sound",
        "Plays when you skin it.", SoundValues, get, set, sounds), 34, 6)

    right:Add(UI:Header(window, "Display"), 26, 2)
    get, set = Setting("tooltip")
    right:Add(UI:Switch(window, "Skill on corpse tooltips",
        "Adds the skill a corpse needs, and yours, under the game's \"Skinnable\" line.", get, set), 34)
    get, set = Setting("scale")
    right:Add(UI:Slider(window, "Card size", nil, 0.7, 1.5, 0.05, get, set,
        function(v) return ("%d%%"):format(v * 100 + 0.5) end), 46)

    -- footer
    local rule = UI:Fill(window, nil, { 1, 1, 1, 0.06 }, "ARTWORK")
    rule:SetPoint("BOTTOMLEFT", 18, 56)
    rule:SetPoint("BOTTOMRIGHT", -18, 56)
    rule:SetHeight(1)

    window.stats = UI:Text(window, { size = 11, color = "textDim" })
    window.stats:SetPoint("BOTTOMLEFT", 18, 22)

    local reset = UI:Button(window, "Reset stats", "ghost", 96, 28)
    reset:SetPoint("BOTTOMRIGHT", -18, 14)
    reset:SetScript("OnClick", function() StaticPopup_Show("PELT_RESET_STATS") end)
    local move = UI:Button(window, "Move", "secondary", 80, 28)
    move:SetPoint("RIGHT", reset, "LEFT", -8, 0)
    move:SetScript("OnClick", function() P.Toast:ToggleMover() end)
    window.move = move
    local test = UI:Button(window, "Preview", "primary", 90, 28)
    test:SetPoint("RIGHT", move, "LEFT", -8, 0)
    test:SetScript("OnClick", function() P.Toast:Demo() end)

    window:SetScript("OnShow", function() Options:Update() end)
    window:SetScript("OnHide", function() UI:CloseMenu() end)
end

StaticPopupDialogs.PELT_RESET_STATS = {
    text = "Reset Pelt's skinning stats for this character?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function() P:ResetStats() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function Options:Update()
    if not window then return end
    for _, c in ipairs(controls) do c:Update() end
    window.stats:SetText(StatsText())
    window.move.text:SetText(P.Toast:IsMoving() and "Lock" or "Move")
end

function Options:Toggle()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

function Options:Open()
    if not window then Build() end
    window:Show()
end

P:Listen("STATS", function() if window and window:IsShown() then window.stats:SetText(StatsText()) end end)
P:Listen("SKILLS", function() if window and window:IsShown() then Options:Update() end end)
P:Listen("MOVER", function() if window and window:IsShown() then Options:Update() end end)

---------------------------------------------------------------------------
-- The game's AddOns settings page and the addon compartment
---------------------------------------------------------------------------

P:Listen("READY", function()
    local panel = CreateFrame("Frame")
    panel.name = "Pelt"
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.tex.logo)
    logo:SetSize(64, 64)
    logo:SetPoint("TOPLEFT", 20, -20)
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    t:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -8)
    t:SetText("|cffe8a23aPelt|r")
    local d = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetText("All settings live in Pelt's own window.")
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(180, 30)
    b:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -20)
    b:SetText("Open Pelt")
    b:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        Options:Open()
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "Pelt"))
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end)

function Pelt_OnAddonCompartmentClick()
    Options:Toggle()
end

function Pelt_OnAddonCompartmentEnter(_, owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cffe8a23aPelt|r")
    local s = P.session
    GameTooltip:AddLine(("This session: %d skinned, %d missed"):format(s.skinned, s.missed), 0.85, 0.83, 0.8)
    GameTooltip:AddLine("Click for settings", 0.6, 0.58, 0.55)
    GameTooltip:Show()
end

function Pelt_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
