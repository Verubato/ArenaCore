-- ============================================================================
-- ARENACORE EDIT MODE - Simple Drag-to-Position System
-- ============================================================================
-- CONCEPT: Same frames, same database, same refresh logic as sliders
-- DIFFERENCE: Click-and-drag instead of sliders to adjust positioning
-- SHARED: Everything saves to the same database paths (trinkets.positioning, etc.)
-- ============================================================================

local AC = _G.ArenaCore
if not AC then return end

AC.EditMode = AC.EditMode or {}
local EM = AC.EditMode

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================
EM.isActive = false
EM.registeredFrames = {} -- Tracks all draggable frames by group

-- ============================================================================
-- DRAGGABLE ELEMENT GROUPS
-- ============================================================================
-- Each group defines:
-- - dbPath: Database path for positioning (e.g., "trinkets.positioning")
-- - refreshFunc: Function to call after position changes
-- - selector: Function to find all frames in this group

local ELEMENT_GROUPS = {
    trinkets = {
        dbPath = "trinkets.positioning",
        refreshFunc = "RefreshTrinketsOtherLayout",
        selector = function()
            local frames = {}
            -- Use FrameManager system (new unified architecture)
            local arenaFrames = AC.FrameManager and AC.FrameManager:GetFrames()
            if arenaFrames then
                for i = 1, 3 do
                    local f = arenaFrames[i]
                    if f and f.trinketIndicator then
                        table.insert(frames, f.trinketIndicator)
                    end
                end
            end
            return frames
        end
    },
    
    racials = {
        dbPath = "racials.positioning",
        refreshFunc = "RefreshTrinketsOtherLayout",
        selector = function()
            local frames = {}
            local arenaFrames = AC.FrameManager and AC.FrameManager:GetFrames()
            if arenaFrames then
                for i = 1, 3 do
                    local f = arenaFrames[i]
                    if f and f.racialIndicator then
                        table.insert(frames, f.racialIndicator)
                    end
                end
            end
            return frames
        end
    },
    
    castBars = {
        dbPath = "castBars.positioning",
        refreshFunc = "RefreshCastBarsLayout",
        selector = function()
            local frames = {}
            local arenaFrames = AC.FrameManager and AC.FrameManager:GetFrames()
            if arenaFrames then
                for i = 1, 3 do
                    local f = arenaFrames[i]
                    if f and f.castBar then
                        table.insert(frames, f.castBar)
                    end
                end
            end
            return frames
        end
    },
    
    -- DR Icons removed from Edit Mode - use sliders on Diminishing Returns page for positioning
    
    classIcons = {
        dbPath = "classIcons.positioning",
        refreshFunc = "RefreshTrinketsOtherLayout",
        selector = function()
            local frames = {}
            local arenaFrames = AC.FrameManager and AC.FrameManager:GetFrames()
            if arenaFrames then
                for i = 1, 3 do
                    local f = arenaFrames[i]
                    if f and f.classIcon then
                        table.insert(frames, f.classIcon)
                    end
                end
            end
            return frames
        end
    },
    
    specIcons = {
        dbPath = "specIcons.positioning",
        refreshFunc = "RefreshTrinketsOtherLayout",
        selector = function()
            local frames = {}
            local arenaFrames = AC.FrameManager and AC.FrameManager:GetFrames()
            if arenaFrames then
                for i = 1, 3 do
                    local f = arenaFrames[i]
                    if f and f.specIcon then
                        table.insert(frames, f.specIcon)
                    end
                end
            end
            return frames
        end
    },
    
    debuffs = {
        dbPath = "moreGoodies.debuffs.positioning",
        refreshFunc = "RefreshDebuffsLayout",
        selector = function()
            local frames = {}
            local arenaFrames = AC.FrameManager and AC.FrameManager:GetFrames()
            if arenaFrames then
                for i = 1, 3 do
                    local f = arenaFrames[i]
                    if f and f.debuffContainer then
                        table.insert(frames, f.debuffContainer)
                    end
                end
            end
            return frames
        end
    }
    
    -- NOTE: Class Packs (TriBadges) support is in EditMode_ClassPacks.lua
    -- They require special handling due to their custom frame structure
    
    -- NOTE: DR icons use SLIDER-ONLY positioning (no Edit Mode)
    -- This prevents jumping conflicts between drag and slider systems
}

-- Expose ELEMENT_GROUPS so modules can extend it
EM.ELEMENT_GROUPS = ELEMENT_GROUPS

-- ============================================================================
-- CORE DRAG LOGIC
-- ============================================================================

