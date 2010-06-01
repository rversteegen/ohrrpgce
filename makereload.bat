@echo off
cls
call fbc -c -g -lang deprecated reload.bas reloadext.bas lumpfile.bas util.bas
if ERRORLEVEL 1 goto end
call fbc -g -profile -lang deprecated reloadtest.bas reload.o reloadext.o lumpfile.o util.o
call fbc -g -profile -lang deprecated xml2reload.bas reload.o reloadext.o lumpfile.o util.o -p . -l xml2
call fbc -g -profile -lang deprecated reload2xml.bas reload.o lumpfile.o util.o
call fbc -g -profile -lang deprecated reloadtime.bas reload.o lumpfile.o util.o
:end
