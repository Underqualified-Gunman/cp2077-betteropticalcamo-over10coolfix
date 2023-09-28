-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local PlayerPuppetObserver = {}
local LOGTAG = "PlayerPuppetObserver"

--- apply settings (status modifiers, etc.) on (re)-load
function observeOnGameAttached(this)
    print_trace(LOGTAG, "entering Observer<PlayerPupper::OnGameAttached>")

    local opticalCamoManager = GetOpticalCamoManager()

    opticalCamoManager:DumpPlayerStats(this)
    opticalCamoManager:ApplySettings(this)
    opticalCamoManager:DumpPlayerStats(this)

    print_trace(LOGTAG, "exiting Observer<PlayerPupper::OnGameAttached>")
end

--- toggle the cloak by pressing the combat gadget button again
function observeOnAction(this, action)
    print_trace(LOGTAG, "entering Observer<PlayerPupper::OnAction>")

    local opticalCamoManager = GetOpticalCamoManager()

    local actionName = Game.NameToString(ListenerAction.GetName(action))
    local actionType = ListenerAction.GetType(action).value

    if (opticalCamoManager:GetSettingsManager():GetValue("enableToggling")) then
        if (actionName == "UseCombatGadget" and actionType == "BUTTON_PRESSED") then
            local opticalCamoCharges = opticalCamoManager:GetOpticalCamoCharges(this)

            if (opticalCamoManager:IsOpticalCamoActive(this)) then
                opticalCamoManager:DeactivateOpticalCamo(this)
            elseif (opticalCamoCharges > 0) then
                opticalCamoManager:ActivateOpticalCamo(this)
            end
        end
    end

    print_trace(LOGTAG, "exiting Observer<PlayerPupper::OnAction>")
end

--- run additional actions when cloak is activated
function observeOnStatusEffectApplied(this, event)
    print_trace(LOGTAG, "entering Observer<PlayerPupper::OnStatusEffectApplied>")

    local playerID = this:GetEntityID()
    local statsSystem = Game.GetStatsSystem()
    local statusEffectSystem = Game.GetStatusEffectSystem()
    local delaySystem = Game.GetDelaySystem()
    local opticalCamoManager = GetOpticalCamoManager()

    local hasActiveCamoGameplayTag = doesEventContainActiveCamoGameplayTag(event)
    local canPlayerExitCombatWithOpticalCamo = Game.HasStatFlag(this, "CanPlayerExitCombatWithOpticalCamo")
    local blockOpticalCamoRelicPerk = Game.HasStatFlag(this, "BlockOpticalCamoRelicPerk")
    local hasOpticalCamoSlideCoolPerkStatusEffect = statusEffectSystem:HasStatusEffect(playerID, "OpticalCamoSlideCoolPerk")
    local hasOpticalCamoGrappleStatusEffect = statusEffectSystem:HasStatusEffect(playerID, "OpticalCamoGrapple")

    local shouldRunInvisibilityLogic = (hasActiveCamoGameplayTag)
        and (not canPlayerExitCombatWithOpticalCamo)
        and (not blockOpticalCamoRelicPerk)
        and (not hasOpticalCamoSlideCoolPerkStatusEffect)
        and (not hasOpticalCamoGrappleStatusEffect)
        and (opticalCamoManager:GetSettingsManager():GetValue("combatCloak"))

    print_trace(LOGTAG, "hasActiveCamoGameplayTag="..tostring(hasActiveCamoGameplayTag))
    print_trace(LOGTAG, "canPlayerExitCombatWithOpticalCamo="..tostring(canPlayerExitCombatWithOpticalCamo))
    print_trace(LOGTAG, "blockOpticalCamoRelicPerk="..tostring(blockOpticalCamoRelicPerk))
    print_trace(LOGTAG, "hasOpticalCamoSlideCoolPerkStatusEffect="..tostring(hasOpticalCamoSlideCoolPerkStatusEffect))
    print_trace(LOGTAG, "hasOpticalCamoGrappleStatusEffect="..tostring(hasOpticalCamoGrappleStatusEffect))
    print_trace(LOGTAG, "#combatCloak="..tostring(opticalCamoManager:GetSettingsManager():GetValue("combatCloak")))

    if (shouldRunInvisibilityLogic) then
        print_info(LOGTAG, "activating combat-cloak")

        opticalCamoManager:SetPlayerInvisible(this)
        opticalCamoManager:MakePlayerExitCombat(this)
    end

    print_trace(LOGTAG, "exiting Observer<PlayerPupper::OnStatusEffectApplied>")
end

--- run additional actions when cloak is deactivated
function observeOnStatusEffectRemoved(this, event)
    print_trace(LOGTAG, "entering Observer<PlayerPupper::OnStatusEffectRemoved>")

    if (doesEventContainActiveCamoGameplayTag(event)) then
        print_info(LOGTAG, "deactivating combat-cloak")

        local opticalCamoManager = GetOpticalCamoManager()

        opticalCamoManager:SetPlayerVisible(this)
        opticalCamoManager:ClearDelayedPlayerExitCombatEvents()
    end

    print_trace(LOGTAG, "exiting Observer<PlayerPupper::OnStatusEffectRemoved>")
end

--- reset registered status-modifiers, etc. on reload
function observeOnDetach(this)
    print_trace(LOGTAG, "entering Observer<PlayerPupper::OnDetach>")

    local opticalCamoManager = GetOpticalCamoManager()

    opticalCamoManager:UnregisterPlayerStatsModifier(this)
    opticalCamoManager:ClearDelayedPlayerExitCombatEvents()

    print_trace(LOGTAG, "exiting Observer<PlayerPupper::OnDetach>")
end

function doesEventContainActiveCamoGameplayTag(event)
    local gameplayTags = event.staticData:GameplayTags()

    return table_contains_value(
        gameplayTags,
        ToCName { hash_lo = 0x0035A31B, hash_hi = 0x3E1E789D --[[ ActiveCamo --]] }
    )
end

PlayerPuppetObserver.Initialize =
    function()
        ObserveBefore("PlayerPuppet", "OnGameAttached", observeOnGameAttached)
        ObserveBefore("PlayerPuppet", "OnAction", observeOnAction)
        ObserveBefore("PlayerPuppet", "OnStatusEffectApplied", observeOnStatusEffectApplied)
        ObserveBefore("PlayerPuppet", "OnStatusEffectRemoved", observeOnStatusEffectRemoved)
        ObserveBefore("PlayerPuppet", "OnDetach", observeOnDetach)
    end

return PlayerPuppetObserver
