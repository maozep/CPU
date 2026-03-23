# 8-bit RISC Processor Design (Verilog)

This project presents the design, implementation, and verification of an 8-bit RISC (Reduced Instruction Set Computer) processor using the Verilog Hardware Description Language (HDL). The project is built using a modular, top-down design approach, where each component is developed, tested, and verified independently (Unit Testing) prior to system-level integration.

## 🚀 Current Status
The project has successfully transitioned from the "Core Component" phase to the **Full Architecture Integration Phase**. We have completed the integration of the **Control Unit** with the ALU and Register File, creating a functional **Fetch-Decode-Execute** pipeline.

The processor now supports automated execution of machine code instructions loaded via `program.hex`, with a verified path from instruction fetching to register write-back.

### Implemented & Verified Components:
* **Control Unit (New)**: Decodes 16-bit instructions into specific control signals for the ALU and Register File.
* **ALU (Arithmetic Logic Unit)**: Executes arithmetic (ADD, SUB) and logical (AND, OR) operations.
* **Register File**: An internal 8x8-bit register array supporting asynchronous dual-read and synchronous single-write operations.
* **Instruction Fetch Path**: Integrated **Program Counter (PC)** and **Instruction Memory (IMEM)** for automated program flow.

## 🛠️ Instruction Set Architecture (ISA)
The processor utilizes a **16-bit instruction width** to support a rich set of operations while maintaining an **8-bit datapath**.

**Instruction Format:**
`[15:12] Opcode | [11:9] Rd | [8:6] Rs1 | [5:3] Rs2 | [2:0] Reserved`

| Opcode | Mnemonic | Operation | Description |
| :--- | :--- | :--- | :--- |
| `4'h1` | **ADD** | `Rd = Rs1 + Rs2` | Arithmetic Addition |
| `4'h2` | **SUB** | `Rd = Rs1 - Rs2` | Arithmetic Subtraction |
| `4'h3` | **AND** | `Rd = Rs1 & Rs2` | Bitwise Logical AND |
| `4'h4` | **OR** | `Rd = Rs1 | Rs2` | Bitwise Logical OR |

## 📂 Project Structure
The repository is organized with a strict engineering separation between the design source code (RTL) and the verification environments (Testbenches):

```text
.
├── src/                # Hardware Design Source Files (RTL)
│   ├── alu.v           # Arithmetic Logic Unit
│   ├── regfile.v       # Register File
│   ├── pc.v            # Program Counter
│   ├── imem.v          # Instruction Memory
│   ├── control_unit.v  # Instruction Decoder & Control Logic (New)
│   └── cpu.v           # Top-Level System Integration
├── tests/              # Verification Environments (Testbenches)
│   ├── tb_alu.v
│   ├── tb_regfile.v
│   ├── tb_control_unit.v # Unit test for the decoder
│   ├── tb_cpu.v        # Full system simulation
│   └── program.hex     # Machine code file loaded during simulation
└── README.md