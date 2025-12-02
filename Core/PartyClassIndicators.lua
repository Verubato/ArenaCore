-- ============================================================================
-- File: ArenaCore/Core/PartyClassIndicators.lua (v2.0 - BBP Pattern)
-- Purpose: Party class indicators matching BetterBlizzPlates proven pattern
-- Rewritten Nov 1, 2025 to match BBP's proven pattern exactly
-- ============================================================================

local AC = _G.ArenaCore
if not AC then return end

-- Class icon paths (ArenaCore Custom theme)
local CLASS_ICON_PATHS = {
    DEATHKNIGHT = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Deathknight",
    DEMONHUNTER = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Demonhunter",
    DRUID = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Druid",
    EVOKER = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Evoker",
    HUNTER = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Hunter",
    MAGE = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Mage",
    MONK = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Monk",
    PALADIN = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Paladin",
    PRIEST = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Priest",
    ROGUE = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Rogue",
    SHAMAN = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Shaman",
    WARLOCK = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Warlock",
    WARRIOR = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\Warrior",
}

-- ColdClasses theme paths (WoW Default Style+Midnight Chill)
-- CRITICAL: Must include .png extension for PNG files
local COLDCLASSES_ICON_PATHS = {
    DEATHKNIGHT = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\deathknight.png",
    DEMONHUNTER = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\demonhunter.png",
    DRUID = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\druid.png",
    EVOKER = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\evoker.png",
    HUNTER = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\hunter.png",
    MAGE = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\mage.png",
    MONK = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\monk.png",
    PALADIN = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\paladin.png",
    PRIEST = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\priest.png",
    ROGUE = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\rogue.png",
    SHAMAN = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\shaman.png",
    WARLOCK = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\warlock.png",
    WARRIOR = "Interface\\AddOns\\ArenaCore\\Media\\Classicons\\ColdClasses\\warrior.png",
}

-- Get class icon path based on useCustomIcons setting
local function GetClassIconPath(classToken)
    if not classToken then return nil end
    
    -- Get settings from database
    local db = AC.DB and AC.DB.profile
    local useCustomIcons = db and db.moreGoodies and db.moreGoodies.partyClassSpecs and db.moreGoodies.partyClassSpecs.useCustomIcons
    
    -- When checkbox is ON: Use ArenaCore custom icons
    -- When checkbox is OFF: Use Midnight Chill (coldclasses) icons
    if useCustomIcons then
        -- Use ArenaCore Custom icons
        return CLASS_ICON_PATHS[classToken]
    else
        -- Use Midnight Chill (coldclasses) icons
        return COLDCLASSES_ICON_PATHS[classToken]
    end
end

-- ============================================================================
-- BBP PATTERN: Single function called from NAME_PLATE_UNIT_ADDED
-- ============================================================================

