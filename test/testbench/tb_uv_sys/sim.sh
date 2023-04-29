SEED=`date +%Y%m%d%H%M%S`
TYPE=none
NAME=none
WAVE=none
CASE=none
INST_FILE=none

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

if [ "$TYPE" == "isa" ];then
    CASE=TC_RISCV_TESTS
    INST_FILE=../../stimulus/riscv-tests/$TYPE/build/$NAME.hex
fi
if [ "$TYPE" == "inst-seq" ];then
    CASE=TC_INST_SEQ
    INST_FILE=../../stimulus/build/$NAME/$NAME.hex
fi
if [ "$TYPE" == "software" ];then
    CASE=TC_SOFTWARE
    INST_FILE=../../../software/build/$NAME/$NAME.hex
fi
if [ "$TYPE" == "perips" ];then
    CASE=TC_PERIPS
    INST_FILE=../../../software/build/$NAME/$NAME.hex
fi

echo Start simulation at `date`.
echo Instruction from $INST_FILE.
iverilog -g2012 -s tb_top -o sim_software.vvp -I . -I ./testcase -I .. -I ../../../common/general -f ../../filelist/uv_sys.f -f ../../filelist/uv_tb.f -D$CASE -DTIME_UNIT=1ns -DTIME_PREC=1ps $WAVE && vvp sim_software.vvp +SEED=$SEED +INST_FILE=$INST_FILE +STI_NAME=$NAME
echo End simulation at `date`.
