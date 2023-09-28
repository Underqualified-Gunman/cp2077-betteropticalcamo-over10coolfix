-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local OpticalCamoManager = {}
local LOGTAG = "OpticalCamoManager"

local m_localizationManager = require("./core/LocalizationManager")
local m_redscriptExtension = require("./core/RedscriptExtension")
local m_settingsManager = require("./core/SettingsManager")

local m_observers = {}
local m_compatAddons = {}

local m_playerStatsModifiers = {}
local m_playerExitCombatDelayIDs = {}

function registerPlayerStatsModifier(player, statType, modifierType, value)
    local playerID = player:GetEntityID()
    local modifier = Game.CreateStatModifier(statType, modifierType, value)

    if (m_playerStatsModifiers[statType] ~= nil) then
        print_debug(LOGTAG, "removing modifier '"..statType.."'")
        Game.GetStatsSystem():RemoveModifier(playerID, m_playerStatsModifiers[statType])
    end

    if (k_debug) then
        print("[BetterOpticalCamo]", "DEBUG", LOGTAG, "adding modifier '"..statType.."': statType=<", statType, ">, modifierType=<", modifierType, ">, value=<", value, ">")
    end

    Game.GetStatsSystem():AddModifier(playerID, modifier)
    m_playerStatsModifiers[statType] = modifier
end

function unregisterPlayerStatsModifier(player)
    local playerID = player:GetEntityID()

    for name, modifier in pairs(m_playerStatsModifiers) do
        print_debug(LOGTAG, "removing modifier '"..name.."'")

        Game.GetStatsSystem():RemoveModifier(playerID, modifier)
        m_playerStatsModifiers[name] = nil
    end
end

function dumpPlayerStat(player, statType)
    local playerID = player:GetEntityID()
    local statsSystem = Game.GetStatsSystem()

    print("[BetterOpticalCamo]", "DEBUG", LOGTAG, statType.."=<", statsSystem:GetStatValue(playerID, statType), ">")
end

function clearDelayedPlayerExitCombatEvents(player)
    local delaySystem = Game.GetDelaySystem()

    for _, delayID in pairs(m_playerExitCombatDelayIDs) do
        print_debug(LOGTAG, "cancelling delayed player ExitCombatOnOpticalCamoActivatedEvent")
        delaySystem:CancelDelay(delayID)
    end

    m_playerExitCombatDelayIDs = {}
end

function loadClassListFile(path)
    local file = io.open(path, "r")
    if file ~= nil then
        local contents = file:read("*a")
        local validJson, classList = pcall(function() return json.decode(contents) end)

        file:close()

        if validJson then
            return classList
        end
    end

    return {}
end

OpticalCamoManager.ApplyTweaks =
    function(this)
        TweakDB:SetFlat("BaseStatusEffect.OpticalCamoPlayerBuffRare_inline1.value", -1)
        TweakDB:SetFlat("BaseStatusEffect.OpticalCamoPlayerBuffEpic_inline1.value", -1)
        TweakDB:SetFlat("BaseStatusEffect.OpticalCamoPlayerBuffLegendary_inline1.value", -1)
    end

OpticalCamoManager.Initialize =
    function(this)
        local player = Game.GetPlayer()

        m_localizationManager:Initialize()
        m_redscriptExtension:Initialize()
        m_settingsManager:Initialize()

        if (player ~= nil) then
            this:DumpPlayerStats(player)
            this:ApplySettings(player)
            this:DumpPlayerStats(player)
        end

        m_settingsManager:PostInitialize()

        -- initialize observers
        local observerClassList = loadClassListFile("./observers/index.json")
        for _, observerClassName in pairs(observerClassList) do
            print_debug(LOGTAG, "Loading observer '"..observerClassName.."'")

            local observer = require("./observers/"..observerClassName)

            if (observer["Initialize"] ~= nil) then
                observer:Initialize()
            end

            m_observers[observerClassName] = observer
        end

        -- initialize compatibility-addons
        local compatAddonClassList = loadClassListFile("./compat/index.json")
        for _, compatAddonClassName in pairs(compatAddonClassList) do
            print_debug(LOGTAG, "Loading compatibility addon '"..compatAddonClassName.."'")

            local compatAddon = require("./compat/"..compatAddonClassName)

            if (compatAddon["Initialize"] ~= nil) then
                compatAddon:Initialize()
            end

            m_compatAddons[compatAddonClassName] = compatAddon
        end
    end

OpticalCamoManager.Update =
    function(this)
        if (not m_settingsManager:GetValue("opticalCamoChargesUseMinimalDecayRate")) then
            local player = Game.GetPlayer()

            if (player ~= nil) then
                local statPoolsSystem = Game.GetStatPoolsSystem()
                local opticalCamoCharges = statPoolsSystem:GetStatPoolValue(player:GetEntityID(), "OpticalCamoCharges")

                if ((opticalCamoCharges < 0.01) and (not m_settingsManager:GetValue("opticalCamoKeepActiveAfterDepletion"))) then
                    this:DeactivateOpticalCamo(player)
                end
            end
        end

        for _, observer in pairs(m_observers) do
            if (observer["Update"] ~= nil) then
                observer:Update()
            end
        end

        for _, compatAddon in pairs(m_compatAddons) do
            if (compatAddon["Update"] ~= nil) then
                compatAddon:Update()
            end
        end
    end

