-- ============================================================================
-- DRTracker_Fixed.lua - 100% Gladius-Compatible DR Tracking System
-- ============================================================================
-- Complete rewrite to match Gladius DR logic EXACTLY
-- Fixes false DR stage reporting by using identical reset/timing logic
-- ============================================================================

local AC = _G.ArenaCore
if not AC then return end

-- Use the same DRList library as Gladius
local DRList = LibStub("DRList-1.0")
if not DRList then
    print("|cffFF0000[ArenaCore DR]|r DRList-1.0 library not found!")
    return
end

local DRTracker = {}
DRTracker.frames = {} -- Store DR frames per unit (arena1, arena2, arena3)

-- ============================================================================
-- DR TEXT DISPLAY (EXACT GLADIUS LOGIC)
-- ============================================================================
local drTexts = {
    [1] = {"½", 0, 1, 0},      -- Stage 1: Green ½
    [0.5] = {"¼", 1, 0.65, 0}, -- Stage 2: Yellow ¼  
    [0.25] = {"%", 1, 0, 0},   -- Stage 3: Red %
    [0] = {"%", 1, 0, 0},      -- Immune: Red %
}

-- ============================================================================
-- AURA HELPER FUNCTIONS (EXACT GLADIUS PATTERN)
-- ============================================================================
local UnitAura = UnitAura
if UnitAura == nil then
    -- Deprecated in 10.2.5
    UnitAura = function(unitToken, index, filter)
        local auraData = C_UnitAuras.GetAuraDataByIndex(unitToken, index, filter)
        if not auraData then return nil end
        return AuraUtil.UnpackAuraData(auraData)
    end
end

local function WA_GetUnitAura(unit, spell, filter)
    if filter and not filter:upper():find("FUL") then
        filter = filter.."|HELPFUL"
    end
    for i = 1, 255 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, filter)
        if not name then return end
        if spell == spellId or spell == name then
            return UnitAura(unit, i, filter)
        end
    end
end

local function WA_GetUnitDebuff(unit, spell, filter)
    filter = filter and filter.."|HARMFUL" or "HARMFUL"
    return WA_GetUnitAura(unit, spell, filter)
end

-- ============================================================================
-- CORE DR TRACKING LOGIC (100% GLADIUS COMPATIBLE)
-- ============================================================================

function DRTracker:GetUnitFromGUID(guid)
    if not guid then return nil end
    
    for i = 1, 3 do
        local unit = "arena" .. i
        if UnitGUID(unit) == guid then
            return unit
        end
    end
    
    return nil
end

function DRTracker:IsSourceFriendly(sourceGUID, sourceFlags)
    -- Check if source is player or party member (EXACT GLADIUS LOGIC)
    if sourceFlags and bit then
        local mine = bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0
        local party = bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0
        local raid = bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0
        if mine or party or raid then
            return true
        end
    end
    
    if not sourceGUID then return false end
    
    if UnitGUID("player") == sourceGUID then return true end
    if UnitGUID("pet") == sourceGUID then return true end
    
    for i = 1, 4 do
        if UnitGUID("party" .. i) == sourceGUID then return true end
        if UnitGUID("partypet" .. i) == sourceGUID then return true end
    end
    
    return false
end

-- ============================================================================
-- DR APPLICATION LOGIC (EXACT GLADIUS IMPLEMENTATION)
-- ============================================================================
function DRTracker:DRApplied(unit, spellID, force, auraDuration)
    local drCat = DRList:GetCategoryBySpellID(spellID)
    if not drCat then return end
    
    -- Get or create frame storage for this unit
    if not self.frames[unit] then
        self.frames[unit] = {}
    end
    
    -- Get or create tracker for this DR category
    local tracked = self.frames[unit][drCat]
    if not tracked then
        tracked = {
            active = false,
            diminished = 1.0,
            reset = 0,
            timeLeft = 0,
        }
        self.frames[unit][drCat] = tracked
    end
    
    tracked.active = true
    
    -- CRITICAL FIX: Use EXACT Gladius DR calculation logic
    if tracked.reset <= GetTime() then
        -- DR window expired - reset to full duration (EXACT GLADIUS LOGIC)
        tracked.diminished = DRList:GetNextDR(1, drCat) * 2
    elseif auraDuration then
        -- DR window still active - calculate next diminished value (EXACT GLADIUS LOGIC)
        tracked.diminished = DRList:NextDR(tracked.diminished, drCat)
    end
    
    -- CRITICAL FIX: Use EXACT Gladius timing logic
    if auraDuration then
        tracked.timeLeft = DRList:GetResetTime(drCat) + auraDuration
    else
        tracked.timeLeft = DRList:GetResetTime(drCat)
    end
    
    tracked.reset = tracked.timeLeft + GetTime()
    
    -- Update visual display using EXACT Gladius text mapping
    local text, r, g, b = unpack(drTexts[tracked.diminished] or drTexts[0])
    
    -- Now update the visual icon via DR module
    self:UpdateDRIcon(unit, drCat, spellID, tracked, text, r, g, b)
