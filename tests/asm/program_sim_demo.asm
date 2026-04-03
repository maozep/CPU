// Test program for C++ simulator - demonstrates various operations
// Initializes R1 with seed value and performs computations

LI R1, 5        // R1 = 5 (pseudo - can use register copy if LI not supported)
ADD R2, R1, R1  // R2 = 5 + 5 = 10
SUB R3, R2, R1  // R3 = 10 - 5 = 5
AND R4, R1, R3  // R4 = 5 & 5 = 5
OR  R5, R2, R1  // R5 = 10 | 5 = 15
HALT            // End execution
