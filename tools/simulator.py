#!/usr/bin/env python3
"""
C++ RISC CPU Behavioral Simulator (Golden Model)
Executes 16-bit RISC instructions from HEX files
Python version for immediate execution (C++ version also available)
"""

import sys
from typing import List

class CPUSimulator:
    def __init__(self):
        self.registers = [0] * 8          # R0-R7, 8-bit
        self.imem = [0] * 256             # Instruction memory, 16-bit words
        self.pc = 0                       # Program counter, 8-bit
        self.halted = False               # HALT flag
        self.instruction_count = 0        # Execution counter
        self.trace_enabled = True         # Verbose trace print flag

    def reset(self):
        self.registers = [0] * 8
        self.imem = [0] * 256
        self.pc = 0
        self.halted = False
        self.instruction_count = 0

    def set_trace(self, enabled: bool):
        self.trace_enabled = enabled

    def load_program(self, words: List[int]):
        self.reset()
        for i, word in enumerate(words[:256]):
            self.imem[i] = word & 0xFFFF

    def set_register(self, idx: int, value: int):
        if 0 <= idx < 8 and idx != 0:
            self.registers[idx] = value & 0xFF

    def seed_demo_registers(self):
        for i in range(1, 8):
            self.registers[i] = i
    
    def load_hex(self, filename: str) -> bool:
        """Load HEX file into instruction memory"""
        self.reset()
        try:
            with open(filename, 'r') as f:
                address = 0
                for line_num, line in enumerate(f, 1):
                    # Remove comments
                    if '//' in line:
                        line = line[:line.index('//')]
                    
                    line = line.strip()
                    if not line:
                        continue
                    
                    try:
                        value = int(line, 16)
                        if value > 0xFFFF:
                            print(f"[LOADER] Warning: Value 0x{value:04X} exceeds 16-bit on line {line_num}")
                        self.imem[address] = value & 0xFFFF
                        address += 1
                        if address >= 256:
                            break
                    except ValueError:
                        print(f"[LOADER] Warning: Invalid hex value '{line}' on line {line_num}")
            
            if self.trace_enabled:
                print(f"[LOADER] Loaded {address} instructions from {filename}")
            return True
        except FileNotFoundError:
            print(f"[ERROR] Cannot open file: {filename}")
            return False
        except Exception as e:
            print(f"[ERROR] Exception loading file: {e}")
            return False
    
    def extract_bits(self, value: int, high: int, low: int) -> int:
        """Extract bits [high:low] from value"""
        width = high - low + 1
        return (value >> low) & ((1 << width) - 1)
    
    def sign_extend(self, value: int, width: int) -> int:
        """Sign-extend a value from given width to 32-bit signed int"""
        if value & (1 << (width - 1)):
            # Sign bit is set; extend with 1s
            return value | ((-1) << width)
        return value
    
    def fetch(self) -> int:
        """Fetch instruction at current PC"""
        return self.imem[self.pc]
    
    def execute_addi(self, instr: int):
        """Execute ADDI instruction: rd = rs1 + sign_extend(imm6)"""
        rd  = self.extract_bits(instr, 11, 9)
        rs1 = self.extract_bits(instr, 8, 6)
        imm6_raw = self.extract_bits(instr, 5, 0)
        imm6 = self.sign_extend(imm6_raw, 6)
        val1 = self.registers[rs1]
        result = (val1 + imm6) & 0xFF
        if self.trace_enabled:
            print(f"ADDI R{rd} = R{rs1}({val1}) + {imm6} = {result}")
        self.registers[rd] = result
        self.pc = (self.pc + 1) & 0xFF

    def execute_alu(self, instr: int, op: str):
        """Execute ALU instruction (ADD, SUB, AND, OR)"""
        rd = self.extract_bits(instr, 11, 9)
        rs1 = self.extract_bits(instr, 8, 6)
        rs2 = self.extract_bits(instr, 5, 3)

        val1 = self.registers[rs1]
        val2 = self.registers[rs2]
        
        if op == '+':
            result = (val1 + val2) & 0xFF
            if self.trace_enabled:
                print(f"ADD R{rd} = R{rs1}({val1}) + R{rs2}({val2}) = {result}", end="")
        elif op == '-':
            result = (val1 - val2) & 0xFF
            if self.trace_enabled:
                print(f"SUB R{rd} = R{rs1}({val1}) - R{rs2}({val2}) = {result}", end="")
        elif op == '&':
            result = val1 & val2
            if self.trace_enabled:
                print(f"AND R{rd} = R{rs1}({val1}) & R{rs2}({val2}) = {result}", end="")
        elif op == '|':
            result = val1 | val2
            if self.trace_enabled:
                print(f"OR  R{rd} = R{rs1}({val1}) | R{rs2}({val2}) = {result}", end="")
        
        self.registers[rd] = result
        self.pc = (self.pc + 1) & 0xFF
        if self.trace_enabled:
            print()
    
    def execute_branch(self, instr: int, is_beq: bool):
        """Execute branch instruction (BEQ or BNE)"""
        rs1 = self.extract_bits(instr, 11, 9)
        rs2 = self.extract_bits(instr, 8, 6)
        offset_raw = self.extract_bits(instr, 5, 0)
        
        # Sign-extend 6-bit offset to signed integer
        offset = self.sign_extend(offset_raw, 6)
        
        val1 = self.registers[rs1]
        val2 = self.registers[rs2]
        
        if is_beq:
            branch_taken = (val1 == val2)
            if self.trace_enabled:
                print(f"BEQ R{rs1}({val1}) == R{rs2}({val2}) ? ", end="")
        else:
            branch_taken = (val1 != val2)
            if self.trace_enabled:
                print(f"BNE R{rs1}({val1}) != R{rs2}({val2}) ? ", end="")
        
        next_pc = (self.pc + 1) & 0xFF
        
        if branch_taken:
            next_pc = (next_pc + offset) & 0xFF
            if self.trace_enabled:
                print(f"YES -> PC = {(self.pc + 1) & 0xFF} + {offset} = {next_pc}")
        else:
            if self.trace_enabled:
                print(f"NO -> PC = {next_pc}")
        
        self.pc = next_pc
    
    def execute_halt(self):
        """Execute HALT instruction"""
        if self.trace_enabled:
            print("HALT -- Execution stopped")
        self.halted = True
    
    def execute(self, instr: int):
        """Decode and execute instruction"""
        opcode = self.extract_bits(instr, 15, 12)
        
        if self.trace_enabled:
            print(f"[PC={self.pc:02x} | Instr=0x{instr:04x}] ", end="")
        
        if opcode == 0x0:      # HALT
            self.execute_halt()
        elif opcode == 0x1:    # ADD
            self.execute_alu(instr, '+')
        elif opcode == 0x2:    # SUB
            self.execute_alu(instr, '-')
        elif opcode == 0x3:    # AND
            self.execute_alu(instr, '&')
        elif opcode == 0x4:    # OR
            self.execute_alu(instr, '|')
        elif opcode == 0x5:    # BEQ
            self.execute_branch(instr, True)
        elif opcode == 0x6:    # BNE
            self.execute_branch(instr, False)
        elif opcode == 0x7:    # ADDI
            self.execute_addi(instr)
        else:
            if self.trace_enabled:
                print(f"UNKNOWN OPCODE 0x{opcode:x}")
    
    def print_registers(self):
        """Print current register file state"""
        reg_str = "  Registers: " + " ".join(f"R{i}={self.registers[i]:02x}" for i in range(8))
        print(reg_str)
    
    def run(self, max_steps: int = 10000) -> bool:
        """Execute fetch-decode-execute loop"""
        if self.trace_enabled:
            print("\n=== Starting CPU Simulation ===")
            print(f"Initial PC: {self.pc}\n")
        
        while not self.halted and self.pc < 256 and self.instruction_count < max_steps:
            if self.trace_enabled:
                self.print_registers()
            instr = self.fetch()
            self.execute(instr)
            self.instruction_count += 1

        completed_by_halt = self.halted
        if not completed_by_halt and self.trace_enabled:
            print(f"[WARN] Stopped due to max_steps={max_steps}")
        
        if self.trace_enabled:
            print("\n=== Simulation Complete ===")
            print(f"Total instructions executed: {self.instruction_count}")
            print(f"Final PC: {self.pc}")
            print("Final Registers: " + " ".join(f"R{i}={self.registers[i]:02x}" for i in range(8)))

        return completed_by_halt


