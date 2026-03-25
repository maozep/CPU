# 8-bit RISC Processor Design (Verilog)

This project presents the design, implementation, and verification of an 8-bit RISC (Reduced Instruction Set Computer) processor using the Verilog Hardware Description Language (HDL). The project is built using a modular, top-down design approach, where each component is developed, tested, and verified independently (Unit Testing) prior to system-level integration.

## 🚀 Current Status
The project has reached a major milestone: **Advanced Control Flow Support**. The processor successfully executes complex programs involving conditional branching and loops loaded via `program.hex`.

We have verified the complete **Fetch-Decode-Execute** cycle, including support for **Signed Offsets**, allowing the processor to perform backward jumps and execute repetitive logic (loops).

### Implemented & Verified Components:
* **Full CPU Integration**: Successfully wired all sub-modules into a cohesive processing unit.
* **Control Flow & Branching**: Implemented `BEQ` and **`BNE`** with **Sign Extension** for 6-bit offsets.
* **Multi-Cycle Execution**: Verified sequences of instructions with data dependencies and jumps.
* **Control Unit**: Decodes 16-bit instructions into specific control signals for the ALU, Register File, and PC.
* **ALU (Arithmetic Logic Unit)**: Executes arithmetic (ADD, SUB) and logical (AND, OR) operations with a `Zero` flag.
* **Register File**: Supporting asynchronous dual-read and synchronous single-write operations.
* **Instruction Fetch Path**: Integrated **PC** with branch logic and **IMEM** for automated flow.

## ✅ Verification Results
The processor's logic has been rigorously verified through behavioral simulation using **Icarus Verilog** and **GTKWave**.

### System Integration Test: Accumulation Loop (1 to 5)
The latest integration run confirmed successful execution of an **Arithmetic Accumulation Loop**:
* **Algorithm:** The processor calculates the sum of integers from 1 to 5 (1+2+3+4+5=15).
* **Branch Logic:** The **`BNE`** instruction correctly identifies when the counter has not yet reached the target, jumping back to the loop start.
* **Backward Jumping:** Verified that the **Signed Offset** correctly recalculated the PC to jump backward (e.g., PC 4 -> PC 2).

#### Waveform Analysis:
- **T=20ns:** Reset phase completed.
- **T=25ns-300ns:** Successive loop iterations, updating the sum in R3.
- **T=310ns:** Target reached, `BNE` condition fails (values are equal), and the processor reaches the `HALT` state.
- **Final Result:** Register R3 contains `0x0F` (15).

## 🛠️ Instruction Set Architecture (ISA)
The processor utilizes a **16-bit instruction width** to support a rich set of operations while maintaining an **8-bit datapath**.

**R-Type Format:** `[15:12] Opcode | [11:9] Rd | [8:6] Rs1 | [5:3] Rs2 | [2:0] Reserved`  
**Branch Format:** `[15:12] Opcode | [11:9] Rs1 | [8:6] Rs2 | [5:0] Signed Offset`

| Opcode | Mnemonic | Operation | Description | Status |
| :--- | :--- | :--- | :--- | :--- |
| `4'h1` | **ADD** | `Rd = Rs1 + Rs2` | Arithmetic Addition | **Verified** |
| `4'h2` | **SUB** | `Rd = Rs1 - Rs2` | Arithmetic Subtraction | **Verified** |
| `4'h3` | **AND** | `Rd = Rs1 & Rs2` | Bitwise Logical AND | **Verified** |
| `4'h4` | **OR** | `Rd = Rs1 \| Rs2` | Bitwise Logical OR | **Verified** |
| `4'h5` | **BEQ** | `if(Rs1==Rs2) PC+=1+Imm` | Branch if Equal (Signed) | **Verified** |
| `4'h6` | **BNE** | `if(Rs1!=Rs2) PC+=1+Imm` | Branch if Not Equal (Signed) | **Verified** |

## 📂 Project Structure
```text
.
├── src/                # Hardware Design Source Files (RTL)
│   ├── alu.v           # ALU with Zero flag support
│   ├── regfile.v       # 8x8-bit Register File
│   ├── pc.v            # Program Counter with Sign-Extended Branching
│   ├── imem.v          # Instruction Memory
│   ├── control_unit.v  # Instruction Decoder
│   └── cpu.v           # Top-Level System Integration
├── tests/              # Verification Environments (Testbenches)
│   ├── tb_cpu.v        # Full system loop and branch integration test
│   └── program.hex     # Machine code file loaded during simulation
└── README.md