-- Headless WoW 1.60.1 API mock + unit tests for LockboxSparkles.

local MOCK = {
    classToken = "ROGUE",
    knowsPickLock = true,
    inCombat = false,
    skillRank = 120,
    skillBonus = 5,
    skillMax = 150,
    cvars = {
        SoftTargetInteract = "0",
        SoftTargetIconGameObject = "0",
        SoftTargetInteractArc = "1",
        SoftTargetInteractRange = "10",
        SoftTargetEnemy = "0",
        SoftTargetFriend = "0",
        SoftTargetNameplateInteract = "0",
    },
    softUnit = nil, -- { guid=..., name=..., tooltip=..., plate=... }
    events = {},
    timers = {},
    now = 0,
    prints = {},
    settingsCategories = {},
    openedCategory = nil,
}

---------------------------------------------------------------------------
-- WoW globals mock
---------------------------------------------------------------------------
SlashCmdList = {}
LOCKED = "Locked"

function strsplit(sep, str)
    local out = {}
    local pattern = "([^" .. sep .. "]*)"
    local idx = 1
    while true do
        local s, e = str:find(sep, idx, true)
        if not s then
            table.insert(out, str:sub(idx))
            break
        end
        table.insert(out, str:sub(idx, s - 1))
        idx = e + 1
    end
    return unpack(out)
end

local SECRET_SENTINEL = setmetatable({}, { __tostring = function() return "<SECRET>" end })
function issecretvalue(v)
    return v == SECRET_SENTINEL
end

function print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring(select(i, ...))
    end
    table.insert(MOCK.prints, table.concat(parts, " "))
end

function geterrorhandler()
    return function(err) error(err) end
end

local Obj = {}
Obj.__index = function(t, k)
    local v = rawget(Obj, k)
    if v then return v end
    return function() end
end

function Obj.new(kind)
    return setmetatable({
        kind = kind,
        shown = false,
        scripts = {},
        points = {},
        alpha = 1,
        checked = false,
        value = 0,
        forbidden = false,
    }, Obj)
end

function Obj:Show()
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Obj:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Obj:IsShown() return self.shown end
function Obj:SetScript(k, fn) self.scripts[k] = fn end
function Obj:GetScript(k) return self.scripts[k] end
function Obj:RegisterEvent(e)
    MOCK.events[e] = MOCK.events[e] or {}
    table.insert(MOCK.events[e], self)
end
function Obj:ClearAllPoints() self.points = {} end
function Obj:SetPoint(...) table.insert(self.points, { ... }) end
function Obj:GetPoint(i) return unpack(self.points[i or 1] or {}) end
function Obj:SetSize(w, h) self.w, self.h = w, h end
function Obj:SetAlpha(a) self.alpha = a end
function Obj:GetAlpha() return self.alpha end
function Obj:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Obj:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function Obj:SetText(t) self.text = t end
function Obj:GetText() return self.text end
function Obj:SetTexture(t) self.texture = t end
function Obj:SetRotation(r) self.rotation = r end
function Obj:SetChecked(v) self.checked = v and true or false end
function Obj:GetChecked() return self.checked end
function Obj:SetValue(v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function Obj:GetValue() return self.value end
function Obj:SetEnabled(v) self.enabled = v end
function Obj:IsForbidden() return self.forbidden end
function Obj:CreateTexture() return Obj.new("Texture") end
function Obj:CreateFontString() return Obj.new("FontString") end

function CreateFrame(kind, name, parent)
    local o = Obj.new(kind)
    o.parent = parent
    if name then _G[name] = o end
    return o
end

UIParent = Obj.new("Frame")
GameTooltip = Obj.new("GameTooltip")

C_AddOns = {
    GetAddOnMetadata = function(_, field)
        if field == "Version" then return "1.0.0" end
        return nil
    end,
}

C_CVar = {
    GetCVar = function(k) return MOCK.cvars[k] end,
    SetCVar = function(k, v) MOCK.cvars[k] = tostring(v) end,
}

C_Timer = {
    After = function(delay, fn)
        table.insert(MOCK.timers, { at = MOCK.now + delay, fn = fn, cancelled = false })
    end,
    NewTimer = function(delay, fn)
        local t = { at = MOCK.now + delay, fn = fn, cancelled = false }
        function t:Cancel() self.cancelled = true end
        table.insert(MOCK.timers, t)
        return t
    end,
}

Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        local cat = { panel = panel, name = name, id = #MOCK.settingsCategories + 1 }
        function cat:GetID() return self.id end
        table.insert(MOCK.settingsCategories, cat)
        return cat
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) MOCK.openedCategory = id end,
}

function UnitClass(unit)
    if unit == "player" then return "Rogue", MOCK.classToken end
    return nil, nil
end

function IsPlayerSpell(id)
    if id == 1804 then return MOCK.knowsPickLock end
    return false
