# Test branch instructions.

.text
.global _start

_start:
    li      a0, 0x80008010
    jal     ra, func
    sw      a0, 0(t0)

_end:
    j       _end

func:
    li      t0, 0x80008000
    li      t1, 0x1
loop:
    sll     t1, t1, 1
    addi    t0, t0, 1
    bne     t0, a0, loop
    mv      a0, t1
    jalr    x0, 0(ra)
