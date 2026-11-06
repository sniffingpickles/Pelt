--[[
    Pelt - professions
    The four professions that gather from corpses, your skill in each, and
    the skill a corpse of a given level needs.
]]

local _, P = ...
local C = P.Compat

local Profs = { order = { "skinning", "herbalism", "mining", "engineering" }, skills = {} }
P.Profs = Profs

-- `line` is the global string the corpse tooltip shows; `english` covers a
-- client without it. `spells` are the ranks, apprentice first.
Profs.info = {
    skinning = {
        name = "Skinning", skillLine = 393, line = "UNIT_SKINNABLE_LEATHER", english = "Skinnable",
        spells = { 8613, 8617, 8618, 10768, 32678, 50305 },
        verb = "Skin it", done = "Skinned", nag = "Skin the %s!",
        icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", color = "skinning",
    },
    herbalism = {
        name = "Herbalism", skillLine = 182, line = "UNIT_SKINNABLE_HERB", english = "Requires Herbalism",
        spells = { 2366, 2368, 3570, 11993, 28695, 50300 },
        verb = "Gather it", done = "Gathered", nag = "Gather from the %s!",
        icon = "Interface\\Icons\\Spell_Nature_NatureTouchGrow", color = "herbalism",
    },
    mining = {
        name = "Mining", skillLine = 186, line = "UNIT_SKINNABLE_ROCK", english = "Requires Mining",
        spells = { 2575, 2576, 3564, 10248, 29354, 50310 },
        verb = "Mine it", done = "Mined", nag = "Mine the %s!",
        icon = "Interface\\Icons\\Trade_Mining", color = "mining",
    },
    engineering = {
        name = "Engineering", skillLine = 202, line = "UNIT_SKINNABLE_BOLTS", english = "Requires Engineering",
        spells = { 4036, 4037, 4038, 12656, 30350, 51306 },
        verb = "Salvage it", done = "Salvaged", nag = "Salvage the %s!",
        icon = "Interface\\Icons\\Trade_Engineering", color = "engineering",
    },
}

-- The classic skill list only has names, and Herbalism's gathering spell is
-- called "Herb Gathering", so its skill line names are listed here.
local HERBALISM = {
    "Herbalism", "Kräuterkunde", "Herboristerie", "Herboristería", "Erbalismo",
    "Herborismo", "Травничество", "약초 채집", "草药学", "草藥學",
}

---------------------------------------------------------------------------
-- Corpse tooltip lines
---------------------------------------------------------------------------

local lines
local function BuildLines()
    lines = {}
    for key, info in pairs(Profs.info) do
        local text = _G[info.line]
        if type(text) == "string" and text ~= "" then lines[text] = key end
        lines[info.english] = key
    end
end

-- Tooltip line -> profession key, or nil.
function Profs.match(text)
    if not lines then BuildLines() end
    return lines[text]
end

---------------------------------------------------------------------------
-- Skill
---------------------------------------------------------------------------

function Profs:Scan()
    local skills = {}
    if GetProfessions and GetProfessionInfo then
        local a, b, c, d, e = GetProfessions()
        for _, index in pairs({ a, b, c, d, e }) do
            local name, _, rank, maxRank, _, _, skillLine, modifier = GetProfessionInfo(index)
            for key, info in pairs(self.info) do
                if skillLine == info.skillLine then
                    skills[key] = { rank = (rank or 0) + (modifier or 0), max = maxRank, name = name }
                end
            end
        end
    end
    if not next(skills) and GetNumSkillLines and GetSkillLineInfo then
        local byName = {}
        for key, info in pairs(self.info) do
            local spell = C.SpellName(info.spells[1])
            if spell then byName[spell] = key end
            byName[info.name] = key
        end
        for _, name in ipairs(HERBALISM) do byName[name] = "herbalism" end
        for i = 1, GetNumSkillLines() do
            local name, header, _, rank, _, modifier, maxRank = GetSkillLineInfo(i)
            local key = name and not header and byName[name]
            if key then
                skills[key] = { rank = (rank or 0) + (modifier or 0), max = maxRank, name = name }
            end
        end
    end
    -- Knowing a gathering spell proves the profession, just not the level.
    for key, info in pairs(self.info) do
        if not skills[key] then
            for _, id in ipairs(info.spells) do
                if C.Knows(id) then
                    skills[key] = { name = info.name }
                    break
                end
            end
        end
    end
    self.skills = skills
    P:Send("SKILLS")
end

function Profs:Has(key)
    return self.skills[key] ~= nil
end

function Profs:Rank(key)
    local s = self.skills[key]
    return s and s.rank
end

function Profs:Max(key)
    local s = self.skills[key]
    return s and s.max
end

function Profs:Name(key)
    local s = self.skills[key]
    return s and s.name or self.info[key].name
end

-- Skill needed to gather from a corpse of this level.
function Profs.Required(level)
    if type(level) ~= "number" or level < 1 then return nil end
    if level <= 10 then return 1 end
    if level <= 20 then return (level - 10) * 10 end
    return level * 5
end

-- Profession that a successful cast of this spell gathers with.
local castKeys
function Profs:FromCast(spellID)
    if not castKeys then
        castKeys = {}
        for key, info in pairs(self.info) do
            for _, id in ipairs(info.spells) do castKeys[id] = key end
            local name = C.SpellName(info.spells[1])
            if name then castKeys[name] = key end
        end
    end
    return castKeys[spellID] or castKeys[C.SpellName(spellID) or false]
end

local pending = false
local function QueueScan()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        Profs:Scan()
    end)
end

P:Listen("READY", function()
    Profs:Scan()
    P:On("SKILL_LINES_CHANGED", QueueScan)
    P:On("SPELLS_CHANGED", QueueScan)
    P:On("CHAT_MSG_SKILL", QueueScan)
    P:On("TRADE_SKILL_LIST_UPDATE", QueueScan)
end)
