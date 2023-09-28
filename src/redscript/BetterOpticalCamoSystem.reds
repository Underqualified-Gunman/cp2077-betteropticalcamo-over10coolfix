// Better Optical Camo
// Copyright (c) 2022-2023 Lukas Berger
// MIT License (See LICENSE.md)
module BetterOpticalCamo

public class BetterOpticalCamoSystem extends ScriptableSystem {

    public final func GetSettings(name: String) -> Variant {
        /* Overriden by RedscriptExtension */
        return null;
    }

    public final func ActivateOpticalCamo(player: wref<PlayerPuppet>) -> Void {
        /* Overriden by RedscriptExtension */
    }

    public final func DeactivateOpticalCamo(player: wref<PlayerPuppet>) -> Void {
        /* Overriden by RedscriptExtension */
    }

    public final func IsOpticalCamoActive(player: wref<PlayerPuppet>) -> Bool {
        /* Overriden by RedscriptExtension */
        return false;
    }

    public final func GetOpticalCamoCharges(player: wref<PlayerPuppet>) -> Float {
        /* Overriden by RedscriptExtension */
        return -1.0;
    }

}