end

function InCombatLockdown()
    return MOCK.inCombat
end

function GetNumSkillLines()
    return MOCK.skillRank > 0 and 2 or 1
end

function GetSkillLineInfo(idx)
    if idx == 1 then
        return "Class Skills", true, nil, 0, 0, 0, 0
    elseif idx == 2 then
        return "Lockpicking", false, nil, MOCK.skillRank, 0, MOCK.skillBonus, MOCK.skillMax
    end
end

function UnitExists(unit)
    if unit == "softinteract" then return MOCK.softUnit ~= nil end
    return false
end

function UnitGUID(unit)
    if unit == "softinteract" and MOCK.softUnit then return MOCK.softUnit.guid end
    return nil
end

function UnitName(unit)
    if unit == "softinteract" and MOCK.softUnit then return MOCK.softUnit.name end
    return nil
end

C_TooltipInfo = {
    GetUnit = function(unit)
        if unit == "softinteract" and MOCK.softUnit then return MOCK.softUnit.tooltip end
        return nil
    end,
}

C_NamePlate = {
    GetNamePlateForUnit = function(unit)
        if unit == "softinteract" and MOCK.softUnit then return MOCK.softUnit.plate end
        return nil
    end,
}

local function fire(event, ...)
    for _, f in ipairs(MOCK.events[event] or {}) do
        if f.scripts.OnEvent then
            f.scripts.OnEvent(f, event, ...)
        end
    end
end

local function advanceTimers(sec)
    MOCK.now = MOCK.now + sec
    local i = 1
    while i <= #MOCK.timers do
        local t = MOCK.timers[i]
        if t.at <= MOCK.now then
            table.remove(MOCK.timers, i)
            if not t.cancelled then t.fn() end
        else
            i = i + 1
        end
    end
end

local function tickSparkles(LBS, dt)
    local fn = LBS.Sparkles.frame:GetScript("OnUpdate")
    if fn then fn(LBS.Sparkles.frame, dt) end
end

