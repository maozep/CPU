# CPU Behavioral Simulator (Golden Model)

## Overview

The C++ behavioral simulator is a **Golden Model** implementation of your 16-bit RISC CPU. It executes the same HEX files as your Verilog RTL implementation, enabling you to verify logical correctness and debug ISA behavior.

Both **C++** and **Python** versions are provided:
- **`simulator.cpp`** - Full C++ implementation (requires g++ compiler)
- **`simulator.py`** - Python version (works immediately with Python 3+)

## Features

- ✅ Reads `.hex` files (4-digit hex per line, supports `//` comments)
- ✅ Full Fetch-Decode-Execute loop
- ✅ Complete ISA support (ALU ops, branches, HALT)
- ✅ Detailed instruction trace (PC, opcode, register updates)
- ✅ Register state snapshot after each instruction  
- ✅ Proper sign-extension for 6-bit branch offsets
- ✅ PC wrapping at 256-word boundary
- ✅ Demo mode (`--demo`) to seed non-zero register values quickly
- ✅ Built-in self-test mode (`--self-test`) for critical ISA edge cases
- ✅ Max-steps guard for loop-safety validation

## ISA Reference

### R-Type Instructions (ALU Operations)
Format: `[Opcode 4b][Rd 3b][Rs1 3b][Rs2 3b][Reserved 3b]`

| Mnemonic | Opcode | Description |
|----------|--------|-------------|
| ADD rd, rs1, rs2 | 0x1 | rd ← rs1 + rs2 |
| SUB rd, rs1, rs2 | 0x2 | rd ← rs1 - rs2 |
| AND rd, rs1, rs2 | 0x3 | rd ← rs1 & rs2 |
| OR rd, rs1, rs2  | 0x4 | rd ← rs1 \| rs2 |

### I-Type Immediate Instruction
Format: `[Opcode 4b][Rd 3b][Rs1 3b][Signed_Imm 6b]`

| Mnemonic | Opcode | Description |
|----------|--------|-------------|
| ADDI rd, rs1, imm6 | 0x7 | rd ← rs1 + sign_extend(imm6) |

Immediate range: **-32 to +31** (signed 6-bit)

### I-Type Branch Instructions
Format: `[Opcode 4b][Rs1 3b][Rs2 3b][Signed_Offset 6b]`

| Mnemonic | Opcode | Description |
|----------|--------|-------------|
| BEQ rs1, rs2, offset | 0x5 | if (rs1 == rs2) PC ← (PC+1) + offset |
| BNE rs1, rs2, offset | 0x6 | if (rs1 != rs2) PC ← (PC+1) + offset |

Branch offsets are signed 6-bit values: **-32 to +31**

### System Instruction
| Mnemonic | Opcode | Description |
|----------|--------|-------------|
| HALT | 0x0 | Stop execution |

## Usage

### Python Simulator (Recommended - Works Immediately)

```bash
# Basic usage
python tools/simulator.py <hex_file>

# Example
python tools/simulator.py tests/program.hex
python tools/simulator.py tests/isa_tests/program_simple_com.hex

# Demo + self-tests
python tools/simulator.py tests/program.hex --demo
python tools/simulator.py --self-test
```

### C++ Simulator (If g++ is installed)

```bash
# Compile
g++ -o tools/sim_cpu tools/simulator.cpp -std=c++11

# Run
./tools/sim_cpu <hex_file>

# Example
./tools/sim_cpu tests/program.hex

# Demo + self-tests
./tools/sim_cpu tests/program.hex --demo
./tools/sim_cpu --self-test
```

### Windows (MSYS2) One-Command Flow

```powershell
C:\msys64\usr\bin\bash.exe -lc 'export PATH=/ucrt64/bin:$PATH; cd /c/Users/LENOVO/Desktop/cursor/Simple-8bit-CPU-Verilog; g++ tools/simulator.cpp -o tools/sim_cpu.exe -std=c++11 && ./tools/sim_cpu.exe tests/program.hex --demo'
```

## Validation Coverage

Latest validated checks include:

