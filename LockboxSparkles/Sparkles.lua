-- Sparkles.lua: Zero-taint 2D additive particle shimmer anchored to soft-interact nameplates.
-- Uses addon-owned UIParent frame so Blizzard / Plater nameplates are never mutated or tainted.
local _, LBS = ...

local D = LBS.Data
local S = {}
LBS.Sparkles = S

local MEDIA = "Interface\\AddOns\\LockboxSparkles\\Media\\"
local TEX_STAR = MEDIA .. "sparkle_star"
local TEX_GLOW = MEDIA .. "sparkle_glow"
local TEX_DOT  = MEDIA .. "sparkle_dot"

local MAX_PARTICLES = 20
local FADE_IN_RATE  = 6.5
local FADE_OUT_RATE = 5.5
local TWO_PI = math.pi * 2

-- Deterministic pseudo-random specs so particle clouds feel organic yet balanced.
local PARTICLE_SPECS = {
    { x = -26, y0 = -12, rise = 38, size = 18, speed = 0.62, phase = 0.00, sway = 4.5, star = true,  rot =  0.7 },
    { x =  24, y0 = -10, rise = 42, size = 16, speed = 0.56, phase = 0.17, sway = 5.0, star = true,  rot = -0.6 },
    { x =   0, y0 =  -6, rise = 44, size = 22, speed = 0.48, phase = 0.33, sway = 3.0, star = true,  rot =  0.5 },
    { x = -14, y0 = -14, rise = 36, size = 14, speed = 0.72, phase = 0.51, sway = 4.0, star = true,  rot = -0.9 },
    { x =  15, y0 = -12, rise = 40, size = 15, speed = 0.66, phase = 0.68, sway = 3.8, star = true,  rot =  0.8 },
    { x = -32, y0 =  -4, rise = 30, size = 12, speed = 0.78, phase = 0.84, sway = 3.2, star = false, rot =  0.0 },
    { x =  31, y0 =  -6, rise = 32, size = 11, speed = 0.74, phase = 0.26, sway = 3.5, star = false, rot =  0.0 },
    { x =  -7, y0 = -16, rise = 46, size = 17, speed = 0.54, phase = 0.44, sway = 4.2, star = true,  rot =  0.6 },
    { x =   9, y0 = -15, rise = 45, size = 13, speed = 0.69, phase = 0.79, sway = 4.8, star = false, rot =  0.0 },
    { x = -21, y0 =  -2, rise = 34, size = 11, speed = 0.82, phase = 0.11, sway = 2.8, star = false, rot =  0.0 },
    { x =  20, y0 =  -3, rise = 35, size = 19, speed = 0.52, phase = 0.61, sway = 3.6, star = true,  rot = -0.5 },
    { x =   2, y0 = -18, rise = 48, size = 10, speed = 0.86, phase = 0.93, sway = 3.4, star = false, rot =  0.0 },
    { x = -36, y0 = -10, rise = 32, size = 15, speed = 0.60, phase = 0.37, sway = 4.0, star = true,  rot =  0.7 },
    { x =  35, y0 = -11, rise = 33, size = 14, speed = 0.64, phase = 0.73, sway = 4.2, star = true,  rot = -0.7 },
    { x = -11, y0 =   0, rise = 30, size = 10, speed = 0.90, phase = 0.05, sway = 2.5, star = false, rot =  0.0 },
    { x =  12, y0 =   2, rise = 28, size = 10, speed = 0.88, phase = 0.55, sway = 2.6, star = false, rot =  0.0 },
    { x = -28, y0 = -16, rise = 40, size = 13, speed = 0.58, phase = 0.22, sway = 4.6, star = false, rot =  0.0 },
    { x =  27, y0 = -16, rise = 40, size = 16, speed = 0.55, phase = 0.88, sway = 4.4, star = true,  rot =  0.6 },
    { x =  -4, y0 =  -8, rise = 38, size = 12, speed = 0.76, phase = 0.48, sway = 3.1, star = false, rot =  0.0 },
    { x =   5, y0 =  -9, rise = 39, size = 17, speed = 0.50, phase = 0.97, sway = 3.3, star = true,  rot = -0.8 },
}

-- Main overlay container (owned by UIParent so it never taints nameplates)
local frame = CreateFrame("Frame", "LockboxSparklesOverlay", UIParent)
frame:SetSize(96, 96)
frame:SetFrameStrata("LOW")
frame:EnableMouse(false)
frame:Hide()
S.frame = frame

-- Ambient soft glow halo
local glow = frame:CreateTexture(nil, "BACKGROUND")
glow:SetTexture(TEX_GLOW)
glow:SetBlendMode("ADD")
glow:SetPoint("CENTER", frame, "CENTER", 0, 4)
glow:SetSize(88, 88)
S.glow = glow

