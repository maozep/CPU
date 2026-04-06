# Simple 8-bit CPU (Verilog)

This repository implements and verifies a simple 8-bit CPU with a 16-bit instruction format.
The design follows a modular RTL approach, with unit tests for each block and integration/ISA tests
for end-to-end behavior.

## Current Status

Implemented and verified:

- ALU operations: ADD, SUB, AND, OR
- Immediate add: ADDI (rd = rs1 + sign_extend(imm6))
- Register file: 8x8, dual asynchronous read, single synchronous write, R0 hard-wired to zero
- Branching: BEQ and BNE with signed 6-bit offset
- Real HALT behavior: PC freezes when HALT is decoded
- Full fetch-decode-execute integration in top-level CPU
- Assembler tool: Assembly -> HEX with labels and signed branch offset resolution

## ISA Summary

Datapath width: 8-bit  
Instruction width: 16-bit

R-type format:

```
[15:12] opcode | [11:9] rd | [8:6] rs1 | [5:3] rs2 | [2:0] reserved
```

I-type format (ADDI):

```
[15:12] opcode | [11:9] rd | [8:6] rs1 | [5:0] signed immediate (imm6)
```

Branch format:

```
[15:12] opcode | [11:9] rs1 | [8:6] rs2 | [5:0] signed offset
```

Supported opcodes:

| Opcode | Mnemonic | Format | Behavior |
| --- | --- | --- | --- |
| `4'h0` | HALT | — | Stop PC advance (freeze at current instruction address) |
| `4'h1` | ADD | R-type | `rd = rs1 + rs2` |
| `4'h2` | SUB | R-type | `rd = rs1 - rs2` |
| `4'h3` | AND | R-type | `rd = rs1 & rs2` |
| `4'h4` | OR | R-type | `rd = rs1 \| rs2` |
| `4'h5` | BEQ | Branch | if equal, `PC = PC + 1 + offset` |
| `4'h6` | BNE | Branch | if not equal, `PC = PC + 1 + offset` |
| `4'h7` | ADDI | I-type | `rd = rs1 + sign_extend(imm6)` (imm6 range: −32..+31) |

## Project Structure

```text
.
├── src/
│   ├── alu.v
│   ├── control_unit.v
│   ├── cpu.v
│   ├── imem.v
│   ├── pc.v
│   └── regfile.v
├── tests/
│   ├── asm/
│   │   ├── program_addi_test.asm
│   │   ├── program_bne_loop.asm
│   │   └── program_simple_com.asm
│   ├── program.hex
│   ├── isa_tests/
│   │   ├── program_addi_test.hex
│   │   ├── program_simple_com.hex
│   │   ├── tb_addi.v
│   │   └── tb_simple_com.v
│   └── unit_tests/
│       ├── tb_alu.v
│       ├── tb_control_unit.v
│       ├── tb_cpu.v
│       ├── tb_imem.v
│       ├── tb_pc.v
│       └── tb_regfile.v
├── tools/
│   └── tools/
│       └── assembler.py
├── sim/
├── waves/
└── README.md
```

## Verification

All current testbenches pass in Icarus Verilog (`iverilog` + `vvp`).

Unit tests:

- `tests/unit_tests/tb_alu.v`
- `tests/unit_tests/tb_control_unit.v`
- `tests/unit_tests/tb_pc.v`
- `tests/unit_tests/tb_regfile.v`
- `tests/unit_tests/tb_imem.v`
- `tests/unit_tests/tb_cpu.v`

ISA tests:

- `tests/isa_tests/tb_simple_com.v` — ADD, SUB, AND, OR
- `tests/isa_tests/tb_addi.v` — ADDI (positive, negative, wrap-around immediates)

## Assembler

The project now includes an assembler implementation in `tools/tools/assembler.py`.

Supported mnemonics:

