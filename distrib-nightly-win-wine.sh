#!/bin/bash

echo "OHRRPGCE nightly build for Windows using Linux+Wine"
echo "---------------------------------------------------"

SCPHOST="james_paige@motherhamster.org"
SCPDEST="HamsterRepublic.com/ohrrpgce/nightly"
SCPDOCS="HamsterRepublic.com/ohrrpgce/nightly/docs"

SCONS="C:\Python27\Scripts\scons.bat"

SCONS_ARGS="debug=0 gengcc=1"

# Using wine
BUILD="wine cmd /C ${SCONS}"

# Uncomment to cross-compile
#export PATH=~/src/mxe/usr/bin:$PATH
#BUILD="scons target=i686-w64-mingw32.shared"
#DONT_BUILD_HSPEAK=yes  #TODO: scons doesn't support cross-compiling hspeak yet


#-----------------------------------------------------------------------

function mustexist {
  if [ ! -f "${1}" -a ! -d "${1}" ] ; then
    echo "ERROR: ${1} does not exist!"
    exit 1
  fi
}

function zip_and_upload {
  mustexist game.exe
  mustexist custom.exe
  mustexist hspeak.exe
  mustexist relump.exe
  BUILDNAME="${1}"
  ZIPFILE="ohrrpgce-win-${BUILDNAME}-wip.zip"
  echo "Now creating and uploading ${ZIPFILE}"

  rm -f distrib/"${ZIPFILE}"
  zip -q distrib/"${ZIPFILE}" game.exe custom.exe hspeak.exe
  zip -q -r distrib/"${ZIPFILE}" data
  zip -q -r distrib/"${ZIPFILE}" ohrhelp
  zip -q distrib/"${ZIPFILE}" support/madplay.exe
  zip -q distrib/"${ZIPFILE}" support/oggenc.exe
  zip -q distrib/"${ZIPFILE}" support/zip.exe
  cp relump.exe support/
  zip -q distrib/"${ZIPFILE}" support/relump.exe
  rm support/relump.exe
  # unlump.exe is excluded
  rm -Rf texttemp
  mkdir texttemp
  cp whatsnew.txt *-binary.txt *-nightly.txt plotscr.hsd scancode.hsi svninfo.txt texttemp/
  unix2dos -q texttemp/*
  zip -q -j distrib/"${ZIPFILE}" texttemp/*
  rm -Rf texttemp

  mustexist distrib/"${ZIPFILE}"

  rm -Rf sanity
  mkdir sanity
  cd sanity
  unzip -qq ../distrib/"${ZIPFILE}"
  cd ..
  mustexist "sanity/game.exe"
  mustexist "sanity/custom.exe"
  rm -Rf sanity

  while [ -f "${2}" ] ; do
    zip -q distrib/"${ZIPFILE}" "${2}"
    shift
  done

  scp distrib/"${ZIPFILE}" "${SCPHOST}":"${SCPDEST}"
}

#-----------------------------------------------------------------------
# turn off wine's debug noise
export WINEDEBUG=fixme-all

svn cleanup
svn update
svn info > svninfo.txt

./distrib-wine.sh nightly
OHRVERDATE=`svn info | grep "^Last Changed Date:" | cut -d ":" -f 2 | cut -d " " -f 2`
OHRVERCODE=`cat codename.txt | grep -v "^#" | head -1 | tr -d "\r"`
SUFFIX="${OHRVERDATE}-${OHRVERCODE}"

mustexist distrib/ohrrpgce-win-installer-"${SUFFIX}".exe
scp -p distrib/ohrrpgce-win-installer-"${SUFFIX}".exe "${SCPHOST}":"${SCPDEST}"/ohrrpgce-wip-win-installer.exe

# Build all utilities once
rm -f unlump.exe relump.exe
${BUILD} relump unlump $SCONS_ARGS
if [ -z "$DONT_BUILD_HSPEAK" ]; then
  rm -f hspeak.exe
  ${BUILD} hspeak $SCONS_ARGS
fi
mustexist unlump.exe
mustexist relump.exe
mustexist hspeak.exe

rm -r game*.exe custom*.exe
${BUILD} music=sdl $SCONS_ARGS
zip_and_upload music_sdl gfx_directx.dll SDL.dll SDL_mixer.dll

rm -f game*.exe custom*.exe
${BUILD} music=native $SCONS_ARGS
zip_and_upload music_native gfx_directx.dll SDL.dll audiere.dll

rm -f game*.exe custom*.exe
${BUILD} music=native2 $SCONS_ARGS
zip_and_upload music_native2 gfx_directx.dll SDL.dll audiere.dll

rm -f game*.exe custom*.exe
${BUILD} music=silence $SCONS_ARGS
zip_and_upload music_silence gfx_directx.dll SDL.dll

# rm -f game*.exe custom*.exe
# ${BUILD} gfx=alleg+directx+fb+sdl music=sdl $SCONS_ARGS
# zip_and_upload gfx_alleg-music_sdl alleg40.dll SDL.dll SDL_mixer.dll

rm -f game*.exe custom*.exe
${BUILD} music=sdl debug=2
zip_and_upload music_sdl-debug gfx_directx.dll SDL.dll SDL_mixer.dll misc/gdbcmds1.txt misc/gdbcmds2.txt gdbgame.bat gdbcustom.bat

# Note that this is duplicated in distrib-nightly-linux.sh
echo "uploading plotscripting docs"
scp docs/plotdict.xml "${SCPHOST}":"${SCPDOCS}"
scp docs/htmlplot.xsl "${SCPHOST}":"${SCPDOCS}"
docs/update-html.sh
scp docs/plotdictionary.html "${SCPHOST}":"${SCPDOCS}"

rm -f distrib/ohrrpgce-util.zip
zip distrib/ohrrpgce-util.zip unlump.exe relump.exe LICENSE-binary.txt svninfo.txt
scp distrib/ohrrpgce-util.zip "${SCPHOST}":"${SCPDEST}"

rm -f distrib/hspeak-win-nightly.zip
zip distrib/hspeak-win-nightly.zip hspeak.exe hspeak.exw hsspiffy.e euphoria/*.e euphoria/License.txt LICENSE.txt plotscr.hsd scancode.hsi
scp distrib/hspeak-win-nightly.zip "${SCPHOST}":"${SCPDEST}"

rm -f distrib/bam2mid.zip
rm -f bam2mid.exe
${BUILD} bam2mid.exe $SCONS_ARGS
mustexist bam2mid.exe
zip distrib/bam2mid.zip bam2mid.exe bam2mid.txt LICENSE.txt svninfo.txt
scp distrib/bam2mid.zip "${SCPHOST}":"${SCPDEST}"

rm -f distrib/madplay+oggenc.zip
zip distrib/madplay+oggenc.zip support/madplay.exe support/oggenc.exe support/LICENSE-*.txt LICENSE.txt
scp distrib/madplay+oggenc.zip "${SCPHOST}":"${SCPDEST}"

scp svninfo.txt "${SCPHOST}":"${SCPDEST}"
