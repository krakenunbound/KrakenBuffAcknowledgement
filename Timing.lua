local _, Addon = ...
Addon.Timing = {}
local function Number(value, fallback, low, high)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return fallback end
    return math.max(low, math.min(high, value))
end
function Addon.Timing.Normalize(db)
    db.replyDelay = Number(db.replyDelay, 10, 0, 120)
    db.typingMode = db.typingMode == "random" and "random" or "fixed"
    db.typingMin = Number(db.typingMin, 8, 1, 120)
    db.typingMax = Number(db.typingMax, 14, db.typingMin, 120)
    db.interSendGap = Number(db.interSendGap, 3, 1, 60)
    db.cooldownDelay = Number(db.cooldownDelay, 60, 0, 3600)
end
function Addon.Timing.Delay(db)
    if db.typingMode == "random" then
        return db.typingMin + math.random() * (db.typingMax - db.typingMin)
    end
    return db.replyDelay
end
function Addon.Timing.Set(db, mode, fixed, low, high, gap, cooldown)
    if mode ~= "fixed" and mode ~= "random" then return false end
    local values = {fixed, low, high, gap, cooldown}
    for i = 1, 5 do local v = values[i]; if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return false end end
    if #values ~= 5 or fixed < 0 or fixed > 120 or low < 1 or high < low or high > 120
        or gap < 1 or gap > 60 or cooldown < 0 or cooldown > 3600 then return false end
    db.typingMode, db.replyDelay, db.typingMin, db.typingMax = mode, fixed, low, high
    db.interSendGap, db.cooldownDelay = gap, cooldown
    return true
end
