@echo off
for /f "tokens=1,2,3 delims=/- " %%a in ("%date%") do @set D=%%a%%b%%c
for /f "tokens=1,2,3 delims=:." %%a in ("%time%") do @set T=%%a%%b%%c
set SEED=%D%%T%

set NAME=none
set WAVE=none

if "%1"=="" (
set NAME=TestUART) else (
set NAME=%1)

if "%2"=="wave" (
set WAVE="-DDUMP_VCD") else (
set WAVE="-DDUMP_NONE")

set INST_FILE=../../../software/build/%NAME%/%NAME%.hex
echo Start simulation at %time%, %date%.
echo Instruction from %INST_FILE%.
iverilog -g2012 -s tb_top -o sim_perips.vvp -I . -I ./testcase -I .. -I ../../../common/general -f ../../filelist/uv_sys.f -f ../../filelist/uv_tb.f -DTC_PERIPS -DTIME_UNIT=1ns -DTIME_PREC=1ps %WAVE% && vvp sim_perips.vvp +SEED=%SEED% +INST_FILE=%INST_FILE% +STI_NAME=%NAME%
echo End simulation at %time%, %date%.
