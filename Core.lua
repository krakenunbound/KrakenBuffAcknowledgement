local addonName, Addon = ...
Addon.Core = Addon.Core or {}

local RP_MESSAGE_SET = 2

local DEFAULTS = {
    enabled = true,
    message = "I felt {buff} take root like a lantern in fog. The night is less sharp now — I owe you a quiet toast.",
    message1 = "I felt {buff} take root like a lantern in fog. The night is less sharp now — I owe you a quiet toast.",
    message2 = "Your {buff} arrived unasked and unearned. I name it a kindness of the old kind, and I will not forget the hand that gave it.",
    message3 = "Hold. {buff} just walked into my marrow. If the gods keep a ledger, let them mark your name beside mine.",
    message4 = "A traveler's blessing: {buff}. I am not too proud to whisper thanks across the dark. Walk safely, gift-giver.",
    message5 = "{buff} sits on my shoulders like borrowed armor. When next our roads cross, the first drink is yours, though you may never know why.",
    responseMode = "random",
    replyDelay = 10,
    typingMode = "fixed",
    typingMin = 8,
    typingMax = 14,
    interSendGap = 3,
    cooldownDelay = 60,
    debugMode = false,
    excludeGroup = false,
    excludeGuild = false,
    watchNearby = true,
    messageSetVersion = RP_MESSAGE_SET,
    behaviorVersion = 5,
}

DB_BuffResponder = DB_BuffResponder or {}

local function InitializeSettings()
    for key, value in pairs(DEFAULTS) do
        if DB_BuffResponder[key] == nil then
            DB_BuffResponder[key] = value
        end
    end

    if DB_BuffResponder.messageSetVersion ~= RP_MESSAGE_SET then
        DB_BuffResponder.message = DEFAULTS.message
        DB_BuffResponder.message1 = DEFAULTS.message1
        DB_BuffResponder.message2 = DEFAULTS.message2
        DB_BuffResponder.message3 = DEFAULTS.message3
        DB_BuffResponder.message4 = DEFAULTS.message4
        DB_BuffResponder.message5 = DEFAULTS.message5
        DB_BuffResponder.responseMode = "random"
        DB_BuffResponder.messageSetVersion = RP_MESSAGE_SET
    end

    if DB_BuffResponder.behaviorVersion ~= 5 then
        if DB_BuffResponder.behaviorVersion ~= 3 and DB_BuffResponder.behaviorVersion ~= 4 then
            DB_BuffResponder.excludeGroup = false
            DB_BuffResponder.excludeGuild = false
        end
        if DB_BuffResponder.watchNearby == nil then
            DB_BuffResponder.watchNearby = true
        end
        DB_BuffResponder.behaviorVersion = 5
    end
    Addon.Timing.Normalize(DB_BuffResponder)
end

local frame = CreateFrame("Frame")

local playerName = GetUnitName("player", true) or UnitName("player")
local playerRealm = GetRealmName()
local playerFullName = playerName

local graceGen = 0
local lastAuraAt = 0
local inWorld = false
local lastInstanceKey

local function RefreshPlayer()
    playerName = Addon.Control.FullPlayerName("player") or GetUnitName("player", true) or UnitName("player")
    playerRealm = GetRealmName()
    playerFullName = playerName
    Addon.Control.Initialize(playerName, playerFullName)
    Addon.Control.RebuildSpellMap()
    Addon.Persona.Initialize()
end

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName == addonName then
            InitializeSettings()
            RefreshPlayer()
            Addon.View.Initialize()
            print("|cFF00FF00Kraken Buff Acknowledgement|r loaded. Type /kba for options.")
            Addon.Control.ApplyFriendlyPlates()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        inWorld = true
        RefreshPlayer()
        Addon.Control.ApplyFriendlyPlates()
        local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
        local key = tostring(instanceType or "") .. ":" .. tostring(instanceID or "")
        local instanceChanged = lastInstanceKey ~= nil and key ~= lastInstanceKey
        local firstEntry = lastInstanceKey == nil
        lastInstanceKey = key
        -- Layer hops also fire this event. Wiping on those cancels in-flight thanks
        -- and snapshots the new buff as "already present".
        if isLogin or isReload or firstEntry or instanceChanged then
            Addon.Control.BeginZoneTransition()
            Addon.Control.SetSuppressReplies(true)
            Addon.Control.SnapshotExistingAuras()
            graceGen = graceGen + 1
            local gen = graceGen
            local earliest = GetTime() + 5
            lastAuraAt = GetTime()
            local function FinishBaseline()
                if gen ~= graceGen or not inWorld then return end
                local wait = math.max(earliest, lastAuraAt + 1) - GetTime()
                if wait > 0 then C_Timer.After(wait, FinishBaseline); return end
                Addon.Control.SnapshotExistingAuras()
                Addon.Control.SetSuppressReplies(false)
            end
            C_Timer.After(5, FinishBaseline)
        else
            Addon.Control.ScanPlayerAuras("resolve")
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        inWorld = false
        graceGen = graceGen + 1
        Addon.Control.BeginZoneTransition()
        Addon.Control.SetSuppressReplies(true)
        lastInstanceKey = nil
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        Addon.Control.HandleWhisperInform(...)
    elseif event == "CHAT_MSG_SYSTEM" then
        Addon.Control.HandleSystemChat(...)
    elseif event == "UNIT_AURA" then
        local unit, updateInfo = ...
        Addon.Control.ObserveAuraEvent(unit, updateInfo, inWorld)
        if inWorld and (not issecretvalue or not issecretvalue(unit)) and unit == "player" then
            lastAuraAt = GetTime()
            Addon.Control.HandleUnitAura(updateInfo)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellId = ...
        Addon.Control.HandleSpellCast(unit, spellId)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        Addon.Control.HandleNameplate(unit)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Addon.Control.ScanPlayerAuras("resolve")
    elseif event == "PLAYER_LOGOUT" then
        Addon.Control.RestoreFriendlyPlates()
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_LOGOUT")
if frame.RegisterUnitEvent then
    frame:RegisterUnitEvent("UNIT_AURA", "player")
else
    frame:RegisterEvent("UNIT_AURA")
end
frame:SetScript("OnEvent", OnEvent)

function Addon.Core.GetSettings()
    return DB_BuffResponder
end

function Addon.Core.GetPlayerInfo()
    return playerName, playerRealm, playerFullName
end

function Addon.Core.ResetSettings()
    for key, value in pairs(DEFAULTS) do
        DB_BuffResponder[key] = value
    end
    Addon.Timing.Normalize(DB_BuffResponder)
end

function KBA_OnAddonCompartmentClick()
    if Addon.View and Addon.View.ShowStatus then
        Addon.View.ShowStatus()
    end
end