local function SavePosition(groupConfig, offsetX, offsetY)
    -- Save to database using ProfileManager (same as sliders)
    local PM = AC.ProfileManager
    if not PM then 
        print("|cffFF0000[EDIT MODE]|r ProfileManager not found!")
        return 
    end
    
    -- REVERTED: Class icons back to frame-relative anchoring
    -- Need to subtract base offset before saving to prevent snap/jump
    if groupConfig.dbPath == "classIcons.positioning" then
        offsetX = offsetX - 8  -- Subtract base LEFT offset
        offsetY = offsetY - 0  -- No base vertical offset
    end
    
    -- DRAG + SLIDER SYSTEM: Save Edit Mode position as base, keep slider offsets unchanged
    -- This mimics Ctrl+Alt+Click frame dragging behavior
    -- Final Position = Edit Mode Base + Slider Offset
    
    -- Special field mapping for Class Packs (TriBadges)
    if groupConfig.dbPath == "classPacks" then
        -- CLEAN SLATE FIX: Simple direct save to offsetX/offsetY
        -- No complex base + offset calculation
        PM:SetSetting("classPacks.offsetX", offsetX)
        PM:SetSetting("classPacks.offsetY", offsetY)
    else
        -- Default path uses horizontal/vertical
        -- CRITICAL FIX: Save dragged position directly as base
        -- Don't try to subtract slider offset - just use the actual dragged position
        -- The dragged position IS the new base position
        PM:SetSetting(groupConfig.dbPath .. ".draggedBaseX", offsetX)
        PM:SetSetting(groupConfig.dbPath .. ".draggedBaseY", offsetY)
        
        -- CRITICAL FIX: Reset slider offsets to 0 after Edit Mode drag
        -- This ensures sliders start from the new dragged position, not the old offset
        PM:SetSetting(groupConfig.dbPath .. ".sliderOffsetX", 0)
        PM:SetSetting(groupConfig.dbPath .. ".sliderOffsetY", 0)
        
        -- CRITICAL FIX: Update main position to match dragged position
        -- This ensures horizontal/vertical = draggedBase + 0 offset
        -- Prevents jumps when exiting Edit Mode and using sliders
        PM:SetSetting(groupConfig.dbPath .. ".horizontal", offsetX)
        PM:SetSetting(groupConfig.dbPath .. ".vertical", offsetY)
        
        -- CRITICAL FIX: Force database write to ensure values persist
        -- Without this, values may not be written to SavedVariables immediately
        local pathParts = {}
        for part in string.gmatch(groupConfig.dbPath, "[^%.]+") do
            table.insert(pathParts, part)
        end
        
        if #pathParts >= 1 and AC.DB and AC.DB.profile then
            local current = AC.DB.profile
            for i = 1, #pathParts do
                if not current[pathParts[i]] then
                    current[pathParts[i]] = {}
                end
                if i < #pathParts then
                    current = current[pathParts[i]]
                end
            end
            
            -- Now current points to the parent table (e.g., trinkets, specIcons)
            local finalTable = AC.DB.profile
            for i = 1, #pathParts do
                finalTable = finalTable[pathParts[i]]
            end
            
            -- Ensure positioning table exists
            if not finalTable.positioning then
                finalTable.positioning = {}
            end
            
            -- Write all positioning values directly to database
            finalTable.positioning.draggedBaseX = offsetX
            finalTable.positioning.draggedBaseY = offsetY
            finalTable.positioning.sliderOffsetX = 0
            finalTable.positioning.sliderOffsetY = 0
            finalTable.positioning.horizontal = offsetX
            finalTable.positioning.vertical = offsetY
        end
        
        -- DEBUG DISABLED FOR PRODUCTION
        -- print("|cffFFAA00[EDIT MODE]|r " .. groupConfig.dbPath .. ": Base=(" .. baseX .. ", " .. baseY .. "), Slider offsets reset to 0, Final=(" .. offsetX .. ", " .. offsetY .. ")")
    end
    
    -- PROFILE EDIT MODE: Skip refresh during edit mode (changes are buffered, not applied)
    -- Frames will stay in their dragged positions visually, but won't be saved to database
    -- When user discards changes, we'll force a refresh to rollback visual changes
    if not AC.profileEditModeActive then
        -- Delay refresh slightly to ensure database is updated
        C_Timer.After(0.05, function()
            if groupConfig.refreshFunc and AC[groupConfig.refreshFunc] then
                AC[groupConfig.refreshFunc](AC)
                
                -- REBIND: Recreate/reuse glow + drag on fresh frames
                C_Timer.After(0.1, function()
                    if EM.isActive then
                        local frames = groupConfig.selector()
                        -- DEBUG: print("|cff00FFFF[EditMode]|r Rebind: Found " .. #frames .. " frames for " .. (groupConfig.dbPath or "unknown"))
                        for i, frame in ipairs(frames) do
                            EM:MakeDraggable(frame, groupConfig)  -- Idempotent: reuses if present, creates if missing
                            
                            -- CRITICAL FIX: Force show glow after MakeDraggable completes
                            -- This ensures blue overlay persists after save button is clicked
                            C_Timer.After(0.05, function()
                                if frame.editModeGlow then 
                                    frame.editModeGlow:Show() 
                                end
                                if frame.editModeGlowFrame then 
                                    frame.editModeGlowFrame:Show()
                                end
                                -- Also show borders
                                if frame.editModeGlowBorders then
                                    for _, border in ipairs(frame.editModeGlowBorders) do
                                        border:Show()
                                    end
                                end
                            end)
                        end
                    end
                end)
            end
        end)
    else
        -- In edit mode: frames stay in their dragged positions, no refresh needed
        -- Changes are buffered and will be applied on commit or discarded on exit
    end
end

function EM:MakeDraggable(frame, groupConfig)
    if not frame then return end
    
    local callID = math.random(1000, 9999)
    -- DEBUG: print("|cffCCFF00[EditMode " .. callID .. "]|r MakeDraggable START for " .. (groupConfig.dbPath or "unknown") .. ", frame=" .. tostring(frame))
    
    -- Accept any table or userdata - try to use it and let WoW handle errors
    local frameType = type(frame)
    if frameType ~= "table" and frameType ~= "userdata" then
        print("|cffFF0000[EDIT MODE ERROR]|r Invalid frame type (" .. frameType .. ") for " .. (groupConfig.dbPath or "unknown"))
        return
    end
    
    -- Add blue glow to indicate draggable (or update if it already exists)
    local glowFrame = frame.editModeGlowFrame
    
    -- Standard glow creation for all elements
    
    if not glowFrame then
        -- Create a separate frame for the glow overlay
        glowFrame = CreateFrame("Frame", nil, frame)
        
        -- CRITICAL FIX: For trinkets/racials/classIcons, fit glow to icon size with padding
        -- For class icons, anchor to the overlay (border) instead of the icon
        -- For trinkets/racials, anchor to the icon
        local targetRegion = frame.overlay or frame.icon or frame
        
        -- Base padding outside the icon/overlay
        local padding = 3
        
        -- Glow extends OUTSIDE the target region with padding
        glowFrame:SetPoint("TOPLEFT", targetRegion, "TOPLEFT", -padding, padding)
        glowFrame:SetPoint("BOTTOMRIGHT", targetRegion, "BOTTOMRIGHT", padding, -padding)
        
        -- Set standard frame level for all elements
        glowFrame:SetFrameStrata("HIGH")
        glowFrame:SetFrameLevel(50)
        
        local glow = glowFrame:CreateTexture(nil, "OVERLAY")
        glow:SetAllPoints(glowFrame)
        glow:SetColorTexture(0.3, 0.5, 1.0, 0.3) -- Blue glow
        glow:SetBlendMode("ADD")
        
        -- Add border textures for clear visual indication
        local borderThickness = 2
        
        -- Top border
        local topBorder = glowFrame:CreateTexture(nil, "OVERLAY")
        topBorder:SetColorTexture(0.3, 0.6, 1.0, 1.0) -- Bright blue, fully opaque
        topBorder:SetPoint("TOPLEFT", glowFrame, "TOPLEFT", 0, 0)
        topBorder:SetPoint("TOPRIGHT", glowFrame, "TOPRIGHT", 0, 0)
        topBorder:SetHeight(borderThickness)
        
        -- Bottom border
        local bottomBorder = glowFrame:CreateTexture(nil, "OVERLAY")
        bottomBorder:SetColorTexture(0.3, 0.6, 1.0, 1.0)
        bottomBorder:SetPoint("BOTTOMLEFT", glowFrame, "BOTTOMLEFT", 0, 0)
        bottomBorder:SetPoint("BOTTOMRIGHT", glowFrame, "BOTTOMRIGHT", 0, 0)
        bottomBorder:SetHeight(borderThickness)
        
        -- Left border
        local leftBorder = glowFrame:CreateTexture(nil, "OVERLAY")
        leftBorder:SetColorTexture(0.3, 0.6, 1.0, 1.0)
        leftBorder:SetPoint("TOPLEFT", glowFrame, "TOPLEFT", 0, 0)
        leftBorder:SetPoint("BOTTOMLEFT", glowFrame, "BOTTOMLEFT", 0, 0)
        leftBorder:SetWidth(borderThickness)
        
        -- Right border
        local rightBorder = glowFrame:CreateTexture(nil, "OVERLAY")
        rightBorder:SetColorTexture(0.3, 0.6, 1.0, 1.0)
        rightBorder:SetPoint("TOPRIGHT", glowFrame, "TOPRIGHT", 0, 0)
        rightBorder:SetPoint("BOTTOMRIGHT", glowFrame, "BOTTOMRIGHT", 0, 0)
        rightBorder:SetWidth(borderThickness)
        
        -- Store reference on frame
        frame.editModeGlow = glow
        frame.editModeGlowFrame = glowFrame
        frame.editModeGlowBorders = {topBorder, bottomBorder, leftBorder, rightBorder}
        
        -- Mark as draggable
        rawset(glowFrame, "editModeDraggable", true)
    else
        -- Glow frame already exists - show the borders that were hidden on Disable
        if frame.editModeGlowBorders then
            for _, border in ipairs(frame.editModeGlowBorders) do
                border:Show()
            end
        end
        
        -- CRITICAL FIX: Clear the editModeDraggable flag so it can be re-setup
        -- Use rawset to bypass any metatable magic
        rawset(glowFrame, "editModeDraggable", nil)
    end
    
    -- Always show the glow
    if frame.editModeGlow then frame.editModeGlow:Show() end
    if frame.editModeGlowFrame then frame.editModeGlowFrame:Show() end
    
    -- Make the frame itself draggable
    local draggableFrame = frame
    local mouseFrame = frame
    
    -- Use standard mouse target for all elements
    mouseFrame = frame
    
    -- If already draggable, just ensure everything is enabled and return
    -- Use rawget to bypass WoW frame metatable magic
    local isDraggable = rawget(draggableFrame, "editModeDraggable")
    -- DEBUG: print("|cffCCCCCC[EditMode " .. callID .. "]|r Check draggable: " .. (groupConfig.dbPath or "unknown") .. ", rawget=" .. tostring(isDraggable))
    if isDraggable then
        -- Re-enable everything (in case it was disabled when exiting Edit Mode)
        draggableFrame:SetMovable(true)
        if mouseFrame ~= draggableFrame then
            mouseFrame:SetMovable(true)
        end
        mouseFrame:EnableMouse(true)
        mouseFrame:RegisterForDrag("LeftButton")
        if frame.editModeGlow then frame.editModeGlow:Show() end
        if frame.editModeGlowFrame then frame.editModeGlowFrame:Show() end
        -- DEBUG: print("|cffFFAA00[EditMode " .. callID .. "]|r MakeDraggable END (already draggable, re-enabled)")
        return
    end
    
    -- DEBUG: print("|cff00FF00[EditMode " .. callID .. "]|r Proceeding with setup...")
    
    -- DEBUG: print("|cff22AA44[EditMode]|r Setting up draggable for " .. (groupConfig.dbPath or "unknown"))
    
    rawset(draggableFrame, "editModeDraggable", true)
    draggableFrame:SetMovable(true)
    
    -- Enable mouse and drag on the mouseFrame
    if mouseFrame ~= draggableFrame then
        mouseFrame:SetMovable(true)
    end
    mouseFrame:EnableMouse(true)
    mouseFrame:RegisterForDrag("LeftButton")
    -- DEBUG: print("|cff00FF00[EditMode]|r Movable=" .. tostring(draggableFrame:IsMovable()) .. ", MouseEnabled=" .. tostring(mouseFrame:IsMouseEnabled()))
    
    -- Store original scripts to restore later
    draggableFrame.originalOnDragStart = draggableFrame:GetScript("OnDragStart")
    draggableFrame.originalOnDragStop = draggableFrame:GetScript("OnDragStop")
    draggableFrame.originalOnUpdate = draggableFrame:GetScript("OnUpdate")
    
    -- Mark that THIS frame was touched by edit mode
    draggableFrame._emStoredScripts = true
    
    -- Store initial mouse position for offset calculation
    local dragStartX, dragStartY
    local initialOffsets = {}
    local isDragging = false
    local lastUpdateTime = 0  -- Throttle updates for performance
    
    mouseFrame:SetScript("OnDragStart", function(self)
        isDragging = true
        
        -- Store initial positions for delta calculation FIRST
        local targetFrame = self.dragTarget or frame
        local scale = targetFrame:GetEffectiveScale()
        local mouseX, mouseY = GetCursorPosition()
        dragStartX = mouseX / scale
        dragStartY = mouseY / scale
        
        -- Prevent one-frame snap on first drag if a layout refresh just happened
        -- Only do this if self is NOT the same as targetFrame (to avoid "anchor to itself" error)
        -- Match the target frame's current anchor to avoid jump
        if self ~= targetFrame then
            local p, rel, rp, x, y = targetFrame:GetPoint()
            self:ClearAllPoints()
            self:SetPoint(p or "TOPLEFT", rel or targetFrame, rp or "TOPLEFT", x or 0, y or 0)
        end
        
        -- Store initial offset of the TARGET frame (the one we're actually positioning)
        local point, relativeTo, relativePoint, xOfs, yOfs = targetFrame:GetPoint()
        initialOffsets.draggedFrame = {
            frame = targetFrame,
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = xOfs or 0,
            y = yOfs or 0
        }
        
        -- Store initial offsets for all sibling frames in group
        local allFrames = groupConfig.selector()
        for i, siblingFrame in ipairs(allFrames) do
            local sPoint, sRelativeTo, sRelativePoint, sXOfs, sYOfs = siblingFrame:GetPoint()
            
            initialOffsets[i] = {
                frame = siblingFrame,
                point = sPoint,
                relativeTo = sRelativeTo,
                relativePoint = sRelativePoint,
                x = sXOfs or 0,
                y = sYOfs or 0
            }
        end
        
        -- Start moving all frames normally
        if self ~= targetFrame and self:IsMovable() then
            self:StartMoving()
        end
    end)
    
    -- Use OnUpdate to track mouse movement during drag
    mouseFrame:SetScript("OnUpdate", function(self, elapsed)
        local targetFrame = self.dragTarget or frame
        if not isDragging then return end
        
        -- Throttle updates to 60 FPS max (0.016s between updates)
        lastUpdateTime = lastUpdateTime + elapsed
        if lastUpdateTime < 0.016 then
            return
        end
        lastUpdateTime = 0
        
        -- Calculate mouse delta
        local scale = self:GetEffectiveScale()
        local currentX, currentY = GetCursorPosition()
        currentX = currentX / scale
        currentY = currentY / scale
        
        local deltaX = currentX - dragStartX
        local deltaY = currentY - dragStartY
        
        -- Move all frames by the same delta
        for i, data in ipairs(initialOffsets) do
            local newX = data.x + deltaX
            local newY = data.y + deltaY
            
            data.frame:ClearAllPoints()
            data.frame:SetPoint(
                data.point,
                data.relativeTo,
                data.relativePoint,
                newX,
                newY
            )
        end
        
        -- Also update the dragged frame itself
        if initialOffsets.draggedFrame then
            local dragData = initialOffsets.draggedFrame
            self:ClearAllPoints()
            self:SetPoint(
                dragData.point,
                dragData.relativeTo,
                dragData.relativePoint,
                dragData.x + deltaX,
                dragData.y + deltaY
            )
        end
    end)
    
    mouseFrame:SetScript("OnDragStop", function(self)
        local targetFrame = self.dragTarget or frame
        isDragging = false
        
        -- Calculate final position from mouse delta (for non-DR elements)
        local scale = self:GetEffectiveScale()
        local currentX, currentY = GetCursorPosition()
        currentX = currentX / scale
        currentY = currentY / scale
        
        local deltaX = currentX - dragStartX
        local deltaY = currentY - dragStartY
        
        -- Get the original position from the dragged frame specifically
        local originalData = initialOffsets.draggedFrame
        if originalData then
            -- Calculate final position
            local finalX = originalData.x + deltaX
            local finalY = originalData.y + deltaY
            
            -- Round to nearest pixel
            finalX = math.floor(finalX + 0.5)
            finalY = math.floor(finalY + 0.5)
            
            -- No special handling needed - finalX/Y are already the correct relative offsets
            
            -- Save position (this triggers refresh for ALL frames in group)
            SavePosition(groupConfig, finalX, finalY)
        else
            -- Fallback: use current position
            local point, relativeTo, relativePoint, offsetX, offsetY = self:GetPoint()
            if offsetX and offsetY then
                offsetX = math.floor(offsetX + 0.5)
                offsetY = math.floor(offsetY + 0.5)
                SavePosition(groupConfig, offsetX, offsetY)
            end
        end
        
        -- Clear stored offsets
        initialOffsets = {}
    end)
end

local function RemoveDraggable(frame)
    if not frame then return end
    
    -- DEBUG: print("|cffFF6600[EditMode]|r RemoveDraggable called on frame: " .. tostring(frame))
    
    -- Clear draggable from the frame itself
    if rawget(frame, "editModeDraggable") then
        -- DEBUG: print("|cffFF6600[EditMode]|r Clearing frame draggable")
        rawset(frame, "editModeDraggable", nil)
        frame:SetMovable(false)
        frame:EnableMouse(false)
        frame:RegisterForDrag()
    end
    
    -- For DR icons, also clear mouse/drag from the glow frame (even if it doesn't have the flag)
    if frame.editModeGlowFrame then
        -- DEBUG: print("|cffFF6600[EditMode]|r Clearing glow frame mouse/drag")
        frame.editModeGlowFrame:SetMovable(false)
        frame.editModeGlowFrame:EnableMouse(false)
        frame.editModeGlowFrame:RegisterForDrag()
    end
    
    -- Hide blue glow
    if frame.editModeGlow then
        frame.editModeGlow:Hide()
    end
    if frame.editModeGlowFrame then
        frame.editModeGlowFrame:Hide()
    end
    
    -- Restore ONLY if this exact frame had edit-mode scripts saved
    if frame._emStoredScripts then
        frame:SetScript("OnDragStart", frame.originalOnDragStart)
        frame:SetScript("OnDragStop", frame.originalOnDragStop)
        frame:SetScript("OnUpdate", frame.originalOnUpdate)
        frame.originalOnDragStart, frame.originalOnDragStop, frame.originalOnUpdate = nil, nil, nil
        frame._emStoredScripts = nil
    end
end

-- ============================================================================
-- VISUAL OVERLAY SYSTEM
-- ============================================================================

local function CreateProfileEditModePopup()
    -- Create draggable popup for Profile Edit Mode (combines old + new info)
    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetSize(450, 310)
    popup:SetPoint("TOP", UIParent, "TOP", 0, -100)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(1000)
    popup:SetMovable(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    
    -- Use ArenaCore's dark texture styling
    local COLORS = AC.COLORS or {}
    
    -- Outer border
    local outerBorder = popup:CreateTexture(nil, "BACKGROUND")
    outerBorder:SetAllPoints()
    outerBorder:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    -- Inner background (dark)
    local bg = popup:CreateTexture(nil, "BORDER")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.98)
    
    -- Accent line at top (purple)
    local accent = popup:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 2, -2)
    accent:SetPoint("TOPRIGHT", -2, -2)
    accent:SetHeight(2)
    accent:SetColorTexture(0.55, 0.35, 0.65, 1)
    
    -- SECTION 1: Edit Mode Info (from old popup)
    local title1 = popup:CreateFontString(nil, "OVERLAY")
    title1:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 14, "OUTLINE")
    title1:SetText("EDIT MODE ACTIVE")
    title1:SetTextColor(1, 1, 0.3, 1) -- Yellow
    title1:SetPoint("TOP", popup, "TOP", 0, -15)
    
    local info1 = popup:CreateFontString(nil, "OVERLAY")
    info1:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 11)
    info1:SetText("Click and drag any blue element to reposition it")
    info1:SetTextColor(0.9, 0.9, 0.9, 1)
    info1:SetPoint("TOP", title1, "BOTTOM", 0, -8)
    info1:SetJustifyH("CENTER")
    
    -- Divider line
    local divider = popup:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -70)
    divider:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -20, -70)
    divider:SetHeight(1)
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    
    -- SECTION 2: Profile Edit Mode Info (new)
    local title2 = popup:CreateFontString(nil, "OVERLAY")
    title2:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 13, "OUTLINE")
    title2:SetText("PROFILE EDITING MODE ACTIVE")
    title2:SetTextColor(1, 0.6, 0.2, 1) -- Orange
    title2:SetPoint("TOP", popup, "TOP", 0, -80)
    
    -- WoW alert icon (Crosshair_Important_128) - MUST be created AFTER title
    local alertIcon2 = popup:CreateTexture(nil, "OVERLAY")
    alertIcon2:SetAtlas("Crosshair_Important_128")
    alertIcon2:SetSize(32, 32)
    alertIcon2:SetPoint("RIGHT", title2, "LEFT", -8, -1)
    
    local info2 = popup:CreateFontString(nil, "OVERLAY")
    info2:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 10)
    info2:SetText("Auto-save is DISABLED while editing.\n\nWhen finished:\n• Click \"Save to Current Profile\" to update current profile, OR\n• Click \"Create New Profile\" to save as a new profile")
    info2:SetTextColor(0.9, 0.9, 0.9, 1)
    info2:SetPoint("TOP", title2, "BOTTOM", 0, -8)
    info2:SetJustifyH("LEFT")
    info2:SetWidth(410)
    
    -- Button 1: Create New Profile (left) - Beautiful gradient style
    local createBtn = CreateFrame("Button", nil, popup)
    createBtn:SetSize(200, 32)
    createBtn:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 15, 50)
    
    -- Background (purple) - matches old popup style
    local createBg = createBtn:CreateTexture(nil, "BACKGROUND")
    createBg:SetAllPoints()
    createBg:SetColorTexture(0.545, 0.271, 1.000, 1) -- ArenaCore PRIMARY purple
    
    -- Border (darker for depth) - matches old popup style
    local createBorder = createBtn:CreateTexture(nil, "BORDER")
    createBorder:SetAllPoints()
    createBorder:SetColorTexture(0.4, 0.2, 0.7, 1) -- Darker purple border
    createBorder:SetPoint("TOPLEFT", 1, -1)
    createBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Text (white, no outline) - matches old popup style
    local createText = createBtn:CreateFontString(nil, "OVERLAY")
    createText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 11)
    createText:SetText("Create New Profile")
    createText:SetTextColor(1, 1, 1, 1) -- Pure white
    createText:SetPoint("CENTER")
    
    createBtn:SetScript("OnClick", function()
        -- Open More Features window to Profiles tab
        if AC.MoreFeatures and AC.MoreFeatures.ShowProfilesTab then
            AC.MoreFeatures:ShowProfilesTab()
        else
            print("|cffFF0000ArenaCore:|r More Features window not available")
        end
    end)
    
    -- Hover effect (lighter purple) - matches old popup style
    createBtn:SetScript("OnEnter", function()
        createBg:SetColorTexture(0.645, 0.371, 1.000, 1) -- Lighter purple on hover
    end)
    
    createBtn:SetScript("OnLeave", function()
        createBg:SetColorTexture(0.545, 0.271, 1.000, 1) -- Back to normal purple
    end)
    
    -- Button 2: Save to Current Profile (right) - Beautiful gradient style
    local saveBtn = CreateFrame("Button", nil, popup)
    saveBtn:SetSize(200, 32)
    saveBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -15, 50)
    
    -- Background (green) - matches old popup style
    local saveBg = saveBtn:CreateTexture(nil, "BACKGROUND")
    saveBg:SetAllPoints()
    saveBg:SetColorTexture(0.133, 0.667, 0.267, 1) -- Green
    
    -- Border (darker for depth) - matches old popup style
    local saveBorder = saveBtn:CreateTexture(nil, "BORDER")
    saveBorder:SetAllPoints()
    saveBorder:SetColorTexture(0.1, 0.5, 0.2, 1) -- Darker green border
    saveBorder:SetPoint("TOPLEFT", 1, -1)
    saveBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Text (white, no outline) - matches old popup style
    local saveText = saveBtn:CreateFontString(nil, "OVERLAY")
    saveText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 11)
    saveText:SetText("Save to Current Profile")
    saveText:SetTextColor(1, 1, 1, 1) -- Pure white
    saveText:SetPoint("CENTER")
    
    saveBtn:SetScript("OnClick", function()
        print("|cff00FF00[SAVE BUTTON]|r Save to Current Profile button clicked!")
        if AC.ProfileManager and AC.ProfileManager.CommitTempBuffer then
            AC.ProfileManager:CommitTempBuffer()
        else
            print("|cffFF0000ArenaCore:|r ProfileManager not available")
        end
    end)
    
    -- Hover effect (lighter green) - matches old popup style
    saveBtn:SetScript("OnEnter", function()
        saveBg:SetColorTexture(0.233, 0.767, 0.367, 1) -- Lighter green on hover
    end)
    
    saveBtn:SetScript("OnLeave", function()
        saveBg:SetColorTexture(0.133, 0.667, 0.267, 1) -- Back to normal green
    end)
    
    -- Button 3: Exit Edit Mode (bottom, full width) - Beautiful gradient style
    local exitBtn = CreateFrame("Button", nil, popup)
    exitBtn:SetSize(420, 32)
    exitBtn:SetPoint("BOTTOM", popup, "BOTTOM", 0, 12)
    
    -- Background (purple) - matches old popup style
    local exitBg = exitBtn:CreateTexture(nil, "BACKGROUND")
    exitBg:SetAllPoints()
    exitBg:SetColorTexture(0.545, 0.271, 1.000, 1) -- ArenaCore PRIMARY purple
    
    -- Border (darker for depth) - matches old popup style
    local exitBorder = exitBtn:CreateTexture(nil, "BORDER")
    exitBorder:SetAllPoints()
    exitBorder:SetColorTexture(0.4, 0.2, 0.7, 1) -- Darker purple border
    exitBorder:SetPoint("TOPLEFT", 1, -1)
    exitBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Text (white, no outline) - matches old popup style
    local exitText = exitBtn:CreateFontString(nil, "OVERLAY")
    exitText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 12)
    exitText:SetText("EXIT EDIT MODE")
    exitText:SetTextColor(1, 1, 1, 1) -- Pure white
    exitText:SetPoint("CENTER")
    
    exitBtn:SetScript("OnClick", function()
        print("|cffFF00FF[EXIT BUTTON]|r Exit Edit Mode button clicked!")
        if EM.ShowExitPrompt then
            EM:ShowExitPrompt()
        end
    end)
    
    -- Hover effect (lighter purple) - matches old popup style
    exitBtn:SetScript("OnEnter", function()
        exitBg:SetColorTexture(0.645, 0.371, 1.000, 1) -- Lighter purple on hover
    end)
    
    exitBtn:SetScript("OnLeave", function()
        exitBg:SetColorTexture(0.545, 0.271, 1.000, 1) -- Back to normal purple
    end)
    
    return popup
