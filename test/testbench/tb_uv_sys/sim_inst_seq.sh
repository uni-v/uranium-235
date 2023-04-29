SEED=`date +%Y%m%d%H%M%S`
NAME=none
WAVE=none

if [ -z "$1" ];then
    NAME=inst_seq_01_add;
else
    NAME=$1
fi
if [ -z "$2" ];then
    WAVE="-DDUMP_NONE";
else
    WAVE="-DDUMP_VCD"
fi
INST_FILE=../../stimulus/build/$NAME/$NAME.hex
echo Instruction from $INST_FILE
iverilog -g2012 -s tb_top -o sim_inst_seq.vvp -I . -I ./testcase -I .. -I ../../../common/general -f ../../filelist/uv_sys.f -f ../../filelist/uv_tb.f -DAUTO_FINISH -DTC_INST_SEQ -DTIME_UNIT=1ns -DTIME_PREC=1ps $WAVE && vvp sim_inst_seq.vvp +SEED=$SEED +INST_FILE=$INST_FILE +STI_NAME=$NAME