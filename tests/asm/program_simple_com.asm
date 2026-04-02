; ISA smoke test program (matches tests/isa_tests/program_simple_com.hex)

    ADD R3, R1, R1
    SUB R4, R1, R1
    OR  R5, R1, R1
    OR  R6, R2, R1
    OR  R7, R2, R2
    AND R5, R1, R1
    AND R6, R2, R1
    AND R7, R2, R2
    HALT