---------------------------------------------------------------------------
-- Test Suite Runner
---------------------------------------------------------------------------
return function(LBS)
    local passed, failed = 0, 0

    local function check(name, cond, detail)
        if cond then
            passed = passed + 1
        else
            failed = failed + 1
            io.stderr:write("FAIL: " .. name .. (detail and (" (" .. tostring(detail) .. ")") or "") .. "\n")
        end
    end

    local D = LBS.Data
    local S = LBS.Sparkles
    local Det = LBS.Detector

    -- 1. Boot lifecycle & CVars
    fire("ADDON_LOADED", "LockboxSparkles")
    fire("PLAYER_LOGIN")
    check("db initialized", LBS.db ~= nil and LBS.db.enabled == true)
    check("Settings category registered", #MOCK.settingsCategories == 1)
    check("SoftTargetInteract enabled", MOCK.cvars.SoftTargetInteract == "3")
    check("SoftTargetIconGameObject enabled", MOCK.cvars.SoftTargetIconGameObject == "1")
    check("SoftTargetInteractArc widened", MOCK.cvars.SoftTargetInteractArc == "2")
    check("SoftTargetInteractRange set to 40", MOCK.cvars.SoftTargetInteractRange == "40")
    check("SoftTargetEnemy untouched", MOCK.cvars.SoftTargetEnemy == "0")
    check("SoftTargetFriend untouched", MOCK.cvars.SoftTargetFriend == "0")
    check("SoftTargetNameplateInteract untouched", MOCK.cvars.SoftTargetNameplateInteract == "0")

    -- 2. GUID parsing
    local isGO, objID = D.ParseGameObjectGUID("GameObject-0-4211-0-100-179488-0000123456")
    check("Parses GameObject GUID", isGO == true and objID == 179488)
    local isCreature, cid = D.ParseGameObjectGUID("Creature-0-4211-0-100-1234-0000123456")
    check("Rejects Creature GUID", isCreature == false and cid == nil)

    -- 3. Lockpicking skill includes gear bonus (+5 Dark Leather Gloves)
    local skill, cap, base, bonus = LBS.GetLockpickingSkill()
    check("Effective skill includes modifier", skill == 125 and base == 120 and bonus == 5 and cap == 150)

    -- 4. Known footlocker ID detection & sparkle attachment
    local plate1 = Obj.new("Frame")
    MOCK.softUnit = {
        guid = "GameObject-0-4211-0-100-179488-000001",
        name = "Battered Footlocker",
        tooltip = { lines = { { leftText = "Battered Footlocker" }, { leftText = "Requires Lockpicking (110)" } } },
        plate = plate1,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Attaches to unlockable Battered Footlocker", S.frame:IsShown() == true and S.state.anchorPlate == plate1)
    check("Anchors to plate via SetPoint", select(2, S.frame:GetPoint(1)) == plate1)
    tickSparkles(LBS, 0.05)
    check("Animation ramps alpha on tick", S.state.alpha > 0)

    -- 5. Skill too low hidden when onlyUnlockable = true (default)
    local plate2 = Obj.new("Frame")
    MOCK.softUnit = {
        guid = "GameObject-0-4211-0-100-179498-000002",
        name = "Scarlet Footlocker",
        tooltip = { lines = { { leftText = "Scarlet Footlocker" }, { leftText = "|cffff2020Requires Lockpicking (250)|r" } } },
        plate = plate2,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Hides Scarlet Footlocker (250) when skill is 125 & onlyUnlockable=true", S.state.active == false)

    -- 6. Skill too low shown in dimmed red when onlyUnlockable = false
    LBS.db.onlyUnlockable = false
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Shows Scarlet Footlocker when onlyUnlockable=false", S.state.active == true and S.state.colorR > 0.8 and S.state.colorG < 0.3)
    LBS.db.onlyUnlockable = true

    -- 7. Brand-new WoW: Forever custom lockbox detected purely from live tooltip
    local plate3 = Obj.new("Frame")
    MOCK.softUnit = {
        guid = "GameObject-0-4211-0-100-999888-000003",
        name = "Gilnean Strongbox",
        tooltip = { lines = { { leftText = "Gilnean Strongbox" }, { leftText = "Requires Lockpicking (125)" } } },
        plate = plate3,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Detects custom Forever box via tooltip (125 <= 125 with +5 gloves)", S.state.active == true and S.state.anchorPlate == plate3)

    -- 8. Unlocked normal chest does NOT sparkle; locked chest DOES sparkle
    local plate4 = Obj.new("Frame")
    MOCK.softUnit = {
        guid = "GameObject-0-4211-0-100-2844-000004",
        name = "Solid Chest",
        tooltip = { lines = { { leftText = "Solid Chest" } } },
        plate = plate4,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Ignores unlocked Solid Chest", S.state.active == false)

    MOCK.softUnit.tooltip = { lines = { { leftText = "Solid Chest" }, { leftText = "Locked" } } }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Sparkles locked Solid Chest when includeLockedChests=true", S.state.active == true)

    LBS.db.includeLockedChests = false
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Ignores locked Solid Chest when includeLockedChests=false", S.state.active == false)
    LBS.db.includeLockedChests = true

    -- 9. Gathering nodes & key-only doors never sparkle
    MOCK.softUnit = {
        guid = "GameObject-0-4211-0-100-1731-000005",
        name = "Copper Vein",
        tooltip = { lines = { { leftText = "Copper Vein" }, { leftText = "Requires Mining (1)" } } },
        plate = plate4,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Ignores Mining node", S.state.active == false)

    MOCK.softUnit = {
        guid = "GameObject-0-4211-0-100-104600-000006",
        name = "Scarlet Gate",
        tooltip = { lines = { { leftText = "Scarlet Gate" }, { leftText = "Requires The Scarlet Key" } } },
        plate = plate4,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Ignores key-only door", S.state.active == false)

    -- 10. Non-GameObject (NPC/Creature) never sparkles
    MOCK.softUnit = {
        guid = "Creature-0-4211-0-100-5555-000007",
        name = "Battered Footlocker Mimic",
        tooltip = { lines = { { leftText = "Battered Footlocker" } } },
        plate = plate4,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Ignores Creature GUID even with lockbox name", S.state.active == false)

    -- 11. Secret value safety
    MOCK.softUnit = {
        guid = SECRET_SENTINEL,
        name = SECRET_SENTINEL,
        tooltip = { lines = { { leftText = SECRET_SENTINEL } } },
        plate = plate4,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Handles secret values without error", S.state.active == false)

    -- 12. Forbidden nameplate safety
    local forbiddenPlate = Obj.new("Frame")
    forbiddenPlate.forbidden = true
    MOCK.softUnit = {
        guid = "GameObject-0-4211-0-100-179486-000008",
        name = "Battered Footlocker",
        tooltip = { lines = { { leftText = "Battered Footlocker" } } },
        plate = forbiddenPlate,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Never anchors to forbidden nameplate", S.state.active == false)

    -- 13. Deferred plate creation retry (0.05s)
    local latePlate = Obj.new("Frame")
    MOCK.softUnit = {
        guid = "GameObject-0-4211-0-100-179487-000009",
        name = "Waterlogged Footlocker",
        tooltip = { lines = { { leftText = "Waterlogged Footlocker" } } },
        plate = nil,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Waits for late nameplate", S.state.active == false)
    MOCK.softUnit.plate = latePlate
    advanceTimers(0.06)
    check("Attaches after deferred retry", S.state.active == true and S.state.anchorPlate == latePlate)

    -- 14. Difficulty color mode
    LBS.db.colorMode = "difficulty"
    S:RefreshStyle()
    -- skill 125, Waterlogged req 70 -> delta = 55 -> green!
    local diff = D.GetDifficulty(125, 70)
    check("Difficulty math 125 vs 70 is green", diff == "green")
    check("Difficulty color applies green tint", S.state.colorG > 0.8 and S.state.colorR < 0.4)
    LBS.db.colorMode = "gold"

    -- 15. Rogue-only gating
    MOCK.classToken = "WARRIOR"
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Inactive on Warrior when roguesOnly=true", S.state.active == false)
    LBS.db.roguesOnly = false
    fire("PLAYER_SOFT_INTERACT_CHANGED")
    check("Active on Warrior when roguesOnly=false", S.state.active == true)
    MOCK.classToken = "ROGUE"
    LBS.db.roguesOnly = true

    -- 16. Combat-safe CVar deferral & restoration
    MOCK.inCombat = true
    LBS.db.interactRange = 25
    local appliedNow = LBS.ApplyCVars()
    check("Defers CVar apply during combat", appliedNow == false and MOCK.cvars.SoftTargetInteractRange == "40")
    MOCK.inCombat = false
    fire("PLAYER_REGEN_ENABLED")
    check("Applies deferred CVar on PLAYER_REGEN_ENABLED", MOCK.cvars.SoftTargetInteractRange == "25")

    LBS.RestoreCVars()
    check("Restores original CVars cleanly",
        MOCK.cvars.SoftTargetInteract == "0"
        and MOCK.cvars.SoftTargetIconGameObject == "0"
        and MOCK.cvars.SoftTargetInteractArc == "1"
        and MOCK.cvars.SoftTargetInteractRange == "10"
    )

    -- 17. WoW: Forever 1.60.1 specifics: C_SkillInfo + UnitExists("softinteract")==false + event GUID + GetNamePlates fallback
    C_SkillInfo = {
        GetSkillLineInfoByID = function(id)
            if id == 633 then
                return { name = "Lockpicking", skillID = 633, rank = 195, maxRank = 200, modifier = 5 }
            end
        end,
    }
    local fSkill, fCap, fBase, fBonus = LBS.GetLockpickingSkill()
    check("Reads C_SkillInfo.GetSkillLineInfoByID(633)", fSkill == 200 and fBase == 195 and fBonus == 5 and fCap == 200)

    -- Simulate GameObject where UnitExists("softinteract") is false and UnitGUID("softinteract") is nil,
    -- while PLAYER_SOFT_INTERACT_CHANGED passes the GameObject GUID and GetNamePlates has a plate with SoftTargetFrame.Icon shown.
    local origUnitExists = UnitExists
    local origUnitGUID = UnitGUID
    local origGetPlate = C_NamePlate.GetNamePlateForUnit
    UnitExists = function() return false end
    UnitGUID = function() return nil end
    C_NamePlate.GetNamePlateForUnit = function() return nil end

    local scanPlate = Obj.new("Frame")
    scanPlate.UnitFrame = { SoftTargetFrame = { Icon = Obj.new("Texture") } }
    scanPlate.UnitFrame.SoftTargetFrame.Icon:Show()
    C_NamePlate.GetNamePlates = function() return { scanPlate } end

    MOCK.softUnit = {
        guid = nil,
        name = nil,
        tooltip = nil,
        plate = nil,
    }
    fire("PLAYER_SOFT_INTERACT_CHANGED", nil, "GameObject-0-4211-0-100-179493-000010")
    check("Attaches to Mossy Footlocker (175) when UnitExists=false via event GUID + GetNamePlates fallback",
        S.state.active == true and S.state.anchorPlate == scanPlate)

    -- Clearing soft interact hides sparkles
    fire("PLAYER_SOFT_INTERACT_CHANGED", "GameObject-0-4211-0-100-179493-000010", nil)
    check("Clears sparkles when PLAYER_SOFT_INTERACT_CHANGED sends nil", S.state.active == false)

    UnitExists = origUnitExists
    UnitGUID = origUnitGUID
    C_NamePlate.GetNamePlateForUnit = origGetPlate
    C_NamePlate.GetNamePlates = nil
    C_SkillInfo = nil

    -- 18. Slash commands & preview mode
    SlashCmdList["LOCKBOXSPARKLES"]("test")
    check("/lbs test starts preview", S:IsPreviewing() == true and S.frame:IsShown() == true)
    advanceTimers(13)
    check("Preview auto-stops after duration", S:IsPreviewing() == false)
    SlashCmdList["LOCKBOXSPARKLES"]("status")
    check("/lbs status prints info", #MOCK.prints > 0)
    SlashCmdList["LOCKBOXSPARKLES"]("")
    check("/lbs opens Blizzard Settings category", MOCK.openedCategory == 1)

    return passed, failed
end