def encode_rtype(opcode: int, rd: int, rs1: int, rs2: int) -> int:
    return ((opcode & 0xF) << 12) | ((rd & 0x7) << 9) | ((rs1 & 0x7) << 6) | ((rs2 & 0x7) << 3)


def encode_branch(opcode: int, rs1: int, rs2: int, offset6: int) -> int:
    return ((opcode & 0xF) << 12) | ((rs1 & 0x7) << 9) | ((rs2 & 0x7) << 6) | (offset6 & 0x3F)


def encode_itype(opcode: int, rd: int, rs1: int, imm6: int) -> int:
    return ((opcode & 0xF) << 12) | ((rd & 0x7) << 9) | ((rs1 & 0x7) << 6) | (imm6 & 0x3F)


def run_self_tests() -> int:
    tests = []

    def test_alu_sequence():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_rtype(0x1, 3, 1, 2),
            encode_rtype(0x2, 4, 3, 2),
            encode_rtype(0x3, 5, 3, 2),
            encode_rtype(0x4, 6, 4, 2),
            0x0000,
        ])
        cpu.set_register(1, 5)
        cpu.set_register(2, 2)
        assert cpu.run()
        assert cpu.registers[3] == 7
        assert cpu.registers[4] == 5
        assert cpu.registers[5] == 2
        assert cpu.registers[6] == 7

    def test_beq_taken_skip():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_branch(0x5, 1, 2, 1),
            encode_rtype(0x1, 3, 1, 1),
            encode_rtype(0x1, 4, 1, 2),
            0x0000,
        ])
        cpu.set_register(1, 9)
        cpu.set_register(2, 9)
        assert cpu.run()
        assert cpu.registers[3] == 0
        assert cpu.registers[4] == 18

    def test_bne_negative_loop():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_rtype(0x2, 1, 1, 7),
            encode_branch(0x6, 1, 0, -2),
            0x0000,
        ])
        cpu.set_register(1, 3)
        cpu.set_register(7, 1)
        assert cpu.run()
        assert cpu.registers[1] == 0
        assert cpu.pc == 2

    def test_max_steps_guard():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_branch(0x6, 1, 0, -1),
            0x0000,
        ])
        cpu.set_register(1, 1)
        halted = cpu.run(max_steps=20)
        assert halted is False
        assert cpu.pc == 0
        assert cpu.instruction_count == 20

    def test_addi():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_itype(0x7, 2, 1, 10),   # R2 = R1 + 10  (5+10=15)
            encode_itype(0x7, 3, 1, -3),   # R3 = R1 + (-3) (5-3=2)
            encode_itype(0x7, 4, 0, 7),    # R4 = R0 + 7   (0+7=7)
            encode_itype(0x7, 5, 2, 31),   # R5 = R2 + 31  (15+31=46)
            encode_itype(0x7, 6, 2, -32),  # R6 = R2 + (-32) (15-32= wrap 239)
            0x0000,
        ])
        cpu.set_register(1, 5)
        assert cpu.run()
        assert cpu.registers[2] == 15,  f"R2={cpu.registers[2]}"
        assert cpu.registers[3] == 2,   f"R3={cpu.registers[3]}"
        assert cpu.registers[4] == 7,   f"R4={cpu.registers[4]}"
        assert cpu.registers[5] == 46,  f"R5={cpu.registers[5]}"
        assert cpu.registers[6] == 239, f"R6={cpu.registers[6]}"

    tests.append(("ALU sequence", test_alu_sequence))
    tests.append(("BEQ taken", test_beq_taken_skip))
    tests.append(("BNE loop to zero", test_bne_negative_loop))
    tests.append(("Max-steps guard", test_max_steps_guard))
    tests.append(("ADDI immediate", test_addi))

    print(f"[SELF-TEST] Running {len(tests)} Python simulator tests")
    passed = 0
    for name, fn in tests:
        try:
            fn()
            passed += 1
            print(f"  [PASS] {name}")
        except AssertionError as exc:
            msg = str(exc) if str(exc) else "assertion failed"
            print(f"  [FAIL] {name} -- {msg}")
    print(f"[SELF-TEST] Summary: {passed}/{len(tests)} passed")
    return 0 if passed == len(tests) else 1


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--self-test":
        sys.exit(run_self_tests())

    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <hex_file> [--demo]")
        print(f"       {sys.argv[0]} --self-test")
        print(f"Example: {sys.argv[0]} program.hex --demo")
        sys.exit(1)
    
    hex_file = sys.argv[1]
    cpu = CPUSimulator()
    
    if not cpu.load_hex(hex_file):
        sys.exit(1)

    if len(sys.argv) >= 3 and sys.argv[2] == "--demo":
        print("[MODE] Demo register seed enabled (R1=1..R7=7)")
        cpu.seed_demo_registers()
    
    cpu.run()


if __name__ == "__main__":
    main()
