local AC = _G.ArenaCore or {}

local CastBars = {}
local bit_band = bit.band

local function ResolveSpellSchoolMask(spellOrMask)
    if not spellOrMask then
        return 1  -- Physical (default)
    end

    if type(spellOrMask) == "number" then
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellOrMask)
            if info and info.schoolMask and info.schoolMask ~= 0 then
                -- Successfully retrieved spell school from spell ID
                return info.schoolMask
            end
        end

        -- CRITICAL FIX: If we can't get spell info, assume it's already a school mask
        -- School masks are small numbers (1, 2, 4, 8, 16, 32, 64 or combinations)
        -- Spell IDs are typically large (100+)
        -- If input is < 100, treat as school mask; otherwise default to Physical
        if spellOrMask < 100 then
            return spellOrMask
        else
            -- Spell ID but couldn't get info - default to Physical
            return 1
        end
    end

    return 1  -- Physical (default)
end

---Return RGB values for a given spell school or spell ID.
---@param spellOrMask number|nil Spell school mask or spell ID.
function CastBars:GetSpellSchoolColor(spellOrMask)
    local spellSchool = ResolveSpellSchoolMask(spellOrMask)

    -- Spell School Color Mapping (WoW Standard)
    if not spellSchool or spellSchool == 0 then
        return 1.0, 0.7, 0.0  -- Unknown/Default - Orange
    elseif spellSchool == 1 then
        return 1.0, 1.0, 1.0  -- Physical - White
    elseif spellSchool == 2 or bit_band(spellSchool, 2) > 0 then
        return 1.0, 0.9, 0.0  -- Holy - Gold/Yellow
    elseif spellSchool == 4 or bit_band(spellSchool, 4) > 0 then
        return 1.0, 0.3, 0.0  -- Fire - Orange/Red
    elseif spellSchool == 8 or bit_band(spellSchool, 8) > 0 then
        return 0.3, 1.0, 0.3  -- Nature - Green
    elseif spellSchool == 16 or bit_band(spellSchool, 16) > 0 then
        return 0.3, 0.8, 1.0  -- Frost - Light Blue
    elseif spellSchool == 32 or bit_band(spellSchool, 32) > 0 then
        return 0.5, 0.3, 0.7  -- Shadow - Purple
    elseif spellSchool == 64 or bit_band(spellSchool, 64) > 0 then
        return 1.0, 0.5, 1.0  -- Arcane - Pink/Purple
    else
        return 1.0, 0.7, 0.0  -- Fallback - Orange
    end
end

---Register all UNIT_SPELLCAST events that drive cast bar updates.
function CastBars:RegisterEvents(eventFrame)
    if not eventFrame then return end
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "arena1", "arena2", "arena3")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "arena1", "arena2", "arena3")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "arena1", "arena2", "arena3")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "arena1", "arena2", "arena3")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "arena1", "arena2", "arena3")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "arena1", "arena2", "arena3")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", "arena1", "arena2", "arena3")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", "arena1", "arena2", "arena3")
end

