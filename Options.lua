local _, Addon = ...
Addon.Options = {}
local panel, fields, mode = nil, {}, "fixed"
local function Refresh()
    local db = DB_BuffResponder
    mode = db.typingMode
    panel.mode:SetText("Typing mode: " .. mode)
    local keys = {"replyDelay", "typingMin", "typingMax", "interSendGap", "cooldownDelay"}
    for i, key in ipairs(keys) do fields[i]:SetText(tostring(db[key])) end
end
function Addon.Options.Initialize()
    if panel then return end
    panel = CreateFrame("Frame", "KrakenBuffAcknowledgementOptions", UIParent)
    panel.name = "Kraken Buff Acknowledgement"
    panel:SetSize(580, 420)
    panel:SetPoint("CENTER")
    panel:Hide()
    local bg=panel:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(0.06,0.06,0.08,0.97)
    local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",20,-20);title:SetText("Kraken Buff Acknowledgement — Reply timing")
    local text=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    text:SetPoint("TOPLEFT",20,-50);text:SetWidth(530);text:SetJustifyH("LEFT")
    text:SetText("Typing delay makes the response feel composed. Cooldown prevents repeated thanks to one player. Replies to different players are spaced apart. Changes apply to newly queued replies.")
    local button=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    button:SetSize(220,26);button:SetPoint("TOPLEFT",20,-95);panel.mode=button
    button:SetScript("OnClick",function() mode=mode=="fixed" and "random" or "fixed";button:SetText("Typing mode: "..mode) end)
    local labels={"Fixed typing delay (0–120 seconds)","Random typing minimum (1–120 seconds)","Random typing maximum (minimum–120)","Gap between replies (1–60 seconds)","Per-player cooldown (0–3600 seconds)"}
    for i,label in ipairs(labels) do
        local l=panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        l:SetPoint("TOPLEFT",20,-130-(i-1)*36);l:SetText(label)
        local edit=CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
        edit:SetSize(85,24);edit:SetPoint("TOPLEFT",420,-125-(i-1)*36);edit:SetAutoFocus(false);edit:SetMaxLetters(6)
        fields[i]=edit
    end
    panel.feedback=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    panel.feedback:SetPoint("TOPLEFT",20,-325);panel.feedback:SetWidth(530);panel.feedback:SetJustifyH("LEFT")
    local save=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");save:SetSize(100,26);save:SetPoint("BOTTOMLEFT",20,20);save:SetText("Apply")
    save:SetScript("OnClick",function()
        local v={};for i,e in ipairs(fields) do v[i]=tonumber(e:GetText()) end
        if Addon.Timing.Set(DB_BuffResponder,mode,v[1],v[2],v[3],v[4],v[5]) then panel.feedback:SetText("Saved. Current queued replies keep their typing delay.")
        else panel.feedback:SetText("Use numbers within the displayed ranges; random maximum must be at least the minimum.") end
    end)
    local close=CreateFrame("Button",nil,panel,"UIPanelButtonTemplate");close:SetSize(100,26);close:SetPoint("BOTTOMRIGHT",-20,20);close:SetText("Close");close:SetScript("OnClick",function() panel:Hide() end)
    panel:SetScript("OnShow",Refresh)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok,category=pcall(Settings.RegisterCanvasLayoutCategory,panel,panel.name)
        if ok and category then pcall(Settings.RegisterAddOnCategory,category) end
    elseif InterfaceOptions_AddCategory then pcall(InterfaceOptions_AddCategory,panel) end
end
function Addon.Options.Show()
    Addon.Options.Initialize()
    panel:Show()
end
