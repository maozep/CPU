// program_addi_test.asm -- ADDI instruction validation
// Initial register values (injected by testbench): R1=5, R2=10
//
// Expected results:
//   R3 = 15  (ADDI R3, R1, 10  => 5+10)
//   R4 = 2   (ADDI R4, R1, -3  => 5-3)
//   R5 = 10  (ADDI R5, R0, 10  => 0+10)
//   R6 = 41  (ADDI R6, R2, 31  => 10+31, max positive imm)
//   R7 = 234 (ADDI R7, R2, -32 => 10-32 = -22 = 234 wrap-around)

ADDI R3, R1, 10   // R3 = R1 + 10 = 5 + 10 = 15
ADDI R4, R1, -3   // R4 = R1 + (-3) = 5 - 3 = 2
ADDI R5, R0, 10   // R5 = R0 + 10 = 0 + 10 = 10 (R0 always 0)
ADDI R6, R2, 31   // R6 = R2 + 31 = 10 + 31 = 41 (max positive imm)
ADDI R7, R2, -32  // R7 = R2 + (-32) = 10 - 32 = -22 = 234 (wrap)
HALT
