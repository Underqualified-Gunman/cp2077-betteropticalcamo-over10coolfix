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

local m_playerExitCombatDelayIDs = {}

local m_detectedOpticalCamoItem = ""

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

    local itemTDBID = ItemID.FromTDBID(itemName).id

    -- primary method: check active gadget, this seems to work on all saves I tried so far
    -- Thanks to Wilieragr for providing me a savegame to solve this problem
    if (equipmentPlayerData:GetActiveGadget().id == itemTDBID) then
        return true
    end

    -- secondary method: directly query active cyberware, only worked on my savegame
    if (equipmentPlayerData:GetActiveCyberware().id == itemTDBID) then
        -- return true
    end

    -- backup method: just iterate through equipped cyberware
    --
    -- @remark keep this disabled, as even if the Optical Camo is basically equipped, the player may have another
    --         cyberware equipped on shortcut, we don't want to activate camo if the player doesn't expect it to;
    --         but just in case, I want to keep the basic logic here
    --[[ for i = 1, 3 do
        if (equipmentPlayerData:GetItemInEquipSlot("IntegumentarySystemCW", i).id == itemTDBID) then
            return true
        end
    end ]]

    return false
end

OpticalCamoManager.ApplyTweaks =
    function(this)
        -- Set max duration to infinite
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
            this:AttachPlayer(player)
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

        if ((player ~= nil) and (this:IsOpticalCamoActive(player))) then
            this:SetPlayerVisible(player)
            this:DeactivateOpticalCamo(player)
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
        local playerID = player:GetEntityID()

        this:ApplySettings(player)

        local statusEffectName = this:GetOpticalCamoStatusEffectName(player)
        if (statusEffectName ~= nil) then
            -- Thanks to Taylor2000 for pointing out that just applying
            -- the effect is actually enough to activate the cloak
            statusEffectSystem:ApplyStatusEffect(playerID, statusEffectName)
        end
    end

OpticalCamoManager.DeactivateOpticalCamo =
    function(this, player)
        local statusEffectSystem = Game.GetStatusEffectSystem()
        local statPoolsSystem = Game.GetStatPoolsSystem()
        local delaySystem = Game.GetDelaySystem()
        local playerID = player:GetEntityID()

        local statusEffectName = this:GetOpticalCamoStatusEffectName(player)
        if (statusEffectName ~= nil) then
            statusEffectSystem:RemoveStatusEffect(playerID, statusEffectName)
        else
            statusEffectSystem:RemoveStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffCommon")
            statusEffectSystem:RemoveStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffUncommon")
            statusEffectSystem:RemoveStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffRare")
            statusEffectSystem:RemoveStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffEpic")
            statusEffectSystem:RemoveStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffLegendary")
        end

        if (m_settingsManager:GetValue("opticalCamoNoDecay")) then
            -- empty optical camo charges
            statPoolsSystem:RequestSettingStatPoolValue(playerID, gamedataStatPoolType.OpticalCamoCharges, 0, player, true)
        end
    end

OpticalCamoManager.IsOpticalCamoActive =
    function(this, player)
        local statusEffectSystem = Game.GetStatusEffectSystem()
        local playerID = player:GetEntityID()

        local statusEffectName = this:GetOpticalCamoStatusEffectName(player)
        if (statusEffectName ~= nil) then
            return statusEffectSystem:HasStatusEffect(playerID, statusEffectName)
        else
            return statusEffectSystem:HasStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffCommon") or
                statusEffectSystem:HasStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffUncommon") or
                statusEffectSystem:HasStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffRare") or
                statusEffectSystem:HasStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffEpic") or
                statusEffectSystem:HasStatusEffect(playerID, "BaseStatusEffect.OpticalCamoPlayerBuffLegendary")
        end
    end

OpticalCamoManager.HasOpticalCamoEquipped =
    function(this, player)
        return (this:GetOpticalCamoStatusEffectName(player) ~= nil)
    end

OpticalCamoManager.GetOpticalCamoStatusEffectName =
    function(this, player)
        for itemName, effectName in pairs(k_opticalCamoItemToStatusEffectName) do
            if (hasPlayerItemEquipped(player, itemName)) then
                print_trace(LOGTAG, "Item '"..itemName.."' equipped, using status-effect '"..effectName.."'")

                if (m_detectedOpticalCamoItem ~= itemName) then
                    print_info(LOGTAG, "Detected optical camo cyberware item '"..itemName.."' (using status-effect '"..effectName.."')")
                    m_detectedOpticalCamoItem = itemName
                end

                return effectName
            end
        end

        if (m_detectedOpticalCamoItem ~= nil) then
            print_info(LOGTAG, "No optical camo cyberware item detected")
            m_detectedOpticalCamoItem = nil
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
        this:ApplyDecayModifierSettings(player)
        this:ApplyRegenModifierSettings(player)
    end

