-- Core/AurasWindow.lua --
-- Debuff/Buff Auras Configuration Window
local AC = _G.ArenaCore
if not AC then return end

local aurasWindow = nil
local aurasTestFrame = nil

-- Create the auras configuration window
local function CreateAurasWindow()
    if aurasWindow then return aurasWindow end
    
    -- Main window frame
    local window = CreateFrame("Frame", "ArenaCoreAurasWindow", UIParent)
    window:SetSize(450, 530)  -- Increased height for interrupt checkbox
    window:SetPoint("CENTER")
    window:SetClampedToScreen(true)
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    
    -- Background using ArenaCore styling - same dark color as slider track
    local bg = AC:CreateFlatTexture(window, "BACKGROUND", 1, {0.102, 0.102, 0.102, 1}, 1)
    bg:SetAllPoints()
    
    -- Border
    AC:AddWindowEdge(window, 1, 0)
    
    -- Header matching Dispel Configuration style
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetHeight(50)
    
    -- Header background (dark like main UI) - same dark color as slider track
    local headerBg = AC:CreateFlatTexture(header, "BACKGROUND", 1, {0.102, 0.102, 0.102, 1}, 1)
    headerBg:SetAllPoints()
    
    -- Purple accent line (hairline like main UI)
    local accent = AC:CreateFlatTexture(header, "OVERLAY", 3, AC.COLORS.PRIMARY, 1)
    accent:SetPoint("TOPLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", 0, 0)
    accent:SetHeight(2)
    
    -- Header border
    local hbLight = AC:CreateFlatTexture(header, "OVERLAY", 2, AC.COLORS.BORDER_LIGHT, 0.8)
    hbLight:SetPoint("BOTTOMLEFT", 0, 0)
    hbLight:SetPoint("BOTTOMRIGHT", 0, 0)
    hbLight:SetHeight(1)
    
    -- Title
    local title = AC:CreateStyledText(header, "Auras Configuration", 14, AC.COLORS.TEXT, "OVERLAY", "")
    title:SetPoint("LEFT", 15, 0)
    
    -- Close button (matching other pages)
    local closeBtn = AC:CreateTexturedButton(header, 36, 36, "", "button-close")
    closeBtn:SetPoint("RIGHT", -10, 0)
    closeBtn:SetScript("OnClick", function()
        window:Hide()
    end)
    local xText = AC:CreateStyledText(closeBtn, "×", 18, AC.COLORS.TEXT, "OVERLAY", "")
    xText:SetPoint("CENTER", 0, 0)
    
    -- Content area
    local content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -15)
    content:SetPoint("BOTTOMRIGHT", -15, 15)
    
    -- Get current settings
    local function GetSettings()
        local moreGoodiesDB = AC.DB and AC.DB.profile and AC.DB.profile.moreGoodies
        return (moreGoodiesDB and moreGoodiesDB.auras) or {}
    end
    
    -- Save setting function
    local function SaveSetting(key, value)
        if not AC.DB or not AC.DB.profile then return end
        if not AC.DB.profile.moreGoodies then
            AC.DB.profile.moreGoodies = {}
        end
        if not AC.DB.profile.moreGoodies.auras then
            AC.DB.profile.moreGoodies.auras = {}
        end
        AC.DB.profile.moreGoodies.auras[key] = value
    end
    
    local y = -20
    
    -- Enable checkbox
    local enableLabel = AC:CreateStyledText(content, "Enable Aura Tracking", 12, AC.COLORS.TEXT_2, "OVERLAY", "")
    enableLabel:SetPoint("TOPLEFT", 20, y)
    
    local enableCheckbox = AC:CreateFlatCheckbox(content, 20, GetSettings().enabled ~= false, function(value)
        SaveSetting("enabled", value)
        if value then
            print("|cff8B45FFArena Core:|r Aura tracking enabled")
        else
            print("|cff8B45FFArena Core:|r Aura tracking disabled")
            -- Hide test frame if it exists
            if aurasTestFrame then
                aurasTestFrame:Hide()
            end
        end
    end)
    enableCheckbox:SetPoint("TOPRIGHT", -25, y)
    
    y = y - 30
    
    -- Hide Tooltips checkbox
    local tooltipLabel = AC:CreateStyledText(content, "Hide Tooltips", 12, AC.COLORS.TEXT_2, "OVERLAY", "")
    tooltipLabel:SetPoint("TOPLEFT", 20, y)
    
    local tooltipCheckbox = AC:CreateFlatCheckbox(content, 20, GetSettings().hideTooltips == true, function(value)
        SaveSetting("hideTooltips", value)
        if value then
            print("|cff8B45FFArena Core:|r Aura tooltips hidden")
        else
            print("|cff8B45FFArena Core:|r Aura tooltips enabled")
        end
        -- Refresh auras to apply tooltip setting
        if AC.AuraTracker then
            AC.AuraTracker:RefreshAllAuras()
        end
    end)
    tooltipCheckbox:SetPoint("TOPRIGHT", -25, y)
    
    y = y - 50
    
    -- Category checkboxes
    local categoryLabel = AC:CreateStyledText(content, "Aura Categories", 13, AC.COLORS.PRIMARY, "OVERLAY", "")
    categoryLabel:SetPoint("TOPLEFT", 20, y)
    
    y = y - 30
    
    -- Interrupts checkbox (HIGHEST PRIORITY - shows kicks/silences)
    local intLabel = AC:CreateStyledText(content, "Interrupts (Kicks/Silences)", 12, AC.COLORS.TEXT_2, "OVERLAY", "")
    intLabel:SetPoint("TOPLEFT", 20, y)
    
    local intCheckbox = AC:CreateFlatCheckbox(content, 20, GetSettings().interrupt ~= false, function(value)
        SaveSetting("interrupt", value)
        if AC.AuraTracker then
            AC.AuraTracker:RefreshAllAuras()
        end
    end)
    intCheckbox:SetPoint("TOPRIGHT", -25, y)
    
    y = y - 30
    
    -- Crowd Control checkbox
    local ccLabel = AC:CreateStyledText(content, "Crowd Control", 12, AC.COLORS.TEXT_2, "OVERLAY", "")
    ccLabel:SetPoint("TOPLEFT", 20, y)
    
    local ccCheckbox = AC:CreateFlatCheckbox(content, 20, GetSettings().crowdControl ~= false, function(value)
        SaveSetting("crowdControl", value)
        if AC.AuraTracker then
            AC.AuraTracker:RefreshAllAuras()
        end
    end)
    ccCheckbox:SetPoint("TOPRIGHT", -25, y)
    
    y = y - 30
    
    -- Defensive checkbox
    local defLabel = AC:CreateStyledText(content, "Defensive Cooldowns", 12, AC.COLORS.TEXT_2, "OVERLAY", "")
    defLabel:SetPoint("TOPLEFT", 20, y)
    
    local defCheckbox = AC:CreateFlatCheckbox(content, 20, GetSettings().defensive ~= false, function(value)
        SaveSetting("defensive", value)
        if AC.AuraTracker then
            AC.AuraTracker:RefreshAllAuras()
        end
    end)
    defCheckbox:SetPoint("TOPRIGHT", -25, y)
    
    y = y - 30
    
    -- Utility checkbox
    local utilLabel = AC:CreateStyledText(content, "Utility Spells", 12, AC.COLORS.TEXT_2, "OVERLAY", "")
    utilLabel:SetPoint("TOPLEFT", 20, y)
    
    local utilCheckbox = AC:CreateFlatCheckbox(content, 20, GetSettings().utility ~= false, function(value)
        SaveSetting("utility", value)
        if AC.AuraTracker then
            AC.AuraTracker:RefreshAllAuras()
        end
    end)
    utilCheckbox:SetPoint("TOPRIGHT", -25, y)
    
    y = y - 40
    
    -- Test and Hide buttons (matching other pages)
    local testBtn = AC:CreateTexturedButton(content, 80, 32, "TEST", "button-test")
    testBtn:SetPoint("TOPLEFT", 20, y)
    testBtn:SetScript("OnClick", function()
        if AC.TestAuraTracking then
            AC:TestAuraTracking()
            print("|cff8B45FFArena Core:|r Testing aura tracking...")
        else
            print("|cff8B45FFArena Core:|r Test aura functionality not yet implemented.")
        end
    end)
    
    local hideBtn = AC:CreateTexturedButton(content, 80, 32, "HIDE", "button-hide")
    hideBtn:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
    hideBtn:SetScript("OnClick", function()
        if AC.HideAuraTracking then
            AC:HideAuraTracking()
        end
    end)
    
    y = y - 35
    
    -- Description text
    local desc = AC:CreateStyledText(content, "Tracks enemy debuffs and buffs by replacing the class icon with the highest priority aura. Shows crowd control, defensive cooldowns, and utility spells. Only one aura displays at a time - the most important one. Use Test button to see sample auras in action.", 10, AC.COLORS.TEXT_MUTED, "OVERLAY", "")
    desc:SetPoint("TOPLEFT", 20, y)
    desc:SetPoint("TOPRIGHT", -20, y)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    
    aurasWindow = window
    return window
end

-- Show the auras window
function AC:ShowAurasWindow()
    local window = CreateAurasWindow()
    if window then
        window:Show()
    end
end

-- Test aura tracking function
function AC:TestAuraTracking()
    if AC.AuraTracker then
        AC.AuraTracker:EnableTestMode()
    else
        -- Aura tracker not loaded yet
    end
end

-- Hide aura tracking test
function AC:HideAuraTracking()
    if AC.AuraTracker then
        AC.AuraTracker:DisableTestMode()
    end
end
