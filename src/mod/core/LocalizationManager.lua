-- Better Optical Camo
-- Copyright (c) 2022-2023 Lukas Berger
-- MIT License (See LICENSE.md)
local LocalizationManager = {}
local LOGTAG = "LocalizationManager"

local m_i18n = {}

function loadI18nFile(filepath)
    print_debug(LOGTAG, "attempting to load translation file '"..filepath.."'")

    local file = io.open(filepath, "r")
    if file ~= nil then
        print_debug(LOGTAG, "loading translations from file '"..filepath.."'")

        local contents = file:read("*a")
        local validJson, loadedTranslations = pcall(function() return json.decode(contents) end)

        file:close()

        if validJson then
            for key, value in pairs(loadedTranslations) do
                m_i18n[key] = value
            end
        end
    end
end

LocalizationManager.Initialize =
    function(this)
        -- load the default translations
        loadI18nFile("./i18n.default.json")

        -- load the custom translations
        -- overrides all default translations which the custom i18n-file defines
        loadI18nFile("./i18n.json")
    end

LocalizationManager.GetTranslation =
    function(this, name)
        return m_i18n[name]
    end

return LocalizationManager
