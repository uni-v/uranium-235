# Windows
.\sim_inst_seq.bat inst_seq_01_add
.\sim_inst_seq.bat inst_seq_02_ldst
.\sim_inst_seq.bat inst_seq_03_jmp
.\sim_inst_seq.bat inst_seq_04_loop

.\sim_riscv_tests.bat isa rv32ui-p-add
.\sim_riscv_tests.bat isa rv32ui-p-addi
.\sim_riscv_tests.bat isa rv32ui-p-and
.\sim_riscv_tests.bat isa rv32ui-p-andi

.\sim_software.bat HelloWorld
.\sim_software.bat Dhrystone
.\sim_software.bat CoreMark

.\sim_perips.bat TestTimer
.\sim_perips.bat TestUART
.\sim_perips.bat TestSPI

# Linux
./sim_inst_seq.sh inst_seq_01_add
./sim_inst_seq.sh inst_seq_02_ldst
./sim_inst_seq.sh inst_seq_03_jmp
./sim_inst_seq.sh inst_seq_04_loop

./sim_riscv_tests.sh isa rv32ui-p-add
./sim_riscv_tests.sh isa rv32ui-p-addi
./sim_riscv_tests.sh isa rv32ui-p-and
./sim_riscv_tests.sh isa rv32ui-p-andi

./sim_software.sh HelloWorld
./sim_software.sh Dhrystone
./sim_software.sh CoreMark

./sim_perips.sh TestTimer
./sim_perips.sh TestUART
./sim_perips.sh TestSPI
