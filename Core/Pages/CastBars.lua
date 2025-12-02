-- ============================================================================
-- File: ArenaCore/Core/Pages/CastBars.lua (CLEAN REBUILD)
-- Purpose: Clean rebuild of Cast Bars settings page with single source of truth
-- ============================================================================

local AC = _G.ArenaCore
if not AC then return end

local V = AC.Vanity

-- SINGLE SOURCE OF TRUTH: All defaults come from AC.DEFAULTS.castBars
local function GetDefaults()
    return AC.DEFAULTS and AC.DEFAULTS.castBars or {
        positioning = { horizontal = 2, vertical = -81 },
        sizing = { scale = 86, width = 227, height = 18 },
        spellSchoolColors = true,
        spellIcons = {
            enabled = true,
            positioning = { horizontal = -4, vertical = 0 },
            sizing = { scale = 121 }
        }
    }
end

-- Get current database values with proper fallbacks
local function GetDB()
    if not AC.DB or not AC.DB.profile then return GetDefaults() end
    return AC.DB.profile.castBars or GetDefaults()
end

-- Update cast bars immediately when settings change
local function RefreshCastBars()
    if AC.RefreshCastBarsLayout then
        AC:RefreshCastBarsLayout()
    end
end

-- Clean slider creation with no initialization conflicts
local function CreateCleanSlider(parent, label, y, dbPath, min, max, isPct)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 20, y)
    row:SetPoint("TOPRIGHT", -20, y)
    row:SetHeight(26)

    -- Label
    local labelText = AC:CreateStyledText(row, label, 11, AC.COLORS.TEXT_2, "OVERLAY", "")
    labelText:SetPoint("LEFT", 0, 0)
    labelText:SetWidth(70)
    labelText:SetJustifyH("LEFT")

    -- Create DOWN arrow button for fine adjustment
    local downBtn = CreateFrame("Button", nil, row)
    downBtn:SetSize(16, 16)
    downBtn:SetPoint("LEFT", labelText, "RIGHT", 6, 0)
    
    -- Down arrow styling
    local downBg = downBtn:CreateTexture(nil, "BACKGROUND")
    downBg:SetAllPoints()
    downBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    local downBorder = downBtn:CreateTexture(nil, "BORDER") 
    downBorder:SetAllPoints()
    downBorder:SetColorTexture(0.4, 0.4, 0.4, 1)
    downBorder:SetPoint("TOPLEFT", 1, -1)
    downBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    local downText = downBtn:CreateFontString(nil, "OVERLAY")
    downText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 12, "")
    downText:SetText("-")
    downText:SetTextColor(0.8, 0.8, 0.8, 1)
    downText:SetPoint("CENTER")

    -- Min/Max labels
    local minText = AC:CreateStyledText(row, isPct and (min .. "%") or tostring(min), 9, AC.COLORS.TEXT_MUTED, "OVERLAY", "")
    minText:SetPoint("LEFT", downBtn, "RIGHT", 6, 0)
    minText:SetWidth(25)
    minText:SetJustifyH("RIGHT")

    -- Value display
    local valueText = AC:CreateStyledText(row, "", 11, AC.COLORS.TEXT_2, "OVERLAY", "")
    valueText:SetWidth(70)
    valueText:SetJustifyH("CENTER")

    -- Get current value from database
    local db = GetDB()
    local keys = {}
    for k in string.gmatch(dbPath, "([^%.]+)") do
        table.insert(keys, k)
    end
    
    local currentValue = db
    for _, key in ipairs(keys) do
        currentValue = currentValue and currentValue[key]
    end
    
    -- Use default if no value exists
    local defaults = GetDefaults()
    local defaultValue = defaults
    for _, key in ipairs(keys) do
        defaultValue = defaultValue and defaultValue[key]
    end
    currentValue = currentValue or defaultValue or (isPct and 100 or 0)

    -- OnChange function - ONLY called by user interaction
    local function OnChange(value)
        -- Ensure database structure exists
        AC.DB.profile = AC.DB.profile or {}
        AC.DB.profile.castBars = AC.DB.profile.castBars or {}
        
        local target = AC.DB.profile.castBars
        for i = 1, #keys - 1 do
            target[keys[i]] = target[keys[i]] or {}
            target = target[keys[i]]
        end
        target[keys[#keys]] = value

        -- Update display
        if isPct then
            valueText:SetText(string.format("%.0f%%", value))
        else
            valueText:SetText(string.format("%.0f", value))
        end

        -- Refresh cast bars
        RefreshCastBars()
    end

    -- Create slider
    local slider = AC:CreateFlatSlider(row, 120, 18, min, max, currentValue, isPct, OnChange)
    slider:SetPoint("LEFT", minText, "RIGHT", 10, 0)

    -- Create UP arrow button for fine adjustment  
    local upBtn = CreateFrame("Button", nil, row)
    upBtn:SetSize(16, 16)
    upBtn:SetPoint("LEFT", slider, "RIGHT", 4, 0)
    
    -- Up arrow styling
    local upBg = upBtn:CreateTexture(nil, "BACKGROUND")
    upBg:SetAllPoints()
    upBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    local upBorder = upBtn:CreateTexture(nil, "BORDER")
    upBorder:SetAllPoints() 
    upBorder:SetColorTexture(0.4, 0.4, 0.4, 1)
    upBorder:SetPoint("TOPLEFT", 1, -1)
    upBorder:SetPoint("BOTTOMRIGHT", -1, 1)
    
    local upText = upBtn:CreateFontString(nil, "OVERLAY")
    upText:SetFont("Interface/AddOns/ArenaCore/Media/Fonts/arenacore.ttf", 12, "")
    upText:SetText("+")
    upText:SetTextColor(0.8, 0.8, 0.8, 1)
    upText:SetPoint("CENTER")

    -- Max label
    local maxText = AC:CreateStyledText(row, isPct and (max .. "%") or tostring(max), 9, AC.COLORS.TEXT_MUTED, "OVERLAY", "")
    maxText:SetPoint("LEFT", upBtn, "RIGHT", 6, 0)
    maxText:SetWidth(20)
    maxText:SetJustifyH("LEFT")

    -- Position value text
    valueText:SetPoint("LEFT", maxText, "RIGHT", 8, 0)

    -- Initialize display WITHOUT calling OnChange
    if isPct then
        valueText:SetText(string.format("%.0f%%", currentValue))
    else
        valueText:SetText(string.format("%.0f", currentValue))
    end

    -- Down arrow click handler
    downBtn:SetScript("OnClick", function()
        local currentVal = slider.slider:GetValue()
        local increment = isPct and 1 or 1
        local newVal = math.max(min, currentVal - increment)
        slider.slider:SetValue(newVal)
    end)

    -- Up arrow click handler
    upBtn:SetScript("OnClick", function()
        local currentVal = slider.slider:GetValue()
        local increment = isPct and 1 or 1
        local newVal = math.min(max, currentVal + increment)
        slider.slider:SetValue(newVal)
    end)

    -- Arrow hover effects
    downBtn:SetScript("OnEnter", function()
        downBg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
        downText:SetTextColor(1, 1, 1, 1)
    end)
    downBtn:SetScript("OnLeave", function()
        downBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        downText:SetTextColor(0.8, 0.8, 0.8, 1)
    end)
    
    upBtn:SetScript("OnEnter", function()
        upBg:SetColorTexture(0.3, 0.3, 0.3, 0.9)
        upText:SetTextColor(1, 1, 1, 1)
    end)
    upBtn:SetScript("OnLeave", function()
        upBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        upText:SetTextColor(0.8, 0.8, 0.8, 1)
    end)

    return row
end

-- Clean checkbox creation
local function CreateCleanCheckbox(parent, label, y, dbPath)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 20, y)
    row:SetPoint("TOPRIGHT", -20, y)
    row:SetHeight(26)

    local labelText = AC:CreateStyledText(row, label, 12, AC.COLORS.TEXT_2, "OVERLAY", "")
    labelText:SetPoint("LEFT", 0, 0)

    -- Get current value
    local db = GetDB()
    local keys = {}
    for k in string.gmatch(dbPath, "([^%.]+)") do
        table.insert(keys, k)
    end
    
    local currentValue = db
    for _, key in ipairs(keys) do
        currentValue = currentValue and currentValue[key]
    end
    
    -- Use default if no value exists
    local defaults = GetDefaults()
    local defaultValue = defaults
    for _, key in ipairs(keys) do
        defaultValue = defaultValue and defaultValue[key]
    end
    -- CRITICAL FIX: Don't use 'or' operator with boolean values
    -- When currentValue is false, 'false or X' evaluates to X, which is wrong
    if currentValue == nil then
        currentValue = defaultValue
    end

    local function OnChange(value)
        -- Ensure database structure exists
        AC.DB.profile = AC.DB.profile or {}
        AC.DB.profile.castBars = AC.DB.profile.castBars or {}
        
        local target = AC.DB.profile.castBars
        for i = 1, #keys - 1 do
            target[keys[i]] = target[keys[i]] or {}
            target = target[keys[i]]
        end
        target[keys[#keys]] = value

        -- Refresh cast bars
        RefreshCastBars()
    end

    local checkbox = AC:CreateFlatCheckbox(row, 20, currentValue, OnChange)
    checkbox:SetPoint("RIGHT", -25, 0)

    return row
end

-- Reset function that uses DEFAULTS
local function ResetToDefaults()
    -- Reset database to defaults
    AC.DB.profile = AC.DB.profile or {}
    AC.DB.profile.castBars = {}
    
    -- Deep copy defaults
    local defaults = GetDefaults()
    local function DeepCopy(tbl)
        if type(tbl) ~= "table" then return tbl end
        local out = {}
        for k, v in pairs(tbl) do out[k] = DeepCopy(v) end
        return out
    end
    
    AC.DB.profile.castBars = DeepCopy(defaults)
    
    -- Refresh cast bars
    RefreshCastBars()
    
    -- Refresh page to update all controls
    C_Timer.After(0.1, function()
        if AC.ShowPage and AC.currentPage == "CastBars" then
            AC:ShowPage("CastBars")
        end
    end)
end

-- Main page creation function
local function CreateCleanCastBarsPage(parent)
    local db = GetDB()

    if V and V.EnsureMottoStrip then V:EnsureMottoStrip(parent) end
    
    -- Create the top button bar
    local buttonBar = CreateFrame("Frame", nil, parent)
    if parent._mottoStrip then
        buttonBar:SetPoint("TOPLEFT", parent._mottoStrip, "BOTTOMLEFT", 2, -8)
        buttonBar:SetPoint("TOPRIGHT", parent._mottoStrip, "BOTTOMRIGHT", -2, -8)
    else
        buttonBar:SetPoint("TOPLEFT", 10, -52)
        buttonBar:SetPoint("TOPRIGHT", -10, -52)
    end
    buttonBar:SetHeight(40)

    local sBorder = AC:CreateFlatTexture(buttonBar, "BACKGROUND", 1, AC.COLORS.BORDER_LIGHT, 0.6)
    sBorder:SetAllPoints()
    local sFill = AC:CreateFlatTexture(buttonBar, "BACKGROUND", 2, AC.COLORS.INPUT_DARK, 1)
    sFill:SetPoint("TOPLEFT", 1, -1); sFill:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Personal Mascot button (no function)
    local mascotBtn = AC:CreateTexturedButton(buttonBar, 140, 32, "Personal Mascot", "UI\\tab-purple-matte")
    mascotBtn:SetPoint("LEFT", 6, 0)
    -- No function assigned - button disabled
    
    -- Coming Soon notice
    AC:CreateComingSoonText(buttonBar, mascotBtn)

    -- REMOVED: TEST and HIDE buttons - replaced by new unified architecture

    -- Group 1: SPELL SCHOOLS
    local groupSchools = CreateFrame("Frame", nil, parent)
    groupSchools:SetPoint("TOPLEFT", buttonBar, "BOTTOMLEFT", 18, -18)
    groupSchools:SetPoint("TOPRIGHT", buttonBar, "BOTTOMRIGHT", -18, -18)
    groupSchools:SetHeight(80)
    AC:HairlineGroupBox(groupSchools)
    local titleSchools = AC:CreateStyledText(groupSchools, "SPELL SCHOOLS", 13, AC.COLORS.PRIMARY, "OVERLAY", "")
    titleSchools:SetPoint("TOPLEFT", 20, -18)

    CreateCleanCheckbox(groupSchools, "Spell school colors for cast bars", -50, "spellSchoolColors")

    -- Group 2: POSITIONING
    local groupPos = CreateFrame("Frame", nil, parent)
    groupPos:SetPoint("TOP", groupSchools, "BOTTOM", 0, -12)
    groupPos:SetPoint("LEFT", groupSchools, "LEFT", 0, 0)
    groupPos:SetPoint("RIGHT", groupSchools, "RIGHT", 0, 0)
    groupPos:SetHeight(110)
    AC:HairlineGroupBox(groupPos)
    local titlePos = AC:CreateStyledText(groupPos, "POSITIONING", 13, AC.COLORS.PRIMARY, "OVERLAY", "")
    titlePos:SetPoint("TOPLEFT", 20, -18)

    -- Enhanced sliders with fine-tuned positioning for precise control
    AC:CreateEnhancedSliderRow(groupPos, "Horizontal", -50, "castBars.positioning.horizontal", "positioning_horizontal_fine")
    AC:CreateEnhancedSliderRow(groupPos, "Vertical", -80, "castBars.positioning.vertical", "positioning_vertical_fine")

    -- Group 3: SIZING
    local groupSize = CreateFrame("Frame", nil, parent)
    groupSize:SetPoint("TOP", groupPos, "BOTTOM", 0, -12)
    groupSize:SetPoint("LEFT", groupPos, "LEFT", 0, 0)
    groupSize:SetPoint("RIGHT", groupPos, "RIGHT", 0, 0)
    groupSize:SetHeight(140)
    AC:HairlineGroupBox(groupSize)
    local titleSize = AC:CreateStyledText(groupSize, "SIZING", 13, AC.COLORS.PRIMARY, "OVERLAY", "")
    titleSize:SetPoint("TOPLEFT", 20, -18)

    -- Enhanced sliders with 1-10 scale
    AC:CreateEnhancedSliderRow(groupSize, "Scale", -50, "castBars.sizing.scale", "sizing_scale")
    AC:CreateEnhancedSliderRow(groupSize, "Width", -80, "castBars.sizing.width", "sizing_width")
    AC:CreateEnhancedSliderRow(groupSize, "Height", -110, "castBars.sizing.height", "sizing_height")

    -- Group 4: SPELL ICONS
    local groupIcons = CreateFrame("Frame", nil, parent)
    groupIcons:SetPoint("TOP", groupSize, "BOTTOM", 0, -12)
    groupIcons:SetPoint("LEFT", groupPos, "LEFT", 0, 0)
    groupIcons:SetPoint("RIGHT", groupPos, "RIGHT", 0, 0)
    groupIcons:SetHeight(200)
    AC:HairlineGroupBox(groupIcons)
    local titleIcons = AC:CreateStyledText(groupIcons, "SPELL ICONS", 13, AC.COLORS.PRIMARY, "OVERLAY", "")
    titleIcons:SetPoint("TOPLEFT", 20, -18)

    -- Enhanced sliders with fine-tuned positioning for precise control
    AC:CreateEnhancedSliderRow(groupIcons, "Horizontal", -50, "castBars.spellIcons.positioning.horizontal", "positioning_horizontal_fine")
    AC:CreateEnhancedSliderRow(groupIcons, "Vertical", -80, "castBars.spellIcons.positioning.vertical", "positioning_vertical_fine")
    AC:CreateEnhancedSliderRow(groupIcons, "Scale", -110, "castBars.spellIcons.sizing.scale", "sizing_scale")
    CreateCleanCheckbox(groupIcons, "Enable", -140, "spellIcons.enabled")
end

-- Register the clean page
AC:RegisterPage("CastBars", CreateCleanCastBarsPage)
