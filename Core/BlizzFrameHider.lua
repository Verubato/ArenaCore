-- =============================================================
-- File: Core/BlizzFrameHider.lua
-- ArenaCore Blizzard Frame Hider
-- Hides default Blizzard arena frames introduced in Dragonflight
-- Based on ArenaAntiMalware addon functionality
-- =============================================================

local AC = _G.ArenaCore
if not AC then return end

AC.BlizzFrameHider = AC.BlizzFrameHider or {}
local BlizzFrameHider = AC.BlizzFrameHider

-- Hidden frame to parent Blizzard frames to
local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

-- Event list for monitoring arena state
local events = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA", 
    "ARENA_PREP_OPPONENT_SPECIALIZATIONS",
    "PVP_MATCH_STATE_CHANGED"
}

-- State tracking
BlizzFrameHider.isEnabled = true
BlizzFrameHider.isInitialized = false

-- Main function to hide Blizzard arena frames
local function HideBlizzardFrames()
    if InCombatLockdown() then return end
    if not BlizzFrameHider.isEnabled then return end
    
    local instanceType = select(2, IsInInstance())
    if instanceType == "arena" then
        -- Hide CompactArenaFrame and related frames
        if CompactArenaFrame then
            CompactArenaFrame:SetParent(hiddenFrame)
        end
        if CompactArenaFrameTitle then
            CompactArenaFrameTitle:SetParent(hiddenFrame)
        end
    end
end

-- Event handler
local function OnEvent(self, event, ...)
    HideBlizzardFrames()
    -- Also try one frame later to catch any delayed frame creation
    C_Timer.After(0, HideBlizzardFrames)
end

-- Initialize the frame hider
function BlizzFrameHider:Initialize()
    if self.isInitialized then return end
    
    -- Create event frame
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", OnEvent)
    
    -- Register events
    for _, event in ipairs(events) do
        self.eventFrame:RegisterEvent(event)
    end
    
    -- Hook frame show events to catch them immediately
    if CompactArenaFrame then
        CompactArenaFrame:HookScript("OnLoad", HideBlizzardFrames)
        CompactArenaFrame:HookScript("OnShow", HideBlizzardFrames)
    end
    if CompactArenaFrameTitle then
        CompactArenaFrameTitle:HookScript("OnLoad", HideBlizzardFrames)
        CompactArenaFrameTitle:HookScript("OnShow", HideBlizzardFrames)
    end
    
    -- Initial hide attempt
    HideBlizzardFrames()
    
    self.isInitialized = true
    
    -- Load saved setting
    self:LoadSettings()
end

-- Enable frame hiding
function BlizzFrameHider:EnableHiding()
    self.isEnabled = true
    HideBlizzardFrames()
end

-- Disable frame hiding (restore frames)
function BlizzFrameHider:DisableHiding()
    self.isEnabled = false
    self:RestoreFrames()
    print("|cff8B45FFArena Core:|r Blizzard arena frames restored")
end

-- Restore Blizzard frames to their original parent
function BlizzFrameHider:RestoreFrames()
    if InCombatLockdown() then return end
    
    if CompactArenaFrame then
        CompactArenaFrame:SetParent(UIParent)
    end
    if CompactArenaFrameTitle then
        CompactArenaFrameTitle:SetParent(UIParent)
    end
end

-- Load settings from database
function BlizzFrameHider:LoadSettings()
    AC.DB = AC.DB or {}
    AC.DB.profile = AC.DB.profile or {}
    AC.DB.profile.moreFeatures = AC.DB.profile.moreFeatures or {}
    
    -- Default to enabled if not set
    if AC.DB.profile.moreFeatures.hideBlizzardArenaFrames == nil then
        AC.DB.profile.moreFeatures.hideBlizzardArenaFrames = true
    end
    
    -- Apply the setting
    if AC.DB.profile.moreFeatures.hideBlizzardArenaFrames then
        self:EnableHiding()
    else
        self:DisableHiding()
    end
end

-- Check if hiding is enabled
function BlizzFrameHider:IsEnabled()
    return self.isEnabled
end

-- Initialize on addon load
C_Timer.After(0.1, function()
    BlizzFrameHider:Initialize()
end)
