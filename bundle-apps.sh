#!/bin/sh

TODAY=`date "+%Y%m%d"`
CODE=`cat codename.txt | tr -d "\r"`

echo Deleting old apps
rm -rf OHRRPGCE-Game.app
rm -rf OHRRPGCE-Custom.app

echo Bundling OHRRPGCE-Game.app
cp -R mac/OHRRPGCE-Game.app.template OHRRPGCE-Game.app &&
rm -Rf OHRRPGCE-Game.app/.svn &&
rm -Rf OHRRPGCE-Game.app/Contents/.svn &&
rm -Rf OHRRPGCE-Game.app/Contents/Resources/.svn &&
mkdir -p OHRRPGCE-Game.app/Contents/MacOS &&
sed -i -e "s/#VERSION#/O.H.R.RPG.C.E version ${CODE} ${TODAY}/g" OHRRPGCE-Game.app/Contents/Info.plist &&
cp ohrrpgce-game OHRRPGCE-Game.app/Contents/MacOS/ &&
tar xf mac/Frameworks.tar.gz -C OHRRPGCE-Game.app/Contents || exit 1

echo Bundling OHRRPGCE-Custom.app
cp -R mac/OHRRPGCE-Custom.app.template OHRRPGCE-Custom.app &&
rm -Rf OHRRPGCE-Custom.app/.svn &&
rm -Rf OHRRPGCE-Custom.app/Contents/.svn &&
rm -Rf OHRRPGCE-Custom.app/Contents/Resources/.svn &&
mkdir -p OHRRPGCE-Custom.app/Contents/MacOS/support &&
mkdir -p OHRRPGCE-Custom.app/Contents/Resources/ohrhelp &&
sed -i -e "s/#VERSION#/O.H.R.RPG.C.E version ${CODE} ${TODAY}/g" OHRRPGCE-Custom.app/Contents/Info.plist &&
cp ohrrpgce-custom OHRRPGCE-Custom.app/Contents/MacOS/ &&
tar xf mac/Frameworks.tar.gz -C OHRRPGCE-Custom.app/Contents &&
cp -R ohrhelp/*.txt OHRRPGCE-Custom.app/Contents/Resources/ohrhelp &&
cp ohrrpgce.new OHRRPGCE-Custom.app/Contents/Resources/ &&
cp mac/Terminal_wrapper.sh OHRRPGCE-Custom.app/Contents/MacOS/support/ &&
cp plotscr.hsd scancode.hsi OHRRPGCE-Custom.app/Contents/MacOS/support/ &&
tar xf mac/utilities.tar.gz -C OHRRPGCE-Custom.app/Contents/MacOS/support/ && 
cp hspeak OHRRPGCE-Custom.app/Contents/MacOS/support/ || exit 1