end

local function CreateEditModeOverlay()
    -- Create full-screen overlay
    local overlay = CreateFrame("Frame", "ArenaCoreEditModeOverlay", UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("MEDIUM") -- Changed from BACKGROUND to be visible over game world
    overlay:SetFrameLevel(1)
    
    -- Get cast bar texture from database
    local texturesDB = AC.DB and AC.DB.profile and AC.DB.profile.textures
    local castBarTexture = "Interface\\AddOns\\ArenaCore\\Media\\Frametextures\\texture1.tga"
    if texturesDB and texturesDB.castBarTexture then
        castBarTexture = texturesDB.castBarTexture
    end
    
    -- Solid purple base
    local tex = overlay:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    tex:SetVertexColor(0.4, 0.15, 0.5, 0.5) -- Purple base
    
    -- Create diagonal stripe pattern using cast bar texture
    -- Cover entire screen with more stripes
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    
    -- Calculate diagonal distance to cover entire screen
    local diagonal = math.sqrt(screenWidth^2 + screenHeight^2)
    local stripeSpacing = 30
    local stripeCount = math.ceil(diagonal / stripeSpacing) + 30 -- Extra stripes for full coverage
    
    for i = 1, stripeCount do
        local stripe = overlay:CreateTexture(nil, "ARTWORK")
        stripe:SetTexture(castBarTexture) -- Use your cast bar texture
        stripe:SetVertexColor(0.6, 0.25, 0.7, 0.4) -- Lighter purple for stripes
        stripe:SetBlendMode("ADD") -- Additive blending for nice overlay effect
        
        -- Position diagonal stripes to cover entire screen including corners
        local offset = (i - 1) * stripeSpacing - (diagonal / 2) - 300 -- Start well off-screen left
        stripe:SetSize(25, diagonal + 500) -- Make stripes as long as screen diagonal
        stripe:SetPoint("CENTER", overlay, "CENTER", offset * 0.707, offset * 0.707) -- Position along diagonal
        stripe:SetRotation(math.rad(45)) -- Rotate 45 degrees for diagonal
    end
    
    -- Create info popup with ArenaCore styling
    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetSize(280, 100)
    popup:SetPoint("TOP", UIParent, "TOP", 0, -100)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(1000)
    
    -- Use ArenaCore's dark texture styling (same as dispel window)
    local COLORS = AC.COLORS or {}
    
    -- Outer border
    local outerBorder = popup:CreateTexture(nil, "BACKGROUND")
    outerBorder:SetAllPoints()
    outerBorder:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    -- Inner background (dark)
    local bg = popup:CreateTexture(nil, "BORDER")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.98)
    
    -- Accent line at top (purple)
    local accent = popup:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 2, -2)
    accent:SetPoint("TOPRIGHT", -2, -2)
    accent:SetHeight(2)
    accent:SetColorTexture(0.55, 0.35, 0.65, 1)
    
    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 14, "OUTLINE")
    title:SetText("EDIT MODE ACTIVE")
    title:SetTextColor(1, 1, 0.3, 1) -- Yellow
    title:SetPoint("TOP", popup, "TOP", 0, -15)
    
    -- Info text
    local info = popup:CreateFontString(nil, "OVERLAY")
    info:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 11)
    info:SetText("Click and drag any blue element\nto reposition it")
    info:SetTextColor(0.9, 0.9, 0.9, 1)
    info:SetPoint("TOP", title, "BOTTOM", 0, -8)
    info:SetJustifyH("CENTER")
    
    -- Exit button with ArenaCore purple styling (matches Save Settings button)
    local exitBtn = CreateFrame("Button", nil, popup)
    exitBtn:SetSize(120, 28)
    exitBtn:SetPoint("BOTTOM", popup, "BOTTOM", 0, 10)
    
    -- Background (purple)
    local exitBg = exitBtn:CreateTexture(nil, "BACKGROUND")
    exitBg:SetAllPoints()
    exitBg:SetColorTexture(0.545, 0.271, 1.000, 1) -- ArenaCore PRIMARY purple
    
    -- Border (darker for depth)
    local exitBorder = exitBtn:CreateTexture(nil, "BORDER")
    exitBorder:SetAllPoints()
    exitBorder:SetColorTexture(0.4, 0.2, 0.7, 1) -- Darker purple border
    exitBorder:SetPoint("TOPLEFT", 1, -1)
    exitBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Text (white, no outline)
    local exitText = exitBtn:CreateFontString(nil, "OVERLAY")
    exitText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 12) -- No outline
    exitText:SetText("EXIT EDIT MODE")
    exitText:SetTextColor(1, 1, 1, 1) -- Pure white
    exitText:SetPoint("CENTER")
    
    exitBtn:SetScript("OnClick", function()
        if AC.EditMode then
            AC.EditMode:Disable()
            
            -- Update the Edit Mode button in Arena Frames page
            if AC.UpdateEditModeButton then
                AC.UpdateEditModeButton()
            end
        end
    end)
    
    -- Hover effect (lighter purple)
    exitBtn:SetScript("OnEnter", function()
        exitBg:SetColorTexture(0.645, 0.371, 1.000, 1) -- Lighter purple on hover
    end)
    
    exitBtn:SetScript("OnLeave", function()
        exitBg:SetColorTexture(0.545, 0.271, 1.000, 1) -- Back to normal purple
    end)
    
    overlay.popup = popup
    return overlay
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function EM:ShowExitPrompt()
    -- Check if there are unsaved changes
    local hasChanges = AC.ProfileManager and AC.ProfileManager:HasUnsavedChanges()
    
    -- CRITICAL FIX: Handle post-save exit properly
    if not hasChanges then
        if AC._skipRepositionOnRefresh then
            -- User just saved, now wants to exit
            -- Clear skip flag FIRST, then disable WITHOUT refresh
            print("|cffFFAA00[SHOW EXIT PROMPT]|r No changes and skip flag is set - clean exit without refresh")
            AC._skipRepositionOnRefresh = false
            self.isActive = false
            
            -- PROFILE EDIT MODE: Disable auto-save disable flag and clear snapshot
            AC.profileEditModeActive = false
            AC.profileSnapshot = nil
            
            -- Hide visual overlay
            if self.overlay then
                self.overlay:Hide()
                self.overlay.popup:Hide()
            end
            
            -- Hide Profile Edit Mode popup
            if self.profilePopup then
                self.profilePopup:Hide()
            end
            
            -- Remove draggable from all registered frames
            for groupName, frames in pairs(self.registeredFrames) do
                for _, frame in ipairs(frames) do
                    if frame.editModeGlow then
                        frame.editModeGlow:Hide()
                    end
                    if frame.editModeGlowFrame then
                        frame.editModeGlowFrame:Hide()
                    end
                end
            end
            
            -- Clear registry
            self.registeredFrames = {}
            
            return
        elseif not self.isActive then
            -- Edit Mode already disabled and no changes, nothing to do
            return
        else
            -- No unsaved changes and not in post-save state, just exit and rollback any visual changes
            self:Disable()
            
            -- CRITICAL: Force complete UI refresh to rollback ALL visual changes
            C_Timer.After(0.1, function()
                -- Refresh ALL element groups to rollback visual changes
                if AC.RefreshSpecIconsLayout then AC:RefreshSpecIconsLayout() end
                if AC.RefreshClassIconsLayout then AC:RefreshClassIconsLayout() end
                if AC.RefreshTrinketsOtherLayout then AC:RefreshTrinketsOtherLayout() end
                if AC.RefreshRacialsLayout then AC:RefreshRacialsLayout() end
                if AC.RefreshCastBarsLayout then AC:RefreshCastBarsLayout() end
                if AC.RefreshClassPacksLayout then AC:RefreshClassPacksLayout() end
                if AC.RefreshDebuffsLayout then AC:RefreshDebuffsLayout() end
                if AC.ProfileManager and AC.ProfileManager.ApplyArenaFramesSettings then
                    AC.ProfileManager:ApplyArenaFramesSettings()
                end
            end)
            return
        end
    end
    
    -- Create exit prompt (Option A - 3 buttons with detailed info)
    local prompt = CreateFrame("Frame", nil, UIParent)
    prompt:SetSize(400, 200)
    prompt:SetPoint("CENTER", 0, 0)
    prompt:SetFrameStrata("FULLSCREEN_DIALOG")
    prompt:SetFrameLevel(2000)
    
    -- Outer border
    local outerBorder = prompt:CreateTexture(nil, "BACKGROUND")
    outerBorder:SetAllPoints()
    outerBorder:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    -- Inner background (dark)
    local bg = prompt:CreateTexture(nil, "BORDER")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.98)
    
    -- Accent line at top (warning yellow)
    local accent = prompt:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 2, -2)
    accent:SetPoint("TOPRIGHT", -2, -2)
    accent:SetHeight(2)
    accent:SetColorTexture(0.8, 0.533, 0.0, 1)
    
    -- Title
    local title = prompt:CreateFontString(nil, "OVERLAY")
    title:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 14, "OUTLINE")
    title:SetText("UNSAVED CHANGES")
    title:SetTextColor(1, 0.8, 0.3, 1) -- Warning yellow
    title:SetPoint("TOP", prompt, "TOP", 0, -15)
    
    -- WoW alert icon (Crosshair_Important_128) - MUST be created AFTER title
    local alertIcon = prompt:CreateTexture(nil, "OVERLAY")
    alertIcon:SetAtlas("Crosshair_Important_128")
    alertIcon:SetSize(32, 32)
    alertIcon:SetPoint("RIGHT", title, "LEFT", -8, -1)
    
    -- Info text
    local changeCount = AC.ProfileManager:GetUnsavedChangeCount()
    local info = prompt:CreateFontString(nil, "OVERLAY")
    info:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 11)
    info:SetText("You have " .. changeCount .. " unsaved change" .. (changeCount > 1 and "s" or "") .. ".\nWhat would you like to do?")
    info:SetTextColor(0.9, 0.9, 0.9, 1)
    info:SetPoint("TOP", title, "BOTTOM", 0, -10)
    info:SetJustifyH("CENTER")
    
    -- Button 1: Save to Current Profile (left) - Beautiful gradient style
    local saveBtn = CreateFrame("Button", nil, prompt)
    saveBtn:SetSize(180, 32)
    saveBtn:SetPoint("TOPLEFT", prompt, "TOPLEFT", 15, -80)
    
    -- Background (green) - matches Edit Mode popup style
    local saveBg = saveBtn:CreateTexture(nil, "BACKGROUND")
    saveBg:SetAllPoints()
    saveBg:SetColorTexture(0.133, 0.667, 0.267, 1) -- Green
    
    -- Border (darker for depth) - matches Edit Mode popup style
    local saveBorder = saveBtn:CreateTexture(nil, "BORDER")
    saveBorder:SetAllPoints()
    saveBorder:SetColorTexture(0.1, 0.5, 0.2, 1) -- Darker green border
    saveBorder:SetPoint("TOPLEFT", 1, -1)
    saveBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Text (white, no outline) - matches Edit Mode popup style
    local saveText = saveBtn:CreateFontString(nil, "OVERLAY")
    saveText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 10)
    saveText:SetText("Save to\nCurrent Profile")
    saveText:SetTextColor(1, 1, 1, 1) -- Pure white
    saveText:SetPoint("CENTER")
    
    saveBtn:SetScript("OnClick", function()
        AC.ProfileManager:CommitTempBuffer()
        prompt:Hide()
        EM:Disable()
    end)
    
    -- Hover effect (lighter green) - matches Edit Mode popup style
    saveBtn:SetScript("OnEnter", function()
        saveBg:SetColorTexture(0.233, 0.767, 0.367, 1) -- Lighter green on hover
    end)
    
    saveBtn:SetScript("OnLeave", function()
        saveBg:SetColorTexture(0.133, 0.667, 0.267, 1) -- Back to normal green
    end)
    
    -- Button 2: Create New Profile (right) - Beautiful gradient style
    local createBtn = CreateFrame("Button", nil, prompt)
    createBtn:SetSize(180, 32)
    createBtn:SetPoint("TOPRIGHT", prompt, "TOPRIGHT", -15, -80)
    
    -- Background (purple) - matches Edit Mode popup style
    local createBg = createBtn:CreateTexture(nil, "BACKGROUND")
    createBg:SetAllPoints()
    createBg:SetColorTexture(0.545, 0.271, 1.000, 1) -- ArenaCore PRIMARY purple
    
    -- Border (darker for depth) - matches Edit Mode popup style
    local createBorder = createBtn:CreateTexture(nil, "BORDER")
    createBorder:SetAllPoints()
    createBorder:SetColorTexture(0.4, 0.2, 0.7, 1) -- Darker purple border
    createBorder:SetPoint("TOPLEFT", 1, -1)
    createBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Text (white, no outline) - matches Edit Mode popup style
    local createText = createBtn:CreateFontString(nil, "OVERLAY")
    createText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 10)
    createText:SetText("Create New\nProfile")
    createText:SetTextColor(1, 1, 1, 1) -- Pure white
    createText:SetPoint("CENTER")
    
    createBtn:SetScript("OnClick", function()
        prompt:Hide()
        if AC.MoreFeatures and AC.MoreFeatures.ShowProfilesTab then
            AC.MoreFeatures:ShowProfilesTab()
        end
    end)
    
    -- Hover effect (lighter purple) - matches Edit Mode popup style
    createBtn:SetScript("OnEnter", function()
        createBg:SetColorTexture(0.645, 0.371, 1.000, 1) -- Lighter purple on hover
    end)
    
    createBtn:SetScript("OnLeave", function()
        createBg:SetColorTexture(0.545, 0.271, 1.000, 1) -- Back to normal purple
    end)
    
    -- Button 3: Discard Changes & Exit (bottom, full width) - Beautiful gradient style
    local discardBtn = CreateFrame("Button", nil, prompt)
    discardBtn:SetSize(370, 32)
    discardBtn:SetPoint("BOTTOM", prompt, "BOTTOM", 0, 15)
    
    -- Background (red) - matches Edit Mode popup style
    local discardBg = discardBtn:CreateTexture(nil, "BACKGROUND")
    discardBg:SetAllPoints()
    discardBg:SetColorTexture(0.863, 0.176, 0.176, 1) -- Red
    
    -- Border (darker for depth) - matches Edit Mode popup style
    local discardBorder = discardBtn:CreateTexture(nil, "BORDER")
    discardBorder:SetAllPoints()
    discardBorder:SetColorTexture(0.6, 0.1, 0.1, 1) -- Darker red border
    discardBorder:SetPoint("TOPLEFT", 1, -1)
    discardBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    -- Text (white, no outline) - matches Edit Mode popup style
    local discardText = discardBtn:CreateFontString(nil, "OVERLAY")
    discardText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 11)
    discardText:SetText("Discard Changes & Exit")
    discardText:SetTextColor(1, 1, 1, 1) -- Pure white
    discardText:SetPoint("CENTER")
    
    discardBtn:SetScript("OnClick", function()
        AC.ProfileManager:DiscardTempBuffer()
        prompt:Hide()
        EM:Disable()
        
        -- CRITICAL: Force complete UI refresh to rollback ALL visual changes
        C_Timer.After(0.1, function()
            -- Refresh ALL element groups to rollback visual changes
            if AC.RefreshSpecIconsLayout then AC:RefreshSpecIconsLayout() end
            if AC.RefreshClassIconsLayout then AC:RefreshClassIconsLayout() end
            if AC.RefreshTrinketsOtherLayout then AC:RefreshTrinketsOtherLayout() end
            if AC.RefreshRacialsLayout then AC:RefreshRacialsLayout() end
            if AC.RefreshCastBarsLayout then AC:RefreshCastBarsLayout() end
            if AC.RefreshClassPacksLayout then AC:RefreshClassPacksLayout() end
            if AC.RefreshDebuffsLayout then AC:RefreshDebuffsLayout() end
            if AC.ProfileManager and AC.ProfileManager.ApplyArenaFramesSettings then
                AC.ProfileManager:ApplyArenaFramesSettings()
            end
            
            -- CRITICAL: Refresh More Features checkboxes AFTER Edit Mode is disabled
            if AC.ProfileManager and AC.ProfileManager.RefreshMoreFeaturesCheckboxes then
                AC.ProfileManager:RefreshMoreFeaturesCheckboxes()
            end
            
            print("|cffFFAA00ArenaCore:|r Visual changes rolled back to saved profile")
        end)
    end)
    
    -- Hover effect (lighter red) - matches Edit Mode popup style
    discardBtn:SetScript("OnEnter", function()
        discardBg:SetColorTexture(0.963, 0.276, 0.276, 1) -- Lighter red on hover
    end)
    
    discardBtn:SetScript("OnLeave", function()
        discardBg:SetColorTexture(0.863, 0.176, 0.176, 1) -- Back to normal red
    end)
    
    prompt:Show()
