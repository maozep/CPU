; Default CPU integration program (feeds tests/program.hex)
; Expected final state with R1=1 seed (as in tb_cpu.v):
;   R2=0, R3=2, R4=2, R5=1

    ADD R2, R1, R1
    ADD R3, R1, R1
    SUB R2, R3, R3
    AND R4, R3, R3
    OR  R5, R1, R1
    HALT
