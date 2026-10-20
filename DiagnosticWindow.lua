local _, Addon = ...
Addon.DiagnosticWindow = {}
local frame, edit
function Addon.DiagnosticWindow.Show(report)
    if not frame then
        frame = CreateFrame("Frame", "KBADiagnosticReport", UIParent)
        frame:SetSize(620, 480);frame:SetPoint("CENTER");frame:SetFrameStrata("DIALOG")
        local bg=frame:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(0.04,0.04,0.06,0.98)
        local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        title:SetPoint("TOPLEFT",18,-18);title:SetText("Kraken Buff Acknowledgement — Diagnostic snapshot")
        local instruction=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        instruction:SetPoint("TOPLEFT",18,-46);instruction:SetText("Click the report, press Ctrl+A then Ctrl+C. Opening this window does not clear diagnostics.")
        local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",18,-74);scroll:SetPoint("BOTTOMRIGHT",-40,52)
        edit=CreateFrame("EditBox",nil,scroll)
        edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(550);edit:SetMaxLetters(16000)
        edit:SetScript("OnEscapePressed",function() frame:Hide() end)
        edit:SetScript("OnTextChanged",function(self)
            local text=self:GetText() or ""
            local _, lines=text:gsub("\n","")
            self:SetHeight(math.max(340,(lines+math.ceil(#text/70)+1)*14))
            scroll:UpdateScrollChildRect()
        end)
        scroll:SetScrollChild(edit)
        local close=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
        close:SetSize(100,26);close:SetPoint("BOTTOMRIGHT",-18,16);close:SetText("Close")
        close:SetScript("OnClick",function() frame:Hide() end)
    end
    edit:SetText(report:sub(1,16000));frame:Show();edit:SetFocus();edit:HighlightText()
end