function AC.UpdatePartyClassIndicator(frame)
    if not frame or not frame.unit then return end
    if frame:IsForbidden() or frame:IsProtected() then return end
    
    -- Get ArenaCore config
    local db = AC.DB and AC.DB.profile and AC.DB.profile.moreGoodies and AC.DB.profile.moreGoodies.partyClassSpecs
    if not db or not db.mode or db.mode == "off" then
        -- Feature disabled - restore any hidden elements
        if frame.__acClassIndicatorActive then
            if frame.HealthBarsContainer then
                frame.HealthBarsContainer:SetAlpha(1)
            end
            if frame.name then
                frame.name:SetAlpha(1)
            end
            frame.__acClassIndicatorActive = nil
        end
        if frame.ArenaCore_ClassIndicator then
            frame.ArenaCore_ClassIndicator:Hide()
        end
        if frame.ArenaCore_Pointer then
            frame.ArenaCore_Pointer:Hide()
        end
        -- Restore raid target markers when feature is off
        if frame.RaidTargetFrame and frame.RaidTargetFrame.RaidTargetIcon then
            frame.RaidTargetFrame.RaidTargetIcon:SetAlpha(1)
        end
        return
    end
    
    -- Only handle nameplates
    if not frame.unit:find("nameplate") then return end
    
    -- Get unit info
    local unitForData = frame.displayedUnit or frame.unit
    if not unitForData or not UnitExists(unitForData) then return end
    
    -- CRITICAL: Only work on FRIENDLY PLAYERS, not NPCs (BBP pattern)
    if not UnitIsPlayer(unitForData) or not UnitIsFriend("player", unitForData) then
        -- NPC or enemy - don't touch anything
        if frame.__acClassIndicatorActive then
            frame.HealthBarsContainer:SetAlpha(1)
            frame.__acClassIndicatorActive = nil
        end
        if frame.ArenaCore_ClassIndicator then
            frame.ArenaCore_ClassIndicator:Hide()
        end
        if frame.ArenaCore_Pointer then
            frame.ArenaCore_Pointer:Hide()
        end
        -- Restore raid target markers for NPCs/enemies
        if frame.RaidTargetFrame and frame.RaidTargetFrame.RaidTargetIcon then
            frame.RaidTargetFrame.RaidTargetIcon:SetAlpha(1)
        end
        return
    end
    
    -- Check mode setting (party vs all)
    local showOnThisUnit = false
    if db.mode == "all" then
        showOnThisUnit = true
    elseif db.mode == "party" then
        showOnThisUnit = UnitInParty(unitForData)
    end
    
    -- If mode doesn't match, hide and return
    if not showOnThisUnit then
        -- Mode doesn't match - hide everything
        if frame.__acClassIndicatorActive then
            frame.HealthBarsContainer:SetAlpha(1)
            frame.__acClassIndicatorActive = nil
        end
        if frame.ArenaCore_ClassIndicator then
            frame.ArenaCore_ClassIndicator:Hide()
        end
        if frame.ArenaCore_Pointer then
            frame.ArenaCore_Pointer:Hide()
        end
        -- Restore raid target markers for enemies/neutrals
        if frame.RaidTargetFrame and frame.RaidTargetFrame.RaidTargetIcon then
            frame.RaidTargetFrame.RaidTargetIcon:SetAlpha(1)
        end
        return
    end
    
    -- Don't show on self
    if UnitIsUnit(unitForData, "player") then
        if frame.ArenaCore_ClassIndicator then
            frame.ArenaCore_ClassIndicator:Hide()
        end
        if frame.ArenaCore_Pointer then
            frame.ArenaCore_Pointer:Hide()
        end
        -- Restore raid target markers for self
        if frame.RaidTargetFrame and frame.RaidTargetFrame.RaidTargetIcon then
            frame.RaidTargetFrame.RaidTargetIcon:SetAlpha(1)
        end
        return
    end
    
    -- Get class info
    local _, class = UnitClass(unitForData)
    if not class then return end
    
    -- ========================================================================
    -- CLASS INDICATOR (Icon above nameplate)
    -- ========================================================================
    
    -- Always show class icons when feature is enabled (mode != "off")
    if true then
        -- Create class indicator frame if needed
        if not frame.ArenaCore_ClassIndicator then
            frame.ArenaCore_ClassIndicator = CreateFrame("Frame", nil, frame)
            frame.ArenaCore_ClassIndicator:SetSize(32, 32)
            frame.ArenaCore_ClassIndicator:SetIgnoreParentAlpha(true)
            
            -- Create the class icon texture
            frame.ArenaCore_ClassIndicator.icon = frame.ArenaCore_ClassIndicator:CreateTexture(nil, "ARTWORK")
            frame.ArenaCore_ClassIndicator.icon:SetPoint("CENTER", frame.ArenaCore_ClassIndicator)
            frame.ArenaCore_ClassIndicator.icon:SetSize(28, 28)
            
            -- Create circular mask
            frame.ArenaCore_ClassIndicator.mask = frame.ArenaCore_ClassIndicator:CreateMaskTexture()
            frame.ArenaCore_ClassIndicator.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            frame.ArenaCore_ClassIndicator.mask:SetSize(28, 28)
            frame.ArenaCore_ClassIndicator.mask:SetPoint("CENTER", frame.ArenaCore_ClassIndicator.icon)
            frame.ArenaCore_ClassIndicator.icon:AddMaskTexture(frame.ArenaCore_ClassIndicator.mask)
            
            -- Create border using BlackOutline.tga
            frame.ArenaCore_ClassIndicator.border = frame.ArenaCore_ClassIndicator:CreateTexture(nil, "OVERLAY")
            frame.ArenaCore_ClassIndicator.border:SetAllPoints(frame.ArenaCore_ClassIndicator)
            frame.ArenaCore_ClassIndicator.border:SetTexture("Interface\\AddOns\\ArenaCore\\Media\\Classicons\\BlackOutline.tga")
        end
        
        -- Apply scale from settings
        local finalScale
        do
            local pm = AC.ProfileManager
            local scalePixels = pm and pm.GetSetting and pm:GetSetting("moreGoodies.partyClassSpecs.scale")
            if type(scalePixels) == "number" then
                local currentScale = AC.ConvertPixelsToScale and AC:ConvertPixelsToScale(scalePixels, 50, 360, 1, 12) or 6.5
                finalScale = 0.5 + (currentScale - 1) * (2.5 / 11)
            else
                local rawScale = (db.scale) or 100
                if rawScale <= 12 then
                    finalScale = 0.5 + (rawScale - 1) * (2.5 / 11)
                else
                    finalScale = rawScale / 100
                end
            end
            finalScale = math.max(0.5, math.min(finalScale or 1.0, 3.0))
            frame.ArenaCore_ClassIndicator:SetScale(finalScale)
        end
        
        -- Apply horizontal/vertical offsets
        local offX, offY = 0, 0
        do
            local pm = AC.ProfileManager
            local px = pm and pm.GetSetting and pm:GetSetting("moreGoodies.partyClassSpecs.offsetX")
            local py = pm and pm.GetSetting and pm:GetSetting("moreGoodies.partyClassSpecs.offsetY")
            if type(px) ~= "number" then
                px = db.offsetX or 0
            end
            if type(py) ~= "number" then
                py = db.offsetY or 0
            end
            offX, offY = tonumber(px) or 0, tonumber(py) or 0
        end
        
        local baseY = 8
        frame.ArenaCore_ClassIndicator:ClearAllPoints()
        if frame.name then
            frame.ArenaCore_ClassIndicator:SetPoint("BOTTOM", frame.name, "TOP", offX, baseY + offY)
        else
            frame.ArenaCore_ClassIndicator:SetPoint("BOTTOM", frame, "TOP", offX, baseY + offY)
        end
        
        -- Set class icon texture (use custom ArenaCore icons)
        -- CRITICAL FIX: Check if this is a healer and showHealerIcon is enabled
        local useHealerIcon = false
        if db.showHealerIcon then
            -- Check if this unit is a healer using role assignment
            local role = UnitGroupRolesAssigned(unitForData)
            if role == "HEALER" then
                useHealerIcon = true
            end
        end
        
        if useHealerIcon then
            -- Use custom ArenaCore healer icon
            frame.ArenaCore_ClassIndicator.icon:SetTexture("Interface\\AddOns\\ArenaCore\\Media\\Classicons\\HealerPointer.tga")
            frame.ArenaCore_ClassIndicator.icon:SetTexCoord(0, 1, 0, 1) -- Full texture for healer icon
        else
            -- Use normal class icon (respects theme setting)
            local iconPath = GetClassIconPath(class)
            if iconPath then
                frame.ArenaCore_ClassIndicator.icon:SetTexture(iconPath)
                frame.ArenaCore_ClassIndicator.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
            end
        end
        
        -- Hide raid target markers (skull, cross, moon, etc.) when showing class icons
        if frame.RaidTargetFrame and frame.RaidTargetFrame.RaidTargetIcon then
            frame.RaidTargetFrame.RaidTargetIcon:SetAlpha(0)
        end
        
        frame.ArenaCore_ClassIndicator:Show()
    else
        if frame.ArenaCore_ClassIndicator then
            frame.ArenaCore_ClassIndicator:Hide()
        end
    end
    
    -- ========================================================================
    -- PARTY POINTER (Arrow above nameplate)
    -- ========================================================================
    
    -- Update pointer (triangle arrow) with separate positioning
    if db.showPointers then
        -- Create pointer frame if needed
        if not frame.ArenaCore_Pointer then
            frame.ArenaCore_Pointer = CreateFrame("Frame", nil, frame)
            frame.ArenaCore_Pointer:SetSize(34, 48)
            frame.ArenaCore_Pointer:SetIgnoreParentAlpha(true)
            
            frame.ArenaCore_Pointer.icon = frame.ArenaCore_Pointer:CreateTexture(nil, "ARTWORK")
            frame.ArenaCore_Pointer.icon:SetAtlas("UI-QuestPoiImportant-QuestNumber-SuperTracked")
            frame.ArenaCore_Pointer.icon:SetSize(34, 48)
            frame.ArenaCore_Pointer.icon:SetPoint("BOTTOM", frame.ArenaCore_Pointer, "BOTTOM", 0, 5)
            frame.ArenaCore_Pointer.icon:SetDesaturated(true)
            frame.ArenaCore_Pointer.icon:SetTexelSnappingBias(0.0)
            frame.ArenaCore_Pointer.icon:SetSnapToPixelGrid(false)
        end
        
        -- Apply pointer scale
        local pointerScale
        do
            local pm = AC.ProfileManager
            local scalePixels = pm and pm.GetSetting and pm:GetSetting("moreGoodies.partyClassSpecs.pointerScale")
            if type(scalePixels) == "number" then
                local currentScale = AC.ConvertPixelsToScale and AC:ConvertPixelsToScale(scalePixels, 50, 360, 1, 12) or 6.5
                pointerScale = 0.5 + (currentScale - 1) * (2.5 / 11)
            else
                local rawScale = db.pointerScale or 100
                if rawScale <= 12 then
                    pointerScale = 0.5 + (rawScale - 1) * (2.5 / 11)
                else
                    pointerScale = rawScale / 100
                end
            end
            pointerScale = math.max(0.5, math.min(pointerScale or 1.0, 3.0))
            frame.ArenaCore_Pointer:SetScale(pointerScale)
        end
        
        -- Apply pointer offsets
        local ptrOffX, ptrOffY = 0, 0
        do
            local pm = AC.ProfileManager
            local px = pm and pm.GetSetting and pm:GetSetting("moreGoodies.partyClassSpecs.pointerOffsetX")
            local py = pm and pm.GetSetting and pm:GetSetting("moreGoodies.partyClassSpecs.pointerOffsetY")
            if type(px) ~= "number" then
                px = db.pointerOffsetX or 0
            end
            if type(py) ~= "number" then
                py = db.pointerOffsetY or 0
            end
            ptrOffX, ptrOffY = tonumber(px) or 0, tonumber(py) or 0
        end
        
        -- Position pointer above class icon
        local basePointerY = 40
        frame.ArenaCore_Pointer:ClearAllPoints()
        if frame.name then
            frame.ArenaCore_Pointer:SetPoint("BOTTOM", frame.name, "TOP", ptrOffX, basePointerY + ptrOffY)
        else
            frame.ArenaCore_Pointer:SetPoint("BOTTOM", frame, "TOP", ptrOffX, basePointerY + ptrOffY)
        end
        
        -- Color pointer based on class
        if class and RAID_CLASS_COLORS[class] then
            local classColor = RAID_CLASS_COLORS[class]
            frame.ArenaCore_Pointer.icon:SetVertexColor(classColor.r, classColor.g, classColor.b, 1)
        end
        
        frame.ArenaCore_Pointer:Show()
    else
        if frame.ArenaCore_Pointer then
            frame.ArenaCore_Pointer:Hide()
        end
    end
    
    -- ========================================================================
    -- HIDE HEALTH BARS (BBP Pattern with flags)
    -- ========================================================================
    
    if db.hideHealthBars then
        -- BBP PATTERN: Use flag to track state
        if not frame.__acClassIndicatorActive then
            frame.HealthBarsContainer:SetAlpha(0)
            frame.selectionHighlight:SetAlpha(0)
            frame.__acClassIndicatorActive = true  -- Set flag
        end
    else
        -- Restore if previously hidden
        if frame.__acClassIndicatorActive then
            frame.HealthBarsContainer:SetAlpha(1)
            frame.selectionHighlight:SetAlpha(0.22)
            frame.__acClassIndicatorActive = nil  -- Clear flag
        end
    end
    
    -- ========================================================================
    -- HIDE NAMES (BBP Pattern)
    -- ========================================================================
    
    -- Only hide names when class icons are actually showing (not when feature is off/hidden)
    if frame.ArenaCore_ClassIndicator and frame.ArenaCore_ClassIndicator:IsShown() then
        -- Hide name when class icon is showing (BBP pattern)
        -- BBP uses classIndicatorHideName flag which is checked in ConsolidatedUpdateName
        frame.classIndicatorHideName = true
        if frame.name then
            frame.name:SetText("")
        end
    else
        -- Restore name when class icon is hidden
        frame.classIndicatorHideName = false
    end