end

-- ============================================================================
-- UPDATE DR ICON (Calls into DR.lua visual system)
-- ============================================================================
function DRTracker:UpdateDRIcon(unit, category, spellID, tracked, text, r, g, b)
    -- Get the DR module for visual updates
    local drModule = AC.MasterFrameManager and AC.MasterFrameManager.DR
    if not drModule then return end
    
    -- Get the arena frame
    local frames = AC.FrameManager and AC.FrameManager.GetFrames and AC.FrameManager:GetFrames()
    if not frames then return end
    
    local index = tonumber(unit:match("arena(%d+)"))
    if not index or not frames[index] then return end
    
    -- Call the DR module's TrackApplication function with corrected stage info
    local unitGUID = UnitGUID(unit)
    if drModule.TrackApplication then
        -- Convert diminished value to stage number for display
        local stage
        if tracked.diminished >= 1.0 then
            stage = 1  -- Full duration
        elseif tracked.diminished >= 0.5 then
            stage = 2  -- Half duration  
        elseif tracked.diminished >= 0.25 then
            stage = 3  -- Quarter duration
        else
            stage = 3  -- Immune (show as stage 3)
        end
        
        drModule:TrackApplication(unitGUID, spellID, category, stage, text, r, g, b)
    end
end

-- ============================================================================
-- COMBAT_LOG_EVENT_UNFILTERED HANDLER (EXACT GLADIUS LOGIC)
-- ============================================================================
function DRTracker:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType = CombatLogGetCurrentEventInfo()
    
    -- Get the unit (arena1, arena2, arena3) - EXACT Gladius logic
    local unit
    for i = 1, 3 do
        local arenaUnit = "arena" .. i
        if UnitGUID(arenaUnit) == destGUID then
            unit = arenaUnit
            break
        end
    end
    if not unit then return end
    
    -- Get aura duration - EXACT Gladius logic
    local _, _, _, _, auraDuration, _ = WA_GetUnitDebuff(unit, spellID)
    
    -- Process events - EXACT Gladius logic
    if eventType == "SPELL_AURA_APPLIED" then
        if auraType == "DEBUFF" and DRList:GetCategoryBySpellID(spellID) then
            self:DRApplied(unit, spellID, false, auraDuration)
        end
    elseif eventType == "SPELL_AURA_REFRESH" then
        if auraType == "DEBUFF" and DRList:GetCategoryBySpellID(spellID) then
            self:DRApplied(unit, spellID)
        end
    elseif eventType == "SPELL_AURA_REMOVED" then
        if auraType == "DEBUFF" and DRList:GetCategoryBySpellID(spellID) then
            self:DRApplied(unit, spellID)
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
function DRTracker:Initialize()
    -- Register combat log event
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self.eventFrame:SetScript("OnEvent", function(_, event)
            if event == "COMBAT_LOG_EVENT_UNFILTERED" then
                self:COMBAT_LOG_EVENT_UNFILTERED()
            end
        end)
    end
end

function DRTracker:Reset(unit)
    if self.frames[unit] then
        for cat, tracked in pairs(self.frames[unit]) do
            tracked.active = false
            tracked.diminished = 1.0
            tracked.reset = 0
        end
    end
end

-- ============================================================================
-- REGISTER MODULE
-- ============================================================================
AC.DRTracker_Fixed = DRTracker

-- Auto-initialize after a short delay to ensure DR module is loaded
C_Timer.After(1, function()
    DRTracker:Initialize()
    print("|cff00FF00[ArenaCore DR]|r 100% Gladius-compatible DR system loaded!")
end)

return DRTracker