-- Secondary inner bright core shimmer
local coreGlow = frame:CreateTexture(nil, "ARTWORK")
coreGlow:SetTexture(TEX_STAR)
coreGlow:SetBlendMode("ADD")
coreGlow:SetPoint("CENTER", frame, "CENTER", 0, 4)
coreGlow:SetSize(30, 30)

-- Pre-allocated particle textures
local particles = {}
for i = 1, MAX_PARTICLES do
    local spec = PARTICLE_SPECS[i]
    local tex = frame:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(spec.star and TEX_STAR or TEX_DOT)
    tex:SetBlendMode("ADD")
    tex:SetSize(spec.size, spec.size)
    tex:SetPoint("CENTER", frame, "CENTER", spec.x, spec.y0)
    tex:Hide()
    particles[i] = { tex = tex, spec = spec }
end
S.particles = particles

-- Optional compact skill pill below the sparkle cluster
local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("TOP", frame, "BOTTOM", 0, 14)
label:SetShadowColor(0, 0, 0, 0.85)
label:SetShadowOffset(1, -1)
label:Hide()
S.label = label

-- Animation state
local state = {
    active = false,
    previewing = false,
    alpha = 0,
    targetAlpha = 0,
    elapsed = 0,
    colorR = 1.0,
    colorG = 0.84,
    colorB = 0.20,
    colorAlpha = 1.0,
    anchorPlate = nil,
    currentInfo = nil,
    previewTimer = nil,
}
S.state = state

function S.ResolveColor(difficulty)
    local db = LBS.db or LBS.DEFAULTS
    if difficulty == "locked" then
        local c = D.DIFFICULTY_COLORS.locked
        return c[1], c[2], c[3], 0.65
    end
    if db.colorMode == "difficulty" then
        local c = D.DIFFICULTY_COLORS[difficulty] or D.ROGUE_GOLD
        return c[1], c[2], c[3], 1.0
    elseif db.colorMode == "custom" and type(db.customColor) == "table" then
        return db.customColor[1] or 1, db.customColor[2] or 0.84, db.customColor[3] or 0.20, 1.0
    end
    return D.ROGUE_GOLD[1], D.ROGUE_GOLD[2], D.ROGUE_GOLD[3], 1.0
end

local function updateLabel()
    local db = LBS.db or LBS.DEFAULTS
    local info = state.currentInfo
    if not db.showLabel or not info then
        label:Hide()
        return
    end
    local req = info.match and info.match.requiredSkill
    if state.previewing then
        label:SetText("Lockpicking 110 (Preview)")
        label:SetTextColor(state.colorR, state.colorG, state.colorB)
        label:Show()
    elseif req and req > 0 then
        if info.canUnlock then
            label:SetText("Lockpicking " .. req)
        else
            label:SetText("Locked (" .. req .. ")")
        end
        label:SetTextColor(state.colorR, state.colorG, state.colorB)
        label:Show()
    else
        label:Hide()
    end
end

local function applyAnchor()
    local db = LBS.db or LBS.DEFAULTS
    local yOff = tonumber(db.yOffset) or -12
    frame:ClearAllPoints()
    if state.previewing then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    elseif state.anchorPlate and (not state.anchorPlate.IsForbidden or not state.anchorPlate:IsForbidden()) then
        frame:SetPoint("CENTER", state.anchorPlate, "CENTER", 0, yOff)
    end
end

