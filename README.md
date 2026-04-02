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

## Notes

- `imem.v` initializes the full ROM to zero before `$readmemh`, so short HEX programs are safe.
- You may still see a `$readmemh` warning about "not enough words" when loading short files into a 256-word ROM. This is expected and non-fatal.

## Next Planned Step

Build an assembler tool (Assembly -> HEX) to replace manual hex editing and support labels for branch targets.