@echo off
for /f "tokens=1,2,3 delims=/- " %%a in ("%date%") do @set D=%%a%%b%%c
for /f "tokens=1,2,3 delims=:." %%a in ("%time%") do @set T=%%a%%b%%c
set SEED=%D%%T%

set TYPE=none
set NAME=none
set WAVE=none
set CASE=none
set INST_FILE=none

if "%1"=="" (
set TYPE=isa) else (
set TYPE=%1)

if "%2"=="" (
set NAME=rv32ui-p-add) else (
set NAME=%2)

if "%3"=="wave" (
set WAVE="-DDUMP_VCD") else (
set WAVE="-DDUMP_NONE")

if "%TYPE%"=="isa" (
    set CASE=TC_RISCV_TESTS
    set INST_FILE=../../stimulus/riscv-tests/%TYPE%/build/%NAME%.hex
)
if "%TYPE%"=="inst-seq" (
    set CASE=TC_INST_SEQ
    set INST_FILE=../../stimulus/build/%NAME%/%NAME%.hex
)
if "%TYPE%"=="software" (
    set CASE=TC_SOFTWARE
    set INST_FILE=../../../software/build/%NAME%/%NAME%.hex
)
if "%TYPE%"=="perips" (
    set CASE=TC_PERIPS
    set INST_FILE=../../../software/build/%NAME%/%NAME%.hex
)

echo Start simulation at %time%, %date%.
echo Instruction from %INST_FILE%.
iverilog -g2012 -s tb_top -o sim_riscv_tests.vvp -I . -I ./testcase -I .. -I ../../../common/general -f ../../filelist/uv_sys.f -f ../../filelist/uv_tb.f -D%CASE% -DTIME_UNIT=1ns -DTIME_PREC=1ps %WAVE% && vvp sim_riscv_tests.vvp +SEED=%SEED% +INST_FILE=%INST_FILE% +STI_NAME=%NAME%
echo End simulation at %time%, %date%.