- `HALT`
- `ADD rd, rs1, rs2`
- `SUB rd, rs1, rs2`
- `AND rd, rs1, rs2`
- `OR rd, rs1, rs2`
- `BEQ rs1, rs2, label_or_offset`
- `BNE rs1, rs2, label_or_offset`
- `ADDI rd, rs1, imm` (imm is a signed integer in −32..+31)

Assembler features:

- Two-pass parsing (label collection + encoding)
- Label support (`loop:`)
- Signed branch offset calculation for 6-bit branch immediate
- Input validation with source line errors (bad registers, unknown labels, offset out of range)
- Optional listing output (PC/HEX/source)
- Default build script that generates the exact HEX files used by tests

## Quick Run Commands

Run from repository root.

Example: CPU integration test

```bash
iverilog -o sim/cpu_sim tests/unit_tests/tb_cpu.v src/cpu.v src/pc.v src/imem.v src/control_unit.v src/regfile.v src/alu.v
vvp sim/cpu_sim
```

Example: ISA test

```bash
iverilog -o sim/sim_cpu tests/isa_tests/tb_simple_com.v src/cpu.v src/pc.v src/imem.v src/control_unit.v src/regfile.v src/alu.v
vvp sim/sim_cpu
```

Example: assemble an ISA smoke program

```bash
python tools/tools/assembler.py tests/asm/program_simple_com.asm -o tests/isa_tests/program_simple_com.hex --listing sim/program_simple_com.lst
```

Example: assemble a loop/branch program with labels

```bash
python tools/tools/assembler.py tests/asm/program_bne_loop.asm -o tests/program_bne_loop.hex --listing sim/program_bne_loop.lst
```

Recommended: build all default HEX targets used by tests

```bash
python tools/tools/assemble_all.py
```

Typical flow:

1. Write or edit an `.asm` file under `tests/asm/`
2. Run `python tools/tools/assemble_all.py`
3. Run simulation with `iverilog` + `vvp`

## Behavioral Simulator (Golden Model)

A C++/Python behavioral simulator is included to verify ISA correctness against your Verilog implementation.
This "Golden Model" executes the same HEX files as the RTL and shows register state after each instruction.

**Quick start:**

```bash
# Python version (recommended - works immediately)
python tools/simulator.py tests/program.hex
python tools/simulator.py tests/program.hex --demo
python tools/simulator.py --self-test

# C++ version (if g++ is installed)
g++ -o tools/sim_cpu tools/simulator.cpp -std=c++11
./tools/sim_cpu tests/program.hex
./tools/sim_cpu tests/program.hex --demo
./tools/sim_cpu --self-test
```

Windows (MSYS2 one-command compile+run):

```powershell
C:\msys64\usr\bin\bash.exe -lc 'export PATH=/ucrt64/bin:$PATH; cd /c/Users/LENOVO/Desktop/cursor/Simple-8bit-CPU-Verilog; g++ tools/simulator.cpp -o tools/sim_cpu.exe -std=c++11 && ./tools/sim_cpu.exe tests/program.hex --demo'
```

Latest validation highlights:

- Python simulator built-in self-tests: `5/5` passed (`--self-test`, includes ADDI)
- C++ simulator built-in self-tests: `5/5` passed (`--self-test`, includes ADDI)
- Verilog PC edge tests in `tests/unit_tests/tb_pc.v` include `+31`, `-32`, and 8-bit wrap-around branch behavior
- Verilog ADDI ISA test (`tests/isa_tests/tb_addi.v`): PASS — positive imm, negative imm, R0 source, max/min imm6, 8-bit wrap
- Full regression (`tools/tools/e2e_run.py`) passes after updates

See [SIMULATOR.md](SIMULATOR.md) for full documentation, ISA reference, troubleshooting, and verification techniques.

## Notes

- `imem.v` initializes the full ROM to zero before `$readmemh`, so short HEX programs are safe.
- You may still see a `$readmemh` warning about "not enough words" when loading short files into a 256-word ROM. This is expected and non-fatal.