--[[
    Pelt - core
    Namespace, saved variables, the event hub, slash commands and the
    skinning stats kept per character.
]]

local ADDON, P = ...

local GetMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
P.version = GetMeta and GetMeta(ADDON, "Version") or "1.0.0"

local build = select(4, GetBuildInfo())
P.IS_FOREVER = (build >= 16000 and build < 20000)
    or (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)

P.defaults = {
    enabled = true,
    profs = { skinning = true, herbalism = true, mining = true, engineering = true },
    onlyMine = false,       -- only corpses you looted yourself
    lowSkill = false,       -- also remind when your skill is too low to skin it
    remindFor = 60,         -- seconds out of combat before a corpse counts as missed
    nag = true,             -- shake, sound and big text when you walk away
    bigText = true,
    sound = "ping",         -- keys from P:SoundList() (Sounds.lua)
    nagSound = "warning",
    doneSound = "coins",
    tooltip = true,         -- skill needed vs yours on corpse tooltips
    scale = 1,
    position = { "BOTTOM", 0, 230 },
}

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

local function Dispatch(list, ...)
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then geterrorhandler()(err) end
    end
end

-- Returns false when the client doesn't have the event (soft targeting on
-- older clients), instead of erroring like RegisterEvent does.
function P:On(event, fn)
    if not handlers[event] then
        if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then return false end
        if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
        handlers[event] = {}
    end
    table.insert(handlers[event], fn)
    return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    Dispatch(handlers[event], ...)
end)

-- Messages between Pelt's own files.
local listeners = {}
function P:Listen(msg, fn)
    listeners[msg] = listeners[msg] or {}
    table.insert(listeners[msg], fn)
end

function P:Send(msg, ...)
    if listeners[msg] then Dispatch(listeners[msg], ...) end
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function NewStats()
    return { skinned = 0, missed = 0, items = 0, streak = 0, best = 0, skillups = 0 }
end

local function InitDB()
    PeltDB = type(PeltDB) == "table" and PeltDB or {}
    local db = PeltDB
    db.profile = type(db.profile) == "table" and db.profile or {}
    CopyDefaults(P.defaults, db.profile)
    -- NPC ID -> profession, learned from corpse tooltips. Lets Pelt remind
    -- you even when it never gets a look at the corpse after looting it.
    db.learned = type(db.learned) == "table" and db.learned or {}
    db.chars = type(db.chars) == "table" and db.chars or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?")
    db.chars[key] = type(db.chars[key]) == "table" and db.chars[key] or {}
    CopyDefaults(NewStats(), db.chars[key])

    P.db = db.profile
    P.learned = db.learned
    P.stats = db.chars[key]
    P.session = NewStats()
end

function P:ResetPosition()
    local d = self.defaults.position
    self.db.position = { d[1], d[2], d[3] }
    self:Send("LAYOUT")
end

function P:ResetStats()
    for k, v in pairs(NewStats()) do
        self.stats[k] = v
        self.session[k] = v
    end
    self:Send("STATS")
end

---------------------------------------------------------------------------
-- Stats
---------------------------------------------------------------------------

function P:CountDone(items, undoMiss)
    local n = 0
    for _, it in ipairs(items or {}) do n = n + (it.count or 0) end
    for _, s in ipairs({ self.stats, self.session }) do
        s.skinned = s.skinned + 1
        s.items = s.items + n
        s.streak = s.streak + 1
        if s.streak > s.best then s.best = s.streak end
        if undoMiss then s.missed = math.max(0, s.missed - 1) end
    end
    self:Send("STATS")
end

function P:CountMissed()
    for _, s in ipairs({ self.stats, self.session }) do
        s.missed = s.missed + 1
        s.streak = 0
    end
    self:Send("STATS")
end

function P:CountSkillUp(n)
    for _, s in ipairs({ self.stats, self.session }) do
        s.skillups = s.skillups + n
    end
    self:Send("STATS")
end

---------------------------------------------------------------------------
-- Chat and slash commands
---------------------------------------------------------------------------

function P:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffe8a23aPelt|r " .. msg)
end

function P:PrintStats()
    local s, ses = self.stats, self.session
    self:Print(("This session: %d skinned, %d missed, %d items, %d skill-ups."):format(
        ses.skinned, ses.missed, ses.items, ses.skillups))
    self:Print(("This character: %d skinned, %d missed, best streak %d, %d skill-ups."):format(
        s.skinned, s.missed, s.best, s.skillups))
end

local HELP = {
    "/pelt - settings",
    "/pelt test - preview the reminder",
    "/pelt move - move the reminder (again to lock)",
    "/pelt stats - what you've skinned and missed",
    "/pelt check - what Pelt can see on your target",
}

SLASH_PELT1 = "/pelt"
SlashCmdList.PELT = function(msg)
    msg = strtrim((msg or ""):lower())
    if msg == "test" or msg == "preview" then
        P.Toast:Demo()
    elseif msg == "move" or msg == "unlock" or msg == "lock" then
        P.Toast:ToggleMover()
    elseif msg == "stats" then
        P:PrintStats()
    elseif msg == "check" then
        P.Tracker:Diagnose()
    elseif msg == "help" or msg == "?" then
        for _, line in ipairs(HELP) do P:Print(line) end
    else
        P.Options:Toggle()
    end
end

P:On("ADDON_LOADED", function(name)
    if name == ADDON then InitDB() end
end)

P:On("PLAYER_LOGIN", function()
    P:Send("READY")
end)
