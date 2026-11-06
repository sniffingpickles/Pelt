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
