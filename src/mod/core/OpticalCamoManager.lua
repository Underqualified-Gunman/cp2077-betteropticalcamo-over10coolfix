-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local OpticalCamoManager = {}
local LOGTAG = "OpticalCamoManager"

local m_localizationManager = require("./core/LocalizationManager")
local m_redscriptExtension = require("./core/RedscriptExtension")
local m_settingsManager = require("./core/SettingsManager")

local k_opticalCamoItemToStatusEffectName = {
    ["Items.AdvancedOpticalCamoCommon"]            = "BaseStatusEffect.OpticalCamoPlayerBuffCommon",
    ["Items.AdvancedOpticalCamoUncommon"]          = "BaseStatusEffect.OpticalCamoPlayerBuffUncommon",
    ["Items.AdvancedOpticalCamoUncommonPlus"]      = "BaseStatusEffect.OpticalCamoPlayerBuffUncommon",
    ["Items.AdvancedOpticalCamoRare"]              = "BaseStatusEffect.OpticalCamoPlayerBuffRare",
    ["Items.AdvancedOpticalCamoRarePlus"]          = "BaseStatusEffect.OpticalCamoPlayerBuffRare",
    ["Items.AdvancedOpticalCamoEpic"]              = "BaseStatusEffect.OpticalCamoPlayerBuffEpic",
    ["Items.AdvancedOpticalCamoEpicPlus"]          = "BaseStatusEffect.OpticalCamoPlayerBuffEpic",
    ["Items.AdvancedOpticalCamoLegendary"]         = "BaseStatusEffect.OpticalCamoPlayerBuffLegendary",
    ["Items.AdvancedOpticalCamoLegendaryPlus"]     = "BaseStatusEffect.OpticalCamoPlayerBuffLegendary",
    ["Items.AdvancedOpticalCamoLegendaryPlusPlus"] = "BaseStatusEffect.OpticalCamoPlayerBuffLegendary"
}

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

function hasPlayerItemEquipped(player, itemName)
    local transactionSystem = Game.GetTransactionSystem()
    local equipmentSystem = Game.GetScriptableSystemsContainer():Get("EquipmentSystem")

    local equipmentPlayerData = equipmentSystem:GetPlayerData(player)
    if (equipmentPlayerData == nil) then
        return false
    end

    return (equipmentPlayerData:GetActiveCyberware().id == ItemID.FromTDBID(itemName).id)
end

OpticalCamoManager.ApplyTweaks =
    function(this)
        TweakDB:SetFlat("BaseStatusEffect.OpticalCamoPlayerBuffCommon_inline1.value", -1)
        TweakDB:SetFlat("BaseStatusEffect.OpticalCamoPlayerBuffUncommon_inline1.value", -1)
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
            if (observer ~= nil) then
                m_observers[observerClassName] = observer

                if (observer["Initialize"] ~= nil) then
                    observer:Initialize()
                end
            else
                print_error(LOGTAG, "Failed to load observer '"..observerClassName.."'")
            end
        end

        -- initialize compatibility-addons
        local compatAddonClassList = loadClassListFile("./compat/index.json")
        for _, compatAddonClassName in pairs(compatAddonClassList) do
            print_debug(LOGTAG, "Loading compatibility addon '"..compatAddonClassName.."'")

            local compatAddon = require("./compat/"..compatAddonClassName)
            if (compatAddon ~= nil) then
                m_compatAddons[compatAddonClassName] = compatAddon
    
                if (compatAddon["Initialize"] ~= nil) then
                    compatAddon:Initialize()
                end
            else
                print_error(LOGTAG, "Failed to load compatibility addon '"..observerClassName.."'")
            end
        end

        print_info(LOGTAG, "BetterOpticalCamo initialized!")
    end

OpticalCamoManager.Update =
    function(this)
        local player = Game.GetPlayer()

        if (player ~= nil) then
            local opticalCamoCharges = this:GetOpticalCamoCharges(player)
            if ((opticalCamoCharges < 0.01) and (not m_settingsManager:GetValue("opticalCamoKeepActiveAfterDepletion"))) then
                this:DeactivateOpticalCamo(player)
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
                this:SetPlayerVisible(player)
                this:DeactivateOpticalCamo(player)
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

OpticalCamoManager.ActivateOpticalCamo =
    function(this, player)
        local statusEffectSystem = Game.GetStatusEffectSystem()
        local statusEffectName = this:GetOpticalCamoStatusEffectName(player)

        if (statusEffectName ~= nil) then
            -- Thanks to Taylor2000 for pointing out that just applying
            -- the effect is actually enough to activate the cloak
            statusEffectSystem:ApplyStatusEffect(player:GetEntityID(), statusEffectName)
        end
    end

OpticalCamoManager.DeactivateOpticalCamo =
    function(this, player)
        local statusEffectSystem = Game.GetStatusEffectSystem()
        local statusEffectName = this:GetOpticalCamoStatusEffectName(player)

        if (statusEffectName ~= nil) then
            statusEffectSystem:RemoveStatusEffect(player:GetEntityID(), statusEffectName)
        end
    end

OpticalCamoManager.IsOpticalCamoActive =
    function(this, player)
        local statusEffectSystem = Game.GetStatusEffectSystem()
        local statusEffectName = this:GetOpticalCamoStatusEffectName(player)

        if (statusEffectName ~= nil) then
            return statusEffectSystem:HasStatusEffect(player:GetEntityID(), statusEffectName)
        end

        return false
    end

OpticalCamoManager.GetOpticalCamoStatusEffectName =
    function(this, player)
        local transactionSystem = Game.GetTransactionSystem()

        for itemName, effectName in pairs(k_opticalCamoItemToStatusEffectName) do
            if (hasPlayerItemEquipped(player, itemName)) then
                print_trace(LOGTAG, "Item '"..itemName.."' equipped, using status-effect '"..effectName.."'")
                return effectName
            end
        end

        print_trace(LOGTAG, "No optical camo-item equipped")
        return nil
    end

OpticalCamoManager.GetOpticalCamoCharges =
    function(this, player)
        local statPoolsSystem = Game.GetStatPoolsSystem()
        return statPoolsSystem:GetStatPoolValue(player:GetEntityID(), "OpticalCamoCharges")
    end

OpticalCamoManager.ApplySettings =
    function(this, player)
        this:DumpPlayerStats(player)

        registerPlayerStatsModifier(player, "OpticalCamoChargesDecayRate", "Multiplier", m_settingsManager:GetValue("opticalCamoChargesDecayRateModifier"))

        if (m_settingsManager:GetValue("opticalCamoRechargeImmediate")) then
            registerPlayerStatsModifier(player, "OpticalCamoChargesRegenRate", "Multiplier", 100)
            registerPlayerStatsModifier(player, "OpticalCamoRechargeDuration", "Multiplier", 0.01)
        else
            registerPlayerStatsModifier(player, "OpticalCamoChargesRegenRate", "Multiplier", m_settingsManager:GetValue("opticalCamoChargesRegenRateModifier"))
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