---Handle UNIT_SPELLCAST_* events and update the supplied cast bar.
function CastBars:Update(frame, unit, event)
    if not frame or not frame.castBar then return end

    if _G.ArenaCore and _G.ArenaCore.testModeEnabled then
        return
    end

    local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID

    if event == "UNIT_SPELLCAST_START" then
        name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unit)
        if name then
            frame.castBar.isCasting = true
            frame.castBar.isChanneling = false
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unit)
        if name then
            frame.castBar.isChanneling = true
            frame.castBar.isCasting = false
        end
    elseif event == "UNIT_SPELLCAST_EMPOWER_START" then
        name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, spellID = UnitChannelInfo(unit)
        if name then
            frame.castBar.isChanneling = true
            frame.castBar.isCasting = false
        end
    end

    if not name or not startTime or not endTime then
        self:Hide(frame)
        return
    end

    if frame.castBar.borderFrame then
        frame.castBar.borderFrame:Show()
    end

    if frame.castBar.shieldOverlay then
        if notInterruptible then
            frame.castBar.shieldOverlay:Show()
        else
            frame.castBar.shieldOverlay:Hide()
        end
    end

    local castBarDB = AC.DB and AC.DB.profile and AC.DB.profile.castBars
    if notInterruptible then
        frame.castBar:SetStatusBarColor(1.0, 1.0, 1.0)
    else
        if castBarDB and castBarDB.spellSchoolColors then
            -- CRITICAL FIX: Pass spellID directly to GetSpellSchoolColor
            -- Let ResolveSpellSchoolMask() handle the spell school lookup
            -- Don't pre-extract schoolMask as it may be nil/0
            local r, g, b = CastBars:GetSpellSchoolColor(spellID)
            frame.castBar:SetStatusBarColor(r, g, b)
        else
            frame.castBar:SetStatusBarColor(1.0, 0.7, 0.0)
        end
    end

    local statusBarTexture = frame.castBar:GetStatusBarTexture()
    if statusBarTexture then
        statusBarTexture:SetDrawLayer("ARTWORK", 0)
        statusBarTexture:SetAlpha(1.0)
        statusBarTexture:Show()
    end

    frame.castBar:Show()
    frame.castBar:SetAlpha(1.0)

    if frame.castBar.bg then
        frame.castBar.bg:Show()
    end

    if frame.castBar.text then
        frame.castBar.text:SetText(name or text or "")
        frame.castBar.text:Show()
    end

    if frame.castBar.spellIcon and frame.castBar.spellIcon.texture and texture then
        frame.castBar.spellIcon.texture:SetTexture(texture)
        local spellIconsEnabled = castBarDB and castBarDB.spellIcons and (castBarDB.spellIcons.enabled == true)
        if spellIconsEnabled then
            frame.castBar.spellIcon:Show()
            
            -- CRITICAL FIX: Show the border textures when showing the spell icon
            -- These were hidden in UpdatePrepRoomUnit and need to be shown again
            if frame.castBar.spellIcon.border then
                if frame.castBar.spellIcon.border.top then frame.castBar.spellIcon.border.top:Show() end
                if frame.castBar.spellIcon.border.bottom then frame.castBar.spellIcon.border.bottom:Show() end
                if frame.castBar.spellIcon.border.left then frame.castBar.spellIcon.border.left:Show() end
                if frame.castBar.spellIcon.border.right then frame.castBar.spellIcon.border.right:Show() end
            end
            -- Also check styledBorder (alternative storage location)
            if frame.castBar.spellIcon.styledBorder then
                if frame.castBar.spellIcon.styledBorder.top then frame.castBar.spellIcon.styledBorder.top:Show() end
                if frame.castBar.spellIcon.styledBorder.bottom then frame.castBar.spellIcon.styledBorder.bottom:Show() end
                if frame.castBar.spellIcon.styledBorder.left then frame.castBar.spellIcon.styledBorder.left:Show() end
                if frame.castBar.spellIcon.styledBorder.right then frame.castBar.spellIcon.styledBorder.right:Show() end
            end
        else
            frame.castBar.spellIcon:Hide()
        end
    end

    local duration = (endTime - startTime) / 1000
    frame.castBar:SetMinMaxValues(0, duration)
    
    -- CRITICAL FIX: Channeled spells start at max and count down (Gladius-style)
    -- Normal casts start at 0 and count up
    if frame.castBar.isChanneling then
        -- Channeling: Start at max (full bar), count down to 0
        frame.castBar:SetValue(duration)
    else
        -- Normal cast: Start at 0, count up to max
        frame.castBar:SetValue((GetTime() * 1000 - startTime) / 1000)
    end
    
    frame.castBar._castStartTimeMS = startTime
    frame.castBar._castEndTimeMS = endTime

    if frame.castBar.updateTimer then
        frame.castBar.updateTimer:Cancel()
        frame.castBar.updateTimer = nil
    end

    frame.castBar.updateTimer = C_Timer.NewTicker(0.01, function()
        if not frame.castBar:IsShown() then
            if frame.castBar.updateTimer then
                frame.castBar.updateTimer:Cancel()
                frame.castBar.updateTimer = nil
            end
            return
        end

        local newTime = GetTime() * 1000
        local duration = frame.castBar._castEndTimeMS - frame.castBar._castStartTimeMS
        local elapsed = newTime - frame.castBar._castStartTimeMS

        -- CRITICAL FIX: Different update logic for channeling vs casting
        if frame.castBar.isChanneling then
            -- Channeling: Count down from max to 0 (bar empties)
            local remaining = duration - elapsed
            if remaining <= 0 then
                CastBars:Hide(frame)
                return
            end
            frame.castBar:SetValue(remaining / 1000)
        else
            -- Normal cast: Count up from 0 to max (bar fills)
            if elapsed >= duration then
                CastBars:Hide(frame)
                return
            end
            frame.castBar:SetValue(elapsed / 1000)
        end
    end)
