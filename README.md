# Simple 8-bit CPU (Verilog)

![Circuit schematic](screenshot/%D7%A9%D7%A8%D7%98%D7%95%D7%98%20%D7%94%D7%9E%D7%A2%D7%92%D7%9C.png)

*Schematic of the circuit.*

A single-cycle 8-bit CPU implemented in synthesizable Verilog, with a complete toolchain: assembler, behavioral simulators (Python + C++), and a layered test suite covering unit, ISA, and golden-model verification.

## Architecture Overview

| Parameter | Value |
|---|---|
| Datapath width | 8-bit |
| Instruction width | 16-bit |
| Registers | 8 (R0-R7), R0 hard-wired to zero |
| Instruction memory | 256 x 16-bit ROM |
| Data memory | 256 x 8-bit RAM |
| Program counter | 8-bit, wraps at 256 |
| Execution model | Single-cycle (fetch-decode-execute in one clock) |
| Cycle counter | 32-bit hardware counter, exposed as output port |

### Microarchitecture

```
                  +--------+
         +------->|  IMEM  |-------+
         |        | 256x16 |       |
         |        +--------+       |
         |                         v
    +----+----+            +---------------+
    |   PC    |            | Control Unit  |
    | 8-bit   |<-----------|  (decoder)    |
    +---------+   branch/  +-------+-------+
                  jump             |
                  signals          v
              +---------+    +---------+    +---------+
              | RegFile |<-->|   ALU   |<-->|  DMEM   |
              | 8x8-bit |    | 8-bit   |    | 256x8   |
              +---------+    +---------+    +---------+
```

Data flows in a single cycle:
1. **Fetch** -- PC addresses IMEM, producing a 16-bit instruction
2. **Decode** -- Control unit extracts opcode, register addresses, immediate, and control signals
3. **Execute** -- ALU computes result (or SLTI comparator for set-less-than)
4. **Memory** -- LW reads from DMEM, SW writes to DMEM (address = ALU result)
5. **Writeback** -- Result written to register file on rising clock edge

### RTL Modules

| Module | File | Description |
|---|---|---|
| `cpu` | `src/cpu.v` | Top-level integration: wires all modules together, includes write-back mux and cycle counter |
| `pc` | `src/pc.v` | Program counter with reset, halt freeze, branch/jump logic |
| `imem` | `src/imem.v` | 256x16 instruction ROM, loaded via `$readmemh` |
| `control_unit` | `src/control_unit.v` | Combinational decoder: instruction to control signals |
| `regfile` | `src/regfile.v` | 8x8 register file, dual async read, sync write, R0=0 |
| `alu` | `src/alu.v` | 8 operations: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA |
| `dmem` | `src/dmem.v` | 256x8 data RAM, async read, sync write |

## Instruction Set

All 16 opcodes (4-bit, `0x0`-`0xF`) are allocated:

| Opcode | Mnemonic | Format | Behavior |
|---|---|---|---|
| `0x0` | HALT | -- | Freeze PC, stop execution |
| `0x1` | ADD | R-type | `rd = rs1 + rs2` |
| `0x2` | SUB | R-type | `rd = rs1 - rs2` |
| `0x3` | AND | R-type | `rd = rs1 & rs2` |
| `0x4` | OR | R-type | `rd = rs1 \| rs2` |
| `0x5` | BEQ | Branch | `if (rs1 == rs2) PC = PC + 1 + offset` |
| `0x6` | BNE | Branch | `if (rs1 != rs2) PC = PC + 1 + offset` |
| `0x7` | ADDI | I-type | `rd = rs1 + sign_extend(imm6)` |
| `0x8` | LW | I-type | `rd = DMEM[rs1 + sign_extend(imm6)]` |
| `0x9` | SW | S-type | `DMEM[rs1 + sign_extend(imm6)] = rs2` |
| `0xA` | JMP | Jump | `PC = PC + 1 + sign_extend(offset)` |
| `0xB` | XOR | R-type | `rd = rs1 ^ rs2` |
| `0xC` | SLL | R-type | `rd = rs1 << rs2[2:0]` |
| `0xD` | SRL | R-type | `rd = rs1 >> rs2[2:0]` (logical, zero-fill) |
| `0xE` | SRA | R-type | `rd = rs1 >>> rs2[2:0]` (arithmetic, sign-fill) |
| `0xF` | SLTI | I-type | `rd = (rs1 < sign_extend(imm6)) ? 1 : 0` (signed) |

### Instruction Formats

**R-type** (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA):
```
[15:12] opcode | [11:9] rd | [8:6] rs1 | [5:3] rs2 | [2:0] reserved
```

**I-type** (ADDI, LW, SLTI):
```
[15:12] opcode | [11:9] rd | [8:6] rs1 | [5:0] signed immediate (imm6, range: -32..+31)
```

**S-type** (SW):
```
[15:12] opcode | [11:9] rs2 (data) | [8:6] rs1 (base) | [5:0] signed immediate (imm6)
```

