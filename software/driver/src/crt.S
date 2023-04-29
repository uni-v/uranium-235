# See LICENSE for license details.

#include "encoding.h"

#if __riscv_xlen == 64
	#define LREG 		ld
	#define SREG 		sd
	#define REGBYTES 	8
#else
	#define LREG 		lw
	#define SREG 		sw
	#define REGBYTES 	4
#endif

.section ".init"
.globl _start

_start:
	# Clear registers.
	li  x1,  0
	li  x2,  0
	li  x3,  0
	li  x4,  0
	li  x5,  0
	li  x6,  0
	li  x7,  0
	li  x8,  0
	li  x9,  0
	li  x10, 0
	li  x11, 0
	li  x12, 0
	li  x13, 0
	li  x14, 0
	li  x15, 0
	li  x16, 0
	li  x17, 0
	li  x18, 0
	li  x19, 0
	li  x20, 0
	li  x21, 0
	li  x22, 0
	li  x23, 0
	li  x24, 0
	li  x25, 0
	li  x26, 0
	li  x27, 0
	li  x28, 0
	li  x29, 0
	li  x30, 0
	li  x31, 0

	# Enable FPU and accelerator if present
	li t0, MSTATUS_FS | MSTATUS_XS
	csrs mstatus, t0

	# make sure XLEN agrees with compilation choice
	li t0, 1
	slli t0, t0, 31
#if __riscv_xlen == 64
  	bgez t0, 1f
#else
  	bltz t0, 1f
#endif
2:
	li a0, 1
	sw a0, tohost, t0
	j 2b
1:

#ifdef __riscv_flen
	# initialize FPU if we have one
	la t0, 1f
	csrw mtvec, t0

	fssr    x0
	fmv.s.x f0, x0
	fmv.s.x f1, x0
	fmv.s.x f2, x0
	fmv.s.x f3, x0
	fmv.s.x f4, x0
	fmv.s.x f5, x0
	fmv.s.x f6, x0
	fmv.s.x f7, x0
	fmv.s.x f8, x0
	fmv.s.x f9, x0
	fmv.s.x f10,x0
	fmv.s.x f11,x0
	fmv.s.x f12,x0
	fmv.s.x f13,x0
	fmv.s.x f14,x0
	fmv.s.x f15,x0
	fmv.s.x f16,x0
	fmv.s.x f17,x0
	fmv.s.x f18,x0
	fmv.s.x f19,x0
	fmv.s.x f20,x0
	fmv.s.x f21,x0
	fmv.s.x f22,x0
	fmv.s.x f23,x0
	fmv.s.x f24,x0
	fmv.s.x f25,x0
	fmv.s.x f26,x0
	fmv.s.x f27,x0
	fmv.s.x f28,x0
	fmv.s.x f29,x0
	fmv.s.x f30,x0
	fmv.s.x f31,x0
1:
#endif

	# initialize trap vector
	la t0, trap_entry
	csrw mtvec, t0

	# Initialize global pointer.
.option push
.option norelax
  	la gp, __global_pointer$
.option pop

	# Initialize stack pointer.
	la sp, _sp

	# Initialize data section.
	la a0, _data_lma
	la a1, _data
	la a2, _edata
	bgeu a1, a2, 2f
1:
	lw t0, (a0)
	sw t0, (a1)
	addi a0, a0, 4
	addi a1, a1, 4
	bltu a1, a2, 1b
2:

	# Initialize bss section.
	la a0, __bss_start
	la a1, __bss_end
	bgeu a0, a1, 2f
1:
	sw zero, (a0)
	addi a0, a0, 4
	bltu a0, a1, 1b
2:

	/* Call global constructors */
	la a0, __libc_fini_array
	call atexit
	call __libc_init_array

	/* argc = argv = 0 */
	li a0, 0
	li a1, 0
	call main
	tail exit

1:
	j 1b

.globl trap_entry

.align 2
trap_entry:
	addi sp, sp, -16*REGBYTES
	SREG x1,  0*REGBYTES(sp)
	SREG x5,  1*REGBYTES(sp)
	SREG x6,  2*REGBYTES(sp)
	SREG x7,  3*REGBYTES(sp)
	SREG x10, 4*REGBYTES(sp)
	SREG x11, 5*REGBYTES(sp)
	SREG x12, 6*REGBYTES(sp)
	SREG x13, 7*REGBYTES(sp)
	SREG x14, 8*REGBYTES(sp)
	SREG x15, 9*REGBYTES(sp)
	SREG x16, 10*REGBYTES(sp)
	SREG x17, 11*REGBYTES(sp)
	SREG x28, 12*REGBYTES(sp)
	SREG x29, 13*REGBYTES(sp)
	SREG x30, 14*REGBYTES(sp)
	SREG x31, 15*REGBYTES(sp)

	csrr a0, mcause
	csrr a1, mepc
	mv a2, sp
	jal handle_trap
	csrw mepc, a0

	# Remain in M-mode after eret
	# li t0, MSTATUS_MPP
	# csrs mstatus, t0

	LREG x1,  0*REGBYTES(sp)
	LREG x5,  1*REGBYTES(sp)
	LREG x6,  2*REGBYTES(sp)
	LREG x7,  3*REGBYTES(sp)
	LREG x10, 4*REGBYTES(sp)
	LREG x11, 5*REGBYTES(sp)
	LREG x12, 6*REGBYTES(sp)
	LREG x13, 7*REGBYTES(sp)
	LREG x14, 8*REGBYTES(sp)
	LREG x15, 9*REGBYTES(sp)
	LREG x16, 10*REGBYTES(sp)
	LREG x17, 11*REGBYTES(sp)
	LREG x28, 12*REGBYTES(sp)
	LREG x29, 13*REGBYTES(sp)
	LREG x30, 14*REGBYTES(sp)
	LREG x31, 15*REGBYTES(sp)
	addi sp, sp, 16*REGBYTES
	mret

.section ".tdata.begin"
.globl _tdata_begin
_tdata_begin:

.section ".tdata.end"
.globl _tdata_end
_tdata_end:

.section ".tbss.end"
.globl _tbss_end
_tbss_end:

.section ".tohost","aw",@progbits
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0
