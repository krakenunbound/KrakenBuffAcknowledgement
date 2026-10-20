local addonName, Addon = ...
Addon.Control = Addon.Control or {}

local FeelingsBySpellId = {}
local FeelingsByName = {}
local PoolTokenBySpellId = {}
local PoolTokenByName = {}
local lastResponseByPool = {}
local playerCooldowns = {}
local scheduledWhispers = {}
local thankedAuras = {}
local presentSpells = {}
local presentPools = {}
local poolMisses = {}
local announcedPools = {}
local thankedPools = {}
local recentCasts = {}
local giftSeenAt = {}
local sendGen = 0
local suppressReplies = false
local playerName, playerFullName
local savedFriendPlates
local platesOwned = false
local observedInstances = {}
local diagnostics = {}
local pendingSources = {}
local diagnosticCounts = {}
local nameObservations = {}
local function Count(reason)
    diagnosticCounts[reason] = (diagnosticCounts[reason] or 0) + 1
end

local lastScanError
local aimLog = {}
local whisperRetry = {}
local pulseStarted = false
local resolveTicker
local restorePools = {}
local poolExpiry = {}
local lastAutomaticAttempt = -math.huge
local lookupExpired = {}
local pendingEcho = {}
local sendCounts = { attempts = 0, errors = 0, echoes = 0, unknown = 0 }

