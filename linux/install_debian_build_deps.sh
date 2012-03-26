#!/bin/sh

echo "This script installs the debian packages that are required to"
echo "compile the OHRRPGCE. You must manually install FreeBasic and"
echo "Euphoria because they are not currently available as deb packages"
echo ""
echo "http://freebasic.net/"
echo "http://openeuphoria.org/"
echo "------------------------------------------------------------------"

sudo apt-get install scons g++ libx11-dev libxpm-dev libxrandr-dev libxrender-dev libsdl-mixer1.2-dev timidity gdb
# gdb isn't strictly required, but is useful anyway
