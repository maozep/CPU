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

## ISA Reference

### R-Type Instructions (ALU Operations)
Format: `[Opcode 4b][Rd 3b][Rs1 3b][Rs2 3b][Reserved 3b]`

| Mnemonic | Opcode | Description |
|----------|--------|-------------|
| ADD rd, rs1, rs2 | 0x1 | rd ← rs1 + rs2 |
| SUB rd, rs1, rs2 | 0x2 | rd ← rs1 - rs2 |
| AND rd, rs1, rs2 | 0x3 | rd ← rs1 & rs2 |
| OR rd, rs1, rs2  | 0x4 | rd ← rs1 \| rs2 |

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
python simulator.py <hex_file>

# Example
python simulator.py tests/program.hex
python simulator.py tests/isa_tests/program_simple_com.hex
```

### C++ Simulator (If g++ is installed)

```bash
# Compile
g++ -o sim_cpu simulator.cpp -std=c++11

# Run
./sim_cpu <hex_file>

# Example
./sim_cpu tests/program.hex
```

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
python simulator.py test_beq.hex
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

## Integration with Build System

Currently the Python simulator is standalone. To integrate into `e2e_run.py`:

```python
# In e2e_run.py
def run_simulator(repo_root, hex_file):
    """Run behavioral simulator for verification"""
    cmd = [
        get_python_exe(repo_root),
        os.path.join(repo_root, "tools/simulator.py"),
        hex_file
    ]
    return run_command(cmd)
```

## Future Enhancements

- [ ] Add support for ADDI instruction (immediate arithmetic)
- [ ] Implement memory-mapped I/O (LW, SW instructions)
- [ ] Add cycle count / performance profiling
- [ ] Generate VCD (Value Change Dump) for waveform comparison
- [ ] Compare register state with Verilog simulation output automatically

