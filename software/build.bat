@echo off
set APP=None
if "%1"=="" (
set APP=Hello) else (
set APP=%1)
dir .\build\%APP% > nul 2> nul || md .\build\%APP%
make -C ./build/%APP% -f ../../Makefile APP=%APP%
