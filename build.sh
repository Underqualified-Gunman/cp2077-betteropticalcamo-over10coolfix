#!/bin/bash
# Better Optical Camo
# Copyright (c) 2022 Lukas Berger
# MIT License (See LICENSE.md)
set -e

rm -rvf build/
mkdir -pv build/

rm -vf BetterOpticalCamo.zip

# create directory structure
mkdir -pv "build/"
mkdir -pv "build/Core Mod/"
mkdir -pv "build/Compatibility Addons/"
mkdir -pv "build/Compatibility Addons/Customer Quickslots"

# copy files
cp -vf {CHANGELOG,LICENSE,README}.md "build/"
cp -rvf core/* "build/Core Mod/"
cp -rvf compat/custom_quickslots/* "build/Compatibility Addons/Customer Quickslots"

# create final artifact
cd build/
zip -v -r9 ../BetterOpticalCamo.zip .
