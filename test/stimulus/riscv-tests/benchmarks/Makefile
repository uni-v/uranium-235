#=======================================================================
# UCB VLSI FLOW: Makefile for riscv-bmarks
#-----------------------------------------------------------------------
# Yunsup Lee (yunsup@cs.berkeley.edu)
#

XLEN ?= 32

default: all

src_dir = ..

instname = riscv-bmarks
instbasedir = $(UCB_VLSI_HOME)/install

#--------------------------------------------------------------------
# Sources
#--------------------------------------------------------------------

bmarks = \
	median \
	qsort \
	rsort \
	towers \
	vvadd \
	multiply \
	mm \
	dhrystone \
	spmv \
	mt-vvadd \
	mt-matmul \
	pmp \

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

RISCV_PREFIX ?= riscv-none-embed-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -march=rv32i -mabi=ilp32 -DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common
RISCV_LINK ?= $(RISCV_GCC) -T $(src_dir)/common/test.ld $(incs)
RISCV_LINK_OPTS ?= --specs=nano.specs --specs=nosys.specs -static -nostartfiles -lm -lgcc -Wl,--gc-sections -Wl,--check-sections -T $(src_dir)/common/test.ld
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump --disassemble-all
# --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data
RISCV_OBJCOPY ?= $(RISCV_PREFIX)objcopy
RISCV_SIM ?= spike

incs  += -I$(src_dir)/../env -I$(src_dir)/common $(addprefix -I$(src_dir)/, $(bmarks))
objs  :=

define compile_template
$(1).elf: $(wildcard $(src_dir)/$(1)/*) $(wildcard $(src_dir)/common/*)
	$$(RISCV_GCC) $$(incs) $$(RISCV_GCC_OPTS) -o $$@ $(wildcard $(src_dir)/$(1)/*.c) $(wildcard $(src_dir)/common/*.c) $(wildcard $(src_dir)/common/*.S) $$(RISCV_LINK_OPTS)
endef

define dump_template
$(1).dump: $(1).elf
	$$(RISCV_OBJDUMP) $$< > $$@
endef

define copy_template
$(1).hex: $(1).elf
	$$(RISCV_OBJCOPY) -O verilog $$< $$@
	sed -i 's/@8/@0/g' $$@
$(1).bin: $(1).elf
	$$(RISCV_OBJCOPY) -O binary $$< $$@
endef

$(foreach bmark,$(bmarks),$(eval $(call compile_template,$(bmark))))
$(foreach bmark,$(bmarks),$(eval $(call dump_template,$(bmark))))
$(foreach bmark,$(bmarks),$(eval $(call copy_template,$(bmark))))

#------------------------------------------------------------
# Build and run benchmarks on riscv simulator

bmarks_riscv_elf  = $(addsuffix .elf,  $(bmarks))
bmarks_riscv_hex  = $(addsuffix .hex,  $(bmarks))
bmarks_riscv_bin  = $(addsuffix .bin,  $(bmarks))
bmarks_riscv_dump = $(addsuffix .dump, $(bmarks))

riscv: $(bmarks_riscv_dump) $(bmarks_riscv_hex) $(bmarks_riscv_bin)

junk += $(bmarks_riscv_elf) $(bmarks_riscv_dump) $(bmarks_riscv_hex) $(bmarks_riscv_bin)

#------------------------------------------------------------
# Default

all: riscv

#------------------------------------------------------------
# Install

date_suffix = $(shell date +%Y-%m-%d_%H-%M)
install_dir = $(instbasedir)/$(instname)-$(date_suffix)
latest_install = $(shell ls -1 -d $(instbasedir)/$(instname)* | tail -n 1)

install:
	mkdir $(install_dir)
	cp -r $(bmarks_riscv_bin) $(bmarks_riscv_dump) $(install_dir)

install-link:
	rm -rf $(instbasedir)/$(instname)
	ln -s $(latest_install) $(instbasedir)/$(instname)

#------------------------------------------------------------
# Clean up

clean:
	rm -rf $(objs) $(junk)
