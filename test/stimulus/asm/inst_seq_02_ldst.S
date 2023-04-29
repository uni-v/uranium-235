# Test load-store instructions.

.text
.global _start

_start:
    li  x6, 0xcafebabe
    li  x7, 0x80008010
    sw  x6, 0(x7)
    sw  x7, 4(x7)
    lw  x8, 4(x7)
    lh  x5, 0(x8) # 0x3(x8)
    lb  x4, 0(x8) # 0x1(x8)
    lw  x3, 0(x8)
    lhu x2, 0(x8)
    lbu x1, 0(x8)
_end:
    j   _end