end

---Hide and reset the cast bar for the supplied frame.
function CastBars:Hide(frame)
    if not frame or not frame.castBar then return end

    if frame.castBar.updateTimer then
        frame.castBar.updateTimer:Cancel()
        frame.castBar.updateTimer = nil
    end

    frame.castBar:Hide()
    frame.castBar:SetValue(0)
    frame.castBar.isCasting = false
    frame.castBar.isChanneling = false

    if frame.castBar.bg then
        frame.castBar.bg:Hide()
    end

    if frame.castBar.text then
        frame.castBar.text:SetText("")
        frame.castBar.text:Hide()
    end

    if frame.castBar.spellIcon then
        frame.castBar.spellIcon:Hide()
    end

    if frame.castBar.shieldOverlay then
        frame.castBar.shieldOverlay:Hide()
    end

    if frame.castBar.borderFrame then
        frame.castBar.borderFrame:Hide()
    end
end

---Apply static test-mode spell visuals to a frame's cast bar.
---@param frame table Arena frame container.
---@param spellData table Table with `name`, `icon`, `spellSchool` fields.
---@param opts table|nil Optional config `{ isNonInterruptible=bool, progress=number }`.
function CastBars:ApplyTestSpell(frame, spellData, opts)
    if not frame or not frame.castBar or not spellData then return end

    local castBarDB = AC.DB and AC.DB.profile and AC.DB.profile.castBars
    local useSpellSchoolColors = castBarDB and castBarDB.spellSchoolColors
    local spellIconsEnabled = castBarDB and castBarDB.spellIcons and (castBarDB.spellIcons.enabled == true)
    local progress = opts and opts.progress or 75
    local nonInterruptible = opts and opts.isNonInterruptible or false

    local castBar = frame.castBar

    castBar.testSpellName = spellData.name
    castBar.testSpellIcon = spellData.icon
    castBar.testSpellSchool = spellData.spellSchool or 1
    castBar.testNotInterruptible = nonInterruptible

    castBar:SetMinMaxValues(0, 100)
    castBar:SetValue(progress)
    castBar:SetAlpha(1)
    castBar:Show()

    if castBar.fill then
        castBar.fill:Show()
    end
    if castBar.bg then
        castBar.bg:Show()
    end
    if castBar.borderFrame then
        castBar.borderFrame:Show()
    end

    if castBar.text then
        castBar.text:SetText(spellData.name or "")
        castBar.text:Show()
    end

    if castBar.spellIcon and castBar.spellIcon.texture then
        if spellData.icon then
            castBar.spellIcon.texture:SetTexture(spellData.icon)
        end
        if spellIconsEnabled then
            castBar.spellIcon:Show()
            
            -- CRITICAL FIX: Show the border textures when showing the spell icon
            if castBar.spellIcon.border then
                if castBar.spellIcon.border.top then castBar.spellIcon.border.top:Show() end
                if castBar.spellIcon.border.bottom then castBar.spellIcon.border.bottom:Show() end
                if castBar.spellIcon.border.left then castBar.spellIcon.border.left:Show() end
                if castBar.spellIcon.border.right then castBar.spellIcon.border.right:Show() end
            end
            if castBar.spellIcon.styledBorder then
                if castBar.spellIcon.styledBorder.top then castBar.spellIcon.styledBorder.top:Show() end
                if castBar.spellIcon.styledBorder.bottom then castBar.spellIcon.styledBorder.bottom:Show() end
                if castBar.spellIcon.styledBorder.left then castBar.spellIcon.styledBorder.left:Show() end
                if castBar.spellIcon.styledBorder.right then castBar.spellIcon.styledBorder.right:Show() end
            end
        else
            castBar.spellIcon:Hide()
        end
    end

    if castBar.shieldOverlay then
        if nonInterruptible then
            castBar.shieldOverlay:Show()
        else
            castBar.shieldOverlay:Hide()
        end
    end

    if nonInterruptible then
        castBar:SetStatusBarColor(1.0, 1.0, 1.0)
    elseif useSpellSchoolColors then
        local r, g, b = self:GetSpellSchoolColor(castBar.testSpellSchool)
        castBar:SetStatusBarColor(r, g, b)
    else
        castBar:SetStatusBarColor(1.0, 0.7, 0.0)
    end
