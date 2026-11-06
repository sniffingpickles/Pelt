--[[
    Pelt - corpse tracker
    Decides which corpses need skinning, when to nag and when one is done.
    Forever gives addons no combat log, so it all comes from loot windows,
    the corpse's tooltip ("Skinnable") and your own casts.
]]

local _, P = ...
local C, Profs = P.Compat, P.Profs

local T = { corpses = {}, pending = {} }
P.Tracker = T

local TOKENS = { "target", "mouseover", "softinteract" }
local CONFIRM_FOR = 4       -- seconds after looting to keep looking for the "Skinnable" line
local TRUST_LEARNED = 0.8   -- then fall back on what this NPC was last time
local CAST_WINDOW = 1       -- a loot window this soon after a gathering cast is its loot
local WALK_AWAY = 1.25      -- seconds of moving before it counts as walking off
local NAG_GRACE = 1.5       -- never nag in the first moments of a reminder
local FORGET = 600          -- drop finished corpses from memory after this long

local now = GetTime

local function Corpse(guid)
    local c = T.corpses[guid]
    if not c then
        c = { guid = guid, npc = C.NpcID(guid), state = "new", born = now() }
        T.corpses[guid] = c
    end
    return c
end

local function Learn(npc, key)
    if npc and key then P.learned[npc] = key end
end

-- Fill in name and level from whichever unit token shows this corpse.
local function Describe(c)
    for _, unit in ipairs(TOKENS) do
        if C.ValidToken(unit) and UnitExists(unit) and C.GUID(unit) == c.guid then
            c.name = C.Readable(UnitName(unit)) or c.name
            local level = C.Readable(UnitLevel(unit))
            if level and level > 0 then c.level = level end
            return unit
        end
    end
end

-- The waiting corpse you're looking at, or the only one waiting.
local function PendingInView()
    for _, unit in ipairs(TOKENS) do
        local guid = C.ValidToken(unit) and UnitExists(unit) and C.GUID(unit)
        local c = guid and T.corpses[guid]
        if c and c.state == "pending" then return c end
    end
    if #T.pending == 1 then return T.pending[1] end
end

local function RemovePending(c)
    for i = #T.pending, 1, -1 do
        if T.pending[i] == c then table.remove(T.pending, i) end
    end
end

---------------------------------------------------------------------------
-- State changes
---------------------------------------------------------------------------

-- The corpse can be gathered by `key`: remind, unless it doesn't apply.
function T:Promote(c, key)
    c.prof = key
    Describe(c)
    if not (P.db.enabled and P.db.profs[key] and Profs:Has(key)) then
        c.state = "ignored"
        return
    end
    c.need = Profs.Required(c.level)
    local rank = Profs:Rank(key)
    c.low = (c.need and rank and rank < c.need) or false
    if c.low and not P.db.lowSkill then
        c.state = "low"
        return
    end
    RemovePending(c)
    c.state = "pending"
    c.age, c.moved, c.nagged = 0, 0, false
    table.insert(self.pending, 1, c)
    P.Toast:Push(c)
    self:Wake()
end

-- how: done | missed | gone | dismissed
function T:Resolve(c, how, items)
    RemovePending(c)
    c.state = how
    c.resolvedAt = now()
    if how == "done" then
        P:CountDone(items, c.countedMiss)
        c.countedMiss = nil
        -- you're busy skinning: walking to the next corpse isn't walking away
        for _, other in ipairs(self.pending) do other.moved = 0 end
    elseif how == "missed" and not c.countedMiss then
        c.countedMiss = true
        P:CountMissed()
    end
    P.Toast:Resolve(c, how, items)
end

function T:Dismiss(c)
    if c and (c.state == "pending" or c.state == "missed") then
        self:Resolve(c, "dismissed")
    end
end

---------------------------------------------------------------------------
-- Looking at corpses
---------------------------------------------------------------------------

-- `fresh`: you just moused over or targeted it, so a missed corpse comes back.
function T:Scan(unit, fresh)
    -- tooltips and GUIDs of other units are secret in combat on Forever
    if P.inCombat or not P.db.enabled or not C.ValidToken(unit) then return end
    if not UnitExists(unit) or not UnitIsDead(unit) then return end
    local guid = C.GUID(unit)
    local npc = C.NpcID(guid)
    if not npc then return end
    local key = C.UnitGatherLine(unit, Profs.match)
    if key == nil then return end
    local c = self.corpses[guid]
    if key then
        Learn(npc, key)
        if not c then
            -- not one you looted: skip other people's kills, and all of them
            -- when you only want your own
            if P.db.onlyMine or C.Readable(UnitIsTapDenied(unit)) ~= false then return end
            c = Corpse(guid)
        end
        c.seen = now()
        if c.state == "new" or c.state == "looted" or (c.state == "missed" and fresh) then
            self:Promote(c, key)
        end
    elseif c and (c.state == "pending" or c.state == "low" or c.state == "missed") then
        -- the gather line is gone: you skinned it, or someone else did
        local yours = self.lastGather and now() - self.lastGather < 6
        self:Resolve(c, yours and "done" or "gone")
    end
end

function T:ScanAll()
    for _, unit in ipairs(TOKENS) do self:Scan(unit) end
end

---------------------------------------------------------------------------
-- Loot windows
---------------------------------------------------------------------------

local loot  -- the open window: { sources, total, cleared, gather }