local function Record(message)
    local last = diagnostics[#diagnostics]
    if last and last.message == message then return end
    diagnostics[#diagnostics + 1] = { time = GetTime(), message = message }
    if #diagnostics > 20 then table.remove(diagnostics, 1) end
end

function Addon.Control.GetDiagnosticReport()
    local lines = {"Kraken Buff Acknowledgement 2.3.19 - diagnostic snapshot"}
    local function Add(line) lines[#lines + 1] = line end
    Add("Enabled: " .. tostring(DB_BuffResponder.enabled) .. "; baseline settling: " .. tostring(suppressReplies))
    Add("Typing: " .. tostring(DB_BuffResponder.typingMode) .. "; fixed delay: " .. tostring(DB_BuffResponder.replyDelay) .. "; cooldown: " .. tostring(DB_BuffResponder.cooldownDelay))
    local _, build = GetBuildInfo()
    Add("Client build: " .. tostring(build) .. "; caster GUID API: " .. tostring(C_UnitAuras and type(C_UnitAuras.GetAuraCasterGUID) == "function"))
    Add("WHISPER attempts: " .. sendCounts.attempts .. "; API errors: " .. sendCounts.errors .. "; outgoing echoes: " .. sendCounts.echoes .. "; unknown/no echo: " .. sendCounts.unknown)
    Add("An API attempt or outgoing echo does not confirm recipient delivery.")
    local names={};for name in pairs(diagnosticCounts) do names[#names+1]=name end;table.sort(names)
    for _,name in ipairs(names) do Add(name .. ": " .. diagnosticCounts[name]) end
    if lastScanError then Add("Last indexed scan error: " .. lastScanError) end
    local pendingCount=0
    for key, pending in pairs(pendingSources) do
        pendingCount=pendingCount+1
        Add("Pending caster: " .. tostring(key) .. "; expires in " .. math.max(0,math.floor(pending.expires-GetTime())) .. "s")
    end
    if pendingCount==0 then Add("No pending caster lookups.") end
    Add("Recent relevant caster name API snapshots (not display-name guesses):")
    for _,entry in ipairs(nameObservations) do Add(entry) end
    if #diagnostics==0 then Add("No matching buff decisions recorded since reload.") end
    for _,entry in ipairs(diagnostics) do Add(math.floor(GetTime()-entry.time) .. "s ago: " .. entry.message) end
    return table.concat(lines,"\n"):sub(1,16000)
end
function Addon.Control.ShowDiagnostics()
    local report=Addon.Control.GetDiagnosticReport()
    if Addon.DiagnosticWindow then Addon.DiagnosticWindow.Show(report) end
    print("|cFF00FF00Kraken Buff Acknowledgement:|r Diagnostic snapshot opened. Ctrl+A then Ctrl+C to copy; data retained.")
end

local CAST_WINDOW = 8.0
local MAX_RECENT = 24

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Usable(value)
    return not IsSecret(value) and value ~= nil
end

local function RestorePoolActive(key)
    local expires = restorePools[key]
    if expires and GetTime() >= expires then restorePools[key] = nil; return false end
    return expires ~= nil
end

local function RememberPoolExpiry(key, data)
    local expires = data and not IsSecret(data) and data.expirationTime
    if Usable(expires) and type(expires) == "number" and expires > GetTime() then
        poolExpiry[key] = expires
    elseif not poolExpiry[key] then poolExpiry[key] = GetTime() + 180 end
end

function Addon.Control.ObserveAuraEvent(unit, updateInfo, inWorld)
    Count("UNIT_AURA received")
    if IsSecret(unit) then Count("unit token restricted"); return end
    if unit ~= "player" then Count("non-player unit event"); return end
    Count("player UNIT_AURA received")
    if not inWorld then Count("event outside world"); return end
    if IsSecret(updateInfo) or type(updateInfo) ~= "table" then Count("update payload unavailable"); return end
    local added, updated = updateInfo.addedAuras, updateInfo.updatedAuraInstanceIDs
    if not IsSecret(added) and type(added)=="table" then Count("added aura batches") end
    if not IsSecret(updated) and type(updated)=="table" then Count("updated aura batches") end
end

local function PublicString(value)
    if IsSecret(value) or type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

-- The build-matched API returns unitName and unitServer. Preserve the full
-- character name as returned; never reinterpret the server as a surname.
local function Dehyphenate(name)
    local raw = PublicString(name)
    if not raw then return nil end
    raw = raw:match("^%s*(.-)%s*$")
    if raw == "" then return nil end
    return raw -- spaces, apostrophes and hyphens are identity, not separators to guess.
end

local function SpacedName(unitName, unitServer)
    if IsSecret(unitName) then return nil end
    local name, server = Dehyphenate(unitName), PublicString(unitServer)
    if not name then return nil end
    -- unitName is an authoritative engine address, not necessarily a display name
    -- containing a literal space. Retain it exactly; never fabricate a surname.
    if IsSecret(unitServer) and not name:find(" ", 1, true) then
        Count("routing component restricted")
        return nil
    end
    if not name:find(" ", 1, true) then Count("single-token canonical API name accepted") end
    local localServer = type(GetRealmName) == "function" and PublicString(GetRealmName()) or nil
    if server and server ~= "" and server ~= localServer then return name .. "-" .. server end
    return name
end

local function FullPlayerName(unit)
    if not unit then
        return nil
    end
    local ok, first, second = pcall(UnitName, unit)
    if ok then
        local spaced = SpacedName(first, second)
        if spaced then
            return spaced
        end
    end
    local shown = nil
    if GetUnitName then
        local okShown, value = pcall(GetUnitName, unit, true)
        if okShown then
            shown = Dehyphenate(value)
        end
    end
    if shown then return shown end
    return nil
end

local function MapName(name, pool, poolKey)
    if type(name) == "string" and name ~= "" and pool then
        FeelingsByName[name] = pool
        if poolKey then
            PoolTokenByName[name] = poolKey
        end
    end
end

local function SpellNameById(spellId)
    if not Usable(spellId) then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellId)
        if ok and PublicString(name) then
            return name
        end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
        if ok and not IsSecret(info) and type(info) == "table" and PublicString(info.name) then
            return info.name
        end
        if ok and PublicString(info) then
            return info
        end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellId)
        if ok and PublicString(name) then
            return name
        end
    end
    return nil
end

local function MapSpell(spellId, pool, poolKey)
    if pool and Usable(spellId) then
        FeelingsBySpellId[spellId] = pool
        if poolKey then
            PoolTokenBySpellId[spellId] = poolKey
        end
        MapName(SpellNameById(spellId), pool, poolKey)
    end
end

function Addon.Control.RebuildSpellMap()
    wipe(FeelingsBySpellId)
    wipe(FeelingsByName)
    wipe(PoolTokenBySpellId)
    wipe(PoolTokenByName)

    for key, spellId in pairs(Addon.Static.BuffSpells) do
        local poolKey = Addon.Static.SpellFeelings[key]
        MapSpell(spellId, poolKey and Addon.Static.FeelingPools[poolKey], poolKey)
    end

    if Addon.Static.BuffSpellRanks then
        for poolKey, ids in pairs(Addon.Static.BuffSpellRanks) do
            local pool = Addon.Static.FeelingPools[poolKey]
            for i = 1, #ids do
                MapSpell(ids[i], pool, poolKey)
            end
        end
    end

    for poolKey, names in pairs(Addon.Static.EnglishNames) do
        local pool = Addon.Static.FeelingPools[poolKey]
        for i = 1, #names do
            MapName(names[i], pool, poolKey)
        end
    end
end

Addon.Control.RebuildSpellMap()

local function GetCVarValue(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok then
            return value
        end
    end
    if GetCVar then
        local ok, value = pcall(GetCVar, name)
        if ok then
            return value
        end
    end
    return nil
end

local function SetCVarValue(name, value)
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, name, value)
        return
    end
    if SetCVar then
        pcall(SetCVar, name, value)
    end
end

function Addon.Control.ApplyFriendlyPlates()
    if not DB_BuffResponder or not DB_BuffResponder.enabled or not DB_BuffResponder.watchNearby then
        return
    end
    local current = GetCVarValue("nameplateShowFriends")
    if not platesOwned then
        savedFriendPlates = current
        platesOwned = true
    end
    if current ~= "1" then
        SetCVarValue("nameplateShowFriends", "1")
    end
end

function Addon.Control.RestoreFriendlyPlates()
    if platesOwned and savedFriendPlates and savedFriendPlates ~= "1" then
        SetCVarValue("nameplateShowFriends", savedFriendPlates)
    end
    platesOwned = false
end

local function IsPlayerInGroup(name)
    if not IsInGroup() then
        return false
    end
    local numGroupMembers = GetNumGroupMembers()
    for i = 1, numGroupMembers do
        local unit = (IsInRaid() and "raid" or "party") .. i
        if FullPlayerName(unit) == name then
            return true
        end
    end
    return false
end

local function IsPlayerInGuild(name)
    if not IsInGuild() then
        return false
    end
    local numGuildMembers = GetNumGuildMembers()
    for i = 1, numGuildMembers do
        local guildMemberName = GetGuildRosterInfo(i)
        if PublicString(guildMemberName) and Dehyphenate(guildMemberName) == name then
            return true
        end
    end
    return false
end

local function Pick(list, poolKey)
    if #list == 1 then
        return list[1]
    end
    local choice
    repeat
        choice = list[math.random(1, #list)]
    until choice ~= lastResponseByPool[poolKey]
    lastResponseByPool[poolKey] = choice
    return choice
end

local function GetScrollPool(spellName)
    if not spellName then
        return nil, nil
    end
    for i = 1, #Addon.Static.ScrollPatterns do
        local entry = Addon.Static.ScrollPatterns[i]
        if spellName:find(entry.text, 1, true) then
            return Addon.Static.FeelingPools[entry.pool], entry.pool
        end
    end
    return nil, nil
end

local function GetPoolForSpell(spellId, spellName)
    if Usable(spellId) and FeelingsBySpellId[spellId] then
        return FeelingsBySpellId[spellId], spellId
    end
    if Usable(spellName) then
        if FeelingsByName[spellName] then
            return FeelingsByName[spellName], spellName
        end
        return GetScrollPool(spellName)
    end
    return nil, nil
end

local function GetResponseMessage(spellId, spellName)
    local pool, poolKey = GetPoolForSpell(spellId, spellName)
    if pool and #pool > 0 then
        return Addon.Persona.Decorate(Pick(pool, poolKey))
    end
    return Addon.Persona.Decorate("You have my thanks. I feel better for your gift. Truly.")
end

function Addon.Control.BeginZoneTransition()
    sendGen = sendGen + 1
    wipe(scheduledWhispers)
    wipe(recentCasts)
    wipe(thankedAuras)
    for key in pairs(presentPools) do restorePools[key] = poolExpiry[key] or (GetTime() + 180) end
    wipe(presentPools)
    wipe(thankedPools)
    wipe(giftSeenAt)
    wipe(pendingSources)
    wipe(lookupExpired)
    wipe(pendingEcho)
    wipe(observedInstances)
    wipe(aimLog)
    whisperRetry = {}
    if resolveTicker then
        resolveTicker:Cancel()
        resolveTicker = nil
    end
end

function Addon.Control.SetSuppressReplies(value)
    suppressReplies = value and true or false
end

function Addon.Control.CombatLogDisabled()
    return true
end

local function AuraKey(sourceGUID, spellName)
    return tostring(sourceGUID or "") .. "\0" .. tostring(spellName or "")
end

-- Forever full names are "First Last". Do not split on space or treat the
-- last name as a realm. The whisper API takes one target string.
local function WhisperTarget(name)
    return Dehyphenate(name)
end

local function Whisper(targetName, message)
    local target = WhisperTarget(targetName)
    if not target or not message then
        return false
    end
    -- Preserve WHISPER and the existing API choice. Never retry an uncertain send.
    local send = SendChatMessage or (C_ChatInfo and C_ChatInfo.SendChatMessage)
    if type(send) ~= "function" then Record("Send unavailable: no chat API."); return false end
    sendCounts.attempts = sendCounts.attempts + 1
    local attempt = { target = target, message = message, gen = sendGen }
    pendingEcho[#pendingEcho + 1] = attempt
    Record("WHISPER API attempt: " .. target)
    local ok = pcall(send, message, "WHISPER", nil, target)
    if not ok then
        attempt.error = true
        attempt.message = nil
        sendCounts.errors = sendCounts.errors + 1
        Record("WHISPER API error; not retried.")
        table.remove(pendingEcho, #pendingEcho)
        return false
    end
    C_Timer.After(8, function()
        if attempt.gen ~= sendGen then return end
        if not attempt.echo and not attempt.error then
            sendCounts.unknown = sendCounts.unknown + 1
            Record("No outgoing echo observed; delivery unknown, not retried.")
        end
        for i = #pendingEcho, 1, -1 do
            if pendingEcho[i] == attempt then table.remove(pendingEcho, i) end
        end
        attempt.message = nil
    end)
    return true -- API request only, never delivery confirmation.
end

function Addon.Control.HandleWhisperInform(text, target)
    text, target = PublicString(text), WhisperTarget(target)
    if not text or not target then return end
    for _, attempt in ipairs(pendingEcho) do
        if attempt.gen == sendGen and not attempt.error and not attempt.echo
            and attempt.target == target and attempt.message == text then
            attempt.echo = true
            attempt.message = nil
            sendCounts.echoes = sendCounts.echoes + 1
            Record("Outgoing whisper echo observed; recipient delivery unconfirmed.")
            return
        end
    end
end

function Addon.Control.HandleSystemChat(msg)
    -- Do not interpret unrelated/localized system text as a reason to resend.
end

function Addon.Control.SendTestWhisper()
    local message = Addon.Persona.Decorate("You have my thanks. This is a test whisper from Buff Acknowledgement.")
    if UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
        local target = FullPlayerName("target") or GetUnitName("target", true) or UnitName("target")
        local sent = Whisper(target, message)
        if sent then
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Sent a test whisper to " .. tostring(WhisperTarget(target) or target) .. ".")
        end
        return
    end
    print("|cFF00FF00Kraken Buff Acknowledgement:|r Target another player, then /kba test.")
    print("|cFF00FF00Would send:|r " .. message)
end

local function Note(msg)
    Record(msg)
    print("|cFF00FF00Kraken Buff Acknowledgement:|r " .. msg)
end

local function Debug(msg)
    Record(msg)
    if DB_BuffResponder.debugMode then
        print("|cFF00FF00BuffResponder:|r " .. msg)
    end
end

local function GiftKey(spellId, spellName)
    if Usable(spellId) and PoolTokenBySpellId[spellId] then
        return PoolTokenBySpellId[spellId]
    end
    if Usable(spellName) and PoolTokenByName[spellName] then
        return PoolTokenByName[spellName]
    end
    return nil
end

local function MarkGiftSeen(spellId, spellName)
    local key = GiftKey(spellId, spellName)
    if not key then
        return GetTime()
    end
    if not giftSeenAt[key] then
        giftSeenAt[key] = GetTime()
    end
    return giftSeenAt[key]
end

local function RemainingDelay(spellId, spellName)
    -- A full typing pause starts when the recipient is resolved, even after a slow lookup.
    return Addon.Timing.Delay(DB_BuffResponder)
end

local function ScheduleWhisper(targetName, delay, spellId, spellName, casterGUID)
    local currentTime = GetTime()
    local whisperName = WhisperTarget(targetName)
    if not whisperName then return end
    local identityKey = PublicString(casterGUID) or whisperName
    if not DB_BuffResponder.debugMode and playerCooldowns[identityKey] and currentTime < playerCooldowns[identityKey] then
        Count("per-player cooldown suppressed")
        Debug("Cooldown active for " .. tostring(whisperName))
        return
    end
    if scheduledWhispers[identityKey] then
        Count("recipient already queued")
        return
    end

    Count("response queued")
    scheduledWhispers[identityKey] = true
    local poolKey = GiftKey(spellId, spellName)
    if poolKey then
        thankedPools[poolKey] = true
    end
    local gen = sendGen
    -- Immutable name/GUID snapshot: later target changes never alter the queued recipient.
    local recipient = { name = whisperName, guid = PublicString(casterGUID) }
    local wait = delay
    if wait == nil then
        wait = RemainingDelay(spellId, spellName)
    end
    local shown = math.floor(wait + 0.5)
    if shown <= 0 then
        Note("Thanking " .. tostring(whisperName) .. " now.")
    else
        Note("Thanking " .. tostring(whisperName) .. " in " .. tostring(shown) .. "s.")
    end
    local function SendQueued()
        if gen ~= sendGen then
            return
        end
        if not DB_BuffResponder.enabled or suppressReplies then scheduledWhispers[identityKey] = nil; return end
        local gapWait = lastAutomaticAttempt + DB_BuffResponder.interSendGap - GetTime()
        if gapWait > 0 then C_Timer.After(gapWait, SendQueued); return end
        scheduledWhispers[identityKey] = nil
        if DB_BuffResponder.excludeGroup and IsPlayerInGroup(whisperName) then return end
        if DB_BuffResponder.excludeGuild and IsPlayerInGuild(whisperName) then return end
        if playerCooldowns[identityKey] and GetTime() < playerCooldowns[identityKey] then return end
        lastAutomaticAttempt = GetTime()
        -- Throttle attempts including API errors, without blind resend.
        playerCooldowns[identityKey] = GetTime() + math.max(3, DB_BuffResponder.cooldownDelay)
        local message = GetResponseMessage(spellId, spellName)
        if Whisper(recipient.name, message) then
            playerCooldowns[identityKey] = GetTime() + math.max(3, DB_BuffResponder.cooldownDelay)
            Note("Whisper submitted for " .. tostring(whisperName) .. ".")
        end
    end
    C_Timer.After(wait, SendQueued)
end

local function ConsiderBuff(sourceGUID, sourceName, sourceIsPlayerUnit, spellId, spellName)
    if not DB_BuffResponder.enabled then
        return
    end

    local pool = GetPoolForSpell(spellId, spellName)
    if not pool then
        return
    end
    local stableKey = GiftKey(spellId, spellName)
    if stableKey and thankedPools[stableKey] then return end

    if not Usable(sourceName) or sourceName == "" then
        Debug("Saw '" .. tostring(spellName or spellId) .. "' but no caster name.")
        return
    end

    local playerGUID = PublicString(UnitGUID("player"))
    local sourceIsSelf = sourceGUID and playerGUID and sourceGUID == playerGUID
    if not sourceIsSelf then
        local incoming = WhisperTarget(sourceName)
        if incoming and (incoming == WhisperTarget(playerName) or incoming == WhisperTarget(playerFullName)) then
            sourceIsSelf = true
        end
    end

    if type(sourceGUID) == "string" and sourceGUID:find("^Player%-") then
        sourceIsPlayerUnit = true
    end

    if sourceIsSelf and not DB_BuffResponder.debugMode then
        Record("Skipped self buff: " .. tostring(spellName or spellId))
        return
    end

    if not sourceIsSelf and not sourceIsPlayerUnit and not DB_BuffResponder.debugMode then
        return
    end

    local auraKey = AuraKey(sourceGUID, spellName or spellId)
    if thankedAuras[auraKey] then
        Record("Already handled: " .. tostring(spellName or spellId))
        return
    end

    if suppressReplies then
        thankedAuras[auraKey] = GiftKey(spellId, spellName) or true
        return
    end

    local cleanName = WhisperTarget(sourceName) or sourceName
    Debug("Received '" .. tostring(spellName) .. "' from " .. cleanName)

    if sourceIsSelf and DB_BuffResponder.debugMode then
        thankedAuras[auraKey] = GiftKey(spellId, spellName) or true
        ScheduleWhisper(playerName, RemainingDelay(spellId, spellName), spellId, spellName)
        return
    end

    if DB_BuffResponder.excludeGroup and IsPlayerInGroup(cleanName) then
        return
    end
    if DB_BuffResponder.excludeGuild and IsPlayerInGuild(cleanName) then
        return
    end

    thankedAuras[auraKey] = GiftKey(spellId, spellName) or true
    ScheduleWhisper(sourceName, RemainingDelay(spellId, spellName), spellId, spellName, sourceGUID)
end

local function SafeUnitIsPlayer(unit)
    local ok, value = pcall(UnitIsPlayer, unit)
    return ok and Usable(value) and value
end

local function IsPlayerGuid(guid)
    return PublicString(guid) and guid:find("^Player%-") ~= nil
end

local function UnitPlayerName(unit)
    if not unit then
        return nil, nil, false
    end
    local existsOk, exists = pcall(UnitExists, unit)
    if not existsOk or not Usable(exists) or not exists then
        return nil, nil, false
    end
    local name = FullPlayerName(unit)
    local guid = PublicString(UnitGUID(unit))
    if guid and not IsPlayerGuid(guid) then return nil, guid, false end
    local isPlayer = SafeUnitIsPlayer(unit) or IsPlayerGuid(guid)
    return name, guid, isPlayer and true or false
end

local function EachNearbyPlayer(fn)
    local units = { "target", "focus", "mouseover", "softfriend", "softenemy" }
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    elseif IsInGroup() then
        for i = 1, math.max(GetNumGroupMembers() - 1, 0) do
            units[#units + 1] = "party" .. i
        end
    end
    for i = 1, 40 do
        units[#units + 1] = "nameplate" .. i
    end
    local seen = {}
    for i = 1, #units do
        local unit = units[i]
        local name, guid, isPlayer = UnitPlayerName(unit)
        if name and isPlayer and not seen[guid or name] then
            seen[guid or name] = true
            fn(unit, name, guid)
        end
    end
end

local function NoteNearbyTargeting()
    local now = GetTime()
    EachNearbyPlayer(function(unit, name, guid)
        local ok, isMe = pcall(UnitIsUnit, unit .. "target", "player")
        if ok and Usable(isMe) and isMe and name then
            local last = aimLog[#aimLog]
            if not last or last.name ~= name or now - last.t > 0.4 then
                aimLog[#aimLog + 1] = { t = now, name = name, guid = guid, unit = unit }
            end
        end
    end)
    while #aimLog > 0 and now - aimLog[1].t > 10 do
        table.remove(aimLog, 1)
    end
end

local function UniqueAimer(since, untilTime)
    untilTime = untilTime or GetTime()
    local seen = {}
    local unique
    local count = 0
    for i = 1, #aimLog do
        local entry = aimLog[i]
        if entry.t >= since and entry.t <= untilTime then
            local key = entry.guid or entry.name
            if not seen[key] then
                seen[key] = true
                unique = entry
                count = count + 1
                if count > 1 then
                    return nil
                end
            end
        end
    end
    if count == 1 then
        return unique
    end
    return nil
end

local function BestAimer(seen)
    local best, bestDist
    for i = 1, #aimLog do
        local entry = aimLog[i]
        if entry.name then
            local dist = math.abs(entry.t - seen)
            if dist <= 3 and (not best or dist < bestDist) then
                best, bestDist = entry, dist
            end
        end
    end
    return best
end

local function CasterFromTooltip(spellId, spellName)
    if not C_TooltipInfo or not C_TooltipInfo.GetUnitBuff then
        return nil
    end
    local auraCasterType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.AuraCaster
    for i = 1, 80 do
        local ok, data = pcall(C_TooltipInfo.GetUnitBuff, "player", i)
        if not ok then
            return nil
        end
        if data == nil then
            break
        end
        if not IsSecret(data) and type(data) == "table" then
            local lines = data.lines
            if not IsSecret(lines) and type(lines) == "table" then
                local first = lines[1]
                local title = first and not IsSecret(first) and PublicString(first.leftText)
                local idMatch = Usable(data.id) and spellId and data.id == spellId
                local nameMatch = spellName and title and title:find(spellName, 1, true)
                if idMatch or nameMatch then
                    for li = 1, #lines do
                        local line = lines[li]
                        if not IsSecret(line) and type(line) == "table" then
                            local text = PublicString(line.leftText)
                            if text then
                                text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                                if auraCasterType and line.type == auraCasterType then
                                    local by = text:match("[Bb]y%s+(.+)$") or text
                                    by = by and Dehyphenate(by)
                                    if by then
                                        return by
                                    end
                                end
                                local by = text:match("[Cc]ast by%s+(.+)") or text:match("[Rr]eceived from%s+(.+)")
                                if by then
                                    by = Dehyphenate(by:gsub("[%.]+$", ""))
                                    if by then
                                        return by
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function SourceFromAura(data)
    if IsSecret(data) or type(data) ~= "table" then
        return nil
    end
    local sourceUnit = PublicString(data.sourceUnit)
    local sourceName, sourceGUID, isPlayer
    local id = Usable(data.auraInstanceID) and data.auraInstanceID or nil
    if type(id) == "number" and C_UnitAuras and type(C_UnitAuras.GetAuraCasterGUID) == "function" then
        local ok, guid = pcall(C_UnitAuras.GetAuraCasterGUID, "player", id)
        if not ok or IsSecret(guid) then
            Count("caster GUID restricted")
            Record("Authoritative caster GUID restricted; identity unresolved.")
            return nil, nil, false, nil, nil, true
        end
        guid = ok and PublicString(guid) or nil
        if guid and not IsPlayerGuid(guid) then
            Record("Authoritative caster is not a player; skipped.")
            return guid, nil, false, nil, nil, true
        end
        if guid and IsPlayerGuid(guid) then
            sourceGUID, isPlayer = guid, true
            local named, first, second = false, nil, nil
            if type(UnitNameFromGUID) == "function" then
                named, first, second = pcall(UnitNameFromGUID, guid)
            else Count("GUID naming API unavailable") end
            if named then
                local primary = PublicString(first)
                local secondary = IsSecret(second) and "<restricted>" or PublicString(second) or "<empty>"
                local observation = "UnitNameFromGUID: primary=" .. (primary or "<unavailable>") .. "; unitServer=" .. secondary
                if nameObservations[#nameObservations] ~= observation then
                    nameObservations[#nameObservations+1] = observation:sub(1,300)
                    if #nameObservations > 8 then table.remove(nameObservations,1) end
                end
                sourceName = SpacedName(first, second)
            end
            if sourceName then Count("direct caster resolved"); Record("Caster resolved directly by aura GUID.")
            else Count("caster name unresolved") end
        end
    end
    if not sourceName and sourceUnit then
        local name, guid, player = UnitPlayerName(sourceUnit)
        if not sourceGUID or (guid and sourceGUID == guid) then
            sourceName, sourceGUID, isPlayer = name, sourceGUID or guid, isPlayer or player
        end
    end
    if not isPlayer and Usable(data.isFromPlayerOrPlayerPet) and data.isFromPlayerOrPlayerPet then
        isPlayer = true
    end
    return sourceGUID, sourceName, isPlayer, Usable(data.spellId) and data.spellId or nil, Usable(data.name) and data.name or nil
end

local function AuraPresent(spellId, spellName)
    -- Forever marks these targeted lookups RequiresNonSecretAura. Never
    -- inspect protected values; an unavailable result stays unavailable.
    if C_UnitAuras then
        local lookups = {
            { fn = C_UnitAuras.GetPlayerAuraBySpellID, arg = spellId },
            { fn = C_UnitAuras.GetAuraDataBySpellName, arg = spellName, byName = true },
        }
        for _, lookup in ipairs(lookups) do
            if lookup.fn and Usable(lookup.arg) then
                local ok, data
                if lookup.byName then
                    ok, data = pcall(lookup.fn, "player", lookup.arg, "HELPFUL")
                else
                    ok, data = pcall(lookup.fn, lookup.arg)
                end
                if ok and not IsSecret(data) and type(data) == "table" then
                    return true, data
                end
            end
        end
    end
    return false, nil
end

local function EachHelpfulAura(fn)
    local complete = true
    for i = 1, 255 do
        local data
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, result = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok then
                Count("indexed scan API errors")
                lastScanError = PublicString(result) or "Error detail unavailable"
                Record("Indexed aura scan failed; using readable events and direct lookups.")
                return false
            end
            if IsSecret(result) then
                Count("indexed aura restricted")
                complete = false
            elseif result == nil then
                return complete
            elseif type(result) == "table" then
                data = result
            else
                complete = false
            end
        elseif UnitAura then
            local ok, name, _, _, _, _, _, source, _, _, spellId = pcall(UnitAura, "player", i, "HELPFUL")
            if not ok then return false end
            if IsSecret(name) or IsSecret(spellId) then
                complete = false
            elseif name == nil then
                return complete
            else
                data = { name = name, sourceUnit = source, spellId = spellId }
            end
        else
            Record("No supported aura scan API.")
            return false
        end
        if data then
            if Usable(data.spellId) or PublicString(data.name) then
                fn(data)
            else
                complete = false
            end
        end
    end
    return false
end

local function ResolveCastIdentity(cast)
    if not cast or not cast.unit then
        return cast and cast.name or nil
    end
    local name, guid, isPlayer = UnitPlayerName(cast.unit)
    if not name then
        return cast.name
    end
    local liveGuid = PublicString(UnitGUID(cast.unit))
    if cast.guid and liveGuid and liveGuid ~= cast.guid then
        return cast.name
    end
    cast.name = name
    cast.guid = guid or cast.guid
    cast.isPlayer = isPlayer or cast.isPlayer
    return cast.name
end

local function RememberCast(unit, spellId, spellName)
    local name, guid, isPlayer = UnitPlayerName(unit)
    -- Forever nameplates often populate after the cast event. Keep the token
    -- even without a name and read it on the next resolve pass.
    if guid and not isPlayer and not IsPlayerGuid(guid) then
        return
    end
    if isPlayer or guid or name or PublicString(unit) then
        if name then
            Record("Observed readable cast: " .. tostring(spellName or spellId) .. " by " .. name)
        else
            Record("Observed cast without a name yet: " .. tostring(spellName or spellId))
        end
        recentCasts[#recentCasts + 1] = {
            t = GetTime(),
            spellId = spellId,
            spellName = spellName,
            name = name,
            guid = guid,
            isPlayer = isPlayer,
            unit = unit,
        }
        while #recentCasts > MAX_RECENT do
            table.remove(recentCasts, 1)
        end
    end
end

local function MatchRecentCast(spellId, spellName)
    local now = GetTime()
    local seen = giftSeenAt[GiftKey(spellId, spellName)]
    if not seen or now - seen > CAST_WINDOW then
        return nil
    end
    local matches = {}
    for i = #recentCasts, 1, -1 do
        local cast = recentCasts[i]
        if now - cast.t > CAST_WINDOW then
            break
        end
        ResolveCastIdentity(cast)
        local sameSpell = (Usable(spellId) and cast.spellId == spellId)
            or (spellName and cast.spellName == spellName)
        if sameSpell and cast.name and math.abs(cast.t - seen) <= 3.0 then
            local key = cast.guid or cast.name
            if not matches[key] then
                matches[key] = cast
                matches[#matches + 1] = cast
            end
        end
    end
    if #matches == 1 then
        return matches[1]
    end
    if #matches > 1 then
        local aimer = UniqueAimer(seen - 2.0, seen + 2.0)
        if aimer then
            for i = 1, #matches do
                local cast = matches[i]
                if (aimer.guid and cast.guid and aimer.guid == cast.guid) or cast.name == aimer.name then
                    Record("Ambiguous casts; using the player who had you targeted.")
                    return cast
                end
            end
        end
        Record("Ambiguous matching casts; skipping inferred recipient.")
        return nil
    end
    return nil
end

local function HasUnresolvedCaster()
    local now = GetTime()
    for key, pending in pairs(pendingSources) do
        if now >= pending.expires then
            pendingSources[key] = nil
            lookupExpired[key] = true
            Record("Caster lookup expired; no reply sent.")
        else return true end
    end
    for poolKey in pairs(presentPools) do
        if not thankedPools[poolKey] and not lookupExpired[poolKey] then
            return true
        end
    end
    return false
end

local function EnsureResolveTicker()
    if resolveTicker then
        return
    end
    resolveTicker = C_Timer.NewTicker(0.25, function()
        if not DB_BuffResponder.enabled or not HasUnresolvedCaster() then
            resolveTicker:Cancel()
            resolveTicker = nil
            return
        end
        NoteNearbyTargeting()
        for i = 1, #recentCasts do
            ResolveCastIdentity(recentCasts[i])
        end
        Addon.Control.ScanPlayerAuras("resolve")
    end)
end

local function ClearThankedForSpell(spellId, spellName)
    local key = GiftKey(spellId, spellName) or spellName
    if key then pendingSources[key] = nil; lookupExpired[key] = nil end
    if spellName then pendingSources[spellName] = nil end
    local needle = tostring(spellName or spellId)
    for key, pool in pairs(thankedAuras) do
        if pool == spellName or key:sub(-#needle) == needle then
            thankedAuras[key] = nil
        end
    end
end

local ThankFromCastOrAura
ThankFromCastOrAura = function(spellId, spellName, data)
    local knownKey = GiftKey(spellId, spellName)
    local pending = knownKey and pendingSources[knownKey]
    if knownKey and (lookupExpired[knownKey] or (pending and GetTime() >= pending.expires)) then
        pendingSources[knownKey] = nil
        lookupExpired[knownKey] = true
        Record("Caster lookup expired; no reply sent.")
        return
    end
    local sourceGUID, sourceName, isPlayer, identityRestricted
    if data then
        local guid, name, playerFlag, sid, sname, denied = SourceFromAura(data)
        identityRestricted = denied
        sourceGUID = guid or sourceGUID
        sourceName = name or sourceName
        isPlayer = playerFlag or isPlayer
        spellId = sid or spellId
        spellName = sname or spellName
    end
    if not sourceName and not identityRestricted then
        local _, fresh = AuraPresent(spellId, spellName)
        if fresh then
            sourceGUID, sourceName, isPlayer = SourceFromAura(fresh)
        end
    end
    -- Targeting and recent casts are diagnostics only; never guess a recipient.
    local key = GiftKey(spellId, spellName)
    if sourceName then
        if key then pendingSources[key] = nil; lookupExpired[key] = nil end
        ConsiderBuff(sourceGUID, sourceName, isPlayer, spellId, spellName)
    else
        if key and not lookupExpired[key] and not pendingSources[key] then
            -- Keep looking for as long as the buff lasts. Never ask the player to thank by hand.
            local pending = { spellId = spellId, spellName = spellName, data = data, casterGUID = sourceGUID, expires = GetTime() + 180, noticed = false }
            pendingSources[key] = pending
            EnsureResolveTicker()
            local gen = sendGen
            for _, delay in ipairs({ 0.15, 0.4, 0.8, 1.5, 3, 5.5, 10, 20, 40, 80 }) do
                C_Timer.After(delay, function()
                    if gen == sendGen and DB_BuffResponder.enabled and not suppressReplies and pendingSources[key] == pending and GetTime() < pending.expires then
                        ThankFromCastOrAura(pending.spellId, pending.spellName, pending.data)
                    end
                end)
            end
            C_Timer.After(8, function()
                if gen == sendGen and pendingSources[key] == pending and not pending.noticed then
                    pending.noticed = true
                    Record("Still identifying caster for " .. tostring(spellName or spellId))
                end
            end)
        end
        Debug("Buff '" .. tostring(spellName or spellId) .. "' is up, but the caster is hidden.")
    end
end

local function RestoredAura(data)
    if not data or IsSecret(data) then return false end
    local duration, expires = data.duration, data.expirationTime
    if not Usable(duration) or not Usable(expires) or type(duration) ~= "number" or type(expires) ~= "number" or duration <= 0 then return false end
    return GetTime() - (expires - duration) > 5
end

local function CollectPoolsUp()
    local poolsUp = {}
    local complete = EachHelpfulAura(function(data)
        local spellId = Usable(data.spellId) and data.spellId or nil
        local spellName = Usable(data.name) and data.name or nil
        if not GetPoolForSpell(spellId, spellName) then
            return
        end
        local poolKey = GiftKey(spellId, spellName)
        if not poolKey then
            return
        end
        poolsUp[poolKey] = { spellId = spellId, spellName = spellName, data = data }
    end)
    if not complete then
        for spellId in pairs(FeelingsBySpellId) do
            local _, data = AuraPresent(spellId, nil)
            if data then
                local sid = Usable(data.spellId) and data.spellId or spellId
                local name = PublicString(data.name)
                local key = GiftKey(sid, name)
                if key and not poolsUp[key] then
                    poolsUp[key] = { spellId = sid, spellName = name, data = data }
                end
            end
        end
    end
    return poolsUp, complete
end

function Addon.Control.SnapshotExistingAuras()
    local poolsUp = CollectPoolsUp()
    for poolKey, info in pairs(poolsUp) do
        restorePools[poolKey] = nil
        RememberPoolExpiry(poolKey, info.data)
        local instance = info.data and not IsSecret(info.data) and info.data.auraInstanceID
        if Usable(instance) and type(instance) == "number" then observedInstances[instance] = true end
        presentPools[poolKey] = true
        announcedPools[poolKey] = true
        thankedPools[poolKey] = true
        poolMisses[poolKey] = 0
        giftSeenAt[poolKey] = GetTime()
        local auraKey = AuraKey(nil, info.spellName or poolKey)
        thankedAuras[auraKey] = poolKey
    end
end

function Addon.Control.ScanPlayerAuras(mode)
    if not DB_BuffResponder.enabled then
        return
    end
    mode = mode or "detect"

    local poolsUp, complete = CollectPoolsUp()
    if not complete then Record("Some auras unreadable; processing readable buffs, preserving removal history.") end

    if mode == "detect" then
        for poolKey, info in pairs(poolsUp) do
            RememberPoolExpiry(poolKey, info.data)
            poolMisses[poolKey] = 0
            Count("indexed whitelist match")
            if not presentPools[poolKey] then
                if RestorePoolActive(poolKey) or RestoredAura(info.data) then
                    thankedPools[poolKey] = true
                    restorePools[poolKey] = nil
                    Record("Zone-restored buff suppressed: " .. tostring(info.spellName or info.spellId))
                end
                presentPools[poolKey] = true
                giftSeenAt[poolKey] = GetTime()
                Record("Detected " .. tostring(info.spellName or info.spellId))
                if suppressReplies then
                    Record("Existing/login buff suppressed: " .. tostring(info.spellName or info.spellId))
                    announcedPools[poolKey] = true
                    thankedPools[poolKey] = true
                end
            end
            if not thankedPools[poolKey] and not suppressReplies then
                ThankFromCastOrAura(info.spellId, info.spellName, info.data)
            end
        end

        for poolKey in pairs(presentPools) do
            if complete and not poolsUp[poolKey] then
                poolMisses[poolKey] = (poolMisses[poolKey] or 0) + 1
                if poolMisses[poolKey] >= 1 then
                    presentPools[poolKey] = nil
                    giftSeenAt[poolKey] = nil
                    poolExpiry[poolKey] = nil
                    restorePools[poolKey] = nil
                    announcedPools[poolKey] = nil
                    thankedPools[poolKey] = nil
                    poolMisses[poolKey] = nil
                    pendingSources[poolKey] = nil
                    ClearThankedForSpell(nil, poolKey)
                end
            end
        end
        return
    end

    -- resolve: look up casters for gifts we already know about. Never announce.
    for poolKey, info in pairs(poolsUp) do
        if presentPools[poolKey] and not thankedPools[poolKey] and not suppressReplies then
            ThankFromCastOrAura(info.spellId, info.spellName, info.data)
        end
    end
end

function Addon.Control.ThankTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsUnit("target", "player") then
        Note("No player target. Automation will keep looking for the caster.")
        return
    end
    local name, guid, isPlayer = UnitPlayerName("target")
    if not name then
        Note("Can't read that target's name.")
        return
    end
    local spellId, spellName
    EachHelpfulAura(function(data)
        local sid = Usable(data.spellId) and data.spellId or nil
        local sname = Usable(data.name) and data.name or nil
        if GetPoolForSpell(sid, sname) then
            spellId = sid or spellId
            spellName = sname or spellName
        end
    end)
    if not GetPoolForSpell(spellId, spellName) then
        spellName = "Mark of the Wild"
    end
    ConsiderBuff(guid, name, isPlayer or true, spellId, spellName)
end

function Addon.Control.HandleUnitAura(updateInfo)
    if not DB_BuffResponder.enabled then Count("disabled aura processing"); return end
    -- Event additions can be readable even when indexed scanning is restricted.
    if not IsSecret(updateInfo) and type(updateInfo) == "table" then
        local updated = updateInfo.updatedAuraInstanceIDs
        if not IsSecret(updated) and type(updated) == "table" and C_UnitAuras
            and type(C_UnitAuras.GetAuraDataByAuraInstanceID) == "function" then
            for _, id in ipairs(updated) do
                if Usable(id) and type(id) == "number" then
                    local ok, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
                    if ok and not IsSecret(data) and type(data) == "table" then
                        local sid, name = Usable(data.spellId) and data.spellId or nil, PublicString(data.name)
                        local key = GiftKey(sid, name)
                        -- Updates resolve known, unhandled gifts; they do not reset dedupe.
                        if key and presentPools[key] and not thankedPools[key] and not suppressReplies then
                            ThankFromCastOrAura(sid, name, data)
                        end
                    end
                end
            end
        end
        local added = updateInfo.addedAuras
        if not IsSecret(added) and type(added) == "table" then
            for _, data in ipairs(added) do
                if not IsSecret(data) and type(data) == "table" then
                    local sid = Usable(data.spellId) and data.spellId or nil
                    local name = PublicString(data.name)
                    local key = GiftKey(sid, name)
                    Count(key and "added whitelist match" or "added identity unavailable or unsupported")
                    local instance = Usable(data.auraInstanceID) and data.auraInstanceID or nil
                    local harmful = data.isHarmful
                    if key and not IsSecret(harmful) and not harmful and (not instance or not observedInstances[instance]) then
                        if instance then observedInstances[instance] = true end
                        local alreadyHandled = presentPools[key] and thankedPools[key]
                        if alreadyHandled then Count("existing handled gift suppressed") end
                        if suppressReplies then Count("baseline gift suppressed") end
                        if RestorePoolActive(key) or RestoredAura(data) then Count("restored or old aura suppressed") end
                        RememberPoolExpiry(key, data)
                        presentPools[key] = true
                        giftSeenAt[key] = GetTime()
                        if not alreadyHandled then ClearThankedForSpell(nil, key) end
                        thankedPools[key] = (alreadyHandled or suppressReplies or RestorePoolActive(key) or RestoredAura(data)) or nil
                        restorePools[key] = nil
                        Record("Buff event: " .. tostring(name or sid))
                        NoteNearbyTargeting()
                        EnsureResolveTicker()
                        if not suppressReplies and not thankedPools[key] then ThankFromCastOrAura(sid, name, data) end
                    end
                end
            end
        end
    end
    Addon.Control.ScanPlayerAuras()
end

function Addon.Control.HandleNameplate(unit)
    if not unit or not DB_BuffResponder.enabled then
        return
    end
    -- Forever fires NAME_PLATE_UNIT_ADDED before the unit is populated.
    local gen = sendGen
    local function resolve()
        if gen ~= sendGen or not DB_BuffResponder.enabled then
            return
        end
        NoteNearbyTargeting()
        Addon.Control.ScanPlayerAuras("resolve")
    end
    resolve()
    C_Timer.After(0.15, resolve)
    C_Timer.After(0.5, resolve)
end

function Addon.Control.HandleSpellCast(unit, spellId)
    if not DB_BuffResponder.enabled then
        return
    end
    local unitToken = PublicString(unit)
    if not unitToken then
        Record("Cast unit token unreadable.")
        NoteNearbyTargeting()
        return
    end
    if not Usable(spellId) then
        Record("Cast spell identity unavailable; cannot match this cast.")
        NoteNearbyTargeting()
        return
    end
    local spellName = SpellNameById(spellId)
    if not GetPoolForSpell(spellId, spellName) then return end
    RememberCast(unitToken, spellId, spellName)
    NoteNearbyTargeting()
    local gen = sendGen
    local function followUp()
        if gen ~= sendGen then
            return
        end
        ResolveCastIdentity(recentCasts[#recentCasts])
        for _, pending in pairs(pendingSources) do
            if GetTime() < pending.expires then
                ThankFromCastOrAura(pending.spellId, pending.spellName, pending.data)
            end
        end
        Addon.Control.ScanPlayerAuras()
    end
    C_Timer.After(0.1, followUp)
    C_Timer.After(0.4, followUp)
end

function Addon.Control.FullPlayerName(unit)
    return FullPlayerName(unit)
end

function Addon.Control.Initialize(pName, pFullName)
    playerName = pName
    playerFullName = pFullName
    if not pulseStarted then
        pulseStarted = true
        C_Timer.NewTicker(0.2, function()
            if DB_BuffResponder and DB_BuffResponder.enabled then
                NoteNearbyTargeting()
            end
        end)
    end
end
