# CPU Simulator - Quick Start Guide

## ⚡ TL;DR - Get Started in 30 Seconds

```bash
# Test the simulator immediately (Python)
cd Simple-8bit-CPU-Verilog
python tools/simulator.py tests/program.hex
```

Expected output: Shows instruction trace, ends with `HALT -- Execution stopped` and final register state.

## 📋 What You Have

| Component | File | Purpose |
|-----------|------|---------|
| **Python Simulator** | `tools/simulator.py` | Behavioral simulator (works immediately) |
| **C++ Simulator** | `tools/simulator.cpp` | Alternative implementation (compile with g++) |
| **Verification Tool** | `tools/verify_simulator.py` | Parse and compare outputs |
| **Full Docs** | `SIMULATOR.md` | Complete reference & troubleshooting |
| **Summary** | `SIMULATOR_SUMMARY.md` | Implementation details & architecture |

## 🚀 5-Minute Setup

### 1. Run Simulator on Existing Test File
```bash
python tools/simulator.py tests/program.hex
```

### 2. Run on ISA Test Program
```bash
python tools/simulator.py tests/isa_tests/program_simple_com.hex
```

### 3. Verify Both Programs Simultaneously
```bash
python tools/verify_simulator.py tests/program.hex tests/isa_tests/program_simple_com.hex
```

### 4. Compile C++ Version (Optional)
```bash
g++ -o tools/sim_cpu tools/simulator.cpp -std=c++11
./tools/sim_cpu tests/program.hex
```

## 📊 Understanding Simulator Output

```
[LOADER] Loaded 6 instructions from tests/program.hex

=== Starting CPU Simulation ===
Initial PC: 0

  Registers: R0=00 R1=00 R2=00 R3=00 R4=00 R5=00 R6=00 R7=00
[PC=00 | Instr=0x1448] ADD R2 = R1(0) + R1(0) = 0
  Registers: R0=00 R1=00 R2=00 R3=00 R4=00 R5=00 R6=00 R7=00
[PC=01 | Instr=0x0000] HALT -- Execution stopped

=== Simulation Complete ===
Total instructions executed: 2
Final PC: 1
Final Registers: R0=00 R1=00 R2=00 R3=00 R4=00 R5=00 R6=00 R7=00
```

**Breaking it down:**
- `PC=00` → Program counter at step 0
- `Instr=0x1448` → 16-bit instruction hex
- `ADD R2 = R1(0) + R1(0) = 0` → Operation details (operand values in parentheses)
- `Registers: ...` → Full state snapshot after instruction

## 🔍 Comparing Simulator vs Verilog

**Goal**: Verify your Verilog implementation matches the simulator ("Golden Model")

**Process**:
1. Run simulator on HEX file → note final register values
2. Run Verilog testbench on same HEX file → note final register values
3. Compare → should be identical

**Example**:
```bash
# Step 1: Get simulator output
python tools/simulator.py tests/program.hex > sim_result.txt
# Look at "Final Registers" line

# Step 2: Run Verilog
iverilog -o sim/cpu_sim tests/unit_tests/tb_cpu.v src/cpu.v src/pc.v src/imem.v src/control_unit.v src/regfile.v src/alu.v
vvp sim/cpu_sim
# Look for register values in output

# Step 3: Compare
# Both should show: R0=00 R1=00 ... R7=00 (or whatever the program produces)
```

## 📚 ISA Quick Reference

| Instruction | Format | Example |
|-------------|--------|---------|
| `ADD rd, rs1, rs2` | `[0x1 \| rd \| rs1 \| rs2]` | Opcode 1, add R1+R1→R2 |
| `SUB rd, rs1, rs2` | `[0x2 \| rd \| rs1 \| rs2]` | Opcode 2, subtract |
| `AND rd, rs1, rs2` | `[0x3 \| rd \| rs1 \| rs2]` | Opcode 3, bitwise AND |
| `OR rd, rs1, rs2` | `[0x4 \| rd \| rs1 \| rs2]` | Opcode 4, bitwise OR |
| `BEQ rs1, rs2, offset` | `[0x5 \| rs1 \| rs2 \| offset]` | Branch if equal |
| `BNE rs1, rs2, offset` | `[0x6 \| rs1 \| rs2 \| offset]` | Branch if not equal |
| `HALT` | `[0x0 \| ...]` | Stop execution |

**Note**: All registers R0-R7 are 8-bit. Branch offsets are signed 6-bit (-32 to +31).

## 🛠️ Troubleshooting

### Simulator Won't Start
```
python: No module named 'simulator'
```
**Fix**: Make sure you're in the repository root directory
```bash
cd Simple-8bit-CPU-Verilog
python tools/simulator.py tests/program.hex
```

### File Not Found Error
```
[ERROR] Cannot open file: tests/program.hex
```
**Fix**: Use correct relative path from repository root or absolute path
```bash
python tools/simulator.py tests/program.hex        # From repo root
python tools/simulator.py /full/path/to/file.hex  # Absolute path
```

### Python Not Found (Windows)
```
python: command not found
```
**Fix**: Use full path to Python from your venv
```bash
.venv/Scripts/python.exe tools/simulator.py tests/program.hex
```

### Outputs Don't Match
If simulator registers differ from Verilog registers:

1. **Check HEX file is loaded correctly**
   - Look for `[LOADER] Loaded X instructions` message
   
2. **Check final register values**
   - Simulator shows: `Final Registers: R0=... R1=... ...`
   - Find same in Verilog output
   
3. **Trace divergence point**
   - Look at instruction-by-instruction trace
   - Find first instruction where register values differ
   - Debug that instruction specifically

4. **Check instruction encoding**
   - Print the HEX value of diverging instruction
   - Verify opcode, operand positions in both implementations

## 📖 Full Documentation

For detailed information, see:
- **SIMULATOR.md** - Complete reference (ISA tables, algorithms, integration)
- **SIMULATOR_SUMMARY.md** - Implementation overview & architecture

## ✨ Key Features

✅ Supports all 7 ISA opcodes (HALT, ADD, SUB, AND, OR, BEQ, BNE)  
✅ Proper 6-bit signed branch offset calculation  
✅ Detailed instruction execution trace  
✅ Parses HEX files with `//` comments  
✅ Works immediately (Python) or compiles with g++ (C++)  
✅ No external dependencies  
✅ Production-ready error handling  

## 🎯 Next Steps

1. **Run it**: `python tools/simulator.py tests/program.hex`
2. **Verify correctness**: Compare with your Verilog output
3. **Create test programs**: Write `.asm` files and assemble them
4. **Debug issues**: Use detailed trace to find mismatches
5. **Integrate into CI/CD**: Add simulator verification to your build pipeline

---

**Questions?** See SIMULATOR.md for comprehensive documentation.
