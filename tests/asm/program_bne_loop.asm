; Branch/loop demo using signed 6-bit offset
; Loop until R1 == R2, then halt.

start:
    ADD R1, R0, R0
loop:
    ADD R1, R1, R7
    BNE R1, R2, loop
    HALT
