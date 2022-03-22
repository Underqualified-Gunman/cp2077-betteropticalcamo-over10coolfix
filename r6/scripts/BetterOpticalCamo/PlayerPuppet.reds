// Better Optical Camo
// Copyright (c) 2022 Lukas Berger
// MIT License (See LICENSE.md)

@addMethod(PlayerPuppet)
public func DeactivateOpticalCamo() -> Void {
    let playerEntityID: EntityID;
    let statusEffectSystem: ref<StatusEffectSystem>;

    playerEntityID = this.GetEntityID();
    statusEffectSystem = GameInstance.GetStatusEffectSystem(this.GetGame());

    statusEffectSystem.RemoveStatusEffect(
        playerEntityID,
        t"BaseStatusEffect.Cloaked");

    statusEffectSystem.RemoveStatusEffect(
        playerEntityID,
        t"BaseStatusEffect.OpticalCamoPlayerBuffBase");

    statusEffectSystem.RemoveStatusEffect(
        playerEntityID,
        t"BaseStatusEffect.OpticalCamoPlayerBuffRare");

    statusEffectSystem.RemoveStatusEffect(
        playerEntityID,
        t"BaseStatusEffect.OpticalCamoPlayerBuffEpic");

    statusEffectSystem.RemoveStatusEffect(
        playerEntityID,
        t"BaseStatusEffect.OpticalCamoPlayerBuffLegendary");
}

@addMethod(PlayerPuppet)
public func IsOpticalCamoActive() -> Bool {
    let playerEntityID: EntityID;
    let statusEffectSystem: ref<StatusEffectSystem>;

    playerEntityID = this.GetEntityID();
    statusEffectSystem = GameInstance.GetStatusEffectSystem(this.GetGame());

    return statusEffectSystem.HasStatusEffect(playerEntityID, t"BaseStatusEffect.Cloaked") ||
        statusEffectSystem.HasStatusEffect(playerEntityID, t"BaseStatusEffect.OpticalCamoPlayerBuffBase") ||
        statusEffectSystem.HasStatusEffect(playerEntityID, t"BaseStatusEffect.OpticalCamoPlayerBuffRare") ||
        statusEffectSystem.HasStatusEffect(playerEntityID, t"BaseStatusEffect.OpticalCamoPlayerBuffEpic") ||
        statusEffectSystem.HasStatusEffect(playerEntityID, t"BaseStatusEffect.OpticalCamoPlayerBuffLegendary");
}