function T:OnLootReady()
    if loot then return end  -- LOOT_READY and LOOT_OPENED both fire for one window
    loot = { sources = {}, total = 0, cleared = 0 }
    if IsFishingLoot and IsFishingLoot() then return end
    loot.sources = C.LootSources()
    loot.total = GetNumLootItems and GetNumLootItems() or 0
    local castKey = self.lastCast and now() - self.lastCast <= CAST_WINDOW and self.lastCastKey
    self.lastCast = nil
    -- no source GUIDs to go on: credit the corpse you were skinning
    if castKey and not next(loot.sources) then
        local c = PendingInView()
        if c then
            loot.gather = true
            Learn(c.npc, castKey)
            self:Resolve(c, "done", C.LootItems())
        end
        return
    end
    for guid in pairs(loot.sources) do
        local npc = C.NpcID(guid)
        if npc then
            local c = Corpse(guid)
            -- Looting a corpse that's already skinnable, or a second window
            -- from one you emptied, can only be the gathering loot.
            local gathered = castKey or c.state == "pending" or c.state == "missed" or c.state == "low"
                or (c.state == "looted" and c.full)
            if gathered and c.state ~= "done" then
                c.prof = c.prof or castKey or P.learned[npc] or "skinning"
                if castKey then Learn(npc, castKey) end
                Describe(c)
                loot.gather = true
                self:Resolve(c, "done", C.LootItems())
            elseif c.state == "new" then
                c.state = "looted"
                c.lootedAt = now()
                Describe(c)
            end
        end
    end
end

function T:OnLootClosed()
    local l = loot
    loot = nil
    if not l or l.gather then return end
    local full = l.total == 0 or l.cleared >= l.total
    for guid in pairs(l.sources) do
        local c = self.corpses[guid]
        if c and c.state == "looted" then
            c.full = full
            c.closedAt = now()
        end
    end
    self:Wake()
    -- the corpse turns skinnable a moment after the window closes
    C_Timer.After(0.15, function() T:ScanAll() end)
    C_Timer.After(0.6, function() T:ScanAll() end)
end

function T:OnCast(spellID)
    spellID = C.Readable(spellID)
    local key = spellID and Profs:FromCast(spellID)
    if key then
        self.lastCast = now()
        self.lastGather = self.lastCast
        self.lastCastKey = key
    end
end

---------------------------------------------------------------------------
-- Ticking: confirm, age, nag, expire
---------------------------------------------------------------------------

local ticker = CreateFrame("Frame")
ticker:Hide()
local scanIn, purgeIn = 0, 0

function T:Wake()
    ticker:Show()
end

function T:OnUpdate(dt)
    local t = now()
    local busy = false

    for guid, c in pairs(self.corpses) do
        if c.state == "looted" and c.closedAt and t - c.closedAt < CONFIRM_FOR then
            busy = true
            local learned = P.learned[c.npc]
            if c.full and learned and t - c.closedAt >= TRUST_LEARNED then
                self:Promote(c, learned)
            end
        end
    end

    scanIn = scanIn - dt
    if scanIn <= 0 and (busy or #self.pending > 0) then
        scanIn = 0.25
        self:ScanAll()
    end

    if not P.inCombat and #self.pending > 0 then
        for i = #self.pending, 1, -1 do
            local c = self.pending[i]
            c.age = c.age + dt
            if c.age >= P.db.remindFor then self:Resolve(c, "missed") end
        end
        local top = self.pending[1]
        if top and P.db.nag and not top.nagged then
            local onTarget = C.GUID("target") == top.guid
            local near = onTarget and C.InReach("target")
            if near then
                top.moved = 0
            elseif C.IsMoving() then
                top.moved = top.moved + dt
            end
            if top.age >= NAG_GRACE and (top.moved >= WALK_AWAY or (onTarget and near == false)) then
                top.nagged = true
                P.Toast:Nag(top)
            end
        end
    end

    purgeIn = purgeIn - dt
    if purgeIn <= 0 then
        purgeIn = 30
        for guid, c in pairs(self.corpses) do
            if t - (c.resolvedAt or c.seen or c.lootedAt or c.born) > FORGET and c.state ~= "pending" then
                self.corpses[guid] = nil
            end
        end
    end

    if not busy and #self.pending == 0 then
        ticker:Hide()
    end
end

ticker:SetScript("OnUpdate", function(_, dt) T:OnUpdate(dt) end)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

P:Listen("READY", function()
    P.inCombat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) or false

    P:On("LOOT_READY", function() T:OnLootReady() end)
    P:On("LOOT_OPENED", function() T:OnLootReady() end)
    P:On("LOOT_SLOT_CLEARED", function() if loot then loot.cleared = loot.cleared + 1 end end)
    P:On("LOOT_CLOSED", function() T:OnLootClosed() end)

    P:On("UPDATE_MOUSEOVER_UNIT", function() T:Scan("mouseover", true) end)
    P:On("PLAYER_TARGET_CHANGED", function() T:Scan("target", true) end)
    P:On("PLAYER_SOFT_INTERACT_CHANGED", function() T:Scan("softinteract", true) end)
    -- fires when the corpse's skinnable flag lands
    P:On("UNIT_FLAGS", function(unit)
        if unit == "target" or unit == "mouseover" then T:Scan(unit) end
    end)

    P:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
        if unit == "player" then T:OnCast(spellID) end
    end)

    P:On("PLAYER_REGEN_DISABLED", function()
        P.inCombat = true
        P.Toast:Refresh()
    end)
    P:On("PLAYER_REGEN_ENABLED", function()
        P.inCombat = false
        P.Toast:Refresh()
        -- your target is often the corpse of the last thing you killed
        C_Timer.After(0.3, function() T:ScanAll() end)
        T:Wake()
    end)

    -- corpses don't follow you through a loading screen
    P:On("PLAYER_ENTERING_WORLD", function()
        for i = #T.pending, 1, -1 do T:Resolve(T.pending[i], "gone") end
    end)
end)

P:Listen("SETTINGS", function()
    if not P.db.enabled then
        for i = #T.pending, 1, -1 do T:Resolve(T.pending[i], "dismissed") end
    end
end)