1. Python simulator self-tests (`--self-test`): 5/5 pass (includes ADDI)
2. C++ simulator self-tests (`--self-test`): 5/5 pass (includes ADDI)
3. Verilog PC critical edge testbench (`tests/unit_tests/tb_pc.v`) now covers:
  - BEQ with max positive offset `+31`
  - BEQ with min negative offset `-32`
  - 8-bit PC wrap-around after large positive branches
  - HALT freeze/release behavior after branch sequences

## Output Format

Each line of execution shows:

```
  Registers: R0=00 R1=00 R2=00 R3=00 R4=00 R5=00 R6=00 R7=00
[PC=XX | Instr=0xXXXX] <OPERATION_DETAILS>
```

**Example output:**

```
[PC=00 | Instr=0x1448] ADD R2 = R1(5) + R1(5) = 10
[PC=01 | Instr=0x24a8] SUB R3 = R2(10) - R1(5) = 5
[PC=02 | Instr=0x38a8] AND R4 = R2(10) & R1(5) = 0
[PC=03 | Instr=0x4a48] OR  R5 = R1(5) | R1(5) = 5
[PC=04 | Instr=0x0000] HALT -- Execution stopped
```

## Comparing Simulator vs Verilog

To verify correctness, run both simulators/Verilog against the same HEX file:

1. **Python/C++ Simulators** show the "ground truth" behavior
2. **Verilog testbenches** should produce identical register state transitions
3. If outputs differ, the ISA encoding or execution logic needs debugging

## Example: Verifying BEQ Instruction

Create a test HEX file with BEQ and trace both:

```
# test_beq.hex
5000  # BEQ R0, R0, 0  (always true, branches to PC+1+0 = PC+1, no-op)
1240  # ADD R1, R1, R1
0000  # HALT
```

Run simulator:
```bash
python tools/simulator.py test_beq.hex
```

Expected trace:
```
[PC=00 | Instr=0x5000] BEQ R0(0) == R0(0) ? YES -> PC = 1 + 0 = 1
[PC=01 | Instr=0x1240] ADD R1 = R1(0) + R1(0) = 0
[PC=02 | Instr=0x0000] HALT -- Execution stopped
```

If your Verilog generates identical register states, the implementation is correct.

## Debugging Tips

1. **Check branch offset calculations** - offset must be signed 6-bit (-32..+31)
2. **Verify register encoding** - ISA uses Rd, Rs1, Rs2 positions specific to format
3. **Compare with Verilog trace** - Look for PC mismatches or wrong register updates
4. **Use intermediate hex files** - Create small test programs, step through them
5. **Check comments** - HEX files can include `//` comments for manual debugging

## Architecture Details

### CPU State
- **Registers**: 8 registers (R0-R7), 8-bit unsigned
- **Memory**: 256 words of instruction memory, 16-bit per word
- **PC**: 8-bit, automatically wraps at 256

### Execution Model
1. **Fetch**: Load instruction at PC from memory
2. **Decode**: Extract opcode and operands
3. **Execute**: Perform operation, update registers or PC
4. **Increment**: PC ← PC+1 (except for HALT or taken branches)

### Sign Extension
6-bit signed offsets are sign-extended to handle:
- Forward branches: offset = +1 to +31
- Backward branches: offset = -32 to -1

## Verification Tool

A dedicated verification script (`tools/verify_simulator.py`) can run the simulator on multiple HEX files and extract final register state for comparison:

```bash
python tools/verify_simulator.py tests/program.hex tests/isa_tests/program_simple_com.hex
```

Output shows per-file register snapshots and a pass/fail summary.

## Troubleshooting

### File Not Found Error
```
[ERROR] Cannot open file: tests/program.hex
```
**Fix**: Use correct relative path from repository root or absolute path.

### Python Not Found (Windows)
```
python: command not found
```
**Fix**: Use full path to Python from your venv:
```bash
.venv/Scripts/python.exe tools/simulator.py tests/program.hex
```

### Outputs Don't Match Verilog
1. Check HEX file is loaded correctly (look for `[LOADER] Loaded X instructions`)
2. Compare final register values line by line
3. Find the first instruction where register values diverge
4. Verify opcode and operand bit positions in both implementations

## Future Enhancements

- [ ] Implement memory-mapped I/O (LW, SW instructions)
- [ ] Add cycle count / performance profiling
- [ ] Generate VCD (Value Change Dump) for waveform comparison
- [ ] Compare register state with Verilog simulation output automatically

