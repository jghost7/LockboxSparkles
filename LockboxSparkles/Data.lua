-- Data.lua: Curated Classic / WoW: Forever open-world lockbox & footlocker database
-- plus live tooltip classification for dynamically detecting new Classic+ locked containers.
local _, LBS = ...

local D = {}
LBS.Data = D

D.LOCKPICKING_SKILL_ID = 633
D.PICK_LOCK_SPELL_ID = 1804

-- Known Classic / WoW: Forever open-world rogue-unlockable GameObject IDs.
-- req = minimum Lockpicking skill (tooltip value always takes precedence when present,
-- since Forever or zone variants can adjust requirements).
D.OBJECT_DB = {
    -- Practice Lockboxes (Alther's Mill, Redridge Mountains)
    [178244] = { name = "Practice Lockbox",       req = 1,   kind = "lockbox" },
    [178245] = { name = "Practice Lockbox",       req = 1,   kind = "lockbox" },
    [178246] = { name = "Practice Lockbox",       req = 1,   kind = "lockbox" },

    -- Buccaneer's Strongboxes (Ship south of Ratchet, The Barrens)
    [123330] = { name = "Buccaneer's Strongbox",  req = 1,   kind = "lockbox" },
    [123331] = { name = "Buccaneer's Strongbox",  req = 1,   kind = "lockbox" },
    [123333] = { name = "Buccaneer's Strongbox",  req = 1,   kind = "lockbox" },

    -- Open-world Footlockers (70 - 300 progression)
    [179486] = { name = "Battered Footlocker",    req = 70,  kind = "footlocker" },
    [179487] = { name = "Waterlogged Footlocker", req = 70,  kind = "footlocker" },
    [179488] = { name = "Battered Footlocker",    req = 110, kind = "footlocker" },
    [179489] = { name = "Waterlogged Footlocker", req = 70,  kind = "footlocker" },
    [179490] = { name = "Battered Footlocker",    req = 150, kind = "footlocker" },
    [179491] = { name = "Waterlogged Footlocker", req = 150, kind = "footlocker" },
    [179492] = { name = "Dented Footlocker",      req = 175, kind = "footlocker" },
    [179493] = { name = "Mossy Footlocker",       req = 175, kind = "footlocker" },
    [179494] = { name = "Dented Footlocker",      req = 200, kind = "footlocker" },
    [179495] = { name = "Waterlogged Footlocker", req = 175, kind = "footlocker" },
    [179496] = { name = "Dented Footlocker",      req = 225, kind = "footlocker" },
    [179497] = { name = "Mossy Footlocker",       req = 225, kind = "footlocker" },
    [179498] = { name = "Scarlet Footlocker",     req = 250, kind = "footlocker" },

    -- Rogue class quest & specialty world lockboxes
    [180228] = { name = "Gallywix's Lockbox",     req = 1,   kind = "lockbox" },
    [123214] = { name = "Lucius's Lockbox",       req = 1,   kind = "lockbox" },
    [105570] = { name = "Fizzule's Lockbox",      req = 1,   kind = "lockbox" },
}

-- Fallback lookup by lowercase object name for WoW: Forever custom spawns or alternate IDs.
-- req = nil means "use tooltip skill if available, otherwise assume unlockable".
D.NAME_DB = {
    ["practice lockbox"]       = { req = 1,   kind = "lockbox" },
    ["buccaneer's strongbox"]  = { req = 1,   kind = "lockbox" },
    ["battered footlocker"]    = { req = 70,  kind = "footlocker" },
    ["waterlogged footlocker"] = { req = 70,  kind = "footlocker" },
    ["mossy footlocker"]       = { req = 175, kind = "footlocker" },
    ["dented footlocker"]      = { req = 175, kind = "footlocker" },
    ["scarlet footlocker"]     = { req = 250, kind = "footlocker" },
    ["rockjaw footlocker"]     = { req = 70,  kind = "footlocker" },
    ["syndicate footlocker"]   = { req = 110, kind = "footlocker" },
}

-- Substring patterns that identify open-world rogue lockboxes/footlockers by name.
D.LOCKBOX_NAME_PATTERNS = {
    "footlocker",
    "lockbox",
    "strongbox",
}

-- Generic container keywords that ONLY sparkle when live tooltip confirms they are locked.
D.CHEST_NAME_PATTERNS = {
    "chest",
    "coffer",
    "crate",
    "trunk",
    "box",
    "cache",
}

-- Gathering professions that should never be misclassified as lockboxes.
local OTHER_PROFESSIONS = {
    "herbalism",
    "mining",
    "skinning",
    "fishing",
    "engineering",
}

-- Difficulty colors (RGB 0..1)
D.DIFFICULTY_COLORS = {
    orange = { 1.00, 0.50, 0.15 }, -- guaranteed skill-up
    yellow = { 1.00, 0.85, 0.15 }, -- high skill-up chance
    green  = { 0.28, 0.85, 0.35 }, -- low skill-up chance
    grey   = { 0.65, 0.68, 0.72 }, -- trivial skill, still unlockable
    locked = { 0.90, 0.22, 0.22 }, -- skill too low to unlock
}

D.ROGUE_GOLD = { 1.00, 0.84, 0.20 }

--- Parse a WoW GameObject GUID such as "GameObject-0-4211-0-100-179486-0000123456".
-- Only reads the GameObject prefix and entry ID field (other fields may be obfuscated).
-- Returns (isGameObject, objectID_number_or_nil).
function D.ParseGameObjectGUID(guid)
    if type(guid) ~= "string" or guid == "" then
        return false, nil
    end
    if not guid:match("^GameObject%-") then
        return false, nil
    end
    local idStr = guid:match("^GameObject%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)%-")
    return true, tonumber(idStr)
end

--- Compute Lockpicking difficulty tier given player's effective skill and box required skill.
-- Classic Lockpicking thresholds:
--   skill < req          -> "locked" (cannot unlock)
--   skill < req + 25     -> "orange"
--   skill < req + 50     -> "yellow"
--   skill < req + 75     -> "green"
--   skill >= req + 75    -> "grey"
function D.GetDifficulty(playerSkill, requiredSkill)
    local skill = tonumber(playerSkill) or 0
    local req = tonumber(requiredSkill) or 0
    if req > 0 and skill < req then
        return "locked", false
    end
    if req <= 0 then
        return "yellow", true
    end
    local delta = skill - req
    if delta < 25 then
        return "orange", true
    elseif delta < 50 then
        return "yellow", true
    elseif delta < 75 then
        return "green", true
    else
        return "grey", true
    end
end

local function stripColorCodes(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    return s
end

--- Inspect tooltip lines from C_TooltipInfo.GetUnit("softinteract") (or a table of strings).
-- Returns a structured summary:
--   {
--     title = string|nil,
--     hasLockpickingReq = boolean,
--     requiredSkill = number|nil,
--     isLocked = boolean,
--     requiresKeyItem = boolean,
--     otherProfession = boolean,
--   }
function D.ParseTooltip(tooltipData)
    local result = {
        title = nil,
        hasLockpickingReq = false,
        requiredSkill = nil,
        isLocked = false,
        requiresKeyItem = false,
        otherProfession = false,
    }
    if type(tooltipData) ~= "table" then
        return result
    end
    local lines = tooltipData.lines or tooltipData
    if type(lines) ~= "table" then
        return result
    end

    local lockedGlobal = (type(LOCKED) == "string" and LOCKED ~= "") and LOCKED:lower() or "locked"

    for i, entry in ipairs(lines) do
        local rawText
        if type(entry) == "table" then
            rawText = entry.leftText
        elseif type(entry) == "string" then
            rawText = entry
        end
        if rawText and (not issecretvalue or not issecretvalue(rawText)) then
            local clean = stripColorCodes(rawText):match("^%s*(.-)%s*$") or ""
            local lower = clean:lower()

            if i == 1 and clean ~= "" then
                result.title = clean
            elseif clean ~= "" then
                -- Check for explicit Lockpicking requirement, e.g. "Requires Lockpicking (175)"
                local lpSkill = lower:match("lockpicking%s*%((%d+)%)")
                    or lower:match("lockpicking%s+(%d+)")
                if lpSkill then
                    result.hasLockpickingReq = true
                    result.isLocked = true
                    result.requiredSkill = tonumber(lpSkill)
                elseif lower:find("lockpicking", 1, true) then
                    result.hasLockpickingReq = true
                    result.isLocked = true
                elseif lower == lockedGlobal or lower == "locked" then
                    result.isLocked = true
                elseif lower:match("^requires%s+") then
                    local matchedOther = false
                    for _, prof in ipairs(OTHER_PROFESSIONS) do
                        if lower:find(prof, 1, true) then
                            result.otherProfession = true
                            matchedOther = true
                            break
                        end
                    end
                    if not matchedOther and not lower:find("lockpicking", 1, true) then
                        -- E.g. "Requires Shadowforge Key" or "Requires Thieves' Tools"
                        if not lower:find("thieves' tools", 1, true) then
                            result.requiresKeyItem = true
                        end
                    end
                end
            end
        end
    end

    return result
end

local function matchesAnyPattern(lowerName, patterns)
    if not lowerName or lowerName == "" then return false end
    for _, pat in ipairs(patterns) do
        if lowerName:find(pat, 1, true) then
            return true
        end
    end
    return false
end

--- Classify a soft-interact GameObject using ID DB, live tooltip info, and name fallbacks.
-- Returns nil if this object is NOT a rogue-unlockable open-world lockbox/chest,
-- or a descriptor table:
--   {
--     objectID = number|nil,
--     name = string,
--     kind = "footlocker"|"lockbox"|"chest",
--     requiredSkill = number|nil,
--     source = "tooltip"|"id"|"name",
--   }
function D.ClassifyObject(objectID, unitName, tooltipData, includeLockedChests)
    local tip = D.ParseTooltip(tooltipData)
    if tip.otherProfession then
        return nil
    end

    local resolvedName = (unitName and unitName ~= "" and unitName) or tip.title or ""
    local lowerName = resolvedName:lower()

    -- 1. Highest authority: Tooltip explicitly states "Requires Lockpicking (N)".
    --    Automatically catches brand-new WoW: Forever Classic+ lockboxes & locked chests!
    if tip.hasLockpickingReq then
        local dbEntry = objectID and D.OBJECT_DB[objectID]
        local kind = (dbEntry and dbEntry.kind)
            or (lowerName:find("footlocker", 1, true) and "footlocker")
            or (matchesAnyPattern(lowerName, D.LOCKBOX_NAME_PATTERNS) and "lockbox")
            or "chest"
        if kind == "chest" and not includeLockedChests and not dbEntry then
            return nil
        end
        return {
            objectID = objectID,
            name = resolvedName,
            kind = kind,
            requiredSkill = tip.requiredSkill or (dbEntry and dbEntry.req) or nil,
            source = "tooltip",
        }
    end

    -- If tooltip explicitly says it requires a key item (and not Lockpicking), skip it.
    if tip.requiresKeyItem then
        return nil
    end

    -- 2. Curated GameObject ID database (exact Classic / Forever footlockers & practice boxes).
    local dbEntry = objectID and D.OBJECT_DB[objectID]
    if dbEntry then
        return {
            objectID = objectID,
            name = (resolvedName ~= "" and resolvedName) or dbEntry.name,
            kind = dbEntry.kind,
            requiredSkill = tip.requiredSkill or dbEntry.req,
            source = "id",
        }
    end

    -- 3. Known exact lockbox/footlocker name (catches alternate IDs of known footlockers).
    local nameEntry = D.NAME_DB[lowerName]
    if nameEntry then
        return {
            objectID = objectID,
            name = resolvedName,
            kind = nameEntry.kind,
            requiredSkill = tip.requiredSkill or nameEntry.req,
            source = "name",
        }
    end

    -- 4. Generic lockbox/footlocker name patterns (e.g., new Forever "* Footlocker" or "* Lockbox").
    if matchesAnyPattern(lowerName, D.LOCKBOX_NAME_PATTERNS) then
        local kind = lowerName:find("footlocker", 1, true) and "footlocker" or "lockbox"
        return {
            objectID = objectID,
            name = resolvedName,
            kind = kind,
            requiredSkill = tip.requiredSkill,
            source = "name",
        }
    end

    -- 5. Locked open-world chests (Solid Chest, Large Iron Bound Chest, etc.) ONLY when tooltip says "Locked".
    if includeLockedChests and tip.isLocked and matchesAnyPattern(lowerName, D.CHEST_NAME_PATTERNS) then
        return {
            objectID = objectID,
            name = resolvedName,
            kind = "chest",
            requiredSkill = tip.requiredSkill,
            source = "tooltip",
        }
    end

    return nil
end
