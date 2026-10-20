local addonName, Addon = ...
Addon.View = Addon.View or {}

local function Trim(value)
    return strtrim(value or "")
end

local function ShowHelp()
    print("|cFF00FF00Kraken Buff Acknowledgement Commands:|r")
    print("----------------------------------------------------")
    print("Kraken Buff Acknowledgement 2.3.19 (Forever) - Responds to meaningful player buffs")
    print("----------------------------------------------------")
    print("  /kba - Show this help")
    print("  /kba options - Typing delay, random range, reply gap and cooldown")
    print("  /kba typing fixed|random - Select typing-delay mode")
    print("  /kba range MIN MAX - Random typing-delay range (1-120 seconds)")
    print("  /kba gap SECONDS - Gap between replies (1-60 seconds)")
    print("  /kba status - Show current configuration")
    print("  /kba diagnose - Open copyable diagnostic snapshot (Ctrl+A, Ctrl+C)")
    print("  /kba on/off - Enable/Disable the addon")
    print("  /kba test - Whisper your current target (must be another player)")
    print("  /kba plates on/off - Show friendly nameplates so casters can be seen")
    print("  Whispers are random poetic sensations (the gift is never named).")
    print("  /kba delay [seconds] - Set reply delay (default: 10)")
    print("  /kba cooldown [seconds] - Per-player cooldown (default: 60)")
    print("  /kba excludegroup on/off - Exclude group members")
    print("  /kba excludeguild on/off - Exclude guild members")
    print("  /kba debug on/off - Enable/Disable debug mode")
    print("  /kba persona - Show your active character voice")
    print("  /kba reset - Reset all settings to default values")
    print("----------------------------------------------------")
    print("  Fully automatic. Whispers use both names (First Last).")
    print("  Keep friendly nameplates on so nearby buffers can be identified.")
end

