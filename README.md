# Simple 8-bit CPU (Verilog)

This repository implements and verifies a simple 8-bit CPU with a 16-bit instruction format.
The design follows a modular RTL approach, with unit tests for each block and integration/ISA tests
for end-to-end behavior.

## Current Status

Implemented and verified:

- ALU operations: ADD, SUB, AND, OR
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

Branch format:

```
[15:12] opcode | [11:9] rs1 | [8:6] rs2 | [5:0] signed offset
```

Supported opcodes:

| Opcode | Mnemonic | Behavior |
| --- | --- | --- |
| `4'h0` | HALT | Stop PC advance (freeze at current instruction address) |
| `4'h1` | ADD | `rd = rs1 + rs2` |
| `4'h2` | SUB | `rd = rs1 - rs2` |
| `4'h3` | AND | `rd = rs1 & rs2` |
| `4'h4` | OR | `rd = rs1 \| rs2` |
| `4'h5` | BEQ | if equal, `PC = PC + 1 + offset` |
| `4'h6` | BNE | if not equal, `PC = PC + 1 + offset` |

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
│   │   ├── program_bne_loop.asm
│   │   └── program_simple_com.asm
│   ├── program.hex
│   ├── isa_tests/
│   │   ├── program_simple_com.hex
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

ISA test:

- `tests/isa_tests/tb_simple_com.v`

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

## Notes

- `imem.v` initializes the full ROM to zero before `$readmemh`, so short HEX programs are safe.
- You may still see a `$readmemh` warning about "not enough words" when loading short files into a 256-word ROM. This is expected and non-fatal.