local function onUpdate(_, dt)
    -- Clamp dt after alt-tab / loading hitches so animation stays smooth
    if dt > 0.1 then dt = 0.1 end
    state.elapsed = state.elapsed + dt

    -- Smooth fade in/out
    if state.alpha < state.targetAlpha then
        state.alpha = math.min(state.targetAlpha, state.alpha + dt * FADE_IN_RATE)
    elseif state.alpha > state.targetAlpha then
        state.alpha = math.max(state.targetAlpha, state.alpha - dt * FADE_OUT_RATE)
    end

    if state.alpha <= 0.001 and state.targetAlpha == 0 then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        for i = 1, MAX_PARTICLES do
            particles[i].tex:Hide()
        end
        return
    end

    local db = LBS.db or LBS.DEFAULTS
    local scale = math.max(0.5, math.min(2.0, tonumber(db.scale) or 1.0))
    local count = math.max(6, math.min(MAX_PARTICLES, math.floor((tonumber(db.intensity) or 12) + 0.5)))
    local t = state.elapsed
    local masterAlpha = state.alpha * state.colorAlpha
    local r, g, b = state.colorR, state.colorG, state.colorB

    -- Breathing ambient glow
    local pulse = 0.72 + 0.28 * math.sin(t * 3.1)
    local glowSize = (86 + 10 * math.sin(t * 2.3)) * scale
    glow:SetSize(glowSize, glowSize)
    glow:SetVertexColor(r, g, b, 0.34 * pulse * masterAlpha)

    -- Subtle central star glint
    local corePulse = 0.55 + 0.45 * math.sin(t * 5.2 + 1.1)
    local coreSize = (24 + 8 * corePulse) * scale
    coreGlow:SetSize(coreSize, coreSize)
    if coreGlow.SetRotation then
        coreGlow:SetRotation(t * 0.45)
    end
    coreGlow:SetVertexColor(
        math.min(1, r + 0.20),
        math.min(1, g + 0.20),
        math.min(1, b + 0.20),
        0.55 * corePulse * masterAlpha
    )

    -- Rising, twinkling sparkle particles
    for i = 1, MAX_PARTICLES do
        local p = particles[i]
        local tex = p.tex
        if i <= count then
            local sp = p.spec
            local life = (sp.phase + t * sp.speed) % 1.0
            local envelope = math.sin(life * math.pi)
            local twinkle = 0.58 + 0.42 * math.sin(t * (7.0 + sp.speed * 4.0) + i * 1.9)
            local pAlpha = envelope * twinkle * masterAlpha

            if pAlpha > 0.02 then
                local px = (sp.x + math.sin(t * 2.4 + i * 1.3) * sp.sway) * scale
                local py = (sp.y0 + life * sp.rise) * scale
                local pSize = sp.size * scale * (0.65 + 0.55 * envelope)

                tex:ClearAllPoints()
                tex:SetPoint("CENTER", frame, "CENTER", px, py)
                tex:SetSize(pSize, pSize)
                if sp.star and tex.SetRotation then
                    tex:SetRotation(t * sp.rot + i)
                end
                -- Slightly whiten the hottest peak of each twinkle for crisp metallic glint
                local hot = twinkle * 0.28
                tex:SetVertexColor(
                    math.min(1, r + hot),
                    math.min(1, g + hot),
                    math.min(1, b + hot),
                    pAlpha
                )
                tex:Show()
            else
                tex:Hide()
            end
        else
            tex:Hide()
        end
    end

    if label:IsShown() then
        label:SetAlpha(masterAlpha)
    end
end

local function startAnimating()
    frame:Show()
    frame:SetScript("OnUpdate", onUpdate)
end

function S:AttachToPlate(plate, info)
    if not plate then
        self:Hide()
        return false
    end
    if plate.IsForbidden and plate:IsForbidden() then
        self:Hide()
        return false
    end

    self:CancelPreviewTimer()
    state.previewing = false
    state.anchorPlate = plate
    state.currentInfo = info
    state.active = true
    state.targetAlpha = 1.0

    local r, g, b, a = S.ResolveColor(info and info.difficulty)
    state.colorR, state.colorG, state.colorB, state.colorAlpha = r, g, b, a

    applyAnchor()
    updateLabel()
    startAnimating()
    return true
end

function S:CancelPreviewTimer()
    if state.previewTimer and state.previewTimer.Cancel then
        state.previewTimer:Cancel()
    end
    state.previewTimer = nil
end

function S:IsPreviewing()
    return state.previewing
end

function S:StartPreview(duration)
    self:CancelPreviewTimer()
    state.previewing = true
    state.anchorPlate = nil
    state.currentInfo = {
        match = { name = "Battered Footlocker", requiredSkill = 110, kind = "footlocker" },
        difficulty = "yellow",
        canUnlock = true,
    }
    state.active = true
    state.targetAlpha = 1.0

    local r, g, b, a = S.ResolveColor("yellow")
    state.colorR, state.colorG, state.colorB, state.colorAlpha = r, g, b, a

    applyAnchor()
    updateLabel()
    startAnimating()

    if C_Timer and C_Timer.NewTimer then
        state.previewTimer = C_Timer.NewTimer(duration or 12, function()
            state.previewTimer = nil
            if state.previewing then
                S:StopPreview()
            end
        end)
    end
end

function S:StopPreview()
    self:CancelPreviewTimer()
    state.previewing = false
    self:Hide()
    if LBS.Detector then
        LBS.Detector:Evaluate()
    end
end

function S:TogglePreview()
    if state.previewing then
        self:StopPreview()
        return false
    else
        self:StartPreview(12)
        return true
    end
end

function S:Hide(immediate)
    state.active = false
    state.anchorPlate = nil
    state.currentInfo = nil
    state.targetAlpha = 0
    label:Hide()
    if immediate then
        state.alpha = 0
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        for i = 1, MAX_PARTICLES do
            particles[i].tex:Hide()
        end
    end
end

function S:RefreshStyle()
    if not state.active and not state.previewing then return end
    local diff = state.currentInfo and state.currentInfo.difficulty or "yellow"
    local r, g, b, a = S.ResolveColor(diff)
    state.colorR, state.colorG, state.colorB, state.colorAlpha = r, g, b, a
    applyAnchor()
    updateLabel()
end

LBS:On("LBS_SETTINGS_CHANGED", function()
    S:RefreshStyle()
end)
