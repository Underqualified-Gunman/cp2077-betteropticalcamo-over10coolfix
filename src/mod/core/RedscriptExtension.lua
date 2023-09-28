-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local RedscriptExtension = {}
local LOGTAG = "RedscriptExtension"

local k_scriptableSystem = "BetterOpticalCamo.BetterOpticalCamoSystem"

local m_isInstalled = false

RedscriptExtension.Initialize =
    function(this)
        if (GetSingleton(k_scriptableSystem) ~= nil) then
            print_info(LOGTAG, "extension found")
            m_isInstalled = true

            Override(k_scriptableSystem, "GetSettings",
                function(this, name)
                    return GetOpticalCamoManager():GetSettingsManager():GetValue(name)
                end)

            Override(k_scriptableSystem, "ActivateOpticalCamo",
                function(this, player)
                    return GetOpticalCamoManager():ActivateOpticalCamo(player)
                end)

            Override(k_scriptableSystem, "DeactivateOpticalCamo",
                function(this, player)
                    return GetOpticalCamoManager():DeactivateOpticalCamo(player)
                end)

            Override(k_scriptableSystem, "IsOpticalCamoActive",
                function(this, player)
                    return GetOpticalCamoManager():IsOpticalCamoActive(player)
                end)

            Override(k_scriptableSystem, "GetOpticalCamoCharges",
                function(this, player)
                    return GetOpticalCamoManager():GetOpticalCamoCharges(player)
                end)
        else
            print_info(LOGTAG, "extension not found")
        end
    end

RedscriptExtension.IsInstalled =
    function(this)
        return m_isInstalled
    end

return RedscriptExtension
