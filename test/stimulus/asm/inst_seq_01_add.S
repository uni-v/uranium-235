# Test load-imm & add instructions.

.text
.global _start

_start:
    li  x6, 0x23456789
    li  x7, 0xabcdef01
    add x5, x6, x7
_end:
    j   _end
