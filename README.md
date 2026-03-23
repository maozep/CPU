# 8-bit RISC Processor Design (Verilog)

This project presents the design, implementation, and verification of an 8-bit RISC (Reduced Instruction Set Computer) processor using the Verilog Hardware Description Language (HDL). The project is built using a modular, top-down design approach, where each component is developed, tested, and verified independently (Unit Testing) prior to system-level integration.

## 🚀 Current Status
Currently, the development and verification of the **Core Components** have been completed. All modules have been rigorously tested against edge cases and verified successfully using waveform simulations. 

We are currently at the **Integration Phase**, successfully connecting the Program Counter to the Instruction Memory to create an automated Instruction Fetch path.

This processor implements a **Harvard Architecture**: an **8-bit datapath** (ALU/Register File) and a **16-bit instruction width** (Instruction Memory / instruction fetch) to support a richer RISC ISA.

### Implemented & Verified Components:
* **ALU (Arithmetic Logic Unit)**: Executes arithmetic (ADD, SUB) and logical (AND, OR, XOR) operations, featuring a Zero Flag to support future conditional branching.
* **Register File**: An internal 8x8-bit register array supporting asynchronous dual-read and synchronous single-write operations within the same clock cycle.
* **Program Counter (PC)**: An 8-bit counter equipped with an asynchronous reset mechanism.
* **Instruction Memory (IMEM)**: A 256-byte Read-Only Memory (ROM) for instruction storage, supporting dynamic loading of machine code from an external hex file (`program.hex`).

## 📂 Project Structure
The repository is organized with a strict engineering separation between the design source code (RTL) and the verification environments (Testbenches):

```text
.
├── src/                # Hardware Design Source Files (RTL)
│   ├── alu.v           # Arithmetic Logic Unit
│   ├── regfile.v       # Register File
│   ├── pc.v            # Program Counter
│   ├── imem.v          # Instruction Memory
│   └── cpu.v           # Top-Level Module (Integration)
├── tests/              # Verification Environments (Testbenches)
│   ├── tb_alu.v
│   ├── tb_regfile.v
│   ├── tb_pc.v
│   ├── tb_imem.v
│   ├── tb_cpu.v
│   └── program.hex     # Machine code file loaded during simulation
└── README.md