-- Core.lua: Addon namespace, SavedVariables, secret-value safety, Lockpicking skill reader,
-- combat-safe Soft-Interact CVar management, and event bus.
local ADDON, LBS = ...
_G.LockboxSparkles = LBS

local D = LBS.Data

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
LBS.version = (getMeta and getMeta(ADDON, "Version")) or "1.0.0"
LBS.ADDON = ADDON

LBS.DEFAULTS = {
    enabled = true,
    roguesOnly = true,
    onlyUnlockable = true,
    includeLockedChests = true,
    colorMode = "gold", -- "gold" | "difficulty" | "custom"
    customColor = { 1.00, 0.84, 0.20 },
    scale = 1.0,
    intensity = 12,
    yOffset = -12,
    showLabel = false,
    manageCVars = true,
    interactRange = 40,
    savedCVars = nil,
}

local MANAGED_CVAR_KEYS = {
    "SoftTargetInteract",
    "SoftTargetIconGameObject",
    "SoftTargetIconInteract",
    "SoftTargetLowPriorityIcons",
    "SoftTargetInteractArc",
    "SoftTargetInteractRange",
    "SoftTargetInteractRangeIsHard",
}

local function copyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                copyDefaults(dst[k], v)
            else
                dst[k] = v
            end
        end
    end
    return dst
end

--- Guard against Midnight / 1.60.1 secret values that cannot be compared or stored.
function LBS.Safe(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

function LBS.Print(...)
    print("|cffffd433Lockbox Sparkles:|r", ...)
end

---------------------------------------------------------------------------
-- Event bus (one frame, pcall-isolated handlers)
---------------------------------------------------------------------------
local busFrame = CreateFrame("Frame")
local handlers = {}

function LBS:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        if not event:find("^LBS_") then
            busFrame:RegisterEvent(event)
        end
    end
    table.insert(handlers[event], fn)
end

function LBS:Fire(event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok and geterrorhandler then
            geterrorhandler()(err)
        end
    end
end

busFrame:SetScript("OnEvent", function(_, event, ...)
    LBS:Fire(event, ...)
end)

---------------------------------------------------------------------------
-- Player class & Lockpicking skill
---------------------------------------------------------------------------
function LBS.IsRogue()
    if not UnitClass then return false end
    local _, classToken = UnitClass("player")
    return LBS.Safe(classToken) == "ROGUE"
end

function LBS.KnowsPickLock()
    if IsPlayerSpell then
        local ok, known = pcall(IsPlayerSpell, D.PICK_LOCK_SPELL_ID)
        if ok and known then return true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, D.PICK_LOCK_SPELL_ID)
        if ok and known then return true end
    end
    return false
end

--- Returns (effectiveSkill, maxRank, baseRank, modifier) for Rogue Lockpicking.
function LBS.GetLockpickingSkill()
    -- Primary (WoW: Forever 1.60.1+): C_SkillInfo API.
    if C_SkillInfo then
        if C_SkillInfo.GetSkillLineInfoByID then
            local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, D.LOCKPICKING_SKILL_ID)
            if ok and type(info) == "table" then
                local base = LBS.Safe(info.rank) or 0
                local bonus = (LBS.Safe(info.tempPoints) or 0)
                    + (LBS.Safe(info.skillModifier) or 0)
                    + (LBS.Safe(info.modifier) or 0)
                local cap = LBS.Safe(info.maxRank) or 0
                if base > 0 or cap > 0 then
                    return base + bonus, cap, base, bonus
                end
            end
        end
        if C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
            local okCount, count = pcall(C_SkillInfo.GetNumSkillLines)
            count = okCount and (LBS.Safe(count) or 0) or 0
            for i = 1, count do
                local okInfo, info = pcall(C_SkillInfo.GetSkillLineInfo, i)
                if okInfo and type(info) == "table" and not info.isHeader then
                    local sid = LBS.Safe(info.skillID) or LBS.Safe(info.skillLineID)
                    local name = LBS.Safe(info.name)
                    if sid == D.LOCKPICKING_SKILL_ID or (name and name:lower() == "lockpicking") then
                        local base = LBS.Safe(info.rank) or 0
                        local bonus = (LBS.Safe(info.tempPoints) or 0)
                            + (LBS.Safe(info.skillModifier) or 0)
                            + (LBS.Safe(info.modifier) or 0)
                        local cap = LBS.Safe(info.maxRank) or 0
                        return base + bonus, cap, base, bonus
                    end
                end
            end
        end
    end

    -- Fallback: Classic global skill line API.
    if GetNumSkillLines and GetSkillLineInfo then
        local count = LBS.Safe(GetNumSkillLines()) or 0
        for i = 1, count do
            local name, isHeader, _, rank, tempPoints, modifier, maxRank = GetSkillLineInfo(i)
            name = LBS.Safe(name)
            if not isHeader and name and name:lower() == "lockpicking" then
                local base = LBS.Safe(rank) or 0
                local bonus = (LBS.Safe(tempPoints) or 0) + (LBS.Safe(modifier) or 0)
                local cap = LBS.Safe(maxRank) or 0
                return base + bonus, cap, base, bonus
            end
        end
    end

    -- Fallback: Modern profession slots if Lockpicking is exposed there.
    if GetProfessions and GetProfessionInfo then
        for _, idx in pairs({ GetProfessions() }) do
            if idx then
                local name, _, rank, maxRank, _, _, skillLine, skillModifier = GetProfessionInfo(idx)
                name = LBS.Safe(name)
                skillLine = LBS.Safe(skillLine)
                if skillLine == D.LOCKPICKING_SKILL_ID or (name and name:lower() == "lockpicking") then
                    local base = LBS.Safe(rank) or 0
                    local bonus = LBS.Safe(skillModifier) or 0
                    local cap = LBS.Safe(maxRank) or 0
                    return base + bonus, cap, base, bonus
                end
            end
        end
    end

    return 0, 0, 0, 0
