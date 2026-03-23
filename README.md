# 8-bit RISC Processor Design (Verilog)

This project presents the design, implementation, and verification of an 8-bit RISC (Reduced Instruction Set Computer) processor using the Verilog Hardware Description Language (HDL). The project is built using a modular, top-down design approach, where each component is developed, tested, and verified independently (Unit Testing) prior to system-level integration.

## 🚀 Current Status
The project has reached a major milestone: **Full System Functionality**. The processor successfully executes multi-instruction programs loaded via `program.hex`. 

We have verified the complete **Fetch-Decode-Execute** cycle, confirming that the Control Unit correctly orchestrates data flow between the Instruction Memory, Register File, and ALU over multiple clock cycles.

### Implemented & Verified Components:
* **Full CPU Integration**: Successfully wired all sub-modules into a cohesive processing unit.
* **Multi-Cycle Execution**: Verified the ability to run sequences of instructions with data dependencies.
* **Control Unit**: Decodes 16-bit instructions into specific control signals for the ALU and Register File.
* **ALU (Arithmetic Logic Unit)**: Executes arithmetic (ADD, SUB) and logical (AND, OR) operations.
* **Register File**: Supporting asynchronous dual-read and synchronous single-write operations.
* **Instruction Fetch Path**: Integrated **PC** and **IMEM** for automated program flow.

## ✅ Verification Results
The processor's logic has been rigorously verified through behavioral simulation using **Icarus Verilog** and **GTKWave**. 

### System Integration Test (Simulation)
The latest integration run confirmed the following:
* **Data Dependency:** Result of a previous instruction (e.g., `Rd` of instruction N) is correctly used as an operand (`Rs`) in instruction N+1.
* **Control Flow:** The Control Unit successfully decodes opcodes and orchestrates ALU operations without timing violations.
* **Register Persistence:** Internal registers maintain their state and are updated only on the rising edge of the clock when `reg_write` is active.

#### Waveform Analysis:
- **T=20ns:** Reset phase completed.
- **T=25ns:** Fetching `1312` (ADD R3, R1, R2). Result `0F` (15) computed.
- **T=35ns:** Fetching `1432` (ADD R4, R3, R2). Successfully uses `0F` from the previous cycle to compute `14` (20).

## 🛠️ Instruction Set Architecture (ISA)
The processor utilizes a **16-bit instruction width** to support a rich set of operations while maintaining an **8-bit datapath**.

**Instruction Format:**
`[15:12] Opcode | [11:9] Rd | [8:6] Rs1 | [5:3] Rs2 | [2:0] Reserved`

| Opcode | Mnemonic | Operation | Description | Status |
| :--- | :--- | :--- | :--- | :--- |
| `4'h1` | **ADD** | `Rd = Rs1 + Rs2` | Arithmetic Addition | **Verified** |
| `4'h2` | **SUB** | `Rd = Rs1 - Rs2` | Arithmetic Subtraction | **Verified** |
| `4'h3` | **AND** | `Rd = Rs1 & Rs2` | Bitwise Logical AND | **Verified** |
| `4'h4` | **OR** | `Rd = Rs1 \| Rs2` | Bitwise Logical OR | **Verified** |

## 📂 Project Structure
```text
.
├── src/                # Hardware Design Source Files (RTL)
│   ├── alu.v           # Arithmetic Logic Unit
│   ├── regfile.v       # Register File
│   ├── pc.v            # Program Counter
│   ├── imem.v          # Instruction Memory (Loads program.hex)
│   ├── control_unit.v  # Instruction Decoder & Control Logic
│   └── cpu.v           # Top-Level System Integration
├── tests/              # Verification Environments (Testbenches)
│   ├── tb_alu.v
│   ├── tb_regfile.v
│   ├── tb_control_unit.v
│   ├── tb_cpu.v        # Full system simulation & Integration test
│   └── program.hex     # Machine code file loaded during simulation
└── README.md