#!/bin/bash
# Better Optical Camo
# Copyright (c) 2022 Lukas Berger
# MIT License (See LICENSE.md)
set -e

rm -vfr build/
mkdir -pv build/

rm -vf BetterOpticalCamo.zip

# create directory structure
mkdir -pv "build/"
mkdir -pv "build/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/"
mkdir -pv "build/r6/scripts/BetterOpticalCamo/"

# copy files
cp -v {CHANGELOG,LICENSE,README}.md  "build/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/"
cp -rv src/mod/*                     "build/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/"
cp -rv src/redscript/*               "build/r6/scripts/BetterOpticalCamo/"

# remove runtime files
rm -vf \
    "build/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/BetterOpticalCamo.log" \
    "build/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/db.sqlite3" \
    "build/bin/x64/plugins/cyber_engine_tweaks/mods/BetterOpticalCamo/settings.json"

# create final mod-artifact
cd build/
zip -v -r9 ../BetterOpticalCamo.zip .
cd -

# cleanup
rm -vfr build/
