-- =============================================================================
-- EditMode_ClassPacks.lua - Class Packs (TriBadges) Edit Mode Support
-- =============================================================================
local AddonName, _ns = ...
if type(_G.ArenaCore) ~= "table" then _G.ArenaCore = {} end
local AC = _G.ArenaCore

if not AC.EditMode then
    print("|cffFF0000ArenaCore ClassPacks Edit Mode:|r Edit Mode not loaded!")
    return
end

local EM = AC.EditMode

-- Register Class Packs as an Edit Mode group
C_Timer.After(0.5, function()
    if not EM.ELEMENT_GROUPS then
        print("|cffFF0000ArenaCore ClassPacks Edit Mode:|r ELEMENT_GROUPS not found!")
        return
    end

    -- Drag the first badge; the module re-anchors the whole trio from DB offsets
    EM.ELEMENT_GROUPS.classPacks = {
        dbPath = "classPacks",                 -- we special-case this in SavePosition
        refreshFunc = "RefreshClassPacksLayout",
        selector = function()
            local frames = {}
            local arenaFrames = AC.FrameManager and AC.FrameManager:GetFrames()
            if arenaFrames then
                for i = 1, 3 do
                    local f = arenaFrames[i]
                    -- Use the *first* badge as the drag handle for the group
                    if f and f.TriBadges and f.TriBadges[1] then
                        table.insert(frames, f.TriBadges[1])
                    end
                end
            end
            return frames
        end
    }

    -- Class Packs Edit Mode support loaded (debug removed for clean chat output)
end)
