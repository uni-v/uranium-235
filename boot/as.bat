:: See LICENSE for license details.

riscv-none-embed-as .\boot.S -o .\boot.o
riscv-none-embed-objcopy -O binary .\boot.o .\boot.bin
riscv-none-embed-objcopy -O verilog .\boot.o .\boot.hex
riscv-none-embed-objdump -D .\boot.o > .\boot.dump
