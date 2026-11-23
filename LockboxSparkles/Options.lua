-- Options.lua: Blizzard Settings > AddOns panel and /lbs slash commands.
local _, LBS = ...

local O = {}
LBS.Options = O

local categoryID = nil
local refreshers = {}

local function notifySettingsChanged(reapplyCVars)
    if reapplyCVars then
        if LBS.db.manageCVars and LBS.ShouldBeActive() then
            LBS.ApplyCVars()
        elseif not LBS.db.manageCVars then
            LBS.RestoreCVars()
        end
    end
    LBS:Fire("LBS_SETTINGS_CHANGED")
    O:Refresh()
end

function O:Refresh()
    for _, fn in ipairs(refreshers) do
        fn()
    end
end

local function openColorPicker(currentColor, onChanged)
    local r = currentColor[1] or 1
    local g = currentColor[2] or 0.84
    local b = currentColor[3] or 0.20

    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                onChanged(nr, ng, nb)
            end,
            cancelFunc = function(prev)
                if prev then
                    onChanged(prev.r or r, prev.g or g, prev.b or b)
                else
                    onChanged(r, g, b)
                end
            end,
        })
    elseif ColorPickerFrame then
        ColorPickerFrame.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            onChanged(nr, ng, nb)
        end
        ColorPickerFrame.cancelFunc = function()
            onChanged(r, g, b)
        end
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end
end

local function createCheckbox(parent, x, y, labelText, tooltipText, key, reapplyCVars)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetSize(24, 24)

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    lbl:SetText(labelText)

    cb:SetScript("OnClick", function(self)
        LBS.db[key] = self:GetChecked() and true or false
        notifySettingsChanged(reapplyCVars)
    end)

    if tooltipText then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(labelText, 1, 0.84, 0.2)
            GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    table.insert(refreshers, function()
        if LBS.db then
            cb:SetChecked(LBS.db[key] and true or false)
        end
    end)
    return cb
end

local function createSlider(parent, x, y, title, minVal, maxVal, step, key, fmt, reapplyCVars)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(title)

    local valText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 175, y)

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    slider:SetSize(210, 14)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:EnableMouse(true)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(1, 1, 1, 0.16)
    track:SetHeight(4)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1.0, 0.84, 0.20, 1.0)
    thumb:SetSize(12, 14)
    slider:SetThumbTexture(thumb)

    local updating = false
    slider:SetScript("OnValueChanged", function(_, value)
        if updating or not LBS.db then return end
        local snapped = math.floor((value / step) + 0.5) * step
        snapped = math.max(minVal, math.min(maxVal, snapped))
        LBS.db[key] = snapped
        valText:SetText(fmt(snapped))
        notifySettingsChanged(reapplyCVars)
    end)

    table.insert(refreshers, function()
        if not LBS.db then return end
        updating = true
        local v = tonumber(LBS.db[key]) or minVal
        slider:SetValue(v)
        valText:SetText(fmt(v))
        updating = false
    end)
    return slider
end

