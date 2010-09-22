#!/bin/sh

# Scheduling this script to run automatically is equivalent to giving the other devs
# write access to your automatric build machine. Don't do it unless you trust them all.
# (which James fortunately does, and the build machine is reasonably sandboxed, so!)

UPLOAD_SERVER="james_paige@motherhamster.org"
UPLOAD_FOLDER="HamsterRepublic.com"
UPLOAD_DEST="$UPLOAD_SERVER:$UPLOAD_FOLDER"
TODAY=`date "+%Y-%m-%d"`

cd ~/src/nightly

if [ ! -d ohrrpgce ] ; then
  echo nightly snapshot not found, checking out from svn...
  svn checkout svn://gilgamesh.HamsterRepublic.com/ohrrpgce ./ohrrpgce
fi

cd ohrrpgce

svn update > ../nightly-temp.txt
UPDATE=`wc -l < ../nightly-temp.txt`
cat ../nightly-temp.txt
rm ../nightly-temp.txt

if [ ${UPDATE} -eq 1 ] ; then
  echo no changes, no need to update snapshot.
  exit
fi

echo removing old nightly source snapshot...
rm ohrrpgce-source-nightly.zip

echo zipping up new nightly snapshot
zip -q -r ohrrpgce-source-nightly.zip wip
ls -l ohrrpgce-source-nightly.zip

echo uploading new nightly snapshot
scp -p ohrrpgce-source-nightly.zip $UPLOAD_DEST/ohrrpgce/nightly/

echo uploading plotscripting docs
scp -p wip/docs/plotdict.xml $UPLOAD_DEST/ohrrpgce/docs/
scp -p wip/docs/htmlplot.xsl $UPLOAD_DEST/ohrrpgce/docs/

echo Now we go to build the linux nightlies

cd ..

if [ ! -d ohrrpgce-build ] ; then
  echo nightly snapshot not found, checking out from svn...
  svn checkout svn://gilgamesh.HamsterRepublic.com/ohrrpgce ./ohrrpgce-build
fi

cd ohrrpgce-build

svn cleanup
svn update

cd wip

./distrib.sh

mv distrib/ohrrpgce-linux-*-wip.tar.bz2 distrib/ohrrpgce-linux-wip.tar.bz2
scp -p distrib/ohrrpgce-linux-wip.tar.bz2 $UPLOAD_DEST/ohrrpgce/nightly/
rm distrib/ohrrpgce-linux-wip.tar.bz2

ssh $UPLOAD_SERVER rm "$UPLOAD_FOLDER/ohrrpgce/nightly/ohrrpgce_*.deb"
scp -p distrib/ohrrpgce_*.wip-*_i386.deb $UPLOAD_DEST/ohrrpgce/nightly/
rm distrib/ohrrpgce_*.deb
