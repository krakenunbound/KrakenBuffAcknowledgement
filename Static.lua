local addonName, Addon = ...
Addon.Static = Addon.Static or {}

-- Rank-1 IDs; combat log matches on localized spell name, so group versions share a feeling pool.
-- Rank-1 IDs used for localized name lookup at load.
Addon.Static.BuffSpells = {
    MARK = 1126,
    GOTW = 21849,
    THORNS = 467,
    AI = 1459,
    BRILLIANCE = 23028,
    MIGHT = 19740,
    GB_MIGHT = 25782,
    KINGS = 20217,
    GB_KINGS = 25898,
    WIS = 19742,
    GB_WIS = 25894,
    FORT = 1243,
    PRAYER_FORT = 21562,
    BREATH = 5697,
    WATERWALK = 546,
    AMPLIFY = 1008,
    DAMPEN = 604,
    SPIRIT = 14752,
    PRAYER_SPIRIT = 27681,
}

-- GetPlayerAuraBySpellID matches exact rank. City buffers use rank 4-7, not rank 1.
Addon.Static.BuffSpellRanks = {
    wild = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 },
    thorns = { 467, 782, 1075, 8914, 9756, 9910 },
    intellect = { 1459, 1460, 1461, 10156, 10157, 23028 },
    might = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916 },
    kings = { 20217, 25898 },
    wisdom = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918 },
    fortitude = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 },
    breath = { 5697, 131 },
    waterwalk = { 546 },
    spirit = { 14752, 14818, 14819, 27841, 27681 },
    amplify = { 1008, 8455, 10169, 10170 },
    dampen = { 604, 8450, 8451, 10173, 10174 },
}

Addon.Static.SpellFeelings = {
    MARK = "wild",
    GOTW = "wild",
    THORNS = "thorns",
    AI = "intellect",
    BRILLIANCE = "intellect",
    MIGHT = "might",
    GB_MIGHT = "might",
    KINGS = "kings",
    GB_KINGS = "kings",
    WIS = "wisdom",
    GB_WIS = "wisdom",
    FORT = "fortitude",
    PRAYER_FORT = "fortitude",
    BREATH = "breath",
    WATERWALK = "waterwalk",
    AMPLIFY = "amplify",
    DAMPEN = "dampen",
    SPIRIT = "spirit",
    PRAYER_SPIRIT = "spirit",
}

