SEED=`date +%Y%m%d%H%M%S`
TYPE=none
NAME=none
WAVE=none

if [ -z "$1" ];then
    TYPE=isa;
else
    TYPE=$1
fi
if [ -z "$2" ];then
    NAME=rv32ui-p-add;
else
    NAME=$2
fi
if [ -z "$3" ];then
    WAVE="-DDUMP_NONE";
else
    WAVE="-DDUMP_VCD"
fi
INST_FILE=../../stimulus/riscv-tests/$TYPE/build/$NAME.hex
echo Instruction from $INST_FILE
iverilog -g2012 -s tb_top -o sim_riscv_tests.vvp -I . -I ./testcase -I .. -I ../../../common/general -f ../../filelist/uv_sys.f -f ../../filelist/uv_tb.f -DTC_RISCV_TESTS -DTIME_UNIT=1ns -DTIME_PREC=1ps $WAVE && vvp sim_riscv_tests.vvp +SEED=$SEED +INST_FILE=$INST_FILE +STI_NAME=$NAME