function Addon.View.ShowStatus()
    local profile = Addon.Persona.GetProfile()
    print("|cFF00FF00Kraken Buff Acknowledgement Status:|r")
    print("  Enabled: " .. (DB_BuffResponder.enabled and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Response engine: |cFFFFFF00buff-specific random pools|r")
    print("  Persona: |cFFFFFF00" .. profile.race .. " / " .. profile.gender .. " / " .. profile.faction .. " / " .. profile.class .. "|r")
    print("  Typing mode: " .. DB_BuffResponder.typingMode .. "; fixed delay: " .. DB_BuffResponder.replyDelay .. "s; random: " .. DB_BuffResponder.typingMin .. "-" .. DB_BuffResponder.typingMax .. "s")
    print("  Gap between replies: " .. DB_BuffResponder.interSendGap .. " seconds")
    print("  Cooldown: " .. DB_BuffResponder.cooldownDelay .. " seconds")
    print("  Exclude Group: " .. (DB_BuffResponder.excludeGroup and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Exclude Guild: " .. (DB_BuffResponder.excludeGuild and "|cFF00FF00Yes|r" or "|cFFFF0000No|r"))
    print("  Debug Mode: " .. (DB_BuffResponder.debugMode and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
    print("  Nearby plates: " .. (DB_BuffResponder.watchNearby and "|cFF00FF00On|r" or "|cFFFF0000Off|r"))
end

local function SlashCommandHandler(msg)
    local command, args = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "" or command == "help" then
        ShowHelp()
    elseif command == "options" then
        Addon.Options.Show()
    elseif command == "typing" and (args == "fixed" or args == "random") then
        DB_BuffResponder.typingMode = args
        Addon.View.ShowStatus()
    elseif command == "range" then
        local low, high = args:match("^(%S+)%s+(%S+)$")
        low, high = tonumber(low), tonumber(high)
        if low and high and low >= 1 and high >= low and high <= 120 then
            DB_BuffResponder.typingMin, DB_BuffResponder.typingMax = low, high
            Addon.View.ShowStatus()
        else print("Use /kba range MIN MAX (1 <= MIN <= MAX <= 120).") end
    elseif command == "gap" then
        local gap = tonumber(args)
        if gap and gap >= 1 and gap <= 60 then DB_BuffResponder.interSendGap = gap; Addon.View.ShowStatus()
        else print("Use /kba gap 1-60.") end
    elseif command == "diagnose" or command == "diag" or command == "diagnostics" then
        Addon.Control.ShowDiagnostics()
    elseif command == "status" then
        Addon.View.ShowStatus()
    elseif command == "on" then
        DB_BuffResponder.enabled = true
        Addon.Control.ApplyFriendlyPlates()
        print("|cFF00FF00Kraken Buff Acknowledgement:|r Enabled")
    elseif command == "off" then
        DB_BuffResponder.enabled = false
        Addon.Control.BeginZoneTransition()
        Addon.Control.RestoreFriendlyPlates()
        print("|cFF00FF00Kraken Buff Acknowledgement:|r Disabled")
    elseif command == "delay" then
        local delay = tonumber(args)
        if delay and delay >= 0 and delay <= 120 then
            DB_BuffResponder.replyDelay = delay
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Reply delay set to " .. delay .. " seconds")
        else
            print("|cFFFF0000Kraken Buff Acknowledgement:|r Please provide a valid number (>= 0)")
        end
    elseif command == "cooldown" then
        local cooldown = tonumber(args)
        if cooldown and cooldown >= 0 and cooldown <= 3600 then
            DB_BuffResponder.cooldownDelay = cooldown
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Cooldown set to " .. cooldown .. " seconds")
        else
            print("|cFFFF0000Kraken Buff Acknowledgement:|r Please provide a valid number (>= 0)")
        end
    elseif command == "excludegroup" then
        local toggleCmd = Trim(args):lower()
        if toggleCmd == "on" then
            DB_BuffResponder.excludeGroup = true
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Group members will be excluded from whispers.")
        elseif toggleCmd == "off" then
            DB_BuffResponder.excludeGroup = false
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Group members will receive whispers.")
        else
            print("|cFFFF0000Kraken Buff Acknowledgement:|r Usage: /kba excludegroup on|off")
        end
    elseif command == "excludeguild" then
        local toggleCmd = Trim(args):lower()
        if toggleCmd == "on" then
            DB_BuffResponder.excludeGuild = true
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Guild members will be excluded from whispers.")
        elseif toggleCmd == "off" then
            DB_BuffResponder.excludeGuild = false
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Guild members will receive whispers.")
        else
            print("|cFFFF0000Kraken Buff Acknowledgement:|r Usage: /kba excludeguild on|off")
        end
    elseif command == "debug" then
        local debugCmd = Trim(args):lower()
        if debugCmd == "on" then
            DB_BuffResponder.debugMode = true
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Debug mode enabled. You can now buff yourself to test whispers.")
        elseif debugCmd == "off" then
            DB_BuffResponder.debugMode = false
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Debug mode disabled.")
        else
            print("|cFFFF0000Kraken Buff Acknowledgement:|r Usage: /kba debug on|off")
        end
    elseif command == "test" then
        Addon.Control.SendTestWhisper()
    elseif command == "thank" then
        Addon.Control.ThankTarget()
    elseif command == "plates" then
        local toggleCmd = Trim(args):lower()
        if toggleCmd == "on" then
            DB_BuffResponder.watchNearby = true
            Addon.Control.ApplyFriendlyPlates()
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Friendly nameplates on so nearby buffers can be seen.")
        elseif toggleCmd == "off" then
            DB_BuffResponder.watchNearby = false
            Addon.Control.RestoreFriendlyPlates()
            print("|cFF00FF00Kraken Buff Acknowledgement:|r Friendly nameplates restored to your previous setting.")
        else
            print("|cFFFF0000Kraken Buff Acknowledgement:|r Usage: /kba plates on|off")
        end
    elseif command == "persona" then
        local profile = Addon.Persona.GetProfile()
        print("|cFF00FF00Kraken Buff Acknowledgement persona:|r " .. profile.race .. " / " .. profile.gender .. " / " .. profile.faction .. " / " .. profile.class)
    elseif command == "reset" then
        Addon.Core.ResetSettings()
        print("|cFF00FF00Kraken Buff Acknowledgement:|r All settings have been reset to default values.")
        Addon.View.ShowStatus()
    else
        print("|cFFFF0000Kraken Buff Acknowledgement:|r Unknown command. Type /kba for help.")
    end
end

function Addon.View.Initialize()
    SLASH_KBA1 = "/kba"
    SLASH_KBA2 = "/buffr"
    SlashCmdList["KBA"] = SlashCommandHandler
    Addon.Options.Initialize()
end
