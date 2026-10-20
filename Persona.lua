local addonName, Addon = ...
Addon.Persona = Addon.Persona or {}

local skyborne = {
    "May the winds remember your name.",
    "The ley remembers kindness.",
    "Walk light, as the high airs do.",
}

local profiles = {
    Human = {
        "A fine courtesy, and returned in kind.",
        "You have my word—I will remember it.",
        "May good fortune find you as well.",
    },
    Dwarf = {
        "By my beard, that is a fine kindness.",
        "Stone and steel, I owe you one.",
        "May your tankard stay full.",
    },
    NightElf = {
        "May Elune light your path.",
        "The old groves remember kindness.",
        "The stars favor your road.",
    },
    Gnome = {
        "A most efficient kindness.",
        "Marvelous. Precisely what I needed.",
        "That should improve my odds considerably.",
    },
    Draenei = {
        "May the naaru bless your path.",
        "Your kindness will be remembered.",
        "May the Light guide you.",
    },
    Orc = {
        "You have my respect.",
        "Your strength honors us both.",
        "I will not waste this gift.",
    },
    Tauren = {
        "May the Earth Mother walk with you.",
        "Your kindness strengthens the herd.",
        "Walk in balance.",
    },
    Troll = {
        "Ya got my thanks.",
        "Dis be a good deed.",
        "May da spirits favor ya.",
    },
    Undead = {
        "A rare kindness in a world of rot.",
        "The dead do not forget.",
        "I will remember this, for what memory is worth.",
    },
    Scourge = {
        "A rare kindness in a world of rot.",
        "The dead do not forget.",
        "I will remember this, for what memory is worth.",
    },
    BloodElf = {
        "Your courtesy does you credit.",
        "I shall remember this kindness.",
        "A refined gift, indeed.",
    },
    Goblin = {
        "Now that is a return on investment.",
        "Efficient. I like it.",
        "I will put this in the profit column.",
    },
    Worgen = {
        "A fine favor. I will not forget it.",
        "The pack remembers kindness.",
        "Much appreciated.",
    },
    Skyborne = skyborne,
    HighOrder = skyborne,
    Windshaper = skyborne,
    Highborne = skyborne,
    Shendorei = skyborne,
    ShenDorei = skyborne,
}

local fallback = {
    "Your kindness will be remembered.",
    "I will put this gift to good use.",
    "You have my gratitude.",
}

local classFragments = {
    WARRIOR = {"I will carry this kindness into the next battle."},
    MAGE = {"May your own spellwork find a willing world."},
    PRIEST = {"May kindness return to you in your hour of need."},
    DRUID = {"May the living world shelter your road."},
    PALADIN = {"I will strive to be worthy of this kindness."},
    SHAMAN = {"May the spirits remember this good deed."},
    WARLOCK = {"A freely given gift is a rare thing. I remember it."},
    HUNTER = {"May your path be clear and your watch untroubled."},
    ROGUE = {"I remember a favor, even from the shadows."},
}
local function PublicString(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return type(value) == "string" and value or nil
end
local profile
local lastFragment

local function Pick(list)
    if #list == 1 then
        return list[1]
    end
    local choice
    repeat
        choice = list[math.random(1, #list)]
    until choice ~= lastFragment
    lastFragment = choice
    return choice
end

local function RaceFragments(raceToken)
    if not raceToken then
        return fallback
    end
    if profiles[raceToken] then
        return profiles[raceToken]
    end
    local compact = raceToken:gsub("[%s'_%-]", "")
    if profiles[compact] then
        return profiles[compact]
    end
    if raceToken:lower():find("sky", 1, true) or raceToken:lower():find("wind", 1, true) then
        return skyborne
    end
    return fallback
end

function Addon.Persona.Initialize()
    local _, raceToken = UnitRace("player")
    local faction = UnitFactionGroup("player") or "Neutral"
    local sex = UnitSex("player")
    local className, classToken = UnitClass("player")

    className, classToken = PublicString(className), PublicString(classToken)
    profile = {
        race = raceToken or "Unknown",
        faction = faction,
        gender = sex == 3 and "female" or "male",
        class = classToken or className or "Unknown",
        fragments = RaceFragments(raceToken),
        classFragments = classToken and classFragments[classToken] or nil,
    }
end

function Addon.Persona.GetProfile()
    if not profile then
        Addon.Persona.Initialize()
    end
    return profile
end

function Addon.Persona.Decorate(message)
    local current = Addon.Persona.GetProfile()

    -- Most responses stay clean; the occasional voice fragment makes the
    -- character feel consistent without making every whisper formulaic.
    if math.random(1, 100) > 35 then
        return message
    end

    local fragments = current.fragments
    if current.classFragments and math.random(1, 2) == 1 then fragments = current.classFragments end
    return message .. " " .. Pick(fragments)
end