end

---Refresh stored test-mode visuals after layout changes.
---@param frame table Arena frame container.
---@param castBarDB table|nil Cast bar database settings.
function CastBars:RefreshTestLayout(frame, castBarDB)
    if not frame or not frame.castBar then return end
    local castBar = frame.castBar

    if not AC.testModeEnabled or not castBar:IsShown() then
        return
    end

    castBarDB = castBarDB or (AC.DB and AC.DB.profile and AC.DB.profile.castBars)
    local useSpellSchoolColors = castBarDB and castBarDB.spellSchoolColors
    local spellIconsEnabled = castBarDB and castBarDB.spellIcons and (castBarDB.spellIcons.enabled == true)

    castBar:SetAlpha(1)

    if castBar.fill then
        castBar.fill:Show()
    end
    if castBar.bg then
        castBar.bg:Show()
    end
    if castBar.borderFrame then
        castBar.borderFrame:Show()
    end

    if castBar.text and castBar.testSpellName then
        castBar.text:SetText(castBar.testSpellName)
        castBar.text:Show()
    end

    if castBar.spellIcon and castBar.spellIcon.texture and castBar.testSpellIcon then
        castBar.spellIcon.texture:SetTexture(castBar.testSpellIcon)
        if spellIconsEnabled then
            castBar.spellIcon:Show()
            
            -- CRITICAL FIX: Show the border textures when showing the spell icon
            if castBar.spellIcon.border then
                if castBar.spellIcon.border.top then castBar.spellIcon.border.top:Show() end
                if castBar.spellIcon.border.bottom then castBar.spellIcon.border.bottom:Show() end
                if castBar.spellIcon.border.left then castBar.spellIcon.border.left:Show() end
                if castBar.spellIcon.border.right then castBar.spellIcon.border.right:Show() end
            end
            if castBar.spellIcon.styledBorder then
                if castBar.spellIcon.styledBorder.top then castBar.spellIcon.styledBorder.top:Show() end
                if castBar.spellIcon.styledBorder.bottom then castBar.spellIcon.styledBorder.bottom:Show() end
                if castBar.spellIcon.styledBorder.left then castBar.spellIcon.styledBorder.left:Show() end
                if castBar.spellIcon.styledBorder.right then castBar.spellIcon.styledBorder.right:Show() end
            end
        else
            castBar.spellIcon:Hide()
        end
    elseif castBar.spellIcon and not spellIconsEnabled then
        castBar.spellIcon:Hide()
    end

    if castBar.shieldOverlay then
        if castBar.testNotInterruptible then
            castBar.shieldOverlay:Show()
        else
            castBar.shieldOverlay:Hide()
        end
    end

    if castBar.testNotInterruptible then
        castBar:SetStatusBarColor(1.0, 1.0, 1.0)
    elseif useSpellSchoolColors then
        local r, g, b = self:GetSpellSchoolColor(castBar.testSpellSchool or 1)
        castBar:SetStatusBarColor(r, g, b)
    else
        castBar:SetStatusBarColor(1.0, 0.7, 0.0)
    end
end

AC.MasterFrameManager = AC.MasterFrameManager or {}
AC.FrameManager = AC.MasterFrameManager
AC.MasterFrameManager.CastBars = CastBars

return CastBars
