// Better Optical Camo
// Copyright (c) 2022-2023 Lukas Berger
// MIT License (See LICENSE.md)
module BetterOpticalCamo

public class BetterOpticalCamoSystem extends ScriptableSystem {

    public final func GetSettings(name: String) -> Variant {
        /* Implemented by CET-mod */
        return null;
    }

    public final func DeactivateOpticalCamo(player: wref<PlayerPuppet>) -> Bool {
        /* Implemented by CET-mod */
        return false;
    }

    public final func IsOpticalCamoActive(player: wref<PlayerPuppet>) -> Bool {
        /* Implemented by CET-mod */
        return false;
    }

}
