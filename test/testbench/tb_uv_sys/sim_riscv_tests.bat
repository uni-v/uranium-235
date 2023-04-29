@echo off
for /f "tokens=1,2,3 delims=/- " %%a in ("%date%") do @set D=%%a%%b%%c
for /f "tokens=1,2,3 delims=:." %%a in ("%time%") do @set T=%%a%%b%%c
set SEED=%D%%T%

set TYPE=none
set NAME=none
set WAVE=none
if "%1"=="" (
set TYPE=isa) else (
set TYPE=%1)

if "%2"=="" (
set NAME=rv32ui-p-add) else (
set NAME=%2)

if "%3"=="wave" (
set WAVE="-DDUMP_VCD") else (
set WAVE="-DDUMP_NONE")

set INST_FILE=../../stimulus/riscv-tests/%TYPE%/build/%NAME%.hex
echo Instruction from %INST_FILE%
iverilog -g2012 -s tb_top -o sim_riscv_tests.vvp -I . -I ./testcase -I .. -I ../../../common/general -f ../../filelist/uv_sys.f -f ../../filelist/uv_tb.f -DTC_RISCV_TESTS -DTIME_UNIT=1ns -DTIME_PREC=1ps %WAVE% && vvp sim_riscv_tests.vvp +SEED=%SEED% +INST_FILE=%INST_FILE% +STI_NAME=%NAME%