end

function EM:Enable()
    if self.isActive then return end
    
    -- Ensure test mode is active
    if not AC.testModeEnabled then
        print("|cffFF0000ArenaCore Edit Mode:|r Please enable Test Mode first (/ac test)")
        return
    end
    
    -- CRITICAL: Clear skip flag when entering Edit Mode to start fresh
    AC._skipRepositionOnRefresh = false
    print("|cff00FF00[EDIT MODE ENABLE]|r Cleared skip flag on Enable")
    
    self.isActive = true
    
    -- PROFILE EDIT MODE: Enable auto-save disable flag and create snapshot
    AC.profileEditModeActive = true
    
    -- CRITICAL: Create deep copy snapshot of current profile state
    -- This allows us to revert ALL changes (sliders, checkboxes, frames, etc.) if user discards
    if AC.Serialization and _G.ArenaCoreDB and _G.ArenaCoreDB.profile then
        AC.profileSnapshot = AC.Serialization:DeepCopy(_G.ArenaCoreDB.profile)
    end
    
    -- Create visual overlay
    if not self.overlay then
        self.overlay = CreateEditModeOverlay()
    end
    self.overlay:Show()
    
    -- CRITICAL: Hide old popup, show new combined popup instead
    self.overlay.popup:Hide()
    
    -- Create Profile Edit Mode popup (new combined popup with all info)
    if not self.profilePopup then
        self.profilePopup = CreateProfileEditModePopup()
    end
    self.profilePopup:Show()
    
    -- Make all element groups draggable
    for groupName, groupConfig in pairs(ELEMENT_GROUPS) do
        local frames = groupConfig.selector()
        for _, frame in ipairs(frames) do
            self:MakeDraggable(frame, groupConfig)
        end
        self.registeredFrames[groupName] = frames
    end
    
    -- Edit Mode enabled successfully
    
    -- DEBUG DISABLED FOR PRODUCTION
    -- print("|cff22AA44ArenaCore Edit Mode:|r ENABLED - Auto-save DISABLED (Profile Edit Mode)")