**Branch** (BEQ, BNE):
```
[15:12] opcode | [11:9] rs1 | [8:6] rs2 | [5:0] signed offset
```

**Jump** (JMP):
```
[15:12] opcode | [11:6] unused | [5:0] signed offset
```

### Design Notes

- **Shift amounts**: SLL/SRL/SRA use only `rs2[2:0]` (0-7), matching the 8-bit datapath width.
- **SLTI** bypasses the ALU entirely -- a dedicated signed comparator in `cpu.v` feeds the write-back mux.
- **Branch offsets** are relative to `PC+1`, not `PC`. A BEQ with offset=0 falls through to the next instruction.
- **All 16 opcodes are used.** Adding new instructions requires either the funct-field approach (using the unused `instr[2:0]` bits in R-type) or widening the instruction format. See the opcode pressure discussion in project docs.

## Verification

The project uses three independent verification layers. Every instruction is tested at every layer.

### Layer 1: Verilog Unit Tests

Test each RTL module in isolation with direct stimulus. Run with Icarus Verilog (`iverilog` + `vvp`).

| Testbench | Module | What it verifies |
|---|---|---|
| `tb_alu.v` | ALU | All 8 operations across 8x8 value sweep (500+ checks), zero flag, overflow/underflow wrap |
| `tb_control_unit.v` | Decoder | Every opcode (0x0-0xF): correct `alu_op`, `reg_write`, `use_imm`, `mem_read/write`, field extraction |
| `tb_regfile.v` | Registers | Dual async read, sync write, R0 write protection |
| `tb_pc.v` | PC | Reset, halt freeze, BEQ/BNE with max offsets (+31/-32), 8-bit wrap-around |
| `tb_imem.v` | IMEM | ROM load via `$readmemh`, address range |
| `tb_dmem.v` | DMEM | Sync write, async read, boundary addresses, overwrite |
| `tb_cpu.v` | Top-level | End-to-end: loads `program.hex`, runs to HALT, checks final register state |

```bash
# Example: run ALU unit test
iverilog -o sim/alu_sim tests/unit_tests/tb_alu.v src/alu.v
vvp sim/alu_sim
```

### Layer 2: Verilog ISA Tests

Each instruction has a dedicated testbench + HEX program. The testbench loads the HEX, injects register/memory values, runs the CPU to HALT, and checks results. Covers edge cases specific to each instruction.

| Testbench | Instruction | Key edge cases tested |
|---|---|---|
| `tb_simple_com.v` | ADD, SUB, AND, OR | Complementary bit patterns (0xA5/0x5A), overflow wrap, underflow wrap, zero result |
| `tb_xor.v` | XOR | Complementary -> 0xFF, self-XOR -> 0, identity with R0 |
| `tb_sll.v` | SLL | Shift by 1, shift by computed value, shift 0 (identity), shift 7 (max), zero source |
| `tb_srl.v` | SRL | Same pattern as SLL, verifies zero-fill from MSB |
| `tb_sra.v` | SRA | Sign-fill on negative (0x80>>>1=0xC0), zero-fill on positive (0x7F>>>1=0x3F), max shift |
| `tb_slti.v` | SLTI | True/false/equal cases, signed negative (-128 < 0), cross-sign comparison (5 < -1 = false) |
| `tb_addi.v` | ADDI | Positive/negative immediate, wrap-around, max/min imm6, R0 write protection |
| `tb_beq.v` | BEQ | Taken, not taken, R0==R0 edge case, forward offset |
| `tb_bne.v` | BNE | Taken, not taken, self-compare, R0!=Rx edge case |
| `tb_lw.v` | LW | Basic load, max offset, negative offset, unwritten address (returns 0) |
| `tb_sw.v` | SW | Basic store, register base, max offset, untouched memory preserved |
| `tb_jmp.v` | JMP | Forward +1, forward +2, backward -4, skipped instruction verified |

Each testbench also reports the hardware cycle count from the CPU's built-in counter.

```bash
# Example: run XOR ISA test
iverilog -o sim/xor_sim tests/isa_tests/tb_xor.v src/cpu.v src/pc.v src/imem.v src/control_unit.v src/regfile.v src/alu.v src/dmem.v
vvp sim/xor_sim
```

### Layer 3: Behavioral Simulators (Golden Model)

Python and C++ simulators execute the same HEX files as the Verilog, serving as an independent reference implementation. Each has a built-in self-test suite.

| Simulator | Self-tests | Coverage |
|---|---|---|
| `tools/simulator.py` | 12/12 pass | ALU (ADD/SUB/AND/OR), XOR, SLL, SRL, SRA, SLTI, BEQ, BNE, ADDI, LW/SW, JMP, max-steps guard |
| `tools/simulator.cpp` | 12/12 pass | Identical test suite to Python |

The simulators can also run any HEX file with full instruction trace, showing PC, decoded operation, and register state at each step -- useful for debugging mismatches against the Verilog.