OpticalCamoManager.Shutdown =
    function(this)
        local player = Game.GetPlayer()

        if (player ~= nil) then
            if (this:IsOpticalCamoActive(player)) then
                this:SetPlayerVisible(this)
                this:DeactivateOpticalCamo(this)
            end

            unregisterPlayerStatsModifier(player)
        end

        clearDelayedPlayerExitCombatEvents()

        for _, observer in pairs(m_observers) do
            if (observer["Shutdown"] ~= nil) then
                observer:Shutdown()
            end
        end

        for _, compatAddon in pairs(m_compatAddons) do
            if (compatAddon["Shutdown"] ~= nil) then
                compatAddon:Shutdown()
            end
        end
    end

OpticalCamoManager.GetSettingsManager =
    function(this)
        return m_settingsManager
    end

OpticalCamoManager.GetLocalizationManager =
    function(this)
        return m_localizationManager
    end

OpticalCamoManager.DeactivateOpticalCamo =
    function(this, player)
        local playerID = player:GetEntityID()
        local statusEffectSystem = Game.GetStatusEffectSystem()

        statusEffectSystem:RemoveStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffRare")
        statusEffectSystem:RemoveStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffEpic")
        statusEffectSystem:RemoveStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffLegendary")
    end

OpticalCamoManager.IsOpticalCamoActive =
    function(this, player)
        local playerID = player:GetEntityID()
        local statusEffectSystem = Game.GetStatusEffectSystem()

        return statusEffectSystem:HasStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffRare") or
            statusEffectSystem:HasStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffEpic") or
            statusEffectSystem:HasStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffLegendary")
    end

OpticalCamoManager.ApplySettings =
    function(this, player)
        this:DumpPlayerStats(player)

        if (m_settingsManager:GetValue("opticalCamoChargesUseMinimalDecayRate")) then
            registerPlayerStatsModifier(player, "OpticalCamoChargesDecayRate", "Multiplier", 0.025)
        else
            registerPlayerStatsModifier(player, "OpticalCamoChargesDecayRate", "Multiplier", m_settingsManager:GetValue("opticalCamoChargesDecayRateModifier"))
            registerPlayerStatsModifier(player, "OpticalCamoChargesRegenRate", "Multiplier", m_settingsManager:GetValue("opticalCamoChargesRegenRateModifier"))
        end

        if (m_settingsManager:GetValue("opticalCamoRechargeImmediate")) then
            registerPlayerStatsModifier(player, "OpticalCamoRechargeDuration", "Multiplier", 0.01)
        else
            registerPlayerStatsModifier(player, "OpticalCamoRechargeDuration", "Multiplier", (1 / m_settingsManager:GetValue("opticalCamoChargesRegenRateModifier")))
        end

        this:DumpPlayerStats(player)
    end

OpticalCamoManager.SetPlayerInvisible =
    function(this, player)
        player:SetInvisible(true)
    end

OpticalCamoManager.SetPlayerVisible =
    function(this, player)
        player:SetInvisible(false)
    end

OpticalCamoManager.MakePlayerExitCombat =
    function(this, player)
        local delaySystem = Game.GetDelaySystem()
        local hostileTargets = player:GetTargetTrackerComponent():GetHostileThreats(false)

        for _, e in pairs(hostileTargets) do
            local hostileTarget = e.entity

            vanishEvt = NewObject("ExitCombatOnOpticalCamoActivatedEvent")
            vanishEvt.npc = hostileTarget

            m_playerExitCombatDelayIDs[hostileTarget:GetEntityID()] =
                delaySystem:DelayEvent(
                    player,
                    vanishEvt,
                    m_settingsManager:GetValue("combatCloakDelay"),
                    true -- isAffectedByTimeDilation
                )

            hostileTarget:GetTargetTrackerComponent():DeactivateThreat(player)
        end
    end

OpticalCamoManager.UnregisterPlayerStatsModifier =
    function(this, player)
        unregisterPlayerStatsModifier(player)
    end

OpticalCamoManager.ClearDelayedPlayerExitCombatEvents =
    function(this)
        clearDelayedPlayerExitCombatEvents()
    end

OpticalCamoManager.DumpPlayerStats =
    function(this, player)
        if (k_debug and (player ~= nil)) then 
            dumpPlayerStat(player, "OpticalCamoCharges")
            dumpPlayerStat(player, "OpticalCamoChargesDecayRate")
            dumpPlayerStat(player, "OpticalCamoChargesDecayRateMult")
            dumpPlayerStat(player, "OpticalCamoChargesDecayStartDelay")
            dumpPlayerStat(player, "OpticalCamoChargesDelayOnChange")
            dumpPlayerStat(player, "OpticalCamoChargesRegenBegins")
            dumpPlayerStat(player, "OpticalCamoChargesRegenEnabled")
            dumpPlayerStat(player, "OpticalCamoChargesRegenEnds")
            dumpPlayerStat(player, "OpticalCamoChargesRegenRate")
            dumpPlayerStat(player, "OpticalCamoDuration")
            dumpPlayerStat(player, "OpticalCamoEmptyStat")
            dumpPlayerStat(player, "OpticalCamoIsActive")
            dumpPlayerStat(player, "OpticalCamoRechargeDuration")
        end
    end

return OpticalCamoManager
