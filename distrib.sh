#!/bin/sh

if [ ! -f distrib.sh ] ; then
  echo You should only run this script from the ohrrpgce directory.
  exit 1
fi

echo Building binaries
./makegame.sh || exit 1
./makeedit.sh || exit 1
./makeutil.sh || exit 1

echo "Lumping Vikings of Midgard"
if [ -f vikings.rpg ] ; then
  rm vikings.rpg
fi
./relump ../games/vikings/vikings.rpgdir ./vikings.rpg

echo "Downloading import media"
if [ -f import.zip ] ; then
  rm import.zip
fi
if [ -d "import/Music" ] ; then
  rm -Rf "import/Music"
fi
if [ -d "import/Sound Effects" ] ; then
  rm -Rf "import/Sound Effects"
fi
wget -q http://gilgamesh.hamsterrepublic.com/ohrimport/import.zip
unzip -q -d import/ import.zip
rm import.zip

echo "Erasing contents of temporary directory"
rm -Rf tmp/*

echo Erasing old distribution files
rm distrib/ohrrpgce-*.tar.bz2
rm distrib/*.deb

echo "Packaging binary distribution of CUSTOM"

echo "  Including binaries"
cp -p ohrrpgce-game tmp
cp -p ohrrpgce-custom tmp
cp -p unlump tmp
cp -p relump tmp

echo "  Including hspeak"
cp -p hspeak.sh tmp
cp -p hspeak.exw tmp
cp -p hsspiffy.e tmp

echo "  Including support files"
cp -p ohrrpgce.new tmp
cp -p plotscr.hsd tmp
cp -p scancode.hsi tmp

echo "  Including readmes"
cp -p README-game.txt tmp
cp -p README-custom.txt tmp
cp -p LICENSE.txt tmp
cp -p LICENSE-binary.txt tmp
cp -p whatsnew.txt tmp

echo "  Including Vikings of Midgard"
cp -p vikings.rpg tmp
cp -pr "../games/vikings/Vikings script files" tmp
cp -p ../games/vikings/README-vikings.txt tmp

echo "  Including import"
mkdir tmp/import
cp -pr import/* tmp/import

echo "  Including docs"
mkdir tmp/docs
cp -p docs/*.html tmp/docs
cp -p docs/plotdict.xml tmp/docs
cp -p docs/htmlplot.xsl tmp/docs
cp -p docs/more-docs.txt tmp/docs

echo "tarring and bzip2ing distribution"
mv tmp ohrrpgce
tar -jcf distrib/ohrrpgce-linux-x86.tar.bz2 ./ohrrpgce --exclude .svn
mv ohrrpgce tmp

TODAY=`date "+%Y-%m-%d"`
CODE=`cat codename.txt | tr -d "\r"`
mv distrib/ohrrpgce-linux-x86.tar.bz2 distrib/ohrrpgce-linux-x86-$TODAY-$CODE.tar.bz2

echo "Erasing contents of temporary directory"
rm -Rf tmp/*

echo "Building Debian/Ubuntu packages"
cd linux
if [ -f *.deb ] ; then
  rm *.deb
fi
./all.sh
cd ..
mv linux/*.deb distrib
