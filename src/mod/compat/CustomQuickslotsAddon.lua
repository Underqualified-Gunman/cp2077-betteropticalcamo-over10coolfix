-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local CustomQuickslotsAddon = {}
local LOGTAG = "CustomQuickslotsAddon"

local m_isPresent = false

CustomQuickslotsAddon.Initialize =
    function(this)
        if (GetSingleton("HotkeyItemController")["UseEquippedItem"] ~= nil) then
            print_info(LOGTAG, "Initializing 'Custom Quickslots' compatibility addon")
            m_isPresent = true

            ObserveBefore("HotkeyItemController", "UseEquippedItem",
                function(this)
                    print_trace(LOGTAG, "entering <HotkeyItemController::UseEquippedItem()>")

                    local opticalCamoManager = GetOpticalCamoManager()

                    if (opticalCamoManager:GetSettingsManager():GetValue("enableToggling")) then
                        local player = Game.GetPlayer()

                        if (this:IsOpticalCamoCyberwareAbility() and opticalCamoManager:IsOpticalCamoActive(player)) then
                            opticalCamoManager:DeactivateOpticalCamo(player)
                        end
                    end

                    print_trace(LOGTAG, "exiting <HotkeyItemController::UseEquippedItem()>")
                end)
        end
    end

CustomQuickslotsAddon.IsInstalled =
    function(this)
        return m_isPresent
    end

return CustomQuickslotsAddon
