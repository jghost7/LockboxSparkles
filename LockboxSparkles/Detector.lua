-- Detector.lua: Tracks WoW's soft-interact GameObject target, identifies rogue-unlockable
-- open-world lockboxes/footlockers/locked chests, and attaches the sparkle overlay.
local _, LBS = ...

local D = LBS.Data
local S = LBS.Sparkles

local Det = {}
LBS.Detector = Det

local evalGen = 0
local currentGUID = nil
local lastEventGUID = nil

local function isUsableFrame(f)
    return f ~= nil and (not f.IsForbidden or not f:IsForbidden())
end

local function getSoftInteractTooltip()
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok, data = pcall(C_TooltipInfo.GetUnit, "softinteract")
        if ok and type(data) == "table" then
            return data
        end
    end
    return nil
end

--- Resolve the active soft-interact nameplate (or SoftTargetFrame anchor) cleanly.
-- On WoW: Forever 1.60.1, GameObjects expose their interact icon via SoftTargetFrame on a nameplate
-- even when UnitExists("softinteract") is false.
local function getSoftInteractPlate()
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "softinteract")
        if ok and isUsableFrame(plate) then
            return plate, "direct"
        end
        local ok2, plate2 = pcall(C_NamePlate.GetNamePlateForUnit, "softinteract", true)
        if ok2 and isUsableFrame(plate2) then
            return plate2, "direct_incl"
        end
    end

    -- Fallback: scan active nameplates for softinteract token or a visible SoftTargetFrame icon.
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates, false)
        if ok and type(plates) == "table" then
            local iconFallback = nil
            for _, plate in ipairs(plates) do
                if isUsableFrame(plate) then
                    local token = plate.namePlateUnitToken
                    if token and UnitIsUnit then
                        local okU, same = pcall(UnitIsUnit, token, "softinteract")
                        if okU and same then
                            return plate, "scan_unit"
                        end
                    end
                    local uf = plate.UnitFrame
                    local stf = (uf and uf.SoftTargetFrame) or plate.SoftTargetFrame
                    if isUsableFrame(stf) and stf.Icon and stf.Icon.IsShown and stf.Icon:IsShown() then
                        iconFallback = plate
                    end
                end
            end
            if iconFallback then
                return iconFallback, "scan_icon"
            end
        end
    end

    return nil, "none"
end

function Det:GetActiveGUID()
    local liveGUID = UnitGUID and LBS.Safe(UnitGUID("softinteract"))
    if liveGUID and liveGUID ~= "" then
        return liveGUID, "unit"
    end
    if lastEventGUID and lastEventGUID ~= "" then
        return lastEventGUID, "event"
    end
    return nil, "none"
end

--- Inspect the current "softinteract" GameObject and return a structured evaluation table or nil.
function Det:InspectSoftInteract()
    if not LBS.ShouldBeActive() then
        return nil, "inactive"
    end

    -- Do NOT gate on UnitExists("softinteract"): on WoW: Forever 1.60.1, GameObjects
    -- (footlockers, chests, herbs, bobbers) return false for UnitExists even while soft-targeted.
    local guid, guidSrc = self:GetActiveGUID()
    if not guid then
        return nil, "no_guid"
    end

    local isGO, objectID = D.ParseGameObjectGUID(guid)
    if not isGO then
        return nil, "not_gameobject"
    end

    local unitName = UnitName and LBS.Safe(UnitName("softinteract"))
    local tooltipData = getSoftInteractTooltip()
    local includeChests = LBS.db and LBS.db.includeLockedChests ~= false

    local match = D.ClassifyObject(objectID, unitName, tooltipData, includeChests)
    if not match then
        return nil, "not_lockbox", {
            guid = guid,
            guidSrc = guidSrc,
            objectID = objectID,
            unitName = unitName,
        }
    end

    local playerSkill, maxSkill = LBS.GetLockpickingSkill()
    local difficulty, canUnlock = D.GetDifficulty(playerSkill, match.requiredSkill)

    -- If we truly have 0 skill and don't know Pick Lock (e.g. Rogue < level 16), treat as locked.
    -- If the Rogue DOES know Pick Lock but skill API returned 0/0 (unexpected client quirk),
    -- avoid falsely hiding boxes when requiredSkill is unknown.
    if LBS.IsRogue() and playerSkill == 0 and maxSkill == 0 and not LBS.KnowsPickLock() then
        canUnlock = false
        difficulty = "locked"
    end

    if LBS.db and LBS.db.onlyUnlockable and not canUnlock then
        return nil, "skill_too_low", {
            guid = guid,
            guidSrc = guidSrc,
            match = match,
            difficulty = difficulty,
            canUnlock = false,
            playerSkill = playerSkill,
        }
    end

    return {
        guid = guid,
        guidSrc = guidSrc,
        match = match,
        difficulty = difficulty,
        canUnlock = canUnlock,
        playerSkill = playerSkill,
    }, "ok"
