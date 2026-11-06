--[[
    Pelt - sounds
    Pelt's own sounds, a pick of the game's, and whatever EllesmereUI and
    SharedMedia packs bring. The profile saves a sound's key.
]]

local _, P = ...

local MEDIA = "Interface\\AddOns\\Pelt\\Media\\Sounds\\"

-- Made for Pelt. `fallback` plays when the client won't play the file.
local OWN = {
    { key = "pelt-chime", label = "Chime", file = "Chime.wav", fallback = 878 },
    { key = "pelt-rise",  label = "Rise",  file = "Rise.wav",  fallback = 878 },
    { key = "pelt-tick",  label = "Tick",  file = "Tick.wav",  fallback = 120 },
    { key = "pelt-bell",  label = "Bell",  file = "Bell.wav",  fallback = 3175 },
    { key = "pelt-knock", label = "Knock", file = "Knock.wav", fallback = 1212 },
    { key = "pelt-nudge", label = "Nudge", file = "Nudge.wav", fallback = 8959 },
}

-- The game's, by SOUNDKIT name. The first seven keep their 1.0 keys.
local GAME = {
    { key = "ping",      label = "Map ping",         kit = "MAP_PING", id = 3175 },
    { key = "chime",     label = "Quest complete",   kit = "IG_QUEST_LIST_COMPLETE", id = 878 },
    { key = "coins",     label = "Coins",            kit = "LOOT_WINDOW_COIN_SOUND", id = 120 },
    { key = "chain",     label = "Chain",            kit = "PUT_DOWN_SMALL_CHAIN", id = 1212 },
    { key = "whisper",   label = "Boss whisper",     kit = "UI_RAID_BOSS_WHISPER_WARNING", id = 37666 },
    { key = "alarm",     label = "Alarm clock",      kit = "ALARM_CLOCK_WARNING_3", id = 12889 },
    { key = "warning",   label = "Raid warning",     kit = "RAID_WARNING", id = 8959 },
    { key = "tell",      label = "Whisper",          kit = "TELL_MESSAGE", id = 3081 },
    { key = "ready",     label = "Ready check",      kit = "READY_CHECK", id = 8960 },
    { key = "emote",     label = "Boss emote",       kit = "RAID_BOSS_EMOTE_WARNING", id = 12197 },
    { key = "queue",     label = "Queue pop",        kit = "PVP_THROUGH_QUEUE", id = 8459 },
    { key = "role",      label = "Role check",       kit = "LFG_ROLE_CHECK", id = 17317 },
    { key = "gm",        label = "GM message",       kit = "GM_CHAT_WARNING", id = 15273 },
    { key = "anvil",     label = "Anvil",            kit = "ITEM_REPAIR", id = 7994 },
    { key = "reel",      label = "Fishing reel",     kit = "FISHING_REEL_IN", id = 3407 },
    { key = "tutorial",  label = "Tutorial",         kit = "TUTORIAL_POPUP", id = 7355 },
    { key = "friend",    label = "Friend online",    kit = "UI_BNET_TOAST", id = 18019 },
    { key = "quest",     label = "Quest pop-up",     kit = "UI_AUTO_QUEST_COMPLETE", id = 23404 },
    { key = "countdown", label = "Countdown",        kit = "UI_BATTLEGROUND_COUNTDOWN_TIMER", id = 25477 },
    { key = "control",   label = "Loss of control",  kit = "UI_LOSS_OF_CONTROL_START", id = 34468 },
    { key = "epic",      label = "Epic loot",        kit = "UI_EPICLOOT_TOAST", id = 31578 },
    { key = "dig",       label = "Dig site",         kit = "UI_DIG_SITE_COMPLETION_TOAST", id = 38326 },
    { key = "invasion",  label = "Invasion alert",   kit = "UI_GARRISON_TOAST_INVASION_ALERT", id = 44292 },
    { key = "mission",   label = "Mission complete", kit = "UI_GARRISON_TOAST_MISSION_COMPLETE", id = 44294 },
    { key = "recipe",    label = "New recipe",       kit = "UI_PROFESSIONS_NEW_RECIPE_LEARNED_TOAST", id = 73919 },
    { key = "worldq",    label = "World quest done", kit = "UI_WORLDQUEST_COMPLETE", id = 73277 },
    { key = "unwrap",    label = "Gift unwrap",      kit = "UI_STORE_UNWRAP", id = 64329 },
    { key = "celebrate", label = "Celebration",      kit = "TRADING_POST_UI_PURCHASE_CELEBRATION", id = 218231 },
}

P.SOUND_GROUPS = { "Pelt", "Game", "EllesmereUI", "SharedMedia" }

local list, byKey

local function Add(s, group)
    s.group = group
    list[#list + 1] = s
    byKey[s.key] = s
end

local function AddEllesmere(seen)
    if type(EllesmereUI) ~= "table" or type(EllesmereUI.BuildAlertSoundTables) ~= "function" then return end
    local ok, paths, names, order = pcall(EllesmereUI.BuildAlertSoundTables)
    if not (ok and type(paths) == "table" and type(order) == "table") then return end
    for _, k in ipairs(order) do
        local path = paths[k]
        if type(path) == "string" then
            seen[path:lower()] = true
            Add({ key = "eui:" .. k, label = type(names) == "table" and names[k] or k, path = path }, "EllesmereUI")
        end
    end
end

local function AddSharedMedia(seen)
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    local sounds = lsm and lsm.HashTable and lsm:HashTable("sound")
    if type(sounds) ~= "table" then return end
    local names = {}
    for name, value in pairs(sounds) do
        local dupe = type(value) == "string" and seen[value:lower()]
        if type(name) == "string" and name ~= "None" and value ~= 1 and not dupe then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        Add({ key = "lsm:" .. name, label = name, value = sounds[name] }, "SharedMedia")
    end
end

-- Every sound the pickers offer, grouped in P.SOUND_GROUPS order.
function P:SoundList()
    if list then return list end
    list, byKey = {}, {}
    Add({ key = "none", label = "None" })
    for _, s in ipairs(OWN) do
        s.path = MEDIA .. s.file
        Add(s, "Pelt")
    end
    for _, s in ipairs(GAME) do
        -- older clients don't have every sound
        if not SOUNDKIT or SOUNDKIT[s.kit] then Add(s, "Game") end
    end
    local seen = {}
    AddEllesmere(seen)
    AddSharedMedia(seen)
    return list
end

function P:Sound(key)
    self:SoundList()
    return byKey[key]
end

local function Play(s)
    if s.path then
        if not PlaySoundFile(s.path, "Master") and s.fallback then PlaySound(s.fallback, "Master") end
    elseif type(s.value) == "number" then
        PlaySound(s.value, "Master")
    elseif type(s.value) == "string" then
        PlaySoundFile(s.value, "Master")
    elseif s.id then
        PlaySound(SOUNDKIT and SOUNDKIT[s.kit] or s.id, "Master")
    end
end

function P:PlaySound(key)
    local s = self:Sound(key)
    -- a pack's broken path shouldn't break a reminder
    if s then pcall(Play, s) end
end

-- SharedMedia packs can register sounds after Pelt has built the list.
local owner = {}
P:Listen("READY", function()
    list = nil
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm and lsm.RegisterCallback then
        lsm.RegisterCallback(owner, "LibSharedMedia_Registered", function(_, kind)
            if kind == "sound" then list = nil end
        end)
    end
end)