OpticalCamoManager.ApplyDecayModifierSettings =
    function(this, player)
        local statsSystem = Game.GetStatsSystem()
        local statPoolsSystem = Game.GetStatPoolsSystem()
        local playerID = player:GetEntityID()

        local defOpticalCamoDuration = statsSystem:GetStatValue(playerID, "OpticalCamoDuration")
        local defDecayModifierValuePerSec = (100 / defOpticalCamoDuration)

        local decayModifier = StatPoolModifier.new()

        decayModifier.enabled = true
        decayModifier.rangeBegin = 0.00
        decayModifier.rangeEnd = 100.00
        decayModifier.delayOnChange = false

        if (m_settingsManager:GetValue("opticalCamoNoDecay")) then
            decayModifier.valuePerSec = 0
        else
            decayModifier.valuePerSec = (defDecayModifierValuePerSec * m_settingsManager:GetValue("opticalCamoChargesDecayRateModifier"))
        end

        statPoolsSystem:RequestSettingModifier(playerID, gamedataStatPoolType.OpticalCamoCharges, gameStatPoolModificationTypes.Decay, decayModifier)
    end

OpticalCamoManager.ApplyRegenModifierSettings =
    function(this, player)
        local statsSystem = Game.GetStatsSystem()
        local statPoolsSystem = Game.GetStatPoolsSystem()
        local playerID = player:GetEntityID()

        local defOpticalCamoRechargeDuration = statsSystem:GetStatValue(playerID, "OpticalCamoRechargeDuration")
        local defRegenModifierValuePerSec = (100 / defOpticalCamoRechargeDuration)

        local regenModifier = StatPoolModifier.new()

        regenModifier.enabled = true
        regenModifier.rangeBegin = 0.00
        regenModifier.rangeEnd = 100.00
        regenModifier.delayOnChange = false

        if (m_settingsManager:GetValue("opticalCamoRechargeImmediate")) then
            regenModifier.valuePerSec = 100000
        else
            regenModifier.valuePerSec = (defRegenModifierValuePerSec * m_settingsManager:GetValue("opticalCamoChargesRegenRateModifier"))
        end

        statPoolsSystem:RequestSettingModifier(playerID, gamedataStatPoolType.OpticalCamoCharges, gameStatPoolModificationTypes.Regeneration, regenModifier)
    end

OpticalCamoManager.ResetOpticalCamoModifiers =
    function(this, player)
        local statPoolsSystem = Game.GetStatPoolsSystem()
        local playerID = player:GetEntityID()

        statPoolsSystem:RequestResetingModifier(playerID, gamedataStatPoolType.OpticalCamoCharges, gameStatPoolModificationTypes.Decay)
        statPoolsSystem:RequestResetingModifier(playerID, gamedataStatPoolType.OpticalCamoCharges, gameStatPoolModificationTypes.Regeneration)
    end

OpticalCamoManager.ResetOpticalCamoCharges =
    function(this, player)
        local statPoolsSystem = Game.GetStatPoolsSystem()
        local playerID = player:GetEntityID()

        -- reset stat pool to prevent permanent discharge-then-recharge cycle
        -- that occurs after the modifiers have been applied when the pool is filled
        player:SetStatPoolEnabled(gamedataStatPoolType.OpticalCamoCharges, gameStatPoolModificationTypes.Decay, false)
        player:SetStatPoolEnabled(gamedataStatPoolType.OpticalCamoCharges, gameStatPoolModificationTypes.Regeneration, false)

        -- fill optical camo charges
        statPoolsSystem:RequestSettingStatPoolValue(playerID, gamedataStatPoolType.OpticalCamoCharges, 100, player, true)
    end

OpticalCamoManager.AttachPlayer =
    function(this, player)
        this:DeactivateOpticalCamo(player)
        this:DumpPlayerStats(player)
    end

OpticalCamoManager.DetachPlayer =
    function(this, player)
        this:ClearDelayedPlayerExitCombatEvents()
        this:ResetOpticalCamoModifiers(player)
        this:DeactivateOpticalCamo(player)
        this:SetPlayerVisible(player)
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