end

function Det:Evaluate(isRetry)
    if S:IsPreviewing() then
        return
    end

    evalGen = evalGen + 1
    local gen = evalGen

    local info, reason = self:InspectSoftInteract()
    if not info then
        currentGUID = nil
        S:Hide()
        return nil, reason
    end

    local plate, plateSrc = getSoftInteractPlate()
    if plate and isUsableFrame(plate) then
        currentGUID = info.guid
        info.plateSrc = plateSrc
        S:AttachToPlate(plate, info)
        return info, "attached"
    end

    -- Blizzard occasionally creates the softinteract nameplate one frame after
    -- PLAYER_SOFT_INTERACT_CHANGED fires; do one short retry before giving up.
    if not isRetry and C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            if gen == evalGen then
                Det:Evaluate(true)
            end
        end)
        return info, "retry_scheduled"
    end

    currentGUID = nil
    S:Hide()
    return nil, "no_plate"
end

function Det:GetCurrentGUID()
    return currentGUID
end

function Det:GetDebugInfo()
    local guid, guidSrc = self:GetActiveGUID()
    local plate, plateSrc = getSoftInteractPlate()
    local unitName = UnitName and LBS.Safe(UnitName("softinteract"))
    local tip = getSoftInteractTooltip()
    local tipCount = tip and tip.lines and #tip.lines or 0
    return {
        guid = guid,
        guidSrc = guidSrc,
        unitName = unitName,
        plate = plate ~= nil,
        plateSrc = plateSrc,
        tipLines = tipCount,
        knowsPickLock = LBS.KnowsPickLock(),
    }
end

-- Core soft-interact & nameplate events
LBS:On("PLAYER_SOFT_INTERACT_CHANGED", function(_, _oldTarget, newTarget)
    local safeNew = LBS.Safe(newTarget)
    if type(safeNew) == "string" and safeNew ~= "" then
        lastEventGUID = safeNew
    else
        lastEventGUID = nil
    end
    Det:Evaluate()
end)

LBS:On("NAME_PLATE_UNIT_ADDED", function(_, unitToken)
    if LBS.Safe(unitToken) == "softinteract" or not currentGUID then
        Det:Evaluate()
    end
end)

LBS:On("NAME_PLATE_UNIT_REMOVED", function(_, unitToken)
    if LBS.Safe(unitToken) == "softinteract" then
        Det:Evaluate()
    end
end)

-- Skill / gear / zone / settings changes can alter unlockability or colors
LBS:On("SKILL_LINES_CHANGED", function()
    Det:Evaluate()
end)

LBS:On("PLAYER_EQUIPMENT_CHANGED", function()
    Det:Evaluate()
end)

LBS:On("PLAYER_ENTERING_WORLD", function()
    lastEventGUID = nil
    Det:Evaluate()
end)

LBS:On("LBS_READY", function()
    Det:Evaluate()
end)

LBS:On("LBS_SETTINGS_CHANGED", function()
    Det:Evaluate()
end)