end

-- ============================================================================
-- REFRESH FUNCTION: Called when settings change
-- ============================================================================

function AC:RefreshPartyClassIcons()
    -- Refresh all visible nameplates
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        local frame = nameplate.UnitFrame
        if frame and not frame:IsForbidden() and not frame:IsProtected() then
            AC.UpdatePartyClassIndicator(frame)
        end
    end
end

-- ============================================================================
-- HOOK: Prevent Blizzard from showing names when hideNameOverride is set
-- ============================================================================

-- Hook CompactUnitFrame_UpdateName to enforce classIndicatorHideName
local function OnNameUpdate(frame)
    if not frame or not frame.unit or not frame.unit:find("nameplate") then return end
    if frame:IsForbidden() or frame:IsProtected() then return end
    
    -- If we set classIndicatorHideName, enforce it (BBP pattern)
    -- Only use SetText - let BBP handle alpha via its own system
    if frame.classIndicatorHideName and frame.name then
        frame.name:SetText("")
    end
end

-- Register the hook after a short delay to ensure CompactUnitFrame_UpdateName exists
C_Timer.After(0.1, function()
    if CompactUnitFrame_UpdateName then
        hooksecurefunc("CompactUnitFrame_UpdateName", OnNameUpdate)
    end
end)

-- ============================================================================
-- INTEGRATION: This will be called from BlackoutEngine's NAME_PLATE_UNIT_ADDED
-- ============================================================================

-- Module loaded (debug message removed for cleaner startup)
