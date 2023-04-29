APP=None
if [ -z "$1" ];then
    APP=Hello;
else
    APP=$1
fi
ls ./build/$APP > /dev/null 2> /dev/null && make clean -C ./build/$APP -f ../../Makefile APP=$APP
