-- ============================================================================
-- DRTracker.lua - Complete DR Tracking System
-- ============================================================================
-- Unified single-module DR tracking system for ArenaCore
-- Handles combat log events, DR calculations, and icon updates
-- ============================================================================

local AC = _G.ArenaCore
if not AC then return end

-- ArenaCore DR Library for DR category detection and calculations
local DRList = AC.DRLibrary
if not DRList then
    print("|cffFF0000[ArenaCore DR]|r DR Library not found!")
    return
end

local DRTracker = {}
DRTracker.frames = {} -- Store DR frames per unit (arena1, arena2, arena3)

-- ============================================================================
-- AURA HELPER FUNCTIONS (WeakAuras Pattern)
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
-- CORE DR TRACKING LOGIC
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
    -- Check if source is player or party member
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
-- DR APPLICATION LOGIC
-- ============================================================================
function DRTracker:DRApplied(unit, spellID, auraDuration)
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
    tracked.spellID = spellID
    tracked.category = drCat
    
    -- CRITICAL FIX: Calculate correct stage number for display
    local stage
    if tracked.diminished >= 1.0 then
        stage = 1  -- Full duration (should show 1/3)
    elseif tracked.diminished >= 0.5 then
        stage = 2  -- Half duration (should show 2/3)  
    elseif tracked.diminished >= 0.25 then
        stage = 3  -- Quarter duration (should show 3/3)
    else
        stage = 3  -- Immune (show as 3/3)
    end
    
    -- Now update the visual icon via DR module with corrected stage
    self:UpdateDRIcon(unit, drCat, spellID, tracked, stage)
end

-- ============================================================================
-- UPDATE DR ICON (Calls into DR.lua visual system)
-- ============================================================================
function DRTracker:UpdateDRIcon(unit, category, spellID, tracked, stage)
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
        drModule:TrackApplication(unitGUID, spellID, category, stage)
    end
end

-- ============================================================================
-- COMBAT_LOG_EVENT_UNFILTERED HANDLER
-- ============================================================================
function DRTracker:COMBAT_LOG_EVENT_UNFILTERED()
    local timestamp, eventType, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool, auraType = CombatLogGetCurrentEventInfo()
    
    -- Only process SPELL_AURA_APPLIED, SPELL_AURA_REFRESH, and SPELL_AURA_REMOVED
    if eventType ~= "SPELL_AURA_APPLIED" and eventType ~= "SPELL_AURA_REFRESH" and eventType ~= "SPELL_AURA_REMOVED" then
        return
    end
    
    -- Only process DEBUFFs
    if auraType ~= "DEBUFF" then
        return
    end
    
    -- Check if this is a DR-able spell
    local drCat = DRList:GetCategoryBySpellID(spellID)
    if not drCat then
        return
    end
    
    -- Check if source is friendly (we applied it)
    if not self:IsSourceFriendly(sourceGUID, sourceFlags) then
        return
    end
    
    -- Get the unit (arena1, arena2, arena3)
    local unit = self:GetUnitFromGUID(destGUID)
    if not unit then
        return
    end
    
    -- Get aura duration
    local _, _, _, _, auraDuration, _ = WA_GetUnitDebuff(unit, spellID)
    
    -- Apply the DR
    self:DRApplied(unit, spellID, auraDuration)
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
AC.DRTracker = DRTracker

-- Auto-initialize after a short delay to ensure DR module is loaded
C_Timer.After(1, function()
    DRTracker:Initialize()
end)

return DRTracker
