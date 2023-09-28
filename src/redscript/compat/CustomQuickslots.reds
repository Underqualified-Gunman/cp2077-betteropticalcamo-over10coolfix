// Better Optical Camo (Redscript compatibility module for "Custom Quickslots")
// Copyright (c) 2022 Lukas Berger
// MIT License (See LICENSE.md)

@if(ModuleExists("CustomQuickslots"))
@addMethod(HotkeyItemController)
public func IsOpticalCamoCyberwareAbility() -> Bool {
    switch this.m_customQuickslotProperties.itemType {
        case CustomQuickslotsConfig.CustomQuickslotItemType.OpticalCamo:
            return true;
        default:
            return false;
    }
}