local function buildSettingsPanel()
    local panel = CreateFrame("Frame", "LockboxSparklesOptionsPanel", UIParent)
    panel.name = "Lockbox Sparkles"
    O.panel = panel

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Lockbox Sparkles |cff999999v" .. LBS.version .. "|r")

    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("Adds animated sparkles to open-world lockboxes, footlockers, and locked chests rogues can unlock.")

    -- Left column: behavior toggles
    local secLeft = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secLeft:SetPoint("TOPLEFT", 16, -64)
    secLeft:SetText("Detection & Filtering")

    createCheckbox(panel, 14, -86, "Enable Lockbox Sparkles",
        "Master switch for open-world lockbox sparkles.", "enabled", true)
    createCheckbox(panel, 14, -116, "Rogues only",
        "Only activate on Rogue characters.", "roguesOnly", true)
    createCheckbox(panel, 14, -146, "Only show lockboxes I can unlock",
        "Hide sparkles when your Lockpicking skill is below the box requirement. Uncheck to show them in dimmed red.",
        "onlyUnlockable", false)
    createCheckbox(panel, 14, -176, "Include locked world chests",
        "Also sparkle open-world chests (Solid, Iron Bound, Mithril, etc.) when their tooltip shows Locked or Requires Lockpicking.",
        "includeLockedChests", false)
    createCheckbox(panel, 14, -206, "Show Lockpicking skill label",
        "Display the required Lockpicking level underneath the sparkles when known.",
        "showLabel", false)
    createCheckbox(panel, 14, -236, "Auto-configure Soft-Interact CVars",
        "Safely enables GameObject soft-interact scanning out of combat (never touches enemy/friendly soft-targeting or NPC nameplates).",
        "manageCVars", true)

    -- Color mode section
    local secColor = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secColor:SetPoint("TOPLEFT", 16, -278)
    secColor:SetText("Sparkle Color Mode")

    local modeButtons = {}
    local modes = {
        { id = "gold",       label = "Rogue Gold" },
        { id = "difficulty", label = "Skill-Up Color" },
        { id = "custom",     label = "Custom" },
    }
    for i, m in ipairs(modes) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(102, 24)
        btn:SetPoint("TOPLEFT", 16 + (i - 1) * 108, -300)
        btn:SetText(m.label)
        btn:SetScript("OnClick", function()
            LBS.db.colorMode = m.id
            notifySettingsChanged(false)
        end)
        modeButtons[m.id] = btn
    end

    local swatch = CreateFrame("Button", nil, panel)
    swatch:SetSize(24, 24)
    swatch:SetPoint("TOPLEFT", 342, -300)
    local swatchBg = swatch:CreateTexture(nil, "BACKGROUND")
    swatchBg:SetAllPoints()
    swatchBg:SetColorTexture(0.1, 0.1, 0.1, 1)
    local swatchTex = swatch:CreateTexture(nil, "ARTWORK")
    swatchTex:SetPoint("TOPLEFT", 2, -2)
    swatchTex:SetPoint("BOTTOMRIGHT", -2, 2)
    swatch:SetScript("OnClick", function()
        LBS.db.colorMode = "custom"
        openColorPicker(LBS.db.customColor, function(r, g, b)
            LBS.db.customColor = { r, g, b }
            notifySettingsChanged(false)
        end)
    end)

    table.insert(refreshers, function()
        if not LBS.db then return end
        for id, btn in pairs(modeButtons) do
            if btn.SetEnabled then
                btn:SetEnabled(LBS.db.colorMode ~= id)
            end
        end
        local c = LBS.db.customColor or LBS.DEFAULTS.customColor
        swatchTex:SetColorTexture(c[1] or 1, c[2] or 0.84, c[3] or 0.2, 1)
    end)

    -- Right column: appearance & range sliders
    local secRight = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    secRight:SetPoint("TOPLEFT", 340, -64)
    secRight:SetText("Appearance & Range")

    createSlider(panel, 340, -88, "Sparkle Scale", 0.5, 2.0, 0.1, "scale",
        function(v) return string.format("%.1fx", v) end, false)
    createSlider(panel, 340, -142, "Sparkle Intensity", 6, 20, 1, "intensity",
        function(v) return tostring(math.floor(v + 0.5)) end, false)
    createSlider(panel, 340, -196, "Vertical Offset", -40, 60, 2, "yOffset",
        function(v) return string.format("%d px", math.floor(v + 0.5)) end, false)
    createSlider(panel, 340, -250, "Detection Range", 10, 40, 5, "interactRange",
        function(v) return string.format("%d yds", math.floor(v + 0.5)) end, true)

    -- Action buttons
    local previewBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    previewBtn:SetSize(145, 26)
    previewBtn:SetPoint("TOPLEFT", 16, -346)
    previewBtn:SetText("Preview Sparkles")
    previewBtn:SetScript("OnClick", function()
        local on = LBS.Sparkles:TogglePreview()
        LBS.Print(on and "Showing live sparkle preview at screen center (12s)." or "Preview stopped.")
    end)

    local restoreBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    restoreBtn:SetSize(165, 26)
    restoreBtn:SetPoint("LEFT", previewBtn, "RIGHT", 10, 0)
    restoreBtn:SetText("Restore Original CVars")
    restoreBtn:SetScript("OnClick", function()
        LBS.db.manageCVars = false
        local ok = LBS.RestoreCVars()
        O:Refresh()
        if ok then
            LBS.Print("Restored your original Soft-Interact CVars and disabled auto-CVar management.")
        else
            LBS.Print("No saved original CVars to restore (or queued until combat ends).")
        end
    end)

    panel:SetScript("OnShow", function()
        O:Refresh()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        pcall(function()
            local category = Settings.RegisterCanvasLayoutCategory(panel, "Lockbox Sparkles")
            Settings.RegisterAddOnCategory(category)
            categoryID = category:GetID()
        end)
    end
end

function O:Open()
    if categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(categoryID)
        return true
    end
    LBS.Print("Open Escape -> Options -> AddOns -> Lockbox Sparkles, or use /lbs test | status | toggle.")
    return false
end

---------------------------------------------------------------------------
-- Slash commands: /lbs and /lockboxsparkles
---------------------------------------------------------------------------
function O.HandleSlash(msg)
    local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
    local cmd, arg = raw:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""
    arg = arg and arg:lower() or ""

    if cmd == "" or cmd == "options" or cmd == "config" then
        O:Open()
    elseif cmd == "test" or cmd == "preview" then
        local on = LBS.Sparkles:TogglePreview()
        LBS.Print(on and "Previewing sparkles at screen center (12s). Run /lbs test again to stop." or "Preview stopped.")
    elseif cmd == "toggle" then
        LBS.db.enabled = not LBS.db.enabled
        notifySettingsChanged(true)
        LBS.Print(LBS.db.enabled and "Enabled." or "Disabled.")
    elseif cmd == "color" then
        if arg == "gold" or arg == "difficulty" or arg == "custom" then
            LBS.db.colorMode = arg
            notifySettingsChanged(false)
            LBS.Print("Color mode set to: " .. arg)
        else
            LBS.Print("Usage: /lbs color gold | difficulty | custom")
        end
    elseif cmd == "restore" then
        LBS.db.manageCVars = false
        LBS.RestoreCVars()
        O:Refresh()
        LBS.Print("Restored original Soft-Interact CVars.")
    elseif cmd == "status" then
        local skill, cap, base, bonus = LBS.GetLockpickingSkill()
        local active = LBS.ShouldBeActive() and "active" or "inactive"
        local info, reason, extra = LBS.Detector:InspectSoftInteract()
        local dbg = LBS.Detector:GetDebugInfo()
        LBS.Print(string.format(
            "v%s | %s | Rogue: %s | PickLock: %s | Lockpicking: %d/%d (base %d, bonus +%d) | Color: %s",
            LBS.version,
            active,
            LBS.IsRogue() and "yes" or "no",
            dbg.knowsPickLock and "yes" or "no",
            skill, cap, base, bonus,
            LBS.db.colorMode
        ))
        if info then
            LBS.Print(string.format(
                "Soft-interact MATCH: %s (ID %s, req %s, %s, plate=%s via %s)",
                info.match.name,
                tostring(info.match.objectID or "?"),
                tostring(info.match.requiredSkill or "?"),
                info.difficulty,
                tostring(dbg.plate),
                tostring(dbg.plateSrc)
            ))
        else
            local detail = ""
            if extra and extra.match then
                detail = string.format(" [%s, req %s]", extra.match.name, tostring(extra.match.requiredSkill or "?"))
            elseif extra and extra.objectID then
                detail = string.format(" [ID %s, name=%s]", tostring(extra.objectID), tostring(extra.unitName or "?"))
            end
            LBS.Print(string.format(
                "Soft-interact: none (%s)%s | guid=%s (%s) | plate=%s (%s) | tipLines=%d",
                tostring(reason),
                detail,
                tostring(dbg.guid or "nil"),
                tostring(dbg.guidSrc),
                tostring(dbg.plate),
                tostring(dbg.plateSrc),
                dbg.tipLines
            ))
        end
    else
        LBS.Print("Commands: /lbs | /lbs test | /lbs toggle | /lbs status | /lbs color gold|difficulty|custom | /lbs restore")
    end
end

LBS:On("LBS_INIT", function()
    buildSettingsPanel()
    SLASH_LOCKBOXSPARKLES1 = "/lbs"
    SLASH_LOCKBOXSPARKLES2 = "/lockboxsparkles"
    SlashCmdList["LOCKBOXSPARKLES"] = O.HandleSlash
end)
