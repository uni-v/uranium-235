# Test jump instructions.

.text
.global _start

_start:
    li      a0, 0x23456789
    li      a1, 0xabcdef01
    li      t0, 0x80008010
    jal     ra, func
    sw      a0, 0(t0)

_end:
    j       _end

func:
    add     a0, a0, a1
    jalr    s0, 0(ra)
