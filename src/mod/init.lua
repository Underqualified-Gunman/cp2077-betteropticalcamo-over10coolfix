-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
k_trace = false
k_debug = false

local OpticalCamoManager = require("./core/OpticalCamoManager")

function GetOpticalCamoManager()
    return OpticalCamoManager
end

if (OpticalCamoManager ~= nil) then
    print("ERROR: OpticalCamoManager ~= nil")
end

registerForEvent("onTweak", function()
    print_debug("onTweak", "entering")
    OpticalCamoManager:ApplyTweaks()
    print_debug("onTweak", "exiting")
end)

registerForEvent("onInit", function()
    print_debug("onInit", "entering")
    OpticalCamoManager:Initialize()
    print_debug("onInit", "exiting")
end)

registerForEvent("onUpdate", function()
    print_trace("onUpdate", "entering")
    if (OpticalCamoManager ~= nil) then
        OpticalCamoManager:Update()
    end
    print_trace("onUpdate", "exiting")
end)

registerForEvent("onShutdown", function()
    print_debug("onShutdown", "entering")
    OpticalCamoManager:Shutdown()
    print_debug("onShutdown", "exiting")
end)

--------------------------------
--- Utils
--------------------------------
function file_exists(path)
    local f = io.open(path, "r")
    if (f ~= nil) then
        io.close(f)
        return true
    else
        return false
    end
end

function print_trace(tag, text)
    if (k_trace) then
        print("[BetterOpticalCamo]", "TRACE", tag..":", text)
    end
end

function print_debug(tag, text)
    if (k_debug) then
        print("[BetterOpticalCamo]", "DEBUG", tag..":", text)
    end
end

function print_info(tag, text)
    print("[BetterOpticalCamo]", "INFO", tag..":", text)
end

function print_error(tag, text)
    print("[BetterOpticalCamo]", "ERROR", tag..":", text)
end

function table_contains_value(table, needle)
    for _, value in pairs(table) do
        if (value == needle) then
            return true
        end
    end

    return false
end