end

function EM:Disable()
    if not self.isActive then return end
    
    -- Disable() called
    
    self.isActive = false
    
    -- CRITICAL FIX: Set skip reposition flag BEFORE disabling edit mode
    -- This prevents frames from jumping when Edit Mode is disabled
    AC._skipRepositionOnRefresh = true
    
    -- PROFILE EDIT MODE: Disable auto-save disable flag and clear snapshot
    AC.profileEditModeActive = false
    AC.profileSnapshot = nil  -- Clear snapshot when exiting Edit Mode
    
    -- Hide visual overlay
    if self.overlay then
        self.overlay:Hide()
        self.overlay.popup:Hide()
    end
    
    -- Hide Profile Edit Mode popup
    if self.profilePopup then
        self.profilePopup:Hide()
    end
    
    -- Remove draggable from all registered frames
    for groupName, frames in pairs(self.registeredFrames) do
        for _, frame in ipairs(frames) do
            RemoveDraggable(frame)
            
            -- Hide glow texture and borders
            if frame.editModeGlow then
                frame.editModeGlow:Hide()
            end
            if frame.editModeGlowBorders then
                for _, border in ipairs(frame.editModeGlowBorders) do
                    border:Hide()
                end
            end
            
            -- CRITICAL: Clean up debug textures
            if frame.debugTexture then
                frame.debugTexture:Hide()
                frame.debugTexture = nil
            end
            
            -- Clean up debug backgrounds on child frames (DR icons)
            local children = {frame:GetChildren()}
            for _, child in ipairs(children) do
                if child.dragDebugBg then
                    child.dragDebugBg:Hide()
                    child.dragDebugBg = nil
                end
            end
        end
    end
    
    -- Clear registry
    self.registeredFrames = {}
    
    -- DEBUG DISABLED FOR PRODUCTION
    -- print("|cff22AA44ArenaCore Edit Mode:|r DISABLED - Frames locked")
    
    -- Update the Edit Mode button in Arena Frames page
    if AC.UpdateEditModeButton then
        AC.UpdateEditModeButton()
    end
    
    -- Clear skip reposition flag after delay to prevent flicker
    C_Timer.After(1.0, function()
        if not self.isActive then
            AC._skipRepositionOnRefresh = false
        end
    end)
