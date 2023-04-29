# Test CSR instructions.

.equ CSR_MVENDORID, 0xf11
.equ CSR_MARCHID  , 0xf12
.equ CSR_MIMPID   , 0xf13
.equ CSR_MHARTID  , 0xf14
.equ CSR_MSTATUS  , 0x300
.equ CSR_MISA     , 0x301
.equ CSR_MCYCLE   , 0xb00
.equ CSR_MINSTRET , 0xb02
.equ CSR_MCNTPRHB , 0x320

.text
.global _start

_start:
    csrwi   CSR_MCNTPRHB, 0
    csrr    s0, CSR_MVENDORID
    csrr    s1, CSR_MARCHID
    csrr    s2, CSR_MIMPID
    li      t1, 0xffffffff
    csrw    CSR_MSTATUS, t1
    csrrci  s3, CSR_MSTATUS, 0x8
    csrr    s4, CSR_MSTATUS
    csrr    s5, CSR_MCYCLE
    csrrwi  s6, CSR_MINSTRET, 0
    csrr    s7, CSR_MISA
    csrwi   CSR_MCNTPRHB, 0x3
_end:
    j       _end
