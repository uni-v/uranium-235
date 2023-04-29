name="inst_seq_01_add"
if [ "$#" -ge 1 ]; then
  name=$1
fi
mkdir ./build/$name
riscv-none-embed-as -o ./build/%name%/%name%.o  ./asm/%name%.S
riscv-none-embed-ld -T ./env/link_asm.lds -o ./build/%name%/%name%.elf ./build/%name%/%name%.o
riscv-none-embed-objcopy -O binary ./build/%name%/%name%.elf ./build/%name%/%name%.bin
riscv-none-embed-objcopy -O verilog ./build/%name%/%name%.elf ./build/%name%/%name%.hex
riscv-none-embed-objdump -D ./build/%name%/%name%.elf > ./build/%name%/%name%.dump
sed -i 's/@8/@0/g' ./build/%name%/%name%.hex
