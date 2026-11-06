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
local POINTED = { "mouseover", "softinteract" }
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

-- The profession a corpse can be gathered with: its tooltip line first, then
-- the cursor it shows. false when neither shows one, nil when hidden.
local function GatherKey(unit)
    local key = C.UnitGatherLine(unit, Profs.match)
    if key then return key end
    local cursor = C.UnitCursor(unit)
    if cursor and cursor.prof then return cursor.prof end
    return key
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
    c.rankAt = rank
    table.insert(self.pending, 1, c)
    P.Toast:Push(c)
    self:Wake()
end

-- how: done | missed | gone | dismissed
function T:Resolve(c, how, items)
    RemovePending(c)
    c.state = how
    c.resolvedAt = now()
    c.casting = nil
    if self.hover == c then self.hover, self.hoverUnit = nil, nil end
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
    local key = GatherKey(unit)
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
    self:UpdateHover()
end

-- The waiting corpse under your mouse (it shows the skinning cursor), or the
-- one soft targeting has picked out. It takes the card while you point at it.
function T:UpdateHover()
    local hover, unit
    if not P.inCombat then
        for _, u in ipairs(POINTED) do
            local guid = C.ValidToken(u) and UnitExists(u) and C.GUID(u)
            local c = guid and self.corpses[guid]
            if c and c.state == "pending" then hover, unit = c, u break end
        end
    end
    if hover == self.hover and unit == self.hoverUnit then return end
    self.hover, self.hoverUnit = hover, unit
    if hover then
        hover.moved = 0
        if self.pending[1] ~= hover then
            RemovePending(hover)
            table.insert(self.pending, 1, hover)
        end
    end
    P.Toast:Refresh()
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
        for _, c in ipairs(self.pending) do
            if c.casting then c.casting.done = true end
        end
    end
end

-- Started skinning: the card fills up with the cast.
function T:OnCastStart(spellID)
    spellID = C.Readable(spellID)
    local key = spellID and Profs:FromCast(spellID)
    local c = key and (self.hover or PendingInView())
    if not c then return end
    c.casting = { at = now(), dur = C.CastDuration() or 2 }
    c.moved = 0
    c.rankAt = Profs:Rank(c.prof)
    P.Toast:Refresh()
end

function T:OnCastFailed(spellID)
    spellID = C.Readable(spellID)
    if not (spellID and Profs:FromCast(spellID)) then return end
    for _, c in ipairs(self.pending) do
        if c.casting and not c.casting.done then c.casting = nil end
    end
    P.Toast:Refresh()
end

-- Skill went up: credit the corpse you just skinned. The rank is re-read
-- half a second after the game says so.
function T:OnSkills()
    local t = now()
    for _, c in pairs(self.corpses) do
        local rank = c.prof and Profs:Rank(c.prof)
        if rank and c.rankAt and rank > c.rankAt then
            if c.state == "done" and not c.gain and t - c.resolvedAt < 8 then
                c.gain, c.rankNow = rank - c.rankAt, rank
                P:CountSkillUp(c.gain)
                P.Toast:SkillUp(c)
            elseif c.state == "pending" then
                c.rankAt = rank
            end
        end
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
            -- a cast that never got its loot: let the card go back
            if c.casting and t - c.casting.at > c.casting.dur + 1.5 then
                c.casting = nil
                P.Toast:Refresh()
            end
            -- no ticking down while you're skinning it
            if not c.casting then c.age = c.age + dt end
            if c.age >= P.db.remindFor then self:Resolve(c, "missed") end
        end
        local top = self.pending[1]
        if top and P.db.nag and not top.nagged then
            local onTarget = C.GUID("target") == top.guid
            local near = onTarget and C.InReach("target")
            -- pointing at it from across the field is still walking away
            local onIt = top.casting or (self.hover == top and C.InReach(self.hoverUnit) ~= false)
            if near or onIt then
                top.moved = 0
            elseif C.IsMoving() then
                top.moved = top.moved + dt
            end
            if not onIt and top.age >= NAG_GRACE and (top.moved >= WALK_AWAY or (onTarget and near == false)) then
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

    local function Pointed(unit)
        T:Scan(unit, true)
        T:UpdateHover()
    end
    P:On("UPDATE_MOUSEOVER_UNIT", function() Pointed("mouseover") end)
    -- the mouse moved onto or off something in the world
    P:On("WORLD_CURSOR_TOOLTIP_UPDATE", function() Pointed("mouseover") end)
    P:On("PLAYER_SOFT_INTERACT_CHANGED", function() Pointed("softinteract") end)
    P:On("PLAYER_TARGET_CHANGED", function() T:Scan("target", true) end)
    -- fires when the corpse's skinnable flag lands
    P:On("UNIT_FLAGS", function(unit)
        if unit == "target" or unit == "mouseover" then T:Scan(unit) end
    end)

    P:On("UNIT_SPELLCAST_START", function(unit, _, spellID)
        if unit == "player" then T:OnCastStart(spellID) end
    end)
    P:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
        if unit == "player" then T:OnCast(spellID) end
    end)
    for _, event in ipairs({ "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
        P:On(event, function(unit, _, spellID)
            if unit == "player" then T:OnCastFailed(spellID) end
        end)
    end

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

P:Listen("SKILLS", function() T:OnSkills() end)

---------------------------------------------------------------------------
-- /pelt check: what Pelt can read off your target
---------------------------------------------------------------------------

local function YesNo(v)
    if v == nil then return "can't tell" end
    return v and "yes" or "no"
end

local STATE_TEXT = {
    new = "seen it",
    looted = "you looted it, waiting for it to turn skinnable",
    pending = "reminding you",
    done = "skinned",
    missed = "missed",
    gone = "gone (someone else skinned it, or it despawned)",
    dismissed = "skipped",
    low = "your skill is too low (turn on the low-skill reminder to see it)",
    ignored = "that profession is off, or you don't have it",
}

function T:Diagnose()
    local unit
    for _, u in ipairs(TOKENS) do
        if C.ValidToken(u) and UnitExists(u) then unit = u break end
    end
    if not unit then
        P:Print("Target a corpse or point at one, then type /pelt check.")
        return
    end
    local dead = C.Readable(UnitIsDead(unit))
    P:Print(("%s (%s): %s"):format(C.Readable(UnitName(unit)) or "Hidden name", unit,
        dead == nil and "can't tell if it's dead" or dead and "dead" or "alive"))
    if P.inCombat then P:Print("  You're in combat, so most of this is hidden until it ends.") end

    local line = C.UnitGatherLine(unit, Profs.match)
    P:Print("  Tooltip line: " .. (line and Profs.info[line].name or line == false and "none" or "hidden"))

    local cursor, raw = C.UnitCursor(unit)
    local shows
    if cursor then
        shows = cursor.file
    elseif cursor == false then
        shows = "none"
    elseif raw ~= nil then
        shows = "not one Pelt knows (" .. tostring(raw) .. ")"
    else
        shows = SetUnitCursorTexture and "hidden" or "not on this client"
    end
    P:Print("  Cursor: " .. shows)
    P:Print("  Someone else's kill: " .. YesNo(C.Readable(UnitIsTapDenied(unit))))
    P:Print("  In reach: " .. YesNo(C.InReach(unit)))

    local guid = C.GUID(unit)
    local c = guid and self.corpses[guid]
    local learned = P.learned[C.NpcID(guid) or false]
    P:Print("  Pelt: " .. (c and STATE_TEXT[c.state] or "not tracking it")
        .. (learned and ("  ·  learned as " .. Profs.info[learned].name) or ""))
end