end

function EM:Toggle()
    if self.isActive then
        self:Disable()
    else
        self:Enable()
    end
end

function EM:IsActive()
    return self.isActive
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

SLASH_ACEDITMODE1 = "/acedit"
SlashCmdList["ACEDITMODE"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "on" or msg == "enable" then
        EM:Enable()
    elseif msg == "off" or msg == "disable" then
        EM:Disable()
    elseif msg == "toggle" or msg == "" then
        EM:Toggle()
    elseif msg == "status" then
        if EM.isActive then
            print("|cff22AA44ArenaCore Edit Mode:|r Currently ENABLED")
        else
            print("|cffFFAA00ArenaCore Edit Mode:|r Currently DISABLED")
        end
    elseif msg == "help" then
        print("|cff22AA44ArenaCore Edit Mode Commands:|r")
        print("  /acedit - Toggle edit mode on/off")
        print("  /acedit on - Enable edit mode")
        print("  /acedit off - Disable edit mode")
        print("  /acedit status - Check if edit mode is active")
        print(" ")
        print("|cffFFAA00How it works:|r")
        print("  • Enable Test Mode first (/ac test)")
        print("  • Enable Edit Mode (/acedit)")
        print("  • Click and drag any element (trinket, cast bar, etc.)")
        print("  • All elements in that group move together")
        print("  • Changes save in real-time to the same database as sliders")
        print("  • Use /ac hide and /ac test to verify positions persist")
    else
        print("|cffFF0000ArenaCore Edit Mode:|r Unknown command. Type /acedit help for usage")
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- Hook into UI close to also disable Edit Mode
-- Use event system to wait for UI to be created
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("ADDON_LOADED")
hookFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "ArenaCore" then
        -- Try multiple times to find the frame
        local attempts = 0
        local function TryHook()
            attempts = attempts + 1
            local configFrame = _G["ArenaCoreConfigFrame"]
            if configFrame then
                configFrame:HookScript("OnHide", function()
                    -- DEBUG: print("|cffFF00FF[EditMode]|r UI OnHide triggered! isActive=" .. tostring(EM.isActive))
                    if EM.isActive then
                        -- UI closed, disabling Edit Mode
                        -- DEBUG: print("|cffFF0000[EditMode]|r UI closed, calling Disable()")
                        EM:Disable()
                        -- Update button if it exists
                        if AC.UpdateEditModeButton then
                            AC.UpdateEditModeButton()
                        end
                    end
                    
                    -- Apply Z-order policy when panel hides
                    if AC.ZPolicy then
                        AC.ZPolicy:OnPanelHide()
                    end
                end)
                -- Hooked to UI close
            elseif attempts < 10 then
                -- Try again in 0.5 seconds
                C_Timer.After(0.5, TryHook)
            else
                -- DEBUG: Config frame not found - not critical, Edit Mode still works
                -- print("|cffFF0000ArenaCore Edit Mode:|r Could not find ArenaCoreConfigFrame after 10 attempts")
            end
        end
        TryHook()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Disabled startup message for end users
-- print("|cff22AA44ArenaCore:|r Edit Mode loaded - Type /acedit help for usage")
