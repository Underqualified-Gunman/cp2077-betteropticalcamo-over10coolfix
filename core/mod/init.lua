-- Better Optical Camo
-- Copyright (c) 2022 Lukas Berger
-- MIT License (See LICENSE.md)
local defaultOpticalCamoCooldown = 0.5
local defaultOpticalCamoDurationIsInfinite = false
local defaultOpticalCamoDuration = 45
local defaultEnableToggling = true
local defaultDeactivateOnVehicleEnter = false

local GameUI = require('lib/GameUI')

local settings = {
    opticalCamoCooldown = defaultOpticalCamoCooldown,
    opticalCamoDurationIsInfinite = defaultOpticalCamoDurationIsInfinite,
    opticalCamoDuration = defaultOpticalCamoDuration,
    enableToggling = defaultEnableToggling,
    deactivateOnVehicleEnter = defaultDeactivateOnVehicleEnter
}

local pendingSettings = {
    opticalCamoCooldown = defaultOpticalCamoCooldown,
    opticalCamoDurationIsInfinite = defaultOpticalCamoDurationIsInfinite,
    opticalCamoDuration = defaultOpticalCamoDuration,
    enableToggling = defaultEnableToggling,
    deactivateOnVehicleEnter = defaultDeactivateOnVehicleEnter
}

registerForEvent('onInit', function()
    loadSettingsFromFile()
    writeSettingsToFile()
    applySettings()
    createSettingsMenu()

    -- observe for playing mount a vehicle
    GameUI.Listen('VehicleEnter', function()
        local player = Game.GetPlayer()

        if (settings.deactivateOnVehicleEnter) then
            deactivateOpticalCamo(player)
        end
    end)

    -- toggle the cloak by pressing the combat gadget button again
    Observe('PlayerPuppet', 'OnAction', function(_, action)
        local player = Game.GetPlayer()

        local actionName = Game.NameToString(ListenerAction.GetName(action))
        local actionType = ListenerAction.GetType(action).value

        if (settings.enableToggling and actionName == 'UseCombatGadget' and actionType == 'BUTTON_PRESSED' and isOpticalCamoActive(player)) then
            deactivateOpticalCamo(player)
        end
    end)

    -- compatibility with "Custom Quickslots" for toggling the cloak if selected
    ObserveBefore('HotkeyItemController', 'UseEquippedItem', function(this)
        local player = Game.GetPlayer()

        if (settings.enableToggling and this:IsOpticalCamoCyberwareAbility() and isOpticalCamoActive(player)) then
            deactivateOpticalCamo(player)
        end
    end)

    print('[BetterOpticalCamo]', 'initialization done!')
end)

function applySettings()
    -- set cloak cooldown duration
    setFlatAndUpdate('BaseStatusEffect.OpticalCamoCooldown_inline1.value', settings.opticalCamoCooldown)
    setFlatAndUpdate('BaseStatusEffect.OpticalCamoLegendaryCooldown_inline1.value', settings.opticalCamoCooldown)

    -- set cloak duration
    if (settings.opticalCamoDurationIsInfinite) then
        setOpticalCamoDuration(-1)
    else
        setOpticalCamoDuration(settings.opticalCamoDuration)
    end
end

function setOpticalCamoDuration(duration)
    setFlatAndUpdate('BaseStatusEffect.OpticalCamoPlayerBuffEpic_inline1.value', duration)
    setFlatAndUpdate('BaseStatusEffect.OpticalCamoPlayerBuffRare_inline1.value', duration)
    setFlatAndUpdate('BaseStatusEffect.OpticalCamoPlayerBuffLegendary_inline1.value', duration)
end

function deactivateOpticalCamo(entity)
    local entityID = entity:GetEntityID()
    local statusEffectSystem = Game.GetStatusEffectSystem()

    statusEffectSystem:RemoveStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.Cloaked"))
    statusEffectSystem:RemoveStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.OpticalCamoPlayerBuffBase"))
    statusEffectSystem:RemoveStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.OpticalCamoPlayerBuffRare"))
    statusEffectSystem:RemoveStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.OpticalCamoPlayerBuffEpic"))
    statusEffectSystem:RemoveStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.OpticalCamoPlayerBuffLegendary"))
end

function isOpticalCamoActive(entity)
    local entityID = entity:GetEntityID()
    local statusEffectSystem = Game.GetStatusEffectSystem()

    return statusEffectSystem:HasStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.Cloaked")) or
        statusEffectSystem:HasStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.OpticalCamoPlayerBuffBase")) or
        statusEffectSystem:HasStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.OpticalCamoPlayerBuffRare")) or
        statusEffectSystem:HasStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.OpticalCamoPlayerBuffEpic")) or
        statusEffectSystem:HasStatusEffect(entityID, TweakDBID.new("BaseStatusEffect.OpticalCamoPlayerBuffLegendary"))
