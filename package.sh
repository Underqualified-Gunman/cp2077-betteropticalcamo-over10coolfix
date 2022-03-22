#!/bin/bash
# Better Optical Camo
# Copyright (c) 2022 Lukas Berger
# MIT License (See LICENSE.md)
set -e

rm -vf BetterOpticalCamo.zip

cp -vf {CHANGELOG,LICENSE,README}.md bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/

zip -v -r9 BetterOpticalCamo.zip \
    bin/ \
    r6/ \
    -x bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/BetterOpticalCamo.log \
    -x bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/db.sqlite3 \
    -x bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/settings.json

rm -vf bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/{CHANGELOG,LICENSE,README}.md
