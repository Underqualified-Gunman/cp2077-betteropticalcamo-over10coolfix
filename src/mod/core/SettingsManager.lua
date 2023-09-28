-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local SettingsManager = {}

local k_defaultSettings = {
    enableToggling = true,
    opticalCamoChargesDecayRateModifier = 1,
    opticalCamoChargesRegenRateModifier = 1,
    opticalCamoChargesUseMinimalDecayRate = false,
    opticalCamoRechargeImmediate = false,
    combatCloak = false,
    combatCloakDelay = 1.5
}

local m_activeSettings = {}
local m_pendingSettings = {}

function createSettingsMenu()
    local nativeSettings = GetMod("nativeSettings")
    if (nativeSettings == nil) then
        return
    end

    local localizationManager = GetOpticalCamoManager():GetLocalizationManager()

    if not nativeSettings.pathExists("/BetterOpticalCamo") then
        -- nativeSettings.addTab(path, label, optionalClosedCallback)
        nativeSettings.addTab(
            "/BetterOpticalCamo",
            localizationManager:GetTranslation("settings.label"),
            function(state)
                local needsReload = willNeedLoadLastCheckpoint()

                SettingsManager:ApplyPendingSettings()
                SettingsManager:WriteToFile()

                if (needsReload) then
                    -- Game.GetSettingsSystem():RequestLoadLastCheckpointDialog()
                end
            end
        )
    end

    if nativeSettings.pathExists("/BetterOpticalCamo/Core") then
        nativeSettings.removeSubcategory("/BetterOpticalCamo/Core")
    end

    nativeSettings.addSubcategory(
        "/BetterOpticalCamo/Core",
        localizationManager:GetTranslation("settings.subcategory.label")
    )

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        localizationManager:GetTranslation("settings.enableToggling.label"),
        localizationManager:GetTranslation("settings.enableToggling.description"),
        m_activeSettings.enableToggling,
        k_defaultSettings.enableToggling,
        function(state)
            m_pendingSettings.enableToggling = state
        end)

    -- nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addRangeFloat(
        "/BetterOpticalCamo/Core",
        localizationManager:GetTranslation("settings.opticalCamoChargesDecayRateModifier.label"),
        localizationManager:GetTranslation("settings.opticalCamoChargesDecayRateModifier.description"),
        .1,
        10,
        0.1,
        "%.1f",
        m_activeSettings.opticalCamoChargesDecayRateModifier,
        k_defaultSettings.opticalCamoChargesDecayRateModifier,
        function(state)
            m_pendingSettings.opticalCamoChargesDecayRateModifier = state
        end)

    -- nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addRangeFloat(
        "/BetterOpticalCamo/Core",
        localizationManager:GetTranslation("settings.opticalCamoChargesRegenRateModifier.label"),
        localizationManager:GetTranslation("settings.opticalCamoChargesRegenRateModifier.description"),
        .1,
        10,
        0.1,
        "%.1f",
        m_activeSettings.opticalCamoChargesRegenRateModifier,
        k_defaultSettings.opticalCamoChargesRegenRateModifier,
        function(state)
            m_pendingSettings.opticalCamoChargesRegenRateModifier = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        localizationManager:GetTranslation("settings.opticalCamoChargesUseMinimalDecayRate.label"),
        localizationManager:GetTranslation("settings.opticalCamoChargesUseMinimalDecayRate.description"),
        m_activeSettings.opticalCamoChargesUseMinimalDecayRate,
        k_defaultSettings.opticalCamoChargesUseMinimalDecayRate,
        function(state)
            m_pendingSettings.opticalCamoChargesUseMinimalDecayRate = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        localizationManager:GetTranslation("settings.opticalCamoRechargeImmediate.label"),
        localizationManager:GetTranslation("settings.opticalCamoRechargeImmediate.description"),
        m_activeSettings.opticalCamoRechargeImmediate,
        k_defaultSettings.opticalCamoRechargeImmediate,
        function(state)
            m_pendingSettings.opticalCamoRechargeImmediate = state
        end)

    -- nativeSettings.addSwitch(path, label, desc, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addSwitch(
        "/BetterOpticalCamo/Core",
        localizationManager:GetTranslation("settings.combatCloak.label"),
        localizationManager:GetTranslation("settings.combatCloak.description"),
        m_activeSettings.combatCloak,
        k_defaultSettings.combatCloak,
        function(state)
            m_pendingSettings.combatCloak = state
        end)

    -- nativeSettings.addRangeFloat(path, label, desc, min, max, step, format, currentValue, defaultValue, callback, optionalIndex)
    nativeSettings.addRangeFloat(
        "/BetterOpticalCamo/Core",
        localizationManager:GetTranslation("settings.combatCloakDelay.label"),
        localizationManager:GetTranslation("settings.combatCloakDelay.description"),
        0,
        10,
        0.1,
        "%.1f",
        m_activeSettings.combatCloakDelay,
        k_defaultSettings.combatCloakDelay,
        function(state)
            m_pendingSettings.combatCloakDelay = state
        end)

    nativeSettings.refresh()
end

function willNeedLoadLastCheckpoint()
    return false
end

SettingsManager.Initialize =
    function(this)
        SettingsManager:ApplyDefaultSettings()
        SettingsManager:LoadFromFile()
        SettingsManager:WriteToFile()
    end

SettingsManager.PostInitialize =
    function(this)
        createSettingsMenu()
    end

SettingsManager.GetValue =
    function(this, name)
        return m_activeSettings[name]
    end

SettingsManager.SetPendingValue =
    function(this, name, value)
        m_pendingSettings[name] = value
    end

SettingsManager.ApplyDefaultSettings =
    function(this)
        for name, value in pairs(k_defaultSettings) do
            m_activeSettings[name] = value
            m_pendingSettings[name] = value
        end
    end

SettingsManager.ApplyPendingSettings =
    function(this)
        for name, value in pairs(m_pendingSettings) do
            m_activeSettings[name] = value
        end

        GetOpticalCamoManager():ApplySettings(Game.GetPlayer())
    end

SettingsManager.LoadFromFile =
    function(this)
        local file = io.open("settings.json", "r")
        if file ~= nil then
            local contents = file:read("*a")
            local validJson, savedSettings = pcall(function() return json.decode(contents) end)

            file:close()

            if validJson then
                for name, value in pairs(savedSettings) do
                    if k_defaultSettings[name] ~= nil then
                        m_activeSettings[name] = value
                        m_pendingSettings[name] = value
                    end
                end
            end
        end
    end

SettingsManager.WriteToFile =
    function(this)
        local validJson, contents = pcall(function() return json.encode(m_activeSettings) end)

        if validJson and contents ~= nil then
            local file = io.open("settings.json", "w+")
            file:write(contents)
            file:close()
        end
    end

return SettingsManager
