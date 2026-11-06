--[[
    Pelt - compat
    Client differences in one place: WoW Forever (12.x engine, where names,
    GUIDs and tooltip text can be secret in combat) and Burning Crusade
    Anniversary (classic globals, no C_TooltipInfo).
]]

local _, P = ...

local C = {}
P.Compat = C

function C.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- The value, or nil when the client hides it from addons.
function C.Readable(v)
    if C.IsSecret(v) then return nil end
    return v
end

---------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------

function C.SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

function C.Knows(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) == true end
    if IsPlayerSpell then return IsPlayerSpell(id) == true end
    if IsSpellKnown then return IsSpellKnown(id) == true end
    return false
end

-- Length of the spell you're casting, in seconds.
function C.CastDuration()
    if not UnitCastingInfo then return nil end
    local _, _, _, startMS, endMS = UnitCastingInfo("player")
    startMS, endMS = C.Readable(startMS), C.Readable(endMS)
    if type(startMS) == "number" and type(endMS) == "number" and endMS > startMS then
        return (endMS - startMS) / 1000
    end
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------

-- NPC ID from a creature GUID ("Creature-0-1-2-3-<npc>-<spawn>").
function C.NpcID(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, npc = strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(npc) end
end

function C.GUID(unit)
    return C.Readable(UnitGUID(unit))
end

-- Soft targeting ("softinteract") only exists on newer clients.
local tokenOK = {}
function C.ValidToken(unit)
    if tokenOK[unit] == nil then
        tokenOK[unit] = pcall(UnitExists, unit)
    end
    return tokenOK[unit]
end

-- Within about 10 yards. nil when the client won't say.
function C.InReach(unit)
    if not CheckInteractDistance then return nil end
    local ok, res = pcall(CheckInteractDistance, unit, 3)
    if ok then return C.Readable(res) end
end

function C.IsMoving()
    local speed = C.Readable(GetUnitSpeed("player"))
    return speed ~= nil and speed > 0
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------

-- Finds the "Skinnable" / "Requires Herbalism" line. `match` maps a line of
-- text to a profession key. Returns the key, false when there's no such
-- line, or nil when some lines were secret and none matched.
function C.GatherFromData(data, match)
    if not data or C.IsSecret(data) then return nil end
    local ok, res = pcall(function()
        local lines = data.lines
        if not lines or C.IsSecret(lines) then return nil end
        local hidden = false
        for _, line in ipairs(lines) do
            if line.leftText == nil and line.args and TooltipUtil and TooltipUtil.SurfaceArgs then
                TooltipUtil.SurfaceArgs(line)
            end
            local text = line.leftText
            if C.IsSecret(text) then
                hidden = true
            elseif text then
                local key = match(text)
                if key then return key end
            end
        end
        if hidden then return nil end
        return false
    end)
    if ok then return res end
end

local scanner
local function ScanTooltip(unit, match)
    if not scanner then
        scanner = CreateFrame("GameTooltip", "PeltScanTooltip", UIParent, "GameTooltipTemplate")
    end
    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:SetUnit(unit)
    local found, hidden = false, false
    for i = 1, scanner:NumLines() do
        local fs = _G["PeltScanTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if C.IsSecret(text) then
            hidden = true
        elseif text then
            local key = match(text)
            if key then found = key break end
        end
    end
    scanner:Hide()
    if not found and hidden then return nil end
    return found
end

function C.UnitGatherLine(unit, match)
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if not ok then return nil end
        return C.GatherFromData(data, match)
    end
    return ScanTooltip(unit, match)
end

---------------------------------------------------------------------------
-- Cursor
---------------------------------------------------------------------------

-- The cursor a unit shows under the mouse: the skinning knife, the pick,
-- the herb hand. "Unable" is the greyed-out one (too far, or skill too low).
local CURSORS = {
    { file = "Skin", prof = "skinning" },
    { file = "UnableSkin", prof = "skinning", unable = true },
    { file = "GatherHerbs", prof = "herbalism" },
    { file = "UnableGatherHerbs", prof = "herbalism", unable = true },
    { file = "Mine", prof = "mining" },
    { file = "UnableMine", prof = "mining", unable = true },
    { file = "EngineerSkin", prof = "engineering" },
    { file = "UnableEngineerSkin", prof = "engineering", unable = true },
    { file = "LootAll" },
    { file = "UnableLootAll", unable = true },
    { file = "Pickup" },
    { file = "UnablePickup", unable = true },
}

local cursorTex, cursorByID, cursorByName

local function BuildCursors()
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()
    cursorTex = holder:CreateTexture()
    cursorByID, cursorByName = {}, {}
    for _, c in ipairs(CURSORS) do
        cursorByName[c.file:lower()] = c
        -- the client may hand back a file ID instead of a path
        local ref = holder:CreateTexture()
        ref:SetTexture("Interface\\Cursor\\" .. c.file)
        local id = ref.GetTextureFileID and C.Readable(ref:GetTextureFileID())
        if type(id) == "number" and id > 0 then cursorByID[id] = c end
    end
end

local function CursorFrom(v)
    if type(v) == "number" then return cursorByID[v] end
    if type(v) == "string" then
        local name = (v:lower():match("([^\\/]+)$") or ""):gsub("%.%w+$", "")
        return cursorByName[name]
    end
end

-- Which cursor `unit` shows. Returns the cursor (a CURSORS entry), false
-- when it has none, or nil when the client won't say. The second value is
-- what the client handed back, for /pelt check.
function C.UnitCursor(unit)
    if not SetUnitCursorTexture then return nil end
    if not cursorTex then BuildCursors() end
    cursorTex:SetTexture(nil)
    local ok, has = pcall(SetUnitCursorTexture, cursorTex, unit)
    if not ok then return nil end
    has = C.Readable(has)
    if has == nil then return nil end
    if not has then return false end
    local raw
    for _, get in ipairs({ "GetTextureFileID", "GetTextureFilePath", "GetTexture", "GetAtlas" }) do
        local v = cursorTex[get] and C.Readable(cursorTex[get](cursorTex))
        local c = CursorFrom(v)
        if c then return c, v end
        raw = raw or v
    end
    return nil, raw
end

---------------------------------------------------------------------------
-- Loot
---------------------------------------------------------------------------

-- GUIDs of everything the open loot window came from.
function C.LootSources()
    local out = {}
    if not (GetLootSourceInfo and GetNumLootItems) then return out end
    for slot = 1, GetNumLootItems() do
        local info = { GetLootSourceInfo(slot) }
        for i = 1, #info, 2 do
            local guid = C.Readable(info[i])
            if type(guid) == "string" then out[guid] = true end
        end
    end
    return out
end

-- Items in the open loot window, money left out.
function C.LootItems()
    local out = {}
    if not (GetNumLootItems and GetLootSlotInfo) then return out end
    for slot = 1, GetNumLootItems() do
        local icon, name, count = GetLootSlotInfo(slot)
        count = C.Readable(count)
        if name and not C.IsSecret(name) and count and count > 0 then
            out[#out + 1] = { name = name, count = count, icon = icon }
        end
    end
    return out
end