```bash
# Run self-tests
python tools/simulator.py --self-test

# Trace a HEX program
python tools/simulator.py tests/isa_tests/program_xor_test.hex

# C++ version
g++ -o tools/sim_cpu tools/simulator.cpp -std=c++11
./tools/sim_cpu --self-test
```

### Verification Summary

| What | How many | Tool |
|---|---|---|
| ALU operations | 500+ value pairs x 8 ops | `tb_alu.v` |
| Decoder opcodes | All 16 (0x0-0xF) | `tb_control_unit.v` |
| ISA instructions | 12 dedicated testbenches | `tests/isa_tests/` |
| Golden model checks | 12 self-tests x 2 languages | `simulator.py`, `simulator.cpp` |
| VCD waveforms | Generated by every testbench | `$dumpfile` / `$dumpvars` |

## Assembler

Two-pass assembler in `tools/tools/assembler.py` converts assembly to HEX.

Supported mnemonics:

```
HALT
ADD  rd, rs1, rs2       SUB  rd, rs1, rs2
AND  rd, rs1, rs2       OR   rd, rs1, rs2
XOR  rd, rs1, rs2
SLL  rd, rs1, rs2       SRL  rd, rs1, rs2       SRA  rd, rs1, rs2
ADDI rd, rs1, imm       SLTI rd, rs1, imm
LW   rd, rs1, imm       SW   rs2, rs1, imm
BEQ  rs1, rs2, label    BNE  rs1, rs2, label
JMP  label
```

Features: label support, signed offset resolution, range validation, optional listing output.

```bash
# Assemble a single file
python tools/tools/assembler.py tests/asm/program_simple_com.asm -o tests/isa_tests/program_simple_com.hex

# Build all default HEX targets
python tools/tools/assemble_all.py
```

## Project Structure

```
src/                        RTL source (7 modules)
  alu.v                       8 ALU operations (ADD/SUB/AND/OR/XOR/SLL/SRL/SRA)
  control_unit.v              Instruction decoder (all 16 opcodes)
  cpu.v                       Top-level integration + cycle counter + SLTI comparator
  dmem.v                      256x8 data memory (RAM)
  imem.v                      256x16 instruction memory (ROM)
  pc.v                        Program counter with branch/jump/halt
  regfile.v                   8x8 register file (R0=0)

tests/unit_tests/           Component-level testbenches (7)
  tb_alu.v  tb_control_unit.v  tb_cpu.v  tb_dmem.v
  tb_imem.v  tb_pc.v  tb_regfile.v

tests/isa_tests/            Per-instruction testbenches (12) + HEX programs (12)
  tb_simple_com.v + program_simple_com.hex    (ADD/SUB/AND/OR)
  tb_xor.v        + program_xor_test.hex
  tb_sll.v        + program_sll_test.hex
  tb_srl.v        + program_srl_test.hex
  tb_sra.v        + program_sra_test.hex
  tb_slti.v       + program_slti_test.hex
  tb_addi.v       + program_addi_test.hex
  tb_beq.v        + program_beq_test.hex
  tb_bne.v        + program_bne_test.hex
  tb_lw.v         + program_lw_test.hex
  tb_sw.v         + program_sw_test.hex
  tb_jmp.v        + program_jmp_test.hex

tests/asm/                  Assembly source files
tools/simulator.py          Python golden model (12 self-tests)
tools/simulator.cpp         C++ golden model (12 self-tests)
tools/tools/assembler.py    Two-pass assembler (ASM -> HEX)
tools/tools/assemble_all.py Batch assembler for all test programs
```

## Quick Start

Requirements: [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog` + `vvp`), Python 3+.

```bash
# 1. Run all unit tests
for tb in tests/unit_tests/tb_alu.v tests/unit_tests/tb_control_unit.v tests/unit_tests/tb_pc.v tests/unit_tests/tb_regfile.v tests/unit_tests/tb_imem.v tests/unit_tests/tb_dmem.v; do
  iverilog -o sim/test "$tb" src/alu.v src/control_unit.v src/pc.v src/regfile.v src/imem.v src/dmem.v && vvp sim/test
done

# 2. Run full CPU integration test
iverilog -o sim/cpu_sim tests/unit_tests/tb_cpu.v src/cpu.v src/pc.v src/imem.v src/control_unit.v src/regfile.v src/alu.v src/dmem.v
vvp sim/cpu_sim

# 3. Run an ISA test (e.g. XOR)
iverilog -o sim/xor_sim tests/isa_tests/tb_xor.v src/cpu.v src/pc.v src/imem.v src/control_unit.v src/regfile.v src/alu.v src/dmem.v
vvp sim/xor_sim

# 4. Run golden model self-tests
python tools/simulator.py --self-test
```

## Notes

- Short HEX programs produce a harmless `$readmemh` warning ("not enough words") when loaded into the 256-word ROM. This is expected.
- See [SIMULATOR.md](SIMULATOR.md) for detailed golden model documentation, ISA reference, trace format, and debugging tips.
