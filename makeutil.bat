@echo off
echo Now compiling OHRRPGCE utilities
fbc -lang deprecated unlump.bas util.bas lumpfile.bas win32\blit.o
fbc -lang deprecated relump.bas util.bas lumpfile.bas win32\blit.o
echo.