end

--------------------------------
--- Settings
--------------------------------
function createSettingsMenu()
    local nativeSettings = GetMod("nativeSettings")

    if not nativeSettings.pathExists("/BetterOpticalCamo") then
        -- nativeSettings.addTab(path, label, optionalClosedCallback)
        nativeSettings.addTab(
            "/BetterOpticalCamo",
            "Better Optical Camo",
            function(state)
                local needsReload = willNeedLoadLastCheckpoint()

                applyPendingSettings()
                writeSettingsToFile()

                if (needsReload) then
                    -- Game.GetSettingsSystem():RequestLoadLastCheckpointDialog()
                end
            end
        )
    end

    if nativeSettings.pathExists("/BetterOpticalCamo/Core") then
        nativeSettings.removeSubcategory("/BetterOpticalCamo/Core")
    end

    nativeSettings.addSubcategory("/BetterOpticalCamo/Core", "Better Optical Camo")

    -- nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addRangeFloat(
        "/BetterOpticalCamo/Core",
        "Optical Camo Cooldown",
        "Cooldown of the optical camo after the effect has run out (Reload required)",
        0.5,
        30,
        0.1,
        "%.1f",
        settings.opticalCamoCooldown,
        defaultOpticalCamoCooldown,
        function(state)
            pendingSettings.opticalCamoCooldown = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        "Infinite Optical Camo Duration",
        "Allow the optical camo to stay active indefinitely (Overrides \"Optical Camo Duration\"; Reload required)",
        settings.opticalCamoDurationIsInfinite,
        defaultOpticalCamoDurationIsInfinite,
        function(state)
            pendingSettings.opticalCamoDurationIsInfinite = state
        end)

        -- nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addRangeFloat(
        "/BetterOpticalCamo/Core",
        "Optical Camo Duration",
        "Duration of the optical camo effect (Reload required)",
        0.5,
        120,
        1,
        "%.0f",
        settings.opticalCamoDuration,
        defaultOpticalCamoDuration,
        function(state)
            pendingSettings.opticalCamoDuration = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        "Enable Toggling",
        "Allow player to toggle the optical camo",
        settings.enableToggling,
        defaultEnableToggling,
        function(state)
            pendingSettings.enableToggling = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    --nativeSettings.addSwitch(
    --    "/BetterOpticalCamo/Core",
    --    "Deactivate when entering vehicle (Bugged)",
    --    "Automatically deactivate the optical camo when entering a vehicle (Bugged)",
    --    settings.deactivateOnVehicleEnter,
    --    defaultDeactivateOnVehicleEnter,
    --    function(state)
    --        pendingSettings.deactivateOnVehicleEnter = state
    --    end)

    nativeSettings.refresh()
end

function willNeedLoadLastCheckpoint()
    if not (settings.opticalCamoCooldown == pendingSettings.opticalCamoCooldown) then
        return true
    end
    if not (settings.opticalCamoDurationIsInfinite == pendingSettings.opticalCamoDurationIsInfinite) then
        return true
    end
    if not (settings.opticalCamoDuration == pendingSettings.opticalCamoDuration) then
        return true
    end
    return false
end

function applyPendingSettings()
    settings.opticalCamoCooldown = pendingSettings.opticalCamoCooldown
    settings.opticalCamoDurationIsInfinite = pendingSettings.opticalCamoDurationIsInfinite
    settings.opticalCamoDuration = pendingSettings.opticalCamoDuration
    settings.enableToggling = pendingSettings.enableToggling
    settings.deactivateOnVehicleEnter = pendingSettings.deactivateOnVehicleEnter

    applySettings()
end

function loadSettingsFromFile()
    local file = io.open('settings.json', 'r')
    if file ~= nil then
        local contents = file:read("*a")
        local validJson, savedSettings = pcall(function() return json.decode(contents) end)

        file:close()

        if validJson then
            for key, _ in pairs(settings) do
                if savedSettings[key] ~= nil then
                    settings[key] = savedSettings[key]
                end
            end
        end
    end
end

function writeSettingsToFile()
    local validJson, contents = pcall(function() return json.encode(settings) end)

    if validJson and contents ~= nil then
        local file = io.open("settings.json", "w+")
        file:write(contents)
        file:close()
    end
end

--------------------------------
--- Utils
--------------------------------
function setFlatAndUpdate(name, value)
    TweakDB:SetFlat(name, value)
    TweakDB:Update(name)
end
