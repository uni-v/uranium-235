# See LICENSE for license details.

APP             := Hello

PREFIX          := riscv-none-embed-
RV_ARCH         := rv32im
RV_ABI          := ilp32

CC              := $(PREFIX)gcc
GXX             := $(PREFIX)g++
OBJDUMP         := $(PREFIX)objdump
OBJCOPY         := $(PREFIX)objcopy
AR              := $(PREFIX)ar
SIZE            := $(PREFIX)size

BASE_DIR        := ../..
BUILD_DIR       := $(BASE_DIR)/build/$(APP)

APP_DIR         := $(BASE_DIR)/app/$(APP)
APP_INC         := $(APP_DIR)/include
APP_SRC         := $(APP_DIR)/src

DRIVER_DIR      := $(BASE_DIR)/driver
DRIVER_INC      := $(DRIVER_DIR)/include
DRIVER_SRC      := $(DRIVER_DIR)/src

PRINT_FLOAT     := 0
LD_SCRIPT       := $(DRIVER_DIR)/uv_link.ld

.PHONY: default
default: $(APP).elf

DRIVER_INCS     := encoding.h
DRIVER_ASMS     := crt.S
DRIVER_SRCS     := init.c

DRIVER_SRCS     += close.c
DRIVER_SRCS     += exit.c
DRIVER_SRCS     += fstat.c
DRIVER_SRCS     += isatty.c
DRIVER_SRCS     += lseek.c
DRIVER_SRCS     += read.c
DRIVER_SRCS     += sbrk.c
DRIVER_SRCS     += write.c
DRIVER_SRCS     += write_hex.c
DRIVER_SRCS     += handler.c
DRIVER_SRCS     += uv_sys.c

APP_INCS        :=
APP_ASMS        :=
APP_SRCS        :=

CFLAGS          :=
LDFLAGS         :=

include $(APP_DIR)/Makefile

CFLAGS  += -march=$(RV_ARCH) -mabi=$(RV_ABI) -I$(DRIVER_INC) -I$(APP_INC) -O2 -g -ffunction-sections -fdata-sections -fno-inline -fno-common -falign-labels=4 -falign-functions=4 -falign-jumps=4 -falign-loops=4

LDFLAGS += -L$(BUILD_DIR) -T $(LD_SCRIPT) -nostartfiles -Wl,--gc-sections -Wl,--check-sections --specs=nano.specs
ifeq ($(PRINT_FLOAT), 1) 
LDFLAGS += -u _printf_float 
endif

DRIVER_ASM_OBJS := $(DRIVER_ASMS:.S=.o)
DRIVER_C_OBJS   := $(DRIVER_SRCS:.c=.o)
APP_ASM_OBJS    := $(APP_ASMS:.S=.o)
APP_C_OBJS      := $(APP_SRCS:.c=.o)
OBJS            := $(DRIVER_ASM_OBJS) $(DRIVER_C_OBJS) $(APP_ASM_OBJS) $(APP_C_OBJS)

INCS            := $(wildcard $(DRIVER_INC)/*.h $(APP_INC)/*.h)
SRCS            := $(wildcard $(DRIVER_SRC)/*.S $(DRIVER_SRC)/*.c $(APP_SRC)/*.c)

$(DRIVER_ASM_OBJS): %.o: $(DRIVER_SRC)/%.S $(INCS)
	@echo "$(OBJS)"
	$(CC) $(CFLAGS) -c -o $@ $<

$(DRIVER_C_OBJS): %.o: $(DRIVER_SRC)/%.c $(INCS)
	$(CC) $(CFLAGS) -include sys/cdefs.h -c -o $@ $<

$(APP_ASM_OBJS): %.o: $(APP_SRC)/%.S $(INCS)
	$(CC) $(CFLAGS) -c -o $@ $<

$(APP_C_OBJS): %.o: $(APP_SRC)/%.c $(INCS)
	$(CC) $(CFLAGS) -include sys/cdefs.h -c -o $@ $<

$(APP).elf: $(OBJS)
	$(CC) $(CFLAGS) $(OBJS) -o $@ $(LDFLAGS)
	$(OBJDUMP) -D $@ > $(APP).dump
	$(OBJDUMP) -D -S $@ > $(APP).src.dump
	$(OBJCOPY) $@ -O verilog $(APP).hex
	sed -i 's/@800/@000/g' $(APP).hex
	$(SIZE) $@

.PHONY: clean
clean:
	rm -f $(OBJS) $(APP).elf $(APP).hex $(APP).dump $(APP).src.dump
