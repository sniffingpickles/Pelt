--[[
    Pelt - corpse tooltips
    Adds "Skinning 125 · you 130" under the game's "Skinnable" line, green
    when you can skin it and red when you can't yet.
]]

local _, P = ...
local UI, C, Profs = P.UI, P.Compat, P.Profs

local function CorpseLevel(guid)
    for _, unit in ipairs({ "mouseover", "target" }) do
        if UnitExists(unit) and UnitIsDead(unit) and (not guid or C.GUID(unit) == guid) then
            return C.Readable(UnitLevel(unit))
        end
    end
end

local function AddLine(tooltip, key, level)
    if not (key and Profs:Has(key)) then return end
    local need = Profs.Required(level)
    if not need then return end
    local rank = Profs:Rank(key)
    local color = "textDim"
    local text = ("%s %d"):format(Profs:Name(key), need)
    if rank then
        color = rank >= need and "good" or "danger"
        text = text .. ("  ·  you %d"):format(rank)
    end
    local r, g, b = UI:Color(color)
    tooltip:AddLine("|T" .. UI.tex.glyph .. ":12:12:0:0|t " .. text, r, g, b)
    tooltip:Show()
end

P:Listen("READY", function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
            if tooltip ~= GameTooltip or P.inCombat or not (P.db.enabled and P.db.tooltip) then return end
            local key = C.GatherFromData(data, Profs.match)
            if key then AddLine(tooltip, key, CorpseLevel(C.Readable(data.guid))) end
        end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            if P.inCombat or not (P.db.enabled and P.db.tooltip) then return end
            local _, unit = tooltip:GetUnit()
            if not unit or not UnitIsDead(unit) then return end
            local key = C.UnitGatherLine(unit, Profs.match)
            if key then AddLine(tooltip, key, C.Readable(UnitLevel(unit))) end
        end)
    end
end)