-- English fallbacks so a missing spell lookup at load cannot empty the whitelist.
Addon.Static.EnglishNames = {
    wild = { "Mark of the Wild", "Gift of the Wild" },
    thorns = { "Thorns" },
    intellect = { "Arcane Intellect", "Arcane Brilliance" },
    might = { "Blessing of Might", "Greater Blessing of Might" },
    kings = { "Blessing of Kings", "Greater Blessing of Kings" },
    wisdom = { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
    fortitude = { "Power Word: Fortitude", "Prayer of Fortitude" },
    breath = { "Unending Breath", "Water Breathing" },
    waterwalk = { "Water Walking" },
    spirit = { "Divine Spirit", "Prayer of Spirit" },
    amplify = { "Amplify Magic" },
    dampen = { "Dampen Magic" },
}

-- Scroll effects are item-cast spells, so their spell IDs vary by rank and
-- are easier to recognize by their localized effect name. These patterns are
-- intentionally mapped to the same feelings as the equivalent class buffs.
Addon.Static.ScrollPatterns = {
    { text = "Scroll of Strength", pool = "might" },
    { text = "Scroll of Agility", pool = "wild" },
    { text = "Scroll of Intellect", pool = "intellect" },
    { text = "Scroll of Spirit", pool = "spirit" },
    { text = "Scroll of Stamina", pool = "fortitude" },
    { text = "Scroll of Protection", pool = "fortitude" },
    { text = "Scroll of Nature Resistance", pool = "fortitude" },
    { text = "Scroll of Shadow Protection", pool = "fortitude" },
}

-- Readable fantasy thanks. Never name the spell. No clock-talk.
Addon.Static.FeelingPools = {
    waterwalk = {
        "You have my thanks. The water feels willing to bear my steps.",
        "My thanks. The river has offered me a road across its back.",
        "I am grateful. Even the waves seem ready to hold me up.",
        "You have my thanks. My road need not end at the water's edge.",
    },
    spirit = {
        "You have my thanks. A quiet strength has settled in my spirit.",
        "My thanks. My resolve feels renewed, like a lantern freshly tended.",
        "I am grateful. There is a steadiness within me that was missing before.",
        "You have my thanks. My spirit feels rested for the road ahead.",
    },
    wild = {
        "You have my thanks. The wild just leaned into my bones — I feel quicker and hardier.",
        "My thanks. I feel the forest's favor upon me.",
        "I am grateful. A wild strength woke in me. May your road be kind.",
        "You have my thanks, traveler. I feel as if the woods themselves walk with me.",
        "Bless you. I feel livelier, like a creature of the green places.",
        "My thanks. The wild has touched my blood. Walk safely.",
        "I owe you a kindness. I feel hardy as old oak now.",
        "You have my thanks. I am more of the wild than I was a breath ago.",
    },
    thorns = {
        "You have my thanks. My skin prickles as if thorns keep watch.",
        "My thanks. Whoever strikes me now will feel a sting in return.",
        "I am grateful. A sharp ward sits on me — I feel safer for it.",
        "Bless you. I feel guarded, as though a briar has taken my side.",
        "You have my thanks. There is a warning in my flesh now, and I welcome it.",
        "My thanks. I feel less easy to touch. Travel well.",
        "I owe you a kindness. Let them come close — they will remember.",
        "You have my thanks. I feel armed in a quiet, thorny way.",
    },
    intellect = {
        "You have my thanks. The fog in my mind has lifted — I can think clearly again.",
        "My thanks. My thoughts feel bright as lantern-light.",
        "I am grateful. A sharpness has come to my wits.",
        "Bless you. I feel awake in the mind, and that is no small mercy.",
        "You have my thanks. The clutter in my head has found its order.",
        "My thanks. I see the next steps more clearly now.",
        "I owe you a kindness. My thoughts run true again.",
        "You have my thanks. It feels as if a window opened behind my eyes.",
    },
    amplify = {
        "You have my thanks. Magic feels nearer, as if it will take more readily.",
        "My thanks. I feel more open to spellwork.",
        "I am grateful. The unseen sits closer to my skin.",
        "Bless you. I feel attuned. May your path be light.",
    },
    dampen = {
        "You have my thanks. I feel shielded from stray magics.",
        "My thanks. Spells should have a harder time finding me.",
        "I am grateful. A hush has settled over the part of me that hexes like to shout at.",
        "Bless you. I feel padded against the next curse. Walk well.",
    },
    might = {
        "You have my thanks. Strength has settled in my arms.",
        "My thanks. I feel as though I could swing a heavier blade.",
        "I am grateful. Power just took a seat in my shoulders.",
        "Bless you. The tired in my limbs has stepped back.",
        "You have my thanks. There is iron in my hands now.",
        "My thanks. I feel able — truly able. That is no small gift.",
        "I owe you a kindness. My blows will land with more weight.",
        "You have my thanks. The fight in me is louder. Stay safe.",
    },
    kings = {
        "You have my thanks. I feel favored, as if fortune itself took my side.",
        "My thanks. I stand a little taller for your blessing.",
        "I am grateful. A quiet crown of luck has settled on me.",
        "Bless you. I feel more myself — the better shape of me.",
        "You have my thanks. I feel chosen, in a small and careful way.",
        "My thanks. Whatever you laid upon me, I feel whole.",
        "I owe you a kindness. I will try to deserve this favor.",
        "You have my thanks. I feel lifted. Walk well.",
    },
    wisdom = {
        "You have my thanks. A calm well has filled in my spirit.",
        "My thanks. I feel wiser, and less hurried.",
        "I am grateful. Quiet strength has settled in me.",
        "Bless you. My spirit feels full, as if I have more to give.",
        "You have my thanks. Patience came with your gift, and I needed it.",
        "My thanks. I feel clear-headed and ready.",
        "I owe you a kindness. The long work looks kinder now.",
        "You have my thanks. A lantern of calm lit in my chest. Be well.",
    },
    fortitude = {
        "You have my thanks. I feel sturdier — harder to knock from my feet.",
        "My thanks. There is a stone-steadiness in my chest now.",
        "I am grateful. I feel as if I can take a blow and remain standing.",
        "Bless you. I feel less breakable on this road.",
        "You have my thanks. Endurance has sat down beside my heart.",
        "My thanks. I feel stout as a door that does not open on the first knock.",
        "I owe you a kindness. The next strike will have to work for it.",
        "You have my thanks. I feel ready for whatever comes. Travel safe.",
    },
    breath = {
        "You have my thanks. The water no longer frightens my lungs.",
        "My thanks. Breath comes easy, even for the deep.",
        "I am grateful. I feel at ease beneath the surface already.",
        "Bless you. The fear of drowning has stepped back.",
        "You have my thanks. Air is no longer a bargain I must beg for.",
        "My thanks. I could walk a river's story and finish it.",
        "I owe you a kindness. My chest has stopped counting. Be well.",
        "You have my thanks. I feel ready for deep water. Stay safe.",
    },
}

-- Unused. Kept empty so old code that appends a closer stays readable.
Addon.Static.Closers = {}