end

function LBS.ShouldBeActive()
    if not LBS.db or not LBS.db.enabled then
        return false
    end
    if LBS.db.roguesOnly and not LBS.IsRogue() then
        return false
    end
    return true
end

---------------------------------------------------------------------------
-- Combat-safe Soft-Interact CVar management
-- Only touches GameObject soft-interact CVars; never touches SoftTargetEnemy,
-- SoftTargetFriend, or SoftTargetNameplateInteract.
---------------------------------------------------------------------------
local pendingCVarAction = nil -- "apply" | "restore" | nil

local function getCVar(name)
    if C_CVar and C_CVar.GetCVar then
        local ok, v = pcall(C_CVar.GetCVar, name)
        if ok then return LBS.Safe(v) end
    end
    if GetCVar then
        local ok, v = pcall(GetCVar, name)
        if ok then return LBS.Safe(v) end
    end
    return nil
end

local function setCVar(name, value)
    local strVal = tostring(value)
    if getCVar(name) == strVal then return true end
    if C_CVar and C_CVar.SetCVar then
        local ok = pcall(C_CVar.SetCVar, name, strVal)
        return ok
    end
    if SetCVar then
        local ok = pcall(SetCVar, name, strVal)
        return ok
    end
    return false
end

local function snapshotOriginalCVars()
    if not LBS.db then return end
    if LBS.db.savedCVars then return end
    local snap = {}
    for _, key in ipairs(MANAGED_CVAR_KEYS) do
        local v = getCVar(key)
        if v ~= nil then
            snap[key] = v
        end
    end
    LBS.db.savedCVars = snap
end

function LBS.ApplyCVars()
    if not LBS.db or not LBS.db.manageCVars or not LBS.ShouldBeActive() then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        pendingCVarAction = "apply"
        return false
    end
    pendingCVarAction = nil
    snapshotOriginalCVars()

    local range = math.max(10, math.min(40, math.floor((tonumber(LBS.db.interactRange) or 40) + 0.5)))
    setCVar("SoftTargetInteract", "3")
    setCVar("SoftTargetIconGameObject", "1")
    setCVar("SoftTargetIconInteract", "1")
    setCVar("SoftTargetLowPriorityIcons", "1")
    setCVar("SoftTargetInteractArc", "2")
    setCVar("SoftTargetInteractRange", tostring(range))
    setCVar("SoftTargetInteractRangeIsHard", "0")
    return true
end

function LBS.RestoreCVars()
    if not LBS.db or not LBS.db.savedCVars then
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        pendingCVarAction = "restore"
        return false
    end
    pendingCVarAction = nil
    for _, key in ipairs(MANAGED_CVAR_KEYS) do
        local orig = LBS.db.savedCVars[key]
        if orig ~= nil then
            setCVar(key, orig)
        end
    end
    LBS.db.savedCVars = nil
    return true
end

LBS:On("PLAYER_REGEN_ENABLED", function()
    if pendingCVarAction == "apply" then
        LBS.ApplyCVars()
    elseif pendingCVarAction == "restore" then
        LBS.RestoreCVars()
    end
end)

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
LBS:On("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= ADDON then return end
    LockboxSparklesDB = LockboxSparklesDB or {}
    LBS.db = copyDefaults(LockboxSparklesDB, LBS.DEFAULTS)
    LBS:Fire("LBS_INIT")
end)

LBS:On("PLAYER_LOGIN", function()
    if not LBS.db then
        LockboxSparklesDB = LockboxSparklesDB or {}
        LBS.db = copyDefaults(LockboxSparklesDB, LBS.DEFAULTS)
        LBS:Fire("LBS_INIT")
    end
    if LBS.db.manageCVars and LBS.ShouldBeActive() then
        LBS.ApplyCVars()
    end
    LBS:Fire("LBS_READY")
end)
