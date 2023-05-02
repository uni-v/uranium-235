The Uranium-235 Open-source Processor
=====================================

-----------
## Overview
The Uranium-V project contains a series of RISC-V cores, where the Uranium-235 (U235) core is an open-source RISC-V processor, implemented in Verilog HDL (IEEE-1634). U235 is a single issued in-order core with 5-stage pipeline. It is a low-power implementation for basic RV32I ISA and M extension (i.e., RV32IM). (In contrast, U238 is another 8-stage out-of-order processor in development for high-performance applications.)

The 5 stages are Instruction Fetching (IF), Instruction Decoding (ID), Execution (EX), Memory Access (MA) and Write Back (WB). A bypass network is added to avoid pipeline hazards. For simplicity, static BTFN branch prediction strategy is adopted. The branch predictin unit will be improved in future.

The U235 SOC is provided for complete processor functions. There are two kind of SOC configurations: DAM-based version and cache-based version. The Directly Accessed Memory (DAM) is connected to core directly and can be accessed with fixed delay (like the tightly coupled memory of ARM). The DAM-based SOC is usually used for size-limited applications as the memory cannot be extended arbitrarily. In contrast, the cache-based SOC (to be implemented) can be used for larger applications with multi-level memory system.

![The DAM-based SOC](https://github.com/uni-v/uranium-235/blob/master/doc/pics/uv_soc_arch_dam_version.png "The DAM-based SOC")

![The cache-based SOC](https://github.com/uni-v/uranium-235/blob/master/doc/pics/uv_soc_arch_cache_version.png "The cache-based SOC")

The U235 core is mainly focus on research and education purpose. It is allowed to be used commercially but should be verificated carefully.

--------------
## Quick Start

### Checkout the Code
```shell
git clone https://github.com/uni-v/uranium-235.git
cd uranium-235
```

### Install Simulation Tools
Icarus Verilog is the default simulator of this project. It can be installed by
```
apt-get install iverilog
```
for Debian/Ubuntu, and
```
yum install iverilog
```
for CentOS.

The latest version can be built from source code. Please refer to https://github.com/steveicarus/iverilog for more infomation. For windows users, the prebuilt .exe install packages can be obtained from http://bleyer.org/icarus/.

If you have other simulators such as VCS or ModelSim, the run scripts at testbench directory should be updated with commands for these tools. For example, to run ISA regression with VCS, you have to edit `test/testbench/tb_uv_sys/sim.sh` and replace the iverilog command to VCS one.

### Run ISA Regression
```shell
cd regression
python regress_isa.py
```

### Run Hello World
```shell
cd test/testbench/tb_uv_sys
./sim.sh software HelloWorld
```

### Run Benchmarks
```shell
cd test/testbench/tb_uv_sys
./sim.sh software Dhrystone
./sim.sh software CoreMark
```

With default configuration, the Dhrystone score of U235 is 1.39 DMIPS/MHz, and its CoreMark score is 2.24 CoreMark/MHz.

### Compile Softwares
The RISC-V GNU toolchain can be obtained from https://github.com/riscv-software-src/riscv-gnu-toolchain. For conveniency, we can download the prebuilt package from https://github.com/ilg-archived/riscv-none-gcc/releases/.

Suppose the prebuilt toolchain is used, and set up the RISCV environment variable at first:
```shell
export RISCV=/path/to/riscv/prebuilt/toolchain
export PATH=$PATH:$RISCV/bin
```

Build the hello world example:
```shell
cd software
mkdir build/HelloWorld
make -C ./build/HelloWorld -f ../../Makefile APP=HelloWorld
```

If the toolchain is built from source, the `PREFIX` variable must be updated. You can edit `software/Makefile` or specify the value by command option. For example,
```shell
make -C ./build/Hello -f ../../Makefile APP=Hello PREFIX=riscv32-unknown-elf-
```

-----------------------
## Software Development
New software project must follow the same directory hierarchy as examples.
```
software
    |- app
        |- APP_NAME
            |- include
                |- INCLUDE_FILES
            |- src
                |- SOURCE_FILES
            |- Makefile
```

The source files and extra compiler/linker flags must be specified in the Makefile under APP_NAME directory.

--------------
## Future Work
* RVC extension.
* L1/L2 caches.
* More effective branch prediction.
* Instruction prefeching.
* DMA subsystem.
* Verification of peripherals.
* RTOS support.
